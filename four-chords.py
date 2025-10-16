from music21 import chord, duration, stream
from random_rhythms import Rhythm
from chord_progression_network import Generator

r = Rhythm(durations=[1, 3/2, 2])
motifs = [ r.motif() for _ in range(4) ]

s = stream.Score()
p = stream.Part()

g1 = Generator(
    net={
        1: [5],
        2: [],
        3: [],
        4: [],
        5: [6],
        6: [4],
        7: [],
    },
    weights={ i: [1] for i in range(1, 8) },
    tonic=False,
    resolve=False,
)

for _ in range(4):
    for m in motifs:
        g1.max = len(m)
        phrase = g1.generate()
        for i, d in enumerate(m):
            c = chord.Chord(phrase[i])
            c.duration = duration.Duration(d)
            p.append(c)

s.append(p)

s.show('midi')
