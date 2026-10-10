if Debug and Debug.beginFile then Debug.beginFile("Systems/BaseHandicap") end

OnInit("BaseHandicap", function(import)
    import.strict("GameSettings")
    import.strict("PlayerData")

    local REFRESH_INTERVAL = 2.0
    local ABILITY_ATTACK_SPEED = FourCC("A0TN")
    local ABILITY_INFO_ICON = FourCC("S01N")
    local TOWER_CLASSIFICATION = FourCC("TOWR")
    local WARD_CLASSIFICATION = FourCC("WARD")

    local BASE_RECT_NAMES = {
        "gg_rct_BaseTopOfTheWorld",
        "gg_rct_BasePoseidon",
        "gg_rct_BaseHeaven",
        "gg_rct_BaseRiver",
        "gg_rct_BaseTomb",
        "gg_rct_BaseHideout",
        "gg_rct_BaseHermit",
        "gg_rct_BaseBrokenFountain",
        "gg_rct_BaseAztec",
        "gg_rct_BaseSky",
        "gg_rct_BaseRetreat",
        "gg_rct_BaseOvaries",
        "gg_rct_BasePalace",
        "gg_rct_BaseParadise",
        "gg_rct_BaseWaterfall",
        "gg_rct_BaseTommygun",
        "gg_rct_BaseStronghold",
        "gg_rct_BaseClaw",
        "gg_rct_BaseBay",
        "gg_rct_BaseBeach"
    }

    local EXCLUDE_RECT_NAMES = {
        [1] = "gg_rct_BaseExclTheTopOfTheWorld",
        [6] = "gg_rct_BaseExclHideout",
        [17] = "gg_rct_BaseExclStronghold"
    }

    local BaseHandicap = {}

    local function rectByName(name)
        return rawget(_G, name)
    end

    local function enabled()
        if GameSettings.exists("BASE_HANDICAP_ENABLED") then
            return GameSettings.getBool("BASE_HANDICAP_ENABLED")
        end
        return true
    end

    local function isValidCountingUnit(unit)
        local playerData = unit and PlayerData.get(GetOwningPlayer(unit)) or nil
        return playerData
            and playerData:class() == PlayerData.CLASS_DEFENDER
            and GetUnitState(unit, UNIT_STATE_LIFE) >= 0.405
            and GetUnitAbilityLevel(unit, WARD_CLASSIFICATION) == 0
    end

    local function removeUnitsInExcludeZone(group, excludeRect)
        local excludeGroup = CreateGroup()
        local unit = nil

        if not excludeRect then
            return
        end

        GroupEnumUnitsInRect(excludeGroup, excludeRect, nil)
        unit = FirstOfGroup(excludeGroup)
        while unit do
            GroupRemoveUnit(excludeGroup, unit)
            GroupRemoveUnit(group, unit)
            unit = FirstOfGroup(excludeGroup)
        end
        DestroyGroup(excludeGroup)
    end

    local function countDefenderPlayersInBase(baseRect, excludeRect)
        local group = CreateGroup()
        local playerUnits = CreateGroup()
        local unit = nil
        local count = 0

        GroupEnumUnitsInRect(group, baseRect, nil)
        removeUnitsInExcludeZone(group, excludeRect)

        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isValidCountingUnit(unit) then
                count = count + 1
                GroupEnumUnitsOfPlayer(playerUnits, GetOwningPlayer(unit), nil)
                local sameOwnerUnit = FirstOfGroup(playerUnits)
                while sameOwnerUnit do
                    GroupRemoveUnit(playerUnits, sameOwnerUnit)
                    GroupRemoveUnit(group, sameOwnerUnit)
                    sameOwnerUnit = FirstOfGroup(playerUnits)
                end
            end
            unit = FirstOfGroup(group)
        end

        DestroyGroup(playerUnits)
        DestroyGroup(group)
        return count
    end

    local function applyEffectsOnTowers(baseRect, playerCount)
        local group = CreateGroup()
        local unit = nil
        local level = playerCount + 1

        GroupEnumUnitsInRect(group, baseRect, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if GetUnitAbilityLevel(unit, TOWER_CLASSIFICATION) > 0 then
                if GetUnitAbilityLevel(unit, ABILITY_ATTACK_SPEED) > 0 then
                    SetUnitAbilityLevel(unit, ABILITY_ATTACK_SPEED, level)
                end
                if GetUnitAbilityLevel(unit, ABILITY_INFO_ICON) > 0 then
                    SetUnitAbilityLevel(unit, ABILITY_INFO_ICON, level)
                end
            end
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
    end

    function BaseHandicap.refresh()
        local i = 1
        local forcedCount = nil

        if not enabled() then
            forcedCount = 0
        end

        while i <= #BASE_RECT_NAMES do
            local baseRect = rectByName(BASE_RECT_NAMES[i])
            if baseRect then
                local count = forcedCount
                if count == nil then
                    count = countDefenderPlayersInBase(baseRect, rectByName(EXCLUDE_RECT_NAMES[i]))
                end
                applyEffectsOnTowers(baseRect, count)
            end
            i = i + 1
        end
    end

    function BaseHandicap.setEnabled(value)
        GameSettings.setBool("BASE_HANDICAP_ENABLED", value == true)
        BaseHandicap.refresh()
    end

    function BaseHandicap.isEnabled()
        return enabled()
    end

    local trigger = CreateTrigger()
    TriggerRegisterTimerEvent(trigger, REFRESH_INTERVAL, true)
    TriggerAddAction(trigger, function()
        BaseHandicap.refresh()
    end)

    _G.BaseHandicap = BaseHandicap
end)

if Debug and Debug.endFile then Debug.endFile() end
