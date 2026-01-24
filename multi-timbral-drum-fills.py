"""
Play Euclidean patterns and snare fills with no clock.
"""

import mido
import random
import sys
import time

from find_primes import all_primes
from music_creatingrhythms import Rhythms
from random_rhythms import Rhythm

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

def drum_part():
    global patterns, drums, beats, velo, N, voices, chans
    try:
        while True:
            for i in range(3):
                adjust_kit(i, N) # set notes and patterns

                for step in range(beats):
                    for drum in voices:
                        if patterns[drum][step]:
                            midi_msg(outport, 'note_on', drums[drum]['num'], drums[drum]['chan'], velo())
                    
                    time.sleep(dura * 0.9) # slightly shorter than step to prevent overlap

                    for drum in voices:
                        if patterns[drum][step]:
                            midi_msg(outport, 'note_off', drums[drum]['num'], drums[drum]['chan'], 0)

                    time.sleep(dura * 0.1) # Remainder of the step duration

            fill(outport)
            N += 1
    except KeyboardInterrupt:
        for c in chans:
            msg = mido.Message('control_change', channel=c, control=123, value=0)
            outport.send(msg)
        outport.close()
        print("\nDrum machine stopped.")

if __name__ == "__main__":
    bpm = int(sys.argv[1]) if len(sys.argv) > 1 else 120 # XXX actual = 115

    per_sec = 60.0 / bpm
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

    try:
        with mido.open_output('MIDIThing2') as outport:
            print(f"Opened output port: {outport.name}")
            print("Drum machine running... Ctrl+C to stop.")
            drum_part()
    except mido.PortUnavailableError as e:
        print(f"Error: {e}")