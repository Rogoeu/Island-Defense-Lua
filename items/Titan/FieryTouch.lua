if Debug and Debug.beginFile then Debug.beginFile("items/Titan/FieryTouch") end

OnInit("TitanItemFieryTouch", function(import)
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("TitanDamageSystem")

    local IDS = {
        GAUNTLETS_OF_EMBERS = FourCC("I08Q"),
        MOLTEN_BLADE = FourCC("I093")
    }

    local AOE = 400.0
    local EMBER_DURATION_GAUNTLETS = 10.0
    local EMBER_DURATION_MOLTEN_BLADE = 15.0
    local BURN_INTERVAL = 0.5
    local BURN_DURATION_GAUNTLETS = 10.0
    local BURN_DURATION_MOLTEN_BLADE = 5.0
    local EFFECT_EMBERHEART = "EmberHearthSparks.mdx"
    local EFFECT_BURN = "Abilities\\Spells\\Other\\BreathOfFire\\BreathOfFireDamage.mdl"

    local TitanItemFieryTouch = {}
    local burnByTarget = {}

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405
    end

    local function effectAtHeight(path, x, y, height)
        local effect = AddSpecialEffect(path, x, y)

        if effect and rawget(_G, "BlzSetSpecialEffectHeight") and rawget(_G, "GetLocationZ") then
            local loc = Location(x, y)
            BlzSetSpecialEffectHeight(effect, GetLocationZ(loc) + (height or 0.0))
            RemoveLocation(loc)
        end

        return effect
    end

    local function createEmberheart(attacker, target)
        local duration = EMBER_DURATION_GAUNTLETS
        local x = GetUnitX(target)
        local y = GetUnitY(target)
        local effect = effectAtHeight(EFFECT_EMBERHEART, x, y, 128.0)
        local fog = CreateFogModifierRadius(GetOwningPlayer(attacker), FOG_OF_WAR_VISIBLE, x, y, AOE, true, true)

        if hasItem(attacker, IDS.MOLTEN_BLADE) then
            duration = EMBER_DURATION_MOLTEN_BLADE
        end

        FogModifierStart(fog)
        GameTimer.after(duration, function()
            if effect then
                DestroyEffect(effect)
            end
            FogModifierStop(fog)
            DestroyFogModifier(fog)
        end)
    end

    local function clearBurn(targetId)
        local burn = burnByTarget[targetId]

        if not burn then
            return
        end

        if burn.timer then
            burn.timer:destroy()
        end
        if burn.effect then
            DestroyEffect(burn.effect)
        end
        burnByTarget[targetId] = nil
    end

    local function startBurn(attacker, target)
        local targetId = GetHandleId(target)
        local burn = burnByTarget[targetId]

        if burn then
            clearBurn(targetId)
        end

        burn = {
            attacker = attacker,
            target = target,
            ticks = 0,
            effect = AddSpecialEffectTarget(EFFECT_BURN, target, "origin")
        }
        burnByTarget[targetId] = burn

        burn.timer = GameTimer.every(BURN_INTERVAL, function()
            local duration = BURN_DURATION_GAUNTLETS
            local damagePerSecond = 0.0

            if not isAlive(burn.attacker) or not isAlive(burn.target) then
                clearBurn(targetId)
                return
            end

            if hasItem(burn.attacker, IDS.MOLTEN_BLADE) then
                duration = BURN_DURATION_MOLTEN_BLADE
                damagePerSecond = BlzGetUnitMaxHP(burn.target) * 0.05 + 12.5
            elseif hasItem(burn.attacker, IDS.GAUNTLETS_OF_EMBERS) then
                damagePerSecond = BlzGetUnitMaxHP(burn.target) * 0.05
            else
                clearBurn(targetId)
                return
            end

            burn.ticks = burn.ticks + 1
            if burn.ticks <= duration / BURN_INTERVAL then
                TitanDamageSystem.dealDamage(burn.attacker, burn.target, damagePerSecond * BURN_INTERVAL, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            else
                clearBurn(targetId)
            end
        end)
    end

    function TitanItemFieryTouch.apply(attacker, target)
        createEmberheart(attacker, target)
        startBurn(attacker, target)
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()
        local damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL

        if not attacker or not target or damageType ~= DAMAGE_TYPE_NORMAL then
            return
        end
        if not IsUnitType(target, UNIT_TYPE_STRUCTURE) then
            return
        end
        if hasItem(attacker, IDS.GAUNTLETS_OF_EMBERS) or hasItem(attacker, IDS.MOLTEN_BLADE) then
            TitanItemFieryTouch.apply(attacker, target)
        end
    end

    local trigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    TitanItemFieryTouch.ids = IDS

    _G.TitanItemFieryTouch = TitanItemFieryTouch
end)

if Debug and Debug.endFile then Debug.endFile() end
