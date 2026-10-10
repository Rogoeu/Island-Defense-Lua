if Debug and Debug.beginFile then Debug.beginFile("Commands/CameraCommand") end

OnInit("CameraCommand", function(import)
    import.strict("CommandRegistry")
    import.strict("GameTimer")
    import.strict("PlayerData")
    import.strict("PlayerProfile")

    local cameras = {}

    local function dataFor(player)
        local id = GetPlayerId(player)
        if not cameras[id] then
            local saved = PlayerProfile.camera(player)
            cameras[id] = {
                player = player,
                distance = saved.distance or 100,
                locked = saved.locked == true,
                smooth = saved.smooth == true
            }
        end
        return cameras[id]
    end

    local function saveProfile(data)
        PlayerProfile.setCamera(data.player, data.distance, data.locked, data.smooth)
    end

    local function persistProfile(data)
        if GetLocalPlayer() == data.player then
            PlayerProfile.saveAllPlayers()
        end
    end

    local function say(data, text)
        DisplayTimedTextToPlayer(data.player, 0, 0, 10, text)
    end

    local function clampDistance(value)
        if value < 50 then
            return 50
        end
        if value > 400 then
            return 400
        end
        return value
    end

    local function cameraDistanceToField(value)
        return R2I(value * (bj_CAMERA_DEFAULT_DISTANCE / 100.0) + 50.0)
    end

    local function applyDistance(data, value, time, silent)
        local distance = clampDistance(value)
        local result = cameraDistanceToField(distance)
        local text = "|cff90b0d0Your camera's zoom level has now been set to |r" ..
            I2S(distance) .. "|cff90b0d0%"

        data.distance = distance
        saveProfile(data)

        if distance == 400 then
            text = text .. " (max distance)"
        elseif distance == 50 then
            text = text .. " (min distance)"
        end
        text = text .. "|r"

        if GetLocalPlayer() == data.player then
            if GetCameraField(CAMERA_FIELD_TARGET_DISTANCE) ~= result then
                SetCameraField(CAMERA_FIELD_FARZ, bj_CAMERA_DEFAULT_FARZ + (result - bj_CAMERA_DEFAULT_DISTANCE), 0)
                SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, result, time or 0)
                if not silent and not data.locked then
                    say(data, text)
                end
            end
        end
    end

    local function applySmooth(data, value, silent)
        data.smooth = value == true
        saveProfile(data)
        if GetLocalPlayer() == data.player then
            if data.smooth then
                CameraSetSmoothingFactor(5.0)
            else
                CameraSetSmoothingFactor(0.0)
            end
            if not silent then
                if data.smooth then
                    say(data, "|cff90b0d0Camera smoothing has been |r|cff00ff00enabled.|r")
                else
                    say(data, "|cff90b0d0Camera smoothing has been |r|cffff0000disabled.|r")
                end
            end
        end
    end

    local function lock(data)
        data.locked = true
        saveProfile(data)
        say(data, "|cff90b0d0Your camera's distance has been locked in position.|r")
    end

    local function unlock(data)
        data.locked = false
        saveProfile(data)
        say(data, "|cff90b0d0Your camera's distance has been unlocked.|r")
    end

    local function reset(data)
        data.locked = false
        applyDistance(data, 100, 0.0, true)
        applySmooth(data, false, true)
        saveProfile(data)
        say(data, "|cff90b0d0Your camera has been reset.|r")
    end

    local function restorePlayer(player)
        local data = dataFor(player)

        -- Camera target changes may reset WC3's zoom fields; restore only the player's saved preferences.
        applyDistance(data, data.distance, 0.0, true)
        applySmooth(data, data.smooth, true)
    end

    local function parseInt(text)
        local value = tonumber(text or "")
        if not value then
            return nil
        end
        return R2I(value)
    end

    local function parseOnOff(text)
        local value = StringCase(text or "", false)
        if value == "on" then
            return true
        elseif value == "off" then
            return false
        end
        return nil
    end

    local function run(args)
        local data = dataFor(args:player())
        local index = 0

        if args:count() == 0 then
            reset(data)
            persistProfile(data)
            return
        end

        while index < args:count() do
            local raw = args:at(index)
            local number = parseInt(raw)

            if number then
                applyDistance(data, number, 1.0, false)
            else
                local arg = StringCase(raw, false)

                if arg == "scroll" or arg == "s" or arg == "smooth" then
                    local nextValue = parseOnOff(args:at(index + 1))
                    if nextValue ~= nil then
                        index = index + 1
                        applySmooth(data, nextValue, false)
                    else
                        applySmooth(data, not data.smooth, false)
                    end
                elseif arg == "lock" or arg == "l" then
                    local nextNumber = parseInt(args:at(index + 1))
                    local nextValue = parseOnOff(args:at(index + 1))
                    if nextNumber then
                        index = index + 1
                        applyDistance(data, nextNumber, 0.0, true)
                        lock(data)
                    elseif nextValue ~= nil then
                        index = index + 1
                        if nextValue then
                            lock(data)
                        else
                            unlock(data)
                        end
                    else
                        lock(data)
                    end
                elseif arg == "unlock" or arg == "u" then
                    unlock(data)
                elseif arg == "reset" or arg == "r" then
                    reset(data)
                else
                    say(data, "|cffff0000Unknown camera request: |r" .. arg .. "|cffff0000.|r")
                end
            end

            index = index + 1
        end

        persistProfile(data)
    end

    Command["-c"].register(run, "Camera command: -c 50-400, s, l, u, r.")
    Command["-cam"].register(run, "Camera command: -cam 50-400, smooth, lock.")
    Command["-camera"].register(run, "Camera command alias.")
    Command["-zoom"].register(run, "Camera command alias.")

    PlayerProfile.onLoaded(function(player, profile, loadedFromSave)
        local data = dataFor(player)

        data.distance = profile.camera.distance or 100
        data.locked = profile.camera.locked == true
        data.smooth = profile.camera.smooth == true
        applyDistance(data, data.distance, 0.0, true)
        applySmooth(data, data.smooth, true)

        if loadedFromSave and GetLocalPlayer() == player then
            local smoothing = data.smooth and "on" or "off"
            local locked = data.locked and "locked" or "unlocked"

            say(data, "|cff99b4d1Loaded saved camera settings: |r|cffffff80" ..
                I2S(data.distance) .. "% zoom, smoothing " .. smoothing .. ", " .. locked .. ".|r")
        end
    end)

    GameTimer.every(0.5, function()
        local list = PlayerData.allReal()
        local i = 0
        while i < list:size() do
            local data = dataFor(list:at(i):player())
            if data.locked then
                applyDistance(data, data.distance, 0.0, true)
            end
            i = i + 1
        end
        list:destroy()
    end)

    _G.CameraCommand = {
        dataFor = dataFor,
        reset = reset,
        setDistance = applyDistance,
        setSmooth = applySmooth,
        restorePlayer = restorePlayer
    }
end)

if Debug and Debug.endFile then Debug.endFile() end
