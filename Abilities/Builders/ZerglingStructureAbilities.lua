if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/ZerglingStructureAbilities") end

OnInit("ZerglingStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    local IDS = {
        HIVE_MIND_DAMAGE = FourCC("A0ST")
    }

    local HIVE_MIND_RADIUS = 2500.0
    local HIVE_MIND_DAMAGE_PER_TOWER = 1

    local function hasHiveMind(unit)
        return unit and GetUnitAbilityLevel(unit, IDS.HIVE_MIND_DAMAGE) > 0
    end

    local function refreshDamageBonus(unit)
        IncUnitAbilityLevel(unit, IDS.HIVE_MIND_DAMAGE)
        DecUnitAbilityLevel(unit, IDS.HIVE_MIND_DAMAGE)
    end

    local function damageBonus(unit)
        local ability = BlzGetUnitAbility(unit, IDS.HIVE_MIND_DAMAGE)
        if ability then
            return BlzGetAbilityIntegerLevelField(ability, ABILITY_ILF_ATTACK_BONUS, 0)
        end
        return 0
    end

    local function setDamageBonus(unit, value)
        local ability = BlzGetUnitAbility(unit, IDS.HIVE_MIND_DAMAGE)
        if ability then
            BlzSetAbilityIntegerLevelField(ability, ABILITY_ILF_ATTACK_BONUS, 0, value)
            refreshDamageBonus(unit)
        end
    end

    local function addDamageBonus(unit, amount)
        setDamageBonus(unit, damageBonus(unit) + amount)
    end

    local function forHiveMindTowersNear(source, callback)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRange(group, GetUnitX(source), GetUnitY(source), HIVE_MIND_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if hasHiveMind(unit) then
                callback(unit)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function updateTowerDamage(source)
        local towerCount = -1

        forHiveMindTowersNear(source, function(tower)
            addDamageBonus(tower, HIVE_MIND_DAMAGE_PER_TOWER)
            towerCount = towerCount + 1
        end)

        setDamageBonus(source, HIVE_MIND_DAMAGE_PER_TOWER * towerCount)
    end

    local function decreaseTowerDamage(source)
        forHiveMindTowersNear(source, function(tower)
            addDamageBonus(tower, -HIVE_MIND_DAMAGE_PER_TOWER)
        end)
        RemoveUnit(source)
    end

    local function onConstructStart()
        local unit = GetTriggerUnit()
        if hasHiveMind(unit) then
            updateTowerDamage(unit)
        end
    end

    local function onDeath()
        local unit = GetTriggerUnit()
        if hasHiveMind(unit) then
            decreaseTowerDamage(unit)
        end
    end

    local constructTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(constructTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_START, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end

    TriggerAddAction(constructTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onConstructStart)
        else
            onConstructStart()
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

    AbilityRegistry.registerRace("Zergling", "structures", {
        notes = "Zergling structure ability ported from old ZerglingTower library.",
        abilities = {
            {
                name = "Hive Mind",
                id = IDS.HIVE_MIND_DAMAGE,
                source = "library ZerglingTower",
                behavior = "Towers with A0ST grant +1 attack damage to each nearby A0ST tower within 2500 range. The bonus is updated when a tower starts construction and removed when it dies."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
