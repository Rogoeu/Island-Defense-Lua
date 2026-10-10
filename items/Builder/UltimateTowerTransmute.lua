if Debug and Debug.beginFile then Debug.beginFile("items/Builder/UltimateTowerTransmute") end

OnInit("BuilderItemUltimateTowerTransmute", function(import)
    import.strict("BuilderShop")

    local TRANSMUTE_ABILITY = FourCC("A00D")
    local ULTIMATE_STRUCTURE = FourCC("o00Z")

    local UNIT_TO_ITEM = {
        [FourCC("o01P")] = FourCC("I02V"), -- Wave Tower
        [FourCC("o03S")] = FourCC("I07R"), -- Demonic Altar
        [FourCC("o005")] = FourCC("I00J"), -- Sacred Seashell
        [FourCC("h00P")] = FourCC("I00Y"), -- Heavy Cannon
        [FourCC("o01Y")] = FourCC("I03A"), -- Methane Machine
        [FourCC("o003")] = FourCC("I00K"), -- Sludge Launcher
        [FourCC("o006")] = FourCC("I00N"), -- Tropical Glyph
        [FourCC("o00J")] = FourCC("I00T"), -- Giant Hermit
        [FourCC("o00K")] = FourCC("I00U"), -- Crab Mutant
        [FourCC("o00L")] = FourCC("I00V"), -- Catapult
        [FourCC("o00N")] = FourCC("I011"), -- Whirlpool
        [FourCC("o00M")] = FourCC("I00W"), -- Stasis Totem
        [FourCC("o007")] = FourCC("I00O"), -- Magic Pearl
        [FourCC("o00O")] = FourCC("I00Z"), -- Magic Tower / Anti-Magic Tower
        [FourCC("o00P")] = FourCC("I010"), -- Bombard
        [FourCC("o00Q")] = FourCC("I00X"), -- Magic Mushroom
        [FourCC("o00R")] = FourCC("I013"), -- Aura Tree
        [FourCC("o00S")] = FourCC("I014"), -- Spell Well
        [FourCC("o00T")] = FourCC("I015"), -- Spiny Protector
        [FourCC("n01K")] = FourCC("I01A"), -- Rapid Fire Tower
        [FourCC("n01J")] = FourCC("I01B"), -- Deepfreeze
        [FourCC("n01L")] = FourCC("I01C"), -- Energy Spire
        [FourCC("o015")] = FourCC("I01K"), -- Mutation Tower
        [FourCC("o016")] = FourCC("I01L"), -- Toxic Tower
        [FourCC("o01U")] = FourCC("I02Y"), -- Demolisher Totem
        [FourCC("e00Y")] = FourCC("I037"), -- Crown of Thieves
        [FourCC("o01V")] = FourCC("I04T"), -- Replicator
        [FourCC("o02H")] = FourCC("I05A"), -- Box of Gaia
        [FourCC("o02G")] = FourCC("I058"), -- Box of Pyros
        [FourCC("o02I")] = FourCC("I059"), -- Box of Storms
        [FourCC("o02A")] = FourCC("I057"), -- High Energy Conduit
        [FourCC("o02R")] = FourCC("I04O"), -- Ice Palace
        [FourCC("o02Z")] = FourCC("I05T"), -- Egg Sack
        [FourCC("o02Q")] = FourCC("I04J"), -- Fireworks Launcher
        [FourCC("o02P")] = FourCC("I04L"), -- Tavern
        [FourCC("o02E")] = FourCC("I056"), -- Well of Power
        [FourCC("o031")] = FourCC("I061"), -- Spiritual Rift
        [FourCC("o03C")] = FourCC("I06D"), -- Island Bloom
        [FourCC("o017")] = FourCC("I01M"), -- Light Energy Tower
        [FourCC("o03N")] = FourCC("I08C"), -- Super Keg of Destruction
        [FourCC("o040")] = FourCC("I04P"), -- Tribal Totem
        [FourCC("e00X")] = FourCC("I06I"), -- Elephant Foot
        [FourCC("o04G")] = FourCC("I06W"), -- Stampede Tower
        [ULTIMATE_STRUCTURE] = FourCC("I04E") -- Ultimate Structure
    }

    local ITEM_TO_REBUILD = {
        [FourCC("I04L")] = FourCC("I04M"), -- Tavern -> rebuild
        [FourCC("I04J")] = FourCC("I04K"), -- Fireworks Launcher -> rebuild
        [FourCC("I01K")] = FourCC("I04U"), -- Mutation Tower -> rebuild
        [FourCC("I05T")] = FourCC("I05U"), -- Egg Sack -> rebuild
        [FourCC("I014")] = FourCC("I03K"), -- Spell Well -> rebuild
        [FourCC("I08D")] = FourCC("I08C"), -- Super Keg rebuild -> item
        [FourCC("I00O")] = FourCC("I05B"), -- Magic Pearl -> rebuild

        [FourCC("I04M")] = FourCC("I04L"), -- Tavern rebuild -> item
        [FourCC("I04K")] = FourCC("I04J"), -- Fireworks rebuild -> item
        [FourCC("I04U")] = FourCC("I01K"), -- Mutation rebuild -> item
        [FourCC("I05U")] = FourCC("I05T"), -- Egg Sack rebuild -> item
        [FourCC("I03K")] = FourCC("I014"), -- Spell Well rebuild -> item
        [FourCC("I08C")] = FourCC("I08D"), -- Super Keg item -> rebuild
        [FourCC("I05B")] = FourCC("I00O") -- Magic Pearl rebuild -> item
    }

    local BuilderItemUltimateTowerTransmute = {}

    local function unitItemId(unitTypeId)
        return UNIT_TO_ITEM[unitTypeId] or 0
    end

    local function rebuildItemId(item)
        return item and (ITEM_TO_REBUILD[GetItemTypeId(item)] or 0) or 0
    end

    local function createItem(itemId, x, y)
        if itemId and itemId ~= 0 then
            return CreateItem(itemId, x, y)
        end
        return nil
    end

    local function transmuteUnit(unit)
        local itemId = unitItemId(GetUnitTypeId(unit))
        local x = GetUnitX(unit)
        local y = GetUnitY(unit)

        if itemId == 0 then
            return false
        end

        RemoveUnit(unit)
        createItem(itemId, x, y)
        return true
    end

    local function onSpellFinish()
        local unit = GetTriggerUnit()

        if GetSpellAbilityId() == TRANSMUTE_ABILITY and unit then
            transmuteUnit(unit)
        end
    end

    local function onConstructCancel()
        local unit = GetCancelledStructure()
        local unitTypeId = unit and GetUnitTypeId(unit) or 0
        local itemId = unitItemId(unitTypeId)

        if itemId ~= 0 and unitTypeId ~= ULTIMATE_STRUCTURE then
            createItem(itemId, GetUnitX(unit), GetUnitY(unit))
        end
    end

    local function onUpgradeStart()
        local unit = GetTriggerUnit()

        if unit and unitItemId(GetUnitTypeId(unit)) ~= 0 then
            UnitSetUpgradeProgress(unit, 80)
        end
    end

    local function splitChargedItem(unit, item)
        local charges = GetItemCharges(item)
        local newCharges = 0
        local newItem = nil

        if charges <= 1 then
            return false
        end

        newCharges = charges - R2I(charges / 2)
        charges = charges - newCharges
        SetItemCharges(item, charges)
        newItem = CreateItem(GetItemTypeId(item), GetUnitX(unit), GetUnitY(unit))
        DisableTrigger(BuilderShop.pickupTrigger)
        UnitAddItem(unit, newItem)
        EnableTrigger(BuilderShop.pickupTrigger)
        SetItemCharges(newItem, newCharges)
        return true
    end

    local function mergeChargedItems(item, slotItem)
        if GetItemType(item) == ITEM_TYPE_CHARGED and
            item ~= slotItem and
            GetItemTypeId(item) == GetItemTypeId(slotItem) then
            SetItemCharges(item, GetItemCharges(item) + GetItemCharges(slotItem))
            RemoveItem(slotItem)
            return true
        end

        return false
    end

    local function onTargetOrder()
        local orderId = GetIssuedOrderId()
        local slot = orderId - 852002
        local unit = GetOrderedUnit()
        local item = GetOrderTargetItem()
        local slotItem = nil
        local rebuildId = rebuildItemId(item)

        if orderId <= 852001 or orderId >= 852008 or not unit or not item then
            return
        end

        slotItem = UnitItemInSlot(unit, slot)
        if item == slotItem and rebuildId ~= 0 then
            RemoveItem(item)
            UnitAddItemToSlotById(unit, rebuildId, slot)
        elseif item == slotItem and GetItemType(item) == ITEM_TYPE_CHARGED then
            splitChargedItem(unit, item)
        elseif slotItem then
            mergeChargedItems(item, slotItem)
        end
    end

    function BuilderItemUltimateTowerTransmute.itemForUnit(unitTypeId)
        return unitItemId(unitTypeId)
    end

    function BuilderItemUltimateTowerTransmute.rebuildForItem(itemId)
        return ITEM_TO_REBUILD[itemId] or 0
    end

    function BuilderItemUltimateTowerTransmute.rebuildFor(value)
        if type(value) == "number" then
            return ITEM_TO_REBUILD[value] or 0
        end
        return rebuildItemId(value)
    end

    function BuilderItemUltimateTowerTransmute.transmuteUnit(unit)
        return transmuteUnit(unit)
    end

    local spellTrigger = CreateTrigger()
    local cancelTrigger = CreateTrigger()
    local upgradeTrigger = CreateTrigger()
    local orderTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(cancelTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_CANCEL, nil)
        TriggerRegisterPlayerUnitEvent(upgradeTrigger, Player(i), EVENT_PLAYER_UNIT_UPGRADE_START, nil)
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
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

    TriggerAddAction(spellTrigger, function() guarded(onSpellFinish) end)
    TriggerAddAction(cancelTrigger, function() guarded(onConstructCancel) end)
    TriggerAddAction(upgradeTrigger, function() guarded(onUpgradeStart) end)
    TriggerAddAction(orderTrigger, function() guarded(onTargetOrder) end)

    BuilderItemUltimateTowerTransmute.unitToItem = UNIT_TO_ITEM
    BuilderItemUltimateTowerTransmute.itemToRebuild = ITEM_TO_REBUILD

    _G.BuilderItemUltimateTowerTransmute = BuilderItemUltimateTowerTransmute
    _G.GetUltimateTowerItemId = BuilderItemUltimateTowerTransmute.itemForUnit
    _G.GetTransmutedItemId = BuilderItemUltimateTowerTransmute.rebuildFor
end)

if Debug and Debug.endFile then Debug.endFile() end
