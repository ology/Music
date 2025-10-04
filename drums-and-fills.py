from music_drummer import Drummer
from random_rhythms import Rhythm
import random

def section_A(section=0):
    for _ in range(3):
        d.pattern(
            patterns={
                'kick':  '1000000010000000',
                'snare': '0000100000001000',
                'hihat': '1010101010101010',
            },
        )
    if section == 1:
        d.note('crash1', 1)
    for _ in range(1):
        d.pattern(
            patterns={
                'kick':  '10000000',
                'snare': '00001000',
                'hihat': '10101010',
            },
        )
    fill = random.choice(fills)
    for duration in fill:
        d.note('snare', duration)
    d.rest(['kick', 'hihat'], 2)
    if section == 1:
        d.rest('cymbals', 15)
    else:
        d.rest('cymbals', 16)

def section_B():
    for _ in range(3):
        d.pattern(
            patterns={
                'kick':  '1000001010000000',
                'snare': '0000100000001000',
                'hihat': '0010101010101010',
            },
        )
    d.note('crash1', 1)
    for _ in range(1):
        d.pattern(
            patterns={
                'kick':  '10000001',
                'snare': '00001000',
                'hihat': '23101010',
            },
        )
    fill = random.choice(fills)
    for duration in fill:
        d.note('snare', duration)
    d.rest(['kick', 'hihat'], 2)
    d.rest('cymbals', 15)


if __name__ == "__main__":
    r = Rhythm(
        measure_size=2,
        durations=[1/4, 1/2],
    )
    fills = [ r.motif() for x in range(4) ]

    d = Drummer()
    d.set_bpm(100)
    d.set_ts()
    
    section_A()
    section_B()
    section_B()
    section_A(1)

    d.sync_parts()
    d.show('midi')
    # d.write()