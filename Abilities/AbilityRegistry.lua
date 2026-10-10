if Debug and Debug.beginFile then Debug.beginFile("Abilities/AbilityRegistry") end

OnInit("AbilityRegistry", function()
    local globals = {}
    local races = {}

    local AbilityRegistry = {}

    local function ensureRace(name)
        if not races[name] then
            races[name] = {}
        end
        return races[name]
    end

    function AbilityRegistry.registerGlobal(scope, data)
        globals[scope] = data or {}
        return globals[scope]
    end

    function AbilityRegistry.global(scope)
        return globals[scope]
    end

    function AbilityRegistry.registerRace(raceName, scope, data)
        local race = ensureRace(raceName)
        race[scope] = data or {}
        return race[scope]
    end

    function AbilityRegistry.race(raceName, scope)
        local race = races[raceName]
        if not race then
            return nil
        end
        return race[scope]
    end

    function AbilityRegistry.allRaces()
        return races
    end

    _G.AbilityRegistry = AbilityRegistry
end)

if Debug and Debug.endFile then Debug.endFile() end
