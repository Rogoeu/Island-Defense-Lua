if Debug and Debug.beginFile then Debug.beginFile("EasterEggs/Jen") end

OnInit("Jen", function(import)
    import.strict("GameTimer")
    import.strict("ShowTagFromUnit")

    -- Port of Zinc library Jen. The frog must already be placed on the map.
    local JEN_ID = FourCC("nJEN")
    local FOLLOW_ITEM = FourCC("I00Q")
    local REWARD_ITEM = FourCC("I055")
    local TARGET_X, TARGET_Y = 10432.0, 1600.0
    local EFFECT = "Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTo.mdl"
    local jen
    local originX, originY, originFacing
    local initialized = false

    local function findJen()
        local placed = rawget(_G, "gg_unit_nJEN_0152")
        if placed and GetUnitTypeId(placed) == JEN_ID then
            return placed
        end
        local group = CreateGroup()
        GroupEnumUnitsInRect(group, GetWorldBounds(), nil)
        local unit = FirstOfGroup(group)
        local found
        while unit do
            GroupRemoveUnit(group, unit)
            if GetUnitTypeId(unit) == JEN_ID then
                found = unit
                break
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return found
    end

    local function hasFollowItem(unit)
        for slot = 0, bj_MAX_INVENTORY - 1 do
            local item = UnitItemInSlot(unit, slot)
            if item and GetItemTypeId(item) == FOLLOW_ITEM then
                return true
            end
        end
        return false
    end

    local timer
    timer = GameTimer.every(2.0, function()
        if not initialized then
            initialized = true
            jen = findJen()
            if jen then
                originX, originY, originFacing = GetUnitX(jen), GetUnitY(jen), GetUnitFacing(jen)
            end
        end
        if not jen or GetUnitTypeId(jen) == 0 then
            timer:destroy()
            return
        end
        if GetWidgetLife(jen) <= 0.405 or IsUnitType(jen, UNIT_TYPE_DEAD) then
            return
        end

        local x, y = GetUnitX(jen), GetUnitY(jen)
        local group = CreateGroup()
        GroupEnumUnitsInRange(group, x, y, 500.0, nil)
        local unit = FirstOfGroup(group)
        local carrier
        while unit do
            GroupRemoveUnit(group, unit)
            if hasFollowItem(unit) then
                carrier = unit
                break
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        if not carrier then return end
        if IsUnitInRangeXY(jen, TARGET_X, TARGET_Y, 300.0) then
            ShowTagFromUnit.fromUnitForAll("|cffffffffThat's enough adventuring for today!|r", jen)
            local effect = AddSpecialEffect(EFFECT, x, y)
            GameTimer.after(1.0, function() DestroyEffect(effect) end)
            SetUnitX(jen, originX)
            SetUnitY(jen, originY)
            SetUnitFacing(jen, originFacing)
            SetUnitPathing(jen, true)
            CreateItem(REWARD_ITEM, x, y)
        else
            IssuePointOrder(jen, "smart", GetUnitX(carrier), GetUnitY(carrier))
            SetUnitPathing(jen, false)
        end
    end)
end)

if Debug and Debug.endFile then Debug.endFile() end
