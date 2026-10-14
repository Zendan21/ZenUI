-- ZenUI chat shell/layout + native 10-message history.
-- Reuses the native Wrath chat frames/docking system and fully suppresses native frame chrome.

local RUI = ZenUI
local Chat = RUI:NewModule("Chat")

local PANEL_LEFT = 8
local PANEL_RIGHT = 8
local PANEL_TOP = 24
local PANEL_BOTTOM = 10
local PANEL_MIN_WIDTH = 320
local PANEL_MIN_HEIGHT = 160
local CHAT_HISTORY_LIMIT = 10

local function GetSettings()
    return RUI.db and RUI.db.chat
end

local function GetChatCount()
    return tonumber(NUM_CHAT_WINDOWS) or 7
end

local function GetChatScale()
    return RUI:GetEffectiveScale("chat")
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then value = minimum end
    if maximum and value > maximum then value = maximum end
    return value
end

local function GetPanelDimensions(settings)
    settings = settings or {}
    local scale = GetChatScale()
    if scale <= 0 then scale = 1 end
    local parentWidth = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1024
    local parentHeight = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768

    local minInnerWidth = tonumber(CHAT_FRAME_MIN_WIDTH) or 296
    local minInnerHeight = tonumber(CHAT_FRAME_NORMAL_MIN_HEIGHT) or 120
    local physicalMinWidth = math.max(PANEL_MIN_WIDTH, minInnerWidth + PANEL_LEFT + PANEL_RIGHT)
    local physicalMinHeight = math.max(PANEL_MIN_HEIGHT, minInnerHeight + PANEL_TOP + PANEL_BOTTOM)
    local physicalMaxWidth = math.min(608 + PANEL_LEFT + PANEL_RIGHT, math.max(physicalMinWidth, parentWidth - 24))
    local physicalMaxHeight = math.min(400 + PANEL_TOP + PANEL_BOTTOM, math.max(physicalMinHeight, parentHeight - 24))

    -- Width/height settings remain base values. Component/global scale multiplies
    -- them without permanently rewriting the user's chosen panel dimensions.
    local minWidth = physicalMinWidth / scale
    local minHeight = physicalMinHeight / scale
    local maxWidth = physicalMaxWidth / scale
    local maxHeight = physicalMaxHeight / scale
    local baseWidth = Clamp(settings.width or 430, minWidth, maxWidth)
    local baseHeight = Clamp(settings.height or 180, minHeight, maxHeight)

    return baseWidth * scale, baseHeight * scale, scale
end

local function HideNativeChrome(frame)
    if not frame or not frame.GetName then return end
    local name = frame:GetName()
    frame.RUIChatNativeChrome = frame.RUIChatNativeChrome or {}
    if type(CHAT_FRAME_TEXTURES) == "table" then
        for _, suffix in pairs(CHAT_FRAME_TEXTURES) do
            local object = _G[name .. suffix]
            if object then
                local state = frame.RUIChatNativeChrome[suffix]
                if not state then
                    state = {
                        shown = object.IsShown and object:IsShown() and true or false,
                        alpha = object.GetAlpha and object:GetAlpha() or 1,
                    }
                    frame.RUIChatNativeChrome[suffix] = state
                end
                if object.SetAlpha and (not object.GetAlpha or object:GetAlpha() ~= 0) then object:SetAlpha(0) end
                if object.Hide and (not object.IsShown or object:IsShown()) then object:Hide() end
            end
        end
    end
end

local function RestoreNativeChrome(frame)
    if not frame or not frame.GetName then return end
    local name = frame:GetName()
    local saved = frame.RUIChatNativeChrome
    if not saved then return end
    for suffix, state in pairs(saved) do
        local object = _G[name .. suffix]
        if object then
            if object.SetAlpha then object:SetAlpha(state.alpha or 1) end
            if state.shown then
                if object.Show then object:Show() end
            else
                if object.Hide then object:Hide() end
            end
        end
    end
    frame.RUIChatNativeChrome = nil
end

local function HideEditBoxChrome(edit)
    if not edit or not edit.GetName then return end
    local name = edit:GetName()
    local suffixes = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
    edit.RUIChatEditChrome = edit.RUIChatEditChrome or {}
    for i = 1, #suffixes do
        local suffix = suffixes[i]
        local object = _G[name .. suffix]
        if object then
            if not edit.RUIChatEditChrome[suffix] then
                edit.RUIChatEditChrome[suffix] = {
                    shown = object.IsShown and object:IsShown() and true or false,
                    alpha = object.GetAlpha and object:GetAlpha() or 1,
                }
            end
            if object.SetAlpha and (not object.GetAlpha or object:GetAlpha() ~= 0) then object:SetAlpha(0) end
            if object.Hide and (not object.IsShown or object:IsShown()) then object:Hide() end
        end
    end
