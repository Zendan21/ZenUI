-- ZenUI 0.5.1 minimap shell.
-- Reuses the native 3.3.5 Minimap while owning layout, chrome, text overlays,
-- native indicator placement and optional third-party minimap-button collection.

local RUI = ZenUI
local MinimapModule = RUI:NewModule("Minimap")

local NATIVE_ART = {
    "MinimapBorder",
    "MinimapBorderTop",
    "MinimapNorthTag",
    "MinimapCompassTexture",
}

local NATIVE_FRAME_NAMES = {
    "Minimap",
    "MinimapCluster",
    "MinimapBackdrop",
    "MinimapZoneTextButton",
    "MinimapZoomIn",
    "MinimapZoomOut",
    "MiniMapWorldMapButton",
    "MiniMapTracking",
    "MiniMapTrackingButton",
    "MiniMapMailFrame",
    "MiniMapBattlefieldFrame",
    "MiniMapLFGFrame",
    "MiniMapRecordingButton",
    "MiniMapInstanceDifficulty",
    "TimeManagerClockButton",
    "GameTimeFrame",
}

local function SetMouse(frame, enabled)
    if frame and frame.EnableMouse then
        frame:EnableMouse(enabled and true or false)
    end
end

local function SetConfiguredVisible(frame, visible)
    if not frame then return end
    frame:SetAlpha(visible and 1 or 0)
    SetMouse(frame, visible)
end

