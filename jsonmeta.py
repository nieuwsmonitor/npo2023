from datetime import datetime
import glob
import json
from pathlib import Path
import re


def scrape_files(file):
    article = {}
    with open(str(file)) as data_file:
        data = json.load(data_file)
        if "fullTitle" in data["info"]:
            article["name"] = data["info"]["fullTitle"]
        else:
            article["name"] = data["info"]["title"]
        date = data["info"]["broadcastDate"]
        article["date"] = datetime.strptime(date, "%d-%m-%Y").isoformat()
        if article["date"] < datetime.strptime("01-11-2023", "%d-%m-%Y").isoformat():
            return
        article["title"] = data["assets"][0]["title"]
        if "EENVANDAAG___-INC30008ZP8" in article["title"]:
            return
        if "EENVANDAAG___-INC3000VKAI" in article["title"]:
            return
        if not (m := re.search("-((WON|AT_|ITX|-INC|INC|BV_)[A-Z0-9]+)\\.mxf", article["title"])):
            raise Exception(f"Cannot parse {article['title']}")
        article["won"] = m.group(1)
        article["description"] = data["info"].get("description")
        return article


def get_meta(folder: Path):
    for f in folder.glob("**/*.json"):
        art = scrape_files(f)
        if art:
            yield art["won"], art

if __name__ == '__main__':
    import sys
    meta = get_meta(Path(sys.argv[1]))
    import csv
    w = csv.writer(sys.stdout)
    w.writerow(["won", "name", "date"])
    for won, art in meta:
        w.writerow([won, art["name"], art["date"]])
