#!/usr/bin/env python3

import sys
from random import randint

from music_drummer import Drummer
from random_rhythms import Rhythm

def part(name, note, pool):
    global size, drummer
    rr = Rhythm(
        measure_size=size,
        durations=pool,
    )
    motif = rr.motif()
    print(f"{name}: {motif}")
    for _ in range(drummer.beats - 1):
        for duration in motif:
            drummer.note(note, duration=duration)
    drummer.rest(note, duration=4)

def hihat():
    global drummer
    for _ in range(drummer.beats):
        part('Hihat', 'closed', [1, 0.5])

def kick():
    global drummer
    for _ in range(drummer.beats):
        part('Kick', 'kick', [2, 1.5, 1, 0.5])

def snare():
    global size, drummer
    for _ in range(drummer.beats):
        i = randint(0, 1)
        print(f"Snare toggle: {i}")
        for _ in range(drummer.beats - 1):
            for n in range(1, size + 1):
                if i:
                    if n % 2 == 0:
                        drummer.note('snare', duration=1)
                    else:
                        drummer.rest('snare', duration=1)
                else:
                    if n % 3 == 0:
                        drummer.note('snare', duration=1)
                    else:
                        drummer.rest('snare', duration=1)
        fill()

def fill():
    global drummer
    rr = Rhythm(
        measure_size=size,
        durations=[1, 0.5, 0.25],
        weights=[5, 10, 5],
        groups=[0, 0, 2]
    )
    motif = rr.motif()
    print(f"Fill: {motif}")
    for duration in motif:
        drummer.note('snare', duration=duration)

if __name__ == "__main__":
    bpm = int(sys.argv[1]) if len(sys.argv) > 1 else 120
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 4

    drummer = Drummer()
    drummer.set_bpm(bpm)
    drummer.set_ts()
    drummer.beats(size)

    kick()
    snare()
    hihat()
    drummer.sync_parts()
    
    drummer.show('midi')