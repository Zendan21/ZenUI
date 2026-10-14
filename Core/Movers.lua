-- ZenUI 0.1.3 mover/layout system.
-- UI modules register named anchors here instead of implementing dragging themselves.

local RUI = ZenUI

local function Round(value)
    value = value or 0
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function Snap(value, size)
    if not size or size <= 1 then
        return Round(value)
    end

    if value >= 0 then
        return math.floor((value / size) + 0.5) * size
    end

    return math.ceil((value / size) - 0.5) * size
end

local LOCK_POINTS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local LOCK_POINT_LABELS = {
    TOPLEFT = "Top Left",
    TOPRIGHT = "Top Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOMRIGHT = "Bottom Right",
}

local function IsLockPoint(point)
    return point == "TOPLEFT" or point == "TOPRIGHT" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT"
end

-- Mover groups power the section-specific /zenui mover views. A mover can
-- intentionally belong to more than one group (for example Bank appears both
-- on the dedicated Bank page and in the broader Service Panels collection).
local DEFAULT_MOVER_GROUPS = {
    PlayerFrame = { unitframes=true }, TargetFrame = { unitframes=true }, FocusFrame = { unitframes=true }, PetFrame = { unitframes=true },
    PartyFrames = { groups=true }, RaidFrames = { groups=true },
    ActionBar1 = { actionbars=true }, ActionBar2 = { actionbars=true }, ActionBar3 = { actionbars=true },
    ActionBar4 = { actionbars=true }, ActionBar5 = { actionbars=true }, ActionBar6 = { actionbars=true },
    PetActionBar = { actionbars=true }, StanceBar = { actionbars=true }, TotemBar = { actionbars=true }, TotemTimerBar = { actionbars=true },
    MicroMenu = { menu=true }, QuickMenu = { menu=true }, Minimap = { minimap=true }, Chat = { chat=true }, Bags = { bags=true }, ZenLootRolls = { loot=true },
    ZenSpellbook = { panelsA=true }, ZenSocial = { panelsA=true }, ZenDungeonFinder = { panelsA=true },
    ZenCharacter = { panelsB=true }, ZenQuestLog = { panelsB=true }, ZenMail = { panelsB=true },
    ZenMerchant = { panelsB=true }, ZenBank = { panelsB=true, bank=true }, ZenTrade = { panelsB=true },
    ZenTalents = { panelsC=true }, ZenPvP = { panelsC=true }, ExperienceBar = { panelsC=true },
    ReputationBar = { panelsC=true }, ZenAchievements = { panelsC=true },
    ZenInspect = { panelsD=true }, ZenTrainer = { panelsD=true }, ZenNPCInteraction = { panelsD=true },
}

local function CopyMoverGroups(source)
    if type(source) ~= "table" then return nil end
    local out = {}
    local found = false
    for key, value in pairs(source) do
        if type(key) == "number" then
            if type(value) == "string" and value ~= "" then out[value] = true; found = true end
        elseif value then
            out[key] = true; found = true
        end
    end
    return found and out or nil
end

function RUI:IsMoverInGroup(mover, group)
    if not group or group == "" or group == "all" then return true end
    if type(mover) == "string" then mover = self:GetMover(mover) end
    if not mover then return false end
    local groups = mover.groups or DEFAULT_MOVER_GROUPS[mover.id]
    return groups and groups[group] and true or false
end

local function CopyPosition(source)
    return {
        point = source.point or "CENTER",
        relativePoint = source.relativePoint or "CENTER",
        x = source.x or 0,
        y = source.y or 0,
        lockPoint = IsLockPoint(source.lockPoint) and source.lockPoint or "TOPLEFT",
    }
end

local function GetMoverPosition(mover)
    local x, y
    local moverX, moverY = mover:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if moverX and moverY and parentX and parentY then
        x = moverX - parentX
        y = moverY - parentY
    else
        local db = RUI.db and RUI.db.movers and RUI.db.movers[mover.id]
        x = db and db.x or mover.defaults.x or 0
        y = db and db.y or mover.defaults.y or 0
    end

    return x, y
end

-- Convert between the mover's stored CENTER position and the visible corner
-- selected under Lock Position. Grid snapping should land that selected corner
-- on a grid intersection; snapping the mover's hidden centre makes differently
-- sized panels appear off-grid even when their stored centre technically snapped.
local function GetMoverLockOffset(mover, point)
    local halfW = (mover and mover:GetWidth() or 0) / 2
    local halfH = (mover and mover:GetHeight() or 0) / 2

    if point == "TOPLEFT" then return -halfW, halfH end
    if point == "TOPRIGHT" then return halfW, halfH end
    if point == "BOTTOMLEFT" then return -halfW, -halfH end
    if point == "BOTTOMRIGHT" then return halfW, -halfH end
    return 0, 0
end

local function SetBorderTexture(texture, r, g, b, a)
    texture:SetTexture(r, g, b, a)
end

local function StyleMoverControlText(fontString, size, muted)
    if not fontString then return end
    local r, g, b = RUI:GetTextColor(muted and true or false)
    RUI:StyleFontString(fontString, size or 10, r, g, b)
end

local function CreateMoverControlButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width or 120)
    button:SetHeight(height or 24)
    -- Wrath/private-server clients can be fussy when child buttons have had
    -- mouse input toggled off and on while their parent is movable. Keep the
    -- button hit rect live permanently; the click handlers themselves are
    -- safe no-ops until a mover is selected.
    button:EnableMouse(true)
    if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp") end
    if button.SetFrameStrata then button:SetFrameStrata("TOOLTIP") end
    if parent and parent.GetFrameLevel then
        button:SetFrameLevel((parent:GetFrameLevel() or 0) + 20)
    end
    button.RUIText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.RUIText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.RUIText:SetText(label or "Button")
    StyleMoverControlText(button.RUIText, 10, false)
    RUI:StyleButton(button)
    return button
end


local function GetReadableGridSpacing(snapSize)
    local spacing = tonumber(snapSize) or 4
    if spacing < 1 then spacing = 1 end
    while spacing < 24 do spacing = spacing * 2 end
    return spacing
end

