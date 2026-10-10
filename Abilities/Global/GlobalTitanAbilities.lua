if Debug and Debug.beginFile then Debug.beginFile("Abilities/Global/GlobalTitanAbilities") end

OnInit("GlobalTitanAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("DummyCaster")
    import.strict("GameTimer")
    import.strict("MissileSystem")
    import.strict("TitanDamageSystem")

    local IDS = {
        TITANIC_ARMOR = FourCC("R017"),
        TITAN_COURIER = FourCC("A02H"),
        MASS_CYCLONE = FourCC("A0UN"),
        MASS_CYCLONE_DUMMY = FourCC("A0UL"),
        GRAVITY_WAVE = FourCC("A0UP"),
        PENDANT_OF_VITALITY = FourCC("A0HN"),
        PENDANT_SUMMON = FourCC("h02P"),
        TIMED_LIFE_BUFF = FourCC("B061")
    }

    local ORDER_CYCLONE = OrderId("cyclone")
    local COURIER_MODEL = "units\\nightelf\\Chimaera\\Chimaera.mdl"
    local GRAVITY_WAVE_MODEL = "Abilities\\Spells\\Other\\CrushingWave\\CrushingWaveDamage.mdl"
    local GRAVITY_TARGET_FX = "Abilities\\Spells\\Undead\\Impale\\ImpaleTargetDust.mdl"
    local PENDANT_EFFECT = "Abilities\\Spells\\Other\\Doom\\DoomDeath.mdl"

    local MASS_CYCLONE_AOE = 500.0
    local GRAVITY_RADIUS = 800.0
    local GRAVITY_DURATION = 1.80
    local GRAVITY_PERIOD = 0.03
    local GRAVITY_PULL_STRENGTH = 5.0
    local GRAVITY_WAVE_INTERVAL = 0.12

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function setCooldown(unit, abilityId, cooldown)
        if rawget(_G, "BlzStartUnitAbilityCooldown") then
            BlzStartUnitAbilityCooldown(unit, abilityId, cooldown)
        end
    end

    local function castTitanCourier(caster)
        local target = GetSpellTargetUnit()
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local items = {}
        local slot = 0

        while slot < bj_MAX_INVENTORY do
            local item = UnitItemInSlot(caster, slot)
            if item then
                SetItemVisible(item, false)
                SetItemPosition(item, 8715.0, -10600.0)
                items[#items + 1] = item
            end
            slot = slot + 1
        end

        if #items == 0 then
            return
        end

        MissileSystem.launch({
            x = GetUnitX(caster),
            y = GetUnitY(caster),
            z = 120.0,
            target = target,
            targetX = targetX,
            targetY = targetY,
            speed = 522.0,
            collision = 48.0,
            model = COURIER_MODEL,
            scale = 0.4,
            onImpact = function(impactTarget, x, y)
                local i = 1
                while i <= #items do
                    local item = items[i]
                    SetItemVisible(item, true)
                    SetItemPosition(item, x, y)
                    if impactTarget and GetUnitTypeId(impactTarget) ~= 0 then
                        UnitAddItem(impactTarget, item)
                    end
                    i = i + 1
                end
            end
        })
    end

    local function isCycloneTarget(caster, target)
        return isAlive(target)
            and target ~= caster
            and IsUnitEnemy(target, GetOwningPlayer(caster))
            and not IsUnitType(target, UNIT_TYPE_STRUCTURE)
            and not IsUnitType(target, UNIT_TYPE_MAGIC_IMMUNE)
    end

    local function castMassCyclone(caster)
        local group = CreateGroup()
        local target = nil

        GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), MASS_CYCLONE_AOE, nil)
        target = FirstOfGroup(group)
        while target do
            GroupRemoveUnit(group, target)
            if isCycloneTarget(caster, target) then
                DummyCaster.castTarget(GetOwningPlayer(caster), IDS.MASS_CYCLONE_DUMMY, 1, ORDER_CYCLONE, target, GetUnitX(target), GetUnitY(target), 0, 1.0)
            end
            target = FirstOfGroup(group)
        end
        DestroyGroup(group)
        setCooldown(caster, IDS.MASS_CYCLONE, 120.0)
    end

    local function isGravityTarget(caster, target)
        return isCycloneTarget(caster, target)
    end

    local function createGravityRing(x, y, radius)
        local i = 0
        local points = 12
        while i < points do
            local angle = (2.0 * bj_PI / points) * i
            DestroyEffect(AddSpecialEffect(GRAVITY_WAVE_MODEL, x + radius * Cos(angle), y + radius * Sin(angle)))
            i = i + 1
        end
    end

    local function castGravityWave(caster)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local targets = {}
        local elapsed = 0.0
        local waveElapsed = 0.0
        local group = CreateGroup()
        local unit = nil
        local timer = nil

        createGravityRing(x, y, GRAVITY_RADIUS)
        GroupEnumUnitsInRange(group, x, y, GRAVITY_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isGravityTarget(caster, unit) then
                targets[#targets + 1] = unit
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        timer = GameTimer.every(GRAVITY_PERIOD, function()
            local progress = 0.0
            local waveRadius = 0.0
            local i = 1

            elapsed = elapsed + GRAVITY_PERIOD
            waveElapsed = waveElapsed + GRAVITY_PERIOD
            progress = elapsed / GRAVITY_DURATION
            if progress > 1.0 then
                progress = 1.0
            end
            waveRadius = GRAVITY_RADIUS * (1.0 - progress)

            if waveElapsed >= GRAVITY_WAVE_INTERVAL then
                waveElapsed = 0.0
                createGravityRing(x, y, waveRadius)
            end

            while i <= #targets do
                local target = targets[i]
                if isGravityTarget(caster, target) then
                    local targetX = GetUnitX(target)
                    local targetY = GetUnitY(target)
                    local dx = x - targetX
                    local dy = y - targetY
                    local distance = SquareRoot(dx * dx + dy * dy)
                    local step = GRAVITY_PULL_STRENGTH

                    if distance > 40.0 then
                        if distance < 150.0 then
                            step = step * 0.5
                        end
                        SetUnitX(target, targetX + (dx / distance) * step)
                        SetUnitY(target, targetY + (dy / distance) * step)
                        if GetRandomInt(1, 8) == 1 then
                            DestroyEffect(AddSpecialEffect(GRAVITY_TARGET_FX, GetUnitX(target), GetUnitY(target)))
                        end
                    end
                end
                i = i + 1
            end

            if elapsed >= GRAVITY_DURATION then
                timer:destroy()
            end
        end)
    end

    local function offsetTowards(x, y, angleDegrees, distance)
        local angle = angleDegrees * bj_DEGTORAD
        return x + distance * Cos(angle), y + distance * Sin(angle)
    end

    local function castPendantOfVitality(caster)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local facing = GetUnitFacing(caster)
        local summonX, summonY = offsetTowards(x, y, facing, 180.0)
        local summon = nil

        if GetTerrainCliffLevel(x, y) ~= GetTerrainCliffLevel(summonX, summonY) then
            summonX, summonY = offsetTowards(x, y, facing, 0.0)
        end

        summon = CreateUnit(GetOwningPlayer(caster), IDS.PENDANT_SUMMON, summonX, summonY, facing)
        DestroyEffect(AddSpecialEffectTarget(PENDANT_EFFECT, summon, "chest"))
        if IsUnitType(caster, UNIT_TYPE_HERO) then
            local level = GetHeroLevel(caster)
            if rawget(_G, "BlzSetUnitMaxHP") then
                BlzSetUnitMaxHP(summon, BlzGetUnitMaxHP(summon) + R2I(150.0 * level))
                SetWidgetLife(summon, BlzGetUnitMaxHP(summon))
            else
                SetWidgetLife(summon, GetWidgetLife(summon) + 150.0 * level)
            end
            if rawget(_G, "BlzSetUnitBaseDamage") then
                BlzSetUnitBaseDamage(summon, R2I(125.0 + 10.0 * level), 0)
            elseif rawget(_G, "BlzSetUnitWeaponIntegerField") then
                BlzSetUnitWeaponIntegerField(summon, UNIT_WEAPON_IF_ATTACK_DAMAGE_BASE, 0, R2I(125.0 + 10.0 * level))
            end
        end
        UnitApplyTimedLife(summon, IDS.TIMED_LIFE_BUFF, 60.0)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.TITAN_COURIER then
            castTitanCourier(caster)
        elseif abilityId == IDS.MASS_CYCLONE then
            castMassCyclone(caster)
        elseif abilityId == IDS.GRAVITY_WAVE then
            castGravityWave(caster)
        elseif abilityId == IDS.PENDANT_OF_VITALITY then
            castPendantOfVitality(caster)
        end
    end

    -- Port of BuilderUpgrades: share the completed research level with every player.
    local function onResearchFinished()
        if GetResearched() ~= IDS.TITANIC_ARMOR then
            return
        end

        local level = GetPlayerTechCount(GetTriggerPlayer(), IDS.TITANIC_ARMOR, true)
        for playerId = 0, bj_MAX_PLAYER_SLOTS - 1 do
            SetPlayerTechResearched(Player(playerId), IDS.TITANIC_ARMOR, level)
        end
    end

    local researchTrigger = CreateTrigger()
    local spellEffectTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellEffectTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(researchTrigger, Player(i), EVENT_PLAYER_UNIT_RESEARCH_FINISH, nil)
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

    TriggerAddAction(researchTrigger, function() guarded(onResearchFinished) end)
    TriggerAddAction(spellEffectTrigger, function() guarded(onSpellEffect) end)

    AbilityRegistry.registerGlobal("titan", {
        notes = "Global Titan and Minion abilities shared across titan races. Titan item and buff damage control is handled through TitanDamageSystem.",
        abilities = {
            {
                name = "Titan Damage System",
                source = "Lua Systems/TitanDamageSystem",
                behavior = "Central rule engine for Titan/Minion outgoing and incoming damage. Rules can filter by item, buff, damage type and attack type, then adjust damage or rewrite the resulting damage/attack type."
            },
            {
                name = "Titan Courier",
                id = IDS.TITAN_COURIER,
                source = "library TitanCourier",
                behavior = "Sends the caster's inventory as a Chimaera courier to the target point/unit, restoring items on arrival."
            },
            {
                name = "Mass Cyclone",
                id = IDS.MASS_CYCLONE,
                source = "library MassCyclone",
                behavior = "Cyclones enemy non-structure, non-magic-immune units within 500 range of the caster."
            },
            {
                name = "Gravity Wave",
                id = IDS.GRAVITY_WAVE,
                source = "library GravityWave",
                behavior = "Creates inward wave effects and pulls enemy non-structure, non-magic-immune units toward the caster for 1.8 seconds."
            },
            {
                name = "Pendant of Vitality",
                id = IDS.PENDANT_OF_VITALITY,
                source = "library PendantOfVitality",
                behavior = "Summons a timed helper in front of the caster and scales its life/damage with hero level."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
