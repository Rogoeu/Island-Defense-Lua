if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/RadioactiveStructureAbilities") end

OnInit("RadioactiveStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    local IDS = {
        MAGIC_MODULE_ENHANCED = FourCC("A0QI"),
        MAGIC_MODULE_SUPER = FourCC("A05J"),
        MAGIC_MODULE_MEGA = FourCC("A0QJ"),
        FROST_MODULE = FourCC("A0F1"),
        OVERLOAD_MODULE = FourCC("A05C"),
        RAPID_MODULE = FourCC("A0F3"),
        MODULE_IMMUNITY_BUFF = FourCC("B084"),
        ULTRA_MODULE_RESEARCH = FourCC("R03S"),
        MAGIC_SUPER_LUMBER = FourCC("h03Y"),
        MAGIC_MEGA_GOLD = FourCC("h04B"),
        FROST_SUPER_LUMBER = FourCC("h03T"),
        FROST_MEGA_GOLD = FourCC("h04C"),
        OVERLOAD_SUPER_LUMBER = FourCC("h047"),
        OVERLOAD_MEGA_GOLD = FourCC("h04A"),
        RAPID_SUPER_LUMBER = FourCC("h048"),
        RAPID_MEGA_GOLD = FourCC("h049")
    }

    local MODULES = {
        [IDS.MAGIC_SUPER_LUMBER] = IDS.MAGIC_MODULE_MEGA,
        [IDS.MAGIC_MEGA_GOLD] = IDS.MAGIC_MODULE_MEGA,
        [IDS.FROST_SUPER_LUMBER] = IDS.FROST_MODULE,
        [IDS.FROST_MEGA_GOLD] = IDS.FROST_MODULE,
        [IDS.OVERLOAD_SUPER_LUMBER] = IDS.OVERLOAD_MODULE,
        [IDS.OVERLOAD_MEGA_GOLD] = IDS.OVERLOAD_MODULE,
        [IDS.RAPID_SUPER_LUMBER] = IDS.RAPID_MODULE,
        [IDS.RAPID_MEGA_GOLD] = IDS.RAPID_MODULE
    }

    local function setMana(unit, value)
        if value < 0.0 then
            value = 0.0
        end
        SetUnitState(unit, UNIT_STATE_MANA, value)
    end

    local function magicDrain(attacker)
        if GetUnitAbilityLevel(attacker, IDS.MAGIC_MODULE_ENHANCED) > 0 then
            return 6.0
        elseif GetUnitAbilityLevel(attacker, IDS.MAGIC_MODULE_SUPER) > 0 then
            return 12.0
        elseif GetUnitAbilityLevel(attacker, IDS.MAGIC_MODULE_MEGA) > 0 then
            if GetPlayerTechCount(GetOwningPlayer(attacker), IDS.ULTRA_MODULE_RESEARCH, false) == 1 then
                return 36.0
            end
            return 24.0
        end
        return 0.0
    end

    local function updateModule(unit)
        local abilityId = MODULES[GetUnitTypeId(unit)]
        local level = 0

        if not abilityId or GetUnitAbilityLevel(unit, abilityId) <= 0 then
            return
        end

        level = GetPlayerTechCount(GetOwningPlayer(unit), IDS.ULTRA_MODULE_RESEARCH, true) + 1
        SetUnitAbilityLevel(unit, abilityId, level)
    end

    local function onConstructOrUpgrade()
        updateModule(GetTriggerUnit())
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local drain = 0.0

        if not target or not attacker or GetUnitTypeId(attacker) == 0 then
            return
        end

        drain = magicDrain(attacker)
        if drain <= 0.0 then
            return
        end
        if GetUnitAbilityLevel(target, IDS.MODULE_IMMUNITY_BUFF) > 0 or GetUnitState(target, UNIT_STATE_MANA) <= 0.0 then
            return
        end

        setMana(target, GetUnitState(target, UNIT_STATE_MANA) - drain)
    end

    local constructTrigger = CreateTrigger()
    local upgradeTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(constructTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(upgradeTrigger, Player(i), EVENT_PLAYER_UNIT_UPGRADE_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        i = i + 1
    end

    TriggerAddAction(constructTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onConstructOrUpgrade)
        else
            onConstructOrUpgrade()
        end
    end)

    TriggerAddAction(upgradeTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onConstructOrUpgrade)
        else
            onConstructOrUpgrade()
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

    AbilityRegistry.registerRace("Radioactive", "structures", {
        notes = "Radioactive tower/building abilities ported from StructureAbilities and RadioMagicModule.",
        abilities = {
            {
                name = "Radioactive Module Levels",
                id = IDS.ULTRA_MODULE_RESEARCH,
                source = "global StructureAbilities",
                behavior = "Radioactive Magic, Frost, Overload and Rapid module towers update their module ability level from R03S on construct/upgrade finish."
            },
            {
                name = "Magic Module Mana Drain",
                id = IDS.MAGIC_MODULE_MEGA,
                source = "library RadioMagicModule",
                behavior = "Magic module tower attacks drain mana from targets without B084: 6/12/24, or 36 for Mega with Ultra Module Systems."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