-- When the visible alignment grid is enabled, that grid becomes the snapping
-- authority. This keeps mover anchors landing exactly on the lines/intersections
-- the player can see instead of on smaller invisible snap increments between
-- them. With the alignment grid hidden, the configured Snap Size remains the
-- normal precision interval.
local function GetEffectiveSnapSpacing(layout)
    layout = layout or {}
    local snapSize = tonumber(layout.snapSize) or 4
    if layout.showGrid == true then
        return GetReadableGridSpacing(snapSize), true
    end
    return snapSize, false
end

function RUI:CreateAlignmentGrid()
    if self.alignmentGrid then return self.alignmentGrid end

    local grid = CreateFrame("Frame", "ZenUIAlignmentGrid", UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("DIALOG")
    grid:SetFrameLevel(1)
    grid:EnableMouse(false)
    grid.lines = {}

    grid:SetScript("OnSizeChanged", function(self)
        if self:IsShown() then RUI:RefreshAlignmentGrid() end
    end)

    grid:Hide()
    self.alignmentGrid = grid
    return grid
end

local function AcquireGridLine(grid, index)
    local line = grid.lines[index]
    if not line then
        line = grid:CreateTexture(nil, "ARTWORK")
        line:SetTexture(RUI.Media.textures.white)
        grid.lines[index] = line
    end
    line:Show()
    return line
end

function RUI:RefreshAlignmentGrid()
    local grid = self.alignmentGrid
    if not grid then return end

    for i = 1, #grid.lines do grid.lines[i]:Hide() end
    if not self.moverMode then grid:Hide(); return end

    local layout = self.db and self.db.layout or {}
    if layout.showGrid ~= true then grid:Hide(); return end

    local width = UIParent:GetWidth() or 0
    local height = UIParent:GetHeight() or 0
    if width <= 0 or height <= 0 then grid:Hide(); return end

    local spacing = GetReadableGridSpacing(layout.snapSize or 4)
    -- Grid lines must remain readable over the 3D world. Zen's border
    -- color is intentionally very dark, so use the normal UI text color for
    -- the neutral grid and reserve the accent for the exact center axes.
    local gr, gg, gb = self:GetTextColor(true)
    local ar, ag, ab = self:GetAccentColor()
    local index = 0

    -- Build outward from exact screen center. The visible grid spacing is a
    -- readable multiple of the configured snap interval, so every line still
    -- lands on a valid snap coordinate without turning a 4px snap into a wall
    -- of hundreds of opaque lines.
    local maxX = math.floor((width / 2) / spacing)
    for n = -maxX, maxX do
        if n ~= 0 then
            index = index + 1
            local line = AcquireGridLine(grid, index)
            line:ClearAllPoints()
            line:SetWidth(1)
            line:SetPoint("TOP", UIParent, "TOP", n * spacing, 0)
            line:SetPoint("BOTTOM", UIParent, "BOTTOM", n * spacing, 0)
            local alpha = (math.abs(n) % 4 == 0) and 0.44 or 0.24
            line:SetTexture(gr, gg, gb, alpha)
        end
    end

    local maxY = math.floor((height / 2) / spacing)
    for n = -maxY, maxY do
        if n ~= 0 then
            index = index + 1
            local line = AcquireGridLine(grid, index)
            line:ClearAllPoints()
            line:SetHeight(1)
            line:SetPoint("LEFT", UIParent, "LEFT", 0, n * spacing)
            line:SetPoint("RIGHT", UIParent, "RIGHT", 0, n * spacing)
            local alpha = (math.abs(n) % 4 == 0) and 0.44 or 0.24
            line:SetTexture(gr, gg, gb, alpha)
        end
    end

    -- Strong center crosshair for exact horizontal/vertical alignment.
    index = index + 1
    local centerV = AcquireGridLine(grid, index)
    centerV:ClearAllPoints()
    centerV:SetWidth(3)
    centerV:SetPoint("TOP", UIParent, "TOP", 0, 0)
    centerV:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
    centerV:SetTexture(ar, ag, ab, 1)

    index = index + 1
    local centerH = AcquireGridLine(grid, index)
    centerH:ClearAllPoints()
    centerH:SetHeight(3)
    centerH:SetPoint("LEFT", UIParent, "LEFT", 0, 0)
    centerH:SetPoint("RIGHT", UIParent, "RIGHT", 0, 0)
    centerH:SetTexture(ar, ag, ab, 1)

    grid:Show()
end

function RUI:SetAlignmentGridShown(enabled)
    if not self.db or not self.db.layout then return false end
    self.db.layout.showGrid = enabled and true or false
    if self.moverMode then
        self:CreateAlignmentGrid()
        self:RefreshAlignmentGrid()
    elseif self.alignmentGrid then
        self.alignmentGrid:Hide()
    end
    self:RefreshMoverControlWindow()
    return true
end

function RUI:CreateMoverControlWindow()
    if self.moverControls then
        return self.moverControls
    end

    local frame = CreateFrame("Frame", "ZenUIMoverControls", UIParent)
    frame:SetWidth(360)
    frame:SetHeight(344)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -54)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(1000)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    RUI:CreateBackdrop(frame)
    frame.accent = RUI:CreateAccentLine(frame, 2)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -16)
    frame.title:SetText("Mover Controls")
    StyleMoverControlText(frame.title, 12, false)

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.hint:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -5)
    frame.hint:SetWidth(332)
    frame.hint:SetJustifyH("LEFT")
    frame.hint:SetText("Drag anchors normally. Click an anchor to unlock precision movement and choose which corner the UI locks to.")
    StyleMoverControlText(frame.hint, 9, true)

    -- Full-row toggles are intentionally high contrast, but keep the label and
    -- state in separate fixed regions so they never collide. The row itself
    -- communicates selection; a compact badge on the right gives an explicit
    -- ON/OFF readout without adding a second checkbox control.
    local function CreateMoverToggleRowChrome(check)
        local fill = check:CreateTexture(nil, "BACKGROUND")
        fill:SetPoint("TOPLEFT", check, "TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMRIGHT", check, "BOTTOMRIGHT", 0, 0)
        fill:SetTexture(1, 1, 1, 1)

        local border = {}
        border.top = check:CreateTexture(nil, "BORDER")
        border.top:SetHeight(1)
        border.top:SetPoint("TOPLEFT", check, "TOPLEFT", 0, 0)
        border.top:SetPoint("TOPRIGHT", check, "TOPRIGHT", 0, 0)
        border.bottom = check:CreateTexture(nil, "BORDER")
        border.bottom:SetHeight(1)
        border.bottom:SetPoint("BOTTOMLEFT", check, "BOTTOMLEFT", 0, 0)
        border.bottom:SetPoint("BOTTOMRIGHT", check, "BOTTOMRIGHT", 0, 0)
        border.left = check:CreateTexture(nil, "BORDER")
        border.left:SetWidth(1)
        border.left:SetPoint("TOPLEFT", check, "TOPLEFT", 0, 0)
        border.left:SetPoint("BOTTOMLEFT", check, "BOTTOMLEFT", 0, 0)
        border.right = check:CreateTexture(nil, "BORDER")
        border.right:SetWidth(1)
        border.right:SetPoint("TOPRIGHT", check, "TOPRIGHT", 0, 0)
        border.right:SetPoint("BOTTOMRIGHT", check, "BOTTOMRIGHT", 0, 0)

        local badge = CreateFrame("Frame", nil, check)
        badge:SetWidth(34)
        badge:SetHeight(16)
        badge:SetPoint("RIGHT", check, "RIGHT", -4, 0)
        badge:SetFrameLevel(check:GetFrameLevel() + 2)

        local badgeFill = badge:CreateTexture(nil, "BACKGROUND")
        badgeFill:SetAllPoints(badge)
        badgeFill:SetTexture(0.04, 0.04, 0.04, 1)

        local state = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        state:SetPoint("CENTER", badge, "CENTER", 0, 0)
        state:SetJustifyH("CENTER")
        RUI:StyleFontString(state, 8, 1, 1, 1)
        return fill, border, badge, badgeFill, state
    end

    frame.snapCheck = CreateFrame("CheckButton", nil, frame)
    frame.snapCheck:SetWidth(166)
    frame.snapCheck:SetHeight(22)
    frame.snapCheck:EnableMouse(true)
    frame.snapCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -70)
    frame.snapCheck:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.snapStateFill, frame.snapStateBorder, frame.snapStateBadge, frame.snapStateBadgeFill, frame.snapStateText = CreateMoverToggleRowChrome(frame.snapCheck)

    frame.snapLabel = frame.snapCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.snapLabel:SetPoint("LEFT", frame.snapCheck, "LEFT", 9, 0)
    frame.snapLabel:SetWidth(112)
    frame.snapLabel:SetJustifyH("LEFT")
    frame.snapLabel:SetText("Snap to grid")
    StyleMoverControlText(frame.snapLabel, 10, false)

    frame.snapCheck:SetScript("OnClick", function(self)
        RUI:SetSnapEnabled(self:GetChecked() and true or false)
    end)

    frame.gridCheck = CreateFrame("CheckButton", nil, frame)
    frame.gridCheck:SetWidth(166)
    frame.gridCheck:SetHeight(22)
    frame.gridCheck:EnableMouse(true)
    frame.gridCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -96)
    frame.gridCheck:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.gridStateFill, frame.gridStateBorder, frame.gridStateBadge, frame.gridStateBadgeFill, frame.gridStateText = CreateMoverToggleRowChrome(frame.gridCheck)

    frame.gridLabel = frame.gridCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.gridLabel:SetPoint("LEFT", frame.gridCheck, "LEFT", 9, 0)
    frame.gridLabel:SetWidth(112)
    frame.gridLabel:SetJustifyH("LEFT")
    frame.gridLabel:SetText("Show alignment grid")
    StyleMoverControlText(frame.gridLabel, 10, false)

    frame.gridCheck:SetScript("OnClick", function(self)
        RUI:SetAlignmentGridShown(self:GetChecked() and true or false)
    end)

    frame.snapSizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.snapSizeLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 188, -68)
    frame.snapSizeLabel:SetText("SNAP SIZE")
    StyleMoverControlText(frame.snapSizeLabel, 8, true)

    frame.snapSizeValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.snapSizeValue:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -68)
    frame.snapSizeValue:SetJustifyH("RIGHT")
    StyleMoverControlText(frame.snapSizeValue, 9, false)

    frame.snapSlider = CreateFrame("Slider", nil, frame)
    frame.snapSlider:SetOrientation("HORIZONTAL")
    frame.snapSlider:EnableMouse(true)
    frame.snapSlider:SetWidth(158)
    frame.snapSlider:SetHeight(14)
    frame.snapSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 188, -86)
    frame.snapSlider:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.snapSlider:SetMinMaxValues(1, 32)
    frame.snapSlider:SetValueStep(1)

    frame.snapTrack = frame.snapSlider:CreateTexture(nil, "BACKGROUND")
    frame.snapTrack:SetHeight(3)
    frame.snapTrack:SetPoint("LEFT", frame.snapSlider, "LEFT", 0, 0)
    frame.snapTrack:SetPoint("RIGHT", frame.snapSlider, "RIGHT", 0, 0)

    frame.snapSlider:SetThumbTexture(RUI.Media.textures.white)
    frame.snapThumb = frame.snapSlider:GetThumbTexture()
    frame.snapThumb:SetWidth(8)
    frame.snapThumb:SetHeight(14)
    RUI:SetAccentTexture(frame.snapThumb)
    frame.snapSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = Round(value)
        frame.snapSizeValue:SetText(tostring(rounded) .. "px")
        if not frame.refreshing then
            RUI:SetSnapSize(rounded)
        end
    end)

    frame.selectedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.selectedLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -122)
    frame.selectedLabel:SetText("SELECTED PANEL")
    StyleMoverControlText(frame.selectedLabel, 8, true)

    frame.selectedValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.selectedValue:SetPoint("TOPLEFT", frame.selectedLabel, "BOTTOMLEFT", 0, -4)
    frame.selectedValue:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -134)
    frame.selectedValue:SetJustifyH("LEFT")
    frame.selectedValue:SetText("None - click a mover panel")
    StyleMoverControlText(frame.selectedValue, 10, false)

    frame.lockPointLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.lockPointLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -154)
    frame.lockPointLabel:SetText("LOCK POSITION")
    StyleMoverControlText(frame.lockPointLabel, 8, true)

    frame.lockPointButtons = {}
    local previous
    for i = 1, #LOCK_POINTS do
        local point = LOCK_POINTS[i]
        local button = CreateMoverControlButton(frame, LOCK_POINT_LABELS[point], 78, 24)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        else
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -172)
        end
        button.lockPoint = point
        button:SetScript("OnClick", function(self)
            RUI:SetSelectedMoverLockPoint(self.lockPoint)
        end)
        frame.lockPointButtons[point] = button
        previous = button
    end

    frame.precisionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.precisionLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -210)
    frame.precisionLabel:SetText("PRECISION MOVE  •  1PX")
    StyleMoverControlText(frame.precisionLabel, 8, true)

    frame.nudgeLeft = CreateMoverControlButton(frame, "-X", 50, 24)
    frame.nudgeLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -228)
    frame.nudgeLeft:SetScript("OnClick", function() RUI:NudgeSelectedMover(-1, 0) end)

    frame.nudgeRight = CreateMoverControlButton(frame, "+X", 50, 24)
    frame.nudgeRight:SetPoint("LEFT", frame.nudgeLeft, "RIGHT", 6, 0)
    frame.nudgeRight:SetScript("OnClick", function() RUI:NudgeSelectedMover(1, 0) end)

    frame.nudgeUp = CreateMoverControlButton(frame, "+Y", 50, 24)
    frame.nudgeUp:SetPoint("LEFT", frame.nudgeRight, "RIGHT", 6, 0)
    frame.nudgeUp:SetScript("OnClick", function() RUI:NudgeSelectedMover(0, 1) end)

    frame.nudgeDown = CreateMoverControlButton(frame, "-Y", 50, 24)
    frame.nudgeDown:SetPoint("LEFT", frame.nudgeUp, "RIGHT", 6, 0)
    frame.nudgeDown:SetScript("OnClick", function() RUI:NudgeSelectedMover(0, -1) end)

    frame.resetSelected = CreateMoverControlButton(frame, "Reset", 88, 24)
    frame.resetSelected:SetPoint("LEFT", frame.nudgeDown, "RIGHT", 6, 0)
    frame.resetSelected:SetScript("OnClick", function()
        if RUI.selectedMover then
            RUI:ResetMover(RUI.selectedMover.id)
            RUI:SelectMover(RUI.selectedMover)
        end
    end)

    frame.precisionHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.precisionHint:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -262)
    frame.precisionHint:SetWidth(332)
    frame.precisionHint:SetJustifyH("LEFT")
    frame.precisionHint:SetText("Grid snap magnetizes the nearest visible panel edges. Lock Position controls which UI corner follows its mover. Precision nudges ignore grid snap.")
    StyleMoverControlText(frame.precisionHint, 8, true)

    frame.lock = CreateMoverControlButton(frame, "Lock & Return to Settings", 332, 28)
    frame.lock:EnableMouse(true)
    frame.lock:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
    frame.lock:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.lock:SetScript("OnClick", function()
        local returnPage = RUI.moverReturnPage or "LAYOUT"
        RUI:SetMoverMode(false)
        local config = RUI:GetModule("Config")
        if config and config.ShowPage then
            config:ShowPage(returnPage)
        end
    end)

    frame:Hide()
    self.moverControls = frame
    self:RefreshMoverControlWindow()
    return frame
