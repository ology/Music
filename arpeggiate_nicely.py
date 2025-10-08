from chord_progression_network import Generator
from music_melodicdevice import Device
from music21 import duration, note, stream

s = stream.Score()
p = stream.Part()

weights = [ 1 for _ in range(1,5) ] # equal probability

g = Generator(
    max=4 * 4, # beats x measures
    net={
        1: [2,3,5,6],
        2: [1,3,5,6],
        3: [1,2,5,6],
        4: [],
        5: [1,2,3,6],
        6: [1,2,3,5],
        7: [],
    },
    weights={ i: weights for i in range(1,8) },
    resolve=False,
    substitute=False,
    verbose=False,
)
phrase = g.generate()

device = Device(verbose=False)

for i, ph in enumerate(phrase):
    arped = device.arp(ph, duration=1, arp_type='updown', repeats=1)
    for a in arped:
        n = note.Note(a[1])
        n.duration = duration.Duration(a[0])
        p.append(n)

s.append(p)
s.show('midi')
