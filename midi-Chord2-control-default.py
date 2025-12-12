# This program controls the QU-Bit Chord module.

import sys
import mido
import random
import time
import threading
from music_voicegen import MusicVoiceGen

def duration(x=1, y=4):
    return random.randint(x, y)

def velo():
    global velocity
    return velocity.rand()

def play_chord(pitch, velocity=127, duration=1):
    global outport
    nv = velo()
    msg = mido.Message('note_on', note=pitch, channel=0, velocity=nv)
    outport.send(msg)
    time.sleep(duration)
    msg = mido.Message('note_off', note=pitch, channel=0, velocity=nv)
    outport.send(msg)

def note_stream_thread():
    global x, y, voice, stop_threads
    while not stop_threads:
        pitch = voice.rand()
        play_chord(pitch, duration=duration(x, y))

if __name__ == "__main__":
    pitches = [
        12, # c0
        14, # d
        16, # e
        17, # f
        19, # g
        21, # a
        23, # b
    ]
    voice = MusicVoiceGen(
        pitches=pitches,
        intervals=[-3,-2,-1,1,2,3],
    )
    velocity = MusicVoiceGen(
        pitches=[ i for i in range(0,128) ],
        intervals=[ i for i in range(-10,11) if i != 0 ],
    )
    velocity.context(context=[64])

    # time between clocks at 24 PPQN per beat and 100 BPM
    interval = 60 / (100 * 24)
    stop_threads = False

    port_name = sys.argv[1] if len(sys.argv) > 1 else 'MIDIThing2'
    # note duration length range, between x and y inclusive
    x = sys.argv[2] if len(sys.argv) > 2 else 4
    y = sys.argv[3] if len(sys.argv) > 3 else 8

    with mido.open_output(port_name) as outport:
        print(outport)
        note_thread = threading.Thread(target=note_stream_thread, daemon=True)
        note_thread.start()
        outport.send(mido.Message('start'))
        try:
            while True:
                time.sleep(interval) # keep main thread alive and respond to interrupts
        except KeyboardInterrupt:
            outport.send(mido.Message('stop'))
            print("\nSignaling threads to stop...")
            stop_threads = True
            note_thread.join()
            print("All threads stopped.")
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            outport.close()