end

function RUI:RefreshMoverControlWindow()
    local frame = self.moverControls
    if not frame then return end

    local layout = self.db and self.db.layout or {}
    local enabled = layout.snapEnabled and true or false
    local showGrid = layout.showGrid == true
    local size = tonumber(layout.snapSize) or 4
    local groupLabel = self.moverGroupLabel
    frame.title:SetText(groupLabel and ("Mover Controls  /  " .. groupLabel) or "Mover Controls  /  All Panels")
    if groupLabel then
        frame.hint:SetText("Only " .. groupLabel .. " anchors are shown. Drag an anchor, or click it for lock-point and 1px precision controls.")
    else
        frame.hint:SetText("All enabled Zen anchors are shown. Drag an anchor, or click it for lock-point and 1px precision controls.")
    end

    frame.refreshing = true
    frame.snapCheck:SetChecked(enabled)
    frame.gridCheck:SetChecked(showGrid)
    frame.snapSlider:SetValue(size)
    if enabled and showGrid then
        local effective = GetReadableGridSpacing(size)
        frame.snapSizeValue:SetText(tostring(Round(size)) .. "px  |  grid " .. tostring(Round(effective)) .. "px")
    else
        frame.snapSizeValue:SetText(tostring(Round(size)) .. "px")
    end
    frame.refreshing = false

    RUI:RefreshBackdrop(frame)
    RUI:SetAccentTexture(frame.accent)
    RUI:SetAccentTexture(frame.snapThumb)

    -- Clean full-row state inversion. Labels have a fixed text region and the
    -- ON/OFF badge has its own fixed-width region, preventing overlap at any UI
    -- scale while keeping the selected state unmistakable.
    local tr, tg, tb = RUI:GetTextColor(false)
    local bgr, bgg, bgb = RUI:GetBackgroundColor()

    local function SetToggleRowBorder(border, r, g, b, a)
        if not border then return end
        for _, tex in pairs(border) do tex:SetTexture(r, g, b, a or 1) end
    end

    local function SetMoverToggleVisual(label, rowFill, rowBorder, badgeFill, stateText, checked)
        if checked then
            rowFill:SetTexture(0.94, 0.94, 0.94, 0.98)
            SetToggleRowBorder(rowBorder, 1, 1, 1, 1)
            label:SetTextColor(0.035, 0.035, 0.035, 1)
            badgeFill:SetTexture(0.035, 0.035, 0.035, 1)
            stateText:SetText("ON")
            stateText:SetTextColor(1, 1, 1, 1)
        else
            rowFill:SetTexture(bgr, bgg, bgb, 0.96)
            SetToggleRowBorder(rowBorder, 0.42, 0.44, 0.49, 1)
            label:SetTextColor(tr, tg, tb, 1)
            badgeFill:SetTexture(0.18, 0.19, 0.22, 1)
            stateText:SetText("OFF")
            stateText:SetTextColor(0.72, 0.74, 0.79, 1)
        end
        rowFill:Show()
    end

    SetMoverToggleVisual(frame.snapLabel, frame.snapStateFill, frame.snapStateBorder, frame.snapStateBadgeFill, frame.snapStateText, enabled)
    SetMoverToggleVisual(frame.gridLabel, frame.gridStateFill, frame.gridStateBorder, frame.gridStateBadgeFill, frame.gridStateText, showGrid)

    local br, bg, bb = RUI:GetBorderColor()
    frame.snapTrack:SetTexture(br, bg, bb, 0.85)
    StyleMoverControlText(frame.title, 12, false)
    StyleMoverControlText(frame.hint, 9, true)
    -- snapLabel/gridLabel keep the explicit high-contrast ON/OFF colors above.
    StyleMoverControlText(frame.snapSizeLabel, 8, true)
    StyleMoverControlText(frame.snapSizeValue, 9, false)
    StyleMoverControlText(frame.selectedLabel, 8, true)
    StyleMoverControlText(frame.selectedValue, 10, false)
    StyleMoverControlText(frame.lockPointLabel, 8, true)
    StyleMoverControlText(frame.precisionLabel, 8, true)
    StyleMoverControlText(frame.precisionHint, 8, true)
    if frame.lockPointButtons then
        for _, button in pairs(frame.lockPointButtons) do RUI:StyleButton(button) end
    end
    RUI:StyleButton(frame.nudgeLeft)
    RUI:StyleButton(frame.nudgeRight)
    RUI:StyleButton(frame.nudgeUp)
    RUI:StyleButton(frame.nudgeDown)
    RUI:StyleButton(frame.resetSelected)
    RUI:StyleButton(frame.lock)
    self:RefreshSelectedMoverControls()
