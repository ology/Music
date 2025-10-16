from music21 import chord, duration, stream
from pychord import Chord as Pychord
from random_rhythms import Rhythm
from chord_progression_network import Generator

r = Rhythm(durations=[1, 3/2, 2, 3, 4])
motifs1 = [ r.motif() for _ in range(4) ]
motifs2 = [ r.motif() for _ in range(4) ]

s = stream.Score()
chord_part = stream.Part()

g1 = Generator(
    net={
        1: [5],
        2: [],
        3: [],
        4: [1],
        5: [6],
        6: [4],
        7: [],
    },
    weights={ i: [1] for i in range(1, 8) },
    tonic=True,
    resolve=False,
    chord_phrase=True,
)
g2 = Generator(
    net={
        1: [5],
        2: [],
        3: [],
        4: [1],
        5: [6],
        6: [4],
        7: [],
    },
    weights={ i: [1] for i in range(1, 8) },
    tonic=False,
    resolve=False,
    chord_phrase=True,
)

for _ in range(4):
    for m in motifs1:
        g1.max = len(m)
        phrase = g1.generate()
        for i, d in enumerate(m):
            c = Pychord(phrase[i])
            c = chord.Chord(c.components())
            c.duration = duration.Duration(d)
            chord_part.append(c)

for _ in range(4):
    for m in motifs2:
        g2.max = len(m)
        phrase = g2.generate()
        for i, d in enumerate(m):
            c = Pychord(phrase[i])
            c = chord.Chord(c.components())
            c.duration = duration.Duration(d)
            chord_part.append(c)

for _ in range(4):
    for m in motifs1:
        g1.max = len(m)
        phrase = g1.generate()
        for i, d in enumerate(m):
            c = Pychord(phrase[i])
            c = chord.Chord(c.components())
            c.duration = duration.Duration(d)
            chord_part.append(c)

s.insert(0, chord_part)
s.show('midi')
