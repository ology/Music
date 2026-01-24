
import mido
import random
import sys
import threading
import time

from find_primes import all_primes
from music_creatingrhythms import Rhythms
from random_rhythms import Rhythm

def midi_clock_thread():
    global interval, stop_threads, clock_tick_event, clock_tick_count
    while not stop_threads:
        outport.send(mido.Message('clock'))
        clock_tick_count += 1
        # signal arp_stream thread every beat
        if clock_tick_count % clocks_per_beat == 0:
            clock_tick_event.set()
            time.sleep(0.001)  # Brief delay to ensure stream thread sees the set event
        time.sleep(interval)

def midi_msg(outport, event, note, channel, velocity):
    msg = mido.Message(event, note=note, channel=channel, velocity=velocity)
    outport.send(msg)

def fill(outport):
    global per_sec, drums, velo
    rr = Rhythm(
        measure_size=4,
        durations=[1, 1/2, 1/4],
        weights=[5, 10, 5],
        groups=[0, 0, 2]
    )
    motif = rr.motif()
    for duration in motif:
        midi_msg(outport, 'note_on', drums['snare']['num'], drums['snare']['chan'], velo())
        time.sleep(duration * per_sec * 0.9)
        midi_msg(outport, 'note_off', drums['snare']['num'], drums['snare']['chan'], 0)
        time.sleep(duration * per_sec * 0.1)

def adjust_kit(i, n):
    global r, patterns, drums, beats, random_note, primes
    p = random.choice(primes)
    patterns['hihat'] = r.euclid(p, beats)
    drums['snare']['num'] = random_note()
    if n % 2 == 0:
        patterns['snare'] = r.rotate_n(4, r.euclid(2, beats))
        patterns['kick'] = r.euclid(2, beats)
    else:
        patterns['snare'] = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,0]
        patterns['kick'] = [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1]
        drums['kick']['num'] = random_note()
        drums['hihat']['num'] = random_note()
    if i == 0 and n > 0:
        patterns['cymbals'] = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
        drums['cymbals']['num'] = random_note()
        patterns['hihat'][0] = 0
    else:
        patterns['cymbals'] = [0 for _ in range(beats)]

def stream_thread_fn():
    global outport, stop_threads, clock_tick_event, patterns, drums, beats, velo, N
    while not stop_threads:
        if clock_tick_event.wait(timeout=1.0):  # Add timeout to prevent hanging
            clock_tick_event.clear()
        else:
            continue  # Skip this iteration if timeout occurs
        for i in range(3):
            adjust_kit(i, N)

            for step in range(beats):
                for drum in ['kick', 'snare', 'hihat', 'cymbals']:
                    if patterns[drum][step]:
                        midi_msg(outport, 'note_on', drums[drum]['num'], drums[drum]['chan'], velo())
                
                time.sleep(dura * 0.9) # slightly shorter than step to prevent overlap

                for drum in ['kick', 'snare', 'hihat', 'cymbals']:
                    if patterns[drum][step]:
                        midi_msg(outport, 'note_off', drums[drum]['num'], drums[drum]['chan'], 0)

                time.sleep(dura * 0.1) # Remainder of the step duration

        fill(outport)
        N += 1

if __name__ == "__main__":
    bpm = int(sys.argv[1]) if len(sys.argv) > 1 else 120

    per_sec = 60.0 / bpm
    dura = per_sec / 4 # duration of one pattern step

    clock_tick_event = threading.Event() # signal the threads on each clock tick
    clock_tick_count = 0 # clock tick counter
    clocks_per_beat = 24 # clock ticks per beat
    interval = 60 / (bpm * clocks_per_beat) # time between clock messages at 24 PPQN per beat
    stop_threads = False

    drums = {
        'kick': {
            'num': 36, # Acoustic Bass Drum
            'chan': 0,
        },
        'snare': {
            'num': 38, # Acoustic Snare
            'chan': 1,
        },
        'hihat': {
            'num': 42, # Closed Hi-Hat
            'chan': 2,
        },
        'cymbals': {
            'num': 49, # Crash1
            'chan': 3,
        },
    }

    r = Rhythms()
    beats = 16
    patterns = {
        'kick': r.euclid(2, beats),
        'snare': r.rotate_n(4, r.euclid(2, beats)),
        'hihat': r.euclid(11, beats),
        'cymbals': [0 for _ in range(beats)],
    }

    velo = lambda: 64 + random.randint(-10, 10)
    random_note = lambda: random.choice([60,64,67]) - 24

    N = 0

    primes = all_primes(beats, 'list')

    with mido.open_output('MIDIThing2') as outport:
        print(outport)
        clock_thread = threading.Thread(target=midi_clock_thread, daemon=True) # daemon = stops when main thread exits
        stream_thread = threading.Thread(target=stream_thread_fn, daemon=True)
        clock_thread.start()
        stream_thread.start()
        outport.send(mido.Message('start'))
        try:
            while True:
                time.sleep(interval)
        except KeyboardInterrupt:
            outport.send(mido.Message('stop'))
            print("\nSignaling threads to stop...")
            stop_threads = True
            clock_thread.join()
            stream_thread.join()
            print("All threads stopped.")
            for c in [0,1,2,3]:
                msg = mido.Message('control_change', channel=c, control=123, value=0)
                outport.send(msg)
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            outport.close()
