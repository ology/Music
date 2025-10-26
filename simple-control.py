import mido
import sys

in_port_name = sys.argv[1] if len(sys.argv) > 1 else sys.argv[0]
out_port_name = sys.argv[2] if len(sys.argv) > 2 else sys.argv[0]

try:
    inport = mido.open_input(in_port_name)
    print(f"Listening for messages from: {inport.name}")
    outport = mido.open_output(out_port_name)
    print(f"Sending messages to: {outport.name}")
except (ValueError, OSError) as e:
    print(f"Error opening ports: {e}")
    exit()

print("Routing MIDI messages. Ctrl+C to exit.")
try:
    for msg in inport:
        print(f"Received: {msg}")
        outport.send(msg)

except KeyboardInterrupt:
    print("\nExiting MIDI router.")
finally:
    inport.close()
    outport.close()
