if Debug and Debug.beginFile then Debug.beginFile("items/ItemExtras") end

OnInit("ItemExtras", function(import)
    import.strict("UnitStateSystem")

    local ItemExtras = {}
    local ITEM_GOLD_COST_FIELD = rawget(_G, "ITEM_IF_GOLD_COST") or ConvertItemIntegerField(FourCC("igol"))
    local ITEM_LUMBER_COST_FIELD = rawget(_G, "ITEM_IF_LUMBER_COST") or ConvertItemIntegerField(FourCC("ilum"))

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    function ItemExtras.unitHasItemById(unit, itemId)
        local slot = 0

        if not unit or not itemId or itemId == 0 then
            return false
        end

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item and GetItemTypeId(item) == itemId then
                return true
            end
            slot = slot + 1
        end

        return false
    end

    function ItemExtras.itemFromUnitById(unit, itemId)
        local slot = 0

        if not unit or not itemId or itemId == 0 then
            return nil
        end

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item and GetItemTypeId(item) == itemId then
                return item
            end
            slot = slot + 1
        end

        return nil
    end

    function ItemExtras.slotById(unit, itemId)
        local slot = 0

        if not unit or not itemId or itemId == 0 then
            return -1
        end

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item and GetItemTypeId(item) == itemId then
                return slot
            end
            slot = slot + 1
        end

        return -1
    end

    function ItemExtras.hasFreeSlot(unit)
        local slot = 0

        if not unit then
            return false
        end

        while slot < 6 do
            if not UnitItemInSlot(unit, slot) then
                return true
            end
            slot = slot + 1
        end

        return false
    end

    function ItemExtras.itemGrade(itemId)
        local item = nil
        local grade = 0

        if not itemId or itemId == 0 then
            return 0
        end

        item = CreateItem(itemId, 0.0, 0.0)
        if item then
            if BlzGetItemIntegerField then
                grade = BlzGetItemIntegerField(item, ITEM_IF_PRIORITY)
            end
            RemoveItem(item)
        end

        return grade
    end

    function ItemExtras.itemCost(itemId)
        local item = nil
        local cost = 0

        if not itemId or itemId == 0 then
            return 0
        end

        item = CreateItem(itemId, 0.0, 0.0)
        if item then
            cost = GetItemLevel(item)
            RemoveItem(item)
        end

        return cost
    end

    function ItemExtras.itemGoldCost(itemId)
        local item = nil
        local cost = 0

        if not itemId or itemId == 0 then
            return 0
        end

        item = CreateItem(itemId, 0.0, 0.0)
        if item then
            if BlzGetItemIntegerField then
                cost = BlzGetItemIntegerField(item, ITEM_GOLD_COST_FIELD)
            else
                cost = GetItemLevel(item)
            end
            RemoveItem(item)
        end

        return cost
    end

    function ItemExtras.itemLumberCost(itemId)
        local item = nil
        local cost = 0

        if not itemId or itemId == 0 then
            return 0
        end

        item = CreateItem(itemId, 0.0, 0.0)
        if item then
            if BlzGetItemIntegerField then
                cost = BlzGetItemIntegerField(item, ITEM_LUMBER_COST_FIELD)
            end
            RemoveItem(item)
        end

        return cost
    end

    function ItemExtras.addMana(unit, amount)
        return UnitStateSystem.addMana(unit, amount)
    end

    function ItemExtras.addHealth(unit, amount)
        return UnitStateSystem.addLife(unit, amount)
    end

    function ItemExtras.getMana(unit)
        return UnitStateSystem.mana(unit)
    end

    function ItemExtras.isAlive(unit)
        return isAlive(unit)
    end

    _G.ItemExtras = ItemExtras
    _G.UnitHasItemById = ItemExtras.unitHasItemById
    _G.GetItemFromUnitById = ItemExtras.itemFromUnitById
    _G.GetSlotById = ItemExtras.slotById
    _G.HasFreeSlot = ItemExtras.hasFreeSlot
    _G.GetItemGoldCost = ItemExtras.itemGoldCost
    _G.GetItemLumberCost = ItemExtras.itemLumberCost
    _G.getMana = ItemExtras.getMana
    _G.addMana = ItemExtras.addMana
    _G.addHealth = ItemExtras.addHealth
end)

if Debug and Debug.endFile then Debug.endFile() end
