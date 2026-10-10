if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/TrollBuilderAbilities") end

OnInit("TrollBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")

    local IDS = {
        TROLL_HUNTER = FourCC("H00M"),
        SERPENT_STRIKE = FourCC("A0OG"),
        SERPENT_STRIKE_BUFF = FourCC("B07K"),
        SERPENT_WARD = FourCC("o03X"),
        TROLL_REGENERATION_INFO = FourCC("A0OE"),
        TROLL_REGENERATION_ACTIVE = FourCC("A0OF"),
        VOODOO = FourCC("A02F"),
        VOODOO_BUFF = FourCC("B013")
    }

    local SERPENT_WARD_OFFSET = 150.0
    local REGENERATION_DELAY = 5.0
    local delayedRegeneration = {}
    local suppressVoodoo = false

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function offsetX(x, angle, distance)
        return x + distance * Cos(angle * bj_DEGTORAD)
    end

    local function offsetY(y, angle, distance)
        return y + distance * Sin(angle * bj_DEGTORAD)
    end

    local function restartRegenerationTimer(unit)
        local id = GetHandleId(unit)

        if delayedRegeneration[id] then
            delayedRegeneration[id]:destroy()
        end

        UnitRemoveAbility(unit, IDS.TROLL_REGENERATION_ACTIVE)
        delayedRegeneration[id] = GameTimer.after(REGENERATION_DELAY, function()
            if isAlive(unit) then
                UnitAddAbility(unit, IDS.TROLL_REGENERATION_ACTIVE)
            end
            delayedRegeneration[id] = nil
        end)
    end

    local function spawnSerpentWard(attacker, target)
        local angle = GetRandomReal(0.0, 360.0)
        local x = offsetX(GetUnitX(target), angle, SERPENT_WARD_OFFSET)
        local y = offsetY(GetUnitY(target), angle, SERPENT_WARD_OFFSET)

        CreateUnit(GetOwningPlayer(attacker), IDS.SERPENT_WARD, x, y, angle)
    end

    local function trySerpentStrike(attacker, target)
        local level = GetUnitAbilityLevel(attacker, IDS.SERPENT_STRIKE)
        local threshold = 0.0

        if level <= 0 or GetUnitAbilityLevel(target, IDS.SERPENT_STRIKE_BUFF) <= 0 then
            return
        end

        threshold = 0.10 + level * 0.05
        if GetRandomReal(0.0, 1.0) <= threshold then
            spawnSerpentWard(attacker, target)
        end
    end

    local function findVoodooReceiver(owner)
        local group = CreateGroup()
        local unit = nil
        local found = nil

        GroupEnumUnitsOfPlayer(group, owner, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if not found and isAlive(unit) and GetUnitAbilityLevel(unit, IDS.VOODOO_BUFF) > 0 then
                found = unit
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return found
    end

    local function redirectVoodooDamage(target, attacker, damage)
        local receiver = findVoodooReceiver(GetOwningPlayer(target))
        local damageType = DAMAGE_TYPE_NORMAL
        local attackType = ATTACK_TYPE_NORMAL

        if not receiver then
            return
        end

        if BlzGetEventDamageType and BlzGetEventDamageType() == DAMAGE_TYPE_MAGIC then
            damageType = DAMAGE_TYPE_MAGIC
            attackType = ATTACK_TYPE_MAGIC
        end

        if BlzSetEventDamage then
            BlzSetEventDamage(0.0)
        end

        GameTimer.after(0.10, function()
            if isAlive(receiver) and attacker and GetUnitTypeId(attacker) ~= 0 then
                suppressVoodoo = true
                UnitDamageTarget(attacker, receiver, damage, true, false, attackType, damageType, WEAPON_TYPE_WHOKNOWS)
                suppressVoodoo = false
            end
        end)
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local damage = GetEventDamage()

        if not target or not attacker or GetUnitTypeId(attacker) == 0 then
            return
        end

        trySerpentStrike(attacker, target)

        if GetUnitAbilityLevel(target, IDS.TROLL_REGENERATION_INFO) > 0 then
            restartRegenerationTimer(target)
        end

        if not suppressVoodoo and damage > 0.0 and GetUnitAbilityLevel(target, IDS.VOODOO) > 0 then
            redirectVoodooDamage(target, attacker, damage)
        end
    end

    local function onHeroSkill()
        local unit = GetTriggerUnit()

        if GetLearnedSkill() == IDS.TROLL_REGENERATION_INFO and GetUnitTypeId(unit) == IDS.TROLL_HUNTER then
            restartRegenerationTimer(unit)
        end
    end

    local damageTrigger = CreateTrigger()
    local skillTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        i = i + 1
    end

    TriggerAddAction(damageTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    TriggerAddAction(skillTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onHeroSkill)
        else
            onHeroSkill()
        end
    end)

    AbilityRegistry.registerRace("Troll", "builder", {
        notes = "Troll builder/hunter abilities ported from TitanHunterTroll and TrollVoodoo.",
        abilities = {
            {
                name = "Serpent Strike",
                id = IDS.SERPENT_STRIKE,
                source = "library TitanHunterTroll",
                behavior = "Attacks against units with B07K can spawn a serpent ward near the target with 10% + 5% per level chance."
            },
            {
                name = "Troll Regeneration",
                id = IDS.TROLL_REGENERATION_INFO,
                source = "library TitanHunterTroll",
                behavior = "Taking damage removes active regeneration and restores it after 5 seconds without damage."
            },
            {
                name = "Troll Voodoo",
                id = IDS.VOODOO,
                source = "library TrollVoodoo",
                behavior = "Damage to a unit with A02F is redirected to the owner's living unit with B013."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
