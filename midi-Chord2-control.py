# This program controls the QU-Bit Chord module through a MIDI-CV interface.
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
import time
import threading

factor = 1/4 # duration divider
# time between clock messages at 24 PPQN per beat and 100 BPM
interval = 60 / (100 * 24)
stop_threads = False # should I stay or should I go?

def play_chord(quality, note, velocity=100, duration=1):
    quality_volts = {
        'maj7': 0,
        'm7': 4,
        '7': 10,
        'half-dim': 15,
        'dim7': 20,
        '7#5': 25,
        '6': 30,
        '7b9': 35,
        '7b5': 40,
        'Mm7': 45,
        '7#9': 50,
        'augM7': 55,
    }
    msg = mido.Message('note_on', note=quality_volts[quality], channel=0, velocity=velocity)
    outport.send(msg)
    msg = mido.Message('note_on', note=quality_volts[quality], channel=1, velocity=velocity)
    outport.send(msg)
    time.sleep(duration * factor)
    msg = mido.Message('note_off', note=note, channel=0, velocity=velocity)
    outport.send(msg)
    msg = mido.Message('note_off', note=note, channel=1, velocity=velocity)
    outport.send(msg)

def note_stream_thread():
    global stop_threads
    i = 0
    while not stop_threads:
        play_chord('maj7', 49, duration=4)
        play_chord('maj7', 49, duration=1)
        play_chord('maj7', 49, duration=1)
        play_chord('m7', 46, duration=2)
        play_chord('7', 51, duration=4)
        play_chord('7', 51, duration=4)
        play_chord('m7', 51, duration=4)
        play_chord('7', 44, duration=4)
        play_chord('maj7', 49, duration=4)
        if i % 2 == 0:
            play_chord('maj7', 49, duration=2)
            play_chord('7', 49, duration=2)
        else:
            play_chord('7#5', 45, duration=2)
            play_chord('7', 44, duration=2)

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
