-- ZenUI database bootstrap.

local RUI = ZenUI

local defaults = {
    schemaVersion = 47,
    global = {
        debug = false,
        -- Account-wide last-known character balances. Updated by Zen Bags
        -- whenever a character enters the world or their money changes.
        characterMoney = {},
        -- Diagnostic capture for Project Ebonhold's native Extended Bank
        -- transport.  Stores only the most recent server packet and a small
        -- snapshot of ExtBank-named globals so the protocol can be mapped.
        extBankDebug = {},
        -- Character-specific cache of native Ebonhold Echo Saved Build names.
        -- Only names/current selection are cached; Echo choices remain native.
        echoBuildCache = {},
        -- Per-character Callboard cooldown/history data used by the integrated tracker.
        callboardTracker = { characters = {} },
        -- Account-wide Zen Mail address book/history. Kept out of profiles so
        -- personal recipient history is not included in profile export strings.
        mail = { contacts = {}, recentRecipients = {} },
    },
    profileKeys = {},
    profiles = {
        Default = {
            appearance = {
                mode = "GLOBAL",
                style = "CLASSIC",
                scale = 1,
                font = "Narrow",
                panelAlpha = 0.96,
                visualStyle = "CLASSIC",
                darkMode = false,
                accent = { 0.92, 0.63, 0.40 },
                background = { 0.035, 0.037, 0.043 },
                border = { 0.15, 0.16, 0.18 },
                text = { 0.90, 0.91, 0.93 },
                mutedText = { 0.55, 0.57, 0.61 },
            },
            scales = {
                unitframes = 1.00,
                party = 1.00,
                raid = 1.00,
                actionbars = 1.00,
                minimap = 1.00,
                chat = 1.00,
                bags = 1.00,
                menu = 1.00,
                zenLootRolls = 1.00,
                blizzardCore = 1.00,
                blizzardServices = 1.00,
                blizzardExtras = 1.00,
                blizzardMenu = 1.00,
                blizzardDialogs = 1.00,
                zenSpellbook = 1.00,
                zenSocial = 1.00,
                zenGuild = 1.00,
                zenDungeonFinder = 1.00,
                zenCharacter = 1.00,
                zenQuestLog = 1.00,
                zenMail = 1.00,
                zenMerchant = 1.00,
                zenBank = 1.00,
                zenTrade = 1.00,
                zenTalents = 1.00,
                zenPVP = 1.00,
                zenStatusBars = 1.00,
                zenAchievements = 1.00,
                zenInspect = 1.00,
                zenTrainer = 1.00,
                zenNPCInteraction = 1.00,
            },
            layout = {
                snapEnabled = true,
                snapSize = 4,
                showGrid = false,
            },
            actionbars = {
                enabled = true,
                hideBlizzardArt = true,
                buttonSize = 34,
                spacing = 4,
                showHotkeys = true,
                showMacroText = false,
                showEmptyButtons = false,
                showPetBar = true,
                showStanceBar = true,
                showTotemBar = true,
                showTotemTimers = true,
                petBehavior = { alpha = 1.00, mouseover = false, visibility = "ALWAYS" },
                stanceBehavior = { alpha = 1.00, mouseover = false, visibility = "ALWAYS" },
                bars = {
                    [1] = { enabled = true, rows = 1, buttons = 12, alpha = 1.00, mouseover = false, visibility = "ALWAYS" },
                    [2] = { enabled = false, rows = 1, buttons = 12, alpha = 1.00, mouseover = false, visibility = "ALWAYS" },
                    [3] = { enabled = false, rows = 12, buttons = 12, alpha = 1.00, mouseover = false, visibility = "ALWAYS" },
                    [4] = { enabled = false, rows = 12, buttons = 12, alpha = 1.00, mouseover = false, visibility = "ALWAYS" },
                    [5] = { enabled = true, rows = 1, buttons = 12, alpha = 1.00, mouseover = false, visibility = "ALWAYS" },
                    [6] = { enabled = true, rows = 1, buttons = 12, alpha = 1.00, mouseover = false, visibility = "ALWAYS" },
                },
            },
            menu = {
                enabled = true,
                hideBlizzard = true,
                showBagButton = true,
                showFreeSlots = true,
                closeOnClick = true,
                -- Separate lightweight launcher for fast toggles such as
                -- Auto Invite. This remains independent of the full R menu.
                showQuickMenu = true,
            },
            minimap = {
                enabled = true,
                size = 180,
                showZone = true,
                showRaidIdentifier = true,
                showClock = true,
                clock24 = true,
                clockOffsetMinutes = 0,
                mouseWheelZoom = true,
                showZoomButtons = false,
                showWorldMapButton = false,
                showTracking = true,
                showMail = true,
                showLFG = true,
                showDifficulty = true,
                showBattlefield = true,
                collectAddonButtons = true,
                collectorColumns = 4,
            },
            tooltip = {
                enabled = true,
                unitBorder = true,
                showHealthBar = true,
                scale = 1.00,
            },
            chat = {
                enabled = true,
                locked = true,
                hideButtons = true,
                fade = false,
                fontSize = 12,
                width = 430,
                height = 180,
                backgroundAlpha = 0.45,
                editBoxAlpha = 0.72,
                editBoxHeight = 28,
                editBoxFontSize = 12,
            },
            bags = {
                enabled = true,
                columns = 12,
                buttonSize = 34,
                spacing = 4,
                showQuality = true,
                showSearch = true,
                -- Safe view-only sorting. No underlying bag/bank slots are moved.
                visualSortBags = false,
                visualSortBank = false,
                containers = {
                    backpack = true,
                    bag1 = true,
                    bag2 = true,
                    bag3 = true,
                    bag4 = true,
                    keyring = true,
                    bank = false,
                    bankBags = false,
                },
            },
            groupTools = {
                -- Opt-in LFG helper. Matching whispers are queued and paced so
                -- multiple near-simultaneous requests are not lost to client/server
                -- invite throttling. Custom triggers are comma-separated.
                autoInvite = false,
                autoInviteTriggers = "inv",
            },
            mail = {
                -- Batch mail actions are paced and confirmed one operation at a time.
                -- Reserve normal bag space so Open All cannot unexpectedly fill every slot.
                keepFreeSlots = 1,
                showSessionTotal = true,
            },
            loot = {
                enabled = true,
                -- D2 auto-roll is deliberately opt-in.  Rules are evaluated
                -- once when START_LOOT_ROLL fires; MANUAL means Zen leaves
                -- the decision entirely to the player.
                autoRollEnabled = false,
                autoRollNotify = true,
                hideRollChat = false,
                autoPassBoPNoNeed = false,
                autoRollRules = {
                    [0] = "MANUAL", -- Poor
                    [1] = "MANUAL", -- Common
                    [2] = "MANUAL", -- Uncommon
                    [3] = "MANUAL", -- Rare
                    [4] = "MANUAL", -- Epic
                },
            },
            blizzard = {
                enabled = true,
                spellbook = true,
                social = true,
                guild = true,
                dungeonFinder = true,
                character = true,
                questLog = true,
                mail = true,
                merchant = true,
                bank = true,
                trade = true,
                talents = true,
                pvp = true,
                xpBar = true,
                reputationBar = true,
                achievements = true,
                inspect = true,
                trainer = true,
                npcDialog = true,
                -- Per-character Zen presentation for Project Ebonhold's
                -- five persistent specialization slots. Names are user-editable;
                -- icons are learned from the dominant tree whenever that spec is active.
                talentSpecNames = {},
                talentSpecIcons = {},
                -- Modifier used for the Bank/Void quick-drop secondary route.
                -- Normal right-click keeps the native Bag <-> Bank / Void -> Bag
                -- behavior; modifier + right-click selects the alternate target.
                bankQuickDropModifier = "SHIFT",
                -- Phase A panel preference: keep the Guild roster's offline
                -- filter exactly as the user last left it.
                guildShowOffline = true,
                -- Phase B unified-bank visibility filters. Void Storage starts
                -- hidden and is explicitly opened with V on each banker visit.
                bankContainers = {
                    bank = true,
                    bag1 = true,
                    bag2 = true,
                    bag3 = true,
                    bag4 = true,
                    bag5 = true,
                    bag6 = true,
                    bag7 = true,
                    void = false,
                },
                corePanels = true,
                servicePanels = true,
                extraPanels = true,
                gameMenu = true,
                dialogs = true,
                buttons = true,
                fonts = true,
                accentLine = true,
            },
            unitframes = {
                enabled = true,
                hideBlizzard = true,
                showCastbars = true,
                showTargetTarget = true,
                showPlayerAuras = false,
                showTargetAuras = true,
                showFocusAuras = false,
                showPetAuras = false,
                playerBuffPosition = "TOP",
                playerDebuffPosition = "BOTTOM",
                targetBuffPosition = "TOP",
                targetDebuffPosition = "BOTTOM",
                focusBuffPosition = "TOP",
                focusDebuffPosition = "BOTTOM",
                petBuffPosition = "TOP",
                petDebuffPosition = "BOTTOM",
                -- Legacy 0.9.x/1.0.2 key retained only for migration compatibility.
                targetBuffsAbove = true,
                showClassResources = true,
                showPortraits = false,
                showFocus = true,
                showFocusTarget = true,
                showPet = true,
                showParty = true,
                showRaid = true,
                raid = {
                    groups = 5,
                    orientation = "HORIZONTAL",
                    showGroupLabels = true,
                    showPower = true,
                    showDebuffs = true,
                    showReady = true,
                    showRank = true,
                    healthMode = "PERCENT",
                },
                text = {
                    font = "Default",
                    size = 1.10,
                    style = "OUTLINE",
                    colorMode = "LIGHT",
                    customColor = { 1.00, 1.00, 1.00 },
                    autoFit = true,
                    minScale = 0.70,
                    showName = true,
                    showLevel = true,
                    showClass = true,
                    showHealthValue = true,
                    showHealthPercent = true,
                    showPowerValue = true,
                    showPowerMax = true,
                },
            },
            movers = {
                TestPanel = {
                    point = "CENTER",
                    relativePoint = "CENTER",
                    x = 0,
                    y = -120,
                },
                PlayerFrame = {
                    point = "CENTER",
                    relativePoint = "CENTER",
                    x = -250,
                    y = -185,
                },
                TargetFrame = {
                    point = "CENTER",
                    relativePoint = "CENTER",
                    x = 250,
                    y = -185,
                },
                FocusFrame = {
                    point = "CENTER",
                    relativePoint = "CENTER",
                    x = 250,
                    y = -300,
                },
                PetFrame = {
                    point = "CENTER",
                    relativePoint = "CENTER",
                    x = -250,
                    y = -300,
                },
                PartyFrames = {
                    point = "CENTER",
                    relativePoint = "CENTER",
                    x = -430,
                    y = 70,
                },
                RaidFrames = {
                    point = "TOPLEFT",
                    relativePoint = "TOPLEFT",
                    x = 24,
                    y = -190,
                },
                ActionBar1 = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -370 },
                ActionBar2 = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -210 },
                ActionBar3 = { point = "CENTER", relativePoint = "CENTER", x = 470, y = -35 },
                ActionBar4 = { point = "CENTER", relativePoint = "CENTER", x = 510, y = -35 },
                ActionBar5 = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -290 },
                ActionBar6 = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -330 },
                PetActionBar = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -245 },
                StanceBar = { point = "CENTER", relativePoint = "CENTER", x = -255, y = -245 },
                MicroMenu = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -22, y = 18 },
                QuickMenu = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -104, y = 18 },
                Minimap = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -24, y = -24 },
                Chat = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 22, y = 48 },
                Bags = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -24, y = 78 },
                ZenLootRolls = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -120 },
            },
            testFrame = {
                shown = false,
            },
        },
    },
}

