-- ZenUI 0.2.5 visual development preview.
-- Validates the shared appearance/media API before real gameplay frames consume it.

local RUI = ZenUI
local TestFrame = RUI:NewModule("TestFrame")

function TestFrame:OnInitialize()
    local frame = CreateFrame("Frame", "ZenUITestFrame", UIParent)
    frame:SetWidth(320)
    frame:SetHeight(144)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(false)

    RUI:CreateBackdrop(frame)
    frame.accent = RUI:CreateAccentLine(frame, 2)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -17)
    RUI:StyleFontString(frame.title, 14)
    frame.title:SetText("ZenUI")

    frame.version = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.version:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -19)
    RUI:StyleFontString(frame.version, 10)
    frame.version:SetText(RUI.version or "0.2.5b")

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.status:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -12)
    RUI:StyleFontString(frame.status, 11)
    frame.status:SetText("Design system online - live appearance preview")

    frame.previewLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.previewLabel:SetPoint("TOPLEFT", frame.status, "BOTTOMLEFT", 0, -14)
    RUI:StyleFontString(frame.previewLabel, 9)
    frame.previewLabel:SetText("MEDIA / STATUSBAR")

    frame.previewBar = RUI:CreateStatusBar(frame, 292, 9)
    frame.previewBar:SetPoint("TOPLEFT", frame.previewLabel, "BOTTOMLEFT", 0, -6)
    frame.previewBar:SetValue(72)

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 13)
    RUI:StyleFontString(frame.hint, 10)
    frame.hint:SetText("/zenui settings  |  /zenui move  |  /zenui theme")

    self.frame = frame
    self.mover = RUI:RegisterMover("TestPanel", frame, {
        label = "ZenUI Test Panel",
        width = 320,
        height = 144,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -120,
        enabled = RUI.db and RUI.db.testFrame and RUI.db.testFrame.shown ~= false,
    })

    RUI:RegisterCallback("PROFILE_RESET", self, "OnProfileReset")
    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "OnAppearanceChanged")

    self:ApplyProfile()
end

function TestFrame:OnEnable()
    self:ApplyProfile()
end

function TestFrame:OnProfileReset()
    self:ApplyProfile()
end

function TestFrame:OnAppearanceChanged()
    self:ApplyAppearance()
end

function TestFrame:ApplyAppearance()
    if not self.frame then
        return
    end

    local frame = self.frame
    local scale = RUI:GetUIScale()
    frame:SetScale(scale)

    RUI:RefreshBackdrop(frame)
    RUI:SetAccentTexture(frame.accent)
    frame.accent:SetHeight(RUI:GetPixelSize(frame, 2))
    RUI:RefreshStatusBar(frame.previewBar)

    RUI:StyleFontString(frame.title, 14)
    RUI:StyleFontString(frame.version, 10, 0.55, 0.57, 0.61)
    RUI:StyleFontString(frame.status, 11, 0.72, 0.74, 0.78)
    RUI:StyleFontString(frame.previewLabel, 9, 0.55, 0.57, 0.61)
    RUI:StyleFontString(frame.hint, 10, 0.50, 0.52, 0.56)

    -- The mover lives on UIParent, so account for the target's visual scale.
    RUI:UpdateMoverSize("TestPanel", 320 * scale, 144 * scale)
end

function TestFrame:ApplyProfile()
    if not self.frame or not RUI.db or not RUI.db.testFrame then
        return
    end

    self:ApplyAppearance()

    if RUI.db.testFrame.shown == false then
        self.frame:Hide()
        RUI:SetMoverEnabled("TestPanel", false)
    else
        self.frame:Show()
        RUI:SetMoverEnabled("TestPanel", true)
    end
end

function TestFrame:ShowForTesting(resetPosition)
    if not self.frame then
        RUI:Print("TestFrame is not initialized. Use /zenui status for the stored module error.")
        return false
    end

    if resetPosition then
        RUI:ResetMover("TestPanel")
    end

    self.frame:Show()
    RUI:SetMoverEnabled("TestPanel", true)
    if RUI.db and RUI.db.testFrame then
        RUI.db.testFrame.shown = true
    end
    return true
end

function TestFrame:Toggle()
    if not self.frame then
        RUI:Print("TestFrame is not initialized.")
        return
    end

    if self.frame:IsShown() then
        self.frame:Hide()
        RUI:SetMoverEnabled("TestPanel", false)
        RUI.db.testFrame.shown = false
    else
        self:ShowForTesting(false)
    end
end
