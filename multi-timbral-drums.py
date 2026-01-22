
import mido
import random
import sys
import time

from find_primes import all_primes
from music_creatingrhythms import Rhythms

def run_drum_machine(port_name):
    global PATTERNS, DRUMS, dura, beats, N, velo, primes
    try:
        with mido.open_output(port_name) as outport:
            print(f"Opened output port: {outport.name}")
            print("Drum machine running... Ctrl+C to stop.")
            try:
                while True:
                    p = random.choice(primes)
                    PATTERNS['hihat'] = r.euclid(p, beats)
                    DRUMS['snare'] = random_note()
                    if N % 2 == 0:
                        PATTERNS['kick'] = r.euclid(2, beats)
                    else:
                        PATTERNS['kick'] = [1,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0]
                        DRUMS['kick'] = random_note()
                        DRUMS['hihat'] = random_note()
                    for step in range(16):
                        if PATTERNS['kick'][step]:
                            v = velo()
                            msg = mido.Message('note_on', note=DRUMS['kick'], velocity=v, channel=0)
                            outport.send(msg)
                        if PATTERNS['snare'][step]:
                            v = velo()
                            msg = mido.Message('note_on', note=DRUMS['snare'], velocity=v, channel=1)
                            outport.send(msg)
                        if PATTERNS['hihat'][step]:
                            v = velo()
                            msg = mido.Message('note_on', note=DRUMS['hihat'], velocity=v, channel=2)
                            outport.send(msg)
                        
                        time.sleep(dura * 0.9) # slightly shorter than step to prevent overlap

                        if PATTERNS['kick'][step]:
                            msg = mido.Message('note_off', note=DRUMS['kick'], velocity=0, channel=0)
                            outport.send(msg)
                        if PATTERNS['snare'][step]:
                            msg = mido.Message('note_off', note=DRUMS['snare'], velocity=0, channel=1)
                            outport.send(msg)
                        if PATTERNS['hihat'][step]:
                            msg = mido.Message('note_off', note=DRUMS['hihat'], velocity=0, channel=2)
                            outport.send(msg)

                        time.sleep(dura * 0.1) # Remainder of the step duration
                    N += 1
            except KeyboardInterrupt:
                print("\nDrum machine stopped.")
    except mido.PortUnavailableError as e:
        print(f"Error: {e}")
        print("Check your virtual MIDI port setup and names")

if __name__ == "__main__":
    BPM = 70
    dura = 60.0 / BPM / 4 # duration for one step in pattern

    DRUMS = {
        'kick': 36,  # Acoustic Bass Drum
        'snare': 38, # Acoustic Snare
        'hihat': 42  # Closed Hi-Hat
    }

    r = Rhythms()
    beats = 16
    PATTERNS = {
        'kick': r.euclid(2, beats),
        'snare': r.rotate_n(4, r.euclid(2, beats)),
        'hihat': r.euclid(11, beats),
    }

    velocity = 64
    velo = lambda: velocity + random.randint(-10, 10)
    random_note = lambda: random.choice([60,64,67,71]) - 12

    N = 0

    primes = all_primes(beats, 'list')

    try:
        run_drum_machine('MIDIThing2')
    except IndexError:
        print("No MIDI output ports found.")
        sys.exit(1)
