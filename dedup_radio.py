import collections
from pathlib import Path
import re
import sys
from amcat4py import AmcatClient

files = """
ditisdedag20231101.m4a  eenvandaag20231122.m4a  nieuwsbv20231106.m4a       nieuwsweekend20231118.m4a  spraakmakers20231103.m4a  tribune20231111.m4a
ditisdedag20231102.m4a  humberto20231103.m4a    nieuwsbv20231107.m4a       oog20231101.m4a            spraakmakers20231106.m4a  tribune20231118.m4a
ditisdedag20231103.m4a  humberto20231110.m4a    nieuwsbv20231108.m4a       oog20231102.m4a            spraakmakers20231107.m4a  villa20231101.m4a
ditisdedag20231106.m4a  humberto20231117.m4a    nieuwsbv20231109.m4a       oog20231103.m4a            spraakmakers20231108.m4a  villa20231102.m4a
ditisdedag20231107.m4a  journaal20231102.m4a    nieuwsbv20231110.m4a       oog20231104.m4a            spraakmakers20231109.m4a  villa20231106.m4a
ditisdedag20231108.m4a  journaal20231103.m4a    nieuwsbv20231113.m4a       oog20231105.m4a            spraakmakers20231110.m4a  villa20231107.m4a
ditisdedag20231109.m4a  journaal20231104.m4a    nieuwsbv20231114.m4a       oog20231106.m4a            spraakmakers20231113.m4a  villa20231108.m4a
ditisdedag20231110.m4a  journaal20231106.m4a    nieuwsbv20231115.m4a       oog20231107.m4a            spraakmakers20231114.m4a  villa20231109.m4a
ditisdedag20231113.m4a  journaal20231107.m4a    nieuwsbv20231116.m4a       oog20231108.m4a            spraakmakers20231115.m4a  villa20231113.m4a
ditisdedag20231114.m4a  journaal20231108.m4a    nieuwsbv20231117.m4a       oog20231109.m4a            spraakmakers20231116.m4a  villa20231114.m4a
ditisdedag20231115.m4a  journaal20231109.m4a    nieuwsbv20231120.m4a       oog20231110.m4a            spraakmakers20231117.m4a  villa20231115.m4a
ditisdedag20231116.m4a  journaal20231111.m4a    nieuwsbv20231121.m4a       oog20231111.m4a            spraakmakers20231120.m4a  villa20231116.m4a
ditisdedag20231117.m4a  journaal20231113.m4a    nieuwsbv20231122.m4a       oog20231112.m4a            spraakmakers20231121.m4a  villa20231120.m4a
ditisdedag20231120.m4a  journaal20231114.m4a    nieuwsenco20231101.m4a     oog20231113.m4a            spraakmakers20231122.m4a  villa20231121.m4a
ditisdedag20231121.m4a  journaal20231117.m4a    nieuwsenco20231102.m4a     oog20231114.m4a            sven20231101.m4a          villa20231122.m4a
ditisdedag20231122.m4a  journaal20231118.m4a    nieuwsenco20231103.m4a     oog20231115.m4a            sven20231102.m4a          vroeg20231101.m4a
eenvandaag20231101.m4a  journaal20231120.m4a    nieuwsenco20231106.m4a     oog20231116.m4a            sven20231103.m4a          vroeg20231102.m4a
eenvandaag20231102.m4a  journaal20231121.m4a    nieuwsenco20231107.m4a     oog20231117.m4a            sven20231106.m4a          vroeg20231103.m4a
eenvandaag20231103.m4a  journaal20231122.m4a    nieuwsenco20231108.m4a     oog20231118.m4a            sven20231107.m4a          vroeg20231106.m4a
eenvandaag20231106.m4a  kantine20231104.m4a     nieuwsenco20231109.m4a     oog20231119.m4a            sven20231108.m4a          vroeg20231107.m4a
eenvandaag20231107.m4a  kantine20231111.m4a     nieuwsenco20231110.m4a     oog20231120.m4a            sven20231109.m4a          vroeg20231108.m4a
eenvandaag20231108.m4a  kantine20231118.m4a     nieuwsenco20231113.m4a     oog20231121.m4a            sven20231110.m4a          vroeg20231109.m4a
eenvandaag20231109.m4a  kelder20231104.m4a      nieuwsenco20231114.m4a     oog20231122.m4a            sven20231113.m4a          vroeg20231110.m4a
eenvandaag20231110.m4a  kelder20231111.m4a      nieuwsenco20231115.m4a     perstribune20231105.m4a    sven20231114.m4a          vroeg20231113.m4a
eenvandaag20231113.m4a  kelder20231118.m4a      nieuwsenco20231116.m4a     perstribune20231112.m4a    sven20231115.m4a          vroeg20231114.m4a
eenvandaag20231114.m4a  lobby20231106.m4a       nieuwsenco20231117.m4a     perstribune20231119.m4a    sven20231116.m4a          vroeg20231115.m4a
eenvandaag20231115.m4a  lobby20231113.m4a       nieuwsenco20231120.m4a     pointer20231104.m4a        sven20231117.m4a          vroeg20231116.m4a
eenvandaag20231116.m4a  lobby20231120.m4a       nieuwsenco20231121.m4a     pointer20231111.m4a        sven20231120.m4a          vroeg20231117.m4a
eenvandaag20231117.m4a  nieuwsbv20231101.m4a    nieuwsenco20231122.m4a     pointer20231118.m4a        sven20231121.m4a          vroeg20231120.m4a
eenvandaag20231120.m4a  nieuwsbv20231102.m4a    nieuwsweekend20231104.m4a  spraakmakers20231101.m4a   sven20231122.m4a          vroeg20231121.m4a
eenvandaag20231121.m4a  nieuwsbv20231103.m4a    nieuwsweekend20231111.m4a  spraakmakers20231102.m4a   tribune20231104.m4a       vroeg20231122.m4a
""".split()

shows = set()
for file in files:
    m = re.match(r"(\w+)(2023\d{4})\.m4a", file)
    shows.add((m.group(1), m.group(2)))

todo = shows.copy()

amcat = AmcatClient("https://amcat4.labs.vu.nl/amcat")
amcat.login()

done = set()

dedup = collections.defaultdict(set)

for i, doc in enumerate(amcat.query("tk2023_radio", fields=["publisher", "date", "speakernum", "start"])):
    datestr = doc['date'].strftime("%Y%m%d")
    key = (datestr, doc['publisher'], doc['speakernum'], doc['start'])
    dedup[key].add(doc['_id'])
    if not i % 1000:
        print(i)

keys = sorted(dedup.keys())

for key in keys:
    if len(dedup[key]) > 1:
        print(key, len(dedup[key]))
