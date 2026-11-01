if Debug and Debug.beginFile then Debug.beginFile("items/ShopSystemAutoBuy") end

OnInit("ShopSystemAutoBuy", function(import)
    import.strict("ItemExtras")
    import.strict("UnitSpawner")
    import.strict("PlayerData")

    local ShopSystemAutoBuy = {}
    local busy = false
    local ankhCrafted = false
    local I_SWITCH_PAGE = FourCC("I051")
    local I_RESEARCH_PAGE = FourCC("I07N")
    local I_ANKH_OF_REINCARNATION = FourCC("I00P")

    -- Component/result item ids. Tier 2/3 recipe indexes map to the crafted item here.
    local COM = {
        -- Tier I
        [101] = FourCC("I07T"), -- Chimaera Pendant
        [102] = FourCC("I00B"), -- Gem Of Haste
        [103] = FourCC("I07W"), -- Magic Coral
        [104] = FourCC("I07P"), -- Pearl Of Vision
        [105] = FourCC("I042"), -- Reef Shield
        [106] = FourCC("I00C"), -- Regenerative Spines
        [107] = FourCC("I07X"), -- Rune Fragment
        [108] = FourCC("I05P"), -- Shadow Shard
        [109] = FourCC("I00D"), -- Surge Trident
        [110] = FourCC("I07U"), -- Tides Heart
        [111] = FourCC("I00E"), -- Webbed Feet
        [112] = FourCC("I00P"), -- Ankh of Reincarnation

        -- Consumables
        [151] = FourCC("I018"), -- Beast Scroll
        [152] = FourCC("I017"), -- Healing Ward
        [153] = FourCC("I01G"), -- Potion of Recovery
        [154] = FourCC("I01I"), -- Staff of Teleport
        [155] = FourCC("I03L"), -- Wand of Neutralization
        [156] = FourCC("I01H"), -- Wand of the Wind
        [157] = FourCC("I01F"), -- Watcher's Eye

        -- Tier II crafted items
        [201] = FourCC("I06X"), -- Blasting Wand
        [202] = FourCC("I031"), -- Casque of Valor
        [203] = FourCC("I081"), -- Caster Scroll
        [204] = FourCC("I086"), -- Enchantress' Vial
        [205] = FourCC("I01Z"), -- Eternal Wards
        [206] = FourCC("I068"), -- Ethereal Mirror
        [207] = FourCC("I0A1"), -- Cyclone Staff
        [208] = FourCC("I08Q"), -- Gauntlets of Embers
        [209] = FourCC("I01V"), -- Heart of the Sea
        [210] = FourCC("I089"), -- Tidal Guardian's Grace
        [211] = FourCC("I09X"), -- Pearl of Grand Vision
        [212] = FourCC("I07Z"), -- Reef Armor
        [213] = FourCC("I08R"), -- Runic Axe
        [214] = FourCC("I07Q"), -- Berserkers Gem
        [215] = FourCC("I09Z"), -- Stormrider Cloak
        [216] = FourCC("I080"), -- Super Regeneration Spines
        [217] = FourCC("I0A0"), -- Titanic Trident
        [218] = FourCC("I08B"), -- Voodoo Doll
        [219] = FourCC("I07O"), -- Warbanner
        [221] = FourCC("I087"), -- Magic Armor
        [222] = FourCC("I0A3"), -- Floating Eye

        -- Tier III crafted items
        [301] = FourCC("I07A"), -- Ankh of Superiority
        [302] = FourCC("I08V"), -- Armor of Tides
        [303] = FourCC("I08X"), -- Dawnkeeper
        [304] = FourCC("I052"), -- Enchanted Druid Leaf
        [305] = FourCC("I08U"), -- Essence of Pure Magic
        [306] = FourCC("I090"), -- Foreteller's Sickle
        [307] = FourCC("I091"), -- Helmet of the Damned
        [308] = FourCC("I092"), -- Mistlord's Cape
        [309] = FourCC("I093"), -- Molten Blade
        [310] = FourCC("I01T"), -- Mystic Staff of Gods
        [311] = FourCC("I08T"), -- Mace of Mortality
        [312] = FourCC("I094"), -- Poseidon's Trident
        [313] = FourCC("I08W"), -- Robe of Spellcraft
        [314] = FourCC("I095"), -- Spear of Fervor
        [315] = FourCC("I08S"), -- Tidal Scepter
        [316] = FourCC("I08Y"), -- Highseer Slippers
        [317] = FourCC("I08Z"), -- Enhanced Magic Armor
        [318] = FourCC("I01P")  -- Siegecaster's Trophy
    }

    -- Recipe scroll ids. Buying one of these scrolls triggers auto-buy/combine into COM[index].
    local RECIPE = {
        -- Tier II recipe scrolls
        [201] = FourCC("I06Y"), -- Blasting Wand Recipe
        [202] = FourCC("I06B"), -- Casque of Valor Recipe
        [203] = FourCC("I097"), -- Caster Scroll Recipe
        [204] = FourCC("I099"), -- Enchantress' Vial Recipe
        [205] = FourCC("I01Y"), -- Eternal Wards Recipe
        [206] = FourCC("I040"), -- Ethereal Mirror Recipe
        [207] = FourCC("I0A2"), -- Cyclone Staff Recipe
        [208] = FourCC("I09D"), -- Gauntlets of Embers Recipe
        [209] = FourCC("I01W"), -- Heart of the Sea Recipe
        [210] = FourCC("I09S"), -- Tidal Guardian's Grace Recipe
        [211] = FourCC("I09K"), -- Pearl of Grand Vision Recipe
        [212] = FourCC("I09M"), -- Reef Armor Recipe
        [213] = FourCC("I09O"), -- Runic Axe Recipe
        [214] = FourCC("I09Y"), -- Berserkers Gem Recipe
        [215] = FourCC("I09Q"), -- Stormrider Cloak Recipe
        [216] = FourCC("I09R"), -- Super Regeneration Spines Recipe
        [217] = FourCC("I09U"), -- Titanic Trident Recipe
        [218] = FourCC("I09V"), -- Voodoo Doll Recipe
        [219] = FourCC("I09W"), -- Warbanner Recipe
        [221] = FourCC("I09H"), -- Magic Armor Recipe
        [222] = FourCC("I0A4"), -- Floating Eye Recipe

        -- Tier III recipe scrolls
        [301] = FourCC("I079"), -- Ankh of Superiority Recipe
        [302] = FourCC("I096"), -- Armor of Tides Recipe
        [303] = FourCC("I098"), -- Dawnkeeper Recipe
        [304] = FourCC("I053"), -- Enchanted Druid Leaf Recipe
        [305] = FourCC("I09B"), -- Essence of Pure Magic Recipe
        [306] = FourCC("I09C"), -- Foreteller's Sickle Recipe
        [307] = FourCC("I09E"), -- Helmet of the Damned Recipe
        [308] = FourCC("I09I"), -- Mistlord's Cape Recipe
        [309] = FourCC("I09J"), -- Molten Blade Recipe
        [310] = FourCC("I01S"), -- Mystic Staff of Gods Recipe
        [311] = FourCC("I09G"), -- Mace of Mortality Recipe
        [312] = FourCC("I09L"), -- Poseidon's Trident Recipe
        [313] = FourCC("I09N"), -- Robe of Spellcraft Recipe
        [314] = FourCC("I09P"), -- Spear of Fervor Recipe
        [315] = FourCC("I09T"), -- Tidal Scepter Recipe
        [316] = FourCC("I09F"), -- Highseer Slippers Recipe
        [317] = FourCC("I09A"), -- Enhanced Magic Armor Recipe
        [318] = FourCC("I01Q")  -- Siegecaster's Trophy Recipe
    }

    -- Recipe requirements reference COM indexes, not raw item ids.
    local COMPONENT_INDEXES = {
        -- Tier II recipes
        [201] = { 103, 107 },      -- Blasting Wand
        [202] = { 105, 106, 110 }, -- Casque of Valor
        [203] = { 103, 103 },      -- Caster Scroll
        [204] = { 153, 110, 110 }, -- Enchantress' Vial
        [205] = { 152, 152, 106 }, -- Eternal Wards
        [206] = { 103, 108 },      -- Ethereal Mirror
        [207] = { 156, 156 },      -- Cyclone Staff
        [208] = { 107 },           -- Gauntlets of Embers
        [209] = { 103, 106, 110 }, -- Heart of the Sea
        [210] = {},                -- Tidal Guardian's Grace
        [211] = { 104 },           -- Pearl of Grand Vision
        [212] = { 105, 105, 110 }, -- Reef Armor
        [213] = { 157, 107 },      -- Runic Axe
        [214] = { 102, 102 },      -- Berserkers Gem
        [215] = { 102, 108, 111 }, -- Stormrider Cloak
        [216] = { 106, 106, 106 }, -- Super Regeneration Spines
        [217] = { 109, 109, 109 }, -- Titanic Trident
        [218] = { 109, 152, 152 }, -- Voodoo Doll
        [219] = { 151, 102, 109 }, -- Warbanner
        [221] = { 103, 105, 105 }, -- Magic Armor
        [222] = { 157, 157 },      -- Floating Eye

        -- Tier III recipes
        [301] = { 112 },                -- Ankh of Superiority
        [302] = { 212, 216 },           -- Armor of Tides
        [303] = { 202, 204 },           -- Dawnkeeper
        [304] = { 205 },                -- Enchanted Druid Leaf
        [305] = { 204, 209 },           -- Essence of Pure Magic
        [306] = { 213, 103, 214 },      -- Foreteller's Sickle
        [307] = { 218, 214, 109 },      -- Helmet of the Damned
        [308] = { 215, 216 },           -- Mistlord's Cape
        [309] = { 208, 213 },           -- Molten Blade
        [310] = { 209, 211 },           -- Mystic Staff of Gods
        [311] = { 219, 217, 110, 110 }, -- Mace of Mortality
        [312] = { 217, 219 },           -- Poseidon's Trident
        [313] = { 212, 221, 103 },      -- Robe of Spellcraft
        [314] = { 214, 214 },           -- Spear of Fervor
        [315] = { 201, 203 },           -- Tidal Scepter
        [316] = { 213, 203, 102 },      -- Highseer Slippers
        [317] = { 221, 216 },           -- Enhanced Magic Armor
        [318] = { 209, 103, 103 }       -- Siegecaster's Trophy
    }

    local recipeByItem = {}
    local recipeByResult = {}

    local function playerGold(player)
        return GetPlayerState(player, PLAYER_STATE_RESOURCE_GOLD)
    end

    local function setPlayerGold(player, amount)
        SetPlayerState(player, PLAYER_STATE_RESOURCE_GOLD, amount)
    end

    local function componentItemId(index)
        return COM[index] or 0
    end

    local function itemName(itemId)
        local item = CreateItem(itemId, 0.0, 0.0)
        local name = ""
        if item then
            name = GetItemName(item)
            RemoveItem(item)
        end
        return name
    end

    local function isTitanBuyer(unit)
        local playerData = unit and PlayerData.get(GetOwningPlayer(unit)) or nil
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function componentCost(itemId)
        return ItemExtras.itemCost(itemId)
    end

    local function recipeCost(recipeIndex)
        return ItemExtras.itemCost(RECIPE[recipeIndex] or 0)
    end

    local function indexToItemId(value)
        return COM[value] or RECIPE[value] or value
    end

    local function recipeIndexFromRecipeItem(itemId)
        return recipeByItem[itemId]
    end

    local function recipeIndexFromResultItem(itemId)
        return recipeByResult[itemId]
    end

    local function recipeIndexFromBuyRequest(value)
        if type(value) == "number" and RECIPE[value] then
            return value
        end
        return recipeIndexFromResultItem(value)
    end

    local function addInventorySource(sources, unit, item, slotOffset)
        local itemId = GetItemTypeId(item)
        local charges = GetItemCharges(item)
        local count = 1

        if GetItemType(item) == ITEM_TYPE_CHARGED and charges > 0 then
            count = charges
        end

        if not sources[itemId] then
            sources[itemId] = {}
        end

        sources[itemId][#sources[itemId] + 1] = {
            unit = unit,
            item = item,
            count = count,
            charged = GetItemType(item) == ITEM_TYPE_CHARGED,
            slotOffset = slotOffset or 0,
            used = 0
        }
    end

    local function collectSources(unit)
        local sources = {}
        local slot = 0
        local mound = UnitSpawner.get("TITAN_SPELL_WELL")

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item then
                addInventorySource(sources, unit, item, 0)
            end
            slot = slot + 1
        end

        if mound and GetOwningPlayer(mound) == GetOwningPlayer(unit) then
            slot = 0
            while slot < 6 do
                local item = UnitItemInSlot(mound, slot)
                if item then
                    addInventorySource(sources, mound, item, 6)
                end
                slot = slot + 1
            end
        end

        return sources
    end

    local function takeExisting(plan, itemId)
        local entries = plan.sources[itemId]
        local i = 1

        if not entries then
            return false
        end

        while i <= #entries do
            local entry = entries[i]
            if entry.used < entry.count then
                entry.used = entry.used + 1
                plan.consumed[#plan.consumed + 1] = entry
                return true
            end
            i = i + 1
        end

        return false
    end

    local ensurePlannedItem

    local function ensurePlannedRecipe(plan, recipeIndex, includeRecipeCost)
        local list = COMPONENT_INDEXES[recipeIndex] or {}
        local i = 1

        if includeRecipeCost then
            plan.cost = plan.cost + recipeCost(recipeIndex)
        end

        while i <= #list do
            if not ensurePlannedItem(plan, componentItemId(list[i])) then
                return false
            end
            i = i + 1
        end

        return true
    end

    ensurePlannedItem = function(plan, itemId)
        local recipeIndex = recipeByResult[itemId]

        if takeExisting(plan, itemId) then
            return true
        end

        if plan.rootRecipeIndex == 301 and itemId == I_ANKH_OF_REINCARNATION then
            plan.error = "|cff3399ffAnkh of Reincarnation|cff99b4d1 must be present for this action!|r"
            return false
        end

        if recipeIndex then
            return ensurePlannedRecipe(plan, recipeIndex, true)
        end

        plan.cost = plan.cost + componentCost(itemId)
        return true
    end

    local function applyConsumed(plan)
        local i = 1
        local applied = {}

        while i <= #plan.consumed do
            local entry = plan.consumed[i]
            local id = entry.item and GetHandleId(entry.item) or 0
            if id ~= 0 and not applied[id] then
                applied[id] = true
                if entry.charged and GetItemCharges(entry.item) > entry.used then
                    SetItemCharges(entry.item, GetItemCharges(entry.item) - entry.used)
                elseif entry.item then
                    RemoveItem(entry.item)
                end
            end
            i = i + 1
        end
    end

    local function inventoryCanReceiveResult(unit, plan, recipeItem)
        if ItemExtras.hasFreeSlot(unit) then
            return true
        end

        if recipeItem then
            return true
        end

        return #plan.consumed > 0
    end

    local function craftRecipe(unit, recipeIndex, recipeAlreadyPaid, recipeItem, refundOnFailure)
        local result = COM[recipeIndex]
        local player = GetOwningPlayer(unit)
        local plan = nil
        local paidCost = recipeItem and ItemExtras.itemCost(GetItemTypeId(recipeItem)) or recipeCost(recipeIndex)

        if not result then
            return false
        end

        if recipeIndex == 301 and ankhCrafted then
            if refundOnFailure and recipeAlreadyPaid then
                setPlayerGold(player, playerGold(player) + paidCost)
            end
            if recipeItem then
                RemoveItem(recipeItem)
            end
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1There should only be one |cff3399ffAnkh of Superiority|cff99b4d1.|r")
            return false
        end

        plan = {
            sources = collectSources(unit),
            consumed = {},
            cost = recipeAlreadyPaid and 0 or recipeCost(recipeIndex),
            rootRecipeIndex = recipeIndex,
            error = nil
        }

        if not ensurePlannedRecipe(plan, recipeIndex, false) or plan.cost > playerGold(player) or not inventoryCanReceiveResult(unit, plan, recipeItem) then
            if refundOnFailure and recipeAlreadyPaid then
                setPlayerGold(player, playerGold(player) + paidCost)
            end
            if recipeItem then
                RemoveItem(recipeItem)
            end
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1" .. (plan.error or ("Failed to create |cff3399ff" .. itemName(result) .. "|cff99b4d1.")) .. "|r")
            return false
        end

        applyConsumed(plan)
        if recipeItem then
            RemoveItem(recipeItem)
        end
        setPlayerGold(player, playerGold(player) - plan.cost)
        UnitAddItemById(unit, result)
        if recipeIndex == 301 then
            ankhCrafted = true
        end
        return true
    end

    local function tryBoughtRecipe(unit, item)
        local recipeIndex = item and recipeIndexFromRecipeItem(GetItemTypeId(item)) or nil
        if not recipeIndex then
            return false
        end
        return craftRecipe(unit, recipeIndex, true, item, true)
    end

    function ShopSystemAutoBuy.recipeIndex(itemId)
        return recipeIndexFromRecipeItem(itemId)
    end

    function ShopSystemAutoBuy.getItemGrade(itemId)
        return ItemExtras.itemGrade(itemId)
    end

    function ShopSystemAutoBuy.GetCom(index)
        return COM[index]
    end

    function ShopSystemAutoBuy.GetRecipe(index)
        return RECIPE[index]
    end

    function ShopSystemAutoBuy.GetRecipeCompCount(index)
        local components = COMPONENT_INDEXES[index]
        if components then
            return #components
        end
        return 0
    end

    function ShopSystemAutoBuy.GetRecipeComp(index, slot)
        local components = COMPONENT_INDEXES[index]
        if components then
            return componentItemId(components[slot] or 0)
        end
        return 0
    end

    function ShopSystemAutoBuy.matchComponent2Recipe(itemId)
        local index = recipeByResult[itemId]
        if index and index >= 200 and index < 300 then
            return RECIPE[index]
        end
        return 0
    end

    function ShopSystemAutoBuy.matchAnyComponent2Recipe(itemId)
        local index = recipeByResult[itemId]
        if index then
            return RECIPE[index]
        end
        return 0
    end

    function ShopSystemAutoBuy.fMatchRecipeToComponent(itemId)
        local index = recipeByItem[itemId]
        if index then
            return COM[index]
        end
        return 0
    end

    function ShopSystemAutoBuy.recipeItem(index)
        return RECIPE[index]
    end

    function ShopSystemAutoBuy.resultItem(index)
        return COM[index]
    end

    function ShopSystemAutoBuy.componentItem(index)
        return componentItemId(index)
    end

    function ShopSystemAutoBuy.tryCombine(unit, itemId)
        local recipeIndex = recipeIndexFromRecipeItem(itemId) or recipeIndexFromBuyRequest(itemId)
        if not recipeIndex then
            return false
        end
        return craftRecipe(unit, recipeIndex, false, nil, false)
    end

    function ShopSystemAutoBuy.checkItemAvailability(unit, itemId, recipeAlreadyPaid)
        local actualItemId = indexToItemId(itemId)
        local recipeIndex = recipeIndexFromRecipeItem(actualItemId) or recipeIndexFromBuyRequest(itemId)
        local plan = nil
        local cost = 0

        if not unit or not actualItemId or actualItemId == 0 then
            return false
        end

        if not recipeIndex then
            cost = componentCost(actualItemId)
            return cost <= playerGold(GetOwningPlayer(unit)) and ItemExtras.hasFreeSlot(unit)
        end

        plan = {
            sources = collectSources(unit),
            consumed = {},
            cost = recipeAlreadyPaid and 0 or recipeCost(recipeIndex),
            rootRecipeIndex = recipeIndex,
            error = nil
        }

        return ensurePlannedRecipe(plan, recipeIndex, false) and plan.cost <= playerGold(GetOwningPlayer(unit)) and inventoryCanReceiveResult(unit, plan, nil)
    end

    function ShopSystemAutoBuy.buyItemForUnit(unit, itemId)
        local player = unit and GetOwningPlayer(unit) or nil
        local actualItemId = indexToItemId(itemId)
        local recipeIndex = recipeIndexFromRecipeItem(actualItemId) or recipeIndexFromBuyRequest(itemId)
        local cost = 0

        if not unit or not actualItemId or actualItemId == 0 then
            return false
        end

        if actualItemId == I_ANKH_OF_REINCARNATION then
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1This item cannot be bought in the new UI.|r")
            return false
        end

        if recipeIndex then
            return craftRecipe(unit, recipeIndex, false, nil, false)
        end

        cost = componentCost(actualItemId)
        if cost > playerGold(player) then
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Not enough gold for |cff3399ff" .. itemName(actualItemId) .. "|cff99b4d1.|r")
            return false
        end
        if not ItemExtras.hasFreeSlot(unit) then
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Inventory full.|r")
            return false
        end

        setPlayerGold(player, playerGold(player) - cost)
        UnitAddItemById(unit, actualItemId)
        return true
    end

    ShopSystemAutoBuy.BuyItemForUnit = ShopSystemAutoBuy.buyItemForUnit

    for index, itemId in pairs(RECIPE) do
        recipeByItem[itemId] = index
    end

    for index, itemId in pairs(COM) do
        if RECIPE[index] then
            recipeByResult[itemId] = index
        end
    end

    local sellTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(sellTrigger, Player(i), EVENT_PLAYER_UNIT_SELL_ITEM, nil)
        i = i + 1
    end

    TriggerAddAction(sellTrigger, function()
        local buyer = GetBuyingUnit()
        local sold = GetSoldItem()
        local seller = GetSellingUnit()
        local itemId = sold and GetItemTypeId(sold) or 0
        local recipeIndex = recipeByItem[itemId]

        if busy or not buyer or not sold then
            return
        end

        if itemId == I_SWITCH_PAGE or itemId == I_RESEARCH_PAGE then
            local current = seller
            local nextShop = nil

            if current == UnitSpawner.get("RECIPES_PAGE_TWO") then
                nextShop = UnitSpawner.get("RECIPES_PAGE_ONE")
            elseif current == UnitSpawner.get("RECIPES_PAGE_ONE") then
                nextShop = UnitSpawner.get("RECIPES_PAGE_TWO")
            elseif current == UnitSpawner.get("RECIPES_PAGE_TWO_TIER3") then
                nextShop = UnitSpawner.get("RECIPES_PAGE_ONE_TIER3")
            elseif current == UnitSpawner.get("RECIPES_PAGE_ONE_TIER3") then
                nextShop = UnitSpawner.get("RECIPES_PAGE_TWO_TIER3")
            elseif current == UnitSpawner.get("TITAN_PUNISH_CAGE_PUNISH") then
                nextShop = UnitSpawner.get("TITAN_PUNISH_CAGE_RESEARCH")
            elseif current == UnitSpawner.get("TITAN_PUNISH_CAGE_RESEARCH") then
                nextShop = UnitSpawner.get("TITAN_PUNISH_CAGE_PUNISH")
            end

            if nextShop then
                IssueTargetOrderById(nextShop, OrderId("neutralinteract"), buyer)
                SelectUnitForPlayerSingle(nextShop, GetOwningPlayer(buyer))
            end
            RemoveItem(sold)
            return
        end

        if not recipeIndex or not isTitanBuyer(buyer) then
            return
        end

        busy = true
        tryBoughtRecipe(buyer, sold)
        busy = false
    end)

    _G.ShopSystemAutoBuy = ShopSystemAutoBuy
    _G.BuyItemForUnit = ShopSystemAutoBuy.buyItemForUnit
    _G.GetCom = ShopSystemAutoBuy.GetCom
    _G.GetRecipe = ShopSystemAutoBuy.GetRecipe
    _G.GetRecipeCompCount = ShopSystemAutoBuy.GetRecipeCompCount
    _G.GetRecipeComp = ShopSystemAutoBuy.GetRecipeComp
    _G.matchComponent2Recipe = ShopSystemAutoBuy.matchComponent2Recipe
    _G.matchAnyComponent2Recipe = ShopSystemAutoBuy.matchAnyComponent2Recipe
    _G.fMatchRecipeToComponent = ShopSystemAutoBuy.fMatchRecipeToComponent
    _G.checkItemAvailability = ShopSystemAutoBuy.checkItemAvailability
end)

if Debug and Debug.endFile then Debug.endFile() end
