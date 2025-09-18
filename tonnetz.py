from music21 import duration, chord, stream
from music_tonnetztransform import Transform
from random_rhythms import Rhythm

s = stream.Stream()
p = stream.Part()

r = Rhythm(durations=[1, 3/2, 2])
motif = r.motif()

t = Transform(max=len(motif))
generated = t.generate()[0]
print(generated)

for i,dura in enumerate(motif):
    c = chord.Chord(generated[i])
    c.duration = duration.Duration(dura)
    p.append(c)

s.append(p)
s.show()
