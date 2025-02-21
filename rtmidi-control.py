import asyncio
import mido
import sys
import os
import rtmidi

async def main():
    output_port = rtmidi.MidiOut()
    output_port.open_port(2) # FluidSynth virtual port (96411)
    port_name = 'Synido TempoPAD Z-1'
    with mido.open_input(port_name) as input_port:
        print(f"Connected to MIDI input port: {port_name}")
        while True:
            await asyncio.sleep(0.01)
            for msg in input_port.iter_pending():
                await play(output_port, msg)

async def play(midi_port, message):
    print(f"Received MIDI message: {message}")
    midi_port.send_message(message.bytes())
    await asyncio.sleep(0.5)
    midi_port.send_message(message.bytes())

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print('Interrupted')
        try:
            sys.exit(130)
        except SystemExit:
            os._exit(130)
