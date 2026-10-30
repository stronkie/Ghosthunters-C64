# Stronkie's Hunters - version 1.2

Same game as 1.1, but with a new memory layout:
- BASIC is switched off while the game runs ($01 = $36), so the 8 KB of RAM at $A000-$BFFF is usable.
- The cutscene code (car arrival, boss approach, leaving, level complete) now lives at $A000.
- Free space is now about 2.8 KB below $A000 plus about 5 KB above it (it was about 220 bytes).
- RUN/STOP switches BASIC back on before returning to BASIC; BASIC then sees only the SYS line.

Because this changes how the machine is set up, please test on a real C64 / Ultimate. If anything misbehaves, version 1.1 is the fallback.
