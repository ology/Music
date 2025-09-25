import mido
import time
import threading

MIDI_PORT_NAME = 'USB MIDI Interface'
BPM = 100
NOTE_DURATION_SECONDS = 0.5
NOTE_VELOCITY = 100

# Calculate delay for MIDI clock (24 clock messages per quarter note)
CLOCK_DELAY = (60 / BPM) / 24

try:
    outport = mido.open_output(MIDI_PORT_NAME)
    # print(f"Opened MIDI port: {MIDI_PORT_NAME}")
except Exception as e:
    print(f"Error opening MIDI port: {e}")
    exit()

def midi_clock_thread():
    while True:
        outport.send(mido.Message('clock'))
        time.sleep(CLOCK_DELAY)

def note_stream_thread():
    notes_to_play = [60, 62, 64, 65, 67, 69, 71, 72] # C major scale    
    for note in notes_to_play:
        msg_on = mido.Message('note_on', note=note, velocity=NOTE_VELOCITY)
        outport.send(msg_on)
        time.sleep(NOTE_DURATION_SECONDS) # Hold note for a duration
        msg_off = mido.Message('note_off', note=note, velocity=NOTE_VELOCITY)
        outport.send(msg_off)
        time.sleep(0.1) # Small delay between notes

if __name__ == "__main__":
    clock_thread = threading.Thread(target=midi_clock_thread, daemon=True) # Daemon so it stops when main thread exits
    note_thread = threading.Thread(target=note_stream_thread)

    clock_thread.start()
    note_thread.start()

    note_thread.join() # Wait for the note stream to finish

    outport.close()