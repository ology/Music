# This program controls the QU-Bit Chord module through a multi-timbral MIDI-CV interface.

import sys
import mido
import time
import threading
from music_voicegen import MusicVoiceGen

def play_chord(pitch, velocity=127, duration=1):
    msg = mido.Message('note_on', note=pitch, channel=0, velocity=velocity)
    outport.send(msg)
    time.sleep(duration * factor)
    msg = mido.Message('note_off', note=pitch, channel=0, velocity=velocity)
    outport.send(msg)

def note_stream_thread():
    global voice, pitch_qualites, quality_volts, stop_threads
    while not stop_threads:
        pitch = voice.rand()
        play_chord(pitch, duration=4)

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

    factor = 1/2 # duration multiplier
    # time between clocks at 24 PPQN per beat and 100 BPM
    interval = 60 / (100 * 24)
    stop_threads = False # should I stay or should I go?

    port_name = sys.argv[1] if len(sys.argv) > 1 else 'MIDIThing2'

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
