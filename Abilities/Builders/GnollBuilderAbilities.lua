if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/GnollBuilderAbilities") end

OnInit("GnollBuilderAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Gnoll", "builder", {
        notes = "Gnoll builder/unit abilities. Port 1:1 from old JASS/Zinc here.",
        abilities = {}
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
