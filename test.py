from pathlib import Path
import shutil

from do_frames import get_won

ndel = 0
files = list(Path("data/in2").glob("*"))
for file in files:
    won = get_won(file)
    framedir = Path("data/frames") / won
    if framedir.exists():
        print(f"Deleting {file}")
        ndel += 1
        file.unlink()

print(f"Deleted {ndel} / {len(files)} files")