end


local function EnablePlainArrowHistory(edit)
    if not edit then return end

    -- Wrath's native ChatEdit_SendText(..., 1) already calls
    -- ChatEdit_AddHistory(), which stores sent text directly on the EditBox.
    -- Use that native history instead of replacing OnEnterPressed /
    -- OnArrowPressed scripts: Project Ebonhold and other addons are free to
    -- replace those scripts, but the EditBox history itself remains stable.
    if not edit.RUIChatNativeHistorySaved then
        edit.RUIChatNativeHistorySaved = true

        if edit.GetAltArrowKeyMode then
            local ok, mode = pcall(edit.GetAltArrowKeyMode, edit)
            edit.RUIChatOriginalAltArrowMode = ok and mode and true or false
        else
            edit.RUIChatOriginalAltArrowMode = true
        end

        if edit.GetHistoryLines then
            local ok, lines = pcall(edit.GetHistoryLines, edit)
            if ok then edit.RUIChatOriginalHistoryLines = tonumber(lines) end
        end
    end

    -- Stock Wrath chat uses 32 native history lines and ignoreArrows=true,
    -- which requires Alt+Up/Down. Zen deliberately exposes the last ten
    -- entries on plain Up/Down. These are cheap state setters and are safe to
    -- reassert when Ebonhold rebuilds/refreshes the chat box.
    if edit.SetHistoryLines then pcall(edit.SetHistoryLines, edit, CHAT_HISTORY_LIMIT) end
    if edit.SetAltArrowKeyMode then pcall(edit.SetAltArrowKeyMode, edit, false) end
end

local function RestoreArrowHistoryMode(edit)
    if not edit or not edit.RUIChatNativeHistorySaved then return end

    if edit.SetHistoryLines and edit.RUIChatOriginalHistoryLines then
        pcall(edit.SetHistoryLines, edit, edit.RUIChatOriginalHistoryLines)
    end
    if edit.SetAltArrowKeyMode then
        pcall(edit.SetAltArrowKeyMode, edit, edit.RUIChatOriginalAltArrowMode and true or false)
    end

    edit.RUIChatNativeHistorySaved = nil
    edit.RUIChatOriginalHistoryLines = nil
    edit.RUIChatOriginalAltArrowMode = nil
end

local function RestoreEditBoxChrome(edit)
    if not edit or not edit.GetName or not edit.RUIChatEditChrome then return end
    local name = edit:GetName()
    for suffix, state in pairs(edit.RUIChatEditChrome) do
        local object = _G[name .. suffix]
        if object then
            if object.SetAlpha then object:SetAlpha(state.alpha or 1) end
            if state.shown then
                if object.Show then object:Show() end
            else
                if object.Hide then object:Hide() end
            end
        end
    end
    edit.RUIChatEditChrome = nil
end

local function SetRUIBackdropVisible(frame, visible)
    if not frame or not frame.RUIBackdrop then return end
    if frame.RUIBackground then
        if visible then frame.RUIBackground:Show() else frame.RUIBackground:Hide() end
    end
    if frame.RUIBorder then
        for _, texture in pairs(frame.RUIBorder) do
            if visible then texture:Show() else texture:Hide() end
        end
    end
end

local function SetControlVisible(control, visible)
    if not control then return end
    if visible then
        if control.SetAlpha then control:SetAlpha(1) end
        if control.EnableMouse then control:EnableMouse(true) end
        if control.Show then control:Show() end
    else
        if control.SetAlpha then control:SetAlpha(0) end
        if control.EnableMouse then control:EnableMouse(false) end
    end
end

function Chat:CreateHolder()
    local holder = CreateFrame("Frame", "ZenUIChatHolder", UIParent)
    holder:SetWidth(430)
    holder:SetHeight(180)
    holder:SetFrameStrata("BACKGROUND")
    holder:SetFrameLevel(1)
    holder:SetClampedToScreen(true)
    holder:EnableMouse(false)
    RUI:CreateBackdrop(holder)
    holder.accent = RUI:CreateAccentLine(holder, 2)
    holder:SetScript("OnUpdate", function(_, elapsed) Chat:MaintainChrome(elapsed) end)
    self.holder = holder

    RUI:RegisterMover("Chat", holder, {
        label = "Chat",
        width = 430,
        height = 180,
        point = "BOTTOMLEFT",
        relativePoint = "BOTTOMLEFT",
        x = 22,
        y = 48,
    })
end

function Chat:IsDockedFrame(frame)
    if not frame then return false end
    if frame == DEFAULT_CHAT_FRAME or frame == ChatFrame1 then return true end
    return frame.isDocked and true or false
end

