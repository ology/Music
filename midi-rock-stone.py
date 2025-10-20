import os
import re
import sys
import yaml

device_file = sys.argv[1] if len(sys.argv) > 1 else sys.argv[0]
match = re.search(r'^(.+?)\.py$', device_file)
if match:
    device_file = match.group(1)
device_file = device_file + '.yaml'
if os.path.exists(device_file):
    with open(device_file, 'r') as f:
        data = yaml.safe_load(f)
        print(data)
else:
    print(device_file, 'does not exist')