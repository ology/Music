import random
from music21 import converter, corpus, instrument, note, stream
# if author:
import sys
sys.path.append('./src')
from music_voicegen.music_voicegen import MusicVoiceGen
# else:
# from music_voicegen import MusicVoiceGen

# song = converter.parse('/Users/gene/Music/MIDI/lichens_g_major.mid')
# song = corpus.parse('bwv66.6')
song = corpus.parse('bwv1.6')
song = instrument.partitionByInstrument(song)[0] # only inspect a single part
# song.show()

max = int(sys.argv[1]) if len(sys.argv) > 1 else 16 # maximum notes in the result phrase

pitch_transition = {}
beat_transition = {}
prev = None # network item
last = None # network item
total = 0 # total number of notes
pitches = []
intervals = []

# gather the transitions
for n in song.flatten().notes:
    if type(n) == note.Note:
        pitches.append(n.pitch.midi)
        if prev:
            if last:
                # pitch
                pitch_key = (prev.name, last.name)
                interval = last.pitch.midi - prev.pitch.midi
                # print(f"{last.name}{last.octave} - {prev.name}{prev.octave} = {interval}")
                intervals.append(interval)
                # tally pitch transition frequency
                if pitch_key in pitch_transition:
                    if n.name in pitch_transition[pitch_key]:
                        pitch_transition[pitch_key][n.name] += 1
                    else:
                        pitch_transition[pitch_key][n.name] = 1
                else:
                    pitch_transition[pitch_key] = {n.name: 1}
                # beat
                beat_key = (prev.duration.quarterLength, last.duration.quarterLength)
                # tally beat transition frequency
                if beat_key in beat_transition:
                    if n.duration.quarterLength in beat_transition[beat_key]:
                        beat_transition[beat_key][n.duration.quarterLength] += 1
                    else:
                        beat_transition[beat_key][n.duration.quarterLength] = 1
                else:
                    beat_transition[beat_key] = {n.duration.quarterLength: 1}
                prev = last
                total += 1
            last = n
        else:
            prev = n

pitches = list(set(pitches)) # uniqify
intervals = list(set(intervals)) # uniqify

# probability for each transition
for k,v in pitch_transition.items():
    for i,j in v.items():
        pitch_transition[k][i] = j / total

# # transition probability score
score = stream.Stream()

key = list(pitch_transition.keys())[0]
keys = [' '.join(i) for i in list(pitch_transition.keys())]

voice = MusicVoiceGen(
    pitches=pitches,
    intervals=intervals
)
# voice.context(context=[60]) # start at middle c

# build the score
i = 0
while(i < max):
    if key in pitch_transition:
        draw = voice.rand()
        n = note.Note(draw)
        score.append(n)
        key = (key[1], n.name)
        i += 1
    else:
        # print(key)
        # score.append(note.Rest())
        draw = random.choice(keys)
        key = tuple(draw.split())

score.show('midi')
