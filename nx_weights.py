import networkx as nx
import random
import sys
from music21 import converter, corpus, duration, instrument, note, stream

# song = converter.parse('/Users/gene/Music/MIDI/lichens_g_major.mid')
# song = corpus.parse('bwv66.6')
song = corpus.parse('bwv1.6')
song = instrument.partitionByInstrument(song)[0] # only use a single part
# song.show('midi')

max = int(sys.argv[1]) if len(sys.argv) > 1 else 16 # maximum notes in the result phrase

pitch_transition = {}
beat_transition = {}
prev = None # network item
last = None # network item
total = 0 # total number of notes

# gather the transitions
for n in song.flatten().notes:
    if type(n) == note.Note:
        if prev:
            if last:
                # pitch
                pitch_key = (prev.name, last.name)
                # tally pitch transition frequency
                if pitch_key in pitch_transition:
                    if n.name in pitch_transition[pitch_key]:
                        pitch_transition[pitch_key][last.name] += 1
                    else:
                        pitch_transition[pitch_key][last.name] = 1
                else:
                    pitch_transition[pitch_key] = { last.name: 1 }
                # tally beat transition frequency
                beat_key = (prev.duration.quarterLength, last.duration.quarterLength)
                ql = last.duration.quarterLength
                if beat_key in beat_transition:
                    if ql in beat_transition[beat_key]:
                        beat_transition[beat_key][ql] += 1
                    else:
                        beat_transition[beat_key][ql] = 1
                else:
                    beat_transition[beat_key] = {ql: 1}
                prev = last
                total += 1
            last = n
        else:
            prev = n

# probability for pitch transitions
pitch_graph = nx.DiGraph()
for k,v in pitch_transition.items():
    for i,j in v.items():
        w = j / total
        pitch_graph.add_edge(k[0], i, weight=w)

# probability for beat transitions
beat_graph = nx.DiGraph()
for k,v in beat_transition.items():
    for i,j in v.items():
        w = j / total
        beat_graph.add_edge(k[0], i, weight=w)

score = stream.Stream()

key = list(pitch_transition.keys())[0]
keys = [' '.join(i) for i in list(pitch_transition.keys())]

def get_weighted_successor(graph, node):
    successors = list(graph.successors(node))
    if not successors:
        return None
    weights = [
        graph.get_edge_data(node, successor)['weight'] for successor in successors
    ]
    return random.choices(successors, weights=weights, k=1)[0]

# build the score
i = 0
current_pitch = list(pitch_transition.keys())[0]
current_beat = list(beat_transition.keys())[0]
while (i < max):
    if key in pitch_transition:
        choice = get_weighted_successor(pitch_graph, current_pitch[0])
        n = note.Note(choice)
        choice = get_weighted_successor(beat_graph, current_beat[0])
        n.duration = duration.Duration(choice)
        score.append(n)
        key = (key[1], n.name)
        current_pitch = (current_pitch[1], choice)
        current_beat = (current_beat[1], choice)
        i += 1
    else:
        # print(key)
        # score.append(note.Rest())
        draw = random.choice(keys)
        key = tuple(draw.split())

score.show('midi')
