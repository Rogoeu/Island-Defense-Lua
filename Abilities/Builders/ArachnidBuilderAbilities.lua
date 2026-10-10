if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/ArachnidBuilderAbilities") end

OnInit("ArachnidBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("RacePickSystem")
    import.strict("DummyCaster")
    import.strict("MissileSystem")

    local IDS = {
        SPELL_BOOK = FourCC("A0M2"),
        SPELL_BOOK_DUMMY = FourCC("A0M1"),
        PANIC_SLOW = FourCC("A0M4"),
        WEB_PRISON = FourCC("A0M5"),
        WEB_PRISON_DUMMY = FourCC("A0MA"),
        NEST_RAGE = FourCC("A0MC"),
        DUMMY_CASTER = FourCC("e01B")
    }

    local WEB_PRISON_ORDER = 852171
    local PANIC_ORDER = "slow"
    local PANIC_RANGE = 400.0
    local WEB_PRISON_RANGE = 300.0
    local HUNTER_ATTACK_RANGE = 450.0
    local RAGE_ATTACK_RANGE_BONUS = 300.0
    local WEB_EFFECT = "Abilities\\Spells\\Undead\\Web\\WebTarget.mdl"
    local PANIC_MISSILE_SPEED = 1200.0
    local rageTimers = {}

    local function angleBetween(x1, y1, x2, y2)
        return bj_RADTODEG * Atan2(y2 - y1, x2 - x1)
    end

    local function isArachnid(playerData)
        return playerData and playerData:race() ~= NullRace.instance() and playerData:race():toString() == "Arachnid"
    end

    local function makePermanent(unit, abilityId)
        if GetUnitAbilityLevel(unit, abilityId) > 0 then
            UnitMakeAbilityPermanent(unit, true, abilityId)
        end
    end

    RacePickSystem.onBuilderSpawn(function(playerData, unit)
        if isArachnid(playerData) then
            makePermanent(unit, IDS.SPELL_BOOK)
            makePermanent(unit, IDS.SPELL_BOOK_DUMMY)
        end
    end)

    local function castWebPrison(caster)
        local tx = GetSpellTargetX()
        local ty = GetSpellTargetY()
        local level = GetUnitAbilityLevel(caster, IDS.WEB_PRISON)
        local owner = GetOwningPlayer(caster)
        local group = CreateGroup()
        local target = nil

        GroupEnumUnitsInRange(group, tx, ty, WEB_PRISON_RANGE, nil)
        target = FirstOfGroup(group)

        while target do
            GroupRemoveUnit(group, target)
            if IsUnitEnemy(target, owner) then
                DummyCaster.castTarget(
                    owner,
                    IDS.WEB_PRISON_DUMMY,
                    level,
                    WEB_PRISON_ORDER,
                    target,
                    tx,
                    ty,
                    angleBetween(tx, ty, GetUnitX(target), GetUnitY(target))
                )
            end
            target = FirstOfGroup(group)
        end

        DestroyGroup(group)
    end

    local function castPanic(caster)
        local owner = GetOwningPlayer(caster)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local group = CreateGroup()
        local target = nil

        GroupEnumUnitsInRange(group, x, y, PANIC_RANGE, nil)
        target = FirstOfGroup(group)

        while target do
            GroupRemoveUnit(group, target)
            if IsUnitEnemy(target, owner) then
                MissileSystem.launch({
                    model = WEB_EFFECT,
                    x = x,
                    y = y,
                    z = 80.0,
                    target = target,
                    speed = PANIC_MISSILE_SPEED,
                    collision = 48.0,
                    onImpact = function(hit)
                        if hit and GetUnitTypeId(hit) ~= 0 then
                            DummyCaster.castTarget(
                                owner,
                                IDS.PANIC_SLOW,
                                1,
                                PANIC_ORDER,
                                hit,
                                GetUnitX(hit),
                                GetUnitY(hit),
                                angleBetween(GetUnitX(hit), GetUnitY(hit), x, y)
                            )
                        end
                    end
                })
            end
            target = FirstOfGroup(group)
        end

        DestroyGroup(group)
        DestroyEffect(AddSpecialEffectTarget(WEB_EFFECT, caster, "origin"))
    end

    local function resetNestRage(unit)
        if not unit then
            return
        end
        if unit and GetUnitTypeId(unit) ~= 0 then
            BlzSetUnitWeaponRealField(unit, UNIT_WEAPON_RF_ATTACK_RANGE, 0, HUNTER_ATTACK_RANGE)
        end
        rageTimers[GetHandleId(unit)] = nil
    end

    local function castNestRage(caster)
        local duration = GetUnitAbilityLevel(caster, IDS.NEST_RAGE) * 7.0
        local id = GetHandleId(caster)
        local timer = rageTimers[id]

        if duration <= 0 then
            return
        end

        if timer and TimerGetRemaining(timer) >= duration then
            return
        end

        if timer then
            DestroyTimer(timer)
        end

        BlzSetUnitWeaponRealField(caster, UNIT_WEAPON_RF_ATTACK_RANGE, 0, HUNTER_ATTACK_RANGE + RAGE_ATTACK_RANGE_BONUS)
        timer = CreateTimer()
        rageTimers[id] = timer
        TimerStart(timer, duration, false, function()
            resetNestRage(caster)
            DestroyTimer(timer)
        end)
    end

    local function onSpellEffect()
        local abilityId = GetSpellAbilityId()
        local caster = GetTriggerUnit()

        if abilityId == IDS.SPELL_BOOK and GetUnitAbilityLevel(caster, IDS.SPELL_BOOK) == 2 then
            castPanic(caster)
        elseif abilityId == IDS.WEB_PRISON then
            castWebPrison(caster)
        elseif abilityId == IDS.NEST_RAGE then
            castNestRage(caster)
        end
    end

    local spellTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
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

    AbilityRegistry.registerRace("Arachnid", "builder", {
        notes = "Arachnid builder/hunter abilities ported from ArachnidRace and WebPrison.",
        abilities = {
            {
                name = "Arachnid spellbook permanents",
                ids = { IDS.SPELL_BOOK, IDS.SPELL_BOOK_DUMMY },
                source = "library ArachnidRace.onSpawn",
                behavior = "Makes Arachnid spellbook abilities permanent on builder spawn."
            },
            {
                name = "Panic slow",
                id = IDS.SPELL_BOOK,
                source = "library Spiderwebs",
                behavior = "When A0M2 is level 2, launches web visuals at enemies within 400 range and casts A0M4 Slow on impact."
            },
            {
                name = "Web Prison",
                id = IDS.WEB_PRISON,
                source = "library WebPrison",
                behavior = "Casts dummy web prison on enemy units within 300 range of the target point."
            },
            {
                name = "Nest Rage",
                id = IDS.NEST_RAGE,
                source = "library WebPrison",
                behavior = "Temporarily increases hunter attack range from 450 to 750 for 7 seconds per level."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
