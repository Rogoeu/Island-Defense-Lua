if Debug and Debug.beginFile then Debug.beginFile("Systems/MinionSpawner") end

OnInit("MinionSpawner", function(import)
    import.strict("GameSettings")
    import.strict("GameTimer")
    import.strict("PlayerData")
    import.strict("Races")
    import.strict("UnitSpawner")
    import.strict("UnitFilter")

    local CONFIG = {
        spawnDistance = 96.0,
        graceEnabledKey = "MINION_SPAWN_ALLOW_GRACE",
        graceTimeKey = "MINION_SPAWN_GRACE_TIME",
        courierEnabledKey = "MINION_SPAWN_COURIER_ENABLED",
        courierSpeedKey = "MINION_SPAWN_COURIER_SPEED",
        graceDefaultEnabled = true,
        graceDefaultTime = 180.0,
        courierDefaultEnabled = true,
        courierDefaultSpeed = 522.0,
        graveEffect = "Doodads\\Cinematic\\GlowingRunes\\GlowingRunes0.mdl",
        courierModel = "units\\nightelf\\Chimaera\\Chimaera.mdl",
        courierScale = 0.4,
        graceRevealItemKey = "MINION_GRACE_REVEAL_ITEM",
        graceRevealItemDefault = "I03M",
        missingMinionAttempts = 30
    }

    local MINION_BY_TITAN_WIDGET_ID = {
        [FourCC("TITA")] = FourCC("TIMA"),
        [FourCC("E011")] = FourCC("U00Y"),
        [FourCC("E00I")] = FourCC("U00B"),
        [FourCC("E00E")] = FourCC("U005"),
        [FourCC("E012")] = FourCC("U01A"),
        [FourCC("E00J")] = FourCC("U00D"),
        [FourCC("E01D")] = FourCC("U016"),
        [FourCC("E00C")] = FourCC("U003"),
        [FourCC("E00B")] = FourCC("U001"),
        [FourCC("E00O")] = FourCC("U00O"),
        [FourCC("E00K")] = FourCC("U00L")
    }

    local MinionSpawner = {}
    local pendingRevealItem = {}

    local function say(message)
        if rawget(_G, "Game") and Game.say then
            Game.say(message)
        else
            BJDebugMsg(message)
        end
    end

    local function settingBool(key, defaultValue)
        if GameSettings.exists(key) then
            return GameSettings.getBool(key)
        end
        return defaultValue
    end

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

    local function minionGraceRevealItemId()
        local rawcode = CONFIG.graceRevealItemDefault

        if GameSettings.exists(CONFIG.graceRevealItemKey) then
            rawcode = GameSettings.getStr(CONFIG.graceRevealItemKey)
        end
        if type(rawcode) == "string" and StringLength(rawcode) == 4 then
            return FourCC(rawcode)
        end
        return FourCC(CONFIG.graceRevealItemDefault)
    end

    local function minionIdFromTitan(playerData)
        local race = playerData and playerData:race() or NullRace.instance()

        if race ~= NullRace.instance() and race:childId() ~= 0 then
            return race:childId()
        end
        if race ~= NullRace.instance() and race:widgetId() ~= 0 and MINION_BY_TITAN_WIDGET_ID[race:widgetId()] then
            return MINION_BY_TITAN_WIDGET_ID[race:widgetId()]
        end
        if playerData and playerData:unit() and MINION_BY_TITAN_WIDGET_ID[GetUnitTypeId(playerData:unit())] then
            return MINION_BY_TITAN_WIDGET_ID[GetUnitTypeId(playerData:unit())]
        end
        return 0
    end

    local function canSpawnForPlayer(playerData)
        return playerData and
            not playerData:hasLeft() and
            not playerData:isLeaving() and
            playerData:class() == PlayerData.CLASS_MINION and
            not playerData:unit()
    end

    local function currentTitanMinionId()
        local list = PlayerData.withClass(PlayerData.CLASS_TITAN)
        local minionId = 0
        local i = 0

        while i < list:size() do
            minionId = minionIdFromTitan(list:at(i))
            if minionId ~= 0 then
                i = list:size()
            end
            i = i + 1
        end

        list:destroy()
        return minionId
    end

    local function currentTitanPlayerData()
        local list = PlayerData.withClass(PlayerData.CLASS_TITAN)
        local titanData = nil
        local i = 0

        while i < list:size() do
            local candidate = list:at(i)
            if not candidate:hasLeft() and not candidate:isLeaving() then
                titanData = candidate
                i = list:size()
            end
            i = i + 1
        end

        list:destroy()
        return titanData
    end

    local function randomPointNear(originX, originY)
        local angle = GetRandomReal(0.0, 360.0) * bj_DEGTORAD
        return originX + CONFIG.spawnDistance * Cos(angle), originY + CONFIG.spawnDistance * Sin(angle), bj_RADTODEG * angle
    end

    local function createMinionUnit(owner, minionId, originX, originY, level)
        local x, y, facing = randomPointNear(originX, originY)
        local unit = nil

        if not minionId or minionId == 0 then
            return nil
        end

        unit = CreateUnit(owner, minionId, x, y, facing)
        if unit then
            UnitFilter.registerUnitClass(unit, PlayerData.CLASS_MINION)
            UnitSpawner.setHeroLevel(unit, level or UnitSpawner.minionStartingLevel())
        end
        return unit
    end

    local function postSpawn(playerData, unit)
        local punishmentCentre = rawget(_G, "PunishmentCentre")
        local punished = nil

        if not unit then
            return
        end

        punished = punishmentCentre and punishmentCentre.applyAutoPunish and punishmentCentre.applyAutoPunish(unit)

        if pendingRevealItem[playerData:id()] then
            UnitAddItemById(unit, minionGraceRevealItemId())
            pendingRevealItem[playerData:id()] = nil
        end
        if not punished then
            UnitSpawner.focusMainUnitCamera(playerData)
        end
        if punishmentCentre and punishmentCentre.update then
            punishmentCentre.update()
        end
    end

    local function spawnForPlayer(playerData, originX, originY, attempt)
        attempt = attempt or 0

        if not canSpawnForPlayer(playerData) then
            if playerData then
                pendingRevealItem[playerData:id()] = nil
            end
            return nil
        end

        local minionId = currentTitanMinionId()
        if minionId == 0 then
            if attempt < CONFIG.missingMinionAttempts then
                GameTimer.after(1.0, function()
                    if canSpawnForPlayer(playerData) then
                        spawnForPlayer(playerData, originX, originY, attempt + 1)
                    end
                end)
            else
                say("|cffff6060Minion spawn failed. Missing childId for current Titan race.|r")
            end
            return nil
        end

        local x, y, facing = randomPointNear(originX, originY)
        local unit = UnitSpawner.spawnMinion(playerData, minionId, x, y, facing)

        if unit then
            postSpawn(playerData, unit)
        else
            say("|cffff6060Minion spawn failed. Unit rawcode could not be created.|r")
        end

        return unit
    end

    function MinionSpawner.graceEnabled()
        return settingBool(CONFIG.graceEnabledKey, CONFIG.graceDefaultEnabled)
    end

    function MinionSpawner.graceTime()
        return settingReal(CONFIG.graceTimeKey, CONFIG.graceDefaultTime)
    end

    function MinionSpawner.courierEnabled()
        return settingBool(CONFIG.courierEnabledKey, CONFIG.courierDefaultEnabled)
    end

    function MinionSpawner.courierSpeed()
        return settingReal(CONFIG.courierSpeedKey, CONFIG.courierDefaultSpeed)
    end

    function MinionSpawner.currentMinionId()
        return currentTitanMinionId()
    end

    function MinionSpawner.minionIdFromTitan(playerData)
        return minionIdFromTitan(playerData)
    end

    function MinionSpawner.spawnUnitForTitan(titanUnit, originX, originY, level)
        local titanData = titanUnit and PlayerData.get(GetOwningPlayer(titanUnit)) or nil
        local minionId = minionIdFromTitan(titanData)
        local unitRace = titanUnit and Races.fromChildId(GetUnitTypeId(titanUnit)) or NullRace.instance()

        if minionId == 0 and unitRace ~= NullRace.instance() then
            minionId = unitRace:childId()
        end
        if minionId == 0 and titanUnit then
            minionId = MINION_BY_TITAN_WIDGET_ID[GetUnitTypeId(titanUnit)] or 0
        end
        if minionId == 0 then
            say("|cffff6060Minion spawn failed. Missing childId for current Titan race.|r")
            return nil
        end

        return createMinionUnit(GetOwningPlayer(titanUnit), minionId, originX, originY, level)
    end

    function MinionSpawner.spawn(playerData, originX, originY)
        return spawnForPlayer(playerData, originX, originY, 0)
    end

    function MinionSpawner.spawnAtMound(playerData)
        local x, y = UnitSpawner.minionSpawnPosition()
        return MinionSpawner.spawn(playerData, x, y)
    end

    function MinionSpawner.spawnForTitan(x, y, giveRevealItem)
        local titanData = currentTitanPlayerData()
        local minionId = 0
        local unit = nil
        local punishmentCentre = rawget(_G, "PunishmentCentre")

        if not titanData then
            say("|cffff6060Grace minion spawn failed. No active Titan was found.|r")
            return nil
        end

        minionId = minionIdFromTitan(titanData)
        if minionId == 0 then
            say("|cffff6060Grace minion spawn failed. Missing childId for current Titan race.|r")
            return nil
        end

        unit = createMinionUnit(titanData:player(), minionId, x, y, UnitSpawner.minionStartingLevel())
        if unit then
            if giveRevealItem then
                UnitAddItemById(unit, minionGraceRevealItemId())
            end
            if punishmentCentre and punishmentCentre.applyAutoPunish then
                punishmentCentre.applyAutoPunish(unit)
            end
            if punishmentCentre and punishmentCentre.update then
                punishmentCentre.update()
            end
        end

        return unit
    end

    function MinionSpawner.spawnGraceMinionAtMound()
        local x, y = UnitSpawner.minionSpawnPosition()
        return MinionSpawner.spawnForTitan(x, y, true)
    end

    function MinionSpawner.launchGraceCourier(deathX, deathY)
        local x, y = UnitSpawner.minionSpawnPosition()
        local missileSystem = rawget(_G, "MissileSystem")

        if not MinionSpawner.courierEnabled() or not missileSystem or not missileSystem.launch then
            return MinionSpawner.spawnGraceMinionAtMound()
        end

        missileSystem.launch({
            x = deathX,
            y = deathY,
            z = 120.0,
            targetX = x,
            targetY = y,
            speed = MinionSpawner.courierSpeed(),
            collision = 48.0,
            model = CONFIG.courierModel,
            scale = CONFIG.courierScale,
            onImpact = function()
                MinionSpawner.spawnGraceMinionAtMound()
            end
        })
        return true
    end

    function MinionSpawner.launchCourier(playerData, deathX, deathY)
        return MinionSpawner.launchGraceCourier(deathX, deathY)
    end

    function MinionSpawner.schedule(playerData, deathX, deathY, immediateSpawnX, immediateSpawnY)
        local graceTime = MinionSpawner.graceTime()
        local remaining = graceTime - gameElapsed()
        local grave = nil

        if not MinionSpawner.graceEnabled() or remaining <= 0.0 then
            if playerData and (playerData:isLeaving() or playerData:hasLeft()) then
                MinionSpawner.spawnForTitan(immediateSpawnX or deathX, immediateSpawnY or deathY, false)
            else
                MinionSpawner.spawn(playerData, immediateSpawnX or deathX, immediateSpawnY or deathY)
            end
            return false
        end

        grave = AddSpecialEffect(CONFIG.graveEffect, deathX, deathY)

        GameTimer.after(remaining, function()
            if grave then
                DestroyEffect(grave)
                grave = nil
            end

            -- Grace minions are Titan-owned, even when the original defender has left.
            MinionSpawner.launchGraceCourier(deathX, deathY)
        end)

        return true
    end

    MinionSpawner.CONFIG = CONFIG
    MinionSpawner.MINION_BY_TITAN_WIDGET_ID = MINION_BY_TITAN_WIDGET_ID
    MinionSpawner.canSpawnForPlayer = canSpawnForPlayer

    _G.MinionSpawner = MinionSpawner
end)

if Debug and Debug.endFile then Debug.endFile() end
