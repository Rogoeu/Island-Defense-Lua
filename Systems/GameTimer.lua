if Debug and Debug.beginFile then Debug.beginFile("Systems/GameTimer") end

OnInit("GameTimer", function()
    local timers = {}
    local nextId = 0

    local GameTimer = {}
    GameTimer.__index = GameTimer

    local function invoke(callback, gameTimer)
        if callback then
            callback(gameTimer)
        end
    end

    local function remove(gameTimer)
        timers[gameTimer.idValue] = nil
    end

    local function runCallback(gameTimer)
        if gameTimer.destroyedValue then
            return
        end

        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(invoke, gameTimer.callbackValue, gameTimer)
        else
            invoke(gameTimer.callbackValue, gameTimer)
        end

        if not gameTimer.periodicValue and timers[gameTimer.idValue] then
            gameTimer:destroy()
        end
    end

    local function create(callback, timeout, periodic, name)
        local wc3Timer = CreateTimer()
        local this = setmetatable({
            idValue = nextId,
            timerValue = wc3Timer,
            callbackValue = callback,
            timeoutValue = timeout or 0,
            periodicValue = periodic == true,
            nameValue = name or "",
            dataValue = 0,
            pausedValue = false,
            runningValue = false,
            destroyedValue = false
        }, GameTimer)

        nextId = nextId + 1
        timers[this.idValue] = this

        TimerStart(wc3Timer, this.timeoutValue, this.periodicValue, function()
            this.runningValue = this.periodicValue
            runCallback(this)
        end)

        this.runningValue = true
        return this
    end

    function GameTimer.new(callback, timeout, periodic)
        return create(callback, timeout or 0.0, periodic == true, "")
    end

    function GameTimer.newNamed(name, callback, timeout, periodic)
        return create(callback, timeout or 0.0, periodic == true, name)
    end

    function GameTimer.after(timeout, callback)
        return create(callback, timeout or 0.0, false, "")
    end

    function GameTimer.every(timeout, callback)
        return create(callback, timeout or 0.0, true, "")
    end

    function GameTimer:destroy()
        if self.destroyedValue then
            return
        end
        self.destroyedValue = true
        PauseTimer(self.timerValue)
        DestroyTimer(self.timerValue)
        remove(self)
        self.runningValue = false
        self.pausedValue = false
    end

    function GameTimer:pause()
        if self.destroyedValue then
            return
        end
        PauseTimer(self.timerValue)
        self.pausedValue = true
        self.runningValue = false
    end

    function GameTimer:resume()
        if not self.destroyedValue and self.pausedValue then
            TimerStart(self.timerValue, TimerGetRemaining(self.timerValue), self.periodicValue, function()
                self.runningValue = self.periodicValue
                runCallback(self)
            end)
            self.pausedValue = false
            self.runningValue = true
        end
    end

    function GameTimer:isPaused()
        return self.pausedValue
    end

    function GameTimer:isRunning()
        return self.runningValue
    end

    function GameTimer:id()
        return self.idValue
    end

    function GameTimer:name()
        return self.nameValue
    end

    function GameTimer:data()
        return self.dataValue
    end

    function GameTimer:setData(value)
        self.dataValue = value or 0
    end

    function GameTimer:elapsed()
        if self.destroyedValue then
            return 0.0
        end
        return TimerGetElapsed(self.timerValue)
    end

    function GameTimer:remaining()
        if self.destroyedValue then
            return 0.0
        end
        return TimerGetRemaining(self.timerValue)
    end

    function GameTimer.count()
        local count = 0
        for _ in pairs(timers) do
            count = count + 1
        end
        return count
    end

    function GameTimer.destroyAll()
        local copy = {}
        for _, gameTimer in pairs(timers) do
            copy[#copy + 1] = gameTimer
        end

        local i = 1
        while i <= #copy do
            copy[i]:destroy()
            i = i + 1
        end
    end

    _G.GameTimer = GameTimer

    _G.StartGameTimer = function(gameTimer)
        if gameTimer and gameTimer.timerValue and not gameTimer.destroyedValue then
            TimerStart(gameTimer.timerValue, gameTimer.timeoutValue, gameTimer.periodicValue, function()
                gameTimer.runningValue = gameTimer.periodicValue
                runCallback(gameTimer)
            end)
            gameTimer.runningValue = true
        end
    end

    _G.PauseGameTimer = function(gameTimer)
        if gameTimer and gameTimer.pause then
            gameTimer:pause()
        end
    end

    _G.ResumeGameTimer = function(gameTimer)
        if gameTimer and gameTimer.resume then
            gameTimer:resume()
        end
    end

    _G.IsGameTimerPaused = function(gameTimer)
        return gameTimer ~= nil and gameTimer:isPaused()
    end

    _G.IsGameTimerRunning = function(gameTimer)
        return gameTimer ~= nil and gameTimer:isRunning()
    end
end)

if Debug and Debug.endFile then Debug.endFile() end
