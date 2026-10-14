-- ZenUI 1.0.25 shared visual/design API.
-- Intentionally conservative: only frame/widget behaviour available to WoW 3.3.5a.

local RUI = ZenUI

local FALLBACK = {
    scale = 1,
    font = "Narrow",
    panelAlpha = 0.96,
    accent = { 0.92, 0.63, 0.40 },
    background = { 0.035, 0.037, 0.043 },
    surface = { 0.070, 0.075, 0.087 },
    border = { 0.15, 0.16, 0.18 },
    text = { 0.90, 0.91, 0.93 },
    muted = { 0.55, 0.57, 0.61 },
}

-- Appearance is now provided by the embedded ZenStylingPack design system.
-- Keep these compatibility accessors because the rest of ZenUI is deliberately
-- written against the stable ZenUI API rather than directly against the pack.
function RUI:GetAppearanceStyleKey()
    local ui = self.StylingPack
    if ui and ui.StyleKey then return ui:StyleKey() end
    local a = self.db and self.db.appearance or {}
    return string.upper(tostring(a.style or a.visualStyle or "CLASSIC"))
end

function RUI:GetAppearanceStyle()
    local ui = self.StylingPack
    if ui and ui.Theme then return ui:Theme() end
    return {
        label = "Zen Classic", background = FALLBACK.background,
        surface = FALLBACK.surface, border = FALLBACK.border,
        text = FALLBACK.text, muted = FALLBACK.muted,
        alphaMultiplier = 1, borderWidth = 1, hoverAlpha = 0.12,
        shadow = "none", overlay = "none",
    }
end

function RUI:GetButtonHoverAlpha()
    local style = self:GetAppearanceStyle()
    return tonumber(style and style.hoverAlpha) or 0.12
end

local function GetAppearanceValue(key)
    local appearance = RUI.GetAppearanceSettings and RUI:GetAppearanceSettings() or (RUI.db and RUI.db.appearance)
    if appearance and appearance[key] ~= nil then return appearance[key] end
    return FALLBACK[key]
end

