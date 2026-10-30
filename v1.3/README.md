# Stronkie's Hunters - version 1.3

New: a better Hall of Fame.
- Every entry now shows the **place reached** (HAR, MAN, HBR, JFK, LIB) next to the level.
- Entries from players who **completed the game** get a **star** (*).
- The HIGHSCORE file is now 120 bytes. An older 110-byte file is converted automatically when loaded, so existing scores are kept (their place column stays empty).
- The build now stops with an error if two memory segments overlap.

Built and regression-tested in a custom 6502 emulator; needs a real-C64 check (1.0 was confirmed on hardware).
