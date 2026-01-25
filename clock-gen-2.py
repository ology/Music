import random
import sys
from time import sleep, time
import mido
from find_primes import all_primes
from music_creatingrhythms import Rhythms
from random_rhythms import Rhythm

CLOCK = mido.Message('clock')

class DrumPattern:
    def __init__(self, outport):
        self.outport = outport
        self.r = Rhythms()
        self.beats = 16
        self.drums = {
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
        self.patterns = {
            'kick': self.r.euclid(2, self.beats),
            'snare': self.r.rotate_n(4, self.r.euclid(2, self.beats)),
            'hihat': self.r.euclid(16, self.beats),
            'cymbals': [0 for _ in range(self.beats)],
        }
        self.velo = lambda: 64 + random.randint(-10, 10)

    def midi_msg(self, event, note, channel, velocity):
        msg = mido.Message(event, note=note, channel=channel, velocity=velocity)
        self.outport.send(msg)

    def play(self, bpm):
        dura = 60.0 / bpm / self.beats
        for step in range(self.beats):
            for drum in ['kick', 'snare', 'hihat', 'cymbals']:
                if self.patterns[drum][step]:
                    self.midi_msg('note_on', self.drums[drum]['num'], self.drums[drum]['chan'], self.velo())                
                sleep(0.01) # slightly shorter than step to prevent overlap
                for drum in ['kick', 'snare', 'hihat', 'cymbals']:
                    if self.patterns[drum][step]:
                        self.midi_msg('note_off', self.drums[drum]['num'], self.drums[drum]['chan'], 0)
                sleep(dura - 0.01) # Remainder of the step duration

class MidiClockGenerator:
    def __init__(self, port, bpm, tpb=24):
        self.port = port
        self.bpm = bpm
        self.tpb = tpb
        self.ticks = 0
        self.drums = DrumPattern(port)

    def start(self):
        initial_time = time()
        tick_time = 60.0 / self.bpm / self.tpb
        wait_time = tick_time / 1.5
        sleep_time = wait_time / 2.0
        
        while True:
            next_time = initial_time + (tick_time * self.ticks)
            while time() + wait_time < next_time:
                sleep(sleep_time)
            while time() < next_time:
                pass
            self._tick()
            self.ticks += 1

    def _tick(self):
        self.port.send(CLOCK)
        if self.beat_tick == 0:
            self.drums.play(self.bpm)

    @property
    def beat(self):
        return self.ticks // self.tpb

    @property
    def beat_tick(self):
        return self.ticks % self.tpb

if __name__ == "__main__":
    bpm = int(sys.argv[1]) if len(sys.argv) > 1 else 120

    with mido.open_output('MIDIThing2') as outport:
        outport.send(mido.Message('start'))
        gen = MidiClockGenerator(port=outport, bpm=bpm)
        try:
            print(outport)
            gen.start()
        except KeyboardInterrupt:
            outport.send(mido.Message('stop'))
            for c in [0,1,2,3]:
                msg = mido.Message('control_change', channel=c, control=123, value=0)
                outport.send(msg)
            print("\nStopped.")