if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/PandaBuilderAbilities") end

OnInit("PandaBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("RacePickSystem")
    import.strict("GameTimer")
    import.strict("AbilityMeta")
    import.strict("MissileSystem")
    import.strict("UnitStateSystem")
    import.strict("DummyCaster")
    import.strict("PlayerData")
    import.strict("UnitFilter")
    import.strict("DebugCheatPack")

    local IDS = {
        BASIC_SKIN = FourCC("h02D"),
        STORM_SKIN = FourCC("h04V"),
        EARTH_SKIN = FourCC("h04D"),
        FIRE_SKIN = FourCC("h02N"),
        STORM_FORM = FourCC("A0F8"),
        EARTH_FORM = FourCC("A0FA"),
        FIRE_FORM = FourCC("A0B1"),
        BUILD_REFRESH = FourCC("A09E"),
        HIDDEN_HARVEST = FourCC("A0B6"),
        HARVEST = FourCC("A0PJ"),
        GOLD = FourCC("A041"),
        REPAIR = FourCC("A0KC"),
        REPAIR_EARTH = FourCC("A0QO"),
        BOOK_STORM = FourCC("A0F9"),
        STORM_SKY_STRIKE = FourCC("A0JG"),
        STORM_WIND_WALK = FourCC("A0GR"),
        STORM_WIND_WALK_BUFF = FourCC("B06J"),
        STORM_HASTE = FourCC("A08T"),
        STORM_TEMPEST = FourCC("A0H1"),
        STORM_AIR = FourCC("A0GO"),
        STORM_FLEET_FOOT = FourCC("S005"),
        STORM_MARK_OF_WIND = FourCC("A0GS"),
        STORM_FLEET_FOOT_ALLY = FourCC("S00I"),
        BOOK_EARTH = FourCC("A0FE"),
        EARTH_BOULDER_SLAM = FourCC("A0FR"),
        EARTH_EARTHQUAKE = FourCC("A0G7"),
        EARTH_PILLAR = FourCC("A0FX"),
        EARTH_EARTHBOUND = FourCC("A0FC"),
        EARTH_BORN = FourCC("A0JE"),
        EARTH_STONESKIN = FourCC("A05X"),
        EARTH_ROCK_SOLID = FourCC("A0PK"),
        EARTH_ROCK_SOLID_INFO = FourCC("A0PI"),
        EARTH_ROCK_SOLID_ORB = FourCC("A0JF"),
        BOOK_FIRE = FourCC("A0FF"),
        FIRE_BREATH = FourCC("A0H4"),
        FIRE_FURY = FourCC("A0GJ"),
        FIRE_DANCE = FourCC("A0H6"),
        FIRE_TWIN = FourCC("A0O2"),
        FIRE_ENFLAME = FourCC("A0FO"),
        FIRE_BURNING_OIL = FourCC("A0H2"),
        FIRE_LIFESTEAL_INFO = FourCC("A0HA"),
        FIRE_EMBERHEART = FourCC("S00K"),
        FIRE_FORM_BUFF = FourCC("B05X"),
        FIRE_BURNING_OIL_BUFF = FourCC("B07G"),
        FIRE_TWIN_DUMMY = FourCC("e01B"),
        FIRE_TWIN_ILLUSION = FourCC("A0H8"),
        FIRE_TWIN_GHOST = FourCC("AGho"),
        VOLCANIC_ACTIVITY = FourCC("A0HB"),
        CYCLONE_BUFF = FourCC("Bcy2"),
        HALL_OF_ELEMENTS = FourCC("e01M"),
        WARD = FourCC("WARD"),
        DISPEL_CYCLONE = FourCC("A0PO"),
        EARTHBOUND_BUFF_TARGET = FourCC("A0FD"),
        EARTHBOUND_BUFF_PANDA = FourCC("A0FQ"),
        REFRESH_HUMAN_ONE = FourCC("A0FU"),
        REFRESH_HUMAN_TWO = FourCC("A0JD"),
        REFRESH_ORC_ONE = FourCC("A0PB"),
        REFRESH_ORC_TWO = FourCC("A0PD"),
        REFRESH_UNDEAD_ONE = FourCC("A0PC"),
        REFRESH_UNDEAD_TWO = FourCC("A0PE")
    }

    local RESEARCH = {
        STORM_STUDIES = FourCC("R03T"),
        EARTH_STUDIES = FourCC("R03U"),
        FIRE_STUDIES = FourCC("R03F"),
        OATH_STORM = FourCC("R040"),
        OATH_EARTH = FourCC("R03X"),
        OATH_FIRE = FourCC("R03Z"),
        STORMS_EYE = FourCC("R048"),
        HASTE = FourCC("R03M"),
        EMPOWERED_HASTE = FourCC("R046"),
        EARTH_APPROVAL = FourCC("R025"),
        PILLAR_OF_STONE = FourCC("R041"),
        HEALTH_UPGRADE = FourCC("R04K"),
        BURNING_OIL = FourCC("R04A"),
        VOLCANIC_ACTIVITY = FourCC("R04D"),
        EVERFLAME = FourCC("R04B"),
        ATTACK_DAMAGE = FourCC("RPAD"),
        ATTACK_SPEED = FourCC("RPAS"),
        ATTACK_RANGE = FourCC("RPAR"),
        MANA_POINTS = FourCC("RPMP"),
        LIFE_REGEN = FourCC("RPHR"),
        MANA_REGEN = FourCC("RPMR"),
        ARMOR_BONUS = FourCC("RPAB")
    }

    local STRUCTURES = {
        ARROW_TOWER = FourCC("o02S"),
        STORM_SPIRE = FourCC("o02Y"),
        EARTH_WALL = FourCC("h03E"),
        EARTH_WALL_ADVANCED = FourCC("h02I"),
        VOLCANO = FourCC("o01Z")
    }

    local FORM_BASIC = 0
    local FORM_STORM = 1
    local FORM_EARTH = 2
    local FORM_FIRE = 3
    local TRANSFORM_EFFECT = "Abilities\\Spells\\Human\\Polymorph\\PolyMorphDoneGround.mdl"
    local EARTHBOUND_LIGHTNING = "SPLK"
    local EARTHBOUND_DURATION = 6.0
    local ORDER_MOVE = 851986
    local ORDER_PATROL = 851991
    local ORDER_STOP = 851972
    local ORDER_HOLD_POSITION = 851993
    local formByUnit = {}
    local formTimerByUnit = {}
    local formTransitionByUnit = {}
    local formTransitionTokenByUnit = {}
    local controlRecoveryTokenByUnit = {}
    local cycloneTimerByUnit = {}
    local cycloneSeenByUnit = {}
    local earthboundByPanda = {}
    local earthboundTimerByPanda = {}
    local suppressEarthboundDamage = false
    local burningOilTimerByTarget = {}
    local enflameShieldByUnit = {}
    local enflameUnitById = {}
    local twinPandaByDummy = {}
    local twinActiveByDummy = {}
    local twinDummyById = {}
    local lastEarthWallBuilderByPlayer = {}
    local trackedPandasById = {}
    local debugByPlayerId = {}
    local suppressPandaProcDamage = false

    local BURNING_OIL_TICK = 0.20
    local BURNING_OIL_DURATION = 2.00
    local SKYSTRIKE_MODEL = "AirStrikeMissile.mdx"
    local SKYSTRIKE_HIT_EFFECT = "Abilities\\Spells\\Human\\Invisibility\\InvisibilityTarget.mdl"
    local SKYSTRIKE_BASE_DAMAGE = 125.0
    local SKYSTRIKE_AOE = 200.0
    local SKYSTRIKE_MISSILES_PER_SECOND = 4
    local SKYSTRIKE_IMPACT_AOE = 135.0
    local SKYSTRIKE_ARC = 0.35
    local SKYSTRIKE_SPEED = 1300.0
    local ORDER_SMART = 851971
    local ORDER_TWIN_GHOST = 852274
    local ORDER_TWIN_ILLUSION = 852069
    local ORDER_DISPEL_CYCLONE = 852057


    local PERMANENT_ABILITIES = {
        IDS.BOOK_STORM,
        IDS.STORM_SKY_STRIKE,
        IDS.STORM_WIND_WALK,
        IDS.STORM_HASTE,
        IDS.STORM_TEMPEST,
        IDS.STORM_AIR,
        IDS.STORM_FLEET_FOOT,
        IDS.STORM_MARK_OF_WIND,
        IDS.BOOK_EARTH,
        IDS.EARTH_BOULDER_SLAM,
        IDS.EARTH_EARTHQUAKE,
        IDS.EARTH_PILLAR,
        IDS.EARTH_EARTHBOUND,
        IDS.EARTH_BORN,
        IDS.EARTH_STONESKIN,
        IDS.EARTH_ROCK_SOLID,
        IDS.EARTH_ROCK_SOLID_INFO,
        IDS.EARTH_ROCK_SOLID_ORB,
        IDS.BOOK_FIRE,
        IDS.FIRE_BREATH,
        IDS.FIRE_FURY,
        IDS.FIRE_DANCE,
        IDS.FIRE_TWIN,
        IDS.FIRE_ENFLAME,
        IDS.FIRE_BURNING_OIL,
        IDS.FIRE_LIFESTEAL_INFO,
        IDS.FIRE_EMBERHEART,
        IDS.HIDDEN_HARVEST,
        IDS.HARVEST,
        IDS.GOLD,
        IDS.REPAIR
    }

    local function formName(form)
        if form == FORM_STORM then
            return "Storm"
        elseif form == FORM_EARTH then
            return "Earth"
        elseif form == FORM_FIRE then
            return "Fire"
        end
        return "Basic"
    end

    local function debugMessage(unit, text)
        local player = unit and GetOwningPlayer(unit) or nil

        if player and debugByPlayerId[GetPlayerId(player)] then
            DisplayTimedTextToPlayer(player, 0.0, 0.0, 20.0, "|cffffcc00[Panda Debug]|r " .. text)
        end
    end

    local function abilityStateText(unit)
        return "H=" .. I2S(GetUnitAbilityLevel(unit, IDS.HARVEST)) ..
            " HH=" .. I2S(GetUnitAbilityLevel(unit, IDS.HIDDEN_HARVEST)) ..
            " SB=" .. I2S(GetUnitAbilityLevel(unit, IDS.BOOK_STORM)) ..
            " EB=" .. I2S(GetUnitAbilityLevel(unit, IDS.BOOK_EARTH)) ..
            " FB=" .. I2S(GetUnitAbilityLevel(unit, IDS.BOOK_FIRE)) ..
            " order=" .. I2S(GetUnitCurrentOrder(unit))
    end

    local function isPanda(playerData)
        local race = playerData and playerData:race() or nil
        return race and race ~= NullRace.instance() and race:toString() == "Panda"
    end

    local function tech(player, techId)
        return GetPlayerTechCount(player, techId, false)
    end

    local function abilityLevel(unit, abilityId)
        local level = GetUnitAbilityLevel(unit, abilityId)
        if level < 1 then
            return 1
        end
        return level
    end

    local function distanceBetween(x1, y1, x2, y2)
        local dx = x2 - x1
        local dy = y2 - y1
        return SquareRoot(dx * dx + dy * dy)
    end

    local function offsetX(x, angle, distance)
        return x + distance * Cos(angle * bj_DEGTORAD)
    end

    local function offsetY(y, angle, distance)
        return y + distance * Sin(angle * bj_DEGTORAD)
    end

    local function terrainZ(x, y)
        local loc = Location(x, y)
        local z = GetLocationZ(loc)
        RemoveLocation(loc)
        return z
    end

    local function healUnit(unit, amount)
        if unit and amount and amount > 0.0 then
            SetWidgetLife(unit, GetWidgetLife(unit) + amount)
        end
    end

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405
    end

    local function isRealPanda(unit)
        local playerData = unit and
            (PlayerData.mainUnitData(unit) or PlayerData.get(GetOwningPlayer(unit))) or nil
        local race = playerData and playerData:race() or nil

        return unit and GetUnitTypeId(unit) ~= 0 and not IsUnitIllusion(unit) and
            UnitFilter.isDefenderMain(unit) and race and race ~= NullRace.instance() and
            race:toString() == "Panda"
    end

    local function formAbility(form)
        if form == FORM_STORM then
            return IDS.STORM_FORM
        elseif form == FORM_EARTH then
            return IDS.EARTH_FORM
        elseif form == FORM_FIRE then
            return IDS.FIRE_FORM
        end
        return 0
    end

    local function formSkin(form)
        if form == FORM_STORM then
            return IDS.STORM_SKIN
        elseif form == FORM_EARTH then
            return IDS.EARTH_SKIN
        elseif form == FORM_FIRE then
            return IDS.FIRE_SKIN
        end
        return IDS.BASIC_SKIN
    end

    local function isEarthWallBuildOrder(unit)
        local order = unit and GetUnitCurrentOrder(unit) or 0
        return order == STRUCTURES.EARTH_WALL or order == STRUCTURES.EARTH_WALL_ADVANCED
    end

    local function restorePandaControlState(unit)
        -- Orc construction hides its worker. Never override that engine-owned
        -- state: showing/morphing the worker does not release it from a building.
        if not isAlive(unit) or IsUnitHidden(unit) then
            return
        end

        PauseUnit(unit, false)
        SetUnitInvulnerable(unit, false)
        SetUnitPathing(unit, true)
        ShowUnit(unit, true)
    end

    local function scheduleControlRecovery(unit)
        local id = GetHandleId(unit)
        local token = (controlRecoveryTokenByUnit[id] or 0) + 1
        local delays = { 0.03, 0.10, 0.25 }
        local i = 1

        controlRecoveryTokenByUnit[id] = token
        if not isAlive(unit) or IsUnitHidden(unit) then
            return
        end
        IssueImmediateOrderById(unit, ORDER_STOP)
        restorePandaControlState(unit)
        while i <= #delays do
            local delay = delays[i]
            GameTimer.after(delay, function()
                if controlRecoveryTokenByUnit[id] == token and isRealPanda(unit) then
                    restorePandaControlState(unit)
                end
            end)
            i = i + 1
        end
    end

    local function setTech(player, id, max)
        SetPlayerTechMaxAllowed(player, id, max)
    end

    local function refreshBuildStyle(unit)
        UnitRemoveAbility(unit, FourCC("AHbu"))
        UnitRemoveAbility(unit, FourCC("AObu"))
        UnitRemoveAbility(unit, FourCC("ASbu"))
        UnitAddAbility(unit, IDS.BUILD_REFRESH)
        UnitRemoveAbility(unit, IDS.BUILD_REFRESH)
    end

    local function pulseAbility(unit, abilityId)
        UnitAddAbility(unit, abilityId)
        UnitRemoveAbility(unit, abilityId)
    end

    local function buildStyleHuman(unit)
        refreshBuildStyle(unit)
        pulseAbility(unit, IDS.REFRESH_HUMAN_ONE)
        pulseAbility(unit, IDS.REFRESH_HUMAN_TWO)
    end

    local function buildStyleOrc(unit)
        refreshBuildStyle(unit)
        pulseAbility(unit, IDS.REFRESH_ORC_ONE)
        pulseAbility(unit, IDS.REFRESH_ORC_TWO)
    end

    local function buildStyleUndead(unit)
        refreshBuildStyle(unit)
        pulseAbility(unit, IDS.REFRESH_UNDEAD_ONE)
        pulseAbility(unit, IDS.REFRESH_UNDEAD_TWO)
    end

    local function setupStructures(player, form)
        setTech(player, STRUCTURES.ARROW_TOWER, form == FORM_BASIC and -1 or 0)
        setTech(player, STRUCTURES.STORM_SPIRE, form == FORM_STORM and -1 or 0)
        setTech(player, STRUCTURES.VOLCANO, form == FORM_FIRE and -1 or 0)

        if form == FORM_EARTH then
            if tech(player, RESEARCH.EARTH_APPROVAL) == 2 then
                setTech(player, STRUCTURES.EARTH_WALL, -1)
                setTech(player, STRUCTURES.EARTH_WALL_ADVANCED, 0)
            else
                setTech(player, STRUCTURES.EARTH_WALL, 0)
                setTech(player, STRUCTURES.EARTH_WALL_ADVANCED, -1)
            end
        else
            setTech(player, STRUCTURES.EARTH_WALL, 0)
            setTech(player, STRUCTURES.EARTH_WALL_ADVANCED, -1)
        end
    end

    local function setSkin(unit, form)
        if BlzSetUnitSkin then
            BlzSetUnitSkin(unit, formSkin(form))
        end
    end

    local function setupStats(unit, player, form)
        local attackDamage = 0
        local attackSpeed = 0
        local attackRange = 0
        local manaPoints = 0
        local lifeRegen = 0
        local manaRegen = 0
        local armorBonus = 0

        if tech(player, RESEARCH.OATH_STORM) == 2 then
            manaPoints = manaPoints + 20
            manaRegen = manaRegen + 20
        elseif tech(player, RESEARCH.OATH_EARTH) == 2 then
            armorBonus = armorBonus + 2
        elseif tech(player, RESEARCH.OATH_FIRE) == 2 then
            attackDamage = attackDamage + 5
            attackSpeed = attackSpeed + 5
            manaPoints = manaPoints + 10
        end

        if form == FORM_STORM then
            attackRange = attackRange + 35
            manaPoints = manaPoints + 8 * tech(player, RESEARCH.STORM_STUDIES)
            if tech(player, RESEARCH.STORMS_EYE) >= 1 then
                attackDamage = attackDamage + 5
                attackRange = attackRange + 15
                attackSpeed = attackSpeed + 10
            end
        elseif form == FORM_EARTH then
            armorBonus = armorBonus + 3 + 2 * tech(player, RESEARCH.EARTH_STUDIES)
            if tech(player, RESEARCH.EARTH_APPROVAL) >= 1 then
                lifeRegen = lifeRegen + 10
            end
        elseif form == FORM_FIRE then
            attackRange = attackRange + 2
            attackDamage = attackDamage + 5 + 4 * tech(player, RESEARCH.FIRE_STUDIES)
            attackSpeed = attackSpeed + 2 * tech(player, RESEARCH.FIRE_STUDIES)
        end

        if tech(player, RESEARCH.OATH_EARTH) > 0 then
            buildStyleOrc(unit)
        elseif tech(player, RESEARCH.OATH_STORM) > 0 then
            buildStyleUndead(unit)
        else
            buildStyleHuman(unit)
        end

        SetPlayerTechResearched(player, RESEARCH.ATTACK_DAMAGE, attackDamage)
        SetPlayerTechResearched(player, RESEARCH.ATTACK_SPEED, attackSpeed)
        SetPlayerTechResearched(player, RESEARCH.ATTACK_RANGE, attackRange)
        SetPlayerTechResearched(player, RESEARCH.MANA_POINTS, manaPoints)
        SetPlayerTechResearched(player, RESEARCH.LIFE_REGEN, lifeRegen)
        SetPlayerTechResearched(player, RESEARCH.MANA_REGEN, manaRegen)
        SetPlayerTechResearched(player, RESEARCH.ARMOR_BONUS, armorBonus)

        if BlzSetUnitRealField then
            if form == FORM_STORM then
                BlzSetUnitRealField(unit, UNIT_RF_ACQUISITION_RANGE, tech(player, RESEARCH.STORMS_EYE) >= 1 and 450.0 or 350.0)
            else
                BlzSetUnitRealField(unit, UNIT_RF_ACQUISITION_RANGE, 200.0)
            end
        end
        if BlzSetUnitIntegerField then
            BlzSetUnitIntegerField(unit, UNIT_IF_DEFENSE_TYPE, form == FORM_EARTH and 2 or 1)
        end
        if BlzSetUnitWeaponIntegerField then
            if form == FORM_STORM then
                BlzSetUnitWeaponIntegerField(unit, UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0, 4)
            elseif form == FORM_FIRE and tech(player, RESEARCH.OATH_FIRE) > 0 then
                BlzSetUnitWeaponIntegerField(unit, UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0, 6)
            else
                BlzSetUnitWeaponIntegerField(unit, UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0, 1)
            end
        end
    end

    local function swapForm(unit, player, form)
        local id = 0
        local previousForm = FORM_BASIC

        if not unit or GetUnitTypeId(unit) == 0 then
            return false
        end
        id = GetHandleId(unit)
        previousForm = formByUnit[id] or FORM_BASIC

        if previousForm == FORM_BASIC then
            BlzUnitDisableAbility(unit, IDS.HARVEST, true, true)
            BlzUnitDisableAbility(unit, IDS.HIDDEN_HARVEST, false, false)
        end

        if previousForm == FORM_STORM and form ~= FORM_STORM then
            BlzUnitDisableAbility(unit, IDS.BOOK_STORM, true, true)
            BlzUnitDisableAbility(unit, IDS.STORM_SKY_STRIKE, true, true)
            BlzUnitDisableAbility(unit, IDS.STORM_WIND_WALK, true, true)
            BlzUnitDisableAbility(unit, IDS.STORM_HASTE, true, true)
            BlzUnitDisableAbility(unit, IDS.STORM_TEMPEST, true, true)
            BlzUnitDisableAbility(unit, IDS.STORM_AIR, true, true)
            BlzUnitDisableAbility(unit, IDS.STORM_FLEET_FOOT, true, false)
            BlzUnitDisableAbility(unit, IDS.STORM_MARK_OF_WIND, true, true)
            BlzUnitDisableAbility(unit, IDS.STORM_FLEET_FOOT_ALLY, true, true)
        elseif previousForm == FORM_EARTH and form ~= FORM_EARTH then
            if tech(player, RESEARCH.OATH_EARTH) >= 1 then
                UnitRemoveAbility(unit, IDS.REPAIR_EARTH)
            end
            BlzUnitDisableAbility(unit, IDS.BOOK_EARTH, true, true)
            BlzUnitDisableAbility(unit, IDS.EARTH_BOULDER_SLAM, true, true)
            BlzUnitDisableAbility(unit, IDS.EARTH_PILLAR, true, true)
            BlzUnitDisableAbility(unit, IDS.EARTH_EARTHBOUND, true, true)
            BlzUnitDisableAbility(unit, IDS.EARTH_EARTHQUAKE, true, true)
            BlzUnitDisableAbility(unit, IDS.EARTH_STONESKIN, true, true)
            BlzUnitDisableAbility(unit, IDS.EARTH_BORN, true, true)
            BlzUnitDisableAbility(unit, IDS.EARTH_ROCK_SOLID, true, true)
            BlzUnitDisableAbility(unit, IDS.EARTH_ROCK_SOLID_ORB, true, true)
        elseif previousForm == FORM_FIRE and form ~= FORM_FIRE then
            BlzUnitDisableAbility(unit, IDS.BOOK_FIRE, true, true)
            BlzUnitDisableAbility(unit, IDS.FIRE_BREATH, true, true)
            BlzUnitDisableAbility(unit, IDS.FIRE_FURY, true, true)
            BlzUnitDisableAbility(unit, IDS.FIRE_DANCE, true, true)
            BlzUnitDisableAbility(unit, IDS.FIRE_TWIN, true, true)
            BlzUnitDisableAbility(unit, IDS.FIRE_ENFLAME, true, true)
            BlzUnitDisableAbility(unit, IDS.FIRE_BURNING_OIL, true, true)
            BlzUnitDisableAbility(unit, IDS.FIRE_EMBERHEART, true, true)
        end

        if form == FORM_BASIC then
            BlzUnitDisableAbility(unit, IDS.HARVEST, false, false)
            BlzUnitDisableAbility(unit, IDS.HIDDEN_HARVEST, true, true)
        elseif form == FORM_STORM then
            BlzUnitDisableAbility(unit, IDS.BOOK_STORM, false, false)
            BlzUnitDisableAbility(unit, IDS.STORM_SKY_STRIKE, false, false)
            BlzUnitDisableAbility(unit, IDS.STORM_WIND_WALK, false, false)
            BlzUnitDisableAbility(unit, IDS.STORM_HASTE, false, false)
            BlzUnitDisableAbility(unit, IDS.STORM_TEMPEST, false, false)
            BlzUnitDisableAbility(unit, IDS.STORM_AIR, false, false)
            BlzUnitDisableAbility(unit, IDS.STORM_FLEET_FOOT, false, false)
            BlzUnitDisableAbility(unit, IDS.STORM_MARK_OF_WIND, false, false)
            BlzUnitDisableAbility(unit, IDS.STORM_FLEET_FOOT_ALLY, false, false)
            if tech(player, RESEARCH.STORM_STUDIES) >= 1 then
                SetUnitAbilityLevel(unit, IDS.STORM_WIND_WALK, 2)
                SetUnitAbilityLevel(unit, IDS.STORM_FLEET_FOOT, 2)
                if tech(player, RESEARCH.STORM_STUDIES) == 3 then
                    SetUnitAbilityLevel(unit, IDS.STORM_FLEET_FOOT, 3)
                end
            end
            SetUnitAbilityLevel(unit, IDS.STORM_HASTE, tech(player, RESEARCH.HASTE))
            if tech(player, RESEARCH.EMPOWERED_HASTE) == 1 then
                SetUnitAbilityLevel(unit, IDS.STORM_HASTE, 4)
            end
            if tech(player, RESEARCH.OATH_STORM) >= 1 then
                SetUnitAbilityLevel(unit, IDS.STORM_WIND_WALK, 3)
            end
        elseif form == FORM_EARTH then
            if tech(player, RESEARCH.OATH_EARTH) >= 1 then
                UnitRemoveAbility(unit, IDS.REPAIR)
                UnitAddAbility(unit, IDS.REPAIR_EARTH)
            end
            BlzUnitDisableAbility(unit, IDS.BOOK_EARTH, false, false)
            BlzUnitDisableAbility(unit, IDS.EARTH_BOULDER_SLAM, false, false)
            BlzUnitDisableAbility(unit, IDS.EARTH_PILLAR, false, false)
            BlzUnitDisableAbility(unit, IDS.EARTH_EARTHBOUND, false, false)
            BlzUnitDisableAbility(unit, IDS.EARTH_EARTHQUAKE, false, false)
            BlzUnitDisableAbility(unit, IDS.EARTH_STONESKIN, false, false)
            BlzUnitDisableAbility(unit, IDS.EARTH_BORN, false, false)
            BlzUnitDisableAbility(unit, IDS.EARTH_ROCK_SOLID, false, false)
            BlzUnitDisableAbility(unit, IDS.EARTH_ROCK_SOLID_ORB, false, false)
            if tech(player, RESEARCH.EARTH_STUDIES) >= 1 then
                SetUnitAbilityLevel(unit, IDS.EARTH_STONESKIN, tech(player, RESEARCH.EARTH_STUDIES) + 1)
            end
            if tech(player, RESEARCH.EARTH_APPROVAL) == 2 then
                SetUnitAbilityLevel(unit, IDS.EARTH_ROCK_SOLID, 1)
                SetUnitAbilityLevel(unit, IDS.EARTH_ROCK_SOLID_INFO, 1)
            end
            if tech(player, RESEARCH.PILLAR_OF_STONE) == 1 then
                SetUnitAbilityLevel(unit, IDS.EARTH_ROCK_SOLID, 2)
                SetUnitAbilityLevel(unit, IDS.EARTH_ROCK_SOLID_INFO, 2)
            end
        elseif form == FORM_FIRE then
            BlzUnitDisableAbility(unit, IDS.BOOK_FIRE, false, false)
            BlzUnitDisableAbility(unit, IDS.FIRE_BREATH, false, false)
            BlzUnitDisableAbility(unit, IDS.FIRE_FURY, false, false)
            BlzUnitDisableAbility(unit, IDS.FIRE_DANCE, false, false)
            BlzUnitDisableAbility(unit, IDS.FIRE_TWIN, false, false)
            BlzUnitDisableAbility(unit, IDS.FIRE_ENFLAME, false, false)
            BlzUnitDisableAbility(unit, IDS.FIRE_BURNING_OIL, false, false)
            BlzUnitDisableAbility(unit, IDS.FIRE_EMBERHEART, false, false)
            SetUnitAbilityLevel(unit, IDS.FIRE_BURNING_OIL, tech(player, RESEARCH.BURNING_OIL) + 1)
            if tech(player, RESEARCH.FIRE_STUDIES) == 3 then
                SetUnitAbilityLevel(unit, IDS.FIRE_ENFLAME, 2)
            end
            if tech(player, RESEARCH.EVERFLAME) == 1 then
                SetUnitAbilityLevel(unit, IDS.FIRE_BREATH, 2)
                SetUnitAbilityLevel(unit, IDS.FIRE_DANCE, 2)
                SetUnitAbilityLevel(unit, IDS.FIRE_ENFLAME, 3)
            end
            if tech(player, RESEARCH.OATH_FIRE) >= 1 then
                SetUnitAbilityLevel(unit, IDS.FIRE_TWIN, 2)
            end
        end

        formByUnit[id] = form
        setSkin(unit, form)
        return true
    end

    local function stopCycloneMonitor(unit)
        local id = GetHandleId(unit)
        local timer = cycloneTimerByUnit[id]

        if timer then
            timer:destroy()
            cycloneTimerByUnit[id] = nil
        end
        cycloneSeenByUnit[id] = nil
    end

    local function ensureCycloneMonitor(unit)
        local id = GetHandleId(unit)

        if cycloneTimerByUnit[id] then
            return
        end
        cycloneSeenByUnit[id] = false
        cycloneTimerByUnit[id] = GameTimer.every(0.10, function(timer)
            local form = formByUnit[id] or FORM_BASIC

            if not isRealPanda(unit) or not isAlive(unit) or form == FORM_BASIC then
                cycloneTimerByUnit[id] = nil
                cycloneSeenByUnit[id] = nil
                timer:destroy()
                return
            end
            if GetUnitAbilityLevel(unit, IDS.CYCLONE_BUFF) > 0 then
                cycloneSeenByUnit[id] = true
            elseif cycloneSeenByUnit[id] then
                setSkin(unit, FORM_BASIC)
                setSkin(unit, form)
                cycloneTimerByUnit[id] = nil
                cycloneSeenByUnit[id] = nil
                timer:destroy()
            end
        end)
    end

    local function applyForm(unit, form, transformationAbility, wallOrderCleared)
        local id = GetHandleId(unit)
        local token = 0
        local player = GetOwningPlayer(unit)
        local previousForm = formByUnit[id] or FORM_BASIC
        local previousAbility = formAbility(previousForm)
        local duration = 0.0

        -- A09E is Metamorphosis-based. Pulsing it while Warcraft is processing
        -- an Earth Wall build order can strand the Panda in the hidden,
        -- invulnerable transformation state.
        if not isRealPanda(unit) or not isAlive(unit) then
            debugMessage(unit, "Swap rejected: unit is not recognized as the real Panda.")
            return
        end
        debugMessage(unit, "Swap request " .. formName(previousForm) .. " -> " .. formName(form) ..
            " ability=" .. I2S(transformationAbility or 0) .. " | " .. abilityStateText(unit))

        -- Current order is not a reliable construction test once an Orc worker
        -- has entered the building. Defer manual swaps and timed form expiry
        -- until the engine releases the hidden worker on finish/cancel/death.
        if IsUnitHidden(unit) then
            token = (formTransitionTokenByUnit[id] or 0) + 1
            formTransitionTokenByUnit[id] = token
            GameTimer.after(0.10, function()
                if formTransitionTokenByUnit[id] == token and isRealPanda(unit) and isAlive(unit) then
                    applyForm(unit, form, transformationAbility)
                end
            end)
            return
        end

        if not wallOrderCleared and isEarthWallBuildOrder(unit) then
            token = (formTransitionTokenByUnit[id] or 0) + 1
            formTransitionTokenByUnit[id] = token
            IssueImmediateOrderById(unit, ORDER_STOP)
            restorePandaControlState(unit)
            debugMessage(unit, "Swap deferred: Earth Wall build order was active.")
            GameTimer.after(0.03, function()
                if formTransitionTokenByUnit[id] == token and isRealPanda(unit) then
                    debugMessage(unit, "Deferred swap resumed.")
                    applyForm(unit, form, transformationAbility, true)
                    scheduleControlRecovery(unit)
                end
            end)
            return
        end
        if formTransitionByUnit[id] then
            debugMessage(unit, "Swap blocked: transition lock is still active.")
            return
        end
        formTransitionByUnit[id] = true
        formTransitionTokenByUnit[id] = (formTransitionTokenByUnit[id] or 0) + 1
        token = formTransitionTokenByUnit[id]

        GameTimer.after(0.25, function()
            if formTransitionTokenByUnit[id] == token and formTransitionByUnit[id] then
                formTransitionByUnit[id] = nil
                if isRealPanda(unit) and isAlive(unit) and not IsUnitHidden(unit) then
                    debugMessage(unit, "Recovery watchdog fired for " .. formName(form) .. ".")
                    restorePandaControlState(unit)
                    setupStructures(player, form)
                    setupStats(unit, player, form)
                    swapForm(unit, player, form)
                end
            end
        end)

        if formTimerByUnit[id] then
            formTimerByUnit[id]:destroy()
            formTimerByUnit[id] = nil
        end

        DestroyEffect(AddSpecialEffectTarget(TRANSFORM_EFFECT, unit, "origin"))
        setupStructures(player, form)
        setupStats(unit, player, form)
        swapForm(unit, player, form)
        debugMessage(unit, "swapForm complete -> " .. formName(form) .. " | " .. abilityStateText(unit))
        if form == FORM_BASIC then
            stopCycloneMonitor(unit)
        else
            ensureCycloneMonitor(unit)
        end

        if previousAbility ~= 0 and previousAbility ~= transformationAbility and abilityLevel(unit, previousAbility) < 5 then
            AbilityMeta.startCooldown(unit, previousAbility, 180.0 - 30.0 * abilityLevel(unit, previousAbility))
        end

        if transformationAbility ~= 0 and form ~= FORM_BASIC then
            if abilityLevel(unit, transformationAbility) < 5 then
                duration = 10.0 * abilityLevel(unit, transformationAbility)
                AbilityMeta.startCooldown(unit, transformationAbility, duration)
                duration = duration - 0.10
                if duration < 0.10 then
                    duration = 0.10
                end
                formTimerByUnit[id] = GameTimer.after(duration, function()
                    formTimerByUnit[id] = nil
                    if isRealPanda(unit) and (formByUnit[id] or FORM_BASIC) == form then
                        DummyCaster.castPoint(
                            GetOwningPlayer(unit),
                            IDS.DISPEL_CYCLONE,
                            1,
                            ORDER_DISPEL_CYCLONE,
                            GetUnitX(unit),
                            GetUnitY(unit),
                            GetUnitX(unit),
                            GetUnitY(unit),
                            GetUnitFacing(unit),
                            1.0
                        )
                        applyForm(unit, FORM_BASIC, transformationAbility)
                    end
                end)
            else
                AbilityMeta.startCooldown(unit, transformationAbility, 0.50)
            end
        elseif transformationAbility ~= 0 and abilityLevel(unit, transformationAbility) < 5 then
            AbilityMeta.startCooldown(unit, transformationAbility, 180.0 - 30.0 * abilityLevel(unit, transformationAbility))
        end
        formTransitionByUnit[id] = nil
        debugMessage(unit, "Swap complete -> " .. formName(form) .. ".")
    end

    local function wantedForm(abilityId, currentForm)
        if abilityId == IDS.STORM_FORM then
            return currentForm == FORM_STORM and FORM_BASIC or FORM_STORM
        elseif abilityId == IDS.EARTH_FORM then
            return currentForm == FORM_EARTH and FORM_BASIC or FORM_EARTH
        elseif abilityId == IDS.FIRE_FORM then
            return currentForm == FORM_FIRE and FORM_BASIC or FORM_FIRE
        end
        return -1
    end

    local function isPandaUnit(unit)
        return isRealPanda(unit)
    end

    local function forPandasOfPlayer(player, callback)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsOfPlayer(group, player, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isPandaUnit(unit) and GetWidgetLife(unit) > 0.405 then
                callback(unit)
            end
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
    end

    local function setOathLocks(player, researched, cancelling)
        if researched == RESEARCH.OATH_STORM then
            setTech(player, RESEARCH.OATH_EARTH, cancelling and 1 or 0)
            setTech(player, RESEARCH.OATH_FIRE, cancelling and 1 or 0)
        elseif researched == RESEARCH.OATH_EARTH then
            setTech(player, RESEARCH.OATH_STORM, cancelling and 1 or 0)
            setTech(player, RESEARCH.OATH_FIRE, cancelling and 1 or 0)
        elseif researched == RESEARCH.OATH_FIRE then
            setTech(player, RESEARCH.OATH_STORM, cancelling and 1 or 0)
            setTech(player, RESEARCH.OATH_EARTH, cancelling and 1 or 0)
        end
    end

    local function onResearchStart()
        setOathLocks(GetOwningPlayer(GetTriggerUnit()), GetResearched(), false)
    end

    local function onResearchCancel()
        setOathLocks(GetOwningPlayer(GetTriggerUnit()), GetResearched(), true)
    end

    local function onResearchFinish()
        local player = GetOwningPlayer(GetTriggerUnit())
        local researched = GetResearched()

        setOathLocks(player, researched, false)
        if researched == RESEARCH.HEALTH_UPGRADE and GetUnitTypeId(GetTriggerUnit()) == IDS.HALL_OF_ELEMENTS then
            forPandasOfPlayer(player, function(unit)
                UnitStateSystem.addMaxLife(unit, 100.0, { fillAdded = true })
            end)
        elseif researched == RESEARCH.OATH_EARTH and tech(player, RESEARCH.OATH_EARTH) == 2 then
            setTech(player, FourCC("o04G"), -1)
            forPandasOfPlayer(player, function(unit)
                UnitStateSystem.addMaxLife(unit, 150.0, { fillAdded = true })
            end)
        elseif researched == RESEARCH.OATH_FIRE and tech(player, RESEARCH.OATH_FIRE) == 2 then
            setTech(player, FourCC("o015"), -1)
        elseif researched == RESEARCH.OATH_STORM and tech(player, RESEARCH.OATH_STORM) == 2 then
            setTech(player, FourCC("o01P"), -1)
        elseif researched == RESEARCH.EARTH_STUDIES then
            forPandasOfPlayer(player, function(unit)
                if (formByUnit[GetHandleId(unit)] or FORM_BASIC) == FORM_EARTH then
                    UnitStateSystem.addMaxLife(unit, 50.0, { fillAdded = true })
                end
            end)
        end

    end

    local function clearEarthbound(panda)
        local id = GetHandleId(panda)
        local target = earthboundByPanda[id]
        local timer = earthboundTimerByPanda[id]

        earthboundTimerByPanda[id] = nil
        if timer then
            timer:destroy()
        end
        if target then
            UnitRemoveAbility(target, IDS.EARTHBOUND_BUFF_TARGET)
        end
        UnitRemoveAbility(panda, IDS.EARTHBOUND_BUFF_PANDA)
        earthboundByPanda[id] = nil
    end

    local function wouldCreateEarthboundCycle(panda, target)
        local current = target
        local visited = {}

        while current do
            local id = GetHandleId(current)
            if current == panda or visited[id] then
                return true
            end
            visited[id] = true
            current = earthboundByPanda[id]
        end
        return false
    end

    local function beginEarthbound()
        local panda = GetTriggerUnit()
        local target = GetSpellTargetUnit()
        local id = GetHandleId(panda)

        if GetSpellAbilityId() ~= IDS.EARTH_EARTHBOUND or not target or
            target == panda or wouldCreateEarthboundCycle(panda, target) then
            return
        end

        clearEarthbound(panda)
        earthboundByPanda[id] = target
        UnitAddAbility(target, IDS.EARTHBOUND_BUFF_TARGET)
        UnitAddAbility(panda, IDS.EARTHBOUND_BUFF_PANDA)
        earthboundTimerByPanda[id] = GameTimer.after(EARTHBOUND_DURATION, function()
            clearEarthbound(panda)
        end)
    end

    local function redirectEarthboundDamage()
        local panda = GetTriggerUnit()
        local target = earthboundByPanda[GetHandleId(panda)]
        local attacker = GetEventDamageSource()
        local damage = GetEventDamage()
        local lightning = nil

        if suppressEarthboundDamage or damage <= 0.0 or not target or not attacker or
            GetUnitAbilityLevel(panda, IDS.EARTHBOUND_BUFF_PANDA) <= 0 then
            return false
        end
        if GetUnitTypeId(target) == 0 or GetWidgetLife(target) <= 0.405 then
            clearEarthbound(panda)
            return true
        end

        if BlzSetEventDamage then
            BlzSetEventDamage(0.0)
        end
        suppressEarthboundDamage = true
        UnitDamageTarget(attacker, target, damage, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
        suppressEarthboundDamage = false
        lightning = AddLightning(EARTHBOUND_LIGHTNING, true, GetUnitX(panda), GetUnitY(panda), GetUnitX(target), GetUnitY(target))
        if lightning then
            DestroyLightning(lightning)
        end
        return true
    end


    local function burningOilBaseDamage(level)
        if level == 1 then
            return 20.0
        elseif level == 2 then
            return 40.0
        elseif level == 3 then
            return 80.0
        elseif level == 4 then
            return 160.0
        elseif level >= 5 then
            return 320.0
        end
        return 0.0
    end

    local function burningOilImpactDamage(level)
        if level == 1 then
            return 5.0
        elseif level == 2 then
            return 10.0
        elseif level == 3 then
            return 20.0
        elseif level == 4 then
            return 40.0
        elseif level >= 5 then
            return 80.0
        end
        return 0.0
    end

    local function burningOilDamageMultiplier(level)
        if level == 1 then
            return 1.005
        elseif level == 2 then
            return 1.01
        elseif level == 3 then
            return 1.02
        elseif level == 4 then
            return 1.04
        elseif level >= 5 then
            return 1.08
        end
        return 1.0
    end

    local function stopBurningOil(target)
        local id = type(target) == "number" and target or GetHandleId(target)
        local state = burningOilTimerByTarget[id]

        if state then
            burningOilTimerByTarget[id] = nil
            if state.timer then
                state.timer:destroy()
            end
        end
    end

    local function dealPandaProcDamage(attacker, target, damage)
        if not attacker or not target or damage <= 0.0 then
            return
        end

        suppressPandaProcDamage = true
        UnitDamageTarget(attacker, target, damage, true, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
        suppressPandaProcDamage = false
    end

    local function startBurningOil(attacker, target, level)
        local targetId = GetHandleId(target)
        local state = burningOilTimerByTarget[targetId]

        if state then
            state.attacker = attacker
            state.level = level
            state.remaining = BURNING_OIL_DURATION
            return
        end

        state = {
            target = target,
            attacker = attacker,
            level = level,
            remaining = BURNING_OIL_DURATION,
            timer = nil
        }
        burningOilTimerByTarget[targetId] = state
        state.timer = GameTimer.every(BURNING_OIL_TICK, function(timer)
            local current = burningOilTimerByTarget[targetId]
            local tickDamage = 0.0

            if current ~= state or not isAlive(state.target) or
                not state.attacker or GetUnitTypeId(state.attacker) == 0 or
                GetUnitAbilityLevel(state.target, IDS.FIRE_BURNING_OIL_BUFF) <= 0 then
                if burningOilTimerByTarget[targetId] == state then
                    burningOilTimerByTarget[targetId] = nil
                end
                state.timer = nil
                timer:destroy()
                return
            end

            tickDamage = burningOilBaseDamage(state.level) * (BURNING_OIL_TICK / BURNING_OIL_DURATION)
            dealPandaProcDamage(state.attacker, state.target, tickDamage)
            state.remaining = state.remaining - BURNING_OIL_TICK
            if state.remaining <= 0.0 then
                burningOilTimerByTarget[targetId] = nil
                state.timer = nil
                timer:destroy()
            end
        end)
    end

    local function isNormalAttackDamage()
        if rawget(_G, "BlzGetEventIsAttack") and not BlzGetEventIsAttack() then
            return false
        end
        if rawget(_G, "BlzGetEventDamageType") and BlzGetEventDamageType() ~= DAMAGE_TYPE_NORMAL then
            return false
        end
        return true
    end

    local function applyBurningOil()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local level = 0
        local damage = 0.0

        if suppressPandaProcDamage or not target or not attacker or GetEventDamage() <= 0.0 then
            return
        end

        level = GetUnitAbilityLevel(attacker, IDS.FIRE_BURNING_OIL)
        if level >= 1 and isNormalAttackDamage() and
            tech(GetOwningPlayer(attacker), RESEARCH.BURNING_OIL) >= 1 then
            damage = burningOilImpactDamage(level)
            dealPandaProcDamage(attacker, target, damage)
            startBurningOil(attacker, target, level)
        end

        if level >= 1 and GetUnitAbilityLevel(target, IDS.FIRE_BURNING_OIL_BUFF) > 0 and BlzSetEventDamage then
            BlzSetEventDamage(GetEventDamage() * burningOilDamageMultiplier(level))
        end
    end

    local function applyEnflameShield()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local damage = GetEventDamage()
        local attackerId = 0
        local targetId = 0
        local shield = 0.0
        local balance = 0.0
        local enflameLevel = 0

        if suppressPandaProcDamage or not target or damage <= 0.0 then
            return
        end

        if attacker and GetUnitAbilityLevel(attacker, IDS.FIRE_FORM_BUFF) > 0 and IsUnitEnemy(attacker, GetOwningPlayer(target)) then
            enflameLevel = GetUnitAbilityLevel(attacker, IDS.FIRE_ENFLAME)
            attackerId = GetHandleId(attacker)
            shield = (enflameShieldByUnit[attackerId] or 0.0) + damage * (0.20 + 0.10 * enflameLevel)
            if shield > 100.0 + 125.0 * enflameLevel then
                shield = 100.0 + 125.0 * enflameLevel
            end
            enflameShieldByUnit[attackerId] = shield
            enflameUnitById[attackerId] = attacker
        end

        targetId = GetHandleId(target)
        shield = enflameShieldByUnit[targetId] or 0.0
        if GetUnitAbilityLevel(target, IDS.FIRE_FORM_BUFF) > 0 and shield > 0.0 and BlzSetEventDamage then
            balance = shield - damage
            if balance >= 0.0 then
                enflameShieldByUnit[targetId] = balance
                if balance <= 0.0 then
                    enflameUnitById[targetId] = nil
                end
                BlzSetEventDamage(0.0)
            else
                enflameShieldByUnit[targetId] = 0.0
                enflameUnitById[targetId] = nil
                BlzSetEventDamage(damage - shield)
            end
        end
    end

    local function applyVolcanicActivity()
        local attacker = GetEventDamageSource()
        local level = 0
        local ability = nil
        local maxLevels = 0

        if suppressPandaProcDamage or not attacker or GetUnitTypeId(attacker) == 0 or GetEventDamage() <= 0.0 or
            not isNormalAttackDamage() or
            tech(GetOwningPlayer(attacker), RESEARCH.VOLCANIC_ACTIVITY) <= 0 then
            return
        end

        level = GetUnitAbilityLevel(attacker, IDS.VOLCANIC_ACTIVITY)
        if level <= 0 then
            return
        end

        if BlzGetUnitAbility and BlzGetAbilityIntegerField then
            ability = BlzGetUnitAbility(attacker, IDS.VOLCANIC_ACTIVITY)
            if ability then
                maxLevels = BlzGetAbilityIntegerField(ability, ABILITY_IF_LEVELS)
            end
        end
        if maxLevels <= 0 then
            maxLevels = 4
        end

        if level < maxLevels then
            SetUnitAbilityLevel(attacker, IDS.VOLCANIC_ACTIVITY, level + 1)
        else
            SetUnitAbilityLevel(attacker, IDS.VOLCANIC_ACTIVITY, 1)
        end
    end

    local function applyEmpoweredHaste()
        local caster = GetTriggerUnit()
        local target = GetSpellTargetUnit()
        local level = 0
        local duration = 0.0

        if GetSpellAbilityId() ~= IDS.STORM_HASTE or not target then
            return
        end

        level = GetUnitAbilityLevel(caster, IDS.STORM_HASTE)
        if level < 3 then
            duration = 3.0
        else
            duration = 6.0
        end

        AbilityMeta.increaseMoveSpeedPercent(target, duration, 0.30)

        if level == 4 then
            healUnit(target, 185.0)
        end
    end

    local function isTwinPointOrder(panda)
        local order = GetUnitCurrentOrder(panda)
        return order == ORDER_SMART or order == ORDER_PATROL or order == ORDER_MOVE
    end

    local function cleanupTwinDummy(dummy, dummyId)
        local panda = twinPandaByDummy[dummyId]

        twinPandaByDummy[dummyId] = nil
        twinActiveByDummy[dummyId] = nil
        dummy = dummy or twinDummyById[dummyId]
        twinDummyById[dummyId] = nil
        if panda and GetUnitTypeId(panda) ~= 0 then
            UnitRemoveAbility(panda, IDS.FIRE_TWIN_GHOST)
        end
        if dummy and GetUnitTypeId(dummy) ~= 0 then
            RemoveUnit(dummy)
        end
    end

    local function castTwinFigure()
        local panda = GetTriggerUnit()
        local x = 0.0
        local y = 0.0
        local dummy = nil
        local dummyId = 0

        if GetSpellAbilityId() ~= IDS.FIRE_TWIN or not isRealPanda(panda) then
            return
        end

        x = GetUnitX(panda)
        y = GetUnitY(panda)
        UnitAddAbility(panda, IDS.FIRE_TWIN_GHOST)

        dummy = CreateUnit(GetOwningPlayer(panda), IDS.FIRE_TWIN_DUMMY, x, y, 90.0)
        UnitAddAbility(dummy, IDS.FIRE_TWIN_ILLUSION)
        SetUnitAbilityLevel(dummy, IDS.FIRE_TWIN_ILLUSION, GetUnitAbilityLevel(panda, IDS.FIRE_TWIN))
        dummyId = GetHandleId(dummy)
        twinPandaByDummy[dummyId] = panda
        twinActiveByDummy[dummyId] = true
        twinDummyById[dummyId] = dummy

        GameTimer.after(0.05, function()
            if twinPandaByDummy[dummyId] == panda and isAlive(dummy) then
                IssueTargetOrderById(dummy, ORDER_TWIN_GHOST, panda)
            end
            if panda and GetUnitTypeId(panda) ~= 0 then
                UnitRemoveAbility(panda, IDS.FIRE_TWIN_GHOST)
            end
        end)
        GameTimer.after(2.0, function()
            if twinPandaByDummy[dummyId] ~= nil or twinActiveByDummy[dummyId] ~= nil then
                cleanupTwinDummy(dummy, dummyId)
            end
        end)
    end

    local function onTwinSummon()
        local dummy = GetSummoningUnit()
        local twin = GetSummonedUnit()
        local dummyId = dummy and GetHandleId(dummy) or 0
        local panda = twinPandaByDummy[dummyId]
        local x = 0.0
        local y = 0.0
        local facing = 0.0
        local tx = 0.0
        local ty = 0.0

        if not panda or not twinActiveByDummy[dummyId] or not dummy or not twin or
            GetUnitTypeId(dummy) ~= IDS.FIRE_TWIN_DUMMY or GetUnitTypeId(twin) ~= IDS.BASIC_SKIN then
            if dummyId ~= 0 and twinPandaByDummy[dummyId] then
                cleanupTwinDummy(dummy, dummyId)
            end
            return
        end

        if BlzSetUnitSkin then
            BlzSetUnitSkin(twin, IDS.FIRE_SKIN)
        end
        twinActiveByDummy[dummyId] = false

        if isTwinPointOrder(panda) then
            x = GetUnitX(panda)
            y = GetUnitY(panda)
            facing = GetUnitFacing(panda)
            tx = offsetX(x, facing, 650.0)
            ty = offsetY(y, facing, 650.0)
            IssuePointOrderById(twin, GetUnitCurrentOrder(panda), tx, ty)
        end

        UnitAddAbility(dummy, IDS.FIRE_TWIN_ILLUSION)
        IssueTargetOrderById(dummy, ORDER_TWIN_ILLUSION, twin)
        GameTimer.after(0.25, function()
            cleanupTwinDummy(dummy, dummyId)
        end)
    end

    local function skystrikeImpact(caster, x, y, damage)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRange(group, x, y, SKYSTRIKE_IMPACT_AOE, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if IsUnitEnemy(unit, GetOwningPlayer(caster)) and distanceBetween(x, y, GetUnitX(unit), GetUnitY(unit)) <= SKYSTRIKE_IMPACT_AOE then
                if GetUnitAbilityLevel(unit, IDS.WARD) > 0 then
                    UnitDamageTarget(caster, unit, damage * 0.50, false, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                else
                    UnitDamageTarget(caster, unit, damage, false, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                end
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        DestroyEffect(AddSpecialEffect(SKYSTRIKE_HIT_EFFECT, x, y))
    end

    local function launchSkystrikeMissile(caster, sx, sy, tx, ty, damage)
        local missileSystem = rawget(_G, "MissileSystem")

        if missileSystem and missileSystem.launch then
            missileSystem.launch({
                x = sx,
                y = sy,
                z = terrainZ(sx, sy) + 70.0,
                targetX = tx,
                targetY = ty,
                speed = SKYSTRIKE_SPEED,
                collision = 32.0,
                model = SKYSTRIKE_MODEL,
                onImpact = function(_, impactX, impactY)
                    skystrikeImpact(caster, impactX, impactY, damage)
                end
            })
            return
        end

        -- Fallback, falls das MissileSystem aus irgendeinem Grund nicht geladen ist.
        skystrikeImpact(caster, tx, ty, damage)
    end

    local function createSkystrikeMissile(caster, sourceX, sourceY, targetX, targetY)
        local angleTarget = GetRandomReal(0.0, 360.0)
        local distTarget = GetRandomReal(0.0, SKYSTRIKE_AOE)
        local angleSource = GetRandomReal(0.0, 360.0)
        local distSource = GetRandomReal(0.0, SKYSTRIKE_AOE)
        local sx = offsetX(sourceX, angleSource, distSource)
        local sy = offsetY(sourceY, angleSource, distSource)
        local tx = offsetX(targetX, angleTarget, distTarget)
        local ty = offsetY(targetY, angleTarget, distTarget)
        local damage = SKYSTRIKE_BASE_DAMAGE

        if GetUnitAbilityLevel(caster, IDS.STORM_SKY_STRIKE) > 2 then
            damage = 250.0
        end
        launchSkystrikeMissile(caster, sx, sy, tx, ty, damage)
    end

    local function castSkystrike()
        local caster = GetTriggerUnit()
        local sourceX = 0.0
        local sourceY = 0.0
        local targetX = 0.0
        local targetY = 0.0
        local maxMissiles = 8
        local count = 0
        local timer = nil

        if GetSpellAbilityId() ~= IDS.STORM_SKY_STRIKE then
            return
        end

        sourceX = GetUnitX(caster)
        sourceY = GetUnitY(caster)
        targetX = GetSpellTargetX()
        targetY = GetSpellTargetY()
        if GetUnitAbilityLevel(caster, IDS.STORM_SKY_STRIKE) > 1 then
            maxMissiles = 14
        end

        timer = CreateTimer()
        TimerStart(timer, 1.0 / SKYSTRIKE_MISSILES_PER_SECOND, true, function()
            if count >= maxMissiles then
                PauseTimer(timer)
                DestroyTimer(timer)
                return
            end
            createSkystrikeMissile(caster, sourceX, sourceY, targetX, targetY)
            count = count + 1
        end)
    end

    local function onBuilderSpawn(playerData, unit)
        if not unit or not isPanda(playerData) then
            return
        end

        local i = 1
        while i <= #PERMANENT_ABILITIES do
            UnitMakeAbilityPermanent(unit, true, PERMANENT_ABILITIES[i])
            i = i + 1
        end
        BlzUnitDisableAbility(unit, IDS.HIDDEN_HARVEST, true, true)
        BlzUnitDisableAbility(unit, IDS.BOOK_STORM, true, true)
        BlzUnitDisableAbility(unit, IDS.STORM_SKY_STRIKE, true, true)
        BlzUnitDisableAbility(unit, IDS.STORM_WIND_WALK, true, true)
        BlzUnitDisableAbility(unit, IDS.STORM_HASTE, true, true)
        BlzUnitDisableAbility(unit, IDS.STORM_TEMPEST, true, true)
        BlzUnitDisableAbility(unit, IDS.STORM_AIR, true, true)
        BlzUnitDisableAbility(unit, IDS.STORM_FLEET_FOOT, true, false)
        BlzUnitDisableAbility(unit, IDS.STORM_MARK_OF_WIND, true, true)
        BlzUnitDisableAbility(unit, IDS.STORM_FLEET_FOOT_ALLY, true, true)
        BlzUnitDisableAbility(unit, IDS.BOOK_EARTH, true, true)
        BlzUnitDisableAbility(unit, IDS.EARTH_BOULDER_SLAM, true, true)
        BlzUnitDisableAbility(unit, IDS.EARTH_PILLAR, true, true)
        BlzUnitDisableAbility(unit, IDS.EARTH_EARTHBOUND, true, true)
        BlzUnitDisableAbility(unit, IDS.EARTH_EARTHQUAKE, true, true)
        BlzUnitDisableAbility(unit, IDS.EARTH_STONESKIN, true, true)
        BlzUnitDisableAbility(unit, IDS.EARTH_BORN, true, true)
        BlzUnitDisableAbility(unit, IDS.EARTH_ROCK_SOLID, true, true)
        BlzUnitDisableAbility(unit, IDS.EARTH_ROCK_SOLID_ORB, true, true)
        BlzUnitDisableAbility(unit, IDS.BOOK_FIRE, true, true)
        BlzUnitDisableAbility(unit, IDS.FIRE_BREATH, true, true)
        BlzUnitDisableAbility(unit, IDS.FIRE_FURY, true, true)
        BlzUnitDisableAbility(unit, IDS.FIRE_DANCE, true, true)
        BlzUnitDisableAbility(unit, IDS.FIRE_TWIN, true, true)
        BlzUnitDisableAbility(unit, IDS.FIRE_ENFLAME, true, true)
        BlzUnitDisableAbility(unit, IDS.FIRE_BURNING_OIL, true, true)
        BlzUnitDisableAbility(unit, IDS.FIRE_EMBERHEART, true, true)

        formByUnit[GetHandleId(unit)] = FORM_BASIC
        trackedPandasById[GetHandleId(unit)] = unit
        setupStructures(playerData:player(), FORM_BASIC)
        setupStats(unit, playerData:player(), FORM_BASIC)
        swapForm(unit, playerData:player(), FORM_BASIC)
        debugMessage(unit, "Panda initialized -> Basic | " .. abilityStateText(unit))
    end

    local function onSpellEffect()
        local unit = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()
        local id = GetHandleId(unit)
        local form = wantedForm(abilityId, formByUnit[id] or FORM_BASIC)

        if form >= 0 then
            applyForm(unit, form, abilityId)
        end

        castSkystrike()
        applyEmpoweredHaste()
        castTwinFigure()
    end

    local function onDamaged()
        local unit = GetTriggerUnit()
        local level = GetUnitAbilityLevel(unit, IDS.EARTH_STONESKIN)
        local rockReduction = 0.0
        local reduced = 0.0

        if redirectEarthboundDamage() then
            return
        end

        applyBurningOil()
        applyEnflameShield()
        applyVolcanicActivity()

        if (formByUnit[GetHandleId(unit)] or FORM_BASIC) ~= FORM_EARTH then
            return
        end
        if BlzGetEventDamageType and BlzGetEventDamageType() ~= DAMAGE_TYPE_NORMAL then
            return
        end

        if level == 1 then
            reduced = GetEventDamage() - 5.0
            rockReduction = 20.0
        elseif level == 2 then
            reduced = GetEventDamage() - 10.0
            rockReduction = 25.0
        elseif level == 3 then
            reduced = GetEventDamage() - 15.0
            rockReduction = 30.0
        elseif level >= 4 then
            reduced = GetEventDamage() - 20.0
            rockReduction = 40.0
        else
            return
        end

        if BlzSetEventDamage then
            if reduced > 24.0 then
                reduced = reduced - rockReduction
            else
                reduced = 25.0 - rockReduction
            end
            if reduced < 0.0 then
                reduced = 0.0
            end
            BlzSetEventDamage(reduced)
        end
    end

    local function onIssuedOrder(eventKind)
        local unit = GetTriggerUnit()
        local orderId = GetIssuedOrderId()

        if not unit or not isPandaUnit(unit) then
            return
        end
        if eventKind == "point" and
            (orderId == STRUCTURES.EARTH_WALL or orderId == STRUCTURES.EARTH_WALL_ADVANCED) then
            lastEarthWallBuilderByPlayer[GetPlayerId(GetOwningPlayer(unit))] = unit
        end
        if (formByUnit[GetHandleId(unit)] or FORM_BASIC) ~= FORM_STORM then
            return
        end
        if GetUnitAbilityLevel(unit, IDS.STORM_WIND_WALK_BUFF) <= 0 then
            return
        end

        if orderId == ORDER_SMART and eventKind == "point" then
            return
        end
        if orderId ~= ORDER_MOVE and orderId ~= ORDER_PATROL and
            orderId ~= ORDER_STOP and orderId ~= ORDER_HOLD_POSITION then
            UnitRemoveAbility(unit, IDS.STORM_WIND_WALK_BUFF)
        end
    end

    local function recoverEarthPandasAfterWallCancel()
        local cancelled = rawget(_G, "GetCancelledStructure") and GetCancelledStructure() or GetTriggerUnit()
        local cancelledId = cancelled and GetUnitTypeId(cancelled) or 0
        local player = cancelled and GetOwningPlayer(cancelled) or nil
        local panda = player and lastEarthWallBuilderByPlayer[GetPlayerId(player)] or nil

        if not player or (cancelledId ~= STRUCTURES.EARTH_WALL and cancelledId ~= STRUCTURES.EARTH_WALL_ADVANCED) then
            return
        end
        lastEarthWallBuilderByPlayer[GetPlayerId(player)] = nil

        if isRealPanda(panda) and (formByUnit[GetHandleId(panda)] or FORM_BASIC) == FORM_EARTH then
            scheduleControlRecovery(panda)
            return
        end

        GameTimer.after(0.03, function()
            local group = CreateGroup()
            local unit = nil

            GroupEnumUnitsOfPlayer(group, player, nil)
            unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                if isPandaUnit(unit) and (formByUnit[GetHandleId(unit)] or FORM_BASIC) == FORM_EARTH then
                    scheduleControlRecovery(unit)
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function cleanupUnitState(unit)
        local id = unit and GetHandleId(unit) or 0
        local timer = nil
        local panda = nil
        local dummyIds = {}

        if id == 0 then
            return
        end

        stopBurningOil(id)
        enflameShieldByUnit[id] = nil
        enflameUnitById[id] = nil
        if twinPandaByDummy[id] then
            cleanupTwinDummy(unit, id)
        end

        if trackedPandasById[id] == unit or formByUnit[id] ~= nil then
            timer = formTimerByUnit[id]
            formTimerByUnit[id] = nil
            if timer then
                timer:destroy()
            end
            stopCycloneMonitor(unit)
            clearEarthbound(unit)
            formByUnit[id] = nil
            formTransitionByUnit[id] = nil
            formTransitionTokenByUnit[id] = nil
            controlRecoveryTokenByUnit[id] = nil
            trackedPandasById[id] = nil
            if lastEarthWallBuilderByPlayer[GetPlayerId(GetOwningPlayer(unit))] == unit then
                lastEarthWallBuilderByPlayer[GetPlayerId(GetOwningPlayer(unit))] = nil
            end

            for dummyId, ownerPanda in pairs(twinPandaByDummy) do
                if ownerPanda == unit then
                    dummyIds[#dummyIds + 1] = dummyId
                end
            end
            table.sort(dummyIds)
            for _, dummyId in ipairs(dummyIds) do
                cleanupTwinDummy(nil, dummyId)
            end
        end

        for pandaId, target in pairs(earthboundByPanda) do
            if target == unit then
                panda = trackedPandasById[pandaId]
                if panda then
                    clearEarthbound(panda)
                else
                    earthboundByPanda[pandaId] = nil
                    timer = earthboundTimerByPanda[pandaId]
                    earthboundTimerByPanda[pandaId] = nil
                    if timer then
                        timer:destroy()
                    end
                end
            end
        end
    end

    if rawget(_G, "Command") then
        Command["-pandadebug"].register(function(args)
            local player = args:player()
            local playerId = GetPlayerId(player)
            local enabled = not debugByPlayerId[playerId]

            if not DebugCheatPack.isEnabled(player) then
                Command.say(player, "|cffff6060Panda debug is only available in debug lobbies.|r")
                return
            end

            debugByPlayerId[playerId] = enabled
            Command.say(player, enabled and
                "|cff80ff80Panda form debug enabled.|r" or
                "|cffffcc00Panda form debug disabled.|r")

            if enabled then
                local found = 0
                for _, panda in pairs(trackedPandasById) do
                    if panda and GetUnitTypeId(panda) ~= 0 and GetOwningPlayer(panda) == player then
                        found = found + 1
                        debugMessage(panda,
                            "Snapshot form=" .. formName(formByUnit[GetHandleId(panda)] or FORM_BASIC) ..
                            " lock=" .. (formTransitionByUnit[GetHandleId(panda)] and "yes" or "no") ..
                            " | " .. abilityStateText(panda))
                    end
                end
                if found == 0 then
                    Command.say(player,
                        "|cffff6060Panda debug: no tracked Panda found. The builder-spawn callback did not complete.|r")
                end
            end
        end, "Debug: traces Panda form, spellbook and Harvest transitions.")
    end

    RacePickSystem.onBuilderSpawn(onBuilderSpawn)

    local spellTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local researchStartTrigger = CreateTrigger()
    local researchCancelTrigger = CreateTrigger()
    local researchFinishTrigger = CreateTrigger()
    local immediateOrderTrigger = CreateTrigger()
    local pointOrderTrigger = CreateTrigger()
    local targetOrderTrigger = CreateTrigger()
    local summonTrigger = CreateTrigger()
    local constructCancelTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(researchStartTrigger, Player(i), EVENT_PLAYER_UNIT_RESEARCH_START, nil)
        TriggerRegisterPlayerUnitEvent(researchCancelTrigger, Player(i), EVENT_PLAYER_UNIT_RESEARCH_CANCEL, nil)
        TriggerRegisterPlayerUnitEvent(researchFinishTrigger, Player(i), EVENT_PLAYER_UNIT_RESEARCH_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(immediateOrderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(pointOrderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(targetOrderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(summonTrigger, Player(i), EVENT_PLAYER_UNIT_SUMMON, nil)
        TriggerRegisterPlayerUnitEvent(constructCancelTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_CANCEL, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end

    TriggerAddAction(spellTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(function()
                onSpellEffect()
                beginEarthbound()
            end)
        else
            onSpellEffect()
            beginEarthbound()
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

    TriggerAddAction(researchStartTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onResearchStart)
        else
            onResearchStart()
        end
    end)

    TriggerAddAction(researchCancelTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onResearchCancel)
        else
            onResearchCancel()
        end
    end)

    TriggerAddAction(researchFinishTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onResearchFinish)
        else
            onResearchFinish()
        end
    end)

    local function guardedOrder(kind)
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onIssuedOrder, kind)
        else
            onIssuedOrder(kind)
        end
    end

    TriggerAddAction(immediateOrderTrigger, function() guardedOrder("immediate") end)
    TriggerAddAction(pointOrderTrigger, function() guardedOrder("point") end)
    TriggerAddAction(targetOrderTrigger, function() guardedOrder("target") end)

    TriggerAddAction(summonTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onTwinSummon)
        else
            onTwinSummon()
        end
    end)

    TriggerAddAction(constructCancelTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(recoverEarthPandasAfterWallCancel)
        else
            recoverEarthPandasAfterWallCancel()
        end
    end)

    TriggerAddAction(deathTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(cleanupUnitState, GetTriggerUnit())
        else
            cleanupUnitState(GetTriggerUnit())
        end
    end)

    GameTimer.every(1.0, function()
        local removed = {}
        local staleEarthbound = {}

        for id, unit in pairs(trackedPandasById) do
            if not unit or GetUnitTypeId(unit) == 0 then
                removed[#removed + 1] = unit
                if not unit then
                    trackedPandasById[id] = nil
                    formByUnit[id] = nil
                    formTimerByUnit[id] = nil
                end
            end
        end
        for id, unit in pairs(enflameUnitById) do
            if not unit or GetUnitTypeId(unit) == 0 then
                enflameUnitById[id] = nil
                enflameShieldByUnit[id] = nil
            end
        end
        for pandaId, target in pairs(earthboundByPanda) do
            if not target or GetUnitTypeId(target) == 0 then
                staleEarthbound[#staleEarthbound + 1] = pandaId
            end
        end
        table.sort(staleEarthbound)
        table.sort(removed, function(left, right)
            return GetHandleId(left) < GetHandleId(right)
        end)
        for _, pandaId in ipairs(staleEarthbound) do
            local panda = trackedPandasById[pandaId]
            if panda then
                clearEarthbound(panda)
            end
        end
        for _, unit in ipairs(removed) do
            if unit then
                cleanupUnitState(unit)
            end
        end
    end)

    AbilityRegistry.registerRace("Panda", "builder", {
        notes = "Panda builder/unit abilities ported from PandaRace and the first pass of PandaTransformations.",
        abilities = {
            {
                name = "Panda permanent abilities",
                source = "library PandaRace",
                behavior = "Makes Storm, Earth, Fire, generic harvest/repair/gold and form abilities permanent on spawn."
            },
            {
                name = "Panda Transformations",
                source = "library PandaTransformations",
                behavior = "Switches between Basic, Storm, Earth and Fire forms, updates visible abilities, skin, form structures, cooldowns and temporary form duration."
            },
            {
                name = "Earth Stoneskin",
                id = IDS.EARTH_STONESKIN,
                source = "library PandaTransformations and RockSolidStrategy",
                behavior = "Earth form reduces normal damage with the old Stoneskin floor and Rock Solid bonus reduction."
            },
            {
                name = "Earthbound",
                id = IDS.EARTH_EARTHBOUND,
                source = "library Earthbound",
                behavior = "Links Panda to a target for 6 seconds and redirects incoming Panda damage to that target."
            },
            {
                name = "Burning Oil",
                id = IDS.FIRE_BURNING_OIL,
                source = "library BurningOil",
                behavior = "Normal attacks with Burning Oil research deal extra magic damage, add the burning buff DOT and increase damage taken while burning."
            },
            {
                name = "Aflame Shield / Enflame",
                id = IDS.FIRE_ENFLAME,
                source = "library AflameShield",
                behavior = "Fire Form damage builds a capped shield; the shield absorbs incoming damage until depleted."
            },
            {
                name = "Twin Figure",
                id = IDS.FIRE_TWIN,
                source = "library TwinFigure",
                behavior = "Creates the Fire-skinned illusion and forwards Panda move/smart/patrol orders to it."
            },
            {
                name = "Volcanic Activity",
                id = IDS.VOLCANIC_ACTIVITY,
                source = "library VolcanicActivity",
                behavior = "Cycles the Volcanic Activity ability level on damage dealt."
            },
            {
                name = "Skystrike",
                id = IDS.STORM_SKY_STRIKE,
                source = "library Skystrike",
                behavior = "Launches timed missiles around the target point, damaging enemies in impact AOE and dealing half damage to wards."
            },
            {
                name = "Empowered Haste",
                id = IDS.STORM_HASTE,
                source = "library EmpoweredHaste",
                behavior = "Haste gives +30% movement speed for 3/6 seconds and heals 185 at level 4."
            },
            {
                name = "Panda Oaths",
                source = "library PandaTransformations",
                behavior = "Starting an oath locks the other oaths; finishing an oath refreshes current form stats and unlocks the old oath ultimate structures."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
