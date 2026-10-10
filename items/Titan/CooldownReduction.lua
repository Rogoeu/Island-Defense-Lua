if Debug and Debug.beginFile then Debug.beginFile("items/Titan/CooldownReduction") end

OnInit("TitanItemCooldownReduction", function(import)
    import.strict("AbilityMeta")
    import.strict("GameTimer")
    import.strict("ItemExtras")

    local IDS = {
        CASTER_SCROLL = FourCC("I081"),
        HIGHSEER_SLIPPERS = FourCC("I08Y")
    }

    local CASTER_SCROLL_REFUND = 0.10
    local HIGHSEER_REFUND = 0.20

    local TitanItemCooldownReduction = {}

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function isItemAbility(unit, abilityId)
        local ability = unit and BlzGetUnitAbility(unit, abilityId) or nil

        if ability and BlzGetAbilityBooleanField then
            return BlzGetAbilityBooleanField(ability, ABILITY_BF_ITEM_ABILITY)
        end

        return false
    end

    local function refundFor(unit)
        if hasItem(unit, IDS.HIGHSEER_SLIPPERS) then
            return HIGHSEER_REFUND
        elseif hasItem(unit, IDS.CASTER_SCROLL) then
            return CASTER_SCROLL_REFUND
        end

        return 0.0
    end

    local function refundCooldown(caster, abilityId)
        local refund = refundFor(caster)

        if refund <= 0.0 or isItemAbility(caster, abilityId) then
            return false
        end

        GameTimer.after(0.0, function()
            if caster and GetUnitTypeId(caster) ~= 0 and GetUnitAbilityLevel(caster, abilityId) > 0 then
                AbilityMeta.refundCooldownPercent(caster, abilityId, refund)
            end
        end)

        return true
    end

    local function onSpellEffect()
        refundCooldown(GetTriggerUnit(), GetSpellAbilityId())
    end

    local trigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
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

    TriggerAddAction(trigger, function() guarded(onSpellEffect) end)

    TitanItemCooldownReduction.ids = IDS
    TitanItemCooldownReduction.refundCooldown = refundCooldown
    _G.TitanItemCooldownReduction = TitanItemCooldownReduction
end)

if Debug and Debug.endFile then Debug.endFile() end
