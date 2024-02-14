from pathlib import Path
from urllib.request import urlretrieve
from retinaface import RetinaFace as rf
from PIL import Image, ImageDraw, ImageFont
from deepface import DeepFace


def detect_faces(file):
    rfaces = rf.detect_faces(str(file), model=rf.build_model(), threshold=0.9)
    rfaces = {(f["facial_area"][0], f["facial_area"][1]): f for f in rfaces.values()}
    w = Image.open(file).size[0]
    try:
        DeepFace.extract_faces(file, detector_backend="retinaface")
    except ValueError:
        # No faces detected
        return
    for face in DeepFace.extract_faces(file, detector_backend="retinaface", enforce_detection=False):
        rface = rfaces[face["facial_area"]["x"], face["facial_area"]["y"]]
        face["landmarks"] = rface["landmarks"]
        leftx = face["landmarks"]["left_eye"][0]
        rightx = face["landmarks"]["right_eye"][0]
        face["frontness"] = abs(leftx - rightx) / face["facial_area"]["w"]
        face["center"] = (face["facial_area"]["x"] + face["facial_area"]["w"] / 2) / w
        face["area"] = min(face["facial_area"]["w"], face["facial_area"]["h"])
        yield face


def select_face(file):
    faces = [
        f
        for f in detect_faces(file)
        if f["confidence"] > 0 and f["center"] > 0.2 and f["center"] < 0.8 and f["frontness"] > 0.2 and f["area"] > 200
    ]
    if not faces:
        return None
    return sorted(faces, key=lambda f: f["area"], reverse=True)[0]


def save_face(file, face, outfile, concat=None, **extra):
    im = Image.open(file)
    d = ImageDraw.Draw(im)
    annotate_face(d, face, im, **extra)
    if concat:
        im1 = im
        im2 = Image.open(concat)
        im = Image.new("RGB", (im1.width + im2.width, max(im1.height, im2.height)))
        im.paste(im1, (0, 0))
        im.paste(im2, (im1.width, 0))
    im.save(outfile)


def annotate_face(d, face, im, color="green", annotate="face", **extra):
    a = face["facial_area"]

    fontfile = "Gidole-Regular.ttf"
    if not Path(fontfile).exists():
        url = "https://github.com/larsenwork/Gidole/raw/master/Resources/GidoleFont/Gidole-Regular.ttf"
        urlretrieve(url, fontfile)
    font = ImageFont.truetype(fontfile, 32)
    x, y, w, h = a["x"], a["y"], a["w"], a["h"]
    d.rectangle((x, y, x + w, y + h), outline=color, width=4)
    for landmark, xy in face.get("landmarks", {}).items():
        d.text((xy[0] - 16, xy[1] - 16), landmark[0].upper(), fill="red", font=font)
    i = 0
    if annotate == "face":
        ax = x + 2
        ay = y + h
    elif annotate == "bottom":
        ax = 10
        ay = im.height
    for key in ["center", "frontness", "area"]:
        if key in face:
            i += 1
            d.text((ax, ay - (35 * i)), f"{key}: {face[key]:.2f}", fill="white", font=font)
    for key, val in extra.items():
        i += 1
        d.text((ax, ay - (35 * i)), f"{key}: {val}", fill="white", font=font)
