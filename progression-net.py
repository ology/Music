from music21 import chord, duration, stream
from chord_progression_network import Generator
from random_rhythms import Rhythm

r = Rhythm(durations=[1, 3/2, 2])
motifs = [ r.motif() for _ in range(4) ]

s = stream.Score()
p = stream.Part()

g = Generator(
    net={
        1: [2,3],
        2: [1,3,4],
        3: [2,4,5],
        4: [3,5,6],
        5: [4,6,7],
        6: [5,7],
        7: [6],
    },
)

for m in motifs:
    g.max = len(m)
    phrase = g.generate()
    for i, d in enumerate(m):
        c = chord.Chord(phrase[i])
        c.duration = duration.Duration(d)
        p.append(c)

s.append(p)

s.show('midi')
