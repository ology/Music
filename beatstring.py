from music_drummer import Drummer

d = Drummer()

d.set_instrument('kick', 'kick2')
d.set_instrument('snare', 'snare2')

d.set_ts()
d.set_bpm(60)

d.count_in()
d.rest(['kick', 'snare'], duration=4)

d.note('closed', duration=1/2)
d.note('open', duration=1/2)
d.note('pedal', duration=1/2)
d.note('closed', duration=1/2)
d.rest(['snare', 'kick'], duration=2)

# d.note('crash1', duration=1/2)
# d.note('crash2', duration=1/2)
# d.note('china', duration=1/2)
# d.note('splash', duration=1/2)
# d.note('ride1', duration=1/2)
# d.note('ride2', duration=1/2)
# d.note('ridebell', duration=1/2)
# d.rest(['kick', 'snare', 'hihat'], duration=3.5)

for _ in range(4):
    d.pattern(
        patterns={
            'kick':  '1000000010000000',
            'snare': '0000100000001000',
            'hihat': '2311111111111111',
        }
    )

d.sync_parts()

d.score.show('midi')
# d.score.write(filename='drums.mid')
