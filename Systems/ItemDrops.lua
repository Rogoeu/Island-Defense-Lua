if Debug and Debug.beginFile then Debug.beginFile("Systems/ItemDrops") end

OnInit("ItemDrops", function(import)
    import.strict("GameSettings")
    import.strict("PlayerData")
    import.strict("UnitFilter")

    local DROP_ROLL_MAX = 20
    local DROP_ROLL_SUCCESS = 15
    local GOLD_EFFECT = "Abilities\\Spells\\Other\\Transmute\\PileofGold.mdl"

    local DROP_ITEMS = {
        { id = FourCC("I017"), weight = 1.0 }, -- Healing Wards
        { id = FourCC("I01G"), weight = 1.0 }, -- Replenishment Potion
        { id = FourCC("I018"), weight = 1.0 }, -- Scroll of the Beast
        { id = FourCC("I01F"), weight = 1.0 }, -- Eye of the Ocean
        { id = FourCC("I01H"), weight = 1.0 }, -- Wand of the Wind
        { id = FourCC("I003"), weight = 0.5 }, -- Tome of Health
        { id = FourCC("I008"), weight = 0.5 }, -- Tome of Power
        { id = FourCC("I01I"), weight = 1.0 }, -- Staff of Teleportation
        { id = FourCC("I03Q"), weight = 1.0 }, -- Trident
        { id = FourCC("I03R"), weight = 1.0 }, -- Armored Scales
        { id = FourCC("I000"), weight = 1.0 } -- Shadowstone
    }

    local itemDropPool = nil
    local ItemDrops = {}

    local function setupPool()
        local i = 1

        if itemDropPool then
            return
        end

        itemDropPool = CreateItemPool()
        while i <= #DROP_ITEMS do
            ItemPoolAddItemType(itemDropPool, DROP_ITEMS[i].id, DROP_ITEMS[i].weight)
            i = i + 1
        end
    end

    local function checkDropConditions(killer, killed)
        local killerData = nil
        local killedData = nil

        if not killer or not killed then
            return false
        end

        killerData = PlayerData.get(GetOwningPlayer(killer))
        killedData = PlayerData.get(GetOwningPlayer(killed))

        return UnitFilter.isTitanSidePlayer(killerData) and
            (UnitFilter.isDefenderPlayer(killedData) or GetOwningPlayer(killed) == Player(PLAYER_NEUTRAL_PASSIVE))
    end

    local function showGoldTag(killer, killed, amount)
        local tag = CreateTextTag()

        SetTextTagText(tag, "|cffffcc00+ " .. I2S(amount), TextTagSize2Height(8))
        SetTextTagPos(tag, GetUnitX(killed), GetUnitY(killed), 100)
        SetTextTagVisibility(tag, true)
        SetTextTagPermanent(tag, false)
        SetTextTagLifespan(tag, 1.8)
        SetTextTagFadepoint(tag, 1.4)
        SetTextTagVelocity(tag, TextTagSpeed2Velocity(0), TextTagSpeed2Velocity(44))
        DestroyEffect(AddSpecialEffectTarget(GOLD_EFFECT, killed, "origin"))
    end

    local function tryGoldCoin(killer, killed, roll)
        local gold = GameSettings.getInt("GC_GOLD_AMOUNT")
        local successMax = GameSettings.getInt("GC_CHANCE_SUCCESS_MAX")
        local owner = nil

        if GameSettings.getStr("TWEAK_GC") ~= "on" or gold <= 0 then
            return
        end

        if roll > successMax then
            return
        end

        owner = GetOwningPlayer(killer)
        SetPlayerState(owner, PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(owner, PLAYER_STATE_RESOURCE_GOLD) + gold)
        showGoldTag(killer, killed, gold)
    end

    local function dropRandomItem(x, y)
        setupPool()
        PlaceRandomItem(itemDropPool, x, y)
    end

    local function dropRandomItemChance(killer, killed)
        local roll = GetRandomInt(0, DROP_ROLL_MAX)

        if roll == DROP_ROLL_SUCCESS then
            dropRandomItem(GetUnitX(killed), GetUnitY(killed))
        end

        tryGoldCoin(killer, killed, roll)
    end

    local function onDeath()
        local killed = GetTriggerUnit()
        local killer = GetKillingUnit()

        if checkDropConditions(killer, killed) then
            dropRandomItemChance(killer, killed)
        end
    end

    local deathTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end

    setupPool()
    TriggerAddAction(deathTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDeath)
        else
            onDeath()
        end
    end)

    function ItemDrops.dropRandomItem(x, y)
        dropRandomItem(x, y)
    end

    function ItemDrops.dropRandomItemChance(killer, killed)
        if killer and killed then
            dropRandomItemChance(killer, killed)
        end
    end

    _G.ItemDrops = ItemDrops
end)

if Debug and Debug.endFile then Debug.endFile() end