end

local function SetMoverControlEnabled(control, enabled)
    if not control then return end

    -- Visual-only disabled state. Never turn mouse input off here. On several
    -- 3.3.5/private-server builds EnableMouse(false) on a child of a movable
    -- frame can remain effectively sticky even after EnableMouse(true).
    -- All precision handlers already validate RUI.selectedMover, so leaving
    -- their hit rects live is safe and far more reliable.
    control.RUIMoverControlEnabled = enabled and true or false
    if control.Enable then control:Enable() end
    if control.EnableMouse then control:EnableMouse(true) end
    if control.RegisterForClicks then control:RegisterForClicks("LeftButtonUp") end
    if control.SetButtonState then control:SetButtonState("NORMAL") end
    control:SetAlpha(1)

    if control.RUIText then
        if enabled then
            RUI:StyleFontString(control.RUIText, 10, 1, 1, 1)
            control.RUIText:SetAlpha(1)
        else
            StyleMoverControlText(control.RUIText, 10, true)
            control.RUIText:SetAlpha(0.5)
        end
    end

    -- Keep the backdrop present even while visually inactive. This avoids
    -- inheriting Blizzard's disabled-button tint/state on old FrameXML.
    if enabled then
        RUI:RefreshBackdrop(control)
    end
end

function RUI:GetMoverLockPoint(mover)
    if type(mover) == "string" then mover = self:GetMover(mover) end
    if not mover then return "TOPLEFT" end
    local db = self:GetMoverDB(mover.id, mover.defaults)
    local point = db and db.lockPoint or mover.defaults.lockPoint or "TOPLEFT"
    return IsLockPoint(point) and point or "TOPLEFT"
