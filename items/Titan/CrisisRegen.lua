if Debug and Debug.beginFile then Debug.beginFile("items/Titan/CrisisRegen") end

OnInit("TitanItemCrisisRegen", function(import)
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("UnitStateSystem")

    local IDS = {
        ARMOR_OF_TIDES = FourCC("I08V"),
        SUPER_REG_SPINES = FourCC("I080"),
        MISTLORDS_CAPE = FourCC("I092"),
        CRISIS_REGEN = FourCC("A0UW")
    }

    local LIFE_THRESHOLD = 0.50
    local TICK = 0.50

    local TitanItemCrisisRegen = {}
    local timers = {}

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function hasRegenItem(unit)
        return hasItem(unit, IDS.ARMOR_OF_TIDES) or
            hasItem(unit, IDS.SUPER_REG_SPINES) or
            hasItem(unit, IDS.MISTLORDS_CAPE)
    end

    local function removeRegen(unit)
        if unit and GetUnitTypeId(unit) ~= 0 then
            UnitRemoveAbility(unit, IDS.CRISIS_REGEN)
        end
    end

    local function stop(unit)
        local id = GetHandleId(unit)
        local timer = timers[id]

        removeRegen(unit)
        if timer then
            timer:destroy()
            timers[id] = nil
        end
    end

    local function check(unit)
        if not UnitStateSystem.isAlive(unit) or not hasRegenItem(unit) then
            stop(unit)
            return
        end

        if UnitStateSystem.life(unit) / UnitStateSystem.maxLife(unit) <= LIFE_THRESHOLD then
            if GetUnitAbilityLevel(unit, IDS.CRISIS_REGEN) <= 0 then
                UnitAddAbility(unit, IDS.CRISIS_REGEN)
            end
        else
            removeRegen(unit)
        end
    end

    local function start(unit)
        local id = GetHandleId(unit)

        if timers[id] then
            return
        end

        timers[id] = GameTimer.every(TICK, function()
            check(unit)
        end)
        check(unit)
    end

    local function itemIsRegen(itemId)
        return itemId == IDS.ARMOR_OF_TIDES or
            itemId == IDS.SUPER_REG_SPINES or
            itemId == IDS.MISTLORDS_CAPE
    end

    local function onPickup()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if item and itemIsRegen(GetItemTypeId(item)) then
            start(unit)
        end
    end

    local function onDrop()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if item and itemIsRegen(GetItemTypeId(item)) and not hasRegenItem(unit) then
            stop(unit)
        end
    end

    local pickupTrigger = CreateTrigger()
    local dropTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(pickupTrigger, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
        TriggerRegisterPlayerUnitEvent(dropTrigger, Player(i), EVENT_PLAYER_UNIT_DROP_ITEM, nil)
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

    TriggerAddAction(pickupTrigger, function() guarded(onPickup) end)
    TriggerAddAction(dropTrigger, function() guarded(onDrop) end)

    TitanItemCrisisRegen.ids = IDS
    TitanItemCrisisRegen.start = start
    TitanItemCrisisRegen.stop = stop
    _G.TitanItemCrisisRegen = TitanItemCrisisRegen
end)

if Debug and Debug.endFile then Debug.endFile() end
