# Music

> Theory, Algorithmic Composition, Experimentation

A collection of Perl, Python, and R scripts for generating MIDI music, exploring music theory, and experimenting with algorithmic and mathematical composition techniques.

---

## Overview

This repository is a sandbox of musical experiments spanning:

- **Algorithmic composition** — using genetic algorithms, cellular automata, fractals, and chaos theory to generate music
- **Music theory exploration** — scales, modes, chord progressions, intervals, cadences, and harmonic analysis
- **Rhythm generation** — Euclidean rhythms, drum patterns, MIDI drum machine scripts
- **Real-piece transcriptions** — faithful MIDI renderings of jazz standards and classical pieces
- **Mathematical sonification** — mapping physics and mathematics (Lorenz attractors, Mandelbrot sets, astrophysics data) to sound
- **MIDI tooling** — capture, routing, real-time clock control, and device configuration
- **Hardware control** — scripts that clock and drive drum machines, synths and Eurorack, plus a web UI for a Volca Drum

Almost every program is a standalone, single-file script. Many have a write-up on <https://ology.github.io>; look for the link in the script's header comments.

---

## Languages & Dependencies

| Language | Share |
|----------|-------|
| Perl 5   | ~81%  |
| Python   | ~19%  |
| R        | <1%   |

### Key Perl Modules