local function CopyTable(source)
    local destination = {}

    for key, value in pairs(source) do
        if type(value) == "table" then
            destination[key] = CopyTable(value)
        else
            destination[key] = value
        end
    end

    return destination
end

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end


-- ZenUI was renamed from RavioliUI in 0.9.137. Older profiles contain a few
-- brand-prefixed scale/mover keys. Rename those keys in-place before defaults
-- are applied so existing layouts survive the folder/addon rename unchanged.
local function LegacyBrandKey(key)
    if type(key) ~= "string" then return key end
    key = string.gsub(key, "Ravioli", "Zen")
    key = string.gsub(key, "ravioli", "zen")
    key = string.gsub(key, "RAVIOLI", "ZEN")
    return key
end

local function MigrateLegacyBrandKeys(tbl, seen)
    if type(tbl) ~= "table" then return tbl end
    seen = seen or {}
    if seen[tbl] then return tbl end
    seen[tbl] = true

    local changes = {}
    for key, value in pairs(tbl) do
        if type(value) == "table" then MigrateLegacyBrandKeys(value, seen) end
        local newKey = LegacyBrandKey(key)
        if newKey ~= key then
            table.insert(changes, { old = key, new = newKey, value = value })
        end
    end
    for i = 1, #changes do
        local change = changes[i]
        if tbl[change.new] == nil then tbl[change.new] = change.value end
        tbl[change.old] = nil
    end
    return tbl
