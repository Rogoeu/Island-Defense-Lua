if Debug and Debug.beginFile then Debug.beginFile("Libraries/PlayerColorUtils") end

OnInit("PlayerColorUtils", function()
    local COLOR_CODES = {
        [0] = "ff0303",
        [1] = "0042ff",
        [2] = "1ce6b9",
        [3] = "540081",
        [4] = "fffc01",
        [5] = "fe8a0e",
        [6] = "20c000",
        [7] = "e55bb0",
        [8] = "959697",
        [9] = "7ebff1",
        [10] = "106246",
        [11] = "4e2a04",
        [12] = "9b0000",
        [13] = "0000c3",
        [14] = "00eaff",
        [15] = "be00fe",
        [16] = "ebcd87",
        [17] = "f8a48b",
        [18] = "bfff80",
        [19] = "dcb9eb",
        [20] = "282828",
        [21] = "ebf0ff",
        [22] = "00781e",
        [23] = "a46f33"
    }

    local PlayerColorUtils = {}

    function PlayerColorUtils.code(player)
        return COLOR_CODES[GetPlayerId(player)] or "ffffff"
    end

    function PlayerColorUtils.wrap(player, text)
        return "|cff" .. PlayerColorUtils.code(player) .. tostring(text or "") .. "|r"
    end

    function PlayerColorUtils.name(player)
        return PlayerColorUtils.wrap(player, GetPlayerName(player))
    end

    function GetPlayerNameColored(player)
        return PlayerColorUtils.name(player)
    end

    _G.PlayerColorUtils = PlayerColorUtils
end)

if Debug and Debug.endFile then Debug.endFile() end
