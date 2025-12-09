# This program controls the QU-Bit Chord module through a MIDI-CV interface.
# MIDI channel 0 = chord quality cv input
# MIDI channel 1 = v/oct root note 
#
# Default quality:
# harm: blue = default 4 qualities
# 0-5: maj, 6-13: min, 14-21: dom, 22-28: dim*, 29-36: dim,
# 37-43: sus*, 44-51: sus, 52+: aug
#
# User chord type:
# harm: white = user 12 types
# 0-3: 1, 4-9: 2, 10-14: 3, 15-19: 4, 20-24: 5, 25-29: 6,
# 30-34: 7, 35-39: 8, 40-44: 9, 45-49: 10, 50-54: 11, 55+: 12

import sys
import mido
import random
import time
import threading

factor = 2 # duration divider
# time between clock messages at 24 PPQN per beat and 100 BPM
interval = 60 / (100 * 24)
stop_threads = False # should I stay or should I go?

def play_chord(quality, note, velocity=100, duration=1):
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
        # 62: 'm7',
        64: 'm7',
        # 65: 'maj7',
        67: 'maj7',
        69: 'm7',
        # 71: 'm7',
    }
    quality_volts = {
        'maj7': 10,
        'm7': 15,
        'sus4': 20,
        '5th': 25,
        '6th': 30,
    }
    note = random.choice(list(note_qualities.keys()))
    while not stop_threads:
        play_chord(quality_volts[note_qualities[note]], note, duration=4)

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
