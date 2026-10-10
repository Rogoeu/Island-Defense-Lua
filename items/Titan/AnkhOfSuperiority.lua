if Debug and Debug.beginFile then Debug.beginFile("items/Titan/AnkhOfSuperiority") end

OnInit("TitanItemAnkhOfSuperiority", function()
    local IDS = {
        ANKH_SUPERIORITY = FourCC("I07A"),
        ANKH_BONUS = FourCC("AD20")
    }

    local TitanItemAnkhOfSuperiority = {}
    local bonusGrantedByUnit = {}

    local function ensureAnkhBonus(unit)
        if not unit or GetUnitTypeId(unit) == 0 or not IsUnitType(unit, UNIT_TYPE_HERO) then
            return
        end

        if GetUnitAbilityLevel(unit, IDS.ANKH_BONUS) <= 0 then
            UnitAddAbility(unit, IDS.ANKH_BONUS)
        end
        UnitMakeAbilityPermanent(unit, true, IDS.ANKH_BONUS)
    end

    local function apply(unit, item)
        if not unit or not item or GetItemTypeId(item) ~= IDS.ANKH_SUPERIORITY then
            return
        end

        if IsUnitType(unit, UNIT_TYPE_HERO) then
            SetHeroStr(unit, GetHeroStr(unit, false) + 5, true)
            SetHeroAgi(unit, GetHeroAgi(unit, false) + 5, true)
            SetHeroInt(unit, GetHeroInt(unit, false) + 5, true)
            bonusGrantedByUnit[GetHandleId(unit)] = true
            ensureAnkhBonus(unit)
        else
            RemoveItem(item)
            UnitAddItemById(unit, IDS.ANKH_SUPERIORITY)
        end
    end

    local function onItemUse()
        apply(GetTriggerUnit(), GetManipulatedItem())
    end

    local function onHeroRevive()
        local unit = GetTriggerUnit()

        if unit and bonusGrantedByUnit[GetHandleId(unit)] then
            ensureAnkhBonus(unit)
        end
    end

    local useTrigger = CreateTrigger()
    local reviveTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(useTrigger, Player(i), EVENT_PLAYER_UNIT_USE_ITEM, nil)
        TriggerRegisterPlayerUnitEvent(reviveTrigger, Player(i), EVENT_PLAYER_HERO_REVIVE_FINISH, nil)
        i = i + 1
    end

    TriggerAddAction(useTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onItemUse)
        else
            onItemUse()
        end
    end)

    TriggerAddAction(reviveTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onHeroRevive)
        else
            onHeroRevive()
        end
    end)

    TitanItemAnkhOfSuperiority.ids = IDS
    TitanItemAnkhOfSuperiority.apply = apply

    _G.TitanItemAnkhOfSuperiority = TitanItemAnkhOfSuperiority
end)

if Debug and Debug.endFile then Debug.endFile() end
