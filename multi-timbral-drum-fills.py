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
        midi_msg(outport, 'note_on', drums['snare'], 1, velo())
        time.sleep(duration * per_sec * 0.9)
        midi_msg(outport, 'note_off', drums['snare'], 1, 0)
        time.sleep(duration * per_sec * 0.1)

def drum_part(port_name):
    global r, patterns, drums, dura, beats, N, velo, random_note, primes
    try:
        with mido.open_output(port_name) as outport:
            print(f"Opened output port: {outport.name}")
            print("Drum machine running... Ctrl+C to stop.")
            try:
                while True:
                    for _ in range(3):
                        p = random.choice(primes)
                        patterns['hihat'] = r.euclid(p, beats)
                        drums['snare'] = random_note()
                        if N % 2 == 0:
                            patterns['kick'] = r.euclid(2, beats)
                        else:
                            patterns['kick'] = [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1]
                            drums['kick'] = random_note()
                            drums['hihat'] = random_note()
                        for step in range(beats):
                            if patterns['kick'][step]:
                                midi_msg(outport, 'note_on', drums['kick'], 0, velo())
                            if patterns['snare'][step]:
                                midi_msg(outport, 'note_on', drums['snare'], 1, velo())
                            if patterns['hihat'][step]:
                                midi_msg(outport, 'note_on', drums['hihat'], 2, velo())
                            
                            time.sleep(dura * 0.9) # slightly shorter than step to prevent overlap

                            if patterns['kick'][step]:
                                midi_msg(outport, 'note_off', drums['kick'], 0, 0)
                            if patterns['snare'][step]:
                                midi_msg(outport, 'note_off', drums['snare'], 1, 0)
                            if patterns['hihat'][step]:
                                midi_msg(outport, 'note_off', drums['hihat'], 2, 0)

                            time.sleep(dura * 0.1) # Remainder of the step duration
                    fill(outport)
                    N += 1
            except KeyboardInterrupt:
                for c in [0,1,2]:
                    msg = mido.Message('control_change', channel=c, control=123, value=0)
                    outport.send(msg)
                outport.close()
                print("\nDrum machine stopped.")
    except mido.PortUnavailableError as e:
        print(f"Error: {e}")
        print("Check your virtual MIDI port setup and names")

if __name__ == "__main__":
    bpm = int(sys.argv[1]) if len(sys.argv) > 1 else 120

    per_sec = 60.0 / bpm
    dura = 60.0 / bpm / 4 # duration of one pattern step

    drums = {
        'kick': 36,  # Acoustic Bass Drum
        'snare': 38, # Acoustic Snare
        'hihat': 42  # Closed Hi-Hat
    }

    r = Rhythms()
    beats = 16
    patterns = {
        'kick': r.euclid(2, beats),
        'snare': r.rotate_n(4, r.euclid(2, beats)),
        'hihat': r.euclid(11, beats),
    }

    velo = lambda: 64 + random.randint(-10, 10)
    random_note = lambda: random.choice([60,64,67]) - 12

    N = 0

    primes = all_primes(beats, 'list')

    try:
        drum_part('MIDIThing2')
    except IndexError:
        print("Something went wrong.")
        sys.exit(1)