local function CreateText(parent, text, size, point, relativePoint, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint(point, parent, relativePoint or point, x or 0, y or 0)
    RUI:StyleFontString(fs, size or 9)
    fs:SetText(text or "")
    return fs
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then value = minimum end
    if value > maximum then value = maximum end
    return value
end

local function SafeGetName(frame)
    if not frame or not frame.GetName then return nil end
    local ok, name = pcall(frame.GetName, frame)
    if ok then return name end
    return nil
end

local function IsFrameProtected(frame)
    if not frame or not frame.IsProtected then return false end
    local ok, value = pcall(frame.IsProtected, frame)
    return ok and value and true or false
end

function MinimapModule:GetSettings()
    return RUI.db and RUI.db.minimap
end

function MinimapModule:CaptureFrameState(frame)
    if not frame then return end
    self.nativeState = self.nativeState or {}
    if self.nativeState[frame] then return end

    local state = {
        parent = frame.GetParent and frame:GetParent() or nil,
        scale = frame.GetScale and frame:GetScale() or 1,
        alpha = frame.GetAlpha and frame:GetAlpha() or 1,
        points = {},
    }

    if frame.IsMouseEnabled then
        local ok, enabled = pcall(frame.IsMouseEnabled, frame)
        if ok then state.mouse = enabled and true or false end
    end

    if frame.GetNumPoints and frame.GetPoint then
        local count = frame:GetNumPoints() or 0
        for i = 1, count do
            local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
            state.points[#state.points + 1] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y,
            }
        end
    end

    self.nativeState[frame] = state
end

function MinimapModule:RestoreFrameState(frame)
    if not frame or not self.nativeState then return end
    local state = self.nativeState[frame]
    if not state then return end

    if frame.SetParent and state.parent then frame:SetParent(state.parent) end
    if frame.ClearAllPoints then frame:ClearAllPoints() end
    if frame.SetPoint then
        for i = 1, #state.points do
            local p = state.points[i]
            frame:SetPoint(p.point, p.relativeTo, p.relativePoint, p.x, p.y)
        end
    end
    if frame.SetScale then frame:SetScale(state.scale or 1) end
    if frame.SetAlpha then frame:SetAlpha(state.alpha or 1) end
    if state.mouse ~= nil then SetMouse(frame, state.mouse) end
end

function MinimapModule:CaptureNativeIndicatorStates()
    local frames = {
        MinimapZoomIn,
        MinimapZoomOut,
        MiniMapWorldMapButton,
        MiniMapTracking,
        MiniMapTrackingButton,
        MiniMapMailFrame,
        MiniMapLFGFrame,
        MiniMapBattlefieldFrame,
        MiniMapInstanceDifficulty,
    }
    for i = 1, #frames do
        self:CaptureFrameState(frames[i])
    end
end

function MinimapModule:RestoreNativeIndicators()
    if not self.nativeState then return end
    local frames = {
        MinimapZoomIn,
        MinimapZoomOut,
        MiniMapWorldMapButton,
        MiniMapTracking,
        MiniMapTrackingButton,
        MiniMapMailFrame,
        MiniMapLFGFrame,
        MiniMapBattlefieldFrame,
        MiniMapInstanceDifficulty,
    }
    for i = 1, #frames do
        self:RestoreFrameState(frames[i])
    end
end

function MinimapModule:CreateHolder()
    local holder = CreateFrame("Frame", "ZenUIMinimapHolder", UIParent)
    holder:SetWidth(184)
    holder:SetHeight(184)
    holder:SetFrameStrata("LOW")
    holder:SetFrameLevel(4)
    holder:EnableMouse(false)
    RUI:CreateBackdrop(holder)
    holder.accent = RUI:CreateAccentLine(holder, 2)

    -- Minimap is a child frame, so text placed directly on holder can render below it.
    -- Keep all custom text on a dedicated higher-level overlay.
    local overlay = CreateFrame("Frame", "ZenUIMinimapOverlay", holder)
    overlay:SetAllPoints(holder)
    overlay:SetFrameStrata("LOW")
    overlay:SetFrameLevel(holder:GetFrameLevel() + 30)
    overlay:EnableMouse(false)
    holder.overlay = overlay

    holder.zone = CreateText(overlay, "", 11, "TOPLEFT", "TOPLEFT", 7, -7)
    holder.zone:SetJustifyH("LEFT")
    holder.zone:SetWidth(120)
    holder.zone:SetHeight(15)

    -- Raid context sits directly beneath the zone title. It is Zen-owned text
    -- rather than Blizzard's difficulty badge so the actual group size and
    -- heroic state are readable at a glance (10 / 10h / 25 / 25h).
    holder.raidIdentifier = CreateText(overlay, "", 10, "TOPLEFT", "TOPLEFT", 7, -20)
    holder.raidIdentifier:SetJustifyH("LEFT")
    holder.raidIdentifier:SetWidth(72)
    holder.raidIdentifier:SetHeight(13)
    holder.raidIdentifier:Hide()

    holder.clock = CreateText(overlay, "", 11, "TOPRIGHT", "TOPRIGHT", -7, -7)
    holder.clock:SetJustifyH("RIGHT")
    holder.clock:SetWidth(72)
    holder.clock:SetHeight(15)

    self.holder = holder

    RUI:RegisterMover("Minimap", holder, {
        label = "Minimap",
        width = 184,
        height = 184,
        point = "TOPRIGHT",
        relativePoint = "TOPRIGHT",
        x = -24,
        y = -24,
    })
end

function MinimapModule:CreateCollector()
    if not self.holder then return end

    local button = CreateFrame("Button", "ZenUIMinimapButtonCollector", self.holder)
    button:SetWidth(24)
    button:SetHeight(22)
    button:SetPoint("BOTTOMRIGHT", self.holder, "BOTTOMRIGHT", -4, 4)
    button:SetFrameStrata("LOW")
    button:SetFrameLevel(self.holder:GetFrameLevel() + 45)
    button.RUIText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.RUIText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.RUIText:SetText("A")
    RUI:StyleButton(button)

    button.count = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.count:SetPoint("TOPRIGHT", button, "TOPRIGHT", 4, 4)
    RUI:StyleFontString(button.count, 8)
    button.count:SetText("")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            MinimapModule:ScanAddonButtons(true)
        else
            MinimapModule:SetCollectorOpen(not MinimapModule.collectorOpen)
        end
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.collectorButton = button

    local dock = CreateFrame("Frame", "ZenUIMinimapButtonDock", self.holder)
    dock:SetWidth(42)
    dock:SetHeight(42)
    dock:SetPoint("TOPRIGHT", self.holder, "TOPLEFT", -6, 0)
    dock:SetFrameStrata("LOW")
    dock:SetFrameLevel(self.holder:GetFrameLevel() + 40)
    dock:EnableMouse(true)
    RUI:CreateBackdrop(dock)
    dock.accent = RUI:CreateAccentLine(dock, 2)
    dock:Hide()
    self.collectorDock = dock

    self.collectedButtons = {}
    self.collectedOrder = {}
    self.collectorOpen = false
end

function MinimapModule:BuildNativeReferenceSet()
    local refs = {}
    for i = 1, #NATIVE_FRAME_NAMES do
        local frame = _G[NATIVE_FRAME_NAMES[i]]
        if frame then refs[frame] = true end
    end
    if self.holder then refs[self.holder] = true end
    if self.holder and self.holder.overlay then refs[self.holder.overlay] = true end
    if self.collectorButton then refs[self.collectorButton] = true end
    if self.collectorDock then refs[self.collectorDock] = true end
    return refs
end

function MinimapModule:IsMinimapRelatedFrame(frame)
    if not frame or not frame.GetParent then return false end
    local parent = frame:GetParent()
    if parent == Minimap or parent == MinimapCluster or parent == MinimapBackdrop then
        return true
    end

    if frame.GetNumPoints and frame.GetPoint then
        local count = frame:GetNumPoints() or 0
        for i = 1, count do
            local _, relativeTo = frame:GetPoint(i)
            if relativeTo == Minimap or relativeTo == MinimapCluster or relativeTo == MinimapBackdrop then
                return true
            end
        end
    end
    return false
end

function MinimapModule:IsCollectibleButton(frame, nativeRefs)
    if not frame or nativeRefs[frame] or self.collectedButtons[frame] then return false end
    if frame.ZenNoMinimapCollect == true then return false end
    if IsFrameProtected(frame) then return false end

    local name = SafeGetName(frame)
    if name and string.find(name, "^ZenUI") then return false end

    -- Only collect actual launcher controls.  Earlier builds also accepted any
    -- small clickable Frame; on Ebonhold that catches a large number of helper
    --/overlay frames whose children live far outside their nominal bounds. Once
    -- reparented into the dock those helpers become visible and create the huge
    -- empty/scattered collector seen in Phase-D testing.
    local objectType = frame.GetObjectType and frame:GetObjectType() or ""
    if objectType ~= "Button" and objectType ~= "CheckButton" then return false end

    local width = frame.GetWidth and (frame:GetWidth() or 0) or 0
    local height = frame.GetHeight and (frame:GetHeight() or 0) or 0
    if width < 8 or height < 8 or width > 80 or height > 80 then return false end

    -- IsShown() ignores hidden parents.  That meant buttons belonging to hidden
    -- addon panels could be captured and then suddenly become visible when we
    -- reparented them into Zen's dock. Require genuine on-screen visibility
    -- at discovery time instead.
    if frame.IsVisible then
        local ok, visible = pcall(frame.IsVisible, frame)
        if ok and not visible then return false end
    elseif frame.IsShown then
        local ok, shown = pcall(frame.IsShown, frame)
        if ok and not shown then return false end
    end
    if frame.GetAlpha then
        local ok, alpha = pcall(frame.GetAlpha, frame)
        if ok and tonumber(alpha) and tonumber(alpha) <= 0.05 then return false end
    end

    return self:IsMinimapRelatedFrame(frame)
end

function MinimapModule:CaptureAddonButton(frame)
    if not frame or self.collectedButtons[frame] then return false end

    local data = {
        frame = frame,
        name = SafeGetName(frame) or tostring(frame),
        parent = frame.GetParent and frame:GetParent() or nil,
        scale = frame.GetScale and frame:GetScale() or 1,
        points = {},
    }

    if frame.GetNumPoints and frame.GetPoint then
        local count = frame:GetNumPoints() or 0
        for i = 1, count do
            local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
            data.points[#data.points + 1] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y,
            }
        end
    end

    self.collectedButtons[frame] = data
    self.collectedOrder[#self.collectedOrder + 1] = frame
    return true
end

function MinimapModule:RestoreCollectedButton(frame)
    local data = self.collectedButtons and self.collectedButtons[frame]
    if not data or not frame then return end

    if frame.SetParent and data.parent then frame:SetParent(data.parent) end
    if frame.ClearAllPoints then frame:ClearAllPoints() end
    if frame.SetPoint then
        for i = 1, #data.points do
            local p = data.points[i]
            frame:SetPoint(p.point, p.relativeTo, p.relativePoint, p.x, p.y)
        end
    end
    if frame.SetScale then frame:SetScale(data.scale or 1) end
end

function MinimapModule:RestoreAllCollectedButtons()
    if not self.collectedOrder then return end
    for i = 1, #self.collectedOrder do
        self:RestoreCollectedButton(self.collectedOrder[i])
    end
    self.collectedButtons = {}
    self.collectedOrder = {}
    if self.collectorDock then self.collectorDock:Hide() end
    self.collectorOpen = false
    self:UpdateCollectorButton()
end

function MinimapModule:GetCollectedCount()
    return self.collectedOrder and #self.collectedOrder or 0
end

function MinimapModule:UpdateCollectorButton()
    if not self.collectorButton then return end
    local settings = self:GetSettings() or {}
    local count = self:GetCollectedCount()
    local enabled = settings.collectAddonButtons ~= false

    if enabled then self.collectorButton:Show() else self.collectorButton:Hide() end
    self.collectorButton.count:SetText(count > 0 and tostring(count) or "")

    if count > 0 then
        local r, g, b = RUI:GetAccentColor()
        RUI:StyleFontString(self.collectorButton.RUIText, 10, r, g, b)
    else
        local r, g, b = RUI:GetTextColor(true)
        RUI:StyleFontString(self.collectorButton.RUIText, 10, r, g, b)
    end
end

function MinimapModule:LayoutCollector()
    if not self.collectorDock or not self.collectedOrder then return end
    local settings = self:GetSettings() or {}
    local columns = math.floor(Clamp(settings.collectorColumns or 4, 1, 8) + 0.5)
    local target = 28
    local spacing = 4
    local pad = 6
    local visible = {}
    local retained = {}

    for i = 1, #self.collectedOrder do
        local frame = self.collectedOrder[i]
        -- A launcher can deliberately move away from the minimap after ZenUI
        -- has already collected it (ZenMenu's Minimap -> Floating switch is
        -- the main example). Forget it without restoring the old minimap point;
        -- the owner addon has already applied its new parent/position.
        if frame and frame.ZenNoMinimapCollect == true then
            self.collectedButtons[frame] = nil
        elseif frame then
            retained[#retained + 1] = frame
            if frame.IsShown and frame:IsShown() then
                visible[#visible + 1] = frame
            end
        end
    end
    self.collectedOrder = retained

    local count = #visible
    if count == 0 then
        self.collectorDock:SetWidth((target)+(pad*2))
        self.collectorDock:SetHeight((target)+(pad*2))
        self.collectorDock:Hide()
        return
    end

    -- Size from the controls that are actually participating in this layout,
    -- never from the number of frames discovered historically.  This keeps the
    -- A-menu compact even when addons dynamically hide their minimap launchers.
    local usedColumns = math.min(columns, count)
    local rows = math.ceil(count / usedColumns)
    local width = (usedColumns * target) + ((usedColumns - 1) * spacing) + (pad * 2)
    local height = (rows * target) + ((rows - 1) * spacing) + (pad * 2)
    self.collectorDock:SetWidth(width)
    self.collectorDock:SetHeight(height)

    for i = 1, count do
        local frame = visible[i]
        local data = self.collectedButtons[frame]
        if frame.SetParent then frame:SetParent(self.collectorDock) end
        if frame.ClearAllPoints then frame:ClearAllPoints() end

        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        frame:SetPoint("TOPLEFT", self.collectorDock, "TOPLEFT", pad + (col * (target + spacing)), -pad - (row * (target + spacing)))

        local widthNow = frame.GetWidth and (frame:GetWidth() or target) or target
        local heightNow = frame.GetHeight and (frame:GetHeight() or target) or target
        local maxSize = math.max(widthNow, heightNow, 1)
        if frame.SetScale then frame:SetScale(target / maxSize) end

        -- Reparent/anchor every scan: some addons periodically try to restore their radial minimap point.
        if data then data.docked = true end
    end

    if self.collectorOpen and count > 0 then
        self.collectorDock:Show()
    else
        self.collectorDock:Hide()
    end
end

function MinimapModule:SetCollectorOpen(open)
    local settings = self:GetSettings() or {}
    if settings.collectAddonButtons == false then open = false end
    if self:GetCollectedCount() == 0 then open = false end
    self.collectorOpen = open and true or false
    self:LayoutCollector()
end

function MinimapModule:ScanAddonButtons(force)
    local settings = self:GetSettings() or {}
    if settings.enabled == false or settings.collectAddonButtons == false then
        return
    end

    local nativeRefs = self:BuildNativeReferenceSet()
    local seen = {}
    local candidates = {}

    local function AddChildren(parent)
        if not parent or not parent.GetChildren then return end
        local children = { parent:GetChildren() }
        for i = 1, #children do
            local frame = children[i]
            if frame and not seen[frame] then
                seen[frame] = true
                candidates[#candidates + 1] = frame
            end
        end
    end

    AddChildren(Minimap)
    AddChildren(MinimapCluster)
    AddChildren(MinimapBackdrop)

    -- UIParent can contain hundreds or thousands of frames on a full UI.
    -- Scanning it on a permanent timer caused visible periodic hitches. Do the
    -- broad discovery only once after addon loading (or on a manual forced
    -- scan); routine maintenance scans stay local to the minimap hierarchy.
    if force or not self.uiParentScanComplete then
        AddChildren(UIParent)
        self.uiParentScanComplete = true
    end

    local added = 0
    for i = 1, #candidates do
        local frame = candidates[i]
        if self:IsCollectibleButton(frame, nativeRefs) then
            if self:CaptureAddonButton(frame) then added = added + 1 end
        end
    end

    table.sort(self.collectedOrder, function(a, b)
        local ad = self.collectedButtons[a]
        local bd = self.collectedButtons[b]
        return tostring(ad and ad.name or a) < tostring(bd and bd.name or b)
    end)

    self:LayoutCollector()
    self:UpdateCollectorButton()
    if force then
        RUI:Print("Minimap button scan: " .. tostring(self:GetCollectedCount()) .. " addon button(s) collected.")
    end
end

function MinimapModule:InstallMinimap()
    if not Minimap or not self.holder then return end

    if not self.original then
        local point, relativeTo, relativePoint, x, y = Minimap:GetPoint(1)
        self.original = {
            parent = Minimap:GetParent(),
            point = point or "CENTER",
            relativeTo = relativeTo or MinimapCluster,
            relativePoint = relativePoint or "TOP",
            x = x or 9,
            y = y or -92,
            width = Minimap:GetWidth() or 140,
            height = Minimap:GetHeight() or 140,
            scale = Minimap:GetScale() or 1,
        }
    end

    self:CaptureNativeIndicatorStates()

    Minimap:SetParent(self.holder)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPLEFT", self.holder, "TOPLEFT", 3, -3)
    Minimap:SetFrameLevel(self.holder:GetFrameLevel() + 5)
    Minimap:SetScale(1)

    if Minimap.SetMaskTexture then
        Minimap:SetMaskTexture(RUI.Media.textures.white)
    end

    Minimap:EnableMouseWheel(true)
    if not self.mouseWheelInstalled then
        self.mouseWheelInstalled = true
        Minimap:SetScript("OnMouseWheel", function(_, delta)
            local settings = RUI.db and RUI.db.minimap
            if not settings or settings.mouseWheelZoom == false then return end
            local zoom = Minimap:GetZoom() or 0
            if delta > 0 then zoom = zoom + 1 else zoom = zoom - 1 end
            if zoom < 0 then zoom = 0 end
            if zoom > 5 then zoom = 5 end
            Minimap:SetZoom(zoom)
        end)
    end
end

function MinimapModule:RestoreNative()
    self:RestoreAllCollectedButtons()
    self:RestoreNativeIndicators()

    if not Minimap then return end
    local original = self.original
    Minimap:SetParent((original and original.parent) or MinimapCluster or UIParent)
    Minimap:ClearAllPoints()
    if original then
        Minimap:SetPoint(original.point, original.relativeTo, original.relativePoint, original.x, original.y)
        Minimap:SetWidth(original.width)
        Minimap:SetHeight(original.height)
        Minimap:SetScale(original.scale or 1)
    else
        Minimap:SetPoint("CENTER", MinimapCluster, "TOP", 9, -92)
        Minimap:SetWidth(140)
        Minimap:SetHeight(140)
    end
    if Minimap.SetMaskTexture then Minimap:SetMaskTexture("Textures\\MinimapMask") end
end

function MinimapModule:ApplyNativeChrome(settings)
    local enabled = settings and settings.enabled ~= false
    if MinimapCluster and MinimapCluster.EnableMouse then MinimapCluster:EnableMouse(not enabled) end

    for i = 1, #NATIVE_ART do
        local frame = _G[NATIVE_ART[i]]
        if frame then frame:SetAlpha(enabled and 0 or 1) end
    end

    if MinimapZoneTextButton then SetConfiguredVisible(MinimapZoneTextButton, not enabled) end
    if TimeManagerClockButton then SetConfiguredVisible(TimeManagerClockButton, not enabled) end
    if GameTimeFrame then SetConfiguredVisible(GameTimeFrame, not enabled) end

    if MinimapZoomIn then SetConfiguredVisible(MinimapZoomIn, not enabled or settings.showZoomButtons == true) end
    if MinimapZoomOut then SetConfiguredVisible(MinimapZoomOut, not enabled or settings.showZoomButtons == true) end
    if MiniMapWorldMapButton then SetConfiguredVisible(MiniMapWorldMapButton, not enabled or settings.showWorldMapButton == true) end
end

function MinimapModule:PositionNativeIndicators(settings)
    if not self.holder then return end
    self:CaptureNativeIndicatorStates()

    if MiniMapTracking then
        MiniMapTracking:ClearAllPoints()
        -- Leave the second title line clear while a raid identifier is visible.
        -- Outside raids the native tracking button keeps its original Zen position.
        local trackingY = self.raidIdentifierVisible and -36 or -22
        MiniMapTracking:SetPoint("TOPLEFT", self.holder, "TOPLEFT", 4, trackingY)
        MiniMapTracking:SetScale(0.72)
        SetConfiguredVisible(MiniMapTracking, settings.showTracking ~= false)
        if MiniMapTrackingButton then SetMouse(MiniMapTrackingButton, settings.showTracking ~= false) end
    end

    if MiniMapMailFrame then
        MiniMapMailFrame:ClearAllPoints()
        MiniMapMailFrame:SetPoint("TOPRIGHT", self.holder, "TOPRIGHT", 2, -20)
        MiniMapMailFrame:SetScale(0.72)
        -- Blizzard owns Show/Hide according to pending mail; Zen only suppresses by alpha/mouse.
        SetConfiguredVisible(MiniMapMailFrame, settings.showMail ~= false)
    end

    if MiniMapLFGFrame then
        MiniMapLFGFrame:ClearAllPoints()
        MiniMapLFGFrame:SetPoint("BOTTOMLEFT", self.holder, "BOTTOMLEFT", 2, 2)
        MiniMapLFGFrame:SetScale(0.72)
        SetConfiguredVisible(MiniMapLFGFrame, settings.showLFG ~= false)
    end

    if MiniMapBattlefieldFrame then
        MiniMapBattlefieldFrame:ClearAllPoints()
        MiniMapBattlefieldFrame:SetPoint("BOTTOMLEFT", self.holder, "BOTTOMLEFT", 26, 2)
        MiniMapBattlefieldFrame:SetScale(0.72)
        SetConfiguredVisible(MiniMapBattlefieldFrame, settings.showBattlefield ~= false)
    end

    if MiniMapInstanceDifficulty then
        MiniMapInstanceDifficulty:ClearAllPoints()
        MiniMapInstanceDifficulty:SetPoint("TOPRIGHT", self.holder, "TOPRIGHT", -18, -20)
        MiniMapInstanceDifficulty:SetScale(0.72)
        SetConfiguredVisible(MiniMapInstanceDifficulty, settings.showDifficulty ~= false)
    end

    -- Put optional native utility buttons at predictable Zen positions.
    if MinimapZoomIn then
        MinimapZoomIn:ClearAllPoints()
        MinimapZoomIn:SetPoint("BOTTOMRIGHT", self.holder, "BOTTOMRIGHT", -54, 4)
        MinimapZoomIn:SetScale(0.72)
    end
    if MinimapZoomOut then
        MinimapZoomOut:ClearAllPoints()
        MinimapZoomOut:SetPoint("BOTTOMRIGHT", self.holder, "BOTTOMRIGHT", -30, 4)
        MinimapZoomOut:SetScale(0.72)
    end
    if MiniMapWorldMapButton then
        MiniMapWorldMapButton:ClearAllPoints()
        MiniMapWorldMapButton:SetPoint("TOPRIGHT", self.holder, "TOPRIGHT", -44, -20)
        MiniMapWorldMapButton:SetScale(0.72)
    end

    -- Remove bulky rings around native indicator icons where globals exist.
    local rings = {
        MiniMapTrackingButtonBorder,
        MiniMapMailBorder,
        MiniMapLFGFrameBorder,
        MiniMapBattlefieldBorder,
        MiniMapWorldBorder,
    }
    for i = 1, #rings do
        if rings[i] then rings[i]:SetAlpha(0) end
    end
end

function MinimapModule:UpdateZone()
    if not self.holder then return end
    local settings = self:GetSettings() or {}
    if settings.showZone == false then
        self.holder.zone:SetText("")
        return
    end

    local zone = ""
    if GetMinimapZoneText then zone = GetMinimapZoneText() or "" end
    if zone == "" and GetZoneText then zone = GetZoneText() or "" end
    self.holder.zone:SetText(zone)
end

function MinimapModule:GetRaidIdentifierText()
    if not GetInstanceInfo then return nil end

    -- Private-server implementations occasionally return incomplete instance
    -- information for a frame during a zone transition. Keep this cosmetic
    -- feature isolated from the rest of the minimap if that happens.
    local ok, _, instanceType, difficultyID, difficultyName, maxPlayers = pcall(GetInstanceInfo)
    if not ok or tostring(instanceType or "") ~= "raid" then return nil end

    difficultyID = tonumber(difficultyID)
    maxPlayers = tonumber(maxPlayers)
    difficultyName = tostring(difficultyName or "")

    local size = maxPlayers and maxPlayers > 0 and maxPlayers or nil
    if not size then
        local parsed = string.match(difficultyName, "(%d+)")
        parsed = tonumber(parsed)
        if parsed and parsed >= 10 then size = parsed end
    end

    -- Wrath difficulty IDs: 3/5 = 10 player, 4/6 = 25 player. The max-player
    -- value above remains authoritative; these are only a fallback for Ebonhold
    -- packets that briefly omit it.
    if not size then
        if difficultyID == 3 or difficultyID == 5 then
            size = 10
        elseif difficultyID == 4 or difficultyID == 6 then
            size = 25
        end
    end
    if not size then return nil end

    local lowered = string.lower(difficultyName)
    local heroic = string.find(lowered, "heroic", 1, true) ~= nil
    if not heroic and (difficultyID == 5 or difficultyID == 6) then heroic = true end

    return tostring(size) .. (heroic and "h" or "")
end

function MinimapModule:UpdateRaidIdentifier()
    if not self.holder or not self.holder.raidIdentifier then return end
    local settings = self:GetSettings() or {}
    if settings.showRaidIdentifier == false then
        self.holder.raidIdentifier:SetText("")
        self.holder.raidIdentifier:Hide()
        self.raidIdentifierVisible = false
        return
    end

    local text = self:GetRaidIdentifierText()
    if not text or text == "" then
        self.holder.raidIdentifier:SetText("")
        self.holder.raidIdentifier:Hide()
        self.raidIdentifierVisible = false
        return
    end

    -- If zone text is disabled, promote the identifier to the first title line
    -- instead of leaving an unexplained blank line above it.
    self.holder.raidIdentifier:ClearAllPoints()
    self.holder.raidIdentifier:SetPoint("TOPLEFT", self.holder.overlay, "TOPLEFT", 7, settings.showZone == false and -7 or -20)
    self.holder.raidIdentifier:SetText(text)
    self.holder.raidIdentifier:Show()
    self.raidIdentifierVisible = true
end

function MinimapModule:GetClockTime()
    local h, m
    if GetGameTime then
        h, m = GetGameTime()
        h, m = tonumber(h), tonumber(m)
    end

    -- Some private-server cores can briefly return nil/invalid server time during login.
    if not h or not m or h < 0 or h > 23 or m < 0 or m > 59 then
        if date then
            h = tonumber(date("%H")) or 0
            m = tonumber(date("%M")) or 0
        else
            h, m = 0, 0
        end
    end

    local settings = self:GetSettings() or {}
    local offset = tonumber(settings.clockOffsetMinutes) or 0
    if offset ~= 0 then
        local total = ((h * 60) + m + offset) % 1440
        if total < 0 then total = total + 1440 end
        h = math.floor(total / 60)
        m = total % 60
    end
    return h, m
end

function MinimapModule:UpdateClock()
    if not self.holder then return end
    local settings = self:GetSettings() or {}
    if settings.showClock == false then
        self.holder.clock:SetText("")
        return
    end

    local h, m = self:GetClockTime()
    if settings.clock24 == false then
        local suffix = h >= 12 and "p" or "a"
        local display = h % 12
        if display == 0 then display = 12 end
        self.holder.clock:SetText(string.format("%d:%02d%s", display, m, suffix))
    else
        self.holder.clock:SetText(string.format("%02d:%02d", h, m))
    end
end

function MinimapModule:RefreshAppearance()
    if not self.holder then return end
    local scale = RUI:GetEffectiveScale("minimap")
    self.holder:SetScale(scale)
    RUI:UpdateMoverSize("Minimap", (self.holder:GetWidth() or 184) * scale, (self.holder:GetHeight() or 184) * scale)
    RUI:RefreshBackdrop(self.holder)
    RUI:SetAccentTexture(self.holder.accent)

    if self.collectorDock then
        RUI:RefreshBackdrop(self.collectorDock)
        RUI:SetAccentTexture(self.collectorDock.accent)
    end
    if self.collectorButton then RUI:RefreshBackdrop(self.collectorButton) end

    local r, g, b = RUI:GetTextColor(false)
    RUI:StyleFontString(self.holder.zone, 11, r, g, b)
    local ar, ag, ab = RUI:GetAccentColor()
    if self.holder.raidIdentifier then RUI:StyleFontString(self.holder.raidIdentifier, 10, ar, ag, ab) end
    RUI:StyleFontString(self.holder.clock, 11, ar, ag, ab)
    if self.collectorButton and self.collectorButton.count then
        RUI:StyleFontString(self.collectorButton.count, 8, ar, ag, ab)
    end
    self:UpdateCollectorButton()
end

function MinimapModule:ApplySettings()
    local settings = self:GetSettings()
    if not settings or not self.holder then return end

    if settings.enabled == false then
        self.holder:Hide()
        RUI:SetMoverEnabled("Minimap", false)
        self:RestoreNative()
        self:ApplyNativeChrome(settings)
        return
    end

    self:InstallMinimap()
    self.holder:Show()

    local size = Clamp(settings.size or 180, 120, 260)
    local outer = size + 6
    self.holder:SetWidth(outer)
    self.holder:SetHeight(outer)
    Minimap:SetWidth(size)
    Minimap:SetHeight(size)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPLEFT", self.holder, "TOPLEFT", 3, -3)

    -- Text widths track the real minimap width so long zones do not collide with the clock.
    self.holder.zone:SetWidth(math.max(56, size - 88))
    self.holder.zone:SetHeight(15)
    self.holder.clock:SetWidth(72)
    self.holder.clock:SetHeight(15)

    if settings.showZone ~= false then self.holder.zone:Show() else self.holder.zone:Hide() end
    if settings.showClock ~= false then self.holder.clock:Show() else self.holder.clock:Hide() end

    self:ApplyNativeChrome(settings)
    self:UpdateZone()
    self:UpdateRaidIdentifier()
    self:PositionNativeIndicators(settings)
    self:UpdateClock()

    if settings.collectAddonButtons == false then
        self:RestoreAllCollectedButtons()
        if self.collectorButton then self.collectorButton:Hide() end
    else
        if self.collectorButton then self.collectorButton:Show() end
        self:ScanAddonButtons(false)
    end

    RUI:UpdateMoverSize("Minimap", outer * RUI:GetEffectiveScale("minimap"), outer * RUI:GetEffectiveScale("minimap"))
    RUI:SetMoverEnabled("Minimap", true)
    self:RefreshAppearance()
end

function MinimapModule:OnComponentScaleChanged(key)
    if key == "all" or key == "minimap" then self:ApplySettings() end
end

function MinimapModule:OnEvent(event, addonName)
    if event == "ADDON_LOADED" then
        -- A newly loaded addon may create a minimap launcher parented directly
        -- to UIParent. Allow one broad discovery pass for that load, then stop.
        self.uiParentScanComplete = nil
        if addonName == "Blizzard_TimeManager" then
            local settings = self:GetSettings()
            if settings then self:ApplyNativeChrome(settings) end
        end
        local settings = self:GetSettings()
        if settings and settings.enabled ~= false and settings.collectAddonButtons ~= false then
            self.scanPending = true
        end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        self:UpdateZone()
        self:UpdateRaidIdentifier()
        local settings = self:GetSettings()
        if settings and settings.enabled ~= false then self:PositionNativeIndicators(settings) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:ApplySettings()
        self.scanPending = true
    elseif event == "UPDATE_PENDING_MAIL" or event == "LFG_UPDATE" or event == "PLAYER_DIFFICULTY_CHANGED" or event == "UPDATE_INSTANCE_INFO" or event == "UPDATE_BATTLEFIELD_STATUS" then
        local settings = self:GetSettings()
        if settings and settings.enabled ~= false then
            if event == "PLAYER_DIFFICULTY_CHANGED" or event == "UPDATE_INSTANCE_INFO" then self:UpdateRaidIdentifier() end
            self:PositionNativeIndicators(settings)
        end
    end
end

function MinimapModule:OnInitialize()
    self:CreateHolder()
    self:CreateCollector()
    self:InstallMinimap()

    self.updateFrame = CreateFrame("Frame", nil, self.holder)
    self.updateFrame.elapsed = 0
    self.updateFrame.scanElapsed = 0
    self.updateFrame:SetScript("OnUpdate", function(self, elapsed)
        elapsed = elapsed or 0
        self.elapsed = self.elapsed + elapsed
        self.scanElapsed = self.scanElapsed + elapsed

        if self.elapsed >= 5 then
            self.elapsed = 0
            MinimapModule:UpdateClock()
        end

        if MinimapModule.scanPending or self.scanElapsed >= 15 then
            self.scanElapsed = 0
            MinimapModule.scanPending = false
            local settings = MinimapModule:GetSettings() or {}
            if settings.enabled ~= false and settings.collectAddonButtons ~= false then
                MinimapModule:ScanAddonButtons(false)
            end
        end
    end)

    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "RefreshAppearance")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED", self, "OnComponentScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET", self, "ApplySettings")
end

function MinimapModule:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "OnEvent")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
    self:RegisterEvent("ZONE_CHANGED", "OnEvent")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "OnEvent")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEvent")
    self:RegisterEvent("UPDATE_PENDING_MAIL", "OnEvent")
    self:RegisterEvent("LFG_UPDATE", "OnEvent")
    self:RegisterEvent("PLAYER_DIFFICULTY_CHANGED", "OnEvent")
    self:RegisterEvent("UPDATE_INSTANCE_INFO", "OnEvent")
    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", "OnEvent")
    self:ApplySettings()
end
