import random
from mido import Message, MidiFile, MidiTrack, MetaMessage, bpm2tempo
from music_creatingrhythms import Rhythms

def open_mid():
    mid = MidiFile()
    track = MidiTrack()
    mid.tracks.append(track)
    tempo = bpm2tempo(120)
    track.append(MetaMessage('set_tempo', tempo=tempo, time=0))
    track.append(MetaMessage('time_signature', numerator=4, denominator=4, time=0))
    return mid, track

def play_simul(notes):
    global mid, track
    channel = 9
    duration = mid.ticks_per_beat // 4 # nb: 480 = quarter-note
    for i, n in enumerate(notes):
        bit = notes[n]
        t = duration if i == 0 else 0
        if bit == 1:
            msg = Message('note_on', note=n, channel=channel, velocity=100, time=t)
            track.append(msg)
        else: # rest
            track.append(Message('note_on', note=n, velocity=0, time=t)) 
    for i, n in enumerate(notes):
        bit = notes[n]
        t = duration if i == 0 else 0
        if bit == 1:
            msg = Message('note_off', note=n, channel=channel, velocity=0, time=t)
            track.append(msg)
        else: # rest
            track.append(Message('note_off', note=n, velocity=0, time=t))

if __name__ == '__main__':
    mid, track = open_mid()

    claves = 75
    hi_conga = 63
    low_conga = 64
    repeat = 6
    beats = 8

    r = Rhythms()

    necklaces = r.neck(beats) # all necklaces of 16 beats

    x_choice = random.choice(necklaces)
    y_choice = random.choice(necklaces)
    z_choice = random.choice(necklaces)

    for _ in range(repeat):
        for i in range(len(x_choice)):
            simul = {
                claves: x_choice[i],
                hi_conga: y_choice[i],
                low_conga: z_choice[i],
            }
            print(simul)
            play_simul(simul)

    mid.save('coder-legion-4.2.mid')
