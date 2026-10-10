if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/ZerglingBuilderAbilities") end

OnInit("ZerglingBuilderAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Zergling", "builder", {
        notes = "The old Zergling race library has no standalone builder trigger; Zergling-specific gameplay is handled by RaceData and ZerglingStructureAbilities.",
        abilities = {
            {
                name = "Zergling race setup",
                source = "library ZerglingRace",
                behavior = "RaceData enables Crab Mutant, Giant Hermit and Replicator ultimate towers and registers Zergling hunter IDs H057/H05L."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
