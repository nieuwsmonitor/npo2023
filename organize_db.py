from pathlib import Path
import re
import shutil


for file in Path("data/facedb_input").glob("*/*.png"):
    if not (m := re.match(r"(WON\w+)__\d+__(\d+).png", file.name)):
        raise Exception(f"Cannot parse {file.name}")
    won = m.group(1)
    frame = m.group(2)
    name = file.parent.name
    outfile = Path("data/facedb") / f"{name}__{won}__{frame}.png"
    infile = Path("data/frames") / won / f"{won}__{frame}.png"
    print(file, "->", outfile)
    shutil.move(infile, outfile)
