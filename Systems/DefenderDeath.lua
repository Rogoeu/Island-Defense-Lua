if Debug and Debug.beginFile then Debug.beginFile("Systems/DefenderDeath") end

OnInit("DefenderDeath", function(import)
    import.strict("GameTimer")
    import.strict("GameSettings")
    import.strict("PlayerData")
    import.strict("TeamAlliances")
    import.strict("MinionSpawner")
    import.strict("IslandDefenseMultiboard")
    import.strict("IslandDefenseSystem")
    import.strict("DefenderGhostBuildings")
    import.strict("PlayerProfile")

    local CONFIG = {
        titanRevealOnDeathSecondsKey = "DEFENDER_DEATH_TITAN_REVEAL_SECONDS",
        titanRevealOnDeathDefaultSeconds = 3.0,
        corpseRemoveSeconds = 3.0,
        structureCorpseRemoveSeconds = 3.0
    }

    local function settingReal(key, defaultValue)
        if GameSettings.exists(key) then
            return GameSettings.getReal(key)
        end
        return defaultValue
    end

    local function gameElapsed()
        if rawget(_G, "Game") and Game.currentGameElapsed then
            return Game.currentGameElapsed()
        end
        return 0.0
    end

    local function nameColored(playerData)
        if playerData and playerData.nameColored then
            return playerData:nameColored()
        end
        if playerData then
            return playerData:name()
        end
        return "Unknown"
    end

    local function refreshAlliances()
        TeamAlliances.refresh()
    end

    local DefenderDeath = {}
    DefenderDeath.CONFIG = CONFIG

    function DefenderDeath.ghostBuildingsEnabled()
        return DefenderGhostBuildings.enabled()
    end

    function DefenderDeath.setGhostBuildingsEnabled(value)
        DefenderGhostBuildings.setEnabled(value)
    end

    function DefenderDeath.ghostBuildingsDuration()
        return DefenderGhostBuildings.duration()
    end

    function DefenderDeath.setGhostBuildingsDuration(seconds)
        DefenderGhostBuildings.setDuration(seconds)
    end

    function DefenderDeath.removeGhostBuildings()
        return DefenderGhostBuildings.removeAfterDuration()
    end

    function DefenderDeath.setRemoveGhostBuildings(value)
        DefenderGhostBuildings.setRemoveAfterDuration(value)
    end

    function DefenderDeath.minionSpawnGraceEnabled()
        return MinionSpawner.graceEnabled()
    end

    function DefenderDeath.minionSpawnGraceTime()
        return MinionSpawner.graceTime()
    end

    function DefenderDeath.minionSpawnCourierEnabled()
        return MinionSpawner.courierEnabled()
    end

    function DefenderDeath.minionSpawnCourierSpeed()
        return MinionSpawner.courierSpeed()
    end

    function DefenderDeath.titanRevealOnDeathSeconds()
        return settingReal(CONFIG.titanRevealOnDeathSecondsKey, CONFIG.titanRevealOnDeathDefaultSeconds)
    end

    local function isTitanTeamVisionReceiver(playerData)
        if not playerData or playerData:hasLeft() then
            return false
        end
        if playerData:class() == PlayerData.CLASS_TITAN or playerData:class() == PlayerData.CLASS_MINION then
            return true
        end
        return playerData:isObserver() and playerData:observeTeam() == "titan"
    end

    local function revealTitanTeam(seconds)
        local duration = seconds or DefenderDeath.titanRevealOnDeathSeconds()
        local bounds = GetWorldBounds()
        local modifiers = {}
        local list = PlayerData.allWithFake()
        local i = 0

        if duration <= 0.0 then
            list:destroy()
            return
        end

        while i < list:size() do
            local playerData = list:at(i)
            if isTitanTeamVisionReceiver(playerData) then
                local modifier = CreateFogModifierRect(playerData:player(), FOG_OF_WAR_VISIBLE, bounds, true, false)
                modifiers[#modifiers + 1] = modifier
                FogModifierStart(modifier)
            end
            i = i + 1
        end
        list:destroy()

        GameTimer.after(duration, function()
            local j = 1
            while j <= #modifiers do
                FogModifierStop(modifiers[j])
                DestroyFogModifier(modifiers[j])
                j = j + 1
            end
        end)
    end

    local function playDefenderDeathSound()
        local sound = rawget(_G, "gg_snd_Titan_BuilderKill")
        if sound then
            PlaySoundBJ(sound)
        end
    end

    local function pingDefenderDeath(x, y)
        PingMinimapEx(x, y, 10.00, 254, 0, 0, true)
    end

    local function removeCorpseLater(unit)
        GameTimer.after(CONFIG.corpseRemoveSeconds, function()
            if unit and GetUnitTypeId(unit) ~= 0 then
                RemoveUnit(unit)
            end
        end)
    end

    local function removeStructureCorpseLater(unit)
        if not unit or not IsUnitType(unit, UNIT_TYPE_STRUCTURE) then
            return
        end

        GameTimer.after(CONFIG.structureCorpseRemoveSeconds, function()
            -- Do not remove a structure if another system brought it back to life in the meantime.
            if unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) <= 0.405 then
                RemoveUnit(unit)
            end
        end)
    end

    local function deathPosition(unit, fallback)
        local x = 0.0
        local y = 0.0

        if unit and GetUnitTypeId(unit) ~= 0 then
            x = GetUnitX(unit)
            y = GetUnitY(unit)
        end
        if x == 0.0 and y == 0.0 and fallback and GetUnitTypeId(fallback) ~= 0 then
            x = GetUnitX(fallback)
            y = GetUnitY(fallback)
        end
        if x == 0.0 and y == 0.0 then
            x = -384.0
            y = -512.0
        end
        return x, y
    end

    function DefenderDeath.ghostBuildings(playerData)
        return DefenderGhostBuildings.apply(playerData)
    end

    function DefenderDeath.spawnMinion(playerData, originX, originY)
        return MinionSpawner.spawn(playerData, originX, originY)
    end

    function DefenderDeath.spawnMinionAtMound(playerData)
        return MinionSpawner.spawnAtMound(playerData)
    end

    function DefenderDeath.launchMinionCourier(playerData, deathX, deathY)
        return MinionSpawner.launchCourier(playerData, deathX, deathY)
    end

    function DefenderDeath.scheduleMinionSpawn(playerData, deathX, deathY, immediateSpawnX, immediateSpawnY)
        return MinionSpawner.schedule(playerData, deathX, deathY, immediateSpawnX, immediateSpawnY)
    end

    function DefenderDeath.convert(playerData, deathX, deathY, killerX, killerY)
        local disconnected = playerData:isLeaving() or playerData:hasLeft()
        local ghosted = DefenderDeath.ghostBuildings(playerData)
        DefenderGhostBuildings.removeNonStructureUnits(playerData)
        playDefenderDeathSound()

        GameSettings.setInt("KILLED_DEFENDERS_COUNT", GameSettings.getInt("KILLED_DEFENDERS_COUNT") + 1)

        playerData:setObserver(false)
        playerData:setObserveTeam("")
        playerData:setClass(PlayerData.CLASS_MINION)
        playerData:setRace(NullRace.instance())
        playerData:setPicked(false)
        playerData:setCanPick(false)
        playerData:setUnit(nil)
        -- A converted Defender starts their Minion life without the former Builder bank.
        -- Otherwise a later Minion leave transfers those old resources to the Titan.
        playerData:setGold(0)
        playerData:setLumber(0)

        -- Finish the leave now: its pending grace callback must not clean up
        -- or count this Defender a second time after the death conversion.
        if disconnected then
            playerData:setLeft(true)
            playerData:setLeaving(false)
        end

        refreshAlliances()
        DefenderGhostBuildings.refreshTitanHostility()
        if rawget(_G, "RefreshObserverViews") then
            RefreshObserverViews()
        end
        local delayed = DefenderDeath.scheduleMinionSpawn(playerData, deathX, deathY, killerX, killerY)
        local message = nil
        IslandDefenseMultiboard.refresh()

        if delayed then
            local remaining = DefenderDeath.minionSpawnGraceTime() - gameElapsed()
            message = nameColored(playerData) .. "|cff00bfff has fallen and joined the Titan as a Minion. They will spawn at the mound after |r|cffffff80" .. I2S(R2I(remaining)) .. " seconds|r|cff00bfff.|r"
        else
            revealTitanTeam(DefenderDeath.titanRevealOnDeathSeconds())
            message = nameColored(playerData) .. "|cffffaa40 has fallen and joined the Titan as a Minion near their killer.|r"
        end
        if disconnected then
            message = message .. " |cff99b4d1The Minion belongs to the Titan because the Defender has left.|r"
        end
        if ghosted > 0 then
            if DefenderDeath.removeGhostBuildings() then
                message = message .. " |cff99b4d1Their structures will remain for an additional " .. I2S(R2I(DefenderDeath.ghostBuildingsDuration())) .. " seconds.|r"
            else
                message = message .. " |cff99b4d1Their structures will remain until killed.|r"
            end
        end
        Game.say(message)
    end

    function DefenderDeath.findDefenderByUnit(unit)
        local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local found = nil
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if playerData:unit() == unit then
                found = playerData
                i = list:size()
            end
            i = i + 1
        end

        list:destroy()
        return found
    end

    local function onDeath()
        local dying = GetTriggerUnit()
        local killer = GetKillingUnit()
        local playerData = DefenderDeath.findDefenderByUnit(dying)
        local deathX = 0.0
        local deathY = 0.0
        local spawnX = 0.0
        local spawnY = 0.0

        removeStructureCorpseLater(dying)

        if playerData then
            deathX, deathY = deathPosition(dying, killer)
            pingDefenderDeath(deathX, deathY)
            spawnX = deathX
            spawnY = deathY
            if killer and GetUnitTypeId(killer) ~= 0 then
                spawnX = GetUnitX(killer)
                spawnY = GetUnitY(killer)
            end
            PlayerProfile.recordBuilderLoss(playerData)
            PlayerProfile.recordBuilderDeath(killer, playerData)
            DefenderDeath.convert(playerData, deathX, deathY, spawnX, spawnY)
            -- Matches the old DefenderDeath behavior: remove the dead builder corpse after 3 seconds.
            removeCorpseLater(dying)
        end
    end

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDeath)
        else
            onDeath()
        end
    end)

    local function debugCommandsEnabled(player)
        local cheatPack = rawget(_G, "DebugCheatPack")

        return cheatPack and cheatPack.isEnabled and cheatPack.isEnabled(player)
    end

    if rawget(_G, "Command") then
        Command["-defdie"].register(function(args)
            local playerData = PlayerData.get(args:player())
            if not debugCommandsEnabled(args:player()) then
                return
            end
            if playerData and playerData:class() == PlayerData.CLASS_DEFENDER and playerData:unit() then
                KillUnit(playerData:unit())
            else
                Command.say(args:player(), "|cffff6060You need a living defender main unit for this test.|r")
            end
        end, "Debug: kills your defender main unit.")

        Command["-spawnminion"].register(function(args)
            local playerData = PlayerData.get(args:player())
            local unit = nil
            if not debugCommandsEnabled(args:player()) then
                return
            end
            if playerData then
                playerData:setClass(PlayerData.CLASS_MINION)
                unit = DefenderDeath.spawnMinion(playerData, GetStartLocationX(GetPlayerStartLocation(args:player())), GetStartLocationY(GetPlayerStartLocation(args:player())))
                IslandDefenseMultiboard.refresh()
            end
            if unit then
                Command.say(args:player(), "|cff80ff80Spawned test minion.|r")
            else
                Command.say(args:player(), "|cffff6060Could not spawn test minion.|r")
            end
        end, "Debug: spawns a minion for rawcode testing.")
    end

    _G.DefenderDeath = DefenderDeath
end)

if Debug and Debug.endFile then Debug.endFile() end
