import argparse
import csv
import logging
import os
import shutil
import sys
import time
from collections import namedtuple
from multiprocessing import Pool, Queue, current_process, pool
from pathlib import Path
from subprocess import check_output
from tempfile import TemporaryDirectory

import torch
from dotenv import load_dotenv
from pyannote.audio import Pipeline

logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")


Todo = namedtuple("Todo", ["infile", "outfile"])


class LogProgressHook:
    """Replacement for pyannote progresshook to output to stderr and flush"""

    def __init__(self, won):
        self.won = won
        self.last_name, self.last_pct, self.last_time = None, None, None

    def __call__(self, name, *args, total=None, completed=None, **kargs):
        if total is None or completed is None:
            return
        now = time.time()
        pct = completed * 100 // total
        if name != self.last_name:
            self.last_name = name
        elif (self.last_time is not None) and ((now - self.last_time) < 5):
            return
        elif (self.last_pct is not None) and (pct <= self.last_pct):
            return
        self.last_pct = pct
        self.last_time = now
        logging.info(f"{self.won}: {name} {pct}% ({completed}/{total})")


def get_wav(infile, outfile):
    cmd = ["ffmpeg", "-i", infile, outfile]
    check_output(cmd)


def worker(queue: "Queue[Todo]"):
    load_dotenv()
    auth_token = os.environ.get("HUGGINGFACE_TOKEN")
    checkpoint = "pyannote/speaker-diarization-3.1"
    logging.info(f"Loading {checkpoint}")
    pipeline = Pipeline.from_pretrained(checkpoint, use_auth_token=auth_token)
    pipeline.to(torch.device("cuda"))

    while not queue.empty():
        todo = queue.get(block=False)
        if todo is None:
            break
        logging.info(f"[{current_process().pid} Processing {todo.infile}")
        with TemporaryDirectory() as tmpdir:
            wavfile = f"{tmpdir}/tmp.wav"
            logging.info(f"Converting {todo.infile} to {wavfile}")
            get_wav(todo.infile, wavfile)

            outfile = f"{tmpdir}/out.csv"
            diarization = pipeline(wavfile, hook=LogProgressHook(todo.infile.name))
            with open(outfile, "w") as outf:
                w = csv.writer(outf)
                w.writerow(["start", "stop", "speakernum"])
                for segment, _, speaker in diarization.itertracks(yield_label=True):
                    w.writerow([segment.start, segment.end, speaker])

            logging.info(f"Moving {outfile} to {todo.outfile}")
            shutil.move(outfile, todo.outfile)


VIDEO_SUFFIX = [".mp4", ".m4a"]


def get_todo(indir: Path, outdir: Path):
    for f in indir.glob("*"):
        if f.suffix in VIDEO_SUFFIX:
            outfile = outdir / f.with_suffix(".csv").name
            if not outfile.exists():
                yield Todo(f, outfile)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")
    parser = argparse.ArgumentParser()
    parser.add_argument("infolder", type=Path)
    parser.add_argument("outfolder", type=Path)
    parser.add_argument("--processes", type=int, default=8)

    args = parser.parse_args()

    q = Queue()
    for f in get_todo(args.infolder, args.outfolder):
        q.put(f)
    nworkers = min(args.processes, q.qsize())
    logging.info(f"[{current_process().pid}] {q.qsize()} files to do, spawning {nworkers} workers")
    pool = Pool(nworkers, worker, (q,))
    q.close()
    q.join_thread()
    pool.close()
    pool.join()
    logging.info("Done?")