end

function RUI:ApplyMoverTargetAnchors(mover)
    if type(mover) == "string" then mover = self:GetMover(mover) end
    if not mover or mover.anchorTarget == false then return false end

    local point = self:GetMoverLockPoint(mover)
    local function AnchorTarget(target)
        if not target then return end
        target:ClearAllPoints()
        target:SetPoint(point, mover, point, mover.targetX or 0, mover.targetY or 0)
    end

    AnchorTarget(mover.target)
    if mover.linkedTargets then
        for i = 1, #mover.linkedTargets do AnchorTarget(mover.linkedTargets[i]) end
    end
    return true
end

function RUI:AddMoverLinkedTarget(id, target)
    local mover = self:GetMover(id)
    if not mover or not target then return false end
    mover.linkedTargets = mover.linkedTargets or {}
    for i = 1, #mover.linkedTargets do
        if mover.linkedTargets[i] == target then
            self:ApplyMoverTargetAnchors(mover)
            return true
        end
    end
    table.insert(mover.linkedTargets, target)
    self:ApplyMoverTargetAnchors(mover)
    return true
end

function RUI:SetSelectedMoverLockPoint(point)
    local mover = self.selectedMover
    if not mover or not IsLockPoint(point) then return false end
    local db = self:GetMoverDB(mover.id, mover.defaults)
    if not db then return false end
    db.lockPoint = point
    self:ApplyMoverTargetAnchors(mover)
    self:RefreshSelectedMoverControls()
    self:FireCallback("MOVER_LOCK_POINT_CHANGED", mover.id, point)
    return true
end

function RUI:RefreshSelectedMoverControls()
    local controls = self.moverControls
    if not controls or not controls.selectedValue then return end

    local mover = self.selectedMover
    local enabled = mover ~= nil
    if not mover then
        controls.selectedValue:SetText("None - click a mover panel")
    else
        local x, y = GetMoverPosition(mover)
        controls.selectedValue:SetText((mover.label or mover.id) .. "   X " .. Round(x) .. "   Y " .. Round(y))
    end

    local dependent = {
        controls.nudgeLeft, controls.nudgeRight, controls.nudgeUp,
        controls.nudgeDown, controls.resetSelected,
    }
    for i = 1, #dependent do SetMoverControlEnabled(dependent[i], enabled) end

    local activePoint = mover and self:GetMoverLockPoint(mover) or nil
    if controls.lockPointButtons then
        local ar, ag, ab = self:GetAccentColor()
        for point, button in pairs(controls.lockPointButtons) do
            -- Style first: StyleButton enables mouse input as part of its shared
            -- setup, so the selected-state gate must be applied afterwards.
            RUI:StyleButton(button)
            SetMoverControlEnabled(button, enabled)
            if enabled and point == activePoint then
                if button.RUIBackground then button.RUIBackground:SetTexture(1, 1, 1, 1) end
                RUI:SetBorderColor(button, 1, 1, 1, 1)
                if button.RUIText then RUI:StyleFontString(button.RUIText, 10, 0.06, 0.06, 0.06) end
            else
                RUI:RefreshBackdrop(button)
            end
        end
    end

    if controls.lockPointLabel then controls.lockPointLabel:SetAlpha(enabled and 1 or 0.35) end
    if controls.precisionLabel then controls.precisionLabel:SetAlpha(enabled and 1 or 0.35) end
    if controls.precisionHint then controls.precisionHint:SetAlpha(enabled and 1 or 0.35) end
