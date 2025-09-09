from music_drummer import Drummer
from music21 import instrument


d = Drummer()

d.set_instrument('kick', 36) # change the kick patch
d.set_instrument('snare', 40) # change the snare patch
# add a crash
d.set_instrument('crash', 49, obj=instrument.CrashCymbals())

d.set_bpm(99) # change the beats per minute from 120

d.set_ts('5/8') # change the time signature from 4/4

d.count_in(2) # count-in on the hi-hats for 2 measures
d.rest('kick', duration=10)
d.rest('snare', duration=10)
d.rest('crash', duration=10)

# add a 64th-note flam to the score
d.note('snare', duration=1/2, flam=1/16)
d.rest('kick', duration=1/2)
d.rest('hihat', duration=1/2)
d.rest('crash', duration=1/2)

# add a roll of 5 notes for an eighth-note, increasing in volume
d.roll('snare', duration=1/2, subdivisions=5, crescendo=[100, 127])
d.rest('kick', duration=1/2)
d.rest('hihat', duration=1/2)
d.rest('crash', duration=1/2)

# crash and kick!
d.note('kick', duration=1/2)
d.note('crash', duration=1/2)
d.rest('snare', duration=1/2)
d.rest('hihat', duration=1/2)

# add an eighth-note phrase of 3 parts, to the score
for _ in range(4):
    d.pattern(
        patterns={ 'kick': '1000000010', 'snare': '0000001000', 'hihat': '1111111111' },
        duration=1/2
    )

d.sync_parts() # make the parts play simultaneously

d.score.show('midi') # or text, midi, etc. see music21 docs
