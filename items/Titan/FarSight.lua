if Debug and Debug.beginFile then Debug.beginFile("items/Titan/FarSight") end

OnInit("TitanItemFarSight", function(import)
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("AbilityMeta")

    local IDS = {
        PEARL_OF_GRAND_VISION = FourCC("I09K"),
        MYSTIC_STAFF_OF_GODS = FourCC("I01T"),
        FAR_SIGHT = FourCC("A0DQ"),
        FAR_SIGHT_GODS = FourCC("A0II"),
        TRUE_SIGHT = FourCC("A0C1")
    }

    local PEARL_AOE = 3000.0
    local MYSTIC_BASE_AOE = 3000.0
    local MYSTIC_INT_AOE = 25.0
    local REVEAL_DURATION = 12.5

    local TitanItemFarSight = {}

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function revealForPlayer(player, x, y, radius, duration)
        local fog = CreateFogModifierRadius(player, FOG_OF_WAR_VISIBLE, x, y, radius, true, true)

        FogModifierStart(fog)
        GameTimer.after(duration, function()
            FogModifierStop(fog)
            DestroyFogModifier(fog)
        end)
    end

    local function removeTrueSightTemporarily(item)
        if not item or not rawget(_G, "BlzItemRemoveAbility") or not rawget(_G, "BlzItemAddAbility") then
            return
        end

        BlzItemRemoveAbility(item, IDS.TRUE_SIGHT)
        GameTimer.after(2.0 * REVEAL_DURATION, function()
            if item then
                BlzItemAddAbility(item, IDS.TRUE_SIGHT)
            end
        end)
    end

    function TitanItemFarSight.castPearl(caster, x, y)
        AbilityMeta.setAreaOfEffect(caster, IDS.FAR_SIGHT, PEARL_AOE)
        revealForPlayer(GetOwningPlayer(caster), x, y, PEARL_AOE, REVEAL_DURATION)
    end

    function TitanItemFarSight.castMysticStaff(caster)
        local aoe = MYSTIC_BASE_AOE + MYSTIC_INT_AOE * GetHeroInt(caster, true)
        local item = ItemExtras.itemFromUnitById(caster, IDS.MYSTIC_STAFF_OF_GODS)

        AbilityMeta.setAreaOfEffect(caster, IDS.FAR_SIGHT_GODS, aoe)
        removeTrueSightTemporarily(item)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.FAR_SIGHT_GODS and hasItem(caster, IDS.MYSTIC_STAFF_OF_GODS) then
            TitanItemFarSight.castMysticStaff(caster)
        elseif abilityId == IDS.FAR_SIGHT and hasItem(caster, IDS.PEARL_OF_GRAND_VISION) then
            TitanItemFarSight.castPearl(caster, GetSpellTargetX(), GetSpellTargetY())
        end
    end

    local trigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    TitanItemFarSight.ids = IDS

    _G.TitanItemFarSight = TitanItemFarSight
end)

if Debug and Debug.endFile then Debug.endFile() end
