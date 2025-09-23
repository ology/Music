from chord_progression_network import Generator
from music_melodicdevice import Device
from music21 import duration, note, stream

s = stream.Score()
p = stream.Part()

g = Generator(
    scale_name='whole-tone scale',
    net={
        1: [2,3,4,5,6],
        2: [1,3,4,5,6],
        3: [1,2,4,5,6],
        4: [1,2,3,5,6],
        5: [1,2,3,4,6],
        6: [1,2,3,4,5],
    },
    chord_map=['m'] * 6,
    substitute=True,
    verbose=False,
)
phrase = g.generate()

device = Device(verbose=False)

for i, ph in enumerate(phrase):
    arp_type = 'up' if i % 2 == 0 else 'down'
    arped = device.arp(ph, duration=1, arp_type=arp_type)
    for a in arped:
        n = note.Note(a[1])
        n.duration = duration.Duration(a[0])
        p.append(n)

s.append(p)
s.show()