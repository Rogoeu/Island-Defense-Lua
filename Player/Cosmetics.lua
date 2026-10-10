if Debug and Debug.beginFile then Debug.beginFile("Player/Cosmetics") end

OnInit("Cosmetics", function(import)
    import.strict("PlayerData")
    import.strict("PlayerProfile")
    import.strict("Races")

    local categories = {
        aura = {},
        wings = {},
        skin = {}
    }
    local CATEGORY_ORDER = { "aura", "wings", "skin" }
    local byId = {}
    local MAX_ACTIVE = {
        aura = 3,
        wings = 2
    }
    local CACHE_MISSION = "CosmeticSelection"
    -- Runtime state is separate from locally saved profiles. Only synchronized
    -- selections may drive unit ability changes during a match.
    local activeSelections = {}

    local Cosmetics = {}

    local function validCategory(category)
        return categories[category] ~= nil
    end

    local function conditionMet(player, cosmetic)
        if not cosmetic.condition then
            return false
        end
        return cosmetic.condition(player) == true
    end

    local function normalizeCode(value)
        return string.upper(string.gsub(tostring(value or ""), "[^%w]", ""))
    end

    local function normalizeName(name)
        return string.lower(string.gsub(tostring(name or ""), "[^%w]", ""))
    end

    local function boundCodeForName(name, cosmetic)
        local source = normalizeName(name) .. "|" .. cosmetic.unlockSecret
        local hash = 216613626
        local i = 1

        while i <= string.len(source) do
            hash = (hash * 65599 + string.byte(source, i) + i * 97) % 2147483647
            i = i + 1
        end

        return normalizeCode(cosmetic.codePrefix .. string.format("%08X", hash))
    end

    local function mainUnit(player)
        local data = PlayerData.get(player)

        return data and data:unit() or nil
    end

    local function supportedSkinRace(race)
        local name = race and race ~= NullRace.instance() and race:toString() or ""

        return name ~= "" and name ~= "Panda" and name ~= "Morphling"
    end

    local function skinMatchesRace(cosmetic, raceName)
        return cosmetic and cosmetic.category == "skin" and
            (cosmetic.race == "" or cosmetic.race == raceName)
    end

    local function savedSelections(player, category)
        local saved = PlayerProfile.equippedCosmetic(player, category)
        local list = categories[category]
        local limit = MAX_ACTIVE[category]
        local selected = {}
        local safe = {}
        local count = 0
        local index = 1

        -- Accept the old single-string format once so existing saves retain
        -- their selected aura after the multiple-aura upgrade.
        if type(saved) == "string" then
            if saved ~= "" then
                selected[saved] = true
            end
        elseif type(saved) == "table" then
            while index <= #list do
                local cosmetic = list[index]
                if saved[cosmetic.id] == true then
                    selected[cosmetic.id] = true
                end
                index = index + 1
            end
        end

        -- This is the hard fail-safe for malformed or manually edited saves.
        -- Only registered entries survive and only the category limit applies.
        index = 1
        while index <= #list do
            local cosmetic = list[index]
            if cosmetic.id ~= category .. ":none" and selected[cosmetic.id] and count < limit then
                safe[cosmetic.id] = true
                count = count + 1
            end
            index = index + 1
        end
        return safe
    end

    local function activeCount(category, selected)
        local count = 0
        local index = 1
        local list = categories[category]

        while index <= #list do
            local cosmetic = list[index]
            if cosmetic.id ~= category .. ":none" and selected[cosmetic.id] then
                count = count + 1
            end
            index = index + 1
        end
        return count
    end

    local function applyCategoryAbilities(unit, category, selected)
        local index = 1
        local list = categories[category]

        if not unit or GetUnitTypeId(unit) == 0 then
            return
        end

        -- Remove every registered cosmetic ability first. The selected entries
        -- are then reapplied, preventing stale abilities after a toggle.
        while index <= #list do
            local cosmetic = list[index]
            if cosmetic.abilityId then
                -- Dynamic abilities are marked permanent after adding them.
                -- Clear that flag before removal so a deselected aura cannot
                -- remain attached to the hero.
                UnitMakeAbilityPermanent(unit, false, cosmetic.abilityId)
                UnitRemoveAbility(unit, cosmetic.abilityId)
            end
            index = index + 1
        end
        index = 1
        while index <= #list do
            local cosmetic = list[index]
            -- Unlock checks happen before the owner sends the synchronized
            -- selection. Rechecking local save data here would let clients
            -- disagree about which abilities to add and cause a desync.
            if selected[cosmetic.id] and cosmetic.abilityId then
                if GetUnitAbilityLevel(unit, cosmetic.abilityId) <= 0 then
                    UnitAddAbility(unit, cosmetic.abilityId)
                end
                -- Passive aura abilities occasionally remain at level 0 when
                -- added dynamically. Force their first configured level so the
                -- visual effect begins immediately.
                if GetUnitAbilityLevel(unit, cosmetic.abilityId) > 0 then
                    SetUnitAbilityLevel(unit, cosmetic.abilityId, 1)
                end
                -- Warcraft may otherwise remove dynamically added abilities on
                -- hero initialization, replacement or morphing.
                UnitMakeAbilityPermanent(unit, true, cosmetic.abilityId)
            end
            index = index + 1
        end
    end

    function Cosmetics.register(config)
        local cosmetic = {
            id = tostring(config.id or ""),
            category = config.category,
            race = tostring(config.race or ""),
            name = config.name or config.id or "Unnamed Cosmetic",
            description = config.description or "No description available.",
            icon = config.icon or "ReplaceableTextures\\CommandButtons\\BTNCancel.blp",
            condition = config.condition,
            unlockCode = normalizeCode(config.unlockCode),
            unlockSecret = tostring(config.unlockSecret or ""),
            codePrefix = tostring(config.codePrefix or "COS"),
            isDefault = config.isDefault == true,
            abilityId = config.abilityId,
            skinId = config.skinId,
            apply = config.apply
        }

        if cosmetic.id == "" or not validCategory(cosmetic.category) or byId[cosmetic.id] then
            return false
        end

        categories[cosmetic.category][#categories[cosmetic.category] + 1] = cosmetic
        byId[cosmetic.id] = cosmetic
        return cosmetic
    end

    function Cosmetics.all(category)
        return categories[category] or {}
    end

    function Cosmetics.get(cosmeticId)
        return byId[tostring(cosmeticId or "")]
    end

    function Cosmetics.identityName(player)
        local data = PlayerData.get(player)

        return (data and data:originalName()) or GetPlayerName(player) or ""
    end

    function Cosmetics.unlockCodeForPlayer(player, cosmeticOrId)
        local cosmetic = type(cosmeticOrId) == "table" and cosmeticOrId or Cosmetics.get(cosmeticOrId)

        if not cosmetic or cosmetic.unlockSecret == "" then
            return ""
        end
        return boundCodeForName(Cosmetics.identityName(player), cosmetic)
    end

    -- Map-side helper for an external code generator or an admin-only tool.
    -- Example: Cosmetics.unlockCodeForName("onlychris", "aura:sayjan_blue")
    function Cosmetics.unlockCodeForName(name, cosmeticOrId)
        local cosmetic = type(cosmeticOrId) == "table" and cosmeticOrId or Cosmetics.get(cosmeticOrId)

        if not cosmetic or cosmetic.unlockSecret == "" then
            return ""
        end
        return boundCodeForName(name, cosmetic)
    end

    function Cosmetics.isUnlocked(player, cosmeticOrId)
        local cosmetic = type(cosmeticOrId) == "table" and cosmeticOrId or Cosmetics.get(cosmeticOrId)

        if not cosmetic then
            return false
        end
        return cosmetic.isDefault or PlayerProfile.hasCosmetic(player, cosmetic.id) or conditionMet(player, cosmetic)
    end

    function Cosmetics.isEquipped(player, cosmeticOrId, raceName)
        local cosmetic = type(cosmeticOrId) == "table" and cosmeticOrId or Cosmetics.get(cosmeticOrId)

        if not cosmetic then
            return false
        end
        if MAX_ACTIVE[cosmetic.category] then
            return savedSelections(player, cosmetic.category)[cosmetic.id] == true
        end
        if cosmetic.category == "skin" then
            local equipped = PlayerProfile.equippedCosmetic(player, "skin", raceName or cosmetic.race)
            return equipped == cosmetic.id or (equipped == "" and cosmetic.isDefault)
        end
        return PlayerProfile.equippedCosmetic(player, cosmetic.category) == cosmetic.id
    end

    function Cosmetics.refreshUnlocks(player)
        local categoryIndex = 1
        local index = 1
        local changed = false

        while categoryIndex <= #CATEGORY_ORDER do
            local category = CATEGORY_ORDER[categoryIndex]
            local list = categories[category]
            index = 1
            while index <= #list do
                local cosmetic = list[index]
                if not PlayerProfile.hasCosmetic(player, cosmetic.id) and conditionMet(player, cosmetic) then
                    PlayerProfile.unlockCosmetic(player, cosmetic.id)
                    changed = true
                end
                index = index + 1
            end
            categoryIndex = categoryIndex + 1
        end
        if changed and GetLocalPlayer() == player then
            PlayerProfile.saveAllPlayers()
        end
        return changed
    end

    function Cosmetics.redeemCode(player, code)
        local wanted = normalizeCode(code)
        local categoryIndex = 1
        local index = 1

        if wanted == "" then
            return false, nil, "invalid"
        end

        while categoryIndex <= #CATEGORY_ORDER do
            local category = CATEGORY_ORDER[categoryIndex]
            local list = categories[category]
            index = 1
            while index <= #list do
                local cosmetic = list[index]
                local staticMatch = cosmetic.unlockCode ~= "" and cosmetic.unlockCode == wanted
                local boundMatch = cosmetic.unlockSecret ~= "" and
                    Cosmetics.unlockCodeForPlayer(player, cosmetic) == wanted

                if staticMatch or boundMatch then
                    if PlayerProfile.hasCosmetic(player, cosmetic.id) then
                        return true, cosmetic, "already-unlocked"
                    end

                    PlayerProfile.unlockCosmetic(player, cosmetic.id)
                    if GetLocalPlayer() == player then
                        PlayerProfile.saveAllPlayers()
                        PlayerProfile.syncLocalProfile()
                    end
                    return true, cosmetic, "unlocked"
                end
                index = index + 1
            end
            categoryIndex = categoryIndex + 1
        end

        return false, nil, "invalid"
    end

    local function encodeSelection(category, selected)
        local mask = 0
        local index = 1
        local list = categories[category]

        while index <= #list do
            local cosmetic = list[index]
            if cosmetic.id ~= category .. ":none" and selected[cosmetic.id] then
                mask = mask + (2 ^ (index - 1))
            end
            index = index + 1
        end
        return mask
    end

    local function decodeSelection(category, mask)
        local selected = {}
        local count = 0
        local index = 1
        local list = categories[category]
        local limit = MAX_ACTIVE[category]

        mask = tonumber(mask) or 0
        while index <= #list do
            local cosmetic = list[index]
            local weight = 2 ^ (index - 1)
            local enabled = math.floor(mask / weight) % 2 == 1

            if cosmetic.id ~= category .. ":none" and enabled and count < limit then
                selected[cosmetic.id] = true
                count = count + 1
            end
            index = index + 1
        end
        return selected
    end

    local function activeSelection(player, category)
        local playerId = GetPlayerId(player)

        if not activeSelections[playerId] then
            activeSelections[playerId] = {}
        end
        if not activeSelections[playerId][category] then
            activeSelections[playerId][category] = savedSelections(player, category)
        end
        return activeSelections[playerId][category]
    end

    local function selectedSkin(player, raceName)
        local state = activeSelections[GetPlayerId(player)]
        local skin = state and state.skin or nil

        if skin and skin[raceName] ~= nil then
            return skin[raceName]
        end
        return PlayerProfile.equippedCosmetic(player, "skin", raceName)
    end

    local function skinIndex(cosmetic)
        local index = 1

        while index <= #categories.skin do
            if categories.skin[index] == cosmetic then
                return index
            end
            index = index + 1
        end
        return -1
    end

    -- This changes the shared runtime selection and therefore must only be
    -- reached through the synchronized handler below. Aura and wing visuals
    -- update immediately; the selected skin is kept for the next spawn.
    local function applySyncedSelection(player, auraMask, wingsMask, raceIndex, selectedSkinIndex)
        local playerId = GetPlayerId(player)
        local previous = activeSelections[playerId]
        local skin = previous and previous.skin or {}
        local race = nil
        local cosmetic = nil

        if raceIndex >= 0 and selectedSkinIndex >= 1 then
            race = Races.at(raceIndex)
            cosmetic = categories.skin[selectedSkinIndex]
            if supportedSkinRace(race) and skinMatchesRace(cosmetic, race:toString()) then
                skin[race:toString()] = cosmetic.id
            end
        end

        activeSelections[playerId] = {
            aura = decodeSelection("aura", auraMask),
            wings = decodeSelection("wings", wingsMask),
            skin = skin
        }
        Cosmetics.applyAuraToUnit(player, mainUnit(player))
    end

    -- Requesting an equip is safe from a local UI click. The actual selection
    -- and UnitAddAbility/UnitRemoveAbility calls happen in the sync callback
    -- below, on every client in the same order.
    function Cosmetics.requestEquip(player, cosmeticId, raceName)
        local cosmetic = Cosmetics.get(cosmeticId)
        local selected = nil
        local aura = nil
        local wings = nil
        local selectedRaceIndex = -1
        local selectedSkinIndex = -1

        if not player or GetLocalPlayer() ~= player then
            return false, "not-local-player"
        end
        if not rawget(_G, "BlzSendSyncData") then
            return false, "sync-unavailable"
        end
        if not PlayerProfile.areProfilesSynchronized() then
            return false, "profiles-loading"
        end
        if not cosmetic or not Cosmetics.isUnlocked(player, cosmetic) then
            return false, "locked"
        end

        if MAX_ACTIVE[cosmetic.category] then
            selected = savedSelections(player, cosmetic.category)
            if cosmetic.id == cosmetic.category .. ":none" then
                selected = {}
            elseif selected[cosmetic.id] then
                selected[cosmetic.id] = nil
            elseif activeCount(cosmetic.category, selected) >= MAX_ACTIVE[cosmetic.category] then
                return false, cosmetic.category .. "-limit"
            else
                selected[cosmetic.id] = true
            end
            PlayerProfile.setEquippedCosmetic(player, cosmetic.category, selected)
        else
            -- Skin preferences are stored per race and synchronized now, but
            -- their visual is deliberately applied only on the next spawn.
            if cosmetic.category == "skin" then
                raceName = tostring(raceName or cosmetic.race or "")
                local race = Races.fromName(raceName)

                if not supportedSkinRace(race) or not skinMatchesRace(cosmetic, raceName) then
                    return false, "skin-race-required"
                end
                PlayerProfile.setEquippedCosmetic(player, "skin", cosmetic.id, raceName)
                selectedRaceIndex = Races.indexOf(race)
                selectedSkinIndex = skinIndex(cosmetic)
            else
                PlayerProfile.setEquippedCosmetic(player, cosmetic.category, cosmetic.id)
                return true
            end
        end

        aura = savedSelections(player, "aura")
        wings = savedSelections(player, "wings")
        -- Both complete masks travel in one packet, so every client replaces
        -- the same runtime state in the same order.
        BlzSendSyncData(CACHE_MISSION, I2S(GetPlayerId(player)) .. "|" ..
            I2S(encodeSelection("aura", aura)) .. "|" .. I2S(encodeSelection("wings", wings)) .. "|" ..
            I2S(selectedRaceIndex) .. "|" .. I2S(selectedSkinIndex))
        return true
    end

    -- Keep the old public entry point safe for UI callers as well.
    function Cosmetics.equip(player, cosmeticId, raceName)
        return Cosmetics.requestEquip(player, cosmeticId, raceName)
    end

    -- Applies live cosmetics to one concrete unit. This is called immediately
    -- after synchronized selections, so skins must not be applied here.
    function Cosmetics.applyAuraToUnit(player, unit)
        if not PlayerProfile.areProfilesSynchronized() then
            return false
        end

        applyCategoryAbilities(unit, "aura", activeSelection(player, "aura"))
        applyCategoryAbilities(unit, "wings", activeSelection(player, "wings"))
        return true
    end

    -- Freshly spawned main units receive the saved skin in addition to the
    -- live aura and wing state. Selecting another skin never calls this path.
    function Cosmetics.applySpawnCosmetics(player, unit)
        if not Cosmetics.applyAuraToUnit(player, unit) then
            return false
        end
        Cosmetics.applySkinToUnit(player, unit)
        return true
    end

    function Cosmetics.applySkinToUnit(player, unit)
        local data = PlayerData.get(player)
        local race = data and data:race() or nil
        local raceName = supportedSkinRace(race) and race:toString() or ""
        local cosmetic = raceName ~= "" and Cosmetics.get(selectedSkin(player, raceName)) or nil
        local skinId = nil
        local abilityId = skinMatchesRace(cosmetic, raceName) and cosmetic.abilityId or nil
        local index = 1

        if not unit or GetUnitTypeId(unit) == 0 or raceName == "" or
            not rawget(_G, "BlzSetUnitSkin") then
            return false
        end

        -- Legacy Zinc skins are passive visual abilities. Remove every other
        -- registered skin ability first so exactly one skin can be active.
        while index <= #categories.skin do
            local registeredAbility = categories.skin[index].abilityId
            if registeredAbility and registeredAbility ~= abilityId and
                GetUnitAbilityLevel(unit, registeredAbility) > 0 then
                UnitMakeAbilityPermanent(unit, false, registeredAbility)
                UnitRemoveAbility(unit, registeredAbility)
            end
            index = index + 1
        end
        if skinMatchesRace(cosmetic, raceName) then
            skinId = cosmetic.skinId
        end
        if skinId then
            BlzSetUnitSkin(unit, skinId)
        elseif abilityId then
            if GetUnitAbilityLevel(unit, abilityId) <= 0 then
                BlzSetUnitSkin(unit, GetUnitTypeId(unit))
                UnitAddAbility(unit, abilityId)
            end
            if GetUnitAbilityLevel(unit, abilityId) > 0 then
                SetUnitAbilityLevel(unit, abilityId, 1)
                UnitMakeAbilityPermanent(unit, true, abilityId)
            end
        else
            -- Default Skin restores the current gameplay unit type. This
            -- preserves legitimate enhanced forms after removing a cosmetic.
            BlzSetUnitSkin(unit, GetUnitTypeId(unit))
        end
        return true
    end

    function Cosmetics.applyEquipped(player)
        local visualCategories = { "skin" }
        local index = 1
        local data = PlayerData.get(player)
        local race = data and data:race() or nil
        local raceName = race and race ~= NullRace.instance() and race:toString() or ""

        -- Profile data is local until every player has sent it once. Applying
        -- abilities before that point would let clients mutate different units.
        if not PlayerProfile.areProfilesSynchronized() then
            return false
        end

        -- Keep the native-call order fixed across all clients. pairs() is not
        -- a suitable ordering mechanism for synchronized gameplay mutations.
        -- Profiles can finish synchronizing just after the initial unit spawn.
        -- Treat this one-time startup bridge like the spawn path so its saved
        -- skin is not lost merely because profile loading finished one tick late.
        Cosmetics.applySpawnCosmetics(player, mainUnit(player))

        while index <= #visualCategories do
            local cosmetic = Cosmetics.get(PlayerProfile.equippedCosmetic(
                player, visualCategories[index], raceName))
            if cosmetic and Cosmetics.isUnlocked(player, cosmetic) and cosmetic.apply then
                cosmetic.apply(player, cosmetic)
            end
            index = index + 1
        end
        return true
    end

    function Cosmetics.applyAllEquipped()
        local list = nil
        local index = 0

        if not PlayerProfile.areProfilesSynchronized() then
            return false
        end

        list = PlayerData.allReal()
        while index < list:size() do
            local player = list:at(index):player()

            -- This is the one-time bridge from saved profile to shared runtime
            -- state, performed only after every profile packet has arrived.
            activeSelections[GetPlayerId(player)] = {
                aura = savedSelections(player, "aura"),
                wings = savedSelections(player, "wings"),
                skin = {}
            }
            Cosmetics.applyEquipped(player)
            index = index + 1
        end
        list:destroy()
        return true
    end

    -- These default selections deliberately have no gameplay effect. New cosmetic
    -- entries belong here and can define an icon, condition and optional apply callback.
    --
    -- Cosmetic entry fields:
    -- id        Unique, permanent save key. Never rename an existing id after release.
    -- category  "aura", "wings" or "skin"; this decides the UI sub-tab.
    -- race      Exact race name for a skin. Empty entries, such as Default
    --           Skin, are shown for every supported race.
    -- name      Text shown in the profile UI.
    -- icon      BLP path for the profile UI. It can point at an imported texture.
    -- condition Function receiving the Warcraft player; return true to unlock it.
    -- unlockCode Optional global one-time code accepted by -cosmetic <code>.
    -- unlockSecret Optional secret seed for a name-bound one-time code. The code
    --              is calculated from this seed and the player's original name.
    -- codePrefix   Visible prefix for name-bound codes, for example "SB".
    -- isDefault True only for utility entries such as "No Aura".
    -- abilityId Optional visual-only ability rawcode. Aura entries may be toggled
    --           together; the system enforces a maximum of three active auras.
    -- skinId   Optional unit rawcode passed to BlzSetUnitSkin for skin entries.
    -- apply     Optional callback for Wings/Skins or more complex aura behavior.
    Cosmetics.register({
        id = "aura:none",
        category = "aura",
        name = "No Aura",
        description = "Removes every equipped cosmetic aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNCancel.blp",
        isDefault = true
    })

    -- Aura SAYJAN Blue. A0SG is the custom aura ability shown in the object editor.
    -- Each player receives their own name-bound code. The exact generated value
    -- is checked against the player's original name, so another player cannot
    -- redeem it. You can instead use a permanent condition, for example:
    --     condition = function(player)
    --         return PlayerProfile.stats(player).winsTitan >= 25
    --     end
    -- Do not put damage, armor or other balance-changing effects on this ability: a
    -- cosmetic aura should be visual only.
    Cosmetics.register({
        id = "aura:bondage_purple",
        category = "aura",
        name = "Aura Bondage Purple",
        description = "Equips the Bondage Purple visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0TF"),
        unlockSecret = "BONDAGEPURPLE",
        codePrefix = "BP"
    })

    Cosmetics.register({
        id = "aura:sayjan_blue",
        category = "aura",
        name = "Aura SAYJAN Blue",
        description = "Equips the blue SAYJAN visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0SG"),
        unlockSecret = "SAYJANBLUE",
        codePrefix = "SB"
    })

    Cosmetics.register({
        id = "aura:sayjan_green",
        category = "aura",
        name = "Aura SAYJAN Green",
        description = "Equips the green SAYJAN visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0SF"),
        unlockSecret = "SAYJANGREEN",
        codePrefix = "SG"
    })

    Cosmetics.register({
        id = "aura:sayjan_orange",
        category = "aura",
        name = "Aura SAYJAN Orange",
        description = "Equips the orange SAYJAN visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0SE"),
        unlockSecret = "SAYJANORANGE",
        codePrefix = "SO"
    })

    Cosmetics.register({
        id = "aura:sayjan_purple",
        category = "aura",
        name = "Aura SAYJAN Purple",
        description = "Equips the purple SAYJAN visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0SB"),
        unlockSecret = "SAYJANPURPLE",
        codePrefix = "SP"
    })

    Cosmetics.register({
        id = "aura:sayjan_red",
        category = "aura",
        name = "Aura SAYJAN Red",
        description = "Equips the red SAYJAN visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0SC"),
        unlockSecret = "SAYJANRED",
        codePrefix = "SR"
    })

    Cosmetics.register({
        id = "aura:sayjan_teal",
        category = "aura",
        name = "Aura SAYJAN Teal",
        description = "Equips the teal SAYJAN visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0SD"),
        unlockSecret = "SAYJANTEAL",
        codePrefix = "ST"
    })

    Cosmetics.register({
        id = "aura:voidskull_purple",
        category = "aura",
        name = "Aura Voidskull Purple",
        description = "Equips the purple Voidskull visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0TG"),
        unlockSecret = "VOIDSKULLPURPLE",
        codePrefix = "VP"
    })

    Cosmetics.register({
        id = "aura:alpha_tester",
        category = "aura",
        name = "Effect Alpha Tester",
        description = "Equips the Alpha Tester visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A000"),
        unlockSecret = "ALPHATESTER",
        codePrefix = "EAT"
    })

    Cosmetics.register({
        id = "aura:beta_tester_bronze",
        category = "aura",
        name = "Effect Beta Tester (Bronze)",
        description = "Equips the Beta Tester Bronze visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0CC"),
        unlockSecret = "BETATESTERBRONZE",
        codePrefix = "EBTB"
    })

    Cosmetics.register({
        id = "aura:beta_tester_green_shimmer",
        category = "aura",
        name = "Effect Beta Tester (Green shimmer)",
        description = "Equips the Beta Tester Green Shimmer visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0TV"),
        unlockSecret = "BETATESTERSHIMMER",
        codePrefix = "EBTGS"
    })

    Cosmetics.register({
        id = "aura:beta_tester_indication_aura",
        category = "aura",
        name = "Effect Beta Tester (Indication Aura)",
        description = "Equips the Beta Tester Indication Aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0T7"),
        unlockSecret = "BETATESTERINDICATION",
        codePrefix = "EBTIA"
    })

    Cosmetics.register({
        id = "aura:beta_tester_level_1_bronze",
        category = "aura",
        name = "Effect Beta Tester (Level 1) Bronze",
        description = "Equips the Beta Tester Level 1 Bronze visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0RY"),
        unlockSecret = "BETATESTERLEVEL1",
        codePrefix = "EBT1"
    })

    Cosmetics.register({
        id = "aura:beta_tester_level_2_silver",
        category = "aura",
        name = "Effect Beta Tester (Level 2) Silver",
        description = "Equips the Beta Tester Level 2 Silver visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0RZ"),
        unlockSecret = "BETATESTERLEVEL2",
        codePrefix = "EBT2"
    })

    Cosmetics.register({
        id = "aura:beta_tester_level_3_gold",
        category = "aura",
        name = "Effect Beta Tester (Level 3) Gold",
        description = "Equips the Beta Tester Level 3 Gold visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A05W"),
        unlockSecret = "BETATESTERLEVEL3",
        codePrefix = "EBT3"
    })

    Cosmetics.register({
        id = "aura:beta_tester_level_4_ruby",
        category = "aura",
        name = "Effect Beta Tester (Level 4) Ruby",
        description = "Equips the Beta Tester Level 4 Ruby visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0JJ"),
        unlockSecret = "BETATESTERLEVEL4",
        codePrefix = "EBT4"
    })

    Cosmetics.register({
        id = "aura:beta_tester_magic_sentry_aura",
        category = "aura",
        name = "Effect Beta Tester (MagicSentryAura)",
        description = "Equips the Beta Tester Magic Sentry Aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0TA"),
        unlockSecret = "BETATESTERMAGICSENTRY",
        codePrefix = "EBTMS"
    })

    Cosmetics.register({
        id = "aura:beta_tester_mana_out_aura",
        category = "aura",
        name = "Effect Beta Tester (Mana Out Aura)",
        description = "Equips the Beta Tester Mana Out Aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0T9"),
        unlockSecret = "BETATESTERMANAOUT",
        codePrefix = "EBTMO"
    })

    Cosmetics.register({
        id = "aura:beta_tester_pink_elden_ring",
        category = "aura",
        name = "Effect Beta Tester (Pink Elden ring)",
        description = "Equips the Beta Tester Pink Elden Ring visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0TX"),
        unlockSecret = "BETATESTERPINKELDEN",
        codePrefix = "EBTPER"
    })

    Cosmetics.register({
        id = "aura:beta_tester_platinum",
        category = "aura",
        name = "Effect Beta Tester (Platinum)",
        description = "Equips the Beta Tester Platinum visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0JA"),
        unlockSecret = "BETATESTERPLATINUM",
        codePrefix = "EBTP"
    })

    Cosmetics.register({
        id = "aura:beta_tester_silver",
        category = "aura",
        name = "Effect Beta Tester (Silver)",
        description = "Equips the Beta Tester Silver visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A05U"),
        unlockSecret = "BETATESTERSILVER",
        codePrefix = "EBTS"
    })

    Cosmetics.register({
        id = "aura:beta_tester_thoms",
        category = "aura",
        name = "Effect Beta Tester (Thoms)",
        description = "Equips the Beta Tester Thoms visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0U9"),
        unlockSecret = "BETATESTERTHOMS",
        codePrefix = "EBTT"
    })

    Cosmetics.register({
        id = "aura:beta_tester_cripple",
        category = "aura",
        name = "Effect Beta Tester Cripple",
        description = "Equips the Beta Tester Cripple visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0SS"),
        unlockSecret = "BETATESTERCRIPPLE",
        codePrefix = "EBTC"
    })

    Cosmetics.register({
        id = "aura:beta_tester_nuke_stuff",
        category = "aura",
        name = "Effect Beta Tester Nuke stuff",
        description = "Equips the Beta Tester Nuke Stuff visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0S0"),
        unlockSecret = "BETATESTERNUKE",
        codePrefix = "EBTN"
    })

    Cosmetics.register({
        id = "aura:special_level_5",
        category = "aura",
        name = "Effect Special (Level 5)",
        description = "Equips the Special Level 5 visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0FV"),
        unlockSecret = "SPECIALLEVEL5",
        codePrefix = "ES5"
    })
    Cosmetics.register({
        id = "aura:cosmictouch",
        category = "aura",
        name = "Cosmic Touch",
        description = "Equips the Cosmic Touch visual aura.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0TU"),
        unlockSecret = "COSMICTOUCH",
        codePrefix = "CT"
    })
    Cosmetics.register({
        id = "wings:none",
        category = "wings",
        name = "No Wings",
        description = "Removes every equipped wing cosmetic.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNCancel.blp",
        isDefault = true
    })
    Cosmetics.register({
        id = "wings:black_wingsuit",
        category = "wings",
        name = "Black Wingsuit",
        description = "Equips the Black Wingsuit effect from the classic map.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp",
        abilityId = FourCC("A0SR"),
        unlockSecret = "BLACKWINGSUIT",
        codePrefix = "BW"
    })
    Cosmetics.register({
        id = "wings:jetpack",
        category = "wings",
        name = "Jetpack",
        description = "Equips the Jetpack effect from the classic map.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNEngineeringUpgrade.blp",
        abilityId = FourCC("A0UM"),
        unlockSecret = "JETPACK",
        codePrefix = "JP"
    })
    Cosmetics.register({
        id = "wings:redbull",
        category = "wings",
        name = "redbull",
        description = "Equips the redbull wings effect from the classic map.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNEngineeringUpgrade.blp",
        abilityId = FourCC("A0SO"),
        unlockSecret = "REDBULL",
        codePrefix = "RB"
    })
    Cosmetics.register({
        id = "wings:cosmic",
        category = "wings",
        name = "cosmic",
        description = "Equips the cosmic wings effect from the classic map.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNEngineeringUpgrade.blp",
        abilityId = FourCC("A0TT"),
        unlockSecret = "COSMIC",
        codePrefix = "COSW"
    })
    Cosmetics.register({
        id = "skin:default",
        category = "skin",
        name = "Default Skin",
        icon = "ReplaceableTextures\\CommandButtons\\BTNSelectHeroOn.blp",
        isDefault = true
    })
    Cosmetics.register({
        id = "skin:murloc:enhanced",
        category = "skin",
        race = "Murloc",
        name = "Enhanced Murloc",
        description = "Uses the classic Enhanced Form appearance.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNMurgalSlave.blp",
        skinId = FourCC("h059"),
        unlockSecret = "SKINMURLOCENHANCED",
        codePrefix = "SME"
    })

    local LEGACY_SKINS = {
        { "skin:arachnid:mini_foss", "Arachnid", "Mini Foss", "S01Y", "SAF" },
        { "skin:gnoll:treasure_hunter", "Gnoll", "Treasure Hunter", "S01V", "SGTH" },
        { "skin:goblin:artist", "Goblin", "Goblin Artist", "S01R", "SGA" },
        { "skin:magnataur:brown", "Magnataur", "Brown Magnataur", "S01P", "SMB" },
        { "skin:zergling:felhound", "Zergling", "Felhound", "S01O", "SZF" },
        { "skin:tauren:space_marine", "Tauren", "Space Marine", "S01L", "STSM" },
        { "skin:huntress:alliance", "Huntress", "Alliance Huntress", "S01X", "SHA" },
        { "skin:tauren:barbarian", "Tauren", "Tauren Barbarian", "S01I", "STB" },
        { "skin:tauren:dreamwalker", "Tauren", "Tauren Dreamwalker", "S023", "STD" },
        { "skin:demonologist:reaper", "Demonologist", "Demon Reaper", "S01G", "SDR" },
        { "skin:demonologist:ahriman", "Demonologist", "Ahriman", "S01S", "SDA" },
        { "skin:demonologist:zarah", "Demonologist", "Zarah", "S020", "SDZ" },
        { "skin:demonologist:kael", "Demonologist", "Kael", "S01U", "SDK" },
        { "skin:demonologist:puppet_master", "Demonologist", "Puppet Master", "S01Z", "SDPM" },
        { "skin:troll:dark", "Troll", "Dark Troll", "S01E", "STDQ" },
        { "skin:makrura:tortollan_red", "Makrura", "Red Tortollan", "S017", "SMR" },
        { "skin:makrura:tortollan_blue", "Makrura", "Blue Tortollan", "S01H", "SMBL" },
        { "skin:pirate:smiley", "Pirate", "Smiley Pirate", "S016", "SPS" },
        { "skin:pirate:cute_lass", "Pirate", "Cute Lass", "S01J", "SPCL" },
        { "skin:pirate:monkey_d_luffy", "Pirate", "Monkey D. Luffy", "S01W", "SPMDL" },
        { "skin:dryad:keeper", "Dryad", "Dryad Keeper", "S00Q", "SDKP" },
        { "skin:murloc:blue_devil", "Murloc", "Blue Devil", "S00P", "SMBD" },
        { "skin:murloc:fishing", "Murloc", "Fishing Murloc", "S022", "SMF" },
        { "skin:radioactive:amumu", "Radioactive", "Amumu", "S021", "SRA" },
        { "skin:moltenious:ragnaros", "Moltenious", "Ragnaros", "S024", "SMOR" },
        { "skin:granitacles:panda_wardancer", "Granitacles", "Panda Wardancer", "S01K", "SGPW" },
        { "skin:demonicus:reaper", "Demonicus", "Demonicus Reaper", "S01F", "SDER" },
        { "skin:noxious:purple_hydra", "Noxious", "Purple Hydra", "S00V", "SNPH" },
        { "skin:lucidious:demon_hunter", "Lucidious", "Demon Hunter", "S00R", "SLDH" },
        { "skin:lucidious:naga_enchantress", "Lucidious", "Naga Enchantress", "S01T", "SLNE" }
    }
    local legacySkinIndex = 1
    while legacySkinIndex <= #LEGACY_SKINS do
        local entry = LEGACY_SKINS[legacySkinIndex]
        local race = Races.fromName(entry[2])
        local abilityId = FourCC(entry[4])
        local icon = race ~= NullRace.instance() and race:icon() or
            "ReplaceableTextures\\CommandButtons\\BTNSelectHeroOn.blp"

        if rawget(_G, "BlzGetAbilityIcon") then
            local abilityIcon = BlzGetAbilityIcon(abilityId)
            if abilityIcon and abilityIcon ~= "" then
                icon = abilityIcon
            end
        end
        Cosmetics.register({
            id = entry[1],
            category = "skin",
            race = entry[2],
            name = entry[3],
            description = "Classic " .. entry[2] .. " cosmetic skin.",
            icon = icon,
            abilityId = abilityId,
            unlockSecret = string.upper(string.gsub(entry[1], "[^%w]", "")),
            codePrefix = entry[5]
        })
        legacySkinIndex = legacySkinIndex + 1
    end

    -- The owner sends the complete selection through one validated sync path.
    local syncTrigger = CreateTrigger()
    local playerIndex = 0
    while playerIndex < bj_MAX_PLAYER_SLOTS do
        BlzTriggerRegisterPlayerSyncEvent(syncTrigger, Player(playerIndex), CACHE_MISSION, false)
        playerIndex = playerIndex + 1
    end
    TriggerAddAction(syncTrigger, function()
        local playerId, auraMask, wingsMask, raceIndex, selectedSkinIndex =
            string.match(BlzGetTriggerSyncData(), "^(%d+)|(-?%d+)|(-?%d+)|(-?%d+)|(-?%d+)$")
        local player = nil

        playerId = tonumber(playerId)
        auraMask = tonumber(auraMask)
        wingsMask = tonumber(wingsMask)
        raceIndex = tonumber(raceIndex)
        selectedSkinIndex = tonumber(selectedSkinIndex)
        if not playerId or not auraMask or not wingsMask or not raceIndex or not selectedSkinIndex or
            GetPlayerId(GetTriggerPlayer()) ~= playerId then
            return
        end
        player = Player(playerId)
        applySyncedSelection(player, auraMask, wingsMask, raceIndex, selectedSkinIndex)
    end)

    -- Units may already exist when the last profile packet arrives. Apply the
    -- synchronized cosmetic state once at that exact shared point.
    PlayerProfile.onSynchronized(Cosmetics.applyAllEquipped)

    _G.Cosmetics = Cosmetics
end)

if Debug and Debug.endFile then Debug.endFile() end
