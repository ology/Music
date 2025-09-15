from music_creatingrhythms import Rhythms
from music_drummer import Drummer
from find_primes import all_primes
import random

r = Rhythms()
beats = 16
kick1  = ''.join([str(n) for n in r.euclid(2, beats)])
snare1 = ''.join([str(n) for n in r.rotate_n(4, r.euclid(2, beats))])
hihat1 = ''.join([str(n) for n in r.euclid(11, beats)])

primes = all_primes(beats, 'list')

d = Drummer()

d.set_instrument('kick', 'kick2')
d.set_instrument('snare', 'snare2')

d.set_ts()
d.set_bpm(100)

d.count_in()
d.rest(['kick', 'snare'], duration=4)

for _ in range(8):
    d.pattern(
        patterns={
            'kick': kick,
            'snare': snare,
            'hihat': hihat,
        }
    )

for _ in range(8):
    d.pattern(
        patterns={
            'kick':  ''.join([str(n) for n in r.euclid(random.choice(primes), beats)]),
            'snare': ''.join([str(n) for n in r.euclid(random.choice(primes), beats)]),
            'hihat': ''.join([str(n) for n in r.euclid(random.choice(primes), beats)]),
        }
    )

d.sync_parts()

d.score.show('midi')
# d.score.write(filename='drums.mid')
