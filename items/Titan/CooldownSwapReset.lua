if Debug and Debug.beginFile then Debug.beginFile("items/Titan/CooldownSwapReset") end

OnInit("TitanItemCooldownSwapReset", function(import)
    import.strict("GameTimer")

    local PASSABLE_ITEMS = {
        [FourCC("I052")] = true, -- Enchanted Druid Leaf
        [FourCC("I01T")] = true -- Mystic Staff of Gods
    }

    local swappingUnits = {}

    local function resetItemCooldown(unit, item)
        local itemId = GetItemTypeId(item)
        local unitId = GetHandleId(unit)

        if not PASSABLE_ITEMS[itemId] or swappingUnits[unitId] then
            return
        end

        -- A newly created copy has a fresh item cooldown. The unit's own ability
        -- cooldown is intentionally untouched, so each group member can use it once.
        swappingUnits[unitId] = true
        RemoveItem(item)
        UnitAddItemById(unit, itemId)
        GameTimer.after(0.1, function()
            swappingUnits[unitId] = nil
        end)
    end

    local function onPickup()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if unit and item then
            resetItemCooldown(unit, item)
        end
    end

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onPickup)
        else
            onPickup()
        end
    end)
end)

if Debug and Debug.endFile then Debug.endFile() end
