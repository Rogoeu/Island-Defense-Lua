if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/FaerieStructureAbilities") end

OnInit("FaerieStructureAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("DummyCaster")

    local IDS = {
        MANA_FLARE = FourCC("A0QN"),
        MANA_FLARE_DUMMY_UNIT = FourCC("o03J"),
        MANA_FLARE_TIMED_LIFE = FourCC("B061"),
        ENERGY_TOWER_NORMAL = FourCC("A0T8"),
        ENERGY_TOWER_ENHANCED = FourCC("A0A2"),
        ENERGY_TOWER_SUPER = FourCC("A0AI"),
        ENERGY_TOWER_MEGA = FourCC("A0AJ"),
        MAGIC_MUSHROOM_DRAIN = FourCC("A0ND"),
        MAGIC_MUSHROOM_ACTIVE = FourCC("A002"),
        ANTI_MAGIC_TOWER_PASSIVE = FourCC("A0QL"),
        ANTI_MAGIC_SILENCE = FourCC("A0QM")
    }

    local MANA_FLARE_ORDER = 852512
    local MAGIC_MUSHROOM_BLAST_ORDER = 852179
    local SILENCE_ORDER = 852668
    local MANA_FLARE_DURATION = 8.0
    local suppressDamage = false

    local function maxMana(unit)
        if BlzGetUnitMaxMana then
            return BlzGetUnitMaxMana(unit)
        end
        return GetUnitState(unit, UNIT_STATE_MAX_MANA)
    end

    local function addMana(unit, amount)
        local mana = GetUnitState(unit, UNIT_STATE_MANA) + amount
        local cap = maxMana(unit)

        if mana < 0.0 then
            mana = 0.0
        elseif mana > cap then
            mana = cap
        end

        SetUnitState(unit, UNIT_STATE_MANA, mana)
    end

    local function energyDrain(attacker)
        if GetUnitAbilityLevel(attacker, IDS.ENERGY_TOWER_NORMAL) > 0 then
            return 2.0
        elseif GetUnitAbilityLevel(attacker, IDS.ENERGY_TOWER_ENHANCED) > 0 then
            return 3.0
        elseif GetUnitAbilityLevel(attacker, IDS.ENERGY_TOWER_SUPER) > 0 then
            return 4.0
        elseif GetUnitAbilityLevel(attacker, IDS.ENERGY_TOWER_MEGA) > 0 then
            return 6.0
        end
        return 0.0
    end

    local function damageMagic(attacker, target, amount)
        suppressDamage = true
        UnitDamageTarget(attacker, target, amount, true, true, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
        suppressDamage = false
    end

    local function castSilence(attacker, target)
        DummyCaster.castTarget(
            GetOwningPlayer(attacker),
            IDS.ANTI_MAGIC_SILENCE,
            1,
            SILENCE_ORDER,
            target,
            GetUnitX(attacker),
            GetUnitY(attacker),
            GetUnitFacing(attacker)
        )
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local dummy = nil

        if GetSpellAbilityId() ~= IDS.MANA_FLARE then
            return
        end

        dummy = CreateUnit(GetOwningPlayer(caster), IDS.MANA_FLARE_DUMMY_UNIT, GetSpellTargetX(), GetSpellTargetY(), 0)
        IssueImmediateOrderById(dummy, MANA_FLARE_ORDER)
        UnitApplyTimedLife(dummy, IDS.MANA_FLARE_TIMED_LIFE, MANA_FLARE_DURATION)
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local drain = 0.0
        local currentMana = 0.0

        if suppressDamage or not target or not attacker then
            return
        end
        if IsUnitType(target, UNIT_TYPE_MAGIC_IMMUNE) then
            return
        end

        drain = energyDrain(attacker)
        if drain > 0.0 then
            addMana(target, -drain)
            damageMagic(attacker, target, drain * 5.0)
            return
        end

        if GetUnitAbilityLevel(attacker, IDS.MAGIC_MUSHROOM_DRAIN) > 0 and IsUnitEnemy(attacker, GetOwningPlayer(target)) then
            drain = 25.0
            addMana(target, -drain)
            if GetUnitState(target, UNIT_STATE_MANA) < drain then
                damageMagic(attacker, target, drain * 2.0)
            end
            if GetRandomInt(0, 100) <= 10 then
                IssueTargetOrderById(attacker, MAGIC_MUSHROOM_BLAST_ORDER, target)
            end
            return
        end

        if GetUnitAbilityLevel(attacker, IDS.ANTI_MAGIC_TOWER_PASSIVE) > 0 and IsUnitEnemy(attacker, GetOwningPlayer(target)) then
            drain = 10.0
            currentMana = GetUnitState(target, UNIT_STATE_MANA)

            if currentMana < drain then
                drain = currentMana
                castSilence(attacker, target)
            elseif GetRandomInt(0, 100) <= 3 then
                castSilence(attacker, target)
            end

            addMana(target, -drain)
            damageMagic(attacker, target, drain * 2.0)
        end
    end

    local spellTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        i = i + 1
    end

    TriggerAddAction(spellTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    TriggerAddAction(damageTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    AbilityRegistry.registerRace("Faerie", "structures", {
        notes = "Faerie tower/building abilities ported from FaerieManaFlare and FaerieManaDepletion.",
        abilities = {
            {
                name = "Mana Flare",
                id = IDS.MANA_FLARE,
                source = "library FaerieManaFlare",
                behavior = "Creates the old Mana Flare dummy unit at the spell target point for 8 seconds."
            },
            {
                name = "Energy Tower Mana Depletion",
                id = IDS.ENERGY_TOWER_NORMAL,
                source = "library FaerieManaDepletion",
                behavior = "Energy towers drain 2/3/4/6 mana and deal five times that value as magic damage."
            },
            {
                name = "Magic Mushroom Drain",
                id = IDS.MAGIC_MUSHROOM_DRAIN,
                source = "library FaerieManaDepletion",
                behavior = "Drains 25 mana, deals extra damage when target is low on mana and has a 10 percent blast chance."
            },
            {
                name = "Anti-Magic Tower",
                id = IDS.ANTI_MAGIC_TOWER_PASSIVE,
                source = "library FaerieManaDepletion",
                behavior = "Drains mana, deals magic damage and silences when the target runs out of mana or on a 3 percent chance."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
