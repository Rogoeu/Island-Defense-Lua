if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/DryadStructureAbilities") end

OnInit("DryadStructureAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")

    local IDS = {
        DAY_REGEN = FourCC("A0NR"),
        DAY_REGEN_ICON = FourCC("A0NT"),
        NIGHT_REGEN = FourCC("A0NS"),
        NIGHT_REGEN_ICON = FourCC("A0NU"),
        ISLAND_BLOOM = FourCC("o03C"),
        DISABLE_ATTACK = FourCC("&noa"),
        UPGRADE_ORDER = 852531,
        FERAL_TOWERS = {
            FourCC("o032"),
            FourCC("o033"),
            FourCC("o034"),
            FourCC("o035"),
            FourCC("o036"),
            FourCC("o037"),
            FourCC("o038"),
            FourCC("o039"),
            FourCC("o03A"),
            FourCC("o03B")
        },
        FERAL_UPGRADE_ABILITIES = {
            FourCC("ADT0"),
            FourCC("A0NV"),
            FourCC("ADT2"),
            FourCC("ADT3"),
            FourCC("ADT4"),
            FourCC("ADT5"),
            FourCC("ADT6"),
            FourCC("ADT7"),
            FourCC("ADT8")
        }
    }
    local lastDayState = nil

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405
    end

    local function isFeralTowerId(unitId)
        local i = 1
        while i <= #IDS.FERAL_TOWERS do
            if IDS.FERAL_TOWERS[i] == unitId then
                return true
            end
            i = i + 1
        end
        return false
    end

    local function isFeralTower(unit)
        return isFeralTowerId(GetUnitTypeId(unit))
    end

    local function isBloom(unit)
        return GetUnitTypeId(unit) == IDS.ISLAND_BLOOM
    end

    local function isDay()
        local time = GetFloatGameState(GAME_STATE_TIME_OF_DAY)
        return time >= 6.0 and time < 18.0
    end

    local function setUnitRegenDay(unit)
        UnitRemoveAbility(unit, IDS.NIGHT_REGEN)
        UnitRemoveAbility(unit, IDS.NIGHT_REGEN_ICON)
        if GetUnitAbilityLevel(unit, IDS.DAY_REGEN_ICON) <= 0 then
            UnitAddAbility(unit, IDS.DAY_REGEN_ICON)
        end
        if GetUnitAbilityLevel(unit, IDS.DAY_REGEN) <= 0 then
            UnitAddAbility(unit, IDS.DAY_REGEN)
        end
    end

    local function setUnitRegenNight(unit)
        UnitRemoveAbility(unit, IDS.DAY_REGEN)
        UnitRemoveAbility(unit, IDS.DAY_REGEN_ICON)
        if GetUnitAbilityLevel(unit, IDS.NIGHT_REGEN_ICON) <= 0 then
            UnitAddAbility(unit, IDS.NIGHT_REGEN_ICON)
        end
        if GetUnitAbilityLevel(unit, IDS.NIGHT_REGEN) <= 0 then
            UnitAddAbility(unit, IDS.NIGHT_REGEN)
        end
    end

    local function onTimeChange(unit)
        if not isAlive(unit) then
            return
        end

        if not isFeralTower(unit) and not isBloom(unit) then
            return
        end

        if isDay() then
            UnitRemoveAbility(unit, IDS.DISABLE_ATTACK)
            setUnitRegenDay(unit)
        else
            setUnitRegenNight(unit)
            if isBloom(unit) and GetUnitAbilityLevel(unit, IDS.DISABLE_ATTACK) <= 0 then
                UnitAddAbility(unit, IDS.DISABLE_ATTACK)
            end
        end

    end

    local function forDryadStructures(callback)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRect(group, GetWorldBounds(), nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isAlive(unit) and (isFeralTower(unit) or isBloom(unit)) then
                callback(unit)
            end
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
    end

    local function refreshAllByTime()
        local currentDayState = isDay()

        if lastDayState == nil then
            lastDayState = currentDayState
            forDryadStructures(function(unit)
                onTimeChange(unit)
            end)
            return
        end

        if currentDayState ~= lastDayState then
            lastDayState = currentDayState
            forDryadStructures(function(unit)
                onTimeChange(unit)
            end)
        end
    end

    local function autoUpgradeFeral()
        forDryadStructures(function(unit)
            if isFeralTower(unit) and
                GetOwningPlayer(unit) ~= Player(PLAYER_NEUTRAL_PASSIVE) and
                GetUnitAbilityLevel(unit, FourCC("Abun")) == 0 and
                GetUnitState(unit, UNIT_STATE_MANA) >= GetUnitState(unit, UNIT_STATE_MAX_MANA) then
                IssueImmediateOrderById(unit, IDS.UPGRADE_ORDER)
            end
        end)
    end

    local function isFeralUpgradeAbility(abilityId)
        local i = 1
        while i <= #IDS.FERAL_UPGRADE_ABILITIES do
            if IDS.FERAL_UPGRADE_ABILITIES[i] == abilityId then
                return true
            end
            i = i + 1
        end
        return false
    end

    local function onFeralCastEnd()
        local unit = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()
        local x = 0.0
        local y = 0.0

        if not isFeralUpgradeAbility(abilityId) then
            return
        end

        x = GetUnitX(unit)
        y = GetUnitY(unit)
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", x, y))
        GameTimer.after(0.01, function()
            if isAlive(unit) then
                SetUnitAnimation(unit, "stand")
                QueueUnitAnimation(unit, "stand")
                if isDay() then
                    setUnitRegenDay(unit)
                else
                    setUnitRegenNight(unit)
                end
            end
        end)
    end

    local constructTrigger = CreateTrigger()
    local upgradeTrigger = CreateTrigger()
    local spellEndTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(constructTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(upgradeTrigger, Player(i), EVENT_PLAYER_UNIT_UPGRADE_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(spellEndTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_ENDCAST, nil)
        i = i + 1
    end

    TriggerAddAction(constructTrigger, function()
        local debugApi = rawget(_G, "Debug")
        local unit = GetConstructedStructure()
        if debugApi and debugApi.try then
            debugApi.try(onTimeChange, unit)
        else
            onTimeChange(unit)
        end
    end)

    TriggerAddAction(upgradeTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onTimeChange, GetTriggerUnit())
        else
            onTimeChange(GetTriggerUnit())
        end
    end)

    TriggerAddAction(spellEndTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onFeralCastEnd)
        else
            onFeralCastEnd()
        end
    end)

    GameTimer.every(1.0, function()
        autoUpgradeFeral()
    end)

    GameTimer.every(5.0, function()
        refreshAllByTime()
    end)

    AbilityRegistry.registerRace("Dryad", "structures", {
        notes = "Dryad structure abilities ported from FeralTowerRegeneration.",
        abilities = {
            {
                name = "Feral Tower auto-upgrade",
                source = "library FeralTowerRegeneration",
                behavior = "Feral towers try to upgrade themselves with order 852531 when mana is full."
            },
            {
                name = "Feral/Island Bloom day-night regeneration",
                source = "library FeralTowerRegeneration",
                behavior = "Feral towers and Island Bloom swap day/night regeneration abilities; Island Bloom cannot attack at night."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
