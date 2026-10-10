if Debug and Debug.beginFile then Debug.beginFile("Abilities/Global/FakeTeleport") end

OnInit("TitanFakeTeleport", function(import)
    import.strict("AbilityMeta")
    import.strict("GameTimer")
    import.strict("UnitFilter")

    local IDS = {
        FAKE_TELEPORT = FourCC("A0UO")
    }

    local EFFECT = "Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTo.mdl"
    local EFFECT_DURATION = 3.5
    local COOLDOWN = 60.0

    local TitanFakeTeleport = {}

    local function cast(caster, target)
        local effect = nil

        if not caster or not target or GetUnitTypeId(target) == 0 then
            return false
        end

        effect = AddSpecialEffect(EFFECT, GetUnitX(target), GetUnitY(target))
        GameTimer.after(EFFECT_DURATION + 0.5, function()
            if effect then
                DestroyEffect(effect)
            end
        end)
        AbilityMeta.startCooldown(caster, IDS.FAKE_TELEPORT, COOLDOWN)
        return true
    end

    function TitanFakeTeleport.cast(caster, target)
        return cast(caster, target)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()

        if GetSpellAbilityId() == IDS.FAKE_TELEPORT and UnitFilter.isTitanUnit(caster) then
            cast(caster, GetSpellTargetUnit())
        end
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

    TitanFakeTeleport.ids = IDS

    _G.TitanFakeTeleport = TitanFakeTeleport
end)

if Debug and Debug.endFile then Debug.endFile() end
