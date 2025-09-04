from music21 import *
import random
from random_rhythms import Rhythm
import subprocess

def pitch_phrase(n, pitches, intervals=[-4,-3,-2,-1,1,2,3,4]):
    try:
        result = subprocess.run(['perl', 'voicegen.pl', str(n), str(pitches), str(intervals)], capture_output=True, text=True, check=True)
        # print(result.stdout)
        if result.stderr:
            print(f"Error output: {result.stderr}")
        else:
            return(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Command failed with error: {e}")
        print(f"Stderr: {e.stderr}")

r = Rhythm(
    measure_size=5,
    groups={1/3: 3},
)
motifs = [ r.motif() for x in range(4) ]
# print(motifs)

sc = scale.WholeToneScale('C4')
midinums = [ p.midi for p in sc.pitches ]

s = stream.Stream()
s.append(meter.TimeSignature('5/4'))

for m in motifs:
    length=len(m)
    p = pitch_phrase(length, midinums).split(',')
    for i, d in enumerate(m):
        n = note.Note(p[i])
        n.duration = duration.Duration(d)
        # print(n.duration.type)
        s.append(n)

s.show() # 'midi' opens Logic