end

function RUI:SelectMover(mover)
    if type(mover) == "string" then mover = self:GetMover(mover) end
    if not mover then return false end

    if self.selectedMover and self.selectedMover.background then
        local r, g, b = self:GetAccentColor()
        self.selectedMover.background:SetTexture(r, g, b, 0.08)
    end

    self.selectedMover = mover
    if mover.background then
        local r, g, b = self:GetAccentColor()
        mover.background:SetTexture(r, g, b, 0.16)
    end
    self:UpdateMoverText(mover)
    self:RefreshSelectedMoverControls()
    return true
end

function RUI:NudgeSelectedMover(dx, dy)
    local mover = self.selectedMover
    if not mover or not self.moverMode then return false end

    local db = self:GetMoverDB(mover.id, mover.defaults)
    if not db then return false end

    local x, y = GetMoverPosition(mover)
    x = Round(x + (tonumber(dx) or 0))
    y = Round(y + (tonumber(dy) or 0))

    -- Precision nudges intentionally bypass snap. Dragging still obeys the
    -- configured grid, while these buttons provide exact 1px adjustment.
    db.point = "CENTER"
    db.relativePoint = "CENTER"
    db.x = x
    db.y = y

    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "CENTER", x, y)
    self:UpdateMoverText(mover)
    self:RefreshSelectedMoverControls()
    self:FireCallback("MOVER_MOVED", mover.id, x, y)
    return true
end

local function CreateMoverVisual(mover)
    local r, g, b = RUI:GetAccentColor()

    mover.background = mover:CreateTexture(nil, "BACKGROUND")
    mover.background:SetAllPoints(mover)
    mover.background:SetTexture(r, g, b, 0.08)

    mover.border = {}

    local top = mover:CreateTexture(nil, "BORDER")
    top:SetHeight(1)
    top:SetPoint("TOPLEFT", mover, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", mover, "TOPRIGHT", 0, 0)
    table.insert(mover.border, top)

    local bottom = mover:CreateTexture(nil, "BORDER")
    bottom:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT", mover, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", 0, 0)
    table.insert(mover.border, bottom)

    local left = mover:CreateTexture(nil, "BORDER")
    left:SetWidth(1)
    left:SetPoint("TOPLEFT", mover, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", mover, "BOTTOMLEFT", 0, 0)
    table.insert(mover.border, left)

    local right = mover:CreateTexture(nil, "BORDER")
    right:SetWidth(1)
    right:SetPoint("TOPRIGHT", mover, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", 0, 0)
    table.insert(mover.border, right)

    for i = 1, #mover.border do
        SetBorderTexture(mover.border[i], r, g, b, 1)
    end

    mover.title = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mover.title:SetPoint("TOPLEFT", mover, "TOPLEFT", 7, -6)
    mover.title:SetPoint("TOPRIGHT", mover, "TOPRIGHT", -7, -6)
    mover.title:SetJustifyH("LEFT")
    RUI:StyleFontString(mover.title, 9, 1, 1, 1)
    mover.title:SetText(mover.label)

    mover.coords = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mover.coords:SetPoint("TOPLEFT", mover.title, "BOTTOMLEFT", 0, -2)
    mover.coords:SetPoint("TOPRIGHT", mover, "TOPRIGHT", -7, -17)
    mover.coords:SetJustifyH("LEFT")
    RUI:StyleFontString(mover.coords, 8, 0.82, 0.84, 0.88)
    mover.coords:Hide()
end

function RUI:GetMover(id)
    return self.movers[id]
end

function RUI:GetMoverDB(id, defaultsForMover)
    if not self.db then
        return nil
    end

    self.db.movers = self.db.movers or {}

    if not self.db.movers[id] then
        self.db.movers[id] = CopyPosition(defaultsForMover or {})
    elseif not IsLockPoint(self.db.movers[id].lockPoint) then
        self.db.movers[id].lockPoint = IsLockPoint(defaultsForMover and defaultsForMover.lockPoint) and defaultsForMover.lockPoint or "TOPLEFT"
    end

    return self.db.movers[id]
end

function RUI:UpdateMoverText(mover)
    if not mover or not mover.coords then
        return
    end

    local x, y = GetMoverPosition(mover)
    mover.coords:SetText("X " .. Round(x) .. "   Y " .. Round(y))
    if self.selectedMover == mover then self:RefreshSelectedMoverControls() end
end

function RUI:ApplyMoverPosition(mover)
    if type(mover) == "string" then
        mover = self:GetMover(mover)
    end

    if not mover then
        return false
    end

    local db = self:GetMoverDB(mover.id, mover.defaults)
    if not db then
        return false
    end

    mover:ClearAllPoints()
    mover:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.x or 0, db.y or 0)
    self:ApplyMoverTargetAnchors(mover)
    self:UpdateMoverText(mover)
    return true
end

function RUI:SaveMoverPosition(mover)
    if type(mover) == "string" then
        mover = self:GetMover(mover)
    end

    if not mover then
        return false
    end

    local db = self:GetMoverDB(mover.id, mover.defaults)
    if not db then
        return false
    end

    local x, y = GetMoverPosition(mover)
    local layout = self.db and self.db.layout

    if layout and layout.snapEnabled then
        local snapSize = GetEffectiveSnapSpacing(layout)
        local halfW = (mover:GetWidth() or 0) / 2
        local halfH = (mover:GetHeight() or 0) / 2

        -- Magnetic edge snapping: choose the visible edge that is already
        -- closest to a grid line on each axis. The previous lock-corner rule
        -- could make the edge the player was actually lining up jump away from
        -- the grid simply because a different corner was selected.
        local left = x - halfW
        local right = x + halfW
        local leftShift = Snap(left, snapSize) - left
        local rightShift = Snap(right, snapSize) - right
        if math.abs(rightShift) < math.abs(leftShift) then
            x = x + rightShift
        else
            x = x + leftShift
        end

        local bottom = y - halfH
        local top = y + halfH
        local bottomShift = Snap(bottom, snapSize) - bottom
        local topShift = Snap(top, snapSize) - top
        if math.abs(topShift) < math.abs(bottomShift) then
            y = y + topShift
        else
            y = y + bottomShift
        end
    else
        x = Round(x)
        y = Round(y)
    end

    db.point = "CENTER"
    db.relativePoint = "CENTER"
    db.x = x
    db.y = y

    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "CENTER", x, y)
    self:UpdateMoverText(mover)
    self:FireCallback("MOVER_MOVED", mover.id, x, y)
    return true
