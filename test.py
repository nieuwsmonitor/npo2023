import sys
from pyannote.audio.pipelines.speaker_verification import PretrainedSpeakerEmbedding
import torch
from pyannote.core import Segment
from pyannote.audio import Audio
import torchaudio
from speechbrain.pretrained import EncoderClassifier

infile = sys.argv[1]
embedding = PretrainedSpeakerEmbedding("speechbrain/spkrec-ecapa-voxceleb", device=torch.device("cuda"))
audio = Audio(sample_rate=16000, mono="downmix")
duration = audio.get_duration(infile)
turn = Segment(0, duration)
emb = embedding(audio.crop(infile, turn)[0][None])

emb = list(emb[0])

print(emb)


classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb")
signal, fs = torchaudio.load(infile)
embeddings = classifier.encode_batch(signal)
