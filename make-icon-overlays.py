#!/usr/bin/env python3
"""Replay the icon-overlay step for unipipe-large (recorded 2026-10-31).

This is a record of exactly how the badge overlays were produced, so they can
be replayed after switching building graphics. It is deliberately NOT a
generic tool -- it has no options; the recorded inputs and parameters below
are the change history.

What it regenerates:
  graphics/icons/unipipe-large-fill.png     = item icon strip + base-game down arrow
  graphics/icons/unipipe-large-extract.png  = item icon strip + base-game up arrow
  graphics/research/memory-unit.png         = research icon + base-game signal-liquid droplet

Badge rule, identical everywhere: the badge's largest side is 45% of the icon
cell, placed in the top-right corner with an inset of size/16. Item icons are
the family's 120x64 mipmap strips (64 + 32 + 16 + 8 px at y = 0); every
mipmap level gets its own badge, scaled from that level's own overlay mip
(same layout as the arrow strips). The research icon is a plain 128x128 icon;
its droplet badge is scaled from the overlay's 64px mip and sized against the
128px frame.

When switching building graphics: point ITEM_ICON_BASE / RESEARCH_ICON_BASE
below at the new *pristine* (unbadged) icon files and run this again. Never
point them at this script's own outputs -- the badges would stack.

Requires Pillow. Run from anywhere:  python3 make-icon-overlays.py
"""
from pathlib import Path

from PIL import Image

MOD = Path(__file__).resolve().parent  # unipipe-large repo root

# Where the pristine (unbadged) icons come from. These were taken from the
# sister mod on 2026-10-31 -- edit both when switching building graphics.
UNICHEST = MOD.parent / "factorio-unichest-large"
ITEM_ICON_BASE = UNICHEST / "graphics/icons/memory-unit.png"       # pristine 120x64 strip
RESEARCH_ICON_BASE = UNICHEST / "graphics/research/memory-unit.png"  # pristine 128x128 icon

# Base-game overlay assets (white with black border, the arrow style).
BASE_ICONS = Path.home() / ".local/share/Steam/steamapps/common/Factorio/data/base/graphics/icons"
ARROWS = BASE_ICONS / "arrows"
DROPLET = BASE_ICONS / "signal/signal-liquid.png"

# Mipmap strip layout of the item icons: (cell size, x offset).
MIPS = ((64, 0), (32, 64), (16, 96), (8, 112))


def item_icons():
    # Item icons: pristine strip + a directional arrow badge on every mip.
    for arrow_name, out_name in (("down-arrow.png", "unipipe-large-fill.png"),
                                 ("up-arrow.png", "unipipe-large-extract.png")):
        base = Image.open(ITEM_ICON_BASE).convert("RGBA")
        arrow = Image.open(ARROWS / arrow_name).convert("RGBA")
        strip = Image.new("RGBA", (120, 64), (0, 0, 0, 0))
        for s, x in MIPS:
            cell = base.crop((x, 0, x + s, s)).copy()
            a = arrow.crop((x, 0, x + s, s))          # that level's own arrow mip
            bs = max(2, round(s * 0.45))              # badge = 45% of the cell
            a = a.resize((bs, bs), Image.LANCZOS)
            m = max(1, s // 16)                       # corner inset
            cell.alpha_composite(a, (s - bs - m, m))  # top-right
            strip.paste(cell, (x, 0))
        out = MOD / "graphics/icons" / out_name
        strip.save(out)
        print(f"wrote {out}")


def research_icon():
    # Research icon: pristine 128x128 + the generic droplet badge.
    icon = Image.open(RESEARCH_ICON_BASE).convert("RGBA")
    drop = Image.open(DROPLET).convert("RGBA").crop((0, 0, 64, 64))
    drop = drop.crop(drop.getbbox())                  # tight droplet
    maxdim = round(icon.width * 0.45)                 # badge = 45% of the frame
    k = maxdim / max(drop.size)                       # keep the droplet's aspect
    drop = drop.resize((round(drop.width * k), round(drop.height * k)), Image.LANCZOS)
    m = icon.width // 16                              # corner inset
    icon.alpha_composite(drop, (icon.width - drop.width - m, m))  # top-right
    out = MOD / "graphics/research/memory-unit.png"
    icon.save(out)
    print(f"wrote {out}")


if __name__ == "__main__":
    item_icons()
    research_icon()
