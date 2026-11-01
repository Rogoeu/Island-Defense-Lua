if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/MorphlingBuilderAbilities") end

OnInit("MorphlingBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("DummyCaster")
    import.strict("RacePickSystem")

    local IDS = {
        BUILDER_FORM = FourCC("h021"),
        WARRIOR_FORM = FourCC("h023"),
        BEAST_FORM = FourCC("h024"),
        PANIC = FourCC("A07J"),
        SLAM = FourCC("A0JR"),
        SLAM_CAST = FourCC("A04P"),
        SLAM_SLOW = FourCC("A04Q"),
        HOWL = FourCC("A07Z"),
        DEADLY_SPINES = FourCC("A080"),
        BARBS = FourCC("A081"),
        FORM_SWITCH = FourCC("A07E"),
        BUILDER_BEAST = FourCC("A0MK"),
        WARRIOR_BEAST = FourCC("A0PH"),
        SPELLBOOK = FourCC("A07X"),
        SPELL_SHIELD = FourCC("A001"),
        SHOCKWAVE = FourCC("A04E"),
        HEROIC_AURA = FourCC("A06M"),
        HEROIC_AURA_ACTIVE = FourCC("A06L"),
        HEROIC_AURA_BUFF = FourCC("B02R"),
        EVASION = FourCC("A07B"),
        BASH = FourCC("A077"),
        CRITICAL = FourCC("A078"),
        VAMPIRISM = FourCC("A085")
    }

    local SLAM_DAMAGE = 150.0
    local SLAM_AREA = 500.0
    local HEROIC_AURA_RADIUS = 800.0
    local HEROIC_AURA_ORDER_ON = OrderId("immolation")
    local HEROIC_AURA_OFF_ORDERS = {
        [OrderId("undefend")] = true,
        [OrderId("magicundefend")] = true,
        [OrderId("unmanashield")] = true,
        [OrderId("unimmolation")] = true,
        [OrderId("undivineshield")] = true
    }
    local suppressHeroicDamage = false

    local PERMANENT_ABILITIES = {
        IDS.PANIC,
        IDS.SLAM,
        IDS.HOWL,
        IDS.DEADLY_SPINES,
        IDS.FORM_SWITCH,
        IDS.SPELLBOOK,
        IDS.SPELL_SHIELD,
        IDS.SHOCKWAVE,
        IDS.HEROIC_AURA,
        IDS.BUILDER_BEAST,
        IDS.WARRIOR_BEAST,
        IDS.EVASION,
        IDS.BASH,
        IDS.CRITICAL,
        IDS.VAMPIRISM
    }

    local function isMorphling(playerData)
        local race = playerData and playerData:race() or nil
        return race and race ~= NullRace.instance() and race:toString() == "Morphling"
    end

    local function fromBuilder(unit)
        return GetUnitTypeId(unit) == IDS.BUILDER_FORM
    end

    local function fromWarrior(unit)
        return GetUnitTypeId(unit) == IDS.WARRIOR_FORM
    end

    local function fromBeast(unit)
        return GetUnitTypeId(unit) == IDS.BEAST_FORM
    end

    local function isAlive(unit)
        return unit and GetWidgetLife(unit) > 0.405 and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function onBuilderSpawn(playerData, unit)
        if not unit or not isMorphling(playerData) then
            return
        end

        local i = 1
        while i <= #PERMANENT_ABILITIES do
            UnitMakeAbilityPermanent(unit, true, PERMANENT_ABILITIES[i])
            i = i + 1
        end

        BlzUnitDisableAbility(unit, IDS.SHOCKWAVE, true, false)
        BlzUnitDisableAbility(unit, IDS.HEROIC_AURA, true, false)
        BlzUnitDisableAbility(unit, IDS.WARRIOR_BEAST, true, true)
        BlzUnitDisableAbility(unit, IDS.EVASION, true, false)
        BlzUnitDisableAbility(unit, IDS.BASH, true, false)
        BlzUnitDisableAbility(unit, IDS.CRITICAL, true, false)
        BlzUnitDisableAbility(unit, IDS.SLAM, true, true)
        BlzUnitDisableAbility(unit, IDS.DEADLY_SPINES, true, true)
        BlzUnitDisableAbility(unit, IDS.HOWL, true, true)
    end

    local function handleTransformation(unit, abilityId)
        if abilityId ~= IDS.FORM_SWITCH and abilityId ~= IDS.BUILDER_BEAST and abilityId ~= IDS.WARRIOR_BEAST then
            return
        end

        if fromBuilder(unit) then
            BlzUnitDisableAbility(unit, IDS.PANIC, true, true)
            BlzUnitDisableAbility(unit, IDS.SHOCKWAVE, false, false)
            BlzUnitDisableAbility(unit, IDS.HEROIC_AURA, false, false)
            BlzUnitDisableAbility(unit, IDS.EVASION, false, false)
            BlzUnitDisableAbility(unit, IDS.BASH, false, false)
            BlzUnitDisableAbility(unit, IDS.CRITICAL, false, false)

            if abilityId == IDS.FORM_SWITCH then
                BlzUnitDisableAbility(unit, IDS.SLAM, false, false)
                BlzUnitDisableAbility(unit, IDS.BUILDER_BEAST, true, true)
                BlzUnitDisableAbility(unit, IDS.WARRIOR_BEAST, false, false)
                BlzSetAbilityPosX(IDS.WARRIOR_BEAST, 3)
                BlzSetAbilityPosY(IDS.WARRIOR_BEAST, 0)
            elseif abilityId == IDS.BUILDER_BEAST then
                BlzUnitDisableAbility(unit, IDS.FORM_SWITCH, true, true)
                BlzUnitDisableAbility(unit, IDS.DEADLY_SPINES, false, false)
                BlzUnitDisableAbility(unit, IDS.HOWL, false, false)
                BlzUnitDisableAbility(unit, IDS.BARBS, false, false)
            end
        end

        if fromWarrior(unit) then
            if abilityId == IDS.FORM_SWITCH then
                BlzUnitDisableAbility(unit, IDS.SLAM, true, true)
                BlzUnitDisableAbility(unit, IDS.SHOCKWAVE, true, false)
                BlzUnitDisableAbility(unit, IDS.HEROIC_AURA, true, false)
                BlzUnitDisableAbility(unit, IDS.EVASION, true, false)
                BlzUnitDisableAbility(unit, IDS.BASH, true, false)
                BlzUnitDisableAbility(unit, IDS.CRITICAL, true, false)
                BlzUnitDisableAbility(unit, IDS.PANIC, false, false)
                BlzUnitDisableAbility(unit, IDS.WARRIOR_BEAST, true, true)
                BlzUnitDisableAbility(unit, IDS.BUILDER_BEAST, false, false)
                BlzSetAbilityPosX(IDS.BUILDER_BEAST, 3)
                BlzSetAbilityPosY(IDS.BUILDER_BEAST, 0)
            elseif abilityId == IDS.WARRIOR_BEAST then
                BlzUnitDisableAbility(unit, IDS.SLAM, true, true)
                BlzUnitDisableAbility(unit, IDS.FORM_SWITCH, true, true)
                BlzUnitDisableAbility(unit, IDS.DEADLY_SPINES, false, false)
                BlzUnitDisableAbility(unit, IDS.BARBS, false, false)
                BlzUnitDisableAbility(unit, IDS.HOWL, false, false)
            end
        end

        if fromBeast(unit) then
            BlzUnitDisableAbility(unit, IDS.DEADLY_SPINES, true, true)
            BlzUnitDisableAbility(unit, IDS.HOWL, true, true)
            BlzUnitDisableAbility(unit, IDS.BARBS, true, true)

            if abilityId == IDS.WARRIOR_BEAST then
                BlzUnitDisableAbility(unit, IDS.SLAM, false, false)
                BlzUnitDisableAbility(unit, IDS.FORM_SWITCH, false, false)
            elseif abilityId == IDS.BUILDER_BEAST then
                BlzUnitDisableAbility(unit, IDS.SHOCKWAVE, true, false)
                BlzUnitDisableAbility(unit, IDS.HEROIC_AURA, true, false)
                BlzUnitDisableAbility(unit, IDS.EVASION, true, false)
                BlzUnitDisableAbility(unit, IDS.BASH, true, false)
                BlzUnitDisableAbility(unit, IDS.CRITICAL, true, false)
                BlzUnitDisableAbility(unit, IDS.PANIC, false, false)
                BlzUnitDisableAbility(unit, IDS.FORM_SWITCH, false, false)
            end
        end
    end

    local function checkSlamTarget(caster, target)
        return isAlive(target) and
            (not IsUnitAlly(target, GetOwningPlayer(caster)) or GetOwningPlayer(target) == Player(PLAYER_NEUTRAL_PASSIVE)) and
            not IsUnitType(target, UNIT_TYPE_MAGIC_IMMUNE) and
            not IsUnitType(target, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(target, UNIT_TYPE_MECHANICAL)
    end

    local function castSlam(caster)
        local group = CreateGroup()
        local target = nil
        local owner = GetOwningPlayer(caster)
        local level = math.max(1, GetUnitAbilityLevel(caster, IDS.SLAM_CAST))

        GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), SLAM_AREA, nil)
        target = FirstOfGroup(group)
        while target do
            GroupRemoveUnit(group, target)
            if checkSlamTarget(caster, target) then
                UnitDamageTarget(caster, target, SLAM_DAMAGE, true, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                DummyCaster.castTarget(owner, IDS.SLAM_SLOW, level, OrderId("slow"), target, GetUnitX(caster), GetUnitY(caster), 0, 1.0)
            end
            target = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function onSpellEffect()
        local abilityId = GetSpellAbilityId()
        local caster = GetTriggerUnit()

        if abilityId == IDS.SLAM_CAST then
            -- Dawnkeeper shares this ability id; only a Morphling form slams.
            if fromBeast(caster) or fromWarrior(caster) or fromBuilder(caster) then
                castSlam(caster)
            end
        else
            handleTransformation(caster, abilityId)
        end
    end

    local function findHeroicAuraCarrier(target)
        local group = CreateGroup()
        local carrier = nil
        local owner = GetOwningPlayer(target)
        local unit = nil

        GroupEnumUnitsInRange(group, GetUnitX(target), GetUnitY(target), HEROIC_AURA_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isAlive(unit) and
                IsUnitAlly(unit, owner) and
                GetUnitAbilityLevel(unit, IDS.HEROIC_AURA_ACTIVE) > 0 then
                carrier = unit
                unit = nil
            else
                unit = FirstOfGroup(group)
            end
        end

        DestroyGroup(group)
        return carrier
    end

    local function onHeroicAuraDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local damage = GetEventDamage()
        local carrier = nil
        local redirected = 0.0

        if suppressHeroicDamage or not target or not attacker or damage <= 0.0 then
            return
        end
        if GetUnitAbilityLevel(target, IDS.HEROIC_AURA_BUFF) <= 0 then
            return
        end
        if not IsUnitEnemy(target, GetOwningPlayer(attacker)) then
            return
        end

        carrier = findHeroicAuraCarrier(target)
        if not carrier then
            return
        end

        redirected = damage / 2.0
        if BlzSetEventDamage then
            BlzSetEventDamage(damage - redirected)
        end

        suppressHeroicDamage = true
        UnitDamageTarget(
            attacker,
            carrier,
            redirected,
            true,
            false,
            BlzGetEventAttackType and BlzGetEventAttackType() or ATTACK_TYPE_NORMAL,
            BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL,
            WEAPON_TYPE_WHOKNOWS
        )
        suppressHeroicDamage = false
    end

    local function onHeroicAuraOrder()
        local unit = GetOrderedUnit()
        local order = GetIssuedOrderId()

        if not unit or GetUnitAbilityLevel(unit, IDS.HEROIC_AURA) <= 0 or not isAlive(unit) then
            return
        end

        if order == HEROIC_AURA_ORDER_ON then
            UnitAddAbility(unit, IDS.HEROIC_AURA_ACTIVE)
        elseif HEROIC_AURA_OFF_ORDERS[order] then
            UnitRemoveAbility(unit, IDS.HEROIC_AURA_ACTIVE)
        end
    end

    RacePickSystem.onBuilderSpawn(onBuilderSpawn)

    local trigger = CreateTrigger()
    local orderTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
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

    TriggerAddAction(orderTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onHeroicAuraOrder)
        else
            onHeroicAuraOrder()
        end
    end)

    TriggerAddAction(damageTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onHeroicAuraDamaged)
        else
            onHeroicAuraDamaged()
        end
    end)

    AbilityRegistry.registerRace("Morphling", "builder", {
        notes = "Morphling builder abilities ported from MorphlingRace, MorphlingTransformation and HeroicAura.",
        abilities = {
            {
                name = "Morphling permanent abilities",
                source = "library MorphlingRace",
                behavior = "Makes Morphling form and spellbook abilities permanent on spawn and applies builder-form defaults."
            },
            {
                name = "Morphling Transformation",
                source = "library MorphlingTransformation",
                behavior = "Shows and hides Builder, Warrior and Beast form abilities during A07E/A0MK/A0PH transformations."
            },
            {
                name = "Heroic Aura",
                id = IDS.HEROIC_AURA,
                source = "library HeroicAura",
                behavior = "A06M immolation toggle adds/removes hidden A06L; allies with B02R redirect half of incoming enemy damage to a nearby aura carrier."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
