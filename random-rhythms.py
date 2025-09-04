from music21 import *
import random
from random_rhythms import Rhythm

r = Rhythm(
    measure_size=5,
    groups={1/3: 3},
)
motifs = [ r.motif() for x in range(4) ]
# print(motifs)

sc = scale.WholeToneScale('C4')
# print(sc1.pitches)

s = stream.Stream()
s.append(meter.TimeSignature('5/4'))

for m in motifs:
    for d in m:
        p = random.choice(sc.pitches)
        n = note.Note(p)
        n.duration = duration.Duration(d)
        # print(n.duration.type)
        s.append(n)

s.show() # 'midi' opens Logic
