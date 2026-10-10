if Debug and Debug.beginFile then Debug.beginFile("Systems/TitanHunterResist") end

OnInit("TitanHunterResist", function(import)
    import.strict("UnitFilter")

    local IDS = {
        DRAENEI_HUNTER_RESIST = FourCC("R044"),
        DRYAD_HUNTER_RESIST = FourCC("R054"),
        DEMONOLOGIST = FourCC("u00I"),
        DEMONOLOGIST_RESIST = FourCC("R02F")
    }

    local HUNTER_MAGIC_REDUCTION = 0.30
    local DEMONOLOGIST_MAGIC_REDUCTION = 0.25

    local TitanHunterResist = {}

    local function hasResearch(player, researchId)
        return GetPlayerTechCount(player, researchId, true) > 0
    end

    local function reductionFor(unit)
        local owner = GetOwningPlayer(unit)

        if UnitFilter.isTitanHunter(unit) then
            if hasResearch(owner, IDS.DRAENEI_HUNTER_RESIST) or hasResearch(owner, IDS.DRYAD_HUNTER_RESIST) then
                return HUNTER_MAGIC_REDUCTION
            end
        elseif GetUnitTypeId(unit) == IDS.DEMONOLOGIST and hasResearch(owner, IDS.DEMONOLOGIST_RESIST) then
            return DEMONOLOGIST_MAGIC_REDUCTION
        end

        return 0.0
    end

    function TitanHunterResist.apply(unit, damage)
        local reduction = reductionFor(unit)

        if reduction > 0.0 then
            return damage * (1.0 - reduction)
        end
        return damage
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local damage = GetEventDamage()
        local damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL

        if not target or damage <= 0.0 or damageType ~= DAMAGE_TYPE_MAGIC or not BlzSetEventDamage then
            return
        end

        BlzSetEventDamage(TitanHunterResist.apply(target, damage))
    end

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    _G.TitanHunterResist = TitanHunterResist
end)

if Debug and Debug.endFile then Debug.endFile() end
