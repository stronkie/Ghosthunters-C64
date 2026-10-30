# Stronkie's Hunters (C64)

A Commodore 64 ghost-hunting game in 6502 assembly. Hunt ghosts and bosses across New York, then fly home to Amsterdam.

## Files
- `stronkies_hunters.prg` - self-extracting compressed program (`LOAD"*",8,1` then `RUN`)
- `stronkies_hunters.d64` - disk image (program + blank HIGHSCORE file)
- `stronkies_hunters.asm` - full source (built with a custom Python 6502 assembler)

## Game
- Intro with story crawl, world-map flight Amsterdam -> New York, Ghostbusters SID tune on the menus.
- Clear Harlem, Manhattan, Harbor and JFK (Statue of Liberty is optional) to win: fireworks, flight home, high-score entry, credits.
- Each life left on a win = 1000 bonus points.

## Test cheat
On the main menu type `G H O S T` (border flashes). Unlimited lives, full power bar, `N` skips a level, no Hall of Fame entry on game over (a win still counts). Type it again to switch off.

## Status
Tested on an Ultimste c64  / VICE.
