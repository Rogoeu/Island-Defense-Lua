if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/NatureStructureAbilities") end

OnInit("NatureStructureAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")

    local IDS = {
        REPLANT = FourCC("REPL"),
        BUILD_ABILITY = FourCC("AEbu"),
        MYSTICS = FourCC("e003"),
        PROTECTORS = FourCC("h00T"),
        SPEAR_THROWERS = FourCC("h00R"),
        ANCIENT_TREE_WALL = FourCC("h01M"),
        ANCIENT_TREE_WALL_GROWN = FourCC("h00V"),
        FERAL_GROWTH = FourCC("A0MT"),
        FERAL_GROWTH_ARMOR = FourCC("A0N8"),
        FERAL_GROWTH_CHAOS = FourCC("S00O")
    }

    local REPLANT_DAMAGE_PER_SECOND = 25.0
    local REPLANT_LUMBER_REWARD = 175
    local FERAL_GROWTH_DURATION = 6

    local function setUnitHealth(unit, value)
        if value < 0.405 then
            value = 0.405
        end
        SetWidgetLife(unit, value)
    end

    local function setUnitMana(unit, value)
        if value < 0.0 then
            value = 0.0
        end
        SetUnitState(unit, UNIT_STATE_MANA, value)
    end

    local function showLumberTag(player, unit, amount)
        local tag = CreateTextTagUnitBJ("|cff01bf4d+" .. I2S(amount) .. "|r", unit, 0.0, 10.0, 0, 0, 100, 0)
        local speed = TextTagSpeed2Velocity(50.0)

        SetTextTagVelocity(tag, speed * Cos(90.0 * bj_DEGTORAD), speed * Sin(90.0 * bj_DEGTORAD))
        SetTextTagFadepoint(tag, 1.5)
        SetTextTagLifespan(tag, 2.0)
        SetTextTagPermanent(tag, false)

        if GetLocalPlayer() == player then
            SetTextTagVisibility(tag, true)
        else
            SetTextTagVisibility(tag, false)
        end
    end

    local function startReplant(unit)
        return GameTimer.every(1.0, function(gameTimer)
            local owner = nil
            local hp = 0.0
            local mp = 0.0

            if not unit or GetWidgetLife(unit) <= 0.405 then
                gameTimer:destroy()
                return
            end

            hp = GetWidgetLife(unit)
            mp = GetUnitState(unit, UNIT_STATE_MANA)
            owner = GetOwningPlayer(unit)

            if hp < REPLANT_DAMAGE_PER_SECOND then
                KillUnit(unit)
                SetPlayerState(owner, PLAYER_STATE_RESOURCE_LUMBER, GetPlayerState(owner, PLAYER_STATE_RESOURCE_LUMBER) + REPLANT_LUMBER_REWARD)
                showLumberTag(owner, unit, REPLANT_LUMBER_REWARD)
                gameTimer:destroy()
            else
                setUnitHealth(unit, hp - REPLANT_DAMAGE_PER_SECOND)
                if mp > hp then
                    setUnitMana(unit, mp - REPLANT_DAMAGE_PER_SECOND * 2.0)
                else
                    setUnitMana(unit, mp - REPLANT_DAMAGE_PER_SECOND)
                end
            end
        end)
    end

    local function advanceFeralGrowth(unit)
        local typeId = unit and GetUnitTypeId(unit) or 0
        local armorLevel = 0

        if typeId ~= IDS.ANCIENT_TREE_WALL and typeId ~= IDS.ANCIENT_TREE_WALL_GROWN then
            return
        end

        armorLevel = GetUnitAbilityLevel(unit, IDS.FERAL_GROWTH_ARMOR)
        if armorLevel <= 0 then
            UnitAddAbility(unit, IDS.FERAL_GROWTH_ARMOR)
        elseif armorLevel >= FERAL_GROWTH_DURATION then
            UnitRemoveAbility(unit, IDS.FERAL_GROWTH_ARMOR)
            UnitAddAbility(unit, IDS.FERAL_GROWTH_CHAOS)
        else
            SetUnitAbilityLevel(unit, IDS.FERAL_GROWTH_ARMOR, armorLevel + 1)
        end
    end

    local function onSpellEffect()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.REPLANT then
            startReplant(GetTriggerUnit())
        elseif abilityId == IDS.FERAL_GROWTH then
            advanceFeralGrowth(GetTriggerUnit())
        end
    end

    local function onUpgradeFinish()
        local unit = GetTriggerUnit()
        local id = GetUnitTypeId(unit)

        if id == IDS.MYSTICS or id == IDS.PROTECTORS or id == IDS.SPEAR_THROWERS then
            UnitRemoveAbility(unit, IDS.BUILD_ABILITY)
        end
    end

    local spellTrigger = CreateTrigger()
    local upgradeTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(upgradeTrigger, Player(i), EVENT_PLAYER_UNIT_UPGRADE_FINISH, nil)
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

    TriggerAddAction(upgradeTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onUpgradeFinish)
        else
            onUpgradeFinish()
        end
    end)

    AbilityRegistry.registerRace("Nature", "structures", {
        notes = "Nature tower/building/upgrade abilities ported from NatureReplant, NatureRemoveBuild and FeralGrowth.",
        abilities = {
            {
                name = "Replant",
                id = IDS.REPLANT,
                source = "library NatureReplant",
                behavior = "A plant using REPL loses 25 health per second, drains mana, then dies and refunds 175 lumber with a local tag."
            },
            {
                name = "Remove Build",
                id = IDS.BUILD_ABILITY,
                source = "library NatureRemoveBuild",
                behavior = "Removes AEbu from upgraded Mystics e003, Protectors h00T and Spear Throwers h00R."
            },
            {
                name = "Feral Growth",
                id = IDS.FERAL_GROWTH,
                source = "library FeralGrowth",
                behavior = "Ancient Tree Wall h01M gains six A0N8 armor stages from A0MT, then S00O transforms it into h00V."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
