# ex: python midi-thread-5.py 'USB MIDI Interface' 'SE-02'

import sys
import random
import time
import threading
import mido
from music21 import pitch
from chord_progression_network import Generator
from music_melodicdevice import Device
from random_rhythms import Rhythm
from music_bassline_generator import Bassline

def midi_clock_thread():
    global note_outport, bass_outport, interval, stop_threads, clock_tick_event, clock_tick_count
    while not stop_threads:
        note_outport.send(mido.Message('clock'))
        bass_outport.send(mido.Message('clock'))
        clock_tick_count += 1
        # signal stream threads every beat
        if clock_tick_count % CLOCKS_PER_BEAT == 0:
            clock_tick_event.set()
        time.sleep(interval)

def midi_message(outport, channel, note, dura):
    v = velo()
    msg = mido.Message('note_on', note=note, velocity=v, channel=channel)
    outport.send(msg)
    time.sleep(dura)
    msg = mido.Message('note_off', note=note, velocity=v, channel=channel)
    outport.send(msg)

def note_stream_thread():
    global g, device, factor, note_outport, velocity, stop_threads, clock_tick_event
    while not stop_threads:
        clock_tick_event.wait() # wait for the next beat (PLL sync)
        clock_tick_event.clear()
        # msg = mido.Message('program_change', channel=0, program=91)
        # note_outport.send(msg)
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
                midi_message(note_outport, 0, p, d * factor)

def bass_stream_thread():
    global bass, factor, bass_outport, stop_threads, clock_tick_event
    while not stop_threads:
        clock_tick_event.wait() # wait for the next beat (PLL sync)
        clock_tick_event.clear()
        # msg = mido.Message('program_change', channel=1, program=43)
        # outport.send(msg)
        note = random.choice(list(scale_map.keys()))
        chord = note + scale_map[note]
        bassline = bass.generate(chord, 4)
        for n in bassline:
            midi_message(bass_outport, 0, n, factor)

if __name__ == "__main__":
    note_port_name = sys.argv[1] if len(sys.argv) > 1 else 'USB MIDI Interface'
    bass_port_name = sys.argv[2] if len(sys.argv) > 2 else 'SE-02'
    # kludge: duration multiplier to slow down the pace of the notes
    factor = sys.argv[3] if len(sys.argv) > 3 else 1
 
    bpm = 100 # for the clock
    velocity = 100
    scale_map = {
        'A': 'm',
        'C': '',
        'D': 'm',
        'E': 'm',
        'G': '',
    }
    size = len(scale_map) + 1
    transitions = [ i for i in range(1, size) ]
    weights = [ 1 for _ in range(1, size) ]
    g = Generator(
        scale_note='A',
        scale_name='aeolian',
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
    bass = Bassline(
        modal=True,
        tonic=False,
        resolve=False,
    )
    # signal the note_stream thread on each clock tick
    clock_tick_event = threading.Event()
    clock_tick_count = 0
    CLOCKS_PER_BEAT = 24
    interval = 60 / (bpm * CLOCKS_PER_BEAT) # time between clock messages at 24 PPQN per beat
    stop_threads = False

    chance = lambda: random.random() < 0.5
    velo = lambda: velocity + random.randint(-10, 10)

    with mido.open_output(note_port_name) as note_outport, mido.open_output(bass_port_name) as bass_outport:
        print(note_outport, bass_outport)
        clock_thread = threading.Thread(target=midi_clock_thread, daemon=True) # daemon = stops when main thread exits
        note_thread = threading.Thread(target=note_stream_thread, daemon=True)
        bass_thread = threading.Thread(target=bass_stream_thread, daemon=True)
        clock_thread.start()
        note_thread.start()
        bass_thread.start()
        note_outport.send(mido.Message('start'))
        bass_outport.send(mido.Message('start'))
        try:
            while True:
                time.sleep(interval) # keep main thread alive and respond to interrupts
        except KeyboardInterrupt:
            note_outport.send(mido.Message('stop'))
            bass_outport.send(mido.Message('stop'))
            print("\nSignaling threads to stop...")
            stop_threads = True
            clock_thread.join()
            note_thread.join()
            bass_thread.join()
            print("All threads stopped.")
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            note_outport.close()
            bass_outport.close()
