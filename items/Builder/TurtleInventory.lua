if Debug and Debug.beginFile then Debug.beginFile("items/Builder/TurtleInventory") end

OnInit("TurtleInventory", function()
    -- Legacy TurtleInventory checks the inventory ability, not the unit rawcode
    -- (the Turtle is n001), so all units with this inventory share the rule.
    local TURTLE_INVENTORY = FourCC("A014")
    local pickupTrigger = CreateTrigger()
    local dropTrigger = CreateTrigger()

    TriggerRegisterAnyUnitEventBJ(pickupTrigger, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddCondition(pickupTrigger, Condition(function()
        if GetUnitAbilityLevel(GetTriggerUnit(), TURTLE_INVENTORY) > 0 then
            SetItemPawnable(GetManipulatedItem(), false)
        end
        return false
    end))

    TriggerRegisterAnyUnitEventBJ(dropTrigger, EVENT_PLAYER_UNIT_DROP_ITEM)
    TriggerAddCondition(dropTrigger, Condition(function()
        if GetUnitAbilityLevel(GetTriggerUnit(), TURTLE_INVENTORY) > 0 then
            local item = GetManipulatedItem()
            SetItemPawnable(item, IsItemIdPawnable(GetItemTypeId(item)))
        end
        return false
    end))
end)

if Debug and Debug.endFile then Debug.endFile() end
