if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/ArachnidStructureAbilities") end

OnInit("ArachnidStructureAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("DummyCaster")

    local IDS = {
        SPIDER_NEST_BUILDER = FourCC("h04P"),
        DUMMY_CASTER = FourCC("e01B"),
        ICY_WEBS_INFO = FourCC("A0LS"),
        ICY_WEBS_ACTIVE = FourCC("A0LX"),
        POISON_SPIT_INFO = FourCC("A0M9"),
        POISON_SPITTER_CURSE = FourCC("A0M7"),
        WEBWEAVER_NORMAL_GOLD = FourCC("h04Q"),
        WEBWEAVER_NORMAL_LUMBER = FourCC("h04X"),
        WEBWEAVER_ENHANCED = FourCC("h04R"),
        WEBWEAVER_SUPER = FourCC("h04S"),
        WEBWEAVER_MEGA = FourCC("h04T"),
        WEBWEAVER_MULTISHOT = FourCC("A03A"),
        WEBWEAVER_MULTISHOT_RESEARCH = FourCC("R04S")
    }
    local ICY_WEBS_ORDER = 852075
    local POISON_SPITTER_ORDER = 852190

    local function angleBetween(x1, y1, x2, y2)
        return bj_RADTODEG * Atan2(y2 - y1, x2 - x1)
    end

    local function poisonSpitChance(unit)
        local id = GetUnitTypeId(unit)
        if id == IDS.WEBWEAVER_NORMAL_GOLD or id == IDS.WEBWEAVER_NORMAL_LUMBER then
            return 0.54
        elseif id == IDS.WEBWEAVER_ENHANCED then
            return 0.61
        elseif id == IDS.WEBWEAVER_SUPER then
            return 0.68
        elseif id == IDS.WEBWEAVER_MEGA then
            return 0.75
        end
        return 0.0
    end

    local function onConstructStart()
        local unit = GetTriggerUnit()
        if unit and GetUnitTypeId(unit) == IDS.SPIDER_NEST_BUILDER then
            RemoveUnit(unit)
        end
    end

    local function castPoisonSpitter(attacker, target)
        DummyCaster.castTarget(
            GetOwningPlayer(attacker),
            IDS.POISON_SPITTER_CURSE,
            GetUnitAbilityLevel(attacker, IDS.POISON_SPIT_INFO),
            POISON_SPITTER_ORDER,
            target,
            GetUnitX(attacker),
            GetUnitY(attacker),
            angleBetween(GetUnitX(attacker), GetUnitY(attacker), GetUnitX(target), GetUnitY(target))
        )
    end

    local function updateWebweaverMultishot(attacker)
        local owner = GetOwningPlayer(attacker)
        local level = GetUnitAbilityLevel(attacker, IDS.WEBWEAVER_MULTISHOT)

        if GetPlayerTechCount(owner, IDS.WEBWEAVER_MULTISHOT_RESEARCH, true) <= 0 then
            return
        end

        if level >= 5 then
            SetUnitAbilityLevel(attacker, IDS.WEBWEAVER_MULTISHOT, 1)
        elseif level < 12 then
            IncUnitAbilityLevel(attacker, IDS.WEBWEAVER_MULTISHOT)
        end
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()

        if not target or not attacker then
            return
        end
        if BlzGetEventDamageType() ~= DAMAGE_TYPE_NORMAL then
            return
        end

        if GetUnitAbilityLevel(target, IDS.ICY_WEBS_INFO) > 0 and IsUnitEnemy(target, GetOwningPlayer(attacker)) then
            UnitAddAbility(target, IDS.ICY_WEBS_ACTIVE)
            SetUnitAbilityLevel(target, IDS.ICY_WEBS_ACTIVE, GetUnitAbilityLevel(target, IDS.ICY_WEBS_INFO))
            IssueTargetOrderById(target, ICY_WEBS_ORDER, attacker)
            UnitRemoveAbility(target, IDS.ICY_WEBS_ACTIVE)
        end

        if GetUnitAbilityLevel(attacker, IDS.POISON_SPIT_INFO) > 0 and IsUnitEnemy(target, GetOwningPlayer(attacker)) then
            local roll = GetRandomReal(0.0, 100.0)
            local chance = poisonSpitChance(attacker) * GetUnitAbilityLevel(attacker, IDS.POISON_SPIT_INFO)
            if chance > 100.0 then
                chance = 100.0
            end

            if roll <= chance then
                castPoisonSpitter(attacker, target)
            end

            updateWebweaverMultishot(attacker)
        end
    end

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_START, nil)
        i = i + 1
    end
    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onConstructStart)
        else
            onConstructStart()
        end
    end)

    local damageTrigger = CreateTrigger()
    i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        i = i + 1
    end
    TriggerAddAction(damageTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    AbilityRegistry.registerRace("Arachnid", "structures", {
        notes = "Arachnid tower/building/upgrade abilities ported from NestBuilder and IcyWebs.",
        abilities = {
            {
                name = "Nest Builder cleanup",
                id = IDS.SPIDER_NEST_BUILDER,
                source = "library NestBuilder",
                behavior = "Removes Spider Nest Builder units when construction starts."
            },
            {
                name = "Icy Webs",
                id = IDS.ICY_WEBS_INFO,
                source = "library IcyWebs",
                behavior = "When hit by enemy normal damage, temporarily casts the active Icy Webs ability at the attacker."
            },
            {
                name = "Poison Spit",
                id = IDS.POISON_SPIT_INFO,
                source = "library IcyWebs",
                behavior = "Webweaver attacks cast Poison Spitter Curse with old 0.54/0.61/0.68/0.75 tier-based chance against a 0-100 roll."
            },
            {
                name = "Webweaver Multishot ramp",
                id = IDS.WEBWEAVER_MULTISHOT,
                source = "library IcyWebs",
                behavior = "If R04S is researched, Webweaver multishot level ramps on attack and resets after level 5."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
