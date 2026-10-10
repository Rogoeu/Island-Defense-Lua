if Debug and Debug.beginFile then Debug.beginFile("items/Titan/EtherealMirror") end

OnInit("TitanItemEtherealMirror", function(import)
    import.strict("DummyCaster")
    import.strict("GameTimer")
    import.strict("ItemExtras")

    local IDS = {
        ETHEREAL_MIRROR = FourCC("I068"),
        ACTIVE = FourCC("A0OT"),
        DUMMY_ETHEREAL = FourCC("A0OV"),
        FADING = FourCC("A0MI"),
        ETHEREAL_BUILDING = FourCC("e016"),
        TOWER_MARKER = FourCC("TOWR")
    }

    local ORDER_BANISH = 852486
    local DURATION = 5.0
    local AOE = 224.0
    local TOWER_COUNT_RADIUS = 896.0
    local FADE_TICK = 0.10
    local FADE_BASE_TICKS = 15
    local EFFECT_ETHEREAL = "Abilities\\Spells\\Other\\AcidBomb\\BottleImpact.mdl"
    local EFFECT_FADING = "Abilities\\Spells\\Items\\RitualDagger\\RitualDaggerTarget.mdl"

    local statesByReal = {}
    local statesByEntity = {}

    local TitanItemEtherealMirror = {}

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405
    end

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.ETHEREAL_MIRROR)
    end

    local function isValidTarget(unit)
        return isAlive(unit) and not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE)
    end

    local function destroyEffectTimed(effect, duration)
        GameTimer.after(duration, function()
            if effect then
                DestroyEffect(effect)
            end
        end)
    end

    local function effectAt(path, x, y)
        local effect = AddSpecialEffect(path, x, y)
        DestroyEffect(effect)
    end

    local function countTowers(x, y)
        local group = CreateGroup()
        local unit = nil
        local count = 0

        GroupEnumUnitsInRange(group, x, y, TOWER_COUNT_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if GetUnitAbilityLevel(unit, IDS.TOWER_MARKER) > 0 then
                count = count + 1
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return count
    end

    local function cleanupState(state, restoreReal)
        if state.fadeTimer then
            state.fadeTimer:destroy()
            state.fadeTimer = nil
        end
        if state.expireTimer then
            state.expireTimer:destroy()
            state.expireTimer = nil
        end
        if state.effect then
            DestroyEffect(state.effect)
            state.effect = nil
        end
        if state.real and GetUnitTypeId(state.real) ~= 0 then
            if restoreReal then
                ShowUnit(state.real, true)
                SetUnitVertexColor(state.real, 255, 255, 255, 255)
            end
            UnitRemoveAbility(state.real, IDS.FADING)
            statesByReal[GetHandleId(state.real)] = nil
        end
        if state.entity and GetUnitTypeId(state.entity) ~= 0 then
            UnitRemoveAbility(state.entity, IDS.FADING)
            statesByEntity[GetHandleId(state.entity)] = nil
            RemoveUnit(state.entity)
        end
    end

    local function expireBuilding(state)
        cleanupState(state, true)
    end

    local function applyBuildingEthereal(state)
        local real = state.real
        local caster = state.caster
        local x = GetUnitX(real)
        local y = GetUnitY(real)
        local effect = AddSpecialEffect(EFFECT_ETHEREAL, x, y)
        local entity = nil

        if rawget(_G, "BlzSetSpecialEffectHeight") and rawget(_G, "GetLocationZ") then
            local loc = Location(x, y)
            BlzSetSpecialEffectHeight(effect, GetLocationZ(loc) + 65.0)
            RemoveLocation(loc)
        end
        if rawget(_G, "BlzSetSpecialEffectScale") then
            BlzSetSpecialEffectScale(effect, 2.25)
        end

        ShowUnit(real, false)
        SetUnitVertexColor(real, 255, 255, 255, 255)

        entity = CreateUnit(GetOwningPlayer(caster), IDS.ETHEREAL_BUILDING, x, y, 0.0)
        UnitAddAbility(entity, IDS.FADING)

        state.effect = effect
        state.entity = entity
        statesByEntity[GetHandleId(entity)] = state

        state.expireTimer = GameTimer.after(DURATION, function()
            expireBuilding(state)
        end)
    end

    local function fadeBuilding(unit, caster, towerCount)
        local state = {
            real = unit,
            caster = caster,
            ticks = 0,
            totalTicks = FADE_BASE_TICKS + towerCount
        }

        statesByReal[GetHandleId(unit)] = state
        UnitAddAbility(unit, IDS.FADING)
        destroyEffectTimed(AddSpecialEffect(EFFECT_FADING, GetUnitX(unit), GetUnitY(unit)), 1.5)

        state.fadeTimer = GameTimer.every(FADE_TICK, function()
            local colorStep = 240.0 / state.totalTicks

            if not isAlive(state.real) then
                cleanupState(state, false)
                return
            end

            if state.ticks < state.totalTicks then
                state.ticks = state.ticks + 1
                SetUnitVertexColor(
                    state.real,
                    255 - R2I(colorStep) * state.ticks,
                    255 - R2I(colorStep / 2.2) * state.ticks,
                    255 - R2I(colorStep) * state.ticks,
                    255 - R2I(colorStep / 1.5) * state.ticks
                )
            else
                state.fadeTimer:destroy()
                state.fadeTimer = nil
                applyBuildingEthereal(state)
            end
        end)
    end

    local function applyUnitEthereal(caster, target)
        UnitAddAbility(target, IDS.FADING)
        DummyCaster.castTarget(GetOwningPlayer(target), IDS.DUMMY_ETHEREAL, 1, ORDER_BANISH, target, GetUnitX(target), GetUnitY(target), GetUnitFacing(target), 1.0)
        effectAt(EFFECT_ETHEREAL, GetUnitX(target), GetUnitY(target))

        GameTimer.after(DURATION, function()
            if target and GetUnitTypeId(target) ~= 0 then
                UnitRemoveAbility(target, IDS.FADING)
            end
        end)
    end

    function TitanItemEtherealMirror.cast(caster, x, y)
        local towerCount = countTowers(x, y)
        local group = CreateGroup()
        local target = nil

        GroupEnumUnitsInRange(group, x, y, AOE, nil)
        target = FirstOfGroup(group)
        while target do
            GroupRemoveUnit(group, target)
            if isValidTarget(target) and GetUnitAbilityLevel(target, IDS.FADING) <= 0 then
                if IsUnitType(target, UNIT_TYPE_STRUCTURE) then
                    fadeBuilding(target, caster, towerCount)
                else
                    applyUnitEthereal(caster, target)
                end
            end
            target = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()

        if GetSpellAbilityId() == IDS.ACTIVE and hasItem(caster) then
            TitanItemEtherealMirror.cast(caster, GetSpellTargetX(), GetSpellTargetY())
        end
    end

    local function onDamaged()
        local unit = GetTriggerUnit()
        local state = nil

        if GetEventDamage() <= 0.0 or not unit or GetUnitAbilityLevel(unit, IDS.FADING) <= 0 then
            return
        end

        state = statesByEntity[GetHandleId(unit)] or statesByReal[GetHandleId(unit)]
        if state then
            cleanupState(state, true)
            if BlzSetEventDamage then
                BlzSetEventDamage(0.0)
            end
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

    local function guarded(callback)
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(callback)
        else
            callback()
        end
    end

    TriggerAddAction(spellTrigger, function() guarded(onSpellEffect) end)
    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)

    TitanItemEtherealMirror.ids = IDS

    _G.TitanItemEtherealMirror = TitanItemEtherealMirror
end)

if Debug and Debug.endFile then Debug.endFile() end
