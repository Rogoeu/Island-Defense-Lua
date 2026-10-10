if Debug and Debug.beginFile then Debug.beginFile("Systems/ExperienceSystem") end

OnInit("ExperienceSystem", function(import)
    import.strict("GameTimer")
    import.strict("GameSettings")
    import.strict("PlayerData")
    import.strict("IslandDefenseSystem")
    import.strict("UnitFilter")
    import.strict("DefenderGhostBuildings")

    local FEED_DATA = {}
    local processedDeaths = {}
    local updateTimer = nil
    local recentDecayMult = 1.0

    local ExperienceSystem = {}
    local PlayerDataFed = {}

    local BURST_COEFF = 0.30
    local BURST_MIN_MULT = 0.50
    local BURST_HALFLIFE = 60.0
    local BURST_GRACE_TIME = 0.8

    local function ensureReal(key, value)
        if not GameSettings.exists(key) then
            GameSettings.setReal(key, value)
        end
    end

    local function ensureBool(key, value)
        if not GameSettings.exists(key) then
            GameSettings.setBool(key, value)
        end
    end

    local function ensureInt(key, value)
        if not GameSettings.exists(key) then
            GameSettings.setInt(key, value)
        end
    end

    local function isAlive(unit)
        return unit and GetWidgetLife(unit) > 0.405
    end

    local function isTitanSide(playerData)
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function currentElapsed()
        if rawget(_G, "Game") and Game.currentGameElapsed then
            return Game.currentGameElapsed()
        end
        return 0.0
    end

    local function raceDifficulty(playerData)
        local race = playerData:race()
        if race ~= NullRace.instance() and race.difficulty then
            return race:difficulty()
        end
        return 1.0
    end

    function PlayerDataFed.get(playerData)
        if not playerData then
            return nil
        end

        local id = playerData:id()
        if not FEED_DATA[id] then
            FEED_DATA[id] = {
                playerData = playerData,
                rate = 1.0,
                fed = 0,
                goldFed = 0,
                fedRecent = 0.0,
                burstMult = 1.0,
                burstPending = false,
                burstApplyAt = 0.0
            }
        end
        return FEED_DATA[id]
    end

    function PlayerDataFed.reset()
        FEED_DATA = {}
    end

    function PlayerDataFed.factor(data)
        local difficulty = raceDifficulty(data.playerData)
        if difficulty == 0.0 then
            return 0.0
        end
        return 0.95 + (difficulty * 0.05)
    end

    function PlayerDataFed.add(data, feed)
        data.fed = data.fed + (feed or 0)
    end

    function PlayerDataFed.addGold(data, gold)
        data.goldFed = data.goldFed + (gold or 0)
    end

    function PlayerDataFed.addRecent(data, feed)
        data.fedRecent = data.fedRecent + (feed or 0)
    end

    function PlayerDataFed.decayRecent(data, mult)
        data.fedRecent = data.fedRecent * mult
        if data.fedRecent < 0.01 then
            data.fedRecent = 0.0
        end
    end

    function PlayerDataFed.requestBurstGrace(data)
        data.burstPending = true
        data.burstApplyAt = currentElapsed() + BURST_GRACE_TIME
    end

    function PlayerDataFed.updateRate(data)
        local rate = PlayerDataFed.factor(data)
        local burstMult = 1.0
        local reductionEnabled = GameSettings.getBool("TITAN_EXP_REDUCTION_ENABLED")

        if reductionEnabled then
            local time = currentElapsed() / (60.0 * 60.0)
            if time >= 1.0 then
                time = 0.0
                reductionEnabled = false
                GameSettings.setBool("TITAN_EXP_REDUCTION_ENABLED", false)
                Game.say("|cff87cefaThe Feed Reduction System has been disabled.|r")
            end

            rate = PlayerDataFed.factor(data) * ((((-data.fed * 0.05) / 100.0) * (1.0 - time)) + 1.0)
            if rate <= 0.25 then
                rate = 0.25
            end
        end

        if reductionEnabled then
            if data.burstPending and currentElapsed() < data.burstApplyAt then
                burstMult = data.burstMult
            else
                data.burstPending = false
                burstMult = 1.0 - ((data.fedRecent * BURST_COEFF) / 100.0)
                if burstMult < BURST_MIN_MULT then
                    burstMult = BURST_MIN_MULT
                end
            end
        end

        data.burstMult = burstMult
        rate = rate * burstMult
        rate = rate * GameSettings.getReal("TITAN_EXP_GLOBAL_FACTOR")

        local activeOrKilled = PlayerData.countClass(PlayerData.CLASS_DEFENDER) + GameSettings.getInt("KILLED_DEFENDERS_COUNT")
        rate = rate * (1.0 + ((10 - activeOrKilled) * GameSettings.getReal("TITAN_EXP_MISSING_PLAYER_FACTOR")))

        if GameSettings.getBool("TITAN_EXP_GLOBAL_FACTOR_DOUBLED") then
            rate = rate * 2.0
        end

        data.rate = rate
    end

    function PlayerDataFed.updateRates()
        local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local i = 0

        while i < list:size() do
            PlayerDataFed.updateRate(PlayerDataFed.get(list:at(i)))
            i = i + 1
        end

        list:destroy()
    end

    function PlayerDataFed.stats(playerData)
        local data = PlayerDataFed.get(playerData)
        if not data then
            return 0, 0.0, 1.0, 1.0, 0
        end
        return data.fed, data.fedRecent, data.rate, data.burstMult, data.goldFed
    end

    function ExperienceSystem.defaultSettings()
        ensureReal("TITAN_EXP_GLOBAL_FACTOR", 1.0)
        ensureReal("TITAN_EXP_SHARE_FACTOR", 0.75)
        ensureBool("TITAN_EXP_GLOBAL_FACTOR_DOUBLED", false)
        ensureBool("TITAN_EXP_REDUCTION_ENABLED", true)
        ensureReal("TITAN_EXP_MISSING_PLAYER_FACTOR", 0.06)
        ensureReal("TITAN_EXP_NEUTRAL_FACTOR", 0.5)
        ensureReal("DEFENDER_EXP_RATE_TIME", 0.20)
        ensureInt("KILLED_DEFENDERS_COUNT", 0)
        ensureBool("GOLD_FEED_TRACKING_ENABLED", true)
        ensureBool("GOLD_FEED_FALLBACK_TO_EXP_FEED", false)
        ensureInt("GC_GOLD_AMOUNT", 10)
        ensureInt("GC_CHANCE_ROLL_MAX", 20)
        ensureInt("GC_CHANCE_SUCCESS_MAX", 5)
    end

    function ExperienceSystem.initialize()
        ExperienceSystem.defaultSettings()
        GameSettings.setInt("KILLED_DEFENDERS_COUNT", 0)
        PlayerDataFed.reset()
        processedDeaths = {}

        if updateTimer then
            updateTimer:destroy()
            updateTimer = nil
        end

        local dt = GameSettings.getReal("DEFENDER_EXP_RATE_TIME")
        recentDecayMult = Pow(0.5, dt / BURST_HALFLIFE)
        updateTimer = GameTimer.every(dt, function()
            if GameSettings.getBool("TITAN_EXP_REDUCTION_ENABLED") then
                local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
                local i = 0
                while i < list:size() do
                    PlayerDataFed.decayRecent(PlayerDataFed.get(list:at(i)), recentDecayMult)
                    i = i + 1
                end
                list:destroy()
            end
            PlayerDataFed.updateRates()
        end)
    end

    function ExperienceSystem.terminate()
        if updateTimer then
            updateTimer:destroy()
            updateTimer = nil
        end
    end

    function ExperienceSystem.calculateFeed(feeder, victim)
        local feed = GetUnitPointValue(victim)
        if feed <= 0 then
            feed = 1
        end

        if feeder then
            return R2I(feed * feeder.rate)
        end
        return R2I(feed * GameSettings.getReal("TITAN_EXP_NEUTRAL_FACTOR"))
    end

    function ExperienceSystem.unitGoldBounty(victim)
        local base = BlzGetUnitIntegerField(victim, UNIT_IF_GOLD_BOUNTY_AWARDED_BASE)
        local dice = BlzGetUnitIntegerField(victim, UNIT_IF_GOLD_BOUNTY_AWARDED_NUMBER_OF_DICE)
        local sides = BlzGetUnitIntegerField(victim, UNIT_IF_GOLD_BOUNTY_AWARDED_SIDES_PER_DIE)

        if dice > 0 and sides > 0 then
            return base + GetRandomInt(dice, dice * sides)
        end

        return base
    end

    function ExperienceSystem.calculateGoldFeed(victim)
        if not victim or not GameSettings.getBool("GOLD_FEED_TRACKING_ENABLED") then
            return 0
        end

        return ExperienceSystem.unitGoldBounty(victim)
    end

    function ExperienceSystem.goldCoinEnabled()
        return GameSettings.getStr("TWEAK_GC") == "on"
    end

    function ExperienceSystem.tryGoldCoinDrop(killer, victim)
        if not ExperienceSystem.goldCoinEnabled() or not killer or not victim then
            return false
        end

        local rollMax = GameSettings.getInt("GC_CHANCE_ROLL_MAX")
        local successMax = GameSettings.getInt("GC_CHANCE_SUCCESS_MAX")
        local gold = GameSettings.getInt("GC_GOLD_AMOUNT")

        if rollMax <= 0 or successMax < 0 or gold <= 0 then
            return false
        end

        if GetRandomInt(0, rollMax) > successMax then
            return false
        end

        local owner = GetOwningPlayer(killer)
        SetPlayerState(owner, PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(owner, PLAYER_STATE_RESOURCE_GOLD) + gold)

        local tag = CreateTextTag()
        SetTextTagText(tag, "|cffffcc00+ " .. I2S(gold), TextTagSize2Height(8))
        SetTextTagPos(tag, GetUnitX(victim), GetUnitY(victim), 100)
        SetTextTagVisibility(tag, true)
        SetTextTagPermanent(tag, false)
        SetTextTagLifespan(tag, 1.8)
        SetTextTagFadepoint(tag, 1.4)
        SetTextTagVelocity(tag, TextTagSpeed2Velocity(0), TextTagSpeed2Velocity(44))
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Transmute\\PileofGold.mdl", victim, "origin"))
        return true
    end

    function ExperienceSystem.giveExperience(unit, experience)
        if not unit or experience <= 0 then
            return
        end

        local owner = GetOwningPlayer(unit)
        local playerData = PlayerData.get(owner)
        local level = GetHeroLevel(unit)

        if level >= 12 then
            SetPlayerState(owner, PLAYER_STATE_RESOURCE_LUMBER, GetPlayerState(owner, PLAYER_STATE_RESOURCE_LUMBER) + experience)
            return
        end

        SuspendHeroXP(unit, false)
        AddHeroXP(unit, experience, true)
        SuspendHeroXP(unit, true)

        local bonusWood = R2I(experience * 0.25)
        if bonusWood > 0 then
            if playerData then
                playerData:setLumber(playerData:lumber() + bonusWood)
            else
                SetPlayerState(owner, PLAYER_STATE_RESOURCE_LUMBER, GetPlayerState(owner, PLAYER_STATE_RESOURCE_LUMBER) + bonusWood)
            end
        end
    end

    function ExperienceSystem.giveExperienceAsFeed(feeder, unit, experience, doBurst)
        if feeder then
            PlayerDataFed.add(feeder, experience)
            if doBurst and GameSettings.getBool("TITAN_EXP_REDUCTION_ENABLED") then
                PlayerDataFed.addRecent(feeder, experience)
                PlayerDataFed.requestBurstGrace(feeder)
            end
        end

        ExperienceSystem.giveExperience(unit, experience)
    end

    function ExperienceSystem.shareExperienceAsFeedFromPoint(feeder, x, y, feed, excluded, doBurst)
        local group = CreateGroup()
        local units = {}
        local factors = {}
        local total = 0.0
        local count = 0

        GroupEnumUnitsInRange(group, x, y, 4000.0, nil)

        local unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)

            local ownerData = PlayerData.get(GetOwningPlayer(unit))
            if unit ~= excluded and isAlive(unit) and IsUnitType(unit, UNIT_TYPE_HERO) and isTitanSide(ownerData) then
                local dx = x - GetUnitX(unit)
                local dy = y - GetUnitY(unit)
                local factor = 1.0 - (((SquareRoot(dx * dx + dy * dy) - 400.0) / 400.0) * 0.10)
                if factor < 0.0 then
                    factor = 0.0
                elseif factor > 1.0 then
                    factor = 1.0
                end

                if factor > 0.0 then
                    count = count + 1
                    units[count] = unit
                    factors[count] = factor
                    total = total + factor
                end
            end

            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)

        if total <= 0.0 then
            return
        end

        local i = 1
        while i <= count do
            local final = R2I((feed * (factors[i] / total)) * GameSettings.getReal("TITAN_EXP_SHARE_FACTOR"))
            ExperienceSystem.giveExperienceAsFeed(feeder, units[i], final, doBurst)
            i = i + 1
        end
    end

    function ExperienceSystem.onDeathForTitan()
        if not Game.isState(Game.STATE_STARTED) then
            return
        end

        local killer = GetKillingUnit()
        local victim = GetTriggerUnit()
        if not killer or not victim then
            return
        end
        if processedDeaths[victim] then
            return
        end
        processedDeaths[victim] = true
        GameTimer.after(1.0, function()
            processedDeaths[victim] = nil
        end)

        local killerData = PlayerData.get(GetOwningPlayer(killer))
        local victimData = PlayerData.get(GetOwningPlayer(victim))
        local ghostCreditData = nil
        local victimIsNeutral = not victimData and GetOwningPlayer(victim) == Player(PLAYER_NEUTRAL_AGGRESSIVE)

        if not isTitanSide(killerData) then
            return
        end
        if victimIsNeutral then
            ghostCreditData = DefenderGhostBuildings.feedCreditOwner(victim)
        end
        if not victimIsNeutral and (not victimData or victimData:class() ~= PlayerData.CLASS_DEFENDER) then
            return
        end
        if victimData and IsUnitType(victim, UNIT_TYPE_SUMMONED) then
            return
        end
        -- The old feed trigger ignored temporary wards and illusions entirely.
        -- Otherwise their deaths also create lumber through giveExperience().
        if UnitFilter.isWard(victim) or IsUnitIllusion(victim) then
            return
        end

        local feeder = nil
        if ghostCreditData then
            feeder = PlayerDataFed.get(ghostCreditData)
            DefenderGhostBuildings.clearFeedCredit(victim)
        elseif victimData then
            feeder = PlayerDataFed.get(victimData)
        end

        if feeder then
            PlayerDataFed.updateRate(feeder)
        end

        local feed = ExperienceSystem.calculateFeed(feeder, victim)
        local doBurst = GetUnitAbilityLevel(victim, FourCC("A0CN")) > 0
        local goldFeed = ExperienceSystem.calculateGoldFeed(victim)

        if feeder and goldFeed > 0 then
            PlayerDataFed.addGold(feeder, goldFeed)
        end

        if IsUnitType(killer, UNIT_TYPE_HERO) then
            ExperienceSystem.giveExperienceAsFeed(feeder, killer, feed, doBurst)
        end

        ExperienceSystem.shareExperienceAsFeedFromPoint(feeder, GetUnitX(victim), GetUnitY(victim), feed, killer, doBurst)
    end

    local deathTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end

    TriggerAddAction(deathTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(ExperienceSystem.onDeathForTitan)
        else
            ExperienceSystem.onDeathForTitan()
        end
    end)

    if rawget(_G, "Command") then
        Command["-feedstats"].register(function(args)
            local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
            local i = 0
            while i < list:size() do
                local playerData = list:at(i)
                local data = PlayerDataFed.get(playerData)
                Command.say(args:player(),
                    playerData:name() ..
                    " feed=" .. I2S(data.fed) ..
                    " goldfed=" .. I2S(data.goldFed) ..
                    " recent=" .. I2S(R2I(data.fedRecent)) ..
                    " rate=" .. I2S(R2I(data.rate * 100.0)) .. "%")
                i = i + 1
            end
            list:destroy()
        end, "Shows defender feed reduction stats.")

        Command["-feedreduction"].register(function(args)
            local value = StringCase(args:at(0), false)
            if value == "on" then
                GameSettings.setBool("TITAN_EXP_REDUCTION_ENABLED", true)
            elseif value == "off" then
                GameSettings.setBool("TITAN_EXP_REDUCTION_ENABLED", false)
            end

            if GameSettings.getBool("TITAN_EXP_REDUCTION_ENABLED") then
                Command.say(args:player(), "|cff80ff80Feed reduction enabled.|r")
            else
                Command.say(args:player(), "|cffff6060Feed reduction disabled.|r")
            end
        end, "Toggles titan feed reduction: -feedreduction on/off")
    end

    _G.ExperienceSystem = ExperienceSystem
    _G.PlayerDataFed = PlayerDataFed
end)

if Debug and Debug.endFile then Debug.endFile() end
