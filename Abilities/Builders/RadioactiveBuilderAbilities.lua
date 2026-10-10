if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/RadioactiveBuilderAbilities") end

OnInit("RadioactiveBuilderAbilities", function(import)
    import.strict("AbilityRegistry")

    local IDS = {
        RADIOACTIVE_HUNTER = FourCC("H020"),
        RADIOACTIVE_HUNTER_RCS = FourCC("H017"),
        REINFORCED_COMBAT_STATE = FourCC("A0OC"),
        NUCLEAR_EXPLOSION_RCS = FourCC("A0OI"),
        NUCLEAR_EXPLOSION_NCS = FourCC("A0OJ"),
        NITRO_RCS = FourCC("A0OM"),
        NITRO_NCS = FourCC("A0EE"),
        ABILITY_SWAP_RCS = FourCC("A0OK"),
        DAMAGE_BONUS_RCS = FourCC("A0ON"),
        RADIATION = FourCC("A0EF"),
        UNLOAD = FourCC("A05S"),
        RADIOACTIVE_BUILDER = FourCC("u009"),
        RADIOACTIVE_BUILDER_ALT = FourCC("u01L")
    }

    local function isRadioactiveHunter(unit)
        local id = unit and GetUnitTypeId(unit) or 0
        return id == IDS.RADIOACTIVE_HUNTER or id == IDS.RADIOACTIVE_HUNTER_RCS
    end

    local function isRadioactiveUnit(unit)
        local id = unit and GetUnitTypeId(unit) or 0
        return id == IDS.RADIOACTIVE_BUILDER or id == IDS.RADIOACTIVE_BUILDER_ALT
    end

    local function applyRcsDamageLevel(unit)
        if GetUnitTypeId(unit) == IDS.RADIOACTIVE_HUNTER_RCS then
            SetUnitAbilityLevel(unit, IDS.DAMAGE_BONUS_RCS, GetUnitAbilityLevel(unit, IDS.REINFORCED_COMBAT_STATE))
        else
            SetUnitAbilityLevel(unit, IDS.DAMAGE_BONUS_RCS, 1 + GetUnitAbilityLevel(unit, IDS.REINFORCED_COMBAT_STATE))
        end
    end

    local function onHeroSkill()
        local unit = GetTriggerUnit()
        local learned = GetLearnedSkill()

        if not isRadioactiveHunter(unit) then
            return
        end

        UnitMakeAbilityPermanent(unit, true, learned)
        if learned == IDS.REINFORCED_COMBAT_STATE then
            applyRcsDamageLevel(unit)
        end
    end

    local function onSpellEffect()
        local unit = GetTriggerUnit()

        if GetSpellAbilityId() == IDS.REINFORCED_COMBAT_STATE and isRadioactiveHunter(unit) then
            applyRcsDamageLevel(unit)
        elseif GetSpellAbilityId() == IDS.UNLOAD then
            UnitRemoveAbility(unit, IDS.RADIATION)
        end
    end

    local function onLoaded()
        local transport = GetTransportUnit()
        local loaded = GetLoadedUnit()

        if transport and loaded and isRadioactiveUnit(loaded) then
            UnitAddAbility(transport, IDS.RADIATION)
        end
    end

    local function onOrder()
        if GetIssuedOrderId() == OrderId("unload") then
            UnitRemoveAbility(GetTriggerUnit(), IDS.RADIATION)
        end
    end

    local function onDeath()
        local unit = GetTriggerUnit()

        if GetUnitTypeId(unit) == IDS.RADIOACTIVE_HUNTER then
            UnitRemoveAbility(unit, IDS.RADIATION)
        end
    end

    local skillTrigger = CreateTrigger()
    local spellTrigger = CreateTrigger()
    local loadTrigger = CreateTrigger()
    local orderTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(loadTrigger, Player(i), EVENT_PLAYER_UNIT_LOADED, nil)
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end

    TriggerAddAction(skillTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onHeroSkill)
        else
            onHeroSkill()
        end
    end)

    TriggerAddAction(spellTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    TriggerAddAction(loadTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onLoaded)
        else
            onLoaded()
        end
    end)

    TriggerAddAction(orderTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onOrder)
        else
            onOrder()
        end
    end)

    TriggerAddAction(deathTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDeath)
        else
            onDeath()
        end
    end)

    AbilityRegistry.registerRace("Radioactive", "builder", {
        notes = "Radioactive builder/hunter abilities ported from TitanHunterRadioactive and RadioHunter.",
        abilities = {
            {
                name = "Reinforced Combat State",
                id = IDS.REINFORCED_COMBAT_STATE,
                source = "library TitanHunterRadioactive",
                behavior = "Radioactive hunter learned abilities are made permanent; Reinforced Combat State updates the RCS damage bonus level."
            },
            {
                name = "Radiation Transport",
                id = IDS.RADIATION,
                source = "library RadioHunter",
                behavior = "Transports carrying Radioactive units gain Radiation and lose it when unloading."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
