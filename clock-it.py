import mido
import time

def send_clock(outport, bpm=120):
    # Calculate the time between clock messages (24 PPQN per beat)
    interval = 60 / (bpm * 24)
    try:
        while True:
            outport.send(mido.Message('clock'))
            time.sleep(interval)
    except KeyboardInterrupt:
        outport.send(mido.Message('stop'))
        outport.close()
        print("\nExiting...")

def send_clock_messages(outport, bpm=120, num_beats=4):
    # Calculate the time between clock messages (24 PPQN per beat)
    interval = 60 / (bpm * 24)
    for _ in range(num_beats * 24):
        outport.send(mido.Message('clock'))
        time.sleep(interval)

if __name__ == "__main__":
    with mido.open_output('USB MIDI Interface') as outport:
        outport.send(mido.Message('start'))
        # send_clock_messages(outport, bpm=100, num_beats=8)
        # outport.send(mido.Message('stop'))
        send_clock(outport, bpm=100)
