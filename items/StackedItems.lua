if Debug and Debug.beginFile then Debug.beginFile("items/StackedItems") end

OnInit("ItemStacking", function(import)
    local STACKABLE_ITEMS = {
        [FourCC("I001")] = true, -- Builder Healing Wards
        [FourCC("I017")] = true, -- Titan Healing Wards
        [FourCC("I007")] = true, -- Builder Eye of the Ocean
        [FourCC("I01F")] = true, -- Titan Watcher's Eye
        [FourCC("I018")] = true, -- Titan Scroll of the Beast
        [FourCC("I004")] = true, -- Builder Scroll of the Beast
        [FourCC("I01I")] = true, -- Titan Staff of Teleportation
        [FourCC("I005")] = true, -- Builder Staff of Teleportation
        [FourCC("I06C")] = true, -- Builder Wand of the Wind
        [FourCC("I01H")] = true, -- Titan Wand of the Wind
        [FourCC("I002")] = true, -- Builder Potion of Recovery
        [FourCC("I01G")] = true  -- Titan Potion of Recovery
    }

    local ItemStacking = {}

    local function charges(item)
        local amount = GetItemCharges(item)
        return amount > 0 and amount or 1
    end

    local function merge(unit, itemId)
        local matches = {}
        local total = 0
        local slot = 0
        local i = 2

        if not unit or not STACKABLE_ITEMS[itemId] then
            return false
        end

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)

            if item and GetItemTypeId(item) == itemId and GetItemType(item) == ITEM_TYPE_CHARGED then
                total = total + charges(item)
                matches[#matches + 1] = item
            end
            slot = slot + 1
        end

        if #matches > 0 then
            while i <= #matches do
                RemoveItem(matches[i])
                i = i + 1
            end
            SetItemCharges(matches[1], total)
            return true
        end
        return false
    end

    function ItemStacking.isStackable(itemId)
        return STACKABLE_ITEMS[itemId] == true
    end

    function ItemStacking.merge(unit, item)
        local itemId = type(item) == "number" and item or (item and GetItemTypeId(item) or 0)
        return merge(unit, itemId)
    end

    function ItemStacking.mergeAll(unit)
        local itemIds = {}
        local seen = {}
        local slot = 0
        local changed = false
        local i = 1

        if not unit then
            return false
        end

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            local itemId = item and GetItemTypeId(item) or 0

            if STACKABLE_ITEMS[itemId] and not seen[itemId] then
                seen[itemId] = true
                itemIds[#itemIds + 1] = itemId
            end
            slot = slot + 1
        end

        while i <= #itemIds do
            changed = merge(unit, itemIds[i]) or changed
            i = i + 1
        end

        return changed
    end

    -- Shop and item-conversion systems call merge explicitly. A generic
    -- pickup listener would also recombine stacks that a player just split.
    ItemStacking.items = STACKABLE_ITEMS

    _G.ItemStacking = ItemStacking
end)

if Debug and Debug.endFile then Debug.endFile() end