local function MakeSolidTexture(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(r or 1, g or 1, b or 1, a or 1)
    return texture
end

function RUI:GetUIScale()
    return tonumber(GetAppearanceValue("scale")) or 1
end

function RUI:GetComponentScale(key)
    if not key then return 1 end
    local scales = self.db and self.db.scales
    local value = scales and tonumber(scales[key]) or 1
    if value < 0.50 then value = 0.50 end
    if value > 1.50 then value = 1.50 end
    return value
end

function RUI:GetEffectiveScale(key)
    return self:GetUIScale() * self:GetComponentScale(key)
end

function RUI:SetComponentScale(key, value)
    if not self.db or not key then return false end
    self.db.scales = self.db.scales or {}
    value = tonumber(value) or 1
    if value < 0.50 then value = 0.50 end
    if value > 1.50 then value = 1.50 end
    self.db.scales[key] = value
    self:FireCallback("COMPONENT_SCALE_CHANGED", key, value)
    return true
end

function RUI:GetAccentColor()
    local ui = self.StylingPack
    if ui and ui.Accent then return ui:Accent() end
    local color = GetAppearanceValue("accent") or FALLBACK.accent
    return color[1] or 1, color[2] or 1, color[3] or 1
end

function RUI:GetBackgroundColor()
    local style = self:GetAppearanceStyle()
    local color = style and style.background or FALLBACK.background
    return color[1] or 0.04, color[2] or 0.04, color[3] or 0.05
end

function RUI:GetSurfaceColor()
    local style = self:GetAppearanceStyle()
    local color = style and style.surface or FALLBACK.surface
    return color[1] or 0.07, color[2] or 0.075, color[3] or 0.087
end

function RUI:GetBorderColor()
    local style = self:GetAppearanceStyle()
    local color = style and style.border or FALLBACK.border
    return color[1] or 0.15, color[2] or 0.16, color[3] or 0.18
end

function RUI:GetTextColor(muted)
    local style = self:GetAppearanceStyle()
    local color = muted and (style and (style.muted or style.mutedText)) or (style and style.text)
    color = color or (muted and FALLBACK.muted or FALLBACK.text)
    return color[1] or 1, color[2] or 1, color[3] or 1
end

function RUI:GetPanelAlpha()
    local ui = self.StylingPack
    if ui and ui.PanelAlpha then return ui:PanelAlpha() end
    local base = tonumber(GetAppearanceValue("panelAlpha")) or 0.96
    if base < 0.20 then base = 0.20 end
    if base > 1 then base = 1 end
    return base
end

-- Return one physical-pixel-ish UI unit for the supplied frame scale.
-- This avoids depending on modern screen-size APIs that do not exist in 3.3.5.
function RUI:GetPixelSize(frame, pixels)
    local scale = 1
    if frame and frame.GetEffectiveScale then
        scale = frame:GetEffectiveScale() or 1
    elseif UIParent and UIParent.GetEffectiveScale then
        scale = UIParent:GetEffectiveScale() or 1
    end

    if scale <= 0 then
        scale = 1
    end

    return (pixels or 1) / scale
end

-- Snap a UI-space value to the nearest physical-pixel boundary.
function RUI:PixelRound(value, frame)
    local scale = 1
    if frame and frame.GetEffectiveScale then
        scale = frame:GetEffectiveScale() or 1
    elseif UIParent and UIParent.GetEffectiveScale then
        scale = UIParent:GetEffectiveScale() or 1
    end

    if scale <= 0 then
        scale = 1
    end

    local scaled = (value or 0) * scale
    if scaled >= 0 then
        scaled = math.floor(scaled + 0.5)
    else
        scaled = math.ceil(scaled - 0.5)
    end
    return scaled / scale
end

function RUI:CreateBackdrop(frame, kind)
    if not frame then return end
    if not kind and not frame.RUISurfaceKind and frame.GetObjectType then
        local objectType = frame:GetObjectType()
        if objectType == "Button" then kind = "button"
        elseif objectType == "EditBox" or objectType == "Slider" then kind = "input" end
    end
    kind = kind or frame.RUISurfaceKind or "panel"
    frame.RUISurfaceKind = kind

    local ui = self.StylingPack
    if ui and ui.StyleSurface then
        ui:StyleSurface(frame, kind)
        frame.RUIBackdrop = true
        if frame._zenSurface then
            frame.RUIBackground = frame._zenSurface.bg
            frame.RUIBorder = frame._zenSurface.borders
        end
        return
    end

    if not frame.RUIBackdrop then
        frame.RUIBackground = MakeSolidTexture(frame, "BACKGROUND", 1, 1, 1, 1)
        frame.RUIBackground:SetAllPoints(frame)
        frame.RUIBorder = {}
        local top = MakeSolidTexture(frame, "BORDER", 1, 1, 1, 1)
        top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        local bottom = MakeSolidTexture(frame, "BORDER", 1, 1, 1, 1)
        bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        local left = MakeSolidTexture(frame, "BORDER", 1, 1, 1, 1)
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0); left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        local right = MakeSolidTexture(frame, "BORDER", 1, 1, 1, 1)
        right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0); right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame.RUIBorder.top, frame.RUIBorder.bottom = top, bottom
        frame.RUIBorder.left, frame.RUIBorder.right = left, right
        frame.RUIBackdrop = true
    end
    self:RefreshBackdrop(frame)
end

