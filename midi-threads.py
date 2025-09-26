import mido
import time
import threading
from music21 import pitch
from chord_progression_network import Generator
from music_melodicdevice import Device

bpm = 100
velocity = 100
# Calculate the time between clock messages (24 PPQN per beat)
interval = 60 / (bpm * 24)
g = Generator(
    max=4 * 1, # beats x measures
)

def midi_clock_thread():
    while True:
        outport.send(mido.Message('clock'))
        time.sleep(interval)

def note_stream_thread():
    while True:
        phrase = g.generate()
        device = Device(verbose=False)
        for ph in phrase:
            arped = device.arp(ph, duration=1, arp_type='updown', repeats=1)
            for a in arped:
                p = pitch.Pitch(a[1]).midi
                msg_on = mido.Message('note_on', note=p, velocity=velocity)
                outport.send(msg_on)
                time.sleep(a[0])
                msg_off = mido.Message('note_off', note=p, velocity=velocity)
                outport.send(msg_off)

if __name__ == "__main__":
    with mido.open_output('USB MIDI Interface') as outport:
        clock_thread = threading.Thread(target=midi_clock_thread, daemon=True) # daemon = stops when main thread exits
        # note_thread = threading.Thread(target=note_stream_thread)
        clock_thread.start()
        # note_thread.start()
        outport.send(mido.Message('start'))
        try:
            while True:
                time.sleep(0.5) # keep main thread alive and respond to interrupts
        except KeyboardInterrupt:
            print("\nKeyboardInterrupt detected. Signaling threads to stop...")
            # note_thread.join()
            print("All threads stopped. Main program exiting.")
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            outport.send(mido.Message('stop'))
            outport.close()
