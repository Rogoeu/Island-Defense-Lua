# Local model scaling

Player Profile > Graphics > Scaled Models toggles `profile.graphics.scaledModels`.
The default is `false`. Changes immediately refresh existing tracked units and
save through `PlayerProfile.saveAllPlayers()`. No second save system is used.

## Configuration

Edit `MODEL_SCALE` near the top of `Systems/LocalModelScaling.lua`:

```lua
[FourCC("YOUR")] = { factor = 0.70, normalScale = 1.0 },
```

Replace `YOUR` with an actual four-character unit ID. `factor` multiplies the normal
visual size. The module reads `UNIT_RF_SCALING_VALUE` before its first visual write
and caches it per unit/type. SetUnitScale takes an absolute scale: disabled uses
`original * normalScale`, enabled uses `original * normalScale * factor`.
Keep `normalScale = 1.0` to restore the Object Editor size. For example, original
0.6 with factor 0.5 becomes 0.3 when enabled and 0.6 when disabled.
Do not list spell dummies whose size
is animated by another system: this module is not a replacement for those
animations and cannot infer arbitrary scripted per-instance scale changes.

Import this module after PlayerProfile and GameTimer and before PlayerProfileUI.
No FDF/TOC imports are needed. Updated files: PlayerProfile.lua, PlayerProfileUI.lua.

## Compatibility

The existing v1 codec stores typed key paths, not positional fields. Its existing
recursive `copyDefaults` merges the optional graphics table during decoding and
normalization. Version, season, filenames, encryption/checksum, and existing
field meanings are unchanged. No version bump or migration is required.

The regression test encodes a pre-feature v1 fixture without `graphics`, decodes
it with the updated module, and compares every existing serialized field after
normalization. It includes ratings, statistics, camera, cosmetics, bans and an
unknown field. It also tests enabled/disabled round trips. This verifies the
codec path; it does not replace a Warcraft preload-file integration test.

## Local rendering and validation

The profile system maintains profiles by player and synchronizes initial loads.
Only the local player's graphics preference is read. Only SetUnitScale and a
private visual cache depend on its value. No units, orders, damage, stats,
collision, ownership, random draws or gameplay decisions depend on it.
Groups, the region, triggers and timers are created unconditionally on every
client. Refreshing from the local UI/load callback allocates no game handles.
New units are tracked by region entry; an initial scan covers preplaced units.
A fixed 0.5-second pass handles type changes and removes stale handles. It is
independent of the preference, and does not repeatedly set unchanged scales.

Risks to check in Warcraft: engine-specific local SetUnitScale behavior,
selection/attachment visuals, conflicts with other scripted scaling, units
created outside world bounds, and late object-specific model changes. A fixed
type table is deliberately used instead of guessing affected models.

Run `tools/test_model_scaling.py` with Python and lupa. Tests use Lua 5.3 and mock
Warcraft natives; existing/new units, restore, morphs, deletion and two local
player preferences are covered. In-game checks still required:

1. Load an existing saved profile and verify Elo, unlocks and settings.
2. Configure an actual unit ID; enable scaling on one of two clients only.
3. Compare the same preplaced/new/morphed unit on both clients.
4. Toggle off, restart the map, verify persistence and normal size restoration.
5. Play a multiplayer match with opposite settings and check for desyncs.