end

function RUI:MigrateLegacyBrandKeys(tbl)
    return MigrateLegacyBrandKeys(tbl)
end

local function MigrateDatabase(database, oldSchema)
    if oldSchema < 2 then
        for _, profile in pairs(database.profiles or {}) do
            profile.movers = profile.movers or {}

            -- Preserve the 0.0.1 test-panel position as the first real mover.
            if profile.testFrame then
                profile.movers.TestPanel = profile.movers.TestPanel or {}
                local mover = profile.movers.TestPanel
                mover.point = profile.testFrame.point or mover.point or "CENTER"
                mover.relativePoint = profile.testFrame.relativePoint or mover.relativePoint or "CENTER"
                mover.x = profile.testFrame.x or mover.x or 0
                mover.y = profile.testFrame.y or mover.y or -120
            end
        end
    end

    if oldSchema < 3 then
        for _, profile in pairs(database.profiles or {}) do
            profile.appearance = profile.appearance or {}

            -- 0.0.1/0.0.2 stored these at the profile root.
            if profile.scale ~= nil then
                profile.appearance.scale = profile.scale
            end
            if type(profile.accent) == "table" then
                profile.appearance.accent = CopyTable(profile.accent)
            end

            profile.scale = nil
            profile.accent = nil
            ApplyDefaults(profile.appearance, defaults.profiles.Default.appearance)
        end
    end

    if oldSchema < 4 then
        for _, profile in pairs(database.profiles or {}) do
            profile.unitframes = profile.unitframes or {}
            ApplyDefaults(profile.unitframes, defaults.profiles.Default.unitframes)

            profile.movers = profile.movers or {}
            if not profile.movers.PlayerFrame then
                profile.movers.PlayerFrame = CopyTable(defaults.profiles.Default.movers.PlayerFrame)
            end
            if not profile.movers.TargetFrame then
                profile.movers.TargetFrame = CopyTable(defaults.profiles.Default.movers.TargetFrame)
            end

            -- 0.1.0 graduates from the development preview to real gameplay frames.
            -- The preview remains available from Settings but starts hidden after upgrade.
            profile.testFrame = profile.testFrame or {}
            profile.testFrame.shown = false
        end
    end

    if oldSchema < 5 then
        for _, profile in pairs(database.profiles or {}) do
            profile.unitframes = profile.unitframes or {}
            ApplyDefaults(profile.unitframes, defaults.profiles.Default.unitframes)
        end
    end

    if oldSchema < 6 then
        for _, profile in pairs(database.profiles or {}) do
            profile.unitframes = profile.unitframes or {}
            ApplyDefaults(profile.unitframes, defaults.profiles.Default.unitframes)

            profile.movers = profile.movers or {}
            if not profile.movers.FocusFrame then
                profile.movers.FocusFrame = CopyTable(defaults.profiles.Default.movers.FocusFrame)
            end
            if not profile.movers.PetFrame then
                profile.movers.PetFrame = CopyTable(defaults.profiles.Default.movers.PetFrame)
            end
        end
    end


    if oldSchema < 7 then
        for _, profile in pairs(database.profiles or {}) do
            profile.unitframes = profile.unitframes or {}
            ApplyDefaults(profile.unitframes, defaults.profiles.Default.unitframes)

            -- 0.1.3 adds a dedicated, higher-contrast unit-frame typography profile.
            -- Existing users receive the readable defaults without disturbing the
            -- global ZenUI appearance font or accent colour.
            profile.unitframes.text = profile.unitframes.text or {}
            ApplyDefaults(profile.unitframes.text, defaults.profiles.Default.unitframes.text)

            profile.movers = profile.movers or {}
            if not profile.movers.PartyFrames then
                profile.movers.PartyFrames = CopyTable(defaults.profiles.Default.movers.PartyFrames)
            end
        end
    end

    if oldSchema < 8 then
        for _, profile in pairs(database.profiles or {}) do
            profile.unitframes = profile.unitframes or {}
            profile.unitframes.text = profile.unitframes.text or {}

            -- 0.1.5 adds adaptive UnitFrame text layout and per-field visibility.
            -- Existing typography choices are preserved; only new layout/content
            -- controls receive defaults.
            ApplyDefaults(profile.unitframes.text, defaults.profiles.Default.unitframes.text)
        end
    end

    if oldSchema < 9 then
        for _, profile in pairs(database.profiles or {}) do
            profile.unitframes = profile.unitframes or {}
            ApplyDefaults(profile.unitframes, defaults.profiles.Default.unitframes)
            profile.unitframes.raid = profile.unitframes.raid or {}
            ApplyDefaults(profile.unitframes.raid, defaults.profiles.Default.unitframes.raid)

            profile.movers = profile.movers or {}
            if not profile.movers.RaidFrames then
                profile.movers.RaidFrames = CopyTable(defaults.profiles.Default.movers.RaidFrames)
            end
        end
    end

    if oldSchema < 10 then
        for _, profile in pairs(database.profiles or {}) do
            profile.actionbars = profile.actionbars or {}
            ApplyDefaults(profile.actionbars, defaults.profiles.Default.actionbars)
            profile.actionbars.bars = profile.actionbars.bars or {}
            ApplyDefaults(profile.actionbars.bars, defaults.profiles.Default.actionbars.bars)

            profile.movers = profile.movers or {}
            local actionMovers = { "ActionBar1", "ActionBar2", "ActionBar3", "ActionBar4", "ActionBar5", "PetActionBar", "StanceBar" }
            for i = 1, #actionMovers do
                local id = actionMovers[i]
                if not profile.movers[id] then
                    profile.movers[id] = CopyTable(defaults.profiles.Default.movers[id])
                end
            end
        end
    end


    if oldSchema < 11 then
        for _, profile in pairs(database.profiles or {}) do
            profile.actionbars = profile.actionbars or {}
            profile.actionbars.bars = profile.actionbars.bars or {}
            profile.movers = profile.movers or {}

            if oldSchema == 10 then
                -- 0.2.0 labelled the four native multi-bars in screen-position order.
                -- 0.2.1 aligns Bar N to Wrath action page N and exposes the previously
                -- hidden page 2 as its own secure bar. Preserve the old physical bar
                -- settings by remapping them to their page-correct Zen numbers.
                local oldBars = profile.actionbars.bars
                local remapped = {
                    [1] = CopyTable(oldBars[1] or defaults.profiles.Default.actionbars.bars[1]),
                    [2] = CopyTable(defaults.profiles.Default.actionbars.bars[2]),
                    [3] = CopyTable(oldBars[4] or defaults.profiles.Default.actionbars.bars[3]),
                    [4] = CopyTable(oldBars[5] or defaults.profiles.Default.actionbars.bars[4]),
                    [5] = CopyTable(oldBars[3] or defaults.profiles.Default.actionbars.bars[5]),
                    [6] = CopyTable(oldBars[2] or defaults.profiles.Default.actionbars.bars[6]),
                }
                profile.actionbars.bars = remapped

                local oldMover2 = profile.movers.ActionBar2 and CopyTable(profile.movers.ActionBar2) or nil
                local oldMover3 = profile.movers.ActionBar3 and CopyTable(profile.movers.ActionBar3) or nil
                local oldMover4 = profile.movers.ActionBar4 and CopyTable(profile.movers.ActionBar4) or nil
                local oldMover5 = profile.movers.ActionBar5 and CopyTable(profile.movers.ActionBar5) or nil

                profile.movers.ActionBar2 = CopyTable(defaults.profiles.Default.movers.ActionBar2)
                profile.movers.ActionBar3 = oldMover4 or CopyTable(defaults.profiles.Default.movers.ActionBar3)
                profile.movers.ActionBar4 = oldMover5 or CopyTable(defaults.profiles.Default.movers.ActionBar4)
                profile.movers.ActionBar5 = oldMover3 or CopyTable(defaults.profiles.Default.movers.ActionBar5)
                profile.movers.ActionBar6 = oldMover2 or CopyTable(defaults.profiles.Default.movers.ActionBar6)
            else
                -- Profiles predating ActionBars can take the new page-aligned defaults directly.
                ApplyDefaults(profile.actionbars, defaults.profiles.Default.actionbars)
                for i = 1, 6 do
                    local id = "ActionBar" .. tostring(i)
                    if not profile.movers[id] then
                        profile.movers[id] = CopyTable(defaults.profiles.Default.movers[id])
                    end
                end
            end

            ApplyDefaults(profile.actionbars, defaults.profiles.Default.actionbars)
        end
    end

    if oldSchema < 12 then
        for _, profile in pairs(database.profiles or {}) do
            profile.actionbars = profile.actionbars or {}
            profile.actionbars.bars = profile.actionbars.bars or {}
            ApplyDefaults(profile.actionbars, defaults.profiles.Default.actionbars)
            ApplyDefaults(profile.actionbars.bars, defaults.profiles.Default.actionbars.bars)
        end
    end

    if oldSchema < 13 then
        for _, profile in pairs(database.profiles or {}) do
            profile.actionbars = profile.actionbars or {}
            profile.actionbars.bars = profile.actionbars.bars or {}
            ApplyDefaults(profile.actionbars, defaults.profiles.Default.actionbars)
            ApplyDefaults(profile.actionbars.bars, defaults.profiles.Default.actionbars.bars)
            profile.actionbars.petBehavior = profile.actionbars.petBehavior or {}
            profile.actionbars.stanceBehavior = profile.actionbars.stanceBehavior or {}
            ApplyDefaults(profile.actionbars.petBehavior, defaults.profiles.Default.actionbars.petBehavior)
            ApplyDefaults(profile.actionbars.stanceBehavior, defaults.profiles.Default.actionbars.stanceBehavior)
        end
    end

    if oldSchema < 14 then
        for _, profile in pairs(database.profiles or {}) do
            profile.menu = profile.menu or {}
            ApplyDefaults(profile.menu, defaults.profiles.Default.menu)
            profile.movers = profile.movers or {}
            if not profile.movers.MicroMenu then
                profile.movers.MicroMenu = CopyTable(defaults.profiles.Default.movers.MicroMenu)
            end
        end
    end

    if oldSchema < 15 then
        for _, profile in pairs(database.profiles or {}) do
            profile.minimap = profile.minimap or {}
            profile.tooltip = profile.tooltip or {}
            ApplyDefaults(profile.minimap, defaults.profiles.Default.minimap)
            ApplyDefaults(profile.tooltip, defaults.profiles.Default.tooltip)
            profile.movers = profile.movers or {}
            if not profile.movers.Minimap then
                profile.movers.Minimap = CopyTable(defaults.profiles.Default.movers.Minimap)
            end
        end
    end

    if oldSchema < 16 then
        for _, profile in pairs(database.profiles or {}) do
            profile.minimap = profile.minimap or {}
            ApplyDefaults(profile.minimap, defaults.profiles.Default.minimap)
        end
    end

    if oldSchema < 17 then
        for _, profile in pairs(database.profiles or {}) do
            profile.chat = profile.chat or {}
            profile.bags = profile.bags or {}
            ApplyDefaults(profile.chat, defaults.profiles.Default.chat)
            ApplyDefaults(profile.bags, defaults.profiles.Default.bags)
            profile.movers = profile.movers or {}
            if not profile.movers.Chat then profile.movers.Chat = CopyTable(defaults.profiles.Default.movers.Chat) end
            if not profile.movers.Bags then profile.movers.Bags = CopyTable(defaults.profiles.Default.movers.Bags) end
        end
    end

    if oldSchema < 18 then
        for _, profile in pairs(database.profiles or {}) do
            profile.bags = profile.bags or {}
            ApplyDefaults(profile.bags, defaults.profiles.Default.bags)
        end
    end

    if oldSchema < 19 then
        for _, profile in pairs(database.profiles or {}) do
            profile.scales = profile.scales or {}
            ApplyDefaults(profile.scales, defaults.profiles.Default.scales)
        end
    end

    if oldSchema < 20 then
        for _, profile in pairs(database.profiles or {}) do
            profile.blizzard = profile.blizzard or {}
            ApplyDefaults(profile.blizzard, defaults.profiles.Default.blizzard)
        end
    end

    if oldSchema < 21 then
        for _, profile in pairs(database.profiles or {}) do
            profile.scales = profile.scales or {}
            ApplyDefaults(profile.scales, defaults.profiles.Default.scales)
        end
    end

    if oldSchema < 22 then
        for _, profile in pairs(database.profiles or {}) do
            profile.scales = profile.scales or {}
            profile.blizzard = profile.blizzard or {}
            ApplyDefaults(profile.scales, defaults.profiles.Default.scales)
            ApplyDefaults(profile.blizzard, defaults.profiles.Default.blizzard)
        end
    end

    if oldSchema < 23 then
        for _, profile in pairs(database.profiles or {}) do
            profile.scales = profile.scales or {}
            profile.blizzard = profile.blizzard or {}
            ApplyDefaults(profile.scales, defaults.profiles.Default.scales)
            ApplyDefaults(profile.blizzard, defaults.profiles.Default.blizzard)
        end
    end

    if oldSchema < 24 then
        for _, profile in pairs(database.profiles or {}) do
            profile.blizzard = profile.blizzard or {}
            ApplyDefaults(profile.blizzard, defaults.profiles.Default.blizzard)
        end
    end

    if oldSchema < 25 then
        for _, profile in pairs(database.profiles or {}) do
            profile.scales = profile.scales or {}
            profile.blizzard = profile.blizzard or {}
            ApplyDefaults(profile.scales, defaults.profiles.Default.scales)
            ApplyDefaults(profile.blizzard, defaults.profiles.Default.blizzard)
        end
    end

    if oldSchema < 26 then
        for _, profile in pairs(database.profiles or {}) do
            profile.blizzard = profile.blizzard or {}
            ApplyDefaults(profile.blizzard, defaults.profiles.Default.blizzard)
        end
    end

    if oldSchema < 27 then
        for _, profile in pairs(database.profiles or {}) do
            profile.scales = profile.scales or {}
            profile.blizzard = profile.blizzard or {}
            ApplyDefaults(profile.scales, defaults.profiles.Default.scales)
            ApplyDefaults(profile.blizzard, defaults.profiles.Default.blizzard)
        end
    end

    if oldSchema < 28 then
        for _, profile in pairs(database.profiles or {}) do
            profile.scales = profile.scales or {}
            profile.blizzard = profile.blizzard or {}
            ApplyDefaults(profile.scales, defaults.profiles.Default.scales)
            ApplyDefaults(profile.blizzard, defaults.profiles.Default.blizzard)
        end
    end

    if oldSchema < 29 then
        for _, profile in pairs(database.profiles or {}) do
            profile.scales = profile.scales or {}
            profile.blizzard = profile.blizzard or {}
            ApplyDefaults(profile.scales, defaults.profiles.Default.scales)
            ApplyDefaults(profile.blizzard, defaults.profiles.Default.blizzard)
        end
    end

    if oldSchema < 32 then
        for _, profile in pairs(database.profiles or {}) do
            profile.actionbars = profile.actionbars or {}
            ApplyDefaults(profile.actionbars, defaults.profiles.Default.actionbars)
        end
    end

    if oldSchema < 33 then
        for _, profile in pairs(database.profiles or {}) do
            profile.loot = profile.loot or {}
            profile.scales = profile.scales or {}
            profile.movers = profile.movers or {}
            ApplyDefaults(profile.loot, defaults.profiles.Default.loot)
            ApplyDefaults(profile.scales, defaults.profiles.Default.scales)
            ApplyDefaults(profile.movers, defaults.profiles.Default.movers)
        end
    end

    if oldSchema < 34 then
        for _, profile in pairs(database.profiles or {}) do
            profile.loot = profile.loot or {}
            ApplyDefaults(profile.loot, defaults.profiles.Default.loot)
        end
    end

    if oldSchema < 36 then
        for _, profile in pairs(database.profiles or {}) do
            profile.groupTools = profile.groupTools or {}
            ApplyDefaults(profile.groupTools, defaults.profiles.Default.groupTools)
        end
    end

    if oldSchema < 37 then
        for _, profile in pairs(database.profiles or {}) do
            profile.menu = profile.menu or {}
            ApplyDefaults(profile.menu, defaults.profiles.Default.menu)
            profile.movers = profile.movers or {}
            if not profile.movers.QuickMenu then
                profile.movers.QuickMenu = CopyTable(defaults.profiles.Default.movers.QuickMenu)
            end
        end
    end

    if oldSchema < 39 then
        database.global = database.global or {}
        database.global.echoBuildCache = database.global.echoBuildCache or {}
    end

    if oldSchema < 40 then
        database.global = database.global or {}
        database.global.callboardTracker = database.global.callboardTracker or { characters = {} }
        database.global.callboardTracker.characters = database.global.callboardTracker.characters or {}
    end

    if oldSchema < 43 then
        for _, profile in pairs(database.profiles or {}) do
            profile.groupTools = profile.groupTools or {}
            ApplyDefaults(profile.groupTools, defaults.profiles.Default.groupTools)
        end
    end

    if oldSchema < 44 then
        for _, profile in pairs(database.profiles or {}) do
            profile.unitframes = profile.unitframes or {}
            -- Preserve the old Target-only "buffs above" choice when moving to
            -- the new independent Buff/Debuff Top/Bottom aura layout settings.
            if profile.unitframes.targetBuffsAbove == false then
                profile.unitframes.targetBuffPosition = "BOTTOM"
            else
                profile.unitframes.targetBuffPosition = "TOP"
            end
            ApplyDefaults(profile.unitframes, defaults.profiles.Default.unitframes)
        end
    end

    if oldSchema < 45 then
        database.global = database.global or {}
        database.global.mail = database.global.mail or { contacts = {}, recentRecipients = {} }
        database.global.mail.contacts = database.global.mail.contacts or {}
        database.global.mail.recentRecipients = database.global.mail.recentRecipients or {}
        for _, profile in pairs(database.profiles or {}) do
            profile.mail = profile.mail or {}
            -- Development builds briefly stored address-book data in profiles;
            -- migrate it account-wide if encountered, then keep profiles clean.
            for _,name in ipairs(profile.mail.contacts or {}) do table.insert(database.global.mail.contacts,name) end
            for _,name in ipairs(profile.mail.recentRecipients or {}) do table.insert(database.global.mail.recentRecipients,name) end
            profile.mail.contacts=nil; profile.mail.recentRecipients=nil
            ApplyDefaults(profile.mail, defaults.profiles.Default.mail)
        end
    end

    if oldSchema < 46 then
        for _, profile in pairs(database.profiles or {}) do
            profile.appearance = profile.appearance or {}
            -- Preserve the old Dark Mode choice as the new Obsidian style.
            if not profile.appearance.visualStyle then
                profile.appearance.visualStyle = profile.appearance.darkMode == true and "OBSIDIAN" or "CLASSIC"
            end
            profile.appearance.darkMode = (profile.appearance.visualStyle == "OBSIDIAN")
            ApplyDefaults(profile.appearance, defaults.profiles.Default.appearance)
        end
    end

    if oldSchema < 47 then
        for _, profile in pairs(database.profiles or {}) do
            profile.appearance = profile.appearance or {}
            local a = profile.appearance
            if not a.style then
                a.style = a.visualStyle or (a.darkMode == true and "OBSIDIAN" or "CLASSIC")
            end
            if a.mode ~= "LOCAL" and a.mode ~= "GLOBAL" then
                -- ZenStylingPack defaults to shared styling when EbonAPI exists;
                -- without EbonAPI this resolves transparently to the local profile.
                a.mode = "GLOBAL"
            end
            a.visualStyle = a.style
            a.darkMode = (a.style == "OBSIDIAN")
            ApplyDefaults(a, defaults.profiles.Default.appearance)
        end
    end

    database.schemaVersion = defaults.schemaVersion
