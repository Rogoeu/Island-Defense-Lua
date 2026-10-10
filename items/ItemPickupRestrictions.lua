if Debug and Debug.beginFile then Debug.beginFile("items/ItemHandling") end

OnInit("ItemHandling", function(import)
    import.strict("PlayerData")
    import.strict("UnitSpawner")

    local DROP_DISTANCE = 5.0
    local TITAN_ITEM_POINT_VALUE = 200
    local TOME_OF_HEALTH = FourCC("I003")
    local TOME_OF_POWER = FourCC("I008")

    local ItemHandling = {}
    local builderToTitan = {
        [FourCC("I007")] = FourCC("I01F"), -- Eye of the Ocean -> Watcher's Eye
        [FourCC("I001")] = FourCC("I017"), -- Healing Wards
        [FourCC("I002")] = FourCC("I01G"), -- Potion of Recovery
        [FourCC("I005")] = FourCC("I01I"), -- Staff of Teleportation
        [FourCC("I004")] = FourCC("I018"), -- Scroll of the Beast
        [FourCC("I009")] = FourCC("I03Q"), -- Trident
        [FourCC("I00A")] = FourCC("I03R"), -- Armored Scales
        [FourCC("I060")] = FourCC("I000"), -- Shadowstone
        [FourCC("I06C")] = FourCC("I01H")  -- Wand of the Wind
    }
    local titanToBuilder = {
        [FourCC("I01F")] = FourCC("I007"), -- Watcher's Eye -> Eye of the Ocean
        [FourCC("I017")] = FourCC("I001"), -- Healing Wards
        [FourCC("I01G")] = FourCC("I002"), -- Potion of Recovery
        [FourCC("I01I")] = FourCC("I005"), -- Staff of Teleportation
        [FourCC("I018")] = FourCC("I004"), -- Scroll of the Beast
        [FourCC("I03Q")] = FourCC("I009"), -- Trident
        [FourCC("I03R")] = FourCC("I00A"), -- Armored Scales
        [FourCC("I000")] = FourCC("I060"), -- Shadowstone
        [FourCC("I01H")] = FourCC("I06C")  -- Wand of the Wind
    }

    local function usesTitanInventory(unit)
        return unit and GetUnitPointValue(unit) >= TITAN_ITEM_POINT_VALUE
    end

    local function isDummy(unit)
        local dummyCaster = rawget(_G, "DummyCaster")

        return unit and dummyCaster and dummyCaster.unitId and GetUnitTypeId(unit) == dummyCaster.unitId()
    end

    local function isTitanSidePlayer(player)
        local data = PlayerData.get(player)

        return data and (data:class() == PlayerData.CLASS_TITAN or data:class() == PlayerData.CLASS_MINION)
    end

    local function duplicateSpellWellTome(unit, itemTypeId, itemType)
        local well = UnitSpawner.get("TITAN_SPELL_WELL")

        if itemType == ITEM_TYPE_POWERUP and unit == well and (itemTypeId == TOME_OF_HEALTH or itemTypeId == TOME_OF_POWER) then
            CreateItem(itemTypeId, GetUnitX(unit), GetUnitY(unit))
        end
    end

    local function replaceItem(unit, item, newItemTypeId)
        local charges = GetItemCharges(item)
        local replacement = nil

        if not newItemTypeId or newItemTypeId == 0 then
            return false
        end

        RemoveItem(item)
        replacement = CreateItem(newItemTypeId, 0, 0)
        UnitAddItem(unit, replacement)
        if charges > 1 then
            SetItemCharges(replacement, charges)
        end
        return true
    end

    local function convertChargedItem(unit, item, itemTypeId, itemType)
        local newItemTypeId = 0

        if itemType ~= ITEM_TYPE_CHARGED then
            return false
        end
        if isTitanSidePlayer(GetOwningPlayer(unit)) then
            newItemTypeId = builderToTitan[itemTypeId] or 0
        else
            newItemTypeId = titanToBuilder[itemTypeId] or 0
        end
        return replaceItem(unit, item, newItemTypeId)
    end

    local function isAllowed(unit, item)
        local itemType = item and GetItemType(item) or nil
        local titanInventory = usesTitanInventory(unit)

        if isDummy(unit) then
            return true
        end
        -- Old Zinc inventory routing was unit-based, not owner-role-based:
        -- point value >= 200 is treated as Titan-side inventory.
        if titanInventory and (itemType == ITEM_TYPE_CAMPAIGN or itemType == ITEM_TYPE_PERMANENT) then
            return false
        end
        if not titanInventory and itemType == ITEM_TYPE_ARTIFACT then
            return false
        end
        return true
    end

    local function handleItem(unit, item)
        local itemTypeId = GetItemTypeId(item)
        local itemType = GetItemType(item)

        if isDummy(unit) then
            return true
        end

        duplicateSpellWellTome(unit, itemTypeId, itemType)
        if convertChargedItem(unit, item, itemTypeId, itemType) then
            return true
        end
        if itemType == ITEM_TYPE_MISCELLANEOUS then
            RemoveItem(item)
            return true
        end
        return isAllowed(unit, item)
    end

    local function returnItem(unit, item)
        local angle = GetUnitFacing(unit) * bj_DEGTORAD
        local x = GetUnitX(unit) + DROP_DISTANCE * Cos(angle)
        local y = GetUnitY(unit) + DROP_DISTANCE * Sin(angle)

        UnitRemoveItem(unit, item)
        SetItemPosition(item, x, y)
    end

    function ItemHandling.isAllowed(unit, item)
        return isAllowed(unit, item)
    end

    function ItemHandling.handle(unit, item)
        return handleItem(unit, item)
    end

    local function onPickup()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if item and not handleItem(unit, item) then
            returnItem(unit, item)
            --DisplayTimedTextToPlayer(GetOwningPlayer(unit), 0, 0, 5, "|cffff6060This unit cannot carry that item type.|r")
        end
    end

    local trigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
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

    TriggerAddAction(trigger, function() guarded(onPickup) end)

    _G.ItemHandling = ItemHandling
    _G.ItemPickupRestrictions = ItemHandling
end)

if Debug and Debug.endFile then Debug.endFile() end
