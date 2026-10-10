if Debug and Debug.beginFile then Debug.beginFile("items/Titan/SiegecastersTrophy") end

OnInit("TitanItemSiegecastersTrophy", function(import)
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("UnitStateSystem")

    local IDS = {
        SIEGECASTERS_TROPHY = FourCC("I01P"),
        CRAFT_RUNE = FourCC("I016"),
        TITAN_UNIT = FourCC("CTIT")
    }

    local PROC_CHANCE = 1.00
    local MIN_RUNES = 3
    local MAX_RUNES = 5
    local THROW_DISTANCE = 500.0
    local THROW_MIN_DISTANCE = 220.0
    local DESPAWN_MIN = 3.0
    local DESPAWN_MAX = 5.0
    local MOVE_DURATION = 0.35
    local TIMER_PERIOD = 0.03125
    local RUNE_MANA_RADIUS = 500.0
    local RUNE_MANA_RATIO = 0.05
    local RUNE_DESPAWN_MANA_FACTOR = 0.50
    local RUNE_MANA_EFFECT = "Abilities\\Spells\\Items\\AIma\\AImaTarget.mdl"
    local RUNE_MANA_EFFECT_ATTACH = "origin"

    local TitanItemSiegecastersTrophy = {}
    local activeRunes = {}

    local function isTitanUnit(unit)
        return unit and GetUnitAbilityLevel(unit, IDS.TITAN_UNIT) > 0
    end

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.SIEGECASTERS_TROPHY)
    end

    local function restoreRuneManaInRadius(x, y, factor)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRange(group, x, y, RUNE_MANA_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isTitanUnit(unit) and not IsUnitType(unit, UNIT_TYPE_DEAD) then
                UnitStateSystem.addMana(unit, UnitStateSystem.maxMana(unit) * RUNE_MANA_RATIO * factor, {
                    effect = RUNE_MANA_EFFECT,
                    attachPoint = RUNE_MANA_EFFECT_ATTACH
                })
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function scheduleRuneDespawn(item, delay)
        local itemId = GetHandleId(item)

        GameTimer.after(delay, function()
            if item and activeRunes[itemId] then
                restoreRuneManaInRadius(GetItemX(item), GetItemY(item), RUNE_DESPAWN_MANA_FACTOR)
                activeRunes[itemId] = nil
                RemoveItem(item)
            end
        end)
    end

    local function launchRune(sourceX, sourceY, targetX, targetY)
        local item = CreateItem(IDS.CRAFT_RUNE, sourceX, sourceY)
        local itemId = GetHandleId(item)
        local elapsed = 0.0
        local despawnDelay = GetRandomReal(DESPAWN_MIN, DESPAWN_MAX)
        local timer = nil

        activeRunes[itemId] = true

        timer = GameTimer.every(TIMER_PERIOD, function()
            local progress = 0.0
            local x = 0.0
            local y = 0.0

            if not item or not activeRunes[itemId] then
                timer:destroy()
                return
            end

            elapsed = elapsed + TIMER_PERIOD
            if elapsed >= MOVE_DURATION then
                SetItemPosition(item, targetX, targetY)
                scheduleRuneDespawn(item, despawnDelay)
                timer:destroy()
                return
            end

            progress = elapsed / MOVE_DURATION
            x = sourceX + (targetX - sourceX) * progress
            y = sourceY + (targetY - sourceY) * progress
            SetItemPosition(item, x, y)
        end)

        return item
    end

    local function spawnRunesFromBuilding(dying, killer)
        local sourceX = GetUnitX(dying)
        local sourceY = GetUnitY(dying)
        local angle = Atan2(GetUnitY(killer) - sourceY, GetUnitX(killer) - sourceX)
        local count = GetRandomInt(MIN_RUNES, MAX_RUNES)
        local i = 1

        while i <= count do
            local spreadAngle = angle + GetRandomReal(-0.55, 0.55)
            local distance = GetRandomReal(THROW_MIN_DISTANCE, THROW_DISTANCE)
            local targetX = sourceX + distance * Cos(spreadAngle)
            local targetY = sourceY + distance * Sin(spreadAngle)

            launchRune(sourceX, sourceY, targetX, targetY)
            i = i + 1
        end
    end

    function TitanItemSiegecastersTrophy.spawnRunesFromBuilding(dying, killer)
        spawnRunesFromBuilding(dying, killer)
    end

    local function onBuildingDeath()
        local dying = GetTriggerUnit()
        local killer = GetKillingUnit()

        if not dying or not killer or GetUnitTypeId(killer) == 0 then
            return
        end

        if IsUnitType(dying, UNIT_TYPE_STRUCTURE) and hasItem(killer) and GetRandomReal(0.0, 1.0) <= PROC_CHANCE then
            spawnRunesFromBuilding(dying, killer)
        end
    end

    local function onPickup()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if item and GetItemTypeId(item) == IDS.CRAFT_RUNE then
            activeRunes[GetHandleId(item)] = nil
            restoreRuneManaInRadius(GetUnitX(unit), GetUnitY(unit), 1.00)
            RemoveItem(item)
        end
    end

    local deathTrigger = CreateTrigger()
    local pickupTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerRegisterPlayerUnitEvent(pickupTrigger, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
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

    TriggerAddAction(deathTrigger, function() guarded(onBuildingDeath) end)
    TriggerAddAction(pickupTrigger, function() guarded(onPickup) end)

    TitanItemSiegecastersTrophy.ids = IDS

    _G.TitanItemSiegecastersTrophy = TitanItemSiegecastersTrophy
end)

if Debug and Debug.endFile then Debug.endFile() end
