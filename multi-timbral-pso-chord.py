# This program is for driving a multi-timbral synth; in this case, a multi-oscillator eurorack.
# > python multi-timbral.py MIDIThing2

import sys
import random
import subprocess
import time
import threading
import mido
from music21 import pitch
from music_melodicdevice import Device
from random_rhythms import Rhythm
from music_bassline_generator import Bassline

def generate():
    command = ['perl', 'pso-chord.pl']
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        # print("STDOUT:", result.stdout)
        notes = result.stdout.split()
        notes = [ pitch.Pitch(n).midi for n in notes ]
        print(f"Notes: {notes}")
        # print("STDERR:", result.stderr)
        return [notes]
    except subprocess.CalledProcessError as e:
        print(f"Failed with return code {e.returncode}")
        print("STDOUT:", e.stdout)
        print("STDERR:", e.stderr)
    except FileNotFoundError:
        print("Error: Something went wrong.")

def midi_message(outport, channel, note, dura):
    v = velo()
    msg = mido.Message('note_on', note=note, velocity=v, channel=channel)
    outport.send(msg)
    time.sleep(dura)
    msg = mido.Message('note_off', note=note, velocity=v, channel=channel)
    outport.send(msg)

def midi_clock_thread():
    global phrase1, phrase2, interval, stop_threads, clock_tick_event, clock_tick_count
    while not stop_threads:
        outport.send(mido.Message('clock'))
        clock_tick_count += 1
        # signal stream threads every beat
        if clock_tick_count % clocks_per_beat == 0:
            clock_tick_event.set()
            phrase1 = generate()
            phrase2 = generate()
        time.sleep(interval)

def stream0_thread_fn():
    global phrase1, device, factor, outport, velocity, stop_threads, clock_tick_event
    channel = 0
    while not stop_threads:
        clock_tick_event.wait() # wait for the next beat (PLL sync)
        clock_tick_event.clear()
        msg = mido.Message('program_change', channel=channel, program=5)
        outport.send(msg)
        transpose = chance()
        motif = r.motif()
        for _ in range(4):
            for ph in phrase1:
                arped = device.arp(ph, duration=1, arp_type='updown', repeats=1)
                for i,d in enumerate(motif):
                    p = pitch.Pitch(arped[i % len(arped)][1]).midi
                    if transpose:
                        p -= 12
                        if chance():
                            p -= 12
                    midi_message(outport, channel, p, d * factor)

def stream1_thread_fn():
    global phrase2, melody, factor, outport, stop_threads, clock_tick_event
    channel = 1
    while not stop_threads:
        clock_tick_event.wait() # wait for the next beat (PLL sync)
        clock_tick_event.clear()
        msg = mido.Message('program_change', channel=channel, program=91)
        outport.send(msg)
        motif = r.motif()
        for _ in range(4):
            for ph in phrase2:
                arped = device.arp(ph, duration=1, arp_type='updown', repeats=1)
                for i,d in enumerate(motif):
                    p = pitch.Pitch(arped[i % len(arped)][1]).midi
                    midi_message(outport, channel, p, d * factor)

def stream2_thread_fn():
    global bass, factor, outport, stop_threads, clock_tick_event
    channel = 2
    while not stop_threads:
        clock_tick_event.wait() # wait for the next beat (PLL sync)
        clock_tick_event.clear()
        msg = mido.Message('program_change', channel=channel, program=43)
        outport.send(msg)
        note = random.choice(list(scale_map.keys()))
        chord = note + scale_map[note]
        bassline = bass.generate(chord, 1)
        print(f"Bass: {bassline}")
        for n in bassline:
            midi_message(outport, channel, n, factor)

if __name__ == "__main__":
    port_name = sys.argv[1] if len(sys.argv) > 1 else 'MIDIThing2'
    # kludge: duration multiplier to slow down the pace of the notes
    factor = int(sys.argv[2]) if len(sys.argv) > 2 else 2

    velocity = 64
    scale_map = {
        'C': '',
        'D': 'm',
        'E': 'm',
        'F': '',
        'G': '',
    }
    device = Device(verbose=False)
    r = Rhythm(
        measure_size=1,
        durations=[ 1/8, 1/4, 1/2 ],
        # groups={ 1/3: 3 },
    )
    bass = Bassline(
        modal=True,
        tonic=False,
        resolve=False,
    )
    melody = Bassline(
        octave=5,
        modal=True,
        tonic=False,
        resolve=False,
    )
    bpm = 60 # for the clock
    # signal the threads on each clock tick
    clock_tick_event = threading.Event()
    # clock tick counter
    clock_tick_count = 0
    # clock ticks per beat
    clocks_per_beat = 24
    # time between clock messages at 24 PPQN per beat
    interval = 60 / (bpm * clocks_per_beat)
    stop_threads = False

    phrase1 = [] # generated on each clock interval
    phrase2 = [] # "

    chance = lambda: random.random() < 0.5
    velo = lambda: velocity + random.randint(-20, 20)

    with mido.open_output(port_name) as outport:
        print(outport)
        clock_thread = threading.Thread(target=midi_clock_thread, daemon=True) # daemon = stops when main thread exits
        stream0_thread = threading.Thread(target=stream0_thread_fn, daemon=True)
        stream1_thread = threading.Thread(target=stream1_thread_fn, daemon=True)
        stream2_thread = threading.Thread(target=stream2_thread_fn, daemon=True)
        clock_thread.start()
        stream0_thread.start()
        stream1_thread.start()
        stream2_thread.start()
        outport.send(mido.Message('start'))
        try:
            while True:
                time.sleep(interval) # keep main thread alive and respond to interrupts
        except KeyboardInterrupt:
            outport.send(mido.Message('stop'))
            print("\nSignaling threads to stop...")
            stop_threads = True
            clock_thread.join()
            stream0_thread.join()
            stream1_thread.join()
            stream2_thread.join()
            print("All threads stopped.")
            msg = mido.Message('control_change', channel=0, control=123, value=0)
            outport.send(msg)
            msg = mido.Message('control_change', channel=1, control=123, value=0)
            outport.send(msg)
            msg = mido.Message('control_change', channel=2, control=123, value=0)
            outport.send(msg)
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            outport.close()
