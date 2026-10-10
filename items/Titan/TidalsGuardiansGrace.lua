if Debug and Debug.beginFile then Debug.beginFile("items/Titan/TidalsGuardiansGrace") end

OnInit("TitanItemTidalsGuardiansGrace", function(import)
    import.strict("ItemExtras")

    local IDS = {
        TIDALS_GUARDIANS_GRACE = FourCC("I089"),
        SHALLOW_SPAWN = FourCC("n01F"),
        CRITTER = FourCC("CRIT"),
        TIMED_LIFE = FourCC("B061")
    }

    local SPAWN_DURATION = 45.0
    local SPAWN_EFFECT = "Abilities\\Spells\\Other\\CrushingWave\\CrushingWaveDamage.mdx"
    local MAX_SPAWNS = 1

    local TitanItemTidalsGuardiansGrace = {}
    local spawnsByTitan = {}
    local titanBySpawn = {}

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.TIDALS_GUARDIANS_GRACE)
    end

    local function isCritter(unit)
        return unit and GetUnitAbilityLevel(unit, IDS.CRITTER) > 0
    end

    local function forgetSpawn(spawn)
        local spawnId = GetHandleId(spawn)
        local titan = titanBySpawn[spawnId]
        local titanId = titan and GetHandleId(titan) or nil
        local list = titanId and spawnsByTitan[titanId] or nil
        local i = 1

        if list then
            while i <= #list do
                if list[i] == spawn then
                    table.remove(list, i)
                else
                    i = i + 1
                end
            end
            if #list == 0 then
                spawnsByTitan[titanId] = nil
            end
        end

        titanBySpawn[spawnId] = nil
    end

    local function killSpawn(spawn)
        if spawn and GetUnitTypeId(spawn) ~= 0 then
            forgetSpawn(spawn)
            KillUnit(spawn)
        end
    end

    local function removeTitanSpawns(titan)
        local titanId = GetHandleId(titan)
        local list = spawnsByTitan[titanId]
        local i = 1

        if not list then
            return
        end

        while i <= #list do
            killSpawn(list[i])
            i = i + 1
        end

        spawnsByTitan[titanId] = nil
    end

    local function addGraceSpawn(titan, dying)
        local titanId = GetHandleId(titan)
        local list = spawnsByTitan[titanId] or {}
        local spawn = CreateUnit(
            GetOwningPlayer(titan),
            IDS.SHALLOW_SPAWN,
            GetUnitX(dying),
            GetUnitY(dying),
            GetUnitFacing(dying)
        )

        UnitApplyTimedLife(spawn, IDS.TIMED_LIFE, SPAWN_DURATION)
        DestroyEffect(AddSpecialEffectTarget(SPAWN_EFFECT, spawn, "chest"))

        list[#list + 1] = spawn
        spawnsByTitan[titanId] = list
        titanBySpawn[GetHandleId(spawn)] = titan

        while #list > MAX_SPAWNS do
            killSpawn(list[1])
        end

        return spawn
    end

    function TitanItemTidalsGuardiansGrace.spawn(titan, dying)
        return addGraceSpawn(titan, dying)
    end

    local function onDrop()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if item and GetItemTypeId(item) == IDS.TIDALS_GUARDIANS_GRACE then
            removeTitanSpawns(unit)
        end
    end

    local function onDeath()
        local dying = GetTriggerUnit()
        local killer = GetKillingUnit()

        if GetUnitTypeId(dying) == IDS.SHALLOW_SPAWN then
            forgetSpawn(dying)
            return
        end

        if killer and GetUnitTypeId(killer) ~= 0 and hasItem(killer) and isCritter(dying) then
            addGraceSpawn(killer, dying)
        end
    end

    local dropTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(dropTrigger, Player(i), EVENT_PLAYER_UNIT_DROP_ITEM, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end

    local function guarded(callback)
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(callback)
        else
            callback()
        end
    end

    TriggerAddAction(dropTrigger, function() guarded(onDrop) end)
    TriggerAddAction(deathTrigger, function() guarded(onDeath) end)

    TitanItemTidalsGuardiansGrace.ids = IDS

    _G.TitanItemTidalsGuardiansGrace = TitanItemTidalsGuardiansGrace
end)

if Debug and Debug.endFile then Debug.endFile() end
