import shutil
import progressbar
from pathlib import Path
import re
from tempfile import NamedTemporaryFile
from urllib.request import urlretrieve
import links_eenvandaag
import links_goedemorgen
import links_opeen
import links_wnl
import links_buitenhof
import links_nieuwsuur
import links_nosjournaal
import links_ks
import links_nos

from lxml import etree

files = dict(
    # eenvandaag=links_eenvandaag.eenvandaag,
    # goedemorgen=links_goedemorgen.goedemorgen,
    # opeen=links_opeen.opeen,
    # buitenhof=links_buitenhof.buitenhof,
    # wnl=links_wnl.wnl,
    # nieuwsuur=links_nieuwsuur.nieuwsuur,
    nosjournaal=links_nosjournaal.nosjournaal,
    # ks=links_ks.ks,
    # nos=links_nos.nos,
)

parser = etree.HTMLParser()


# https://stackoverflow.com/a/53643011
class MyProgressBar:
    def __init__(self):
        self.pbar = None

    def __call__(self, block_num, block_size, total_size):
        if not self.pbar:
            self.pbar = progressbar.ProgressBar(maxval=total_size)
            self.pbar.start()
        downloaded = block_num * block_size
        if downloaded < total_size:
            self.pbar.update(downloaded)
        else:
            self.pbar.finish()


for folder, htmlstrings in files.items():
    outfolder = Path.cwd() / "data" / "in_extra2"
    existing = {f.name for f in outfolder.glob("*.mp4")}
    todo, done = set(), set()
    for htmlstring in htmlstrings:
        root = etree.fromstring(htmlstring, parser)
        for a in root.cssselect("a"):
            href = a.get("href")
            fn = href.split("/")[-1]
            if fn in existing:
                done.add(href)
            else:
                todo.add(href)

    print(
        f"{folder}: {len(done)+len(todo)} total, {len(existing)} files on disk; {len(done)} downloaded, {len(todo)} to go"
    )
    for i, href in enumerate(todo):
        fn = href.split("/")[-1]
        with NamedTemporaryFile(suffix=".mp4", delete=False) as tmpf:
            print(f"[{i+1}/{len(todo)}] {fn} Downloading to {tmpf.name}")
            print(href)
            urlretrieve(href, tmpf.name, MyProgressBar())
            outf = outfolder / fn
            print(f"[{i+1}/{len(todo)}] {fn} moving {tmpf.name} to {outf}")
            shutil.move(tmpf.name, outf)
