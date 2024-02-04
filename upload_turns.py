import argparse
from collections import namedtuple
from functools import lru_cache
import glob
import json
import logging
from operator import index
import sys
import re
from tempfile import NamedTemporaryFile, TemporaryDirectory
import time

from diarizer import Diarizer, get_wav
from jsonmeta import get_meta
from amcat4py import AmcatClient


logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")

FIELDS = {
    "npo_id": "keyword",
    "start": "double",
    "end": "double",
    "speakernum": "keyword",
    "embedding": "dense_vector_192",
    "publisher": "keyword",
    "won": "keyword",
}


def get_existing_wons(conn, index):
    return {art.get("won") for art in conn.query(index, fields=["won"])}


def get_docs(name, infile, diarizer, meta):
    if not (m := re.search("-((WON|INC|BV_|INC)[A-Z0-9]+)\\_", infile)):
        raise Exception(f"Cannot parse {infile}")
    won = m.group(1)
    if won not in meta:
        raise Exception(f"Uknown won {won}")
    meta = meta[won]

    with TemporaryDirectory() as tmpdir:
        wavfile = f"{tmpdir}/tmp.wav"
        logging.info(f"Converting {infile} to {wavfile}")
        get_wav(infile, wavfile)
        for segment in diarizer.transcribe(wavfile, language="nl", initial_prompt=meta["description"]):
            doc = dict(
                publisher=meta["name"],
                date=meta["date"],
                won=meta["won"],
                start=segment.start,
                end=segment.end,
                speakernum=segment.speaker,
                text=segment.text,
            )
            embedding = diarizer.get_embedding(name, wavfile, segment.start, segment.end)
            if embedding:
                doc["embedding"] = embedding

            doc["title"] = f"{doc['publisher']} {doc['date']} segment {doc['start']} - {doc['end']}"
            yield doc


from multiprocessing import Pool, Process, Queue, current_process, pool


def worker(server, index, queue: Queue):
    diarizer = Diarizer(whisper_model="large")
    amcat = AmcatClient(args.server)
    while not queue.empty():
        todo = queue.get(block=False)
        if todo is None:
            break
        logging.info(f"[{current_process().pid} Processing {todo.won}")
        turns = get_docs(todo.won, todo.filename, diarizer, todo.meta)
        logging.info("Uploading to AmCAT")
        amcat.upload_documents(args.index, turns)


def setup_amcat(amcat, index, delete=False):
    if delete:
        logging.info(f"Deleting index {index}")
        amcat.delete_index(index)
    if not amcat.check_index(index):
        logging.info(f"Creating index {index}")
        amcat.create_index(index)
        amcat.set_fields(index, FIELDS)


Todo = namedtuple("Todo", ["filename", "won", "meta"])


def get_todo(amcat, index, pattern):
    wons = get_existing_wons(amcat, index)
    metadict = dict(get_meta())
    for f in glob.glob(pattern):
        if not (m := re.search("-((WON|INC|BV_|INC)[A-Z0-9]+)\\_", f)):
            raise Exception(f"Cannot parse {f}")
        won = m.group(1)
        if won not in metadict:
            raise Exception(f"Uknown won {won}")
        meta = metadict[won]

        if won not in wons:
            yield Todo(f, won, meta)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")
    parser = argparse.ArgumentParser()
    parser.add_argument("server", help="AmCAT host name")
    parser.add_argument("index", help="AmCAT index")
    parser.add_argument("--delete", help="Delete the index before proceeding", action="store_true")
    args = parser.parse_args()

    amcat = AmcatClient(args.server)
    setup_amcat(amcat, args.index, args.delete)
    q = Queue()
    for f in get_todo(amcat, args.index, "/home/wva/npo2023/ks2/*.mp4"):
        q.put(f)
    logging.info(f"[{current_process().pid}] {q.qsize()} files to do, spawning workers")
    pool = Pool(3, worker, (None, None, q))
    q.close()
    q.join_thread()
    pool.close()
    pool.join()
    logging.info("Done?")
