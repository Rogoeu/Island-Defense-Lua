if Debug and Debug.beginFile then Debug.beginFile("Systems/TitanDamageSystem") end

OnInit("TitanDamageSystem", function(import)
    import.strict("PlayerData")
    import.strict("UnitFilter")

    local rules = {}
    local damageListeners = {}
    local statsByPlayerId = {}
    local suppressDamage = false

    local TitanDamageSystem = {}

    local function playerDataOf(unit)
        return UnitFilter.playerDataOf(unit)
    end

    local function hasItem(unit, itemId)
        local slot = 0

        if not itemId or itemId == 0 then
            return true
        end

        while slot < 6 do
            local item = UnitItemInSlot(unit, slot)
            if item and GetItemTypeId(item) == itemId then
                return true
            end
            slot = slot + 1
        end

        return false
    end

    local function hasAbility(unit, abilityId)
        return not abilityId or abilityId == 0 or (unit and GetUnitAbilityLevel(unit, abilityId) > 0)
    end

    local function damageTypeKey(damageType)
        if damageType == DAMAGE_TYPE_NORMAL then
            return "normal"
        elseif damageType == DAMAGE_TYPE_MAGIC then
            return "magic"
        elseif damageType == DAMAGE_TYPE_UNIVERSAL then
            return "universal"
        elseif damageType == DAMAGE_TYPE_ENHANCED then
            return "enhanced"
        elseif damageType == DAMAGE_TYPE_FIRE then
            return "fire"
        elseif damageType == DAMAGE_TYPE_COLD then
            return "cold"
        elseif damageType == DAMAGE_TYPE_LIGHTNING then
            return "lightning"
        elseif damageType == DAMAGE_TYPE_POISON then
            return "poison"
        elseif damageType == DAMAGE_TYPE_DISEASE then
            return "disease"
        elseif damageType == DAMAGE_TYPE_DIVINE then
            return "divine"
        end
        return "other"
    end

    local function ensureStats(playerData)
        local id = playerData:id()
        if not statsByPlayerId[id] then
            statsByPlayerId[id] = {
                playerData = playerData,
                dealt = 0.0,
                taken = 0.0,
                dealtByType = {},
                takenByType = {}
            }
        end
        return statsByPlayerId[id]
    end

    local function addStats(playerData, direction, damage, damageType)
        local stats = nil
        local byType = nil
        local key = nil

        if not playerData or not UnitFilter.isTitanSidePlayer(playerData) or damage <= 0.0 then
            return
        end

        stats = ensureStats(playerData)
        key = damageTypeKey(damageType)

        if direction == "dealt" then
            stats.dealt = stats.dealt + damage
            byType = stats.dealtByType
        else
            stats.taken = stats.taken + damage
            byType = stats.takenByType
        end

        byType[key] = (byType[key] or 0.0) + damage
    end

    local function sideMatches(ruleSide, playerData)
        if not ruleSide or ruleSide == "titanSide" then
            return UnitFilter.isTitanSidePlayer(playerData)
        elseif ruleSide == "titan" then
            return playerData and playerData:class() == PlayerData.CLASS_TITAN
        elseif ruleSide == "minion" then
            return playerData and playerData:class() == PlayerData.CLASS_MINION
        end
        return false
    end

    local function ruleApplies(rule, context)
        local actor = nil
        local other = nil
        local actorData = nil

        if rule.direction == "incoming" then
            actor = context.target
            other = context.source
            actorData = context.targetData
        else
            actor = context.source
            other = context.target
            actorData = context.sourceData
        end

        if not sideMatches(rule.side, actorData) then
            return false
        end

        if rule.damageType and rule.damageType ~= context.damageType then
            return false
        end

        if rule.attackType and rule.attackType ~= context.attackType then
            return false
        end

        if not hasItem(actor, rule.itemId) then
            return false
        end

        if not hasAbility(actor, rule.buffId) then
            return false
        end

        if not hasAbility(context.source, rule.sourceBuffId) then
            return false
        end

        if not hasAbility(context.target, rule.targetBuffId) then
            return false
        end

        if rule.otherBuffId and not hasAbility(other, rule.otherBuffId) then
            return false
        end

        if rule.predicate and not rule.predicate(context, actor, other) then
            return false
        end

        return true
    end

    local function applyRule(rule, context)
        if rule.multiplier then
            context.damage = context.damage * rule.multiplier
        end

        if rule.add then
            context.damage = context.damage + rule.add
        end

        if rule.min and context.damage < rule.min then
            context.damage = rule.min
        end

        if rule.max and context.damage > rule.max then
            context.damage = rule.max
        end

        if rule.setDamageType and rule.setDamageType ~= context.damageType then
            context.damageType = rule.setDamageType
            context.rewriteDamage = true
        end

        if rule.setAttackType and rule.setAttackType ~= context.attackType then
            context.attackType = rule.setAttackType
            context.rewriteDamage = true
        end

        if rule.onApply then
            rule.onApply(context)
        end
    end

    local function applyRules(context)
        local i = 1

        while i <= #rules do
            local rule = rules[i]
            if ruleApplies(rule, context) then
                applyRule(rule, context)
            end
            i = i + 1
        end
    end

    local function notifyDamageListeners(context)
        local i = 1

        while i <= #damageListeners do
            damageListeners[i](context)
            i = i + 1
        end
    end

    local function onDamaged()
        local source = GetEventDamageSource()
        local target = GetTriggerUnit()
        local damage = GetEventDamage()
        local context = nil

        if suppressDamage or damage <= 0.0 or not source or not target then
            return
        end

        context = {
            source = source,
            target = target,
            sourceData = playerDataOf(source),
            targetData = playerDataOf(target),
            originalDamage = damage,
            damage = damage,
            isAttack = BlzGetEventIsAttack and BlzGetEventIsAttack() or true,
            attackType = BlzGetEventAttackType and BlzGetEventAttackType() or ATTACK_TYPE_NORMAL,
            damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL,
            weaponType = BlzGetEventWeaponType and BlzGetEventWeaponType() or WEAPON_TYPE_WHOKNOWS,
            rewriteDamage = false
        }

        if not UnitFilter.isTitanSidePlayer(context.sourceData) and not UnitFilter.isTitanSidePlayer(context.targetData) then
            return
        end

        applyRules(context)

        if context.damage < 0.0 then
            context.damage = 0.0
        end

        addStats(context.sourceData, "dealt", context.damage, context.damageType)
        addStats(context.targetData, "taken", context.damage, context.damageType)
        notifyDamageListeners(context)

        if context.rewriteDamage then
            if BlzSetEventDamage then
                BlzSetEventDamage(0.0)
            end

            if context.damage > 0.0 then
                suppressDamage = true
                UnitDamageTarget(context.source, context.target, context.damage, context.isAttack, false, context.attackType, context.damageType, context.weaponType)
                suppressDamage = false
            end
        elseif BlzSetEventDamage and context.damage ~= context.originalDamage then
            BlzSetEventDamage(context.damage)
        end
    end

    function TitanDamageSystem.register(rule)
        rule = rule or {}
        rule.direction = rule.direction or "outgoing"
        rule.side = rule.side or "titanSide"
        rules[#rules + 1] = rule
        return rule
    end

    function TitanDamageSystem.onDamage(callback)
        if callback then
            damageListeners[#damageListeners + 1] = callback
        end
    end

    function TitanDamageSystem.clearRules()
        rules = {}
    end

    function TitanDamageSystem.rules()
        local copy = {}
        local i = 1
        while i <= #rules do
            copy[i] = rules[i]
            i = i + 1
        end
        return copy
    end

    function TitanDamageSystem.stats(playerData)
        if not playerData then
            return nil
        end
        return ensureStats(playerData)
    end

    function TitanDamageSystem.resetStats()
        statsByPlayerId = {}
    end

    function TitanDamageSystem.hasItem(unit, itemId)
        return hasItem(unit, itemId)
    end

    function TitanDamageSystem.isTitanSide(playerData)
        return UnitFilter.isTitanSidePlayer(playerData)
    end

    function TitanDamageSystem.damageTypeKey(damageType)
        return damageTypeKey(damageType)
    end

    local function spellAttackType(attackType, damageType, isAttack)
        -- The old Damage.Spell wrapper used ATTACK_TYPE_NORMAL together with
        -- DAMAGE_TYPE_MAGIC. ATTACK_TYPE_MAGIC bypasses normal Warcraft spell
        -- resistance for scripted damage in this map.
        if isAttack ~= true and damageType == DAMAGE_TYPE_MAGIC and attackType == ATTACK_TYPE_MAGIC then
            return ATTACK_TYPE_NORMAL
        end
        return attackType
    end

    function TitanDamageSystem.dealDamage(source, target, amount, attackType, damageType, weaponType, isAttack)
        local finalDamageType = damageType or DAMAGE_TYPE_MAGIC
        local finalAttackType = attackType or ATTACK_TYPE_MAGIC

        if not source or not target or not amount or amount <= 0.0 then
            return false
        end

        return UnitDamageTarget(
            source,
            target,
            amount,
            isAttack == true,
            false,
            spellAttackType(finalAttackType, finalDamageType, isAttack),
            finalDamageType,
            weaponType or WEAPON_TYPE_WHOKNOWS
        )
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

    _G.TitanDamageSystem = TitanDamageSystem
end)

if Debug and Debug.endFile then Debug.endFile() end
