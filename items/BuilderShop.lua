if Debug and Debug.beginFile then Debug.beginFile("items/BuilderShop") end

OnInit("BuilderShop", function(import)
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("ItemStacking")
    import.strict("PlayerData")

    local BuilderShop = {}

    local RANDOM_ULTIMATE_RECIPE = FourCC("I02Z") -- Recipe item used to reroll an ultimate tower.
    local RANDOM_ULTIMATE_ITEM = FourCC("I03C") -- Old randomized ultimate tower result item.
    local EGG_COMPONENT = FourCC("I022") -- Egg consumed by ultimate tower rerolls.
    local processed = {}
    local busy = false
    local vision = {}

    local function cost(gold, lumber)
        return { gold = gold or 0, lumber = lumber or 0 }
    end

    -- Manual builder-shop costs. These override Object Editor costs for this shop only.
    -- Fill in gold/lumber here when a shop item should be bought by Lua auto-complete.
    local ITEM_COSTS = {
        -- Basic builder consumables / components.
        [FourCC("I007")] = cost(0, 1500), -- Eye of the Ocean
        [FourCC("I001")] = cost(0, 1000), -- Healing Wards
        [FourCC("I002")] = cost(0, 600), -- Potion of Recovery
        [FourCC("I005")] = cost(10, 0), -- Staff of Teleportation
        [FourCC("I004")] = cost(0, 800), -- Scroll of the Beast
        [FourCC("I009")] = cost(0, 1200), -- Trident
        [FourCC("I00A")] = cost(0, 900), -- Armored Scales
        [FourCC("I060")] = cost(0, 1000), -- Shadowstone
        [FourCC("I06C")] = cost(5, 0), -- Wand of the Wind
        [FourCC("I00H")] = cost(0, 700), -- Troll Hands
        [FourCC("I00G")] = cost(0, 700), -- Summoning Stone
        [FourCC("I00I")] = cost(0, 1600), -- Gnoll Luck
        [FourCC("I00Q")] = cost(0, 300), -- Turtle Summons
        [FourCC("I022")] = cost(45, 0), -- Egg component
        [FourCC("I032")] = cost(0, 0), -- Smith's Hammer component

        -- Upgrade components.
        [FourCC("I04B")] = cost(1, 1000), -- Greater Troll Hands component
        [FourCC("I049")] = cost(1, 1000), -- Greater Summoning Stone component
        [FourCC("I04A")] = cost(5, 1000), -- Greater Gnoll Luck component

        -- Recipe marker items.
        [FourCC("I023")] = cost(0, 0), -- Ring of Shadows recipe
        [FourCC("I021")] = cost(0, 0), -- Storm Hammer recipe
        [FourCC("I026")] = cost(0, 0), -- Teleporter recipe
        [FourCC("I03S")] = cost(0, 0), -- Shield of Will recipe
        [FourCC("I04H")] = cost(0, 0), -- Shield of Might recipe
        [FourCC("I04I")] = cost(0, 0), -- Runed Bracers recipe
        [FourCC("I04W")] = cost(0, 0), -- Great Turtle Summons recipe
        [FourCC("I05W")] = cost(0, 0), -- Solar Blade recipe
        [FourCC("I04S")] = cost(0, 0), -- Sword of the Magistrate recipe
        [FourCC("I05G")] = cost(0, 0), -- Mystic Stone recipe

        -- Crafted builder items that can also be sold directly by a shop.
        [FourCC("I048")] = cost(0, 0), -- Greater Troll Hands
        [FourCC("I046")] = cost(0, 0), -- Greater Summoning Stone
        [FourCC("I047")] = cost(0, 0), -- Greater Gnoll Luck
        [FourCC("I04F")] = cost(0, 0), -- Runed Bracers
        [FourCC("I03P")] = cost(0, 0), -- Shield of Will
        [FourCC("I04G")] = cost(0, 0), -- Shield of Might
        [FourCC("I05D")] = cost(0, 0), -- Shield of Fortitude
        [FourCC("I020")] = cost(0, 0), -- Ring of Shadows
        [FourCC("I01X")] = cost(0, 0), -- Storm Hammer
        [FourCC("I025")] = cost(0, 0), -- Teleporter
        [FourCC("I04Y")] = cost(0, 0), -- Great Turtle Summons
        [FourCC("I04R")] = cost(0, 0), -- Solar Blade
        [FourCC("I071")] = cost(0, 0), -- Wings of the White Tree
        [FourCC("I072")] = cost(0, 0), -- Charged Wings of the White Tree
        [FourCC("I05V")] = cost(0, 0), -- Sword of the Magistrate
        [FourCC("I05X")] = cost(0, 0), -- Mystic Stone

        -- Titan-side variants used by conversion/hidden recipes.
        [FourCC("I01F")] = cost(0, 0), -- Watcher's Eye
        [FourCC("I017")] = cost(0, 0), -- Titan Healing Wards
        [FourCC("I01G")] = cost(0, 0), -- Titan Potion of Recovery
        [FourCC("I01I")] = cost(0, 0), -- Titan Staff of Teleportation
        [FourCC("I018")] = cost(0, 0), -- Titan Scroll of the Beast
        [FourCC("I03Q")] = cost(0, 0), -- Titan Trident
        [FourCC("I03R")] = cost(0, 0), -- Titan Armored Scales
        [FourCC("I000")] = cost(0, 0), -- Titan Shadowstone
        [FourCC("I01H")] = cost(0, 0), -- Titan Wand of the Wind
        [FourCC("I02S")] = cost(0, 0), -- Siren Scepter
        [FourCC("I00D")] = cost(0, 0), -- Stacked Tridents
        [FourCC("I00B")] = cost(0, 0), -- Stacked Shadowstone
        [FourCC("I042")] = cost(0, 0), -- Stacked Armor Scales
        [FourCC("I03F")] = cost(0, 0), -- Smith's Hammer

        -- Ultimate tower result items.
        [FourCC("I00J")] = cost(0, 0), -- Sacred Seashell
        [FourCC("I00Y")] = cost(0, 0), -- Heavy Cannon
        [FourCC("I03A")] = cost(0, 0), -- Methane Machine
        [FourCC("I00K")] = cost(0, 0), -- Sludge Launcher
        [FourCC("I00N")] = cost(0, 0), -- Tropical Glyph
        [FourCC("I00T")] = cost(0, 0), -- Giant Hermit
        [FourCC("I00U")] = cost(0, 0), -- Crab Mutant
        [FourCC("I00V")] = cost(0, 0), -- Catapult
        [FourCC("I011")] = cost(0, 0), -- Whirlpool
        [FourCC("I00W")] = cost(0, 0), -- Stasis Totem
        [FourCC("I00O")] = cost(0, 0), -- Magic Pearl
        [FourCC("I00Z")] = cost(0, 0), -- Magic Tower
        [FourCC("I010")] = cost(0, 0), -- Bombard
        [FourCC("I00X")] = cost(0, 0), -- Magic Mushroom
        [FourCC("I013")] = cost(0, 0), -- Aura Tree
        [FourCC("I014")] = cost(0, 0), -- Spell Well
        [FourCC("I015")] = cost(0, 0), -- Spiny Protector
        [FourCC("I01A")] = cost(0, 0), -- Rapid Fire Tower
        [FourCC("I01B")] = cost(0, 0), -- Deepfreeze
        [FourCC("I01C")] = cost(0, 0), -- Energy Spire
        [FourCC("I01K")] = cost(0, 0), -- Mutation Tower
        [FourCC("I01L")] = cost(0, 0), -- Toxic Tower
        [FourCC("I02Y")] = cost(0, 0), -- Demolisher Totem
        [FourCC("I04T")] = cost(0, 0), -- Replicator
        [FourCC("I05A")] = cost(0, 0), -- Box of Gaia
        [FourCC("I058")] = cost(0, 0), -- Box of Pyros
        [FourCC("I059")] = cost(0, 0), -- Box of Storms
        [FourCC("I057")] = cost(0, 0), -- High Energy Conduit
        [FourCC("I04O")] = cost(0, 0), -- Ice Palace
        [FourCC("I05T")] = cost(0, 0), -- Egg Sack
        [FourCC("I04J")] = cost(0, 0), -- Fireworks Launcher
        [FourCC("I04L")] = cost(0, 0), -- Tavern
        [FourCC("I056")] = cost(0, 0), -- Well of Power
        [FourCC("I06D")] = cost(0, 0), -- Island Bloom
        [FourCC("I01M")] = cost(0, 0), -- Light Energy Tower
        [FourCC("I07R")] = cost(0, 0), -- Demonic Altar
        [FourCC("I04P")] = cost(0, 0), -- Tribal Totem
        [FourCC("I06W")] = cost(0, 0), -- Stampede Tower
        [FourCC("I06I")] = cost(0, 0), -- Elephant Foot
        [RANDOM_ULTIMATE_RECIPE] = cost(0, 0), -- Randomize Ultimate Tower recipe
        [RANDOM_ULTIMATE_ITEM] = cost(0, 0) -- Old random ultimate tower result item
    }

    local builderToTitan = {
        [FourCC("I007")] = FourCC("I01F"), -- Eye of the Ocean -> Watcher's Eye
        [FourCC("I001")] = FourCC("I017"), -- Healing Wards
        [FourCC("I002")] = FourCC("I01G"), -- Potion of Recovery
        [FourCC("I005")] = FourCC("I01I"), -- Staff of Teleportation
        [FourCC("I004")] = FourCC("I018"), -- Scroll of the Beast
        [FourCC("I009")] = FourCC("I03Q"), -- Trident
        [FourCC("I00A")] = FourCC("I03R"), -- Armored Scales
        [FourCC("I060")] = FourCC("I000"), -- Shadowstone
        [FourCC("I06C")] = FourCC("I01H")  -- Wand of the Wind
    }

    local titanToBuilder = {
        [FourCC("I01F")] = FourCC("I007"), -- Watcher's Eye -> Eye of the Ocean
        [FourCC("I017")] = FourCC("I001"), -- Healing Wards
        [FourCC("I01G")] = FourCC("I002"), -- Potion of Recovery
        [FourCC("I01I")] = FourCC("I005"), -- Staff of Teleportation
        [FourCC("I018")] = FourCC("I004"), -- Scroll of the Beast
        [FourCC("I03Q")] = FourCC("I009"), -- Trident
        [FourCC("I03R")] = FourCC("I00A"), -- Armored Scales
        [FourCC("I000")] = FourCC("I060"), -- Shadowstone
        [FourCC("I01H")] = FourCC("I06C")  -- Wand of the Wind
    }

    local ultimateTowerItems = {
        FourCC("I00J"), -- Sacred Seashell
        FourCC("I00Y"), -- Heavy Cannon
        FourCC("I03A"), -- Methane Machine
        FourCC("I00K"), -- Sludge Launcher
        FourCC("I00N"), -- Tropical Glyph
        FourCC("I00T"), -- Giant Hermit
        FourCC("I00U"), -- Crab Mutant
        FourCC("I00V"), -- Catapult
        FourCC("I011"), -- Whirlpool
        FourCC("I00W"), -- Stasis Totem
        FourCC("I00O"), -- Magic Pearl
        FourCC("I00Z"), -- Magic Tower
        FourCC("I010"), -- Bombard
        FourCC("I00X"), -- Magic Mushroom
        FourCC("I013"), -- Aura Tree
        FourCC("I014"), -- Spell Well
        FourCC("I015"), -- Spiny Protector
        FourCC("I01A"), -- Rapid Fire Tower
        FourCC("I01B"), -- Deepfreeze
        FourCC("I01C"), -- Energy Spire
        FourCC("I01K"), -- Mutation Tower
        FourCC("I01L"), -- Toxic Tower
        FourCC("I02Y"), -- Demolisher Totem
        FourCC("I04T"), -- Replicator
        FourCC("I05A"), -- Box of Gaia
        FourCC("I058"), -- Box of Pyros
        FourCC("I059"), -- Box of Storms
        FourCC("I057"), -- High Energy Conduit
        FourCC("I04O"), -- Ice Palace
        FourCC("I05T"), -- Egg Sack
        FourCC("I04J"), -- Fireworks Launcher
        FourCC("I04L"), -- Tavern
        FourCC("I056"), -- Well of Power
        FourCC("I06D"), -- Island Bloom
        FourCC("I01M"), -- Light Energy Tower
        FourCC("I07R"), -- Demonic Altar
        FourCC("I04P"), -- Tribal Totem
        FourCC("I06W"), -- Stampede Tower
        FourCC("I06I")  -- Elephant Foot
    }

    local recipes = {
        -- Hidden item upgrades / shared old RecipeSYS behavior.
        { result = FourCC("I00D"), components = { FourCC("I03Q"), FourCC("I03Q") }, name = "Tridents" }, -- I03Q titan Trident x2 -> I00D stacked Tridents
        { result = FourCC("I00B"), components = { FourCC("I000"), FourCC("I000") }, name = "Shadowstone" }, -- I000 titan Shadowstone x2 -> I00B stacked Shadowstone
        { result = FourCC("I042"), components = { FourCC("I03R"), FourCC("I03R") }, name = "Armor Scales" }, -- I03R titan Armored Scales x2 -> I042 stacked Armor Scales
        { result = FourCC("I03F"), components = { FourCC("I02S"), FourCC("I032") }, name = "Smith's Hammer" }, -- I02S Siren Scepter + I032 hammer component -> I03F Smith's Hammer

        -- Builder item recipes from old ItemRecipes.initBuilderItems.
        { result = FourCC("I048"), components = { FourCC("I00H"), FourCC("I04B") }, name = "Greater Troll Hands" }, -- I00H Troll Hands base + I04B upgrade component -> I048
        { result = FourCC("I046"), components = { FourCC("I00G"), FourCC("I049") }, name = "Greater Summoning Stone" }, -- I00G Summoning Stone base + I049 upgrade component -> I046
        { result = FourCC("I047"), components = { FourCC("I00I"), FourCC("I04A") }, name = "Greater Gnoll Luck" }, -- I00I Gnoll Luck base + I04A upgrade component -> I047
        { result = FourCC("I05D"), components = { FourCC("I04F"), FourCC("I04G") }, name = "Shield of Fortitude" }, -- I04F Runed Bracers + I04G Shield of Might -> I05D
        { result = FourCC("I020"), components = { FourCC("I022"), FourCC("I022"), FourCC("I022"), FourCC("I047"), FourCC("I023") }, name = "Ring of Shadows" }, -- I022 egg x3 + I047 Greater Gnoll Luck + I023 recipe -> I020
        { result = 0, components = { FourCC("I023") }, name = "Destroy Ring of Shadows recipe" }, -- I023 Ring of Shadows recipe marker, consumed if incomplete.
        { result = FourCC("I01X"), components = { FourCC("I022"), FourCC("I022"), FourCC("I009"), FourCC("I021") }, name = "Storm Hammer" }, -- I022 egg x2 + I009 Trident + I021 recipe -> I01X
        { result = 0, components = { FourCC("I021") }, name = "Destroy Storm Hammer recipe" }, -- I021 Storm Hammer recipe marker, consumed if incomplete.
        { result = FourCC("I025"), components = { FourCC("I022"), FourCC("I022"), FourCC("I005"), FourCC("I026") }, name = "Teleporter" }, -- I022 egg x2 + I005 Staff of Teleportation + I026 recipe -> I025
        { result = 0, components = { FourCC("I026") }, name = "Destroy Teleporter recipe" }, -- I026 Teleporter recipe marker, consumed if incomplete.
        { result = FourCC("I03P"), components = { FourCC("I022"), FourCC("I00A"), FourCC("I00A"), FourCC("I03S") }, name = "Shield of Will" }, -- I022 egg + I00A Armored Scales x2 + I03S recipe -> I03P
        { result = 0, components = { FourCC("I03S") }, name = "Destroy Shield of Will recipe" }, -- I03S Shield of Will recipe marker, consumed if incomplete.
        { result = FourCC("I04G"), components = { FourCC("I022"), FourCC("I03P"), FourCC("I04H") }, name = "Shield of Might" }, -- I022 egg + I03P Shield of Will + I04H recipe -> I04G
        { result = 0, components = { FourCC("I04H") }, name = "Destroy Shield of Might recipe" }, -- I04H Shield of Might recipe marker, consumed if incomplete.
        { result = FourCC("I04F"), components = { FourCC("I022"), FourCC("I00A"), FourCC("I04I") }, name = "Runed Bracers" }, -- I022 egg + I00A Armored Scales + I04I recipe -> I04F
        { result = 0, components = { FourCC("I04I") }, name = "Destroy Runed Bracers recipe" }, -- I04I Runed Bracers recipe marker, consumed if incomplete.
        { result = FourCC("I04Y"), components = { FourCC("I00Q"), FourCC("I04W"), FourCC("I022") }, name = "Great Turtle Summons" }, -- I00Q Turtle Summons base + I04W recipe + I022 egg -> I04Y
        { result = 0, components = { FourCC("I04W") }, name = "Destroy Great Turtle recipe" }, -- I04W Great Turtle Summons recipe marker, consumed if incomplete.
        { result = FourCC("I04R"), components = { FourCC("I05W"), FourCC("I05V"), FourCC("I004"), FourCC("I022"), FourCC("I009") }, name = "Solar Blade" }, -- I05W recipe + I05V Sword of the Magistrate + I004 Scroll of the Beast + I022 egg + I009 Trident -> I04R
        { result = 0, components = { FourCC("I05W") }, name = "Destroy Solar Blade recipe" }, -- I05W Solar Blade recipe marker, consumed if incomplete.
        { result = FourCC("I072"), components = { FourCC("I071"), FourCC("I04R") }, name = "Charged Wings of the White Tree" }, -- I071 Wings of the White Tree + I04R Solar Blade -> I072
        { result = FourCC("I05V"), components = { FourCC("I04S"), FourCC("I022"), FourCC("I022"), FourCC("I009") }, name = "Sword of the Magistrate" }, -- I04S recipe + I022 egg x2 + I009 Trident -> I05V
        { result = 0, components = { FourCC("I04S") }, name = "Destroy Sword recipe" }, -- I04S Sword of the Magistrate recipe marker, consumed if incomplete.
        { result = FourCC("I05X"), components = { FourCC("I05G"), FourCC("I022"), FourCC("I005") }, name = "Mystic Stone" }, -- I05G recipe + I022 egg + I005 Staff of Teleportation -> I05X
        { result = 0, components = { FourCC("I05G") }, name = "Destroy Mystic Stone recipe" } -- I05G Mystic Stone recipe marker, consumed if incomplete.
    }

    local resultRecipe = {}
    local recipeByRecipeItem = {}

    local function playerData(unit)
        return unit and PlayerData.get(GetOwningPlayer(unit)) or nil
    end

    local function isTitanSide(unit)
        local data = playerData(unit)
        return data and (data:class() == PlayerData.CLASS_TITAN or data:class() == PlayerData.CLASS_MINION)
    end

    local function isBuilderSide(unit)
        local data = playerData(unit)
        return data and data:class() == PlayerData.CLASS_DEFENDER
    end

    local function shouldSeeBuilderShop(playerData)
        if not playerData or playerData:hasLeft() then
            return false
        end
        if playerData:class() == PlayerData.CLASS_TITAN or playerData:class() == PlayerData.CLASS_MINION then
            return true
        end
        return playerData:isObserver() and playerData:observeTeam() == "titan"
    end

    local function canUseNeutralPassiveShop(playerData)
        if not playerData or playerData:hasLeft() then
            return false
        end
        return playerData:class() == PlayerData.CLASS_DEFENDER or playerData:class() == PlayerData.CLASS_OBSERVER
    end

    local function shouldBePassiveToNeutralPassive(playerData)
        if not playerData or playerData:hasLeft() then
            return false
        end
        return playerData:class() == PlayerData.CLASS_DEFENDER or
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION or
            playerData:class() == PlayerData.CLASS_OBSERVER
    end

    local function refreshNeutralPassiveShopAlliance(playerData)
        local neutral = Player(PLAYER_NEUTRAL_PASSIVE)
        local player = playerData:player()
        local shopAllied = canUseNeutralPassiveShop(playerData)
        local passiveAllied = shouldBePassiveToNeutralPassive(playerData)

        SetPlayerAlliance(neutral, player, ALLIANCE_PASSIVE, passiveAllied)
        SetPlayerAlliance(neutral, player, ALLIANCE_HELP_REQUEST, shopAllied)
        SetPlayerAlliance(neutral, player, ALLIANCE_HELP_RESPONSE, shopAllied)
        SetPlayerAlliance(neutral, player, ALLIANCE_SHARED_XP, shopAllied)
        SetPlayerAlliance(neutral, player, ALLIANCE_SHARED_SPELLS, shopAllied)
        SetPlayerAlliance(player, neutral, ALLIANCE_PASSIVE, passiveAllied)
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

    local function inventoryItems(unit)
        local items = {}
        local slot = 0

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item then
                items[#items + 1] = item
            end
            slot = slot + 1
        end

        return items
    end

    local function itemTypeCounts(unit)
        local counts = {}
        local items = inventoryItems(unit)
        local i = 1

        while i <= #items do
            local item = items[i]
            local itemId = GetItemTypeId(item)
            counts[itemId] = (counts[itemId] or 0) + 1
            i = i + 1
        end

        return counts
    end

    local function playerGold(player)
        return GetPlayerState(player, PLAYER_STATE_RESOURCE_GOLD)
    end

    local function setPlayerGold(player, amount)
        SetPlayerState(player, PLAYER_STATE_RESOURCE_GOLD, R2I(amount))
    end

    local function playerLumber(player)
        return GetPlayerState(player, PLAYER_STATE_RESOURCE_LUMBER)
    end

    local function setPlayerLumber(player, amount)
        SetPlayerState(player, PLAYER_STATE_RESOURCE_LUMBER, R2I(amount))
    end

    local function itemGoldCost(itemId)
        local manual = ITEM_COSTS[itemId]
        if manual then
            return manual.gold or 0
        end
        return ItemExtras.itemGoldCost(itemId)
    end

    local function itemLumberCost(itemId)
        local manual = ITEM_COSTS[itemId]
        if manual then
            return manual.lumber or 0
        end
        return ItemExtras.itemLumberCost(itemId)
    end

    local function addPlanItemCost(plan, itemId)
        plan.goldCost = plan.goldCost + itemGoldCost(itemId)
        plan.lumberCost = plan.lumberCost + itemLumberCost(itemId)
    end

    local function canPayPlan(player, plan)
        return plan.goldCost <= playerGold(player) and plan.lumberCost <= playerLumber(player)
    end

    local function spendPlan(player, plan)
        setPlayerGold(player, playerGold(player) - plan.goldCost)
        setPlayerLumber(player, playerLumber(player) - plan.lumberCost)
    end

    local function refundItemCost(player, itemId)
        setPlayerGold(player, playerGold(player) + itemGoldCost(itemId))
        setPlayerLumber(player, playerLumber(player) + itemLumberCost(itemId))
    end

    local function costText(gold, lumber)
        if lumber and lumber > 0 then
            return "|cffffcc00" .. I2S(gold or 0) .. " gold|r and |cff80ff80" .. I2S(lumber) .. " lumber|r"
        end
        return "|cffffcc00" .. I2S(gold or 0) .. " gold|r"
    end

    local function collectSources(unit)
        local sources = {}
        local items = inventoryItems(unit)
        local i = 1

        while i <= #items do
            local item = items[i]
            local itemId = GetItemTypeId(item)
            sources[itemId] = sources[itemId] or {}
            sources[itemId][#sources[itemId] + 1] = item
            i = i + 1
        end

        return sources
    end

    local function takeExisting(plan, itemId)
        local list = plan.sources[itemId]
        local item = nil

        if not list or #list == 0 then
            return false
        end

        item = list[#list]
        list[#list] = nil
        plan.consumed[#plan.consumed + 1] = item
        return true
    end

    local function canCraft(unit, recipe)
        local counts = itemTypeCounts(unit)
        local i = 1

        while i <= #recipe.components do
            local itemId = recipe.components[i]
            if (counts[itemId] or 0) <= 0 then
                return false
            end
            counts[itemId] = counts[itemId] - 1
            i = i + 1
        end

        return true
    end

    local function removeOneItem(unit, itemId)
        local slot = 0

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item and GetItemTypeId(item) == itemId then
                RemoveItem(item)
                return true
            end
            slot = slot + 1
        end

        return false
    end

    local function craft(unit, recipe)
        local i = 1

        if not canCraft(unit, recipe) then
            return false
        end

        while i <= #recipe.components do
            removeOneItem(unit, recipe.components[i])
            i = i + 1
        end

        if recipe.result and recipe.result ~= 0 then
            UnitAddItemById(unit, recipe.result)
            DisplayTextToPlayer(GetOwningPlayer(unit), 0, 0, "|cff99b4d1Created |cff3399ff" .. itemName(recipe.result) .. "|cff99b4d1.|r")
        end

        return true
    end

    local function isUltimateTowerItem(itemId)
        local i = 1

        while i <= #ultimateTowerItems do
            if ultimateTowerItems[i] == itemId then
                return true
            end
            i = i + 1
        end

        return false
    end

    local function findUltimateTowerItem(unit)
        local slot = 0

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item and isUltimateTowerItem(GetItemTypeId(item)) then
                return item
            end
            slot = slot + 1
        end

        return nil
    end

    local function findItemById(unit, itemId)
        local slot = 0

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item and GetItemTypeId(item) == itemId then
                return item
            end
            slot = slot + 1
        end

        return nil
    end

    local function convertVariant(unit, item)
        local itemId = GetItemTypeId(item)
        local replacement = nil
        local charges = GetItemCharges(item)
        local newItem = nil

        if isTitanSide(unit) then
            replacement = builderToTitan[itemId]
        elseif isBuilderSide(unit) then
            replacement = titanToBuilder[itemId]
        end

        if not replacement then
            return false
        end

        RemoveItem(item)
        newItem = CreateItem(replacement, 0.0, 0.0)
        UnitAddItem(unit, newItem)
        if charges > 1 then
            SetItemCharges(newItem, charges)
        end
        return true
    end

    local function randomUltimateTower(unit, item)
        local player = unit and GetOwningPlayer(unit) or nil
        local itemId = item and GetItemTypeId(item) or 0
        local ultimateItem = nil
        local eggItem = nil
        local plan = {
            goldCost = 0,
            lumberCost = 0
        }
        local oldTower = 0
        local result = nil

        if not unit or not item or (itemId ~= RANDOM_ULTIMATE_RECIPE and itemId ~= RANDOM_ULTIMATE_ITEM) then
            return false
        end

        ultimateItem = findUltimateTowerItem(unit)
        if not ultimateItem then
            refundItemCost(player, itemId)
            RemoveItem(item)
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Bring an ultimate tower to reroll it.|r")
            return true
        end

        if itemId == RANDOM_ULTIMATE_RECIPE then
            eggItem = findItemById(unit, EGG_COMPONENT)
            if not eggItem then
                addPlanItemCost(plan, EGG_COMPONENT)
                if not canPayPlan(player, plan) then
                    refundItemCost(player, itemId)
                    RemoveItem(item)
                    DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Not enough resources to reroll an ultimate tower. Need " .. costText(plan.goldCost, plan.lumberCost) .. "|cff99b4d1.|r")
                    return true
                end
            end
        end

        oldTower = GetItemTypeId(ultimateItem)
        RemoveItem(ultimateItem)
        if eggItem then
            RemoveItem(eggItem)
        elseif itemId == RANDOM_ULTIMATE_RECIPE then
            spendPlan(player, plan)
        end
        RemoveItem(item)
        result = ultimateTowerItems[GetRandomInt(1, #ultimateTowerItems)]
        if #ultimateTowerItems > 1 then
            while result == oldTower do
                result = ultimateTowerItems[GetRandomInt(1, #ultimateTowerItems)]
            end
        end
        if result then
            UnitAddItemById(unit, result)
            DisplayTextToPlayer(GetOwningPlayer(unit), 0, 0, "|cff99b4d1Random ultimate tower: |cff3399ff" .. itemName(result) .. "|cff99b4d1.|r")
        end
        return true
    end

    local function autoComplete(unit)
        local candidates = recipes
        local changed = false
        local i = 1

        while i <= #candidates do
            if craft(unit, candidates[i]) then
                changed = true
                i = 1
            else
                i = i + 1
            end
        end

        return changed
    end

    local ensurePlannedItem

    local function ensurePlannedRecipe(plan, recipe)
        local i = 1

        while i <= #recipe.components do
            if not ensurePlannedItem(plan, recipe.components[i]) then
                return false
            end
            i = i + 1
        end

        return true
    end

    ensurePlannedItem = function(plan, itemId)
        local recipe = resultRecipe[itemId]

        if plan.paidRecipeItemId == itemId and not plan.paidRecipeItemUsed then
            plan.paidRecipeItemUsed = true
            return true
        end

        if takeExisting(plan, itemId) then
            return true
        end

        if recipe then
            return ensurePlannedRecipe(plan, recipe)
        end

        addPlanItemCost(plan, itemId)
        return true
    end

    local function applyConsumed(plan)
        local i = 1
        local applied = {}

        while i <= #plan.consumed do
            local item = plan.consumed[i]
            local id = item and GetHandleId(item) or 0
            if id ~= 0 and not applied[id] then
                applied[id] = true
                RemoveItem(item)
            end
            i = i + 1
        end
    end

    local function inventoryCanReceiveResult(unit, plan)
        return ItemExtras.hasFreeSlot(unit) or #plan.consumed > 0
    end

    local function craftPlanned(unit, recipe)
        local player = GetOwningPlayer(unit)
        local plan = {
            sources = collectSources(unit),
            consumed = {},
            goldCost = 0,
            lumberCost = 0
        }

        if not ensurePlannedRecipe(plan, recipe) then
            return false
        end
        if not canPayPlan(player, plan) then
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Not enough resources for |cff3399ff" .. itemName(recipe.result) .. "|cff99b4d1. Need " .. costText(plan.goldCost, plan.lumberCost) .. "|cff99b4d1.|r")
            return false
        end
        if not inventoryCanReceiveResult(unit, plan) then
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Inventory full.|r")
            return false
        end

        applyConsumed(plan)
        spendPlan(player, plan)
        UnitAddItemById(unit, recipe.result)
        DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Created |cff3399ff" .. itemName(recipe.result) .. "|cff99b4d1.|r")
        return true
    end

    local function craftBoughtRecipe(unit, recipe, recipeItem)
        local player = GetOwningPlayer(unit)
        local recipeItemId = recipeItem and GetItemTypeId(recipeItem) or 0
        local plan = {
            sources = collectSources(unit),
            consumed = {},
            goldCost = 0,
            lumberCost = 0,
            paidRecipeItemId = recipeItemId,
            paidRecipeItemUsed = false
        }

        if not recipeItem or not recipe or not recipe.result or recipe.result == 0 then
            return false
        end

        if not takeExisting(plan, recipeItemId) then
            plan.consumed[#plan.consumed + 1] = recipeItem
        end
        if not ensurePlannedRecipe(plan, recipe) or not canPayPlan(player, plan) or not inventoryCanReceiveResult(unit, plan) then
            refundItemCost(player, recipeItemId)
            RemoveItem(recipeItem)
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Failed to create |cff3399ff" .. itemName(recipe.result) .. "|cff99b4d1. Refunding " .. costText(itemGoldCost(recipeItemId), itemLumberCost(recipeItemId)) .. "|cff99b4d1.|r")
            return false
        end

        applyConsumed(plan)
        spendPlan(player, plan)
        UnitAddItemById(unit, recipe.result)
        DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Created |cff3399ff" .. itemName(recipe.result) .. "|cff99b4d1.|r")
        return true
    end

    local function craftBoughtResult(unit, recipe, soldItem)
        local player = GetOwningPlayer(unit)
        local soldItemId = soldItem and GetItemTypeId(soldItem) or 0
        local plan = {
            sources = collectSources(unit),
            consumed = {},
            goldCost = 0,
            lumberCost = 0
        }

        if not soldItem or not recipe or not recipe.result or recipe.result == 0 then
            return false
        end

        refundItemCost(player, soldItemId)
        if not takeExisting(plan, soldItemId) then
            plan.consumed[#plan.consumed + 1] = soldItem
        end
        if not ensurePlannedRecipe(plan, recipe) or not canPayPlan(player, plan) or not inventoryCanReceiveResult(unit, plan) then
            RemoveItem(soldItem)
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Failed to create |cff3399ff" .. itemName(recipe.result) .. "|cff99b4d1.|r")
            return false
        end

        applyConsumed(plan)
        spendPlan(player, plan)
        UnitAddItemById(unit, recipe.result)
        DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Created |cff3399ff" .. itemName(recipe.result) .. "|cff99b4d1.|r")
        return true
    end

    local function process(unit, item)
        local id = item and GetHandleId(item) or 0
        local itemId = item and GetItemTypeId(item) or 0
        local loops = 0

        if busy or not unit or not item or id == 0 or processed[id] then
            return
        end

        processed[id] = true
        GameTimer.after(0.25, function()
            processed[id] = nil
        end)

        busy = true
        if randomUltimateTower(unit, item) then
            -- handled by ultimate tower reroll
        elseif recipeByRecipeItem[itemId] then
            craftBoughtRecipe(unit, recipeByRecipeItem[itemId], item)
        else
            convertVariant(unit, item)
        end
        -- Recipe creation and variant conversion add items while busy, so
        -- their nested pickup events cannot combine the newly created result.
        while loops < 8 and autoComplete(unit) do
            loops = loops + 1
        end
        ItemStacking.mergeAll(unit)
        busy = false
    end

    local function onPickup()
        process(GetTriggerUnit(), GetManipulatedItem())
    end

    local function onSell()
        local buyer = GetBuyingUnit()
        local sold = GetSoldItem()

        GameTimer.after(0.0, function()
            local itemId = sold and GetItemTypeId(sold) or 0
            local recipe = recipeByRecipeItem[itemId]

            if randomUltimateTower(buyer, sold) then
                return
            elseif recipe then
                craftBoughtRecipe(buyer, recipe, sold)
            elseif resultRecipe[itemId] then
                craftBoughtResult(buyer, resultRecipe[itemId], sold)
            else
                process(buyer, sold)
            end

            -- Recheck the inventory after the shop transaction has settled.
            -- Do not depend on the sold handle: crafting may have replaced it.
            if buyer and GetUnitTypeId(buyer) ~= 0 then
                busy = true
                autoComplete(buyer)
                ItemStacking.mergeAll(buyer)
                busy = false
            end
        end)
    end

    local function revealBuilderShop()
        local rect = rawget(_G, "gg_rct_BuilderShop")
        local list = nil
        local i = 0

        list = PlayerData.allWithFake()
        while i < list:size() do
            local data = list:at(i)
            local id = data:id()
            refreshNeutralPassiveShopAlliance(data)
            if rect and shouldSeeBuilderShop(data) then
                if not vision[id] then
                    vision[id] = CreateFogModifierRect(data:player(), FOG_OF_WAR_VISIBLE, rect, false, false)
                    FogModifierStart(vision[id])
                end
                SetFogStateRect(data:player(), FOG_OF_WAR_VISIBLE, rect, false)
            elseif vision[id] then
                FogModifierStop(vision[id])
                DestroyFogModifier(vision[id])
                vision[id] = nil
            end
            i = i + 1
        end
        list:destroy()
    end

    function BuilderShop.tryCombine(unit)
        return autoComplete(unit)
    end

    function BuilderShop.itemGoldCost(itemId)
        return itemGoldCost(itemId)
    end

    function BuilderShop.itemLumberCost(itemId)
        return itemLumberCost(itemId)
    end

    function BuilderShop.recipeForResult(itemId)
        return resultRecipe[itemId]
    end

    function BuilderShop.buyItemForUnit(unit, itemId)
        local player = unit and GetOwningPlayer(unit) or nil
        local recipe = resultRecipe[itemId]
        local goldCost = 0
        local lumberCost = 0

        if not unit or not itemId or itemId == 0 then
            return false
        end

        if recipe then
            return craftPlanned(unit, recipe)
        end

        goldCost = itemGoldCost(itemId)
        lumberCost = itemLumberCost(itemId)
        if goldCost > playerGold(player) or lumberCost > playerLumber(player) then
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Not enough resources for |cff3399ff" .. itemName(itemId) .. "|cff99b4d1. Need " .. costText(goldCost, lumberCost) .. "|cff99b4d1.|r")
            return false
        end
        if not ItemExtras.hasFreeSlot(unit) then
            DisplayTextToPlayer(player, 0, 0, "|cff99b4d1Inventory full.|r")
            return false
        end

        setPlayerGold(player, playerGold(player) - goldCost)
        setPlayerLumber(player, playerLumber(player) - lumberCost)
        process(unit, UnitAddItemById(unit, itemId))
        return true
    end

    local i = 1
    while i <= #recipes do
        local recipe = recipes[i]
        local destroyItemId = nil

        if recipe.result and recipe.result ~= 0 then
            resultRecipe[recipe.result] = recipe
        elseif #recipe.components == 1 then
            destroyItemId = recipe.components[1]
            local j = 1
            while j <= #recipes do
                local candidate = recipes[j]
                local k = 1
                while candidate.result and candidate.result ~= 0 and k <= #candidate.components do
                    if candidate.components[k] == destroyItemId then
                        recipeByRecipeItem[destroyItemId] = candidate
                        k = #candidate.components
                        j = #recipes
                    end
                    k = k + 1
                end
                j = j + 1
            end
        end
        i = i + 1
    end

    local pickupTrigger = CreateTrigger()
    local sellTrigger = CreateTrigger()
    local playerIndex = 0
    local sellRegistered = {}

    local function registerSellEvent(playerId)
        if not sellRegistered[playerId] then
            sellRegistered[playerId] = true
            TriggerRegisterPlayerUnitEvent(sellTrigger, Player(playerId), EVENT_PLAYER_UNIT_SELL_ITEM, nil)
        end
    end

    while playerIndex < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(pickupTrigger, Player(playerIndex), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
        registerSellEvent(playerIndex)
        playerIndex = playerIndex + 1
    end
    registerSellEvent(PLAYER_NEUTRAL_PASSIVE)

    local function guarded(callback)
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(callback)
        else
            callback()
        end
    end

    TriggerAddAction(pickupTrigger, function() guarded(onPickup) end)
    TriggerAddAction(sellTrigger, function() guarded(onSell) end)
    GameTimer.every(0.5, revealBuilderShop)

    BuilderShop.pickupTrigger = pickupTrigger
    BuilderShop.BuyItemForUnit = BuilderShop.buyItemForUnit

    _G.BuilderShop = BuilderShop
    _G.BuyBuilderItemForUnit = BuilderShop.buyItemForUnit
end)

if Debug and Debug.endFile then Debug.endFile() end
