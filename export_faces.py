import argparse
import collections
import logging
from pathlib import Path
import shutil
from deepface import DeepFace
from PIL import Image, ImageDraw, ImageFont
import re

import numpy as np
from sklearn.cluster import AgglomerativeClustering
from scipy import spatial

logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")

parser = argparse.ArgumentParser()
parser.add_argument("infolder", type=Path)
parser.add_argument("outfolder", type=Path)
args = parser.parse_args()

won = "WON02443802"
won = "WON02439236"
won = "WON02441449"
won = "WON02441460"

wons = ["WON02441460", "WON02439060", "WON02443799", "WON02441946"]

wons = "WON02438760 WON02439264 WON02440077 WON02440721 WON02440975".split()
wons = ["WON02439070"]
wons = "WON02440081 WON02438760 WON02442245 WON02440075".split()

missing = [won for won in wons if not (args.infolder / won).exists()]
if missing:
    raise Exception(f"Missing frames for {missing}")


def find_examplar(m, labels):
    vectors = collections.defaultdict(list)
    indices = collections.defaultdict(list)
    for i, label in enumerate(labels):
        vectors[label].append(m[i])
        indices[label].append(i)
    for cluster, vectors in vectors.items():
        mean_vector = np.average(vectors, axis=0)
        best = np.argmin([spatial.distance.cosine(mean_vector, v) for v in vectors])
        index = indices[cluster][best]
        yield cluster, index


def save_face(file, face, outfile):
    im = Image.open(file)
    d = ImageDraw.Draw(im)
    a = face["facial_area"]
    area = a["x"], a["y"], a["x"] + a["w"], a["y"] + a["h"]
    d.rectangle(area, outline="green", width=4)
    font = ImageFont.truetype("Gidole-Regular.ttf", 32)
    d.text((a["x"] + 2, a["y"] + a["h"] - 70), f"conf: {face['face_confidence']:.2f}", fill="green", font=font)
    d.text((a["x"] + 2, a["y"] + a["h"] - 35), f"size: {min(a['w'], a['h'])}", fill="green", font=font)
    im.save(outfile)


for i, won in enumerate(wons):
    faces = {}
    files = list((args.infolder / won).glob("*.png"))
    for j, file in enumerate(files):
        if not j % 100:
            logging.info(f"[{won} {i}/{len(wons)}] [{j}/{len(files)}] {file.name}")
        frame = int(re.search("__(\\d+).png$", file.name).group(1))
        found_faces = [
            f
            for f in DeepFace.represent(file, enforce_detection=False, detector_backend="retinaface")
            if f["face_confidence"] > 0 and f["facial_area"]["w"] > 200
        ]
        if len(found_faces) != 1:
            continue
        face = found_faces[0]
        face["file"] = file
        face["frame"] = frame
        faces[frame] = face

    m = np.array([f["embedding"] for f in faces.values()])

    logging.info("{won} Clustering with threshold 2")
    clustering = AgglomerativeClustering(n_clusters=None, distance_threshold=2).fit(m)

    logging.info(f"{won} Found {len(set(clustering.labels_))} clusters")
    keys = list(faces.keys())
    outdir = args.outfolder / won
    logging.info(f"{won} Writing examplars to {outdir}")
    outdir.mkdir(parents=True, exist_ok=True)

    for cluster, i in find_examplar(m, clustering.labels_):
        key = keys[i]
        face = faces[key]
        outfile = outdir / f"{won}__{cluster}__{face['frame']}.png"
        shutil.copy(face["file"], outfile)


# for i, (key, label) in enumerate(zip(keys, clustering.labels_)):
#    face = faces[key]
#    outfile = outdir / f"{label}_{face['frame']}_{face['i']}.png"
#    if not i % 10:
##        logging.info(f"[{i}/{len(keys)}] {outfile}")
#    save_face(face["file"], face, outfile)
