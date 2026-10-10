if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/TaurenStructureAbilities") end

OnInit("TaurenStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    local IDS = {
        TRIBAL_AURA_BUFF = FourCC("B07V"),
        MAGIC_PEARL_BUFF = FourCC("B086")
    }

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local damage = GetEventDamage()
        local reduction = 0.0

        if damage <= 0.0 or not target or not attacker then
            return
        end
        if BlzGetEventDamageType and BlzGetEventDamageType() ~= DAMAGE_TYPE_MAGIC then
            return
        end
        if not IsUnitEnemy(target, GetOwningPlayer(attacker)) then
            return
        end

        if GetUnitAbilityLevel(target, IDS.TRIBAL_AURA_BUFF) > 0 then
            reduction = 0.40
        elseif GetUnitAbilityLevel(target, IDS.MAGIC_PEARL_BUFF) > 0 then
            reduction = 0.25
        end

        if reduction > 0.0 and BlzSetEventDamage then
            BlzSetEventDamage(damage * (1.0 - reduction))
        end
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

    AbilityRegistry.registerRace("Tauren", "structures", {
        notes = "Tauren tower/building abilities ported from TribalAura.",
        abilities = {
            {
                name = "Tribal Aura",
                id = IDS.TRIBAL_AURA_BUFF,
                source = "library TribalAura",
                behavior = "Enemy magic damage against units with B07V is reduced by 40 percent."
            },
            {
                name = "Magic Pearl Aura",
                id = IDS.MAGIC_PEARL_BUFF,
                source = "library TribalAura",
                behavior = "Enemy magic damage against units with B086 is reduced by 25 percent."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