end

-- Allow normal Zen panels to be dragged directly by their own exposed frame
-- chrome, while still saving through the same profile-aware mover database.
-- The invisible mover is temporarily shown at zero alpha only for the duration
-- of the drag, so direct dragging and /zenui mover mode remain one layout system.
function RUI:EnableDirectPanelDrag(frame, moverID)
    if not frame or not moverID or frame.RUIDirectMoverDragInstalled then return end
    frame.RUIDirectMoverDragInstalled = true
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        if RUI.moverMode then return end
        local mover = RUI:GetMover(moverID)
        if not mover or mover.enabled == false then return end
        self.RUIDirectMover = mover
        self.RUIDirectMoverWasShown = mover:IsShown() and true or false
        self.RUIDirectMoverOldAlpha = mover:GetAlpha()
        mover:SetAlpha(0)
        mover:Show()
        mover:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        local mover = self.RUIDirectMover
        if not mover then return end
        mover:StopMovingOrSizing()
        RUI:SaveMoverPosition(mover)
        mover:SetAlpha(self.RUIDirectMoverOldAlpha or 1)
        if not self.RUIDirectMoverWasShown and not RUI.moverMode then mover:Hide() end
        self.RUIDirectMover = nil
        self.RUIDirectMoverWasShown = nil
        self.RUIDirectMoverOldAlpha = nil
    end)
end

