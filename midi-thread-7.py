# Constrol two synths on the first and second MIDI channels, respectively.
# ex: python midi-thread-7.py 'USB MIDI Interface' 'SE-02'

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
    global synth1_outport, synth2_outport, interval, stop_threads, clock_tick_event, clock_tick_count
    while not stop_threads:
        synth1_outport.send(mido.Message('clock'))
        synth2_outport.send(mido.Message('clock'))
        clock_tick_count += 1
        # signal stream threads every beat
        if clock_tick_count % clocks_per_beat == 0:
            clock_tick_event.set()
        time.sleep(interval)

def midi_message(outport, note, channel=0, dura=1):
    v = velo()
    msg = mido.Message('note_on', note=note, velocity=v, channel=channel)
    outport.send(msg)
    time.sleep(dura)
    msg = mido.Message('note_off', note=note, velocity=v, channel=channel)
    outport.send(msg)

def synth1_stream_thread(program=None, bank=6, prog=8):
    global g, device, factor, synth1_outport, velocity, stop_threads, clock_tick_event
    if program is None:
        program = int(str(bank - 1) + str(prog - 1), 8) # 8x8 bank x program
    msg = mido.Message('program_change', channel=0, program=program)
    synth1_outport.send(msg)
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
                midi_message(synth1_outport, p, 0, d * factor)

def synth2_stream_thread(program=44, bank=None, prog=None):
    global bass, factor, synth2_outport, stop_threads, clock_tick_event
    if program is None:
        program = int(str(bank - 1) + str(prog - 1), 8) # 8x8 bank x program
    msg = mido.Message('program_change', channel=1, program=program)
    synth2_outport.send(msg)
    while not stop_threads:
        clock_tick_event.wait() # wait for the next beat (PLL sync)
        clock_tick_event.clear()
        note = random.choice(list(scale_map.keys()))
        chord = note + scale_map[note]
        bassline = bass.generate(chord, 4)
        for n in bassline:
            midi_message(synth2_outport, n, 1, factor)

if __name__ == "__main__":
    synth1_port_name = sys.argv[1] if len(sys.argv) > 1 else 'USB MIDI Interface'
    synth2_port_name = sys.argv[2] if len(sys.argv) > 2 else 'SE-02'
    factor           = sys.argv[3] if len(sys.argv) > 3 else 2

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

    # signal the synth1_stream thread on each clock tick
    clock_tick_event = threading.Event()
    clock_tick_count = 0
    bpm = 100 # for the clock
    clocks_per_beat = 24
    interval = 60 / (bpm * clocks_per_beat) # time between clock messages at 24 PPQN per beat
    stop_threads = False
    velocity = 100

    chance = lambda: random.random() < 0.5
    velo = lambda: velocity + random.randint(-10, 10)

    with mido.open_output(synth1_port_name) as synth1_outport, mido.open_output(synth2_port_name) as synth2_outport:
        print(synth1_outport, synth2_outport)
        clock_thread = threading.Thread(target=midi_clock_thread, daemon=True) # daemon = stops when main thread exits
        synth1_thread = threading.Thread(target=synth1_stream_thread, daemon=True)
        synth2_thread = threading.Thread(target=synth2_stream_thread, daemon=True)
        clock_thread.start()
        synth1_thread.start()
        synth2_thread.start()
        try:
            while True:
                time.sleep(interval) # keep main thread alive and respond to interrupts
        except KeyboardInterrupt:
            print("\nSignaling threads to stop...")
            stop_threads = True
            clock_thread.join()
            synth1_thread.join()
            synth2_thread.join()
            print("All threads stopped.")
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            synth1_outport.close()
            synth2_outport.close()
