import asyncio
import mido
from mido import Message
import sys

def periodic_task(loop, interval, task_func):
    task_func()
    # Schedule the next call recursively
    loop.call_later(interval, periodic_task, loop, interval, task_func)

def clock():
    global midi_out
    midi_out.send(Message('clock'))
    print("MIDI clock sent")

async def main(interval):
    loop = asyncio.get_running_loop()
    # delay, callback, *args passed to the callback
    loop.call_later(interval, periodic_task, loop, interval, clock)
    await asyncio.sleep(10)  # Keep main alive to see it work

if __name__ == '__main__':
    name = sys.argv[1] if len(sys.argv) > 1 else 'USB MIDI Interface'
    bpm  = int(sys.argv[2]) if len(sys.argv) > 2 else 120

    clock_interval = 60 / bpm / 24

    with mido.open_output(name) as midi_out:
        midi_out.send(Message('start'))
        try:
            asyncio.run(main(clock_interval))
        except KeyboardInterrupt:
            midi_out.send(Message('stop'))
            print("\nStop")
