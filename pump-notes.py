import mido
import random
import time
import threading
from music21 import pitch

def note_stream_thread():
    notes = [ i for i in range(60, 73)]
    phrase = [ random.choice(notes) for _ in range(16) ]
    while True:
        for n in phrase:
            p = pitch.Pitch(n).midi
            msg_on = mido.Message('note_on', note=p, velocity=100)
            outport.send(msg_on)
            time.sleep(0.2)
            msg_off = mido.Message('note_off', note=p, velocity=100)
            outport.send(msg_off)

if __name__ == "__main__":
    with mido.open_output('USB MIDI Interface') as outport:
        print(outport)
        note_thread = threading.Thread(target=note_stream_thread, daemon=True)
        note_thread.start()
        outport.send(mido.Message('start'))
        try:
            while True:
                time.sleep(0.5) # keep main thread alive and respond to interrupts
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
