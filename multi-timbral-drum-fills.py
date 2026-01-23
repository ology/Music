import mido
import random
import sys
import time

from find_primes import all_primes
from music_creatingrhythms import Rhythms
from random_rhythms import Rhythm

def midi_msg(outport, event, note, channel, velocity):
    msg = mido.Message(event, note=note, channel=channel, velocity=velocity)
    outport.send(msg)

def fill(outport):
    global per_sec, drums, velo
    rr = Rhythm(
        measure_size=4,
        durations=[1, 1/2, 1/4],
        weights=[5, 10, 5],
        groups=[0, 0, 2]
    )
    motif = rr.motif()
    for duration in motif:
        midi_msg(outport, 'note_on', drums['snare']['num'], drums['snare']['chan'], velo())
        time.sleep(duration * per_sec * 0.9)
        midi_msg(outport, 'note_off', drums['snare']['num'], drums['snare']['chan'], 0)
        time.sleep(duration * per_sec * 0.1)

def adjust_kit(i, n):
    global r, patterns, drums, beats, random_note, primes
    p = random.choice(primes)
    patterns['hihat'] = r.euclid(p, beats)
    drums['snare']['num'] = random_note()
    if n % 2 == 0:
        patterns['kick'] = r.euclid(2, beats)
        patterns['snare'] = r.rotate_n(4, r.euclid(2, beats))
    else:
        patterns['kick'] = [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1]
        drums['kick']['num'] = random_note()
        drums['hihat']['num'] = random_note()
        patterns['snare'] = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,0]
    if i == 0 and n > 0:
        patterns['cymbals'] = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
        drums['cymbals']['num'] = random_note()
        patterns['hihat'][0] = 0
    else:
        patterns['cymbals'] = [0 for _ in range(beats)]

def drum_part(port_name):
    global r, patterns, drums, beats, velo, N
    try:
        with mido.open_output(port_name) as outport:
            print(f"Opened output port: {outport.name}")
            print("Drum machine running... Ctrl+C to stop.")
            try:
                while True:
                    for i in range(3):
                        adjust_kit(i, N)
                        for step in range(beats):
                            if patterns['kick'][step]:
                                midi_msg(outport, 'note_on', drums['kick']['num'], drums['kick']['chan'], velo())
                            if patterns['snare'][step]:
                                midi_msg(outport, 'note_on', drums['snare']['num'], drums['snare']['chan'], velo())
                            if patterns['hihat'][step]:
                                midi_msg(outport, 'note_on', drums['hihat']['num'], drums['hihat']['chan'], velo())
                            if patterns['cymbals'][step]:
                                midi_msg(outport, 'note_on', drums['cymbals']['num'], drums['cymbals']['chan'], velo())
                            
                            time.sleep(dura * 0.9) # slightly shorter than step to prevent overlap

                            if patterns['kick'][step]:
                                midi_msg(outport, 'note_off', drums['kick']['num'], drums['kick']['chan'], 0)
                            if patterns['snare'][step]:
                                midi_msg(outport, 'note_off', drums['snare']['num'], drums['snare']['chan'], 0)
                            if patterns['hihat'][step]:
                                midi_msg(outport, 'note_off', drums['hihat']['num'], drums['hihat']['chan'], 0)
                            if patterns['cymbals'][step]:
                                midi_msg(outport, 'note_off', drums['cymbals']['num'], drums['cymbals']['chan'], 0)

                            time.sleep(dura * 0.1) # Remainder of the step duration
                    fill(outport)
                    N += 1
            except KeyboardInterrupt:
                for c in [0,1,2,3]:
                    msg = mido.Message('control_change', channel=c, control=123, value=0)
                    outport.send(msg)
                outport.close()
                print("\nDrum machine stopped.")
    except mido.PortUnavailableError as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    bpm = int(sys.argv[1]) if len(sys.argv) > 1 else 120

    per_sec = 60.0 / bpm
    dura = per_sec / 4 # duration of one pattern step

    drums = {
        'kick': {
            'num': 36, # Acoustic Bass Drum
            'chan': 0,
        },
        'snare': {
            'num': 38, # Acoustic Snare
            'chan': 1,
        },
        'hihat': {
            'num': 42, # Closed Hi-Hat
            'chan': 2,
        },
        'cymbals': {
            'num': 49, # Crash1
            'chan': 3,
        },
    }

    r = Rhythms()
    beats = 16
    patterns = {
        'kick': r.euclid(2, beats),
        'snare': r.rotate_n(4, r.euclid(2, beats)),
        'hihat': r.euclid(11, beats),
        'cymbals': [0 for _ in range(beats)],
    }

    velo = lambda: 64 + random.randint(-10, 10)
    random_note = lambda: random.choice([60,64,67]) - 24

    N = 0

    primes = all_primes(beats, 'list')

    try:
        drum_part('MIDIThing2')
    except IndexError:
        print("Something went wrong.")
        sys.exit(1)
