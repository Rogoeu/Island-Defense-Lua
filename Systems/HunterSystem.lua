if Debug and Debug.beginFile then Debug.beginFile("Systems/HunterSystem") end

OnInit("HunterSystem", function(import)
    import.strict("PlayerData")
    import.strict("RaceData")
    import.strict("IslandDefenseSystem")

    local HUNTER_ABILITY = FourCC("TIHU")
    local DEMONOLOGIST_HUNTER = FourCC("U00S")
    local tracked = {}
    local pendingHunterTypeByPlayerId = {}
    local worldRegion = nil
    local worldBounds = nil

    local HunterSystem = {}

    local function handleId(unit)
        return GetHandleId(unit)
    end

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405
    end

    local function isTitanSide(playerData)
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION or
            (playerData.isObserver and playerData:isObserver() and playerData:observeTeam() == "titan")
        )
    end

    local function nameColored(playerData)
        if playerData and playerData.nameColored then
            return playerData:nameColored()
        end
        if playerData then
            return playerData:name()
        end
        return "|cffbbbbbbUnknown|r"
    end

    local function sayTo(playerData, text)
        if playerData and not playerData:isFake() then
            DisplayTimedTextToPlayer(playerData:player(), 0, 0, 10, text)
        end
    end

    local function sayByPerspective(titanText, defenderText)
        local list = PlayerData.allReal()
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if isTitanSide(playerData) then
                sayTo(playerData, titanText)
            else
                sayTo(playerData, defenderText)
            end
            i = i + 1
        end

        list:destroy()
    end

    local function playHunterKillSound()
        local sound = rawget(_G, "gg_snd_Titan_HunterKill")
        if sound then
            PlaySoundBJ(sound)
        end
    end

    local function ownerData(unit)
        return PlayerData.get(GetOwningPlayer(unit))
    end

    local function raceForHunter(unit, owner)
        local race = Races.fromChildId(GetUnitTypeId(unit))
        if race ~= NullRace.instance() then
            return race
        end
        if owner then
            race = owner:race()
            if race and race ~= NullRace.instance() and race:isChildId(GetUnitTypeId(unit)) then
                return race
            end
        end
        return NullRace.instance()
    end

    local function childIdsFor(owner)
        local race = owner and owner:race() or NullRace.instance()

        if race and race ~= NullRace.instance() then
            return race:childIds()
        end
        return {}
    end

    local function isHunterChoice(owner, unitTypeId)
        local race = owner and owner:race() or NullRace.instance()
        return race and race ~= NullRace.instance() and race:isChildId(unitTypeId)
    end

    local function setHunterChoiceLimits(owner, selectedTypeId)
        local childIds = childIdsFor(owner)
        local player = owner:player()
        local i = 1

        while i <= #childIds do
            local childId = childIds[i]
            SetPlayerTechMaxAllowed(player, childId, childId == selectedTypeId and 1 or 0)
            i = i + 1
        end
    end

    local function unlockHunterChoices(owner)
        local childIds = childIdsFor(owner)
        local player = owner:player()
        local i = 1

        pendingHunterTypeByPlayerId[owner:id()] = nil
        while i <= #childIds do
            SetPlayerTechMaxAllowed(player, childIds[i], 1)
            i = i + 1
        end
    end

    local function isDemonologistHunter(unit)
        return unit and GetUnitTypeId(unit) == DEMONOLOGIST_HUNTER
    end

    local function shouldAnnounceRevive(unit)
        return not isDemonologistHunter(unit)
    end

    local function shouldAnnounceUnkilledDeath(unit)
        return not isDemonologistHunter(unit)
    end

    function HunterSystem.isHunter(unit)
        local owner = nil

        if not unit then
            return false
        end
        owner = ownerData(unit)
        if not owner or owner:class() ~= PlayerData.CLASS_DEFENDER then
            return false
        end
        -- Some alternate race children are hero units without the legacy TIHU
        -- classification ability. Race child IDs must count as Hunters too,
        -- otherwise a builder could summon one of each alternate hero.
        return GetUnitAbilityLevel(unit, HUNTER_ABILITY) > 0 or
            HunterSystem.isHunterId(GetUnitTypeId(unit))
    end

    function HunterSystem.isHunterId(unitTypeId)
        local race = Races.fromChildId(unitTypeId)

        -- Titan minions are also registered as Titan-race child units. Only
        -- Defender child units are selectable Titan Hunters.
        return race ~= NullRace.instance() and race:class() == PlayerData.CLASS_DEFENDER
    end

    local function keepInventoryOnDeath(unit)
        local slot = 0

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item then
                SetItemDropOnDeath(item, false)
            end
            slot = slot + 1
        end
    end

    function HunterSystem.lockChoices(owner, unitTypeId)
        if owner and owner:class() == PlayerData.CLASS_DEFENDER and isHunterChoice(owner, unitTypeId) then
            pendingHunterTypeByPlayerId[owner:id()] = unitTypeId
            setHunterChoiceLimits(owner, unitTypeId)
            return true
        end
        return false
    end

    function HunterSystem.unlockChoices(owner)
        if owner and owner:class() == PlayerData.CLASS_DEFENDER then
            unlockHunterChoices(owner)
        end
    end

    function HunterSystem.get(unit)
        if not unit then
            return nil
        end
        return tracked[handleId(unit)]
    end

    function HunterSystem.register(unit, eventName)
        local owner = ownerData(unit)
        local id = handleId(unit)
        local entry = tracked[id]
        local race = raceForHunter(unit, owner)
        local existing = nil

        if not owner or not HunterSystem.isHunter(unit) then
            return nil
        end

        -- Tech limits block normal training. This also covers scripted or ability-based spawns.
        if owner:class() == PlayerData.CLASS_DEFENDER then
            existing = owner:hunter()
            -- A dead hero can still be revived. It must continue to occupy the
            -- builder's one Hunter slot until Warcraft removes it for good.
            if existing and existing ~= unit and GetUnitTypeId(existing) ~= 0 then
                RemoveUnit(unit)
                return nil
            end
            HunterSystem.lockChoices(owner, GetUnitTypeId(unit))
        end

        if not entry then
            entry = {
                unit = unit,
                owner = owner,
                race = race,
                unitTypeId = GetUnitTypeId(unit),
                alive = true
            }
            tracked[id] = entry
            owner:setHunter(unit)

            if eventName == "spawn" then
                sayByPerspective(
                    "|cff99b4d1A Titan hunter has spawned. Kill it to gain additional resources before it gets too strong.|r",
                    nameColored(owner) .. "|cff99b4d1's |cff3399ffTitan Hunter|cff99b4d1 has spawned.|r"
                )
            end
        else
            entry.unit = unit
            entry.owner = owner
            entry.race = race
            entry.unitTypeId = GetUnitTypeId(unit)
            entry.alive = true
            owner:setHunter(unit)
        end

        keepInventoryOnDeath(unit)

        if eventName == "revive" and shouldAnnounceRevive(unit) then
            sayByPerspective(
                "|cff99b4d1A Titan hunter has been revived. Kill it to gain additional resources before it gets too strong.|r",
                "|cff99b4d1A Titan hunter has been revived! Use it to kill the titan and his minions to gain experience and gold.|r"
            )
        end

        return entry
    end

    function HunterSystem.unregister(unit)
        local entry = HunterSystem.get(unit)
        if entry then
            entry.alive = false
        end
        return entry
    end

    function HunterSystem.findByOwner(playerData)
        if not playerData then
            return nil
        end
        local hunter = playerData:hunter()
        if hunter and isAlive(hunter) then
            return hunter
        end
        return nil
    end

    local function onEnter()
        local unit = GetEnteringUnit()
        if unit and HunterSystem.isHunter(unit) then
            HunterSystem.register(unit, "spawn")
        end
    end

    local function onRevive()
        local unit = GetRevivingUnit()
        if unit and HunterSystem.isHunter(unit) then
            HunterSystem.register(unit, "revive")
        end
    end

    local function onTrainStart()
        local trainer = GetTriggerUnit()
        local owner = trainer and ownerData(trainer) or nil
        local unitTypeId = GetTrainedUnitType()

        HunterSystem.lockChoices(owner, unitTypeId)
    end

    local function onTrainCancel()
        local trainer = GetTriggerUnit()
        local owner = trainer and ownerData(trainer) or nil
        local unitTypeId = GetTrainedUnitType()

        if owner and pendingHunterTypeByPlayerId[owner:id()] == unitTypeId and not HunterSystem.findByOwner(owner) then
            HunterSystem.unlockChoices(owner)
        end
    end

    local function onPickup()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if unit and item and HunterSystem.isHunter(unit) then
            SetItemDropOnDeath(item, false)
        end
    end

    local function onDeath()
        local unit = GetTriggerUnit()
        local killer = GetKillingUnit()
        local entry = HunterSystem.get(unit)
        local owner = nil
        local killerData = nil

        if not entry and HunterSystem.isHunter(unit) then
            entry = HunterSystem.register(unit, nil)
        end

        if not entry then
            return
        end

        owner = entry.owner or ownerData(unit)
        killerData = killer and PlayerData.get(GetOwningPlayer(killer)) or nil
        HunterSystem.unregister(unit)

        if not killerData and not shouldAnnounceUnkilledDeath(unit) then
            return
        end

        if killerData and (killerData:class() == PlayerData.CLASS_TITAN or killerData:class() == PlayerData.CLASS_MINION) then
            playHunterKillSound()
            Game.say(nameColored(owner) .. "|cff99b4d1's |r|cff3399ffTitan Hunter|cff99b4d1 has been slain by |r" ..
                nameColored(killerData) .. "|cff99b4d1!|r")
        elseif killerData then
            Game.say(nameColored(owner) .. "|cff99b4d1's |cff3399ffTitan Hunter|cff99b4d1 has been denied by |r" ..
                nameColored(killerData) .. "|cff99b4d1!|r")
        else
            Game.say(nameColored(owner) .. "|cff99b4d1's |cff3399ffTitan Hunter|cff99b4d1 has died.|r")
        end
    end

    local reviveTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local enterTrigger = CreateTrigger()
    local trainStartTrigger = CreateTrigger()
    local trainCancelTrigger = CreateTrigger()
    local pickupTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(reviveTrigger, Player(i), EVENT_PLAYER_HERO_REVIVE_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerRegisterPlayerUnitEvent(trainStartTrigger, Player(i), EVENT_PLAYER_UNIT_TRAIN_START, nil)
        TriggerRegisterPlayerUnitEvent(trainCancelTrigger, Player(i), EVENT_PLAYER_UNIT_TRAIN_CANCEL, nil)
        TriggerRegisterPlayerUnitEvent(pickupTrigger, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
        i = i + 1
    end

    worldBounds = GetWorldBounds()
    worldRegion = CreateRegion()
    RegionAddRect(worldRegion, worldBounds)
    TriggerRegisterEnterRegion(enterTrigger, worldRegion, nil)

    TriggerAddAction(reviveTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onRevive)
        else
            onRevive()
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

    TriggerAddAction(enterTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onEnter)
        else
            onEnter()
        end
    end)

    TriggerAddAction(trainStartTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onTrainStart)
        else
            onTrainStart()
        end
    end)

    TriggerAddAction(trainCancelTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onTrainCancel)
        else
            onTrainCancel()
        end
    end)

    TriggerAddAction(pickupTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onPickup)
        else
            onPickup()
        end
    end)

    _G.HunterSystem = HunterSystem
end)

if Debug and Debug.endFile then Debug.endFile() end
