if Debug and Debug.beginFile then Debug.beginFile("Systems/LocalModelScaling") end

OnInit("LocalModelScaling", function(import)
    import.strict("PlayerProfile")
    import.strict("GameTimer")

    -- Central configuration: factors relative to the Object Editor model size.
    -- normalScale is an optional multiplier of the Object Editor scale.
    -- Do not configure animated/scaling spell dummies here.
    local MODEL_SCALE = {
        --Builders
        [FourCC("u00I")] = {factor = 0.5, normalScale = 1}, -- Demonologist
        [FourCC("h01B")] = {factor = 0.5, normalScale = 1}, -- Magnataur
        [FourCC("h009")] = {factor = 0.8, normalScale = 1}, -- Gnoll
        [FourCC("h021")] = {factor = 0.6, normalScale = 1}, -- Morphling Builder
        [FourCC("h024")] = {factor = 0.7, normalScale = 1}, -- Morphling Beast
        [FourCC("h01T")] = {factor = 1.2, normalScale = 1}, -- Dryad
        [FourCC("h05K")] = {factor = 0.6, normalScale = 1}, -- Zergling custom Model Felhound
        [FourCC("h037")] = {factor = 0.85, normalScale = 1},-- Ogre
        --Titan Hunter
        [FourCC("H04U")] = {factor = 0.5, normalScale = 1},-- Arachnid Hunter
        [FourCC("H00N")] = {factor = 0.6, normalScale = 1},-- Makrura Hunter
        [FourCC("H00Z")] = {factor = 0.7, normalScale = 1},-- Goblin Hunter
        [FourCC("H05G")] = {factor = 0.7, normalScale = 1},-- Goblin Hunter
        [FourCC("H020")] = {factor = 0.75, normalScale = 1},-- Radioactive Hunter
        [FourCC("H00O")] = {factor = 0.8, normalScale = 1},-- Gnoll Hunter
        [FourCC("H039")] = {factor = 0.75, normalScale = 1},-- Ogre Hunter
        [FourCC("H05O")] = {factor = 0.9, normalScale = 1},-- Makrura small hunter
        [FourCC("U00S")] = {factor = 1.2, normalScale = 1},-- Demonologist Hunter
        --Titan
        [FourCC("E00B")] = {factor = 0.5, normalScale = 1},-- Noxious
        [FourCC("E00E")] = {factor = 1.2, normalScale = 1},-- Demonicus
        [FourCC("E00C")] = {factor = 0.6, normalScale = 1},-- Moltenious
        --Minion
        [FourCC("U01B")] = {factor = 0.6, normalScale = 1},-- Foss egg
        [FourCC("U001")] = {factor = 0.6, normalScale = 1},-- Noxious Child
        [FourCC("U00B")] = {factor = 1.2, normalScale = 1},-- Bub Minion
        --Doodads
        -- [FourCC("h001")] = { factor = 0.70, normalScale = 1.0 },
    }

    local LocalModelScaling = {}
    local units = {} -- Populated on every client, never based on preferences.
    local lastVisual = {} -- Local-only cache; never read by gameplay code.
    local originalScale = {} -- Capture before our first visual write per type.
    local scanGroup = CreateGroup()
    local region = CreateRegion()
    RegionAddRect(region, GetWorldBounds())

    local function enabledLocally()
        -- Profiles are indexed by player and initially synchronized. Only this
        -- client's preference is read for rendering; do not use it in gameplay.
        return PlayerProfile.graphics(GetLocalPlayer()).scaledModels == true
    end

    function LocalModelScaling.apply(unit)
        if not unit then return end
        local typeId = GetUnitTypeId(unit)
        if typeId == 0 then return end
        local config = MODEL_SCALE[typeId]
        local previous = lastVisual[unit]
        if not config and not previous then return end

        -- SetUnitScale takes an absolute scale, not a multiplier of the
        -- Object Editor scale. Capture the original field before writing.
        local original = originalScale[unit]
        if not original or original.typeId ~= typeId then
            original = { typeId = typeId, scale = BlzGetUnitRealField(unit, UNIT_RF_SCALING_VALUE) }
            originalScale[unit] = original
        end
        local scale = original.scale * (config and (config.normalScale or 1.0) or 1.0)
        if config and enabledLocally() then scale = scale * config.factor end
        if not previous or previous.typeId ~= typeId or previous.scale ~= scale then
            SetUnitScale(unit, scale, scale, scale)
            lastVisual[unit] = config and { typeId = typeId, scale = scale } or nil
        end
    end

    function LocalModelScaling.refresh()
        -- Enumerate the centrally tracked units, including hidden main units.
        -- No handles, timers, orders or synchronized state are created here.
        for unit in pairs(units) do
            LocalModelScaling.apply(unit)
        end
    end

    function LocalModelScaling.setEnabled(enabled)
        -- Called by the existing local settings UI. Persist in PlayerProfile;
        -- no profile broadcast is needed for this purely visual preference.
        PlayerProfile.setScaledModels(GetLocalPlayer(), enabled)
        LocalModelScaling.refresh()
        return PlayerProfile.saveAllPlayers()
    end

    local enter = CreateTrigger()
    TriggerRegisterEnterRegion(enter, region, nil)
    TriggerAddAction(enter, function()
        local unit = GetEnteringUnit()
        units[unit] = true
        LocalModelScaling.apply(unit)
    end)

    -- Always scheduled on every client. Also catches morphs/upgrades without
    -- installing hooks in the many independent CreateUnit call sites.
    GameTimer.after(0.0, function()
        GroupEnumUnitsInRect(scanGroup, GetWorldBounds(), nil)
        local unit = FirstOfGroup(scanGroup)
        while unit do
            GroupRemoveUnit(scanGroup, unit)
            units[unit] = true
            LocalModelScaling.apply(unit)
            unit = FirstOfGroup(scanGroup)
        end
        DestroyGroup(scanGroup)
    end)
    GameTimer.every(0.5, function()
        for unit in pairs(units) do
            if GetUnitTypeId(unit) == 0 then
                units[unit] = nil
                lastVisual[unit] = nil
                originalScale[unit] = nil
            else
                LocalModelScaling.apply(unit)
            end
        end
    end)

    PlayerProfile.onLoaded(function()
        LocalModelScaling.refresh()
    end)

    _G.LocalModelScaling = LocalModelScaling
end)

if Debug and Debug.endFile then Debug.endFile() end
