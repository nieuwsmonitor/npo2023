import csv
import argparse
import collections
import csv
import logging
import sys
import time
from amcat4py import AmcatClient
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
from numpy.linalg import norm
from scipy.spatial import distance
from scipy.spatial.distance import cdist
from scipy.spatial import cKDTree
from sklearn.neighbors import KDTree
from torch import embedding

def get_articles(src_api, src_index, titles):
    articles = src_api.query(
        src_index,
        fields=(
            "_id",
            "title",
            "date",
            "publisher",
            "embedding",
            "speakernum",
            "start",
            "end",
            "text"
        ),
        filters={"title": titles},
    )
    return list(articles)


def get_reference_matrix(docs):
    embeds = collections.defaultdict(list)  # {spreker : [embedding1, embedding2, ...]}
    for doc in docs:
        if "spreker" in doc:
            embeds[doc["spreker"]].append(doc["embedding"])
    ref_embeds = {}
    for s, embs in embeds.items():
        average_emb = np.average(embs, axis=0)
        average_emb = average_emb / np.linalg.norm(average_emb)
        ref_embeds[s] = average_emb
    orderedNames = list(ref_embeds.keys())
    ref_matrix = np.array([ref_embeds[i] for i in orderedNames])
    return orderedNames, ref_matrix


def guess_speaker(docs, reference_matrix, names, threshold=0.8):
    tree = cKDTree(reference_matrix)
    votes = collections.Counter()
    for doc in docs:
        emb = doc["embedding"] / np.linalg.norm(doc["embedding"])
        dist, i = tree.query(emb, k=1)
        closest = i if dist <= threshold else None
        votes[closest] += 1
        doc["closest_speaker"] = names[i]
        doc["closest_dist"] = dist
    spreker, nvotes = votes.most_common(1)[0]
    conf = nvotes / votes.total()
    return spreker, conf


def validate(docs, target):
    ref_docs = [d for d in docs if d["title"] != target]
    target_docs = [d for d in docs if d["title"] == target]
    logging.info("Creating reference matrix")
    names, m = get_reference_matrix(ref_docs)

    turns_per_spreker = collections.defaultdict(list)
    for doc in target_docs:
        turns_per_spreker[doc["speakernum"]].append(doc)

    for turns in turns_per_spreker.values():
        i, conf = guess_speaker(turns, m, names)
        for turn in turns:
            turn["majority_speaker"] = names[i] if i is not None else None
            turn["majority_perc"] = conf
    return target_docs


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")

    parser = argparse.ArgumentParser(epilog=__doc__)
    parser.add_argument("source_url", help='URL of the source (e.g. "http://localhost/amcat")')
    parser.add_argument("source_index", help="index in the source")

    args = parser.parse_args()

    inf = csv.DictReader(open("results/radio_speakers.csv"))

    speakers = {(r["pub"].replace("-", ""), r["speakernum"]) : r["speaker"] for r in inf}
    titles = set(title for (title, _speakernum) in speakers)

    logging.info(f"Connecting to AmCAT {args.source_url}")
    amcat = AmcatClient(args.source_url)
    amcat.login()

    logging.info(f"Retrieving {len(titles)} articles from AmCAT")
    docs = get_articles(amcat, args.source_index, titles)
    titles2 = set(doc['title'] for doc in docs)
    if titles2 - titles:
        raise Exception(f"Title problem: {titles2-titles}")

    docs2 = []
    for doc in docs:
        doc['spreker'] = speakers.get((doc['title'], doc['speakernum']))
        if doc['spreker']:
            docs2.append(doc)

    w = csv.writer(sys.stdout)
    w.writerow(
        [
            "title",
            "speakernum",
            "start",
            "end",
            "spreker",
            "majority_speaker",
            "majority_perc",
            "closest_speaker",
            "closest_dist",
            "text",
        ]
    )

    for title in titles:
        logging.info(f"Validating {title}")
        turns = sorted(validate(docs2, target=title), key=lambda doc: doc["start"])
        for doc in turns:
            w.writerow(
                [
                    doc["title"],
                    doc["speakernum"],
                    doc["start"],
                    doc["end"],
                    doc.get("spreker"),
                    doc["majority_speaker"],
                    doc["majority_perc"],
                    doc["closest_speaker"],
                    doc["closest_dist"],
                    doc["text"],
                ]
            )
