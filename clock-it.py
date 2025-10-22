import mido
import sys
import time

def send_clock(outport, bpm):
    interval = 60 / (int(bpm) * 24) # time between clock messages (24 PPQN per beat)
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
        print(outport, f"at {bpm} BPM")
        outport.send(mido.Message('start'))
        send_clock(outport, bpm)