- [`MIDI::Util`](https://metacpan.org/pod/MIDI::Util) — score setup and MIDI helpers
- [`MIDI::Drummer::Tiny`](https://metacpan.org/pod/MIDI::Drummer::Tiny) — drum pattern generation
- [`MIDI::Simple`](https://metacpan.org/pod/MIDI::Simple) — low-level MIDI score building
- [`MIDI::Chord::Guitar`](https://metacpan.org/pod/MIDI::Chord::Guitar) — guitar chord voicings
- [`Music::Duration::Partition`](https://metacpan.org/pod/Music::Duration::Partition) — rhythmic motif generation
- [`Music::CreatingRhythms`](https://metacpan.org/pod/Music::CreatingRhythms) — Euclidean and other rhythm algorithms
- [`Music::AtonalUtil`](https://metacpan.org/pod/Music::AtonalUtil) — pitch-set operations (invert, retrograde, transpose, rotate)
- [`Music::Chord::Note`](https://metacpan.org/pod/Music::Chord::Note) — chord-to-note mapping
- [`Music::Note`](https://metacpan.org/pod/Music::Note) — note name/MIDI number conversions
- [`AI::Genetic`](https://metacpan.org/pod/AI::Genetic) — genetic algorithm engine
- [`Music::VoiceGen`](https://metacpan.org/pod/Music::VoiceGen) — constrained, weighted melodic voices
- [`Music::Scales`](https://metacpan.org/pod/Music::Scales) / [`Music::ScaleNote`](https://metacpan.org/pod/Music::ScaleNote) — scale pitches and scale-aware note movement
- [`Music::Cadence`](https://metacpan.org/pod/Music::Cadence) / [`Music::Chord::Namer`](https://metacpan.org/pod/Music::Chord::Namer) — cadences and chord naming
- [`Graph::Weighted`](https://metacpan.org/pod/Graph::Weighted) — weighted graph walks
- [`MIDI::RtMidi::FFI::Device`](https://metacpan.org/pod/MIDI::RtMidi::FFI::Device) / [`IO::Async`](https://metacpan.org/pod/IO::Async) — real-time MIDI I/O and clocking
- [`Game::Life`](https://metacpan.org/pod/Game::Life) — Conway's Game of Life grid
- [`Math::Utils`](https://metacpan.org/pod/Math::Utils) — scaling utilities

### Key Python Libraries

- `mido` / `python-rtmidi` — MIDI I/O and real-time clock
- `music21` — music analysis and notation
- `networkx`, `numpy`, `pychord`, `pyyaml` — graphs, math, chord names, YAML
- `fritter` — async clock scheduling
- The author's own packages: `music_voicegen`, `music_melodicdevice`, `music_bassline_generator`, `music_creatingrhythms`, `chord_progression_network`, `random_rhythms`, `music_drummer`

---

## Scripts by Category

### Algorithmic Composition

| Script | Description |
|--------|-------------|
| `ai-genetic` | Uses a genetic algorithm (`AI::Genetic`) to evolve a pitch set scored by consonance, then optionally evolves rhythm and velocity. Applies atonal transformations (inversion, retrograde, rotation, transposition). |
| `ai-genetic-pro` | `AI::Genetic::Pro` version: evolves pitches whose adjacent intervals must be 2–5 half-steps, then feeds them to contrapuntal transformations. |
| `algo-progression` | Generates a whole band by genre: chord progressions (from `Music::Dataset::ChordProgressions`), drums, bass line, and optional arpeggios. |
| `algo-progression-rt.pl` | Real-time version of `algo-progression`, played on an external device. |
| `cope` | Scores chord combinations with David Cope's tension model (`Music::Tension::Cope`). |
| `cope-genetic` | Genetic search over chords using Cope tension, with a dissonance threshold at the tritone. |
| `pso-cope.pl`, `pso-chord.pl`, `pso-music.pl` | Particle-swarm experiments using Cope tension and a Tenney-height dissonance model (`pso-chord.pl` is unfinished). |
| `bitstring-fitness` | Evolves bit-string individuals (`Algorithm::Evolutionary`) with a musical fitness function. |
| `evolver.pl` | Breeds MIDI phrases from a "mother" and "father" using partitions and permutations. |
| `fragments` | Builds pieces from short fragments using `Music::VoiceGen` and partitioned durations. |
| `micro-themed` | Micro-motifs with inversion and transposition (the header warns it "produces unsavory things"). |
| `reichify` | Steve Reich-style phasing built on cyclic permutations. |
| `tape-loop` | Imitates the tape-loop effect of Eno's *Music for Airports*. |

### Chaos, Fractals & Mathematics

| Script | Description |
|--------|-------------|
| `lorenz-attractor.pl` | Solves the Lorenz system using RK4 integration; maps x/y/z trajectory values to MIDI pitch ranges and writes quarter-note triads. Outputs a `.csv` of trajectory data alongside the MIDI file. |
| `lorenz-attractor.py` | Python equivalent of the above. |
| `mandelbrot_music.py` | Sonifies the Mandelbrot set — escape count drives pitch, and duration is its inverse. |
| `barycenter`, `barycenter3`, `barycenter4` | Genetic algorithms scored with `Music::Interval::Barycentric` chord geometry; `3` adds cadences and rhythm partitions. |
| `hilbert-notes` | Uses a Hilbert space-filling curve to traverse a note grid. |
| `astrophysics` | Space-themed piece built on Voss noise (`Music::Voss`). |
| `five-parsecs`, `kiloparsec` | Space-themed pieces: drums with fills and crashes, and Voss-noise melodies. |
| `event-horizon`, `gravity-well`, `sidereal-time` | More space-themed pieces using scale-note walking, cadences and chords. |
| `collision` | Wind-chime simulation with `Collision::2D`. |
| `base-fibo2`, `base-primes` | Fibonacci numbers and primes rewritten in other number bases and played. |
| `primes`, `primes-layered`, `prime-durations` | Primes as note indexes and durations. |
| `oeis-midi` | Plays any OEIS sequence modulo the number of notes in a scale. |
| `voss-method`, `voss-method-midi`, `voss-alteration` | Voss's 1/f method from *Musimathics* (numbers, MIDI, and phrase alteration). |
| `quantum` | Note choice via `Quantum::Superpositions::Lazy`. |
| `play-pixels`, `play-color-pixels` | Hear an image pixel by pixel (grayscale, or one chord per RGB colour). |
| `prolog-music` | Scale and note logic expressed in `AI::Prolog`. |

### Cellular Automata & Systems

| Script | Description |
|--------|-------------|
| `game-of-life-cluster` | Runs Conway's Game of Life on a grid of notes with incrementing octaves; each generation's live-cell cluster becomes a chord. Seeded with a glider (a blinker is commented out). |
| `lindenmayer-midi` | Applies L-system (Lindenmayer system) rewriting rules, supplied in YAML, to produce MIDI sequences. |
| `midi-turtle.pl` | Turtle-graphics-style movement (`Data::Turtle`) mapped to notes. |
| `cryptomorphic` | Voss-driven structure with rhythmic motifs and `Music::VoiceGen` melodies over drums. |
| `random-walk`, `random-walk-transform` | Random walks over weighted graphs (`Graph::Weighted`); the second adds atonal transformations. |
| `note-transition`, `stat-walk` | Count note transitions in a MIDI file (saved with `Storable`), then walk the frequencies to generate new music. `-sync` variants handle synchronized parts. |
| `synch-weighted`, `synch-weighted-randomized`, `synch-oo` | Weighted-graph chord and drum generators with synchronized parts. |
| `perm-perm`, `variations`, `combi-duras.pl` | Permutations, variations and duration combinations. |
| `random-selection`, `random-selection-mutate` | Random population samples compared by Levenshtein distance, then mutated. |

### Rhythm & Drums

| Script | Description |
|--------|-------------|
| `euclidean-beats` | Distributes kick and snare onsets using Euclidean rhythm algorithm with prime-number onset counts. Hi-hat plays straight eighths. |
| `euclidean-drums.pl` | Real-time Euclidean drum machine for an external MIDI device (args: verbose, port, BPM). |
| `clocked-euclidean-drums.pl` | Euclidean drum patterns synchronised to an external MIDI clock. |
| `clocked-euclidean-drum-fills.pl` | Adds fills to clocked Euclidean drum patterns. |
| `OMB.pl` | One-Man Band: generates randomised hi-hat, kick, and snare patterns plus drum fills using `Music::Duration::Partition`. Six fill styles descend the tom kit with optional cymbal substitutions. |
| `drum-circle` | Multi-part drum circle (has POD usage text). |
| `multi-timbral-drums.py`, `multi-timbral-drum-fills.pl` / `.py` | Euclidean patterns and snare fills with no clock, for multi-timbral gear. |
| `rand-drums`, `rand-drums.py`, `random-beat` | Randomised drum parts, and a random pick from all 3-strike eighth-note patterns. |
| `rhythm-necklace`, `rhythm-chunks` | Rhythm necklaces drawn as SVG, and rhythm pieces driven by `rhythm-chunks.yml`. |
| `tabla`, `applause.pl`, `possible-reggae` | Tabla patterns, synthesised applause, and a reggae groove. |
| `duration-selection` | Explores rhythmic duration selection strategies. |
| `figured-syncopation` | Realistic syncopated drum grooves (see the 2023 "realistic drum grooves" write-up). |
| `five-four-durations` | Experiments with 5/4 time signatures. |
| `quasi-random-durations`, `phrase-context`, `polygenic`, `oddness`, `fulfilled` | More duration-partition experiments with pitched voices over drums. |

### Music Theory

| Script | Description |
|--------|-------------|
| `all-modes` | Prints each chromatic note's seven modes (12 × 7 = 84). |
| `modal-chords`, `modal-stacked-3rds.pl`, `mode-pivot` | Chords by mode, stacked thirds, and modal pivots (`Music::ModalFunction`). |
| `which-keys` | Brute-forces which keys a given chord belongs to. |
| `all-possible-chords` | Enumerates note variations and names each chord (`Music::Chord::Namer`). |
| `intervals` | Large interval/ratio explorer (superseded by the `Music::Intervals` module). |
| `circle-intervals` | Draws SVG diagrams of interval circles around the chromatic scale. |
| `inversion` | Names every permutation of a set of notes (mathematical rather than strict musical inversions). |
| `chord-melody` | Combines chord voicings with a melody line. |
| `chord-mutate` | Chord mutation using `Music::ScaleNote`. |
| `chordal` | Chord-driven composition over drums, built on `Music::VoiceGen`. |
| `progressive`, `walk-prog`, `buzz`, `voice-gen` | Chord progressions with generated voices; `walk-prog` adds a walking bass. |
| `transformational`, `transform-chords` | Neo-Riemannian chord transformations (`Music::Chord::Progression::Transform`). |
| `walking-bass` | Parses a chord and builds a walking line under guitar-range constraints. |
| `cadences` | Generates common cadential patterns. |
| `cadence-logic.pl` | Cadence experiments using `Math::Logic`. |
| `blues-progressions` | Blues-jazz progression practice tool, taken from Dan Haerle's chart. |
| `harmonic-entropy.pl` | Psychoacoustic harmonic-entropy model. |
| `guidonian` | Turns text into melodies using Guido d'Arezzo's method (`Music::Guidonian`). |

### Jazz & Real Pieces

| Script | Description |
|--------|-------------|
| `blue-monk` | Full MIDI transcription of Thelonious Monk's *Blue Monk* (Bb) from the Real Book, with synchronized drums, walking bass, chord comping, and melody. |
| `mohawk` | Charlie Parker's *Mohawk* with drums, bass and guitar chords. |
| `take-the-a-train` | Duke Ellington's *Take the "A" Train* (Real Book #421). |
| `blue-gene` | Blues in the same style with generated bass, guitar chords and voices. |
| `coltrane` | Imitates John Coltrane via his circle diagram (see the 2022 write-up). |
| `coltrane-and-company` | The same, with added bass and guitar chords. |
| `jingle-bells.pl` | Jingle Bells ornamented with `Music::MelodicDevice::Ornamentation` (plain and fancy `.mp3`s included; `jingle-bells.pod` is the Perl Advent article). |
| `in-c` | Approximation of Terry Riley's *In C*. |
| `in-c-randomized` | Randomised version of the *In C* performance practice. |
| `dice-game` | Implements Mozart's musical dice game (*Musikalisches Würfelspiel*). |

### Bach Choral Analysis

| Script | Description |
|--------|-------------|
| `bach-choral` | Reads a CSV of Bach choral data (produced by `bach-choral.R`) and reconstructs melody, chord accompaniment, and bass line as MIDI. |
| `bach-choral-freq` | Builds a weighted graph of chord transition frequencies from the chorale data. |
| `bach-choral-network` | Builds a network graph of chord transitions via `Music::BachChoralHarmony` and `Graph::Easy`. |
| `bach-choral.R` | R script to pre-process the Bach choral dataset. |

### Guitar Tools

| Script | Description |
|--------|-------------|
| `fretboard` | Draws a guitar fretboard with `Imager` (superseded by `Music::FretboardDiagram`). |
| `fretting` | Enumerates fingering patterns and flags infractions (backward, span). |
| `fretting-viz` | Visualisation of fretting patterns. |

### MIDI Utilities & Real-Time

| Script | Description |
|--------|-------------|
| `capture-midi` | Captures incoming MIDI events and sends text or keystrokes to the focused window (e.g. Vim motions). |
| `receive-midi.pl` | Receives MIDI and maps notes and velocities using `receive-midi.yaml`. |
| `clock-gen-async.pl` / `.py`, `clock-gen-fritter.py` | Async MIDI clock generators (e.g. `perl clock-gen-async.pl usb 90`). |
| `clock-listener.pl` | Listens to an external MIDI clock signal. |
| `midi-control.py` | Sends MIDI messages defined in a YAML file. |
| `tk-control.py` | Tkinter app that builds those YAML control lists. |
| `simple-control.py`, `program_change.pl` | Minimal control-change and program-change senders. |
| `midi-ports.py` | Lists available MIDI ports. |
| `ezd2gm.pl`, `ezd2gm-choose` | Convert single-track EZdrummer MIDI to General MIDI; `choose` picks files interactively. |
| `midi-simple-dump`, `gestalt-file` | Dump a MIDI file's events, and report pitch/velocity bounds per channel. |
| `ngram-play` | Plays the top repeated note phrases of a MIDI file (use this rather than `note-ngram-play`). |
| `irc-bot` | Musical-processing IRC bot (scales, chord names and notes, MP3 tags); see the 2021 write-up. |
| `m21_config.py` | Textual TUI for editing music21's settings. |

### Real-Time MIDI (Perl)

These drive hardware or a software synth through `MIDI::RtMidi::FFI::Device`, clocked with `IO::Async` timers. Most take a port-name fragment and a BPM.

| Script | Description |
|--------|-------------|
| `clock-listener.pl` | Prints incoming MIDI events. |
| `arping.pl`, `arping2iac.pl` | Arpeggiators: one clock for two devices, or an open port (e.g. macOS IAC) with keyboard control. |
| `clocked-euclidean-drums.pl`, `clocked-euclidean-drum-fills.pl` | Euclidean drums, with an outgoing clock. |
| `rt-bassline.pl` | Quasi-random walking bass line over "Autumn Leaves" changes. |
| `rtmidi-callback.pl`, `rtmidi-control.pl`, `rtmidi-vcv.pl` | `MIDI::RtController` filters, a CC sender, and a VCV Rack controller. |
| `rtmidi-phrase.pl`, `rtmidi-fuzzix.pl`, `seq-part-churn.pl` | Play a phrase string at a BPM, an async pedal-note experiment, and a program changer every four bars. |
| `SE-02-VolcaDrum.pl`, `microKorg-VolcaDrum.pl`, `eurorack-Pams.pl` | Rig-specific pitch players on a clock. |
| `volca-drum-cc.pl` | Mojolicious::Lite web UI for the Volca Drum's control changes, with saved patches. |
| `trinity-midithing.pl` | Euclidean/prime player (its header says it is currently broken). |

### Real-Time MIDI (Python)

| Script | Description |
|--------|-------------|
| `midi-thread-1.py` … `midi-thread-9.py` | An evolving series of threaded generators clocked at 24 PPQN: chords, arpeggios, rhythms and bass, ending with two synths on channels 1 and 2. |
| `multi-timbral.py`, `multi-timbral-pso-chord.py` | Drive a multi-timbral synth, fluidsynth, or a multi-oscillator Eurorack. |
| `midi-Chord2-control.py`, `midi-wholetone.py`, `pump-notes.py` | Qu-Bit Chord 2 control, a whole-tone generator, and a pitch-list sender. |
| `four-chords.py`, `hours.py`, `parts.py`, `pop-ballad.py` | music21 songs built on the author's generator packages. |
| `nx_weights.py`, `transition.py` | NetworkX and music21 transition weights from corpus pieces. |

### Analysis & Metadata

| Script | Description |
|--------|-------------|
| `analyze-recordings`, `analyze-low-level` | AcousticBrainz features as radar charts (see "Led Zeppelin in Seven Dimensions", 2022). |
| `mb-artist-release`, `www-spotify` | MusicBrainz / Cover Art Archive and Spotify lookups. |

### Configuration Files

| File | Description |
|------|-------------|
| `capture-midi.yaml` | MIDI capture configuration. |
| `midi-rock-stone-SE-02.yaml`, `se-02.yaml` | Studio Electronics SE-02 synthesiser MIDI maps. |
| `midi-rock-stone-microKORG.yaml` | Korg microKORG MIDI map. |
| `midi-rock-stone.yaml`, `midi-rock-stone-midi-thing.yaml`, `midi-thing-v2.yaml` | Controller maps for the Rock-Stone / MIDI Thing. |
| `receive-midi.yaml`, `rhythm-chunks.yml` | Inputs for `receive-midi.pl` and `rhythm-chunks`. |

### Subdirectories

| Directory | Description |
|-----------|-------------|
| `clock/` | External-device clock demos: `clocked-drums.pl`, `clocked-drums-3.pl`, `clock-drums.py`, `clock-gen.py`. |
| `cmmwp/` | `cmmwp-1.pl` … `cmmwp-9.pl`: nine progressively richer `MIDI::Util` examples, from a quarter-note loop to rhythmic phrases with voices. |
| `mrwmip/` | "Musical Rhythms with Math in Python": `music-and-math.md`, `coder-legion-*.py` (partitions, necklaces, Euclidean), `perldotcom-*.pl`, and rendered `.mp3`s. |
| `perl.com/` | Code for perl.com articles: `arpeggios.pl`, `little-drummer.pl`, `euclidean-drummer.pl`, with sample `.mid` / `.mp3` files. |
| `tones/` | `tones-*.pl`: progressive real-time tonal MIDI examples. |

---

## Getting Started

### Prerequisites

Install the required Perl modules via CPAN or `cpanm`:

```bash
cpanm MIDI::Util MIDI::Drummer::Tiny Music::Duration::Partition \
      Music::CreatingRhythms Music::AtonalUtil Music::Chord::Note \
      Music::Note Music::Scales Music::VoiceGen Music::Cadence \
      AI::Genetic Game::Life Math::Utils Math::Prime::XS
```

For Python scripts:

```bash
pip install mido python-rtmidi music21 pychord networkx numpy pyyaml
```

### Running a Script

Offline scripts write a `.mid` file to the current directory named after the script (`$0.mid`). Real-time scripts take a MIDI port-name fragment instead (list ports with `python3 midi-ports.py`). Run them directly:

```bash
perl euclidean-beats          # generates euclidean-beats.mid
perl blue-monk                # generates blue-monk.mid
perl lorenz-attractor.pl      # generates lorenz-attractor.pl.mid + .csv
python3 mandelbrot_music.py   # generates MIDI output
```

Many scripts accept positional arguments to control parameters such as BPM, bar count, or loop count:

```bash
perl euclidean-beats 16 8 90 100   # terms, loops, BPM, volume (these are the defaults)
perl OMB.pl 120 4 4                # BPM, motif length in quarter notes, repeats
```

Open the resulting `.mid` file in any DAW, MIDI player, or notation software (e.g. GarageBand, MuseScore, Logic Pro, Ableton).

---

## Status Notes

- Superseded: `fretboard` (by `Music::FretboardDiagram`), `intervals` (by `Music::Intervals`), `note-ngram-play` (by `ngram-play`).
- Moved: `solitude` now lives in the `Music-Bassline-Generator` repository.
- Broken: `trinity-midithing.pl` (per its header); `string-blender` depends on the broken `String::Blender`.
- Helper only: `voicegen.pl` is called by `random-rhythms.py`.

## Modern Perl Notes

Of the ~150 Perl programs, only 25 declare a modern version (23 use `v5.36`, 2 use `v5.40`); most use plain `use strict`.

- Replace `use strict; use warnings;` with `use v5.36;` (adds `say` and signatures).
- `rtmidi-vcv.pl` has no `use strict` at all.
- `random-selection` has a typo shebang (`#!usr/bin/env perl`, missing the leading slash); `fretboard` and `fretting` use `#!/usr/bin/perl`.
- `multi-timbral-drum-fills.pl` uses `Try::Tiny` (`use feature 'try'` on 5.34+), and `random-walk-transform` uses `Readonly` (`use constant`).
- About 14 scripts still use the legacy `MIDI::Simple`; newer ones use `MIDI::Util::setup_score` or `MIDI::Drummer::Tiny`.

```perl
use v5.40;
sub add_bar ($score, $pitch) { $score->n('wn', $pitch) }
```

---

## License

This project is licensed under the [Artistic License 2.0](LICENSE).
