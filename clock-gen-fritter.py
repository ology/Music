import asyncio
import sys

from fritter.boundaries import PhysicalScheduler, SomeScheduledCall
from fritter.drivers.asyncio import AsyncioTimeDriver
from fritter.repeat import repeatedly
from fritter.repeat.rules.seconds import EverySecond
from fritter.scheduler import schedulerFromDriver
from mido import Message, open_output  # type:ignore[import-untyped]

def clock(steps: int, scheduled: SomeScheduledCall) -> None:
    midi_out.send(Message("clock"))
    print("MIDI clock sent")


async def main(interval: float) -> None:

    loop = asyncio.get_running_loop()

    driver = AsyncioTimeDriver(loop)
    scheduler: PhysicalScheduler = schedulerFromDriver(driver)
    repeatedly(scheduler, clock, EverySecond(interval))
    # delay, callback, *args passed to the callback
    await asyncio.sleep(10)  # Keep main alive to see it work


if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "USB MIDI Interface"
    bpm = int(sys.argv[2]) if len(sys.argv) > 2 else 120

    clock_interval = 60 / bpm / 24
    # print(clock_interval)

    with open_output(name) as midi_out:
        midi_out.send(Message("start"))
        try:
            asyncio.run(main(clock_interval))
        except KeyboardInterrupt:
            midi_out.send(Message("stop"))
            print("\nStop")
