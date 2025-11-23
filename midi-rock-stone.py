import mido # also install python-rtmidi
import os
import re
import sys
import time
import yaml

# https://mido.readthedocs.io/en/latest/message_types.html
def send_to(outport, mtype, patch=0, data=0, channel=0, velocity=100):
    if mtype == 'start' or mtype == 'stop':
        msg = mido.Message(mtype)
        print(f"Out: {msg}")
        outport.send(msg)
    elif mtype == 'control_change':
        msg = mido.Message(mtype, control=patch, value=data, channel=channel)
        print(f"Out: {msg}")
        outport.send(msg)
    elif mtype == 'pitchwheel':
        msg = mido.Message(mtype, pitch=data, channel=channel)
        print(f"Out: {msg}")
        outport.send(msg)
    elif mtype == 'program_change':
        msg = mido.Message(mtype, program=patch, channel=channel)
        print(f"Out: {msg}")
        outport.send(msg)
    else:
        msg = mido.Message('note_on', note=patch, velocity=velocity, channel=channel)
        print(f"Out: {msg}")
        outport.send(msg)
        time.sleep(data)
        msg = mido.Message('note_off', note=patch, velocity=velocity, channel=channel)
        print(f"Out: {msg}")
        outport.send(msg)

# data arg keys: type (required), cmd (required), note, control, target, data
def dispatch(port, msg, data):
    for m in data['messages']:
        if msg.type == m['type']:
            if m['type'] == 'note_on' and m['cmd'] == 'control_change' and msg.note == m['note']:
                send_to(port, m['cmd'], patch=m['target'], data=m['data'])
            elif m['type'] == 'note_on' and msg.note == m['note']:
                send_to(port, m['cmd'])
            elif m['type'] == 'control_change' and m['cmd'] == 'program_change' and msg.control == m['control']:
                send_to(port, 'program_change', patch=msg.value)
            elif m['type'] == 'control_change' and msg.control == m['control'] and 'data' in m:
                send_to(port, 'control_change', patch=m['target'], data=m['data'])
            elif m['type'] == 'control_change' and msg.control == m['control']:
                send_to(port, 'control_change', patch=m['target'], data=msg.value)
            elif m['type'] == 'pitchwheel' and m['cmd'] == 'control_change':
                scaled_result = scale_number(msg.pitch, -8192, 8192, 0, 127)
                send_to(port, 'control_change', patch=m['target'], data=scaled_result)
            elif m['type'] == 'pitchwheel':
                send_to(port, 'pitchwheel', data=msg.pitch)

def scale_number(value, original_min, original_max, target_min, target_max):
    """
    Scales a number from one range to another as an integer.
    Args:
        value: The number to be scaled.
        original_min: minimum value of the original range
        original_max: maximum value of the original range
        target_min: minimum value of the target range
        target_max: maximum value of the target range
    Returns:
        float: The integer scaled number in the target range
    """
    if original_max == original_min:
        # Handle the case where the original range is a single point
        return target_min  # Or raise an error, depending on desired behavior
    scaled_value = ((value - original_min) * (target_max - target_min)) / (original_max - original_min) + target_min
    return round(scaled_value)

if __name__ == "__main__":
    device_file = sys.argv[1] if len(sys.argv) > 1 else sys.argv[0]

    match = re.search(r'^(.+?)\.py$', device_file)
    if match:
        device_file = match.group(1)
        device_file = device_file + '.yaml'
    if not os.path.exists(device_file):
        print(device_file, 'does not exist')
        sys.exit()

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
                    print(f"In: {msg}")
                    dispatch(outport, msg, data)
    except KeyboardInterrupt:
        print('Stopping MIDI I/O.')
    except Exception as e:
        print(f"ERROR: {e}")