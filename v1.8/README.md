# Stronkie's Hunters v1.8

- **Wobbling ghosts:** the ghost now has three animation frames (the lower body sways left and right) instead of one.
- **New ghost types**, picked per place (Statue of Liberty has hardly any normal ghosts):
  - **Fast (cyan):** twice the speed and a faster wobble.
  - **Splitter (orange):** the first hit shrinks it into a small, fast mini ghost (+5 points, no quota progress); the second hit catches it.
  - **Dodger (purple):** jumps away along its path when the beam gets close, with a short cool-down so it can still be caught.
- **Weather per place:** Harlem rain, Manhattan lightning with thunder, Harbor fog (the sky pulses light blue), JFK wind streaks that push the hunter in gusts, Statue of Liberty a thunderstorm (rain + lightning).
- **Boss warning screen:** before the boss approach scene the border flashes red, the siren sounds and "!!! WARNING !!!  BOSS INCOMING" blinks for 1.5 seconds.

Built and regression-tested in a custom 6502 emulator; not yet tested on real hardware (v1.0 to v1.7 were). Free memory left below `$BE00`: about 2 KB.
