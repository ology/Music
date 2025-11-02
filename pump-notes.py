import mido
import random
import time
import sys
from music21 import pitch

def note_stream():
    notes = [ 60, 64, 67, 69 ]
    while True:
        phrase = [ random.choice(notes) for _ in range(16) ]
        for n in phrase:
            p = pitch.Pitch(n).midi
            if random.random() < (30 / 100):
                p -= 24
            elif random.random() < (60 / 100):
                p -= 12
            msg_on = mido.Message('note_on', note=p, velocity=100)
            outport.send(msg_on)
            time.sleep(4)
            msg_off = mido.Message('note_off', note=p, velocity=100)
            outport.send(msg_off)

if __name__ == "__main__":
    port_name = sys.argv[1] if len(sys.argv) > 1 else 'USB MIDI Interface'
    with mido.open_output(port_name) as outport:
        try:
            note_stream()
        except KeyboardInterrupt:
            print("\nStop!")
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            outport.close()
