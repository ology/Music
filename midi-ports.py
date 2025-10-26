import mido

# available input port names
input_ports = mido.get_input_names()
print("Available Input Ports:")
for port_name in input_ports:
    print(f"- {port_name}")

# available output port names
output_ports = mido.get_output_names()
print("\nAvailable Output Ports:")
for port_name in output_ports:
    print(f"- {port_name}")

# available both I/O port names
ioports = mido.get_ioport_names()
print("\nAvailable I/O Ports:")
for port_name in ioports:
    print(f"- {port_name}")