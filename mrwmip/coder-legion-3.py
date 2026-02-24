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

    kick = 36
    snare = 40
    hihat = 42
    repeat = 16

    r = Rhythms()

    s_comps = r.compm(4, 2) # snare compositions of 4 with 2 elements
    # [[1, 3], [2, 2], [3, 1]]
    s_seq = r.int2b(s_comps)
    # [[1, 1, 0, 0], [1, 0, 1, 0], [1, 0, 0, 1]]

    k_comps = r.compm(4, 3) # kick compositions of 4 with 3 elements
    # [[1, 1, 2], [1, 2, 1], [2, 1, 1]]
    k_seq = r.int2b(k_comps)
    # [[1, 1, 1, 0], [1, 1, 0, 1], [1, 0, 1, 1]]

    h_seq = [[1, 1, 1, 1]] # hihat

    for _ in range(repeat):
        s_choice = random.choice(s_seq)
        k_choice = random.choice(k_seq)
        for i in range(len(s_choice)):
            simul = {
                snare: s_choice[i],
                kick: k_choice[i],
                hihat: 1,
            }
            print(simul)
            play_simul(simul)

    mid.save('coder-legion-3.mid')