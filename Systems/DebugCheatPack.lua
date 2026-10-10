if Debug and Debug.beginFile then Debug.beginFile("Systems/DebugCheatPack") end

OnInit("DebugCheatPack", function(import)
    import.strict("CommandRegistry")
    import.strict("GameSettings")
    import.strict("PlayerData")
    import.strict("GameTimer")

    local enabled = {}
    local selectedUnits = {}
    local revealModifiers = {}
    local noCooldown = {}
    local infiniteMana = {}
    local teleportPatrol = {}
    local fastBuild = {}
    local fastResearch = {}
    local autoHealPercent = {}
    local autoHealTimer = nil
    local titanDpsEnabled = {}
    local titanDpsFrame = nil
    local titanDpsRegistered = false
    local titanDpsTimer = nil
    local titanDpsTarget = {}
    local titanDpsDamage = {}
    local titanDpsLast = {}
    local titanDpsPeak = {}
    local titanDpsTotal = {}
    local ui = {
        ready = false,
        expanded = {},
        frames = {},
        buttons = {},
        icons = {},
        tooltips = {},
        actionByButton = {},
        localActionByButton = {},
        shareOpen = {}
    }

    local DebugCheatPack = {}

    local function pid(player)
        return GetPlayerId(player)
    end

    local function say(player, text)
        Command.say(player, text)
    end

    local function rawcode(text)
        if type(text) == "string" and string.len(text) == 4 then
            return FourCC(text)
        end
        return 0
    end

    local function rawcodeText(id)
        local value = id or 0
        if not id or id == 0 then
            return "0000"
        end
        if value < 0 then
            value = value + 0x100000000
        end
        return string.char(
            ModuloInteger(R2I(value / 0x1000000), 0x100),
            ModuloInteger(R2I(value / 0x10000), 0x100),
            ModuloInteger(R2I(value / 0x100), 0x100),
            ModuloInteger(value, 0x100)
        )
    end

    local function numberArg(args, index, fallback)
        return tonumber(args:at(index) or "") or fallback or 0
    end

    local function requiredNumberArg(args, index)
        return tonumber(args:at(index) or "")
    end

    local function playerArg(args, index, fallback)
        local value = numberArg(args, index, -1)
        if value >= 0 and value < bj_MAX_PLAYER_SLOTS then
            return Player(value)
        end
        return fallback
    end

    local function selectedOrMain(player)
        local unit = selectedUnits[pid(player)]
        if unit and GetWidgetLife(unit) > 0.405 then
            return unit
        end

        local playerData = PlayerData.get(player)
        if playerData and playerData:unit() then
            return playerData:unit()
        end

        return nil
    end

    local function forSelectedOrMain(player, callback)
        local group = CreateGroup()
        local unit = nil
        local count = 0

        GroupEnumUnitsSelected(group, player, nil)
        unit = FirstOfGroup(group)

        while unit do
            GroupRemoveUnit(group, unit)
            callback(unit)
            count = count + 1
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)

        if count == 0 then
            unit = selectedOrMain(player)
            if unit then
                callback(unit)
                count = 1
            end
        end

        return count
    end

    local function targetPosition(player)
        local unit = selectedOrMain(player)
        if unit then
            return GetUnitX(unit), GetUnitY(unit), GetUnitFacing(unit)
        end

        local start = GetPlayerStartLocation(player)
        return GetStartLocationX(start), GetStartLocationY(start), 270
    end

    local function requireEnabled(args)
        if enabled[pid(args:player())] then
            return true
        end
        say(args:player(), "|cffff6060Cheats are not active in this lobby.|r")
        return false
    end

    local function addResource(player, state, amount)
        SetPlayerState(player, state, GetPlayerState(player, state) + amount)
    end

    local function setFoodCap(player, amount)
        SetPlayerState(player, PLAYER_STATE_FOOD_CAP_CEILING, amount)
        SetPlayerState(player, PLAYER_STATE_RESOURCE_FOOD_CAP, amount)
    end

    local function setFastBuild(player, enabled)
        fastBuild[pid(player)] = enabled == true
        say(player, fastBuild[pid(player)] and "|cff80ff80Fast buildings enabled.|r" or "|cffffcc00Fast buildings disabled.|r")
    end

    local function setFastResearch(player, enabled)
        fastResearch[pid(player)] = enabled == true
        say(player, fastResearch[pid(player)] and "|cff80ff80Fast research enabled.|r" or "|cffffcc00Fast research disabled.|r")
    end

    local function finishBuildingNow(unit)
        if not unit or GetUnitTypeId(unit) == 0 then
            return
        end

        -- The old cheat used 99. In practice that is safer than 100 here:
        -- it lets Warcraft finish the construction/update path itself.
        UnitSetConstructionProgress(unit, 99)
        UnitSetUpgradeProgress(unit, 99)
    end

    local function finishResearchNow(player, unit, researchId, level)
        local targetLevel = level or 0

        if not player or not researchId or researchId == 0 then
            return
        end

        if targetLevel <= 0 then
            targetLevel = GetPlayerTechCount(player, researchId, true) + 1
        end
        SetPlayerTechResearched(player, researchId, targetLevel)
        if unit and GetUnitTypeId(unit) ~= 0 then
            UnitSetUpgradeProgress(unit, 99)
        end
    end

    local function setSelectedAnimation(player, animation)
        forSelectedOrMain(player, function(unit)
            SetUnitAnimation(unit, animation)
        end)
    end

    local function setSelectedPathing(player, enabled)
        forSelectedOrMain(player, function(unit)
            SetUnitPathing(unit, enabled)
        end)
    end

    local function setSelectedPaused(player, enabled)
        forSelectedOrMain(player, function(unit)
            PauseUnit(unit, enabled)
        end)
    end

    local function setSelectedInvisible(player, invisible)
        forSelectedOrMain(player, function(unit)
            if invisible then
                UnitAddAbility(unit, FourCC("Apiv"))
            else
                UnitRemoveAbility(unit, FourCC("Apiv"))
            end
        end)
    end

    local function debuffSelected(player)
        forSelectedOrMain(player, function(unit)
            UnitRemoveBuffs(unit, true, true)
        end)
    end

    local function copySelected(player, count)
        if count < 1 then
            count = 1
        elseif count > 50 then
            count = 50
        end

        forSelectedOrMain(player, function(unit)
            local i = 1
            while i <= count do
                CreateUnit(GetOwningPlayer(unit), GetUnitTypeId(unit), GetUnitX(unit), GetUnitY(unit), GetUnitFacing(unit))
                i = i + 1
            end
        end)
    end

    local function reviveSelectedHero(player)
        local x, y = targetPosition(player)
        forSelectedOrMain(player, function(unit)
            if IsUnitType(unit, UNIT_TYPE_HERO) then
                ReviveHero(unit, x, y, false)
            end
        end)
    end

    local function setSelectedScale(player, percent)
        local scale = percent / 100.0
        forSelectedOrMain(player, function(unit)
            SetUnitScale(unit, scale, scale, scale)
        end)
    end

    local function setSelectedFlyHeight(player, height, rate)
        forSelectedOrMain(player, function(unit)
            UnitAddAbility(unit, FourCC("Amrf"))
            SetUnitFlyHeight(unit, height, rate or 0.0)
            UnitRemoveAbility(unit, FourCC("Amrf"))
        end)
    end

    local function ensureAutoHealTimer()
        if autoHealTimer then
            return
        end

        autoHealTimer = GameTimer.every(0.10, function()
            local any = false
            for id, data in pairs(autoHealPercent) do
                local unit = data.unit
                local percent = data.percent
                if unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 then
                    local targetLife = GetUnitState(unit, UNIT_STATE_MAX_LIFE) * percent / 100.0
                    if GetWidgetLife(unit) < targetLife then
                        SetWidgetLife(unit, targetLife)
                    end
                    any = true
                else
                    autoHealPercent[id] = nil
                end
            end

            if not any then
                autoHealTimer:destroy()
                autoHealTimer = nil
            end
        end)
    end

    local function autoHealSelected(player, percent)
        if percent < 1.0 then
            percent = 1.0
        elseif percent > 100.0 then
            percent = 100.0
        end

        forSelectedOrMain(player, function(unit)
            autoHealPercent[GetHandleId(unit)] = {
                unit = unit,
                percent = percent
            }
        end)
        ensureAutoHealTimer()
    end

    local function clearAutoHealSelected(player)
        forSelectedOrMain(player, function(unit)
            autoHealPercent[GetHandleId(unit)] = nil
        end)
    end

    local setSharedControl = nil
    local closeAllianceUi = nil
    local setTitanDpsMeter = nil

    local function selectedHero(player)
        local playerData = PlayerData.get(player)
        if playerData and playerData:unit() then
            selectedUnits[pid(player)] = playerData:unit()
            SelectUnitForPlayerSingle(playerData:unit(), player)
            return playerData:unit()
        end
        return selectedOrMain(player)
    end

    local function performUiAction(player, action)
        local unit = nil

        if not DebugCheatPack.isEnabled(player) then
            return
        end

        if action == "gold" then
            addResource(player, PLAYER_STATE_RESOURCE_GOLD, 1000)
        elseif action == "gold_big" then
            addResource(player, PLAYER_STATE_RESOURCE_GOLD, 10000)
        elseif action == "lumber" then
            addResource(player, PLAYER_STATE_RESOURCE_LUMBER, 1000)
        elseif action == "lumber_big" then
            addResource(player, PLAYER_STATE_RESOURCE_LUMBER, 10000)
        elseif action == "food" then
            setFoodCap(player, 300)
        elseif action == "heal" then
            unit = selectedOrMain(player)
            if unit then
                SetWidgetLife(unit, GetUnitState(unit, UNIT_STATE_MAX_LIFE))
                SetUnitState(unit, UNIT_STATE_MANA, GetUnitState(unit, UNIT_STATE_MAX_MANA))
            end
        elseif action == "mana" then
            unit = selectedOrMain(player)
            if unit then
                SetUnitState(unit, UNIT_STATE_MANA, GetUnitState(unit, UNIT_STATE_MAX_MANA))
            end
        elseif action == "level" then
            unit = selectedOrMain(player)
            if unit and IsUnitType(unit, UNIT_TYPE_HERO) then
                SetHeroLevel(unit, GetHeroLevel(unit) + 1, false)
            end
        elseif action == "level_10" then
            unit = selectedOrMain(player)
            if unit and IsUnitType(unit, UNIT_TYPE_HERO) then
                SetHeroLevel(unit, 10, false)
            end
        elseif action == "invul" then
            unit = selectedOrMain(player)
            if unit then SetUnitInvulnerable(unit, true) end
        elseif action == "vul" then
            unit = selectedOrMain(player)
            if unit then SetUnitInvulnerable(unit, false) end
        elseif action == "kill" then
            unit = selectedOrMain(player)
            if unit then KillUnit(unit) end
        elseif action == "remove" then
            unit = selectedOrMain(player)
            if unit then RemoveUnit(unit) end
        elseif action == "hero" then
            selectedHero(player)
        elseif action == "cooldown" then
            unit = selectedOrMain(player)
            if unit then
                UnitResetCooldown(unit)
            end
        elseif action == "nocd_toggle" then
            noCooldown[pid(player)] = not noCooldown[pid(player)]
            say(player, noCooldown[pid(player)] and "|cff80ff80No cooldown enabled.|r" or "|cffffcc00No cooldown disabled.|r")
        elseif action == "mana_toggle" then
            infiniteMana[pid(player)] = not infiniteMana[pid(player)]
            say(player, infiniteMana[pid(player)] and "|cff80ff80Infinite mana enabled.|r" or "|cffffcc00Infinite mana disabled.|r")
        elseif action == "tele_toggle" then
            teleportPatrol[pid(player)] = not teleportPatrol[pid(player)]
            say(player, teleportPatrol[pid(player)] and "|cff80ff80Patrol teleport enabled.|r" or "|cffffcc00Patrol teleport disabled.|r")
        elseif action == "invis" then
            setSelectedInvisible(player, true)
        elseif action == "vis" then
            setSelectedInvisible(player, false)
        elseif action == "pathoff" then
            setSelectedPathing(player, false)
        elseif action == "pathon" then
            setSelectedPathing(player, true)
        elseif action == "bfast_toggle" then
            setFastBuild(player, not fastBuild[pid(player)])
        elseif action == "ufast_toggle" then
            setFastResearch(player, not fastResearch[pid(player)])
        elseif action == "tdps_toggle" then
            setTitanDpsMeter(player, not titanDpsEnabled[pid(player)])
        elseif action == "autoh" then
            autoHealSelected(player, 100.0)
        elseif action == "autohoff" then
            clearAutoHealSelected(player)
        elseif action == "copy" then
            copySelected(player, 1)
        elseif action == "reveal" then
            local id = pid(player)
            if not revealModifiers[id] then
                revealModifiers[id] = CreateFogModifierRect(player, FOG_OF_WAR_VISIBLE, GetWorldBounds(), true, false)
            end
            FogModifierStart(revealModifiers[id])
        elseif action == "day" then
            SetTimeOfDay(12.0)
        elseif action == "night" then
            SetTimeOfDay(0.0)
        elseif action == "share_all" then
            local list = PlayerData.allWithFake()
            local i = 0
            while i < list:size() do
                local other = list:at(i):player()
                if other ~= player then
                    setSharedControl(other, player, true)
                end
                i = i + 1
            end
            list:destroy()
            closeAllianceUi(player)
        elseif string.sub(action, 1, 6) == "share_" then
            local targetId = tonumber(string.sub(action, 7)) or -1
            if targetId >= 0 and targetId < bj_MAX_PLAYER_SLOTS then
                setSharedControl(Player(targetId), player, true)
                closeAllianceUi(player)
            end
        end
    end

    local function setAlliancePair(a, b, allied)
        SetPlayerAlliance(a, b, ALLIANCE_PASSIVE, allied)
        SetPlayerAlliance(a, b, ALLIANCE_HELP_REQUEST, allied)
        SetPlayerAlliance(a, b, ALLIANCE_HELP_RESPONSE, allied)
        SetPlayerAlliance(a, b, ALLIANCE_SHARED_XP, allied)
        SetPlayerAlliance(a, b, ALLIANCE_SHARED_SPELLS, allied)
        SetPlayerAlliance(a, b, ALLIANCE_SHARED_VISION, allied)
    end

    local function playerColorByName(name)
        name = string.lower(name or "")
        if name == "red" then return PLAYER_COLOR_RED end
        if name == "blue" then return PLAYER_COLOR_BLUE end
        if name == "teal" or name == "cyan" then return PLAYER_COLOR_CYAN end
        if name == "purple" then return PLAYER_COLOR_PURPLE end
        if name == "yellow" then return PLAYER_COLOR_YELLOW end
        if name == "orange" then return PLAYER_COLOR_ORANGE end
        if name == "green" then return PLAYER_COLOR_GREEN end
        if name == "pink" then return PLAYER_COLOR_PINK end
        if name == "gray" or name == "grey" then return PLAYER_COLOR_LIGHT_GRAY end
        if name == "lb" or name == "lightblue" then return PLAYER_COLOR_LIGHT_BLUE end
        if name == "dg" or name == "darkgreen" then return PLAYER_COLOR_AQUA end
        if name == "brown" then return PLAYER_COLOR_BROWN end
        return nil
    end

    setSharedControl = function(owner, receiver, enabled)
        if rawget(_G, "SetPlayerAllianceStateFullControlBJ") then
            SetPlayerAllianceStateFullControlBJ(owner, receiver, enabled)
            SetPlayerAllianceStateControlBJ(owner, receiver, enabled)
            SetPlayerAllianceStateVisionBJ(owner, receiver, enabled)
            return
        end

        SetPlayerAlliance(owner, receiver, ALLIANCE_SHARED_CONTROL, enabled)
        SetPlayerAlliance(owner, receiver, ALLIANCE_SHARED_ADVANCED_CONTROL, enabled)
        SetPlayerAlliance(owner, receiver, ALLIANCE_SHARED_VISION, enabled)
    end

    closeAllianceUi = function(player)
        local function closeLocal()
            if GetLocalPlayer() == player and rawget(_G, "ForceUICancel") then
                ForceUICancel()
            end
        end

        closeLocal()
        GameTimer.after(0.03, closeLocal)
        GameTimer.after(0.25, closeLocal)
    end

    local function applyDebugTiming()
        if not GameSettings.getBool("DEBUG_FAST_TIMERS") then
            return
        end

        GameSettings.setReal("TITAN_SELECTION_TIME", 4.0)
        GameSettings.setReal("PICK_MODE_SELECTION_TIME", 4.0)
        GameSettings.setReal("DEFENDER_PICK_TIME", 6.0)
        GameSettings.setReal("TITAN_PICK_TIME", 5.0)
        GameSettings.setReal("TITAN_SPAWN_GRACE_TIME", 5.0)
        GameSettings.setInt("UNIQUE_PICK_MAX_CHOICES", 6)
    end

    local function forceDebugAllowed()
        if not GameSettings.getBool("FORCE_DEBUG_MODE") then
            return false
        end

        return PlayerData.countReal() <= 1 or GameSettings.getBool("DEBUG_ALLOW_MULTIPLAYER")
    end

    function DebugCheatPack.isDebugLobby()
        return forceDebugAllowed() or (PlayerData.countReal() == 1 and PlayerData.countFake() > 0)
    end

    function DebugCheatPack.isEnabled(player)
        return GameSettings.getBool("DEBUG") and enabled[pid(player)] == true
    end

    local function setFrameVisibleLocal(frame, player, visible)
        if frame and GetLocalPlayer() == player then
            BlzFrameSetVisible(frame, visible)
        end
    end

    local function anyTitanDpsEnabled()
        local i = 0

        while i < bj_MAX_PLAYER_SLOTS do
            if titanDpsEnabled[i] == true then
                return true
            end
            i = i + 1
        end
        return false
    end

    local function unitName(unit)
        if unit and GetUnitTypeId(unit) ~= 0 then
            return GetUnitName(unit)
        end
        return "No target"
    end

    local function updateTitanDpsFrame()
        local i = 0

        if not titanDpsFrame then
            return
        end

        while i < bj_MAX_PLAYER_SLOTS do
            local player = Player(i)
            if GetLocalPlayer() == player then
                local text = "|cffff6060DPS|r |cffffffff" .. I2S(R2I((titanDpsLast[i] or 0.0) + 0.5)) ..
                    "|r  |cff99b4d1Peak|r |cffffffff" .. I2S(R2I((titanDpsPeak[i] or 0.0) + 0.5)) ..
                    "|r  |cff99b4d1Total|r |cffffffff" .. I2S(R2I((titanDpsTotal[i] or 0.0) + 0.5)) ..
                    "|r  |cff99b4d1Target|r |cffffffff" .. unitName(titanDpsTarget[i]) .. "|r"
                BlzFrameSetVisible(titanDpsFrame, titanDpsEnabled[i] == true)
                BlzFrameSetText(titanDpsFrame, text)
            end
            i = i + 1
        end
    end

    local function createTitanDpsFrame()
        local gameUi = nil

        if titanDpsFrame or
            not rawget(_G, "BlzCreateFrameByType") or
            not rawget(_G, "BlzGetOriginFrame") then
            return
        end

        gameUi = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        titanDpsFrame = BlzCreateFrameByType("TEXT", "IDDebugTitanDpsMeter", gameUi, "", 0)
        BlzFrameSetAbsPoint(titanDpsFrame, FRAMEPOINT_TOPLEFT, 0.285, 0.535)
        BlzFrameSetText(titanDpsFrame, "")
        BlzFrameSetScale(titanDpsFrame, 1.30)
        BlzFrameSetVisible(titanDpsFrame, false)
    end

    local function ensureTitanDpsTimer()
        if titanDpsTimer then
            return
        end

        titanDpsTimer = GameTimer.every(1.0, function()
            local i = 0

            while i < bj_MAX_PLAYER_SLOTS do
                if titanDpsEnabled[i] == true and
                    (not titanDpsTarget[i] or GetUnitTypeId(titanDpsTarget[i]) == 0) then
                    titanDpsEnabled[i] = false
                    titanDpsTarget[i] = nil
                    titanDpsDamage[i] = 0.0
                    titanDpsLast[i] = 0.0
                else
                    titanDpsLast[i] = titanDpsDamage[i] or 0.0
                    titanDpsDamage[i] = 0.0
                    if titanDpsLast[i] > (titanDpsPeak[i] or 0.0) then
                        titanDpsPeak[i] = titanDpsLast[i]
                    end
                end
                i = i + 1
            end
            updateTitanDpsFrame()
        end)
    end

    local function tryRegisterTitanDps()
        local damageSystem = rawget(_G, "TitanDamageSystem")

        if titanDpsRegistered then
            return true
        end

        if damageSystem and damageSystem.onDamage then
            damageSystem.onDamage(function(context)
                local i = 0

                if not anyTitanDpsEnabled() then
                    return
                end

                while i < bj_MAX_PLAYER_SLOTS do
                    if titanDpsEnabled[i] == true and
                        titanDpsTarget[i] and
                        context.target == titanDpsTarget[i] and
                        context.damage > 0.0 then
                        titanDpsDamage[i] = (titanDpsDamage[i] or 0.0) + context.damage
                        titanDpsTotal[i] = (titanDpsTotal[i] or 0.0) + context.damage
                    end
                    i = i + 1
                end
            end)
            titanDpsRegistered = true
            return true
        end
        return false
    end

    local function ensureTitanDpsMeter()
        createTitanDpsFrame()
        ensureTitanDpsTimer()
        if not tryRegisterTitanDps() then
            GameTimer.after(0.50, ensureTitanDpsMeter)
        end
    end

    local function clearTitanDpsMeter(player, quiet)
        local id = pid(player)

        titanDpsEnabled[id] = false
        titanDpsTarget[id] = nil
        titanDpsDamage[id] = 0.0
        titanDpsLast[id] = 0.0
        titanDpsPeak[id] = 0.0
        titanDpsTotal[id] = 0.0
        updateTitanDpsFrame()
        if not quiet then
            say(player, "|cffffcc00DPS meter reset.|r")
        end
    end

    setTitanDpsMeter = function(player, enabled)
        local id = pid(player)
        local target = nil

        if enabled ~= true then
            clearTitanDpsMeter(player, false)
            return
        end

        target = selectedUnits[id]
        if not target or GetUnitTypeId(target) == 0 then
            say(player, "|cffff6060Select a unit first, then enable the DPS meter.|r")
            return
        end

        titanDpsEnabled[id] = true
        titanDpsTarget[id] = target
        titanDpsDamage[id] = 0.0
        titanDpsLast[id] = 0.0
        titanDpsPeak[id] = 0.0
        titanDpsTotal[id] = 0.0
        ensureTitanDpsMeter()
        updateTitanDpsFrame()
        say(player, "|cff80ff80DPS meter enabled for |r|cffffff80" .. unitName(target) .. "|r|cff80ff80.|r")
    end

    local function resetTitanDpsMeter(player)
        clearTitanDpsMeter(player, false)
    end

    local function updateUiForPlayer(player)
        local id = pid(player)
        local active = DebugCheatPack.isEnabled(player)
        local expanded = ui.expanded[id] == true
        local shareOpen = ui.shareOpen[id] == true

        if not ui.ready then
            return
        end

        setFrameVisibleLocal(ui.frames.toggle, player, active)
        setFrameVisibleLocal(ui.frames.panel, player, active and expanded)
        setFrameVisibleLocal(ui.frames.sharePanel, player, active and expanded and shareOpen)
        if titanDpsFrame and GetLocalPlayer() == player then
            BlzFrameSetVisible(titanDpsFrame, active and titanDpsEnabled[id] == true)
        end
        if GetLocalPlayer() == player and ui.frames.toggle then
            BlzFrameSetText(ui.frames.toggle, expanded and "DBG <" or "DBG >")
        end
    end

    local function setExpanded(player, expanded)
        ui.expanded[pid(player)] = expanded
        if not expanded then
            ui.shareOpen[pid(player)] = false
        end
        updateUiForPlayer(player)
    end

    function DebugCheatPack.activate(player)
        if not enabled[pid(player)] then
            enabled[pid(player)] = true
            say(player, "|cff00bfffCheatPack|r |cff80ff80activated.|r")
        end
        ensureTitanDpsMeter()
        updateUiForPlayer(player)
    end

    function DebugCheatPack.activateDebugLobby()
        if not GameSettings.getBool("DEBUG") then
            return false
        end

        if not DebugCheatPack.isDebugLobby() then
            return false
        end

        applyDebugTiming()

        local list = PlayerData.allReal()
        local i = 0
        while i < list:size() do
            DebugCheatPack.activate(list:at(i):player())
            i = i + 1
        end
        list:destroy()
        return true
    end

    local function createTooltip(gameUi, action, title, text)
        local tooltip = BlzCreateFrameByType("BACKDROP", "IDDebugTooltip" .. action, gameUi, "", 0)
        local titleFrame = nil
        local textFrame = nil

        BlzFrameSetSize(tooltip, 0.185, 0.052)
        BlzFrameSetAbsPoint(tooltip, FRAMEPOINT_TOPLEFT, 0.135, 0.515)
        if rawget(_G, "BlzFrameSetTexture") then
            BlzFrameSetTexture(tooltip, "ReplaceableTextures\\TeamColor\\TeamColor27.blp", 0, true)
        end
        BlzFrameSetAlpha(tooltip, 205)

        titleFrame = BlzCreateFrameByType("TEXT", "IDDebugTooltipTitle" .. action, tooltip, "", 0)
        BlzFrameSetPoint(titleFrame, FRAMEPOINT_TOPLEFT, tooltip, FRAMEPOINT_TOPLEFT, 0.008, -0.006)
        BlzFrameSetText(titleFrame, "|cff00bfff" .. title .. "|r")
        BlzFrameSetScale(titleFrame, 0.82)

        textFrame = BlzCreateFrameByType("TEXT", "IDDebugTooltipText" .. action, tooltip, "", 0)
        BlzFrameSetPoint(textFrame, FRAMEPOINT_TOPLEFT, tooltip, FRAMEPOINT_TOPLEFT, 0.008, -0.022)
        BlzFrameSetSize(textFrame, 0.170, 0.026)
        BlzFrameSetText(textFrame, "|cffdddddd" .. text .. "|r")
        BlzFrameSetScale(textFrame, 0.72)
        if rawget(_G, "BlzFrameSetTextAlignment") then
            BlzFrameSetTextAlignment(textFrame, TEXT_JUSTIFY_TOP, TEXT_JUSTIFY_LEFT)
        end

        BlzFrameSetVisible(tooltip, false)
        ui.tooltips[#ui.tooltips + 1] = tooltip
        return tooltip
    end

    local function createButton(gameUi, parent, data, x, y)
        local button = BlzCreateFrameByType("GLUETEXTBUTTON", "IDDebugButton" .. data.action, parent, "ScriptDialogButton", 0)
        local icon = BlzCreateFrameByType("BACKDROP", "IDDebugIcon" .. data.action, button, "", 0)
        local tooltip = createTooltip(gameUi, data.action, data.title, data.tooltip)
        local mark = nil

        BlzFrameSetSize(button, 0.025, 0.025)
        BlzFrameSetPoint(button, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, x, y)
        BlzFrameSetText(button, "")
        BlzFrameSetAllPoints(icon, button)
        if rawget(_G, "BlzFrameSetTexture") then
            BlzFrameSetTexture(icon, data.icon, 0, true)
        end
        BlzFrameSetEnable(icon, false)
        BlzFrameSetTooltip(button, tooltip)

        if data.mark then
            mark = BlzCreateFrameByType("TEXT", "IDDebugMark" .. data.action, button, "", 0)
            BlzFrameSetPoint(mark, FRAMEPOINT_BOTTOMRIGHT, button, FRAMEPOINT_BOTTOMRIGHT, -0.002, 0.002)
            BlzFrameSetText(mark, "|cffffcc00" .. data.mark .. "|r")
            BlzFrameSetScale(mark, 0.68)
        end

        ui.buttons[#ui.buttons + 1] = button
        ui.icons[#ui.icons + 1] = icon
        if data.localOnly then
            ui.localActionByButton[GetHandleId(button)] = data.action
        else
            ui.actionByButton[GetHandleId(button)] = data.action
        end
        return button
    end

    local function createShareButton(parent, playerId, x, y)
        local button = BlzCreateFrameByType("GLUETEXTBUTTON", "IDDebugShareButton" .. I2S(playerId), parent, "ScriptDialogButton", 0)
        local color = BlzCreateFrameByType("BACKDROP", "IDDebugShareColor" .. I2S(playerId), button, "", 0)
        local label = BlzCreateFrameByType("TEXT", "IDDebugShareLabel" .. I2S(playerId), button, "", 0)
        local suffix = I2S(playerId)

        if playerId < 10 then
            suffix = "0" .. suffix
        end

        BlzFrameSetSize(button, 0.026, 0.022)
        BlzFrameSetPoint(button, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, x, y)
        BlzFrameSetText(button, "")
        BlzFrameSetAllPoints(color, button)
        if rawget(_G, "BlzFrameSetTexture") then
            BlzFrameSetTexture(color, "ReplaceableTextures\\TeamColor\\TeamColor" .. suffix .. ".blp", 0, true)
        end
        BlzFrameSetAlpha(color, 210)
        BlzFrameSetEnable(color, false)
        BlzFrameSetPoint(label, FRAMEPOINT_CENTER, button, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetText(label, "|cffffffff" .. I2S(playerId) .. "|r")
        BlzFrameSetScale(label, 0.72)

        ui.buttons[#ui.buttons + 1] = button
        ui.actionByButton[GetHandleId(button)] = "share_" .. I2S(playerId)
        return button
    end

    local function createDebugUi()
        local gameUi = nil
        local trigger = nil
        local syncTrigger = nil
        local actions = {
            { action = "gold_big", title = "+10000 Gold", tooltip = "Adds 10000 gold to you.", icon = "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp", mark = "++" },
            { action = "lumber_big", title = "+10000 Lumber", tooltip = "Adds 10000 lumber to you.", icon = "ReplaceableTextures\\CommandButtons\\BTNBundleOfLumber.blp", mark = "++" },
            { action = "food", title = "Food Cap", tooltip = "Sets your food cap to 300.", icon = "ReplaceableTextures\\CommandButtons\\BTNFarm.blp" },
            { action = "hero", title = "Select Hero", tooltip = "Selects your main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNSelectHeroOn.blp" },
            { action = "heal", title = "Heal + Mana", tooltip = "Fully restores selected/main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNHealingSalve.blp" },
            { action = "mana", title = "Full Mana", tooltip = "Restores selected/main unit mana.", icon = "ReplaceableTextures\\CommandButtons\\BTNPotionOfClarity.blp" },
            { action = "level", title = "+1 Level", tooltip = "Adds one hero level.", icon = "ReplaceableTextures\\CommandButtons\\BTNTome.blp", mark = "+1" },
            { action = "level_10", title = "Level 10", tooltip = "Sets selected/main hero to level 10.", icon = "ReplaceableTextures\\CommandButtons\\BTNTomeRed.blp", mark = "10" },
            { action = "cooldown", title = "Reset Cooldowns", tooltip = "Resets selected/main unit cooldowns.", icon = "ReplaceableTextures\\CommandButtons\\BTNEngineeringUpgrade.blp" },
            { action = "nocd_toggle", title = "No Cooldown", tooltip = "Toggles automatic cooldown reset.", icon = "ReplaceableTextures\\CommandButtons\\BTNEngineeringUpgrade.blp", mark = "ON" },
            { action = "mana_toggle", title = "Infinite Mana", tooltip = "Toggles automatic mana refill on spell events.", icon = "ReplaceableTextures\\CommandButtons\\BTNPotionOfClarity.blp", mark = "ON" },
            { action = "invul", title = "Invulnerable", tooltip = "Makes selected/main unit invulnerable.", icon = "ReplaceableTextures\\CommandButtons\\BTNInvulnerable.blp" },
            { action = "vul", title = "Vulnerable", tooltip = "Removes invulnerability from selected/main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNCancel.blp" },
            { action = "invis", title = "Invisible", tooltip = "Adds permanent invisibility to selected/main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNInvisibility.blp" },
            { action = "vis", title = "Visible", tooltip = "Removes permanent invisibility from selected/main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNDustOfAppearance.blp" },
            { action = "pathoff", title = "Pathing Off", tooltip = "Disables collision for selected/main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNGhost.blp", mark = "OFF" },
            { action = "pathon", title = "Pathing On", tooltip = "Enables collision for selected/main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNHumanBuild.blp", mark = "ON" },
            { action = "bfast_toggle", title = "Fast Buildings", tooltip = "Toggles instant completion for placed buildings.", icon = "ReplaceableTextures\\CommandButtons\\BTNHumanBuild.blp", mark = "B" },
            { action = "ufast_toggle", title = "Fast Research", tooltip = "Toggles instant research completion.", icon = "ReplaceableTextures\\CommandButtons\\BTNEngineeringUpgrade.blp", mark = "R" },
            { action = "tdps_toggle", title = "DPS Meter", tooltip = "Tracks damage per second on the selected unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNCriticalStrike.blp", mark = "D" },
            { action = "autoh", title = "Auto Heal", tooltip = "Keeps selected/main unit at full life.", icon = "ReplaceableTextures\\CommandButtons\\BTNRejuvenation.blp", mark = "A" },
            { action = "autohoff", title = "Auto Heal Off", tooltip = "Stops auto heal for selected/main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", mark = "A" },
            { action = "copy", title = "Copy Unit", tooltip = "Creates one copy of selected/main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNMirrorImage.blp" },
            { action = "tele_toggle", title = "Patrol Teleport", tooltip = "Toggles old -tele patrol-to-point teleport.", icon = "ReplaceableTextures\\CommandButtons\\BTNMassTeleport.blp" },
            { action = "kill", title = "Kill Target", tooltip = "Kills selected/main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNDeathCoil.blp" },
            { action = "remove", title = "Remove Unit", tooltip = "Removes selected/main unit.", icon = "ReplaceableTextures\\CommandButtons\\BTNDust.blp" },
            { action = "reveal", title = "Reveal Map", tooltip = "Reveals the map for you.", icon = "ReplaceableTextures\\CommandButtons\\BTNSentryWard.blp" },
            { action = "day", title = "Noon", tooltip = "Sets time of day to noon.", icon = "ReplaceableTextures\\CommandButtons\\BTNDustOfAppearance.blp" },
            { action = "night", title = "Midnight", tooltip = "Sets time of day to midnight.", icon = "ReplaceableTextures\\CommandButtons\\BTNMoonStone.blp" },
            { action = "share_menu", title = "Share Control", tooltip = "Opens player share selection.", icon = "ReplaceableTextures\\CommandButtons\\BTNControlMagic.blp", localOnly = true }
        }
        local i = 1
        local playerIndex = 0

        if ui.ready or
            not rawget(_G, "BlzCreateFrameByType") or
            not rawget(_G, "BlzGetOriginFrame") or
            not rawget(_G, "BlzTriggerRegisterFrameEvent") or
            not rawget(_G, "BlzFrameSetTooltip") or
            not rawget(_G, "BlzGetTriggerFrame") then
            return
        end

        gameUi = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        ui.frames.toggle = BlzCreateFrameByType("GLUETEXTBUTTON", "IDDebugToggle", gameUi, "ScriptDialogButton", 0)
        BlzFrameSetSize(ui.frames.toggle, 0.055, 0.026)
        BlzFrameSetAbsPoint(ui.frames.toggle, FRAMEPOINT_TOPLEFT, 0.004, 0.520)
        BlzFrameSetText(ui.frames.toggle, "DBG >")
        BlzFrameSetVisible(ui.frames.toggle, false)

        ui.frames.panel = BlzCreateFrameByType("FRAME", "IDDebugPanel", gameUi, "", 0)
        BlzFrameSetSize(ui.frames.panel, 0.126, 0.306)
        BlzFrameSetAbsPoint(ui.frames.panel, FRAMEPOINT_TOPLEFT, 0.004, 0.490)
        BlzFrameSetVisible(ui.frames.panel, false)

        ui.frames.title = BlzCreateFrameByType("TEXT", "IDDebugTitle", ui.frames.panel, "", 0)
        BlzFrameSetPoint(ui.frames.title, FRAMEPOINT_TOPLEFT, ui.frames.panel, FRAMEPOINT_TOPLEFT, 0.010, -0.008)
        BlzFrameSetText(ui.frames.title, "|cff00bfffDebug|r")
        BlzFrameSetScale(ui.frames.title, 0.90)

        while i <= #actions do
            local index = i - 1
            local column = ModuloInteger(index, 4)
            local row = R2I(index / 4)
            createButton(gameUi, ui.frames.panel, actions[i], 0.009 + column * 0.029, -0.030 - row * 0.027)
            i = i + 1
        end

        ui.frames.sharePanel = BlzCreateFrameByType("FRAME", "IDDebugSharePanel", gameUi, "", 0)
        BlzFrameSetSize(ui.frames.sharePanel, 0.126, 0.112)
        BlzFrameSetAbsPoint(ui.frames.sharePanel, FRAMEPOINT_TOPLEFT, 0.134, 0.490)
        BlzFrameSetVisible(ui.frames.sharePanel, false)

        ui.frames.shareTitle = BlzCreateFrameByType("TEXT", "IDDebugShareTitle", ui.frames.sharePanel, "", 0)
        BlzFrameSetPoint(ui.frames.shareTitle, FRAMEPOINT_TOPLEFT, ui.frames.sharePanel, FRAMEPOINT_TOPLEFT, 0.008, -0.006)
        BlzFrameSetText(ui.frames.shareTitle, "|cff00bfffShare|r")
        BlzFrameSetScale(ui.frames.shareTitle, 0.78)

        local allButton = BlzCreateFrameByType("GLUETEXTBUTTON", "IDDebugShareAll", ui.frames.sharePanel, "ScriptDialogButton", 0)
        BlzFrameSetSize(allButton, 0.045, 0.022)
        BlzFrameSetPoint(allButton, FRAMEPOINT_TOPLEFT, ui.frames.sharePanel, FRAMEPOINT_TOPLEFT, 0.073, -0.006)
        BlzFrameSetText(allButton, "ALL")
        ui.buttons[#ui.buttons + 1] = allButton
        ui.actionByButton[GetHandleId(allButton)] = "share_all"

        i = 0
        while i < 12 do
            local column = ModuloInteger(i, 4)
            local row = R2I(i / 4)
            createShareButton(ui.frames.sharePanel, i, 0.008 + column * 0.029, -0.034 - row * 0.025)
            i = i + 1
        end

        trigger = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.toggle, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigger, function()
            local player = GetTriggerPlayer()
            setExpanded(player, not ui.expanded[pid(player)])
        end)

        trigger = CreateTrigger()
        i = 1
        while i <= #ui.buttons do
            BlzTriggerRegisterFrameEvent(trigger, ui.buttons[i], FRAMEEVENT_CONTROL_CLICK)
            i = i + 1
        end
        TriggerAddAction(trigger, function()
            local frame = BlzGetTriggerFrame()
            local action = frame and ui.actionByButton[GetHandleId(frame)] or nil
            local localAction = frame and ui.localActionByButton[GetHandleId(frame)] or nil
            local player = GetTriggerPlayer()

            if localAction == "share_menu" then
                ui.shareOpen[pid(player)] = not ui.shareOpen[pid(player)]
                updateUiForPlayer(player)
                return
            end

            if not action then
                return
            end

            if string.sub(action, 1, 6) == "share_" then
                ui.shareOpen[pid(player)] = false
                updateUiForPlayer(player)
            end

            if rawget(_G, "BlzSendSyncData") then
                if GetLocalPlayer() == player then
                    BlzSendSyncData("IDDbgUI", action)
                end
            else
                performUiAction(player, action)
            end
        end)

        if rawget(_G, "BlzTriggerRegisterPlayerSyncEvent") then
            syncTrigger = CreateTrigger()
            while playerIndex < bj_MAX_PLAYER_SLOTS do
                BlzTriggerRegisterPlayerSyncEvent(syncTrigger, Player(playerIndex), "IDDbgUI", false)
                playerIndex = playerIndex + 1
            end
            TriggerAddAction(syncTrigger, function()
                performUiAction(GetTriggerPlayer(), BlzGetTriggerSyncData())
            end)
        end

        ui.ready = true
        playerIndex = 0
        while playerIndex < bj_MAX_PLAYER_SLOTS do
            updateUiForPlayer(Player(playerIndex))
            playerIndex = playerIndex + 1
        end
    end

    local spellAssistTrigger = CreateTrigger()
    local orderAssistTrigger = CreateTrigger()
    local assistPlayerIndex = 0
    while assistPlayerIndex < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellAssistTrigger, Player(assistPlayerIndex), EVENT_PLAYER_UNIT_SPELL_CAST, nil)
        TriggerRegisterPlayerUnitEvent(spellAssistTrigger, Player(assistPlayerIndex), EVENT_PLAYER_UNIT_SPELL_CHANNEL, nil)
        TriggerRegisterPlayerUnitEvent(spellAssistTrigger, Player(assistPlayerIndex), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(spellAssistTrigger, Player(assistPlayerIndex), EVENT_PLAYER_UNIT_SPELL_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(spellAssistTrigger, Player(assistPlayerIndex), EVENT_PLAYER_UNIT_SPELL_ENDCAST, nil)
        TriggerRegisterPlayerUnitEvent(orderAssistTrigger, Player(assistPlayerIndex), EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, nil)
        assistPlayerIndex = assistPlayerIndex + 1
    end

    TriggerAddAction(spellAssistTrigger, function()
        local unit = GetTriggerUnit()
        local player = unit and GetOwningPlayer(unit) or nil
        if not player or not DebugCheatPack.isEnabled(player) then
            return
        end

        if noCooldown[pid(player)] then
            UnitResetCooldown(unit)
        end

        if infiniteMana[pid(player)] then
            SetUnitState(unit, UNIT_STATE_MANA, GetUnitState(unit, UNIT_STATE_MAX_MANA))
        end
    end)

    TriggerAddAction(orderAssistTrigger, function()
        local unit = GetTriggerUnit()
        local player = unit and GetOwningPlayer(unit) or nil
        if not player or not DebugCheatPack.isEnabled(player) or not teleportPatrol[pid(player)] then
            return
        end

        if GetIssuedOrderId() == 851990 then
            SetUnitPosition(unit, GetOrderPointX(), GetOrderPointY())
        end
    end)

    local fastBuildTrigger = CreateTrigger()
    local fastResearchTrigger = CreateTrigger()
    local fastPlayerIndex = 0
    while fastPlayerIndex < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(fastBuildTrigger, Player(fastPlayerIndex), EVENT_PLAYER_UNIT_CONSTRUCT_START, nil)
        TriggerRegisterPlayerUnitEvent(fastBuildTrigger, Player(fastPlayerIndex), EVENT_PLAYER_UNIT_UPGRADE_START, nil)
        TriggerRegisterPlayerUnitEvent(fastResearchTrigger, Player(fastPlayerIndex), EVENT_PLAYER_UNIT_RESEARCH_START, nil)
        fastPlayerIndex = fastPlayerIndex + 1
    end

    TriggerAddAction(fastBuildTrigger, function()
        local unit = GetTriggerUnit()
        local player = GetTriggerPlayer()

        if player and DebugCheatPack.isEnabled(player) and fastBuild[pid(player)] then
            finishBuildingNow(unit)
            GameTimer.after(0.03, function()
                finishBuildingNow(unit)
            end)
        end
    end)

    TriggerAddAction(fastResearchTrigger, function()
        local unit = GetTriggerUnit()
        local player = GetTriggerPlayer()
        local researchId = GetResearched()
        local targetLevel = 0

        if player and DebugCheatPack.isEnabled(player) and fastResearch[pid(player)] then
            if researchId and researchId ~= 0 then
                targetLevel = GetPlayerTechCount(player, researchId, true) + 1
            end
            finishResearchNow(player, unit, researchId, targetLevel)
            GameTimer.after(0.03, function()
                finishResearchNow(player, unit, researchId, targetLevel)
            end)
        end
    end)

    local selectionTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(selectionTrigger, Player(i), EVENT_PLAYER_UNIT_SELECTED, nil)
        i = i + 1
    end
    TriggerAddAction(selectionTrigger, function()
        selectedUnits[pid(GetTriggerPlayer())] = GetTriggerUnit()
    end)

    local function register(name, callback, description)
        Command[name].register(function(args)
            if requireEnabled(args) then
                callback(args)
            end
        end, description)
    end

    Command["-cheats"].register(function(args)
        local mode = string.lower(args:at(0) or "")
        if mode == "on" and DebugCheatPack.isDebugLobby() then
            DebugCheatPack.activate(args:player())
        elseif mode == "help" then
            say(args:player(), "|cff99b4d1Cheats:|r -gold, -lumber, -g, -l, -unit, -item, -heal, -kill, -invul, -vul, -lvl, -hp, -mp, -mana, -nocd, -infmana, -bfast, -ufast, -tdps, -tele, -invis, -vis, -pathoff, -pathon, -copy, -unitid, -itemid, -loc, -shareall")
        elseif DebugCheatPack.isEnabled(args:player()) then
            say(args:player(), "|cff80ff80Cheats active.|r")
        else
            say(args:player(), "|cffff6060Cheats inactive. Enable FORCE_DEBUG_MODE and DEBUG_ALLOW_MULTIPLAYER for multiplayer debug.|r")
        end
    end, "Shows or activates debug cheats.")

    register("-gold", function(args)
        local amount = requiredNumberArg(args, 0)
        if amount then
            addResource(args:player(), PLAYER_STATE_RESOURCE_GOLD, amount)
        else
            say(args:player(), "|cff99b4d1Usage:|r -gold <amount>")
        end
    end, "Adds gold to yourself.")

    register("-lumber", function(args)
        addResource(args:player(), PLAYER_STATE_RESOURCE_LUMBER, numberArg(args, 0, 1000))
    end, "Adds lumber to yourself.")

    register("-tdps", function(args)
        local mode = string.lower(args:at(0) or "")

        if mode == "on" or mode == "1" then
            setTitanDpsMeter(args:player(), true)
        elseif mode == "off" or mode == "0" then
            setTitanDpsMeter(args:player(), false)
        elseif mode == "reset" or mode == "r" then
            resetTitanDpsMeter(args:player())
        else
            setTitanDpsMeter(args:player(), not titanDpsEnabled[pid(args:player())])
        end
    end, "Tracks DPS on your currently selected unit.")

    register("-g", function(args)
        addResource(playerArg(args, 0, args:player()), PLAYER_STATE_RESOURCE_GOLD, numberArg(args, 1, 1000))
    end, "Adds gold to player id.")

    register("-l", function(args)
        addResource(playerArg(args, 0, args:player()), PLAYER_STATE_RESOURCE_LUMBER, numberArg(args, 1, 1000))
    end, "Adds lumber to player id.")

    register("-food", function(args)
        local amount = numberArg(args, 0, 300)
        setFoodCap(args:player(), amount)
    end, "Sets your food cap.")

    register("-f", function(args)
        local player = playerArg(args, 0, args:player())
        local amount = numberArg(args, 1, 300)
        setFoodCap(player, amount)
    end, "Sets food cap for player id.")

    register("-unit", function(args)
        local id = rawcode(args:at(0))
        local x, y, facing = targetPosition(args:player())
        if id ~= 0 and CreateUnit(args:player(), id, x, y, facing) then
            say(args:player(), "|cff80ff80Unit spawned.|r")
        else
            say(args:player(), "|cffff6060Invalid unit rawcode.|r")
        end
    end, "Spawns unit at selected/main unit.")

    register("-item", function(args)
        local id = rawcode(args:at(0))
        local x, y = targetPosition(args:player())
        if id ~= 0 and CreateItem(id, x, y) then
            say(args:player(), "|cff80ff80Item spawned.|r")
        else
            say(args:player(), "|cffff6060Invalid item rawcode.|r")
        end
    end, "Spawns item at selected/main unit.")

    register("-spawn", function(args)
        local id = rawcode(args:at(0))
        local x, y, facing = targetPosition(args:player())
        if id ~= 0 then
            CreateUnit(args:player(), id, x, y, facing)
            CreateItem(id, x, y)
            say(args:player(), "|cff80ff80Tried unit/item spawn for rawcode.|r")
        end
    end, "Legacy-style rawcode spawn helper.")

    register("-heal", function(args)
        local unit = selectedOrMain(args:player())
        if unit then
            SetWidgetLife(unit, GetUnitState(unit, UNIT_STATE_MAX_LIFE))
            SetUnitState(unit, UNIT_STATE_MANA, GetUnitState(unit, UNIT_STATE_MAX_MANA))
        end
    end, "Heals selected/main unit.")

    register("-kill", function(args)
        local unit = selectedOrMain(args:player())
        if unit then KillUnit(unit) end
    end, "Kills selected/main unit.")

    register("-invul", function(args)
        local unit = selectedOrMain(args:player())
        if unit then SetUnitInvulnerable(unit, true) end
    end, "Makes selected/main unit invulnerable.")

    register("-vul", function(args)
        local unit = selectedOrMain(args:player())
        if unit then SetUnitInvulnerable(unit, false) end
    end, "Makes selected/main unit vulnerable.")

    register("-lvl", function(args)
        local unit = selectedOrMain(args:player())
        if unit then SetHeroLevel(unit, numberArg(args, 0, 1), false) end
    end, "Sets hero level.")

    register("-xp", function(args)
        local unit = selectedOrMain(args:player())
        if unit then SetHeroXP(unit, numberArg(args, 0, 0), false) end
    end, "Sets hero XP.")

    register("-str", function(args)
        local amount = numberArg(args, 0, 0)
        local count = 0
        forSelectedOrMain(args:player(), function(unit)
            if IsUnitType(unit, UNIT_TYPE_HERO) then
                SetHeroStr(unit, amount, true)
                count = count + 1
            end
        end)
        say(args:player(), "|cff80ff80Set strength on " .. I2S(count) .. " hero(es).|r")
    end, "Sets selected hero strength.")

    register("-agi", function(args)
        local amount = numberArg(args, 0, 0)
        local count = 0
        forSelectedOrMain(args:player(), function(unit)
            if IsUnitType(unit, UNIT_TYPE_HERO) then
                SetHeroAgi(unit, amount, true)
                count = count + 1
            end
        end)
        say(args:player(), "|cff80ff80Set agility on " .. I2S(count) .. " hero(es).|r")
    end, "Sets selected hero agility.")

    register("-int", function(args)
        local amount = numberArg(args, 0, 0)
        local count = 0
        forSelectedOrMain(args:player(), function(unit)
            if IsUnitType(unit, UNIT_TYPE_HERO) then
                SetHeroInt(unit, amount, true)
                count = count + 1
            end
        end)
        say(args:player(), "|cff80ff80Set intelligence on " .. I2S(count) .. " hero(es).|r")
    end, "Sets selected hero intelligence.")

    register("-hp", function(args)
        local unit = selectedOrMain(args:player())
        if unit then SetWidgetLife(unit, numberArg(args, 0, GetUnitState(unit, UNIT_STATE_MAX_LIFE))) end
    end, "Sets selected/main unit HP.")

    register("-mp", function(args)
        local unit = selectedOrMain(args:player())
        if unit then SetUnitState(unit, UNIT_STATE_MANA, numberArg(args, 0, GetUnitState(unit, UNIT_STATE_MAX_MANA))) end
    end, "Sets selected/main unit mana.")

    register("-mana", function(args)
        local unit = selectedOrMain(args:player())
        if unit then SetUnitState(unit, UNIT_STATE_MANA, GetUnitState(unit, UNIT_STATE_MAX_MANA)) end
    end, "Restores selected/main unit mana.")

    register("-nocd", function(args)
        noCooldown[pid(args:player())] = true
        say(args:player(), "|cff80ff80No cooldown enabled. Use -cdon to disable.|r")
    end, "Resets cooldown after spell events.")

    register("-cdon", function(args)
        noCooldown[pid(args:player())] = false
        say(args:player(), "|cffffcc00No cooldown disabled.|r")
    end, "Disables no cooldown.")

    register("-infmana", function(args)
        infiniteMana[pid(args:player())] = true
        say(args:player(), "|cff80ff80Infinite mana enabled. Use -noinfmana to disable.|r")
    end, "Refills mana after spell events.")

    register("-noinfmana", function(args)
        infiniteMana[pid(args:player())] = false
        say(args:player(), "|cffffcc00Infinite mana disabled.|r")
    end, "Disables infinite mana.")

    register("-bfast", function(args)
        setFastBuild(args:player(), true)
    end, "Completes placed buildings and building upgrades immediately.")

    register("-nobfast", function(args)
        setFastBuild(args:player(), false)
    end, "Disables fast building completion.")

    register("-ufast", function(args)
        setFastResearch(args:player(), true)
    end, "Completes started researches immediately.")

    register("-noufast", function(args)
        setFastResearch(args:player(), false)
    end, "Disables fast research completion.")

    register("-ms", function(args)
        local unit = selectedOrMain(args:player())
        if unit then SetUnitMoveSpeed(unit, numberArg(args, 0, 522)) end
    end, "Sets selected/main unit movement speed.")

    register("-size", function(args)
        setSelectedScale(args:player(), numberArg(args, 0, 100))
    end, "Sets selected/main unit scale in percent.")

    register("-float", function(args)
        setSelectedFlyHeight(args:player(), numberArg(args, 0, 300), numberArg(args, 1, 300))
    end, "Sets selected/main unit fly height and rate.")

    register("-invis", function(args)
        setSelectedInvisible(args:player(), true)
    end, "Makes selected/main unit invisible.")

    register("-vis", function(args)
        setSelectedInvisible(args:player(), false)
    end, "Removes permanent invisibility.")

    register("-pathoff", function(args)
        setSelectedPathing(args:player(), false)
    end, "Disables selected/main unit collision.")

    register("-pathon", function(args)
        setSelectedPathing(args:player(), true)
    end, "Enables selected/main unit collision.")

    register("-stop", function(args)
        setSelectedPaused(args:player(), true)
    end, "Pauses selected/main unit.")

    register("-pause", function(args)
        setSelectedPaused(args:player(), true)
    end, "Pauses selected/main unit.")

    register("-resume", function(args)
        setSelectedPaused(args:player(), false)
    end, "Unpauses selected/main unit.")

    register("-debuff", function(args)
        debuffSelected(args:player())
    end, "Removes buffs from selected/main unit.")

    register("-autoh", function(args)
        autoHealSelected(args:player(), numberArg(args, 0, 100))
    end, "Keeps selected/main unit at given life percent.")

    register("-autohoff", function(args)
        clearAutoHealSelected(args:player())
    end, "Stops auto heal for selected/main unit.")

    register("-copy", function(args)
        copySelected(args:player(), numberArg(args, 0, 1))
    end, "Copies selected/main unit.")

    register("-revive", function(args)
        reviveSelectedHero(args:player())
    end, "Revives selected/main hero.")

    register("-attack", function(args)
        setSelectedAnimation(args:player(), "attack")
    end, "Plays attack animation.")

    register("-dead", function(args)
        setSelectedAnimation(args:player(), "death")
    end, "Plays death animation.")

    register("-birth", function(args)
        setSelectedAnimation(args:player(), "birth")
    end, "Plays birth animation.")

    register("-stand", function(args)
        setSelectedAnimation(args:player(), "stand")
    end, "Plays stand animation.")

    register("-unitid", function(args)
        local unit = selectedOrMain(args:player())
        if unit then say(args:player(), "|cff80ff80Unit rawcode:|r " .. rawcodeText(GetUnitTypeId(unit))) end
    end, "Shows selected/main unit rawcode.")

    register("-itemid", function(args)
        local unit = selectedOrMain(args:player())
        local item = unit and UnitItemInSlot(unit, 0) or nil
        if item then say(args:player(), "|cff80ff80Slot 1 item rawcode:|r " .. rawcodeText(GetItemTypeId(item))) end
    end, "Shows first inventory item rawcode.")

    register("-loc", function(args)
        local unit = selectedOrMain(args:player())
        if unit then say(args:player(), "|cff80ff80Location:|r " .. R2S(GetUnitX(unit)) .. ", " .. R2S(GetUnitY(unit))) end
    end, "Shows selected/main unit coordinates.")

    register("-tele", function(args)
        teleportPatrol[pid(args:player())] = true
        say(args:player(), "|cff80ff80Patrol teleport enabled. Use -note to disable.|r")
    end, "Turns patrol-point orders into teleport.")

    register("-note", function(args)
        teleportPatrol[pid(args:player())] = false
        say(args:player(), "|cffffcc00Patrol teleport disabled.|r")
    end, "Disables patrol teleport.")

    register("-nofood", function(args)
        forSelectedOrMain(args:player(), function(unit)
            SetUnitUseFood(unit, false)
        end)
    end, "Makes selected/main unit not use food.")

    register("-usefood", function(args)
        forSelectedOrMain(args:player(), function(unit)
            SetUnitUseFood(unit, true)
        end)
    end, "Makes selected/main unit use food.")

    register("-add", function(args)
        local unit = selectedOrMain(args:player())
        local id = rawcode(args:at(0))
        if unit and id ~= 0 then
            UnitAddAbility(unit, id)
            SetUnitAbilityLevel(unit, id, numberArg(args, 1, 1))
        end
    end, "Adds ability to selected/main unit.")

    register("-remove", function(args)
        local unit = selectedOrMain(args:player())
        local id = rawcode(args:at(0))
        if unit and id ~= 0 then UnitRemoveAbility(unit, id) end
    end, "Removes ability from selected/main unit.")

    register("-owner", function(args)
        local unit = selectedOrMain(args:player())
        local player = playerArg(args, 0, args:player())
        if unit then SetUnitOwner(unit, player, true) end
    end, "Changes selected/main unit owner.")

    register("-destroy", function(args)
        local unit = selectedOrMain(args:player())
        if unit then RemoveUnit(unit) end
    end, "Removes selected/main unit.")

    register("-setcolor", function(args)
        local color = playerColorByName(args:at(0))
        if color then
            SetPlayerColor(args:player(), color)
            forSelectedOrMain(args:player(), function(unit)
                SetUnitColor(unit, color)
            end)
        end
    end, "Sets your player color and selected unit color.")

    register("-sc", function(args)
        local target = playerArg(args, 0, args:player())
        local color = playerColorByName(args:at(1))
        if color then
            SetPlayerColor(target, color)
        end
    end, "Sets player id color.")

    register("-time", function(args)
        SetTimeOfDay(numberArg(args, 0, 12))
    end, "Sets time of day.")

    register("-mh", function(args)
        local id = pid(args:player())
        if not revealModifiers[id] then
            revealModifiers[id] = CreateFogModifierRect(args:player(), FOG_OF_WAR_VISIBLE, GetWorldBounds(), true, false)
        end
        FogModifierStart(revealModifiers[id])
        say(args:player(), "|cff80ff80Map reveal enabled.|r")
    end, "Reveals map for player.")

    register("-nomh", function(args)
        local id = pid(args:player())
        if revealModifiers[id] then
            FogModifierStop(revealModifiers[id])
            DestroyFogModifier(revealModifiers[id])
            revealModifiers[id] = nil
        end
        say(args:player(), "|cffffcc00Map reveal disabled.|r")
    end, "Stops map reveal for player.")

    register("-ally", function(args)
        setAlliancePair(args:player(), playerArg(args, 0, args:player()), true)
        setAlliancePair(playerArg(args, 0, args:player()), args:player(), true)
    end, "Allies player id.")

    register("-unally", function(args)
        setAlliancePair(args:player(), playerArg(args, 0, args:player()), false)
        setAlliancePair(playerArg(args, 0, args:player()), args:player(), false)
    end, "Unallies player id.")

    register("-allyall", function(args)
        local i = 0
        while i < bj_MAX_PLAYER_SLOTS do
            if Player(i) ~= args:player() then
                setAlliancePair(args:player(), Player(i), true)
                setAlliancePair(Player(i), args:player(), true)
            end
            i = i + 1
        end
    end, "Allies all player slots.")

    register("-unallyall", function(args)
        local i = 0
        while i < bj_MAX_PLAYER_SLOTS do
            if Player(i) ~= args:player() then
                setAlliancePair(args:player(), Player(i), false)
                setAlliancePair(Player(i), args:player(), false)
            end
            i = i + 1
        end
    end, "Unallies all player slots.")

    register("-share", function(args)
        local other = playerArg(args, 0, args:player())
        setSharedControl(other, args:player(), true)
        closeAllianceUi(args:player())
    end, "Gives shared control from player id to you.")

    register("-shareall", function(args)
        local target = args:player()
        local list = PlayerData.allWithFake()
        local i = 0
        local count = 0

        while i < list:size() do
            local player = list:at(i):player()
            if player ~= target then
                setSharedControl(player, target, true)
                count = count + 1
            end
            i = i + 1
        end

        list:destroy()
        closeAllianceUi(target)
        say(target, "|cff80ff80Shared control enabled from " .. I2S(count) .. " players.|r")
    end, "Gives you shared control over all active players.")

    register("-unshare", function(args)
        local other = playerArg(args, 0, args:player())
        setSharedControl(other, args:player(), false)
        closeAllianceUi(args:player())
    end, "Removes shared control from player id.")

    register("-soff", function(args)
        local target = args:player()
        local i = 0
        while i < bj_MAX_PLAYER_SLOTS do
            if Player(i) ~= target then
                setSharedControl(Player(i), target, false)
            end
            i = i + 1
        end
        closeAllianceUi(target)
        say(target, "|cffffcc00Shared control disabled from all players.|r")
    end, "Removes shared control from all players.")

    register("-setname", function(args)
        SetPlayerName(args:player(), args:joinedFrom(0))
    end, "Sets your player name.")

    register("-sn", function(args)
        SetPlayerName(playerArg(args, 0, args:player()), args:joinedFrom(1))
    end, "Sets player id name.")

    register("-say", function(args)
        DisplayTextToForce(bj_FORCE_ALL_PLAYERS, args:joinedFrom(0))
    end, "Broadcasts text.")

    GameTimer.after(0.03, createDebugUi)

    _G.DebugCheatPack = DebugCheatPack
end)

if Debug and Debug.endFile then Debug.endFile() end
