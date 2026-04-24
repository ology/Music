#!/usr/bin/env python3
import csv
from pathlib import Path
import mido
from mido import Message, MidiFile, MidiTrack

midi_range = (48, 83)
x_range = (-25.0, 25.0)
yz_range = (0.0, 50.0)

SIGMA = 10.0
RHO = 28.0
BETA = 8.0 / 3.0

def uniform_scaling(source, target, value):
    a, b = source
    c, d = target
    if b == a:
        return c
    return c + (value - a) * (d - c) / (b - a)

def rk4(f, t, y, dt):
    k1 = f(t, y)
    k2 = f(t + dt / 2, [y[i] + k1[i] * dt / 2 for i in range(len(y))])
    k3 = f(t + dt / 2, [y[i] + k2[i] * dt / 2 for i in range(len(y))])
    k4 = f(t + dt, [y[i] + k3[i] * dt for i in range(len(y))])
    return [
        y[i] + (dt / 6) * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i])
        for i in range(len(y))
    ]

def lorenz(t, y):
    x, yy, z = y
    return [
        SIGMA * (yy - x),
        x * (RHO - z) - yy,
        x * yy - BETA * z,
    ]

def avoid_accidental(value):
    n = int(round(value))
    naturals = {0, 2, 4, 5, 7, 9, 11}
    while (n % 12) not in naturals:
        n += 1
    return n

def create_midi(notes, path):
    mid = MidiFile()
    track = MidiTrack()
    mid.tracks.append(track)
    track.append(mido.MetaMessage('track_name', name='Lorenz attractor', time=0))
    track.append(Message('program_change', program=4, time=0))
    time_per_chord = 480

    for chord in notes:
        for note in chord:
            track.append(Message('note_on', note=note, velocity=64, time=0))
        track.append(Message('note_off', note=chord[0], velocity=64, time=time_per_chord))
        track.append(Message('note_off', note=chord[1], velocity=64, time=0))
        track.append(Message('note_off', note=chord[2], velocity=64, time=0))

    mid.save(path)


def main():
    t = 0.0
    t_end = 50.0
    dt = 0.01
    y = [1.0, 1.0, 1.0]

    path = Path(__file__)
    csv_path = path.with_suffix(path.suffix + '.csv')
    mid_path = path.with_suffix(path.suffix + '.mid')

    notes = []
    with csv_path.open('w', newline='') as fh:
        writer = csv.writer(fh)
        writer.writerow(['t', 'x', 'y', 'z'])
        while t <= t_end:
            writer.writerow([f'{t:.8g}', f'{y[0]:.8g}', f'{y[1]:.8g}', f'{y[2]:.8g}'])
            y = rk4(lorenz, t, y, dt)
            t += dt
            n1 = uniform_scaling(x_range, midi_range, y[0])
            n2 = uniform_scaling(yz_range, midi_range, y[1])
            n3 = uniform_scaling(yz_range, midi_range, y[2])
            notes.append((avoid_accidental(n1), avoid_accidental(n2), avoid_accidental(n3)))

    create_midi(notes, mid_path)

if __name__ == '__main__':
    main()
