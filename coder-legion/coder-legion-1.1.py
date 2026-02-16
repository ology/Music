from mido import Message, MidiFile, MidiTrack, MetaMessage, bpm2tempo
from music_creatingrhythms import Rhythms

def play_midi(sequence):
    global track
    snare = 40
    channel = 9
    t=240 # nb: mido default 480 ticks per (quarter-note) beat
    for bit in sequence:
        if bit == 1:
            msg = Message('note_on', note=snare, channel=channel, velocity=100, time=0)
            track.append(msg)
            msg = Message('note_off', note=snare, channel=channel, velocity=0, time=t)
            track.append(msg)
        else: # rest
            track.append(Message('note_on', note=snare, velocity=0, time=t)) 
            track.append(Message('note_off', note=snare, velocity=0, time=t))

if __name__ == '__main__':
    mid = MidiFile()
    track = MidiTrack()
    mid.tracks.append(track)
    tempo = bpm2tempo(120)
    track.append(MetaMessage('set_tempo', tempo=tempo, time=0))
    track.append(MetaMessage('time_signature', numerator=4, denominator=4, time=0))

    r = Rhythms()

    parts = r.part(5)
    # [[1, 1, 1, 1, 1], [1, 1, 1, 2], [1, 1, 3], [1, 2, 2], [1, 4], [2, 3], [5]]
    p = parts[2] # [1, 1, 3]
    seq = r.int2b([p]) # [[1, 1, 1, 0, 0]]

    for _ in range(4):
        play_midi(seq[0])

    mid.save('coder-legion-1.1.mid')
