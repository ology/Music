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

bass = Bassline(octave=2)

num = 4

# Autumn Leaves verse
for my_chord in ['Am7','D7','GM7','CM7','F#m7b5','B7','Em','Em']:
    c = pyChord(my_chord)
    c = chord.Chord(c.components())
    chord_part.append(c)
    notes = bass.generate(my_chord, num)
    add_notes(bass_part, notes)

s.insert(0, bass_part)
s.insert(0, chord_part)

s.show()

"""
bass = Bassline(
    keycenter='C', # tonic for modal accompaniment
    modal=False, # only choose notes within the mode
    chord_notes=True, # use chord notes outside the scale
    intervals=[-3, -2, -1, 1, 2, 3], # allowed voicegen intervals
    octave=1, # lowest MIDI octave
    tonic=False, # play the first scale note to start the generated phrase
    positions=None, # allowed notes for major and minor scales
    guitar=False, # transpose notes below E1 (midi #28) up an octave
    wrap=None, # transpose notes above this ISO named note, down an octave
    format='ISO',
    verbose=True, # show progress
)

notes = bass.generate('C7b5', 4)
print(notes)

notes = bass.generate('D/A', 4)
notes = bass.generate('D', 4, 'C/G')
notes = bass.generate('D', 1)

bass = Bassline(modal=True)
notes = bass.generate('Dm7')
notes = bass.generate('Dm7b5')

bass = Bassline(
    octave=3,
    wrap='C3',
    modal=True,
)
notes = bass.generate('C', 4)

bass = Bassline(
    # chord_notes=False,
    positions={'major': [x for x in range(6)], 'minor': [x for x in range(6)]} # no 7ths!
)
notes = bass.generate('C', 4)
print(notes)
"""
