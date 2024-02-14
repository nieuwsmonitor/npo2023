from PIL import Image
import argparse
from collections import namedtuple
import logging
from pathlib import Path
import re
import shutil
from subprocess import check_output
from tempfile import TemporaryDirectory
from typing import NamedTuple


class Job(NamedTuple):
    won: str
    videofile: Path
    framefolder: Path


def create_frames(job: Job, rate="1/1"):
    with TemporaryDirectory() as tmpdir:
        logging.info(f"[{job.won}] Creating frames in {tmpdir}")
        outfile = f"{tmpdir}/{job.won}__%d.png"
        cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", job.videofile, "-r", rate, outfile]
        check_output(cmd)
        shutil.move(tmpdir, job.framefolder)
        logging.info(f"[{job.won}] Frames complete in {job.framefolder}")


def process(job: Job):
    if not job.framefolder.exists():
        create_frames(job)


def get_won(f: Path):
    if not (m := re.search("-((WON|INC|BV_|INC)[A-Z0-9]+)\\_", f.name)):
        raise Exception(f"Cannot parse {f}")
    return m.group(1)


def get_todo(infolder: Path, outfolder: Path):
    for f in infolder.glob("*.mp4"):
        won = get_won(f)
        framesdir = outfolder / won
        if not framesdir.exists():
            yield Job(won, f, framesdir)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")

    parser = argparse.ArgumentParser()
    parser.add_argument("infolder", type=Path)
    parser.add_argument("outfolder", type=Path)
    args = parser.parse_args()
    args.outfolder.mkdir(parents=True, exist_ok=True)

    jobs = list(get_todo(args.infolder, args.outfolder))
    print(f"{len(jobs)} to do")
    for i, job in enumerate(jobs):
        logging.info(f"{i} / {len(jobs)} {job.won} -> {job.framefolder}")
        create_frames(job)
