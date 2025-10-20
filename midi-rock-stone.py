import mido # also install python-rtmidi
import os
import re
import sys
import time
import yaml

out_port_name = sys.argv[3] if len(sys.argv) > 3 else 'SE-02'
in_port_name = sys.argv[2] if len(sys.argv) > 2 else 'MIDI ROCK Joystick'
device_file = sys.argv[1] if len(sys.argv) > 1 else sys.argv[0]

match = re.search(r'^(.+?)\.py$', device_file)
if match:
    device_file = match.group(1)
    device_file = device_file + '.yaml'
if not os.path.exists(device_file):
    print(device_file, 'does not exist')

def send_to(outport, mtype, patch, data, channel=0, velocity=100):
    if mtype == 'control_change':
        msg = mido.Message('control_change', control=patch, value=data, channel=channel)
        outport.send(msg)
    elif mtype == 'program_change':
        msg = mido.Message('program_change', program=patch, channel=channel)
        outport.send(msg)
    else:
        msg = mido.Message('note_on', note=patch, velocity=velocity, channel=channel)
        outport.send(msg)
        time.sleep(data)
        msg = mido.Message('note_off', note=patch, velocity=velocity, channel=channel)
        outport.send(msg)

def get_by_value(dictionary, target_value):
    found = False
    for item in dictionary['messages']:
        for value in item.values():
            print(value)
            if value == target_value:
                found = True
                break
        if found:
            break
    return item

with open(device_file, 'r') as f:
    data = yaml.safe_load(f)
    # print(data)
    item = get_by_value(data, 'green button')
    print(item)

try:
    with mido.open_input(in_port_name) as inport:
        print('Listening to:', inport.name)
        with mido.open_output(out_port_name) as outport:
            print('Sending to:', outport.name)
            for msg in inport:
                if msg.type != 'clock':
                    print(f"Received: {msg}")
                    if msg.type == 'control_change' and msg.control == 26 and msg.value == 0:
                        send_to(outport, 'program_change', 99, 0)
                    elif msg.type == 'control_change' and msg.control == 26 and msg.value == 127:
                        send_to(outport, 'program_change', 98, 1)
except KeyboardInterrupt:
    print('Stopping MIDI I/O.')
except Exception as e:
    print(f"ERROR: {e}")