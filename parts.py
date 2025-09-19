from music21 import duration, chord, note, scale, stream
from chord_progression_network import Generator
from music_tonnetztransform import Transform
from music_voicegen import MusicVoiceGen
from random_rhythms import Rhythm

s = stream.Stream()
chord_part = stream.Part()
melody_part = stream.Part()

r = Rhythm(durations=[1, 2, 3])
chord_motifs = [ r.motif() for _ in range(3) ]
r = Rhythm(
    durations=[1/2, 1/3, 1, 3/2, 2],
    groups={1/3: 3},
)
melody_motifs = [ r.motif() for _ in range(3) ]

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
    for i,motif in enumerate(chord_motifs):
        g.max = len(motif)
        g.tonic = i == 0
        g.resolve = i == len(motif) - 1
        phrase = g.generate()
        for j,dura in enumerate(motif):
            c = chord.Chord(phrase[j])
            c.duration = duration.Duration(dura)
            chord_part.append(c)
    t = Transform(
        format='ISO',
        base_chord=phrase[-1],
        max=len(chord_motifs[0]),
        verbose=True,
    )
    generated = t.circular()[0]
    for i,dura in enumerate(chord_motifs[0]):
        c = chord.Chord(generated[i])
        c.duration = duration.Duration(dura)
        chord_part.append(c)
    for motif in chord_motifs + [chord_motifs[0]]:
        g.max = len(motif)
        phrase = g.generate()
        for j,dura in enumerate(motif):
            c = chord.Chord(phrase[j])
            c.duration = duration.Duration(dura)
            chord_part.append(c)

v = MusicVoiceGen(
    pitches=[ p.midi for p in scale.MajorScale('C').getPitches() ],
    intervals=[-3,-2,-1,1,2,3]
)

for _ in range(2):
    for motif in melody_motifs:
        for dura in motif:
            n = note.Note(v.rand())
            n.duration = duration.Duration(dura)
            melody_part.append(n)
    for dura in melody_motifs[0]:
        n = note.Rest()
        n.duration = duration.Duration(dura)
        melody_part.append(n)
    for motif in melody_motifs:
        for dura in motif:
            n = note.Note(v.rand())
            n.duration = duration.Duration(dura)
            melody_part.append(n)

s.insert(0, chord_part)
s.insert(0, melody_part)

s.show()
