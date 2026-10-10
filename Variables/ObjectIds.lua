if Debug and Debug.beginFile then Debug.beginFile("Variables/ObjectIds") end

OnInit("ObjectIds", function()
    local rawcodes = {}
    local fourCC = rawget(_G, "FourCC")

    local function normalize(code)
        if type(code) == "number" then
            return code
        end

        if type(code) == "string" and string.len(code) == 4 and fourCC then
            return fourCC(code)
        end

        return code
    end

    _G.ObjectIds = {
        register = function(name, code)
            rawcodes[name] = normalize(code)
            return rawcodes[name]
        end,

        get = function(name)
            return rawcodes[name]
        end,

        has = function(name)
            return rawcodes[name] ~= nil
        end,

        all = function()
            local copy = {}
            for name, code in pairs(rawcodes) do
                copy[name] = code
            end
            return copy
        end
    }
end)

if Debug and Debug.endFile then Debug.endFile() end
