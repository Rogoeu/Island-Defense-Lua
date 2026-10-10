if Debug and Debug.beginFile then Debug.beginFile("core/DefaultGameSettings") end

OnInit("DefaultGameSettings", function(import)
    import.strict("GameSettings")

    local DefaultGameSettings = {}

    local function setBoolDefault(key, value)
        if not GameSettings.exists(key) then
            GameSettings.setBool(key, value)
        end
    end

    local function setIntDefault(key, value)
        if not GameSettings.exists(key) then
            GameSettings.setInt(key, value)
        end
    end

    local function setRealDefault(key, value)
        if not GameSettings.exists(key) then
            GameSettings.setReal(key, value)
        end
    end

    local function setStrDefault(key, value)
        if not GameSettings.exists(key) then
            GameSettings.setStr(key, value)
        end
    end

    function DefaultGameSettings.apply()
        -- Boot/runtime flags.
        -- If true, disables the Lua-driven game start flow for debugging/import tests.
        setBoolDefault("LUA_AUTOSTART_DISABLED", false)
        -- Warcraft save files are unsafe for this multiplayer map and can crash clients.
        setBoolDefault("DISABLE_GAME_SAVING", true)

        -- Debug tooling. DEBUG_FAST_TIMERS only matters when debug setup enables its fast test flow.
        -- Main debug flag used by debug-only systems and helper commands.
        setBoolDefault("DEBUG", false)
        -- Forces debug mode even when the normal environment would not enable it.
        setBoolDefault("FORCE_DEBUG_MODE", false)
        -- Allows debug features outside of single-player/local test contexts.
        setBoolDefault("DEBUG_ALLOW_MULTIPLAYER", false)
        -- Lets debug setup shorten timers for faster test rounds.
        setBoolDefault("DEBUG_FAST_TIMERS", true)

        -- Global match setup.
        -- Reveals the full map briefly when the match starts.
        setBoolDefault("REVEAL_MAP_ON_START", true)
        -- Enables optional lightning visuals used by chained spells and items.
        setBoolDefault("LIGHTNING_EFFECTS_ENABLED", true)
        -- Duration of the start-of-game map reveal.
        setRealDefault("REVEAL_MAP_ON_START_SECONDS", 1.0)
        -- Food cap applied to active players.
        setIntDefault("MAX_FOOD_SUPPLY", 150)
        -- Number of fake players created in solo tests to simulate a full lobby target.
        setIntDefault("SOLO_FAKE_TARGET_PLAYERS", 11)
        -- Active gameplay slots are 0 through this value minus one; higher slots are observers.
        setIntDefault("MAX_ACTIVE_PLAYERS", 11)
        -- Total Warcraft player slots considered by the Lua systems, including observers.
        setIntDefault("MAX_PLAYERS", 24)

        -- Pick-mode timings.
        -- Time before the Titan selection/start decision resolves.
        setRealDefault("TITAN_SELECTION_TIME", 20.0)
        -- Minimum saved Builder + Titan games needed to volunteer as Titan.
        setIntDefault("TITAN_SELECTION_MIN_GAMES", 10)
        -- Time the host has in the custom setup UI.
        setRealDefault("PICK_MODE_SELECTION_TIME", 120.0)
        -- Time defenders have to choose their race after setup.
        setRealDefault("DEFENDER_PICK_TIME", 10.0)
        -- Time the Titan has to choose a Titan race.
        setRealDefault("TITAN_PICK_TIME", 55.0)
        -- Grace period between the random Builder spawn and the random Titan spawn.
        setRealDefault("TITAN_SPAWN_GRACE_TIME", 60.0)
        -- Number of race choices shown in unique-pick style selection.
        setIntDefault("UNIQUE_PICK_MAX_CHOICES", 6)
        -- Maximum defender race bans in the pick-mode UI.
        setIntDefault("PICKMODE_RACE_BAN_MAX", 4)
        -- Maximum Titan race bans in the pick-mode UI.
        setIntDefault("PICKMODE_RACE_BAN_MAX_TITANS", 3)
        -- Applies tech limits that prevent unavailable races/options from being chosen.
        setBoolDefault("APPLY_RACE_TECH_LIMITS", true)
        -- Converts real Defenders who never moved after spawning into Builder Observers
        -- when the Titan spawns after their movement/grace window.
        setBoolDefault("PICKMODE_REMOVE_AFK", true)
        -- Replaces a real Titan who performs no synchronized game action for too long.
        setBoolDefault("TITAN_AFK_ENABLED", true)
        -- Announces that the Titan is inactive after this many seconds.
        setRealDefault("TITAN_AFK_WARNING_SECONDS", 30.0)
        -- Starts the Defender AFK vote after this many seconds.
        setRealDefault("TITAN_AFK_TIMEOUT_SECONDS", 60.0)
        -- Time Defenders have to choose between waiting and removing the Titan.
        setRealDefault("TITAN_AFK_VOTE_SECONDS", 30.0)

        -- Starting resources.
        -- Builder starting gold.
        setIntDefault("BUILDER_START_GOLD", 0)
        -- Builder starting lumber.
        setIntDefault("BUILDER_START_LUMBER", 30)
        -- Extra gold granted when the random bonus mode is enabled.
        setIntDefault("BUILDER_RANDOM_BONUS_GOLD", 0)
        -- Extra lumber granted when the random bonus mode is enabled.
        setIntDefault("BUILDER_RANDOM_BONUS_LUMBER", 20)
        -- Titan starting gold.
        setIntDefault("TITAN_START_GOLD", 250)
        -- Titan starting lumber.
        setIntDefault("TITAN_START_LUMBER", 400)
        -- Extra resources granted when the Titan was selected randomly.
        setIntDefault("TITAN_RANDOM_GOLD_BONUS", 50)
        setIntDefault("TITAN_RANDOM_WOOD_BONUS", 100)
        -- Optional item rawcode for the Titan's first inventory slot, for example "I08S". Leave empty for no item.
        setStrDefault("TITAN_START_ITEM_SLOT_1", "I00P")
        -- Optional item rawcode for the Titan's second inventory slot. Leave empty for no item.
        setStrDefault("TITAN_START_ITEM_SLOT_2", "I07P")
        -- Optional item rawcode for the Titan's third inventory slot. Leave empty for no item.
        setStrDefault("TITAN_START_ITEM_SLOT_3", "")
        -- Optional item rawcode for the Titan's fourth inventory slot. Leave empty for no item.
        setStrDefault("TITAN_START_ITEM_SLOT_4", "")
        -- Optional item rawcode for the Titan's fifth inventory slot. Leave empty for no item.
        setStrDefault("TITAN_START_ITEM_SLOT_5", "")
        -- Optional item rawcode for the Titan's sixth inventory slot. Leave empty for no item.
        setStrDefault("TITAN_START_ITEM_SLOT_6", "")

        -- Titan and minion levels.
        -- Hero level assigned to the Titan on spawn.
        setIntDefault("TITAN_START_LEVEL", 2)
        -- Base hero level assigned to newly spawned minions.
        setIntDefault("MINION_START_LEVEL", 2)
        -- Seconds per additional minion start level as game time passes.
        setRealDefault("MINION_START_LEVEL_INTERVAL_SECONDS", 300.0)
        -- Maximum minion start level from time scaling.
        setIntDefault("MINION_START_LEVEL_MAX", 6)

        -- Minion spawning after defender death.
        -- If true, dead defenders can still receive the minion-spawn grace flow.
        setBoolDefault("MINION_SPAWN_ALLOW_GRACE", true)
        -- Grace period before a dead defender may become/spawn a minion.
        setRealDefault("MINION_SPAWN_GRACE_TIME", 180.0)
        -- If true, uses the courier-style delayed minion delivery.
        setBoolDefault("MINION_SPAWN_COURIER_ENABLED", true)
        -- Movement speed used by the minion-spawn courier.
        setRealDefault("MINION_SPAWN_COURIER_SPEED", 522.0)
        -- Item rawcode used to reveal/show the minion grace state.
        setStrDefault("MINION_GRACE_REVEAL_ITEM", "I03M")

        -- UI and lobby-visible game modes.
        -- Enables base handicap scaling.
        setBoolDefault("BASE_HANDICAP_ENABLED", true)
        -- Extra mode labels shown in the multiboard title, such as EXP/FROFF/GC.
        setStrDefault("MULTIBOARD_TWEAKS", "")
        -- If true, multiboard display is split by team.
        setBoolDefault("MULTIBOARD_SPLIT_BY_TEAM", true)

        -- Defender death/leave cleanup.
        -- Seconds the Titan is revealed after killing a defender.
        setRealDefault("DEFENDER_DEATH_TITAN_REVEAL_SECONDS", 3.0)
        -- Enables neutral ghost buildings for dead/left defenders.
        setBoolDefault("DEFENDER_GHOST_BUILDINGS_ENABLED", true)
        -- Lifetime of ghost buildings before cleanup.
        setRealDefault("DEFENDER_GHOST_BUILDING_SECONDS", 120.0)
        -- If true, ghost buildings are removed at the end of their lifetime.
        setBoolDefault("DEFENDER_GHOST_BUILDINGS_REMOVE", true)
        -- Transfers abandoned/dead defender structures to neutral ownership.
        setBoolDefault("NEUTRALIZE_STRUCTURES", true)
        -- Enables timed decay for neutralized structures.
        setBoolDefault("NEUTRALIZE_STRUCTURES_DECAY", true)
        -- Duration before neutralized structures decay/remove.
        setRealDefault("NEUTRALIZE_STRUCTURES_DECAY_TIME", 120.0)
        -- Grace period before leave cleanup fully processes a defender.
        setRealDefault("DEFENDER_LEAVE_GRACE_SECONDS", 30.0)
        -- Runtime counter for killed defenders.
        setIntDefault("KILLED_DEFENDERS_COUNT", 0)

        -- Titan punishment system.
        -- Enables automatic Titan punishment logic.
        setBoolDefault("TITAN_AUTOPUNISH", false)

        -- End-game behavior. Disabled by default while Lua migration is still being tested.
        -- If true, Lua win-condition code can end the game.
        setBoolDefault("WIN_CONDITION_END_GAME", true)

        -- Titan and minion feed experience.
        -- Global multiplier for Titan/minion feed experience.
        setRealDefault("TITAN_EXP_GLOBAL_FACTOR", 1.0)
        -- Share factor used when distributing Titan/minion experience.
        setRealDefault("TITAN_EXP_SHARE_FACTOR", 0.75)
        -- EXP mode toggle that doubles the global Titan/minion experience factor.
        setBoolDefault("TITAN_EXP_GLOBAL_FACTOR_DOUBLED", false)
        -- Enables feed reduction/scaling instead of full raw experience.
        setBoolDefault("TITAN_EXP_REDUCTION_ENABLED", true)
        -- Experience reduction amount per missing defender/player.
        setRealDefault("TITAN_EXP_MISSING_PLAYER_FACTOR", 0.06)
        -- Experience factor for neutral kills/feed.
        setRealDefault("TITAN_EXP_NEUTRAL_FACTOR", 0.5)
        -- Period used by defender passive experience rate logic.
        setRealDefault("DEFENDER_EXP_RATE_TIME", 0.20)

        -- Persistent player profiles.
        -- Elo assigned to a player with no saved rating yet.
        setIntDefault("PLAYER_PROFILE_ELO_DEFAULT", 400)
        -- Maximum Elo movement for one match before opponent-rating scaling.
        setIntDefault("PLAYER_PROFILE_ELO_K", 24)
        -- Elo K-factor for a Titan personally killing a Builder. The actual
        -- transfer scales with the Titan/Builder rating difference.
        setIntDefault("PLAYER_PROFILE_ELO_BUILDER_KILL_K", 10)
        -- Builder Elo lost when the Builder dies without a Titan as killer.
        setIntDefault("PLAYER_PROFILE_BUILDER_ELO_PER_DEATH", 5)
        -- Enables the profile button and profile overview UI for every player.
        setBoolDefault("PLAYER_PROFILE_UI_ENABLED", true)

        -- Titan Hunter side objectives.
        -- Enables the Super Critter objective and multiboard counter.
        setBoolDefault("TITAN_HUNTER_SUPER_CRITTER_ENABLED", true)
        -- Critter kills required before the Super Critter spawns.
        setIntDefault("TITAN_HUNTER_SUPER_CRITTER_KILLS", 50)

        -- Gold-feed tracking and gold coin drops.
        -- Tracks how much gold the Titan receives from defender sources.
        setBoolDefault("GOLD_FEED_TRACKING_ENABLED", true)
        -- Goldfed must only count real gold, never experience feed.
        setBoolDefault("GOLD_FEED_FALLBACK_TO_EXP_FEED", false)
        -- Runtime counter for gold stolen from the Titan mound.
        setIntDefault("TITAN_MOUND_GOLD_STOLEN", 0)
        -- Gold coin mode state; set to "on" by the custom setup UI.
        setStrDefault("TWEAK_GC", "off")
        -- Gold granted by a spawned gold coin.
        setIntDefault("GC_GOLD_AMOUNT", 10)
        -- Upper bound for gold coin chance rolls.
        setIntDefault("GC_CHANCE_ROLL_MAX", 20)
        -- Successful roll threshold/count for gold coin drops.
        setIntDefault("GC_CHANCE_SUCCESS_MAX", 5)
    end

    DefaultGameSettings.apply()

    _G.DefaultGameSettings = DefaultGameSettings
end)

if Debug and Debug.endFile then Debug.endFile() end
