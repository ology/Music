from music21 import chord, duration, note, stream
from pychord import Chord as Pychord
from random_rhythms import Rhythm
from chord_progression_network import Generator
from music_bassline_generator import Bassline

r1 = Rhythm(durations=[1, 3/2, 2, 3, 4])
motifs1 = [ r1.motif() for _ in range(4) ]
motifs2 = [ r1.motif() for _ in range(4) ]
r2 = Rhythm(durations=[1/2, 1, 3/2, 2])
motifs3 = [ r2.motif() for _ in range(4) ]
motifs4 = [ r2.motif() for _ in range(4) ]

s = stream.Score()
chord_part = stream.Part()
bass_part = stream.Part()

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

b1 = Bassline(
    modal=True,
)
b2 = Bassline(
    modal=False,
)

bass = []

for _ in range(4):
    for m in motifs1:
        g1.max = len(m)
        phrase = g1.generate()
        for i, d in enumerate(m):
            bass.append(phrase[i])
            c = Pychord(phrase[i])
            c = chord.Chord(c.components())
            c.duration = duration.Duration(d)
            chord_part.append(c)

for c in bass:
    pitches = b1.generate(c, 4)
    for p in pitches:
        n = note.Note(p, type='quarter')
        bass_part.append(n)

bass = []

for _ in range(4):
    for m in motifs2:
        g2.max = len(m)
        phrase = g2.generate()
        for i, d in enumerate(m):
            bass.append(phrase[i])
            c = Pychord(phrase[i])
            c = chord.Chord(c.components())
            c.duration = duration.Duration(d)
            chord_part.append(c)

for c in bass:
    pitches = b1.generate(c, 4)
    for p in pitches:
        n = note.Note(p, type='quarter')
        bass_part.append(n)

bass = []

for _ in range(4):
    for m in motifs1:
        g1.max = len(m)
        phrase = g1.generate()
        for i, d in enumerate(m):
            bass.append(phrase[i])
            c = Pychord(phrase[i])
            c = chord.Chord(c.components())
            c.duration = duration.Duration(d)
            chord_part.append(c)

for c in bass:
    pitches = b1.generate(c, 4)
    for p in pitches:
        n = note.Note(p, type='quarter')
        bass_part.append(n)

s.insert(0, chord_part)
s.insert(0, bass_part)
s.show('midi')
