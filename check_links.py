from pathlib import Path
import re
from sys import warnoptions
import csv
from lxml import etree
import os
import json
import glob
from datetime import datetime


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
        return article


arts = {}
programmas = ["EenVandaag", "op1", "goedemorgen", "Buitenhof", "Nieuwsuur", "WNL", "nosjournaal"]
for p in programmas:
    for f in glob.glob(f"/home/nel/Dropbox/npo/data2/*/*.json"):
        art = scrape_files(f)
        try:
            arts[art["won"]] = art
        except TypeError:
            pass

out = csv.writer(open("overzicht_missing.csv", "w"))
out.writerow(["naam", "datum"])

for f in glob.glob("/home/nel/npo2023/data/*/*.mp4"):
    if not (m := re.search("-((WON|INC|BV_|INC)[A-Z0-9]+)\\_", f)):
        raise Exception(f"Cannot parse {f}")
    won = m.group(1)
    if won not in arts:
        print(f, won)
    # if won in arts:
    #   naam = arts[won]["name"]
    #  date = arts[won]["date"]
    # out.writerow([naam, date])