function RUI:RegisterMover(id, target, options)
    if type(id) ~= "string" or id == "" or not target then
        self:Print("RegisterMover requires an id and target frame.")
        return nil
    end

    if self.movers[id] then
        self:Print("Mover already registered: " .. id)
        return self.movers[id]
    end

    options = options or {}

    local safeName = string.gsub(id, "[^%w_]", "")
    if safeName == "" then
        safeName = "Mover" .. tostring(#self.moverOrder + 1)
    end

    local mover = CreateFrame("Frame", "ZenUIMover_" .. safeName, UIParent)
    mover.id = id
    mover.target = target
    mover.label = options.label or id
    mover.enabled = options.enabled ~= false
    mover.groups = CopyMoverGroups(options.groups) or CopyMoverGroups(options.group and { options.group } or nil) or CopyMoverGroups(DEFAULT_MOVER_GROUPS[id])
    mover.defaults = {
        point = options.point or "CENTER",
        relativePoint = options.relativePoint or "CENTER",
        x = options.x or 0,
        y = options.y or 0,
        lockPoint = IsLockPoint(options.lockPoint) and options.lockPoint or
            (IsLockPoint(options.targetPoint) and options.targetPoint or "TOPLEFT"),
    }
    mover.anchorTarget = options.anchorTarget ~= false
    mover.targetX = options.targetX or 0
    mover.targetY = options.targetY or 0

    local width = options.width or target:GetWidth() or 100
    local height = options.height or target:GetHeight() or 30
    if width <= 0 then width = 100 end
    if height <= 0 then height = 30 end

    mover:SetWidth(width)
    mover:SetHeight(height)
    mover:SetMovable(true)
    mover:SetClampedToScreen(true)
    mover:SetFrameStrata("TOOLTIP")
    mover:SetFrameLevel(500)
    mover:RegisterForDrag("LeftButton")
    mover:EnableMouse(false)

    CreateMoverVisual(mover)

    mover:SetScript("OnMouseDown", function(self, button)
        if RUI.moverMode and button == "LeftButton" then RUI:SelectMover(self) end
    end)

    mover:SetScript("OnEnter", function(self)
        if RUI.moverMode and self.coords then
            RUI:UpdateMoverText(self)
            self.coords:Show()
        end
    end)
    mover:SetScript("OnLeave", function(self)
        if self.coords and not self.dragging then self.coords:Hide() end
    end)

    mover:SetScript("OnDragStart", function(self)
        if not RUI.moverMode then
            return
        end

        RUI:SelectMover(self)
        self.dragging = true
        if self.coords then self.coords:Show() end
        self:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        if not self.dragging then
            return
        end

        self.dragging = false
        self:StopMovingOrSizing()
        RUI:SaveMoverPosition(self)
        if self.coords then self.coords:Hide() end
    end)

    mover:SetScript("OnUpdate", function(self)
        if self.dragging then
            RUI:UpdateMoverText(self)
        end
    end)

    self.movers[id] = mover
    table.insert(self.moverOrder, id)

    self:GetMoverDB(id, mover.defaults)
    self:ApplyMoverPosition(mover)

    if mover.anchorTarget then
        self:ApplyMoverTargetAnchors(mover)
    end

    if self.moverMode and mover.enabled and self:IsMoverInGroup(mover, self.moverGroup) then
        mover:EnableMouse(true)
        mover:Show()
    else
        mover:EnableMouse(false)
        mover:Hide()
    end

    self:Debug("Registered mover: " .. id)
    self:FireCallback("MOVER_REGISTERED", id, mover, target)
    return mover
end

function RUI:UpdateMoverSize(id, width, height)
    local mover = self:GetMover(id)
    if not mover then
        return false
    end

    if width and width > 0 then
        mover:SetWidth(width)
    end

    if height and height > 0 then
        mover:SetHeight(height)
    end

    return true
end

function RUI:SetMoverMode(enabled, group, returnPage, groupLabel)
    enabled = enabled and true or false

    if enabled and InCombatLockdown and InCombatLockdown() then
        self:Print("Mover mode cannot be enabled during combat.")
        return false
    end

    if enabled then
        self.moverGroup = (group and group ~= "" and group ~= "all") and group or nil
        self.moverReturnPage = returnPage or "LAYOUT"
        self.moverGroupLabel = groupLabel
    end
    self.moverMode = enabled

    for i = 1, #self.moverOrder do
        local mover = self.movers[self.moverOrder[i]]
        if mover then
            local visible = enabled and mover.enabled and self:IsMoverInGroup(mover, self.moverGroup)
            if visible then
                self:UpdateMoverText(mover)
                mover:EnableMouse(true)
                mover:Show()
            else
                if mover.dragging then
                    mover.dragging = false
                    mover:StopMovingOrSizing()
                    self:SaveMoverPosition(mover)
                end
                mover:EnableMouse(false)
                mover:Hide()
            end
        end
    end

    if enabled then
        local controls = self:CreateMoverControlWindow()
        self:RefreshMoverControlWindow()
        controls:Show()
        self:CreateAlignmentGrid()
        self:RefreshAlignmentGrid()

        local layout = self.db and self.db.layout
        local snapText = "off"
        if layout and layout.snapEnabled then
            local spacing, gridPriority = GetEffectiveSnapSpacing(layout)
            if gridPriority then
                snapText = tostring(spacing) .. "px visible grid"
            else
                snapText = tostring(layout.snapSize or 4) .. "px"
            end
        end
        local scopeText = self.moverGroupLabel and (" for " .. self.moverGroupLabel) or " for all panels"
        self:Print("Mover mode enabled" .. scopeText .. ". Grid snap: " .. snapText .. ".")
    else
        if self.selectedMover and self.selectedMover.background then
            local r, g, b = self:GetAccentColor()
            self.selectedMover.background:SetTexture(r, g, b, 0.08)
        end
        self.selectedMover = nil
        if self.moverControls then self.moverControls:Hide() end
        if self.alignmentGrid then self.alignmentGrid:Hide() end
        self:Print("Mover mode disabled. Layout positions saved.")
        self.moverGroup = nil
        self.moverReturnPage = nil
        self.moverGroupLabel = nil
    end

    self:FireCallback("MOVER_MODE_CHANGED", enabled)
    return true
end

function RUI:SetMoverEnabled(id, enabled)
    local mover = self:GetMover(id)
    if not mover then
        return false
    end

    mover.enabled = enabled and true or false
    if mover.enabled and self.moverMode and self:IsMoverInGroup(mover, self.moverGroup) then
        self:UpdateMoverText(mover)
        mover:EnableMouse(true)
        mover:Show()
    else
        mover:EnableMouse(false)
        mover:Hide()
    end

    return true
end

function RUI:ToggleMoverMode()
    self:SetMoverMode(not self.moverMode)
end

function RUI:ResetMover(id)
    local mover = self:GetMover(id)
    if not mover then
        return false
    end

    self.db.movers[id] = CopyPosition(mover.defaults)
    self:ApplyMoverPosition(mover)
    self:FireCallback("MOVER_RESET", id)
    return true
end

function RUI:ResetAllMovers()
    for i = 1, #self.moverOrder do
        local id = self.moverOrder[i]
        local mover = self.movers[id]
        if mover then
            self.db.movers[id] = CopyPosition(mover.defaults)
            self:ApplyMoverPosition(mover)
        end
    end

    self:FireCallback("MOVERS_RESET")
end

function RUI:ApplyAllMovers()
    for i = 1, #self.moverOrder do
        local mover = self.movers[self.moverOrder[i]]
        if mover then
            self:GetMoverDB(mover.id, mover.defaults)
            self:ApplyMoverPosition(mover)
        end
    end
end

function RUI:SetSnapEnabled(enabled)
    if not self.db or not self.db.layout then
        return
    end

    self.db.layout.snapEnabled = enabled and true or false
    self:RefreshMoverControlWindow()
    self:FireCallback("LAYOUT_SNAP_CHANGED", self.db.layout.snapEnabled, self.db.layout.snapSize or 4)
end

function RUI:SetSnapSize(size)
    if not self.db or not self.db.layout then
        return false
    end

    size = tonumber(size)
    if not size then
        return false
    end

    size = math.floor(size + 0.5)
    if size < 1 then size = 1 end
    if size > 64 then size = 64 end

    self.db.layout.snapSize = size
    self.db.layout.snapEnabled = true
    self:RefreshMoverControlWindow()
    if self.moverMode and self.db.layout.showGrid then self:RefreshAlignmentGrid() end
    self:FireCallback("LAYOUT_SNAP_CHANGED", true, size)
    return true
end

function RUI:RefreshMoverAppearance()
    local r, g, b = self:GetAccentColor()

    for i = 1, #self.moverOrder do
        local mover = self.movers[self.moverOrder[i]]
        if mover then
            if mover.background then
                mover.background:SetTexture(r, g, b, self.selectedMover == mover and 0.16 or 0.08)
            end
            if mover.border then
                for _, texture in pairs(mover.border) do
                    texture:SetTexture(r, g, b, 1)
                end
            end
            if mover.title then
                self:StyleFontString(mover.title, 11, 1, 1, 1)
            end
            if mover.coords then
                self:StyleFontString(mover.coords, 9, 0.82, 0.84, 0.88)
            end
        end
    end

    if self.moverControls then
        self:RefreshMoverControlWindow()
    end
    if self.alignmentGrid and self.alignmentGrid:IsShown() then
        self:RefreshAlignmentGrid()
    end
end

RUI:RegisterCallback("APPEARANCE_CHANGED", RUI, "RefreshMoverAppearance")

RUI:RegisterCallback("PROFILE_RESET", RUI, "ApplyAllMovers")
