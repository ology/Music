import sys
from time import sleep, time
import mido

CLOCK = mido.Message('clock')

class DrumPattern:
    def __init__(self, outport):
        self.outport = outport
        self.patterns = {
            'kick': [0, 2],  # Beat positions (0-based)
            'snare': [1, 3],
            'hihat': [0, 1, 2, 3],
        }

    def play(self, beat, pattern_name):
        note = 36
        msg = mido.Message('note_on', note=note, channel=0, velocity=100)
        self.outport.send(msg)
        sleep(0.1)
        msg = mido.Message('note_off', note=note, channel=0, velocity=0)
        self.outport.send(msg)

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
        if self.beat_tick == 0:  # Play drum on beat
            self.drums.play(self.beat, 'kick')
            self.drums.play(self.beat, 'snare')
            self.drums.play(self.beat, 'hihat')

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
            print("\nStopped.")