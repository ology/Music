from music_creatingrhythms import Rhythms
from music_drummer import Drummer

r = Rhythms()
beats = 16
kick = r.euclid(5, beats)
snare = r.euclid(7, beats)
hihat = r.euclid(11, beats)

d = Drummer()

d.set_instrument('kick', 'kick2')
d.set_instrument('snare', 'snare2')

d.set_ts()
d.set_bpm(60)

d.count_in()
d.rest(['kick', 'snare'], duration=4)

for _ in range(4):
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
