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

# time between clock messages at 24 PPQN per beat
interval = 60 / (100 * 24)
stop_threads = False # should I stay or should I go?

def note_stream_thread():
    global bpm, stop_threads
    p = 0
    while not stop_threads:
        print(p)
        msg_on = mido.Message('note_on', note=p + 60, channel=0, velocity=100)
        outport.send(msg_on)
        msg_on = mido.Message('note_on', note=p, channel=1, velocity=100)
        outport.send(msg_on)
        time.sleep(1)
        msg_off = mido.Message('note_off', note=p + 60, channel=0, velocity=100)
        outport.send(msg_off)
        msg_off = mido.Message('note_off', note=p, channel=1, velocity=100)
        outport.send(msg_off)
        p = p + 1

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
