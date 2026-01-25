
import mido
import random
import time
import threading

from find_primes import all_primes
from music_creatingrhythms import Rhythms
from random_rhythms import Rhythm

def midi_msg(outport, event, note, channel, velocity):
    msg = mido.Message(event, note=note, channel=channel, velocity=velocity)
    outport.send(msg)

def midi_clock_generator(out_port_name, bpm, run_event):
    try:
        with mido.open_output(out_port_name) as midi_output:
            print(f"Starting MIDI clock at {bpm} BPM on {out_port_name}")
            clock_tick = mido.Message('clock')
            # time interval between pulses at 24 pulses per quarter note
            pulse_rate = 60.0 / (bpm * 24)
            while run_event.is_set():
                start_time = time.perf_counter()
                midi_output.send(clock_tick)
                elapsed = time.perf_counter() - start_time
                if elapsed < pulse_rate:
                    time.sleep(pulse_rate - elapsed)

    except IOError as e:
        print(f"Error opening MIDI port: {e}")
    except KeyboardInterrupt:
        print("MIDI clock stopped by user")

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

def drum_pattern_player(out_port_name, run_event):
    global N
    try:
        with mido.open_output(out_port_name) as midi_output:
            print(f"Starting drum pattern on {out_port_name}")
            while run_event.is_set():
                for i in range(3):
                    adjust_kit(i, N) # set notes and patterns

                    for step in range(beats):
                        for drum in voices:
                            if patterns[drum][step]:
                                midi_msg(midi_output, 'note_on', drums[drum]['num'], drums[drum]['chan'], velo())
                        
                        time.sleep(dura * 0.9) # slightly shorter than step to prevent overlap

                        for drum in voices:
                            if patterns[drum][step]:
                                midi_msg(midi_output, 'note_off', drums[drum]['num'], drums[drum]['chan'], 0)

                        time.sleep(dura * 0.1) # Remainder of the step duration

                fill(midi_output)
                N += 1

    except IOError as e:
        print(f"Error opening MIDI port: {e}")

if __name__ == '__main__':
    target_port_name = 'MIDIThing2'
    tempo_bpm = 120

    per_sec = 60.0 / tempo_bpm
    dura = per_sec / 4 # duration of one pattern step

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
    voices = list(drums.keys())
    chans = [ i['chan'] for i in drums.values() ]

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

    run_event = threading.Event()
    run_event.set()
    
    clock_counter = { 'count': 0 }

    clock_thread = threading.Thread(target=midi_clock_generator, args=(target_port_name, tempo_bpm, run_event))
    drum_thread = threading.Thread(target=drum_pattern_player, args=(target_port_name, run_event))
    
    clock_thread.start()
    drum_thread.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Stopping script...")
        run_event.clear()
        clock_thread.join()
        drum_thread.join()
        print("Script stopped.")
