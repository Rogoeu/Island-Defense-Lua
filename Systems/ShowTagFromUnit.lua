if Debug and Debug.beginFile then Debug.beginFile("Systems/ShowTagFromUnit") end

OnInit("ShowTagFromUnit", function()
    local ShowTagFromUnit = {}

    local function upwardVelocity()
        local speed = TextTagSpeed2Velocity(50.0)
        return speed * Cos(90.0 * bj_DEGTORAD), speed * Sin(90.0 * bj_DEGTORAD)
    end

    local function finish(tag)
        local x, y = upwardVelocity()
        SetTextTagVelocity(tag, x, y)
        SetTextTagFadepoint(tag, 1.5)
        SetTextTagLifespan(tag, 2.0)
        SetTextTagPermanent(tag, false)
    end

    function ShowTagFromUnit.show(text, x, y, height)
        local tag = CreateTextTag()
        SetTextTagPos(tag, x, y, height or 0.0)
        SetTextTagText(tag, text or "", TextTagSize2Height(10.0))
        SetTextTagColor(tag, 255, 255, 255, 255)
        SetTextTagVisibility(tag, true)
        finish(tag)
        return tag
    end

    function ShowTagFromUnit.fromUnit(text, unit)
        local tag = CreateTextTagUnitBJ(text or "", unit, 0.0, 10.0, 0, 0, 100, 0)
        finish(tag)
        if IsUnitVisible(unit, GetLocalPlayer()) then
            SetTextTagVisibility(tag, true)
        else
            SetTextTagVisibility(tag, false)
        end
        return tag
    end

    function ShowTagFromUnit.fromUnitForAll(text, unit)
        local tag = CreateTextTagUnitBJ(text or "", unit, 0.0, 10.0, 0, 0, 100, 0)
        SetTextTagVisibility(tag, true)
        finish(tag)
        return tag
    end

    function ShowTagFromUnit.fromUnitWithColor(text, unit, red, green, blue)
        local tag = CreateTextTagUnitBJ(text or "", unit, 0.0, 10.0, 0, 0, 100, 0)
        SetTextTagColor(tag, red or 255, green or 255, blue or 255, 255)
        finish(tag)
        if IsUnitVisible(unit, GetLocalPlayer()) then
            SetTextTagVisibility(tag, true)
        else
            SetTextTagVisibility(tag, false)
        end
        return tag
    end

    setmetatable(ShowTagFromUnit, {
        __call = function(_, text, unit)
            return ShowTagFromUnit.fromUnit(text, unit)
        end
    })

    _G.ShowTagFromUnit = ShowTagFromUnit
    _G.ShowTag = ShowTagFromUnit.show
    _G.ShowTagFromUnitText = ShowTagFromUnit.fromUnit
    _G.ShowTagFromUnitForAll = ShowTagFromUnit.fromUnitForAll
    _G.ShowTagFromUnitWithColor = ShowTagFromUnit.fromUnitWithColor
end)

if Debug and Debug.endFile then Debug.endFile() end
