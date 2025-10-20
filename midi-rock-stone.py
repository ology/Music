import mido # also install python-rtmidi
import os
import re
import sys
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

with open(device_file, 'r') as f:
    data = yaml.safe_load(f)
    print(data)

try:
    with mido.open_input(in_port_name) as inport:
        print(f"Listening to: {inport.name}")
        with mido.open_output(out_port_name) as outport:
            for msg in inport:
                if msg.type != 'clock':
                    if msg.type == 'control_change' and msg.control == 26 and msg.value == 0:
                        print(f"Received: {msg}")
                    elif msg.type == 'control_change' and msg.control == 26 and msg.value == 127:
                        print(f"Received: {msg}")
except KeyboardInterrupt:
    print("Stopping MIDI input.")
except Exception as e:
    print(f"ERROR: {e}")