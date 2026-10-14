-- Slash commands for ZenUI 1.0.23.

local RUI = ZenUI

local function Trim(text)
    return string.gsub(text or "", "^%s*(.-)%s*$", "%1")
end

local function SplitCommand(message)
    local text = Trim(message)
    local command, rest = string.match(text, "^(%S*)%s*(.-)$")
    return string.lower(command or ""), Trim(rest or "")
end

local function PrintHelp()
    RUI:Print("Commands:")
    RUI:Print("|cffffffff/zenui|r - open ZenUI settings")
    RUI:Print("|cffffffff/zenui move|r - toggle mover anchors")
    RUI:Print("|cffffffff/zenui profiles|r - saved profiles and import/export")
    RUI:Print("|cffffffff/zenui bind|r - action-bar and Pet Bar keybind mode")
    RUI:Print("|cffffffff/zenui bags|r - toggle unified bags")
    RUI:Print("|cffffffff/zenui menu|r - toggle the Zen menu")
    RUI:Print("|cffffffff/zenui build|r - list / select Ebonhold Echo Saved Builds")
    RUI:Print("|cffffffff/zenui callboard|r - open Callboard cooldown / raid-save tracker")
    RUI:Print("|cffffffff/zenui reset [movers|appearance]|r - reset Zen settings")
end

local function PrintDeveloperHelp()
    RUI:Print("Developer / diagnostic commands:")
    RUI:Print("/zenui status   /zenui movers   /zenui snap   /zenui theme")
    RUI:Print("/zenui abdebug  - detailed ActionBars runtime ownership probe")
    RUI:Print("/zenui uf   /zenui bars   /zenui runes   /zenui raiddebug")
    RUI:Print("/zenui extbank   /zenui extprice   /zenui extmove")
    RUI:Print("/zenui minimapscan   /zenui affixdoctor   /zenui bagdoctor   /zenui bagtrace on|off")
    RUI:Print("/zenui build doctor   /zenui devpanel")
    RUI:Print("/zenui test   /zenui show   /zenui version   /zenui errors [clear]")
end

