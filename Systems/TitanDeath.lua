if Debug and Debug.beginFile then Debug.beginFile("Systems/TitanDeath") end

OnInit("TitanDeath", function(import)
    import.strict("PlayerData")
    import.strict("Races")
    import.strict("GameTimer")

    local IDS = {
        TITAN_BONES_DAMAGE = FourCC("TBOU"), -- Non-hero: damage and armor bones.
        TITAN_BONES_STATS = FourCC("TBOH"), -- Hero: stat bones.
        MINION_BONES_DAMAGE = FourCC("MBOU"), -- Non-hero: damage and armor bones.
        MINION_BONES_STATS = FourCC("MBOH"), -- Hero: stat bones.
        ANKH_REINCARNATION = FourCC("I00P"),
        ANKH_SUPERIORITY = FourCC("I07A"),
        REINCARNATION_ABILITY = FourCC("A012"),
        SUPERIORITY_REINCARNATION = FourCC("A0RR"),
        STANDARD_REINCARNATION = FourCC("AIrc"),
        TITAN_EGG = FourCC("I022"),
        CHICKEN_SMALL = FourCC("n00C"), -- One egg.
        CHICKEN_MEDIUM = FourCC("n018"), -- Two eggs.
        CHICKEN_LARGE = FourCC("n019") -- Three eggs.
    }

    local TitanDeath = {}
    local titanMinionTypeIds = nil
    local pendingReincarnations = {}
    local knownAnkhByUnit = {}
    local removalScheduledByUnit = {}
    local DEATH_EVENT_SETTLE_SECONDS = 0.10
    local REINCARNATION_CONFIRM_SECONDS = 15.0
    local CORPSE_REMOVE_SECONDS = 3.0

    local function playerData(unit)
        return unit and PlayerData.get(GetOwningPlayer(unit)) or nil
    end

    local function isPlayerMainUnit(unit, data)
        return data and data:unit() == unit
    end

    local function hasItem(unit, itemId)
        local slot = 0

        while slot < bj_MAX_INVENTORY do
            local item = UnitItemInSlot(unit, slot)
            if item and GetItemTypeId(item) == itemId then
                return true
            end
            slot = slot + 1
        end
        return false
    end

    local function canReincarnate(unit)
        return unit and IsUnitType(unit, UNIT_TYPE_HERO) and (
            knownAnkhByUnit[GetHandleId(unit)] == true or
            hasItem(unit, IDS.ANKH_REINCARNATION) or
            hasItem(unit, IDS.ANKH_SUPERIORITY)
        )
    end

    local function isTitanSidePlayer(playerData)
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function rememberReincarnationSource(unit)
        local data = playerData(unit)

        if not unit or not isPlayerMainUnit(unit, data) or
            not isTitanSidePlayer(data) or not IsUnitType(unit, UNIT_TYPE_HERO) then
            return
        end

        if hasItem(unit, IDS.ANKH_REINCARNATION) or
            hasItem(unit, IDS.ANKH_SUPERIORITY) then
            knownAnkhByUnit[GetHandleId(unit)] = true
        else
            -- Item-granted reincarnation abilities can remain on the hero
            -- briefly after an Ankh was consumed. They are not proof that the
            -- current death will reincarnate; the inventory snapshot is.
            knownAnkhByUnit[GetHandleId(unit)] = nil
        end
    end

    local function nameColored(data)
        if data and data.nameColored then
            return data:nameColored()
        end
        if data then
            return data:name()
        end
        return "|cff777777Unknown|r"
    end

    local function ensureTitanMinionTypeIds()
        local races = nil
        local i = 1

        if titanMinionTypeIds then
            return
        end

        titanMinionTypeIds = {}
        races = Races.all()
        while i <= #races do
            local race = races[i]
            if race:class() == PlayerData.CLASS_TITAN then
                local childIds = race:childIds()
                local j = 1

                while j <= #childIds do
                    titanMinionTypeIds[childIds[j]] = true
                    j = j + 1
                end
            end
            i = i + 1
        end
    end

    local function isTitanMinionUnit(unit)
        ensureTitanMinionTypeIds()
        return unit and titanMinionTypeIds[GetUnitTypeId(unit)] == true
    end

    local function chickenForLevel(level)
        if level < 3 then
            return IDS.CHICKEN_SMALL
        elseif level < 6 then
            return IDS.CHICKEN_MEDIUM
        end
        return IDS.CHICKEN_LARGE
    end

    local function createItem(itemId, x, y)
        return CreateItem(itemId, x, y)
    end

    local function dropTitanSideRewards(unit)
        local data = playerData(unit)
        local boneId = 0
        local x = 0.0
        local y = 0.0

        if isPlayerMainUnit(unit, data) and data:class() == PlayerData.CLASS_TITAN then
            boneId = IDS.TITAN_BONES_STATS
        elseif isPlayerMainUnit(unit, data) and data:class() == PlayerData.CLASS_MINION then
            boneId = IDS.MINION_BONES_STATS
        elseif isTitanSidePlayer(data) and IsUnitType(unit, UNIT_TYPE_HERO) and isTitanMinionUnit(unit) then
            boneId = IDS.MINION_BONES_STATS
        else
            return false
        end

        x = GetUnitX(unit)
        y = GetUnitY(unit)
        CreateUnit(GetOwningPlayer(unit), chickenForLevel(GetHeroLevel(unit)), x, y, 270.0)
        createItem(boneId, x, y)
        return true
    end

    local function dropChickenEggs(unit)
        local typeId = GetUnitTypeId(unit)
        local x = GetUnitX(unit)
        local y = GetUnitY(unit)

        if typeId == IDS.CHICKEN_SMALL then
            createItem(IDS.TITAN_EGG, x, y)
        elseif typeId == IDS.CHICKEN_MEDIUM then
            createItem(IDS.TITAN_EGG, x, y)
            createItem(IDS.TITAN_EGG, x + 20.0, y + 20.0)
        elseif typeId == IDS.CHICKEN_LARGE then
            createItem(IDS.TITAN_EGG, x, y)
            createItem(IDS.TITAN_EGG, x + 20.0, y + 20.0)
            createItem(IDS.TITAN_EGG, x - 20.0, y - 20.0)
        end
    end

    local function replacementBone(itemId, unit)
        local hero = IsUnitType(unit, UNIT_TYPE_HERO)

        if hero then
            if itemId == IDS.TITAN_BONES_DAMAGE then
                return IDS.TITAN_BONES_STATS
            elseif itemId == IDS.MINION_BONES_DAMAGE then
                return IDS.MINION_BONES_STATS
            end
        else
            if itemId == IDS.TITAN_BONES_STATS then
                return IDS.TITAN_BONES_DAMAGE
            elseif itemId == IDS.MINION_BONES_STATS then
                return IDS.MINION_BONES_DAMAGE
            end
        end

        return 0
    end

    local function swapBoneVariant(unit, item)
        local replacementId = replacementBone(GetItemTypeId(item), unit)
        local replacement = nil

        if replacementId == 0 then
            return
        end

        replacement = createItem(replacementId, GetUnitX(unit), GetUnitY(unit))
        RemoveItem(item)
        UnitAddItem(unit, replacement)
    end

    local function pingTitanSideDeath(x, y)
        local localData = PlayerData.get(GetLocalPlayer())

        -- Old Zinc behavior: Titan-side players see a red ping, everyone else
        -- sees a green ping. This is local UI only.
        if localData and (
            localData:class() == PlayerData.CLASS_TITAN or
            localData:class() == PlayerData.CLASS_MINION
        ) then
            PingMinimapEx(x, y, 10.00, 254, 0, 0, true)
        else
            PingMinimapEx(x, y, 10.00, 0, 255, 0, true)
        end
    end

    local function playDeathSound(soundName)
        local sound = rawget(_G, soundName)

        if sound then
            PlaySoundBJ(sound)
        end
    end

    local function deathPosition(unit, fallback)
        local x = 0.0
        local y = 0.0

        if unit and GetUnitTypeId(unit) ~= 0 then
            x = GetUnitX(unit)
            y = GetUnitY(unit)
        end
        if x == 0.0 and y == 0.0 and fallback and GetUnitTypeId(fallback) ~= 0 then
            x = GetUnitX(fallback)
            y = GetUnitY(fallback)
        end
        if x == 0.0 and y == 0.0 then
            x = -384.0
            y = -512.0
        end
        return x, y
    end

    local function notifyTitanSideDeath(unit, killer, x, y, isTitanSideUnit)
        local data = playerData(unit)
        local killerData = killer and PlayerData.get(GetOwningPlayer(killer)) or nil
        local classValue = PlayerData.mainUnitClass(unit)

        if not isTitanSideUnit then
            return
        end
        if classValue ~= PlayerData.CLASS_TITAN then
            classValue = PlayerData.CLASS_MINION
        end

        if not x or not y then
            x, y = deathPosition(unit, killer)
        end
        pingTitanSideDeath(x, y)

        if classValue == PlayerData.CLASS_TITAN then
            playDeathSound("gg_snd_Titan_Death")
            Game.say(nameColored(data) ..
                " |r(|cffb0d0f0Titan|r)|cff90b0d0 has been vanquished by |r" ..
                nameColored(killerData))
        else
            playDeathSound("gg_snd_Minion_Death")
            Game.say(nameColored(data) ..
                "|cff90b0d0 |r(|cffb0d0f0Titanous Minion|r)|cff90b0d0 has been slain by |r" ..
                nameColored(killerData))
        end
    end

    local function finalizeTitanSideDeath(unit, killer, x, y)
        local isTitanSideUnit = dropTitanSideRewards(unit)

        notifyTitanSideDeath(unit, killer, x, y, isTitanSideUnit)
        if isTitanSideUnit then
            local id = GetHandleId(unit)
            local data = playerData(unit)

            if removalScheduledByUnit[id] then
                return
            end
            removalScheduledByUnit[id] = true
            -- Zinc removed confirmed Titan and Minion corpses after 3 seconds.
            GameTimer.after(CORPSE_REMOVE_SECONDS, function()
                removalScheduledByUnit[id] = nil
                if unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) <= 0.405 then
                    if data and data:unit() == unit then
                        data:setUnit(nil)
                    end
                    RemoveUnit(unit)
                end
            end)
        end
    end

    local function confirmTitanSideDeath(unit, killer, x, y, id, token)
        if pendingReincarnations[id] ~= token then
            return
        end

        pendingReincarnations[id] = nil
        if unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) <= 0.405 then
            finalizeTitanSideDeath(unit, killer, x, y)
            if rawget(_G, "WinCondition") and WinCondition.checkSoon then
                WinCondition.checkSoon()
            end
        end
    end

    local function beginTitanSideDeathCheck(unit, killer)
        local id = GetHandleId(unit)
        local x, y = deathPosition(unit, killer)
        local token = {}

        -- Native Ankhs can consume their item and fire EVENT_UNIT_USE_ITEM
        -- around the hero death event. Mark the unit pending immediately so
        -- WinCondition cannot finish the game during that event ordering.
        pendingReincarnations[id] = token
        GameTimer.after(DEATH_EVENT_SETTLE_SECONDS, function()
            if pendingReincarnations[id] ~= token then
                return
            end

            if canReincarnate(unit) then
                GameTimer.after(REINCARNATION_CONFIRM_SECONDS, function()
                    confirmTitanSideDeath(unit, killer, x, y, id, token)
                end)
            else
                confirmTitanSideDeath(unit, killer, x, y, id, token)
            end
        end)
    end

    local function onDeath()
        local unit = GetTriggerUnit()
        local killer = GetKillingUnit()
        local data = playerData(unit)

        if not unit then
            return
        end

        dropChickenEggs(unit)
        if isPlayerMainUnit(unit, data) and isTitanSidePlayer(data) and
            IsUnitType(unit, UNIT_TYPE_HERO) then
            beginTitanSideDeathCheck(unit, killer)
            return
        end
        finalizeTitanSideDeath(unit, killer)
    end

    local function onDamaged()
        if GetEventDamage() > 0.0 then
            -- Latch the Ankh before lethal damage lets Warcraft consume it.
            rememberReincarnationSource(GetTriggerUnit())
        end
    end

    local function onRevive()
        local unit = GetTriggerUnit()

        if unit then
            local id = GetHandleId(unit)
            pendingReincarnations[id] = nil
            knownAnkhByUnit[id] = nil
        end
    end

    local function onPickup()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if unit and item then
            local itemId = GetItemTypeId(item)
            if itemId == IDS.ANKH_REINCARNATION or itemId == IDS.ANKH_SUPERIORITY then
                knownAnkhByUnit[GetHandleId(unit)] = true
            end
            swapBoneVariant(unit, item)
        end
    end

    local function onUseItem()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        -- The old map relied on native Reincarnation not removing the Titan
        -- from UnitManager's living Titan list. Lua checks actual unit life,
        -- so the native item-use event must explicitly protect the revive
        -- window even when Reincarnation emits no unit death event.
        if unit and item then
            local itemId = GetItemTypeId(item)
            if itemId == IDS.ANKH_REINCARNATION or itemId == IDS.ANKH_SUPERIORITY then
                local id = GetHandleId(unit)
                local data = playerData(unit)

                knownAnkhByUnit[id] = true
                if not pendingReincarnations[id] and isPlayerMainUnit(unit, data) and
                    isTitanSidePlayer(data) and IsUnitType(unit, UNIT_TYPE_HERO) then
                    beginTitanSideDeathCheck(unit, nil)
                end
            end
        end
    end

    local function onDrop()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if unit and item then
            local itemId = GetItemTypeId(item)
            if itemId == IDS.ANKH_REINCARNATION or itemId == IDS.ANKH_SUPERIORITY then
                local id = GetHandleId(unit)
                GameTimer.after(0.03, function()
                    if not pendingReincarnations[id] and
                        not hasItem(unit, IDS.ANKH_REINCARNATION) and
                        not hasItem(unit, IDS.ANKH_SUPERIORITY) then
                        knownAnkhByUnit[id] = nil
                    end
                end)
            end
        end
    end

    local deathTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local reviveTrigger = CreateTrigger()
    local pickupTrigger = CreateTrigger()
    local useTrigger = CreateTrigger()
    local dropTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(reviveTrigger, Player(i), EVENT_PLAYER_HERO_REVIVE_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(pickupTrigger, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
        TriggerRegisterPlayerUnitEvent(useTrigger, Player(i), EVENT_PLAYER_UNIT_USE_ITEM, nil)
        TriggerRegisterPlayerUnitEvent(dropTrigger, Player(i), EVENT_PLAYER_UNIT_DROP_ITEM, nil)
        TriggerRegisterPlayerUnitEvent(dropTrigger, Player(i), EVENT_PLAYER_UNIT_PAWN_ITEM, nil)
        i = i + 1
    end

    local function guarded(callback)
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(callback)
        else
            callback()
        end
    end

    TriggerAddAction(deathTrigger, function() guarded(onDeath) end)
    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)
    TriggerAddAction(reviveTrigger, function() guarded(onRevive) end)
    TriggerAddAction(pickupTrigger, function() guarded(onPickup) end)
    TriggerAddAction(useTrigger, function() guarded(onUseItem) end)
    TriggerAddAction(dropTrigger, function() guarded(onDrop) end)

    -- The starting I00P is inserted with UnitAddItem and therefore emits no
    -- pickup event. Snapshot living Titan-side main inventories before death.
    GameTimer.every(0.25, function()
        local playerId = 0

        while playerId < bj_MAX_PLAYER_SLOTS do
            local data = PlayerData.get(Player(playerId))
            local unit = data and data:unit() or nil

            if unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 and
                isTitanSidePlayer(data) then
                local id = GetHandleId(unit)
                if hasItem(unit, IDS.ANKH_REINCARNATION) or hasItem(unit, IDS.ANKH_SUPERIORITY) then
                    knownAnkhByUnit[id] = true
                elseif not pendingReincarnations[id] then
                    knownAnkhByUnit[id] = nil
                end
            end
            playerId = playerId + 1
        end
    end)

    function TitanDeath.isReincarnationPending(unit)
        return unit and pendingReincarnations[GetHandleId(unit)] ~= nil
    end

    TitanDeath.ids = IDS
    _G.TitanDeath = TitanDeath
end)

if Debug and Debug.endFile then Debug.endFile() end
