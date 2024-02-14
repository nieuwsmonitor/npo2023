from pathlib import Path
from deepface import DeepFace

infolder = Path("data/facedb")
outfolder = Path("data/facedb2")
from PIL import Image, ImageDraw, ImageFont


def save_face(file, face, outfile, dist=None):
    im = Image.open(file)
    d = ImageDraw.Draw(im)
    a = face["facial_area"]
    area = a["x"], a["y"], a["x"] + a["w"], a["y"] + a["h"]
    d.rectangle(area, outline="green", width=4)
    font = ImageFont.truetype("Gidole-Regular.ttf", 32)
    d.text((a["x"] + 2, a["y"] + a["h"] - 70), f"conf: {face['confidence']:.2f}", fill="green", font=font)
    d.text((a["x"] + 2, a["y"] + a["h"] - 35), f"size: {min(a['w'], a['h'])}", fill="green", font=font)
    if dist:
        d.text((a["x"] + 2, a["y"] + a["h"] - 105), f"dist: {dist:.2f}", fill="green", font=font)
    im.save(outfile)


def crop_face(file, face, outfile, margin=20):
    im = Image.open(file)
    a = face["facial_area"]
    w, h = im.size
    box = (
        max(0, a["x"] - margin),
        max(0, a["y"] - margin),
        min(w, a["x"] + a["w"] + 2 * margin),
        min(h, a["y"] + a["h"] + 2 * margin),
    )
    cropped = im.crop(box)
    cropped.save(outfile)


for file in infolder.glob("*.png"):
    faces = DeepFace.extract_faces(file, enforce_detection=False, detector_backend="retinaface")
    for f in faces:
        f["area"] = f["facial_area"]["w"] * f["facial_area"]["h"]
    faces = [f for f in faces if f["confidence"] > 0]
    faces = sorted(faces, key=lambda f: f["area"], reverse=True)
    face = faces[0]
    outfile = outfolder / file.name
    print(file, len(faces), outfile)
    crop_face(file, face, outfile)
