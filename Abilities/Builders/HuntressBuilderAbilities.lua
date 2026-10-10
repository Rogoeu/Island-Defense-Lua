if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/HuntressBuilderAbilities") end

OnInit("HuntressBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("RacePickSystem")
    import.strict("AbilityMeta")
    import.strict("GameTimer")

    local IDS = {
        HUNTRESS = FourCC("H05U"),
        HUNTRESS_ALLIANCE = FourCC("H05Z"),
        HUNTRESS_RANGED_FORM = FourCC("H05J"),
        HUNTRESS_SPECIAL_FORM = FourCC("H05S"),
        COMPANION_OWL = FourCC("H050"),
        COMPANION_WOLF = FourCC("H05W"),
        OLD_WALL = FourCC("h02K"),
        OWL_WALL = FourCC("h05V"),
        AZSHARA = FourCC("e01T"),
        WOLF_WALL = FourCC("h05X"),
        OWL_RESEARCH_CENTER = FourCC("e01F"),
        OWL_ADV_RESEARCH = FourCC("o041"),
        OWL_TOWER = FourCC("e01W"),
        OWL_ULTIMATE = FourCC("o00Z"),
        WOLF_RESEARCH_CENTER = FourCC("e01V"),
        WOLF_ADV_RESEARCH = FourCC("o04J"),
        WOLF_TECH = FourCC("R05N"),
        BUILD_STYLE_REFRESH = FourCC("A0FU"),
        SHADOWFADE = FourCC("A0RJ"),
        HUNTRESS_MARK = FourCC("A0SQ"),
        HUNTRESS_GRACE = FourCC("A0RQ"),
        HUNTRESS_GRACE_ATTACK_SPEED = FourCC("A0SJ"),
        HUNTRESS_GRACE_MAGIC_REDUCTION = FourCC("A0SK"),
        HUNTRESS_GRACE_RESEARCH = FourCC("R05H"),
        HEALING_SHOT_RESEARCH = FourCC("R04C"),
        HEALING_SHOT_BUFF = FourCC("B092"),
        WALL_CLASSIFICATION = FourCC("WALL"),
        VOODOO = FourCC("A0UH"),
        VOODOO_BUFF = FourCC("B097"),
        TITAN_CLASSIFICATION = FourCC("CTIT"),
        RANGED_MASTERY = FourCC("A0RN"),
        SEARING_ARROWS = FourCC("A0RM"),
        BURNING_ARROW = FourCC("A0RO"),
        STUNNING_SHOT = FourCC("A0RP"),
        BASH_SKILL = FourCC("A0UE"),
        BASH_EFFECT = FourCC("A0U8"),
        BASH_EFFECT_SECONDARY = FourCC("A0UC"),
        SPIRITUAL_CLEANSING = FourCC("A0RS"),
        TRUESHOT_AURA = FourCC("A0RL"),
        MULTISHOT = FourCC("A0T2"),
        SUMMON_OWL = FourCC("A0RE"),
        SUMMON_WOLF = FourCC("A0U2"),
        RECALL = FourCC("A0RF"),
        REVIVE = FourCC("A0RG"),
        OWL_BOOK = FourCC("A0RI"),
        WOLF_BOOK = FourCC("A0U1")
    }

    local FORM_OWL = 1
    local FORM_WOLF = 2
    local HUNTRESS_GRACE_MAX_LEVEL = 20
    local HUNTRESS_GRACE_DECAY_DELAY = 1.5
    local HUNTRESS_GRACE_DECAY_INTERVAL = 0.25
    local companionByHuntress = {}
    local formByHuntress = {}
    local graceState = {}
    local suppressVoodoo = false

    local PERMANENT_ABILITIES = {
        IDS.SHADOWFADE,
        IDS.HUNTRESS_MARK,
        IDS.HUNTRESS_GRACE,
        IDS.RANGED_MASTERY,
        IDS.SEARING_ARROWS,
        IDS.BURNING_ARROW,
        IDS.STUNNING_SHOT,
        IDS.SPIRITUAL_CLEANSING,
        IDS.TRUESHOT_AURA,
        IDS.MULTISHOT,
        IDS.SUMMON_OWL,
        IDS.RECALL,
        IDS.REVIVE,
        IDS.OWL_BOOK,
        IDS.WOLF_BOOK
    }

    local function isHuntressRace(playerData)
        local race = playerData and playerData:race() or nil
        return race and race ~= NullRace.instance() and race:toString() == "Huntress"
    end

    local function isHuntress(unit)
        local id = unit and GetUnitTypeId(unit) or 0
        return id == IDS.HUNTRESS or
            id == IDS.HUNTRESS_ALLIANCE or
            id == IDS.HUNTRESS_RANGED_FORM or
            id == IDS.HUNTRESS_SPECIAL_FORM
    end

    local function isCompanion(unit)
        local id = unit and GetUnitTypeId(unit) or 0
        return id == IDS.COMPANION_OWL or id == IDS.COMPANION_WOLF
    end

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 and
            not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function isHealingShotAttacker(unit)
        local id = unit and GetUnitTypeId(unit) or 0
        return id == IDS.HUNTRESS or id == IDS.HUNTRESS_RANGED_FORM or id == IDS.HUNTRESS_SPECIAL_FORM
    end

    local function findVoodooReceiver(owner)
        local group = CreateGroup()
        local unit = nil
        local receiver = nil

        GroupEnumUnitsOfPlayer(group, owner, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if not receiver and isAlive(unit) and GetUnitAbilityLevel(unit, IDS.VOODOO_BUFF) > 0 then
                receiver = unit
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return receiver
    end

    local function redirectVoodooDamage(target, attacker, damage)
        local receiver = findVoodooReceiver(GetOwningPlayer(target))
        local damageType = DAMAGE_TYPE_NORMAL
        local isAttack = true

        if not receiver then
            return false
        end
        if rawget(_G, "BlzGetEventDamageType") and BlzGetEventDamageType() == DAMAGE_TYPE_MAGIC then
            damageType = DAMAGE_TYPE_MAGIC
            isAttack = false
        end
        if rawget(_G, "BlzSetEventDamage") then
            BlzSetEventDamage(0.0)
        end

        GameTimer.after(0.10, function()
            if isAlive(receiver) and attacker and GetUnitTypeId(attacker) ~= 0 then
                suppressVoodoo = true
                UnitDamageTarget(
                    attacker,
                    receiver,
                    damage,
                    isAttack,
                    false,
                    ATTACK_TYPE_NORMAL,
                    damageType,
                    WEAPON_TYPE_WHOKNOWS
                )
                suppressVoodoo = false
            end
        end)
        return true
    end

    local function stopGraceTimers(state)
        if state.delayTimer then
            state.delayTimer:destroy()
            state.delayTimer = nil
        end
        if state.decayTimer then
            state.decayTimer:destroy()
            state.decayTimer = nil
        end
    end

    local function ensureGraceBonuses(huntress)
        if GetUnitAbilityLevel(huntress, IDS.HUNTRESS_GRACE_ATTACK_SPEED) <= 0 then
            UnitAddAbility(huntress, IDS.HUNTRESS_GRACE_ATTACK_SPEED)
        end
        if GetUnitAbilityLevel(huntress, IDS.HUNTRESS_GRACE_MAGIC_REDUCTION) <= 0 then
            UnitAddAbility(huntress, IDS.HUNTRESS_GRACE_MAGIC_REDUCTION)
        end
        UnitMakeAbilityPermanent(huntress, true, IDS.HUNTRESS_GRACE_ATTACK_SPEED)
        UnitMakeAbilityPermanent(huntress, true, IDS.HUNTRESS_GRACE_MAGIC_REDUCTION)
    end

    local function decayGraceStack(huntress, state)
        local attackSpeedLevel = GetUnitAbilityLevel(huntress, IDS.HUNTRESS_GRACE_ATTACK_SPEED)
        local magicReductionLevel = GetUnitAbilityLevel(huntress, IDS.HUNTRESS_GRACE_MAGIC_REDUCTION)

        if not isAlive(huntress) then
            stopGraceTimers(state)
            graceState[GetHandleId(huntress)] = nil
            return false
        end

        if attackSpeedLevel > 1 then
            SetUnitAbilityLevel(huntress, IDS.HUNTRESS_GRACE_ATTACK_SPEED, attackSpeedLevel - 1)
        end
        if magicReductionLevel > 1 then
            SetUnitAbilityLevel(huntress, IDS.HUNTRESS_GRACE_MAGIC_REDUCTION, magicReductionLevel - 1)
        end

        if attackSpeedLevel <= 2 and magicReductionLevel <= 2 then
            stopGraceTimers(state)
            return false
        end
        return true
    end

    local function addGraceStack(huntress)
        local id = GetHandleId(huntress)
        local state = graceState[id]
        local attackSpeedLevel = 0
        local magicReductionLevel = 0

        if not state then
            state = {}
            graceState[id] = state
        end

        ensureGraceBonuses(huntress)
        attackSpeedLevel = GetUnitAbilityLevel(huntress, IDS.HUNTRESS_GRACE_ATTACK_SPEED)
        magicReductionLevel = GetUnitAbilityLevel(huntress, IDS.HUNTRESS_GRACE_MAGIC_REDUCTION)
        if attackSpeedLevel < HUNTRESS_GRACE_MAX_LEVEL then
            SetUnitAbilityLevel(huntress, IDS.HUNTRESS_GRACE_ATTACK_SPEED, attackSpeedLevel + 1)
        end
        if magicReductionLevel < HUNTRESS_GRACE_MAX_LEVEL then
            SetUnitAbilityLevel(huntress, IDS.HUNTRESS_GRACE_MAGIC_REDUCTION, magicReductionLevel + 1)
        end

        stopGraceTimers(state)
        state.delayTimer = GameTimer.after(HUNTRESS_GRACE_DECAY_DELAY, function()
            state.delayTimer = nil
            if decayGraceStack(huntress, state) then
                state.decayTimer = GameTimer.every(HUNTRESS_GRACE_DECAY_INTERVAL, function()
                    decayGraceStack(huntress, state)
                end)
            end
        end)
    end

    local function setAbilityVisible(unit, abilityId, visible)
        if visible then
            UnitAddAbility(unit, abilityId)
            if BlzUnitDisableAbility then
                BlzUnitDisableAbility(unit, abilityId, false, false)
            end
        elseif BlzUnitDisableAbility then
            BlzUnitDisableAbility(unit, abilityId, true, true)
        else
            UnitRemoveAbility(unit, abilityId)
        end
    end

    local function setupStructures(player, form)
        if form == FORM_OWL then
            SetPlayerTechMaxAllowed(player, IDS.OWL_RESEARCH_CENTER, -1)
            SetPlayerTechMaxAllowed(player, IDS.OWL_ADV_RESEARCH, -1)
            SetPlayerTechMaxAllowed(player, IDS.OWL_ULTIMATE, -1)
            SetPlayerTechMaxAllowed(player, IDS.OWL_TOWER, -1)
            SetPlayerTechMaxAllowed(player, IDS.OWL_WALL, -1)
            SetPlayerTechMaxAllowed(player, IDS.AZSHARA, -1)
        elseif form == FORM_WOLF then
            SetPlayerTechMaxAllowed(player, IDS.OLD_WALL, 0)
            SetPlayerTechMaxAllowed(player, IDS.WOLF_WALL, -1)
            SetPlayerTechMaxAllowed(player, IDS.WOLF_RESEARCH_CENTER, -1)
            SetPlayerTechMaxAllowed(player, IDS.WOLF_ADV_RESEARCH, -1)
            SetPlayerTechResearched(player, IDS.WOLF_TECH, 1)
            SetPlayerTechMaxAllowed(player, IDS.OWL_ULTIMATE, -1)
        end
    end

    local function refreshBuildStyle(unit)
        UnitAddAbility(unit, IDS.BUILD_STYLE_REFRESH)
        UnitRemoveAbility(unit, IDS.BUILD_STYLE_REFRESH)
    end

    local function updateCompanionAbilities(huntress, mode)
        local form = formByHuntress[GetHandleId(huntress)] or 0

        if mode == "summoned" then
            UnitRemoveAbility(huntress, IDS.SUMMON_OWL)
            UnitRemoveAbility(huntress, IDS.SUMMON_WOLF)
            UnitRemoveAbility(huntress, IDS.REVIVE)
            UnitAddAbility(huntress, IDS.RECALL)
            if form == FORM_OWL then
                UnitAddAbility(huntress, IDS.OWL_BOOK)
                UnitRemoveAbility(huntress, IDS.WOLF_BOOK)
            elseif form == FORM_WOLF then
                UnitAddAbility(huntress, IDS.WOLF_BOOK)
                UnitRemoveAbility(huntress, IDS.OWL_BOOK)
            end
        elseif mode == "dead" then
            UnitRemoveAbility(huntress, IDS.RECALL)
            UnitAddAbility(huntress, IDS.REVIVE)
        elseif mode == "revived" then
            UnitRemoveAbility(huntress, IDS.REVIVE)
            UnitAddAbility(huntress, IDS.RECALL)
        end
    end

    local function assignCompanion(huntress, form)
        local player = GetOwningPlayer(huntress)
        local x = GetUnitX(huntress) + 100.0
        local y = GetUnitY(huntress)
        local id = IDS.COMPANION_OWL
        local companion = nil

        if form == FORM_WOLF then
            id = IDS.COMPANION_WOLF
        end

        companion = CreateUnit(player, id, x, y, 270)
        companionByHuntress[GetHandleId(huntress)] = companion
        formByHuntress[GetHandleId(huntress)] = form

        setupStructures(player, form)
        refreshBuildStyle(huntress)
        updateCompanionAbilities(huntress, "summoned")
    end

    local function findHuntressForCompanion(companion)
        local player = GetOwningPlayer(companion)
        local group = CreateGroup()
        local unit = nil
        local found = nil

        GroupEnumUnitsOfPlayer(group, player, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isHuntress(unit) and companionByHuntress[GetHandleId(unit)] == companion then
                found = unit
                unit = nil
            else
                unit = FirstOfGroup(group)
            end
        end

        DestroyGroup(group)
        return found
    end

    local function onBuilderSpawn(playerData, unit)
        if not unit or not isHuntressRace(playerData) then
            return
        end

        local i = 1
        while i <= #PERMANENT_ABILITIES do
            UnitMakeAbilityPermanent(unit, true, PERMANENT_ABILITIES[i])
            i = i + 1
        end
        ensureGraceBonuses(unit)

        UnitRemoveAbility(unit, IDS.RECALL)
        UnitRemoveAbility(unit, IDS.REVIVE)
        UnitRemoveAbility(unit, IDS.OWL_BOOK)
        UnitRemoveAbility(unit, IDS.WOLF_BOOK)
    end

    local function onSpellFinish()
        local huntress = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()
        local companion = companionByHuntress[GetHandleId(huntress)]

        if abilityId == IDS.SUMMON_OWL then
            assignCompanion(huntress, FORM_OWL)
        elseif abilityId == IDS.SUMMON_WOLF then
            assignCompanion(huntress, FORM_WOLF)
        elseif abilityId == IDS.REVIVE then
            if companion and IsUnitType(companion, UNIT_TYPE_DEAD) then
                ReviveHero(companion, GetUnitX(huntress) + 100.0, GetUnitY(huntress), false)
                updateCompanionAbilities(huntress, "revived")
            elseif rawget(_G, "Command") then
                Command.say(GetOwningPlayer(huntress), "|cffff6060Companion is not dead or cannot be found.|r")
            end
        elseif abilityId == IDS.RECALL then
            if isAlive(companion) then
                SetUnitPosition(companion, GetUnitX(huntress) + 100.0, GetUnitY(huntress))
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl", GetUnitX(companion), GetUnitY(companion)))
            elseif rawget(_G, "Command") then
                Command.say(GetOwningPlayer(huntress), "|cffff6060Companion is dead or cannot be found.|r")
            end
        end
    end

    local function onSpellEndcast()
        local abilityId = GetSpellAbilityId()
        if abilityId == IDS.RECALL or abilityId == IDS.REVIVE then
            AbilityMeta.startCooldown(GetTriggerUnit(), abilityId, 60.0)
        end
    end

    local function onDeath()
        local dead = GetTriggerUnit()
        local huntress = nil

        if not isCompanion(dead) then
            return
        end

        huntress = findHuntressForCompanion(dead)
        if huntress then
            updateCompanionAbilities(huntress, "dead")
        end
    end

    local function onHeroSkill()
        local unit = GetLearningUnit()
        local learned = GetLearnedSkill()
        local level = GetLearnedSkillLevel()

        if not unit or learned ~= IDS.BASH_SKILL then
            return
        end

        if GetUnitAbilityLevel(unit, IDS.BASH_EFFECT) == 0 then
            UnitAddAbility(unit, IDS.BASH_EFFECT)
            UnitMakeAbilityPermanent(unit, true, IDS.BASH_EFFECT)
            UnitAddAbility(unit, IDS.BASH_EFFECT_SECONDARY)
            UnitMakeAbilityPermanent(unit, true, IDS.BASH_EFFECT_SECONDARY)
        end
        if GetUnitAbilityLevel(unit, IDS.BASH_EFFECT) ~= level then
            SetUnitAbilityLevel(unit, IDS.BASH_EFFECT, level)
            SetUnitAbilityLevel(unit, IDS.BASH_EFFECT_SECONDARY, level)
        end
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local damage = GetEventDamage()

        if not attacker or GetUnitTypeId(attacker) == 0 or not target then
            return
        end
        if isHealingShotAttacker(attacker) and
            rawget(_G, "BlzGetEventDamageType") and BlzGetEventDamageType() == DAMAGE_TYPE_NORMAL and
            GetUnitAbilityLevel(target, IDS.WALL_CLASSIFICATION) > 0 and
            GetPlayerTechCount(GetOwningPlayer(attacker), IDS.HEALING_SHOT_RESEARCH, true) > 0 and
            GetUnitAbilityLevel(attacker, IDS.HEALING_SHOT_BUFF) > 0 and
            rawget(_G, "BlzSetEventDamage") then
            -- Exact Zinc behavior: the attack becomes healing equal to
            -- 20 times the Huntress unit level.
            BlzSetEventDamage(-20.0 * GetUnitLevel(attacker))
            return
        end
        if not suppressVoodoo and damage > 0.0 and GetUnitAbilityLevel(target, IDS.VOODOO) > 0 and
            redirectVoodooDamage(target, attacker, damage) then
            return
        end
        if not isHuntress(attacker) then
            return
        end
        if GetUnitAbilityLevel(attacker, IDS.HUNTRESS_GRACE) <= 0 or
            GetUnitAbilityLevel(target, IDS.TITAN_CLASSIFICATION) <= 0 or
            GetPlayerTechCount(GetOwningPlayer(attacker), IDS.HUNTRESS_GRACE_RESEARCH, true) <= 0 then
            return
        end
        if not rawget(_G, "BlzGetEventDamageType") or BlzGetEventDamageType() ~= DAMAGE_TYPE_NORMAL then
            return
        end

        addGraceStack(attacker)
    end

    RacePickSystem.onBuilderSpawn(onBuilderSpawn)

    local spellFinishTrigger = CreateTrigger()
    local spellEndTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local heroSkillTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellFinishTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(spellEndTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_ENDCAST, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(heroSkillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        i = i + 1
    end

    TriggerAddAction(spellFinishTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellFinish)
        else
            onSpellFinish()
        end
    end)

    TriggerAddAction(spellEndTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEndcast)
        else
            onSpellEndcast()
        end
    end)

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
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    TriggerAddAction(heroSkillTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onHeroSkill)
        else
            onHeroSkill()
        end
    end)

    AbilityRegistry.registerRace("Huntress", "builder", {
        notes = "Huntress builder/unit abilities ported from HuntressRace and HuntressCompanion.",
        abilities = {
            {
                name = "Huntress permanent abilities",
                source = "library HuntressRace",
                behavior = "Makes core Huntress combat and companion abilities permanent on spawn, with companion actions hidden until needed."
            },
            {
                name = "Huntress Companion",
                source = "library HuntressCompanion",
                behavior = "Summons Owl or Wolf companion, unlocks matching structures, supports Recall and Revive, and switches buttons on companion death."
            },
            {
                name = "Huntress Grace",
                id = IDS.HUNTRESS_GRACE,
                source = "library HuntressStacking",
                behavior = "Normal attacks against the Titan build attack-speed and magic-reduction stacks after R05H; stacks begin decaying after 1.5 seconds."
            },
            {
                name = "Huntress Voodoo",
                id = IDS.VOODOO,
                source = "library HuntressVoodoo",
                behavior = "Damage to a unit with A0UH is blocked and transferred after 0.10 seconds to the owner's first living unit with B097."
            },
            {
                name = "Huntress Healing Shot",
                source = "library HuntressHealingShot",
                behavior = "With R04C and B092 active, normal attacks heal WALL units for 20 times the Huntress level."
            },
            {
                name = "Sync Ability Bash",
                id = IDS.BASH_SKILL,
                source = "library SyncAbilitybash",
                behavior = "Learning A0UE adds permanent A0U8 and A0UC effects and synchronizes both effect levels with the learned skill."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
