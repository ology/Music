import sys
import mido
import random
import time
import threading
from music21 import pitch
from chord_progression_network import Generator
from music_melodicdevice import Device
from random_rhythms import Rhythm

factor = 2 # duration multiplier to slow down the pace
bpm = 100
velocity = 100
scale_map = {
    'C': '',
    'E': 'm',
    'F': '',
    'G': '',
    'A': 'm',
}
size = len(scale_map) + 1
transitions = [ i for i in range(1, size) ]
weights = [ 1 for _ in range(1, size) ]
g = Generator(
    max=4 * 1, # beats x measures
    tonic=False,
    resolve=False,
    scale=list(scale_map.keys()),
    chord_map=list(scale_map.values()),
    net={ i: transitions for i in range(1, size) },
    weights={ i: weights for i in range(1, size) },
    verbose=False,
)
device = Device(verbose=False)
r = Rhythm(
    measure_size=1,
    durations=[ 1/8, 1/4, 1/2, 1/3 ],
    groups={ 1/3: 3 },
)
# signal the note_stream thread on each clock tick
clock_tick_event = threading.Event()
# clock tick counter
clock_tick_count = 0
# clock ticks per beat
CLOCKS_PER_BEAT = 24
# time between clock messages at 24 PPQN per beat
interval = 60 / (bpm * CLOCKS_PER_BEAT)
stop_threads = False

chance = lambda: random.random() < 0.5

def midi_clock_thread():
    global interval, stop_threads, clock_tick_event, clock_tick_count
    while not stop_threads:
        outport.send(mido.Message('clock'))
        clock_tick_count += 1
        # signal note_stream thread every beat
        if clock_tick_count % CLOCKS_PER_BEAT == 0:
            clock_tick_event.set()
        time.sleep(interval)

def note_stream_thread():
    global g, device, factor, velocity, stop_threads, clock_tick_event
    while not stop_threads:
        clock_tick_event.wait() # wait for the next beat (PLL sync)
        clock_tick_event.clear()
        phrase = g.generate()
        transpose = chance()
        motif = r.motif()
        for ph in phrase:
            arped = device.arp(ph, duration=1, arp_type='updown', repeats=1)
            for i,d in enumerate(motif):
                p = pitch.Pitch(arped[i % len(arped)][1]).midi
                if transpose:
                    p -= 12
                    if chance():
                        p -= 12
                msg_on = mido.Message('note_on', note=p, velocity=velocity)
                outport.send(msg_on)
                time.sleep(d * factor)
                msg_off = mido.Message('note_off', note=p, velocity=velocity)
                outport.send(msg_off)

if __name__ == "__main__":
    port_name = sys.argv[1] if len(sys.argv) > 1 else 'USB MIDI Interface'
    with mido.open_output(port_name) as outport:
        print(outport)
        clock_thread = threading.Thread(target=midi_clock_thread, daemon=True) # daemon = stops when main thread exits
        note_thread = threading.Thread(target=note_stream_thread, daemon=True)
        clock_thread.start()
        note_thread.start()
        outport.send(mido.Message('start'))
        try:
            while True:
                time.sleep(interval) # keep main thread alive and respond to interrupts
        except KeyboardInterrupt:
            outport.send(mido.Message('stop'))
            print("\nSignaling threads to stop...")
            stop_threads = True
            clock_thread.join()
            note_thread.join()
            print("All threads stopped.")
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            outport.close()
