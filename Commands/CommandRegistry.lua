if Debug and Debug.beginFile then Debug.beginFile("Commands/CommandRegistry") end

OnInit("CommandRegistry", function()
    local registry = {}
    local registeredCommands = {}
    local anyPlayerTrigger = nil

    local function normalize(command)
        local stringTrim = rawget(_G, "StringTrim")

        command = tostring(command or "")
        if stringTrim then
            command = stringTrim(command)
        end
        return StringCase(command, false)
    end

    local function splitWords(text)
        local words = {}
        local current = ""
        local i = 0
        local len = StringLength(text or "")

        while i < len do
            local c = SubString(text, i, i + 1)
            if c == " " or c == "\t" then
                if current ~= "" then
                    words[#words + 1] = current
                    current = ""
                end
            else
                current = current .. c
            end
            i = i + 1
        end

        if current ~= "" then
            words[#words + 1] = current
        end

        return words
    end

    local Args = {}
    Args.__index = Args

    function Args.create(player, rawText, commandName, payload)
        local words = splitWords(payload)
        return setmetatable({
            playerValue = player,
            rawTextValue = rawText,
            commandValue = commandName,
            payloadValue = payload,
            words = words
        }, Args)
    end

    function Args:player()
        return self.playerValue
    end

    function Args:raw()
        return self.rawTextValue
    end

    function Args:command()
        return self.commandValue
    end

    function Args:payload()
        return self.payloadValue
    end

    function Args:count()
        return #self.words
    end

    function Args:at(index)
        return self.words[index + 1] or ""
    end

    function Args:joinedFrom(index)
        local result = ""
        local i = index + 1
        while i <= #self.words do
            if result ~= "" then
                result = result .. " "
            end
            result = result .. self.words[i]
            i = i + 1
        end
        return result
    end

    local function say(player, text)
        DisplayTimedTextToPlayer(player, 0, 0, 10, text)
    end

    local function dispatch()
        local player = GetTriggerPlayer()
        local text = GetEventPlayerChatString()
        local commandName = ""
        local payload = ""
        local stringIndexOf = rawget(_G, "StringIndexOf")
        local separator = stringIndexOf and stringIndexOf(text, " ", true) or -1

        if separator == -1 then
            commandName = text
        else
            commandName = SubString(text, 0, separator)
            payload = SubString(text, separator + 1, StringLength(text))
        end

        local command = registry[normalize(commandName)]
        if command then
            command.callback(Args.create(player, text, commandName, payload))
        end
    end

    local function ensureTrigger()
        if anyPlayerTrigger then
            return
        end

        anyPlayerTrigger = CreateTrigger()

        local i = 0
        while i < bj_MAX_PLAYER_SLOTS do
            TriggerRegisterPlayerChatEvent(anyPlayerTrigger, Player(i), "-", false)
            i = i + 1
        end

        TriggerAddAction(anyPlayerTrigger, function()
            local debugApi = rawget(_G, "Debug")
            if debugApi and debugApi.try then
                debugApi.try(dispatch)
            else
                dispatch()
            end
        end)
    end

    local commandApi = {}

    function commandApi.register(commandName, callback, description)
        return commandApi[commandName].register(callback, description)
    end

    function commandApi.exists(commandName)
        return registry[normalize(commandName)] ~= nil
    end

    function commandApi.say(player, text)
        say(player, text)
    end

    function commandApi.list()
        local list = {}
        for commandName in pairs(registry) do
            list[#list + 1] = commandName
        end
        table.sort(list)
        return list
    end

    function commandApi.Args()
        return Args
    end

    setmetatable(commandApi, {
        __index = function(_, commandName)
            local key = normalize(commandName)
            local entry = registeredCommands[key]
            if not entry then
                entry = {
                    name = tostring(commandName or ""),
                    normalized = key,
                    callback = nil,
                    description = ""
                }
                entry.register = function(callback, description)
                    entry.callback = callback
                    entry.description = description or entry.description or ""
                    registry[entry.normalized] = entry
                    ensureTrigger()
                    return entry
                end
                entry.run = function(args)
                    if entry.callback then
                        return entry.callback(args)
                    end
                    return nil
                end
                registeredCommands[key] = entry
            end
            return entry
        end
    })

    _G.Command = commandApi
end)

if Debug and Debug.endFile then Debug.endFile() end
