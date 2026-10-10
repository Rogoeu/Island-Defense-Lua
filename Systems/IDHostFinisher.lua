if Debug and Debug.beginFile then Debug.beginFile("Systems/IDHostFinisher") end

-- V2: local reporting only; no changes to Elo, profiles or win conditions.
OnInit.map("IDHostFinisher", function(import)
    import.strict("IslandDefenseSystem")
    import.strict("PlayerData")
    local HOST_NAME = "Rogoeu#2907"
    local HOST_SLOT = 15
    local DIRECTORY = "GameData\\IslandDefense\\IDHost\\"
    local token, started, finished = nil, false, false
    local roster = {}

    local function authorized()
        local host = Player(HOST_SLOT - 1)
        local data = PlayerData.get(host)
        return GetLocalPlayer() == host and GetPlayerController(host) == MAP_CONTROL_USER and
            GetPlayerSlotState(host) == PLAYER_SLOT_STATE_PLAYING and data ~= nil and
            not data:isFake() and data:originalName() == HOST_NAME
    end
    local function hex(value)
        return (string.gsub(tostring(value or ""), ".", function(c)
            return string.format("%02x", string.byte(c))
        end))
    end
    local function assignment()
        if token then return true end
        if not authorized() or type(Preloader) ~= "function" then return false end
        -- Same local transport used by preload-based profile readers. Restore immediately.
        local scratch = Player(0)
        local previous = GetPlayerName(scratch)
        SetPlayerName(scratch, "IDHOST_UNASSIGNED")
        local ok = pcall(Preloader, DIRECTORY .. "assignment.pld")
        local value = GetPlayerName(scratch)
        SetPlayerName(scratch, previous)
        local candidate = ok and string.match(value, "^IDHOST2:([0-9a-f]+)$") or nil
        if candidate and #candidate == 32 then token = candidate end
        return token ~= nil
    end
    local function write(kind, suffix, extra)
        if not authorized() or not token then return false end
        if type(PreloadGenClear) ~= "function" or type(PreloadGenStart) ~= "function" or
            type(Preload) ~= "function" or type(PreloadGenEnd) ~= "function" then return false end
        local record = "IDHOST_V2|token=" .. token .. "|kind=" .. kind ..
            "|hostSlot=" .. HOST_SLOT .. "|hostHex=" .. hex(HOST_NAME) ..
            "|elapsed=" .. math.max(0, math.floor(Game.currentGameElapsed())) .. (extra or "") .. "|END"
        return pcall(function()
            PreloadGenClear()
            PreloadGenStart()
            Preload(record)
            PreloadGenEnd(DIRECTORY .. token .. "-" .. suffix .. ".pld")
        end)
    end
    local function begin()
        if started then return true end
        if not assignment() then return false end
        local total = 0
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local player = Player(i)
            local data = PlayerData.get(player)
            if data and not data:isFake() and GetPlayerController(player) == MAP_CONTROL_USER and
                GetPlayerSlotState(player) == PLAYER_SLOT_STATE_PLAYING then
                local race = data:race()
                local info = "|slot=" .. (i + 1) .. "|nameHex=" .. hex(data:originalName()) ..
                    "|classHex=" .. hex(data:class()) .. "|raceHex=" .. hex(race and race:toString() or "")
                if not write("player", "player-" .. (i + 1), info) then return false end
                roster[i] = info
                total = total + 1
            end
        end
        started = write("start", "start", "|game=" .. Game.id() .. "|players=" .. total)
        return started
    end
    -- All clients create identical handles; only the authorized host performs file I/O.
    local timer = CreateTimer()
    TimerStart(timer, 0.5, true, function()
        if not started and Game.isState(Game.STATE_STARTED) then begin() end
    end)
    local leave = CreateTrigger()
    for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
        TriggerRegisterPlayerEvent(leave, Player(i), EVENT_PLAYER_LEAVE)
    end
    TriggerAddAction(leave, function()
        if not started or finished or not authorized() then return end
        local slot = GetPlayerId(GetTriggerPlayer())
        if roster[slot] then write("leave", "leave-" .. (slot + 1), roster[slot]) end
    end)
    Game.onFinish(function(winner)
        if winner ~= "titan" and winner ~= "defenders" then return end
        if finished or not Game.isState(Game.STATE_FINISHED) or not authorized() then return end
        if begin() then
            finished = write("result", "result", "|game=" .. Game.id() .. "|winner=" .. winner)
        end
    end)
end)
if Debug and Debug.endFile then Debug.endFile() end
