from mido import Message, MidiFile, MidiTrack, MetaMessage, bpm2tempo
from music_creatingrhythms import Rhythms

def play_midi(sequence):
    global mid, track
    snare = 40
    channel = 9
    eighth = mid.ticks_per_beat // 2 # nb: 480 = quarter-note
    for bit in sequence:
        if bit == 1:
            msg = Message('note_on', note=snare, channel=channel, velocity=100, time=0)
            track.append(msg)
            msg = Message('note_off', note=snare, channel=channel, velocity=0, time=eighth)
            track.append(msg)
        else: # rest
            track.append(Message('note_on', note=snare, velocity=0, time=eighth)) 
            track.append(Message('note_off', note=snare, velocity=0, time=eighth))

if __name__ == '__main__':
    mid = MidiFile()
    track = MidiTrack()
    mid.tracks.append(track)
    tempo = bpm2tempo(120)
    track.append(MetaMessage('set_tempo', tempo=tempo, time=0))
    track.append(MetaMessage('time_signature', numerator=4, denominator=4, time=0))

    r = Rhythms()

    comps = r.compm(5, 3) # compositions of 5 with 3 elements
    # [[1, 1, 3], [1, 2, 2], [1, 3, 1], [2, 1, 2], [2, 2, 1], [3, 1, 1]]
    seq = r.int2b(comps)
    # [[1, 1, 1, 0, 0], [1, 1, 0, 1, 0], [1, 1, 0, 0, 1], [1, 0, 1, 1, 0], [1, 0, 1, 0, 1], [1, 0, 0, 1, 1]]

    for s in seq:
        play_midi(s)

    mid.save('coder-legion-2.1.mid')