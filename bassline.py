from music21 import chord, note, stream
from music_bassline_generator import Bassline
from pychord import Chord as pyChord

def add_notes(p, notes):
    # print(notes)
    for n in notes:
        n = note.Note(n, type='quarter')
        p.append(n)

s = stream.Stream()
bass_part = stream.Part()
chord_part = stream.Part()

bass = Bassline(modal=True, octave=2, tonic=True, resolve=False)

num = 4

def autumn_leaves():
    return [
        ['Dm7','G7','CM7','FM7','Bm7b5','E7','Am7','Am7'] +
        ['Dm7','G7','CM7','FM7','Bm7b5','E7','Am7','Am7'] +
        ['Bm7b5','E7b9','Am7','Am7','Dm7','G7','CM7','FM7'] +
        ['Bm7b5','E7b9','Am7','Gm7','FM7','Bm7b5','Am7','Am7']
    ]

for my_chord in autumn_leaves()[0]:
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    notes = bass.generate(my_chord, num)
    add_notes(bass_part, notes)

s.insert(0, chord_part)
s.insert(0, bass_part)

s.show()
