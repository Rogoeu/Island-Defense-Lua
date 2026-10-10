if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/FaerieBuilderAbilities") end

OnInit("FaerieBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("RacePickSystem")
    import.strict("DummyCaster")
    import.strict("AbilityMeta")

    local IDS = {
        ENCHANTED_LEDGER = FourCC("A0A4"),
        PHASE_SHIFT = FourCC("A05K"),
        PHASE_SHIFT_BUFF = FourCC("Bpsh"),
        INVULNERABLE = FourCC("INVU"),

        INNER_FIRE = FourCC("A0UQ"),
        INNER_FIRE_DUMMY = FourCC("A0A0"),
        FAERIE_FIRE = FourCC("A0A6"),
        SILENCE = FourCC("A09Z"),
        ENERGY_CHARGE = FourCC("A05M"),
        ENERGY_CHARGE_BUFF = FourCC("Blsh"),
        CRIPPLE = FourCC("A079"),
        DEATH_SHIELD = FourCC("A07C"),
        ENCHANTED_FAERIE_ATTACK = FourCC("A0AA"),
        MANA_FLARE = FourCC("A0QN"),
        WARD_CLASSIFICATION = FourCC("WARD")
    }

    local INNER_FIRE_AOE = 500.0
    local INNER_FIRE_COOLDOWN = 120.0
    local INNER_FIRE_ORDER = "innerfire"

    local PHASE_SHIFT_PERIOD = 0.25
    local phaseShiftTimers = {}
    local energyChargeTimers = {}

    local PERMANENT_ABILITIES = {
        IDS.ENCHANTED_LEDGER,
        IDS.PHASE_SHIFT,
        IDS.INNER_FIRE,
        IDS.FAERIE_FIRE,
        IDS.SILENCE,
        IDS.ENERGY_CHARGE,
        IDS.CRIPPLE,
        IDS.DEATH_SHIELD,
        IDS.ENCHANTED_FAERIE_ATTACK,
        IDS.MANA_FLARE
    }

    local function isFaerie(playerData)
        local race = playerData and playerData:race() or nil
        return race and race ~= NullRace.instance() and race:toString() == "Faerie"
    end

    local function onBuilderSpawn(playerData, unit)
        if not unit or not isFaerie(playerData) then
            return
        end

        local i = 1
        while i <= #PERMANENT_ABILITIES do
            UnitMakeAbilityPermanent(unit, true, PERMANENT_ABILITIES[i])
            i = i + 1
        end
    end

    local function validInnerFireTarget(caster, target)
        return target and
            target ~= caster and
            GetWidgetLife(target) > 0.405 and
            not IsUnitType(target, UNIT_TYPE_DEAD) and
            IsUnitType(target, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(target, UNIT_TYPE_MAGIC_IMMUNE)
    end

    local function startCooldown(unit, abilityId, seconds)
        if rawget(_G, "AbilityMeta") and AbilityMeta.startCooldown then
            AbilityMeta.startCooldown(unit, abilityId, seconds)
        elseif BlzStartUnitAbilityCooldown then
            BlzStartUnitAbilityCooldown(unit, abilityId, seconds)
        end
    end

    local function castMassInnerFire(caster, x, y)
        local group = CreateGroup()
        local target = nil
        local owner = GetOwningPlayer(caster)
        local level = GetUnitAbilityLevel(caster, IDS.INNER_FIRE)

        if level <= 0 then
            level = 1
        end

        GroupEnumUnitsInRange(group, x, y, INNER_FIRE_AOE, nil)
        target = FirstOfGroup(group)
        while target do
            GroupRemoveUnit(group, target)
            if validInnerFireTarget(caster, target) then
                DummyCaster.castTarget(
                    owner,
                    IDS.INNER_FIRE_DUMMY,
                    level,
                    INNER_FIRE_ORDER,
                    target,
                    GetUnitX(caster),
                    GetUnitY(caster),
                    GetUnitFacing(caster)
                )
            end
            target = FirstOfGroup(group)
        end

        DestroyGroup(group)
        startCooldown(caster, IDS.INNER_FIRE, INNER_FIRE_COOLDOWN)
    end

    local function stopPhaseShift(unit)
        local id = GetHandleId(unit)

        UnitRemoveAbility(unit, IDS.INVULNERABLE)

        if phaseShiftTimers[id] then
            DestroyTimer(phaseShiftTimers[id])
            phaseShiftTimers[id] = nil
        end
    end

    local function beginPhaseShift(unit)
        local id = GetHandleId(unit)
        local timer = nil

        if not unit or GetUnitTypeId(unit) == 0 then
            return
        end

        -- Falls Phase Shift erneut startet, alten Watcher sauber entfernen.
        if phaseShiftTimers[id] then
            DestroyTimer(phaseShiftTimers[id])
            phaseShiftTimers[id] = nil
        end

        UnitAddAbility(unit, IDS.INVULNERABLE)

        timer = CreateTimer()
        phaseShiftTimers[id] = timer

        TimerStart(timer, PHASE_SHIFT_PERIOD, true, function()
            if not unit or GetUnitTypeId(unit) == 0 or GetWidgetLife(unit) <= 0.405 then
                stopPhaseShift(unit)
                return
            end

            -- Sobald der Phase-Shift-Buff weg ist, INVU entfernen.
            if GetUnitAbilityLevel(unit, IDS.PHASE_SHIFT_BUFF) <= 0 then
                stopPhaseShift(unit)
            end
        end)
    end

    local function validEnergyChargeTarget(unit)
        return unit and
            GetWidgetLife(unit) > 0.405 and
            not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            GetUnitAbilityLevel(unit, IDS.WARD_CLASSIFICATION) <= 0
    end

    local function stopEnergyCharge(target)
        local id = target and GetHandleId(target) or 0
        local timer = energyChargeTimers[id]

        if timer then
            DestroyTimer(timer)
            energyChargeTimers[id] = nil
        end
    end

    local function startEnergyCharge(source, target, level)
        local interval = 0.25
        local range = 300.0 + 50.0 * level
        local damage = 30.0 * interval * level
        local timer = nil
        local id = GetHandleId(target)

        stopEnergyCharge(target)
        timer = CreateTimer()
        energyChargeTimers[id] = timer
        TimerStart(timer, interval, true, function()
            local group = nil
            local unit = nil

            if GetUnitTypeId(source) == 0 or GetUnitTypeId(target) == 0 or
                GetWidgetLife(target) <= 0.405 or GetUnitAbilityLevel(target, IDS.ENERGY_CHARGE_BUFF) <= 0 then
                stopEnergyCharge(target)
                return
            end

            group = CreateGroup()
            GroupEnumUnitsInRange(group, GetUnitX(target), GetUnitY(target), range, nil)
            unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                if validEnergyChargeTarget(unit) and IsUnitEnemy(unit, GetOwningPlayer(source)) then
                    UnitDamageTarget(source, unit, damage, false, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function onSpellEffect()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.INNER_FIRE then
            castMassInnerFire(GetTriggerUnit(), GetSpellTargetX(), GetSpellTargetY())
        elseif abilityId == IDS.PHASE_SHIFT then
            beginPhaseShift(GetTriggerUnit())
        elseif abilityId == IDS.ENERGY_CHARGE and GetSpellTargetUnit() then
            startEnergyCharge(GetTriggerUnit(), GetSpellTargetUnit(), GetUnitAbilityLevel(GetTriggerUnit(), IDS.ENERGY_CHARGE))
        end
    end

    RacePickSystem.onBuilderSpawn(onBuilderSpawn)

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        i = i + 1
    end
    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    AbilityRegistry.registerRace("Faerie", "builder", {
        notes = "Faerie builder abilities ported from FaerieRace, MassInnerFire, PhaseShift and EnergyCharge.",
        abilities = {
            {
                name = "Faerie permanent spellbook",
                source = "library FaerieRace",
                behavior = "Makes Enchanted Ledger, Phase Shift, Inner Fire, Faerie Fire, Silence, Energy Charge, Cripple, Death Shield, Enchanted Faerie Attack and Mana Flare permanent on spawn."
            },
            {
                name = "Mass Inner Fire",
                id = IDS.INNER_FIRE,
                source = "library MassInnerFire",
                behavior = "Casts dummy Inner Fire A0A0 on nearby non-magic-immune structures in 500 AoE and starts a 120 second cooldown."
            },
            {
                name = "Phase Shift",
                id = IDS.PHASE_SHIFT,
                source = "library PhaseShift",
                behavior = "Adds INVU while the unit has the Phase Shift buff Bpsh, then removes INVU when the buff expires."
            },
            {
                name = "Energy Charge",
                id = IDS.ENERGY_CHARGE,
                source = "library EnergyCharge",
                behavior = "While the Energy Charge buff is active, periodically deals magic damage to nearby enemy non-structure, non-ward units."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
