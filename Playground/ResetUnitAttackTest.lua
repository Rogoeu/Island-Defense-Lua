if Debug and Debug.beginFile then Debug.beginFile("Playground/ResetUnitAttackTest") end

OnInit("ResetUnitAttackTest", function()
    local ATTACKER_ID = FourCC("O054")
    local RESET_ARGUMENT = 1 -- Meaning not yet verified for the new native.
    local PROC_CHANCE = 50
    local trigger = CreateTrigger()

    if type(rawget(_G, "BlzResetUnitAttack")) ~= "function" then
        print("Attack reset test: BlzResetUnitAttack is unavailable in this client.")
        return
    end

    for playerId = 0, bj_MAX_PLAYER_SLOTS - 1 do
        TriggerRegisterPlayerUnitEvent(trigger, Player(playerId), EVENT_PLAYER_UNIT_DAMAGED, nil)
    end

    TriggerAddAction(trigger, function()
        local attacker = GetEventDamageSource()
        if not attacker or GetUnitTypeId(attacker) ~= ATTACKER_ID or
            not BlzGetEventIsAttack() or GetEventDamage() <= 0 then return end
        if GetRandomInt(1, 100) > PROC_CHANCE then return end

        -- Leave the damage event before resetting the attack timer.
        local timer = CreateTimer()
        TimerStart(timer, 0.0, false, function()
            DestroyTimer(timer)
            if GetUnitTypeId(attacker) == 0 or GetWidgetLife(attacker) <= 0.405 then return end
            local ok, err = pcall(BlzResetUnitAttack, attacker, RESET_ARGUMENT)
            local message = ok and
                ("Attack reset test: native called, argument=" .. tostring(RESET_ARGUMENT)) or
                ("Attack reset test: " .. tostring(err))
            DisplayTimedTextToPlayer(GetOwningPlayer(attacker), 0, 0, 3, message)
        end)
    end)
end)

if Debug and Debug.endFile then Debug.endFile() end