function RUI:RefreshBackdrop(frame)
    if not frame or not frame.RUIBackdrop then return end
    local ui = self.StylingPack
    if ui and ui.RefreshSurface and frame._zenSurface then
        frame._zenSurface.kind = frame.RUISurfaceKind or frame._zenSurface.kind or "panel"
        ui:RefreshSurface(frame)
        return
    end

    local br, bg, bb = self:GetBackgroundColor()
    local rr, rg, rb = self:GetBorderColor()
    local alpha = self:GetPanelAlpha()
    local pixel = self:GetPixelSize(frame, 1)
    frame.RUIBackground:SetTexture(br, bg, bb, alpha)
    frame.RUIBorder.top:SetHeight(pixel); frame.RUIBorder.bottom:SetHeight(pixel)
    frame.RUIBorder.left:SetWidth(pixel); frame.RUIBorder.right:SetWidth(pixel)
    frame.RUIBorder.top:SetTexture(rr, rg, rb, 1); frame.RUIBorder.bottom:SetTexture(rr, rg, rb, 1)
    frame.RUIBorder.left:SetTexture(rr, rg, rb, 1); frame.RUIBorder.right:SetTexture(rr, rg, rb, 1)
end

function RUI:SetBorderColor(frame, r, g, b, a)
    if not frame or not frame.RUIBorder then return end
    local ui = self.StylingPack
    if ui and ui.ColorBorder and frame._zenSurface then
        ui:ColorBorder(frame, r, g, b, a)
        return
    end
    frame.RUIBorder.top:SetTexture(r or 1, g or 1, b or 1, a or 1)
    frame.RUIBorder.bottom:SetTexture(r or 1, g or 1, b or 1, a or 1)
    frame.RUIBorder.left:SetTexture(r or 1, g or 1, b or 1, a or 1)
    frame.RUIBorder.right:SetTexture(r or 1, g or 1, b or 1, a or 1)
end

function RUI:CreateAccentLine(parent, height)
    local r, g, b = self:GetAccentColor()
    local texture = MakeSolidTexture(parent, "OVERLAY", r, g, b, 1)
    texture.RUIAccentHeight = height or 2
    texture:SetHeight(self:GetPixelSize(parent, texture.RUIAccentHeight))
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    texture:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    return texture
end

function RUI:SetAccentTexture(texture, alpha)
    if not texture then
        return
    end

    local r, g, b = self:GetAccentColor()
    texture:SetTexture(r, g, b, alpha or 1)
end

function RUI:StyleFontString(fontString, size, r, g, b)
    if not fontString then
        return
    end

    local tr, tg, tb
    if r == nil then
        tr, tg, tb = self:GetTextColor(false)
    else
        tr, tg, tb = r, g, b
    end

    fontString:SetFont(self:GetFontPath(), size or 11)
    fontString:SetTextColor(tr or 1, tg or 1, tb or 1)
    if self:GetAppearanceStyleKey() == "BRUTAL" then
        fontString:SetShadowColor(0, 0, 0, 0.9)
    else
        fontString:SetShadowColor(0, 0, 0, 0.5)
    end
    fontString:SetShadowOffset(1, -1)
end

function RUI:CreateStatusBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetWidth(width or 100)
    bar:SetHeight(height or 10)
    bar:SetStatusBarTexture(self:GetStatusBarTexture())
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(100)

    bar.background = bar:CreateTexture(nil, "BACKGROUND")
    bar.background:SetAllPoints(bar)
    bar.background:SetTexture(0, 0, 0, 0.35)

    self:RefreshStatusBar(bar)
    return bar
end

function RUI:RefreshStatusBar(bar)
    if not bar then
        return
    end

    bar:SetStatusBarTexture(self:GetStatusBarTexture())
    local r, g, b = self:GetAccentColor()
    bar:SetStatusBarColor(r, g, b, 0.92)
end

function RUI:StyleButton(button)
    if not button then return end
    button.RUISurfaceKind = "button"
    self:CreateBackdrop(button, "button")
    button:EnableMouse(true)

    local ui = self.StylingPack
    if ui and ui.InstallHover and button._zenSurface then
        button.RUIHighlight = button._zenSurface.highlight
        ui:InstallHover(button)
    elseif not button.RUIHighlight then
        button.RUIHighlight = button:CreateTexture(nil, "ARTWORK")
        button.RUIHighlight:SetAllPoints(button)
        button.RUIHighlight:Hide()
        button:HookScript("OnEnter", function(self)
            local r, g, b = RUI:GetAccentColor()
            self.RUIHighlight:SetTexture(r, g, b, RUI:GetButtonHoverAlpha())
            self.RUIHighlight:Show()
        end)
        button:HookScript("OnLeave", function(self) self.RUIHighlight:Hide() end)
    end

    if button.RUIText then self:StyleFontString(button.RUIText, 10) end
