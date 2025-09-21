from music21 import chord, note, stream
from music_bassline_generator import Bassline
from pychord import Chord as pyChord

s = stream.Stream()
bass_part = stream.Part()
chord_part = stream.Part()
melody_part = stream.Part()

def autumn_leaves():
    return [
        ['Dm7','G7','CM7','FM7','Bm7b5','E7','Am7','Am7'] +
        ['Dm7','G7','CM7','FM7','Bm7b5','E7','Am7','Am7'] +
        ['Bm7b5','E7b9','Am7','Am7','Dm7','G7','CM7','FM7'] +
        ['Bm7b5','E7b9','Am7','Gm7','FM7','Bm7b5','Am7','Am7']
    ]

def add_notes(p=melody_part, notes=[], type='quarter'):
    for n in notes:
        if type == 'dotted_half':
            n = note.Note(n)
            n.quarterLength = 3
        else:
            n = note.Note(n, type=type)
        p.append(n)

bass = Bassline(modal=True, octave=2, tonic=True, resolve=False)

num = 4

m = note.Rest(type='whole')
bass_part.append(m)
chord_part.append(m)

for my_chord in autumn_leaves()[0]:
    c = pyChord(my_chord)
    c = chord.Chord(c.components(), type='whole')
    chord_part.append(c)
    notes = bass.generate(my_chord, num)
    add_notes(bass_part, notes)

# melody:
m = note.Rest(type='quarter')
melody_part.append(m)
add_notes(notes=['A4','B4','C5'])
add_notes(notes=['F5'], type='whole')
add_notes(notes=['F5','G4','A4','B4'])
add_notes(notes=['E5','E5'], type='half')
add_notes(notes=['E5','F4','G4','A4'])
add_notes(notes=['D5'], type='whole')
add_notes(notes=['D5','E4','F#4','G#4'])
add_notes(notes=['C5'], type='whole')
add_notes(notes=['C5','A4','B4','C5'])
add_notes(notes=['F5'], type='whole')
add_notes(notes=['F5','G4','A4','B4'])
add_notes(notes=['E5','E5'], type='half')
add_notes(notes=['E5','F4','G4','A4']) # 12
add_notes(notes=['D5'], type='whole')
add_notes(notes=['D5','B4','D5','C5'])
add_notes(notes=['A4'], type='whole')
add_notes(notes=['A4'], type='half')
add_notes(notes=['G#4','A4','B4','E4'])
add_notes(notes=['B4'], type='half')
add_notes(notes=['B4','B4','A4','B4'])
add_notes(notes=['C5'], type='whole')
add_notes(notes=['C5','C5','B4','C5'])
add_notes(notes=['D5'], type='whole')
add_notes(notes=['D5','G4','G5','F5'])
add_notes(notes=['E5'], type='whole')
add_notes(notes=['E5'], type='half')
add_notes(notes=['D#5','E5','F5','F5','D5','D5'])
add_notes(notes=['B4'], type='dotted_half')
add_notes(notes=['F5'])
add_notes(notes=['E5','E5'], type='half')
add_notes(notes=['E5'], type='dotted_half')
add_notes(notes=['A4'])
add_notes(notes=['D5'], type='dotted_half')
add_notes(notes=['C5'])
add_notes(notes=['B4'], type='half')
add_notes(notes=['C5','C5'])
add_notes(notes=['A4','A4'], type='whole')

s.insert(0, melody_part)
s.insert(0, chord_part)
s.insert(0, bass_part)
s.show()
