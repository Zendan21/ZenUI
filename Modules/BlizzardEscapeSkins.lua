-- ZenUI 0.9.98 Phase D Blizzard escape skins.
-- Restyles common native transient frames without replacing Blizzard/Ebonhold
-- interaction logic. This intentionally keeps the original scripts/events/API
-- paths authoritative and only changes presentation.

local RUI = ZenUI
local EscapeSkins = RUI:NewModule("BlizzardEscapeSkins")

local function HideTexture(texture)
    if texture and texture.Hide then texture:Hide() end
end

local function HideMatchingTextures(frame, needles)
    if not frame or not frame.GetRegions then return end
    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.GetTexture then
            local texture = region:GetTexture()
            if type(texture) == "string" then
                local lower = string.lower(texture)
                for j = 1, #needles do
                    if string.find(lower, needles[j], 1, true) then
                        region:Hide()
                        break
                    end
                end
            end
        end
    end
end

local function EnsureAccent(frame)
    if not frame then return end
    if not frame.RUIEscapeAccent then
        frame.RUIEscapeAccent = RUI:CreateAccentLine(frame, 2)
    else
        RUI:SetAccentTexture(frame.RUIEscapeAccent, 1)
        frame.RUIEscapeAccent:SetHeight(RUI:GetPixelSize(frame, 2))
    end
end

local function StylePanel(frame)
    if not frame then return end
    if frame.SetBackdrop then frame:SetBackdrop(nil) end
    RUI:CreateBackdrop(frame)
    RUI:RefreshBackdrop(frame)
    EnsureAccent(frame)
end

local function StyleButton(button)
    if not button then return end

    if button.SetNormalTexture then button:SetNormalTexture(nil) end
    if button.SetPushedTexture then button:SetPushedTexture(nil) end
    if button.SetDisabledTexture then button:SetDisabledTexture(nil) end
    if button.SetHighlightTexture then button:SetHighlightTexture(nil) end

    RUI:CreateBackdrop(button)
    RUI:RefreshBackdrop(button)

    local fontString = button.GetFontString and button:GetFontString()
    if fontString then RUI:StyleFontString(fontString, 10) end

    if not button.RUIEscapeHighlight then
        local highlight = button:CreateTexture(nil, "ARTWORK")
        highlight:SetAllPoints(button)
        highlight:Hide()
        button.RUIEscapeHighlight = highlight

        if button.HookScript then
            button:HookScript("OnEnter", function(self)
                local r, g, b = RUI:GetAccentColor()
                self.RUIEscapeHighlight:SetTexture(r, g, b, 0.14)
                self.RUIEscapeHighlight:Show()
            end)
            button:HookScript("OnLeave", function(self)
                if self.RUIEscapeHighlight then self.RUIEscapeHighlight:Hide() end
            end)
        end
    end
end

local function StyleEditBox(editBox)
    if not editBox then return end
    HideMatchingTextures(editBox, { "ui-chatinputborder" })
    RUI:CreateBackdrop(editBox)
    RUI:RefreshBackdrop(editBox)
    if editBox.SetTextInsets then editBox:SetTextInsets(7, 7, 3, 3) end
    if editBox.SetFont then editBox:SetFont(RUI:GetFontPath(), 11) end
    local r, g, b = RUI:GetTextColor(false)
    if editBox.SetTextColor then editBox:SetTextColor(r, g, b) end
end

function EscapeSkins:StyleStaticPopup(frame)
    if not frame then return end
    StylePanel(frame)

    local name = frame.GetName and frame:GetName()
    if name then
        StyleButton(_G[name .. "Button1"])
        StyleButton(_G[name .. "Button2"])
        StyleButton(_G[name .. "Button3"])
        StyleEditBox(_G[name .. "EditBox"])
        StyleEditBox(_G[name .. "WideEditBox"])

        local text = _G[name .. "Text"]
        if text then RUI:StyleFontString(text, 11) end

        local itemFrame = _G[name .. "ItemFrame"]
        if itemFrame then
            HideTexture(_G[name .. "ItemFrameNameFrame"])
            local itemText = _G[name .. "ItemFrameText"]
            if itemText then RUI:StyleFontString(itemText, 10) end
        end
    end
end

function EscapeSkins:StyleStackSplit()
    local frame = _G.StackSplitFrame
    if not frame then return end

    -- StackSplitFrame's parchment/dialog artwork is made from several unnamed
    -- texture regions, not just UI-MoneyFrame.  Hide every texture owned by the
    -- popup itself; the decrement/increment arrows are child buttons and keep
    -- their native artwork/functionality.
    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            local isRUIRegion = region == frame.RUIBackground or region == frame.RUIEscapeAccent
            if not isRUIRegion and frame.RUIBorder then
                isRUIRegion = region == frame.RUIBorder.top or region == frame.RUIBorder.bottom
                    or region == frame.RUIBorder.left or region == frame.RUIBorder.right
            end
            if not isRUIRegion and region and region.GetTexture and region.Hide then region:Hide() end
        end
    end

    StylePanel(frame)
    if _G.StackSplitText then RUI:StyleFontString(_G.StackSplitText, 14) end
    StyleButton(_G.StackSplitOkayButton)
    StyleButton(_G.StackSplitCancelButton)

    -- Some 3.3.5/private-server clients do not propagate a late parent-frame
    -- level change to StackSplitFrame's child buttons.  Put the popup AND its
    -- interactive controls on the TOOLTIP strata explicitly so Zen-owned
    -- DIALOG panels can never cover either the artwork or the mouse targets.
    local baseLevel = 1000
    if frame.SetParent then frame:SetParent(UIParent) end
    if frame.SetFrameStrata then frame:SetFrameStrata("TOOLTIP") end
    if frame.SetFrameLevel then frame:SetFrameLevel(baseLevel) end
    if frame.SetToplevel then frame:SetToplevel(true) end
    if frame.EnableMouse then frame:EnableMouse(true) end

    local controls = {
        _G.StackSplitLeftButton,
        _G.StackSplitRightButton,
        _G.StackSplitOkayButton,
        _G.StackSplitCancelButton,
    }
    for i = 1, #controls do
        local control = controls[i]
        if control then
            if control.SetFrameStrata then control:SetFrameStrata("TOOLTIP") end
            if control.SetFrameLevel then control:SetFrameLevel(baseLevel + 10 + i) end
            if control.EnableMouse then control:EnableMouse(true) end
            if control.Raise then control:Raise() end
        end
    end

    if frame.Raise and frame.IsShown and frame:IsShown() then frame:Raise() end
