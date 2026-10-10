if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/TaurenBuilderAbilities") end

OnInit("TaurenBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("RacePickSystem")
    import.strict("GameTimer")
    import.strict("MissileSystem")
    import.strict("AbilityMeta")
    import.strict("ExperienceSystem")
    import.strict("PlayerData")

    local IDS = {
        TAUREN = FourCC("O01Q"),
        TAUREN_ANCESTRAL = FourCC("O01R"),
        TAUREN_ALT = FourCC("O04H"),
        ANCESTRAL_SKILL = FourCC("A0AD"),
        ANCESTRAL_CALL = FourCC("A061"),
        WAR_STOMP = FourCC("A04F"),
        TOTEM_BASIC = FourCC("e00Q"),
        TOTEM_ENHANCED = FourCC("e00S"),
        TOTEM_SUPER = FourCC("e00T"),
        TOTEM_MEGA = FourCC("e00U")
    }

    local PERMANENT_ABILITIES = {
        FourCC("A0AE"),
        FourCC("A0AR"),
        FourCC("A0AO"),
        FourCC("A0AK"),
        FourCC("A0AQ"),
        FourCC("A0AL"),
        FourCC("A0AF"),
        FourCC("A0AB"),
        FourCC("A0AT"),
        FourCC("A0BD"),
        FourCC("A04F"),
        FourCC("A0AG"),
        FourCC("A0AC"),
        FourCC("A061"),
        FourCC("A0MU"),
        FourCC("A0JH"),
        FourCC("A0MH"),
        FourCC("A0LL")
    }

    local ANCESTRAL_DURATION = 10.0
    local ANCESTRAL_AOE = 1000.0
    local ANCESTRAL_SPLIT = 0.90
    local ANCESTRAL_MISSILE = "Abilities\\Weapons\\ZigguratMissile\\ZigguratMissile.mdl"
    local ANCESTRAL_HIT = "Abilities\\Spells\\NightElf\\Taunt\\TauntCaster.mdl"
    local WAR_STOMP_DAMAGE = 175.0
    local WAR_STOMP_AREA = 250.0
    local WAR_STOMP_DURATION = 1.0
    local TAUREN_EXP_AOE = 1800.0
    local TAUREN_EXP_DAMAGE_THRESHOLD = 45.0
    local TAUREN_EMPOWER_MANA = 25.0
    local TAUREN_EMPOWER_LIFE_PERCENT = 5.0
    local TAUREN_EMPOWER_DAMAGE_PERCENT = 10.0
    local TAUREN_EMPOWER_DURATION = 5.0
    local TAUREN_RESTORE_EFFECT = "Abilities\\Spells\\Orc\\EtherealForm\\SpiritWalkerChange.mdl"
    local activeCalls = {}
    local suppressDamage = false

    local function isTauren(unit)
        local id = unit and GetUnitTypeId(unit) or 0
        return id == IDS.TAUREN or id == IDS.TAUREN_ANCESTRAL or id == IDS.TAUREN_ALT
    end

    local function isTotem(unit)
        local id = unit and GetUnitTypeId(unit) or 0
        return id == IDS.TOTEM_BASIC or
            id == IDS.TOTEM_ENHANCED or
            id == IDS.TOTEM_SUPER or
            id == IDS.TOTEM_MEGA or
            id == FourCC("o040") or
            id == FourCC("o01U")
    end

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function checkWarStompTarget(caster, target)
        return isAlive(target) and
            (not IsUnitAlly(target, GetOwningPlayer(caster)) or GetOwningPlayer(target) == Player(PLAYER_NEUTRAL_PASSIVE)) and
            not IsUnitType(target, UNIT_TYPE_MAGIC_IMMUNE) and
            not IsUnitType(target, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(target, UNIT_TYPE_MECHANICAL)
    end

    local function isTitanSide(unit)
        local playerData = unit and PlayerData.get(GetOwningPlayer(unit)) or nil
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function stunTimed(unit, seconds)
        PauseUnit(unit, true)
        GameTimer.after(seconds, function()
            if isAlive(unit) then
                PauseUnit(unit, false)
            end
        end)
    end

    local function collectTotems(tauren, radius)
        local group = CreateGroup()
        local result = {}
        local unit = nil

        GroupEnumUnitsInRange(group, GetUnitX(tauren), GetUnitY(tauren), radius or ANCESTRAL_AOE, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isAlive(unit) and isTotem(unit) and GetOwningPlayer(unit) == GetOwningPlayer(tauren) then
                result[#result + 1] = unit
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return result
    end

    local function addMana(unit, amount)
        local mana = GetUnitState(unit, UNIT_STATE_MANA) + amount
        local cap = GetUnitState(unit, UNIT_STATE_MAX_MANA)

        if mana > cap then
            mana = cap
        elseif mana < 0.0 then
            mana = 0.0
        end

        SetUnitState(unit, UNIT_STATE_MANA, mana)
    end

    local function addLifePercent(unit, percent)
        local lifePercent = GetUnitLifePercent(unit) + percent
        if lifePercent > 100.0 then
            lifePercent = 100.0
        end
        SetUnitLifePercentBJ(unit, lifePercent)
    end

    local function taurenExpForTarget(target)
        local level = GetHeroLevel(target)
        if level < 6 then
            return 5
        elseif level <= 11 then
            return 7
        end
        return 8
    end

    local function empowerTowers(tauren)
        local totems = collectTotems(tauren, TAUREN_EXP_AOE)
        local i = 1

        while i <= #totems do
            local totem = totems[i]
            addMana(totem, TAUREN_EMPOWER_MANA)
            addLifePercent(totem, TAUREN_EMPOWER_LIFE_PERCENT)
            DestroyEffect(AddSpecialEffectTarget(TAUREN_RESTORE_EFFECT, totem, "overhead"))
            AbilityMeta.addDamageBonus(totem, TAUREN_EMPOWER_DAMAGE_PERCENT, TAUREN_EMPOWER_DURATION, true)
            i = i + 1
        end
    end

    local function startAncestralCall(caster)
        local id = GetHandleId(caster)

        if activeCalls[id] then
            return
        end

        activeCalls[id] = true
        GameTimer.after(ANCESTRAL_DURATION, function()
            activeCalls[id] = nil
        end)
    end

    local function redirectAncestralDamage(tauren, attacker, damage)
        local totems = collectTotems(tauren, ANCESTRAL_AOE)
        local splitDamage = damage * ANCESTRAL_SPLIT
        local perTotem = 0.0
        local i = 1

        if #totems == 0 then
            return false
        end

        if BlzSetEventDamage then
            BlzSetEventDamage(damage * (1.0 - ANCESTRAL_SPLIT))
        end
        DestroyEffect(AddSpecialEffectTarget(ANCESTRAL_HIT, tauren, "origin"))

        perTotem = splitDamage / #totems
        while i <= #totems do
            local target = totems[i]
            MissileSystem.launch({
                x = GetUnitX(tauren),
                y = GetUnitY(tauren),
                z = 100.0,
                target = target,
                speed = 800.0,
                collision = 20.0,
                model = ANCESTRAL_MISSILE,
                onImpact = function(impactTarget)
                    if isAlive(impactTarget) and attacker and GetUnitTypeId(attacker) ~= 0 then
                        suppressDamage = true
                        UnitDamageTarget(attacker, impactTarget, perTotem, false, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
                        suppressDamage = false
                    end
                end
            })
            i = i + 1
        end

        return true
    end

    local function castWarStomp(caster)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), WAR_STOMP_AREA, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if checkWarStompTarget(caster, unit) then
                suppressDamage = true
                UnitDamageTarget(caster, unit, WAR_STOMP_DAMAGE, true, true, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                suppressDamage = false
                stunTimed(unit, WAR_STOMP_DURATION)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function onBuilderSpawn(playerData, unit)
        local race = playerData and playerData:race() or nil
        local i = 1

        if not unit or not race or race:toString() ~= "Tauren" then
            return
        end

        SelectHeroSkill(unit, IDS.ANCESTRAL_SKILL)
        while i <= #PERMANENT_ABILITIES do
            UnitMakeAbilityPermanent(unit, true, PERMANENT_ABILITIES[i])
            i = i + 1
        end
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.ANCESTRAL_CALL and isTauren(caster) then
            startAncestralCall(caster)
        elseif abilityId == IDS.WAR_STOMP and isTauren(caster) then
            castWarStomp(caster)
        end
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local damage = GetEventDamage()

        if suppressDamage or damage <= 0.0 or not attacker or GetUnitTypeId(attacker) == 0 or not isTauren(target) or not activeCalls[GetHandleId(target)] then
            return
        end

        redirectAncestralDamage(target, attacker, damage)
    end

    local function onTaurenAttackDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local damage = GetEventDamage()

        if suppressDamage or not attacker or GetUnitTypeId(attacker) == 0 or not target then
            return
        end
        if BlzGetEventDamageType and BlzGetEventDamageType() ~= DAMAGE_TYPE_NORMAL then
            return
        end
        if not isTauren(attacker) or not isTitanSide(target) or damage <= TAUREN_EXP_DAMAGE_THRESHOLD then
            return
        end

        ExperienceSystem.giveExperience(attacker, taurenExpForTarget(target))
        empowerTowers(attacker)
    end

    RacePickSystem.onBuilderSpawn(onBuilderSpawn)

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
            debugApi.try(function()
                onDamaged()
                onTaurenAttackDamaged()
            end)
        else
            onDamaged()
            onTaurenAttackDamaged()
        end
    end)

    AbilityRegistry.registerRace("Tauren", "builder", {
        notes = "Tauren builder abilities ported from TaurenRace, WarStomp and AncestralCall.",
        abilities = {
            {
                name = "Tauren spawn setup",
                id = IDS.ANCESTRAL_SKILL,
                source = "library TaurenRace",
                behavior = "Learns Ancestral form and makes Tauren form/spellbook abilities permanent on spawn."
            },
            {
                name = "War Stomp",
                id = IDS.WAR_STOMP,
                source = "library WarStomp",
                behavior = "Deals 175 magic damage and briefly stuns valid nearby enemy/non-passive units in 250 range."
            },
            {
                name = "Ancestral Call",
                id = IDS.ANCESTRAL_CALL,
                source = "library AncestralCall",
                behavior = "For 10 seconds, redirects 90 percent of incoming Tauren damage into nearby owned totem towers using ancestor missiles."
            },
            {
                name = "Tauren EXP Empower",
                source = "library TaurenEXP",
                behavior = "Successful normal attacks over 45 damage against Titan-side units grant EXP and empower nearby totems with mana, life and temporary damage."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
