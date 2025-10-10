from music21 import stream, note, duration
import numpy as np
import random

def mandelbrot_escape_count(c, max_iterations=50):
    z = 0
    for i in range(max_iterations):
        z = z**2 + c
        if abs(z) > 2:
            return i
    return max_iterations

width, height = 50, 50
# x_min, x_max = -0.5, 0.5
# y_min, y_max = -0.5, 0.5
x_min, x_max = -random.random(), random.random()
y_min, y_max = -random.random(), random.random()

max_iter = 50
min_pitch = 60
max_pitch = min_pitch + 24

data = np.zeros((height, width))
for row in range(height):
    for col in range(width):
        real_part = x_min + (col / width) * (x_max - x_min)
        imag_part = y_min + (row / height) * (y_max - y_min)
        c = complex(real_part, imag_part)
        data[row, col] = mandelbrot_escape_count(c)

s = stream.Stream()

# pitch based on escape count
# duration is the inverse of escape count (longer for lower counts)
for row in range(data.shape[0]):
    for col in range(data.shape[1]):
        escape_val = data[row, col]

        # escape_val to pitch
        normalized = 1 - (escape_val / max_iter)
        midi_pitch = min_pitch + (normalized * (max_pitch - min_pitch))
        n = note.Note(midi=midi_pitch)
        # escape_val to duration
        if escape_val > 0:
            n.duration = duration.Duration(1 / (escape_val * 0.5)) # higher count = faster
        else:
            n.duration = duration.Duration(2.0)
        # print(f"escape_val: {escape_val}, #: {midi_pitch}, d: {n.duration}")

        if escape_val < max_iter:
            s.append(n)

s.show('midi')