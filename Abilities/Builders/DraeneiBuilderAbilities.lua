if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/DraeneiBuilderAbilities") end

OnInit("DraeneiBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("RacePickSystem")
    import.strict("DummyCaster")
    import.strict("PlayerData")
    import.strict("GameTimer")

    local IDS = {
        DRAENEI = FourCC("u00W"),
        MANA_SHIELD_ORDER = 852589,
        MANA_TAP = FourCC("A0R6"),
        CRITTER_CLASSIFICATION = FourCC("CRIT"),
        MANA_LINK = FourCC("A0K0"),
        DRAENEI_HUNTER = FourCC("H040"),
        DRAENEI_HUNTER_ALT = FourCC("H03Z"),
        RECLAIM = FourCC("A03Y"),
        RECLAIM_DUMMY = FourCC("A042"),
        VOID_PORTAL = FourCC("A0DY"),
        VOID_PORTAL_DISABLE = FourCC("A0AM"),
        VOID_PORTAL_BUFF = FourCC("B05E"),
        VOID_PORTAL_INVULNERABLE = FourCC("INVU"),
        RESEARCH_CENTER = FourCC("e013"),
        ARCANE_AURA = FourCC("A0N5"),
        ARCANE_AURA_SOURCE = FourCC("A0DY"),
        WELL_OF_POWER_ITEM = FourCC("I056"),
        WELL_OF_POWER = FourCC("o02E"),
        WELL_OF_POWER_AURA = FourCC("A0E4"),
        DRAENEI_WELL_OF_POWER_AURA = FourCC("A0NC")
    }

    local VOID_PORTAL_FALLBACK_COOLDOWN = 30.0
    local ARCANE_AURA_MANA_BONUS = 180.0
    local voidPortals = {}
    local arcaneAuraBonusByUnit = {}

    local function maxMana(unit)
        if BlzGetUnitMaxMana then
            return BlzGetUnitMaxMana(unit)
        end
        return R2I(GetUnitState(unit, UNIT_STATE_MAX_MANA))
    end

    local function setMaxMana(unit, value)
        if BlzSetUnitMaxMana then
            BlzSetUnitMaxMana(unit, R2I(value))
        end
    end

    local function addMaxMana(unit, amount)
        local oldMax = maxMana(unit)
        local oldMana = GetUnitState(unit, UNIT_STATE_MANA)
        local newMax = oldMax + amount

        if newMax < 0 then
            newMax = 0
        end

        setMaxMana(unit, newMax)
        if amount > 0 then
            SetUnitState(unit, UNIT_STATE_MANA, oldMana + amount)
        elseif oldMana > newMax then
            SetUnitState(unit, UNIT_STATE_MANA, newMax)
        end
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

    local function isTitanSide(unit)
        local playerData = unit and PlayerData.get(GetOwningPlayer(unit)) or nil
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function itemCount(unit, itemId)
        local slot = 0
        local count = 0

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item and GetItemTypeId(item) == itemId then
                count = count + 1
            end
            slot = slot + 1
        end

        return count
    end

    local function findRandomResearchCenter(player)
        local group = CreateGroup()
        local unit = nil
        local centers = {}
        local i = 1

        GroupEnumUnitsOfPlayer(group, player, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if GetUnitTypeId(unit) == IDS.RESEARCH_CENTER and GetWidgetLife(unit) > 0.405 then
                centers[#centers + 1] = unit
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        if #centers == 0 then
            return nil
        end

        i = GetRandomInt(1, #centers)
        return centers[i]
    end

    local function abilityCooldown(unit, abilityId, fallback)
        local level = GetUnitAbilityLevel(unit, abilityId)
        local cooldown = 0.0

        if level <= 0 then
            level = 1
        end

        if BlzGetUnitAbilityCooldown then
            cooldown = BlzGetUnitAbilityCooldown(unit, abilityId, level - 1)
        elseif BlzGetAbilityCooldown then
            cooldown = BlzGetAbilityCooldown(abilityId, level - 1)
        end

        if cooldown and cooldown > 0.0 then
            return cooldown
        end
        return fallback
    end

    local function startAbilityCooldown(unit, abilityId, fallback)
        if BlzStartUnitAbilityCooldown then
            BlzStartUnitAbilityCooldown(unit, abilityId, abilityCooldown(unit, abilityId, fallback))
        end
    end

    local function finishVoidPortal(caster)
        local id = GetHandleId(caster)
        local data = voidPortals[id]
        local player = GetOwningPlayer(caster)
        local center = nil
        local x = 0.0
        local y = 0.0

        if not data then
            return
        end

        if GetWidgetLife(caster) > 0.405 then
            center = findRandomResearchCenter(player)
            if center then
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl", GetUnitX(caster), GetUnitY(caster)))
                x = GetUnitX(center)
                y = GetUnitY(center)
                SetUnitPosition(caster, x, y)
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl", x, y))
                if GetLocalPlayer() == player then
                    PanCameraToTimed(x, y, 0)
                end
            elseif rawget(_G, "Command") then
                Command.say(player, "|cffff6060Void Portal failed: no Research Center found.|r")
            end
        end

        UnitRemoveAbility(caster, IDS.VOID_PORTAL_BUFF)
        UnitRemoveAbility(caster, IDS.VOID_PORTAL_INVULNERABLE)
        SetUnitVertexColor(caster, 255, 255, 255, 255)
        PauseUnit(caster, false)
        SetUnitTimeScale(caster, 1.0)
        QueueUnitAnimation(caster, "stand")
        SetUnitState(caster, UNIT_STATE_MANA, data.mana)
        voidPortals[id] = nil
    end

    local function beginVoidPortal(caster)
        if not caster then
            return
        end

        voidPortals[GetHandleId(caster)] = {
            mana = GetUnitState(caster, UNIT_STATE_MANA)
        }

        startAbilityCooldown(caster, IDS.VOID_PORTAL, VOID_PORTAL_FALLBACK_COOLDOWN)
        UnitAddAbility(caster, IDS.VOID_PORTAL_INVULNERABLE)
        SetUnitVertexColor(caster, 255, 255, 255, 100)
        SetUnitAnimation(caster, "spell")

        DummyCaster.castTarget(
            GetOwningPlayer(caster),
            IDS.VOID_PORTAL_DISABLE,
            1,
            "cripple",
            caster,
            GetUnitX(caster),
            GetUnitY(caster),
            GetUnitFacing(caster),
            1.0
        )

        GameTimer.after(1.0, function()
            finishVoidPortal(caster)
        end)
    end

    local function onBuilderSpawn(playerData, unit)
        local race = playerData and playerData:race() or nil
        if unit and race and race:toString() == "Draenei" then
            IssueImmediateOrderById(unit, IDS.MANA_SHIELD_ORDER)
        end
    end

    local function onDeath()
        local hunter = GetKillingUnit()
        local target = GetDyingUnit()

        if not hunter or not target then
            return
        end

        if GetUnitAbilityLevel(hunter, IDS.MANA_TAP) > 0 and GetUnitAbilityLevel(target, IDS.CRITTER_CLASSIFICATION) > 0 then
            addMaxMana(hunter, 10)
            addMana(hunter, 25 + 25 * GetHeroLevel(hunter))
        end
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()
        local level = 0
        local amount = 0

        if BlzGetEventDamageType() ~= DAMAGE_TYPE_NORMAL then
            return
        end

        if not attacker or not target then
            return
        end

        if GetUnitTypeId(attacker) ~= IDS.DRAENEI_HUNTER and GetUnitTypeId(attacker) ~= IDS.DRAENEI_HUNTER_ALT then
            return
        end

        if not isTitanSide(target) or GetEventDamage() <= 25.0 then
            return
        end

        if GetUnitAbilityLevel(attacker, IDS.MANA_LINK) <= 0 then
            return
        end

        level = GetHeroLevel(attacker)
        amount = 10 + 5 * level
        addMana(attacker, amount)
        addMana(target, -amount)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()

        if GetSpellAbilityId() == IDS.RECLAIM then
            DummyCaster.castTarget(GetOwningPlayer(caster), IDS.RECLAIM_DUMMY, 1, "unsummon", caster, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(caster), 1.0)
        elseif GetSpellAbilityId() == IDS.VOID_PORTAL then
            beginVoidPortal(caster)
        end
    end

    local function onVoidPortalDamaged()
        local unit = GetTriggerUnit()
        local data = unit and voidPortals[GetHandleId(unit)] or nil

        if not data then
            return
        end

        if BlzSetEventDamage then
            BlzSetEventDamage(0.0)
        end
        SetUnitState(unit, UNIT_STATE_MANA, data.mana)
    end

    local function onPickup()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()
        local id = unit and GetHandleId(unit) or 0

        if not unit or not item or GetItemTypeId(item) ~= IDS.WELL_OF_POWER_ITEM then
            return
        end

        if itemCount(unit, IDS.WELL_OF_POWER_ITEM) >= 1 and not arcaneAuraBonusByUnit[id] and
            GetUnitAbilityLevel(unit, IDS.ARCANE_AURA_SOURCE) > 0 then
            addMaxMana(unit, ARCANE_AURA_MANA_BONUS)
            UnitAddAbility(unit, IDS.ARCANE_AURA)
            arcaneAuraBonusByUnit[id] = ARCANE_AURA_MANA_BONUS
        end
    end

    local function removeArcaneAuraIfNeeded(unit)
        local id = unit and GetHandleId(unit) or 0
        local bonus = arcaneAuraBonusByUnit[id]

        if not unit or not bonus or itemCount(unit, IDS.WELL_OF_POWER_ITEM) > 0 then
            return
        end

        addMaxMana(unit, -bonus)
        UnitRemoveAbility(unit, IDS.ARCANE_AURA)
        arcaneAuraBonusByUnit[id] = nil
    end

    local function onDrop()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if not unit or not item or GetItemTypeId(item) ~= IDS.WELL_OF_POWER_ITEM then
            return
        end

        -- The drop event can fire before Warcraft has removed the item from the inventory.
        GameTimer.after(0.0, function()
            if unit and GetUnitTypeId(unit) ~= 0 then
                removeArcaneAuraIfNeeded(unit)
            end
        end)
    end

    local function onConstructFinish()
        local building = GetConstructedStructure()
        local data = nil
        local race = nil

        if not building or GetUnitTypeId(building) ~= IDS.WELL_OF_POWER then
            return
        end

        if GetUnitAbilityLevel(building, IDS.WELL_OF_POWER_AURA) <= 0 then
            UnitAddAbility(building, IDS.WELL_OF_POWER_AURA)
        end

        data = PlayerData.get(GetOwningPlayer(building))
        race = data and data:race() or nil
        if race and race ~= NullRace.instance() and race:toString() == "Draenei" and
            GetUnitAbilityLevel(building, IDS.DRAENEI_WELL_OF_POWER_AURA) <= 0 then
            UnitAddAbility(building, IDS.DRAENEI_WELL_OF_POWER_AURA)
        end
    end

    RacePickSystem.onBuilderSpawn(onBuilderSpawn)

    local deathTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local spellTrigger = CreateTrigger()
    local pickupTrigger = CreateTrigger()
    local dropTrigger = CreateTrigger()
    local constructFinishTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(pickupTrigger, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
        TriggerRegisterPlayerUnitEvent(dropTrigger, Player(i), EVENT_PLAYER_UNIT_DROP_ITEM, nil)
        TriggerRegisterPlayerUnitEvent(constructFinishTrigger, Player(i), EVENT_PLAYER_UNIT_CONSTRUCT_FINISH, nil)
        i = i + 1
    end

    TriggerAddAction(deathTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDeath)
        else
            onDeath()
        end
    end)

    TriggerAddAction(damageTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(function()
                onVoidPortalDamaged()
                onDamaged()
            end)
        else
            onVoidPortalDamaged()
            onDamaged()
        end
    end)

    TriggerAddAction(spellTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    TriggerAddAction(pickupTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onPickup)
        else
            onPickup()
        end
    end)

    TriggerAddAction(dropTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDrop)
        else
            onDrop()
        end
    end)

    TriggerAddAction(constructFinishTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onConstructFinish)
        else
            onConstructFinish()
        end
    end)

    AbilityRegistry.registerRace("Draenei", "builder", {
        notes = "Draenei builder/hunter abilities ported from DraeneiRace, DraeneiManaTap, DraeneiManaLink, DraeneiReclaim and ArcaneAura.",
        abilities = {
            {
                name = "Mana Shield on spawn",
                source = "library DraeneiRace",
                behavior = "Issues the old mana shield order when the Draenei builder spawns."
            },
            {
                name = "Mana Tap",
                id = IDS.MANA_TAP,
                source = "library DraeneiManaTap",
                behavior = "Draenei hunter gains max/current mana when killing critters."
            },
            {
                name = "Mana Link",
                id = IDS.MANA_LINK,
                source = "library DraeneiManaLink",
                behavior = "Draenei hunter attacks against Titan-side units restore hunter mana and burn target mana."
            },
            {
                name = "Reclaim",
                id = IDS.RECLAIM,
                source = "library DraeneiReclaim",
                behavior = "Dummy-casts unsummon on the caster."
            },
            {
                name = "Void Portal",
                id = IDS.VOID_PORTAL,
                source = "library VoidGate",
                behavior = "After 1 second, teleports the Draenei to a random owned Research Center."
            },
            {
                name = "Arcane Aura",
                id = IDS.ARCANE_AURA,
                source = "library ArcaneAura",
                behavior = "Well of Power item grants 180 additional maximum mana (200 total with the item's 20 mana) and Arcane Aura while held."
            },
            {
                name = "Well of Power auras",
                id = IDS.WELL_OF_POWER,
                source = "Well of Power build completion",
                behavior = "Every Well of Power gains A0E4; Draenei-built ones additionally gain A0NC."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
