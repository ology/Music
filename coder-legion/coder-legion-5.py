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
    repeat = 4
    beats = 16

    r = Rhythms()

    s_pat = r.rotate_n(4, r.euclid(2, beats)) # snare
    k_pat = r.euclid(2, beats) # kick
    h_pat = r.euclid(11, beats) # hihats

    for _ in range(repeat):
        for i in range(beats):
            simul = {
                snare: s_pat[i],
                kick: k_pat[i],
                hihat: h_pat[i],
            }
            print(simul)
            play_simul(simul)

    mid.save('coder-legion-5.mid')