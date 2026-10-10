if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/MurlocStructureAbilities") end

OnInit("MurlocStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    AbilityRegistry.registerRace("Murloc", "structures", {
        notes = "Murloc has no standalone structure trigger in the old code; race-specific tower access is handled through RaceData tech limits.",
        abilities = {
            {
                name = "Murloc ultimate tower access",
                source = "library MurlocRace",
                behavior = "Allows Tropical Glyph o006, Magic Pearl o007 and Sacred Seashell o005 via RaceData setupTech equivalents."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
