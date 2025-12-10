"""
This program controls the QU-Bit Chord module through a multi-timbral MIDI-CV interface.

MIDI channel 0 = chord quality cv input
MIDI channel 1 = v/oct root note 

Default quality:
  harm: blue = default qualities
  0-5: maj, 6-13: min, 14-21: dom, 22-28: dim*, 29-36: dim,
  37-43: sus*, 44-51: sus, 52+: aug

User chord type:
  harm: white = 12 user defined types
  0-3: 1, 4-9: 2, 10-14: 3, 15-19: 4, 20-24: 5, 25-29: 6,
  30-34: 7, 35-39: 8, 40-44: 9, 45-49: 10, 50-54: 11, 55+: 12

Here is a chord_config.txt example, where 5 of 12 user chord types are defined.
The chords can each have up to 4 pitches. (And the root 0 is assumed to be present).
The "#" comments below are for illustration only:

QUANTIZE_AUTOHARM=1  # RTFM
LONGFORM_USERBANK=0  # single-file waveforms or 8 x 8 banks
LFO_MODE=0           # 6 octaves below audible
LEAD_OFFSET=-1       # 0: default, 1: octave above, -1: octave below
CHORD_1=4,7,11       # maj7
CHORD_2=3,7,10       # min7
CHORD_3=7            # 5 no 3
CHORD_4=4,7,9        # 6th
CHORD_5=5,7          # sus4

"""

import sys
import mido
import random
import time
import threading

factor = 2 # duration multiplier
# time between clocks at 24 PPQN per beat and 100 BPM
interval = 60 / (100 * 24)
stop_threads = False # should I stay or should I go?

def play_chord(quality, note, velocity=127, duration=1):
    msg = mido.Message('note_on', note=quality, channel=0, velocity=velocity)
    outport.send(msg)
    msg = mido.Message('note_on', note=quality, channel=1, velocity=velocity)
    outport.send(msg)
    time.sleep(duration * factor)
    msg = mido.Message('note_off', note=note, channel=0, velocity=velocity)
    outport.send(msg)
    msg = mido.Message('note_off', note=note, channel=1, velocity=velocity)
    outport.send(msg)

def note_stream_thread():
    global stop_threads
    note_qualities = {
        60: 'maj7',
        62: 'm7',
        64: 'm7',
        65: 'maj7',
        67: 'maj7',
        69: 'm7',
        71: 'm7',
    }
    quality_volts = {
        'maj7': 0,
        'm7': 4,
        '5th': 10,
        '6th': 15,
        'sus4': 20,
    }
    subset = {
        '5th': 10,
        '6th': 15,
        'sus4': 20,
    }
    while not stop_threads:
        note = random.choice(list(note_qualities.keys()))
        if random.random() < 0.5:
            quality = quality_volts[note_qualities[note]]
        else:
            quality = random.choice(list(subset.values()))
        play_chord(quality, note, duration=4)

if __name__ == "__main__":
    port_name = sys.argv[1] if len(sys.argv) > 1 else 'MIDIThing2'
    with mido.open_output(port_name) as outport:
        print(outport)
        note_thread = threading.Thread(target=note_stream_thread, daemon=True)
        note_thread.start()
        outport.send(mido.Message('start'))
        try:
            while True:
                time.sleep(interval) # keep main thread alive and respond to interrupts
        except KeyboardInterrupt:
            outport.send(mido.Message('stop'))
            print("\nSignaling threads to stop...")
            stop_threads = True
            note_thread.join()
            print("All threads stopped.")
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            outport.close()
