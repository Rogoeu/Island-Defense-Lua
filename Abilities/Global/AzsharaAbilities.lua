if Debug and Debug.beginFile then Debug.beginFile("Abilities/Global/AzsharaAbilities") end

OnInit("AzsharaAbilities", function(import)
    import.strict("AbilityMeta")
    import.strict("GameTimer")
    import.strict("IslandDefenseSystem")
    import.strict("PlayerData")
    import.strict("RacePickSystem")
    import.strict("UnitFilter")

    local IDS = {
        AZSHARA = FourCC("e01T"),
        DELAY_TECH = FourCC("R072"),
        BUILD_TOKEN_TECH = FourCC("R07J"),
        COOLDOWN_ABILITY = FourCC("A0TH")
    }

    local TECH_UNLOCK_TIME = 20.0 * 60.0
    local INITIAL_COOLDOWN = 15.0 * 60.0
    local BUILDER_DEATH_DELAY = 3.0 * 60.0
    local MAX_COOLDOWN = 15.0 * 60.0
    local TITAN_VISION_RADIUS = 128.0
    local TIMER_HEIGHT = 240.0
    local TIMER_PERIOD = 1.0

    local AzsharaAbilities = {}
    local azsharas = {}
    local azsharaByPlayerId = {}
    local grantedGameId = -1

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function isTitanPlayer(player)
        local data = PlayerData.get(player)
        return data and data:class() == PlayerData.CLASS_TITAN
    end

    local function trackedAzshara(player)
        local unit = azsharaByPlayerId[GetPlayerId(player)]

        if unit and GetUnitTypeId(unit) == IDS.AZSHARA and GetWidgetLife(unit) > 0.405 then
            return unit
        end
        return nil
    end

    local function setBuildToken(player, enabled)
        SetPlayerTechResearched(player, IDS.BUILD_TOKEN_TECH, enabled and 1 or 0)
    end

    local function refreshBuildToken(player)
        local available = trackedAzshara(player) == nil

        setBuildToken(player, available)
        -- R07J is the object-editor requirement. Tech max is the immediate menu lock that
        -- prevents a second construction order before Warcraft refreshes that requirement.
        if available then
            SetPlayerTechMaxAllowed(player, IDS.AZSHARA, -1)
        else
            SetPlayerTechMaxAllowed(player, IDS.AZSHARA, 0)
        end
    end

    local function findOwnedAzshara(player, ignored)
        local group = CreateGroup()
        local unit = nil
        local found = nil

        GroupEnumUnitsOfPlayer(group, player, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if unit ~= ignored and GetUnitTypeId(unit) == IDS.AZSHARA and isAlive(unit) then
                found = unit
                break
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return found
    end

    local function synchronizeAzsharaBuildToken(player)
        local playerId = GetPlayerId(player)
        local primary = trackedAzshara(player)
        local group = nil
        local unit = nil

        if not primary then
            primary = findOwnedAzshara(player, nil)
        end

        -- The construction event locks the menu immediately. This scan is a second line of
        -- defense for already-running maps or unusual scripted construction/removal paths.
        group = CreateGroup()
        GroupEnumUnitsOfPlayer(group, player, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if unit ~= primary and GetUnitTypeId(unit) == IDS.AZSHARA and isAlive(unit) then
                RemoveUnit(unit)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        azsharaByPlayerId[playerId] = primary
        refreshBuildToken(player)
    end

    local function releaseAzsharaBuildToken(player, unit)
        local playerId = GetPlayerId(player)

        if not unit or azsharaByPlayerId[playerId] == unit then
            azsharaByPlayerId[playerId] = nil
            refreshBuildToken(player)
        end
    end

    local function formatTime(seconds)
        local total = R2I(seconds + 0.999)
        local minutes = R2I(total / 60)
        local remaining = ModuloInteger(total, 60)

        return I2S(minutes) .. ":" .. (remaining < 10 and "0" or "") .. I2S(remaining)
    end

    local function cooldownRemaining(state)
        local remaining = 0.0

        if BlzGetUnitAbilityCooldownRemaining then
            remaining = BlzGetUnitAbilityCooldownRemaining(state.unit, IDS.COOLDOWN_ABILITY)
        else
            remaining = state.readyAt - Game.currentGameElapsed()
        end

        if remaining < 0.0 then
            return 0.0
        end
        return remaining
    end

    local function updateTimerVisibility(state)
        -- Text tags are client-local. Every client must explicitly keep this one visible.
        SetTextTagVisibility(state.timerTag, true)
    end

    local function destroyVision(state, playerId)
        local modifier = state.vision[playerId]

        if modifier then
            FogModifierStop(modifier)
            DestroyFogModifier(modifier)
            state.vision[playerId] = nil
        end
    end

    local function refreshTitanVision(state)
        local playerId = 0

        while playerId < bj_MAX_PLAYER_SLOTS do
            local player = Player(playerId)

            if isTitanPlayer(player) then
                if not state.vision[playerId] then
                    state.vision[playerId] = CreateFogModifierRadius(
                        player,
                        FOG_OF_WAR_VISIBLE,
                        GetUnitX(state.unit),
                        GetUnitY(state.unit),
                        TITAN_VISION_RADIUS,
                        true,
                        false
                    )
                    FogModifierStart(state.vision[playerId])
                end
            else
                destroyVision(state, playerId)
            end
            playerId = playerId + 1
        end
    end

    local function destroyAzshara(state)
        local playerId = 0

        while playerId < bj_MAX_PLAYER_SLOTS do
            destroyVision(state, playerId)
            playerId = playerId + 1
        end
        DestroyTextTag(state.timerTag)
        azsharas[state.id] = nil
        releaseAzsharaBuildToken(state.owner, state.unit)
    end

    local function updateAzshara(state)
        if not isAlive(state.unit) then
            destroyAzshara(state)
            return
        end

        SetTextTagPos(state.timerTag, GetUnitX(state.unit), GetUnitY(state.unit), TIMER_HEIGHT)
        SetTextTagText(state.timerTag, formatTime(cooldownRemaining(state)), TextTagSize2Height(11.0))
        updateTimerVisibility(state)
        refreshTitanVision(state)
    end

    local function startCooldown(state, seconds)
        local duration = seconds or 0.0

        if duration > MAX_COOLDOWN then
            duration = MAX_COOLDOWN
        end
        if duration < 0.0 then
            duration = 0.0
        end

        state.readyAt = Game.currentGameElapsed() + duration
        AbilityMeta.startCooldown(state.unit, IDS.COOLDOWN_ABILITY, duration)
        updateAzshara(state)
    end

    local function registerAzshara(unit)
        local id = GetHandleId(unit)
        local state = azsharas[id]

        if state then
            return state
        end

        state = {
            id = id,
            unit = unit,
            owner = GetOwningPlayer(unit),
            readyAt = 0.0,
            timerTag = CreateTextTag(),
            vision = {}
        }
        azsharaByPlayerId[GetPlayerId(state.owner)] = unit
        azsharas[id] = state
        SetTextTagColor(state.timerTag, 255, 220, 80, 255)
        SetTextTagPermanent(state.timerTag, true)
        startCooldown(state, INITIAL_COOLDOWN)
        return state
    end

    local function delayAllAzsharas()
        local states = {}
        local id = nil
        local i = 1

        for id, state in pairs(azsharas) do
            states[#states + 1] = state
        end
        table.sort(states, function(left, right)
            return left.id < right.id
        end)

        while i <= #states do
            local state = states[i]
            if isAlive(state.unit) then
                startCooldown(state, cooldownRemaining(state) + BUILDER_DEATH_DELAY)
            else
                destroyAzshara(state)
            end
            i = i + 1
        end
    end

    local function grantDelayTech()
        local list = PlayerData.allWithFake()
        local i = 0

        while i < list:size() do
            local player = list:at(i):player()

            SetPlayerTechResearched(player, IDS.DELAY_TECH, 1)
            refreshBuildToken(player)
            i = i + 1
        end
        list:destroy()
    end

    local function update()
        local gameId = Game.id()
        local states = {}
        local id = nil
        local i = 1

        if not Game.isState(Game.STATE_STARTED) then
            return
        end

        if grantedGameId ~= gameId and Game.currentGameElapsed() >= TECH_UNLOCK_TIME then
            grantDelayTech()
            grantedGameId = gameId
        end

        -- Keep R07J and the immediate build-menu lock in sync with live/removed Azsharas.
        local players = PlayerData.allWithFake()
        local playerIndex = 0
        while playerIndex < players:size() do
            synchronizeAzsharaBuildToken(players:at(playerIndex):player())
            playerIndex = playerIndex + 1
        end
        players:destroy()

        for id, state in pairs(azsharas) do
            states[#states + 1] = state
        end
        table.sort(states, function(left, right)
            return left.id < right.id
        end)
        while i <= #states do
            updateAzshara(states[i])
            i = i + 1
        end
    end

    function AzsharaAbilities.cooldownRemaining(unit)
        local state = unit and azsharas[GetHandleId(unit)] or nil
        return state and cooldownRemaining(state) or 0.0
    end

    function AzsharaAbilities.delayAll(seconds)
        local states = {}
        local id = nil
        local i = 1

        for id, state in pairs(azsharas) do
            states[#states + 1] = state
        end
        table.sort(states, function(left, right)
            return left.id < right.id
        end)
        while i <= #states do
            local state = states[i]
            startCooldown(state, cooldownRemaining(state) + (seconds or BUILDER_DEATH_DELAY))
            i = i + 1
        end
    end

    local function onConstructFinish()
        local structure = GetConstructedStructure()

        if structure and GetUnitTypeId(structure) == IDS.AZSHARA then
            registerAzshara(structure)
        end
    end

    local function onConstructStart()
        local structure = GetConstructedStructure()
        local owner = structure and GetOwningPlayer(structure) or nil
        local existing = nil

        if not structure or not owner or GetUnitTypeId(structure) ~= IDS.AZSHARA then
            return
        end

        -- Check the actual owner list as well. That catches an Azshara created before this
        -- trigger was registered and prevents a second simultaneous construction.
        existing = findOwnedAzshara(owner, structure)
        if existing and existing ~= structure then
            -- Covers simultaneous build orders even if the object-editor requirement has not refreshed yet.
            RemoveUnit(structure)
            return
        end

        azsharaByPlayerId[GetPlayerId(owner)] = structure
        refreshBuildToken(owner)
    end

    local function onConstructCancel()
        local structure = GetCancelledStructure()

        if structure and GetUnitTypeId(structure) == IDS.AZSHARA then
            releaseAzsharaBuildToken(GetOwningPlayer(structure), structure)
        end
    end

    local function onDeath()
        local dead = GetTriggerUnit()

        if dead and GetUnitTypeId(dead) == IDS.AZSHARA then
            releaseAzsharaBuildToken(GetOwningPlayer(dead), dead)
        end
        if dead and UnitFilter.isBuilder(dead) then
            delayAllAzsharas()
        end
    end

    local constructTrigger = CreateTrigger()
    local constructStartTrigger = CreateTrigger()
    local constructCancelTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(constructTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(constructStartTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_START, nil)
        TriggerRegisterPlayerUnitEvent(constructCancelTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_CANCEL, nil)
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

    TriggerAddAction(constructTrigger, function() guarded(onConstructFinish) end)
    TriggerAddAction(constructStartTrigger, function() guarded(onConstructStart) end)
    TriggerAddAction(constructCancelTrigger, function() guarded(onConstructCancel) end)
    TriggerAddAction(deathTrigger, function() guarded(onDeath) end)
    GameTimer.every(TIMER_PERIOD, update)

    -- Keep the entry in every builder's menu from spawn onward. R072 remains the
    -- actual 20-minute requirement, so Warcraft displays it as unavailable until then.
    RacePickSystem.onBuilderSpawn(function(playerData)
        refreshBuildToken(playerData:player())
    end)

    AzsharaAbilities.ids = IDS

    _G.AzsharaAbilities = AzsharaAbilities
end)

if Debug and Debug.endFile then Debug.endFile() end
