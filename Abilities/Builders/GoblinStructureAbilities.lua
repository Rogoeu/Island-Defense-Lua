if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/GoblinStructureAbilities") end

OnInit("GoblinStructureAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("PlayerData")
    import.strict("DebugCheatPack")

    local IDS = {
        GOBLIN_WORKER = FourCC("h051")
    }

    local GoblinStructureAbilities = {}

    local function isGoblinPlayer(player)
        local playerData = PlayerData.get(player)
        local race = playerData and playerData:race() or nil
        return race and race ~= NullRace.instance() and race:toString() == "Goblin"
    end

    function GoblinStructureAbilities.lockWorker(player)
        SetPlayerTechMaxAllowed(player, IDS.GOBLIN_WORKER, 0)
    end

    function GoblinStructureAbilities.unlockWorker(player)
        SetPlayerTechMaxAllowed(player, IDS.GOBLIN_WORKER, -1)
    end

    local function requireDebug(player)
        if DebugCheatPack.isEnabled(player) then
            return true
        end
        Command.say(player, "|cffff6060This command is only available in debug lobbies.|r")
        return false
    end

    if rawget(_G, "Command") then
        Command["-gobworker"].register(function(args)
            local player = args:player()
            if not requireDebug(player) then
                return
            end
            if isGoblinPlayer(player) then
                GoblinStructureAbilities.unlockWorker(player)
                Command.say(player, "|cff80ff80Goblin Workers unlocked for testing.|r")
            else
                Command.say(player, "|cffff6060You need to be Goblin to use this test unlock.|r")
            end
        end, "Debug: unlocks Goblin Workers.")
    end

    AbilityRegistry.registerRace("Goblin", "structures", {
        notes = "Goblin has no custom tower triggers in the old race library; Goblin Worker availability is tracked here.",
        abilities = {
            {
                name = "Goblin Worker lock",
                id = IDS.GOBLIN_WORKER,
                source = "old defender preparation tech lock",
                behavior = "h051 starts disabled. The later Goblin research port can call GoblinStructureAbilities.unlockWorker(player); -gobworker unlocks it in debug tests."
            }
        }
    })

    _G.GoblinStructureAbilities = GoblinStructureAbilities
end)

if Debug and Debug.endFile then Debug.endFile() end