end

function RUI:GetCharacterKey()
    local playerName = UnitName("player") or "Unknown"
    local realmName = GetRealmName() or "Unknown"
    return playerName .. " - " .. realmName
end

function RUI:InitializeDatabase()
    local oldSchema = 1

    -- First ZenUI launch: adopt the previous RavioliUI SavedVariables table.
    -- The old name remains listed in the TOC only so WoW loads it for this
    -- migration; ZenUIDB is the sole live database afterward.
    if type(ZenUIDB) ~= "table" and type(_G.RavioliUIDB) == "table" then
        ZenUIDB = CopyTable(_G.RavioliUIDB)
        for _, profile in pairs(ZenUIDB.profiles or {}) do MigrateLegacyBrandKeys(profile) end
        _G.RavioliUIDB = nil
    end

    if type(ZenUIDB) ~= "table" then
        ZenUIDB = CopyTable(defaults)
        oldSchema = defaults.schemaVersion
    else
        for _, profile in pairs(ZenUIDB.profiles or {}) do MigrateLegacyBrandKeys(profile) end
        oldSchema = tonumber(ZenUIDB.schemaVersion) or 1
        ApplyDefaults(ZenUIDB, defaults)
        MigrateDatabase(ZenUIDB, oldSchema)
    end

    local characterKey = self:GetCharacterKey()
    local profileName = ZenUIDB.profileKeys[characterKey]

    if not profileName or not ZenUIDB.profiles[profileName] then
        profileName = "Default"
        ZenUIDB.profileKeys[characterKey] = profileName
    end

    -- Every active profile receives the current structural defaults.
    ApplyDefaults(ZenUIDB.profiles[profileName], defaults.profiles.Default)

    -- Normalize action-bar indexes on login as well as during live profile
    -- switches. Older/manual imports can contain "1".."6" string keys,
    -- which make the options look populated while runtime numeric lookups miss.
    local activeBars = ZenUIDB.profiles[profileName].actionbars
        and ZenUIDB.profiles[profileName].actionbars.bars
    if type(activeBars) == "table" then
        for i = 1, 6 do
            local stringKey = tostring(i)
            if activeBars[i] == nil and type(activeBars[stringKey]) == "table" then
                activeBars[i] = activeBars[stringKey]
                activeBars[stringKey] = nil
            end
        end
        ApplyDefaults(activeBars, defaults.profiles.Default.actionbars.bars)
    end

    self.dbRoot = ZenUIDB
    self.global = ZenUIDB.global
    self.profileName = profileName
    self.db = ZenUIDB.profiles[profileName]
