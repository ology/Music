import mido # also install python-rtmidi
import os
import re
import sys
import yaml

port_name = sys.argv[2] if len(sys.argv) > 2 else 'MIDI ROCK Joystick'
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
    with mido.open_input(port_name) as port:
        print(f"Listening to: {port.name}")
        for msg in port:
            if msg.type != 'clock':
                print(f"Received: {msg}")
except KeyboardInterrupt:
    print("Stopping MIDI input.")
except Exception as e:
    print(f"ERROR: {e}")