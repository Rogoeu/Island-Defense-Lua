if Debug and Debug.beginFile then Debug.beginFile("Systems/UnitSpawner") end

OnInit("UnitSpawner", function(import)
    import.strict("ObjectIds")
    import.strict("GameTimer")
    import.strict("PlayerData")
    import.strict("RaceData")
    import.strict("GameSettings")
    import.strict("Cosmetics")
    import.strict("MapAreas")

    local units = {}
    local pickShopsPopulated = false

    local UnitSpawner = {
        minionLevel = 2,
        units = units,
        ids = {
            DEFENDER_PICK_BASER = ObjectIds.register("DEFENDER_PICK_BASER_ID", "n01G"),
            DEFENDER_PICK_SUPPORT = ObjectIds.register("DEFENDER_PICK_SUPPORT_ID", "n00X"),
            DEFENDER_PICK_RANDOM = ObjectIds.register("DEFENDER_PICK_RANDOM_ID", "n025"),
            DEFENDER_PICK_IN_HOUSE = ObjectIds.register("DEFENDER_PICK_IN_HOUSE_ID", "n01Z"),
            TITAN_PICK_HARD = ObjectIds.register("TITAN_PICK_HARD_ID", "n00Z"),
            TITAN_PICK_EASY = ObjectIds.register("TITAN_PICK_EASY_ID", "n00M"),
            ARTIFACTS_PAGE_ONE = ObjectIds.register("ARTIFACTS_PAGE_ONE_ID", "n01W"),
            CONSUMABLES_PAGE_ONE = ObjectIds.register("CONSUMABLES_PAGE_ONE_ID", "n01U"),
            RECIPES_PAGE_ONE = ObjectIds.register("RECIPES_PAGE_ONE_ID", "n01A"),
            RECIPES_PAGE_TWO = ObjectIds.register("RECIPES_PAGE_TWO_ID", "n01B"),
            RECIPES_PAGE_ONE_TIER3 = ObjectIds.register("RECIPES_PAGE_ONE_TIER3_ID", "n01M"),
            RECIPES_PAGE_TWO_TIER3 = ObjectIds.register("RECIPES_PAGE_TWO_TIER3_ID", "n01N"),
            BUILDER_SHOP_ITEMS = ObjectIds.register("BUILDER_SHOP_ITEMS_ID", "n00J"),
            BUILDER_SHOP_INVENTORY = ObjectIds.register("BUILDER_SHOP_INVENTORY_ID", "n00L"),
            BUILDER_SHOP_SHOPPING_LIST = ObjectIds.register("BUILDER_SHOP_SHOPPING_LIST_ID", "n00Y"),
            RECOMMENDED_ITEMS = ObjectIds.register("RECOMMENDED_ITEMS_ID", "n022"),
            EXP_STONE = ObjectIds.register("EXP_STONE_ID", "h058"),
            TITAN_PUNISH_CAGE_PUNISH = ObjectIds.register("TITAN_PUNISH_CAGE_PUNISH_ID", "h061"),
            TITAN_PUNISH_CAGE_RESEARCH = ObjectIds.register("TITAN_PUNISH_CAGE_RESEARCH_ID", "h062"),
            TITAN_SPELL_WELL = ObjectIds.register("TITAN_SPELL_WELL_ID", "h001"),
            RACE_PICKER = ObjectIds.register("RACE_PICKER_ID", "n00K"),
            RANDOM_RACE_ITEM = ObjectIds.register("RANDOM_RACE_ITEM_ID", "I006")
        }
    }

    local function neutralAggressive()
        return Player(PLAYER_NEUTRAL_AGGRESSIVE)
    end

    local function neutralPassive()
        return Player(PLAYER_NEUTRAL_PASSIVE)
    end

    local function createTracked(name, owner, unitId, x, y, facing)
        if units[name] then
            return units[name]
        end

        x, y, facing = MapAreas.point(name, x, y, facing)
        local unit = CreateUnit(owner, unitId, x, y, facing)
        units[name] = unit
        return unit
    end

    local function findExistingUnit(unitId)
        local group = CreateGroup()
        local unit = nil
        local found = nil

        GroupEnumUnitsInRect(group, GetWorldBounds(), nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if not found and GetUnitTypeId(unit) == unitId then
                found = unit
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return found
    end

    local function trackExistingOrCreate(name, owner, unitId, x, y, facing)
        local existing = nil

        if units[name] then
            return units[name]
        end

        existing = findExistingUnit(unitId)
        if existing then
            SetUnitOwner(existing, owner, false)
            if MapAreas.name() ~= "Classic" then
                x, y, facing = MapAreas.point(name, x, y, facing)
                SetUnitPosition(existing, x, y)
                SetUnitFacing(existing, facing)
            end
            units[name] = existing
            return existing
        end

        return createTracked(name, owner, unitId, x, y, facing)
    end

    local function setOwnerIfPresent(name, player)
        if units[name] then
            SetUnitOwner(units[name], player, true)
        end
    end

    local function removeAbilityIfPresent(name, abilityId)
        if units[name] then
            UnitRemoveAbility(units[name], abilityId)
        end
    end

    local function removeTitanShopRallyPoints()
        -- Ownership can change when a new Titan is selected. Reapply the old
        -- no-rally setup after that transfer so the buttons stay unavailable.
        removeAbilityIfPresent("TITAN_SPELL_WELL", FourCC("ARal"))
        removeAbilityIfPresent("TITAN_PUNISH_CAGE_PUNISH", FourCC("ARal"))
        removeAbilityIfPresent("TITAN_PUNISH_CAGE_RESEARCH", FourCC("ARal"))
    end

    local function gameElapsed()
        if rawget(_G, "Game") and Game.currentGameElapsed then
            return Game.currentGameElapsed()
        end
        return 0.0
    end

    local function applyEquippedCosmetics(playerData, unit)
        Cosmetics.applySpawnCosmetics(playerData:player(), unit)

        -- Freshly created heroes can finish their object-data initialization one
        -- tick after CreateUnit. Reapply to keep cosmetic abilities persistent.
        GameTimer.after(0.0, function()
            if playerData:unit() == unit and GetUnitTypeId(unit) ~= 0 then
                Cosmetics.applySpawnCosmetics(playerData:player(), unit)
            end
        end)
    end

    local function clampLevel(level, maxLevel)
        if level < 1 then
            return 1
        end
        if maxLevel > 0 and level > maxLevel then
            return maxLevel
        end
        return level
    end

    function UnitSpawner.get(name)
        return units[name]
    end

    function UnitSpawner.has(name)
        return units[name] ~= nil
    end

    function UnitSpawner.remove(name)
        local unit = units[name]
        if unit then
            RemoveUnit(unit)
            units[name] = nil
            return true
        end
        return false
    end

    function UnitSpawner.track(name, unit)
        units[name] = unit
        return unit
    end

    function UnitSpawner.clearCore()
        local names = {}
        local name = nil
        local i = 1

        for name in pairs(units) do
            names[#names + 1] = name
        end
        table.sort(names)
        while i <= #names do
            name = names[i]
            local unit = units[name]
            if unit then
                RemoveUnit(unit)
            end
            units[name] = nil
            i = i + 1
        end
    end

    function UnitSpawner.clearPlayerUnit(playerData)
        local unit = playerData:unit()
        if unit then
            RemoveUnit(unit)
            playerData:setUnit(nil)
            return true
        end
        return false
    end

    function UnitSpawner.clearPicker(playerData)
        local unit = playerData:picker()
        if unit then
            UnitSpawner.releasePlayerCamera(playerData)
            RemoveUnit(unit)
            playerData:setPicker(nil)
            return true
        end
        return false
    end

    function UnitSpawner.clearPlayerUnits()
        local list = PlayerData.all()
        local i = 0
        while i < list:size() do
            UnitSpawner.clearPlayerUnit(list:at(i))
            UnitSpawner.clearPicker(list:at(i))
            i = i + 1
        end
        list:destroy()
    end

    function UnitSpawner.ensureAbility(unit, abilityId)
        if GetUnitAbilityLevel(unit, abilityId) <= 0 then
            UnitAddAbility(unit, abilityId)
        end
    end

    function UnitSpawner.setHeroLevel(unit, level)
        if unit and IsUnitType(unit, UNIT_TYPE_HERO) and level and level > 1 then
            SetHeroLevel(unit, level, false)
        end
    end

    function UnitSpawner.titanStartingLevel()
        return clampLevel(GameSettings.getInt("TITAN_START_LEVEL"), 0)
    end

    function UnitSpawner.minionStartingLevel()
        local base = GameSettings.getInt("MINION_START_LEVEL")
        local interval = GameSettings.getReal("MINION_START_LEVEL_INTERVAL_SECONDS")
        local maxLevel = GameSettings.getInt("MINION_START_LEVEL_MAX")
        local bonus = 0

        if interval > 0 then
            bonus = R2I(gameElapsed() / interval)
        end

        return clampLevel(base + bonus, maxLevel)
    end

    function UnitSpawner.spawnSpellWell()
        if units.TITAN_SPELL_WELL then
            return units.TITAN_SPELL_WELL
        end

        local well = createTracked("TITAN_SPELL_WELL", neutralAggressive(), UnitSpawner.ids.TITAN_SPELL_WELL, -384, -512, 270)
        SetUnitState(well, UNIT_STATE_LIFE, GetUnitState(well, UNIT_STATE_LIFE) / 4)
        UnitRemoveAbility(well, FourCC("ARal"))
        UnitRemoveAbility(well, FourCC("Afih"))
        UnitRemoveAbility(well, FourCC("Afin"))
        UnitRemoveAbility(well, FourCC("Afio"))
        UnitRemoveAbility(well, FourCC("Afir"))
        UnitRemoveAbility(well, FourCC("Afiu"))
        UnitAddAbility(well, FourCC("Avul"))
        return well
    end

    function UnitSpawner.spawnExpStone(owner)
        local point = nil

        if units.EXP_STONE and GetUnitTypeId(units.EXP_STONE) ~= 0 then
            return units.EXP_STONE
        end

        local locations = MapAreas.config().expStones
        point = locations[GetRandomInt(1, #locations)]
        return createTracked("EXP_STONE", owner or neutralAggressive(), UnitSpawner.ids.EXP_STONE, point.x, point.y, 270)
    end

    function UnitSpawner.unlockTitanSpellWell()
        local well = units.TITAN_SPELL_WELL
        if well then
            UnitRemoveAbility(well, FourCC("Avul"))
            SetUnitInvulnerable(well, false)
        end
    end

    function UnitSpawner.spawnShops()
        createTracked("ARTIFACTS_PAGE_ONE", neutralAggressive(), UnitSpawner.ids.ARTIFACTS_PAGE_ONE, 128.0, -384.0, 270)
        createTracked("CONSUMABLES_PAGE_ONE", neutralAggressive(), UnitSpawner.ids.CONSUMABLES_PAGE_ONE, -128.0, -1024.0, 270)
        createTracked("RECIPES_PAGE_ONE", neutralAggressive(), UnitSpawner.ids.RECIPES_PAGE_ONE, -898.5, -444.0, 270)
        createTracked("RECIPES_PAGE_TWO", neutralAggressive(), UnitSpawner.ids.RECIPES_PAGE_TWO, -898.0, -388.5, 270)
        createTracked("RECIPES_PAGE_ONE_TIER3", neutralAggressive(), UnitSpawner.ids.RECIPES_PAGE_ONE_TIER3, -448.5, 128.0, 270)
        createTracked("RECIPES_PAGE_TWO_TIER3", neutralAggressive(), UnitSpawner.ids.RECIPES_PAGE_TWO_TIER3, -447.5, 128.0, 270)
        createTracked("TITAN_PUNISH_CAGE_PUNISH", neutralAggressive(), UnitSpawner.ids.TITAN_PUNISH_CAGE_PUNISH, -448.5, -1024.0, 270)
        createTracked("TITAN_PUNISH_CAGE_RESEARCH", neutralAggressive(), UnitSpawner.ids.TITAN_PUNISH_CAGE_RESEARCH, -447.5, -1024.0, 270)
        -- The old map removes Rally from both Punishment Centre buildings.
        removeAbilityIfPresent("TITAN_PUNISH_CAGE_PUNISH", FourCC("ARal"))
        removeAbilityIfPresent("TITAN_PUNISH_CAGE_RESEARCH", FourCC("ARal"))
        UnitSpawner.spawnExpStone(neutralAggressive())
        UnitSpawner.spawnBuilderShops()
        return units
    end

    function UnitSpawner.spawnBuilderShops()
        local rect = rawget(_G, "gg_rct_BuilderShop")
        local x = rect and GetRectCenterX(rect) or 672.0
        local y = rect and GetRectCenterY(rect) or 6432.0
        if MapAreas.name() ~= "Classic" then
            x, y = MapAreas.point("BUILDER_SHOP_CENTER", x, y, 270)
        end

        trackExistingOrCreate("BUILDER_SHOP_ITEMS", neutralPassive(), UnitSpawner.ids.BUILDER_SHOP_ITEMS, x - 128.0, y, 270)
        trackExistingOrCreate("BUILDER_SHOP_INVENTORY", neutralPassive(), UnitSpawner.ids.BUILDER_SHOP_INVENTORY, x, y, 270)
        trackExistingOrCreate("BUILDER_SHOP_SHOPPING_LIST", neutralPassive(), UnitSpawner.ids.BUILDER_SHOP_SHOPPING_LIST, x + 128.0, y, 270)
        removeAbilityIfPresent("BUILDER_SHOP_ITEMS", FourCC("ARal"))
        removeAbilityIfPresent("BUILDER_SHOP_INVENTORY", FourCC("ARal"))
        removeAbilityIfPresent("BUILDER_SHOP_SHOPPING_LIST", FourCC("ARal"))
        return units
    end

    function UnitSpawner.spawnPickShops()
        MapAreas.applyPickCameraBounds()
        createTracked("DEFENDER_PICK_BASER", Player(PLAYER_NEUTRAL_PASSIVE), UnitSpawner.ids.DEFENDER_PICK_BASER, -10752.0, 8704.0, 0)
        createTracked("DEFENDER_PICK_SUPPORT", Player(PLAYER_NEUTRAL_PASSIVE), UnitSpawner.ids.DEFENDER_PICK_SUPPORT, -10752.0, 8448.0, 0)
        createTracked("DEFENDER_PICK_RANDOM", Player(PLAYER_NEUTRAL_PASSIVE), UnitSpawner.ids.DEFENDER_PICK_RANDOM, -10336.6, 8717.4, 0)
        createTracked("TITAN_PICK_EASY", Player(PLAYER_NEUTRAL_PASSIVE), UnitSpawner.ids.TITAN_PICK_EASY, -10048.0, 10304.0, 270)
        createTracked("TITAN_PICK_HARD", Player(PLAYER_NEUTRAL_PASSIVE), UnitSpawner.ids.TITAN_PICK_HARD, -9856.0, 10304.0, 270)

        UnitRemoveAbility(units.DEFENDER_PICK_BASER, FourCC("Adef"))
        UnitRemoveAbility(units.DEFENDER_PICK_SUPPORT, FourCC("Adef"))
        UnitRemoveAbility(units.DEFENDER_PICK_RANDOM, FourCC("Adef"))
        return units
    end

    function UnitSpawner.populatePickShops()
        if pickShopsPopulated then
            return
        end

        local races = Races.all()
        local i = 1
        while i <= #races do
            local race = races[i]
            if race:itemId() ~= 0 then
                if race:class() == PlayerData.CLASS_TITAN then
                    AddItemToStock(units.TITAN_PICK_HARD, race:itemId(), 1, 1)
                elseif race:class() == PlayerData.CLASS_DEFENDER then
                    AddItemToStock(units.DEFENDER_PICK_BASER, race:itemId(), 1, 1)
                    AddItemToStock(units.DEFENDER_PICK_SUPPORT, race:itemId(), 1, 1)
                end
            end
            i = i + 1
        end

        AddItemToStock(units.TITAN_PICK_EASY, UnitSpawner.ids.RANDOM_RACE_ITEM, 1, 1)
        pickShopsPopulated = true
    end

    function UnitSpawner.clearPickShops()
        UnitSpawner.remove("DEFENDER_PICK_BASER")
        UnitSpawner.remove("DEFENDER_PICK_SUPPORT")
        UnitSpawner.remove("DEFENDER_PICK_RANDOM")
        UnitSpawner.remove("TITAN_PICK_EASY")
        UnitSpawner.remove("TITAN_PICK_HARD")
        pickShopsPopulated = false
    end

    function UnitSpawner.spawnPicker(playerData)
        UnitSpawner.clearPicker(playerData)

        local x, y, facing = UnitSpawner.pickerPosition(playerData)

        local unit = CreateUnit(playerData:player(), UnitSpawner.ids.RACE_PICKER, x, y, facing)
        playerData:setPicker(unit)
        return unit
    end

    function UnitSpawner.pickerPosition(playerData)
        if playerData:class() == PlayerData.CLASS_TITAN then
            return MapAreas.point("TITAN_PICKER", -9952.0, 10304.0, 270)
        end
        return MapAreas.point("DEFENDER_PICKER", -10752.0, 8704.0, 0)
    end

    function UnitSpawner.focusPickerCamera(playerData)
        MapAreas.applyPickCameraBounds(playerData:player())
        local x, y = UnitSpawner.pickerPosition(playerData)
        local picker = playerData:picker()

        PanCameraToTimedForPlayer(playerData:player(), x, y, 0)
        if picker and SetCameraTargetControllerNoZForPlayer then
            SetCameraTargetControllerNoZForPlayer(playerData:player(), picker, 0, 0, false)
        end
    end

    function UnitSpawner.releasePlayerCamera(playerData)
        if ResetToGameCameraForPlayer then
            ResetToGameCameraForPlayer(playerData:player(), 0)
        end

        -- ResetToGameCameraForPlayer also resets custom zoom. Restore it after the reset has taken effect.
        GameTimer.after(0.0, function()
            local cameraCommand = rawget(_G, "CameraCommand")
            if cameraCommand and cameraCommand.restorePlayer then
                cameraCommand.restorePlayer(playerData:player())
            end
        end)
    end

    function UnitSpawner.setTitanShopOwner(player)
        setOwnerIfPresent("TITAN_SPELL_WELL", player)
        setOwnerIfPresent("ARTIFACTS_PAGE_ONE", player)
        setOwnerIfPresent("CONSUMABLES_PAGE_ONE", player)
        setOwnerIfPresent("RECIPES_PAGE_ONE", player)
        setOwnerIfPresent("RECIPES_PAGE_TWO", player)
        setOwnerIfPresent("RECIPES_PAGE_ONE_TIER3", player)
        setOwnerIfPresent("RECIPES_PAGE_TWO_TIER3", player)
        setOwnerIfPresent("TITAN_PUNISH_CAGE_PUNISH", player)
        setOwnerIfPresent("TITAN_PUNISH_CAGE_RESEARCH", player)
        setOwnerIfPresent("TITAN_PICK_EASY", player)
        setOwnerIfPresent("TITAN_PICK_HARD", player)
        setOwnerIfPresent("EXP_STONE", player)
        removeTitanShopRallyPoints()
    end

    function UnitSpawner.spawnPlayerRace(playerData, x, y, facing)
        local race = playerData:race()
        if race == NullRace.instance() or race:widgetId() == 0 then
            return nil
        end

        local unit = CreateUnit(playerData:player(), race:widgetId(), x, y, facing or 270)
        playerData:setUnit(unit)
        applyEquippedCosmetics(playerData, unit)
        return unit
    end

    function UnitSpawner.moundPosition()
        if units.TITAN_SPELL_WELL then
            return GetUnitX(units.TITAN_SPELL_WELL), GetUnitY(units.TITAN_SPELL_WELL)
        end
        return MapAreas.point("TITAN_SPELL_WELL", -384.0, -512.0, 270)
    end

    function UnitSpawner.defenderSpawnPosition()
        local x, y = UnitSpawner.moundPosition()
        return MapAreas.point("DEFENDER_SPAWN", x, y, 270)
    end

    function UnitSpawner.minionSpawnPosition()
        local x, y = UnitSpawner.moundPosition()
        return MapAreas.point("MINION_SPAWN", x, y, 270)
    end

    function UnitSpawner.spawnPlayerRaceAtStart(playerData, angleDegrees, radius)
        local centerX, centerY = UnitSpawner.moundPosition()
        if playerData:class() == PlayerData.CLASS_DEFENDER then
            centerX, centerY = UnitSpawner.defenderSpawnPosition()
        end
        local angle = angleDegrees * bj_DEGTORAD
        local x = centerX + radius * Cos(angle)
        local y = centerY + radius * Sin(angle)
        local facing = bj_RADTODEG * Atan2(centerY - y, centerX - x)
        return UnitSpawner.spawnPlayerRace(playerData, x, y, facing)
    end

    function UnitSpawner.focusMainUnitCamera(playerData, force)
        local unit = playerData:unit()
        if unit then
            if force ~= true and rawget(_G, "Game") and Game.isState and Game.isState(Game.STATE_STARTED) then
                return
            end
            UnitSpawner.releasePlayerCamera(playerData)
            MapAreas.applyCameraBounds(playerData:player())
            PanCameraToTimedForPlayer(playerData:player(), GetUnitX(unit), GetUnitY(unit), 0)
            SelectUnitForPlayerSingle(unit, playerData:player())
        end
    end

    function UnitSpawner.spawnMinion(playerData, minionId, x, y, facing)
        if not minionId or minionId == 0 then
            return nil
        end

        local unit = CreateUnit(playerData:player(), minionId, x, y, facing or 270)
        if unit then
            UnitSpawner.setHeroLevel(unit, UnitSpawner.minionStartingLevel())
            playerData:setUnit(unit)
            applyEquippedCosmetics(playerData, unit)
        end
        return unit
    end

    _G.UnitSpawner = UnitSpawner
end)

if Debug and Debug.endFile then Debug.endFile() end
