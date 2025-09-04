import random
from music21 import *
from random_rhythms import Rhythm
from music_voicegen import MusicVoiceGen

r = Rhythm(
    measure_size=5,
    groups={1/3: 3},
)
motifs = [ r.motif() for x in range(4) ]

sc = scale.WholeToneScale('C4')
midinums = [ p.midi for p in sc.pitches ]

voice = MusicVoiceGen(
    pitches=midinums,
    intervals=[-3,-2,-1,1,2,3]
)

s = stream.Stream()
s.append(meter.TimeSignature('5/4'))

for m in motifs:
    for i, d in enumerate(m):
        chance = random.random()
        if chance < 0.3:
            n = note.Rest()
        else:
            n = note.Note(voice.rand())
        n.duration = duration.Duration(d)
        # print(n.duration.type)
        s.append(n)

s.show() # 'midi' opens Logic
