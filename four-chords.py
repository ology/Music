from music21 import chord, duration, stream
from random_rhythms import Rhythm
try:
    import sys
    sys.path.append('./src')
    from chord_progression_network.chord_progression_network import Generator
except ImportError:
    from chord_progression_network import Generator

r = Rhythm(durations=[1, 3/2, 2])
motifs = [ r.motif() for _ in range(4) ]

s = stream.Score()
p = stream.Part()

g = Generator()

for m in motifs:
    g.max = len(m)
    phrase = g.generate()
    for i, d in enumerate(m):
        c = chord.Chord(phrase[i])
        c.duration = duration.Duration(d)
        p.append(c)

s.append(p)

s.show('midi')
