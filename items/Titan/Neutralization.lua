if Debug and Debug.beginFile then Debug.beginFile("items/Titan/Neutralization") end

OnInit("TitanItemNeutralization", function(import)
    import.strict("GameTimer")
    import.strict("GameSettings")
    import.strict("UnitFilter")

    local IDS = {
        WAND_OF_NEUTRALIZATION = FourCC("I03L"),
        NEUTRALIZATION = FourCC("A03E"),
        SPECIAL_BUFF = FourCC("B01T"),
        AVATAR_BUFF = FourCC("BHav")
    }

    local BOUNCE_RANGE = 600.0
    local BOUNCE_INTERVAL = 0.12
    local MAX_BOUNCES = 5
    local TARGET_EFFECT = "Abilities\\Spells\\Orc\\Purge\\PurgeBuffTarget.mdl"
    local LIGHTNING_CODE = "CHIM"

    local TitanItemNeutralization = {}

    local function destroyEffectTimed(effect)
        GameTimer.after(3.0, function()
            if effect then
                DestroyEffect(effect)
            end
        end)
    end

    local function hitTarget(unit)
        destroyEffectTimed(AddSpecialEffectTarget(TARGET_EFFECT, unit, "head"))
        UnitRemoveBuffs(unit, true, true)
        UnitRemoveAbility(unit, IDS.SPECIAL_BUFF)
        UnitRemoveAbility(unit, IDS.AVATAR_BUFF)
    end

    local function validBounceTarget(state, unit)
        local correctSide = false

        if state.allies and IsUnitAlly(unit, state.player) then
            correctSide = true
        elseif not state.allies and IsUnitEnemy(unit, state.player) then
            correctSide = true
        end

        return not IsUnitInGroup(unit, state.hitUnits) and
            GetOwningPlayer(unit) ~= Player(PLAYER_NEUTRAL_PASSIVE) and
            correctSide and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_MECHANICAL) and
            UnitFilter.isAlive(unit)
    end

    local function closestTarget(state, source)
        local group = CreateGroup()
        local unit = nil
        local closest = nil
        local closestDistance = BOUNCE_RANGE + 50.0
        local sourceX = GetUnitX(source)
        local sourceY = GetUnitY(source)

        GroupEnumUnitsInRange(group, sourceX, sourceY, BOUNCE_RANGE, nil)
        unit = FirstOfGroup(group)
        while unit do
            local dx = sourceX - GetUnitX(unit)
            local dy = sourceY - GetUnitY(unit)
            local distance = SquareRoot(dx * dx + dy * dy)

            GroupRemoveUnit(group, unit)
            if validBounceTarget(state, unit) and distance < closestDistance then
                closest = unit
                closestDistance = distance
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return closest
    end

    local function addBounceLightning(state, source, target)
        local lightning = AddLightning(
            LIGHTNING_CODE,
            false,
            GetUnitX(source),
            GetUnitY(source),
            GetUnitX(target),
            GetUnitY(target)
        )

        if lightning then
            state.lightnings[#state.lightnings + 1] = lightning
        end
    end

    local function cleanup(state)
        local i = 1

        if state.finished then
            return
        end
        state.finished = true
        if state.timer then
            state.timer:destroy()
            state.timer = nil
        end
        while i <= #state.lightnings do
            DestroyLightning(state.lightnings[i])
            i = i + 1
        end
        DestroyGroup(state.hitUnits)
    end

    function TitanItemNeutralization.cast(caster, target)
        local state = nil

        if not caster or not target or GetUnitTypeId(caster) == 0 or GetUnitTypeId(target) == 0 then
            return false
        end

        state = {
            caster = caster,
            player = GetOwningPlayer(caster),
            target = target,
            allies = IsUnitAlly(target, GetOwningPlayer(caster)),
            bounceCount = -1,
            hitUnits = CreateGroup(),
            lightnings = {},
            timer = nil,
            finished = false,
            useLightning = GameSettings.getBool("LIGHTNING_EFFECTS_ENABLED")
        }
        GroupAddUnit(state.hitUnits, target)

        state.timer = GameTimer.every(BOUNCE_INTERVAL, function()
            local previousTarget = state.target

            if state.bounceCount >= 0 then
                state.target = closestTarget(state, state.target)
            else
                previousTarget = state.caster
            end

            if not state.target then
                cleanup(state)
                return
            end

            if state.useLightning and previousTarget and GetUnitTypeId(previousTarget) ~= 0 then
                addBounceLightning(state, previousTarget, state.target)
            end
            hitTarget(state.target)
            GroupAddUnit(state.hitUnits, state.target)
            state.bounceCount = state.bounceCount + 1

            if state.bounceCount >= MAX_BOUNCES then
                cleanup(state)
            end
        end)
        return true
    end

    local function onSpellEffect()
        if GetSpellAbilityId() == IDS.NEUTRALIZATION then
            TitanItemNeutralization.cast(GetTriggerUnit(), GetSpellTargetUnit())
        end
    end

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

    TitanItemNeutralization.ids = IDS
    _G.TitanItemNeutralization = TitanItemNeutralization
end)

if Debug and Debug.endFile then Debug.endFile() end
