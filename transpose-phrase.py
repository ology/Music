from music21 import chord, duration, note, stream, tempo
from pychord import Chord as pyChord
import random
import re
from music_melodicdevice import Device
from music_bassline_generator import Bassline
from random_rhythms import Rhythm

# set-up
s = stream.Stream()
bass_part = stream.Part()
chord_part = stream.Part()

bass = Bassline(
    modal=True,
    octave=2,
    tonic=False,
    resolve=False,
    guitar=True,
    format='ISO',
)

device = Device(
    scale_name='major',
)

r = Rhythm(
    measure_size=4,
    durations=[1/2, 1, 3/2],
)
motifs = [ r.motif() for _ in range(4) ]

chords = ['C','G','Am','F']

# first phrase
pitches1 = bass.generate('C', len(motifs[0]))
for i,my_chord in enumerate(chords):
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    if i == 2:
        notes = device.transpose(3, pitches1)
    elif i == 3:
        notes = device.invert('C3', pitches1)
        notes = device.transpose(-3, notes)
    else:
        notes = pitches1
    for j,d in enumerate(motifs[0]):
        n = note.Note(notes[j])
        n.duration = duration.Duration(d)
        bass_part.append(n)

# second phrase
for i,my_chord in enumerate(chords):
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    if i == 2:
        notes = device.transpose(3, pitches1)
    elif i == 3:
        notes = bass.generate('C', len(motifs[1]))
    else:
        notes = pitches1
    for j,d in enumerate(motifs[1]):
        n = note.Note(notes[j % len(notes)])
        n.duration = duration.Duration(d)
        bass_part.append(n)

# third phrase
pitches2 = bass.generate('G', 4)
for i,my_chord in enumerate(chords):
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    if i == 2:
        notes = device.transpose(3, pitches2)
    elif i == 3:
        notes = device.invert('C3', pitches2)
        notes = device.transpose(-3, notes)
    else:
        notes = pitches2
    for n in notes:
        n = note.Note(n, type='quarter')
        bass_part.append(n)

# fourth phrase
for i,my_chord in enumerate(chords):
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    if i == 2:
        notes = device.transpose(3, pitches1)
    elif i == 3:
        notes = device.invert('C3', pitches1)
        notes = device.transpose(-3, notes)
    else:
        notes = pitches1
    for j,d in enumerate(motifs[0]):
        n = note.Note(notes[j])
        n.duration = duration.Duration(d)
        bass_part.append(n)

unique = random.sample(list(set(chords)), 2)

# bridge phrase
for j,d in enumerate(motifs[1]):
    my_chord = random.choice(unique)
    c = pyChord(my_chord)
    parts = chord.Chord(c.components())
    parts.duration = duration.Duration(d)
    chord_part.append(parts)
    if j == 0:
        n = note.Note(c.components()[0], type='whole')
        bass_part.append(n)

# final resolution
c = pyChord(chords[0])
c = chord.Chord(c.components(), type='whole')
chord_part.append(c)
match = re.search(r'^([a-gA-G][#b]?)', chords[0])
if match:
    n = match.group(1) + '2'
    n = note.Note(n, type='whole')
    bass_part.append(n)

# gather the goods!
s.append(tempo.MetronomeMark(number=90))
s.insert(0, chord_part)
s.insert(0, bass_part)
s.show('midi')
