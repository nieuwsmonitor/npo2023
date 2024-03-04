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


def get_articles(src_api, src_index, titles):
    filters = {"title": titles} if titles else None
    articles = src_api.query(
        src_index,
        fields=(
            "_id",
            "date",
            "publisher",
            "date",
            "text",
            "start",
            "end",
            "title",
            "embedding",
            "speakernum",
        ),
        filters=filters,
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
        try:
            emb = doc["embedding"] / np.linalg.norm(doc["embedding"])
        except KeyError:
            continue
        dist, i = tree.query(emb, k=1)
        closest = i if dist <= threshold else None
        votes[closest] += 1
        doc["closest_speaker"] = names[i]
        doc["closest_dist"] = dist
    if not votes.total():
        logging.warning(f"No embeddings for {doc.get('title')}:{doc.get('speakernum')}")
        return None, 0
    spreker, nvotes = votes.most_common(1)[0]
    conf = nvotes / votes.total()
    logging.info(votes)
    return spreker, conf


def get_reference_matrix_from_amcat(amcat, index):
    inf = csv.DictReader(open("results/radio_speakers.csv"))
    speakers = {(r["pub"].replace("-", ""), r["speakernum"]) : r["speaker"] for r in inf}
    titles = set(title for (title, _speakernum) in speakers)

    logging.info(f"Connecting to AmCAT {args.source_url}")
    amcat = AmcatClient(args.source_url)
    amcat.login()

    logging.info(f"Retrieving {len(titles)} articles from AmCAT")
    docs = get_articles(amcat, index, titles)
    titles2 = set(doc['title'] for doc in docs)
    if titles2 - titles:
        raise Exception(f"Title problem: {titles2-titles}")

    docs2 = []
    for doc in docs:
        doc['spreker'] = speakers.get((doc['title'], doc['speakernum']))
        if doc['spreker']:
            docs2.append(doc)


    names, m = get_reference_matrix(docs2)
    return names, m


def predict(docs, names, m):
    i, conf = guess_speaker(docs, m, names)
    for turn in docs:
        turn["majority_speaker"] = names[i] if i is not None else None
        turn["majority_perc"] = conf
    return i, conf


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s %(name)-12s %(levelname)-5s] %(message)s")

    parser = argparse.ArgumentParser(epilog=__doc__)
    parser.add_argument("source_url", help='URL of the source (e.g. "http://localhost/amcat")')
    parser.add_argument("index", help="index in the source")
    parser.add_argument("--won", type=str, help="Scrape single won")

    args = parser.parse_args()
    logging.info(f"Connecting to AmCAT {args.source_url}")
    amcat = AmcatClient(args.source_url)
    amcat.login()

    names, m = get_reference_matrix_from_amcat(amcat, args.index)
    turns = collections.defaultdict(list)
    for d in get_articles(amcat, args.index, wons=[args.won] if args.won else None):
        won = d["title"]
        speakernum = d["speakernum"]
        turns[won, speakernum].append(d)
    logging.info(f"Predicting {len(turns)} turns")

    w = csv.writer(sys.stdout)
    w.writerow(
        [
            "won",
            "speakernum",
            "start",
            "end",
            "majority_speaker",
            "majority_perc",
            "closest_speaker",
            "closest_dist",
            "text",
        ]
    )

    for (won, speakernum), docs in turns.items():
        logging.info(f"... predicting {won}:{speakernum}")

        i, conf = predict(docs, names, m)
        speaker = names[i] if i is not None else None
        for doc in docs:
            w.writerow(
                [
                    won,
                    doc["speakernum"],
                    doc["start"],
                    doc["end"],
                    speaker,
                    conf,
                    doc.get("closest_speaker"),
                    doc.get("closest_dist"),
                    doc["text"],
                ]
            )
