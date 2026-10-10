if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/MakruraStructureAbilities") end

OnInit("MakruraStructureAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("PlayerData")

    local IDS = {
        ENRAGED_TIDAL_GUARDIAN = FourCC("o00I"),
        CHAIN_RESEARCH = FourCC("R00D"),
        WARD = FourCC("WARD")
    }

    local CHAIN_DAMAGE = 15.0
    local CHAIN_RADIUS = 800.0
    local CHAIN_BOUNCES = 5
    local CHAIN_INTERVAL = 0.15
    local CHAIN_CHANCE = 5
    local LIGHTNING_ID = "CLPB"
    local LIGHTNING_DURATION = 0.55
    local suppressDamage = false

    local function isTitanSide(unit)
        local playerData = unit and PlayerData.get(GetOwningPlayer(unit)) or nil
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function isAlive(unit)
        return unit and GetWidgetLife(unit) > 0.405 and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function validChainTarget(source, unit, hit)
        return isAlive(unit) and
            GetUnitAbilityLevel(unit, IDS.WARD) == 0 and
            not hit[GetHandleId(unit)] and
            isTitanSide(unit) and
            IsUnitEnemy(unit, GetOwningPlayer(source)) and
            not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE)
    end

    local function addLightningTimed(source, target)
        local lightning = AddLightningEx(
            LIGHTNING_ID,
            true,
            GetUnitX(source),
            GetUnitY(source),
            GetUnitFlyHeight(source) + 65.0,
            GetUnitX(target),
            GetUnitY(target),
            GetUnitFlyHeight(target) + 65.0
        )

        GameTimer.after(LIGHTNING_DURATION, function()
            if lightning then
                DestroyLightning(lightning)
            end
        end)
    end

    local function damageTarget(source, target)
        suppressDamage = true
        UnitDamageTarget(source, target, CHAIN_DAMAGE, true, true, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
        suppressDamage = false
    end

    local function findNextTarget(source, current, hit)
        local group = CreateGroup()
        local unit = nil
        local best = nil
        local bestDistance = 99999999.0
        local x = GetUnitX(current)
        local y = GetUnitY(current)

        GroupEnumUnitsInRange(group, x, y, CHAIN_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            local dx = GetUnitX(unit) - x
            local dy = GetUnitY(unit) - y
            local distance = dx * dx + dy * dy

            GroupRemoveUnit(group, unit)
            if validChainTarget(source, unit, hit) and distance < bestDistance then
                best = unit
                bestDistance = distance
            end
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
        return best
    end

    local function launchChain(source, firstTarget)
        local hit = {}
        local current = firstTarget
        local previous = source
        local bounce = 0

        local function step()
            if not current or bounce >= CHAIN_BOUNCES or
                GetUnitAbilityLevel(current, IDS.WARD) > 0 then
                return
            end

            hit[GetHandleId(current)] = true
            addLightningTimed(previous, current)
            damageTarget(source, current)
            bounce = bounce + 1

            previous = current
            current = findNextTarget(source, current, hit)
            if current and bounce < CHAIN_BOUNCES then
                GameTimer.after(CHAIN_INTERVAL, step)
            end
        end

        step()
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()

        if suppressDamage or not attacker or not target then
            return
        end
        if BlzGetEventDamageType() ~= DAMAGE_TYPE_NORMAL then
            return
        end
        if GetUnitTypeId(attacker) ~= IDS.ENRAGED_TIDAL_GUARDIAN then
            return
        end
        if not isTitanSide(target) or GetUnitAbilityLevel(target, IDS.WARD) > 0 then
            return
        end
        if GetPlayerTechCount(GetOwningPlayer(attacker), IDS.CHAIN_RESEARCH, true) < 1 then
            return
        end
        if GetRandomInt(1, 100) > CHAIN_CHANCE then
            return
        end

        launchChain(attacker, target)
    end

    local damageTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        i = i + 1
    end

    TriggerAddAction(damageTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    AbilityRegistry.registerRace("Makrura", "structures", {
        notes = "Makrura structure ability ported from MakChains.",
        abilities = {
            {
                name = "Mak Chains",
                id = IDS.CHAIN_RESEARCH,
                source = "library MakChains",
                behavior = "Enraged Tidal Guardian o00I has a 5 percent chance after R00D research to chain 15 magic damage across up to 5 titan-side targets within 800 range."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