local function PrintDoctor()
    local health, failed, errors = RUI:GetHealthSummary()
    RUI:Print("ZenUI health: " .. health .. "  •  modules " .. tostring(#(RUI.moduleOrder or {})) .. "  •  movers " .. tostring(#(RUI.moverOrder or {})))
    if failed > 0 then
        RUI:Print("Module failures: " .. tostring(failed))
        for i = 1, #RUI.moduleOrder do
            local module = RUI.modules[RUI.moduleOrder[i]]
            if module and (module.initializationError or module.enableError) then
                RUI:Print("- " .. tostring(module.name) .. ": " .. tostring(module.initializationError or module.enableError))
            end
        end
    end
    if errors > 0 then
        RUI:Print("Recent runtime errors: " .. tostring(errors) .. " (showing up to 5)")
        local first = math.max(1, #RUI.runtimeErrors - 4)
        for i = first, #RUI.runtimeErrors do
            local e = RUI.runtimeErrors[i]
            RUI:Print("- " .. tostring(e.kind) .. " / " .. tostring(e.context) .. ": " .. tostring(e.message))
        end
    elseif failed == 0 then
        RUI:Print("No module or runtime errors recorded this session.")
    end

    -- Action Bars are one of the few systems built on protected Blizzard
    -- controls. Include ownership details so an Ebonhold/client-side reclaim is
    -- immediately distinguishable from a bad saved profile or module failure.
    local ab = RUI:GetModule("ActionBars")
    local settings = RUI.db and RUI.db.actionbars or nil
    if ab and settings then
        local parent = ActionButton1 and ActionButton1.GetParent and ActionButton1:GetParent() or nil
        local parentName = parent and parent.GetName and parent:GetName() or tostring(parent or "none")
        local artAlpha = MainMenuBarArtFrame and MainMenuBarArtFrame.GetAlpha and MainMenuBarArtFrame:GetAlpha() or -1
        local holderCount = 0
        for i = 1, 6 do if ab.holders and ab.holders[i] then holderCount = holderCount + 1 end end
        RUI:Print("ActionBars: init=" .. tostring(ab.initialized) .. " enabled=" .. tostring(ab.enabled)
            .. " setting=" .. tostring(settings.enabled ~= false) .. " holders=" .. tostring(holderCount)
            .. " Button1 parent=" .. tostring(parentName) .. " art alpha=" .. tostring(artAlpha))
    end

    local ebon = RUI.EbonAPIBridge
    if ebon and type(ebon.IsAvailable) == "function" and ebon:IsAvailable() then
        local state = type(ebon.GetBuildState) == "function" and ebon:GetBuildState() or nil
        local slots = state and state.slots or nil
        local count = 0
        if type(slots) == "table" then for _ in pairs(slots) do count = count + 1 end end
        RUI:Print("EbonAPI: connected " .. tostring(ebon:GetVersion() or "unknown") .. " • normalized Saved Builds=" .. tostring(count))
    elseif ebon then
        RUI:Print("EbonAPI: not connected • ZenUI native Ebonhold fallbacks active")
    end
end

local function PrintMovers()
    RUI:Print("Registered movers:")

    if #RUI.moverOrder == 0 then
        RUI:Print("- none")
        return
    end

    for i = 1, #RUI.moverOrder do
        local id = RUI.moverOrder[i]
        local mover = RUI.movers[id]
        local db = RUI.db and RUI.db.movers and RUI.db.movers[id]
        if mover and db then
            local state = mover.enabled and "active" or "hidden"
            RUI:Print("- " .. mover.label .. " [" .. id .. "] X " .. tostring(db.x or 0) .. " Y " .. tostring(db.y or 0) .. " (" .. state .. ")")
        end
    end
end

local function HandleSnap(argument)
    local layout = RUI.db and RUI.db.layout
    if not layout then
        RUI:Print("Layout database is unavailable.")
        return
    end

    local value = string.lower(argument or "")

    if value == "on" then
        RUI:SetSnapEnabled(true)
    elseif value == "off" then
        RUI:SetSnapEnabled(false)
    elseif value ~= "" then
        if not RUI:SetSnapSize(value) then
            RUI:Print("Snap size must be a number from 1 to 64.")
            return
        end
    else
        RUI:SetSnapEnabled(not layout.snapEnabled)
    end

    if layout.snapEnabled then
        RUI:Print("Mover grid snap enabled at " .. tostring(layout.snapSize or 4) .. "px.")
    else
        RUI:Print("Mover grid snap disabled.")
    end
end

local function PrintTheme()
    local appearance = (RUI.GetAppearanceSettings and RUI:GetAppearanceSettings()) or (RUI.db and RUI.db.appearance)
    if not appearance then
        RUI:Print("Appearance database is unavailable.")
        return
    end

    local accent = appearance.accent or { 1, 1, 1 }
    local styleKey = RUI.GetAppearanceStyleKey and RUI:GetAppearanceStyleKey() or "CLASSIC"
    local style = RUI.GetAppearanceStyle and RUI:GetAppearanceStyle() or nil
    local mode = RUI.GetAppearanceMode and RUI:GetAppearanceMode() or "LOCAL"
    RUI:Print("Appearance: " .. tostring(style and style.label or styleKey) .. " [" .. mode .. "], scale " .. tostring(math.floor((appearance.scale or 1) * 100 + 0.5)) .. "%, font " .. RUI:GetFontName(appearance.font) .. ", opacity " .. tostring(math.floor((appearance.panelAlpha or 1) * 100 + 0.5)) .. "%")
    RUI:Print("Accent RGB: " .. tostring(math.floor((accent[1] or 0) * 100 + 0.5)) .. " / " .. tostring(math.floor((accent[2] or 0) * 100 + 0.5)) .. " / " .. tostring(math.floor((accent[3] or 0) * 100 + 0.5)))
end

local function PrintUnitFrames()
    local settings = RUI.db and RUI.db.unitframes
    local module = RUI:GetModule("UnitFrames")
    if not settings then
        RUI:Print("Unit-frame database is unavailable.")
        return
    end

    RUI:Print("UnitFrames: " .. (settings.enabled and "enabled" or "disabled") .. ", Blizzard frames " .. (settings.hideBlizzard and "hidden" or "visible"))
    RUI:Print("Castbars: " .. (settings.showCastbars and "on" or "off") .. " / Target-of-target: " .. (settings.showTargetTarget and "on" or "off"))
    RUI:Print("Target auras: " .. (settings.showTargetAuras and "on" or "off") .. " / Class resources: " .. (settings.showClassResources and "on" or "off") .. " / Portraits: " .. (settings.showPortraits and "on" or "off"))
    RUI:Print("Focus: " .. (settings.showFocus and "on" or "off") .. " / Focus target: " .. (settings.showFocusTarget and "on" or "off") .. " / Pet: " .. (settings.showPet and "on" or "off") .. " / Party: " .. (settings.showParty and "on" or "off") .. " / Raid: " .. (settings.showRaid and "on" or "off"))
    local raid = settings.raid or {}
    RUI:Print("Raid layout: " .. tostring(raid.groups or 5) .. " group(s) / " .. tostring(raid.orientation or "HORIZONTAL") .. " / health " .. tostring(raid.healthMode or "PERCENT"))
    local text = settings.text or {}
    RUI:Print("Unit text: " .. RUI:GetFontName(text.font or "Default") .. " / " .. tostring(math.floor((text.size or 1) * 100 + 0.5)) .. "% / " .. tostring(text.style or "OUTLINE") .. " / " .. tostring(text.colorMode or "LIGHT"))
    RUI:Print("Text fit: " .. (text.autoFit == false and "off" or "on") .. " / min " .. tostring(math.floor((text.minScale or 0.70) * 100 + 0.5)) .. "%")
    RUI:Print("Text fields: name " .. (text.showName == false and "off" or "on") ..
        " / level " .. (text.showLevel == false and "off" or "on") ..
        " / class " .. (text.showClass == false and "off" or "on") ..
        " / health " .. (text.showHealthValue == false and "off" or "on") ..
        " / health% " .. (text.showHealthPercent == false and "off" or "on") ..
        " / power " .. (text.showPowerValue == false and "off" or "on") ..
        " / power max " .. (text.showPowerMax == false and "off" or "on"))
    if module then
        RUI:Print("Runtime: Blizzard hidden " .. (module.blizzardHidden and "yes" or "no") .. ", pending settings " .. (module.pendingSettings and "yes" or "no"))
    end
end


local function PrintRaidDiagnostics()
    local module = RUI:GetModule("UnitFrames")
    local count = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    local playerRaid = UnitInRaid and UnitInRaid("player") or nil
    RUI:Print("Raid debug: count=" .. tostring(count) .. " / UnitInRaid(player)=" .. tostring(playerRaid) ..
        " / showRaid=" .. tostring(RUI.db and RUI.db.unitframes and RUI.db.unitframes.showRaid))

    local limit = math.max(5, tonumber(count) or 0)
    if limit > 40 then limit = 40 end
    for i = 1, limit do
        local unit = "raid" .. tostring(i)
        local rosterName, _, subgroup = GetRaidRosterInfo and GetRaidRosterInfo(i)
        local liveName = UnitName and UnitName(unit)
        local exists = UnitExists and UnitExists(unit)
        local shown = module and module.raidFrames and module.raidFrames[i] and module.raidFrames[i]:IsShown()
        RUI:Print("raid" .. tostring(i) .. ": roster=" .. tostring(rosterName) .. " group=" .. tostring(subgroup) ..
            " / UnitName=" .. tostring(liveName) .. " / exists=" .. tostring(exists) .. " / frame=" .. tostring(shown))
    end
end

local function PrintBarDiagnostics()
    local module = RUI:GetModule("UnitFrames")
    if not module or not module.player then
        RUI:Print("UnitFrames module is unavailable.")
        return
    end

    local function Round(value, places)
        local scale = 10 ^ (places or 0)
        return math.floor((tonumber(value) or 0) * scale + 0.5) / scale
    end

    local function Report(label, unit, kind, bar)
        if not bar or not bar.fill then return end

        local current, maximum
        if kind == "health" then
            current = UnitHealth(unit) or 0
            maximum = UnitHealthMax(unit) or 0
        else
            current = UnitPower(unit) or 0
            maximum = UnitPowerMax(unit) or 0
        end

        local ratio = maximum > 0 and (current / maximum) or 0
        local barWidth = bar:GetWidth() or 0
        local fillWidth = bar.fill:IsShown() and (bar.fill:GetWidth() or 0) or 0
        RUI:Print(label .. ": " .. tostring(current) .. "/" .. tostring(maximum) ..
            " = " .. tostring(Round(ratio * 100, 1)) .. "% | bar " ..
            tostring(Round(barWidth, 1)) .. "px | fill " .. tostring(Round(fillWidth, 1)) .. "px")
    end

    Report("Player health", "player", "health", module.player.health)
    Report("Player power", "player", "power", module.player.power)

    if module.target and UnitExists("target") then
        Report("Target health", "target", "health", module.target.health)
        Report("Target power", "target", "power", module.target.power)
    end

    if module.focus and UnitExists("focus") then
        Report("Focus health", "focus", "health", module.focus.health)
        Report("Focus power", "focus", "power", module.focus.power)
    end

    if module.pet and UnitExists("pet") then
        Report("Pet health", "pet", "health", module.pet.health)
        Report("Pet power", "pet", "power", module.pet.power)
    end

    if module.partyFrames then
        for i = 1, 4 do
            local frame = module.partyFrames[i]
            local unit = "party" .. tostring(i)
            if frame and UnitExists(unit) then
                Report("Party" .. tostring(i) .. " health", unit, "health", frame.health)
                Report("Party" .. tostring(i) .. " power", unit, "power", frame.power)
            end
        end
    end
end

local function PrintRuneDiagnostics()
    local _, classToken = UnitClass("player")
    if classToken ~= "DEATHKNIGHT" then
        RUI:Print("Rune diagnostics are only available on a Death Knight.")
        return
    end

    if not GetRuneCooldown then
        RUI:Print("GetRuneCooldown is unavailable on this client/core.")
        return
    end

    local names = { [1] = "Blood", [2] = "Unholy", [3] = "Frost", [4] = "Death" }
    local now = GetTime()
    for i = 1, 6 do
        local runeType = GetRuneType and GetRuneType(i) or 4
        local startTime, duration, ready = GetRuneCooldown(i)
        startTime = tonumber(startTime) or 0
        duration = tonumber(duration) or 0
        local progress = 1
        if ready == false or ready == 0 then
            progress = duration > 0 and math.max(0, math.min(1, (now - startTime) / duration)) or 0
        elseif ready == nil and startTime > 0 and duration > 1.5 then
            progress = math.max(0, math.min(1, (now - startTime) / duration))
        end
        RUI:Print("Rune " .. tostring(i) .. " " .. tostring(names[runeType] or "Unknown") ..
            ": ready=" .. tostring(ready) .. " start=" .. string.format("%.2f", startTime) ..
            " duration=" .. string.format("%.2f", duration) .. " fill=" ..
            tostring(math.floor(progress * 100 + 0.5)) .. "%")
    end
end


local function PrintActionBarDebug()
    local ab = RUI:GetModule("ActionBars")
    local settings = RUI.db and RUI.db.actionbars or nil

    RUI:Print("--- ActionBars runtime debug ---")
    if not ab then
        RUI:Print("ActionBars module: MISSING")
        return
    end

    RUI:Print("module initialized=" .. tostring(ab.initialized) ..
        " enabled=" .. tostring(ab.enabled) ..
        " initError=" .. tostring(ab.initializationError or "none") ..
        " enableError=" .. tostring(ab.enableError or "none"))
    RUI:Print("db enabled=" .. tostring(settings and settings.enabled ~= false) ..
        " hideBlizzardArt=" .. tostring(settings and settings.hideBlizzardArt == true) ..
        " combat=" .. tostring(InCombatLockdown and InCombatLockdown() or false))

    local function FrameName(frame)
        if not frame then return "nil" end
        if frame.GetName then
            local name = frame:GetName()
            if name and name ~= "" then return name end
        end
        return tostring(frame)
    end

    local function FrameState(label, frame)
        if not frame then
            RUI:Print(label .. ": MISSING")
            return
        end
        local parent = frame.GetParent and frame:GetParent() or nil
        local shown = frame.IsShown and frame:IsShown() or "n/a"
        local visible = frame.IsVisible and frame:IsVisible() or "n/a"
        local width = frame.GetWidth and math.floor((frame:GetWidth() or 0) + 0.5) or 0
        local height = frame.GetHeight and math.floor((frame:GetHeight() or 0) + 0.5) or 0
        RUI:Print(label .. ": shown=" .. tostring(shown) ..
            " visible=" .. tostring(visible) ..
            " parent=" .. FrameName(parent) ..
            " size=" .. tostring(width) .. "x" .. tostring(height))
    end

    for i = 1, 6 do
        local holder = ab.holders and ab.holders[i] or nil
        FrameState("holder" .. tostring(i), holder)
        if holder and holder.GetAttribute then
            RUI:Print(" holder" .. tostring(i) .. " actionpage=" .. tostring(holder:GetAttribute("actionpage")) ..
                " state-page=" .. tostring(holder:GetAttribute("state-page")))
        end
    end

    local button = ab.customButtons and ab.customButtons[1] and ab.customButtons[1][1] or nil
    FrameState("custom button 1/1", button)
    if button then
        local protected = button.IsProtected and button:IsProtected() or "n/a"
        local id = button.GetID and button:GetID() or "n/a"
        local action = button.GetAttribute and button:GetAttribute("action") or nil
        local actionpage = button.GetAttribute and button:GetAttribute("actionpage") or nil
        local useParent = button.GetAttribute and button:GetAttribute("useparent-actionpage") or nil
        local kind = button.GetAttribute and button:GetAttribute("type") or nil
        local statehidden = button.GetAttribute and button:GetAttribute("statehidden") or nil
        RUI:Print(" button1 id=" .. tostring(id) ..
            " protected=" .. tostring(protected) ..
            " type=" .. tostring(kind) ..
            " action=" .. tostring(action) ..
            " actionpage=" .. tostring(actionpage) ..
            " useparent-actionpage=" .. tostring(useParent) ..
            " statehidden=" .. tostring(statehidden))

        if ActionButton_UpdateAction then
            local ok, err = pcall(ActionButton_UpdateAction, button)
            RUI:Print(" ActionButton_UpdateAction probe=" .. tostring(ok) .. (ok and "" or (" error=" .. tostring(err))))
        else
            RUI:Print(" ActionButton_UpdateAction probe=UNAVAILABLE")
        end
    end

    for _, id in ipairs({ "ActionBar1", "ActionBar5", "ActionBar6" }) do
        local mover = RUI.movers and RUI.movers[id] or nil
        local moverFrame = mover and (mover.frame or mover.anchor or mover.target) or nil
        RUI:Print("mover " .. id .. ": exists=" .. tostring(mover ~= nil) ..
            " enabled=" .. tostring(mover and mover.enabled or false) ..
            " target=" .. FrameName(moverFrame))
    end

    FrameState("MainMenuBar", _G.MainMenuBar)
    FrameState("MainMenuBarArtFrame", _G.MainMenuBarArtFrame)
    FrameState("MultiBarBottomLeft", _G.MultiBarBottomLeft)
    FrameState("MultiBarBottomRight", _G.MultiBarBottomRight)
    FrameState("MultiBarLeft", _G.MultiBarLeft)
    FrameState("MultiBarRight", _G.MultiBarRight)
    FrameState("BonusActionBarFrame", _G.BonusActionBarFrame)
    FrameState("VehicleMenuBar", _G.VehicleMenuBar)
    FrameState("Zen hider", ab.blizzardHider)
    FrameState("stock ActionButton1", _G.ActionButton1)
    if _G.ActionButton1 and _G.ActionButton1.GetAttribute then
        RUI:Print(" stock ActionButton1 statehidden=" .. tostring(_G.ActionButton1:GetAttribute("statehidden")) ..
            " action=" .. tostring(_G.ActionButton1:GetAttribute("action")) ..
            " type=" .. tostring(_G.ActionButton1:GetAttribute("type")))
    end

    local currentPage = GetActionBarPage and GetActionBarPage() or _G.CURRENT_ACTIONBAR_PAGE
    local bonusOffset = GetBonusBarOffset and GetBonusBarOffset() or "n/a"
    local vehicle = UnitHasVehicleUI and UnitHasVehicleUI("player") or false
    RUI:Print("paging: current=" .. tostring(currentPage) ..
        " bonusOffset=" .. tostring(bonusOffset) ..
        " vehicle=" .. tostring(vehicle))

    if InCombatLockdown and InCombatLockdown() then
        RUI:Print("ApplySettings probe skipped in combat.")
    elseif ab.ApplySettings then
        local ok, result = pcall(ab.ApplySettings, ab)
        RUI:Print("ApplySettings probe pcall=" .. tostring(ok) ..
            " return=" .. tostring(ok and result or nil) ..
            (ok and "" or (" error=" .. tostring(result))))
        FrameState("MainMenuBar after ApplySettings", _G.MainMenuBar)
        FrameState("Zen hider after ApplySettings", ab.blizzardHider)
    end

    RUI:Print("--- end ActionBars runtime debug ---")
end

local function PrintActionBars()
    local settings = RUI.db and RUI.db.actionbars
    local module = RUI:GetModule("ActionBars")
    if not settings then
        RUI:Print("ActionBar database is unavailable.")
        return
    end

    RUI:Print("ActionBars: " .. (settings.enabled and "enabled" or "disabled") ..
        " / Blizzard art " .. (settings.hideBlizzardArt and "hidden" or "visible") ..
        " / size " .. tostring(settings.buttonSize or 34) .. "px / spacing " .. tostring(settings.spacing or 4) .. "px")
    RUI:Print("Text: hotkeys " .. (settings.showHotkeys and "on" or "off") ..
        " / macro names " .. (settings.showMacroText and "on" or "off") ..
        " / empty buttons " .. (settings.showEmptyButtons and "on" or "off"))
    for i = 1, 6 do
        local bar = settings.bars and settings.bars[i] or {}
        RUI:Print("Bar " .. tostring(i) .. ": " .. (bar.enabled and "on" or "off") .. " / " .. tostring(bar.buttons or 12) .. " buttons / " .. tostring(bar.rows or 1) .. " row(s) / alpha " .. tostring(math.floor((bar.alpha or 1) * 100 + 0.5)) .. "% / mouseover " .. (bar.mouseover and "on" or "off") .. " / visibility " .. tostring(bar.visibility or "ALWAYS"))
    end
    local pet = settings.petBehavior or {}; local stance = settings.stanceBehavior or {}
    RUI:Print("Pet bar: " .. (settings.showPetBar and "on" or "off") .. " / alpha " .. tostring(math.floor((pet.alpha or 1) * 100 + 0.5)) .. "% / mouseover " .. (pet.mouseover and "on" or "off") .. " / visibility " .. tostring(pet.visibility or "ALWAYS"))
    RUI:Print("Stance bar: " .. (settings.showStanceBar and "on" or "off") .. " / alpha " .. tostring(math.floor((stance.alpha or 1) * 100 + 0.5)) .. "% / mouseover " .. (stance.mouseover and "on" or "off") .. " / visibility " .. tostring(stance.visibility or "ALWAYS") ..
        " / pending settings " .. (module and module.pendingSettings and "yes" or "no"))
end


local function PrintExtBankDiagnostics(argument)
    local phase = RUI:GetModule("BlizzardPhaseB")
    local store = RUI.global and RUI.global.extBankDebug or {}
    local arg = string.lower(argument or "")
    if arg == "request" and phase and phase.RequestExtBank then
        local ok = phase:RequestExtBank()
        RUI:Print("ExtBank request " .. (ok and "sent." or "could not be sent."))
    end

    local transport = type(ExtBankOpen) == "function" and type(ExtBankMove) == "function"
    RUI:Print("Ebonhold ExtBank transport: " .. (transport and "detected" or "not detected"))
    RUI:Print("Bridge: " .. (store.bridgeInstalled and "installed" or "not installed") ..
        " / original callback: " .. (store.originalCallbackPresent and "present" or "not seen"))
    if tonumber(store.lastPacketBytes) and tonumber(store.lastPacketBytes) > 0 then
        RUI:Print("Last ExtBank server state: " .. tostring(store.lastPacketBytes) .. " bytes / packet #" .. tostring(store.packetCount or 1))
        if store.decoded then
            RUI:Print("Decoded storage: " .. tostring(store.decodedBagCount or 0) .. " bags / " .. tostring(store.decodedCapacity or 0) .. " slots / " .. tostring(store.decodedItemCount or 0) .. " items")
            if store.detectedMaxSlots then
                RUI:Print("ExtBank maximum: " .. tostring(store.detectedMaxSlots) .. " slots (" .. tostring(store.detectedMaxSlotsSource or "runtime") .. ")")
            elseif store.runtimeInspectForUnlocked ~= nil then
                RUI:Print("ExtBank maximum: not exposed by the loaded client Lua; server-controlled.")
            end
            if tonumber(store.unlockCost) and tonumber(store.unlockCost) > 0 then
                local price = GetCoinText and GetCoinText(tonumber(store.unlockCost)) or (tostring(math.floor(tonumber(store.unlockCost) / 10000)) .. "g")
                RUI:Print("Next ExtBank unlock: " .. tostring(price) .. " (" .. tostring(store.unlockCostSource or "runtime") .. ")")
            end
        elseif store.decodeError then
            RUI:Print("Packet decoder: " .. tostring(store.decodeError))
        end
        local hex = tostring(store.lastPacket or "")
        if hex ~= "" then RUI:Print("Packet prefix: " .. string.sub(hex, 1, 64) .. (#hex > 64 and "..." or "")) end
        RUI:Print("Full capture is saved in ZenUIDB.global.extBankDebug after /reload or logout.")
    else
        RUI:Print("No ExtBank server packet captured yet. Open the bank or use /zenui extbank request.")
    end
    if store.lastRequestError then RUI:Print("Last request error: " .. tostring(store.lastRequestError)) end
    if store.originalCallbackError then RUI:Print("Original ExtBank callback error: " .. tostring(store.originalCallbackError)) end
end
local function CaptureExtPriceDiagnostics()
    local module=RUI:GetModule("BlizzardPhaseB")
    if not module or not module.CaptureExtBankPriceDiagnostics then
        RUI:Print("ExtBank price diagnostics are unavailable.")
        return
    end
    local capture,err=module:CaptureExtBankPriceDiagnostics()
    if not capture then
        RUI:Print("ExtBank price capture failed: "..tostring(err or "unknown"))
        return
    end
    RUI:Print("ExtBank price capture: "..tostring(#(capture.frames or {})).." matching visible UI objects / "..tostring(#(capture.numericTables or {})).." numeric Lua tables.")
    if tonumber(capture.visiblePurchaseCost) and tonumber(capture.visiblePurchaseCost)>0 then
        local price=GetCoinText and GetCoinText(tonumber(capture.visiblePurchaseCost)) or (tostring(math.floor(tonumber(capture.visiblePurchaseCost)/10000)).."g")
        RUI:Print("Visible native purchase price: "..tostring(price))
    else
        RUI:Print("No purchase price was readable from the currently visible UI.")
    end
    RUI:Print("Capture saved to ZenUIDB.global.extBankDebug.priceCapture. /reload, then upload ZenUI.lua if you want me to inspect the full table data.")
end


local function PrintExtMoveDiagnostics(argument)
    local module=RUI:GetModule("BlizzardPhaseB")
    if not module or not module.GetExtBankMoveTrace then
        RUI:Print("ExtBank move tracing is unavailable.")
        return
    end
    local arg=string.lower(argument or "")
    if arg=="clear" then
        module:ClearExtBankMoveTrace()
        RUI:Print("ExtBank move trace cleared.")
        return
    end
    if module.InstallExtBankMoveTrace then module:InstallExtBankMoveTrace() end
    local trace=module:GetExtBankMoveTrace() or {}
    local entries=trace.entries or {}
    RUI:Print("ExtBank move trace: "..tostring(#entries).." saved call(s).")
    local first=math.max(1,#entries-7)
    for i=first,#entries do
        local e=entries[i]
        RUI:Print("#"..tostring(i).."  "..tostring(e.srcBag)..":"..tostring(e.srcSlot).." -> "..tostring(e.dstBag)..":"..tostring(e.dstSlot).."  x"..tostring(e.count or 0))
    end
    RUI:Print("Trace is saved in ZenUIDB.global.extBankDebug.moveTrace after /reload/logout.")
end

local function ToggleSettings()
    local config = RUI:GetModule("Config")
    if config and config.Toggle then
        config:Toggle()
    else
        RUI:Print("Config module is unavailable. Use /zenui status for diagnostics.")
    end
end


local function PrintAffixDoctor(argument)
    RUI:Print("=== ZenUI Affix Doctor ===")
    RUI:Print("Run this with an item inserted at the Enchanted Anvil and the native Affix Book OPEN.")

    local version, build, date, toc
    if GetBuildInfo then version, build, date, toc = GetBuildInfo() end
    if version then
        RUI:Print("Client: " .. tostring(version) .. " build " .. tostring(build) .. " / TOC " .. tostring(toc))
    end

    local function Lower(value)
        return string.lower(tostring(value or ""))
    end

    local function IsStrictMatch(value)
        local text = Lower(value)
        return string.find(text, "affix", 1, true)
            or string.find(text, "forge", 1, true)
            or string.find(text, "anvil", 1, true)
    end

    local function IsBookText(value)
        local text = Lower(value)
        return string.find(text, "affix book", 1, true)
            or (string.find(text, "affix", 1, true) and string.find(text, "book", 1, true))
    end

    local function SafeMember(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
        return nil
    end

    local function SafeMethod(object, method, ...)
        local fn = SafeMember(object, method)
        if type(fn) ~= "function" then return nil end
        local args = { ... }
        local ok, a, b, c, d = pcall(function() return fn(object, unpack(args)) end)
        if ok then return a, b, c, d end
        return nil
    end

    local function ObjectName(object)
        local name = SafeMethod(object, "GetName")
        if name and name ~= "" then return tostring(name) end
        return "<unnamed>"
    end

    local function ObjectType(object)
        return tostring(SafeMethod(object, "GetObjectType") or type(object))
    end

    local function ObjectText(object)
        local text = SafeMethod(object, "GetText")
        if type(text) == "string" and text ~= "" then return text end
        return nil
    end

    local function RegionTexts(frame)
        local results = {}
        if not frame then return results end
        local ok, regions = pcall(function() return { frame:GetRegions() } end)
        if not ok or not regions then return results end
        for i = 1, #regions do
            local region = regions[i]
            local getText = SafeMember(region, "GetText")
            if type(getText) == "function" then
                local text = SafeMethod(region, "GetText")
                if type(text) == "string" and text ~= "" then results[#results + 1] = text end
            end
        end
        return results
    end

    local function ChildCount(frame)
        return tonumber(SafeMethod(frame, "GetNumChildren")) or 0
    end

    local function DescribeFrame(frame)
        if not frame then return "<nil>" end
        local parent = SafeMethod(frame, "GetParent")
        local shown = SafeMethod(frame, "IsShown")
        local width = tonumber(SafeMethod(frame, "GetWidth")) or 0
        local height = tonumber(SafeMethod(frame, "GetHeight")) or 0
        local id = SafeMethod(frame, "GetID")
        local desc = ObjectType(frame) .. " " .. ObjectName(frame)
            .. " parent=" .. (parent and ObjectName(parent) or "nil")
            .. " shown=" .. tostring(shown)
            .. " size=" .. tostring(math.floor(width + 0.5)) .. "x" .. tostring(math.floor(height + 0.5))
            .. " children=" .. tostring(ChildCount(frame))
        if id ~= nil then desc = desc .. " id=" .. tostring(id) end
        return desc
    end

    local function ProbeFields(object)
        local keys = { "affixID", "AffixID", "affixId", "id", "ID", "index", "slot", "spellID", "SpellID", "entryID", "name", "label", "data", "info", "affix" }
        local out = {}
        for i = 1, #keys do
            local key = keys[i]
            local value = SafeMember(object, key)
            local vt = type(value)
            if vt == "string" or vt == "number" or vt == "boolean" then
                out[#out + 1] = key .. "=" .. tostring(value)
            elseif vt == "table" then
                local count = 0
                local scalars = {}
                for subKey, subValue in pairs(value) do
                    count = count + 1
                    local st = type(subValue)
                    if #scalars < 8 and (st == "string" or st == "number" or st == "boolean") then
                        local text = tostring(subValue)
                        if #text > 48 then text = string.sub(text, 1, 45) .. "..." end
                        scalars[#scalars + 1] = tostring(subKey) .. "=" .. text
                    end
                    if count >= 50 then break end
                end
                out[#out + 1] = key .. "=<table:" .. tostring(count) .. (#scalars > 0 and (" " .. table.concat(scalars, ";")) or "") .. ">"
            end
        end
        if #out == 0 then return "" end
        return " | " .. table.concat(out, ", ")
    end

    local mode = string.lower(tostring(argument or ""))
    if mode ~= "scan" then
        RUI:Print("-- Hover-target mode --")
        RUI:Print("Keep the mouse cursor on ONE real Affix Book row while running this command.")

        local focus = GetMouseFocus and GetMouseFocus() or nil
        if not focus then
            RUI:Print("No mouse-focus frame was found.")
            RUI:Print("Hover an affix row, press Enter, type /zenui affixdoctor without moving the mouse, then press Enter.")
            RUI:Print("Use /zenui affixdoctor scan only if hover mode cannot capture the row.")
            RUI:Print("=== End Affix Doctor ===")
            return
        end

        local function CombinedText(object)
            local parts = {}
            local own = ObjectText(object)
            if own and own ~= "" then parts[#parts + 1] = own end
            local regions = RegionTexts(object)
            for i = 1, #regions do
                local text = regions[i]
                local duplicate = false
                for j = 1, #parts do
                    if parts[j] == text then duplicate = true break end
                end
                if not duplicate then parts[#parts + 1] = text end
            end
            if #parts == 0 then return nil end
            return table.concat(parts, " | ")
        end

        local function ProbeAffixFields(object)
            local keys = {
                "affixID", "AffixID", "affixId", "affix_id", "affix",
                "spellID", "SpellID", "spellId", "entryID", "entryId",
                "id", "ID", "index", "slot", "buttonIndex", "rowIndex",
                "name", "label", "title", "description", "desc", "text",
                "rank", "tier", "quality", "category", "type",
                "learned", "known", "owned", "collected", "unlocked", "isLearned", "isKnown", "isOwned",
                "selected", "active", "available", "eligible", "state",
                "data", "info", "entry", "record", "payload",
                "affixes", "affixList", "entries", "rows", "buttons", "items", "list", "results", "dataset", "dataProvider"
            }
            local out = {}
            for i = 1, #keys do
                local key = keys[i]
                local value = SafeMember(object, key)
                local vt = type(value)
                if vt == "string" or vt == "number" or vt == "boolean" then
                    local text = tostring(value)
                    if #text > 80 then text = string.sub(text, 1, 77) .. "..." end
                    out[#out + 1] = key .. "=" .. text
                elseif vt == "table" then
                    local count = 0
                    local scalars = {}
                    for subKey, subValue in pairs(value) do
                        count = count + 1
                        local st = type(subValue)
                        if #scalars < 12 and (st == "string" or st == "number" or st == "boolean") then
                            local text = tostring(subValue)
                            if #text > 55 then text = string.sub(text, 1, 52) .. "..." end
                            scalars[#scalars + 1] = tostring(subKey) .. "=" .. text
                        end
                        if count >= 100 then break end
                    end
                    out[#out + 1] = key .. "=<table:" .. tostring(count) .. (#scalars > 0 and (" " .. table.concat(scalars, ";")) or "") .. ">"
                end
            end

            local attributes = { "affixID", "affixId", "spellID", "entryID", "index", "rank", "tier", "learned", "known", "selected" }
            for i = 1, #attributes do
                local key = attributes[i]
                local value = SafeMethod(object, "GetAttribute", key)
                local vt = type(value)
                if vt == "string" or vt == "number" or vt == "boolean" then
                    out[#out + 1] = "attr." .. key .. "=" .. tostring(value)
                end
            end

            if #out == 0 then return "" end
            return " | " .. table.concat(out, ", ")
        end

        local function DescribeDetailed(object)
            local text = CombinedText(object)
            local scripts = {}
            if SafeMethod(object, "GetScript", "OnClick") then scripts[#scripts + 1] = "OnClick" end
            if SafeMethod(object, "GetScript", "OnEnter") then scripts[#scripts + 1] = "OnEnter" end
            if SafeMethod(object, "GetScript", "OnLeave") then scripts[#scripts + 1] = "OnLeave" end
            return DescribeFrame(object)
                .. (text and (" text=[" .. tostring(text) .. "]") or "")
                .. (#scripts > 0 and (" scripts=" .. table.concat(scripts, "/")) or "")
                .. ProbeAffixFields(object)
        end

        RUI:Print("MOUSE: " .. DescribeDetailed(focus))

        local ancestry = {}
        local current = focus
        for level = 0, 8 do
            if not current then break end
            ancestry[#ancestry + 1] = current
            if level > 0 then RUI:Print("P" .. tostring(level) .. ": " .. DescribeDetailed(current)) end
            current = SafeMethod(current, "GetParent")
        end

        RUI:Print("-- Direct global names for mouse/parents --")
        local globalRefs = 0
        for key, value in pairs(_G) do
            if type(key) == "string" then
                for i = 1, #ancestry do
                    if value == ancestry[i] then
                        globalRefs = globalRefs + 1
                        RUI:Print("GLOBAL " .. key .. " -> P" .. tostring(i - 1))
                        break
                    end
                end
            end
            if globalRefs >= 20 then break end
        end
        if globalRefs == 0 then RUI:Print("No direct _G name points at the hovered row or its first parents.") end

        local bestRoot = nil
        local bestScore = -1
        for i = 2, #ancestry do
            local candidate = ancestry[i]
            local count = ChildCount(candidate)
            local width = tonumber(SafeMethod(candidate, "GetWidth")) or 0
            local height = tonumber(SafeMethod(candidate, "GetHeight")) or 0
            if count >= 2 and count <= 120 and width >= 100 and height >= 40 then
                local score = 0
                if count >= 4 then score = score + 3 end
                if count <= 40 then score = score + 2 end
                if width >= 180 then score = score + 1 end
                if height >= 120 then score = score + 1 end
                if i <= 5 then score = score + 2 end
                if score > bestScore then bestScore = score; bestRoot = candidate end
            end
        end
        bestRoot = bestRoot or ancestry[2] or focus

        RUI:Print("-- Immediate row/list neighborhood --")
        RUI:Print("ROOT: " .. DescribeDetailed(bestRoot))
        local okChildren, children = pcall(function() return { bestRoot:GetChildren() } end)
        local printed = 0
        if okChildren and children then
            for i = 1, #children do
                local child = children[i]
                local text = CombinedText(child)
                local objectType = ObjectType(child)
                if objectType == "Button" or (text and text ~= "") or ChildCount(child) > 0 then
                    printed = printed + 1
                    RUI:Print("ROW " .. tostring(printed) .. ": " .. DescribeDetailed(child))
                    if printed >= 40 then break end
                end
            end
        end
        if printed == 0 then RUI:Print("No immediate sibling rows/text objects found under the selected root.") end

        RUI:Print("-- Tooltip currently under mouse --")
        local tooltipLines = 0
        if GameTooltip and SafeMethod(GameTooltip, "IsShown") then
            local numLines = tonumber(SafeMethod(GameTooltip, "NumLines")) or 0
            for i = 1, math.min(numLines, 12) do
                local left = _G["GameTooltipTextLeft" .. tostring(i)]
                local right = _G["GameTooltipTextRight" .. tostring(i)]
                local leftText = left and SafeMethod(left, "GetText") or nil
                local rightText = right and SafeMethod(right, "GetText") or nil
                if leftText or rightText then
                    tooltipLines = tooltipLines + 1
                    RUI:Print("TT" .. tostring(i) .. ": " .. tostring(leftText or "") .. (rightText and (" || " .. tostring(rightText)) or ""))
                end
            end
        end
        if tooltipLines == 0 then RUI:Print("No GameTooltip text captured. Hover the affix name/icon itself if possible.") end

        RUI:Print("=== End Affix Doctor ===")
        RUI:Print("Send me the full hover-target output. If it captures the wrong control, use /zenui affixdoctor scan as a fallback.")
        return
    end

    RUI:Print("-- Broad scan fallback --")
    RUI:Print("-- Matching named globals --")
    local globalCount = 0
    local globalKeys = {}
    for key in pairs(_G) do
        if type(key) == "string" and IsStrictMatch(key) then globalKeys[#globalKeys + 1] = key end
    end
    table.sort(globalKeys)
    for i = 1, math.min(#globalKeys, 35) do
        local key = globalKeys[i]
        local value = _G[key]
        globalCount = globalCount + 1
        if type(value) == "table" then
            local entries = 0
            local methods = {}
            for childKey, childValue in pairs(value) do
                entries = entries + 1
                if type(childKey) == "string" and (IsStrictMatch(childKey) or type(childValue) == "function") and #methods < 10 then
                    methods[#methods + 1] = tostring(childKey) .. ":" .. type(childValue)
                end
                if entries >= 500 then break end
            end
            RUI:Print("G " .. key .. " = table (~" .. tostring(entries) .. " keys)" .. (#methods > 0 and (" {" .. table.concat(methods, ", ") .. "}") or ""))
        else
            local objectType = SafeMethod(value, "GetObjectType")
            if objectType then
                RUI:Print("G " .. key .. " = " .. DescribeFrame(value) .. ProbeFields(value))
            else
                RUI:Print("G " .. key .. " = " .. type(value) .. " " .. tostring(value))
            end
        end
    end
    if globalCount == 0 then RUI:Print("No top-level globals with affix/forge/anvil in the name.") end

    RUI:Print("-- Nested API/service key matches --")
    local nested = {}
    local scannedKeys = 0
    for parentName, parentValue in pairs(_G) do
        if type(parentName) == "string" and type(parentValue) == "table" and parentValue ~= _G then
            local perTable = 0
            for childKey, childValue in pairs(parentValue) do
                perTable = perTable + 1
                scannedKeys = scannedKeys + 1
                if type(childKey) == "string" and IsStrictMatch(childKey) then
                    nested[#nested + 1] = parentName .. "." .. childKey .. " (" .. type(childValue) .. ")"
                    if #nested >= 30 then break end
                end
                if perTable >= 150 or scannedKeys >= 9000 then break end
            end
        end
        if #nested >= 30 or scannedKeys >= 9000 then break end
    end
    table.sort(nested)
    if #nested == 0 then
        RUI:Print("No direct table keys containing affix/forge/anvil found in the bounded scan.")
    else
        for i = 1, #nested do RUI:Print("API " .. nested[i]) end
    end

    RUI:Print("-- Visible UI matches --")
    local visited = {}
    local matches = {}
    local bookOwner = nil
    local nodes = 0

    local function AddMatch(frame, reason)
        if not frame then return end
        local key = tostring(frame) .. "|" .. tostring(reason)
        if visited[key] then return end
        visited[key] = true
        if #matches < 45 then matches[#matches + 1] = { frame = frame, reason = reason } end
    end

    local function ScanFrame(frame, depth)
        if not frame or nodes >= 3500 or depth > 18 then return end
        nodes = nodes + 1
        local name = ObjectName(frame)
        local ownText = ObjectText(frame)
        local texts = RegionTexts(frame)
        local shown = SafeMethod(frame, "IsShown")
        if shown ~= false then
            if name ~= "<unnamed>" and IsStrictMatch(name) then
                AddMatch(frame, "name=" .. name)
            end
            if ownText and IsStrictMatch(ownText) then
                AddMatch(frame, "text=" .. ownText)
                if IsBookText(ownText) and not bookOwner then bookOwner = frame end
            end
            for i = 1, #texts do
                local text = texts[i]
                if IsStrictMatch(text) then
                    AddMatch(frame, "region=" .. text)
                    if IsBookText(text) and not bookOwner then bookOwner = frame end
                end
            end
        end
        local ok, children = pcall(function() return { frame:GetChildren() } end)
        if ok and children then
            for i = 1, #children do ScanFrame(children[i], depth + 1) end
        end
    end

    if UIParent then ScanFrame(UIParent, 0) end
    RUI:Print("Scanned " .. tostring(nodes) .. " UI frames; " .. tostring(#matches) .. " affix/forge/anvil matches captured.")
    for i = 1, #matches do
        local item = matches[i]
        RUI:Print("UI " .. tostring(i) .. ": " .. tostring(item.reason) .. " -> " .. DescribeFrame(item.frame) .. ProbeFields(item.frame))
    end

    if bookOwner then
        RUI:Print("-- Affix Book anchor ancestry --")
        local current = bookOwner
        local ancestry = {}
        for level = 0, 6 do
            if not current then break end
            ancestry[#ancestry + 1] = current
            RUI:Print("L" .. tostring(level) .. " " .. DescribeFrame(current) .. ProbeFields(current))
            current = SafeMethod(current, "GetParent")
        end

        local root = nil
        for i = 1, #ancestry do
            local candidate = ancestry[i]
            local width = tonumber(SafeMethod(candidate, "GetWidth")) or 0
            local height = tonumber(SafeMethod(candidate, "GetHeight")) or 0
            if width >= 300 and height >= 220 and ChildCount(candidate) >= 3 then root = candidate end
        end
        root = root or ancestry[math.min(3, #ancestry)] or bookOwner

        RUI:Print("-- Affix Book neighborhood (buttons/text) --")
        RUI:Print("Root: " .. DescribeFrame(root))
        local printed = 0
        local walked = 0
        local seenObjects = {}
        local function WalkNeighborhood(frame, depth)
            if not frame or walked >= 700 or printed >= 75 or depth > 9 then return end
            walked = walked + 1
            if not seenObjects[frame] then
                seenObjects[frame] = true
                local objectType = ObjectType(frame)
                local ownText = ObjectText(frame)
                local texts = RegionTexts(frame)
                local combined = ownText
                if (not combined or combined == "") and #texts > 0 then combined = table.concat(texts, " | ") end
                if objectType == "Button" or (combined and combined ~= "") then
                    printed = printed + 1
                    local scripts = {}
                    if SafeMethod(frame, "GetScript", "OnClick") then scripts[#scripts + 1] = "OnClick" end
                    if SafeMethod(frame, "GetScript", "OnEnter") then scripts[#scripts + 1] = "OnEnter" end
                    RUI:Print("ROW " .. tostring(printed) .. " d" .. tostring(depth) .. " " .. DescribeFrame(frame)
                        .. (combined and (" text=[" .. tostring(combined) .. "]") or "")
                        .. (#scripts > 0 and (" scripts=" .. table.concat(scripts, "/")) or "")
                        .. ProbeFields(frame))
                end
            end
            local ok, children = pcall(function() return { frame:GetChildren() } end)
            if ok and children then for i = 1, #children do WalkNeighborhood(children[i], depth + 1) end end
        end
        WalkNeighborhood(root, 0)
        RUI:Print("Neighborhood walked " .. tostring(walked) .. " frames; printed " .. tostring(printed) .. " candidate rows/text objects.")
    else
        RUI:Print("No visible 'Affix Book' text anchor found. Make sure the native Affix Book dropdown/panel is actually open, then rerun /zenui affixdoctor.")
    end

    RUI:Print("=== End Affix Doctor ===")
    RUI:Print("Please screenshot/copy this output back to me. Multiple chat screenshots are fine.")
end

local function ResetMovers()
    if InCombatLockdown and InCombatLockdown() then
        RUI:Print("Mover positions cannot be reset during combat.")
        return
    end
    RUI:ResetAllMovers()
    RUI:Print("Mover positions reset to defaults.")
end

function RUI:RegisterSlashCommands()
    SLASH_ZENUI1 = "/zenui"
    SLASH_ZENUI2 = "/zen"
    -- Legacy aliases retained quietly for old macros during the rename.
    SLASH_ZENUI3 = "/rui"
    SLASH_ZENUI4 = "/ravioliui"

    SlashCmdList["ZENUI"] = function(message)
        local command, argument = SplitCommand(message)
        local testFrame = RUI:GetModule("TestFrame")

        if command == "" or command == "settings" or command == "config" or command == "options" then
            ToggleSettings()
        elseif command == "help" then
            PrintHelp()
        elseif command == "devhelp" then
            PrintDeveloperHelp()
        elseif command == "doctor" or command == "health" then
            PrintDoctor()
        elseif command == "devpanel" or command == "diagnostics" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("SYSTEM") end
        elseif command == "errors" then
            if string.lower(argument or "") == "clear" then
                RUI:ClearRuntimeErrors()
                RUI:Print("Runtime error history cleared for this session.")
            else
                PrintDoctor()
            end
        elseif command == "profiles" or command == "profile" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("PROFILES") end
        elseif command == "raid" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("GROUPS") end
        elseif command == "scaling" or command == "scale" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("APPEARANCE") end
            RUI:Print("Section scales now live on their relevant settings pages.")
        elseif command == "abdebug" then
            PrintActionBarDebug()
        elseif command == "actionbars" or command == "actionbar" or command == "ab" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("ACTIONBARS") end
            PrintActionBars()
        elseif command == "bind" or command == "keybind" or command == "keybinds" then
            local actionBars = RUI:GetModule("ActionBars")
            if actionBars and actionBars.ToggleKeybindMode then actionBars:ToggleKeybindMode(false) end
        elseif command == "barbehavior" or command == "behavior" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("BARBEHAVIOR") end
        elseif command == "menu" or command == "hub" then
            local menu = RUI:GetModule("MicroMenu")
            if menu and menu.ToggleMenu then menu:ToggleMenu() end
        elseif command == "build" or command == "echobuild" or command == "hotswap" then
            local menu = RUI:GetModule("MicroMenu")
            if not menu then RUI:Print("MicroMenu module is unavailable."); return end
            local sub = string.lower(Trim(argument))
            if sub == "doctor" then
                if menu.PrintEchoHotSwapDoctor then menu:PrintEchoHotSwapDoctor() end
            elseif sub == "refresh" then
                if menu.RefreshEchoBuildList then
                    local builds, current = menu:RefreshEchoBuildList(false, true)
                    if builds and #builds > 0 then
                        RUI:Print("Echo Saved Builds: " .. tostring(#builds) .. " found" .. (current and (", current=" .. tostring(current)) or "") .. ".")
                    end
                end
            elseif sub ~= "" then
                if menu.ActivateEchoBuildByName then menu:ActivateEchoBuildByName(argument) end
            else
                local builds, current = {}, nil
                if menu.DiscoverEchoSavedBuilds then builds, current = menu:DiscoverEchoSavedBuilds() end
                if not builds or #builds == 0 then
                    RUI:Print("No Echo Saved Builds discovered yet. Open Echoes -> Saved Builds once, or use /zenui build refresh.")
                else
                    RUI:Print("Echo Saved Builds" .. (current and (" (current: " .. tostring(current) .. ")") or "") .. ":")
                    for i = 1, #builds do RUI:Print("- " .. tostring(builds[i].name)) end
                    RUI:Print("Use /zenui build <name> to select one, or use the floating Q menu.")
                end
            end
        elseif command == "callboard" or command == "board" or command == "cb" then
            local tracker = RUI:GetModule("CallboardTracker")
            if tracker and tracker.Toggle then tracker:Toggle() else RUI:Print("Callboard Tracker module is unavailable.") end
        elseif command == "menusettings" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("MENU") end
        elseif command == "minimap" or command == "map" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("MINIMAP") end
        elseif command == "minimapscan" or command == "mapscan" then
            local minimap = RUI:GetModule("Minimap")
            if minimap and minimap.ScanAddonButtons then minimap:ScanAddonButtons(true) end
        elseif command == "tooltip" or command == "tt" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("TOOLTIP") end
        elseif command == "chat" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("CHAT") end
        elseif command == "bags" or command == "bag" then
            local bags = RUI:GetModule("Bags")
            if bags and bags.Toggle then bags:Toggle() end
        elseif command == "bagsettings" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("BAGS") end
        elseif command == "bagdoctor" then
            local bags = RUI:GetModule("Bags")
            if bags and bags.PrintBagDoctor then bags:PrintBagDoctor() else RUI:Print("Bags diagnostic is unavailable.") end
        elseif command == "bagtrace" then
            local bags = RUI:GetModule("Bags")
            if not bags or not bags.SetBagTrace then RUI:Print("Bags diagnostic is unavailable."); return end
            local value=string.lower(Trim(argument or ""))
            if value=="off" or value=="0" or value=="false" then bags:SetBagTrace(false) else bags:SetBagTrace(true) end
        elseif command == "blizzard" or command == "skins" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("PANELS_A") end
        elseif command == "affixdoctor" or command == "affixdebug" then
            PrintAffixDoctor(argument)
        elseif command == "extbank" or command == "voidbank" then
            PrintExtBankDiagnostics(argument)
        elseif command == "extprice" or command == "voidprice" then
            CaptureExtPriceDiagnostics()
        elseif command == "extmove" or command == "voidmove" then
            PrintExtMoveDiagnostics(argument)
        elseif command == "test" then
            if testFrame and testFrame.Toggle then testFrame:Toggle() end
        elseif command == "show" then
            if testFrame and testFrame.ShowForTesting and testFrame:ShowForTesting(true) then
                RUI:Print("Development preview shown and its mover reset onscreen.")
            end
        elseif command == "move" then
            local moveArg = string.lower(argument or "")
            if moveArg == "on" then
                RUI:SetMoverMode(true)
            elseif moveArg == "off" then
                RUI:SetMoverMode(false)
            else
                RUI:ToggleMoverMode()
            end
        elseif command == "movers" then
            PrintMovers()
        elseif command == "snap" then
            HandleSnap(argument)
        elseif command == "uf" or command == "unitframes" then
            PrintUnitFrames()
        elseif command == "bars" then
            PrintBarDiagnostics()
        elseif command == "raiddebug" then
            PrintRaidDiagnostics()
        elseif command == "runes" then
            PrintRuneDiagnostics()
        elseif command == "theme" then
            PrintTheme()
        elseif command == "reset" then
            local resetType = string.lower(argument or "")
            if resetType == "movers" then
                ResetMovers()
            elseif resetType == "appearance" then
                RUI:ResetAppearance()
                local config = RUI:GetModule("Config")
                if config and config.Refresh then config:Refresh() end
                RUI:Print("Appearance reset to ZenUI defaults.")
            else
                if InCombatLockdown and InCombatLockdown() then
                    RUI:Print("The ZenUI profile cannot be reset during combat.")
                    return
                end
                if RUI.moverMode then RUI:SetMoverMode(false) end
                RUI:ResetProfile()
                if testFrame and testFrame.ApplyProfile then testFrame:ApplyProfile() end
                local config = RUI:GetModule("Config")
                if config and config.Refresh then config:Refresh() end
                RUI:Print("Profile reset to ZenUI defaults.")
            end
        elseif command == "debug" then
            RUI.global.debug = not RUI.global.debug
            local config = RUI:GetModule("Config")
            if config and config.Refresh then config:Refresh() end
            RUI:Print("Debug mode " .. (RUI.global.debug and "enabled." or "disabled."))
        elseif command == "addons" then
            local found = false
            RUI:Print("Registered companion addons:")
            for id, data in pairs(RUI.registeredAddons) do
                found = true
                RUI:Print("- " .. tostring(data.name or id) .. " (" .. id .. ")")
            end
            if not found then RUI:Print("- none yet") end
        elseif command == "version" then
            RUI:Print("Version " .. RUI.version .. " / Interface " .. RUI.interface .. " / DB schema " .. tostring(RUI:GetDatabaseSchema()))
        elseif command == "status" then
            RUI:Print("Module status:")
            for i = 1, #RUI.moduleOrder do
                local module = RUI.modules[RUI.moduleOrder[i]]
                if module then
                    local state = module.initialized and "initialized" or "FAILED"
                    if module.enabled then state = state .. ", enabled" end
                    RUI:Print("- " .. module.name .. ": " .. state)
                    if module.initializationError then RUI:Print("  init error: " .. module.initializationError) end
                    if module.enableError then RUI:Print("  enable error: " .. module.enableError) end
                end
            end

            local layout = RUI.db and RUI.db.layout
            local snapState = "unavailable"
            if layout then snapState = layout.snapEnabled and ((layout.snapSize or 4) .. "px") or "off" end
            RUI:Print("Layout: " .. tostring(#RUI.moverOrder) .. " mover(s), move mode " .. (RUI.moverMode and "ON" or "off") .. ", snap " .. tostring(snapState))
            local ebon = RUI.EbonAPIBridge
            if ebon and type(ebon.IsAvailable) == "function" and ebon:IsAvailable() then
                RUI:Print("EbonAPI backend: connected " .. tostring(ebon:GetVersion() or "unknown") .. " (Saved Builds event/state provider)")
            else
                RUI:Print("EbonAPI backend: unavailable; native Ebonhold fallback active")
            end
            PrintUnitFrames()
            PrintActionBars()
            PrintTheme()
        else
            RUI:Print("Unknown command: " .. command)
            PrintHelp()
        end
    end
end
