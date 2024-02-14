import argparse
import csv
import logging
from multiprocessing import Pool, Queue
from pathlib import Path
import shutil
from tempfile import NamedTemporaryFile, TemporaryDirectory
from typing import NamedTuple
import os
from deepface import DeepFace
from imagelib import save_face, select_face

os.environ["DEEPFACE_LOG_LEVEL"] = "30"


class Job(NamedTuple):
    dbfolder: Path
    framefolder: Path
    outfile: Path


def process(job: Job):
    with NamedTemporaryFile(delete=False, suffix=".csv", mode="w+") as tmpf:
        w = csv.writer(tmpf)
        won = job.framefolder.name
        logging.info(f"[{won}] Processing to {tmpf.name}")
        w.writerow(["won", "frame", "person", "file", "x", "y" "w", "h"])
        frames = list(job.framefolder.glob("*.png"))
        for i, file in enumerate(frames):
            if not i % 100:
                logging.info(f"[{won}] frame {i}/{len(frames)}: {file}")
            frame = int(file.with_suffix("").name.split("__")[-1])
            person, dist, area = find_match(file, job.dbfolder)#, save_folder=Path("data/matches"))
            if person:
                w.writerow([won, frame, person, file, area["x"], area["y"], area["w"], area["h"]])
        logging.info(f"[{won}] Moving {tmpf.name} to {job.outfile}")
        tmpf.close()
        shutil.move(tmpf.name, job.outfile)


def get_todo(dbfolder: Path, framefolder: Path, outfolder: Path):
    for framefolder in framefolder.glob("*"):
        won = framefolder.name
        outfile = outfolder / f"{won}__faces.csv"
        if not outfile.exists():
            yield Job(dbfolder, framefolder, outfile)


def find_match(file, db_path, detector_backend="retinaface", save_folder=None):
    face = select_face(file)
    if not face:
        return None, None, None
    hits = DeepFace.find(
        face["face"], db_path, detector_backend=detector_backend, enforce_detection=False, silent=True
    )[0]
    if hits.empty:
        return None, None, None
    found = Path(hits.identity[0])
    person = found.name.split("__")[0]
    dist = hits.distance[0]
    if person == "others" or dist >= 0.45:
        return None, None, None
    if save_folder:
        outfile = save_folder / f"{person}__{file.name}"
        logging.info(f"Saving match at {outfile} -- (matched: {found})")
        save_face(file, face, outfile, dist=f"{dist:.2f}", concat=found, annotate="bottom")

    return found, dist, face["facial_area"]


def worker(queue: "Queue[Job]"):
    while not queue.empty():
        job = queue.get(block=False)
        if job is None:
            break
        logging.info(f"Processing {job.framefolder}")
        process(job)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(process)d %(asctime)s %(name)-12s %(levelname)-5s] %(message)s")

    parser = argparse.ArgumentParser()
    parser.add_argument("dbfolder", type=Path)
    parser.add_argument("framefolder", type=Path)
    parser.add_argument("outfolder", type=Path)
    parser.add_argument("--processes", type=int, default=8)
    args = parser.parse_args()
    args.outfolder.mkdir(parents=True, exist_ok=True)

    jobs = list(get_todo(args.dbfolder, args.framefolder, args.outfolder))

    q = Queue()
    for f in get_todo(args.dbfolder, args.framefolder, args.outfolder):
        q.put(f)
    nworkers = min(args.processes, q.qsize())
    logging.info(f"{q.qsize()} files to do, spawning {nworkers} workers")
    pool = Pool(nworkers, worker, (q,))
    q.close()
    q.join_thread()
    pool.close()
    pool.join()
    logging.info("Done?")
