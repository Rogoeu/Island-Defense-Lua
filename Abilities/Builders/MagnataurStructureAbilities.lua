if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/MagnataurStructureAbilities") end

OnInit("MagnataurStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Magnataur", "structures", {
        notes = "Magnataur tower/building/upgrade abilities. Port 1:1 from old JASS/Zinc here.",
        abilities = {}
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
