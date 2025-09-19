from music21 import duration, chord, stream
from chord_progression_network import Generator
from music_tonnetztransform import Transform
from random_rhythms import Rhythm

s = stream.Stream()
p = stream.Part()

r = Rhythm(durations=[1/2, 1, 3/2, 2, 3])
motifs = [ r.motif() for _ in range(3) ]

t = Transform()

g = Generator(
    net={
        1: [3,4,5,6],
        2: [4,5,6],
        3: [2,4,5,6],
        4: [1,5,6],
        5: [2,3,4,7],
        6: [3,4,5],
        7: [3,5],
    }
)

for _ in range(4):
    for m in motifs:
        t.max = len(m)
        generated = t.circular()[0]
        for i,dura in enumerate(m):
            c = chord.Chord(generated[i])
            c.duration = duration.Duration(dura)
            p.append(c)

s.append(p)
s.show()
