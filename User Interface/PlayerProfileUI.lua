if Debug and Debug.beginFile then Debug.beginFile("User Interface/PlayerProfileUI") end

OnInit("PlayerProfileUI", function(import)
    import.strict("GameTimer")
    import.strict("GameSettings")
    import.strict("PlayerData")
    import.strict("PlayerProfile")
    import.strict("LocalModelScaling")
    import.strict("Cosmetics")
    import.strict("Races")
    import.strict("CommandRegistry")

    local PROFILE_ICON = "ReplaceableTextures\\CommandButtons\\BTNBookOfTheDead.blp"
    local LIST_ROWS = 10
    local COSMETIC_COLUMNS = 8
    local COSMETIC_SLOTS = 32
    local SOLID_TEXTURE = "ReplaceableTextures\\TeamColor\\TeamColor27.blp"
    local THEME = {
        panel = BlzConvertColor(250, 8, 13, 18),
        surface = BlzConvertColor(255, 25, 35, 45),
        surfaceHover = BlzConvertColor(255, 39, 54, 68),
        surfacePressed = BlzConvertColor(255, 50, 68, 84),
        border = BlzConvertColor(255, 71, 86, 102),
        accentSurface = BlzConvertColor(255, 215, 169, 40),
        buttonIdle = BlzConvertColor(0, 0, 0, 0),
        buttonActive = BlzConvertColor(46, 215, 169, 40),
        buttonHover = BlzConvertColor(72, 110, 145, 180),
        buttonPressed = BlzConvertColor(112, 110, 145, 180),
        accent = "|cffD7A928",
        text = "|cffF2F4F7",
        muted = "|cff9CAABD",
        win = "|cff4ADE80",
        loss = "|cffF87171"
    }

    local ui = {
        ready = false,
        visible = false,
        launcherVisible = true,
        tab = "stats",
        cosmeticCategory = "aura",
        skinRace = "",
        cosmeticEntries = {},
        page = 1,
        totalPages = 1,
        frames = {},
        actions = {},
        actionFrames = {},
        buttonVisuals = {},
        profileButtons = {},
        focusedFrame = nil,
        focusTimer = nil,
        focusReleasePending = false
    }

    local PlayerProfileUI = {}
    local hideCosmeticTooltip = nil
    local nextDecorativeContext = 7400

    local function isEnabled()
        return GameSettings.getBool("PLAYER_PROFILE_UI_ENABLED")
    end

    local function setButtonText(button, text)
        local visual = button and ui.buttonVisuals[GetHandleId(button)] or nil
        if visual and visual.label then
            BlzFrameSetText(visual.label, text or "")
        end
    end

    local function setButtonSurface(button, color)
        local visual = button and ui.buttonVisuals[GetHandleId(button)] or nil
        if visual and visual.background then
            if visual.questBackdrop then
                -- Never draw a TeamColor overlay over quest buttons. Warcraft
                -- renders that texture gray even with low/zero vertex alpha.
                BlzFrameSetVisible(visual.background, false)
            end
            if rawget(_G, "BlzFrameSetVertexColor") then
                BlzFrameSetVertexColor(visual.background, color)
            end
        end
    end

    local function buttonShouldBeEnabled(button)
        local action = button and ui.actions[GetHandleId(button)] or nil
        local slotIndex = action and tonumber(string.match(action, "^cosmeticslot:(%d+)$")) or nil

        if action == "toggle" then
            return ui.launcherVisible
        end
        if action == "scaledmodels" then
            return ui.visible and ui.tab == "graphics"
        end
        if not ui.visible then
            return false
        end
        if slotIndex then
            return ui.tab == "cosmetics" and ui.cosmeticEntries[slotIndex] ~= nil
        end
        if action == "previous" then
            return ui.visible and ui.totalPages > 1 and ui.page > 1
        end
        if action == "next" then
            return ui.visible and ui.totalPages > 1 and ui.page < ui.totalPages
        end
        if action == "skinraces" then
            return ui.visible and ui.tab == "cosmetics" and
                ui.cosmeticCategory == "skin" and ui.skinRace ~= ""
        end
        if action and string.match(action, "^category:") then
            return ui.tab == "cosmetics"
        end
        return true
    end

    local function updateInteractiveState()
        local i = 1
        while i <= #ui.profileButtons do
            local button = ui.profileButtons[i]
            BlzFrameSetEnable(button, buttonShouldBeEnabled(button))
            i = i + 1
        end
    end

    local function clearFrameFocusNow()
        local i = 1

        if not rawget(_G, "BlzFrameSetFocus") then
            return
        end
        if ui.focusedFrame then
            BlzFrameSetFocus(ui.focusedFrame, false)
        end
        while i <= #ui.profileButtons do
            BlzFrameSetFocus(ui.profileButtons[i], false)
            i = i + 1
        end
        if ui.frames.button then
            BlzFrameSetFocus(ui.frames.button, false)
        end
    end

    local function releaseFrameInput(clickedFrame)
        ui.focusedFrame = clickedFrame
        hideCosmeticTooltip()
        clearFrameFocusNow()
        updateInteractiveState()
        ui.focusReleasePending = true
    end

    local function setVisible(visible)
        ui.visible = visible == true
        BlzFrameSetVisible(ui.frames.panel, ui.visible)
        if not ui.visible then
            hideCosmeticTooltip()
        end
        updateInteractiveState()
        releaseFrameInput(nil)
    end

    local function setLauncherVisible(visible)
        ui.launcherVisible = visible == true
        if not ui.ready then
            return
        end

        if not ui.launcherVisible and ui.visible then
            setVisible(false)
        end
        BlzFrameSetEnable(ui.frames.button, ui.launcherVisible)
        BlzFrameSetVisible(ui.frames.button, ui.launcherVisible)
        releaseFrameInput(nil)
    end

    local function totalWins(stats)
        return (stats.winsTitan or 0) + (stats.winsBuilder or 0)
    end

    local function totalGames(stats)
        return (stats.titan or 0) + (stats.builder or 0)
    end

    local function raceList(classValue)
        local result = {}
        local all = Races.all()
        local i = 1

        while i <= #all do
            if all[i]:class() == classValue then
                result[#result + 1] = all[i]
            end
            i = i + 1
        end
        table.sort(result, function(left, right)
            return left:toString() < right:toString()
        end)
        return result
    end

    local function setRow(row, icon, name, result, visible)
        BlzFrameSetVisible(row.frame, visible)
        BlzFrameSetVisible(row.icon, visible and icon ~= "")
        if icon ~= "" then
            BlzFrameSetTexture(row.icon, icon, 0, true)
        end
        if rawget(_G, "BlzFrameClearAllPoints") then
            BlzFrameClearAllPoints(row.name)
            BlzFrameSetPoint(row.name, FRAMEPOINT_LEFT, row.frame, FRAMEPOINT_LEFT, icon ~= "" and 0.027 or 0.010, 0.000)
        end
        BlzFrameSetText(row.name, name or "")
        BlzFrameSetText(row.result, result or "")
    end

    local function updateTabs()
        local tabs = ui.frames.tabs
        local names = { stats = "Stats", titan = "Titan", builder = "Builder", cosmetics = "Cosmetics", graphics = "Graphics" }
        local key = nil

        for key, name in pairs(names) do
            if ui.tab == key then
                setButtonText(tabs[key], THEME.accent .. name .. "|r")
                setButtonSurface(tabs[key], THEME.buttonActive)
                BlzFrameSetVisible(ui.buttonVisuals[GetHandleId(tabs[key])].accent, true)
            else
                setButtonText(tabs[key], THEME.muted .. name .. "|r")
                setButtonSurface(tabs[key], THEME.buttonIdle)
                BlzFrameSetVisible(ui.buttonVisuals[GetHandleId(tabs[key])].accent, false)
            end
        end
    end

    local function setCosmeticCategoriesVisible(visible)
        local categories = ui.frames.cosmeticCategories
        local key = nil

        for key in pairs(categories) do
            BlzFrameSetVisible(categories[key], visible)
            BlzFrameSetEnable(categories[key], visible)
        end
        if not visible and ui.frames.skinRaceBack then
            BlzFrameSetVisible(ui.frames.skinRaceBack, false)
            BlzFrameSetVisible(ui.frames.skinRaceName, false)
        end
    end

    local function setCosmeticSlotsVisible(visible)
        local slots = ui.frames.cosmeticSlots
        local i = 1

        while i <= #slots do
            BlzFrameSetVisible(slots[i].button, visible)
            BlzFrameSetEnable(slots[i].button, visible and ui.cosmeticEntries[i] ~= nil)
            i = i + 1
        end
    end

    local function updateCosmeticCategoryTabs()
        local categories = ui.frames.cosmeticCategories
        local labels = { aura = "Auras", wings = "Wings", skin = "Skins" }
        local key = nil

        for key, label in pairs(labels) do
            if key == ui.cosmeticCategory then
                setButtonText(categories[key], THEME.accent .. label .. "|r")
                setButtonSurface(categories[key], THEME.buttonActive)
                BlzFrameSetVisible(ui.buttonVisuals[GetHandleId(categories[key])].accent, true)
            else
                setButtonText(categories[key], THEME.muted .. label .. "|r")
                setButtonSurface(categories[key], THEME.buttonIdle)
                BlzFrameSetVisible(ui.buttonVisuals[GetHandleId(categories[key])].accent, false)
            end
        end
    end

    local function skinRaceList()
        local result = {}
        local all = Races.all()
        local i = 1

        while i <= #all do
            local name = all[i]:toString()
            if name ~= "Panda" and name ~= "Morphling" then
                result[#result + 1] = all[i]
            end
            i = i + 1
        end
        table.sort(result, function(left, right)
            return left:toString() < right:toString()
        end)
        return result
    end

    local function skinEntriesForRace(raceName)
        local result = {}
        local all = Cosmetics.all("skin")
        local i = 1

        while i <= #all do
            if all[i].race == "" or all[i].race == raceName then
                result[#result + 1] = all[i]
            end
            i = i + 1
        end
        return result
    end

    local function updateCosmetics(player)
        local selectingSkinRace = ui.cosmeticCategory == "skin" and ui.skinRace == ""
        local entries = nil
        local pages = 1
        local first = 1
        local i = 1
        updateCosmeticCategoryTabs()

        if selectingSkinRace then
            entries = skinRaceList()
        elseif ui.cosmeticCategory == "skin" then
            entries = skinEntriesForRace(ui.skinRace)
        else
            entries = Cosmetics.all(ui.cosmeticCategory)
        end

        BlzFrameSetVisible(ui.frames.skinRaceBack,
            ui.cosmeticCategory == "skin" and ui.skinRace ~= "")
        BlzFrameSetVisible(ui.frames.skinRaceName,
            ui.cosmeticCategory == "skin" and ui.skinRace ~= "")
        BlzFrameSetText(ui.frames.skinRaceName, THEME.muted .. ui.skinRace .. "|r")

        pages = math.max(1, R2I((#entries + COSMETIC_SLOTS - 1) / COSMETIC_SLOTS))
        ui.totalPages = pages
        if ui.page > pages then
            ui.page = pages
        end
        first = (ui.page - 1) * COSMETIC_SLOTS + 1

        BlzFrameSetVisible(ui.frames.previous, pages > 1)
        BlzFrameSetVisible(ui.frames.next, pages > 1)
        BlzFrameSetVisible(ui.frames.pagination, pages > 1)
        BlzFrameSetEnable(ui.frames.previous, ui.page > 1)
        BlzFrameSetEnable(ui.frames.next, ui.page < pages)
        if pages > 1 then
            BlzFrameSetText(ui.frames.page, "|cff99b4d1" .. I2S(ui.page) .. "/" .. I2S(pages) .. "|r")
        else
            BlzFrameSetText(ui.frames.page, "")
        end

        ui.cosmeticEntries = {}
        while i <= LIST_ROWS do
            setRow(ui.frames.rows[i], "", "", "", false)
            i = i + 1
        end

        i = 1
        while i <= COSMETIC_SLOTS do
            local entry = entries[first + i - 1]
            local slot = ui.frames.cosmeticSlots[i]

            if entry then
                local cosmetic = selectingSkinRace and nil or entry
                local unlocked = cosmetic == nil or Cosmetics.isUnlocked(player, cosmetic)
                local equipped = cosmetic ~= nil and Cosmetics.isEquipped(player, cosmetic, ui.skinRace)

                if selectingSkinRace then
                    ui.cosmeticEntries[i] = {
                        isRace = true,
                        race = entry,
                        name = entry:toString(),
                        description = entry:class() == PlayerData.CLASS_TITAN and "Titan" or "Builder",
                        icon = entry:icon()
                    }
                else
                    ui.cosmeticEntries[i] = cosmetic
                end
                BlzFrameSetVisible(slot.button, true)
                BlzFrameSetEnable(slot.button, true)
                BlzFrameSetTexture(slot.icon, ui.cosmeticEntries[i].icon, 0, true)
                BlzFrameSetVisible(slot.effect, equipped)
                if rawget(_G, "BlzFrameSetAlpha") then
                    BlzFrameSetAlpha(slot.icon, unlocked and 255 or 100)
                end
            else
                BlzFrameSetVisible(slot.button, false)
                BlzFrameSetEnable(slot.button, false)
                BlzFrameSetVisible(slot.effect, false)
            end
            i = i + 1
        end
    end

    local function updateStats(profile)
        local stats = profile.stats
        local rating = profile.rating
        local games = totalGames(stats)
        local wins = totalWins(stats)
        local losses = math.max(0, games - wins)
        local rows = {
            { THEME.muted .. "Titan Elo|r", I2S(R2I(rating.titanElo or 0)) .. " (" .. I2S(rating.titanMatches or 0) .. ")" },
            { THEME.muted .. "Builder Elo|r", I2S(R2I(rating.builderElo or 0)) .. " (" .. I2S(rating.builderMatches or 0) .. ")" },
            { THEME.muted .. "Games|r", I2S(games) },
            { THEME.win .. "Wins|r", I2S(wins) },
            { THEME.loss .. "Losses|r", I2S(losses) },
            { THEME.muted .. "Titan|r", I2S(stats.titan or 0) .. " games, " .. I2S(stats.winsTitan or 0) .. " wins" },
            { THEME.muted .. "Builder|r", I2S(stats.builder or 0) .. " games, " .. I2S(stats.winsBuilder or 0) .. " wins" },
            { THEME.muted .. "Random picks|r", I2S(stats.random or 0) }
        }
        local i = 1

        BlzFrameSetVisible(ui.frames.previous, false)
        BlzFrameSetVisible(ui.frames.next, false)
        BlzFrameSetVisible(ui.frames.pagination, false)
        ui.totalPages = 1
        BlzFrameSetText(ui.frames.page, "")
        while i <= LIST_ROWS do
            local row = rows[i]
            if row then
                setRow(ui.frames.rows[i], "", row[1], "|cffffffff" .. row[2] .. "|r", true)
            else
                setRow(ui.frames.rows[i], "", "", "", false)
            end
            i = i + 1
        end
    end

    local function updateRaceList(profile, classValue)
        local races = raceList(classValue)
        local entries = classValue == PlayerData.CLASS_TITAN and profile.stats.titanRaces or profile.stats.builderRaces
        local pages = math.max(1, R2I((#races + LIST_ROWS - 1) / LIST_ROWS))
        local first = 1
        local i = 1

        ui.totalPages = pages
        if ui.page > pages then
            ui.page = pages
        end
        first = (ui.page - 1) * LIST_ROWS + 1
        BlzFrameSetVisible(ui.frames.previous, pages > 1)
        BlzFrameSetVisible(ui.frames.next, pages > 1)
        BlzFrameSetVisible(ui.frames.pagination, pages > 1)
        BlzFrameSetEnable(ui.frames.previous, ui.page > 1)
        BlzFrameSetEnable(ui.frames.next, ui.page < pages)
        BlzFrameSetText(ui.frames.page, "|cff99b4d1" .. I2S(ui.page) .. "/" .. I2S(pages) .. "|r")

        while i <= LIST_ROWS do
            local race = races[first + i - 1]
            if race then
                local entry = entries[race:toString()]
                local wins = type(entry) == "table" and (entry.wins or 0) or 0
                local losses = type(entry) == "table" and (entry.losses or 0) or 0

                setRow(
                    ui.frames.rows[i],
                    race:icon(),
                    "|cffffffff" .. race:toString() .. "|r",
                    "|cff80ff80W " .. I2S(wins) .. "|r  |cffff6060L " .. I2S(losses) .. "|r",
                    true
                )
            else
                setRow(ui.frames.rows[i], "", "", "", false)
            end
            i = i + 1
        end
    end

    local function update()
        local player = GetLocalPlayer()
        local data = PlayerData.get(player)
        local profile = PlayerProfile.get(player)

        if not data or data:isFake() or not profile then
            return
        end

        BlzFrameSetText(ui.frames.name, "|cffffffff" .. data:name() .. "|r")
        updateTabs()
        BlzFrameSetVisible(ui.frames.scaledModels, ui.tab == "graphics")
        BlzFrameSetVisible(ui.frames.graphicsDescription, ui.tab == "graphics")
        if ui.tab == "graphics" then
            setCosmeticCategoriesVisible(false)
            setCosmeticSlotsVisible(false)
            for i = 1, LIST_ROWS do
                setRow(ui.frames.rows[i], "", "", "", false)
            end
            ui.totalPages = 1
            BlzFrameSetVisible(ui.frames.previous, false)
            BlzFrameSetVisible(ui.frames.next, false)
            BlzFrameSetVisible(ui.frames.pagination, false)
            setButtonText(ui.frames.scaledModels, "Scaled Models: " ..
                (profile.graphics.scaledModels == true and "Enabled" or "Disabled"))
            updateInteractiveState()
            return
        end
        if ui.tab == "titan" then
            setCosmeticCategoriesVisible(false)
            setCosmeticSlotsVisible(false)
            updateRaceList(profile, PlayerData.CLASS_TITAN)
        elseif ui.tab == "builder" then
            setCosmeticCategoriesVisible(false)
            setCosmeticSlotsVisible(false)
            updateRaceList(profile, PlayerData.CLASS_DEFENDER)
        elseif ui.tab == "cosmetics" then
            setCosmeticCategoriesVisible(true)
            updateCosmetics(player)
        else
            setCosmeticCategoriesVisible(false)
            setCosmeticSlotsVisible(false)
            updateStats(profile)
        end
        updateInteractiveState()
    end

    local function toggle()
        setVisible(not ui.visible)
        if ui.visible then
            update()
        end
    end

    local function showCosmeticTooltip(slotIndex)
        local entry = ui.cosmeticEntries[slotIndex]
        local tooltip = ui.frames.cosmeticTooltip
        local slot = ui.frames.cosmeticSlots[slotIndex]
        local unlocked = false
        local equipped = false

        if not entry or not tooltip or not slot then
            return
        end

        unlocked = entry.isRace or Cosmetics.isUnlocked(GetLocalPlayer(), entry)
        equipped = not entry.isRace and Cosmetics.isEquipped(GetLocalPlayer(), entry, ui.skinRace)
        if rawget(_G, "BlzFrameClearAllPoints") then
            BlzFrameClearAllPoints(tooltip.frame)
        end
        BlzFrameSetPoint(tooltip.frame, FRAMEPOINT_TOPLEFT, slot.button, FRAMEPOINT_TOPRIGHT, 0.006, 0.000)
        BlzFrameSetText(tooltip.title, "|cffffcc00" .. entry.name .. "|r")
        BlzFrameSetText(tooltip.description, "|cffd0d0d0" .. entry.description .. "|r")
        if entry.isRace then
            BlzFrameSetText(tooltip.status, "")
        elseif entry.category == "skin" then
            BlzFrameSetText(tooltip.status,
                (unlocked and "|cff80ff80Unlocked|r" or "|cffff6060Locked|r") ..
                "  |  " ..
                (equipped and "|cff80ff80Active|r" or "|cff9CAABDInactive|r"))
        else
            BlzFrameSetText(tooltip.status, unlocked and "|cff80ff80Unlocked|r" or "|cffff6060Locked|r")
        end
        BlzFrameSetVisible(tooltip.frame, true)
    end

    hideCosmeticTooltip = function()
        if ui.frames.cosmeticTooltip then
            BlzFrameSetVisible(ui.frames.cosmeticTooltip.frame, false)
        end
    end

    local function createText(name, parent, point, relative, x, y, scale)
        local frame = BlzCreateFrameByType("TEXT", name, parent, "", 0)

        BlzFrameSetPoint(frame, point, relative or parent, point, x, y)
        BlzFrameSetScale(frame, scale)
        BlzFrameSetEnable(frame, false)
        return frame
    end

    local function createBackdrop(name, parent, color)
        local frame = BlzCreateFrameByType("BACKDROP", name, parent, "", 0)

        BlzFrameSetTexture(frame, SOLID_TEXTURE, 0, true)
        if rawget(_G, "BlzFrameSetVertexColor") then
            BlzFrameSetVertexColor(frame, color)
        end
        BlzFrameSetEnable(frame, false)
        return frame
    end

    local function createActionButton(name, parent, x, y, width, text, action)
        local button = BlzCreateFrameByType("BUTTON", name, parent, "", 0)
        local questBackdrop = BlzCreateFrame("QuestButtonBackdropTemplate", button, 0, nextDecorativeContext)
        local background = createBackdrop(name .. "Background", button, THEME.buttonIdle)
        local accent = createBackdrop(name .. "Accent", button, THEME.accentSurface)
        local label = createText(name .. "Label", button, FRAMEPOINT_CENTER, nil, 0.000, 0.000, 0.78)

        nextDecorativeContext = nextDecorativeContext + 1
        BlzFrameSetSize(button, width, 0.024)
        BlzFrameSetPoint(button, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, x, y)
        if rawget(_G, "BlzFrameClearAllPoints") then
            BlzFrameClearAllPoints(questBackdrop)
        end
        BlzFrameSetAllPoints(questBackdrop, button)
        BlzFrameSetEnable(questBackdrop, false)
        BlzFrameSetAllPoints(background, button)
        BlzFrameSetVisible(background, false)
        BlzFrameSetSize(accent, width - 0.010, 0.002)
        BlzFrameSetPoint(accent, FRAMEPOINT_BOTTOM, button, FRAMEPOINT_BOTTOM, 0.000, 0.003)
        BlzFrameSetVisible(accent, false)
        BlzFrameSetText(label, THEME.muted .. text .. "|r")
        ui.actions[GetHandleId(button)] = action
        ui.actionFrames[GetHandleId(button)] = button
        ui.buttonVisuals[GetHandleId(button)] = {
            questBackdrop = questBackdrop,
            background = background,
            accent = accent,
            label = label
        }
        if action ~= "toggle" then
            ui.profileButtons[#ui.profileButtons + 1] = button
        end
        return button
    end

    local function createFrames()
        local gameUi = nil
        local trigger = nil
        local i = 1

        if ui.ready or not isEnabled() then
            return
        end

        gameUi = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        ui.frames.button = BlzCreateFrameByType("BUTTON", "IDPlayerProfileButton", gameUi, "", 0)
        ui.frames.buttonBackground = createBackdrop("IDPlayerProfileButtonBackground", ui.frames.button, THEME.surface)
        ui.frames.icon = BlzCreateFrameByType("BACKDROP", "IDPlayerProfileIcon", ui.frames.button, "", 0)
        BlzFrameSetSize(ui.frames.button, 0.022, 0.022)
        BlzFrameSetAbsPoint(ui.frames.button, FRAMEPOINT_CENTER, 0.165, 0.018)
        BlzFrameSetAllPoints(ui.frames.buttonBackground, ui.frames.button)
        BlzFrameSetSize(ui.frames.icon, 0.018, 0.018)
        BlzFrameSetPoint(ui.frames.icon, FRAMEPOINT_CENTER, ui.frames.button, FRAMEPOINT_CENTER, 0.000, 0.000)
        BlzFrameSetTexture(ui.frames.icon, PROFILE_ICON, 0, true)
        BlzFrameSetEnable(ui.frames.icon, false)
        ui.actions[GetHandleId(ui.frames.button)] = "toggle"
        ui.actionFrames[GetHandleId(ui.frames.button)] = ui.frames.button
        ui.buttonVisuals[GetHandleId(ui.frames.button)] = { background = ui.frames.buttonBackground, label = nil }
        BlzFrameSetVisible(ui.frames.button, ui.launcherVisible)
        BlzFrameSetEnable(ui.frames.button, ui.launcherVisible)

        -- These are the same standalone templates used by the original UI.
        -- Keep the outer parent enabled so its child buttons remain clickable.
        ui.frames.panel = BlzCreateFrame("EscMenuBackdrop", gameUi, 0, 0)
        if rawget(_G, "BlzFrameClearAllPoints") then
            BlzFrameClearAllPoints(ui.frames.panel)
        end
        BlzFrameSetSize(ui.frames.panel, 0.440, 0.340)
        BlzFrameSetAbsPoint(ui.frames.panel, FRAMEPOINT_CENTER, 0.270, 0.350)
        if rawget(_G, "BlzFrameSetLevel") then
            BlzFrameSetLevel(ui.frames.panel, 8)
        end
        -- Stretched, this gives the content area the same dark texture and gold
        -- edge treatment as the large description field in the quest menu.
        ui.frames.contentBackground = BlzCreateFrame("QuestButtonBackdropTemplate", ui.frames.panel, 0, 0)
        BlzFrameSetEnable(ui.frames.contentBackground, false)
        if rawget(_G, "BlzFrameClearAllPoints") then
            BlzFrameClearAllPoints(ui.frames.contentBackground)
        end
        BlzFrameSetSize(ui.frames.contentBackground, 0.388, 0.208)
        BlzFrameSetPoint(ui.frames.contentBackground, FRAMEPOINT_TOPLEFT, ui.frames.panel, FRAMEPOINT_TOPLEFT, 0.026, -0.108)

        ui.frames.close = createActionButton("IDPlayerProfileClose", ui.frames.panel, 0.392, -0.015, 0.026, "X", "close")
        ui.frames.title = createText("IDPlayerProfileTitle", ui.frames.panel, FRAMEPOINT_TOPLEFT, nil, 0.026, -0.016, 1.08)
        ui.frames.name = createText("IDPlayerProfileName", ui.frames.panel, FRAMEPOINT_TOPLEFT, nil, 0.026, -0.038, 0.90)
        BlzFrameSetText(ui.frames.title, THEME.accent .. "Player Profile|r")

        ui.frames.tabs = {
            stats = createActionButton("IDPlayerProfileStats", ui.frames.panel, 0.026, -0.066, 0.064, "Stats", "tab:stats"),
            titan = createActionButton("IDPlayerProfileTitan", ui.frames.panel, 0.094, -0.066, 0.064, "Titan", "tab:titan"),
            builder = createActionButton("IDPlayerProfileBuilder", ui.frames.panel, 0.162, -0.066, 0.072, "Builder", "tab:builder"),
            cosmetics = createActionButton("IDPlayerProfileCosmetics", ui.frames.panel, 0.238, -0.066, 0.086, "Cosmetics", "tab:cosmetics"),
            graphics = createActionButton("IDPlayerProfileGraphics", ui.frames.panel, 0.328, -0.066, 0.086, "Graphics", "tab:graphics")
        }
        ui.frames.scaledModels = createActionButton("IDScaledModels", ui.frames.panel,
            0.040, -0.130, 0.240, "Scaled Models: Disabled", "scaledmodels")
        ui.frames.graphicsDescription = createText("IDGraphicsDescription", ui.frames.panel,
            FRAMEPOINT_TOPLEFT, nil, 0.040, -0.174, 1.0)
        -- Keep geometry unscaled: scaling the text frame also shifts its
        -- effective offsets and can pull the description over the button.
        BlzFrameSetFont(ui.frames.graphicsDescription, "Fonts\\FRIZQT__.TTF", 0.009, 0)
        BlzFrameClearAllPoints(ui.frames.graphicsDescription)
        BlzFrameSetPoint(ui.frames.graphicsDescription, FRAMEPOINT_TOPLEFT,
            ui.frames.scaledModels, FRAMEPOINT_BOTTOMLEFT, 0.0, -0.018)
        BlzFrameSetSize(ui.frames.graphicsDescription, 0.340, 0.105)
        BlzFrameSetTextAlignment(ui.frames.graphicsDescription, TEXT_JUSTIFY_TOP, TEXT_JUSTIFY_LEFT)
        BlzFrameSetText(ui.frames.graphicsDescription,
            "Makes selected oversized models smaller when using newer Warcraft III graphics.\n\n|cff9CAABDVisual only; gameplay stays unchanged.\nYour choice is saved automatically.|r")
        BlzFrameSetVisible(ui.frames.scaledModels, false)
        BlzFrameSetVisible(ui.frames.graphicsDescription, false)
        ui.frames.cosmeticCategories = {
            aura = createActionButton("IDPlayerProfileAuras", ui.frames.panel, 0.026, -0.092, 0.082, "Auras", "category:aura"),
            wings = createActionButton("IDPlayerProfileWings", ui.frames.panel, 0.114, -0.092, 0.082, "Wings", "category:wings"),
            skin = createActionButton("IDPlayerProfileSkins", ui.frames.panel, 0.202, -0.092, 0.082, "Skins", "category:skin")
        }
        ui.frames.skinRaceBack = createActionButton(
            "IDPlayerProfileSkinRaceBack", ui.frames.panel, 0.298, -0.092, 0.030, "<", "skinraces")
        ui.frames.skinRaceName = createText(
            "IDPlayerProfileSkinRaceName", ui.frames.panel, FRAMEPOINT_TOPLEFT, nil, 0.335, -0.097, 0.68)
        BlzFrameSetVisible(ui.frames.skinRaceBack, false)
        BlzFrameSetVisible(ui.frames.skinRaceName, false)
        ui.frames.pagination = BlzCreateFrameByType("FRAME", "IDPlayerProfilePagination", ui.frames.panel, "", 0)
        BlzFrameSetSize(ui.frames.pagination, 0.112, 0.030)
        BlzFrameSetPoint(ui.frames.pagination, FRAMEPOINT_BOTTOMRIGHT, ui.frames.panel, FRAMEPOINT_BOTTOMRIGHT, -0.026, 0.014)
        BlzFrameSetEnable(ui.frames.pagination, false)
        ui.frames.previous = createActionButton("IDPlayerProfilePrevious", ui.frames.panel, 0.306, -0.305, 0.030, "<", "previous")
        ui.frames.page = createText("IDPlayerProfilePage", ui.frames.panel, FRAMEPOINT_CENTER,
            ui.frames.pagination, 0.000, 0.000, 0.68)
        ui.frames.next = createActionButton("IDPlayerProfileNext", ui.frames.panel, 0.384, -0.305, 0.030, ">", "next")

        ui.frames.rows = {}
        while i <= LIST_ROWS do
            local row = {}
            local y = -0.117 - (i - 1) * 0.019

            row.frame = BlzCreateFrameByType("FRAME", "IDPlayerProfileRow" .. I2S(i), ui.frames.panel, "", 0)
            BlzFrameSetSize(row.frame, 0.380, 0.018)
            BlzFrameSetPoint(row.frame, FRAMEPOINT_TOPLEFT, ui.frames.panel, FRAMEPOINT_TOPLEFT, 0.030, y)
            row.background = createBackdrop("IDPlayerProfileRowBackground" .. I2S(i), row.frame,
                ModuloInteger(i, 2) == 0 and BlzConvertColor(58, 21, 30, 39) or BlzConvertColor(32, 8, 13, 18))
            BlzFrameSetAllPoints(row.background, row.frame)
            BlzFrameSetVisible(row.background, false)
            row.separator = createBackdrop("IDPlayerProfileRowSeparator" .. I2S(i), row.frame,
                BlzConvertColor(110, 154, 111, 24))
            BlzFrameSetSize(row.separator, 0.374, 0.001)
            BlzFrameSetPoint(row.separator, FRAMEPOINT_BOTTOM, row.frame, FRAMEPOINT_BOTTOM, 0.000, 0.000)
            row.icon = BlzCreateFrameByType("BACKDROP", "IDPlayerProfileRowIcon" .. I2S(i), row.frame, "", 0)
            BlzFrameSetSize(row.icon, 0.017, 0.017)
            BlzFrameSetPoint(row.icon, FRAMEPOINT_TOPLEFT, row.frame, FRAMEPOINT_TOPLEFT, 0.000, 0.000)
            BlzFrameSetEnable(row.icon, false)
            row.name = createText("IDPlayerProfileRowName" .. I2S(i), row.frame, FRAMEPOINT_LEFT, nil, 0.027, 0.000, 0.76)
            row.result = createText("IDPlayerProfileRowResult" .. I2S(i), row.frame, FRAMEPOINT_RIGHT, nil, -0.012, 0.000, 0.76)
            ui.frames.rows[i] = row
            i = i + 1
        end

        ui.frames.cosmeticSlots = {}
        i = 1
        while i <= COSMETIC_SLOTS do
            local column = ModuloInteger(i - 1, COSMETIC_COLUMNS)
            local rowIndex = R2I((i - 1) / COSMETIC_COLUMNS)
            local slot = {}

            slot.button = BlzCreateFrameByType("BUTTON", "IDPlayerProfileCosmetic" .. I2S(i), ui.frames.panel, "", 0)
            slot.border = createBackdrop("IDPlayerProfileCosmeticBorder" .. I2S(i), slot.button, THEME.border)
            slot.effect = createBackdrop("IDPlayerProfileCosmeticEffect" .. I2S(i), slot.button, THEME.accentSurface)
            slot.background = createBackdrop("IDPlayerProfileCosmeticBackground" .. I2S(i), slot.button, THEME.surface)
            slot.icon = BlzCreateFrameByType("BACKDROP", "IDPlayerProfileCosmeticIcon" .. I2S(i), slot.button, "", 0)
            BlzFrameSetSize(slot.button, 0.036, 0.036)
            BlzFrameSetPoint(slot.button, FRAMEPOINT_TOPLEFT, ui.frames.panel, FRAMEPOINT_TOPLEFT,
                0.030 + column * 0.045, -0.120 - rowIndex * 0.045)
            BlzFrameSetAllPoints(slot.border, slot.button)
            BlzFrameSetAllPoints(slot.effect, slot.button)
            BlzFrameSetVisible(slot.effect, false)
            BlzFrameSetSize(slot.background, 0.034, 0.034)
            BlzFrameSetPoint(slot.background, FRAMEPOINT_CENTER, slot.button, FRAMEPOINT_CENTER, 0.000, 0.000)
            BlzFrameSetSize(slot.icon, 0.030, 0.030)
            BlzFrameSetPoint(slot.icon, FRAMEPOINT_CENTER, slot.button, FRAMEPOINT_CENTER, 0.000, 0.000)
            BlzFrameSetEnable(slot.icon, false)
            BlzFrameSetVisible(slot.button, false)
            ui.actions[GetHandleId(slot.button)] = "cosmeticslot:" .. I2S(i)
            ui.actionFrames[GetHandleId(slot.button)] = slot.button
            ui.buttonVisuals[GetHandleId(slot.button)] = { background = slot.background, label = nil }
            ui.profileButtons[#ui.profileButtons + 1] = slot.button
            ui.frames.cosmeticSlots[i] = slot
            i = i + 1
        end

        ui.frames.cosmeticTooltip = {
            frame = createBackdrop("IDPlayerProfileCosmeticTooltip", ui.frames.panel, THEME.surface),
            title = nil,
            description = nil,
            status = nil
        }
        BlzFrameSetSize(ui.frames.cosmeticTooltip.frame, 0.145, 0.060)
        if rawget(_G, "BlzFrameSetLevel") then
            BlzFrameSetLevel(ui.frames.cosmeticTooltip.frame, 20)
        end
        ui.frames.cosmeticTooltip.title = createText("IDPlayerProfileCosmeticTooltipTitle", ui.frames.cosmeticTooltip.frame,
            FRAMEPOINT_TOPLEFT, nil, 0.008, -0.006, 0.70)
        ui.frames.cosmeticTooltip.description = createText("IDPlayerProfileCosmeticTooltipDescription", ui.frames.cosmeticTooltip.frame,
            FRAMEPOINT_TOPLEFT, nil, 0.008, -0.023, 0.56)
        ui.frames.cosmeticTooltip.status = createText("IDPlayerProfileCosmeticTooltipStatus", ui.frames.cosmeticTooltip.frame,
            FRAMEPOINT_BOTTOMLEFT, nil, 0.008, 0.006, 0.58)
        BlzFrameSetVisible(ui.frames.cosmeticTooltip.frame, false)

        -- This periodic timer is created identically on every client. Clicks
        -- only set local UI state, so no timer handle is started asymmetrically.
        ui.focusTimer = GameTimer.every(0.03, function()
            if ui.focusReleasePending then
                clearFrameFocusNow()
                updateInteractiveState()
                if ui.focusedFrame then
                    setButtonSurface(ui.focusedFrame, THEME.buttonIdle)
                end
                ui.focusedFrame = nil
                ui.focusReleasePending = false
                updateTabs()
                if ui.tab == "cosmetics" then
                    updateCosmeticCategoryTabs()
                end
            end
        end)

        BlzFrameSetVisible(ui.frames.panel, false)
        updateInteractiveState()
        trigger = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.button, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.close, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.tabs.stats, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.tabs.titan, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.tabs.builder, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.tabs.cosmetics, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.tabs.graphics, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.scaledModels, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.cosmeticCategories.aura, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.cosmeticCategories.wings, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.cosmeticCategories.skin, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.skinRaceBack, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.previous, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(trigger, ui.frames.next, FRAMEEVENT_CONTROL_CLICK)

        i = 1
        while i <= COSMETIC_SLOTS do
            BlzTriggerRegisterFrameEvent(trigger, ui.frames.cosmeticSlots[i].button, FRAMEEVENT_CONTROL_CLICK)
            i = i + 1
        end
        TriggerAddAction(trigger, function()
            local frame = BlzGetTriggerFrame()
            local action = ui.actions[GetHandleId(frame)]

            -- Frame events are broadcast to every client. Profile visibility and
            -- tab state belong to the player who actually clicked the frame.
            if GetTriggerPlayer() ~= GetLocalPlayer() then
                return
            end

            setButtonSurface(frame, THEME.buttonPressed)

            if action == "toggle" then
                toggle()
            elseif action == "close" then
                setVisible(false)
            elseif action == "scaledmodels" then
                local saved = LocalModelScaling.setEnabled(not PlayerProfile.graphics(GetLocalPlayer()).scaledModels)
                if not saved then
                    DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 8,
                        "|cffffcc00Scaled Models changed, but the profile could not be saved.|r")
                end
                update()
            elseif action == "previous" then
                ui.page = math.max(1, ui.page - 1)
                update()
            elseif action == "next" then
                ui.page = ui.page + 1
                update()
            elseif action == "skinraces" then
                ui.skinRace = ""
                ui.page = 1
                update()
            elseif action then
                local tab = string.match(action, "^tab:(.+)$")
                local category = string.match(action, "^category:(.+)$")
                local slotIndex = tonumber(string.match(action, "^cosmeticslot:(%d+)$"))
                if tab then
                    ui.tab = tab
                    ui.page = 1
                    update()
                elseif category then
                    ui.cosmeticCategory = category
                    if category == "skin" then
                        ui.skinRace = ""
                    end
                    ui.page = 1
                    update()
                elseif slotIndex and ui.tab == "cosmetics" then
                    local cosmetic = ui.cosmeticEntries[slotIndex]
                    local requested = false
                    local reason = nil

                    if cosmetic and cosmetic.isRace then
                        ui.skinRace = cosmetic.race:toString()
                        ui.page = 1
                        update()
                    elseif cosmetic then
                        requested, reason = Cosmetics.requestEquip(GetLocalPlayer(), cosmetic.id, ui.skinRace)
                    end

                    if cosmetic and not cosmetic.isRace and not requested then
                        if reason == "aura-limit" then
                            DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 10,
                                "|cffff6060You can equip a maximum of three auras.|r")
                        elseif reason == "wings-limit" then
                            DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 10,
                                "|cffff6060You can equip a maximum of two wings.|r")
                        elseif reason == "profiles-loading" then
                            DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 10,
                                "|cff99b4d1Profiles are still synchronizing. Please try again shortly.|r")
                        elseif reason == "sync-unavailable" then
                            DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 10,
                                "|cffff6060Cosmetic synchronization is unavailable.|r")
                        else
                            DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 10,
                                "|cffff6060This cosmetic is still locked.|r")
                        end
                    elseif requested then
                        -- The local profile was updated before its selection was
                        -- sent to the shared cosmetic sync event.
                        update()
                    end
                end
            end
            releaseFrameInput(frame)
        end)

        local buttonStateTrigger = CreateTrigger()
        BlzTriggerRegisterFrameEvent(buttonStateTrigger, ui.frames.button, FRAMEEVENT_MOUSE_ENTER)
        BlzTriggerRegisterFrameEvent(buttonStateTrigger, ui.frames.button, FRAMEEVENT_MOUSE_LEAVE)
        i = 1
        while i <= #ui.profileButtons do
            BlzTriggerRegisterFrameEvent(buttonStateTrigger, ui.profileButtons[i], FRAMEEVENT_MOUSE_ENTER)
            BlzTriggerRegisterFrameEvent(buttonStateTrigger, ui.profileButtons[i], FRAMEEVENT_MOUSE_LEAVE)
            i = i + 1
        end
        TriggerAddAction(buttonStateTrigger, function()
            local frame = BlzGetTriggerFrame()
            local event = BlzGetTriggerFrameEvent()

            if GetTriggerPlayer() ~= GetLocalPlayer() or not buttonShouldBeEnabled(frame) then
                return
            end
            if event == FRAMEEVENT_MOUSE_ENTER then
                setButtonSurface(frame, THEME.buttonHover)
                local visual = ui.buttonVisuals[GetHandleId(frame)]
                if visual and visual.accent then
                    BlzFrameSetVisible(visual.accent, true)
                end
            else
                setButtonSurface(frame, THEME.buttonIdle)
                local visual = ui.buttonVisuals[GetHandleId(frame)]
                if visual and visual.accent then
                    BlzFrameSetVisible(visual.accent, false)
                end
                updateTabs()
                if ui.tab == "cosmetics" then
                    updateCosmeticCategoryTabs()
                end
            end
        end)

        local tooltipTrigger = CreateTrigger()
        i = 1
        while i <= COSMETIC_SLOTS do
            BlzTriggerRegisterFrameEvent(tooltipTrigger, ui.frames.cosmeticSlots[i].button, FRAMEEVENT_MOUSE_ENTER)
            BlzTriggerRegisterFrameEvent(tooltipTrigger, ui.frames.cosmeticSlots[i].button, FRAMEEVENT_MOUSE_LEAVE)
            i = i + 1
        end
        TriggerAddAction(tooltipTrigger, function()
            local frame = BlzGetTriggerFrame()
            local event = BlzGetTriggerFrameEvent()
            local slotIndex = 1

            if GetTriggerPlayer() ~= GetLocalPlayer() then
                return
            end

            while slotIndex <= COSMETIC_SLOTS do
                if ui.frames.cosmeticSlots[slotIndex].button == frame then
                    if event == FRAMEEVENT_MOUSE_ENTER then
                        showCosmeticTooltip(slotIndex)
                    else
                        hideCosmeticTooltip()
                    end
                    return
                end
                slotIndex = slotIndex + 1
            end
        end)

        ui.ready = true
    end

    PlayerProfile.onLoaded(function(player)
        if ui.ready and ui.visible and player == GetLocalPlayer() then
            update()
        end
    end)

    if isEnabled() then
        -- Avoid a zero-delay map-initialization timer; very short init timers
        -- are known to be unreliable across clients.
        GameTimer.after(0.03, createFrames)
    end

    function PlayerProfileUI.show()
        if isEnabled() and ui.ready then
            setVisible(true)
            update()
        end
    end

    function PlayerProfileUI.hide()
        if ui.ready then
            setVisible(false)
        end
    end

    function PlayerProfileUI.setLauncherVisible(visible)
        setLauncherVisible(visible)
    end

    function PlayerProfileUI.isLauncherVisible()
        return ui.launcherVisible
    end

    local function profileIconCommand(args)
        local value = StringCase(args:at(0) or "", false)
        local visible = nil

        if GetLocalPlayer() ~= args:player() then
            return
        end
        if value == "" then
            visible = not ui.launcherVisible
        elseif value == "on" or value == "show" then
            visible = true
        elseif value == "off" or value == "hide" then
            visible = false
        else
            Command.say(args:player(), "|cff99b4d1Usage: -profileicon [on|off]|r")
            return
        end

        setLauncherVisible(visible)
        if visible then
            Command.say(args:player(), "|cff80ff80Player profile icon enabled.|r")
        else
            Command.say(args:player(), "|cff99b4d1Player profile icon hidden. Type -profileicon to restore it.|r")
        end
    end

    Command["-profileicon"].register(profileIconCommand,
        "Shows or hides the Player Profile launcher icon.")
    Command["-profilebutton"].register(profileIconCommand,
        "Alias for -profileicon.")

    _G.PlayerProfileUI = PlayerProfileUI
end)

if Debug and Debug.endFile then Debug.endFile() end
