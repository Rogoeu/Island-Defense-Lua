if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/SatyrStructureAbilities") end

OnInit("SatyrStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Satyr", "structures", {
        notes = "Satyr tower/building/upgrade abilities. Port 1:1 from old JASS/Zinc here.",
        abilities = {}
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
