if Debug and Debug.beginFile then Debug.beginFile("Systems/UnitStateSystem") end

OnInit("UnitStateSystem", function(import)
    import.strict("GameTimer")

    local UnitStateSystem = {}

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function maxLife(unit)
        if not unit then
            return 0.0
        end
        if BlzGetUnitMaxHP then
            return BlzGetUnitMaxHP(unit)
        end
        return GetUnitState(unit, UNIT_STATE_MAX_LIFE)
    end

    local function maxMana(unit)
        if not unit then
            return 0.0
        end
        if BlzGetUnitMaxMana then
            return BlzGetUnitMaxMana(unit)
        end
        return GetUnitState(unit, UNIT_STATE_MAX_MANA)
    end

    local function clamp(value, minValue, maxValue)
        if value < minValue then
            return minValue
        elseif value > maxValue then
            return maxValue
        end
        return value
    end

    local function normalizePercent(percent)
        local value = percent or 0.0
        if value > -1.0 and value < 1.0 then
            return value * 100.0
        end
        return value
    end

    local function canManipulate(unit, options)
        if not unit or GetUnitTypeId(unit) == 0 then
            return false
        end
        if options and options.allowDead then
            return true
        end
        return isAlive(unit)
    end

    local function showEffect(unit, effectPath, attachPoint)
        if effectPath and effectPath ~= "" and unit and GetUnitTypeId(unit) ~= 0 then
            DestroyEffect(AddSpecialEffectTarget(effectPath, unit, attachPoint or "origin"))
        end
    end

    function UnitStateSystem.isAlive(unit)
        return isAlive(unit)
    end

    function UnitStateSystem.life(unit)
        if not unit then
            return 0.0
        end
        return GetWidgetLife(unit)
    end

    function UnitStateSystem.maxLife(unit)
        return maxLife(unit)
    end

    function UnitStateSystem.mana(unit)
        if not unit then
            return 0.0
        end
        return GetUnitState(unit, UNIT_STATE_MANA)
    end

    function UnitStateSystem.maxMana(unit)
        return maxMana(unit)
    end

    function UnitStateSystem.setLife(unit, amount, options)
        local cap = 0.0
        local floor = 1.0
        local value = amount or 0.0

        if not canManipulate(unit, options) then
            return 0.0
        end

        if options and options.allowKill then
            floor = 0.0
        end

        cap = maxLife(unit)
        if not options or not options.allowOverheal then
            value = clamp(value, floor, cap)
        elseif value < floor then
            value = floor
        end

        SetWidgetLife(unit, value)
        showEffect(unit, options and options.effect, options and options.attachPoint)
        return value
    end

    function UnitStateSystem.addLife(unit, amount, options)
        if not canManipulate(unit, options) then
            return 0.0
        end
        return UnitStateSystem.setLife(unit, GetWidgetLife(unit) + (amount or 0.0), options)
    end

    function UnitStateSystem.heal(unit, amount, options)
        return UnitStateSystem.addLife(unit, amount, options)
    end

    function UnitStateSystem.addLifePercent(unit, percent, options)
        return UnitStateSystem.addLife(unit, maxLife(unit) * normalizePercent(percent) / 100.0, options)
    end

    function UnitStateSystem.setLifePercent(unit, percent, options)
        return UnitStateSystem.setLife(unit, maxLife(unit) * normalizePercent(percent) / 100.0, options)
    end

    function UnitStateSystem.setMana(unit, amount, options)
        local cap = 0.0
        local value = amount or 0.0

        if not canManipulate(unit, options) then
            return 0.0
        end

        cap = maxMana(unit)
        if not options or not options.allowOverfill then
            value = clamp(value, 0.0, cap)
        elseif value < 0.0 then
            value = 0.0
        end

        SetUnitState(unit, UNIT_STATE_MANA, value)
        showEffect(unit, options and options.effect, options and options.attachPoint)
        return value
    end

    function UnitStateSystem.addMana(unit, amount, options)
        if not canManipulate(unit, options) then
            return 0.0
        end
        return UnitStateSystem.setMana(unit, GetUnitState(unit, UNIT_STATE_MANA) + (amount or 0.0), options)
    end

    function UnitStateSystem.addManaPercent(unit, percent, options)
        return UnitStateSystem.addMana(unit, maxMana(unit) * normalizePercent(percent) / 100.0, options)
    end

    function UnitStateSystem.setManaPercent(unit, percent, options)
        return UnitStateSystem.setMana(unit, maxMana(unit) * normalizePercent(percent) / 100.0, options)
    end

    function UnitStateSystem.restore(unit, lifeAmount, manaAmount, options)
        UnitStateSystem.addLife(unit, lifeAmount or 0.0, options)
        UnitStateSystem.addMana(unit, manaAmount or 0.0, options)
    end

    function UnitStateSystem.fullRestore(unit, options)
        UnitStateSystem.setLife(unit, maxLife(unit), options)
        UnitStateSystem.setMana(unit, maxMana(unit), options)
    end

    function UnitStateSystem.setMaxLife(unit, amount, options)
        local oldMax = maxLife(unit)
        local oldLife = UnitStateSystem.life(unit)
        local newMax = amount or oldMax

        if not unit or GetUnitTypeId(unit) == 0 or not BlzSetUnitMaxHP then
            return oldMax
        end

        if newMax < 1.0 then
            newMax = 1.0
        end

        BlzSetUnitMaxHP(unit, R2I(newMax))
        if options and options.keepPercent and oldMax > 0.0 then
            UnitStateSystem.setLife(unit, newMax * oldLife / oldMax, options)
        elseif options and options.fillAdded and newMax > oldMax then
            UnitStateSystem.addLife(unit, newMax - oldMax, options)
        elseif GetWidgetLife(unit) > newMax then
            UnitStateSystem.setLife(unit, newMax, options)
        end

        return newMax
    end

    function UnitStateSystem.addMaxLife(unit, amount, options)
        return UnitStateSystem.setMaxLife(unit, maxLife(unit) + (amount or 0.0), options)
    end

    function UnitStateSystem.addMaxLifeTimed(unit, amount, duration, options)
        local bonus = amount or 0.0
        UnitStateSystem.addMaxLife(unit, bonus, options)
        if duration and duration > 0.0 then
            GameTimer.after(duration, function()
                if unit and GetUnitTypeId(unit) ~= 0 then
                    UnitStateSystem.addMaxLife(unit, -bonus, options)
                end
            end)
        end
    end

    function UnitStateSystem.setMaxMana(unit, amount, options)
        local oldMax = maxMana(unit)
        local oldMana = UnitStateSystem.mana(unit)
        local newMax = amount or oldMax

        if not unit or GetUnitTypeId(unit) == 0 or not BlzSetUnitMaxMana then
            return oldMax
        end

        if newMax < 0.0 then
            newMax = 0.0
        end

        BlzSetUnitMaxMana(unit, R2I(newMax))
        if options and options.keepPercent and oldMax > 0.0 then
            UnitStateSystem.setMana(unit, newMax * oldMana / oldMax, options)
        elseif options and options.fillAdded and newMax > oldMax then
            UnitStateSystem.addMana(unit, newMax - oldMax, options)
        elseif GetUnitState(unit, UNIT_STATE_MANA) > newMax then
            UnitStateSystem.setMana(unit, newMax, options)
        end

        return newMax
    end

    function UnitStateSystem.addMaxMana(unit, amount, options)
        return UnitStateSystem.setMaxMana(unit, maxMana(unit) + (amount or 0.0), options)
    end

    function UnitStateSystem.addMaxManaTimed(unit, amount, duration, options)
        local bonus = amount or 0.0
        UnitStateSystem.addMaxMana(unit, bonus, options)
        if duration and duration > 0.0 then
            GameTimer.after(duration, function()
                if unit and GetUnitTypeId(unit) ~= 0 then
                    UnitStateSystem.addMaxMana(unit, -bonus, options)
                end
            end)
        end
    end

    _G.UnitStateSystem = UnitStateSystem
end)

if Debug and Debug.endFile then Debug.endFile() end
