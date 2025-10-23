import mido # also install python-rtmidi
import os
import re
import sys
import time
import yaml

device_file = sys.argv[1] if len(sys.argv) > 1 else sys.argv[0]

match = re.search(r'^(.+?)\.py$', device_file)
if match:
    device_file = match.group(1)
    device_file = device_file + '.yaml'
if not os.path.exists(device_file):
    print(device_file, 'does not exist')
    sys.exit()

def send_to(outport, mtype, patch=0, data=0, channel=0, velocity=100):
    if mtype == 'start' or mtype == 'stop':
        msg = mido.Message(mtype)
        outport.send(msg)
    elif mtype == 'control_change':
        msg = mido.Message(mtype, control=patch, value=data, channel=channel)
        outport.send(msg)
    elif mtype == 'pitchwheel':
        msg = mido.Message(mtype, pitch=data, channel=channel)
        outport.send(msg)
    elif mtype == 'program_change':
        msg = mido.Message(mtype, program=patch, channel=channel)
        outport.send(msg)
    else:
        msg = mido.Message('note_on', note=patch, velocity=velocity, channel=channel)
        outport.send(msg)
        time.sleep(data)
        msg = mido.Message('note_off', note=patch, velocity=velocity, channel=channel)
        outport.send(msg)

with open(device_file, 'r') as f:
    data = yaml.safe_load(f)
    in_port_name = data['controller']
    out_port_name = data['device']

try:
    with mido.open_input(in_port_name) as inport:
        print('Listening to:', inport.name)
        with mido.open_output(out_port_name) as outport:
            print('Sending to:', outport.name)
            for msg in inport:
                if msg.type == 'clock':
                    continue
                print(f"Received: {msg}")
                # if msg.type == 'note_on' and msg.note == start:
                #     send_to(outport, 'start')
                # elif msg.type == 'note_on' and msg.note == stop:
                #     send_to(outport, 'stop')
                # elif msg.type == 'control_change' and msg.control == 1:
                #     send_to(outport, 'control_change', msg.control, msg.value)
                # elif msg.type == 'pitchwheel':
                #     send_to(outport, 'pitchwheel', 0, msg.pitch)
                # elif msg.type == 'control_change' and msg.control == 9:
                #     send_to(outport, 'program_change', msg.value)
except KeyboardInterrupt:
    print('Stopping MIDI I/O.')
except Exception as e:
    print(f"ERROR: {e}")