import sys
import time
import mido
from music_creatingrhythms import Rhythms

def play_midi(sequence):
    snare = 40
    channel = 9
    for bit in sequence:
        if bit == 1:
            msg = mido.Message('note_on', note=snare, channel=channel, velocity=100)
            port.send(msg)
            time.sleep(0.25)
            msg = mido.Message('note_off', note=snare, channel=channel, velocity=0)
            port.send(msg)
        else: # rest
            time.sleep(0.25)

if __name__ == '__main__':
    port_name = sys.argv[1] if len(sys.argv) > 1 else 'USB MIDI'
    port = mido.open_output(port_name)

    r = Rhythms()

    parts = r.part(5)
    # [[1, 1, 1, 1, 1], [1, 1, 1, 2], [1, 1, 3], [1, 2, 2], [1, 4], [2, 3], [5]]
    p = parts[2] # [1, 1, 3]
    seq = r.int2b([p]) # [[1, 1, 1, 0, 0]]

    for _ in range(4):
        play_midi(seq[0])
