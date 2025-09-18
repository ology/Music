from music21 import duration, chord, stream
from chord_progression_network import Generator
from music_tonnetztransform import Transform
from random_rhythms import Rhythm

s = stream.Stream()
p = stream.Part()

r = Rhythm(durations=[1, 3/2, 2])
motifs = [ r.motif() for _ in range(3) ]

t = Transform(max=len(motifs[0]), verbose=True)
generated = t.circular()[0]

g = Generator()

for motif in motifs:
    g.max = len(motif)
    phrase = g.generate()
    for i,dura in enumerate(motif):
        c = chord.Chord(phrase[i])
        c.duration = duration.Duration(dura)
        p.append(c)

for i,dura in enumerate(motifs[0]):
    c = chord.Chord(generated[i])
    c.duration = duration.Duration(dura)
    p.append(c)

s.append(p)
s.show()
