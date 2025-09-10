from music_drummer import Drummer

d = Drummer()

d.set_instrument('kick', 'kick2')
d.set_instrument('snare', 'snare2')

d.set_ts()
d.set_bpm(60)

d.count_in()
d.rest(['kick', 'snare', 'crash1'], duration=4)

d.note('closed', duration=1/2)
d.note('open', duration=1/2)
d.note('pedal', duration=1/2)
d.note('closed', duration=1/2)
d.rest(['snare', 'kick', 'crash1'], duration=2)

for _ in range(4):
    d.pattern(
        patterns={
            'kick':   '1000000010000000',
            'snare':  '0000100000001000',
            'hihat':  '0111111111111111',
            'crash1': '1000000000000000',
        }
    )

d.sync_parts()

d.score.show('midi')
