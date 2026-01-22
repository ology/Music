
import mido
import random
import sys
import time

from find_primes import all_primes
from music_creatingrhythms import Rhythms

def midi_msg(outport, event, note, channel, velocity):
    msg = mido.Message(event, note=note, channel=channel, velocity=velocity)
    outport.send(msg)

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
                        PATTERNS['kick'] = [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1]
                        DRUMS['kick'] = random_note()
                        DRUMS['hihat'] = random_note()
                    for step in range(16):
                        if PATTERNS['kick'][step]:
                            midi_msg(outport, 'note_on', DRUMS['kick'], 0, velo())
                        if PATTERNS['snare'][step]:
                            midi_msg(outport, 'note_on', DRUMS['snare'], 1, velo())
                        if PATTERNS['hihat'][step]:
                            midi_msg(outport, 'note_on', DRUMS['hihat'], 2, velo())
                        
                        time.sleep(dura * 0.9) # slightly shorter than step to prevent overlap

                        if PATTERNS['kick'][step]:
                            midi_msg(outport, 'note_off', DRUMS['kick'], 0, 0)
                        if PATTERNS['snare'][step]:
                            midi_msg(outport, 'note_off', DRUMS['snare'], 1, 0)
                        if PATTERNS['hihat'][step]:
                            midi_msg(outport, 'note_off', DRUMS['hihat'], 2, 0)

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
