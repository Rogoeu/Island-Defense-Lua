if Debug and Debug.beginFile then Debug.beginFile("Abilities/Global/GlobalBuilderAbilities") end

OnInit("GlobalBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameSettings")
    import.strict("PlayerData")
    import.strict("ExperienceSystem")
    import.strict("UnitSpawner")

    local IDS = {
        GOLDING = FourCC("A041"),
        TAUREN = FourCC("O01Q"),
        TAUREN_ANCESTRAL = FourCC("O01R"),
        TAUREN_ALT = FourCC("O04H")
    }

    local GOLD_EFFECT = "Abilities\\Spells\\Other\\Transmute\\PileofGold.mdl"
    local TAUREN_GOLDING_EXPERIENCE = 2
    local stolenGoldByPlayerId = {}
    local totalStolenGold = 0
    local GlobalBuilderAbilities = {}

    local function isDefender(playerData)
        return playerData and playerData:class() == PlayerData.CLASS_DEFENDER
    end

    local function isTauren(unit)
        local unitTypeId = unit and GetUnitTypeId(unit) or 0

        return unitTypeId == IDS.TAUREN or
            unitTypeId == IDS.TAUREN_ANCESTRAL or
            unitTypeId == IDS.TAUREN_ALT
    end

    local function addGoldFed(playerData, amount)
        local feedApi = rawget(_G, "PlayerDataFed")
        local data = nil

        if feedApi and feedApi.get and feedApi.addGold then
            data = feedApi.get(playerData)
            if data then
                feedApi.addGold(data, amount)
            end
        end
    end

    local function titanDataFromGoldingTarget(target)
        local well = UnitSpawner.get("TITAN_SPELL_WELL")
        local owner = nil

        if target then
            owner = PlayerData.get(GetOwningPlayer(target))
            if owner and owner:class() == PlayerData.CLASS_TITAN then
                return owner
            end
        end

        if well then
            owner = PlayerData.get(GetOwningPlayer(well))
            if owner and owner:class() == PlayerData.CLASS_TITAN then
                return owner
            end
        end

        return nil
    end

    function GlobalBuilderAbilities.stolenGold(playerData)
        if not playerData then
            return 0
        end
        return stolenGoldByPlayerId[playerData:id()] or 0
    end

    function GlobalBuilderAbilities.totalStolenGold()
        return totalStolenGold
    end

    function GlobalBuilderAbilities.resetGoldingStats()
        stolenGoldByPlayerId = {}
        totalStolenGold = 0
    end

    local function onGolding()
        local caster = GetTriggerUnit()
        local target = GetSpellTargetUnit()
        local player = nil
        local playerData = nil
        local titanData = nil

        if GetSpellAbilityId() ~= IDS.GOLDING or not caster then
            return
        end

        player = GetOwningPlayer(caster)
        playerData = PlayerData.get(player)
        if not isDefender(playerData) then
            return
        end

        SetPlayerState(player, PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(player, PLAYER_STATE_RESOURCE_GOLD) + 1)
        if isTauren(caster) then
            ExperienceSystem.giveExperience(caster, TAUREN_GOLDING_EXPERIENCE)
        end
        titanData = titanDataFromGoldingTarget(target)
        if titanData then
            addGoldFed(titanData, 1)
        end
        stolenGoldByPlayerId[playerData:id()] = (stolenGoldByPlayerId[playerData:id()] or 0) + 1
        totalStolenGold = totalStolenGold + 1

        if target then
            DestroyEffect(AddSpecialEffect(GOLD_EFFECT, GetUnitX(target), GetUnitY(target)))
            SetUnitState(target, UNIT_STATE_LIFE, GetUnitState(target, UNIT_STATE_MAX_LIFE) / 4.0)
        end

        if GameSettings.exists("TITAN_MOUND_GOLD_STOLEN") then
            GameSettings.setInt("TITAN_MOUND_GOLD_STOLEN", GameSettings.getInt("TITAN_MOUND_GOLD_STOLEN") + 1)
        else
            GameSettings.setInt("TITAN_MOUND_GOLD_STOLEN", 1)
        end
    end

    local spellTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        i = i + 1
    end

    TriggerAddAction(spellTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onGolding)
        else
            onGolding()
        end
    end)

    AbilityRegistry.registerGlobal("builder", {
        notes = "Global builder abilities shared across defender races.",
        abilities = {
            {
                name = "Golding",
                id = IDS.GOLDING,
                source = "library GetGold",
                behavior = "When a defender casts A041, grants +1 gold to the defender, counts +1 Goldfed for the Titan owning the mound, tracks stolen gold per defender, restores the target mound to 25 percent life and increments TITAN_MOUND_GOLD_STOLEN. Tauren forms also gain 2 experience."
            }
        }
    })

    _G.GlobalBuilderAbilities = GlobalBuilderAbilities
end)

if Debug and Debug.endFile then Debug.endFile() end
