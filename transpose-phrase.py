from music21 import chord, duration, note, stream, tempo
from pychord import Chord as pyChord
import random
import re
from music_melodicdevice import Device
from music_bassline_generator import Bassline
from random_rhythms import Rhythm

def first_verse():
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
        for j,d in enumerate(motifs1[0]):
            n = note.Note(notes[j])
            n.duration = duration.Duration(d)
            bass_part.append(n)

def second_verse():
    for i,my_chord in enumerate(chords):
        c = pyChord(my_chord)
        c = chord.Chord(c.components(), type='whole')
        chord_part.append(c)
        if i == 2:
            notes = device.transpose(3, pitches1)
        elif i == 3:
            notes = bass.generate('C', len(motifs1[1]))
            notes = device.transpose(3, notes)
        else:
            notes = device.transpose(2, pitches1)
        for j,d in enumerate(motifs1[1]):
            n = note.Note(notes[j % len(notes)])
            n.duration = duration.Duration(d)
            bass_part.append(n)

def third_verse():
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
            notes = device.transpose(2, pitches2)
        for n in notes:
            n = note.Note(n, type='quarter')
            bass_part.append(n)

def fourth_verse():
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
        for j,d in enumerate(motifs1[0]):
            n = note.Note(notes[j])
            n.duration = duration.Duration(d)
            bass_part.append(n)

def pre_chorus():
    for j,d in enumerate(motifs2[0]):
        my_chord = random.choice(unique2)
        c = pyChord(my_chord)
        parts = chord.Chord(c.components())
        parts.duration = duration.Duration(d)
        chord_part.append(parts)
        if j == 0:
            n = c.components()[0] + '2'
            n = note.Note(n, type='whole')
            bass_part.append(n)

def chorus():
    for i in range(2):
        for j,d in enumerate(motifs2[1]):
            my_chord = random.choice(unique3)
            c = pyChord(my_chord)
            comp = c.components()
            length = len(comp) - 1
            comp.pop(random.randint(0, length))
            parts = chord.Chord(comp)
            parts.duration = duration.Duration(d)
            chord_part.append(parts)
            if j == 0:
                n = c.components()[0] + '2'
                n = note.Note(n, type='whole')
                bass_part.append(n)

def resolution():
    c = pyChord(chords[0])
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    match = re.search(r'^([a-gA-G][#b]?)', chords[0])
    if match:
        n = match.group(1) + '2'
        n = note.Note(n, type='whole')
        bass_part.append(n)

if __name__ == "__main__":
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

    rhythm1 = Rhythm(
        durations=[1/2, 1, 3/2],
    )
    rhythm2 = Rhythm(
        durations=[1/2, 1, 3/2, 2],
    )

    motifs1 = [ rhythm1.motif() for _ in range(4) ]
    motifs2 = [ rhythm2.motif() for _ in range(4) ]

    chords = ['C','G','Am','F']

    unique2 = random.sample(list(set(chords)), 2)
    unique3 = random.sample(list(set(chords)), 3)

    pitches1 = bass.generate('C', len(motifs1[0]))
    pitches2 = bass.generate('G', 4)

    first_verse()
    second_verse()
    third_verse()
    fourth_verse()
    pre_chorus()
    pre_chorus()
    chorus()
    chorus()
    pre_chorus()
    pre_chorus()
    chorus()
    chorus()
    first_verse()
    second_verse()
    third_verse()
    fourth_verse()
    resolution()

    s.append(tempo.MetronomeMark(number=90))
    s.insert(0, chord_part)
    s.insert(0, bass_part)
    s.show('midi')
