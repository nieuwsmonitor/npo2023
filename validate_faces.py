import csv
import logging
from pathlib import Path
import collections
import re
import shutil
import sys
from tempfile import TemporaryDirectory

os.environ["DEEPFACE_LOG_LEVEL"] = "30"
db_path = "data/facedb"

logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")


def find_match(file, db_path, detector_backend="retinaface"):
    from deepface import DeepFace

    # Go through extract_faces first to avoid false positives with confidence zero == find doesn't return this info :(
    for face in DeepFace.extract_faces(file, enforce_detection=False, detector_backend=detector_backend):
        if face["confidence"] == 0 or face["facial_area"]["w"] <= 200:
            continue
        hits = DeepFace.find(face["face"], db_path, detector_backend=detector_backend, enforce_detection=False)[0]
        if hits.empty:
            continue
        found = Path(hits.identity[0])
        dist = hits.distance[0]
        yield found, dist


files_per_won = collections.defaultdict(list)
for file in Path(db_path).glob("*.png"):
    if not (m := re.search(r"\w+__(WON\w+)__\d+.png", file.name)):
        raise Exception(f"Cannot parse {file.name}")
    files_per_won[m.group(1)].append(file)


logging.info("Writing output to validatie_faces.csv")
w = csv.writer(open("validatie_faces.csv", "w"))
w.writerow(["test_won", "test_file", "actual", "found", "dist", "reference_file"])
for i, (won, testfiles) in enumerate(files_per_won.items()):
    with TemporaryDirectory() as d:
        logging.info(f"[{i}/{len(files_per_won)}] Testing {won}, creating temporary face db in {d}")
        for won2, trainfiles in files_per_won.items():
            if won2 != won:
                for trainfile in trainfiles:
                    outfile = Path(d) / trainfile.name
                    shutil.copy(trainfile, outfile)
        for file in testfiles:
            matches = list(find_match(file, d))
            if len(matches) > 1:
                logging.warning("Oops, multiple matches??")
            if len(matches) == 0:
                found, dist = None, None
            else:
                found, dist = matches[0]

            actual = file.name.split("__")[0]
            found_name = found and found.name.split("__")[0]

            w.writerow([won, file.name, actual, found_name, dist, found and found.name])
