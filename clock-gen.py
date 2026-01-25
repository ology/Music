from time import sleep, time
import mido

CLOCK = mido.Message('clock')

class Generator(object):

    def __init__(self, port, bpm, tpb):
        self.port = port
        self.bpm = bpm
        self.tpb = tpb
        self.ticks = 0

    def start(self):
        initial_time = time()
        tick_time = 60. / self.bpm / self.tpb
        wait_time = tick_time / 1.5
        sleep_time = wait_time / 2.
        while True:
            next_time = initial_time + (tick_time * self.ticks)
            while time() + wait_time < next_time:
                sleep(sleep_time)
            while time() < next_time:
                pass
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

if __name__ == "__main__":
    with mido.open_output('MIDIThing2') as outport:
        outport.send(mido.Message('start'))
        gen = Generator(port=outport, bpm=70, tpb=24)
        try:
            gen.start()
        except KeyboardInterrupt:
            outport.send(mido.Message('stop'))