function Chat:ApplyFrame(frame)
    local settings = GetSettings()
    if not settings or not frame then return end

    local scale = GetChatScale()
    local fontPath = RUI.GetFontPath and RUI:GetFontPath() or nil
    local _, _, oldFlags = frame:GetFont()
    if fontPath and frame.SetFont then
        frame:SetFont(fontPath, (tonumber(settings.fontSize) or 12) * scale, oldFlags or "")
    elseif FCF_SetChatWindowFontSize then
        FCF_SetChatWindowFontSize(nil, frame, (tonumber(settings.fontSize) or 12) * scale)
    end

    if frame.SetFading then frame:SetFading(settings.fade == true) end
    if FCF_SetLocked then FCF_SetLocked(frame, settings.locked ~= false and 1 or nil) end
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    HideNativeChrome(frame)

    local name = frame:GetName()
    local tab = _G[name .. "Tab"]
    if tab then
        local tabText = _G[name .. "TabText"] or (tab.GetFontString and tab:GetFontString())
        if tabText then
            local tr, tg, tb = RUI:GetTextColor(false)
            RUI:StyleFontString(tabText, math.max(8, 10 * scale), tr, tg, tb)
        end
        if tab.GetNormalTexture and tab:GetNormalTexture() then tab:GetNormalTexture():SetAlpha(0) end
        if tab.GetPushedTexture and tab:GetPushedTexture() then tab:GetPushedTexture():SetAlpha(0) end
        if tab.GetHighlightTexture and tab:GetHighlightTexture() then tab:GetHighlightTexture():SetAlpha(0) end
    end

    local edit = _G[name .. "EditBox"] or frame.editBox
    if edit then
        if not edit.RUIChatStyled then
            RUI:CreateBackdrop(edit)
            edit.RUIChatStyled = true
        end
        SetRUIBackdropVisible(edit, true)
        RUI:RefreshBackdrop(edit)
        local br, bg, bb = RUI:GetBackgroundColor()
        if edit.RUIBackground then edit.RUIBackground:SetTexture(br, bg, bb, tonumber(settings.editBoxAlpha) or 0.72) end
        if edit.SetHeight then edit:SetHeight((tonumber(settings.editBoxHeight) or 28) * scale) end
        local editFontPath = RUI.GetFontPath and RUI:GetFontPath() or nil
        if editFontPath and edit.SetFont then
            local _, _, editFlags = edit:GetFont()
            edit:SetFont(editFontPath, (tonumber(settings.editBoxFontSize) or 12) * scale, editFlags or "")
        end
        HideEditBoxChrome(edit)
        EnablePlainArrowHistory(edit)
    end
end

function Chat:AnchorDockedFrames()
    local settings = GetSettings()
    if not settings or not self.holder then return end

    local width, height, scale = GetPanelDimensions(settings)
    local left = PANEL_LEFT * scale
    local right = PANEL_RIGHT * scale
    local top = PANEL_TOP * scale
    local bottom = PANEL_BOTTOM * scale
    local innerWidth = math.max(tonumber(CHAT_FRAME_MIN_WIDTH) or 296, width - left - right)
    local innerHeight = math.max(tonumber(CHAT_FRAME_NORMAL_MIN_HEIGHT) or 120, height - top - bottom)

    self.holder:SetWidth(width)
    self.holder:SetHeight(height)
    RUI:UpdateMoverSize("Chat", width, height)

    -- Use a single anchor plus explicit native dimensions.  Two opposing
    -- anchors can force a ScrollingMessageFrame below its native resize floor,
    -- which is what caused the Zen shell and chat bounds to separate near
    -- screen edges in 0.5.0.
    for i = 1, GetChatCount() do
        local frame = _G["ChatFrame" .. i]
        if frame and self:IsDockedFrame(frame) then
            frame:ClearAllPoints()
            frame:SetWidth(innerWidth)
            frame:SetHeight(innerHeight)
            frame:SetPoint("BOTTOMLEFT", self.holder, "BOTTOMLEFT", left, bottom)
            if frame.SetClampRectInsets then frame:SetClampRectInsets(0, 0, 0, 0) end
            self:ApplyFrame(frame)
        elseif frame then
            self:ApplyFrame(frame)
        end
    end
end

function Chat:ApplyButtonVisibility()
    local settings = GetSettings() or {}
    local hide = settings.enabled ~= false and settings.hideButtons ~= false
    SetControlVisible(ChatFrameMenuButton, not hide)

    for i = 1, GetChatCount() do
        local frame = _G["ChatFrame" .. i]
        if frame then
            SetControlVisible(_G[frame:GetName() .. "ButtonFrame"], not hide)
            if frame.resizeButton then SetControlVisible(frame.resizeButton, not hide and settings.locked == false) end
        end
    end
end

