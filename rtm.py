from music21 import pitch
import mido
import time
from chord_progression_network import Generator
from music_melodicdevice import Device

# print("Available MIDI output ports:")
# for port in mido.get_output_names():
#     print(port)
# output_port_name = mido.get_output_names()[0]
output_port_name = 'USB MIDI Interface'

weights = [ 1 for _ in range(1,6) ] # equal probability
g = Generator(
    max=4 * 6, # beats x measures
    scale_name='whole-tone scale',
    net={
        1: [2,3,4,5,6],
        2: [1,3,4,5,6],
        3: [1,2,4,5,6],
        4: [1,2,3,5,6],
        5: [1,2,3,4,6],
        6: [1,2,3,4,5],
    },
    weights={ i: weights for i in range(1,7) },
    chord_map=['7'] * 6, # set every chord to the same flavor (like '', 'm', '7')
    resolve=False,
    substitute=True,
    verbose=False,
)
phrase = g.generate()

device = Device(verbose=False)

bpm = 100

with mido.open_output(output_port_name) as outport:
    outport.send(mido.Message('start'))
    velocity = 100
    channel = 0
    for i, ph in enumerate(phrase):
        arped = device.arp(ph, duration=1, arp_type='updown', repeats=1)
        for a in arped:
            print(a)
            p = pitch.Pitch(a[1]).midi
            msg_on = mido.Message('note_on', note=p, velocity=velocity, channel=channel)
            outport.send(msg_on)
            time.sleep(a[0])
            msg_off = mido.Message('note_off', note=p, velocity=0, channel=channel)
            outport.send(msg_off)
