from music21 import chord, note, stream, tempo
from pychord import Chord as pyChord
from music_melodicdevice import Device
try:
    import sys
    sys.path.append('./src')
    from music_bassline_generator.music_bassline_generator import Bassline
except ImportError:
    from music_bassline_generator import Bassline

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
pitches = bass.generate('C', 4)

device = Device(
    scale_name='major',
)

chords = ['C','G','Am','F']
# chords = ['CM7','G7','Am7','Fsus4']

for i,my_chord in enumerate(chords):
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    if i == 2:
        notes = device.transpose(3, pitches)
    elif i == 3:
        notes = device.invert('C3', pitches)
        notes = device.transpose(-3, notes)
        # notes = device.transpose(-4, pitches)
    else:
        notes = pitches
    for n in notes:
        n = note.Note(n, type='quarter')
        bass_part.append(n)

for i,my_chord in enumerate(chords):
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    if i == 2:
        notes = device.transpose(3, pitches)
    elif i == 3:
        notes = bass.generate('C', 4)
    else:
        notes = pitches
    for n in notes:
        n = note.Note(n, type='quarter')
        bass_part.append(n)

p2 = bass.generate('G', 4)
for i,my_chord in enumerate(chords):
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    if i == 2:
        notes = device.transpose(3, p2)
    elif i == 3:
        notes = device.invert('C3', p2)
        notes = device.transpose(-3, notes)
        # notes = device.transpose(-4, pitches)
    else:
        notes = p2
    for n in notes:
        n = note.Note(n, type='quarter')
        bass_part.append(n)

for i,my_chord in enumerate(chords):
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    if i == 2:
        notes = device.transpose(3, pitches)
    elif i == 3:
        notes = device.invert('C3', pitches)
        notes = device.transpose(-3, notes)
        # notes = device.transpose(-4, pitches)
    else:
        notes = pitches
    for n in notes:
        n = note.Note(n, type='quarter')
        bass_part.append(n)

c = pyChord(chords[0])
c = chord.Chord(c.components(), type='whole')
chord_part.append(c)
n = note.Note(pitches[0], type='whole')
bass_part.append(n)

s.append(tempo.MetronomeMark(number=90))
s.insert(0, chord_part)
s.insert(0, bass_part)
s.show('midi')
