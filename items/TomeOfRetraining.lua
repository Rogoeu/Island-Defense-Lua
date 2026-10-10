if Debug and Debug.beginFile then Debug.beginFile("items/TomeOfRetraining") end

OnInit("TomeOfRetraining", function()
    local ITEM_ID = FourCC("I05S")

    local removeAbilities = {
        {
            -- Frost Explosion is added separately when A0PL is learned.
            -- Match the ability so custom Glacious skins are covered too.
            abilityId = FourCC("TGAQ")
        },
        {
            abilityId = FourCC("TVA0"),
            unitTypeId = FourCC("E00K")
        }
    }
    local callbacks = {}
    local TomeOfRetraining = {}

    function TomeOfRetraining.itemId()
        return ITEM_ID
    end

    function TomeOfRetraining.registerRemoveAbility(abilityId, filter)
        removeAbilities[#removeAbilities + 1] = {
            abilityId = abilityId,
            filter = filter
        }
    end

    function TomeOfRetraining.register(callback)
        callbacks[#callbacks + 1] = callback
    end

    local function onUse()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()
        local i = 1

        if not unit or not item or GetItemTypeId(item) ~= ITEM_ID then
            return
        end

        while i <= #removeAbilities do
            local entry = removeAbilities[i]
            if (not entry.unitTypeId or GetUnitTypeId(unit) == entry.unitTypeId) and
                (not entry.filter or entry.filter(unit, item)) and
                GetUnitAbilityLevel(unit, entry.abilityId) > 0 then
                UnitRemoveAbility(unit, entry.abilityId)
            end
            i = i + 1
        end

        i = 1
        while i <= #callbacks do
            callbacks[i](unit, item)
            i = i + 1
        end
    end

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_USE_ITEM, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onUse)
        else
            onUse()
        end
    end)

    _G.TomeOfRetraining = TomeOfRetraining
end)

if Debug and Debug.endFile then Debug.endFile() end
