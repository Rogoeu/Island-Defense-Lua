if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/SatyrBuilderAbilities") end

OnInit("SatyrBuilderAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Satyr", "builder", {
        notes = "Satyr builder/unit abilities. Port 1:1 from old JASS/Zinc here.",
        abilities = {}
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
