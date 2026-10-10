if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/DemonologistBuilderAbilities") end

OnInit("DemonologistBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("RacePickSystem")
    import.strict("GameTimer")
    import.strict("DummyCaster")
    import.strict("HunterSystem")
    import.strict("PlayerData")
    import.strict("UnitFilter")

    local IDS = {
        DEMONOLOGIST = FourCC("u00I"),
        DEMONOLOGIST_ENHANCED = FourCC("u00N"),
        DEMONOLOGIST_FIEND = FourCC("e010"),
        DEMONOLOGIST_SKINS = {
            FourCC("S01G"), -- Demon Reaper
            FourCC("S01S"), -- Ahriman
            FourCC("S020"), -- Zarah
            FourCC("S01U"), -- Kael
            FourCC("S01Z")  -- Puppet Master
        },
        SACRIFICE = FourCC("A05P"),
        SACRIFICE_DEMON = FourCC("u00K"),
        SELF_SACRIFICE = FourCC("A0BJ"),
        SELF_SACRIFICE_BUFF = FourCC("S00F"),
        NETHER_JUMP = FourCC("A0BL"),
        NETHER_JUMP_DUMMY = FourCC("A0BM"),
        NETHER_WARP = FourCC("A0DN"),
        NETHER_WARP_MARK = FourCC("h02C"),
        NETHER_WARP_BANISH = FourCC("A05H"),
        ENCHANTMENT = FourCC("A0GT"),
        ENCHANTMENT_LOW_ITEM = FourCC("I01D"),
        ENCHANTMENT_HIGH_ITEM = FourCC("I03V"),
        BALTHASAR = FourCC("A02N"),
        BALTHASAR_UNIT = FourCC("U00S"),
        SPELLBOOK_ABILITIES = {
            FourCC("A05P"),
            FourCC("A074"),
            FourCC("A07A"),
            FourCC("A07D"),
            FourCC("A07R"),
            FourCC("A07Q"),
            FourCC("A07P"),
            FourCC("A0GT"),
            FourCC("A07S"),
            FourCC("A07T"),
            FourCC("A02N")
        }
    }

    local WARP_POINTS = {
        { -500.0, -700.0 },
        { 3600.0, -6200.0 },
        { -8600.0, -3600.0 },
        { -750.0, -6000.0 },
        { 3500.0, 5000.0 },
        { 8500.0, 3800.0 },
        { -7800.0, 6800.0 },
        { -3600.0, -8800.0 },
        { -3100.0, 800.0 },
        { 1800.0, 2200.0 },
        { 9000.0, -6000.0 },
        { 3770.0, 2000.0 },
        { 5376.0, 5888.0 },
        { -2688.0, 8192.0 }
    }

    local balthasarByPlayer = {}

    local function isDemonologist(unit)
        local id = unit and GetUnitTypeId(unit) or 0
        if id == 0 then
            return false
        end
        if id == IDS.DEMONOLOGIST or id == IDS.DEMONOLOGIST_ENHANCED or id == IDS.DEMONOLOGIST_FIEND then
            return true
        end

        -- Legacy cosmetic abilities can morph the gameplay unit type. Recognize
        -- every registered Demonologist skin by its permanent skin ability.
        for i = 1, #IDS.DEMONOLOGIST_SKINS do
            if GetUnitAbilityLevel(unit, IDS.DEMONOLOGIST_SKINS[i]) > 0 then
                return true
            end
        end

        -- Main-unit identity also covers future skins without another rawcode
        -- whitelist update. Other units owned by a Demonologist do not qualify.
        local data = PlayerData.mainUnitData(unit)
        local race = data and data:race() or nil
        return UnitFilter.isDefenderMain(unit) and race ~= nil and race:toString() == "Demonologist"
    end

    local function makePermanent(unit, abilityId)
        if GetUnitAbilityLevel(unit, abilityId) > 0 then
            UnitMakeAbilityPermanent(unit, true, abilityId)
        end
    end

    local function isDefenderMain(unit)
        return UnitFilter.isDefenderMain(unit)
    end

    local function distanceSquared(x1, y1, x2, y2)
        local dx = x2 - x1
        local dy = y2 - y1
        return dx * dx + dy * dy
    end

    local function findWarpMark(player)
        local group = CreateGroup()
        local unit = nil
        local found = nil

        GroupEnumUnitsOfPlayer(group, player, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if GetUnitTypeId(unit) == IDS.NETHER_WARP_MARK and GetWidgetLife(unit) > 0.405 then
                found = unit
                unit = nil
            else
                unit = FirstOfGroup(group)
            end
        end

        DestroyGroup(group)
        return found
    end

    local function randomWarpPointAwayFrom(x, y)
        local closest = 1
        local closestDistance = -1.0
        local i = 1

        while i <= #WARP_POINTS do
            local point = WARP_POINTS[i]
            local dist = distanceSquared(x, y, point[1], point[2])
            if closestDistance < 0.0 or dist < closestDistance then
                closest = i
                closestDistance = dist
            end
            i = i + 1
        end

        local chosen = closest
        while chosen == closest and #WARP_POINTS > 1 do
            chosen = GetRandomInt(1, #WARP_POINTS)
        end

        return WARP_POINTS[chosen][1], WARP_POINTS[chosen][2]
    end

    local function sacrifice(caster, target)
        local owner = GetOwningPlayer(caster)
        local x = GetUnitX(target)
        local y = GetUnitY(target)
        local selected = IsUnitSelected(target, owner)
        local demon = nil

        if isDefenderMain(target) then
            return
        end

        demon = ReplaceUnitBJ(target, IDS.SACRIFICE_DEMON, bj_UNIT_STATE_METHOD_MAXIMUM)
        if not demon then
            return
        end

        UnitRemoveBuffsEx(demon, false, false, false, false, true, false, false)
        UnitApplyTimedLife(demon, FourCC("BTLF"), 15.0)
        SetUnitOwner(demon, owner, true)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", demon, "origin"))

        if selected then
            SelectUnitAddForPlayer(demon, owner)
        end
    end

    local function selfSacrifice(caster)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)

        UnitAddAbility(caster, IDS.SELF_SACRIFICE_BUFF)
        UnitApplyTimedLife(caster, FourCC("BTLF"), 8.0)
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", x, y))
    end

    local function netherJump(caster, target)
        DummyCaster.castPoint(
            GetOwningPlayer(caster),
            IDS.NETHER_JUMP_DUMMY,
            1,
            "darksummoning",
            GetUnitX(caster),
            GetUnitY(caster),
            GetUnitX(target),
            GetUnitY(target),
            GetUnitFacing(caster),
            1.0
        )
    end

    local function netherWarp(caster)
        local player = GetOwningPlayer(caster)

        DummyCaster.castTarget(player, IDS.NETHER_WARP_BANISH, 1, "banish", caster, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(caster), 3.0)

        GameTimer.after(1.0, function()
            local mark = findWarpMark(player)
            local x = 0.0
            local y = 0.0

            if not caster or GetWidgetLife(caster) <= 0.405 then
                return
            end

            if mark then
                x = GetUnitX(mark)
                y = GetUnitY(mark)
                KillUnit(mark)
            else
                x, y = randomWarpPointAwayFrom(GetUnitX(caster), GetUnitY(caster))
            end

            SetUnitPosition(caster, x, y)
            if GetLocalPlayer() == player then
                PanCameraToTimed(x, y, 0)
            end
        end)
    end

    local function enchantment(caster)
        local itemId = IDS.ENCHANTMENT_LOW_ITEM
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)

        if GetUnitAbilityLevel(caster, IDS.ENCHANTMENT) > 1 then
            itemId = IDS.ENCHANTMENT_HIGH_ITEM
        end

        UnitAddItem(caster, CreateItem(itemId, x, y))
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\Unsummon\\UnsummonTarget.mdl", x, y))
    end

    local function spawnBalthasar(caster)
        local player = GetOwningPlayer(caster)
        local id = GetPlayerId(player)
        local facing = GetUnitFacing(caster)
        local x = GetUnitX(caster) + 150.0 * Cos(facing * bj_DEGTORAD)
        local y = GetUnitY(caster) + 150.0 * Sin(facing * bj_DEGTORAD)
        local balthasar = balthasarByPlayer[id]

        if balthasar and GetUnitTypeId(balthasar) ~= 0 then
            if GetWidgetLife(balthasar) > 0.405 then
                KillUnit(balthasar)
            end
            ReviveHero(balthasar, x, y, false)
        else
            balthasar = CreateUnit(player, IDS.BALTHASAR_UNIT, x, y, facing)
            balthasarByPlayer[id] = balthasar
        end

        SetUnitFacing(balthasar, facing)
        UnitApplyTimedLife(balthasar, FourCC("BTLF"), 45.0)
        HunterSystem.register(balthasar, "spawn")
        return balthasar
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        -- Self Sacrifice belongs to a Demonologist-created unit, not the builder itself.
        if caster and abilityId == IDS.SELF_SACRIFICE then
            selfSacrifice(caster)
            return
        end

        if not caster or not isDemonologist(caster) then
            return
        end

        if abilityId == IDS.SACRIFICE then
            local target = GetSpellTargetUnit()
            if target then
                sacrifice(caster, target)
            end
        elseif abilityId == IDS.NETHER_JUMP then
            local target = GetSpellTargetUnit()
            if target then
                netherJump(caster, target)
            end
        elseif abilityId == IDS.NETHER_WARP then
            netherWarp(caster)
        elseif abilityId == IDS.ENCHANTMENT then
            enchantment(caster)
        elseif abilityId == IDS.BALTHASAR then
            spawnBalthasar(caster)
        end
    end

    RacePickSystem.onBuilderSpawn(function(playerData, unit)
        local race = playerData:race()
        local i = 1

        if not unit or not race or race:toString() ~= "Demonologist" then
            return
        end

        while i <= #IDS.SPELLBOOK_ABILITIES do
            makePermanent(unit, IDS.SPELLBOOK_ABILITIES[i])
            i = i + 1
        end
    end)

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

    AbilityRegistry.registerRace("Demonologist", "builder", {
        notes = "Demonologist builder/unit abilities ported from DemonologistRace, DemonologistBalthasar, SelfSacrifice, NetherJump, Sacrifice, Enchantment and NetherWarp.",
        abilities = {
            {
                name = "Demonologist permanent spellbook abilities",
                source = "library DemonologistRace",
                behavior = "Makes the old Demonologist spellbook/escape abilities permanent when the builder spawns."
            },
            {
                name = "Sacrifice",
                id = IDS.SACRIFICE,
                source = "library Sacrifice",
                behavior = "Transforms a non-defender target into a temporary demon for 15 seconds."
            },
            {
                name = "Self Sacrifice",
                id = IDS.SELF_SACRIFICE,
                source = "library SelfSacrifice",
                behavior = "Adds the legacy self-sacrifice ability, then destroys the caster after 8 seconds."
            },
            {
                name = "Nether Jump",
                id = IDS.NETHER_JUMP,
                source = "library NetherJump",
                behavior = "Uses a dummy darksummoning cast from target to caster."
            },
            {
                name = "Nether Warp",
                id = IDS.NETHER_WARP,
                source = "library NetherWarp",
                behavior = "Banishes the caster, then warps to an active mark or a random power-node position after 1 second."
            },
            {
                name = "Enchantment",
                id = IDS.ENCHANTMENT,
                source = "library Enchantment",
                behavior = "Creates the old Demonologist enchantment item at the caster."
            },
            {
                name = "Balthasar",
                id = IDS.BALTHASAR,
                source = "library DemonologistBalthasar",
                behavior = "Creates or revives Balthasar for 45 seconds and registers it with HunterSystem."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
