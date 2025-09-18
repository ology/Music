from music_tonnetztransform import Transform
from music21 import chord, stream

s = stream.Stream()
p = stream.Part()

t = Transform()
generated = t.generate()[0]

for notes in generated:
    c = chord.Chord(notes, type='whole')
    p.append(c)

s.append(p)
s.show()
