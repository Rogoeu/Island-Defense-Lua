if Debug and Debug.beginFile then Debug.beginFile("Systems/PunishmentCentre") end

OnInit("PunishmentCentre", function(import)
    import.strict("GameSettings")
    import.strict("GameTimer")
    import.strict("PlayerData")
    import.strict("UnitSpawner")

    local IDS = {
        AUTO_PUNISH_OFF = FourCC("&PU0"),
        AUTO_PUNISH_ON = FourCC("&PU1"),
        PUNISH = FourCC("&PUN"),
        PUNISH_ALT = FourCC("&PU2"),
        NO_ATTACK = FourCC("&noa"),
        REFRESH_ONE = FourCC("A02V"),
        REFRESH_TWO = FourCC("A0FN"),
        DISPEL_NEW = FourCC("&DS1"),
        DISPEL_OLD = FourCC("&DS2"),
        TELEPORT = FourCC("&TEL"),
        TELEPORT_CHANNEL = FourCC("A06R"),
        TELEPORT_BUFF = FourCC("B02U"),
        TAUREN_ENFEEBLE_BUFF = FourCC("B01V"),
        PAGE_SWAP = FourCC("A0UR")
    }

    local PLAYER_BUTTONS = {
        FourCC("&UP0"), -- Red
        FourCC("&UP1"), -- Blue
        FourCC("&UP2"), -- Teal
        FourCC("&UP3"), -- Purple
        FourCC("&UP4"), -- Yellow
        FourCC("&UP5"), -- Orange
        FourCC("&UP6"), -- Green
        FourCC("&UP7"), -- Pink
        FourCC("&UP8"), -- Grey
        FourCC("&UP9"), -- Light Blue
        FourCC("&UPA"), -- Dark Green
        FourCC("&UPB"), -- Brown
        FourCC("&UPM"), -- Maroon
        FourCC("&UPN"), -- Navy
        FourCC("&UPT"), -- Turquoise
        FourCC("&UPV")  -- Violet
    }

    local TELEPORT_EFFECT = "Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTo.mdl"
    local ORDER_AUTO_ON = OrderId("faeriefireon")
    local ORDER_AUTO_OFF = OrderId("faeriefireoff")

    local PunishmentCentre = {}

    local function cage()
        return UnitSpawner.get("TITAN_PUNISH_CAGE_PUNISH")
    end

    local function researchCage()
        return UnitSpawner.get("TITAN_PUNISH_CAGE_RESEARCH")
    end

    local function spellWell()
        return UnitSpawner.get("TITAN_SPELL_WELL")
    end

    local function titanData()
        local list = PlayerData.withClass(PlayerData.CLASS_TITAN)
        local found = list:at(0)
        list:destroy()
        return found
    end

    local function titanPlayer()
        local data = titanData()
        if data then
            return data:player()
        end
        local unit = cage()
        if unit then
            return GetOwningPlayer(unit)
        end
        return Player(PLAYER_NEUTRAL_AGGRESSIVE)
    end

    local function sayTitans(text)
        local list = PlayerData.withClass(PlayerData.CLASS_TITAN)
        local i = 0

        while i < list:size() do
            list:at(i):say(text)
            i = i + 1
        end

        list:destroy()
    end

    local function buttonIdForPlayerId(id)
        return PLAYER_BUTTONS[(id or -1) + 1]
    end

    local function playerIdFromButton(abilityId)
        local i = 1
        while i <= #PLAYER_BUTTONS do
            if PLAYER_BUTTONS[i] == abilityId then
                return i - 1
            end
            i = i + 1
        end
        return -1
    end

    local function destroyEffectLater(effect, delay)
        GameTimer.after(delay or 0.0, function()
            if effect then
                DestroyEffect(effect)
            end
        end)
    end

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function syncAutoPunishAbility()
        local unit = cage()
        if not unit then
            return
        end

        if GameSettings.getBool("TITAN_AUTOPUNISH") then
            UnitRemoveAbility(unit, IDS.AUTO_PUNISH_OFF)
            UnitAddAbility(unit, IDS.AUTO_PUNISH_ON)
        else
            UnitAddAbility(unit, IDS.AUTO_PUNISH_OFF)
            UnitRemoveAbility(unit, IDS.AUTO_PUNISH_ON)
        end
    end

    function PunishmentCentre.update()
        local owner = titanPlayer()
        local list = nil
        local i = 1
        syncAutoPunishAbility()

        while i <= #PLAYER_BUTTONS do
            SetPlayerAbilityAvailable(owner, PLAYER_BUTTONS[i], false)
            i = i + 1
        end

        list = PlayerData.withClass(PlayerData.CLASS_MINION)
        i = 0
        while i < list:size() do
            local playerData = list:at(i)
            local buttonId = buttonIdForPlayerId(playerData:id())

            if buttonId and not playerData:isLeaving() and not playerData:hasLeft() then
                SetPlayerAbilityAvailable(owner, buttonId, true)
            end
            i = i + 1
        end
        list:destroy()

        local unit = cage()
        if unit then
            UnitRemoveAbility(unit, IDS.REFRESH_ONE)
            UnitRemoveAbility(unit, IDS.REFRESH_TWO)
            UnitAddAbility(unit, IDS.REFRESH_ONE)
            UnitAddAbility(unit, IDS.REFRESH_TWO)
        end
    end

    function PunishmentCentre.setAutoPunish(enabled)
        local unit = cage()

        GameSettings.setBool("TITAN_AUTOPUNISH", enabled == true)
        if enabled then
            sayTitans("|cff90b0d0The |rAuto Punish|cff90b0d0 feature is now |cff20bb20enabled|cff90b0d0.|r")
            if unit then
                UnitRemoveAbility(unit, IDS.AUTO_PUNISH_OFF)
                UnitAddAbility(unit, IDS.AUTO_PUNISH_ON)
            end
        else
            sayTitans("|cff90b0d0The |rAuto Punish|cff90b0d0 feature is now |cffbb2020disabled|cff90b0d0.|r")
            if unit then
                UnitAddAbility(unit, IDS.AUTO_PUNISH_OFF)
                UnitRemoveAbility(unit, IDS.AUTO_PUNISH_ON)
            end
        end
    end

    function PunishmentCentre.applyAutoPunish(unit)
        if not unit or not GameSettings.getBool("TITAN_AUTOPUNISH") then
            return false
        end

        local owner = titanPlayer()
        if GetOwningPlayer(unit) ~= owner then
            SetUnitOwner(unit, owner, true)
        end
        return true
    end

    local function punishTarget(target)
        local owner = titanPlayer()
        if target and GetOwningPlayer(target) ~= owner then
            SetUnitOwner(target, owner, true)
        end

        if target and GetUnitAbilityLevel(target, IDS.NO_ATTACK) > 0 then
            UnitRemoveAbility(target, IDS.NO_ATTACK)
            SetUnitInvulnerable(target, false)
        end
    end

    local function unpunishTarget(abilityId, target)
        local id = playerIdFromButton(abilityId)
        local playerData = id >= 0 and PlayerData.get(Player(id)) or nil

        if target and playerData and playerData:class() == PlayerData.CLASS_MINION then
            IssueImmediateOrder(target, "stop")
            SetUnitOwner(target, Player(id), true)
        end
    end

    local function dispelTarget(target)
        if target then
            UnitRemoveBuffs(target, false, true)
            UnitRemoveAbility(target, IDS.TAUREN_ENFEEBLE_BUFF)
        end
    end

    local function teleportTarget(target)
        local well = spellWell()
        local effect = nil

        if not target or not well then
            return
        end

        effect = AddSpecialEffect(TELEPORT_EFFECT, GetUnitX(well), GetUnitY(well))
        destroyEffectLater(effect, 4.0)
        UnitAddAbility(well, IDS.TELEPORT_CHANNEL)

        GameTimer.after(3.5, function()
            local targetX = GetUnitX(target)
            local targetY = GetUnitY(target)
            local wellX = GetUnitX(well)
            local wellY = GetUnitY(well)
            local angle = Atan2(targetY - wellY, targetX - wellX)

            if isAlive(target) and GetUnitTypeId(well) ~= 0 then
                SetUnitPosition(target, wellX + 200.0 * Cos(angle), wellY + 200.0 * Sin(angle))
            end

            UnitRemoveAbility(well, IDS.TELEPORT_CHANNEL)
            UnitRemoveAbility(well, IDS.TELEPORT_BUFF)
        end)
    end

    local function onOrder()
        local unit = cage()
        local order = GetIssuedOrderId()

        if not unit or GetOrderedUnit() ~= unit then
            return
        end

        if order == ORDER_AUTO_ON then
            PunishmentCentre.setAutoPunish(true)
        elseif order == ORDER_AUTO_OFF then
            PunishmentCentre.setAutoPunish(false)
        end
    end

    local function onSpellCast()
        local unit = cage()
        local well = spellWell()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()
        local target = GetSpellTargetUnit()

        -- Legacy DispellTitan listened specifically to the Titan Spell Well,
        -- not to the Punishment Centre.
        if abilityId == IDS.DISPEL_NEW or abilityId == IDS.DISPEL_OLD then
            if caster == well then
                dispelTarget(target)
            end
            return
        end

        if not unit or caster ~= unit then
            return
        end

        if abilityId == IDS.PUNISH or abilityId == IDS.PUNISH_ALT then
            punishTarget(target)
        else
            unpunishTarget(abilityId, target)
        end
    end

    local function onSpellEffect()
        local abilityId = GetSpellAbilityId()
        local caster = GetTriggerUnit()
        local player = GetOwningPlayer(caster)

        if abilityId == IDS.TELEPORT then
            teleportTarget(GetSpellTargetUnit())
        elseif abilityId == IDS.PAGE_SWAP then
            if caster == cage() and researchCage() then
                SelectUnitForPlayerSingle(researchCage(), player)
            elseif caster == researchCage() and cage() then
                SelectUnitForPlayerSingle(cage(), player)
            end
        end
    end

    local orderTrigger = CreateTrigger()
    local castTrigger = CreateTrigger()
    local effectTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(castTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_CAST, nil)
        TriggerRegisterPlayerUnitEvent(effectTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
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

    TriggerAddAction(orderTrigger, function() guarded(onOrder) end)
    TriggerAddAction(castTrigger, function() guarded(onSpellCast) end)
    TriggerAddAction(effectTrigger, function() guarded(onSpellEffect) end)

    GameTimer.after(0.03, function()
        PunishmentCentre.setAutoPunish(GameSettings.getBool("TITAN_AUTOPUNISH"))
        PunishmentCentre.update()
    end)

    GameTimer.every(3.0, function()
        PunishmentCentre.update()
    end)

    _G.PunishmentCentre = PunishmentCentre
end)

if Debug and Debug.endFile then Debug.endFile() end
