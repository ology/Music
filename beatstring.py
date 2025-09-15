from music_creatingrhythms import Rhythms
from music_drummer import Drummer
from find_primes import all_primes
import random

def pattern(n=8):
    for _ in range(n):
        d.pattern(
            patterns={
                'kick': kick,
                'snare': snare,
                'hihat': hihat,
            }
        )

r = Rhythms()
beats = 16
kick  = ''.join([str(n) for n in r.euclid(2, beats)])
snare = ''.join([str(n) for n in r.rotate_n(4, r.euclid(2, beats))])
hihat = ''.join([str(n) for n in r.euclid(11, beats)])

primes = all_primes(beats, 'list')

d = Drummer()

d.set_instrument('kick', 'kick2')
d.set_instrument('snare', 'snare2')

d.set_ts()
d.set_bpm(100)

d.count_in()
d.rest(['kick', 'snare'], duration=4)

pattern()

for _ in range(4):
    d.pattern(
        patterns={
            'kick':  ''.join([str(n) for n in r.euclid(random.choice(primes), beats)]),
            'snare': ''.join([str(n) for n in r.euclid(random.choice(primes), beats)]),
            'hihat': ''.join([str(n) for n in r.euclid(random.choice(primes), beats)]),
        }
    )

pattern()

d.sync_parts()

d.score.show('midi')
# d.score.write(filename='drums.mid')
