if Debug and Debug.beginFile then Debug.beginFile("Systems/DummyCaster") end

OnInit("DummyCaster", function()
    local DUMMY_UNIT_ID = FourCC("e01B")
    local DEFAULT_RECYCLE_DELAY = 1.0

    local DummyCaster = {}

    local function removeLater(unit, delay)
        local timer = CreateTimer()
        TimerStart(timer, delay or DEFAULT_RECYCLE_DELAY, false, function()
            if unit and GetUnitTypeId(unit) ~= 0 then
                RemoveUnit(unit)
            end
            DestroyTimer(timer)
        end)
    end

    local function prepare(owner, abilityId, level, x, y, facing)
        local dummy = CreateUnit(owner, DUMMY_UNIT_ID, 0.0, 0.0, facing or 0)

        UnitAddAbility(dummy, FourCC("Aloc"))
        UnitAddAbility(dummy, FourCC("Amrf"))
        UnitRemoveAbility(dummy, FourCC("Amrf"))
        UnitAddAbility(dummy, abilityId)

        -- Match xecast: newly prepared dummies must be able to cast abilities
        -- with mana costs or inherited cooldown state immediately.
        UnitResetCooldown(dummy)
        SetUnitState(dummy, UNIT_STATE_MANA, 10000.0)
        if level and level > 1 then
            SetUnitAbilityLevel(dummy, abilityId, level)
        end
        SetUnitX(dummy, x)
        SetUnitY(dummy, y)
        UnitApplyTimedLife(dummy, FourCC("BTLF"), DEFAULT_RECYCLE_DELAY + 1.0)

        return dummy
    end

    function DummyCaster.castTarget(owner, abilityId, level, order, target, x, y, facing, recycleDelay)
        local dummy = prepare(owner, abilityId, level or 1, x or GetUnitX(target), y or GetUnitY(target), facing or 0)

        UnitShareVision(target, owner, true)
        if type(order) == "number" then
            IssueTargetOrderById(dummy, order, target)
        else
            IssueTargetOrder(dummy, tostring(order or ""), target)
        end
        UnitShareVision(target, owner, false)

        removeLater(dummy, recycleDelay)
        return dummy
    end

    function DummyCaster.castPoint(owner, abilityId, level, order, targetX, targetY, x, y, facing, recycleDelay)
        local dummy = prepare(owner, abilityId, level or 1, x or targetX, y or targetY, facing or 0)

        if type(order) == "number" then
            IssuePointOrderById(dummy, order, targetX, targetY)
        else
            IssuePointOrder(dummy, tostring(order or ""), targetX, targetY)
        end

        removeLater(dummy, recycleDelay)
        return dummy
    end

    function DummyCaster.unitId()
        return DUMMY_UNIT_ID
    end

    _G.DummyCaster = DummyCaster
end)

if Debug and Debug.endFile then Debug.endFile() end
