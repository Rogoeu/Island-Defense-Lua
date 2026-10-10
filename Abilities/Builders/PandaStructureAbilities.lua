if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/PandaStructureAbilities") end

OnInit("PandaStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Panda", "structures", {
        notes = "Panda structure access is handled by RaceData and PandaBuilderAbilities form switching.",
        abilities = {
            {
                name = "Panda form structures",
                source = "library PandaRace/PandaTransformations",
                behavior = "Basic form enables o02S, Storm enables o02Y, Earth enables h03E/h02I, Fire enables o01Z."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
