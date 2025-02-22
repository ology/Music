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
            msgs = input_port.iter_pending()
            # for msg in input_port.iter_pending():
            for msg in msgs:
                # if msg.type == 'note_on':
                output_port.send_message(msg.bytes())
                await asyncio.sleep(0.2)
                # output_port.send_message(msg.bytes())
                # input_port.send_message(
                m = mido.Message('note_on', note=60, velocity=100, time=6.2)
                input_port._messages.append(m)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print('Interrupted')
        try:
            sys.exit(130)
        except SystemExit:
            os._exit(130)
