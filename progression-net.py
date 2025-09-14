from music21 import chord, duration, stream
from chord_progression_network import Generator
from random_rhythms import Rhythm

r = Rhythm(durations=[1, 3/2, 2])
motifs = [ r.motif() for _ in range(4) ]

s = stream.Score()
p = stream.Part()

g = Generator(
    scale_name='whole-tone scale',
    net={
        1: [2,3,4,5,6],
        2: [1,3,4,5,6],
        3: [1,2,4,5,6],
        4: [1,2,3,5,6],
        5: [1,2,3,4,6],
        6: [1,2,3,4,5],
    },
    chord_map=['m'] * 6,
    substitute=True,
    verbose=True,
)

for m in motifs:
    g.max = len(m)
    phrase = g.generate()
    for i, d in enumerate(m):
        c = chord.Chord(phrase[i])
        c.duration = duration.Duration(d)
        p.append(c)

s.append(p)

s.show()#'midi')
