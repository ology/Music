from music21 import duration, note, stream
from music_melodicdevice import Device

# default scale: chromatic
device = Device(notes=['C4', 'E4', 'D4', 'G4'])
notes = device.transpose(2) # ['D4', 'F#4', 'E4', 'A4', 'D5']
notes = device.invert('C5')

s = stream.Stream()
p = stream.Part()
for i in device.notes + notes:
    n = note.Note(i)
    n.duration = duration.Duration(1)
    p.append(n)
s.append(p)
s.show()

"""

# diatonic transformation:
device = Device(scale_name='major', verbose=False)
device.notes = ['C4', 'E4', 'D4', 'G4', 'C5']
notes = device.transpose(2) # ['E4', 'G4', 'F4', 'B4', 'E5']
notes = device.invert('C4') # ['C4', 'A3', 'B3', 'F3', 'C3']

# unknown note:
device = Device()
device.build_scale('major')
notes = device.transpose(2, ['C4', 'E4', 'D#4', 'G4', 'C5'])
# ['E4', 'G4', None, 'B4', 'E5']
notes = device.invert('C4', ['C4', 'E4', 'D#4', 'G4', 'C5'])
# ['C4', 'A3', None, 'F3', 'C3']

# Ornamentation:

# chromatic
device = Device()

notes = device.grace_note(1, 'D5') # [[1/16, 'D5'], [1 - 1/16, 'D5']])
notes = device.grace_note(1, 'D5', offset=1) # [[1/16, 'D#5'], [1 - 1/16, 'D5']])
notes = device.grace_note(1, 'D5', offset=-1) # [[1/16, 'C#5'], [1 - 1/16, 'D5']])

notes = device.turn(1, 'D5') # [[1/4,'D#5'], [1/4,'D5'], [1/4,'C#5'], [1/4,'D5']])
notes = device.turn(1, 'D5', offset=-1) # [[1/4,'C#5'], [1/4,'D5'], [1/4,'D#5'], [1/4,'D5']])

notes = device.trill(1, 'D5', number=2, offset=1)
# [[1/4,'D5'], [1/4,'D#5'], [1/4,'D5'], [1/4,'D#5']])
notes = device.trill(1, 'D5', number=2, offset=-1)
# [[1/4,'D5'], [1/4,'C#5'], [1/4,'D5'], [1/4,'C#5']])

notes = device.mordent(1, 'D5', offset=1) # [[1/4,'D5'], [1/4,'D#5'], [1/2,'D5']])
notes = device.mordent(1, 'D5', offset=-1) # [[1/4,'D5'], [1/4,'C#5'], [1/2,'D5']])

notes = device.slide(1, 'D5', 'F5') # [[1/4,'D5'], [1/4,'D#5'], [1/4,'E5'], [1/4,'F5']])
notes = device.slide(1, 'D5', 'B4') # [[1/4,'D5'], [1/4,'C#5'], [1/4,'C5'], [1/4,'B4']])

# diatonic
device = Device(scale_name='major')

notes = device.grace_note(1, 'D5') # [[1/16, 'D5'], [1 - 1/16, 'D5']])
notes = device.grace_note(1, 'D5', offset=1) # [[1/16, 'E5'], [1 - 1/16, 'D5']])
notes = device.grace_note(1, 'D5', offset=-1) # [[1/16, 'C5'], [1 - 1/16, 'D5']])

notes = device.turn(1, 'D5', offset=1) # [[1/4,'E5'], [1/4,'D5'], [1/4,'C5'], [1/4,'D5']])
notes = device.turn(1, 'D5', offset=-1) # [[1/4,'C5'], [1/4,'D5'], [1/4,'E5'], [1/4,'D5']])

notes = device.trill(1, 'D5', number=2, offset=1) # [[1/4,'D5'], [1/4,'E5'], [1/4,'D5'], [1/4,'E5']])
notes = device.trill(1, 'D5', number=2, offset=-1) # [[1/4,'D5'], [1/4,'C5'], [1/4,'D5'], [1/4,'C5']])

notes = device.mordent(1, 'D5', offset=1) # [[1/4,'D5'], [1/4,'E5'], [1/2,'D5']])
notes = device.mordent(1, 'D5', offset=-1) # [[1/4,'D5'], [1/4,'C5'], [1/2,'D5']])
"""
