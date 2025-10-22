import mido
import sys
import time

def send_clock(outport, bpm=100):
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

if __name__ == "__main__":
    bpm = sys.argv[2] if len(sys.argv) > 2 else 120
    port = sys.argv[1] if len(sys.argv) > 1 else 'USB MIDI Interface'
    with mido.open_output(port) as outport:
        outport.send(mido.Message('start'))
        send_clock(outport, bpm)
