"""
Play Euclidean patterns and snare fills with no clock.
"""

import mido
import random
import sys
import time

from find_primes import all_primes
from music_creatingrhythms import Rhythms
from random_rhythms import Rhythm

class DrumMachine:
    def __init__(self, bpm=120):
        self.bpm = bpm
        self.per_sec = 60.0 / bpm
        self.dura = self.per_sec / 4
        
        self.drums = {
            'kick': {'num': 36, 'chan': 0},
            'snare': {'num': 38, 'chan': 1},
            'hihat': {'num': 42, 'chan': 2},
            'cymbals': {'num': 49, 'chan': 3},
        }
        self.voices = list(self.drums.keys())
        self.chans = [i['chan'] for i in self.drums.values()]
        
        self.r = Rhythms()
        self.beats = 16
        self.patterns = {
            'kick': self.r.euclid(2, self.beats),
            'snare': self.r.rotate_n(4, self.r.euclid(2, self.beats)),
            'hihat': self.r.euclid(11, self.beats),
            'cymbals': [0 for _ in range(self.beats)],
        }
        
        self.N = 0
        self.primes = all_primes(self.beats, 'list')
        self.outport = None

    def midi_msg(self, event, note, channel, velocity):
        msg = mido.Message(event, note=note, channel=channel, velocity=velocity)
        self.outport.send(msg)

    def velo(self):
        return 64 + random.randint(-10, 10)

    def random_note(self):
        return random.choice([60, 64, 67]) - 24

    def fill(self):
        rr = Rhythm(
            measure_size=4,
            durations=[1, 1/2, 1/4],
            weights=[5, 10, 5],
            groups=[0, 0, 2]
        )
        motif = rr.motif()
        for duration in motif:
            self.midi_msg('note_on', self.drums['snare']['num'], self.drums['snare']['chan'], self.velo())
            time.sleep(duration * self.per_sec * 0.9)
            self.midi_msg('note_off', self.drums['snare']['num'], self.drums['snare']['chan'], 0)
            time.sleep(duration * self.per_sec * 0.1)

    def adjust_kit(self, i, n):
        p = random.choice(self.primes)
        self.patterns['hihat'] = self.r.euclid(p, self.beats)
        self.drums['snare']['num'] = self.random_note()
        if n % 2 == 0:
            self.patterns['snare'] = self.r.rotate_n(4, self.r.euclid(2, self.beats))
            self.patterns['kick'] = self.r.euclid(2, self.beats)
        else:
            self.patterns['snare'] = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,0]
            self.patterns['kick'] = [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1]
            self.drums['kick']['num'] = self.random_note()
            self.drums['hihat']['num'] = self.random_note()
        if i == 0 and n > 0:
            self.patterns['cymbals'] = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            self.drums['cymbals']['num'] = self.random_note()
            self.patterns['hihat'][0] = 0
        else:
            self.patterns['cymbals'] = [0 for _ in range(self.beats)]

    def drum_part(self):
        try:
            while True:
                for i in range(3):
                    self.adjust_kit(i, self.N)
                    for step in range(self.beats):
                        for drum in self.voices:
                            if self.patterns[drum][step]:
                                self.midi_msg('note_on', self.drums[drum]['num'], self.drums[drum]['chan'], self.velo())
                        time.sleep(self.dura * 0.9)
                        for drum in self.voices:
                            if self.patterns[drum][step]:
                                self.midi_msg('note_off', self.drums[drum]['num'], self.drums[drum]['chan'], 0)
                        time.sleep(self.dura * 0.1)
                self.fill()
                self.N += 1
        except KeyboardInterrupt:
            self.stop()

    def stop(self):
        for c in self.chans:
            msg = mido.Message('control_change', channel=c, control=123, value=0)
            self.outport.send(msg)
        self.outport.close()
        print("\nDrum machine stopped.")

    def run(self, port_name='MIDIThing2'):
        try:
            with mido.open_output(port_name) as outport:
                self.outport = outport
                print(self.outport)
                print("Drum machine running... Ctrl+C to stop.")
                self.drum_part()
        except mido.PortUnavailableError as e:
            print(f"Error: {e}")


if __name__ == "__main__":
    bpm = int(sys.argv[1]) if len(sys.argv) > 1 else 120
    machine = DrumMachine(bpm)
    machine.run()
