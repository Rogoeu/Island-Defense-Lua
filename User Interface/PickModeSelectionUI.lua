if Debug and Debug.beginFile then Debug.beginFile("User Interface/PickModeSelectionUI") end

OnInit("PickModeSelectionUI", function(import)
    import.strict("GameTimer")
    import.strict("PlayerData")
    import.strict("IslandDefenseMultiboard")
    import.strict("IslandDefenseSystem")
    import.strict("GameSettings")
    import.strict("MapAreas")

    local settings = {}
    local finished = false
    local activeSelection = {}
    local selectedChoice = {}
    local selectedSlider = {}
    local activeCallback = nil
    local activeHostId = -1
    local activeSeconds = 10.0
    local remainingSeconds = 10
    local countdownTimer = nil
    local titanSelection = nil
    local titanAnswers = {}

    local ui = {
        ready = false,
        frames = {},
        settingRows = {},
        buttons = {},
        actionByButton = {}
    }

    local PickModeSelectionUI = {}

    local function addChoiceSetting(config)
        settings[#settings + 1] = {
            key = config.key,
            title = config.title,
            description = config.description or "",
            defaultValue = config.defaultValue,
            type = config.type or "choice",
            minValue = config.minValue,
            maxValue = config.maxValue,
            step = config.step,
            valueSuffix = config.valueSuffix,
            choices = config.choices or {},
            apply = config.apply
        }
    end

    local function copyMultiDefaults(defaultValue)
        local result = {}

        if type(defaultValue) == "table" then
            for key, value in pairs(defaultValue) do
                result[key] = value == true
            end
        end

        return result
    end

    local function updateTweakSummary()
        local parts = {}

        if GameSettings.getBool("TITAN_EXP_GLOBAL_FACTOR_DOUBLED") then
            parts[#parts + 1] = "EXP"
        end
        if not GameSettings.getBool("TITAN_EXP_REDUCTION_ENABLED") then
            parts[#parts + 1] = "FROFF"
        end
        if GameSettings.getStr("TWEAK_GC") == "on" then
            parts[#parts + 1] = "GC"
        end

        if #parts == 0 then
            GameSettings.setStr("MULTIBOARD_TWEAKS", "")
        else
            local text = parts[1]
            local i = 2
            while i <= #parts do
                text = text .. "/" .. parts[i]
                i = i + 1
            end
            GameSettings.setStr("MULTIBOARD_TWEAKS", text)
        end

        if rawget(_G, "IslandDefenseMultiboard") then
            IslandDefenseMultiboard.setTweaks("")
        end
    end

    addChoiceSetting({
        key = "mapArea",
        title = "Map",
        description = "Choose the playable area.",
        defaultValue = "Classic",
        choices = {
            { value = "Classic", label = "Classic", icon = MapAreas.icon("Classic"), tooltip = "Classic map area" },
            -- Vulcanic disabled until ready for release.
        },
        apply = function(value) MapAreas.select(value) end
    })

    addChoiceSetting({
        key = "pickMode",
        title = "Pick Mode",
        description = "Race selection rule.",
        defaultValue = "UP",
        choices = {
            { value = "UP", label = "Unique", icon = "war3mapImported\\UniquePick.blp", tooltip = "Unique Pick" },
            { value = "AP", label = "All Pick", icon = "war3mapImported\\AllPick.blp", tooltip = "All Pick" },
            { value = "AR", label = "Random", icon = "war3mapImported\\AllRandomPick.blp", tooltip = "All Random" },
        }
    })

    addChoiceSetting({
        key = "minionGrace",
        title = "Minion Grace",
        description = "Delay before dead defenders spawn.",
        type = "slider",
        defaultValue = 3,
        minValue = 0,
        maxValue = 15,
        step = 1,
        valueSuffix = " min",
        apply = function(value)
            GameSettings.setReal("MINION_SPAWN_GRACE_TIME", (tonumber(value) or 0) * 60.0)
        end
    })

    addChoiceSetting({
        key = "extraModes",
        title = "Extra Modes",
        description = "Optional game modifiers.",
        type = "multi",
        defaultValue = { randomBonus = true, baseHandicap = true, ghostBuildings = true, superCritter = true },
        choices = {
            { value = "debug", label = "Debug", icon = "war3mapImported\\DBGIcon.blp", tooltip = "Enable debug cheats" },
            { value = "randomBonus", label = "Random Bonus", icon = "ReplaceableTextures\\CommandButtons\\BTNStarfall.blp", tooltip = "Random gives bonus lumber" },
            { value = "froff", label = "FROFF", icon = "war3mapImported\\FRIcon.blp", tooltip = "Disable feed reduction" },
            { value = "gc", label = "GC", icon = "war3mapImported\\GCIcon.blp", tooltip = "Gold coin drops enabled" },
            { value = "exp", label = "EXP", icon = "war3mapImported\\EXPicon.blp", tooltip = "Double Titan and Minion experience" },
            { value = "baseHandicap", label = "BH", icon = "war3mapImported\\BHIcon.blp", tooltip = "Base handicap tower scaling" },
            { value = "ghostBuildings", label = "Ghost", icon = "ReplaceableTextures\\CommandButtons\\BTNGhost.blp", tooltip = "Leave dead or left defender structures as neutral ghost buildings" },
            { value = "superCritter", label = "Super Critter", icon = "ReplaceableTextures\\CommandButtons\\BTNCritterChicken.blp", tooltip = "Spawn a Super Critter after enough critter kills" }
        },
        apply = function(value)
            local debugEnabled = value and value.debug == true
            local randomBonusEnabled = value and value.randomBonus == true
            local feedReductionEnabled = not (value and value.froff == true)
            local goldCoinEnabled = value and value.gc == true
            local expEnabled = value and value.exp == true
            local baseHandicapEnabled = value and value.baseHandicap == true
            local ghostBuildingsEnabled = value and value.ghostBuildings == true
            local superCritterEnabled = value and value.superCritter == true

            GameSettings.setBool("DEBUG", debugEnabled)
            GameSettings.setBool("FORCE_DEBUG_MODE", debugEnabled)
            GameSettings.setBool("DEBUG_ALLOW_MULTIPLAYER", debugEnabled)
            GameSettings.setBool("DEBUG_FAST_TIMERS", debugEnabled)
            if debugEnabled then
                local cheatPack = rawget(_G, "DebugCheatPack")
                if cheatPack and cheatPack.activateDebugLobby then
                    cheatPack.activateDebugLobby()
                end
            end

            if randomBonusEnabled then
                GameSettings.setInt("BUILDER_RANDOM_BONUS_GOLD", 0)
                GameSettings.setInt("BUILDER_RANDOM_BONUS_LUMBER", 20)
            else
                GameSettings.setInt("BUILDER_RANDOM_BONUS_GOLD", 0)
                GameSettings.setInt("BUILDER_RANDOM_BONUS_LUMBER", 0)
            end

            GameSettings.setBool("TITAN_EXP_REDUCTION_ENABLED", feedReductionEnabled)
            GameSettings.setBool("TITAN_EXP_GLOBAL_FACTOR_DOUBLED", expEnabled)
            GameSettings.setStr("TWEAK_GC", goldCoinEnabled and "on" or "off")
            GameSettings.setBool("BASE_HANDICAP_ENABLED", baseHandicapEnabled)
            GameSettings.setBool("DEFENDER_GHOST_BUILDINGS_ENABLED", ghostBuildingsEnabled)
            GameSettings.setBool("NEUTRALIZE_STRUCTURES", ghostBuildingsEnabled)
            GameSettings.setBool("TITAN_HUNTER_SUPER_CRITTER_ENABLED", superCritterEnabled)
            local hunterExperience = rawget(_G, "TitanHunterExperience")
            if hunterExperience and hunterExperience.setSuperCritterEnabled then
                hunterExperience.setSuperCritterEnabled(superCritterEnabled)
            end
            local baseHandicap = rawget(_G, "BaseHandicap")
            if baseHandicap and baseHandicap.setEnabled then
                baseHandicap.setEnabled(baseHandicapEnabled)
            end
            local ghostBuildings = rawget(_G, "DefenderGhostBuildings")
            if ghostBuildings and ghostBuildings.setEnabled then
                ghostBuildings.setEnabled(ghostBuildingsEnabled)
            end
            updateTweakSummary()
        end
    })

    local function hostPlayerData()
        local red = PlayerData.get(Player(0))
        if red and not red:isFake() and not red:hasLeft() then
            return red
        end

        local list = PlayerData.playingReal()
        local fallback = list:at(0)
        list:destroy()
        return fallback
    end

    local function selectedLabel(settingIndex)
        local setting = settings[settingIndex]
        if setting.type == "slider" then
            return I2S(R2I(tonumber(activeSelection[setting.key]) or tonumber(setting.defaultValue) or 0)) .. (setting.valueSuffix or "")
        elseif setting.type == "multi" then
            local active = activeSelection[setting.key] or {}
            local labels = ""
            local count = 0
            local i = 1

            while i <= #setting.choices do
                local choice = setting.choices[i]
                if active[choice.value] then
                    count = count + 1
                    if labels ~= "" then
                        labels = labels .. ", "
                    end
                    labels = labels .. choice.label
                end
                i = i + 1
            end

            if labels == "" then
                return "None"
            end
            if count > 1 then
                return I2S(count) .. " on"
            end
            return labels
        end

        local choiceIndex = selectedChoice[settingIndex] or 1
        local choice = setting.choices[choiceIndex]
        if choice then
            return choice.label
        end
        return tostring(activeSelection[setting.key] or setting.defaultValue)
    end

    local function hostName()
        local data = activeHostId >= 0 and PlayerData.get(Player(activeHostId)) or nil
        if data then
            return data:displayName()
        end
        return "Host"
    end

    local function setFrameVisibleForPlaying(frame, visible)
        local data = PlayerData.get(GetLocalPlayer())
        if data and not data:isFake() and not data:hasLeft() then
            BlzFrameSetVisible(frame, visible)
        end
    end

    local function isHostLocal()
        return not titanSelection and activeHostId >= 0 and GetLocalPlayer() == Player(activeHostId)
    end

    local function updateFrames()
        local i = 1

        if not ui.ready then
            return
        end

        BlzFrameSetText(ui.frames.hostText, "|cff99b4d1" .. hostName() .. " selects game setup.|r")
        BlzFrameSetText(ui.frames.timerText, "|cffffff80" .. I2S(remainingSeconds) .. "s|r")
        BlzFrameSetText(ui.frames.confirm, isHostLocal() and "START" or "WAIT")
        BlzFrameSetEnable(ui.frames.confirm, isHostLocal())
        BlzFrameSetVisible(ui.frames.confirm, titanSelection == nil)
        BlzFrameSetVisible(ui.frames.titanYes, titanSelection ~= nil)
        BlzFrameSetVisible(ui.frames.titanNo, titanSelection ~= nil)
        BlzFrameSetVisible(ui.frames.titanInfo, titanSelection ~= nil)
        if titanSelection then
            local data = PlayerData.get(GetLocalPlayer())
            local eligible = data ~= nil and titanSelection.canVolunteer(data) == true
            local answer = data and titanAnswers[data:id()]
            local playing = data ~= nil and not data:isFake() and not data:isObserver() and not data:hasLeft() and not data:isLeaving()
            BlzFrameSetText(ui.frames.hostText, "|cffffff80Do you want to play Titan?|r")
            BlzFrameSetEnable(ui.frames.titanYes, playing and eligible and answer == nil)
            BlzFrameSetEnable(ui.frames.titanNo, playing and answer == nil)
            local info = "Waiting for players to choose."
            if answer ~= nil then
                info = answer and "You volunteered for Titan. Waiting for selection." or "You chose Defender. Waiting for selection."
            elseif playing and not eligible then
                info = "Titan requires " .. I2S(titanSelection.minimum) .. " games (you have " ..
                    I2S(titanSelection.playedGames(data)) .. ")."
            end
            BlzFrameSetText(ui.frames.titanInfo, "|cffffffff" .. info ..
                "|r\n|cffc8d8efIf nobody qualifies, Titan is chosen randomly.|r")
        end

        while i <= #ui.settingRows do
            local row = ui.settingRows[i]
            local setting = settings[i]
            local selected = selectedChoice[i] or 1
            local j = 1

            BlzFrameSetText(row.valueText, "|cffffff80" .. selectedLabel(i) .. "|r")
            if setting.type == "slider" then
                if row.sliderControl then
                    local value = tonumber(activeSelection[setting.key]) or tonumber(setting.defaultValue) or 0
                    local minValue = setting.minValue or 0
                    local maxValue = setting.maxValue or 15
                    BlzFrameSetEnable(row.sliderControl.minus, isHostLocal() and value > minValue)
                    BlzFrameSetEnable(row.sliderControl.plus, isHostLocal() and value < maxValue)
                end
            elseif setting.type == "multi" then
                local active = activeSelection[setting.key] or {}
                while j <= #row.choiceMarks do
                    local choice = setting.choices[j]
                    local enabled = choice ~= nil and active[choice.value] == true

                    BlzFrameSetText(row.choiceMarks[j], "")
                    BlzFrameSetVisible(row.choiceEffects[j], enabled)
                    BlzFrameSetEnable(row.buttons[j], isHostLocal())
                    j = j + 1
                end
            else
                while j <= #row.choiceMarks do
                    BlzFrameSetText(row.choiceMarks[j], "")
                    BlzFrameSetVisible(row.choiceEffects[j], j == selected)
                    BlzFrameSetEnable(row.buttons[j], isHostLocal())
                    j = j + 1
                end
            end

            if setting.description and setting.description ~= "" then
                BlzFrameSetText(row.descriptionText, "|cff9098a8" .. setting.description .. "|r")
            end
            i = i + 1
        end
    end

    local function hide()
        if countdownTimer then
            countdownTimer:destroy()
            countdownTimer = nil
        end
        if ui.ready then
            setFrameVisibleForPlaying(ui.frames.root, false)
        end
    end

    local function applySelections()
        local i = 1
        while i <= #settings do
            local setting = settings[i]
            local value = activeSelection[setting.key] or setting.defaultValue
            activeSelection[setting.key] = value
            if setting.apply then
                setting.apply(value, activeSelection)
            end
            i = i + 1
        end
    end

    local function complete()
        if finished then
            return
        end
        finished = true
        applySelections()
        hide()

        if activeCallback then
            activeCallback(activeSelection)
        end
    end

    local function choose(settingIndex, choiceIndex)
        local setting = settings[settingIndex]
        local choice = setting and setting.choices[choiceIndex] or nil
        if finished or not choice then
            return
        end

        if setting.type == "multi" then
            if not activeSelection[setting.key] then
                activeSelection[setting.key] = {}
            end
            activeSelection[setting.key][choice.value] = not activeSelection[setting.key][choice.value]
            updateFrames()
            return
        end

        selectedChoice[settingIndex] = choiceIndex
        activeSelection[setting.key] = choice.value
        updateFrames()
    end

    local function setSlider(settingIndex, value)
        local setting = settings[settingIndex]
        local number = tonumber(value)
        local step = setting and setting.step or 1

        if finished or not setting or setting.type ~= "slider" or not number then
            return
        end

        if setting.minValue and number < setting.minValue then
            number = setting.minValue
        end
        if setting.maxValue and number > setting.maxValue then
            number = setting.maxValue
        end
        if step and step > 0 then
            number = R2I((number / step) + 0.5) * step
        end

        selectedSlider[settingIndex] = number
        activeSelection[setting.key] = number
        updateFrames()
    end

    local function sliderValueAfterDelta(settingIndex, delta)
        local setting = settings[settingIndex]
        local current = tonumber(activeSelection[setting.key]) or tonumber(setting.defaultValue) or 0
        local step = setting.step or 1
        return current + ((tonumber(delta) or 0) * step)
    end

    local function createTooltip(gameUi, name, title, text)
        local tooltip = BlzCreateFrameByType("BACKDROP", "IDSetupTooltip" .. name, gameUi, "", 0)
        local titleFrame = nil
        local textFrame = nil

        BlzFrameSetSize(tooltip, 0.205, 0.052)
        BlzFrameSetAbsPoint(tooltip, FRAMEPOINT_TOPLEFT, 0.392, 0.512)
        if rawget(_G, "BlzFrameSetTexture") then
            BlzFrameSetTexture(tooltip, "ReplaceableTextures\\TeamColor\\TeamColor27.blp", 0, true)
        end
        BlzFrameSetAlpha(tooltip, 215)

        titleFrame = BlzCreateFrameByType("TEXT", "IDSetupTooltipTitle" .. name, tooltip, "", 0)
        BlzFrameSetPoint(titleFrame, FRAMEPOINT_TOPLEFT, tooltip, FRAMEPOINT_TOPLEFT, 0.008, -0.006)
        BlzFrameSetText(titleFrame, "|cff00bfff" .. title .. "|r")
        BlzFrameSetScale(titleFrame, 0.82)

        textFrame = BlzCreateFrameByType("TEXT", "IDSetupTooltipText" .. name, tooltip, "", 0)
        BlzFrameSetPoint(textFrame, FRAMEPOINT_TOPLEFT, tooltip, FRAMEPOINT_TOPLEFT, 0.008, -0.023)
        BlzFrameSetSize(textFrame, 0.190, 0.024)
        BlzFrameSetText(textFrame, "|cffdddddd" .. text .. "|r")
        BlzFrameSetScale(textFrame, 0.70)
        if rawget(_G, "BlzFrameSetTextAlignment") then
            BlzFrameSetTextAlignment(textFrame, TEXT_JUSTIFY_TOP, TEXT_JUSTIFY_LEFT)
        end

        BlzFrameSetVisible(tooltip, false)
        return tooltip
    end

    local function createChoiceButton(gameUi, rowFrame, settingIndex, choiceIndex, choice, x, y)
        local action = "choice:" .. I2S(settingIndex) .. ":" .. I2S(choiceIndex)
        local button = BlzCreateFrameByType("GLUETEXTBUTTON", "IDSetupChoice" .. I2S(settingIndex) .. "_" .. I2S(choiceIndex), rowFrame, "ScriptDialogButton", 0)
        local icon = BlzCreateFrameByType("BACKDROP", "IDSetupChoiceIcon" .. I2S(settingIndex) .. "_" .. I2S(choiceIndex), button, "", 0)
        local mark = BlzCreateFrameByType("TEXT", "IDSetupChoiceMark" .. I2S(settingIndex) .. "_" .. I2S(choiceIndex), button, "", 0)
        local choiceEffect = BlzCreateFrameByType("BACKDROP", "IDSetupChoiceEffect" .. I2S(settingIndex) .. "_" .. I2S(choiceIndex), button, "", 0)
        local tooltip = createTooltip(gameUi, I2S(settingIndex) .. "_" .. I2S(choiceIndex), choice.label, choice.tooltip or choice.value)

        BlzFrameSetSize(button, 0.027, 0.027)
        BlzFrameSetPoint(button, FRAMEPOINT_TOPLEFT, rowFrame, FRAMEPOINT_TOPLEFT, x, y or -0.002)
        BlzFrameSetText(button, "")
        BlzFrameSetAllPoints(icon, button)
        if rawget(_G, "BlzFrameSetTexture") then
            BlzFrameSetTexture(icon, choice.icon, 0, true)
        end
        BlzFrameSetEnable(icon, false)
        BlzFrameSetPoint(mark, FRAMEPOINT_BOTTOMRIGHT, button, FRAMEPOINT_BOTTOMRIGHT, -0.002, 0.001)
        BlzFrameSetText(mark, "")
        BlzFrameSetScale(mark, 0.82)
        BlzFrameSetAllPoints(choiceEffect, button)
        if rawget(_G, "BlzFrameSetTexture") then
            BlzFrameSetTexture(choiceEffect, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", 0, true)
        end
        BlzFrameSetEnable(choiceEffect, false)
        BlzFrameSetVisible(choiceEffect, false)
        BlzFrameSetTooltip(button, tooltip)

        ui.buttons[#ui.buttons + 1] = button
        ui.actionByButton[GetHandleId(button)] = action
        return button, mark, choiceEffect
    end

    local function createSliderButton(rowFrame, settingIndex, delta, x, text)
        local action = "sliderdelta:" .. I2S(settingIndex) .. ":" .. I2S(delta)
        local button = BlzCreateFrameByType("GLUETEXTBUTTON", "IDSetupSliderButton" .. I2S(settingIndex) .. "_" .. I2S(delta), rowFrame, "ScriptDialogButton", 0)

        BlzFrameSetSize(button, 0.024, 0.022)
        BlzFrameSetPoint(button, FRAMEPOINT_TOPLEFT, rowFrame, FRAMEPOINT_TOPLEFT, x, -0.004)
        BlzFrameSetText(button, text)

        ui.buttons[#ui.buttons + 1] = button
        ui.actionByButton[GetHandleId(button)] = action
        return button
    end

    local function createSliderControl(rowFrame, settingIndex, setting)
        local control = {
            minus = createSliderButton(rowFrame, settingIndex, -1, 0.164, "-"),
            plus = createSliderButton(rowFrame, settingIndex, 1, 0.198, "+")
        }

        return control
    end

    local function createFrames()
        local gameUi = nil
        local trigger = nil
        local i = 1
        local usesEscMenuBackdrop = false

        if ui.ready or
            not rawget(_G, "BlzCreateFrameByType") or
            not rawget(_G, "BlzGetOriginFrame") or
            not rawget(_G, "BlzTriggerRegisterFrameEvent") or
            not rawget(_G, "BlzFrameSetTooltip") or
            not rawget(_G, "BlzGetTriggerFrame") then
            return false
        end

        gameUi = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        if rawget(_G, "BlzCreateFrame") then
            local ok, frame = pcall(BlzCreateFrame, "EscMenuBackdrop", gameUi, 0, 0)
            if ok then
                ui.frames.root = frame
                usesEscMenuBackdrop = ui.frames.root ~= nil
            end
        end
        if not ui.frames.root then
            ui.frames.root = BlzCreateFrameByType("BACKDROP", "IDSetupRoot", gameUi, "", 0)
        end
        BlzFrameSetSize(ui.frames.root, 0.360, 0.360)
        BlzFrameSetAbsPoint(ui.frames.root, FRAMEPOINT_TOPLEFT, 0.014, 0.568)
        if rawget(_G, "BlzFrameSetTexture") and not usesEscMenuBackdrop then
            BlzFrameSetTexture(ui.frames.root, "ReplaceableTextures\\TeamColor\\TeamColor04.blp", 0, true)
            BlzFrameSetAlpha(ui.frames.root, 170)
        end
        BlzFrameSetVisible(ui.frames.root, false)

        if not usesEscMenuBackdrop then
            ui.frames.background = BlzCreateFrameByType("BACKDROP", "IDSetupBackground", ui.frames.root, "", 0)
            BlzFrameSetSize(ui.frames.background, 0.352, 0.356)
            BlzFrameSetPoint(ui.frames.background, FRAMEPOINT_TOPLEFT, ui.frames.root, FRAMEPOINT_TOPLEFT, 0.002, -0.002)
            if rawget(_G, "BlzFrameSetTexture") then
                BlzFrameSetTexture(ui.frames.background, "ReplaceableTextures\\TeamColor\\TeamColor27.blp", 0, true)
            end
            BlzFrameSetAlpha(ui.frames.background, 232)
            BlzFrameSetEnable(ui.frames.background, false)
        end

        ui.frames.title = BlzCreateFrameByType("TEXT", "IDSetupTitle", ui.frames.root, "", 0)
        BlzFrameSetPoint(ui.frames.title, FRAMEPOINT_TOPLEFT, ui.frames.root, FRAMEPOINT_TOPLEFT, 0.024, -0.018)
        BlzFrameSetText(ui.frames.title, "|cff00bfffGame Setup|r")
        BlzFrameSetScale(ui.frames.title, 1.04)

        ui.frames.hostText = BlzCreateFrameByType("TEXT", "IDSetupHost", ui.frames.root, "", 0)
        BlzFrameSetPoint(ui.frames.hostText, FRAMEPOINT_TOPLEFT, ui.frames.root, FRAMEPOINT_TOPLEFT, 0.024, -0.043)
        BlzFrameSetSize(ui.frames.hostText, 0.245, 0.018)
        BlzFrameSetScale(ui.frames.hostText, 0.76)

        ui.frames.timerText = BlzCreateFrameByType("TEXT", "IDSetupTimer", ui.frames.root, "", 0)
        BlzFrameSetPoint(ui.frames.timerText, FRAMEPOINT_TOPRIGHT, ui.frames.root, FRAMEPOINT_TOPRIGHT, -0.024, -0.018)
        BlzFrameSetScale(ui.frames.timerText, 0.95)

        i = 1
        local rowY = -0.070
        while i <= #settings do
            local setting = settings[i]
            local row = {}
            local rowHeight = 0.032
            local j = 1

            if setting.type == "multi" then
                rowHeight = 0.064
            end

            row.frame = BlzCreateFrameByType("FRAME", "IDSetupRow" .. I2S(i), ui.frames.root, "", 0)
            BlzFrameSetSize(row.frame, 0.330, rowHeight)
            BlzFrameSetPoint(row.frame, FRAMEPOINT_TOPLEFT, ui.frames.root, FRAMEPOINT_TOPLEFT, 0.024, rowY)

            row.titleText = BlzCreateFrameByType("TEXT", "IDSetupRowTitle" .. I2S(i), row.frame, "", 0)
            BlzFrameSetPoint(row.titleText, FRAMEPOINT_TOPLEFT, row.frame, FRAMEPOINT_TOPLEFT, 0.000, -0.001)
            BlzFrameSetText(row.titleText, "|cffffffff" .. setting.title .. "|r")
            BlzFrameSetScale(row.titleText, 0.74)

            row.valueText = BlzCreateFrameByType("TEXT", "IDSetupRowValue" .. I2S(i), row.frame, "", 0)
            BlzFrameSetPoint(row.valueText, FRAMEPOINT_TOPLEFT, row.frame, FRAMEPOINT_TOPLEFT, 0.076, -0.001)
            BlzFrameSetSize(row.valueText, 0.060, 0.014)
            BlzFrameSetScale(row.valueText, 0.70)

            row.descriptionText = BlzCreateFrameByType("TEXT", "IDSetupRowDesc" .. I2S(i), row.frame, "", 0)
            BlzFrameSetPoint(row.descriptionText, FRAMEPOINT_TOPLEFT, row.frame, FRAMEPOINT_TOPLEFT, 0.000, -0.018)
            BlzFrameSetSize(row.descriptionText, 0.136, 0.012)
            BlzFrameSetScale(row.descriptionText, 0.58)

            row.buttons = {}
            row.choiceMarks = {}
            row.choiceEffects = {}
            if setting.type == "slider" then
                row.sliderControl = createSliderControl(row.frame, i, setting)
            elseif setting.type == "multi" then
                while j <= #setting.choices do
                    local column = ModuloInteger(j - 1, 4)
                    local rowIndex = R2I((j - 1) / 4)
                    row.buttons[j], row.choiceMarks[j], row.choiceEffects[j] = createChoiceButton(gameUi, row.frame, i, j, setting.choices[j], 0.164 + column * 0.033, -0.002 - rowIndex * 0.030)
                    j = j + 1
                end
            else
                while j <= #setting.choices do
                    local spacing = 0.033
                    row.buttons[j], row.choiceMarks[j], row.choiceEffects[j] = createChoiceButton(gameUi, row.frame, i, j, setting.choices[j], 0.164 + ((j - 1) * spacing))
                    j = j + 1
                end
            end
            ui.settingRows[i] = row
            rowY = rowY - rowHeight - 0.006
            i = i + 1
        end

        ui.frames.confirm = BlzCreateFrameByType("GLUETEXTBUTTON", "IDSetupConfirm", ui.frames.root, "ScriptDialogButton", 0)
        BlzFrameSetSize(ui.frames.confirm, 0.072, 0.026)
        BlzFrameSetPoint(ui.frames.confirm, FRAMEPOINT_BOTTOMRIGHT, ui.frames.root, FRAMEPOINT_BOTTOMRIGHT, -0.024, 0.020)
        BlzFrameSetText(ui.frames.confirm, "START")
        ui.buttons[#ui.buttons + 1] = ui.frames.confirm
        ui.actionByButton[GetHandleId(ui.frames.confirm)] = "complete"

        ui.frames.titanInfo = BlzCreateFrameByType("TEXT", "IDSetupTitanInfo", ui.frames.root, "", 0)
        BlzFrameSetScale(ui.frames.titanInfo, 0.78)
        BlzFrameSetSize(ui.frames.titanInfo, 0.312, 0.036)
        BlzFrameSetPoint(ui.frames.titanInfo, FRAMEPOINT_TOPLEFT, ui.frames.root, FRAMEPOINT_BOTTOMLEFT, 0.024, 0.086)
        BlzFrameSetTextAlignment(ui.frames.titanInfo, TEXT_JUSTIFY_TOP, TEXT_JUSTIFY_LEFT)
        for index, key in ipairs({ "titanYes", "titanNo" }) do
            local button = BlzCreateFrameByType("GLUETEXTBUTTON", "IDSetup" .. key, ui.frames.root, "ScriptDialogButton", 0)
            ui.frames[key] = button
            BlzFrameSetSize(button, 0.145, 0.026)
            BlzFrameSetPoint(button, FRAMEPOINT_BOTTOMLEFT, ui.frames.root, FRAMEPOINT_BOTTOMLEFT,
                0.024 + (index - 1) * 0.163, 0.020)
            BlzFrameSetText(button, index == 1 and "Yes, Titan" or "No, Defender")
            ui.buttons[#ui.buttons + 1] = button
            ui.actionByButton[GetHandleId(button)] = index == 1 and "titan:yes" or "titan:no"
        end

        trigger = CreateTrigger()
        i = 1
        while i <= #ui.buttons do
            BlzTriggerRegisterFrameEvent(trigger, ui.buttons[i], FRAMEEVENT_CONTROL_CLICK)
            i = i + 1
        end
        TriggerAddAction(trigger, function()
            local frame = BlzGetTriggerFrame()
            local action = ui.actionByButton[GetHandleId(frame)]
            local player = GetTriggerPlayer()

            if titanSelection and (action == "titan:yes" or action == "titan:no") then
                if GetLocalPlayer() == player then
                    BlzSendSyncData("IDSetup", action)
                end
                return
            end

            if not action or GetPlayerId(player) ~= activeHostId or finished then
                return
            end

            if rawget(_G, "BlzSendSyncData") then
                if GetLocalPlayer() == player then
                    BlzSendSyncData("IDSetup", action)
                end
            elseif action == "complete" then
                complete()
            else
                local _, _, settingIndex, choiceIndex = string.find(action, "choice:(%d+):(%d+)")
                local _, _, sliderIndex, delta = string.find(action, "sliderdelta:(%d+):(-?%d+)")
                if settingIndex then
                    choose(tonumber(settingIndex), tonumber(choiceIndex))
                elseif sliderIndex then
                    setSlider(tonumber(sliderIndex), sliderValueAfterDelta(tonumber(sliderIndex), tonumber(delta)))
                end
            end
        end)

        if rawget(_G, "BlzTriggerRegisterPlayerSyncEvent") then
            local syncTrigger = CreateTrigger()
            local playerIndex = 0
            while playerIndex < bj_MAX_PLAYER_SLOTS do
                BlzTriggerRegisterPlayerSyncEvent(syncTrigger, Player(playerIndex), "IDSetup", false)
                playerIndex = playerIndex + 1
            end
            TriggerAddAction(syncTrigger, function()
                local action = BlzGetTriggerSyncData()
                if action == "titan:yes" or action == "titan:no" then
                    local data = PlayerData.get(GetTriggerPlayer())
                    if not titanSelection or not data or data:isFake() or data:isObserver() or
                        data:hasLeft() or data:isLeaving() or titanAnswers[data:id()] ~= nil then
                        return
                    end
                    local wantsTitan = action == "titan:yes"
                    if wantsTitan and not titanSelection.canVolunteer(data) then return end
                    titanAnswers[data:id()] = wantsTitan
                    titanSelection.onChoice(data:id(), wantsTitan)
                    updateFrames()
                    return
                end
                if GetPlayerId(GetTriggerPlayer()) ~= activeHostId or finished then
                    return
                end
                if action == "complete" then
                    complete()
                else
                    local _, _, settingIndex, choiceIndex = string.find(action, "choice:(%d+):(%d+)")
                    local _, _, sliderIndex, sliderValue = string.find(action, "slider:(%d+):(%d+)")
                    local _, _, sliderDeltaIndex, sliderDelta = string.find(action, "sliderdelta:(%d+):(-?%d+)")
                    if settingIndex then
                        choose(tonumber(settingIndex), tonumber(choiceIndex))
                    elseif sliderIndex then
                        setSlider(tonumber(sliderIndex), tonumber(sliderValue))
                    elseif sliderDeltaIndex then
                        setSlider(tonumber(sliderDeltaIndex), sliderValueAfterDelta(tonumber(sliderDeltaIndex), tonumber(sliderDelta)))
                    end
                end
            end)
        end

        ui.ready = true
        return true
    end

    local function show(seconds)
        if not ui.ready and not createFrames() then
            return false
        end

        remainingSeconds = R2I(seconds)
        setFrameVisibleForPlaying(ui.frames.root, true)
        updateFrames()
        return true
    end

    function PickModeSelectionUI.startTitanSelection(seconds, config)
        if not rawget(_G, "BlzSendSyncData") or not rawget(_G, "BlzTriggerRegisterPlayerSyncEvent") then
            return false
        end
        if not ui.ready and not createFrames() then return false end
        hide()
        titanSelection = config
        titanAnswers = {}
        remainingSeconds = R2I(seconds)
        setFrameVisibleForPlaying(ui.frames.root, true)
        updateFrames()
        countdownTimer = GameTimer.every(1.0, function()
            remainingSeconds = math.max(0, remainingSeconds - 1)
            updateFrames()
        end)
        return true
    end

    function PickModeSelectionUI.endTitanSelection()
        if titanSelection then
            hide()
            titanSelection = nil
            titanAnswers = {}
        end
    end

    function PickModeSelectionUI.selectionSummary()
        local lines = {}
        for _, setting in ipairs(settings) do
            local value = activeSelection[setting.key]
            local labels = {}
            if setting.type == "multi" then
                for _, choice in ipairs(setting.choices) do
                    if value and value[choice.value] then
                        labels[#labels + 1] = choice.label
                    end
                end
                if #labels == 0 then labels[1] = "None" end
                for i = 1, #labels, 3 do
                    lines[#lines + 1] = (i == 1 and setting.title .. ": " or "") ..
                        table.concat(labels, ", ", i, math.min(i + 2, #labels))
                end
            elseif setting.type == "slider" then
                lines[#lines + 1] = setting.title .. ": " .. tostring(value or setting.defaultValue) ..
                    (setting.valueSuffix or "")
            else
                for _, choice in ipairs(setting.choices) do
                    if choice.value == value then labels[1] = choice.label end
                end
                lines[#lines + 1] = setting.title .. ": " .. (labels[1] or tostring(value or setting.defaultValue))
            end
        end
        return table.concat(lines, "\n")
    end

    function PickModeSelectionUI.registerChoiceSetting(config)
        addChoiceSetting(config)
    end

    function PickModeSelectionUI.start(seconds, callback)
        local hostData = hostPlayerData()
        local i = 1

        if not hostData then
            callback({ pickMode = "UP" })
            return
        end

        seconds = seconds or 10.0
        activeSeconds = seconds
        remainingSeconds = R2I(seconds)
        activeHostId = hostData:id()
        finished = false
        activeSelection = {}
        selectedChoice = {}
        selectedSlider = {}
        activeCallback = callback

        while i <= #settings do
            if settings[i].type == "multi" then
                activeSelection[settings[i].key] = copyMultiDefaults(settings[i].defaultValue)
            else
                activeSelection[settings[i].key] = settings[i].defaultValue
            end
            selectedChoice[i] = 1
            if settings[i].type == "slider" then
                selectedSlider[i] = settings[i].defaultValue
            end
            local j = 1
            while j <= #settings[i].choices do
                if settings[i].choices[j].value == settings[i].defaultValue then
                    selectedChoice[i] = j
                end
                j = j + 1
            end
            i = i + 1
        end

        IslandDefenseMultiboard.setPhase("Host game setup", seconds)
        Game.say("|cff99b4d1" .. hostData:displayName() .. " is selecting game settings.|r")

        if not show(activeSeconds) then
            complete()
            return
        end

        if countdownTimer then
            countdownTimer:destroy()
        end
        countdownTimer = GameTimer.every(1.0, function()
            if finished then
                countdownTimer:destroy()
                countdownTimer = nil
                return
            end

            remainingSeconds = remainingSeconds - 1
            if remainingSeconds <= 0 then
                complete()
            else
                updateFrames()
            end
        end)
    end

    _G.PickModeSelectionUI = PickModeSelectionUI
end)

if Debug and Debug.endFile then Debug.endFile() end
