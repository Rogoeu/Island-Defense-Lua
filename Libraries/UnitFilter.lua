if Debug and Debug.beginFile then Debug.beginFile("Libraries/UnitFilter") end

OnInit("UnitFilter", function(import)
    import.strict("PlayerData")
    import.strict("Races")

    local UnitFilter = {}
    local registeredClasses = {}

    local HUNTER_ABILITY = FourCC("TIHU")
    local BUILDER_ABILITY = FourCC("BLDR")
    local ULTIMATE_TOWER_ABILITY = FourCC("ULTT")

    local function registeredClass(unit)
        local id = unit and GetHandleId(unit) or 0
        local record = id ~= 0 and registeredClasses[id] or nil

        if not record or record.unit ~= unit then
            return PlayerData.CLASS_NONE
        end
        if GetUnitTypeId(unit) == 0 then
            registeredClasses[id] = nil
            return PlayerData.CLASS_NONE
        end
        return record.classValue
    end

    local function raceUnitClass(unit)
        local typeId = unit and GetUnitTypeId(unit) or 0
        local race = nil

        if typeId == 0 then
            return PlayerData.CLASS_NONE
        end

        race = Races.fromChildId(typeId)
        if race ~= NullRace.instance() then
            if race:class() == PlayerData.CLASS_TITAN then
                return PlayerData.CLASS_MINION
            end
            return race:class()
        end

        race = Races.fromWidgetId(typeId)
        if race ~= NullRace.instance() then
            return race:class()
        end
        return PlayerData.CLASS_NONE
    end

    local function playerDataOf(unit)
        if not unit then
            return nil
        end
        return PlayerData.mainUnitData(unit) or PlayerData.get(GetOwningPlayer(unit))
    end

    local function unitClass(unit)
        local classValue = PlayerData.mainUnitClass(unit)
        local playerData = nil

        if classValue ~= PlayerData.CLASS_NONE then
            return classValue
        end
        classValue = registeredClass(unit)
        if classValue ~= PlayerData.CLASS_NONE then
            return classValue
        end
        classValue = raceUnitClass(unit)
        if classValue ~= PlayerData.CLASS_NONE then
            return classValue
        end
        playerData = unit and PlayerData.get(GetOwningPlayer(unit)) or nil
        return playerData and playerData:class() or PlayerData.CLASS_NONE
    end

    local function isAlive(unit)
        return unit and GetWidgetLife(unit) > 0.405
    end

    local function isInvulnerable(unit)
        return rawget(_G, "BlzIsUnitInvulnerable") and BlzIsUnitInvulnerable(unit)
    end

    local function isClass(playerData, classValue)
        return playerData and playerData:class() == classValue
    end

    function UnitFilter.playerDataOf(unit)
        return playerDataOf(unit)
    end

    function UnitFilter.isAlive(unit)
        return isAlive(unit)
    end

    function UnitFilter.isClass(playerData, classValue)
        return isClass(playerData, classValue)
    end

    function UnitFilter.registerUnitClass(unit, classValue)
        if unit and GetUnitTypeId(unit) ~= 0 then
            registeredClasses[GetHandleId(unit)] = {
                unit = unit,
                classValue = classValue or PlayerData.CLASS_NONE
            }
        end
    end

    function UnitFilter.unitClass(unit)
        return unitClass(unit)
    end

    function UnitFilter.isDefenderPlayer(playerData)
        return isClass(playerData, PlayerData.CLASS_DEFENDER)
    end

    function UnitFilter.isTitanPlayer(playerData)
        return isClass(playerData, PlayerData.CLASS_TITAN)
    end

    function UnitFilter.isMinionPlayer(playerData)
        return isClass(playerData, PlayerData.CLASS_MINION)
    end

    function UnitFilter.isTitanSidePlayer(playerData)
        return UnitFilter.isTitanPlayer(playerData) or UnitFilter.isMinionPlayer(playerData)
    end

    function UnitFilter.isDefenderUnit(unit)
        return unitClass(unit) == PlayerData.CLASS_DEFENDER
    end

    function UnitFilter.isTitanUnit(unit)
        return unitClass(unit) == PlayerData.CLASS_TITAN
    end

    function UnitFilter.isMinionUnit(unit)
        return unitClass(unit) == PlayerData.CLASS_MINION
    end

    function UnitFilter.isTitanSideUnit(unit)
        local classValue = unitClass(unit)
        return classValue == PlayerData.CLASS_TITAN or classValue == PlayerData.CLASS_MINION
    end

    function UnitFilter.isMainUnit(unit, classValue)
        local record = PlayerData.mainUnitRecord(unit)

        if record then
            return not classValue or record.classValue == classValue
        end

        local playerData = playerDataOf(unit)
        return playerData and playerData:unit() == unit and (not classValue or playerData:class() == classValue)
    end

    function UnitFilter.isDefenderMain(unit)
        return UnitFilter.isMainUnit(unit, PlayerData.CLASS_DEFENDER)
    end

    function UnitFilter.isTitanSideMain(unit)
        local record = PlayerData.mainUnitRecord(unit)

        if record then
            return record.classValue == PlayerData.CLASS_TITAN or record.classValue == PlayerData.CLASS_MINION
        end

        local playerData = playerDataOf(unit)
        return playerData and playerData:unit() == unit and UnitFilter.isTitanSidePlayer(playerData)
    end

    function UnitFilter.isWard(unit)
        return unit and GetUnitAbilityLevel(unit, FourCC("WARD")) > 0
    end

    function UnitFilter.isWall(unit)
        return unit and GetUnitAbilityLevel(unit, FourCC("WALL")) > 0
    end

    function UnitFilter.isTower(unit)
        return unit and GetUnitAbilityLevel(unit, FourCC("TOWR")) > 0
    end

    function UnitFilter.isUltimateTower(unit)
        local old = rawget(_G, "IsUnitUltimateTower")

        if old and old ~= UnitFilter.isUltimateTower then
            return old(unit)
        end

        return unit and GetUnitAbilityLevel(unit, ULTIMATE_TOWER_ABILITY) > 0
    end

    function UnitFilter.isTitanHunter(unit)
        local old = rawget(_G, "IsUnitTitanHunter")
        local playerData = playerDataOf(unit)

        if old and old ~= UnitFilter.isTitanHunter then
            return old(unit)
        end

        return unit and (
            GetUnitAbilityLevel(unit, HUNTER_ABILITY) > 0 or
            (playerData and type(playerData.hunter) == "function" and playerData:hunter() == unit)
        )
    end

    function UnitFilter.isBuilder(unit)
        local old = rawget(_G, "IsUnitBuilder")

        if old and old ~= UnitFilter.isBuilder then
            return old(unit)
        end

        return unit and GetUnitAbilityLevel(unit, BUILDER_ABILITY) > 0
    end

    function UnitFilter.isEnemyOrganic(unit, owner)
        return isAlive(unit) and
            IsUnitEnemy(unit, owner) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_MECHANICAL) and
            not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE) and
            not UnitFilter.isWard(unit) and
            not isInvulnerable(unit)
    end

    function UnitFilter.isNukable(unit, caster)
        local owner = GetOwningPlayer(caster)
        return isAlive(unit) and
            (IsUnitEnemy(unit, owner) or GetOwningPlayer(unit) == Player(PLAYER_NEUTRAL_PASSIVE)) and
            not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_MECHANICAL) and
            not UnitFilter.isWard(unit) and
            not isInvulnerable(unit)
    end

    function UnitFilter.isNukableStructure(unit, caster)
        return isAlive(unit) and
            (IsUnitEnemy(unit, GetOwningPlayer(caster)) or GetOwningPlayer(unit) == Player(PLAYER_NEUTRAL_PASSIVE)) and
            IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not isInvulnerable(unit)
    end

    function UnitFilter.isHealable(unit, caster)
        return isAlive(unit) and
            IsUnitAlly(unit, GetOwningPlayer(caster)) and
            GetOwningPlayer(unit) ~= Player(PLAYER_NEUTRAL_PASSIVE) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_MECHANICAL) and
            not UnitFilter.isWard(unit) and
            GetUnitState(unit, UNIT_STATE_LIFE) < GetUnitState(unit, UNIT_STATE_MAX_LIFE)
    end

    _G.UnitFilter = UnitFilter
    _G.IsDefenderUnit = UnitFilter.isDefenderUnit
    _G.IsTitanUnit = UnitFilter.isTitanUnit
    _G.IsMinionUnit = UnitFilter.isMinionUnit
    _G.IsTitanSideUnit = UnitFilter.isTitanSideUnit
    _G.IsUnitWard = UnitFilter.isWard
    _G.IsUnitWall = UnitFilter.isWall
    _G.IsUnitTower = UnitFilter.isTower
    _G.IsUnitUltimateTower = UnitFilter.isUltimateTower
    _G.IsTitanHunter = UnitFilter.isTitanHunter
    _G.IsUnitTitanHunter = UnitFilter.isTitanHunter
    _G.IsUnitBuilder = UnitFilter.isBuilder
    _G.UnitAlive = UnitFilter.isAlive
end)

if Debug and Debug.endFile then Debug.endFile() end
