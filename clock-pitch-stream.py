import mido
import time
import threading
from music21 import pitch
from chord_progression_network import Generator
from music_melodicdevice import Device

midi_port = 'USB MIDI Interface'
bpm = 100
velocity = 120
interval = (60 / bpm) / 24 # 24 clock messages per quarter note

try:
    outport = mido.open_output(midi_port)
except Exception as e:
    print(f"Error opening MIDI port: {e}")
    exit()

def midi_clock_thread():
    while True:
        outport.send(mido.Message('clock'))
        time.sleep(interval)

def note_stream_thread():
    # weights = [ 1 for _ in range(1,6) ] # equal probability
    g = Generator(
        max=4 * 8, # beats x measures
        # scale_name='whole-tone scale',
        # net={
        #     1: [2,3,4,5,6],
        #     2: [1,3,4,5,6],
        #     3: [1,2,4,5,6],
        #     4: [1,2,3,5,6],
        #     5: [1,2,3,4,6],
        #     6: [1,2,3,4,5],
        # },
        # weights={ i: weights for i in range(1,7) },
        # chord_map=[''] * 6, # set every chord to the same flavor (like '', 'm', '7')
        # resolve=False,
        # substitute=True,
        # verbose=False,
    )
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
            # time.sleep(0.1) # delay between notes

if __name__ == "__main__":
    clock_thread = threading.Thread(target=midi_clock_thread, daemon=True) # daemon = stops when main thread exits
    note_thread = threading.Thread(target=note_stream_thread)
    clock_thread.start()
    note_thread.start()
    note_thread.join() # wait for the note stream to finish
    outport.close()