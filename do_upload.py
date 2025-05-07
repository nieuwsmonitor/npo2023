from multiprocessing import Pool, Queue, current_process
from amcat4py import AmcatClient
import argparse
from collections import namedtuple
import csv
from functools import cache
import logging
from pathlib import Path
import re
from subprocess import check_output
import sys
from tempfile import TemporaryDirectory
from typing import NamedTuple
import numpy
from pyannote.audio import Audio
from pyannote.audio.pipelines.speaker_verification import PretrainedSpeakerEmbedding
import torch
from jsonmeta import get_meta


from pyannote.core import Segment

FIELDS = {
    "npo_id": "keyword",
    "start": "double",
    "end": "double",
    "speakernum": "keyword",
    "embedding": "dense_vector_192",
    "publisher": "keyword",
    "won": "keyword",
}


class EmbeddingModel(NamedTuple):
    embdedding: PretrainedSpeakerEmbedding
    audio: Audio


@cache
def get_model() -> EmbeddingModel:
    audio = Audio(sample_rate=16000, mono="downmix")
    embedding = PretrainedSpeakerEmbedding(
        "speechbrain/spkrec-ecapa-voxceleb", device=torch.device("cuda")
    )
    embedding.to(torch.device("cuda"))
    return embedding, audio


@cache
def duration(wavfile):
    _, audio = get_model()
    return audio.get_duration(wavfile)


def setup_amcat(amcat, index, delete=False):
    if delete:
        logging.info(f"Deleting index {index}")
        amcat.delete_index(index)
    if not amcat.check_index(index):
        logging.info(f"Creating index {index}")
        amcat.create_index(index)
        amcat.set_fields(index, FIELDS)


UploadJob = namedtuple("UploadJob", ["videofile", "segmentfile", "meta"])


def get_wav(infile, outfile):
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", infile, outfile]
    check_output(cmd)


def get_embedding(wavfile, start, end):
    torch.cuda.empty_cache()
    embedding, audio = get_model()
    turn = Segment(start, min(duration(wavfile), end))
    emb = embedding(audio.crop(wavfile, turn)[0][None])
    emb = list(emb[0])
    if not any((numpy.isnan(x) or (x is None)) for x in emb):
        return emb


def get_docs(job: UploadJob):
    with TemporaryDirectory() as tmpdir:

        wavfile = f"{tmpdir}/tmp.wav"
        logging.info(
            f"[{current_process().pid}] Converting {job.videofile} to {wavfile}"
        )
        get_wav(job.videofile, wavfile)
        logging.info(
            f"[{current_process().pid}] Reading segments from {job.segmentfile}"
        )
        segments = list(csv.DictReader(open(job.segmentfile)))
        logging.info(
            f"[{current_process().pid}] Getting embeddings for {len(segments)} segments from {job.videofile}"
        )
        for i, row in enumerate(segments):
            if i and (not i % 10):
                pct = i * 100 // len(segments)
                logging.info(
                    f"[{current_process().pid}] {job.videofile} [{pct:2}%] Segment {i} / {len(segments)} segments"
                )

            doc = dict(
                publisher=job.meta["name"],
                date=job.meta["date"],
                won=job.meta["won"],
                start=row["start"],
                end=row["stop"],
                speakernum=row["speakernum"],
                text=row["text"],
            )
            emb = get_embedding(wavfile, float(row["start"]), float(row["stop"]))
            if emb:
                doc["embedding"] = emb

            doc["title"] = (
                f"{doc['publisher']} {doc['date']} segment {doc['start']} - {doc['end']}"
            )
            yield doc


def do_upload(amcat: AmcatClient, index: str, job: UploadJob):
    docs = list(get_docs(job))
    logging.info(f"[{current_process().pid}] Uploading {len(docs)} to AmCAT")
    amcat.upload_documents(index, docs, show_progress=True)


def worker(queue: "Queue[UploadJob]", server: str, index: str):
    amcat = AmcatClient(server)

    while not queue.empty():
        job = queue.get(block=False)
        if job is None:
            break
        logging.info(
            f"[{current_process().pid}] Processing {job.videofile} + {job.segmentfile}"
        )
        do_upload(amcat, index, job)


def get_todo(
    amcat: AmcatClient,
    index: str,
    metafolder: Path,
    videofolder: Path,
    segmentfolder: Path,
):
    metadict = dict(get_meta(metafolder))
    existing_wons = {art.get("won") for art in amcat.query(index, fields=["won"])}

    for f in videofolder.glob("*.mp4"):
        if not (m := re.search("-((WON|INC|BV_|INC)[A-Z0-9]+)\\_", f.name)):
            raise Exception(f"Cannot parse {f}")
        won = m.group(1)
        if won in existing_wons:
            continue
        segmentfile = segmentfolder / f.with_suffix(".csv").name
        if not segmentfile.exists():
            logging.warning(f"No segmentfile for {f}")
            continue
        if won not in metadict:
            raise Exception(f"Uknown won {won}")
        yield UploadJob(f, segmentfile, metadict[won])


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s",
    )
    parser = argparse.ArgumentParser()
    parser.add_argument("server")
    parser.add_argument("index")
    parser.add_argument("metafolder", type=Path)
    parser.add_argument("infolder", type=Path)
    parser.add_argument("segmentfolder", type=Path)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--processes", type=int, default=8)
    parser.add_argument(
        "--delete", help="Delete the index before proceeding", action="store_true"
    )
    args = parser.parse_args()

    amcat = AmcatClient(args.server)
    setup_amcat(amcat, args.index, args.delete)

    if args.check:
        for f in get_todo(
            amcat, args.index, args.metafolder, args.infolder, args.segmentfolder
        ):
            print(f)
        sys.exit()

    q = Queue()
    for i, f in enumerate(
        get_todo(amcat, args.index, args.metafolder, args.infolder, args.segmentfolder)
    ):
        q.put(f)
    nworkers = min(args.processes, q.qsize())

    logging.info(
        f"[{current_process().pid}] {q.qsize()} files to do, spawning {nworkers} workers"
    )
    pool = Pool(nworkers, worker, (q, args.server, args.index))
    q.close()
    q.join_thread()
    pool.close()
    pool.join()
    logging.info("Done?")
