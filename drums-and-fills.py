from music_drummer import Drummer
from random_rhythms import Rhythm
import random

def section_A():
    for _ in range(3):
        d.pattern(
            patterns={
                'kick':  '1000000010000000',
                'snare': '0000100000001000',
                'hihat': '1010101010101010',
            },
        )
    for _ in range(1):
        d.pattern(
            patterns={
                'kick':  '10000000',
                'snare': '00001000',
                'hihat': '23101010',
            },
        )
    fill = random.choice(fills)
    for duration in fill:
        d.note('snare', duration)
    d.rest(['kick', 'hihat'], 2)

if __name__ == "__main__":
    r = Rhythm(
        measure_size=2,
        durations=[1/4, 1/2],
    )
    fills = [ r.motif() for x in range(4) ]

    d = Drummer()
    d.set_bpm(100)
    d.set_ts()

    for _ in range(8):
        section_A()

    d.sync_parts()
    d.show('midi')