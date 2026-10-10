# Classic / Vulcanic

Import `MapAreas.lua` before UnitSpawner, PickModeSelectionUI and RacePickSystem.
Update those three modules too. No additional FDF/TOC files are required.

The host chooses Classic or Vulcanic in game setup using the existing synchronized
choice messages. Selection is committed before AutoStart spawns the main buildings.
Classic is the default. The selection belongs to the match, not a player profile.

## Configure Vulcanic

Edit the `Vulcanic` block in `MapAreas.lua`. Its current numbers are explicitly
Classic placeholders, not finished second-area coordinates.

- `icon`: texture path; placeholders are Tree of Life for Classic and Volcano
  for Vulcanic. Lua paths need escaped backslashes. Names remain in tooltips.
- `points`: Mound, Titan shops, recipe shops, punishment buildings, pick shops,
  Titan/Defender picker positions and the builder shop center.
- `BUILDER_SHOP_CENTER`: three builder shops use center X minus 128, center X,
  and center X plus 128. For Vulcanic existing builder shops are relocated.
  Classic preserves existing map-placed builder shops and gg_rct_BuilderShop.
- `expStones`: possible EXP-stone positions; one is selected as before.
- `bounds`: optional `{ minX=..., minY=..., maxX=..., maxY=... }` camera rectangle.
  Applied after race picking, so pick shops can be outside the playable rectangle.
- `titanPickBounds` / `builderPickBounds`: same rectangle format, separately for
  the Titan and Builder teams during the pick phase (including their observers).
  Players without an assigned team use the original camera bounds.
  Applied when pick shops are
  spawned and before focusing a player's picker. On focusing a spawned main unit,
  that player receives the gameplay bounds; other players can continue picking.
  The end of race selection applies gameplay bounds to everyone. `nil` restores
  the original camera rectangle, so pick bounds never remain stuck on afterwards.
  Classic uses the original Zinc `RacePickMode.setupCamera` coordinates:
  Titan (-9952, 10304), Builder (-10752, 8704). Min and max are deliberately
  identical: the original pick camera was locked to a point, not a scrollable area.

`points.DEFENDER_SPAWN` controls the initial Defender circle center (existing
radius and random spread remain unchanged). `points.MINION_SPAWN` controls normal
and grace Minion spawn centers and the grace courier destination. Both Classic
centers remain (-384, -512); enter separate Vulcanic coordinates in its block.
Titan starting spawns still follow moundPosition. Explicit runtime spawn coordinates
(e.g. at a corpse) are not translated a second time.

## Minimap

Camera bounds alone do not crop the existing minimap terrain image. Each area
supports `minimapTexture`, for example `"war3mapImported\\MinimapClassic.blp"`.
Create a terrain minimap image cropped to that area's gameplay `bounds`, import
it with that exact path, and set the field. Use a separate image for Vulcanic.
No images are included yet; `nil` leaves the existing minimap texture unchanged.
The texture is applied together with gameplay camera bounds, locally for the
affected player. Point-sized race-pick bounds do not load the gameplay image.
Check terrain, unit markers and minimap clicks together in-game for alignment.

Warcraft III 3.0 patch notes also announce dynamic minimap generation within
camera bounds. Its activation and behavior with runtime bounds have not been
verified here. If using that feature, leave `minimapTexture = nil` and test both
team pick cameras and the switch to gameplay bounds.

## Remaining terrain work

This adds selection and central spawning; it does not edit W3X terrain or divide
the physical map. Separate the areas using terrain/pathing. Camera bounds alone
do not prevent movement/teleports or restrict the minimap. Existing decorative
units, critters, base handicap rectangles and Easter egg coordinates remain
map-specific and need a separate layout pass for Vulcanic. Keep the Classic
coordinates/regions intact. Until Vulcanic coordinates are entered, selecting
it still uses the copied Classic positions.

Check both choices in-game: Mound, all shops, EXP stone, race pickers, initial
Titan/Defender spawns, Minion spawns and camera bounds. Test synchronized host
selection with another player. This feature is not ready for release with the
placeholder Vulcanic coordinates.
