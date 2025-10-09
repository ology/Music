from numpy.random import choice
from music21 import note

#song = mu.converter.parse('/Users/gene/Music/MIDI/chopin-Fantaisie-Impromptu-op66.mid')
song = mu.corpus.parse('bwv66.6')

notes = 16 # Change me

transition = {}

prev = None
last = None
total = 0

# gather the transitions
for n in song.flat.notes:
    if type(n) == note.Note:
        if prev:
            if last:
                key = (prev.name, last.name)
                if key in transition:
                    if n.name in transition[key]:
                        transition[key][n.name] += 1
                    else:
                        transition[key][n.name] = 1
                else:
                    transition[key] = {n.name: 1}
                prev = last
                total += 1
            last = n
        else:
            prev = n

# probability for each transition
for k,v in transition.items():
    for i,j in v.items():
        transition[k][i] = j / total

# transition probability score
score = mu.stream.Stream()

key = list(transition.keys())[0]
keys = [' '.join(i) for i in list(transition.keys())]

# TODO why?
n = note.Note(key[0])
score.append(n)
n = note.Note(key[1])
score.append(n)

# build the score
for _ in range(notes - 2):
    if key in transition:
        draw = choice(list(transition[key].keys()), 1, list(transition[key].values()))
        n = note.Note(draw[0])
        score.append(n)
        key = (key[1], draw[0])
    else:
        r = note.Rest()
        score.append(r)
        draw = choice(keys)
        key = tuple(draw.split())

score.show()
score.show('midi')
