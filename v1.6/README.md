# Stronkie's Hunters v1.6

- **Parallax skyline:** a second, darker far city now sits behind the New York skyline and scrolls at a third of the speed. Its colour is different for every place (blue, red, black, grey, blue).
- The gaps between the near buildings show the far city instead of empty sky.
- Done with raster splits (extra fine-scroll and background-colour changes at lines 154, 166, 238 and 242), so no extra sprites are used.
- Side effect: the old occasional one-frame jump of the skyline scroll (about 4% of frames) is gone, because the game loop now waits for the right raster line every frame.
- "BOSS CAPTURED!" / "LEVEL COMPLETE!" texts moved up two rows to make room for the far city.

Tested on a real Commodore 64 and working. Built and regression-tested in a custom 6502 emulator.
