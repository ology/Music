from music_creatingrhythms import Rhythms
from music_drummer import Drummer

r = Rhythms()
beats = 16
kick =  ''.join([str(num) for num in r.euclid(2, beats)])
snare = ''.join([str(num) for num in r.rotate_n(4, r.euclid(2, beats))])
hihat = ''.join([str(num) for num in r.euclid(11, beats)])

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

d.sync_parts()

d.score.show('midi')
# d.score.write(filename='drums.mid')
