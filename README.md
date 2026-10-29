# unipipe-large

Enlarges the [Unipipe](https://github.com/mpcomplete/factorio-unipipe) fluid buildings to 7x7 tank docks.

Unipipe's filler and extractor become 7x7 tank buildings with a tank sprite. They still share fluid globally across your factory through Unipipe's engine-level linked connections — this addon only changes their physical footprint and look.

## Why so big?

Balance through geometry: these are fluid ports for subfactory boundaries. A 7x7 footprint makes them too large to crowd around every machine — you route fluids to a dock, you don't dot docks everywhere. Big ports, deliberate placement.

## Install

Requires the **Unipipe** mod (declared as a dependency, so the mod portal / in-game installer downloads it automatically). Place this mod after Unipipe; it patches the prototypes at load time and changes nothing else (recipes, tech, pumping speed are untouched).

## Credits

Storage tank sprite: "Krastorio2Assets" mod by raiguard (Krastor), GNU LGPLv3 — see `CREDITS` and `graphics/LICENSE-Krastorio2Assets.txt`. Code is MIT (see `LICENSE`).
