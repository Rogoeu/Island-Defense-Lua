if Debug and Debug.beginFile then Debug.beginFile("items/Titan/ShadowWalk") end

OnInit("TitanItemShadowWalk", function(import)
    import.strict("AbilityMeta")
    import.strict("DummyCaster")
    import.strict("ItemExtras")

    local IDS = {
        STORMRIDERS_CLOAK = FourCC("I09Z"),
        MISTLORDS_CAPE = FourCC("I092"),
        STORMRIDER = FourCC("A06I"),
        SHADOW_SHARD = FourCC("A0EI"),
        SHADOW_SHARD_DUMMY = FourCC("A0DT")
    }

    local ORDER_WIND_WALK = 852066
    local STORMRIDER_BASE_DURATION = 15.0
    local STORMRIDER_LEVEL_RATIO = 1.0
    local MISTLORD_BASE_DURATION = 20.0
    local MISTLORD_LEVEL_RATIO = 2.0

    local TitanItemShadowWalk = {}

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function onSpellCast()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.STORMRIDER then
            if hasItem(caster, IDS.STORMRIDERS_CLOAK) then
                AbilityMeta.setDuration(caster, IDS.STORMRIDER,
                    STORMRIDER_BASE_DURATION + STORMRIDER_LEVEL_RATIO * GetHeroLevel(caster))
            elseif hasItem(caster, IDS.MISTLORDS_CAPE) then
                AbilityMeta.setDuration(caster, IDS.STORMRIDER,
                    MISTLORD_BASE_DURATION + MISTLORD_LEVEL_RATIO * GetHeroLevel(caster))
            end
        elseif abilityId == IDS.SHADOW_SHARD and hasItem(caster, IDS.MISTLORDS_CAPE) then
            -- Matches the old Shadowwalk library: Shadow Shard applies its
            -- invisibility through the dedicated dummy ability, not by removing
            -- the item-granted spell from the caster.
            DummyCaster.castTarget(GetOwningPlayer(caster), IDS.SHADOW_SHARD_DUMMY,
                1, ORDER_WIND_WALK, caster, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(caster), 1.0)
        end
    end

    local trigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_SPELL_CAST, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellCast)
        else
            onSpellCast()
        end
    end)

    TitanItemShadowWalk.ids = IDS

    _G.TitanItemShadowWalk = TitanItemShadowWalk
end)

if Debug and Debug.endFile then Debug.endFile() end
