from music21 import duration, chord, stream
from chord_progression_network import Generator
from music_tonnetztransform import Transform
from random_rhythms import Rhythm

s = stream.Stream()
p = stream.Part()

r = Rhythm(durations=[1, 2, 3])
motifs = [ r.motif() for _ in range(3) ]

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

for _ in range(2):
    for i,motif in enumerate(motifs):
        g.max = len(motif)
        g.tonic = i == 0
        g.resolve = i == len(motif) - 1
        phrase = g.generate()
        for i,dura in enumerate(motif):
            c = chord.Chord(phrase[i])
            c.duration = duration.Duration(dura)
            p.append(c)

    t = Transform(
        format='ISO',
        base_chord=phrase[-1],
        max=len(motifs[0]),
        verbose=True,
    )
    generated = t.circular()[0]

    for i,dura in enumerate(motifs[0]):
        c = chord.Chord(generated[i])
        c.duration = duration.Duration(dura)
        p.append(c)

    for motif in motifs + [motifs[0]]:
        g.max = len(motif)
        phrase = g.generate()
        for i,dura in enumerate(motif):
            c = chord.Chord(phrase[i])
            c.duration = duration.Duration(dura)
            p.append(c)

s.append(p)
s.show()
