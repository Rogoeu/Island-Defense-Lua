if Debug and Debug.beginFile then Debug.beginFile("Races/RaceRegistry") end

OnInit("Races", function(import)
    import.strict("StringLib")
    import.strict("ObjectIds")

    local races = {}
    local nullRace

    local Race = {}
    Race.__index = Race

    local function rawcode(code)
        if type(code) == "number" then
            return code
        end
        if type(code) == "string" and string.len(code) == 4 then
            return ObjectIds.register(code, code)
        end
        return 0
    end

    local function copyList(values, convertRawcodes)
        local result = {}
        local i = 1

        values = values or {}
        while i <= #values do
            if convertRawcodes then
                result[i] = rawcode(values[i])
            else
                result[i] = values[i]
            end
            i = i + 1
        end

        return result
    end

    local function copyTechLimits(values)
        local result = {}
        local i = 1

        values = values or {}
        while i <= #values do
            result[i] = {
                id = rawcode(values[i].id),
                max = values[i].max or 0,
                note = values[i].note or ""
            }
            i = i + 1
        end

        return result
    end

    local function copyRawcodeSet(values)
        local result = {}
        local seen = {}
        local i = 1

        values = values or {}
        while i <= #values do
            local id = rawcode(values[i])
            if id ~= 0 and not seen[id] then
                result[#result + 1] = id
                seen[id] = true
            end
            i = i + 1
        end

        return result
    end

    function Race.create(data)
        data = data or {}
        local widgetIds = copyRawcodeSet(data.widgetIds)
        local widgetId = rawcode(data.widgetId)
        if widgetId ~= 0 then
            local foundWidget = false
            local i = 1
            while i <= #widgetIds do
                if widgetIds[i] == widgetId then
                    foundWidget = true
                end
                i = i + 1
            end
            if not foundWidget then
                widgetIds[#widgetIds + 1] = widgetId
            end
        end

        local childIds = copyRawcodeSet(data.childIds)
        local childId = rawcode(data.childId)
        if childId ~= 0 then
            local found = false
            local i = 1
            while i <= #childIds do
                if childIds[i] == childId then
                    found = true
                end
                i = i + 1
            end
            if not found then
                childIds[#childIds + 1] = childId
            end
        end

        local this = setmetatable({
            name = data.name or "_Null",
            classValue = data.classValue or 0,
            widgetIdValue = widgetId,
            widgetIdsValue = widgetIds,
            itemIdValue = rawcode(data.itemId),
            childItemIdValue = rawcode(data.childItemId),
            childIdValue = childId,
            childIdsValue = childIds,
            iconValue = data.icon or "",
            childIconValue = data.childIcon or "",
            difficultyValue = data.difficulty or 1.0,
            randomPool = data.randomPool ~= false,
            infoValue = data.info or "No description available.",
            techIdsValue = copyList(data.techIds, true),
            techLimitsValue = copyTechLimits(data.techLimits),
            ultimateTowerIdsValue = copyList(data.ultimateTowerIds, true),
            abilityIdsValue = copyList(data.abilityIds, true),
            spawnSettingsValue = data.spawnSettings or {},
            wikiValue = data.wiki or {}
        }, Race)
        return this
    end

    function Race:toString()
        return self.name
    end

    function Race:class()
        return self.classValue
    end

    function Race:widgetId()
        return self.widgetIdValue
    end

    function Race:widgetIds()
        return copyList(self.widgetIdsValue, false)
    end

    function Race:itemId()
        return self.itemIdValue
    end

    function Race:childItemId()
        return self.childItemIdValue
    end

    function Race:childId()
        return self.childIdValue
    end

    function Race:childIds()
        return copyList(self.childIdsValue, false)
    end

    function Race:icon()
        if self.iconValue ~= "" then
            return self.iconValue
        end
        if self:isTitan() then
            return "ReplaceableTextures\\CommandButtons\\BTNInfernal.blp"
        elseif self:isDefender() then
            return "ReplaceableTextures\\CommandButtons\\BTNSelectHeroOn.blp"
        end
        return "ReplaceableTextures\\CommandButtons\\BTNCancel.blp"
    end

    function Race:childIcon()
        if self.childIconValue ~= "" then
            return self.childIconValue
        end
        return self:icon()
    end

    function Race:difficulty()
        return self.difficultyValue
    end

    function Race:info()
        return self.infoValue
    end

    function Race:techIds()
        return copyList(self.techIdsValue, false)
    end

    function Race:ultimateTowerIds()
        return copyList(self.ultimateTowerIdsValue, false)
    end

    function Race:techLimits()
        return copyTechLimits(self.techLimitsValue)
    end

    function Race:abilityIds()
        return copyList(self.abilityIdsValue, false)
    end

    function Race:spawnSettings()
        return self.spawnSettingsValue
    end

    function Race:wiki()
        return self.wikiValue
    end

    function Race:wikiCategory(name)
        local category = self.wikiValue and self.wikiValue[name]
        if category then
            return category
        end
        return {}
    end

    function Race:inRandomPool()
        return self.randomPool
    end

    function Race:isWidgetId(id)
        local i = 1
        while i <= #self.widgetIdsValue do
            if id == self.widgetIdsValue[i] then
                return true
            end
            i = i + 1
        end
        return false
    end

    function Race:isChildId(id)
        local i = 1
        while i <= #self.childIdsValue do
            if id == self.childIdsValue[i] then
                return true
            end
            i = i + 1
        end
        return false
    end

    function Race:isTitan()
        local playerData = rawget(_G, "PlayerData")
        return playerData ~= nil and self:class() == playerData.CLASS_TITAN
    end

    function Race:isDefender()
        local playerData = rawget(_G, "PlayerData")
        return playerData ~= nil and self:class() == playerData.CLASS_DEFENDER
    end

    local Races = {}

    function Races.register(data)
        local race = Race.create(data)
        races[#races + 1] = race
        return race
    end

    function Races.count()
        return #races
    end

    function Races.at(index)
        return races[index + 1] or nullRace
    end

    function Races.indexOf(race)
        local i = 1
        while i <= #races do
            if races[i] == race then
                return i - 1
            end
            i = i + 1
        end
        return -1
    end

    function Races.fromName(name)
        local wanted = StringCase(tostring(name or ""), false)
        local i = 1
        while i <= #races do
            if StringCase(races[i]:toString(), false) == wanted then
                return races[i]
            end
            i = i + 1
        end
        return nullRace
    end

    function Races.fromNamePartial(name, unique)
        local wanted = tostring(name or "")
        local found = nullRace
        local i = 1
        while i <= #races do
            if StringIndexOf(races[i]:toString(), wanted, false) == 0 then
                if not unique then
                    return races[i]
                end
                if found == nullRace then
                    found = races[i]
                else
                    return nullRace
                end
            end
            i = i + 1
        end
        return found
    end

    function Races.fromItemId(id)
        local i = 1
        while i <= #races do
            if races[i]:itemId() == id then
                return races[i]
            end
            i = i + 1
        end
        return nullRace
    end

    function Races.fromWidgetId(id)
        local i = 1
        while i <= #races do
            if races[i]:isWidgetId(id) then
                return races[i]
            end
            i = i + 1
        end
        return nullRace
    end

    function Races.fromChildId(id)
        local i = 1
        while i <= #races do
            if races[i]:isChildId(id) then
                return races[i]
            end
            i = i + 1
        end
        return nullRace
    end

    function Races.random(classValue)
        local pool = {}
        local i = 1
        while i <= #races do
            if races[i]:inRandomPool() and (classValue == nil or races[i]:class() == classValue) then
                pool[#pool + 1] = races[i]
            end
            i = i + 1
        end
        if #pool == 0 then
            return nullRace
        end
        return pool[GetRandomInt(1, #pool)]
    end

    function Races.all()
        local copy = {}
        local i = 1
        while i <= #races do
            copy[i] = races[i]
            i = i + 1
        end
        return copy
    end

    nullRace = Race.create({ name = "_Null", classValue = 0, difficulty = 0.0, randomPool = false })
    Races.NullRace = nullRace
    Races.Race = Race

    _G.Races = Races
    _G.Race = Race
    _G.NullRace = {
        instance = function()
            return nullRace
        end
    }
end)

if Debug and Debug.endFile then Debug.endFile() end
