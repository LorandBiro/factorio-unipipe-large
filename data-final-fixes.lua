-- unipipe-large: a modification mod for Unipipe.
--
-- We load after Unipipe (see the "Unipipe" dependency in info.json) and mutate
-- the prototypes Unipipe creates in data-final-fixes.lua. Nothing here copies or
-- forks Unipipe code; we only move boxes, ports, sprites and icons on its entities.

-- The internal entity/item names, exactly as Unipipe's config.lua defines them:
--   Config.PIPE_PREFIX       = "zy-unipipe"
--   Config.PIPE_FILL_NAME    = "zy-unipipe-fill"     -- fluid input ("fill" / filler)
--   Config.PIPE_EXTRACT_NAME = "zy-unipipe-extract"  -- fluid output ("extract" / extractor)
-- Unipipe builds both as `table.deepcopy(data.raw["pump"]["pump"])`, so they live
-- in data.raw["pump"].
local FILL_NAME = "zy-unipipe-fill"
local EXTRACT_NAME = "zy-unipipe-extract"

-- Building art: the "fluid-memory-unit" entity from the Fluid Memory Storage mod
-- (MIT, code by notnotmelon, graphics by kaueNP -- see CREDITS and
-- graphics/LICENSE-FluidMemoryStorage.txt). We reuse the art AND the entity
-- configuration exactly as the original mod defines it:
--   collision_box = {{-1.2, -1.2}, {1.2, 1.2}}   -- 3x3 with 0.3 inset
--   selection_box = {{-1.5, -1.5}, {1.5, 1.5}}   -- 3x3
--   picture       = 256x256, scale 0.5, shift {0.25, -0.0625}
--   pipe ports at {0, 1} (south), {0, -1} (north), {1, 0} (east), {-1, 0} (west)
-- Unipipe's pumps are 2-way (fill faces south, extract faces north), so each
-- variant keeps exactly one of the original's four ports: the filler takes the
-- south port {0, 1}, the extractor the north port {0, -1} -- the same
-- orientation as upstream's {0, +/-0.5} ports on the 1x2 pump.
-- (The original sets hide_connection_info = true on its tank; we keep Unipipe's
-- visible connection info on purpose: the engine's fluid port indicator is the
-- in-world "which way does the fluid flow" overlay.)
--
-- The two variants are distinguished by a tint (Factorio's multiplicative
-- sprite tint) plus matching pre-tinted item icons: cool blue = filler (fluid
-- in), warm amber = extractor (fluid out).
local VARIANTS = {
  [FILL_NAME] = {
    connection_position = { 0, 1 },
    tint = { r = 0.55, g = 0.78, b = 1.0 },
    icon = "__unipipe-large__/graphics/icons/unipipe-fill.png",
  },
  [EXTRACT_NAME] = {
    connection_position = { 0, -1 },
    tint = { r = 1.0, g = 0.72, b = 0.45 },
    icon = "__unipipe-large__/graphics/icons/unipipe-extract.png",
  },
}

-- The original mod's research (technology) icon, reused for Unipipe's technology.
local RESEARCH_ICON = "__unipipe-large__/graphics/research/fluid-memory-storage.png"

-- One sprite for all four rotations: the building is rotationally symmetric, so
-- one sprite serves all rotations; the engine's fluid port indicators and pipe
-- covers carry direction. (Upstream's decorative "endcap" pipe-to-ground sprites
-- are dropped along with the old animations, since we replace the whole
-- animations table.)
local function building_sprite(tint)
  return {
    filename = "__unipipe-large__/graphics/fluid-memory-unit.png",
    priority = "high",
    size = { 256, 256 },
    shift = { 0.25, -0.0625 },
    scale = 0.5,
    tint = tint,
  }
end

local function apply_variant(name, variant)
  local entity = data.raw["pump"][name]
  if not entity then
    error(
      "unipipe-large: expected Unipipe entity '" .. name .. "' in data.raw[\"pump\"], but it does not exist. "
      .. "unipipe-large requires Unipipe >= 1.0.0, which creates '" .. FILL_NAME .. "' and '"
      .. EXTRACT_NAME .. "' in its data stage. Check that Unipipe is installed and at a compatible version."
    )
  end

  -- 3x3 building, exactly the fluid-memory-unit's boxes.
  entity.collision_box = { { -1.2, -1.2 }, { 1.2, 1.2 } }
  entity.selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } }
  -- No drawing_box: the original mod sets none, and EntityPrototype::drawing_box
  -- no longer exists in Factorio 2.0 (replaced by
  -- drawing_box_vertical_extension).

  -- Move the regular pipe connection to the original's south/north port (see
  -- VARIANTS above). We locate it by connection_type instead of a hardcoded
  -- index: the engine-level connection_type = "linked" entries
  -- (linked_connection_id = 1 -- what shares fluid globally across all Unipipe
  -- entities) are left exactly as upstream defines them, as are flow_direction,
  -- pipe_covers, max_pipeline_extent and volume.
  if not entity.fluid_box or not entity.fluid_box.pipe_connections then
    error("unipipe-large: '" .. name .. "' has no fluid_box.pipe_connections; Unipipe's internals changed?")
  end
  local moved, linked_seen = 0, false
  for _, connection in pairs(entity.fluid_box.pipe_connections) do
    if connection.connection_type == "linked" then
      linked_seen = true -- intentionally untouched
    else
      connection.position = variant.connection_position
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

  local sprite = building_sprite(variant.tint)
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

  -- Unipipe inherits vanilla pump's icon_draw_specification ({scale = 0.5});
  -- the original mod uses the default alt-mode icon scale. Match the original.
  entity.icon_draw_specification = nil

  -- Icons (item + entity): pre-tinted variants of the original item icon
  -- (64px + 3 mipmap levels in a 120x64 strip).
  local item = data.raw["item"][name]
  item.icon = variant.icon
  item.icon_size = 64
  item.icon_mipmaps = 4
  -- The vanilla pump item carries random_tint_color = item_tints.iron_rust,
  -- which would randomly recolor our carefully tinted icons per stack.
  item.random_tint_color = nil
  entity.icon = variant.icon
  entity.icon_size = 64
  entity.icon_mipmaps = 4
end

apply_variant(FILL_NAME, VARIANTS[FILL_NAME])
apply_variant(EXTRACT_NAME, VARIANTS[EXTRACT_NAME])

-- Technology icon: reuse the original mod's research icon (128x128).
-- Upstream points the technology at a copy of the fill item icon string, so we
-- have to set it explicitly here.
local technology = data.raw["technology"]["zy-unipipe"]
if not technology then
  error(
    "unipipe-large: expected Unipipe technology 'zy-unipipe' in data.raw[\"technology\"], "
    .. "but it does not exist. Unipipe version mismatch?"
  )
end
technology.icon = RESEARCH_ICON
technology.icon_size = 128
technology.icon_mipmaps = nil
