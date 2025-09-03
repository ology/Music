from music21 import *
import random
from random_rhythms import Rhythm

rr = Rhythm(
    measure_size=4
)
motif = rr.motif()
print(motif)

sc1 = scale.WholeToneScale('C4')
# print(sc1.pitches)
sig = '5/4' # time signature

s = stream.Stream()
s.append(meter.TimeSignature(sig))

for dura in motif:
    k = random.choice(sc1.pitches)
    n = note.Note(k)
    n.duration = duration.Duration(dura)
    # print(n.duration.type)
    s.append(n)

s.show() # 'midi' opens Logic