end

function RUI:ResetProfile()
    if not self.dbRoot or not self.profileName then
        return
    end

    self.dbRoot.profiles[self.profileName] = CopyTable(defaults.profiles.Default)
    self.db = self.dbRoot.profiles[self.profileName]
    self:FireCallback("PROFILE_RESET", self.profileName)
    self:ApplyAppearance("profile-reset")
end

function RUI:ResetAppearance()
    if not self.db then
        return
    end

    local previousMode = self.db.appearance and self.db.appearance.mode
    self.db.appearance = CopyTable(defaults.profiles.Default.appearance)
    if previousMode == "LOCAL" or previousMode == "GLOBAL" then
        self.db.appearance.mode = previousMode
    end
    self:ApplyAppearance("appearance-reset")
end

function RUI:ResetComponentScales()
    if not self.db then return end
    self.db.scales = CopyTable(defaults.profiles.Default.scales)
    self:FireCallback("COMPONENT_SCALE_CHANGED", "all")
    self:ApplyAppearance("scale")
end

function RUI:ResetActionBars()
    if not self.db then
        return
    end

    self.db.actionbars = CopyTable(defaults.profiles.Default.actionbars)
    self:FireCallback("ACTIONBARS_RESET")
end

function RUI:GetDatabaseSchema()
    return defaults.schemaVersion
end

-- Profile-management helpers. Keep the actual defaults private to this file,
-- while allowing imported/new profiles to receive the current schema shape.
function RUI:EnsureProfileDefaults(profile)
    if type(profile) ~= "table" then return false end

    -- Repair profiles produced by older/manual import paths that may have
    -- serialized Action Bar indexes as string keys. The options page could
    -- still look enabled while the runtime's numeric lookup saw no bars.
    if type(profile.actionbars) == "table" and type(profile.actionbars.bars) == "table" then
        local bars = profile.actionbars.bars
        for i = 1, 6 do
            local stringKey = tostring(i)
            if bars[i] == nil and type(bars[stringKey]) == "table" then
                bars[i] = bars[stringKey]
                bars[stringKey] = nil
            end
        end
    end

    if type(profile.unitframes) == "table" and profile.unitframes.targetBuffPosition == nil
        and profile.unitframes.targetBuffsAbove ~= nil then
        profile.unitframes.targetBuffPosition = profile.unitframes.targetBuffsAbove == false and "BOTTOM" or "TOP"
    end

    ApplyDefaults(profile, defaults.profiles.Default)
    return true
end

function RUI:GetDefaultProfileCopy()
    return CopyTable(defaults.profiles.Default)
end
