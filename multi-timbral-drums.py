
import mido
import random
import sys
import time

from find_primes import all_primes
from music_creatingrhythms import Rhythms

def run_drum_machine(port_name):
    global PATTERNS, DRUMS, step_duration, beats, N
    try:
        with mido.open_output(port_name) as outport:
            print(f"Opened output port: {outport.name}")
            print("Drum machine running... Ctrl+C to stop.")
            try:
                while True:
                    primes = all_primes(beats, 'list')
                    p = random.choice(primes)
                    PATTERNS['hihat'] = r.euclid(p, beats)
                    if N % 2 == 0:
                        PATTERNS['kick'] = r.euclid(2, beats)
                    else:
                        PATTERNS['kick'] = [1,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0]
                        DRUMS['kick'] = random.choice([60,64,67,71]) - 12
                    for step in range(16):
                        if PATTERNS['kick'][step]:
                            msg = mido.Message('note_on', note=DRUMS['kick'], velocity=90, channel=0)
                            outport.send(msg)
                        if PATTERNS['snare'][step]:
                            msg = mido.Message('note_on', note=DRUMS['snare'], velocity=90, channel=1)
                            outport.send(msg)
                        if PATTERNS['hihat'][step]:
                            msg = mido.Message('note_on', note=DRUMS['hihat'], velocity=70, channel=2)
                            outport.send(msg)
                        
                        time.sleep(step_duration * 0.9) # slightly shorter than step to prevent overlap

                        if PATTERNS['kick'][step]:
                            msg = mido.Message('note_off', note=DRUMS['kick'], velocity=0, channel=0)
                            outport.send(msg)
                        if PATTERNS['snare'][step]:
                            msg = mido.Message('note_off', note=DRUMS['snare'], velocity=0, channel=1)
                            outport.send(msg)
                        if PATTERNS['hihat'][step]:
                            msg = mido.Message('note_off', note=DRUMS['hihat'], velocity=0, channel=2)
                            outport.send(msg)

                        time.sleep(step_duration * 0.1) # Remainder of the step duration
                    N += 1
            except KeyboardInterrupt:
                print("\nDrum machine stopped.")
    except mido.PortUnavailableError as e:
        print(f"Error: {e}")
        print("Check your virtual MIDI port setup and names")

if __name__ == "__main__":
    BPM = 100
    step_duration = 60.0 / BPM / 4 # duration for one step in pattern

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

    N = 0

    try:
        run_drum_machine('MIDIThing2')
    except IndexError:
        print("No MIDI output ports found.")
        sys.exit(1)
