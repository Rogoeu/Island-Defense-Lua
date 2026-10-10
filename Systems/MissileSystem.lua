if Debug and Debug.beginFile then Debug.beginFile("Systems/MissileSystem") end

OnInit("MissileSystem", function()
    local DEFAULT_PERIOD = 0.03125
    local active = {}
    local ticker = nil

    local MissileSystem = {}

    local function visualHeight(missile, x, y, height)
        if not missile.terrainRelative then
            return height
        end
        local point = Location(x, y)
        local ground = GetLocationZ(point)
        RemoveLocation(point)
        return ground + height
    end

    local function distance(x1, y1, x2, y2)
        local dx = x2 - x1
        local dy = y2 - y1
        return SquareRoot(dx * dx + dy * dy)
    end

    local function missileHeight(missile)
        local progress = 1.0
        local baseHeight = 0.0

        if missile.totalDistance > 0.0 then
            progress = missile.traveled / missile.totalDistance
            if progress > 1.0 then
                progress = 1.0
            end
        end

        baseHeight = missile.startZ + (missile.targetZ - missile.startZ) * progress
        if missile.arc and missile.arc > 0.0 then
            -- A parabola reaches its peak halfway through the flight and lands at targetZ.
            baseHeight = baseHeight + missile.arc * missile.totalDistance * 4.0 * progress * (1.0 - progress)
        end
        return baseHeight
    end

    local function ensureTicker()
        if ticker then
            return
        end

        ticker = CreateTimer()
        TimerStart(ticker, DEFAULT_PERIOD, true, function()
            local i = #active

            while i >= 1 do
                local missile = active[i]
                local target = missile.target
                local targetX = missile.targetX
                local targetY = missile.targetY

                if target and GetUnitTypeId(target) ~= 0 then
                    targetX = GetUnitX(target)
                    targetY = GetUnitY(target)
                end

                local remaining = distance(missile.x, missile.y, targetX, targetY)
                local step = missile.speed * DEFAULT_PERIOD

                if remaining <= step or remaining <= missile.collision then
                    BlzSetSpecialEffectPosition(missile.effect, targetX, targetY,
                        visualHeight(missile, targetX, targetY, missile.targetZ))
                    DestroyEffect(missile.effect)
                    table.remove(active, i)

                    if missile.onImpact then
                        missile.onImpact(target, targetX, targetY)
                    end
                else
                    local angle = Atan2(targetY - missile.y, targetX - missile.x)
                    missile.traveled = missile.traveled + step
                    missile.x = missile.x + step * Cos(angle)
                    missile.y = missile.y + step * Sin(angle)
                    missile.z = missileHeight(missile)
                    BlzSetSpecialEffectPosition(missile.effect, missile.x, missile.y,
                        visualHeight(missile, missile.x, missile.y, missile.z))
                    BlzSetSpecialEffectYaw(missile.effect, angle)
                end

                i = i - 1
            end

            if #active == 0 then
                DestroyTimer(ticker)
                ticker = nil
            end
        end)
    end

    function MissileSystem.launch(data)
        data = data or {}

        local startX = data.x or 0.0
        local startY = data.y or 0.0
        local targetX = data.targetX or startX
        local targetY = data.targetY or startY
        local startZ = data.z or 64.0
        local targetZ = data.targetZ or 0.0

        if data.target and GetUnitTypeId(data.target) ~= 0 then
            targetX = GetUnitX(data.target)
            targetY = GetUnitY(data.target)
        end

        local missile = {
            x = startX,
            y = startY,
            z = startZ,
            startZ = startZ,
            targetZ = targetZ,
            terrainRelative = data.terrainRelative == true,
            totalDistance = distance(startX, startY, targetX, targetY),
            traveled = 0.0,
            arc = data.arc or 0.0,
            target = data.target,
            targetX = targetX,
            targetY = targetY,
            speed = data.speed or 900.0,
            collision = data.collision or 32.0,
            onImpact = data.onImpact,
            effect = AddSpecialEffect(data.model or "", startX, startY)
        }

        BlzSetSpecialEffectPosition(missile.effect, missile.x, missile.y,
            visualHeight(missile, missile.x, missile.y, missile.z))
        if data.scale and rawget(_G, "BlzSetSpecialEffectScale") then
            BlzSetSpecialEffectScale(missile.effect, data.scale)
        end

        active[#active + 1] = missile
        ensureTicker()
        return missile
    end

    function MissileSystem.activeCount()
        return #active
    end

    _G.MissileSystem = MissileSystem
end)

if Debug and Debug.endFile then Debug.endFile() end
