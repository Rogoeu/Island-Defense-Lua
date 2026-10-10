if Debug and Debug.beginFile then Debug.beginFile("Systems/HeroLevelBonuses") end

OnInit("HeroLevelBonuses", function(import)
    import.strict("UnitFilter")

    local IDS = {
        TITAN_DAMAGE_ITEM = FourCC("I078"),
        HUNTER_DAMAGE_ITEM = FourCC("I027"),
        BUILDER_DAMAGE_RESEARCH = FourCC("RPAD"),
        BUILDER_ARMOR_RESEARCH = FourCC("R05B")
    }

    local SPECIAL_BUILDER_LEVEL_UNITS = {
        [FourCC("O01Q")] = true,
        [FourCC("O01R")] = true,
        [FourCC("O054")] = true,
        [FourCC("H05U")] = true,
        [FourCC("H05Z")] = true,
        [FourCC("O04H")] = true
    }

    local TITAN_ARMOR_PER_LEVEL = 1.5
    local HUNTER_ARMOR_PER_LEVEL = 1.0
    local BUILDER_DAMAGE_RESEARCH_PER_LEVEL = 2
    local BUILDER_ARMOR_RESEARCH_PER_LEVEL = 1

    local HeroLevelBonuses = {}

    local function unitDefense(unit)
        if BlzGetUnitRealField then
            return BlzGetUnitRealField(unit, UNIT_RF_DEFENSE)
        end
        return 0.0
    end

    local function setUnitDefense(unit, amount)
        if BlzSetUnitRealField then
            BlzSetUnitRealField(unit, UNIT_RF_DEFENSE, amount)
        elseif BlzSetUnitRealFieldBJ then
            BlzSetUnitRealFieldBJ(unit, UNIT_RF_DEFENSE, amount)
        end
    end

    local function addArmor(unit, amount)
        setUnitDefense(unit, unitDefense(unit) + amount)
    end

    local function addResearch(player, researchId, amount)
        SetPlayerTechResearched(player, researchId, GetPlayerTechCount(player, researchId, false) + amount)
    end

    local function isTitanous(unit)
        return unit and GetUnitAbilityLevel(unit, FourCC("CTIT")) > 0
    end

    local function isSpecialBuilder(unit)
        return unit and SPECIAL_BUILDER_LEVEL_UNITS[GetUnitTypeId(unit)] == true
    end

    local function apply(unit)
        local owner = nil

        if not unit or not IsUnitType(unit, UNIT_TYPE_HERO) then
            return false
        end

        owner = GetOwningPlayer(unit)

        if isTitanous(unit) then
            UnitAddItemById(unit, IDS.TITAN_DAMAGE_ITEM)
            addArmor(unit, TITAN_ARMOR_PER_LEVEL)
            return true
        elseif UnitFilter.isTitanHunter(unit) then
            UnitAddItemById(unit, IDS.HUNTER_DAMAGE_ITEM)
            addArmor(unit, HUNTER_ARMOR_PER_LEVEL)
            return true
        elseif isSpecialBuilder(unit) then
            addResearch(owner, IDS.BUILDER_DAMAGE_RESEARCH, BUILDER_DAMAGE_RESEARCH_PER_LEVEL)
            addResearch(owner, IDS.BUILDER_ARMOR_RESEARCH, BUILDER_ARMOR_RESEARCH_PER_LEVEL)
            return true
        end

        return false
    end

    function HeroLevelBonuses.apply(unit)
        return apply(unit)
    end

    local function levelingUnit()
        if rawget(_G, "GetLevelingUnit") then
            return GetLevelingUnit()
        end
        return GetTriggerUnit()
    end

    local function onHeroLevel()
        apply(levelingUnit())
    end

    local trigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_HERO_LEVEL, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onHeroLevel)
        else
            onHeroLevel()
        end
    end)

    HeroLevelBonuses.ids = IDS

    _G.HeroLevelBonuses = HeroLevelBonuses
end)

if Debug and Debug.endFile then Debug.endFile() end
