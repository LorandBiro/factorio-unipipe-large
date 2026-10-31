-- unipipe-large: a modification mod for Unipipe.
--
-- We load after Unipipe (see the "Unipipe" dependency in info.json) and mutate
-- the prototypes Unipipe creates in data-final-fixes.lua. Nothing here copies or
-- forks Unipipe code; we only move boxes, ports and sprites on its entities.

-- The internal entity/item names, exactly as Unipipe's config.lua defines them:
--   Config.PIPE_PREFIX    = "zy-unipipe"
--   Config.PIPE_FILL_NAME    = "zy-unipipe-fill"     -- fluid input ("fill" / filler)
--   Config.PIPE_EXTRACT_NAME = "zy-unipipe-extract"  -- fluid output ("extract" / extractor)
-- Unipipe builds both as `table.deepcopy(data.raw["pump"]["pump"])`, so they live
-- in data.raw["pump"].
local FILL_NAME = "zy-unipipe-fill"
local EXTRACT_NAME = "zy-unipipe-extract"

-- The regular (non-linked) pipe connection follows the Pyanodons caravan
-- outpost arrangement (pyalienlife `prototypes/buildings/outpost-fluid.lua`):
-- a single port on the south side, half a tile east of the centerline --
-- literally `position = {0.5, 2.5}, direction = south` there. A 6x6 building
-- has no center tile (its center is a tile corner), so the port tile is local
-- x in [0, 1], y in [2, 3], and the join point where the neighboring pipe
-- attaches is (0.5, 3.0), exactly on the south edge of the footprint -- grid
-- column 4, row 6 of the 6x6. Both variants use the same port tile, so a base
-- piped up for Pyanodons caravans takes a filler or an extractor drop-in.
--
-- `direction` must travel with the position: upstream's extractor port points
-- north, and the engine keeps `position` fixed "regardless the directions of
-- entity", so leaving the direction stale would put the join point inside the
-- building.
local PORT_POSITION = { 0.5, 2.5 }
local PORT_DIRECTION = defines.direction.south

-- ONE building sprite for both variants, the same for all four rotations --
-- exactly like Pyanodons, whose caravan outpost reuses one building for the
-- item and fluid outposts and only marks the icon. The sprite is the
-- "memory-unit" silo from Deep Storage Unit, taken from the sister mod
-- unichest-large so the mod family shares one art style. The two variants are
-- distinguished by the arrow badge on the icon (see ICONS below), like
-- Pyanodons' drop indicator.
--
-- Sizing: the visible art is kept at ~90% of the 6x6 footprint -- 0.9 x 192 =
-- 173 displayed px wide, i.e. scale = 173/458 = 0.377 for the 458x401
-- visible content of the 512x512 PNG (the rest is transparent padding +
-- shadow). That leaves ~0.3 tile of margin on every side: adjacent buildings
-- no longer touch and the pipe stub at the south port stays visible. The
-- small shift re-centers the visible content, which sits asymmetrically in
-- the PNG because of the cast shadow.
local BUILDING_SPRITE = {
  filename = "__unipipe-large__/graphics/memory-unit.png",
  width = 512,
  height = 512,
  scale = 0.45,
  shift = { 0.534375, 0 },
}

-- The drawn pipe stub, verbatim from Pyanodons' outpost-fluid
-- (pyalienlife/prototypes/buildings/outpost-fluid.lua, GNU GPLv3). Our boxes
-- and port position match theirs exactly, so the hand-tuned shifts land the
-- same way: a short pipe end at the port, drawn behind the building art
-- (secondary_draw_order = -1, set in enlarge() below). All four directions
-- are provided because the building can be rotated.
local PIPE_PICTURE = {
  north = { layers = {
    { filename = "__base__/graphics/entity/pipe/pipe-ending-down.png",
      height = 128, width = 128, scale = 0.5, shift = { 0, 0.9 }, priority = "extra-high" },
  } },
  east = { layers = {
    { filename = "__base__/graphics/entity/pipe/pipe-ending-right.png",
      height = 128, width = 128, scale = 0.5, shift = { -1, 0 }, priority = "extra-high" },
  } },
  south = { layers = {
    { filename = "__base__/graphics/entity/pipe/pipe-ending-up.png",
      height = 128, width = 128, scale = 0.5, shift = { 0, -1.4 }, priority = "extra-high" },
    { filename = "__base__/graphics/entity/pipe/pipe-ending-up.png",
      height = 128, width = 128, scale = 0.5, shift = { 0, -0.75 }, priority = "extra-high" },
  } },
  west = { layers = {
    { filename = "__base__/graphics/entity/pipe/pipe-ending-left.png",
      height = 128, width = 128, scale = 0.5, shift = { 1, 0 }, priority = "extra-high" },
  } },
}