end


-- Modified item/link click bridge.
-- Ebonhold's HandleModifiedItemClick path is not consistent for DRESSUP on
-- custom addon buttons, so Zen explicitly honors Ctrl/DRESSUP for item links
-- before delegating every other modified-click action back to Blizzard.
function RUI:HandleModifiedLinkClick(link, mouseButton)
    if type(link) ~= "string" or link == "" then return false end

    local isItem = string.find(link, "|Hitem:", 1, true) or string.sub(link, 1, 5) == "item:"
    local leftClick = (mouseButton == nil or mouseButton == "LeftButton")
    if isItem and leftClick and DressUpItemLink then
        local dressUp = false
        if IsModifiedClick then
            local ok, result = pcall(IsModifiedClick, "DRESSUP")
            dressUp = ok and result and true or false
        end
        -- Ebonhold has historically used Ctrl+Click for dressing-room preview;
        -- retain that expected gesture even if its modified-click lookup fails.
        if not dressUp and IsControlKeyDown then
            local ok, result = pcall(IsControlKeyDown)
            dressUp = ok and result and true or false
        end
        if dressUp then
            local ok = pcall(DressUpItemLink, link)
            if ok then return true end
        end
    end

    if HandleModifiedItemClick then
        local ok, handled = pcall(HandleModifiedItemClick, link)
        if ok and handled then return true end
    end
    return false
end

function RUI:GetTooltipItemLink(owner)
    if not GameTooltip or not GameTooltip.GetItem then return nil end
    if owner and GameTooltip.IsOwned and not GameTooltip:IsOwned(owner) then return nil end
    local ok, _, link = pcall(GameTooltip.GetItem, GameTooltip)
    if ok then return link end
    return nil
end


-- Zen major-panel coordinator. Bags/action bars are intentionally not
-- registered here: this is only for full-size replacement/config windows that
-- should behave like Blizzard UIPanels and replace one another instead of
-- stacking.
RUI.exclusivePanels = RUI.exclusivePanels or {}

function RUI:RegisterExclusivePanel(frame)
    if not frame or frame.RUIExclusiveRegistered then return end
    frame.RUIExclusiveRegistered = true
    self.exclusivePanels[frame] = true
    if frame.HookScript then
        frame:HookScript("OnShow", function(shown)
            RUI:ActivateExclusivePanel(shown)
        end)
    end
end

local function CanCloseExclusivePanelInCombat(frame)
    if not frame then return false end
    if frame.RUIExclusiveCombatSafeClose ~= nil then
        return frame.RUIExclusiveCombatSafeClose and true or false
    end
    if frame.RUIExclusiveCombatProtected then return false end

    -- IsProtected() exists on Wrath frames and catches parents whose secure
    -- descendants make Show/Hide combat-restricted.  Guard it because some
    -- Ebonhold userdata/frame variants are not perfectly stock.
    if type(frame.IsProtected) == "function" then
        local ok, protected = pcall(frame.IsProtected, frame)
        if ok and protected then return false end
    end
    return true
end

