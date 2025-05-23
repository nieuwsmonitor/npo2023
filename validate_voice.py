import pandas as pd
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


def get_articles(src_api, src_index, wons):
    articles = src_api.query(
        src_index,
        fields=(
            "_id",
            "date",
            "publisher",
            "date",
            "text",
            "spreker",
            "start",
            "end",
            "won",
            "embedding",
            "speakernum",
        ),
        filters={"won": wons},
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


def guess_speaker(docs, reference_matrix, names, threshold=0.7):
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
    ref_docs = [d for d in docs if d["won"] != target]
    target_docs = [d for d in docs if d["won"] == target]
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
    parser.add_argument("--won", type=str, help="Scrape single won")

    args = parser.parse_args()
    logging.info(f"Connecting to AmCAT {args.source_url}")
    amcat = AmcatClient(args.source_url)
    amcat.login()
    sheet_id = "10qSZponLZ06Rv5KOq83pn7vUpV4Fh5LdVlxhF9t6rgE"
    url = f"https://docs.google.com/spreadsheets/d/{sheet_id}/gviz/tq?tqx=out:csv&sheet=Sprekers"
    d = pd.read_csv(url)
    wons = set(d.won)
    logging.info(f"Retrieving {len(wons)} articles from AmCAT")
    docs = get_articles(amcat, args.source_index, wons)
    w = csv.writer(sys.stdout)
    w.writerow(
        [
            "won",
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

    for won in wons:
        logging.info(f"Validating {won}")
        turns = sorted(validate(docs, target=won), key=lambda doc: doc["start"])
        for doc in turns:
            w.writerow(
                [
                    doc["won"],
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