local function enlarge(name, sprite)
  local entity = data.raw["pump"][name]
  if not entity then
    error(
      "unipipe-large: expected Unipipe entity '" .. name .. "' in data.raw[\"pump\"], but it does not exist. "
      .. "unipipe-large requires Unipipe >= 1.0.0, which creates '" .. FILL_NAME .. "' and '"
      .. EXTRACT_NAME .. "' in its data stage. Check that Unipipe is installed and at a compatible version."
    )
  end

  -- 6x6 building. The exact Pyanodons caravan outpost footprint (pyalienlife
  -- outpost / outpost-fluid: collision +/-2.9, selection +/-3), so grids piped
  -- up for caravans line up tile for tile.
  entity.collision_box = { { -2.7, -2.7 }, { 2.7, 2.7 } }
  entity.selection_box = { { -3, -3 }, { 3, 3 } }
  entity.drawing_box = { { -3, -3 }, { 3, 3 } }

  -- Move the regular pipe connection to the Pyanodons caravan port spot (see
  -- PORT_POSITION above). We locate it by connection_type instead of a
  -- hardcoded index: the engine-level connection_type = "linked" entries
  -- (linked_connection_id = 1 -- what shares fluid globally across all Unipipe
  -- entities) are left exactly as upstream defines them, as are flow_direction
  -- (input for the filler, output for the extractor -- that is what makes the
  -- two variants differ), pipe_covers, max_pipeline_extent and volume.
  if not entity.fluid_box or not entity.fluid_box.pipe_connections then
    error("unipipe-large: '" .. name .. "' has no fluid_box.pipe_connections; Unipipe's internals changed?")
  end
  local moved, linked_seen = 0, false
  for _, connection in pairs(entity.fluid_box.pipe_connections) do
    if connection.connection_type == "linked" then
      linked_seen = true -- intentionally untouched
    else
      connection.position = PORT_POSITION
      connection.direction = PORT_DIRECTION
      moved = moved + 1
    end
  end
  if moved ~= 1 or not linked_seen then
    error(
      "unipipe-large: '" .. name .. "' does not have the expected fluid_box.pipe_connections layout "
      .. "(1 regular + 1 linked connection); got " .. moved .. " regular and linked_seen="
      .. tostring(linked_seen) .. ". Unipipe version mismatch?"
    )
  end

  -- The drawn pipe stub at the port (see PIPE_PICTURE above): Pyanodons draws
  -- one on its outpost-fluid, we do the same. secondary_draw_order = -1 keeps
  -- it behind the building art, exactly like the caravan outpost.
  entity.fluid_box.pipe_picture = PIPE_PICTURE
  entity.fluid_box.secondary_draw_order = -1

  entity.animations = {
    north = { layers = { sprite } },
    south = { layers = { sprite } },
    east = { layers = { sprite } },
    west = { layers = { sprite } },
  }

  -- Unipipe deepcopies base "pump" and only replaces `animations`, so the
  -- vanilla pump window overlays would render junk on top of our tank. Both
  -- fields are documented-optional on PumpPrototype (2.0/2.1), so removing them
  -- is safe and draws nothing. `fluid_shadow` is not a documented PumpPrototype
  -- property in 1.1+/2.x, but we nil it defensively in case a base-game version
  -- carries it on the deepcopy.
  -- TODO: `frozen_patch` (optional Sprite4Way) may still draw a vanilla pump
  -- freeze overlay under Space Age; clear it too if that shows up in testing.
  entity.fluid_animation = nil
  entity.glass_pictures = nil
  entity.fluid_shadow = nil

  -- Rotation: in-game the port rotates with the building (the connection
  -- direction carries the join point around the footprint), so no
  -- "not-rotatable" guard is needed; PIPE_PICTURE covers all four directions
  -- for the same reason.
end

-- Icons: one building icon for both variants -- again like the Pyanodons
-- caravan outpost -- with a simple drop indicator to tell them apart: a
-- downward arrow for the filler (fluid drops into the network), an upward
-- arrow for the extractor. The badges are the base-game arrow icons
-- (graphics/icons/arrows/) composited onto the memory-unit icon strip, laid
-- out as the family's standard 120x64 mipmap strip (64 + 32 + 16 + 8 px at
-- y = 0). The plain strip doubles as the technology icon (upstream copies the
-- filler item's icon string at load time, so we restamp that too).
-- `random_tint_color` (inherited from the vanilla pump item) is cleared -- it
-- randomly rust-tinted the icons in inventories. The research icon gets a
-- water-drop badge for the same reason (see below).
-- TODO: alt-mode/map icons inherit vanilla pump's icon_draw_specification =
-- {scale = 0.5}, which is tiny on a 6x6; bumped to 1.5 here -- tune in-game.
local ICONS = {
  [FILL_NAME] = "__unipipe-large__/graphics/icons/unipipe-large-fill.png",
  [EXTRACT_NAME] = "__unipipe-large__/graphics/icons/unipipe-large-extract.png",
}

for name, icon in pairs(ICONS) do
  for _, proto in ipairs({ data.raw["item"][name], data.raw["pump"][name] }) do
    proto.icon = icon
    proto.icon_size = 64
    proto.icon_mipmaps = 4
  end
  data.raw["item"][name].random_tint_color = nil
  data.raw["pump"][name].icon_draw_specification = { scale = 1.5 }
end

local tech = data.raw["technology"]["zy-unipipe"]
if tech then
  -- The research icon is the 128x128 memory-unit render with a droplet badge
  -- (base-game signal-liquid icon, same style as the item arrows), so the
  -- fluid research reads differently from the unichest one.
  -- icon_size must be 128 for this file (a plain 128x128 icon, no mipmap
  -- strip), matching how unichest-large wires its copy of it.
  tech.icon = "__unipipe-large__/graphics/research/memory-unit.png"
  tech.icon_size = 128
  tech.icon_mipmaps = nil
end

enlarge(FILL_NAME, BUILDING_SPRITE)
enlarge(EXTRACT_NAME, BUILDING_SPRITE)
