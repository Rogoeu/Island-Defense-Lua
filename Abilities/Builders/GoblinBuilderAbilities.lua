if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/GoblinBuilderAbilities") end

OnInit("GoblinBuilderAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Goblin", "builder", {
        notes = "Goblin builder/unit abilities. Port 1:1 from old JASS/Zinc here.",
        abilities = {}
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
