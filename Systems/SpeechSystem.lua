if Debug and Debug.beginFile then Debug.beginFile("Systems/SpeechSystem") end

OnInit("SpeechSystem", function(import)
    import.strict("CommandRegistry")
    import.strict("GameTimer")
    import.strict("IslandDefenseSystem")
    import.strict("PlayerData")
    import.strict("StringLib")

    local COOLDOWN_SECONDS = 5.0
    local speeches = {}
    local silenced = {}
    local coolingDown = {}
    local cooldownToken = {}

    local SpeechSystem = {}

    local function normalize(text)
        return StringCase(StringTrim(text or ""), false)
    end

    local function builderClass(classValue)
        return classValue == PlayerData.CLASS_DEFENDER or
            classValue == PlayerData.CLASS_OBSERVER
    end

    local function titanClass(classValue)
        return classValue == PlayerData.CLASS_TITAN or
            classValue == PlayerData.CLASS_MINION
    end

    local function register(phrase, soundName, classFilter)
        speeches[normalize(phrase)] = {
            soundName = soundName,
            classFilter = classFilter
        }
    end

    local function registerBuilderSpeeches()
        local entries = {
            { "im waiting", "gg_snd_Builder_ImWaiting" },
            { "this is too easy", "gg_snd_Builder_ThisIsTooEasy" },
            { "by the gods", "gg_snd_Builder_ByTheGodsYourAnnoying" },
            { "aahh", "gg_snd_Builder_Aahh" },
            { "what", "gg_snd_Builder_What" },
            { "begone", "gg_snd_Builder_BeGoneSpawnOfDarkness" },
            { "i grow tired of waiting", "gg_snd_Builder_IGrowTiredOfWaiting" },
            { "lolol", "gg_snd_Builder_Lolol" },
            { "huh", "gg_snd_Builder_Huh" },
            { "yes", "gg_snd_Builder_Yes" },
            { "why not", "gg_snd_Builder_WhyNot" },
            { "bring it on", "gg_snd_Builder_BringItOn" },
            { "time to die", "gg_snd_Builder_TimeToDie" },
            { "let me at them", "gg_snd_Builder_LetMeAtThem" },
            { "youve done well", "gg_snd_Builder_YouveDoneWell" },
            { "you've done well", "gg_snd_Builder_YouveDoneWell" },
            { "lets get the hell out of here", "gg_snd_Builder_LetsGetTheHellOutOfHere" },
            { "let's get the hell out of here", "gg_snd_Builder_LetsGetTheHellOutOfHere" },
            { "no not that way", "gg_snd_Builder_NoNotThatWay" },
            { "to hell with your apologies", "gg_snd_Builder_ToHellWithYourApologies" },
            { "then lets go", "gg_snd_Builder_ThenLetsGoIDontWantToKeepTheBastardWaiting" },
            { "then let's go", "gg_snd_Builder_ThenLetsGoIDontWantToKeepTheBastardWaiting" },
            { "damned cowards", "gg_snd_Builder_DamnedCowards" },
            { "you bastard", "gg_snd_Builder_YouBastard" },
            { "what the hell is that", "gg_snd_Builder_WhatTheHellIsThat" },
            { "here they come boys", "gg_snd_Builder_HereTheyComeBoysStandYourGround" },
            { "take cover", "gg_snd_Builder_TakeCover" },
            { "hes escaping", "gg_snd_Builder_HesEscapingKillHim" },
            { "he's escaping", "gg_snd_Builder_HesEscapingKillHim" },
            { "save us", "gg_snd_Builder_SaveUs" },
            { "oh no", "gg_snd_Builder_OhNo" },
            { "where", "gg_snd_Builder_Where" },
            { "damn beasts", "gg_snd_Builder_DamnBeasts" },
            { "im so tired", "gg_snd_Builder_ImSoTired" },
            { "i'm so tired", "gg_snd_Builder_ImSoTired" },
            { "demon spawned wretchs", "gg_snd_Builder_DemonSpawnedWretchs" },
            { "demon spawned wretches", "gg_snd_Builder_DemonSpawnedWretchs" },
            { "kill them all twice", "gg_snd_Builder_KillThemAllTwice" },
            { "panda", "gg_snd_Builder_Panda" },
            { "take this", "gg_snd_Builder_TakeThis" },
            { "dancing", "gg_snd_Builder_Dancing" },
            { "insult", "gg_snd_Builder_Insult" }
        }
        local i = 1

        while i <= #entries do
            register(entries[i][1], entries[i][2], builderClass)
            i = i + 1
        end
    end

    local function registerTitanSpeeches()
        local entries = {
            { "this one is mine", "gg_snd_Titan_ThisOneIsMine" },
            { "vanquish the weak", "gg_snd_Titan_VanquishTheWeak" },
            { "dont waste my time", "gg_snd_Titan_DontWasteMyTime" },
            { "don't waste my time", "gg_snd_Titan_DontWasteMyTime" },
            { "right", "gg_snd_Titan_Right" },
            { "of course", "gg_snd_Titan_OfCourse" },
            { "stay out of my way", "gg_snd_Titan_StayOutOfMyWay" },
            { "pitiful", "gg_snd_Titan_Pitiful" },
            { "i must feed", "gg_snd_Titan_IMustFeed" },
            { "im always on the winning side", "gg_snd_Titan_ImAlwaysOnTheWinningSide" },
            { "die", "gg_snd_Titan_Die" },
            { "your soul is mine", "gg_snd_Titan_YourSoulIsMine" },
            { "outstanding", "gg_snd_Titan_Outstanding" },
            { "cross over children", "gg_snd_Titan_CrossOverChildrenCrossOverIntoTheLight" },
            { "i come to cleanse", "gg_snd_Titan_IComeToCleansThisLand" },
            { "taste this", "gg_snd_Titan_TasteThis" },
            { "the dead shall serve", "gg_snd_Titan_TheDeadShallServe" },
            { "let blood drown the weak", "gg_snd_Titan_LetBloodDrownedTheWeak" },
            { "now feel my wrath", "gg_snd_Titan_NowFeelMyWrath" },
            { "never", "gg_snd_Titan_Never" },
            { "what the hell", "gg_snd_Titan_WhatTheHellIsGoingOnHere" },
            { "kill them all", "gg_snd_Titan_KillThemAll" },
            { "youve betrayed us all", "gg_snd_Titan_YouveBetrayedUsAll" },
            { "you've betrayed us all", "gg_snd_Titan_YouveBetrayedUsAll" },
            { "you have betrayed us all", "gg_snd_Titan_YouveBetrayedUsAll" },
            { "you should burn", "gg_snd_Titan_YouShouldBurnInHell" },
            { "gladly", "gg_snd_Titan_Gladly" },
            { "fateless coward", "gg_snd_Titan_FatelessCoward" },
            { "its a trap", "gg_snd_Titan_ItsATrap" },
            { "it's a trap", "gg_snd_Titan_ItsATrap" },
            { "too difficult", "gg_snd_Titan_ThatDoesntSoundTooDifficult" },
            { "that doesn't sound too difficult", "gg_snd_Titan_ThatDoesntSoundTooDifficult" },
            { "your time has come", "gg_snd_Titan_YourTimeHasCome" },
            { "well see about that", "gg_snd_Titan_WellSeeAboutThat" },
            { "we'll see about that", "gg_snd_Titan_WellSeeAboutThat" },
            { "we will see about that", "gg_snd_Titan_WellSeeAboutThat" },
            { "so youre not upset", "gg_snd_Titan_SoYoureNotUpsetAboutMeKillingYouThatOneTime" },
            { "so you're not upset", "gg_snd_Titan_SoYoureNotUpsetAboutMeKillingYouThatOneTime" },
            { "tremble mortals", "gg_snd_Titan_TrembleMortals" },
            { "haha", "gg_snd_Titan_Haha" },
            { "feel", "gg_snd_Titan_Feel" },
            { "i am the wind", "gg_snd_Titan_Breezerious" },
            { "childs play", "gg_snd_Titan_Gladly" }
        }
        local i = 1

        while i <= #entries do
            register(entries[i][1], entries[i][2], titanClass)
            i = i + 1
        end
    end

    local function playSpeech(player, speech)
        local playerData = PlayerData.get(player)
        local id = GetPlayerId(player)
        local token = 0

        if not playerData or silenced[id] or coolingDown[id] or
            not speech.classFilter(playerData:class()) then
            return
        end

        if not silenced[GetPlayerId(GetLocalPlayer())] then
            local soundHandle = rawget(_G, speech.soundName)
            if soundHandle then
                StartSound(soundHandle)
            end
        end

        coolingDown[id] = true
        token = (cooldownToken[id] or 0) + 1
        cooldownToken[id] = token
        GameTimer.after(COOLDOWN_SECONDS, function()
            if cooldownToken[id] == token then
                coolingDown[id] = nil
            end
        end)
    end

    local function onChat()
        if Game.isState(Game.STATE_IDLE) or Game.isState(Game.STATE_FINISHED) then
            return
        end

        local speech = speeches[normalize(GetEventPlayerChatString())]
        if speech then
            playSpeech(GetTriggerPlayer(), speech)
        end
    end

    registerBuilderSpeeches()
    registerTitanSpeeches()

    local chatTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerChatEvent(chatTrigger, Player(i), "", false)
        i = i + 1
    end
    TriggerAddAction(chatTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onChat)
        else
            onChat()
        end
    end)

    Command["-silence"].register(function(args)
        local player = args:player()
        silenced[GetPlayerId(player)] = true
        Command.say(player, "|cff99b4d1Player-produced sounds |rOFF.")
    end, "Disables player-produced speech sounds.")

    Command["-unsilence"].register(function(args)
        local player = args:player()
        silenced[GetPlayerId(player)] = nil
        Command.say(player, "|cff99b4d1Player-produced sounds |rON.")
    end, "Enables player-produced speech sounds.")

    function SpeechSystem.isSilenced(player)
        return player and silenced[GetPlayerId(player)] == true
    end

    SpeechSystem.speeches = speeches
    _G.SpeechSystem = SpeechSystem
end)

if Debug and Debug.endFile then Debug.endFile() end
