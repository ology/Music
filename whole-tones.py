from music21 import duration, chord, note, scale, stream
from chord_progression_network import Generator
from music_tonnetztransform import Transform
from music_voicegen import MusicVoiceGen
from random_rhythms import Rhythm
import random

s = stream.Stream()
chord_part = stream.Part()
melody_part = stream.Part()
bass_part = stream.Part()

bass_notes = [] # accumulated by the first note of a chord progression measure

r = Rhythm(durations=[1, 2, 3])
chord_motifs = [ r.motif() for _ in range(3) ]

r = Rhythm(
    durations=[1/2, 1/3, 1, 3/2],
    weights=[2, 1, 3, 2],
    groups={1/3: 3},
    smallest=1/4,
)
melody_motifs = [ r.motif() for _ in range(3) ]

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
    chord_map=['m'] * 6, # every chord is the same flavor
    substitute=False,
    verbose=False,
)

# chords
for _ in range(2):
    for i,motif in enumerate(chord_motifs):
        g.max = len(motif)
        g.tonic = i == 0
        g.resolve = i == len(motif) - 1
        phrase = g.generate()
        bass_notes.append(phrase[0][0])
        for j,dura in enumerate(motif):
            c = chord.Chord(phrase[j])
            c.duration = duration.Duration(dura)
            chord_part.append(c)
    t = Transform(
        format='ISO',
        base_chord=phrase[-1],
        max=len(chord_motifs[0]),
        verbose=False,
    )
    generated = t.circular()[0]
    bass_notes.append('rest')
    for i,dura in enumerate(chord_motifs[0]):
        c = chord.Chord(generated[i])
        c.duration = duration.Duration(dura)
        chord_part.append(c)
    for motif in chord_motifs + [chord_motifs[0]]:
        g.max = len(motif)
        phrase = g.generate()
        bass_notes.append(phrase[0][0])
        for j,dura in enumerate(motif):
            c = chord.Chord(phrase[j])
            c.duration = duration.Duration(dura)
            chord_part.append(c)

v = MusicVoiceGen(
    pitches=[ p.midi + 12 for p in scale.WholeToneScale('C').getPitches() ],
    intervals=[-3,-2,-1,1,2,3]
)

# "melody"
for _ in range(2):
    for motif in melody_motifs:
        for dura in motif:
            if random.random() < 0.2:
                n = note.Rest()
            else:
                n = note.Note(v.rand())
            n.duration = duration.Duration(dura)
            melody_part.append(n)
    n = note.Rest(type='whole')
    melody_part.append(n)
    for motif in melody_motifs + [melody_motifs[0]]:
        for dura in motif:
            if random.random() < 0.1:
                n = note.Rest()
            else:
                n = note.Note(v.rand())
            n.duration = duration.Duration(dura)
            melody_part.append(n)

# bass
for n in bass_notes:
    if n == 'rest':
        n = note.Rest(type='whole')
    else:
        n = note.Note(n, type='whole')
    bass_part.append(n)

s.insert(0, chord_part)
s.insert(0, melody_part)
s.insert(0, bass_part.transpose(-(12 * 2)))

s.show()