function Chat:RefreshAppearance()
    if not self.holder then return end
    RUI:RefreshBackdrop(self.holder)
    RUI:SetAccentTexture(self.holder.accent)
    local settings = GetSettings() or {}
    if self.holder.RUIBackground then
        local r, g, b = RUI:GetBackgroundColor()
        self.holder.RUIBackground:SetTexture(r, g, b, tonumber(settings.backgroundAlpha) or 0.45)
    end
    self:AnchorDockedFrames()
    for i = 1, GetChatCount() do
        local frame = _G["ChatFrame" .. i]
        if frame then HideNativeChrome(frame) end
    end
end

function Chat:RestoreNative()
    for i = 1, GetChatCount() do
        local frame = _G["ChatFrame" .. i]
        if frame then
            RestoreNativeChrome(frame)
            local edit = _G[frame:GetName() .. "EditBox"] or frame.editBox
            if edit then
                RestoreEditBoxChrome(edit)
                RestoreArrowHistoryMode(edit)
                SetRUIBackdropVisible(edit, false)
            end
            if FCF_RestorePositionAndDimensions and not frame.isTemporary then
                pcall(FCF_RestorePositionAndDimensions, frame)
            end
        end
    end
    SetControlVisible(ChatFrameMenuButton, true)
end

function Chat:ApplySettings()
    local settings = GetSettings()
    if not settings or not self.holder then return end

    local enabled = settings.enabled ~= false
    RUI:SetMoverEnabled("Chat", enabled)
    if enabled then
        self.holder:Show()
        self:AnchorDockedFrames()
        self:ApplyButtonVisibility()
        self:RefreshAppearance()
    else
        self.holder:Hide()
        self:RestoreNative()
    end
end

function Chat:MaintainChrome(elapsed)
    self.maintenanceElapsed = (self.maintenanceElapsed or 0) + (elapsed or 0)
    if self.maintenanceElapsed < 1.00 then return end
    self.maintenanceElapsed = 0
    local settings = GetSettings()
    if not settings or settings.enabled == false then return end

    -- Blizzard can re-apply dock dimensions after our layout pass. Treat the
    -- real primary chat frame as the final size authority and make the Zen
    -- shell follow it, while keeping the frame snapped back to the Zen
    -- holder for positioning.
    local primary = ChatFrame1 or DEFAULT_CHAT_FRAME
    if primary and self.holder and self:IsDockedFrame(primary) then
        local scale = GetChatScale()
        local left = PANEL_LEFT * scale
        local right = PANEL_RIGHT * scale
        local top = PANEL_TOP * scale
        local bottom = PANEL_BOTTOM * scale
        local fw = tonumber(primary:GetWidth()) or 0
        local fh = tonumber(primary:GetHeight()) or 0
        if fw > 0 and fh > 0 then
            local outerW = fw + left + right
            local outerH = fh + top + bottom
            if math.abs((self.holder:GetWidth() or 0) - outerW) > 0.5 or math.abs((self.holder:GetHeight() or 0) - outerH) > 0.5 then
                self.holder:SetWidth(outerW)
                self.holder:SetHeight(outerH)
                RUI:UpdateMoverSize("Chat", outerW, outerH)
                settings.width = outerW / scale
                settings.height = outerH / scale
            end
        end
        local _, relativeTo = primary:GetPoint(1)
        if relativeTo ~= self.holder then
            primary:ClearAllPoints()
            primary:SetPoint("BOTTOMLEFT", self.holder, "BOTTOMLEFT", left, bottom)
        end
    end

    for i = 1, GetChatCount() do
        local frame = _G["ChatFrame" .. i]
        if frame then
            HideNativeChrome(frame)
            local edit = _G[frame:GetName() .. "EditBox"] or frame.editBox
            if edit then
                HideEditBoxChrome(edit)
                EnablePlainArrowHistory(edit)
                local scale = GetChatScale()
                if edit.SetHeight then edit:SetHeight((tonumber(settings.editBoxHeight) or 28) * scale) end
                if edit.RUIBackground then
                    local br, bg, bb = RUI:GetBackgroundColor()
                    edit.RUIBackground:SetTexture(br, bg, bb, tonumber(settings.editBoxAlpha) or 0.72)
                end
            end
        end
    end
end

function Chat:OnComponentScaleChanged(key)
    if key == "all" or key == "chat" then self:ApplySettings() end
end

function Chat:OnEvent(event)
    if event == "UPDATE_CHAT_WINDOWS" or event == "UPDATE_FLOATING_CHAT_WINDOWS" or event == "PLAYER_ENTERING_WORLD" then
        self:ApplySettings()
    end
end

function Chat:OnInitialize()
    self:CreateHolder()
    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "RefreshAppearance")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED", self, "OnComponentScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET", self, "ApplySettings")
end

function Chat:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
    self:RegisterEvent("UPDATE_CHAT_WINDOWS", "OnEvent")
    self:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", "OnEvent")
    self:ApplySettings()
end
