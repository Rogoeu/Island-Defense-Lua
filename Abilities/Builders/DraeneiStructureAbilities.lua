if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/DraeneiStructureAbilities") end

OnInit("DraeneiStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Draenei", "structures", {
        notes = "No separate Draenei structure ability library is currently required. Arcane Aura belongs to the Draenei builder and Energy Charge belongs to Faerie.",
        abilities = {}
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
