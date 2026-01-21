# This program is for driving my modular drum kit...

import sys
import random
import time
import threading
import mido
from music21 import pitch
from music_creatingrhythms import Rhythms

def midi_message(outport, channel, note, dura):
    v = velo()
    msg = mido.Message('note_on', note=note, velocity=v, channel=channel)
    outport.send(msg)
    time.sleep(dura)
    msg = mido.Message('note_off', note=note, velocity=v, channel=channel)
    outport.send(msg)

def midi_clock_thread():
    global interval, stop_threads, clock_tick_event, clock_tick_count, n
    while not stop_threads:
        outport.send(mido.Message('clock'))
        clock_tick_count += 1
        # signal stream threads every beat
        if clock_tick_count % CLOCKS_PER_BEAT == 0:
            n += 1
            clock_tick_event.set()
        time.sleep(interval)

def stream0_thread_fn():
    global outport, beats, n, kick, stop_threads, clock_tick_event
    while not stop_threads:
        clock_tick_event.wait(timeout=0.1)
        if stop_threads:
            break
        if kick[ n % beats ] == 1:
            midi_message(outport, 0, 60, 1)
        clock_tick_event.clear()

def stream1_thread_fn():
    global outport, beats, n, snare, stop_threads, clock_tick_event
    while not stop_threads:
        clock_tick_event.wait(timeout=0.1)
        if stop_threads:
            break
        if snare[ n % beats ] == 1:
            midi_message(outport, 1, 64, 1)
        clock_tick_event.clear()

def stream2_thread_fn():
    global outport, beats, n, hihat, stop_threads, clock_tick_event
    while not stop_threads:
        clock_tick_event.wait(timeout=0.1)
        if stop_threads:
            break
        if hihat[ n % beats ] == 1:
            midi_message(outport, 2, 67, 1)
        clock_tick_event.clear()

if __name__ == "__main__":
    port_name = sys.argv[1] if len(sys.argv) > 1 else 'MIDIThing2'

    r = Rhythms()
    beats = 16
    kick =  r.euclid(2, beats)
    snare = r.rotate_n(4, r.euclid(2, beats))
    hihat = r.euclid(11, beats)
    n = 0

    bpm = 500 # for the clock
    # signal the threads on each clock tick
    clock_tick_event = threading.Event()
    # clock tick counter
    clock_tick_count = 0
    # clock ticks per beat
    CLOCKS_PER_BEAT = 24
    # time between clock messages at 24 PPQN per beat
    interval = 60 / (bpm * CLOCKS_PER_BEAT)
    stop_threads = False

    velocity = 64
    velo = lambda: velocity + random.randint(-10, 10)

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
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            outport.close()
