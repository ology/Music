from music21 import *
from random_rhythms import Rhythm

r = Rhythm(
    measure_size=5,
    groups={1/3: 3},
)
motif = r.motif()
print(motif)

sc = scale.WholeToneScale('C4')
# print(sc1.pitches)

s = stream.Stream()
s.append(meter.TimeSignature('5/4'))

for d in motif:
    p = random.choice(sc.pitches)
    n = note.Note(p)
    n.duration = duration.Duration(d)
    # print(n.duration.type)
    s.append(n)

s.show() # 'midi' opens Logic
