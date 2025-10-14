from chord_progression_network import Generator
from music_melodicdevice import Device
from music21 import duration, note, stream, tempo

s = stream.Score()
p = stream.Part()

weights = [ 1 for _ in range(1,5) ] # equal probability

g = Generator(
    max=4,
    net={
        1: [3,4,5,6],
        2: [],
        3: [1,4,5,6],
        4: [1,3,5,6],
        5: [1,3,4,6],
        6: [1,3,4,5],
        7: [],
    },
    weights={ i: weights for i in range(1,8) },
    tonic=False,
    resolve=False,
    verbose=False,
)

device = Device(verbose=False)

for i in range(1800):
    phrase = g.generate()
    for chord in phrase:
        arped = device.arp(chord, duration=1, arp_type='updown', repeats=1)
        for a in arped:
            n = note.Note(a[1])
            n.duration = duration.Duration(a[0])
            p.append(n)

s.append(tempo.MetronomeMark(number=10))
s.append(p)
s.show('midi')
