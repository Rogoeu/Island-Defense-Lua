if Debug and Debug.beginFile then Debug.beginFile("core/GameSettings") end

OnInit("GameSettings", function()
    local store = {}
    local methods = {}

    local function asString(value)
        if value == nil then
            return ""
        end
        return tostring(value)
    end

    function methods.clear()
        store = {}
    end

    function methods.exists(key)
        return store[asString(key)] ~= nil
    end

    function methods.getStr(key)
        return store[asString(key)] or ""
    end

    function methods.setStr(key, value)
        store[asString(key)] = asString(value)
    end

    function methods.getBool(key)
        local value = string.lower(methods.getStr(key))
        return value == "true" or (tonumber(value) or 0) >= 1
    end

    function methods.setBool(key, value)
        store[asString(key)] = value and "true" or "false"
    end

    function methods.getReal(key)
        return tonumber(methods.getStr(key)) or 0.0
    end

    function methods.setReal(key, value)
        store[asString(key)] = tostring(value or 0.0)
    end

    function methods.getInt(key)
        return R2I(methods.getReal(key))
    end

    function methods.setInt(key, value)
        store[asString(key)] = I2S(value or 0)
    end

    function methods.dump()
        local copy = {}
        for key, value in pairs(store) do
            copy[key] = value
        end
        return copy
    end

    local api = setmetatable({}, {
        __index = function(_, key)
            return methods[key] or store[asString(key)] or ""
        end,
        __newindex = function(_, key, value)
            store[asString(key)] = asString(value)
        end
    })

    _G.GameSettings = api

    if Debug and Debug.log then
        Debug.log("GameSettings Lua module initialized")
    end
end)

if Debug and Debug.endFile then Debug.endFile() end