function RUI:ActivateExclusivePanel(frame)
    if not frame or self.RUIExclusiveSwitching then return end

    -- 1.0.21 skipped exclusivity wholesale during lockdown. That kept menu
    -- hotkeys usable, but meant ordinary Zen panels (Friends/Guild/Raid,
    -- Character/LFD/etc.) accumulated on top of one another in combat.
    -- Keep exclusivity active for ordinary frames and only skip a frame when
    -- Blizzard actually marks it protected (Spellbook is the known example).
    local inCombat = InCombatLockdown and InCombatLockdown()
    self.RUIExclusiveSwitching = true
    for other in pairs(self.exclusivePanels or {}) do
        if other ~= frame and other.IsShown and other:IsShown() then
            if (not inCombat) or CanCloseExclusivePanelInCombat(other) then
                local close = other.RUIExclusiveClose
                if type(close) == "function" then
                    local ok = pcall(close, other, frame)
                    if not ok and other.Hide then pcall(other.Hide, other) end
                elseif other.Hide then
                    pcall(other.Hide, other)
                end
            end
        end
    end
    self.RUIExclusiveSwitching = nil
end


-- Central combat-safe menu binding router.
--
-- Default Blizzard menu bindings eventually call taint-sensitive globals such as
-- ToggleCharacter / ToggleFriendsFrame.  Calling those replacement globals from
-- insecure addon code works out of combat but can be rejected once lockdown
-- begins.  Older Zen builds tried to solve that by showing/hiding the Zen frame
-- directly from SecureHandler snippets.  That bypassed each module's normal
-- toggle/page logic and produced mismatched state (for example C could open the
-- Character frame but fail to close it, while U/K could open the wrong page).
--
-- This router keeps the protected part deliberately tiny: the override binding
-- clicks a SecureActionButtonTemplate whose only secure action is `click`.  That
-- delegates the hardware click to an ordinary hidden Zen dispatcher button.
-- The dispatcher then runs the SAME normal Zen toggle function used out of
-- combat.  The visible replacement panels remain ordinary frames; only genuinely
-- protected gameplay actions inside those panels remain subject to Blizzard's
-- combat restrictions.
RUI.combatMenuRoutes = RUI.combatMenuRoutes or {}

local function CombatMenuRouteSafeName(id)
    return (tostring(id or "route"):gsub("[^%w]", ""))
end

