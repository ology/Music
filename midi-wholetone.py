"""
This program controls the QU-Bit Chord module through a multi-timbral MIDI-CV interface.

MIDI channel 0 = chord quality cv input
MIDI channel 1 = v/oct root note 

User chord type:
  harm: white = 12 user defined types
  0-3: 1, 4-9: 2, 10-14: 3, 15-19: 4, 20-24: 5, 25-29: 6,
  30-34: 7, 35-39: 8, 40-44: 9, 45-49: 10, 50-54: 11, 55+: 12

Here is a wholetone chord_config.txt example.
The chords can each have up to 4 pitches. (And the root 0 is assumed to be present).
The "#" comments below are for illustration only:

QUANTIZE_AUTOHARM=1  # RTFM
LONGFORM_USERBANK=0  # single-file waveforms or 8 x 8 banks
LFO_MODE=0           # 6 octaves below audible
LEAD_OFFSET=-1       # 0: default, 1: octave above, -1: octave below
CHORD_1=0,4,8
CHORD_2=2,6,10
CHORD_3=4,8,0
CHORD_4=6,10,2
CHORD_5=8,0,4
CHORD_6=10,2,6

"""

import sys
import mido
import random
import time
import threading
from music_voicegen import MusicVoiceGen

factor = 1/2 # duration multiplier
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
    global voice, stop_threads
    note_qualities = { # wholetones
        12: 0,
        14: 4,
        16: 10,
        18: 15,
        20: 20,
        22: 25,
    }
    while not stop_threads:
        pitch = voice.rand()
        quality = note_qualities[pitch]
        play_chord(quality, pitch, duration=4)

if __name__ == "__main__":
    pitches = [
        12, # C0
        14, # D
        16, # E
        18, # Gb
        20, # Ab
        22, # Bb
    ]
    voice = MusicVoiceGen(
        pitches=pitches,
        intervals=[-4,-2,2,4],
    )

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
