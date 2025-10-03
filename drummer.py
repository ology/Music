from music_drummer import Drummer

# Ex 1 - basic 4/4 metronome groove:
d = Drummer()
d.set_bpm(100) # set the beats per minute
d.set_ts() # set the default time signature of 4/4
# add a 16-beat phrase for 64 measures
for _ in range(64):
    d.pattern(
        patterns={
            'kick':  '1000000010000000',
            'snare': '0000100000001000',
            'hihat': '2310101010101010',
        },
    )
d.sync_parts() # make the parts play simultaneously
# d.show(format='midi') # or nothing, ='text', etc. see music21 docs

# Ex 2 - 5/8 groove with intro:
d = Drummer()

kit = d.instrument_map() # get all the known kit instruments
sidestick = d.instrument_map(name='Side Stick')
sidestick = d.instrument_map(num=37)

d.set_instrument('kick', 'kick2') # change to the electric kick
d.set_instrument('snare', 'snare2') # change to the electric snare

d.set_bpm(99) # change the beats per minute from 120
d.set_ts('5/8') # change the time signature from 4/4

d.count_in(2) # count-in on the hi-hats for 2 measures
d.rest('kick', duration=10)
d.rest('snare', duration=10)
d.rest('cymbals', duration=10)
d.rest('toms', duration=10)

# 3 known hi-hat states: closed, open, pedal
d.note('closed', duration=1/2)
d.note('open', duration=1/2)
d.note('pedal', duration=1/2)
d.note('closed', duration=1/2)
d.rest(['snare', 'kick', 'cymbals', 'toms'], duration=2)

# 7 known cymbals
d.note('crash1')
d.note('crash2')
d.note('china')
d.note('splash')
d.note('ride1')
d.note('ride2')
d.note('ridebell')
d.rest(['kick', 'snare', 'hihat', 'toms'], duration=7)

# 6 known toms
d.note(['tom1', 'tom2', 'tom3', 'tom4', 'tom5', 'tom6'], duration=1/3)
d.rest(['kick', 'snare', 'hihat', 'cymbals'], duration=2)

# add a eighth-note snare flam to the score
d.note('snare', duration=1/2, flam=1/16)
d.rest(['kick', 'hihat', 'cymbals', 'toms'], duration=1/2)

# add a 5-note snare roll for an eighth-note, increasing in volume
d.roll('snare', duration=1/2, subdivisions=5, crescendo=[100, 127])
d.rest(['kick', 'hihat', 'cymbals', 'toms'], duration=1/2)

# crash and kick!
d.note(['kick', 'crash1'], duration=1/2)
d.rest(['snare', 'hihat', 'toms'], duration=1/2)

# add a 4-part, 8-bar, eighth-note phrase to the score
for _ in range(4):
    d.pattern(
        patterns={
            'kick':   '1000000010',
            'snare':  '0000001000',
            'hihat':  '2311111111',
        },
        duration=1/2
    )

d.sync_parts() # make the parts play simultaneously

m = d.to_mido() # convert to a format mido can understand

d.show() # or format='text', format='midi', etc. see music21 docs
# or
# d.write() # or filename='groove.mid' for example