function RUI:RefreshCombatMenuBindings()
    if InCombatLockdown and InCombatLockdown() then
        self.combatMenuBindingsPending = true
        return false
    end
    if not SetOverrideBindingClick or not ClearOverrideBindings or not GetBindingKey then return false end

    if not self.combatMenuBindingOwner then
        self.combatMenuBindingOwner = CreateFrame("Frame", "ZenUICombatMenuBindingOwner", UIParent)
    end
    ClearOverrideBindings(self.combatMenuBindingOwner)

    local ids = {}
    for id in pairs(self.combatMenuRoutes or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for i = 1, #ids do
        local route = self.combatMenuRoutes[ids[i]]
        if route and route.enabled ~= false and route.command and route.secure and route.secure.GetName then
            local key1, key2 = GetBindingKey(route.command)
            local name = route.secure:GetName()
            if key1 and name then SetOverrideBindingClick(self.combatMenuBindingOwner, true, key1, name, "LeftButton") end
            if key2 and name then SetOverrideBindingClick(self.combatMenuBindingOwner, true, key2, name, "LeftButton") end
        end
    end
    self.combatMenuBindingsPending = nil
    return true
end

function RUI:RegisterCombatMenuRoute(id, command, callback, enabled)
    if type(id) ~= "string" or id == "" or type(command) ~= "string" or command == "" then return false end
    if callback ~= nil and type(callback) ~= "function" then return false end

    local route = self.combatMenuRoutes[id]
    if not route then
        route = { id = id }
        self.combatMenuRoutes[id] = route
    end
    route.command = command
    route.callback = callback
    route.enabled = enabled ~= false

    if not route.dispatcher or not route.secure then
        if InCombatLockdown and InCombatLockdown() then
            self.combatMenuBindingsPending = true
            return false
        end

        local suffix = CombatMenuRouteSafeName(id)
        if suffix == "" then suffix = "Route" end
        local dispatchName = "ZenUICombatDispatch" .. suffix
        local secureName = "ZenUICombatRoute" .. suffix

        local dispatcher = route.dispatcher or _G[dispatchName]
        if not dispatcher then
            dispatcher = CreateFrame("Button", dispatchName, UIParent)
            dispatcher:SetWidth(1); dispatcher:SetHeight(1)
            dispatcher:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
        end
        dispatcher:SetScript("OnClick", function()
            local current = RUI.combatMenuRoutes and RUI.combatMenuRoutes[id]
            if not current or current.enabled == false or type(current.callback) ~= "function" then return end
            local ok, err = pcall(current.callback)
            if not ok then
                if RUI.ReportRuntimeError then RUI:ReportRuntimeError("CombatMenu", id, err)
                elseif RUI.Debug then RUI:Debug("Combat menu route " .. tostring(id) .. " failed: " .. tostring(err)) end
            end
        end)

        local secure = route.secure or _G[secureName]
        if not secure then secure = CreateFrame("Button", secureName, UIParent, "SecureActionButtonTemplate") end
        secure:SetAttribute("type1", "click")
        secure:SetAttribute("clickbutton", dispatcher)

        route.dispatcher = dispatcher
        route.secure = secure
    elseif route.dispatcher then
        -- Refresh the ordinary callback without touching protected attributes.
        route.dispatcher:SetScript("OnClick", function()
            local current = RUI.combatMenuRoutes and RUI.combatMenuRoutes[id]
            if not current or current.enabled == false or type(current.callback) ~= "function" then return end
            local ok, err = pcall(current.callback)
            if not ok then
                if RUI.ReportRuntimeError then RUI:ReportRuntimeError("CombatMenu", id, err)
                elseif RUI.Debug then RUI:Debug("Combat menu route " .. tostring(id) .. " failed: " .. tostring(err)) end
            end
        end)
    end

    self:RefreshCombatMenuBindings()
    return true
end

function RUI:RegisterCombatSecureFrameRoute(id, command, frame, enabled)
    if type(id) ~= "string" or id == "" or type(command) ~= "string" or command == "" or not frame then return false end
    local route = self.combatMenuRoutes[id]
    if not route then route = { id = id }; self.combatMenuRoutes[id] = route end
    route.command = command
    route.callback = nil
    route.enabled = enabled ~= false
    route.secureDirect = true

    if not route.secure then
        if InCombatLockdown and InCombatLockdown() then self.combatMenuBindingsPending = true; return false end
        local suffix = CombatMenuRouteSafeName(id)
        if suffix == "" then suffix = "Route" end
        local secureName = "ZenUICombatRoute" .. suffix
        local secure = _G[secureName]
        if not secure then secure = CreateFrame("Button", secureName, UIParent, "SecureHandlerClickTemplate") end
        secure:SetFrameRef("target", frame)
        secure:SetAttribute("_onclick", [[
            local f = self:GetFrameRef("target")
            if f then
                if f:IsShown() then f:Hide() else f:Show() end
            end
        ]])
        route.secure = secure
    elseif not (InCombatLockdown and InCombatLockdown()) then
        route.secure:SetFrameRef("target", frame)
    end

    self:RefreshCombatMenuBindings()
    return true
end


-- Binding changes and combat-end both happen outside lockdown, so one central
-- owner can rebuild every menu override consistently instead of each module
-- competing with its own priority binding owner.
if not RUI.combatMenuBindingEventFrame then
    local f = CreateFrame("Frame", "ZenUICombatMenuBindingEventFrame")
    f:RegisterEvent("UPDATE_BINDINGS")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function() RUI:RefreshCombatMenuBindings() end)
    RUI.combatMenuBindingEventFrame = f
end

function RUI:ApplyAppearance(reason)
    local ui = self.StylingPack
    if ui then
        if self.db and self.db.appearance and ui._localSettings ~= self.db.appearance and self.InitializeStylingPack then
            self:InitializeStylingPack()
            return
        end
        if ui.RefreshAll then
            ui:RefreshAll()
            return
        end
    end
    self:FireCallback("APPEARANCE_CHANGED", reason or "update")
end
