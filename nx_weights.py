import networkx as nx
import random
import sys
from music21 import converter, corpus, duration, instrument, note, stream

max = int(sys.argv[1]) if len(sys.argv) > 1 else 16 # maximum notes in the result phrase

song = corpus.parse('bwv1.6')
# song = corpus.parse('bwv66.6')
# song = corpus.parse('maple_leaf_rag')
# song = converter.parse('/Users/gene/Music/MIDI/MHaLL.mid')

if len(song.parts) > 1:
    song = instrument.partitionByInstrument(song)[0] # only use a single part
else:
    song = instrument.partitionByInstrument(song)
# song.show('midi')

pitch_transition = {}
beat_transition = {}
prev = None # network item
last = None # network item
total = 0 # total number of notes

def tally_freqs(target, key, transition):
    if key in transition:
        if target in transition[key]:
            transition[key][target] += 1
        else:
            transition[key][target] = 1
    else:
        transition[key] = { target: 1 }

# gather the pitch and beat transitions
i = 0
for n in song.flatten().notes:
    if type(n) == note.Note:
        if prev:
            if last:
                pitch_key = (prev.name, last.name)
                beat_key = (prev.duration.quarterLength, last.duration.quarterLength)
                if i == 0:
                    tally_freqs(last.name, pitch_key, pitch_transition)
                    tally_freqs(last.duration.quarterLength, beat_key, beat_transition)
                tally_freqs(n.name, pitch_key, pitch_transition)
                tally_freqs(n.duration.quarterLength, beat_key, beat_transition)
                prev = last
                total += 1
                i += 1
            last = n
        else:
            prev = n

# probability for pitch transitions
pitch_graph = nx.DiGraph()
for k,v in pitch_transition.items():
    for i,j in v.items():
        w = j / total
        pitch_graph.add_edge(k[1], i, weight=w)

# probability for beat transitions
beat_graph = nx.DiGraph()
for k,v in beat_transition.items():
    for i,j in v.items():
        w = j / total
        beat_graph.add_edge(k[1], i, weight=w)

score = stream.Stream()

current_pitch = list(pitch_transition.keys())[0]
current_beat = list(beat_transition.keys())[0]

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
while (i < max):
    if current_pitch in pitch_transition:
        pitch = get_weighted_successor(pitch_graph, current_pitch[0])
        beat = get_weighted_successor(beat_graph, current_beat[0])
        n = note.Note(pitch)
        n.duration = duration.Duration(beat)
        score.append(n)
        current_pitch = (current_pitch[1], pitch)
        current_beat = (current_beat[1], beat)
        i += 1
    else:
        # score.append(note.Rest())
        current_pitch = random.choice(list(pitch_transition.keys()))

score.show('midi')
