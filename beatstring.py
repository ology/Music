from music_creatingrhythms import Rhythms
from music_drummer import Drummer
from find_primes import all_primes
import random

beats = 16

def pattern1(rhythm, drummer, n=8):
    kick  = ''.join([str(n) for n in rhythm.euclid(2, beats)])
    snare = ''.join([str(n) for n in rhythm.rotate_n(4, rhythm.euclid(2, beats))])
    hihat = ''.join([str(n) for n in rhythm.euclid(11, beats)])
    for _ in range(n):
        drummer.pattern(
            patterns={
                'kick': kick,
                'snare': snare,
                'hihat': hihat,
            }
        )

def pattern2(rhythm, drummer, n=4):
    primes = all_primes(beats, 'list')
    kick  = ''.join([str(n) for n in rhythm.euclid(random.choice(primes), beats)])
    snare = ''.join([str(n) for n in rhythm.euclid(random.choice(primes), beats)])
    hihat = ''.join([str(n) for n in rhythm.euclid(random.choice(primes), beats)])
    for _ in range(n):
        drummer.pattern(
            patterns={
                'kick':  kick,
                'snare': snare,
                'hihat': hihat,
            }
        )

def main():
    r = Rhythms()
    d = Drummer()

    d.set_instrument('kick', 'kick2')
    d.set_instrument('snare', 'snare2')

    d.set_ts()
    d.set_bpm(100)

    d.count_in()
    d.rest(['kick', 'snare'], duration=4)
    pattern1(r, d)
    pattern2(r, d)
    pattern1(r, d)

    d.sync_parts()
    d.show('midi')
    # d.score.write(filename='drums.mid')

if __name__ == "__main__":
    main()
