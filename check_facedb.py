from pathlib import Path
from retinaface import RetinaFace as rf
from PIL import Image, ImageDraw, ImageFont
from deepface import DeepFace


file = "data/frames/WON02440007/WON02440007__560.png"
# file = "data/frames/WON02440272/WON02440272__920.png"
# file = "data/facedb/eerdmans__WON02440075__229.png"


im = Image.open(file)
d = ImageDraw.Draw(im)

for face in detect_faces(file):
    annotate_face(d, face, "green")
selected = select_face(file)
annotate_face(d, selected, "red")

im.save("/tmp/test.png")

# model = rf.build_model()
# for face in
#     print(face)
#     x, y, x2, y2 = face["facial_area"]
#     w = x2 - x
#     h = y2 - y
#     font = ImageFont.truetype("Gidole-Regular.ttf", 32)
#     landmarkxs = {landmark: xy[0] for (landmark, xy) in face["landmarks"].items()}
#     frontness = abs(landmarkxs["left_eye"] - landmarkxs["right_eye"]) / w
#     center = (x + x2) / 2 / im.size[0]
#     for landmark, xy in face["landmarks"].items():
#         d.text((xy[0] - 16, xy[1] - 16), landmark[0].upper(), fill="red", font=font)

#     d.text((x + 2, y + h - 105), f"center: {center:.2f}", fill="white", font=font)
#     d.text((x + 2, y + h - 70), f"front: {frontness:.2f}", fill="white", font=font)
#     d.text((x + 2, y + h - 35), f"size: {min(w, h)}", fill="white", font=font)

# im.save("/tmp/test.png")
