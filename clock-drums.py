import sys
from time import sleep, time
import mido
import threading

CLOCK = mido.Message('clock')

class DrumPattern:
    def __init__(self, pattern):
        self.pattern = pattern

    def get_notes(self, beat_tick):
        return self.pattern.get(beat_tick, [])

class Generator(object):

    def __init__(self, port, bpm, tpb, drum_pattern=None):
        self.port = port
        self.bpm = bpm
        self.tpb = tpb
        self.ticks = 0
        self.running = False
        self.thread = None
        self.drum_pattern = drum_pattern

    def start(self):
        self.running = True
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

    def stop(self):
        self.running = False
        if self.thread:
            self.thread.join()

    def _run(self):
        initial_time = time()
        tick_time = 60. / self.bpm / self.tpb
        wait_time = tick_time / 1.5
        sleep_time = wait_time / 2.
        while self.running:
            next_time = initial_time + (tick_time * self.ticks)
            while time() + wait_time < next_time and self.running:
                sleep(sleep_time)
            while time() < next_time and self.running:
                pass
            if self.running:
                self.tick()
                self.ticks += 1

    @property
    def beat(self):
        return self.ticks // self.tpb

    @property
    def beat_tick(self):
        return self.ticks % self.tpb

    def tick(self):
        self.port.send(CLOCK)
        # Send drum notes at the start of each beat
        if self.beat_tick == 0 and self.drum_pattern:
            notes = self.drum_pattern.get_notes(self.beat % 4)
            for note, velocity, channel in notes:
                self.port.send(mido.Message('note_on', note=note, channel=channel, velocity=velocity))
                sleep(0.01)
                self.port.send(mido.Message('note_off', note=note, channel=channel, velocity=0))
                sleep(0.01)

if __name__ == "__main__":
    bpm = int(sys.argv[1]) if len(sys.argv) > 1 else 120

    pattern = DrumPattern({
        0: [(36, 100, 0)],
        1: [(38, 100, 1)],
        2: [(36, 100, 0)],
        3: [(38, 100, 1)],
    })

    with mido.open_output('MIDIThing2') as outport:
        outport.send(mido.Message('start'))
        gen = Generator(port=outport, bpm=bpm, tpb=24, drum_pattern=pattern)
        try:
            gen.start()
            while True:
                sleep(1)
        except KeyboardInterrupt:
            gen.stop()
            outport.send(mido.Message('stop'))