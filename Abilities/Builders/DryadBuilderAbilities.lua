if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/DryadBuilderAbilities") end

OnInit("DryadBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("AbilityMeta")

    local IDS = {
        MANA_BOMB = FourCC("A0J5"),
        MAGIC_REACTION = FourCC("A0J6"),
        MAGIC_REACTION_ACTIVE = FourCC("A0J7")
    }

    local magicReactionTimers = {}

    local function maxMana(unit)
        if BlzGetUnitMaxMana then
            return BlzGetUnitMaxMana(unit)
        end
        return R2I(GetUnitState(unit, UNIT_STATE_MAX_MANA))
    end

    local function addMana(unit, amount)
        local mana = GetUnitState(unit, UNIT_STATE_MANA) + amount
        local cap = maxMana(unit)

        if mana < 0 then
            mana = 0
        elseif mana > cap then
            mana = cap
        end

        SetUnitState(unit, UNIT_STATE_MANA, mana)
    end

    local function removeMagicReaction(unit)
        if unit and GetUnitTypeId(unit) ~= 0 then
            UnitRemoveAbility(unit, IDS.MAGIC_REACTION_ACTIVE)
        end
        if unit then
            magicReactionTimers[GetHandleId(unit)] = nil
        end
    end

    local function refreshMagicReaction(unit)
        local id = GetHandleId(unit)
        local existing = magicReactionTimers[id]

        if existing then
            existing:destroy()
        end

        if GetUnitAbilityLevel(unit, IDS.MAGIC_REACTION_ACTIVE) <= 0 then
            UnitAddAbility(unit, IDS.MAGIC_REACTION_ACTIVE)
        end

        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", unit, "origin"))
        magicReactionTimers[id] = GameTimer.after(1.0, function()
            removeMagicReaction(unit)
        end)
    end

    local function onSpellEffect()
        local hunter = GetTriggerUnit()
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local level = GetHeroLevel(hunter)
        local range = 150.0 * level
        local mana = 30 * level
        local owner = GetOwningPlayer(hunter)
        local group = nil
        local unit = nil

        if GetSpellAbilityId() ~= IDS.MANA_BOMB then
            return
        end

        AbilityMeta.setAreaOfEffect(hunter, IDS.MANA_BOMB, range)
        group = CreateGroup()
        GroupEnumUnitsInRange(group, targetX, targetY, range, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if GetOwningPlayer(unit) == owner and GetWidgetLife(unit) > 0.405 then
                addMana(unit, mana)
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\NightElf\\MoonWell\\MoonWellCasterArt.mdl", GetUnitX(unit), GetUnitY(unit)))
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function onDamaged()
        local unit = GetTriggerUnit()

        if not unit or BlzGetEventDamageType() ~= DAMAGE_TYPE_MAGIC then
            return
        end

        if GetUnitAbilityLevel(unit, IDS.MAGIC_REACTION) > 0 then
            refreshMagicReaction(unit)
        end
    end

    local spellTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        i = i + 1
    end

    TriggerAddAction(spellTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    TriggerAddAction(damageTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    AbilityRegistry.registerRace("Dryad", "builder", {
        notes = "Dryad builder/hunter abilities ported from TitanHunterDryad.",
        abilities = {
            {
                name = "Mana Bomb",
                id = IDS.MANA_BOMB,
                source = "library TitanHunterDryad",
                behavior = "Restores mana to allied units in an area scaling with Dryad hunter hero level."
            },
            {
                name = "Magic Reaction",
                id = IDS.MAGIC_REACTION,
                source = "library TitanHunterDryad",
                behavior = "When damaged by magic, temporarily grants A0J7 for 1 second and refreshes if triggered again."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
