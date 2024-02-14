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


def parse_article(art):
    article = {}
    article["_id"] = art["_id"]
    article["date"] = art["date"]
    article["text"] = art["text"]
    article["publisher"] = art["publisher"]
    article["embedding"] = art["embedding"]
    article["won"] = art["won"]
    try:
        article["spreker"] = art["spreker"]
    except KeyError:
        return article
    return article


def get_articles(src_api, src_index, publisher=None, won=None):
    filters = {}
    if publisher:
        filters["publisher"] = publisher
    if won:
        filters["won"] = won
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
        filters=filters,
    )
    return list(articles)
    articles2 = []
    for art in articles:
        # art2 = parse_article(art)
        articles2.append(art)
    return articles2


def get_reference_embeds(arts):
    embeds = collections.defaultdict(list)  # {spreker : [embedding1, embedding2, ...]}
    for art in arts:
        try:
            spreker = art["spreker"]
        except KeyError:
            continue
        embeds[spreker].append(art["embedding"])
    return embeds


def get_target_embeds(arts):
    embeds = collections.defaultdict(list)  # {(won, speakernum) : [embedding1, embedding2, ...]}
    for art in arts:
        won = art["won"]
        try:
            speakernum = art["speakernum"]
        except KeyError:
            continue
        if "spreker" in art:
            continue
        embeds[won, speakernum].append(art["embedding"])
    return embeds


if __name__ == "__main__":
    parser = argparse.ArgumentParser(epilog=__doc__)
    parser.add_argument("source_url", help='URL of the source (e.g. "http://localhost/amcat")')
    parser.add_argument("source_index", help="index in the source")
    parser.add_argument("--won", type=str, help="Scrape single won")

    args = parser.parse_args()

    fmt = "[%(asctime)s %(levelname)s %(name)s] %(message)s"
    logging.basicConfig(format=fmt, level=logging.INFO)
    logging.getLogger("requests").setLevel(logging.WARNING)
    src = AmcatClient(args.source_url)
    src.login()

    index_name = args.source_index

    arts = get_articles(src, index_name, won=args.won)
    reference_embeddings = get_reference_embeds(arts)
    target_embeddings = get_target_embeds(arts)
    ref_embeds = {}
    for s, embs in reference_embeddings.items():
        average_emb = np.average(embs, axis=0)
        average_emb = average_emb / np.linalg.norm(average_emb)
        ref_embeds[s] = average_emb
    target_embeds = {}
    for (s, won), embs in target_embeddings.items():
        target_emb = np.average(embs, axis=0)
        target_emb = target_emb / np.linalg.norm(target_emb)
        target_embeds[s, won] = target_emb

    orderedNames = list(ref_embeds.keys())
    ref_matrix = np.array([ref_embeds[i] for i in orderedNames])

tree = cKDTree(ref_matrix)
out = csv.writer(sys.stdout)
out.writerow(["won", "spreker", "dist", "naam"])

for (s, won), embedding in target_embeds.items():
    dist, i = tree.query(embedding, k=1)
    closest_speaker = orderedNames[i]
    out.writerow([won, s, dist, closest_speaker])
