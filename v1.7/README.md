# Stronkie's Hunters v1.7

- **Animated hunter:** the hunter now has two walking frames (legs alternate every 4 frames while moving), a standing frame and a shooting pose with raised arms while the beam is on. Works in the game, the countdown, the cutscenes and demo mode.
- **New animated intro scene** between the logo screen and the story: the night skyline scrolls with both parallax layers, the hunter walks in, a ghost glides over, the hunter blasts it and it flees. Typewriter captions: "NEW YORK. A COLD OCTOBER NIGHT." ... "SHOOT THE GHOSTS. SAVE THE CITY!". About 12 seconds; any key or fire skips the scene and the story and goes to the title.
- The raster split code is now one shared routine (`splits`) used by the game and the intro scene.
- The New York progress variables moved to RAM under BASIC to make room for the new hunter sprites.

Built and regression-tested in a custom 6502 emulator; not yet tested on real hardware (v1.0 to v1.6 were).
