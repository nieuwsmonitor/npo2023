import argparse
import csv
import logging
import os
import shutil
import time
from collections import namedtuple
from multiprocessing import Pool, Queue, current_process, pool
from pathlib import Path
from subprocess import check_output
from tempfile import TemporaryDirectory

import torch
import whisper


prompt = """Dit is een TV uitzending rond de Tweede Kamerverkiezingen. Lijsttrekkers in deze verkiezingen zijn
Dilan Yesilgöz voor VVD,
Rob Jetten voor D66,
Frans Timmermans voor  GroenLinks-PvdA,
Geert Wilders voor PVV,
Pieter Omtzigt voor NSC,
Caroline Van Der Plas voor BBB,
Henri Bontenbal voor CDA,
Lilian Marijnissen voor SP,
Stephan van Baarle voor DENK,
Esther Ouwehand voor PVDD,
Thierry Baudet voor FVD,
Chris Stoffer voor SGP,
Mirjam Bikker voor CU,
Laurens Dassen voor VOLT,
Joost Eerdmans voor JA21,
Gerard Van Hooft voor 50PLUS,
Edson Olf voor BIJ1
"""

WhisperJob = namedtuple("WhisperJob", ["videofile", "segmentfile", "outfile"])
Segment = namedtuple("Segment", ["start", "stop", "speakernum", "texts"])


def get_wav(infile, outfile):
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", infile, outfile]
    check_output(cmd)


def get_segments(segmentfile):
    current_segment = None
    for row in csv.DictReader(open(segmentfile)):
        if current_segment is None:
            current_segment = Segment(float(row["start"]), float(row["stop"]), row["speakernum"], [])
            continue
        if current_segment.speakernum == row["speakernum"]:
            current_segment = Segment(current_segment.start, float(row["stop"]), row["speakernum"], [])
        else:
            yield current_segment
            current_segment = Segment(float(row["start"]), float(row["stop"]), row["speakernum"], [])
    if current_segment:
        yield current_segment


def get_text(segment: Segment, texts):
    for t in texts:
        if t["end"] < segment.start:
            continue
        if t["start"] > segment.stop:
            break
        duration = t["end"] - t["start"]
        overlap = min(t["end"], segment.stop) - max(t["start"], segment.start)
        if overlap / duration > 0.5:
            yield t["text"]


def guess_segment(start, end, segments):
    def duration(segment):
        return segment.stop - segment.start

    max_d = 0
    best_segment = None
    for segment in segments:
        if segment.start > end:
            break
        if segment.stop < start:
            continue
        d = min(segment.stop, end) - max(segment.start, start)
        if d > max_d or (d > 0 and d == max_d and duration(segment) < duration(best_segment)):
            max_d = d
            best_segment = segment
    return best_segment


def do_whisper(whisper: whisper.Whisper, job: WhisperJob):
    logging.info(f"[{current_process().pid} Processing {job.videofile} + {job.segmentfile}")
    with TemporaryDirectory() as tmpdir:

        logging.info(f"Reading segments from {job.segmentfile}")
        segments = list(get_segments(job.segmentfile))

        wavfile = f"{tmpdir}/tmp.wav"
        logging.info(f"Converting {job.videofile} to {wavfile}")
        get_wav(job.videofile, wavfile)
        logging.info("Whispering...")
        for text in whisper.transcribe(wavfile, language="nl", initial_prompt=prompt)["segments"]:
            segment = guess_segment(text["start"], text["end"], segments)
            if segment:
                # print(text["text"], "->", segment.start, segment.stop)
                segment.texts.append(text)
            else:
                logging.warning(f">>> no segment for {text['start']} - {text['end']}: {text['text']}")
        outfile = f"{tmpdir}/out.csv"
        with open(outfile, "w") as outf:
            w = csv.writer(outf)
            w.writerow(["start", "stop", "speakernum", "text"])
            for segment in segments:
                text = "\n\n".join(t["text"] for t in segment.texts)
                if text.strip():
                    w.writerow([segment.start, segment.stop, segment.speakernum, text])

            logging.info(f"Moving {outfile} to {job.outfile}")
            shutil.move(outfile, job.outfile)

        for segment in segments:
            for text in segment.texts:
                print(segment.start, segment.stop, segment.speakernum, text["start"], text["end"], text["text"])


def worker(queue: "Queue[WhisperJob]", whisper_model="large-v2"):
    logging.info(f"Loading whisper model {whisper_model}")
    whispermodel = whisper.load_model(whisper_model)

    while not queue.empty():
        job = queue.get(block=False)
        if job is None:
            break
        logging.info(f"[{current_process().pid} Processing {job.videofile} + {job.segmentfile}")
        do_whisper(whispermodel, job)


def get_todo(videofolder: Path, segmentfolder: Path, outfolder: Path):
    for f in videofolder.glob("*.mp4"):
        outfile = outfolder / f.with_suffix(".csv").name
        if not outfile.exists():
            segmentfile = segmentfolder / f.with_suffix(".csv").name
            if segmentfile.exists():
                yield WhisperJob(f, segmentfile, outfile)
            else:
                logging.warning(f"No segmentfile for {f}")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")
    # import sys
    # whisper = whisper.load_model("large-v2")
    # do_whisper(whisper, WhisperJob(sys.argv[1], sys.argv[2], "/tmp/bla.csv"))
    # sys.exit()

    parser = argparse.ArgumentParser()
    parser.add_argument("videofolder", type=Path)
    parser.add_argument("segmentfolder", type=Path)
    parser.add_argument("outfolder", type=Path)
    parser.add_argument("--processes", type=int, default=1)
    parser.add_argument("--whispermodel", default="large-v2")

    args = parser.parse_args()

    q = Queue()
    for f in get_todo(args.videofolder, args.segmentfolder, args.outfolder):
        q.put(f)
    nworkers = min(args.processes, q.qsize())
    logging.info(f"[{current_process().pid}] {q.qsize()} files to do, spawning {nworkers} workers")
    pool = Pool(nworkers, worker, (q, args.whispermodel))
    q.close()
    q.join_thread()
    pool.close()
    pool.join()
    logging.info("Done?")
