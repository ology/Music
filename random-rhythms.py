from music21 import *
import random

sc1 = scale.WholeToneScale('C4')
# print(sc1.pitches)
sig = '5/4' # time signature
size = 5 # beats per measure

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
# durations = [ 2**x for x in range(-2, 3) ]
# Added triplet-eighth
durations = [ 1/4, 1/2, 1/3, 1, 2, 4 ]
# print(durations)
smallest = sorted(durations)[0]

groups = { 1/3: 3 }

sum = 0
motif = []
group_num = 0
group_item = 0

while sum < size:
    d = random.choice(durations)
    if group_num:
        group_num -= 1
        d = group_item
    else:
        if d in groups:
            group_num = groups[d] - 1
            group_item = d
        else:
            group_num = 0
            group_item = 0
    diff = size - sum
    if diff < smallest:
        if diff >=  0.03125:
            motif.append(diff)
        break
    if d > diff:
        continue
    sum += d
    if sum <= size:
        motif.append(d)

print(motif)

s = stream.Stream()
s.append(meter.TimeSignature(sig))

notes = []
for d in motif:
    k = random.choice(sc1.pitches)
    n = note.Note(k)
    n.duration = duration.Duration(d)
    # print(n.duration.type)
    s.append(n)

s.show() # 'midi' opens Logic
