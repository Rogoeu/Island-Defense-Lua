if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/PirateBuilderAbilities") end

OnInit("PirateBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("AbilityMeta")
    import.strict("DummyCaster")
    import.strict("GameTimer")

    local IDS = {
        DISSIPATE = FourCC("A0FT"),
        BOTTOMS_UP = FourCC("A0Q5"),
        BOTTOMS_UP_BUFF = FourCC("B07W"),
        BOTTOMS_UP_CONFUSE = FourCC("A0Q6"),
        CONFUSED_BUFF = FourCC("B07X"),
        TITAN_CLASSIFICATION = FourCC("CTIT")
    }

    local DISSIPATE_BONUS_DURATION = 3.0
    local DISSIPATE_BONUS_PERCENT = 0.35
    local BOTTOMS_UP_RANGE = 300.0
    local CONFUSION_INTERVAL = 0.10
    local CONFUSION_MOVE_DISTANCE = 200.0
    local CONFUSE_ORDER = 852101

    local function offsetX(x, angle, distance)
        return x + distance * Cos(angle * bj_DEGTORAD)
    end

    local function offsetY(y, angle, distance)
        return y + distance * Sin(angle * bj_DEGTORAD)
    end

    local function isInfusable(unit)
        return unit and
            GetUnitAbilityLevel(unit, IDS.TITAN_CLASSIFICATION) > 0 and
            not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE)
    end

    local function confuseMove(unit, group)
        local x = 0.0
        local y = 0.0

        if not unit or GetUnitAbilityLevel(unit, IDS.CONFUSED_BUFF) <= 0 or GetWidgetLife(unit) <= 0.405 then
            GroupRemoveUnit(group, unit)
            return
        end

        IssueImmediateOrder(unit, "stop")
        x = offsetX(GetUnitX(unit), GetRandomReal(0.0, 360.0), CONFUSION_MOVE_DISTANCE)
        y = offsetY(GetUnitY(unit), GetRandomReal(0.0, 360.0), CONFUSION_MOVE_DISTANCE)
        IssuePointOrder(unit, "move", x, y)
    end

    local function startConfusionLoop(group)
        GameTimer.every(CONFUSION_INTERVAL, function(expiredTimer)
            if CountUnitsInGroup(group) > 0 then
                ForGroup(group, function()
                    confuseMove(GetEnumUnit(), group)
                end)
            else
                DestroyGroup(group)
                expiredTimer:destroy()
            end
        end)
    end

    local function castBottomsUp(pirate)
        local group = CreateGroup()
        local confused = CreateGroup()
        local target = nil

        GroupEnumUnitsInRange(group, GetUnitX(pirate), GetUnitY(pirate), BOTTOMS_UP_RANGE, nil)
        target = FirstOfGroup(group)
        while target do
            GroupRemoveUnit(group, target)
            if isInfusable(target) then
                DummyCaster.castTarget(
                    GetOwningPlayer(target),
                    IDS.BOTTOMS_UP_CONFUSE,
                    1,
                    CONFUSE_ORDER,
                    target,
                    GetUnitX(target),
                    GetUnitY(target),
                    GetUnitFacing(target),
                    1.0
                )
                GroupAddUnit(confused, target)
            end
            target = FirstOfGroup(group)
        end
        DestroyGroup(group)

        if CountUnitsInGroup(confused) > 0 then
            startConfusionLoop(confused)
        else
            DestroyGroup(confused)
        end
    end

    local function onSpellEffect()
        local pirate = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.DISSIPATE then
            if not IsTerrainPathable(GetUnitX(pirate), GetUnitY(pirate), PATHING_TYPE_FLOATABILITY) or GetUnitAbilityLevel(pirate, IDS.BOTTOMS_UP_BUFF) > 0 then
                AbilityMeta.increaseMoveSpeedPercent(pirate, DISSIPATE_BONUS_DURATION, DISSIPATE_BONUS_PERCENT)
            end
        elseif abilityId == IDS.BOTTOMS_UP then
            castBottomsUp(pirate)
        end
    end

    local function onDamaged()
        local pirate = GetTriggerUnit()
        local damage = GetEventDamage()

        if GetUnitAbilityLevel(pirate, IDS.BOTTOMS_UP_BUFF) > 0 and damage > 0.0 and BlzSetEventDamage then
            BlzSetEventDamage(damage * (1.0 - 0.25 * GetUnitAbilityLevel(pirate, IDS.BOTTOMS_UP)))
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

    AbilityRegistry.registerRace("Pirate", "builder", {
        notes = "Pirate builder abilities ported from PirateEscapes.",
        abilities = {
            {
                name = "Dissipate",
                id = IDS.DISSIPATE,
                source = "library PirateEscapes",
                behavior = "If cast in water or during Bottoms Up, grants a short movement speed bonus."
            },
            {
                name = "Bottoms Up",
                id = IDS.BOTTOMS_UP,
                source = "library PirateEscapes",
                behavior = "Confuses nearby titan-classified units and reduces incoming Pirate damage while the buff is active."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
