from multiprocessing import Pool, Queue, current_process
import os
import ossaudiodev
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
from datetime import datetime
from pyannote.core import Segment

FIELDS = {
    "npo_id": "keyword",
    "start": "double",
    "end": "double",
    "speakernum": "keyword",
    "embedding": "dense_vector_192",
    "publisher": "keyword",
    "filename": "keyword",
}

UploadJob = namedtuple("UploadJob", ["audiofile", "segmentfile"])


class EmbeddingModel(NamedTuple):
    embdedding: PretrainedSpeakerEmbedding
    audio: Audio


@cache
def get_model() -> EmbeddingModel:
    audio = Audio(sample_rate=16000, mono="downmix")
    embedding = PretrainedSpeakerEmbedding("speechbrain/spkrec-ecapa-voxceleb", device=torch.device("cuda"))
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
        logging.info(f"[{current_process().pid}] Converting {job.audiofile} to {wavfile}")
        get_wav(job.audiofile, wavfile)
        logging.info(f"[{current_process().pid}] Reading segments from {job.segmentfile}")
        segments = list(csv.DictReader(open(job.segmentfile)))
        logging.info(f"[{current_process().pid}] Getting embeddings for {len(segments)} segments from {job.audiofile}")
        for i, row in enumerate(segments):
            if i and (not i % 10):
                pct = i * 100 // len(segments)
                logging.info(
                    f"[{current_process().pid}] {job.audiofile} [{pct:2}%] Segment {i} / {len(segments)} segments"
                )

            doc = dict(
                start=row["start"],
                end=row["stop"],
                speakernum=row["speakernum"],
                text=row["text"],
            )
            f2 = os.path.split(job.audiofile)[1]
            doc["title"] = re.split("\.", f2)[0]
            names = re.match(r"([a-z]+)([0-9]+)", f2, re.I).groups()
            doc["publisher"] = names[0]
            doc["date"] = datetime.strptime(names[1], "%Y%m%d")
            emb = get_embedding(wavfile, float(row["start"]), float(row["stop"]))
            if emb:
                doc["embedding"] = emb

            # doc["title"] = f"{doc['publisher']} {doc['date']} segment {doc['start']} - {doc['end']}"
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
        logging.info(f"[{current_process().pid}] Processing {job.audiofile} + {job.segmentfile}")
        do_upload(amcat, index, job)


def get_meta(folder: Path):
    art = {}
    for f in folder.glob("*.m4a"):
        f2 = os.path.split(f)[1]
        art["title"] = re.split("\.", f2)[0]
        names = re.match(r"([a-z]+)([0-9]+)", f2, re.I).groups()
        art["publisher"] = names[0]
        art["date"] = datetime.strptime(names[1], "%Y%m%d")
    return art


def get_todo(amcat: AmcatClient, index: str, audiofolder: Path, segmentfolder: Path):
    existing_fns = {art.get("filename") for art in amcat.query(index, fields=["filename"])}
    for f in audiofolder.glob("*.m4a"):
        if f.name in existing_fns:
            continue
        segmentfile = segmentfolder / f.with_suffix(".csv").name
        if not segmentfile.exists():
            logging.warning(f"No segmentfile for {f}")
            continue
        yield UploadJob(f, segmentfile)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")
    parser = argparse.ArgumentParser()
    parser.add_argument("server")
    parser.add_argument("index")
    parser.add_argument("infolder", type=Path)
    parser.add_argument("segmentfolder", type=Path)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--processes", type=int, default=4)
    parser.add_argument("--delete", help="Delete the index before proceeding", action="store_true")
    args = parser.parse_args()

    amcat = AmcatClient(args.server)
    setup_amcat(amcat, args.index, args.delete)

    if args.check:
        for f in get_todo(amcat, args.index, args.infolder, args.segmentfolder):
            print(f)
        sys.exit()

    q = Queue()
    for i, f in enumerate(get_todo(amcat, args.index, args.infolder, args.segmentfolder)):
        q.put(f)
    nworkers = min(args.processes, q.qsize())

    logging.info(f"[{current_process().pid}] {q.qsize()} files to do, spawning {nworkers} workers")
    pool = Pool(nworkers, worker, (q, args.server, args.index))
    q.close()
    q.join_thread()
    pool.close()
    pool.join()
    logging.info("Done?")
