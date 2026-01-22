#!/usr/bin/env python3

import sys
from random import randint, choice

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
        roll = randint(0, 1)
        print(f"Snare: {roll}")
        for _ in range(drummer.beats - 1):
            for n in range(1, size + 1):
                if roll:
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
    global drummer, fills
    rr = Rhythm(
        measure_size=size,
        durations=[1, 0.5, 0.25],
        weights=[5, 10, 5],
        groups=[0, 0, 2]
    )
    motif = rr.motif()
    print(f"Fill: {motif}")
    fill_func = choice(fills)
    for i, duration in enumerate(motif):
        patch = fill_func(i)
        drummer.note(patch, duration=duration)

def fill_1(i):
    patch = 'snare'
    return patch

def fill_2(i):
    patch = 'snare'
    return patch

def fill_3(i):
    patch = 'snare'
    return patch

def fill_4(i):
    patch = 'snare'
    return patch

def fill_5(i):
    patch = 'snare'
    return patch

def fill_6(i):
    patch = 'snare'
    return patch

def or_cymbal(patch):
    global drummer
    cymbals = ['crash1', 'crash2', 'splash', 'china']
    cymbal = choice(cymbals)
    return cymbal

if __name__ == "__main__":
    bpm = int(sys.argv[1]) if len(sys.argv) > 1 else 120
    size = 4

    drummer = Drummer()
    drummer.set_bpm(bpm)
    drummer.set_ts()

    f1 = fill_1
    f2 = fill_2
    f3 = fill_3
    f4 = fill_4
    f5 = fill_5
    f6 = fill_6

    fills = [f1, f2, f3, f4, f5, f6]

    kick()
    snare()
    hihat()

    drummer.sync_parts()
    drummer.show('midi')