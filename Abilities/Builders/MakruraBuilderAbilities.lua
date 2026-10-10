if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/MakruraBuilderAbilities") end

OnInit("MakruraBuilderAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Makrura", "builder", {
        notes = "Makrura has no custom builder ability trigger in the old MakruraRace library.",
        abilities = {}
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
