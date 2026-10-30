# Stronkie's Hunters

A ghost-hunting game for the **Commodore 64**, written entirely in 6502 machine language. Grab your proton blaster, chase slime-spitting ghosts through a scrolling New York skyline, trap the boss of each district, and clear the city to fly home to Amsterdam.

All releases, v1.0 to v1.7, are tested and working on a real Commodore 64 (PAL).

## Download and run

| File | What it is |
|---|---|
| `stronkies_hunters.prg` | Self-extracting packed program (about 20 KB) |
| `stronkies_hunters.d64` | Disk image: the game plus a `HIGHSCORE` file for the Hall of Fame |
| `stronkies_hunters.asm` | Full assembly source |

- **Emulator (VICE):** drag the `.d64` or `.prg` onto the window, or run `x64sc stronkies_hunters.d64`.
- **Real C64:** write the `.d64` to a floppy or SD2IEC / Ultimate device, then:

```
LOAD"STRONKIES HUNTERS",8,1
RUN
```

Use the `.d64` if you want your high scores saved: the Hall of Fame is written back to the disk.

## Controls

| Action | Joystick (port 2) | Keyboard |
|---|---|---|
| Move | left / right | `A` / `D` |
| Fire the proton beam | fire | `SPACE` |
| Pause | | `P` |
| Quit to the menu / BASIC | | `RUN/STOP` or `RESTORE` |
| Reset the Hall of Fame (menu) | | `R` |

## How to play

1. Catch the ghosts floating over the skyline with your proton beam. Dodge their slime: you have 3 lives.
2. Your blaster has a power meter. It drains while you fire, and when it overheats you must wait for it to recharge. Collect power-ups that drop from caught ghosts and bosses.
3. Fill the quota of a level and the **boss** of that district appears. Hit it three times to stun it, then drop the trap and suck it in.
4. After each boss, a map of New York shows your next stop. Cleared places blink and are skipped.
5. Clear **Harlem, Manhattan, Harbor and JFK** to win. The Statue of Liberty is optional.
6. Winning gives a fireworks show, a **1000 point bonus per life left**, a flight back to Amsterdam, and a place in the Hall of Fame.

## The five places

Every place has its own colours, its own boss shape, its own boss attack list and its own attack speed.

| Place | Boss | Style |
|---|---|---|
| Harlem | the original blob | gentle: homing balls and spreads |
| Manhattan | skyscraper | snipers and pincers |
| Harbor | kraken | waves of spread shots |
| JFK | plane | pincers and fast shots |
| Statue of Liberty | crowned statue | everything, fastest attacks |

Boss attacks: **homing** slime, **spread** (two balls fly apart), **sniper** (fast homing ball), **pincer** (one homing ball plus one straight down). All attacks come from the boss itself.

## Features

- Intro screen with a bitmap logo, an animated opening scene (hunter walks in, ghost appears, hunter blasts it), title screen, demo mode (starts after 3 minutes idle), credits and a story intro with a flight to New York.
- Ghostbusters-style tune on the menus, played by a raster interrupt; riff, beam and sound effects in the game.
- Sound effects: ghost catch jingle, hurt wail, GO!, boss warning siren, low-power beep, boss-caught fanfare.
- Smooth scrolling New York skyline in extended colour text mode with a RAM character set, plus a slower far city behind it (parallax, done with raster splits).
- Animated hunter: standing, walking and shooting frames.
- Cutscenes: car arrival, boss approach (the boss grows from far away), boss caught, driving away.
- Top 10 Hall of Fame saved to disk, with the place reached and a star for players who finished the game.
- Test cheat: type `GHOST` in the main menu for unlimited lives and a full power bar (`N` skips a level). No Hall of Fame entry on game over while it is active.

## Technical notes

- Pure 6502 assembly, built with a small custom Python assembler, packed with a custom LZ packer into a self-extracting PRG.
- BASIC is switched off while the game runs (`$01 = $36`), which frees RAM under the BASIC ROM at `$A000` for cutscene code, sound effects and the places of New York.
- Memory map: sprites and variables low (`$0801-$0FFF`), tune at `$1000`, map and charset in VIC bank 0 up to `$3FFF`, data from `$4000`, main code below `$A000`.
- Developed and regression-tested in a custom 6502 emulator, then confirmed on real hardware (v1.0 to v1.7).
- The Hall of Fame file `HIGHSCORE` is a 120-byte SEQ file; old 110-byte files are converted automatically.

## Versions

Each release is kept in its own folder (`v1.0` to `v1.7`), and earlier development snapshots are in `previous-versions/`.

| Version | Highlights |
|---|---|
| v1.0 | First complete game (real C64 OK) |
| v1.1 | Per-place themes, place name on the HUD, "NEXT STOP" screen, low-power beep, boss fanfare (real C64 OK) |
| v1.2 | More free memory (BASIC off, code under BASIC) (real C64 OK) |
| v1.3 | Better Hall of Fame (place reached, star for winners) (real C64 OK) |
| v1.4 | Sound effects (real C64 OK) |
| v1.5 | Unique boss per New York place, cleaned-up source (real C64 OK) |
| v1.6 | Parallax skyline: a slow far city behind the near buildings (real C64 OK) |
| v1.7 | Animated hunter (walk and shoot frames), animated intro scene (real C64 OK) |

## Credits

Game design and testing: **Stronkie**. Code written with Claude (Anthropic). Tune in the style of the *Ghostbusters* theme.
