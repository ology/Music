
import mido
import time
import sys

from music_creatingrhythms import Rhythms

def run_drum_machine(port_name):
    try:
        with mido.open_output(port_name) as outport:
            print(f"Opened output port: {outport.name}")
            print("Drum machine running... Press Ctrl+C to stop.")
            try:
                while True:
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
            except KeyboardInterrupt:
                print("\nDrum machine stopped.")
    except mido.PortUnavailableError as e:
        print(f"Error: {e}")
        print("Check your virtual MIDI port setup and names")

if __name__ == "__main__":
    BPM = 100
    # time duration for one step in pattern
    step_duration = 60.0 / BPM / 4

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
    try:
        run_drum_machine('MIDIThing2')
    except IndexError:
        print("No MIDI output ports found.")
        sys.exit(1)
