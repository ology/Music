from music21 import chord, note, stream, tempo
from pychord import Chord as pyChord
import re
from music_melodicdevice import Device
from music_bassline_generator import Bassline

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

chords = ['C','G','Am','F']
# chords = ['CM7','G7','Am7','Fsus4']

# first phrase
pitches1 = bass.generate('C', 4)
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
    for n in notes:
        n = note.Note(n, type='quarter')
        bass_part.append(n)

# second phrase
for i,my_chord in enumerate(chords):
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    if i == 2:
        notes = device.transpose(3, pitches1)
    elif i == 3:
        notes = bass.generate('C', 4)
    else:
        notes = pitches1
    for n in notes:
        n = note.Note(n, type='quarter')
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
    for n in notes:
        n = note.Note(n, type='quarter')
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
