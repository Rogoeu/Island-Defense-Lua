if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/HuntressStructureAbilities") end

OnInit("HuntressStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Huntress", "structures", {
        notes = "Huntress tower/building/upgrade abilities. Port 1:1 from old JASS/Zinc here.",
        abilities = {}
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
