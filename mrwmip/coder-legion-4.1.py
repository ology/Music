import random
from mido import Message, MidiFile, MidiTrack, MetaMessage, bpm2tempo
from music_creatingrhythms import Rhythms

def play_midi(sequence):
    global mid, track
    note = 75 # claves
    channel = 9
    t = mid.ticks_per_beat // 2 # nb: 480 = quarter-note
    for bit in sequence:
        if bit == 1:
            msg = Message('note_on', note=note, channel=channel, velocity=100, time=0)
            track.append(msg)
            msg = Message('note_off', note=note, channel=channel, velocity=0, time=t)
            track.append(msg)
        else: # rest
            track.append(Message('note_on', note=note, velocity=0, time=t))
            track.append(Message('note_off', note=note, velocity=0, time=t))

if __name__ == '__main__':
    mid = MidiFile()
    track = MidiTrack()
    mid.tracks.append(track)
    tempo = bpm2tempo(120)
    track.append(MetaMessage('set_tempo', tempo=tempo, time=0))
    track.append(MetaMessage('time_signature', numerator=4, denominator=4, time=0))

    repeat = 4
    beats = 8

    r = Rhythms()

    necklaces = r.neck(beats) # all necklaces of 16 beats

    choice = random.choice(necklaces)
    print(choice)

    for _ in range(repeat):
        play_midi(choice)

    mid.save('coder-legion-4.1.mid')
