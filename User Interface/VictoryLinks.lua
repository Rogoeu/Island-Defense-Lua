if Debug and Debug.beginFile then Debug.beginFile("User Interface/VictoryLinks") end

OnInit("VictoryLinks", function()
    -- Set the public URLs here. Empty entries show a neutral placeholder.
    local DISCORD_URL = "https://discord.com/invite/gkFHk3U7T7"
    local DONATION_URL = "https://www.paypal.com/ncp/payment/BQKW99X6JJW52"
    local VictoryLinks = {}
    local panel
    local boxes = {}
    local loadFailed = false

    local function reportFailure(message)
        loadFailed = true
        DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 30,
            "|cffff6060Victory links: |r" .. message)
        return false
    end

    local function label(text, x, y, width)
        local frame = BlzCreateFrameByType("TEXT", "", panel, "", 0)
        BlzFrameSetPoint(frame, FRAMEPOINT_TOPLEFT, panel, FRAMEPOINT_TOPLEFT, x, y)
        BlzFrameSetSize(frame, width, 0.018)
        BlzFrameSetFont(frame, "Fonts\\FRIZQT__.TTF", 0.009, 0)
        BlzFrameSetText(frame, text)
        return frame
    end

    local function create()
        if not BlzLoadTOCFile("war3mapImported\\VictoryLinks.toc") then
            return reportFailure("Could not load war3mapImported\\VictoryLinks.toc. Check the TOC and FDF import paths.")
        end
        panel = BlzCreateFrame("EscMenuBackdrop", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), 0, 0)
        if not panel then
            return reportFailure("Could not create EscMenuBackdrop. Check VictoryLinks.fdf and its templates.")
        end
        -- Keep native scale for editbox cursor and mouse-selection coordinates.
        BlzFrameSetSize(panel, 0.44, 0.125)
        BlzFrameSetAbsPoint(panel, FRAMEPOINT_BOTTOM, 0.55, 0.18)
        label("|cffffcc00Island Defense Community|r", 0.018, -0.014, 0.40)
        label("Drag across a link to select it, then press Ctrl+C.", 0.018, -0.032, 0.40)
        local names = { "Discord", "Donations" }
        for i = 1, 2 do
            local y = -0.052 - (i - 1) * 0.029
            label(names[i], 0.018, y - 0.006, 0.065)
            boxes[i] = BlzCreateFrame("IDVictoryLinkEditBox", panel, 0, i)
            if not boxes[i] then
                BlzDestroyFrame(panel)
                panel = nil
                boxes = {}
                return reportFailure("Could not create IDVictoryLinkEditBox. Check war3mapImported\\VictoryLinks.fdf.")
            end
            BlzFrameSetPoint(boxes[i], FRAMEPOINT_TOPLEFT, panel, FRAMEPOINT_TOPLEFT, 0.090, y)
            BlzFrameSetTextSizeLimit(boxes[i], 2048)
        end
        return true
    end

    function VictoryLinks.show()
        if loadFailed then return end
        if not panel and not create() then return end
        BlzFrameSetText(boxes[1], DISCORD_URL ~= "" and DISCORD_URL or "Discord link not configured yet")
        BlzFrameSetText(boxes[2], DONATION_URL ~= "" and DONATION_URL or "Donation link not configured yet")
        BlzFrameSetVisible(panel, true)
    end

    function VictoryLinks.hide()
        if panel then
            for i = 1, #boxes do BlzFrameSetFocus(boxes[i], false) end
            BlzFrameSetVisible(panel, false)
        end
    end

    _G.VictoryLinks = VictoryLinks
end)

if Debug and Debug.endFile then Debug.endFile() end
