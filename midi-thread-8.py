# Control two synths on MIDI channels 1 & 2, respectively.
# ex: python midi-thread-8.py 'USB MIDI Interface' 'SE-02' 16 ''

import sys
import random
import time
import threading
import mido
import pychord
from music21 import pitch
from chord_progression_network import Generator
from music_melodicdevice import Device
from random_rhythms import Rhythm

def midi_clock_thread():
    global synth1_outport, synth2_outport, interval, stop_threads, clock_tick_event, clock_tick_count
    while not stop_threads:
        synth1_outport.send(mido.Message('clock'))
        synth2_outport.send(mido.Message('clock'))
        clock_tick_count += 1
        # signal stream threads every beat
        if clock_tick_count % clocks_per_beat == 0:
            clock_tick_event.set()
        time.sleep(interval)

def midi_off_messages(outport, notes, channel=0, velocity=0):
    for note in notes:
        p = pitch.Pitch(note).midi
        msg = mido.Message('note_off', note=p, velocity=velocity, channel=channel)
        outport.send(msg)

def midi_on_messages(outport, notes, channel=0, velocity=127):
    for note in notes:
        if not velocity:
            velocity = velo()
        p = pitch.Pitch(note).midi
        msg = mido.Message('note_on', note=p, velocity=velocity, channel=channel)
        outport.send(msg)

def midi_off_messages(outport, notes, channel=0, velocity=0):
    for note in notes:
        p = pitch.Pitch(note).midi
        msg = mido.Message('note_off', note=p, velocity=velocity, channel=channel)
        outport.send(msg)

def synth_stream_thread(program=45, bank=6, prog=8):
    global default_quality, g, device, factor, synth1_outport, synth2_outport, velocity, stop_threads, clock_tick_event
    patch = int(str(bank - 1) + str(prog - 1), 8) # 8x8 bank x program
    msg = mido.Message('program_change', channel=0, program=patch)
    synth1_outport.send(msg)
    msg = mido.Message('program_change', channel=1, program=program-1)
    synth2_outport.send(msg)
    while not stop_threads:
        clock_tick_event.wait() # wait for the next beat (PLL sync)
        clock_tick_event.clear()
        phrase = g.generate()
        motif = r.motif()
        for ph in phrase:
            arped = device.arp(ph, duration=1, arp_type='updown', repeats=1)
            for i,d in enumerate(motif):
                p = pitch.Pitch(arped[i % len(arped)][1]).name
                i = g.scale.index(p) if p in g.scale else None
                if i:
                    quality = g.chord_map[i]
                if not i or quality == 'dim':
                    quality = default_quality
                c = p + quality
                print(c)
                c = pychord.Chord(c)
                c = c.components_with_pitch(root_pitch=g.octave)
                # bassline = [ pitch.Pitch(c[0]).midi - 12 ]
                bassline = [ pitch.Pitch(random.choice(c)).midi - 12 ]
                print(pitch.Pitch(bassline[0]).name)
                midi_on_messages(synth1_outport, c, 0)
                midi_on_messages(synth2_outport, bassline, 1)
                time.sleep(d * factor)
                midi_off_messages(synth1_outport, c, 0)
                midi_off_messages(synth2_outport, bassline, 1)

if __name__ == "__main__":
    synth1_port_name = sys.argv[1]      if len(sys.argv) > 1 else 'USB MIDI Interface'
    synth2_port_name = sys.argv[2]      if len(sys.argv) > 2 else 'SE-02'
    factor           = int(sys.argv[3]) if len(sys.argv) > 3 else 32
    default_quality  = sys.argv[4]      if len(sys.argv) > 4 else 'm' # minor

    g = Generator(
        octave=4,
        scale_note='A',
        scale_name='aeolian',
        max=4,
        tonic=False,
        resolve=False,
        # scale=list(scale_map.keys()),
        verbose=True,
    )
    default_scale = g.scale
    default_scale_map = dict(zip(g.scale, g.chord_map))
    if default_quality == 'm':
        scale_map = {
            'A': 'm',
            'C': '',
            'D': 'm',
            'E': 'm',
            'G': '',
        }
    else:
        scale_map = {
            'C': '',
            'E': 'm',
            'F': '',
            'G': '',
            'A': 'm',
        }
    g.map_net_weights(scale_map=scale_map)

    device = Device(verbose=False)

    r = Rhythm(
        measure_size=1,
        durations=[ 1/8, 1/4, 1/2, 1/3 ],
        groups={ 1/3: 3 },
    )

    # signal the synth1_stream thread on each clock tick
    clock_tick_event = threading.Event()
    clock_tick_count = 0
    bpm = 100 # for the clock
    clocks_per_beat = 24
    interval = 60 / (bpm * clocks_per_beat) # time between clock messages at 24 PPQN per beat
    stop_threads = False

    velocity = 100
    velo = lambda: velocity + random.randint(-10, 10)
    chance = lambda: random.random() < 0.5

    with mido.open_output(synth1_port_name) as synth1_outport, mido.open_output(synth2_port_name) as synth2_outport:
        print(synth1_outport, synth2_outport)
        clock_thread = threading.Thread(target=midi_clock_thread, daemon=True) # daemon = stops when main thread exits
        synth_thread = threading.Thread(target=synth_stream_thread, daemon=True)
        clock_thread.start()
        synth_thread.start()
        try:
            while True:
                time.sleep(interval) # keep main thread alive and respond to interrupts
        except KeyboardInterrupt:
            print("\nSignaling threads to stop...")
            stop_threads = True
            clock_thread.join()
            synth_thread.join()
            print("All threads stopped.")
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            synth1_outport.close()
