if Debug and Debug.beginFile then Debug.beginFile("Player/PlayerProfile") end

OnInit("PlayerProfile", function(import)
    import.strict("PlayerData")
    import.strict("GameSettings")
    import.strict("GameTimer")

    local PROFILE_VERSION = "v1"
    local PROFILE_DIRECTORY = "GameData\\IslandDefense\\Profiles\\"
    -- Change this value for a new ranked season. Each season receives isolated saves.
    local PROFILE_SEASON = "Season1"
    local ALLOW_LEGACY_PROFILE_MIGRATION = false
    local LEGACY_PROFILE_FILE = PROFILE_DIRECTORY .. "player_profile.pld"
    local PROFILE_CHUNK_LENGTH = 209
    local PROFILE_FILE_LENGTH = PROFILE_CHUNK_LENGTH * bj_MAX_PLAYER_SLOTS
    local PROFILE_SEGMENT_LENGTH = PROFILE_FILE_LENGTH - 32
    local MAX_PROFILE_SEGMENTS = 32
    local MAX_PROFILE_LENGTH = PROFILE_SEGMENT_LENGTH * MAX_PROFILE_SEGMENTS
    local SYNC_PREFIX = "IDPROFILE"
    local SYNC_CHUNK_LENGTH = 180
    local MAX_SYNC_CHUNKS = R2I((MAX_PROFILE_LENGTH + SYNC_CHUNK_LENGTH - 1) / SYNC_CHUNK_LENGTH)
    local ELO_REQUIRED_PLAYERS = 11

    local profiles = {}
    local loadCallbacks = {}
    local pendingSyncs = {}
    local expectedProfileSyncs = {}
    local receivedProfileSyncs = {}
    local profileSyncCallbacks = {}
    local profilesSynchronized = false
    local eloMatchEligible = false
    local matchResultRecorded = false
    local matchStartingElo = {}
    local outgoingSyncQueue = {}
    local outgoingSyncHead = 1

    local PlayerProfile = {}

    local function defaultProfile()
        return {
            version = PROFILE_VERSION,
            stats = {
                races = {},
                titanRaces = {},
                builderRaces = {},
                random = 0,
                titan = 0,
                builder = 0,
                winsTitan = 0,
                winsBuilder = 0
            },
            camera = {
                distance = 100,
                locked = false,
                smooth = false
            },
            graphics = {
                scaledModels = false
            },
            bans = {
                builder = {},
                titan = {}
            },
            rating = {
                titanElo = GameSettings.getInt("PLAYER_PROFILE_ELO_DEFAULT"),
                builderElo = GameSettings.getInt("PLAYER_PROFILE_ELO_DEFAULT"),
                titanMatches = 0,
                builderMatches = 0
            },
            pendingMatch = {
                active = false,
                role = "",
                race = "",
                eloEligible = false,
                eloPenalty = 0
            },
            cosmetics = {
                unlocked = {},
                equipped = {
                    aura = {},
                    wings = {},
                    skin = {}
                }
            }
        }
    end

    local function copyDefaults(target, defaults)
        local key = nil

        target = type(target) == "table" and target or {}
        for key, value in pairs(defaults) do
            if type(value) == "table" then
                target[key] = copyDefaults(target[key], value)
            elseif target[key] == nil then
                target[key] = value
            end
        end
        return target
    end

    local function normalizeName(player)
        local data = PlayerData.get(player)
        local name = string.lower((data and data:originalName()) or GetPlayerName(player) or "")

        return string.gsub(name, "[^%w]", "")
    end

    local function hash(value)
        local result = 5381
        local i = 1

        while i <= string.len(value) do
            result = (result * 33 + string.byte(value, i)) % 2147483647
            i = i + 1
        end
        return I2S(R2I(result))
    end

    local function profileFileNameFor(player)
        local data = PlayerData.get(player)
        local battleTag = (data and data:originalName()) or GetPlayerName(player) or ""

        -- BattleTags are readable in Explorer, while unsafe path characters are
        -- replaced so a malformed display name can never escape the directory.
        battleTag = string.gsub(battleTag, "[^%w#%-%._]", "_")
        if battleTag == "" then
            battleTag = "UnknownPlayer"
        end
        return battleTag
    end

    local function profileFileBaseFor(player)
        return PROFILE_DIRECTORY .. profileFileNameFor(player) .. "_" .. PROFILE_SEASON
    end

    local function profileFileForBase(base, segment)
        if segment == 1 then
            return base .. ".pld"
        end
        return base .. "_" .. I2S(segment) .. ".pld"
    end

    local function profileFileFor(player, segment)
        return profileFileForBase(profileFileBaseFor(player), segment)
    end

    -- Compatibility with saves written before profile files included the name.
    local function previousSeasonProfileFileFor(segment)
        return profileFileForBase(PROFILE_DIRECTORY .. "season1", segment)
    end

    local function hexEncode(value)
        local encoded = {}
        local i = 1

        while i <= string.len(value) do
            encoded[#encoded + 1] = string.format("%02X", string.byte(value, i))
            i = i + 1
        end
        return table.concat(encoded)
    end

    local function hexDecode(value)
        local decoded = {}
        local i = 1

        while i <= string.len(value) do
            local byte = tonumber(string.sub(value, i, i + 1), 16)
            if not byte then
                return nil
            end
            decoded[#decoded + 1] = string.char(byte)
            i = i + 2
        end
        return table.concat(decoded)
    end

    local function obfuscate(value, name)
        local result = {}
        local nameLength = math.max(1, string.len(name))
        local i = 1

        while i <= string.len(value) do
            local key = string.byte(name, ((i - 1) % nameLength) + 1) or 0
            local byte = (string.byte(value, i) + key + i * 17) % 256
            result[#result + 1] = string.format("%02X", byte)
            i = i + 1
        end
        return table.concat(result)
    end

    local function deobfuscate(value, name)
        local result = {}
        local nameLength = math.max(1, string.len(name))
        local i = 1

        while i <= string.len(value) do
            local byte = tonumber(string.sub(value, i, i + 1), 16)
            local position = R2I((i + 1) / 2)
            local key = string.byte(name, ((position - 1) % nameLength) + 1) or 0

            if not byte then
                return nil
            end
            result[#result + 1] = string.char((byte - key - position * 17) % 256)
            i = i + 2
        end
        return table.concat(result)
    end

    local function sortedKeys(value)
        local keys = {}
        local key = nil

        for key in pairs(value) do
            keys[#keys + 1] = key
        end
        table.sort(keys, function(left, right)
            return tostring(left) < tostring(right)
        end)
        return keys
    end

    local function serializeValue(value, path, records)
        local valueType = type(value)
        local keys = nil
        local i = 1

        if valueType == "table" then
            keys = sortedKeys(value)
            while i <= #keys do
                local key = keys[i]
                serializeValue(value[key], path .. "\31" .. tostring(key), records)
                i = i + 1
            end
        elseif valueType == "number" then
            records[#records + 1] = "n:" .. hexEncode(path) .. ":" .. hexEncode(tostring(value))
        elseif valueType == "boolean" then
            records[#records + 1] = "b:" .. hexEncode(path) .. ":" .. hexEncode(value and "1" or "0")
        elseif valueType == "string" then
            records[#records + 1] = "s:" .. hexEncode(path) .. ":" .. hexEncode(value)
        end
    end

    local function serialize(profile)
        local records = {}

        serializeValue(profile, "profile", records)
        return table.concat(records, "\n")
    end

    local function setPath(root, path, value)
        local parts = {}
        local current = root
        local i = 1

        for part in string.gmatch(path, "[^\31]+") do
            parts[#parts + 1] = part
        end
        if parts[1] ~= "profile" or #parts < 2 then
            return
        end
        while i < #parts do
            local key = parts[i]
            if i > 1 then
                current[key] = current[key] or {}
                current = current[key]
            end
            i = i + 1
        end
        current[parts[#parts]] = value
    end

    local function deserialize(value)
        local profile = {}

        for kind, encodedPath, encodedValue in string.gmatch(value, "([nbs]):([^:]+):(.-)\n") do
            local path = hexDecode(encodedPath)
            local decoded = hexDecode(encodedValue)
            local result = decoded

            if kind == "n" then
                result = tonumber(decoded)
            elseif kind == "b" then
                result = decoded == "1"
            end
            if path and result ~= nil then
                setPath(profile, path, result)
            end
        end
        return copyDefaults(profile, defaultProfile())
    end

    local function writePreloadFile(fileName, content)
        local index = 0
        local offset = 1

        if not rawget(_G, "PreloadGenClear") or not rawget(_G, "PreloadGenStart") or not rawget(_G, "PreloadGenEnd") then
            return false
        end
        if string.len(content) > PROFILE_FILE_LENGTH then
            return false
        end

        PreloadGenClear()
        PreloadGenStart()
        while offset <= string.len(content) do
            local chunk = string.sub(content, offset, offset + PROFILE_CHUNK_LENGTH - 1)
            Preload("\")\r\n\tcall SetPlayerName(Player(" .. I2S(index) .. "), \" " .. chunk .. "\")\r\n//")
            offset = offset + PROFILE_CHUNK_LENGTH
            index = index + 1
        end
        Preload("\" )\r\nendfunction\r\nfunction AAA takes nothing returns nothing \r\n//")
        PreloadGenEnd(fileName)
        return true
    end

    local function writeLocalFile(player, content)
        local total = math.max(1, R2I((string.len(content) + PROFILE_SEGMENT_LENGTH - 1) / PROFILE_SEGMENT_LENGTH))
        local segment = 1

        if total > MAX_PROFILE_SEGMENTS then
            return false
        end

        while segment <= total do
            local offset = (segment - 1) * PROFILE_SEGMENT_LENGTH + 1
            local payload = string.sub(content, offset, offset + PROFILE_SEGMENT_LENGTH - 1)
            local wrapped = I2S(segment) .. "|" .. I2S(total) .. "|" .. payload

            if not writePreloadFile(profileFileFor(player, segment), wrapped) then
                return false
            end
            segment = segment + 1
        end
        return true
    end

    local function readLocalFile(fileName)
        local previousNames = {}
        local chunks = {}
        local i = 0

        if not rawget(_G, "Preloader") then
            return ""
        end

        while i < bj_MAX_PLAYER_SLOTS do
            previousNames[i] = GetPlayerName(Player(i))
            i = i + 1
        end
        Preloader(fileName)
        i = 0
        while i < bj_MAX_PLAYER_SLOTS do
            local loadedName = GetPlayerName(Player(i))
            if loadedName ~= previousNames[i] and string.sub(loadedName, 1, 1) == " " then
                chunks[#chunks + 1] = string.sub(loadedName, 2)
            end
            SetPlayerName(Player(i), previousNames[i])
            i = i + 1
        end
        return table.concat(chunks)
    end

    local function readLocalProfileSegments(fileForSegment)
        local first = readLocalFile(fileForSegment(1))
        local index, total, payload = string.match(first, "^(%d+)|(%d+)|(.*)$")
        local chunks = {}
        local segment = 2

        index = tonumber(index)
        total = tonumber(total)
        if index == 1 and total and total >= 1 and total <= MAX_PROFILE_SEGMENTS then
            chunks[1] = payload
            while segment <= total do
                local content = readLocalFile(fileForSegment(segment))
                local currentIndex, currentTotal, currentPayload = string.match(content, "^(%d+)|(%d+)|(.*)$")

                if tonumber(currentIndex) ~= segment or tonumber(currentTotal) ~= total then
                    return ""
                end
                chunks[segment] = currentPayload
                segment = segment + 1
            end
            return table.concat(chunks)
        end

        return ""
    end

    local function readLocalProfile(player)
        local current = readLocalProfileSegments(function(segment)
            return profileFileFor(player, segment)
        end)

        if current ~= "" then
            return current
        end

        -- Load the old shared Season 1 file once, then the next save writes the
        -- same profile to the new BattleTag_Season1 filename.
        local previousSeason = readLocalProfileSegments(previousSeasonProfileFileFor)
        if previousSeason ~= "" then
            return previousSeason
        end

        if ALLOW_LEGACY_PROFILE_MIGRATION then
            return readLocalFile(LEGACY_PROFILE_FILE)
        end
        return ""
    end

    local function encodeProfile(player, profile)
        local name = normalizeName(player)
        local payload = serialize(profile)
        local encrypted = obfuscate(payload, name)

        return PROFILE_VERSION .. "|" .. hash(name) .. "|" .. hash(name .. "|" .. payload) .. "|" .. encrypted
    end

    local function decodeProfile(player, encoded)
        local version, nameHash, checksum, encrypted = string.match(encoded or "", "^([^|]+)|([^|]+)|([^|]+)|(.+)$")
        local name = normalizeName(player)
        local payload = nil

        if version ~= PROFILE_VERSION or nameHash ~= hash(name) then
            return nil
        end
        payload = deobfuscate(encrypted, name)
        if not payload or checksum ~= hash(name .. "|" .. payload) then
            return nil
        end
        return deserialize(payload .. "\n")
    end

    local function notifyLoaded(player, profile, loadedFromSave)
        local i = 1

        while i <= #loadCallbacks do
            loadCallbacks[i](player, profile, loadedFromSave == true)
            i = i + 1
        end
    end

    local function notifyProfilesSynchronized()
        local playerId = nil
        local i = 1

        if profilesSynchronized then
            return
        end
        for playerId in pairs(expectedProfileSyncs) do
            if not receivedProfileSyncs[playerId] and
                GetPlayerSlotState(Player(playerId)) == PLAYER_SLOT_STATE_PLAYING then
                return
            end
        end

        profilesSynchronized = true
        while i <= #profileSyncCallbacks do
            profileSyncCallbacks[i]()
            i = i + 1
        end
    end

    local function normalizeProfile(profile)
        local hadSeparateRatings = type(profile) == "table" and
            type(profile.rating) == "table" and
            type(profile.rating.titanElo) == "number" and
            type(profile.rating.builderElo) == "number"
        local legacyAura = type(profile) == "table" and
            type(profile.cosmetics) == "table" and
            type(profile.cosmetics.equipped) == "table" and
            type(profile.cosmetics.equipped.aura) == "string" and
            profile.cosmetics.equipped.aura or ""
        local legacyWings = type(profile) == "table" and
            type(profile.cosmetics) == "table" and
            type(profile.cosmetics.equipped) == "table" and
            type(profile.cosmetics.equipped.wings) == "string" and
            profile.cosmetics.equipped.wings or ""
        local legacySkin = type(profile) == "table" and
            type(profile.cosmetics) == "table" and
            type(profile.cosmetics.equipped) == "table" and
            type(profile.cosmetics.equipped.skin) == "string" and
            profile.cosmetics.equipped.skin or ""
        local result = copyDefaults(profile, defaultProfile())
        local oldRaceName = "Terminus"
        local newRaceName = "Granitacles"
        local oldTitanStats = result.stats.titanRaces[oldRaceName]
        local newTitanStats = result.stats.titanRaces[newRaceName]

        if not hadSeparateRatings then
            local legacyElo = tonumber(result.rating.elo) or GameSettings.getInt("PLAYER_PROFILE_ELO_DEFAULT")
            local legacyMatches = tonumber(result.rating.matches) or 0

            result.rating.titanElo = legacyElo
            result.rating.builderElo = legacyElo
            result.rating.titanMatches = result.stats.titan or legacyMatches
            result.rating.builderMatches = result.stats.builder or legacyMatches
        end
        result.rating.elo = nil
        result.rating.matches = nil
        if legacyAura ~= "" then
            result.cosmetics.equipped.aura[legacyAura] = true
        end
        if legacyWings ~= "" then
            result.cosmetics.equipped.wings[legacyWings] = true
        end
        -- Old profiles had one global skin. Keep it as a fallback entry until
        -- that player chooses a skin for a concrete race.
        if legacySkin ~= "" then
            result.cosmetics.equipped.skin["*"] = legacySkin
        end

        if type(result.stats.races[oldRaceName]) == "number" then
            result.stats.races[newRaceName] =
                (tonumber(result.stats.races[newRaceName]) or 0) + result.stats.races[oldRaceName]
            result.stats.races[oldRaceName] = nil
        end
        if type(oldTitanStats) == "table" then
            if type(newTitanStats) ~= "table" then
                newTitanStats = { games = 0, wins = 0, losses = 0 }
                result.stats.titanRaces[newRaceName] = newTitanStats
            end
            newTitanStats.games = (tonumber(newTitanStats.games) or 0) + (tonumber(oldTitanStats.games) or 0)
            newTitanStats.wins = (tonumber(newTitanStats.wins) or 0) + (tonumber(oldTitanStats.wins) or 0)
            newTitanStats.losses = (tonumber(newTitanStats.losses) or 0) + (tonumber(oldTitanStats.losses) or 0)
            result.stats.titanRaces[oldRaceName] = nil
        end
        if result.bans.titan[oldRaceName] then
            result.bans.titan[newRaceName] = true
            result.bans.titan[oldRaceName] = nil
        end
        return result
    end

    local function setProfile(player, profile, loadedFromSave)
        local id = GetPlayerId(player)

        profiles[id] = normalizeProfile(profile)
        notifyLoaded(player, profiles[id], loadedFromSave)
    end

    local function sendProfile(player, encoded)
        local id = GetPlayerId(player)
        local total = R2I((string.len(encoded) + SYNC_CHUNK_LENGTH - 1) / SYNC_CHUNK_LENGTH)
        local index = 1

        if not rawget(_G, "BlzSendSyncData") or string.len(encoded) > MAX_PROFILE_LENGTH or
            total < 1 or total > MAX_SYNC_CHUNKS then
            return
        end
        while index <= total do
            local offset = (index - 1) * SYNC_CHUNK_LENGTH + 1
            local chunk = string.sub(encoded, offset, offset + SYNC_CHUNK_LENGTH - 1)
            outgoingSyncQueue[#outgoingSyncQueue + 1] =
                I2S(id) .. "|" .. I2S(index) .. "|" .. I2S(total) .. "|" .. chunk
            index = index + 1
        end
    end

    local function receiveProfileChunk()
        local payload = BlzGetTriggerSyncData()
        local playerId, index, total, chunk = string.match(payload, "^(%d+)|(%d+)|(%d+)|(.*)$")
        local pending = nil
        local i = 1

        playerId = tonumber(playerId)
        index = tonumber(index)
        total = tonumber(total)
        if not playerId or not index or not total or
            playerId < 0 or playerId >= bj_MAX_PLAYER_SLOTS or
            total < 1 or total > MAX_SYNC_CHUNKS or
            index < 1 or index > total or
            string.len(chunk or "") > SYNC_CHUNK_LENGTH or
            GetPlayerId(GetTriggerPlayer()) ~= playerId then
            return
        end

        pending = pendingSyncs[playerId]
        if pending and pending.total ~= total then
            pendingSyncs[playerId] = nil
            return
        end
        pending = pending or { total = total, chunks = {} }
        pending.chunks[index] = chunk
        pendingSyncs[playerId] = pending
        while i <= total do
            if not pending.chunks[i] then
                return
            end
            i = i + 1
        end

        local encoded = table.concat(pending.chunks)
        if string.len(encoded) > MAX_PROFILE_LENGTH then
            pendingSyncs[playerId] = nil
            return
        end
        local player = Player(playerId)
        local profile = decodeProfile(player, encoded)
        pendingSyncs[playerId] = nil
        if profile then
            setProfile(player, profile, true)
            receivedProfileSyncs[playerId] = true
            notifyProfilesSynchronized()
        end
    end

    local function profileFor(value)
        local player = value

        if type(value) == "table" and value.player then
            player = value:player()
        end
        if not player then
            return nil
        end
        if not profiles[GetPlayerId(player)] then
            profiles[GetPlayerId(player)] = defaultProfile()
        end
        return profiles[GetPlayerId(player)]
    end

    local function roleFor(playerData)
        if playerData:class() == PlayerData.CLASS_TITAN then
            return "titan"
        elseif playerData:class() == PlayerData.CLASS_DEFENDER then
            return "builder"
        end
        return ""
    end

    local function recordRaceResult(profile, role, race, won)
        local key = role == "titan" and "titanRaces" or "builderRaces"
        local raceName = race:toString()
        local entry = profile.stats[key][raceName]

        if type(entry) ~= "table" then
            entry = { games = 0, wins = 0, losses = 0 }
            profile.stats[key][raceName] = entry
        end

        entry.games = (entry.games or 0) + 1
        if won then
            entry.wins = (entry.wins or 0) + 1
        else
            entry.losses = (entry.losses or 0) + 1
        end
    end

    local function averageRating(list, eloKey)
        local total = 0
        local i = 1

        if #list == 0 then
            return GameSettings.getInt("PLAYER_PROFILE_ELO_DEFAULT")
        end
        while i <= #list do
            total = total + profileFor(list[i]).rating[eloKey]
            i = i + 1
        end
        return total / #list
    end

    local function updateRating(team, opponentRating, won, eloKey, matchesKey)
        local score = won and 1.0 or 0.0
        local k = GameSettings.getInt("PLAYER_PROFILE_ELO_K")
        local i = 1

        while i <= #team do
            local profile = profileFor(team[i])
            local rating = profile.rating[eloKey]
            local expected = 1.0 / (1.0 + 10.0 ^ ((opponentRating - rating) / 400.0))
            local delta = R2I(k * (score - expected) + (score >= expected and 0.5 or -0.5))

            profile.rating[eloKey] = math.max(0, rating + delta)
            profile.rating[matchesKey] = (profile.rating[matchesKey] or 0) + 1
            i = i + 1
        end
    end

    local function clearPendingMatch(profile)
        profile.pendingMatch = {
            active = false,
            role = "",
            race = "",
            eloEligible = false,
            eloPenalty = 0
        }
    end

    local function pendingLossPenalty(rating, opponentRating)
        local k = GameSettings.getInt("PLAYER_PROFILE_ELO_K")
        local expected = 1.0 / (1.0 + 10.0 ^ ((opponentRating - rating) / 400.0))
        local delta = R2I(k * (0.0 - expected) - 0.5)

        return rating - math.max(0, rating + delta)
    end

    local function applyUnconcludedMatch(profile)
        local pending = profile.pendingMatch
        local role = pending and pending.active and pending.role or ""
        local raceName = pending and tostring(pending.race or "") or ""
        local eloPenalty = pending and math.max(0, tonumber(pending.eloPenalty) or 0) or 0
        local raceKey = role == "titan" and "titanRaces" or "builderRaces"
        local eloKey = role == "titan" and "titanElo" or "builderElo"
        local matchesKey = role == "titan" and "titanMatches" or "builderMatches"

        if role ~= "titan" and role ~= "builder" then
            return "", 0
        end

        clearPendingMatch(profile)
        profile.stats[role] = (profile.stats[role] or 0) + 1
        if raceName ~= "" then
            local entry = profile.stats[raceKey][raceName]

            profile.stats.races[raceName] = (profile.stats.races[raceName] or 0) + 1
            if type(entry) ~= "table" then
                entry = { games = 0, wins = 0, losses = 0 }
                profile.stats[raceKey][raceName] = entry
            end
            entry.games = (entry.games or 0) + 1
            entry.losses = (entry.losses or 0) + 1
        end
        if pending.eloEligible == true then
            profile.rating[eloKey] = math.max(0, profile.rating[eloKey] - eloPenalty)
            profile.rating[matchesKey] = (profile.rating[matchesKey] or 0) + 1
        end
        return role, eloPenalty
    end

    local function beginPendingMatch()
        local list = PlayerData.allReal()
        local titans = {}
        local builders = {}
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            local role = roleFor(playerData)

            if role == "titan" then
                titans[#titans + 1] = playerData
            elseif role == "builder" then
                builders[#builders + 1] = playerData
            end
            i = i + 1
        end

        local titanRating = averageRating(titans, "titanElo")
        local builderRating = averageRating(builders, "builderElo")
        i = 1
        while i <= #titans do
            local playerData = titans[i]
            local profile = profileFor(playerData)
            local race = playerData:race()

            profile.pendingMatch = {
                active = true,
                role = "titan",
                race = race and race ~= NullRace.instance() and race:toString() or "",
                eloEligible = eloMatchEligible,
                eloPenalty = eloMatchEligible and
                    pendingLossPenalty(profile.rating.titanElo, builderRating) or 0
            }
            i = i + 1
        end
        i = 1
        while i <= #builders do
            local playerData = builders[i]
            local profile = profileFor(playerData)
            local race = playerData:race()

            profile.pendingMatch = {
                active = true,
                role = "builder",
                race = race and race ~= NullRace.instance() and race:toString() or "",
                eloEligible = eloMatchEligible,
                eloPenalty = eloMatchEligible and
                    pendingLossPenalty(profile.rating.builderElo, titanRating) or 0
            }
            i = i + 1
        end
        list:destroy()
        PlayerProfile.saveAllPlayers()
    end

    local function clearActivePendingMatches()
        local list = PlayerData.allReal()
        local i = 0

        while i < list:size() do
            clearPendingMatch(profileFor(list:at(i)))
            i = i + 1
        end
        list:destroy()
    end

    function PlayerProfile.get(playerOrData)
        return profileFor(playerOrData)
    end

    function PlayerProfile.onLoaded(callback)
        loadCallbacks[#loadCallbacks + 1] = callback
    end

    function PlayerProfile.onSynchronized(callback)
        if not callback then
            return
        end
        profileSyncCallbacks[#profileSyncCallbacks + 1] = callback
        if profilesSynchronized then
            callback()
        end
    end

    function PlayerProfile.areProfilesSynchronized()
        -- A player who leaves during loading must not hold up Titan selection.
        notifyProfilesSynchronized()
        return profilesSynchronized
    end

    function PlayerProfile.loadAllPlayers()
        local list = PlayerData.allReal()
        local i = 0

        pendingSyncs = {}
        expectedProfileSyncs = {}
        receivedProfileSyncs = {}
        profilesSynchronized = false

        while i < list:size() do
            local player = list:at(i):player()
            local profile = defaultProfile()

            expectedProfileSyncs[GetPlayerId(player)] = true
            setProfile(player, profile, false)
            if GetLocalPlayer() == player then
                local saved = decodeProfile(player, readLocalProfile(player))
                if saved then
                    local role = ""
                    local eloPenalty = 0

                    saved = normalizeProfile(saved)
                    role, eloPenalty = applyUnconcludedMatch(saved)
                    setProfile(player, saved, true)
                    if role ~= "" then
                        writeLocalFile(player, encodeProfile(player, profileFor(player)))
                        DisplayTimedTextToPlayer(player, 0, 0, 12.0,
                            "|cffff6060Your previous " .. role ..
                            " match was not concluded. A loss" ..
                            (eloPenalty > 0 and " and " .. I2S(eloPenalty) .. " Elo penalty" or "") ..
                            " has been recorded.|r")
                    end
                end
                -- Every player sends a profile, including a fresh default one.
                -- That gives all clients a clear, finite synchronization barrier.
                sendProfile(player, encodeProfile(player, profileFor(player)))
            end
            i = i + 1
        end
        list:destroy()
        notifyProfilesSynchronized()
    end

    function PlayerProfile.saveAllPlayers()
        local player = GetLocalPlayer()
        local playerData = PlayerData.get(player)

        if playerData and not playerData:isFake() then
            return writeLocalFile(player, encodeProfile(player, profileFor(player)))
        end
        return false
    end

    -- Sends the local player's current profile to every client. This is used
    -- after runtime unlocks so later synchronized cosmetic actions see the
    -- same unlock state everywhere.
    function PlayerProfile.syncLocalProfile()
        local player = GetLocalPlayer()
        local playerData = PlayerData.get(player)

        if not playerData or playerData:isFake() then
            return false
        end
        sendProfile(player, encodeProfile(player, profileFor(player)))
        return true
    end

    function PlayerProfile.localSavePath()
        return profileFileFor(GetLocalPlayer(), 1)
    end

    function PlayerProfile.camera(playerOrData)
        return profileFor(playerOrData).camera
    end

    function PlayerProfile.graphics(playerOrData)
        return profileFor(playerOrData).graphics
    end

    function PlayerProfile.setScaledModels(playerOrData, enabled)
        PlayerProfile.graphics(playerOrData).scaledModels = enabled == true
    end

    function PlayerProfile.stats(playerOrData)
        return profileFor(playerOrData).stats
    end

    function PlayerProfile.rating(playerOrData)
        return profileFor(playerOrData).rating
    end

    function PlayerProfile.matchEloDelta(playerOrData, role)
        local playerData = playerOrData
        local startingElo = nil
        local rating = nil

        if type(playerData) ~= "table" or not playerData.id then
            playerData = playerOrData and PlayerData.get(playerOrData) or nil
        end
        if not playerData then
            return nil
        end

        startingElo = matchStartingElo[playerData:id()]
        rating = profileFor(playerData).rating
        if startingElo == nil then
            return nil
        end
        if role == PlayerData.CLASS_TITAN then
            return R2I((rating.titanElo or 0) - startingElo)
        elseif role == PlayerData.CLASS_DEFENDER then
            return R2I((rating.builderElo or 0) - startingElo)
        end
        return nil
    end

    function PlayerProfile.setCamera(playerOrData, distance, locked, smooth)
        local camera = PlayerProfile.camera(playerOrData)

        camera.distance = distance
        camera.locked = locked == true
        camera.smooth = smooth == true
    end

    function PlayerProfile.bans(playerOrData, role)
        local bans = profileFor(playerOrData).bans

        bans[role] = bans[role] or {}
        return bans[role]
    end

    function PlayerProfile.unlockCosmetic(playerOrData, cosmeticId)
        profileFor(playerOrData).cosmetics.unlocked[tostring(cosmeticId)] = true
    end

    function PlayerProfile.hasCosmetic(playerOrData, cosmeticId)
        return profileFor(playerOrData).cosmetics.unlocked[tostring(cosmeticId)] == true
    end

    function PlayerProfile.equippedCosmetic(playerOrData, category, raceName)
        local value = profileFor(playerOrData).cosmetics.equipped[category]

        if category == "skin" and type(value) == "table" and raceName then
            return value[tostring(raceName)] or value["*"] or ""
        end
        return value or ""
    end

    function PlayerProfile.setEquippedCosmetic(playerOrData, category, cosmeticId, raceName)
        local equipped = profileFor(playerOrData).cosmetics.equipped

        if (category == "aura" or category == "wings") and type(cosmeticId) == "table" then
            local selected = {}
            local ids = sortedKeys(cosmeticId)
            local index = 1

            while index <= #ids do
                local id = ids[index]
                if cosmeticId[id] == true then
                    selected[tostring(id)] = true
                end
                index = index + 1
            end
            equipped[category] = selected
        elseif category == "skin" and raceName then
            equipped.skin[tostring(raceName)] = tostring(cosmeticId or "")
        else
            equipped[category] = tostring(cosmeticId or "")
        end
    end

    function PlayerProfile.isEloMatchEligible()
        return eloMatchEligible
    end

    function PlayerProfile.isMatchResultRecorded()
        return matchResultRecorded
    end

    function PlayerProfile.recordBuilderLoss(builderData)
        local profile = profileFor(builderData)
        local race = builderData and builderData:race() or nil

        if matchResultRecorded or not profile or not builderData or
            builderData:class() ~= PlayerData.CLASS_DEFENDER then
            return false
        end

        profile.stats.builder = (profile.stats.builder or 0) + 1
        if race and race ~= NullRace.instance() then
            local raceName = race:toString()

            profile.stats.races[raceName] = (profile.stats.races[raceName] or 0) + 1
            recordRaceResult(profile, "builder", race, false)
        end

        clearPendingMatch(profile)
        PlayerProfile.saveAllPlayers()
        return true
    end

    local function eloWinDelta(winnerRating, loserRating, kFactor)
        local expected = 1.0 / (1.0 + 10.0 ^ ((loserRating - winnerRating) / 400.0))
        return math.max(1, R2I(kFactor * (1.0 - expected) + 0.5))
    end

    function PlayerProfile.recordBuilderDeath(killer, builderData)
        local builderProfile = profileFor(builderData)
        local builderPenalty = GameSettings.getInt("PLAYER_PROFILE_BUILDER_ELO_PER_DEATH")
        local killerData = killer and PlayerData.get(GetOwningPlayer(killer)) or nil

        if matchResultRecorded or not eloMatchEligible or not builderProfile or
            not builderData or builderData:class() ~= PlayerData.CLASS_DEFENDER then
            return
        end

        if killerData and (killerData:class() == PlayerData.CLASS_TITAN or killerData:class() == PlayerData.CLASS_MINION) then
            -- Former Builders keep their own Titan-side rating while playing a
            -- Minion. A Minion kill must not be credited to the Titan player.
            local titanProfile = profileFor(killerData)
            local kFactor = GameSettings.getInt("PLAYER_PROFILE_ELO_BUILDER_KILL_K")
            local delta = eloWinDelta(titanProfile.rating.titanElo, builderProfile.rating.builderElo, math.max(1, kFactor))

            titanProfile.rating.titanElo = titanProfile.rating.titanElo + delta
            builderProfile.rating.builderElo = math.max(0, builderProfile.rating.builderElo - delta)
        else
            builderProfile.rating.builderElo = math.max(0, builderProfile.rating.builderElo - math.max(0, builderPenalty))
        end

        -- Every client writes only its own profile, so the changed local rating
        -- is persisted immediately without serializing other players' profiles.
        PlayerProfile.saveAllPlayers()
    end

    function PlayerProfile.recordTitanSideDeath(killer, titanSideData)
        local killerData = killer and PlayerData.get(GetOwningPlayer(killer)) or nil
        local builderProfile = killerData and profileFor(killerData) or nil
        local titanProfile = profileFor(titanSideData)
        local kFactor = GameSettings.getInt("PLAYER_PROFILE_ELO_K")
        local delta = 0

        if matchResultRecorded or not eloMatchEligible or not killerData or
            killerData:class() ~= PlayerData.CLASS_DEFENDER or not titanProfile then
            return
        end
        if titanSideData:class() ~= PlayerData.CLASS_TITAN and titanSideData:class() ~= PlayerData.CLASS_MINION then
            return
        end

        delta = eloWinDelta(builderProfile.rating.builderElo, titanProfile.rating.titanElo, math.max(1, kFactor))
        if titanSideData:class() == PlayerData.CLASS_MINION then
            delta = math.max(1, R2I(delta / 2.0 + 0.5))
        end

        builderProfile.rating.builderElo = builderProfile.rating.builderElo + delta
        titanProfile.rating.titanElo = math.max(0, titanProfile.rating.titanElo - delta)
        PlayerProfile.saveAllPlayers()
    end

    function PlayerProfile.recordMatch(winner)
        local list = PlayerData.allReal()
        local titans = {}
        local builders = {}
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            local role = roleFor(playerData)
            local profile = profileFor(playerData)
            local race = playerData:race()

            if role == "titan" then
                profile.stats.titan = profile.stats.titan + 1
                if winner == "titan" then
                    profile.stats.winsTitan = profile.stats.winsTitan + 1
                end
                titans[#titans + 1] = playerData
            elseif role == "builder" then
                profile.stats.builder = profile.stats.builder + 1
                if winner == "defenders" then
                    profile.stats.winsBuilder = profile.stats.winsBuilder + 1
                end
                builders[#builders + 1] = playerData
            end

            if role ~= "" and playerData:isRandoming() then
                profile.stats.random = profile.stats.random + 1
            end
            if role ~= "" and race and race ~= NullRace.instance() then
                local raceName = race:toString()
                profile.stats.races[raceName] = (profile.stats.races[raceName] or 0) + 1
                recordRaceResult(profile, role, race,
                    (role == "titan" and winner == "titan") or (role == "builder" and winner == "defenders"))
            end
            i = i + 1
        end
        list:destroy()

        if eloMatchEligible and #titans > 0 and #builders > 0 then
            local titanRating = averageRating(titans, "titanElo")
            local builderRating = averageRating(builders, "builderElo")

            updateRating(titans, builderRating, winner == "titan", "titanElo", "titanMatches")
            updateRating(builders, titanRating, winner == "defenders", "builderElo", "builderMatches")
        end
    end

    local function onUnitDeath()
        local killer = GetKillingUnit()
        local dying = GetTriggerUnit()
        local targetData = dying and PlayerData.get(GetOwningPlayer(dying)) or nil

        if targetData and targetData:unit() == dying then
            PlayerProfile.recordTitanSideDeath(killer, targetData)
        end
    end

    local syncTrigger = CreateTrigger()
    local playerIndex = 0
    while playerIndex < bj_MAX_PLAYER_SLOTS do
        BlzTriggerRegisterPlayerSyncEvent(syncTrigger, Player(playerIndex), SYNC_PREFIX, false)
        playerIndex = playerIndex + 1
    end
    TriggerAddAction(syncTrigger, receiveProfileChunk)

    -- Created and kept alive identically on every client. Each client only
    -- queues its own payload, while the shared timer prevents a large burst of
    -- profile sync packets during the first game-initialization frame.
    GameTimer.every(0.03, function()
        local payload = outgoingSyncQueue[outgoingSyncHead]

        if payload then
            BlzSendSyncData(SYNC_PREFIX, payload)
            outgoingSyncHead = outgoingSyncHead + 1
        elseif outgoingSyncHead > 1 then
            outgoingSyncQueue = {}
            outgoingSyncHead = 1
        end
    end)

    local deathTrigger = CreateTrigger()
    playerIndex = 0
    while playerIndex < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(playerIndex), EVENT_PLAYER_UNIT_DEATH, nil)
        playerIndex = playerIndex + 1
    end
    TriggerAddAction(deathTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onUnitDeath)
        else
            onUnitDeath()
        end
    end)

    function PlayerProfile.captureEloMatchEligibility()
        local players = PlayerData.playingReal()
        local debugMode = GameSettings.getBool("DEBUG")
        local i = 0

        matchResultRecorded = false
        eloMatchEligible = players:size() == ELO_REQUIRED_PLAYERS and not debugMode
        matchStartingElo = {}
        if eloMatchEligible then
            while i < players:size() do
                local playerData = players:at(i)
                local profile = profileFor(playerData)
                local role = roleFor(playerData)

                if role == "titan" then
                    matchStartingElo[playerData:id()] = profile.rating.titanElo or 0
                elseif role == "builder" then
                    matchStartingElo[playerData:id()] = profile.rating.builderElo or 0
                end
                i = i + 1
            end
        end
        players:destroy()
        if eloMatchEligible then
            beginPendingMatch()
        else
            clearActivePendingMatches()
            PlayerProfile.saveAllPlayers()
        end
    end

    function PlayerProfile.finishMatch(winner)
        if winner == "titan" or winner == "defenders" then
            if matchResultRecorded then
                return false
            end
            matchResultRecorded = true
            PlayerProfile.recordMatch(winner)
            clearActivePendingMatches()
            PlayerProfile.saveAllPlayers()
            return true
        end
        PlayerProfile.saveAllPlayers()
        return false
    end

    _G.PlayerProfile = PlayerProfile
end)

-- The active WCT currently loads PlayerProfile before IslandDefenseSystem.
-- Delay only the Game callbacks until the map-init phase, while keeping the
-- PlayerProfile library available to earlier global initializers.
OnInit.map("PlayerProfileGameHooks", function(import)
    import.strict("PlayerProfile")
    import.strict("IslandDefenseSystem")

    Game.onFinish(PlayerProfile.finishMatch)
end)

if Debug and Debug.endFile then Debug.endFile() end
