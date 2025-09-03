from music21 import *
import random

scale = ['C','D','E','F','G','A','B']
octave = 4
sig = '7/8' # time signature
size = 3.5 # beats per measure

# 128th to 128: .03125 .0625 .125 .25 .5 1 2 4 8 16 32 64 128
# durations = [2**x for x in range(-5, 8)]
# 16th to 16th: .25 .5 1 2 4 8 16
# durations = [2**x for x in range(-2, 5)]
# Triplets: .167 .333 .667 1.333 2.667
# durations = [2**x/3 for x in range(-1, 4)]
# Dotted: .375 .75 1.5 3 6
# durations = [2**x+2**x/2 for x in range(-2, 3)]
# Double dotted: .4375 .875 1.75 3.5 7
# durations = [2**x+2**x/2+2**x/4 for x in range(-2, 3)]
# 16th to whole: .25 .5 1 2 4
durations = [ 2**x for x in range(-2, 3) ]
# print(durations)
smallest = sorted(durations)[0]

sum = 0
motif = []

while sum < size:
    d = random.choice(durations)
    # print(f"d: {d}")
    diff = size - sum
    # print(f"diff: {diff}")
    if diff < smallest:
        motif.append(diff)
        break
    if d > diff:
        continue
    sum += d
    # print(f"sum: {sum}")
    if sum <= size:
        motif.append(d)

print(motif)

s1 = stream.Stream()
ts1 = meter.TimeSignature(sig)
s1.append(ts1)

notes = []
for d in motif:
    k = random.choice(scale)
    n = note.Note(k, octave=octave)
    n.duration = duration.Duration(d)
    # print(n.duration.type)
    s1.append(n)

s1.show()
