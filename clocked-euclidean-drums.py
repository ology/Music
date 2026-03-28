#!/usr/bin/env python3

import sys
import time
import random
import mido
from mido import Message
from music_creatingrhythms import Rhythms
from find_primes import all_primes

def adjust_drums(mcr, drums, primes_dict, toggle):
    p = random.choice(primes_dict['all'])
    q = random.choice(primes_dict['to_5'])
    r = random.choice(primes_dict['to_7'])

    beats = 16
    if toggle[0] == 0:
        print('part A')
        drums['hihat']['pat'] = mcr.euclid(p, beats)
        drums['kick']['pat'] = mcr.euclid(q, beats)
        drums['snare']['pat'] = mcr.rotate_n(r, mcr.euclid(2, beats))
        toggle[0] = 1
    else:
        print('part B')
        drums['hihat']['pat'] = mcr.euclid(p, beats)
        drums['kick']['pat'] = [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1]
        drums['snare']['pat'] = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0]
        toggle[0] = 0
    return drums['hihat']['pat'][0]

def main():
    name = sys.argv[1] if len(sys.argv) > 1 else 'USB MIDI Interface'
    bpm  = int(sys.argv[2]) if len(sys.argv) > 2 else 120
    chan = int(sys.argv[3]) if len(sys.argv) > 3 else 9

    drums = {
        'kick':  { 'num': 36, 'chan': 0 if chan < 0 else chan, 'pat': [] },
        'snare': { 'num': 38, 'chan': 1 if chan < 0 else chan, 'pat': [] },
        'hihat': { 'num': 42, 'chan': 2 if chan < 0 else chan, 'pat': [] },
    }

    beats = 16
    divisions = 4
    clocks_per_beat = 24
    clock_interval = 60 / bpm / clocks_per_beat
    sixteenth = clocks_per_beat / divisions

    primes_dict = {
        'all':  all_primes(beats, 'list'),
        'to_5': all_primes(5, 'list'),
        'to_7': all_primes(7, 'list'),
    }

    ticks = [0]
    beat_count = [0]
    toggle = [0]
    queue = []

    try:
        with mido.open_output(name) as midi_out:
            mcr = Rhythms()

            while True:
                midi_out.send(Message('clock'))
                ticks[0] += 1

                if ticks[0] % sixteenth == 0:
                    if beat_count[0] % (beats * divisions) == 0:
                        adjust_drums(mcr, drums, primes_dict, toggle)

                    for drum in drums:
                        if drums[drum]['pat'][beat_count[0] % beats]:
                            queue.append({'drum': drum, 'velocity': 127})

                    for item in queue:
                        drum_name = item['drum']
                        msg = Message('note_on', channel=drums[drum_name]['chan'],
                                    note=drums[drum_name]['num'], velocity=item['velocity'])
                        midi_out.send(msg)

                    beat_count[0] += 1
                else:
                    while queue:
                        item = queue.pop()
                        drum_name = item['drum']
                        msg = Message('note_off', channel=drums[drum_name]['chan'],
                                    note=drums[drum_name]['num'], velocity=0)
                        midi_out.send(msg)

                time.sleep(clock_interval)
    except KeyboardInterrupt:
        print("\nStop")

if __name__ == '__main__':
    main()