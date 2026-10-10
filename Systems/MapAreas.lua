if Debug and Debug.beginFile then Debug.beginFile("Systems/MapAreas") end

OnInit("MapAreas", function(import)
    import.strict("PlayerData")
    -- Vulcanic currently uses PLACEHOLDER Classic coordinates. Edit its block before release.
    local AREAS = {
        Classic = {
            icon = "ReplaceableTextures\\CommandButtons\\BTNTreeOfLife.blp", -- Placeholder; replace later.
            bounds =  { minX = -11108.5, minY = -10964.4, maxX = 10049.2, maxY = 11161.5 },
            minimapTexture = "war3mapImported\\MinimapClassic.blp", -- crop to this area's bounds.
            -- Original Zinc RacePickMode.setupCamera: fixed camera positions.
            titanPickBounds = { minX = -9952, minY = 10304, maxX = -9952, maxY = 10304 },
            builderPickBounds = { minX = -10752, minY = 8704, maxX = -10752, maxY = 8704 },
            points = {
                DEFENDER_SPAWN = { x = -384, y = -512 }, -- Center of the initial spawn circle.
                MINION_SPAWN = { x = -384, y = -512 }, -- Normal/grace Minion spawn center.
                TITAN_SPELL_WELL = { x = -384, y = -512, facing = 270 },
                ARTIFACTS_PAGE_ONE = { x = 128.0, y = -384.0, facing = 270 },
                CONSUMABLES_PAGE_ONE = { x = -128.0, y = -1024.0, facing = 270 },
                RECIPES_PAGE_ONE = { x = -898.5, y = -444.0, facing = 270 },
                RECIPES_PAGE_TWO = { x = -898.0, y = -388.5, facing = 270 },
                RECIPES_PAGE_ONE_TIER3 = { x = -448.5, y = 128.0, facing = 270 },
                RECIPES_PAGE_TWO_TIER3 = { x = -447.5, y = 128.0, facing = 270 },
                TITAN_PUNISH_CAGE_PUNISH = { x = -448.5, y = -1024.0, facing = 270 },
                TITAN_PUNISH_CAGE_RESEARCH = { x = -447.5, y = -1024.0, facing = 270 },
                DEFENDER_PICK_BASER = { x = -10752.0, y = 8704.0, facing = 0 },
                DEFENDER_PICK_SUPPORT = { x = -10752.0, y = 8448.0, facing = 0 },
                DEFENDER_PICK_RANDOM = { x = -10336.6, y = 8717.4, facing = 0 },
                TITAN_PICK_EASY = { x = -10048.0, y = 10304.0, facing = 270 },
                TITAN_PICK_HARD = { x = -9856.0, y = 10304.0, facing = 270 },
                TITAN_PICKER = { x = -9952, y = 10304, facing = 270 },
                DEFENDER_PICKER = { x = -10752, y = 8704, facing = 0 },
                BUILDER_SHOP_CENTER = { x = 672, y = 6432, facing = 270 },
            },
            expStones = {
                { x = 10730.8, y = 526.8 },
                { x = 3526.3, y = -10154.9 },
                { x = -9730.0, y = -2307.8 },
                { x = -1348.6, y = 7620.5 },
            },
        },
        Vulcanic = {
            icon = "ReplaceableTextures\\CommandButtons\\BTNVolcano.blp", -- Placeholder; replace later.
            bounds = { minX = -12752, minY = -10964.4, maxX = 31487.5, maxY = 11161.5 },
            minimapTexture = nil, -- e.g. "war3mapImported\\MinimapVulcanic.blp"; crop to this area's bounds.
            titanPickBounds = nil, -- { minX = ..., minY = ..., maxX = ..., maxY = ... }
            builderPickBounds = nil, -- Separate Builder-team race-selection area.
            points = {
                DEFENDER_SPAWN = { x = 22025.1, y = 1800.0 }, -- TODO: Vulcanic spawn circle center.
                MINION_SPAWN = { x = 22025.1, y = 1800.0 }, -- TODO: Vulcanic Minion spawn center.
                TITAN_SPELL_WELL = { x = 22025.1, y = 1800.0, facing = 270 },
                ARTIFACTS_PAGE_ONE = { x = 22640.5, y = 1810.0, facing = 270 },
                CONSUMABLES_PAGE_ONE = { x = 22045.0, y = 1280.0, facing = 270 },
                RECIPES_PAGE_ONE = { x = 21510.5, y = 1810.0, facing = 270 },
                RECIPES_PAGE_TWO = { x = 21511.5, y = 1810.0, facing = 270 },
                RECIPES_PAGE_ONE_TIER3 = { x = 22067.5, y = 2380.0, facing = 270 },
                RECIPES_PAGE_TWO_TIER3 = { x = 22068.5, y = 2380.0, facing = 270 },
                TITAN_PUNISH_CAGE_PUNISH = { x = 22245.0, y = 1280.0, facing = 270 },
                TITAN_PUNISH_CAGE_RESEARCH = { x = 22246.0, y = 1280.0, facing = 270 },
                DEFENDER_PICK_BASER = { x = -10752.0, y = 8704.0, facing = 0 },
                DEFENDER_PICK_SUPPORT = { x = -10752.0, y = 8448.0, facing = 0 },
                DEFENDER_PICK_RANDOM = { x = -10336.6, y = 8717.4, facing = 0 },
                TITAN_PICK_EASY = { x = -10048.0, y = 10304.0, facing = 270 },
                TITAN_PICK_HARD = { x = -9856.0, y = 10304.0, facing = 270 },
                TITAN_PICKER = { x = -9952, y = 10304, facing = 270 },
                DEFENDER_PICKER = { x = -10752, y = 8704, facing = 0 },
                BUILDER_SHOP_CENTER = { x = 672, y = 6432, facing = 270 },
            },
            expStones = {
                { x = 10730.8, y = 526.8 },
                { x = 3526.3, y = -10154.9 },
                { x = -9730.0, y = -2307.8 },
                { x = -1348.6, y = 7620.5 },
            },
        },
    }

    local selected = "Classic"
    local originalBounds
    local MapAreas = {}
    function MapAreas.select(name)
        assert(AREAS[name], "Unknown map area: " .. tostring(name))
        selected = name
    end
    function MapAreas.name() return selected end
    function MapAreas.config() return AREAS[selected] end
    function MapAreas.icon(name) return AREAS[name].icon end
    function MapAreas.point(name, x, y, facing)
        local p = AREAS[selected].points[name]
        if p then return p.x, p.y, p.facing end
        return x, y, facing
    end
    local function applyBounds(bounds, player)
        -- Camera state is local; never use these coordinates for gameplay.
        if player and GetLocalPlayer() ~= player then return end
        if not originalBounds then
            originalBounds = {
                minX = GetCameraBoundMinX(), minY = GetCameraBoundMinY(),
                maxX = GetCameraBoundMaxX(), maxY = GetCameraBoundMaxY()
            }
        end
        local b = bounds or originalBounds
        SetCameraBounds(b.minX, b.minY, b.minX, b.maxY, b.maxX, b.maxY, b.maxX, b.minY)
    end
    function MapAreas.applyCameraBounds(player)
        applyBounds(AREAS[selected].bounds, player)
        if player and GetLocalPlayer() ~= player then return end
        -- Apply only the gameplay image, never stretch it over point-sized pick bounds.
        local texture = AREAS[selected].minimapTexture
        if texture and texture ~= "" then
            if not BlzChangeMinimapTerrainTex(texture) then
                DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 10,
                    "|cffff6060Could not load minimap: " .. texture .. "|r")
            end
        end
    end
    function MapAreas.applyPickCameraBounds(player)
        -- Resolve only this client's camera. Never use this local team branch
        -- for spawning units or other synchronized gameplay changes.
        local viewer = player or GetLocalPlayer()
        if viewer ~= GetLocalPlayer() then return end
        local data = PlayerData.get(viewer)
        local area = AREAS[selected]
        local bounds
        if data then
            local class = data:class()
            if class == PlayerData.CLASS_TITAN or class == PlayerData.CLASS_MINION or
                (data:isObserver() and data:observeTeam() == "titan") then
                bounds = area.titanPickBounds
            elseif class == PlayerData.CLASS_DEFENDER or
                (data:isObserver() and data:observeTeam() == "builder") then
                bounds = area.builderPickBounds
            end
        end
        applyBounds(bounds, viewer)
    end
    _G.MapAreas = MapAreas
end)

if Debug and Debug.endFile then Debug.endFile() end
