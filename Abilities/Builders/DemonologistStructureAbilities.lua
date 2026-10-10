if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/DemonologistStructureAbilities") end

OnInit("DemonologistStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    local IDS = {
        DEMONIC_ALTAR = FourCC("o03S"),
        DEMONIC_HOUND = FourCC("n01T"),
        DEMONISM_ITEM = FourCC("I07R"),
        DEMONIC_PILLAR = FourCC("h034"),
        ABILITY_BUILDING = FourCC("u00J"),
        ABILITY_BUILDING_FIRST = FourCC("A0I6"),
        ABILITY_BUILDING_SECOND = FourCC("A06K")
    }

    local function hasItem(unit, itemId)
        local slot = 0
        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item and GetItemTypeId(item) == itemId then
                return true
            end
            slot = slot + 1
        end
        return false
    end

    local function spawnHound(owner, x, y, facing, lifetime, target)
        local hound = CreateUnit(owner, IDS.DEMONIC_HOUND, x, y, facing or 0)

        SetUnitVertexColor(hound, 185, 50, 50, 150)
        UnitAddType(hound, UNIT_TYPE_SUMMONED)
        UnitApplyTimedLife(hound, FourCC("B061"), lifetime)

        if target then
            IssueTargetOrderById(hound, 851983, target)
        end

        return hound
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local altar = GetEventDamageSource()

        if not target or not altar or GetUnitTypeId(altar) ~= IDS.DEMONIC_ALTAR then
            return
        end
        if not IsUnitEnemy(altar, GetOwningPlayer(target)) then
            return
        end

        if GetRandomReal(0.0, 1.0) <= 0.10 then
            IssueTargetOrder(altar, "forkedlightning", target)
            spawnHound(GetOwningPlayer(altar), GetUnitX(target), GetUnitY(target), 0, 120.0, target)
        end
    end

    local function onSummon()
        local caster = GetSummoningUnit()
        local x = 0.0
        local y = 0.0
        local facing = 0.0

        if not caster or not hasItem(caster, IDS.DEMONISM_ITEM) then
            return
        end

        if GetRandomReal(0.0, 1.0) <= 0.40 then
            x = GetUnitX(caster)
            y = GetUnitY(caster)
            facing = GetUnitFacing(caster)
            spawnHound(
                GetOwningPlayer(caster),
                x + 180.0 * Cos(facing * bj_DEGTORAD),
                y + 180.0 * Sin(facing * bj_DEGTORAD),
                facing,
                60.0,
                nil
            )
        end
    end

    local function onEnter()
        local unit = GetEnteringUnit()

        if unit and GetUnitTypeId(unit) == IDS.DEMONIC_PILLAR then
            UnitApplyTimedLife(unit, FourCC("BTLF"), 8.0)
        end
    end

    local function onConstructFinish()
        local building = GetConstructedStructure()

        if not building or GetUnitTypeId(building) ~= IDS.ABILITY_BUILDING then
            return
        end

        if GetUnitAbilityLevel(building, IDS.ABILITY_BUILDING_FIRST) <= 0 then
            UnitAddAbility(building, IDS.ABILITY_BUILDING_FIRST)
        end
        if GetUnitAbilityLevel(building, IDS.ABILITY_BUILDING_SECOND) <= 0 then
            UnitAddAbility(building, IDS.ABILITY_BUILDING_SECOND)
        end
    end

    local damageTrigger = CreateTrigger()
    local summonTrigger = CreateTrigger()
    local enterTrigger = CreateTrigger()
    local constructFinishTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(summonTrigger, Player(i), EVENT_PLAYER_UNIT_SUMMON, nil)
        TriggerRegisterPlayerUnitEvent(constructFinishTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_FINISH, nil)
        i = i + 1
    end
    TriggerRegisterEnterRectSimple(enterTrigger, GetWorldBounds())
    TriggerAddAction(damageTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)
    TriggerAddAction(summonTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSummon)
        else
            onSummon()
        end
    end)
    TriggerAddAction(enterTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onEnter)
        else
            onEnter()
        end
    end)
    TriggerAddAction(constructFinishTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onConstructFinish)
        else
            onConstructFinish()
        end
    end)

    AbilityRegistry.registerRace("Demonologist", "structures", {
        notes = "Demonologist structure abilities ported from DemonicAltar, DemonicPillar and AddAbilitiesOnBuildFinish.",
        abilities = {
            {
                name = "Demonic Altar",
                id = IDS.DEMONIC_ALTAR,
                source = "library DemonicAltar",
                behavior = "10 percent chance on damage to forked-lightning the target and spawn a temporary Demonic Hound."
            },
            {
                name = "Demonism",
                id = IDS.DEMONISM_ITEM,
                source = "library DemonicAltar",
                behavior = "If the summoner carries the Demonic Altar item, summons have a 40 percent chance to create a temporary Demonic Hound."
            },
            {
                name = "Demonic Pillar",
                id = IDS.DEMONIC_PILLAR,
                source = "library DemonicPillar",
                behavior = "Demonic Pillars receive an 8-second timed life when they enter the map."
            },
            {
                name = "Building abilities on completion",
                id = IDS.ABILITY_BUILDING,
                source = "library AddAbilitiesOnBuildFinish",
                behavior = "Adds A0I6 and A06K to u00J when construction finishes."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
