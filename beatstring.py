from music_creatingrhythms import Rhythms
from music_drummer import Drummer
import random

beats = 16

def pattern1(rhythm, drummer, n=4, section=0):
    if section == 1:
        n //= 2
    kick  = ''.join([str(n) for n in rhythm.euclid(2, beats)])
    snare = ''.join([str(n) for n in rhythm.rotate_n(4, rhythm.euclid(2, beats))])
    hihat = ''.join([str(n) for n in rhythm.euclid(11, beats)])
    for _ in range(n):
        drummer.pattern(
            patterns={
                'kick': kick,
                'snare': snare,
                'hihat': hihat,
            }
        )

def even_odd_nums(max=16, min=3):
    odd_numbers = []
    even_numbers = []
    for i in range(min, max + 1):
        if i % 2 == 0:
            even_numbers.append(i)
        else:
            odd_numbers.append(i)
    return even_numbers, odd_numbers

def pattern2(rhythm, drummer, n=4):
    evens, odds = even_odd_nums(11)
    kick  = ''.join([str(n) for n in rhythm.euclid(random.choice(evens), beats)])
    snare = ''.join([str(n) for n in rhythm.euclid(random.choice(odds), beats)])
    hihat = ''.join([str(n) for n in rhythm.euclid(random.choice(odds), beats)])
    for _ in range(n):
        drummer.pattern(
            patterns={
                'kick':  kick,
                'snare': snare,
                'hihat': hihat,
            }
        )

def main():
    r = Rhythms()
    d = Drummer()

    d.set_instrument('kick', 'kick2')
    d.set_instrument('snare', 'snare2')

    d.set_ts()
    d.set_bpm(100)

    d.count_in()
    d.rest(['kick', 'snare'], duration=4)
    pattern1(r, d)
    pattern2(r, d)
    pattern1(r, d, section=1)

    d.sync_parts()
    d.show('midi')
    # d.score.write(filename='drums.mid')

if __name__ == "__main__":
    main()
