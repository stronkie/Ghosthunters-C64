# Previous versions of Stronkie's Hunters

Oldest to newest. Each folder holds the source (`.asm`) and the program (`.prg`; v15 builds also have a `.d64`).
Folders named `v15-before_X` are the build as it was just *before* feature X was added.
The final release is `../v1.26` (and the root folder).

| Folder | What it is |
|---|---|
| `orig` | the first version I started from (program only) |
| `v8` - `v12` | early development builds (uncompressed `stronkies_zappers_unpacked.prg`) |
| `v13`, `v14` | compressed self-extracting builds (`.prg`) plus the uncompressed one |
| `v15-backup` | first v15 build: Ghostbusters SID on the menu, own raster interrupt, credits screen |
| `v15-before_cont` | with story crawl and flight to New York, before continuous music |
| `v15-before_irqplay` | continuous music (tune keeps running between screens) |
| `v15-before_quit` | music played from the raster interrupt |
| `v15-before_nymap` | RUN/STOP quit fix ("syntax error in 10") and 90 s demo timer |
| `v15-before_harden` | New York taxi map between levels |
| `v15-before_sprfix` | start-up sprite register hardening |
| `v15-before_win` | sprites reloaded every level (black sprites fix) |
| `v15-before_cheat` | cleared places blink on the map, victory screen |
| `v15-before_fw` | GHOST test cheat |
| `v15-before_cheat2` | fireworks ending and flight home |
| `v15-before_bonus` | cheat label next to CAUGHT, full power bar, boss attacks only from the boss |

These older development builds were only tested in a custom 6502 emulator. The numbered releases (`v1.0` to `v1.26`, in this folder) are all confirmed on a real Commodore 64.
