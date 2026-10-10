if Debug and Debug.beginFile then Debug.beginFile("Systems/CritterSystem") end

OnInit("CritterSystem", function(import)
    import.strict("GameTimer")
    import.strict("ShowTagFromUnit")

    -- These critters have the funny click-to-explode behavior. This list is
    -- intentionally smaller than the respawn list below.
    local EXPLODABLE_CRITTERS = {
        [FourCC("n020")] = true,
        [FourCC("nJEN")] = true,
        [FourCC("nfbr")] = true
    }

    -- How often a selected explodable critter has to be clicked before it dies.
    local CLICKS_TO_EXPLODE = 100

    -- Old Zinc ticked critter respawns every 20 seconds.
    local RESPAWN_CHECK_INTERVAL = 20.0
    local ACTIVE_PLAYER_SLOTS = 12
    local CLICK_SYNC_PREFIX = "IDCritterClick"

    -- Remaining click counters are stored by handle id, because the unit handle
    -- itself can disappear after death.
    local clicksRemaining = {}
    local explodableById = {}

    -- Each entry stores the original map critter and its spawn data. When the
    -- unit dies, the same entry is reused for the replacement.
    local trackedCritters = {}

    -- Only map-placed ambient critters are tracked for respawning. Summoned
    -- chickens, Super Critters and other gameplay units stay unaffected.
    local RESPAWNABLE_CRITTERS = {
        [FourCC("nalb")] = true,
        [FourCC("nech")] = true,
        [FourCC("ncrb")] = true,
        [FourCC("ndog")] = true,
        [FourCC("ndwm")] = true,
        [FourCC("nfro")] = true,
        [FourCC("nhmc")] = true,
        [FourCC("npig")] = true,
        [FourCC("nerc")] = true,
        [FourCC("nrat")] = true,
        [FourCC("nsea")] = true,
        [FourCC("nshe")] = true,
        [FourCC("nskk")] = true,
        [FourCC("nsno")] = true,
        [FourCC("nder")] = true,
        [FourCC("nvul")] = true
    }

    local EXPLOSION_EFFECTS = {
        "Abilities\\Spells\\Orc\\WarStomp\\WarStompCaster.mdx",
        "Objects\\Spawnmodels\\Human\\HumanLargeDeathExplode\\HumanLargeDeathExplode.mdx",
        "Abilities\\Weapons\\Mortar\\ScatterShotTarget.mdl",
        "Objects\\Spawnmodels\\Orc\\OrcSmallDeathExplode\\OrcSmallDeathExplode.mdx"
    }

    local CritterSystem = {}

    local function isAlive(unit)
        -- GetUnitTypeId becomes 0 after the handle is removed, so this catches
        -- both killed and cleaned-up critters.
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405
    end

    local function isVisibleToAnyPlayer(x, y)
        local playerId = 0

        -- Match old Zinc: only the active 0-11 player range blocks pop-in.
        -- Observer slots above that range must not suppress respawns.
        while playerId < ACTIVE_PLAYER_SLOTS do
            if IsVisibleToPlayer(x, y, Player(playerId)) then
                return true
            end
            playerId = playerId + 1
        end

        return false
    end

    local function trackCritter(unit)
        -- Store everything needed to recreate this exact critter later.
        trackedCritters[#trackedCritters + 1] = {
            unit = unit,
            x = GetUnitX(unit),
            y = GetUnitY(unit),
            facing = GetUnitFacing(unit),
            owner = GetOwningPlayer(unit),
            typeId = GetUnitTypeId(unit),
            delayed = false
        }
    end

    local function trackExplodable(unit)
        if unit and EXPLODABLE_CRITTERS[GetUnitTypeId(unit)] then
            explodableById[GetHandleId(unit)] = unit
        end
    end

    local function collectMapCritters()
        local group = CreateGroup()
        local unit = nil

        -- This runs once at init and captures the starting critter population.
        -- Critters created later are not added to trackedCritters on purpose.
        GroupEnumUnitsInRect(group, GetWorldBounds(), nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            trackExplodable(unit)
            if RESPAWNABLE_CRITTERS[GetUnitTypeId(unit)] then
                trackCritter(unit)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function respawnCritters()
        local i = 1

        -- One pass handles only one state transition:
        -- alive -> tracked as alive
        -- dead handle still stored -> clear unit and arm delay
        -- delay armed -> clear delay
        -- no unit and no delay -> respawn if hidden
        --
        -- This mirrors the old two-tick delay:
        -- first dead pass stores the death, second hidden pass respawns.
        while i <= #trackedCritters do
            local critter = trackedCritters[i]

            if isAlive(critter.unit) then
                -- The critter is still alive, so any previous respawn delay is
                -- cancelled.
                critter.delayed = false
            elseif critter.unit then
                -- Mirror the old two-pass delay before a hidden critter returns.
                -- First dead pass: forget the old unit handle and start delay.
                critter.unit = nil
                critter.delayed = true
            elseif critter.delayed then
                -- Second dead pass: delay is over. If the point is hidden from
                -- active players, respawn immediately in this same tick.
                critter.delayed = false
                if not isVisibleToAnyPlayer(critter.x, critter.y) then
                    critter.unit = CreateUnit(critter.owner, critter.typeId, critter.x, critter.y, critter.facing)
                    trackExplodable(critter.unit)
                end
            elseif not isVisibleToAnyPlayer(critter.x, critter.y) then
                -- Hidden after a previously blocked respawn attempt.
                critter.unit = CreateUnit(critter.owner, critter.typeId, critter.x, critter.y, critter.facing)
                trackExplodable(critter.unit)
            end

            i = i + 1
        end
    end

    local function effectTimed(path, x, y)
        local effect = AddSpecialEffect(path, x, y)

        -- Effects do not clean themselves up. Destroying later avoids leaks.
        GameTimer.after(1.0, function()
            if effect then
                DestroyEffect(effect)
            end
        end)
    end

    local function explode(unit)
        local x = GetUnitX(unit)
        local y = GetUnitY(unit)
        local i = 1

        -- This uses KillUnit so normal death triggers, including the respawn
        -- tracker above, can react to the critter death.
        ShowTagFromUnit.fromUnitForAll("|cffff0000BOOM!|r", unit)
        while i <= #EXPLOSION_EFFECTS do
            effectTimed(EXPLOSION_EFFECTS[i], x, y)
            i = i + 1
        end
        clicksRemaining[GetHandleId(unit)] = nil
        KillUnit(unit)
    end

    local function applySyncedClick(unit)
        local id = unit and GetHandleId(unit) or 0
        local remaining = 0

        -- Ignore all non-explodable critters. Respawnable-only critters are not
        -- affected by clicking.
        if not unit or not EXPLODABLE_CRITTERS[GetUnitTypeId(unit)] then
            return
        end

        remaining = (clicksRemaining[id] or CLICKS_TO_EXPLODE) - 1
        clicksRemaining[id] = remaining

        if remaining <= 0 then
            explode(unit)
        elseif remaining <= 10 then
            ShowTagFromUnit.fromUnitForAll("|cffff0000" .. I2S(remaining) .. "!|r", unit)
        end
    end

    local function requestClickSync()
        local unit = GetTriggerUnit()

        -- Unit selections are local UI state. Only the selecting player's
        -- client may request the click; the counter and KillUnit happen in the
        -- synchronized callback on every client.
        if GetTriggerPlayer() == GetLocalPlayer() and unit and
            EXPLODABLE_CRITTERS[GetUnitTypeId(unit)] and rawget(_G, "BlzSendSyncData") then
            BlzSendSyncData(CLICK_SYNC_PREFIX, I2S(GetHandleId(unit)))
        end
    end

    local function onDeath()
        local unit = GetTriggerUnit()

        -- Death resets the click counter. A respawned critter starts fresh.
        if unit then
            local id = GetHandleId(unit)
            clicksRemaining[id] = nil
            explodableById[id] = nil
        end
    end

    local selectTrigger = CreateTrigger()
    local syncTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(selectTrigger, Player(i), EVENT_PLAYER_UNIT_SELECTED, nil)
        BlzTriggerRegisterPlayerSyncEvent(syncTrigger, Player(i), CLICK_SYNC_PREFIX, false)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end

    local function guarded(callback)
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(callback)
        else
            callback()
        end
    end

    TriggerAddAction(selectTrigger, function() guarded(requestClickSync) end)
    TriggerAddAction(syncTrigger, function()
        guarded(function()
            local id = tonumber(BlzGetTriggerSyncData()) or 0
            local unit = explodableById[id]

            if unit and GetHandleId(unit) == id and isAlive(unit) and
                EXPLODABLE_CRITTERS[GetUnitTypeId(unit)] then
                applySyncedClick(unit)
            end
        end)
    end)
    TriggerAddAction(deathTrigger, function() guarded(onDeath) end)

    -- Capture map-placed critters once and then periodically try to restore
    -- missing entries.
    collectMapCritters()
    GameTimer.every(RESPAWN_CHECK_INTERVAL, respawnCritters)

    CritterSystem.ids = EXPLODABLE_CRITTERS
    _G.CritterSystem = CritterSystem
end)

if Debug and Debug.endFile then Debug.endFile() end
