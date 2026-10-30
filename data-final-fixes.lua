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

-- The regular (non-linked) pipe connection moves from half a tile from the
-- center to the center of the perimeter tile: the south tile row for the
-- filler, the north tile row for the extractor. That is size/2 - 0.5 = 3 for
-- the 7x7 footprint -- the same relative spot as upstream's {0, +/-0.5} on the
-- 1x2 pump. It must stay strictly inside the collision box (+/-3.4, quantized
-- to 1/256 tile => 3.3984375), so the boundary value 3.5 is invalid.
local CONNECTION_POSITIONS = {
  [FILL_NAME] = { 0, 3 },
  [EXTRACT_NAME] = { 0, -3 },
}

-- One sprite for all four rotations: the building is rotationally symmetric, so
-- one sprite serves all rotations; the engine's fluid port indicators and pipe
-- covers carry direction. The 0.8 scale makes the 256px art cover ~5 tiles of
-- the 7x7 footprint, centered; shift/scale may need a small in-game visual tweak.
-- (Upstream's decorative "endcap" pipe-to-ground sprites are dropped along with
-- the old animations, since we replace the whole animations table.)
local tank_sprite = {
  filename = "__unipipe-large__/graphics/big-storage-tank.png",
  width = 256,
  height = 256,
  scale = 0.8,
  shift = { 0, -0.3 },
}

local function enlarge(name, connection_position)
  local entity = data.raw["pump"][name]
  if not entity then
    error(
      "unipipe-large: expected Unipipe entity '" .. name .. "' in data.raw[\"pump\"], but it does not exist. "
      .. "unipipe-large requires Unipipe >= 1.0.0, which creates '" .. FILL_NAME .. "' and '"
      .. EXTRACT_NAME .. "' in its data stage. Check that Unipipe is installed and at a compatible version."
    )
  end

  -- 7x7 building.
  entity.collision_box = { { -3.4, -3.4 }, { 3.4, 3.4 } }
  entity.selection_box = { { -3.5, -3.5 }, { 3.5, 3.5 } }
  entity.drawing_box = { { -3.5, -3.5 }, { 3.5, 3.5 } }

  -- Move the regular pipe connection to the center of the perimeter tile (see
  -- CONNECTION_POSITIONS above). We
  -- locate it by connection_type instead of a hardcoded index: the engine-level
  -- connection_type = "linked" entries (linked_connection_id = 1 -- what shares
  -- fluid globally across all Unipipe entities) are left exactly as upstream
  -- defines them, as are flow_direction, pipe_covers, max_pipeline_extent and
  -- volume.
  if not entity.fluid_box or not entity.fluid_box.pipe_connections then
    error("unipipe-large: '" .. name .. "' has no fluid_box.pipe_connections; Unipipe's internals changed?")
  end
  local moved, linked_seen = 0, false
  for _, connection in pairs(entity.fluid_box.pipe_connections) do
    if connection.connection_type == "linked" then
      linked_seen = true -- intentionally untouched
    else
      connection.position = connection_position
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

  entity.animations = {
    north = { layers = { tank_sprite } },
    south = { layers = { tank_sprite } },
    east = { layers = { tank_sprite } },
    west = { layers = { tank_sprite } },
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
end

enlarge(FILL_NAME, CONNECTION_POSITIONS[FILL_NAME])
enlarge(EXTRACT_NAME, CONNECTION_POSITIONS[EXTRACT_NAME])
