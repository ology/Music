from music_drummer import Drummer

d = Drummer()

d.set_instrument('kick', 'kick2')
d.set_instrument('snare', 'snare2')
d.set_instrument('crash', 'crash1')

d.set_ts()
d.set_bpm(60)

d.count_in()
d.rest('kick', duration=4)
d.rest('snare', duration=4)
d.rest('crash', duration=4)

for _ in range(4):
    d.pattern(
        patterns={
            'kick': '1000000010000000',
            'snare': '0000100000001000',
            'hihat': '0111111111111111',
            'crash': '1000000000000000',
        }
    )

d.sync_parts()

d.score.show('midi')