end

function EscapeSkins:StyleReadyCheck()
    local frame = _G.ReadyCheckFrame
    if not frame then return end

    -- ReadyCheckFrame is a standalone Blizzard transient panel. Remove only
    -- its stock texture regions; the text/buttons and their native scripts stay.
    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region and region.GetTexture then region:Hide() end
        end
    end

    StylePanel(frame)
    if _G.ReadyCheckFrameText then RUI:StyleFontString(_G.ReadyCheckFrameText, 11) end
    StyleButton(_G.ReadyCheckFrameYesButton)
    StyleButton(_G.ReadyCheckFrameNoButton)
end

function EscapeSkins:StyleItemSocketing()
    local frame = _G.ItemSocketingFrame
    if not frame then return end

    -- Keep the socket-specific graphics themselves because their colors and
    -- brackets communicate socket type/state. Only remove the large Blizzard
    -- parchment/chrome around the panel and its scrollbar decoration.
    HideMatchingTextures(frame, { "ui-itemsocketingframe" })
    StylePanel(frame)

    if frame.SetFrameStrata then frame:SetFrameStrata("DIALOG") end
    if frame.SetFrameLevel then frame:SetFrameLevel(700) end

    local action = _G.ItemSocketingSocketButton
    if action then
        StyleButton(action)
        if action.SetHeight then action:SetHeight(24) end
    end

    -- The description is a GameTooltip-shaped child used as static text.
    local desc = _G.ItemSocketingDescription
    if desc and desc.SetBackdrop then desc:SetBackdrop(nil) end

    local scroll = _G.ItemSocketingScrollFrame
    if scroll then
        HideMatchingTextures(scroll, { "ui-itemsocketingframe-scrollbar" })
    end

    -- Preserve the native close-button script but replace its Blizzard art
    -- with the same simple X control used elsewhere in Zen.
    local close = _G.ItemSocketingCloseButton
    if close and not close.RUISocketStyled then
        close.RUISocketStyled = true
        if close.SetNormalTexture then close:SetNormalTexture(nil) end
        if close.SetPushedTexture then close:SetPushedTexture(nil) end
        if close.SetHighlightTexture then close:SetHighlightTexture(nil) end
        close:SetWidth(24)
        close:SetHeight(22)
        local label = close:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER", close, "CENTER", 0, 0)
        -- Wrath requires a FontString to have a font before SetText(); doing
        -- this in the opposite order throws "Font not set" while the
        -- load-on-demand ItemSocketing UI is being skinned.
        RUI:StyleFontString(label, 10)
        label:SetText("X")
        close.RUILabel = label
        RUI:CreateBackdrop(close)
        RUI:RefreshBackdrop(close)
    elseif close then
        RUI:RefreshBackdrop(close)
        if close.RUILabel then RUI:StyleFontString(close.RUILabel, 10) end
    end
end

function EscapeSkins:ApplyAll()
    for i = 1, 4 do
        self:StyleStaticPopup(_G["StaticPopup" .. tostring(i)])
    end
    self:StyleStackSplit()
    self:StyleReadyCheck()
    self:StyleItemSocketing()
end

function EscapeSkins:InstallHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled = true

    for i = 1, 4 do
        local frame = _G["StaticPopup" .. tostring(i)]
        if frame and frame.HookScript then
            frame:HookScript("OnShow", function(self)
                EscapeSkins:StyleStaticPopup(self)
            end)
        end
    end

    if _G.StackSplitFrame and _G.StackSplitFrame.HookScript then
        _G.StackSplitFrame:HookScript("OnShow", function()
            EscapeSkins:StyleStackSplit()
        end)
    end

    if _G.ReadyCheckFrame and _G.ReadyCheckFrame.HookScript then
        _G.ReadyCheckFrame:HookScript("OnShow", function()
            EscapeSkins:StyleReadyCheck()
        end)
    end

    if _G.ItemSocketingFrame and _G.ItemSocketingFrame.HookScript and not self.socketHookInstalled then
        self.socketHookInstalled = true
        _G.ItemSocketingFrame:HookScript("OnShow", function()
            EscapeSkins:StyleItemSocketing()
        end)
    end
end

function EscapeSkins:OnAddonLoaded()
    -- Some clients/private-server builds create raid/transient frames lazily.
    -- Re-run idempotent setup when another Blizzard component becomes ready.
    self:InstallHooks()
    if _G.ItemSocketingFrame and _G.ItemSocketingFrame.HookScript and not self.socketHookInstalled then
        self.socketHookInstalled = true
        _G.ItemSocketingFrame:HookScript("OnShow", function()
            EscapeSkins:StyleItemSocketing()
        end)
    end
    self:ApplyAll()
end

function EscapeSkins:OnInitialize()
    self:InstallHooks()
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "ApplyAll")
    RUI:RegisterCallback("PROFILE_RESET", self, "ApplyAll")
end

function EscapeSkins:OnEnable()
    self:ApplyAll()
end
