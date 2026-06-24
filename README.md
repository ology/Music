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
- [`Game::Life`](https://metacpan.org/pod/Game::Life) — Conway's Game of Life grid
- [`Math::Utils`](https://metacpan.org/pod/Math::Utils) — scaling utilities

### Key Python Libraries

- `mido` / `rtmidi` — MIDI I/O and real-time clock
- `music21` — music analysis and notation
- `pretty_midi` — MIDI file manipulation

---

## Scripts by Category

### Algorithmic Composition

| Script | Description |
|--------|-------------|
| `ai-genetic` | Uses a genetic algorithm (`AI::Genetic`) to evolve a pitch set scored by consonance, then optionally evolves rhythm and velocity. Applies atonal transformations (inversion, retrograde, rotation, transposition). |
| `ai-genetic-pro` | Extended version of `ai-genetic` with additional options. |
| `algo-progression` | Algorithmically generates chord progressions. |
| `cope` | Implements ideas from David Cope's algorithmic composition work. |
| `cope-genetic` | Combines Cope-style composition with genetic evolution. |
| `evolver.pl` | Evolves musical phrases iteratively. |
| `fragments` | Generates and combines small melodic fragments. |
| `micro-themed` | Produces micro-scale themed compositions. |

### Chaos, Fractals & Mathematics

| Script | Description |
|--------|-------------|
| `lorenz-attractor.pl` | Solves the Lorenz system using RK4 integration; maps x/y/z trajectory values to MIDI pitch ranges and writes quarter-note triads. Outputs a `.csv` of trajectory data alongside the MIDI file. |
| `lorenz-attractor.py` | Python equivalent of the above. |
| `mandelbrot_music.py` | Sonifies the Mandelbrot set — escape-time values drive pitch and rhythm. |
| `barycenter`, `barycenter3`, `barycenter4` | Maps gravitational barycenter calculations to musical output. |
| `hilbert-notes` | Uses a Hilbert space-filling curve to traverse a note grid. |
| `astrophysics` | Turns astrophysical data into sound. |
| `five-parsecs`, `kiloparsec` | Space/distance-themed algorithmic pieces. |

### Cellular Automata & Systems

| Script | Description |
|--------|-------------|
| `game-of-life-cluster` | Runs Conway's Game of Life on a 7×7 note grid; each generation's live-cell cluster becomes a chord. Uses a glider or blinker as the seed. |
| `lindenmayer-midi` | Applies L-system (Lindenmayer system) rewriting rules to produce MIDI sequences. |
| `cryptomorphic` | Explores cryptomorphic transformations of musical structures. |

### Rhythm & Drums

| Script | Description |
|--------|-------------|
| `euclidean-beats` | Distributes kick and snare onsets using Euclidean rhythm algorithm with prime-number onset counts. Hi-hat plays straight eighths. |
| `euclidean-drums.pl` | Simpler Euclidean drum machine. |
| `clocked-euclidean-drums.pl` | Euclidean drum patterns synchronised to an external MIDI clock. |
| `clocked-euclidean-drum-fills.pl` | Adds fills to clocked Euclidean drum patterns. |
| `OMB.pl` | One-Man Band: generates randomised hi-hat, kick, and snare patterns plus drum fills using `Music::Duration::Partition`. Six fill styles descend the tom kit with optional cymbal substitutions. |
| `drum-circle` | Multi-part drum circle simulation. |
| `duration-selection` | Explores rhythmic duration selection strategies. |
| `figured-syncopation` | Generates syncopated rhythmic figures. |
| `five-four-durations` | Experiments with 5/4 time signatures. |

### Music Theory

| Script | Description |
|--------|-------------|
| `all-modes` | Generates and plays all diatonic modes. |
| `all-possible-chords` | Enumerates and plays all possible chord voicings in a key. |
| `intervals` | Explores melodic and harmonic intervals. |
| `circle-intervals` | Generates patterns based on the circle of fifths/intervals. |
| `inversion` | Demonstrates melodic and harmonic inversions. |
| `chord-melody` | Combines chord voicings with a melody line. |
| `chord-mutate` | Mutates chord voicings algorithmically. |
| `chordal` | Chordal composition experiments. |
| `cadences` | Generates common cadential patterns. |
| `cadence-logic.pl` | Logic-based cadence generation. |
| `blues-progressions` | Generates 12-bar and extended blues progressions. |
| `harmonic-entropy.pl` | Computes and sonifies harmonic entropy values. |
| `guidonian` | References Guido d'Arezzo's hexachordal system. |

### Jazz & Real Pieces

| Script | Description |
|--------|-------------|
| `blue-monk` | Full MIDI transcription of Thelonious Monk's *Blue Monk* (Bb) from the Real Book, with synchronized drums, walking bass, chord comping, and melody. |
| `coltrane` | Coltrane-changes-inspired composition. |
| `coltrane-and-company` | Extended Coltrane-style harmonic exploration. |
| `jingle-bells.pl` | MIDI arrangement of Jingle Bells (plain and fancy versions included as `.mp3`). |
| `in-c` | Approximation of Terry Riley's *In C*. |
| `in-c-randomized` | Randomised version of the *In C* performance practice. |
| `dice-game` | Implements Mozart's musical dice game (*Musikalisches Würfelspiel*). |

### Bach Choral Analysis

| Script | Description |
|--------|-------------|
| `bach-choral` | Reads a CSV of Bach choral data (produced by `bach-choral.R`) and reconstructs melody, chord accompaniment, and bass line as MIDI. |
| `bach-choral-freq` | Analyses note frequency distributions in Bach chorals. |
| `bach-choral-network` | Builds a network graph of chord transitions in Bach chorals. |
| `bach-choral.R` | R script to pre-process the Bach choral dataset. |

### Guitar Tools

| Script | Description |
|--------|-------------|
| `fretboard` | Visualises scales and notes on a guitar fretboard. |
| `fretting` | Models guitar fretting positions. |
| `fretting-viz` | Visualisation of fretting patterns. |

### MIDI Utilities & Real-Time

| Script | Description |
|--------|-------------|
| `capture-midi` | Captures incoming MIDI events. |
| `clock-gen-async.pl` / `.py` | Async MIDI clock generator. |
| `clock-listener.pl` | Listens to an external MIDI clock signal. |
| `midi-control.py` | Sends MIDI control change messages. |
| `midi-ports.py` | Lists available MIDI ports. |
| `ezd2gm.pl` | Converts EZdrummer patterns to General MIDI. |
| `irc-bot` | IRC bot that triggers music generation. |

### Configuration Files

| File | Description |
|------|-------------|
| `capture-midi.yaml` | MIDI capture configuration. |
| `midi-rock-stone-SE-02.yaml` | Roland SE-02 synthesiser MIDI map. |
| `midi-rock-stone-microKORG.yaml` | Korg microKORG MIDI map. |

### Subdirectories

| Directory | Description |
|-----------|-------------|
| `clock/` | MIDI clock utilities. |
| `cmmwp/` | Supporting files for a composition project. |
| `mrwmip/` | Supporting files for a composition project. |

---

## Getting Started

### Prerequisites

Install the required Perl modules via CPAN or `cpanm`:

```bash
cpanm MIDI::Util MIDI::Drummer::Tiny Music::Duration::Partition \
      Music::CreatingRhythms Music::AtonalUtil Music::Chord::Note \
      Music::Note AI::Genetic Game::Life Math::Utils
```

For Python scripts:

```bash
pip install mido python-rtmidi music21 pretty_midi
```

### Running a Script

Most scripts write a `.mid` file to the current directory with the same base name as the script. Run them directly:

```bash
perl euclidean-beats          # generates euclidean-beats.mid
perl blue-monk                # generates blue-monk.mid
perl lorenz-attractor.pl      # generates lorenz-attractor.pl.mid + .csv
python3 mandelbrot_music.py   # generates MIDI output
```

Many scripts accept positional arguments to control parameters such as BPM, bar count, or loop count:

```bash
perl euclidean-beats 16 8 90 100   # n=16 beats, 8 loops, 90 BPM, volume=100
perl OMB.pl 120 4 4                # 120 BPM, 4-beat motif, 4 repeats
```

Open the resulting `.mid` file in any DAW, MIDI player, or notation software (e.g. GarageBand, MuseScore, Logic Pro, Ableton).

---

## License

This project is licensed under the [Artistic License 2.0](LICENSE).
