if Debug and Debug.beginFile then Debug.beginFile("items/Titan/BlastingWand") end

OnInit("TitanItemBlastingWand", function(import)
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("TitanDamageSystem")
    import.strict("AbilityMeta")
    import.strict("UnitFilter")

    local IDS = {
        BLASTING_WAND = FourCC("I06X"),
        BLAST = FourCC("A04T")
    }

    local AOE_DAMAGE = 195.0
    local AOE = 250.0
    local KILL_COOLDOWN = 72.0
    local NORMAL_COOLDOWN = 120.0
    local LIGHTNING_CODE = "AFOD"
    local DAMAGE_EFFECT = "Abilities\\Spells\\Demon\\DemonBoltImpact\\DemonBoltImpact.mdl"

    local TitanItemBlastingWand = {}
    local suppress = false

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.BLASTING_WAND)
    end

    local function validTarget(unit, caster)
        return UnitFilter.isAlive(unit) and
            IsUnitEnemy(unit, GetOwningPlayer(caster)) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE)
    end

    local function damageFor(unit)
        if UnitFilter.isTitanHunter(unit) then
            return AOE_DAMAGE + (0.15 * GetUnitState(unit, UNIT_STATE_MAX_LIFE))
        elseif UnitFilter.isBuilder(unit) then
            return AOE_DAMAGE * 0.50
        end

        return AOE_DAMAGE
    end

    local function lightningTimed(x1, y1, x2, y2)
        local lightning = AddLightning(LIGHTNING_CODE, false, x1, y1, x2, y2)

        GameTimer.after(0.05, function()
            if lightning then
                DestroyLightning(lightning)
            end
        end)
    end

    local function setCooldown(caster, killed)
        local cooldown = killed and KILL_COOLDOWN or NORMAL_COOLDOWN

        GameTimer.after(0.0, function()
            if caster and GetUnitTypeId(caster) ~= 0 and GetUnitAbilityLevel(caster, IDS.BLAST) > 0 then
                AbilityMeta.setCooldown(caster, IDS.BLAST, cooldown)
                AbilityMeta.startCooldown(caster, IDS.BLAST, cooldown)
            end
        end)
    end

    local function cast(caster, target)
        local group = CreateGroup()
        local unit = nil
        local targetX = GetUnitX(target)
        local targetY = GetUnitY(target)
        local killed = false

        GroupEnumUnitsInRange(group, targetX, targetY, AOE, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if validTarget(unit, caster) then
                lightningTimed(targetX, targetY, GetUnitX(unit), GetUnitY(unit))
                DestroyEffect(AddSpecialEffectTarget(DAMAGE_EFFECT, unit, "origin"))

                suppress = true
                TitanDamageSystem.dealDamage(caster, unit, damageFor(unit), ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                suppress = false

                if not killed and not UnitFilter.isAlive(unit) then
                    killed = true
                end
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        setCooldown(caster, killed)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local target = GetSpellTargetUnit()

        if suppress or GetSpellAbilityId() ~= IDS.BLAST or not target or not hasItem(caster) then
            return
        end

        cast(caster, target)
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

    TitanItemBlastingWand.ids = IDS
    TitanItemBlastingWand.cast = cast
    _G.TitanItemBlastingWand = TitanItemBlastingWand
end)

if Debug and Debug.endFile then Debug.endFile() end
