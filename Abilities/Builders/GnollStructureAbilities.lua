if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/GnollStructureAbilities") end

OnInit("GnollStructureAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("PlayerData")
    import.strict("DebugCheatPack")

    local IDS = {
        DEADLY_MEGA_AXE_TOWER = FourCC("o027")
    }

    local GnollStructureAbilities = {}

    local function isGnollPlayer(player)
        local playerData = PlayerData.get(player)
        local race = playerData and playerData:race() or nil
        return race and race ~= NullRace.instance() and race:toString() == "Gnoll"
    end

    function GnollStructureAbilities.lockDeadlyMegaAxe(player)
        SetPlayerTechMaxAllowed(player, IDS.DEADLY_MEGA_AXE_TOWER, 0)
    end

    function GnollStructureAbilities.unlockDeadlyMegaAxe(player)
        SetPlayerTechMaxAllowed(player, IDS.DEADLY_MEGA_AXE_TOWER, -1)
    end

    local function requireDebug(player)
        if DebugCheatPack.isEnabled(player) then
            return true
        end
        Command.say(player, "|cffff6060This command is only available in debug lobbies.|r")
        return false
    end

    if rawget(_G, "Command") then
        Command["-gnollaxe"].register(function(args)
            local player = args:player()
            if not requireDebug(player) then
                return
            end
            if isGnollPlayer(player) then
                GnollStructureAbilities.unlockDeadlyMegaAxe(player)
                Command.say(player, "|cff80ff80Deadly Mega Axe Towers unlocked for testing.|r")
            else
                Command.say(player, "|cffff6060You need to be Gnoll to use this test unlock.|r")
            end
        end, "Debug: unlocks Gnoll Deadly Mega Axe Towers.")
    end

    AbilityRegistry.registerRace("Gnoll", "structures", {
        notes = "Gnoll has no custom tower triggers in the old race library; Deadly Mega Axe Tower availability is tracked here.",
        abilities = {
            {
                name = "Deadly Mega Axe Tower lock",
                id = IDS.DEADLY_MEGA_AXE_TOWER,
                source = "old defender preparation tech lock",
                behavior = "o027 starts disabled. The later Gnoll research port can call GnollStructureAbilities.unlockDeadlyMegaAxe(player); -gnollaxe unlocks it in debug tests."
            }
        }
    })

    _G.GnollStructureAbilities = GnollStructureAbilities
end)

if Debug and Debug.endFile then Debug.endFile() end
