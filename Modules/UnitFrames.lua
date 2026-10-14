-- ZenUI 0.5.4 Player + Target + Focus + Pet + Party/Raid UnitFrames.
-- Purpose-built for the WoW 3.3.5a API (Interface 30300).

local RUI = ZenUI
local UnitFrames = RUI:NewModule("UnitFrames")

local FRAME_WIDTH = 230
local FRAME_HEIGHT = 48
local HEALTH_HEIGHT = 34
local POWER_HEIGHT = 10
local CAST_HEIGHT = 16
local TOT_WIDTH = 112
local TOT_HEIGHT = 22
local PORTRAIT_SIZE = 46
local AURA_SIZE = 24
local AURA_SPACING = 4
local MAX_AURAS_PER_ROW = 8
local AURA_ROWS_HEIGHT = (AURA_SIZE * 2) + AURA_SPACING
local RESOURCE_HEIGHT = 8
local RESOURCE_SPACING = 3
local PET_WIDTH = 180
local PET_HEIGHT = 38
local PET_HEALTH_HEIGHT = 26
local PET_POWER_HEIGHT = 8
local PET_CAST_HEIGHT = 14
local PET_PORTRAIT_SIZE = 36
local PARTY_WIDTH = 200
local PARTY_HEIGHT = 40
local PARTY_HEALTH_HEIGHT = 28
local PARTY_POWER_HEIGHT = 8
local PARTY_PORTRAIT_SIZE = 38
local PARTY_SPACING = 5
local PARTY_COUNT = 4
local PARTY_STACK_HEIGHT = (PARTY_HEIGHT * PARTY_COUNT) + (PARTY_SPACING * (PARTY_COUNT - 1))
local RAID_FRAME_WIDTH = 102
local RAID_FRAME_HEIGHT = 30
local RAID_HEALTH_HEIGHT = 23
local RAID_POWER_HEIGHT = 5
local RAID_MEMBER_SPACING = 3
local RAID_GROUP_SPACING = 10
local RAID_GROUP_LABEL_HEIGHT = 14
local RAID_MAX_GROUPS = 8
local RAID_MEMBERS_PER_GROUP = 5
local RAID_MAX_MEMBERS = RAID_MAX_GROUPS * RAID_MEMBERS_PER_GROUP
-- Keep out-of-range units unmistakably dim while retaining readable names and
-- a visible class-color trace.  Only Zen-owned fills/text/portraits are
-- faded; the stable bar backgrounds and self-repair path remain fully visible,
-- so a strong range fade cannot be mistaken for a missing/broken status bar.
local GROUP_RANGE_BAR_ALPHA = 0.32
local GROUP_RANGE_TEXT_ALPHA = 0.52
local GROUP_RANGE_PORTRAIT_ALPHA = 0.42
local GROUP_VISUAL_REFRESH = 0.50

local max = math.max
local min = math.min
local floor = math.floor
local format = string.format
local concat = table.concat

local fallbackClassColors = {
    WARRIOR = { 0.78, 0.61, 0.43 },
    PALADIN = { 0.96, 0.55, 0.73 },
    HUNTER = { 0.67, 0.83, 0.45 },
    ROGUE = { 1.00, 0.96, 0.41 },
    PRIEST = { 1.00, 1.00, 1.00 },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    SHAMAN = { 0.00, 0.44, 0.87 },
    MAGE = { 0.41, 0.80, 0.94 },
    WARLOCK = { 0.58, 0.51, 0.79 },
    DRUID = { 1.00, 0.49, 0.04 },
}

local fallbackPowerColors = {
    MANA = { 0.20, 0.45, 0.90 },
    RAGE = { 0.85, 0.20, 0.20 },
    FOCUS = { 1.00, 0.50, 0.25 },
    ENERGY = { 0.95, 0.85, 0.20 },
    HAPPINESS = { 0.00, 0.75, 1.00 },
    RUNES = { 0.50, 0.50, 0.50 },
    RUNIC_POWER = { 0.00, 0.82, 1.00 },
}

local runeColors = {
    [1] = { 0.78, 0.16, 0.20 }, -- Blood
    [2] = { 0.34, 0.72, 0.28 }, -- Unholy
    [3] = { 0.30, 0.62, 0.90 }, -- Frost
    [4] = { 0.72, 0.44, 0.88 }, -- Death
}

local function Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function GetTextSettings()
    local unitframes = RUI.db and RUI.db.unitframes
    return unitframes and unitframes.text or nil
end

local function GetUnitFrameTextColor()
    local settings = GetTextSettings()
    local mode = settings and settings.colorMode or "LIGHT"

    if mode == "ACCENT" then
        return RUI:GetAccentColor()
    elseif mode == "CUSTOM" and settings and type(settings.customColor) == "table" then
        return settings.customColor[1] or 1, settings.customColor[2] or 1, settings.customColor[3] or 1
    end

    return 1, 1, 1
end

local function StyleUnitFrameText(fontString, baseSize, fitScale)
    if not fontString then return end

    local settings = GetTextSettings() or {}
    local scale = tonumber(fitScale) or 1
    local size = max(6, (baseSize or 10) * (tonumber(settings.size) or 1) * scale)
    local fontPath = RUI:GetFontPath(settings.font or "Default")
    local style = settings.style or "OUTLINE"
    local flags

    if style == "OUTLINE" then
        flags = "OUTLINE"
    elseif style == "BOLD" then
        flags = "THICKOUTLINE"
    end

    if flags then
        fontString:SetFont(fontPath, size, flags)
    else
        fontString:SetFont(fontPath, size)
    end

    local r, g, b = GetUnitFrameTextColor()
    fontString:SetTextColor(r, g, b)

    if style == "SHADOW" or style == "OUTLINE" or style == "BOLD" then
        -- Keep a real black shadow even with outline flags. On the small Wrath
        -- fonts this materially improves readability over bright class bars.
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(1, -1)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end

    fontString.ruiBaseSize = baseSize or 10
    fontString.ruiFitScale = scale
end

local function SetTextShown(fontString, shown)
    if not fontString then return end
    if shown then fontString:Show() else fontString:Hide() end
end

local function FitUnitFrameText(fontString, baseSize, maxWidth, maxFontSize)
    if not fontString then return 1 end

    maxWidth = max(1, tonumber(maxWidth) or 1)
    fontString:SetWidth(maxWidth)

    -- Horizontal fitting alone is not enough on the compact health bars: at
    -- large typography settings the top row and descriptor row can physically
    -- overlap even though both strings fit their widths. Give each row a hard
    -- geometry ceiling derived from the bar height, then apply the user's
    -- horizontal auto-fit setting inside that safe vertical scale.
    local settings = GetTextSettings() or {}
    local nominal = max(6, (baseSize or 10) * (tonumber(settings.size) or 1))
    local geometryScale = 1
    if maxFontSize and tonumber(maxFontSize) and tonumber(maxFontSize) > 0 then
        geometryScale = min(1, tonumber(maxFontSize) / nominal)
    end

    local fitScale = geometryScale
    StyleUnitFrameText(fontString, baseSize, fitScale)
    fontString:SetHeight(max(8, nominal * fitScale * 1.15))

    if settings.autoFit == false or not fontString:IsShown() then
        return fitScale
    end

    local width = fontString:GetStringWidth() or 0
    if width <= maxWidth or width <= 0 then
        return fitScale
    end

    local minScale = Clamp(tonumber(settings.minScale) or 0.70, 0.50, 1)
    local widthScale = Clamp(fitScale * ((maxWidth - 1) / width), minScale, 1)
    fitScale = min(geometryScale, widthScale)
    StyleUnitFrameText(fontString, baseSize, fitScale)
    fontString:SetHeight(max(8, nominal * fitScale * 1.15))

    -- Font metrics can round differently after SetFont; one correction pass
    -- keeps the result within its assigned pixel width without oscillating.
    local secondWidth = fontString:GetStringWidth() or 0
    if secondWidth > maxWidth and secondWidth > 0 then
        local corrected = fitScale * ((maxWidth - 1) / secondWidth)
        -- Geometry safety is authoritative. The user min-auto-size remains the
        -- normal width floor, but never forces two vertical rows to collide.
        corrected = max(minScale, corrected)
        fitScale = min(geometryScale, Clamp(corrected, 0.50, 1))
        StyleUnitFrameText(fontString, baseSize, fitScale)
        fontString:SetHeight(max(8, nominal * fitScale * 1.15))
    end

    return fitScale
end

local function ShortValue(value)
    value = tonumber(value) or 0
    local absValue = math.abs(value)

    if absValue >= 1000000 then
        return format("%.1fm", value / 1000000)
    elseif absValue >= 100000 then
        return format("%.0fk", value / 1000)
    elseif absValue >= 10000 then
        return format("%.1fk", value / 1000)
    end

    return tostring(floor(value + 0.5))
end

local function GetClassColor(unit)
    local _, class = UnitClass(unit)
    if not class then
        return nil
    end

    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then
        return color.r, color.g, color.b
    end

    color = fallbackClassColors[class]
    if color then
        return color[1], color[2], color[3]
    end
end

local function GetReactionColor(unit)
    if UnitIsTapped and UnitIsTapped(unit) and UnitIsTappedByPlayer and not UnitIsTappedByPlayer(unit) then
        return 0.45, 0.45, 0.45
    end

    local reaction = UnitReaction(unit, "player")
    if FACTION_BAR_COLORS and reaction and FACTION_BAR_COLORS[reaction] then
        local color = FACTION_BAR_COLORS[reaction]
        return color.r, color.g, color.b
    end

    if reaction and reaction >= 5 then
        return 0.20, 0.75, 0.30
    elseif reaction == 4 then
        return 0.90, 0.80, 0.20
    end

    return 0.85, 0.20, 0.20
end

local function GetHealthColor(unit)
    if UnitIsConnected and not UnitIsConnected(unit) then
        return 0.45, 0.45, 0.45
    end

    if UnitIsPlayer(unit) then
        local r, g, b = GetClassColor(unit)
        if r then return r, g, b end
    end

    if unit == "player" then
        local r, g, b = GetClassColor(unit)
        if r then return r, g, b end
    end

    return GetReactionColor(unit)
end

local function GetLivePowerValues(unit)
    local power, maxPower

    -- Wrath still exposes the legacy UnitMana/UnitManaMax API for every power
    -- type (mana, rage, energy and runic power). Some private-server cores send
    -- the specific UNIT_* events unreliably, so prefer the legacy values when
    -- available and poll them for the player frame below.
    if UnitMana and UnitManaMax then
        local legacyPower = tonumber(UnitMana(unit))
        local legacyMax = tonumber(UnitManaMax(unit))
        if legacyPower ~= nil and legacyMax ~= nil and legacyMax > 0 then
            power, maxPower = legacyPower, legacyMax
        end
    end

    if (power == nil or maxPower == nil or maxPower <= 0) and UnitPower and UnitPowerMax then
        power = tonumber(UnitPower(unit)) or 0
        maxPower = tonumber(UnitPowerMax(unit)) or 0
    end

    return power or 0, maxPower or 0
end

local function GetPowerColor(unit)
    local powerType, powerToken, altR, altG, altB = UnitPowerType(unit)
    local color

    if PowerBarColor then
        color = PowerBarColor[powerToken] or PowerBarColor[powerType]
    end

    if color then
        return color.r, color.g, color.b
    elseif altR then
        return altR, altG, altB
    end

    color = fallbackPowerColors[powerToken or "MANA"] or fallbackPowerColors.MANA
    return color[1], color[2], color[3]
end

local function GetUnitDescriptor(unit)
    local settings = GetTextSettings() or {}
    local parts = {}
    local level = UnitLevel(unit) or 0
    local classification = UnitClassification(unit)
    local localizedClass = UnitClass(unit)

    if settings.showLevel ~= false then
        if classification == "worldboss" then
            parts[#parts + 1] = "Boss"
        elseif level == -1 then
            parts[#parts + 1] = "??"
        elseif level > 0 then
            parts[#parts + 1] = tostring(level)
        else
            parts[#parts + 1] = "??"
        end
    end

    if settings.showClass ~= false then
        local descriptor
        if UnitIsPlayer(unit) and localizedClass then
            descriptor = localizedClass
        elseif unit == "pet" and UnitCreatureFamily then
            descriptor = UnitCreatureFamily(unit)
        elseif classification == "rareelite" then
            descriptor = "Rare Elite"
        elseif classification == "elite" then
            descriptor = "Elite"
        elseif classification == "rare" then
            descriptor = "Rare"
        end

        if descriptor and descriptor ~= "" then
            parts[#parts + 1] = descriptor
        end
    end

    return concat(parts, "  ")
end

local function GetHealthText(unit, health, maxHealth)
    local settings = GetTextSettings() or {}
    local wantsValue = settings.showHealthValue ~= false
    local wantsPercent = settings.showHealthPercent ~= false

    if not wantsValue and not wantsPercent then
        return ""
    end

    if UnitIsConnected and not UnitIsConnected(unit) then
        return "OFFLINE"
    elseif UnitIsGhost and UnitIsGhost(unit) then
        return "GHOST"
    elseif UnitIsDead and UnitIsDead(unit) then
        return "DEAD"
    end

    local parts = {}
    if wantsValue then
        parts[#parts + 1] = ShortValue(health)
    end
    if wantsPercent and maxHealth > 0 then
        parts[#parts + 1] = tostring(floor((health / maxHealth) * 100 + 0.5)) .. "%"
    end

    if #parts == 0 and maxHealth <= 0 then
        return wantsValue and "0" or ""
    end
    return concat(parts, "  ")
end

local function GetPowerText(power, maxPower)
    local settings = GetTextSettings() or {}
    local wantsValue = settings.showPowerValue ~= false
    local wantsMax = settings.showPowerMax ~= false

    if maxPower <= 0 or (not wantsValue and not wantsMax) then
        return ""
    end

    if wantsValue and wantsMax then
        return ShortValue(power) .. " / " .. ShortValue(maxPower)
    elseif wantsValue then
        return ShortValue(power)
    end

    return "max " .. ShortValue(maxPower)
end

local function SetUnitTooltip(frame)
    frame:SetScript("OnEnter", function(self)
        if not self.unit or not UnitExists(self.unit) then
            return
        end

        GameTooltip:SetOwner(self, self.mirrored and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function InitializeUnitMenu(dropdown, unit)
    if not dropdown or not unit or not UnitExists(unit) then return end

    local menu
    local name
    local id

    if unit == "focus" then
        menu = "FOCUS"
        name = SET_FOCUS
    elseif UnitIsUnit(unit, "player") then
        menu = "SELF"
    elseif UnitIsUnit(unit, "vehicle") then
        menu = "VEHICLE"
    elseif UnitIsUnit(unit, "pet") then
        menu = "PET"
    elseif UnitIsPlayer(unit) then
        id = UnitInRaid(unit)
        if id then
            menu = "RAID_PLAYER"
            name = GetRaidRosterInfo(id + 1)
        elseif UnitInParty(unit) then
            menu = "PARTY"
        else
            menu = "PLAYER"
        end
    else
        menu = "TARGET"
        name = RAID_TARGET_ICON
    end

    if menu then
        UnitPopup_ShowMenu(dropdown, menu, unit, name, id)
    end
end

local function ConfigureSecureUnitButton(frame, unit)
    frame.unit = unit
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local dropdownName = frame:GetName() .. "DropDown"
    local dropdown = CreateFrame("Frame", dropdownName, UIParent, "UIDropDownMenuTemplate")
    frame.dropdown = dropdown
    UIDropDownMenu_Initialize(dropdown, function(self)
        InitializeUnitMenu(self, frame.unit)
    end, "MENU")

    local showmenu = function()
        ToggleDropDownMenu(1, nil, dropdown, frame:GetName(), 0, 0)
    end

    if SecureUnitButton_OnLoad then
        SecureUnitButton_OnLoad(frame, unit, showmenu)
    else
        frame:SetAttribute("*type1", "target")
        frame:SetAttribute("*type2", "menu")
        frame:SetAttribute("unit", unit)
        frame.menu = showmenu
    end

    -- Project Ebonhold players commonly use Shift+Left Click as the quick
    -- Inspect gesture. SecureUnitButtonTemplate owns the normal click action,
    -- so bridge the modifier in PostClick rather than replacing targeting or
    -- the native right-click unit menu.
    if frame.HookScript and not frame.ZenInspectClickHooked then
        frame.ZenInspectClickHooked = true
        frame:HookScript("PostClick", function(self, button)
            if button ~= "LeftButton" then return end
            if not IsShiftKeyDown or not IsShiftKeyDown() then return end
            if InCombatLockdown and InCombatLockdown() then return end
            local inspectUnit = self.unit or (self.GetAttribute and self:GetAttribute("unit"))
            if not inspectUnit or not UnitExists or not UnitExists(inspectUnit) then return end
            if UnitIsPlayer and not UnitIsPlayer(inspectUnit) then return end
            local interactions = RUI:GetModule("BlizzardPhaseDInteractions")
            if interactions and interactions.RequestInspect then
                interactions:RequestInspect(inspectUnit)
            elseif type(InspectUnit) == "function" then
                pcall(InspectUnit, inspectUnit)
            end
        end)
    end
end

-- Unit health/power bars deliberately use a plain Frame + Texture instead of
-- Blizzard's StatusBar widget. On the 3.3.5 client, a StatusBar created at one
-- width and then stretched by anchors can leave its internal fill texture using
-- stale geometry. That made values such as 2797 / 24709 (~11.3%) render near
-- half-full. ZenUI owns the fill geometry directly so visual width is exact.
local function CreateBar(parent, height)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(height)
    bar.ratio = 1

    bar.background = bar:CreateTexture(nil, "BACKGROUND")
    bar.background:SetAllPoints(bar)
    bar.background:SetTexture(0, 0, 0, 0.45)

    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetTexture(RUI:GetStatusBarTexture())
    bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)

    function bar:SetFillColor(r, g, b, a)
        local texture = RUI:GetStatusBarTexture()
        r, g, b, a = r or 1, g or 1, b or 1, a or 1
        if self.RUIFillTexture ~= texture then
            self.RUIFillTexture = texture
            self.fill:SetTexture(texture)
        end
        if self.RUIFillR ~= r or self.RUIFillG ~= g or self.RUIFillB ~= b or self.RUIFillA ~= a then
            self.RUIFillR, self.RUIFillG, self.RUIFillB, self.RUIFillA = r, g, b, a
            self.fill:SetVertexColor(r, g, b, a)
        end
    end

    function bar:RepairFillVisual()
        local ratio = Clamp(tonumber(self.ratio) or 0, 0, 1)
        local width = self:GetWidth() or 0
        if ratio <= 0 or width <= 0 then return end

        local expectedWidth = max(0.01, width * ratio)
        local currentWidth = (self.fill.GetWidth and self.fill:GetWidth()) or 0
        local shown = self.fill.IsShown and self.fill:IsShown()

        -- Ebonhold can briefly invalidate a raid unit token while the roster and
        -- cached health text remain valid. In rare cases the Texture ends up
        -- hidden even after the bar ratio itself is still correct. Repair that
        -- presentation state without forcing a full unit-frame rebuild.
        if not shown or math.abs((currentWidth or 0) - expectedWidth) > 0.5 then
            self.fill:ClearAllPoints()
            self.fill:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
            self.fill:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
            self.fill:SetWidth(expectedWidth)
        end
        self.fill:Show()
    end

    function bar:SetRatio(ratio)
        ratio = Clamp(tonumber(ratio) or 0, 0, 1)
        local width = self:GetWidth() or 0
        if self.ratio == ratio and self.RUIRatioWidth == width then
            if ratio > 0 and width > 0 then self:RepairFillVisual() end
            return
        end
        self.ratio = ratio
        self.RUIRatioWidth = width

        if ratio <= 0 or width <= 0 then
            self.fill:Hide()
            return
        end

        self:RepairFillVisual()
    end

    return bar
end

local function SetNormalizedBarValue(bar, currentValue, maximumValue, preserveInvalid)
    if not bar then return end

    currentValue = tonumber(currentValue) or 0
    maximumValue = tonumber(maximumValue) or 0

    if maximumValue > 0 then
        local ratio = Clamp(currentValue / maximumValue, 0, 1)
        bar.lastValidRatio = ratio
        bar:SetRatio(ratio)
    elseif preserveInvalid and bar.lastValidRatio ~= nil then
        -- Some 3.3.5 private-server cores briefly return 0/0 for distant raid
        -- units even though the roster entry is still valid. Keep the last
        -- trustworthy geometry until live unit data resumes instead of leaving
        -- a permanently black bar.
        bar:SetRatio(bar.lastValidRatio)
    else
        bar:SetRatio(0)
    end
end

local function ShouldPreserveGroupValues(unit)
    if UnitIsConnected and not UnitIsConnected(unit) then return false end
    if UnitIsDead and UnitIsDead(unit) then return false end
    if UnitIsGhost and UnitIsGhost(unit) then return false end
    return true
end

local function CacheGroupPollState(frame, health, maxHealth, power, maxPower)
    if not frame then return end
    frame.RUIPollHealth = tonumber(health) or 0
    frame.RUIPollMaxHealth = tonumber(maxHealth) or 0
    frame.RUIPollPower = tonumber(power) or 0
    frame.RUIPollMaxPower = tonumber(maxPower) or 0
    if frame.unit and UnitIsConnected then
        frame.RUIPollConnected = UnitIsConnected(frame.unit) and true or false
    else
        frame.RUIPollConnected = true
    end
end

local function GroupPollStateChanged(frame)
    if not frame or not frame.unit then return false end
    local unit = frame.unit
    local health = (UnitHealth and UnitHealth(unit)) or 0
    local maxHealth = (UnitHealthMax and UnitHealthMax(unit)) or 0
    local power = (UnitPower and UnitPower(unit)) or 0
    local maxPower = (UnitPowerMax and UnitPowerMax(unit)) or 0
    local connected = UnitIsConnected and (UnitIsConnected(unit) and true or false) or true
    local changed = frame.RUIPollHealth ~= health
        or frame.RUIPollMaxHealth ~= maxHealth
        or frame.RUIPollPower ~= power
        or frame.RUIPollMaxPower ~= maxPower
        or frame.RUIPollConnected ~= connected
    CacheGroupPollState(frame, health, maxHealth, power, maxPower)
    return changed
end

local function IsGroupUnitOutOfRange(unit)
    if not unit then return false end
    if UnitIsUnit and UnitIsUnit(unit, "player") then return false end
    if UnitIsConnected and not UnitIsConnected(unit) then return true end

    -- UnitInRange is the native 40-yard group check in Wrath. For party/raid
    -- units, both false and nil mean the unit is not currently confirmed in
    -- range; true/1 means in range. This also handles private-server cores
    -- which use numeric booleans.
    if UnitInRange then
        local inRange = UnitInRange(unit)
        return not (inRange == true or inRange == 1)
    end

    -- Defensive fallback for unusual 3.3.5 cores without UnitInRange. Follow
    -- distance is roughly 28 yards, so it is stricter than the normal 40-yard
    -- raid check but still preferable to never fading distant frames.
    if CheckInteractDistance then
        local inRange = CheckInteractDistance(unit, 4)
        return not (inRange == true or inRange == 1)
    end

    return false
end

local function CreateCastBar(parent, unit, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar.unit = unit
    bar:SetHeight(height or CAST_HEIGHT)
    bar:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -3)
    bar:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -3)
    bar:SetStatusBarTexture(RUI:GetStatusBarTexture())
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()
    RUI:CreateBackdrop(bar)

    bar.fillBackground = bar:CreateTexture(nil, "BACKGROUND")
    bar.fillBackground:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    bar.fillBackground:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    bar.fillBackground:SetTexture(0, 0, 0, 0.55)

    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.text:SetPoint("LEFT", bar, "LEFT", 5, 0)
    bar.text:SetPoint("RIGHT", bar, "RIGHT", -42, 0)
    bar.text:SetJustifyH("LEFT")

    bar.time = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.time:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
    bar.time:SetJustifyH("RIGHT")

    bar:SetScript("OnUpdate", function(self)
        if not self.active then
            return
        end

        local now = GetTime()
        local duration = max(0.001, (self.endTime or now) - (self.startTime or now))
        local value

        if self.channeling then
            value = (self.endTime or now) - now
        else
            value = now - (self.startTime or now)
        end

        value = Clamp(value, 0, duration)
        self:SetMinMaxValues(0, duration)
        self:SetValue(value)

        local remaining = max(0, (self.endTime or now) - now)
        self.time:SetText(format("%.1f", remaining))

        if now > (self.endTime or now) + 0.15 then
            self.active = nil
            self.casting = nil
            self.channeling = nil
            self:Hide()
        end
    end)

    return bar
end

local function CreatePortrait(frame, size)
    local holder = CreateFrame("Frame", nil, frame)
    size = size or PORTRAIT_SIZE
    holder:SetWidth(size)
    holder:SetHeight(size)
    holder:SetFrameLevel(frame:GetFrameLevel() + 2)

    holder.texture = holder:CreateTexture(nil, "ARTWORK")
    holder.texture:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    holder.texture:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    holder.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    RUI:CreateBackdrop(holder)
    holder:Hide()
    return holder
end

local function CreateAuraButton(parent, auraType, index, unit)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(AURA_SIZE)
    button:SetHeight(AURA_SIZE)
    button.auraType = auraType
    button.auraIndex = index
    button.unit = unit or "target"
    RUI:CreateBackdrop(button)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.count = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.count:SetJustifyH("RIGHT")

    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:Hide()

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        if self.auraType == "buff" then
            GameTooltip:SetUnitBuff(self.unit, self.auraIndex)
        else
            GameTooltip:SetUnitDebuff(self.unit, self.auraIndex)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    return button
end

local function CreateAuraContainer(globalName, unit, width)
    width = tonumber(width) or FRAME_WIDTH
    local count = math.min(MAX_AURAS_PER_ROW, math.max(1, math.floor((width + AURA_SPACING) / (AURA_SIZE + AURA_SPACING))))
    local container = CreateFrame("Frame", globalName, UIParent)
    container:SetWidth(width)
    container:SetHeight(AURA_ROWS_HEIGHT)
    container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    container:SetFrameStrata("MEDIUM")
    container.unit = unit
    container.maxAuras = count
    container.buffs = {}
    container.debuffs = {}
    container.buffRow = CreateFrame("Frame", nil, container)
    container.buffRow:SetWidth(width); container.buffRow:SetHeight(AURA_SIZE)
    container.debuffRow = CreateFrame("Frame", nil, container)
    container.debuffRow:SetWidth(width); container.debuffRow:SetHeight(AURA_SIZE)

    for i = 1, count do
        local debuff = CreateAuraButton(container.debuffRow, "debuff", i, unit)
        debuff:SetPoint("TOPLEFT", container.debuffRow, "TOPLEFT", (i - 1) * (AURA_SIZE + AURA_SPACING), 0)
        container.debuffs[i] = debuff

        local buff = CreateAuraButton(container.buffRow, "buff", i, unit)
        buff:SetPoint("TOPLEFT", container.buffRow, "TOPLEFT", (i - 1) * (AURA_SIZE + AURA_SPACING), 0)
        container.buffs[i] = buff
    end

    container:Hide()
    return container
end

local function CreateClassResourceFrame()
    local frame = CreateFrame("Frame", "ZenUIClassResources", UIParent)
    frame:SetWidth(FRAME_WIDTH)
    frame:SetHeight(RESOURCE_HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame.segments = {}
    frame.elapsed = 0

    for i = 1, 6 do
        local segment = CreateFrame("Frame", nil, frame)
        segment:SetHeight(RESOURCE_HEIGHT)
        RUI:CreateBackdrop(segment)

        -- Keep a dim rune-type track visible underneath the live recharge fill.
        -- This lets each slot retain its identity while only the spent rune drains.
        segment.track = segment:CreateTexture(nil, "BACKGROUND")
        segment.track:SetPoint("TOPLEFT", segment, "TOPLEFT", 1, -1)
        segment.track:SetPoint("BOTTOMRIGHT", segment, "BOTTOMRIGHT", -1, 1)
        segment.track:SetTexture(1, 1, 1, 0.12)

        -- The fill is width-driven rather than alpha-driven. 3.3.5 may report
        -- incidental GCD timing for ready runes, so UpdateClassResources uses the
        -- runeReady return as the authority and only animates genuinely spent slots.
        segment.fill = segment:CreateTexture(nil, "ARTWORK")
        segment.fill:SetPoint("TOPLEFT", segment, "TOPLEFT", 1, -1)
        segment.fill:SetPoint("BOTTOMLEFT", segment, "BOTTOMLEFT", 1, 1)
        segment.fill:SetWidth(1)
        segment.fill:SetTexture(1, 1, 1, 1)
        segment.runeType = nil
        segment.rechargeProgress = 1
        frame.segments[i] = segment
    end

    frame:Hide()
    return frame
end

-- FontStrings created directly on a unit button can be visually covered by
-- child health/power frames because frame level takes precedence over region
-- draw layer in the 3.3.5 renderer. Keep all unit text on a dedicated frame
-- above the bar/portrait children so typography remains crisp and its configured
-- colour/outline is rendered exactly as requested.
local function CreateUnitTextOverlay(frame)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    overlay:EnableMouse(false)
    return overlay
end

local GROUP_LEADER_ICON = "Interface\\GroupFrame\\UI-Group-LeaderIcon"

local function CreateGroupLeaderIcon(frame, size)
    if not frame or not frame.textOverlay then return nil end
    local icon = frame.textOverlay:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(GROUP_LEADER_ICON)
    icon:SetWidth(size or 11)
    icon:SetHeight(size or 11)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    icon:Hide()
    return icon
end

local function SetGroupLeaderIcon(frame, shown)
    if not frame or not frame.leaderIcon then return end
    if shown then frame.leaderIcon:Show() else frame.leaderIcon:Hide() end
end

local function CreateUnitFrame(name, unit, mirrored)
    local frame = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    frame:SetWidth(FRAME_WIDTH)
    frame:SetHeight(FRAME_HEIGHT)
    frame:SetClampedToScreen(true)
    frame.mirrored = mirrored and true or false
    frame.portraitSize = PORTRAIT_SIZE
    ConfigureSecureUnitButton(frame, unit)
    SetUnitTooltip(frame)
    RUI:CreateBackdrop(frame)

    frame.health = CreateBar(frame, HEALTH_HEIGHT)
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    frame.power = CreateBar(frame, POWER_HEIGHT)
    frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    frame.separator = frame:CreateTexture(nil, "OVERLAY")
    frame.separator:SetHeight(1)
    frame.separator:SetPoint("BOTTOMLEFT", frame.power, "TOPLEFT", 0, 1)
    frame.separator:SetPoint("BOTTOMRIGHT", frame.power, "TOPRIGHT", 0, 1)
    frame.separator:SetTexture(0, 0, 0, 0.75)

    frame.textOverlay = CreateUnitTextOverlay(frame)
    frame.nameText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.descriptorText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.healthText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.powerText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if unit == "player" then
        frame.leaderIcon = CreateGroupLeaderIcon(frame, 12)
    end

    frame.nameText:SetWidth(145)
    frame.descriptorText:SetWidth(130)
    frame.healthText:SetWidth(100)
    frame.powerText:SetWidth(105)

    if frame.mirrored then
        frame.nameText:SetPoint("TOPRIGHT", frame.health, "TOPRIGHT", -7, -2)
        frame.nameText:SetJustifyH("RIGHT")
        frame.descriptorText:SetPoint("BOTTOMRIGHT", frame.health, "BOTTOMRIGHT", -7, 2)
        frame.descriptorText:SetJustifyH("RIGHT")
        frame.healthText:SetPoint("TOPLEFT", frame.health, "TOPLEFT", 7, -2)
        frame.healthText:SetJustifyH("LEFT")
        frame.powerText:SetPoint("LEFT", frame.power, "LEFT", 5, 0)
        frame.powerText:SetJustifyH("LEFT")
    else
        frame.nameText:SetPoint("TOPLEFT", frame.health, "TOPLEFT", 7, -2)
        frame.nameText:SetJustifyH("LEFT")
        frame.descriptorText:SetPoint("BOTTOMLEFT", frame.health, "BOTTOMLEFT", 7, 2)
        frame.descriptorText:SetJustifyH("LEFT")
        frame.healthText:SetPoint("TOPRIGHT", frame.health, "TOPRIGHT", -7, -2)
        frame.healthText:SetJustifyH("RIGHT")
        frame.powerText:SetPoint("RIGHT", frame.power, "RIGHT", -5, 0)
        frame.powerText:SetJustifyH("RIGHT")
    end

    frame.portrait = CreatePortrait(frame)
    frame.castbar = CreateCastBar(frame, unit)
    return frame
end

local function CreateMiniUnitFrame(name, parent, unit)
    local frame = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
    frame:SetWidth(TOT_WIDTH)
    frame:SetHeight(TOT_HEIGHT)
    frame.isMini = true
    ConfigureSecureUnitButton(frame, unit)
    SetUnitTooltip(frame)
    RUI:CreateBackdrop(frame)

    frame.health = CreateBar(frame, TOT_HEIGHT - 2)
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    frame.textOverlay = CreateUnitTextOverlay(frame)
    frame.nameText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.nameText:SetPoint("LEFT", frame, "LEFT", 5, 0)
    frame.nameText:SetPoint("RIGHT", frame, "RIGHT", -31, 0)
    frame.nameText:SetJustifyH("LEFT")

    frame.healthText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.healthText:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
    frame.healthText:SetJustifyH("RIGHT")

    return frame
end

local function CreatePetFrame()
    local frame = CreateFrame("Button", "ZenUIPetFrame", UIParent, "SecureUnitButtonTemplate")
    frame:SetWidth(PET_WIDTH)
    frame:SetHeight(PET_HEIGHT)
    frame:SetClampedToScreen(true)
    frame.mirrored = false
    frame.isPet = true
    frame.portraitSize = PET_PORTRAIT_SIZE
    ConfigureSecureUnitButton(frame, "pet")
    SetUnitTooltip(frame)
    RUI:CreateBackdrop(frame)

    frame.health = CreateBar(frame, PET_HEALTH_HEIGHT)
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    frame.power = CreateBar(frame, PET_POWER_HEIGHT)
    frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    frame.separator = frame:CreateTexture(nil, "OVERLAY")
    frame.separator:SetHeight(1)
    frame.separator:SetPoint("BOTTOMLEFT", frame.power, "TOPLEFT", 0, 1)
    frame.separator:SetPoint("BOTTOMRIGHT", frame.power, "TOPRIGHT", 0, 1)
    frame.separator:SetTexture(0, 0, 0, 0.75)

    frame.textOverlay = CreateUnitTextOverlay(frame)
    frame.nameText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.descriptorText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.healthText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.powerText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    frame.nameText:SetWidth(105)
    frame.descriptorText:SetWidth(105)
    frame.healthText:SetWidth(70)
    frame.powerText:SetWidth(95)

    frame.nameText:SetPoint("TOPLEFT", frame.health, "TOPLEFT", 6, -1)
    frame.nameText:SetJustifyH("LEFT")
    frame.descriptorText:SetPoint("BOTTOMLEFT", frame.health, "BOTTOMLEFT", 6, 1)
    frame.descriptorText:SetJustifyH("LEFT")
    frame.healthText:SetPoint("TOPRIGHT", frame.health, "TOPRIGHT", -6, -1)
    frame.healthText:SetJustifyH("RIGHT")
    frame.powerText:SetPoint("RIGHT", frame.power, "RIGHT", -4, 0)
    frame.powerText:SetJustifyH("RIGHT")

    frame.portrait = CreatePortrait(frame, PET_PORTRAIT_SIZE)
    frame.castbar = CreateCastBar(frame, "pet", PET_CAST_HEIGHT)
    return frame
end

local function CreatePartyFrame(index, parent)
    local unit = "party" .. tostring(index)
    local frame = CreateFrame("Button", "ZenUIPartyFrame" .. tostring(index), parent or UIParent, "SecureUnitButtonTemplate")
    frame:SetWidth(PARTY_WIDTH)
    frame:SetHeight(PARTY_HEIGHT)
    frame:SetClampedToScreen(true)
    frame.mirrored = false
    frame.isParty = true
    frame.partyIndex = index
    frame.portraitSize = PARTY_PORTRAIT_SIZE
    ConfigureSecureUnitButton(frame, unit)
    SetUnitTooltip(frame)
    RUI:CreateBackdrop(frame)

    frame.health = CreateBar(frame, PARTY_HEALTH_HEIGHT)
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    frame.power = CreateBar(frame, PARTY_POWER_HEIGHT)
    frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    frame.separator = frame:CreateTexture(nil, "OVERLAY")
    frame.separator:SetHeight(1)
    frame.separator:SetPoint("BOTTOMLEFT", frame.power, "TOPLEFT", 0, 1)
    frame.separator:SetPoint("BOTTOMRIGHT", frame.power, "TOPRIGHT", 0, 1)
    frame.separator:SetTexture(0, 0, 0, 0.75)

    frame.textOverlay = CreateUnitTextOverlay(frame)
    frame.nameText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.descriptorText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.healthText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.powerText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.leaderIcon = CreateGroupLeaderIcon(frame, 11)

    frame.nameText:SetWidth(95)
    frame.descriptorText:SetWidth(95)
    frame.healthText:SetWidth(50)
    frame.powerText:SetWidth(52)

    frame.nameText:SetPoint("TOPLEFT", frame.health, "TOPLEFT", 6, -1)
    frame.nameText:SetJustifyH("LEFT")
    frame.descriptorText:SetPoint("BOTTOMLEFT", frame.health, "BOTTOMLEFT", 6, 1)
    frame.descriptorText:SetJustifyH("LEFT")
    frame.healthText:SetPoint("TOPRIGHT", frame.health, "TOPRIGHT", -6, -1)
    frame.healthText:SetJustifyH("RIGHT")
    frame.powerText:SetPoint("RIGHT", frame.power, "RIGHT", -4, 0)
    frame.powerText:SetJustifyH("RIGHT")

    frame.portrait = CreatePortrait(frame, PARTY_PORTRAIT_SIZE)
    return frame
end


local function CreateRaidFrame(index, parent)
    local unit = "raid" .. tostring(index)
    local frame = CreateFrame("Button", "ZenUIRaidFrame" .. tostring(index), parent or UIParent, "SecureUnitButtonTemplate")
    frame:SetWidth(RAID_FRAME_WIDTH)
    frame:SetHeight(RAID_FRAME_HEIGHT)
    frame:SetClampedToScreen(true)
    frame.isRaid = true
    frame.raidIndex = index
    ConfigureSecureUnitButton(frame, unit)
    SetUnitTooltip(frame)
    RUI:CreateBackdrop(frame)

    frame.health = CreateBar(frame, RAID_HEALTH_HEIGHT)
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    frame.power = CreateBar(frame, RAID_POWER_HEIGHT)
    frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    frame.textOverlay = CreateUnitTextOverlay(frame)
    frame.nameText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.healthText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.rankText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.leaderIcon = CreateGroupLeaderIcon(frame, 10)

    frame.nameText:SetPoint("LEFT", frame.health, "LEFT", 12, 0)
    frame.nameText:SetJustifyH("LEFT")
    frame.healthText:SetPoint("RIGHT", frame.health, "RIGHT", -13, 0)
    frame.healthText:SetJustifyH("RIGHT")
    frame.rankText:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -2)
    frame.rankText:SetJustifyH("LEFT")

    frame.ready = frame.textOverlay:CreateTexture(nil, "OVERLAY")
    frame.ready:SetWidth(6)
    frame.ready:SetHeight(6)
    frame.ready:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 3)
    frame.ready:Hide()

    frame.debuff = frame.textOverlay:CreateTexture(nil, "OVERLAY")
    frame.debuff:SetWidth(7)
    frame.debuff:SetHeight(7)
    frame.debuff:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    frame.debuff:Hide()

    frame:Hide()
    return frame
end

function UnitFrames:SetUnitWatch(frame, enabled)
    if not frame then return end

    if enabled then
        if not frame.ruiUnitWatch then
            if RegisterUnitWatch then
                RegisterUnitWatch(frame)
                frame.ruiUnitWatch = true
            elseif UnitExists(frame.unit) then
                frame:Show()
            end
        end
    else
        if frame.ruiUnitWatch and UnregisterUnitWatch then
            UnregisterUnitWatch(frame)
        end
        frame.ruiUnitWatch = nil
        frame:Hide()
    end
end

function UnitFrames:ApplyPortraitLayout(frame, enabled)
    if not frame or not frame.portrait then return end

    local portraitSize = frame.portraitSize or PORTRAIT_SIZE
    frame.health:ClearAllPoints()
    frame.power:ClearAllPoints()
    frame.portrait:ClearAllPoints()

    if enabled then
        if frame.mirrored then
            frame.portrait:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
            frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
            frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(portraitSize + 2), -1)
            frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
            frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(portraitSize + 2), 1)
        else
            frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
            frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", portraitSize + 2, -1)
            frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
            frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", portraitSize + 2, 1)
            frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        end
        frame.portrait:Show()
    else
        frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        frame.portrait:Hide()
    end

    -- Anchor changes alter the usable bar width. Re-apply the current ratio so
    -- the owned fill texture is resized against the final geometry immediately.
    if frame.health and frame.health.SetRatio then frame.health:SetRatio(frame.health.ratio or 0) end
    if frame.power and frame.power.SetRatio then frame.power:SetRatio(frame.power.ratio or 0) end
end

local function GetFrameTextSizes(frame)
    if frame and frame.isMini then
        return 9, nil, 8, nil
    elseif frame and frame.isRaid then
        return 9, nil, 8, nil
    elseif frame and (frame.isPet or frame.isParty) then
        return 10, 8, 9, 7
    end
    return 12, 9, 10, 8
end

local function HasText(fontString)
    if not fontString then return false end
    local text = fontString:GetText()
    return text and text ~= ""
end

local function MeasureUnitFrameText(fontString, baseSize)
    if not fontString or not HasText(fontString) then return 0 end
    StyleUnitFrameText(fontString, baseSize, 1)
    fontString:SetWidth(1000)
    local settings = GetTextSettings() or {}
    local nominal = max(6, (baseSize or 10) * (tonumber(settings.size) or 1))
    fontString:SetHeight(max(8, nominal * 1.15))
    return fontString:GetStringWidth() or 0
end

function UnitFrames:LayoutFrameText(frame)
    if not frame or not frame.nameText or not frame.healthText then return end

    local nameSize, descriptorSize, healthSize, powerSize = GetFrameTextSizes(frame)
    local nameShown = HasText(frame.nameText)
    local healthShown = HasText(frame.healthText)

    SetTextShown(frame.nameText, nameShown)
    SetTextShown(frame.healthText, healthShown)

    if frame.isMini then
        local available = max(36, (frame:GetWidth() or TOT_WIDTH) - 10)
        local gap = 5
        local nameWidth = available
        local healthWidth = available

        if nameShown and healthShown then
            local healthDesired = MeasureUnitFrameText(frame.healthText, healthSize) + 2
            healthWidth = min(healthDesired, available * 0.48)
            healthWidth = max(min(30, available * 0.35), healthWidth)
            nameWidth = max(18, available - gap - healthWidth)
        elseif nameShown then
            nameWidth = available
        elseif healthShown then
            healthWidth = available
        end

        if nameShown then FitUnitFrameText(frame.nameText, nameSize, nameWidth) end
        if healthShown then FitUnitFrameText(frame.healthText, healthSize, healthWidth) end
        return
    end

    local healthWidthTotal = frame.health and frame.health:GetWidth() or 0
    if not healthWidthTotal or healthWidthTotal < 40 then
        healthWidthTotal = frame:GetWidth() or FRAME_WIDTH
        if frame.portrait and frame.portrait:IsShown() then
            healthWidthTotal = healthWidthTotal - (frame.portraitSize or PORTRAIT_SIZE) - 2
        end
    end

    local available = max(40, healthWidthTotal - 12)
    local gap = 6
    local nameWidth = available
    local healthWidth = available
    local healthHeight = frame.health and frame.health:GetHeight() or HEALTH_HEIGHT
    -- Two-line health areas get independent vertical ceilings. This keeps a
    -- 120-150% text profile readable without letting the name/health row and
    -- level/class row collapse into each other.
    local topRowMaxFont = max(7, healthHeight * 0.39)
    local descriptorMaxFont = max(6, healthHeight * 0.30)

    if nameShown and healthShown then
        local healthDesired = MeasureUnitFrameText(frame.healthText, healthSize) + 3
        healthWidth = min(healthDesired, available * 0.48)
        healthWidth = max(min(36, available * 0.35), healthWidth)
        nameWidth = max(22, available - gap - healthWidth)
    elseif nameShown then
        nameWidth = available
    elseif healthShown then
        healthWidth = available
    end

    if nameShown then FitUnitFrameText(frame.nameText, nameSize, nameWidth, topRowMaxFont) end
    if healthShown then FitUnitFrameText(frame.healthText, healthSize, healthWidth, topRowMaxFont) end

    if frame.descriptorText then
        local descriptorShown = HasText(frame.descriptorText)
        SetTextShown(frame.descriptorText, descriptorShown)
        if descriptorShown then FitUnitFrameText(frame.descriptorText, descriptorSize, available, descriptorMaxFont) end
    end

    if frame.powerText then
        local powerShown = HasText(frame.powerText)
        SetTextShown(frame.powerText, powerShown)
        if powerShown then FitUnitFrameText(frame.powerText, powerSize, available) end
    end
end

function UnitFrames:LayoutAllText()
    local frames = { self.player, self.target, self.focus, self.pet }
    for i = 1, #frames do
        if frames[i] then self:LayoutFrameText(frames[i]) end
    end

    if self.targetTarget then self:LayoutFrameText(self.targetTarget) end
    if self.focusTarget then self:LayoutFrameText(self.focusTarget) end

    if self.partyFrames then
        for i = 1, PARTY_COUNT do
            if self.partyFrames[i] then self:LayoutFrameText(self.partyFrames[i]) end
        end
    end

    if self.partyPreviewStop then
        RUI:RefreshBackdrop(self.partyPreviewStop)
        RUI:StyleFontString(self.partyPreviewStop.RUIText, 9)
    end
    if self.raidPreviewStop then
        RUI:RefreshBackdrop(self.raidPreviewStop)
        RUI:StyleFontString(self.raidPreviewStop.RUIText, 9)
    end

    if self.raidFrames then
        for i = 1, RAID_MAX_MEMBERS do
            if self.raidFrames[i] then self:LayoutFrameText(self.raidFrames[i]) end
        end
    end
end

local function GetDisplayUnit(frame)
    if not frame then return nil end
    if frame.unit == "player" and UnitHasVehicleUI and UnitHasVehicleUI("player") and UnitExists and UnitExists("vehicle") then
        return "vehicle"
    end
    return frame.unit
end

function UnitFrames:UpdatePortrait(frame)
    if not frame or not frame.portrait or not frame.unit then return end
    if not RUI.db or not RUI.db.unitframes or not RUI.db.unitframes.showPortraits then
        frame.portrait:Hide()
        return
    end

    local unit = GetDisplayUnit(frame)
    if unit and UnitExists(unit) and SetPortraitTexture then
        SetPortraitTexture(frame.portrait.texture, unit)
        frame.portrait:Show()
    else
        frame.portrait:Hide()
    end
end

function UnitFrames:UpdateAuraButton(button, auraType, index)
    local unit = button and button.unit or "target"
    local name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable
    if auraType == "buff" then
        name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable = UnitBuff(unit, index)
    else
        name, rank, icon, count, debuffType, duration, expirationTime, caster = UnitDebuff(unit, index)
    end

    if not name or not icon then
        button:Hide()
        return false
    end

    button.auraIndex = index
    button.icon:SetTexture(icon)
    button:SetAlpha((caster == "player" or caster == "pet" or caster == "vehicle") and 1 or 0.82)

    if count and count > 1 then
        button.count:SetText(tostring(count))
        button.count:Show()
    else
        button.count:Hide()
    end

    if duration and duration > 0 and expirationTime and CooldownFrame_SetTimer then
        CooldownFrame_SetTimer(button.cooldown, expirationTime - duration, duration, 1)
        button.cooldown:Show()
    else
        button.cooldown:Hide()
    end

    if auraType == "debuff" then
        local color = DebuffTypeColor and DebuffTypeColor[debuffType or "none"]
        if color then
            RUI:SetBorderColor(button, color.r, color.g, color.b, 1)
        else
            RUI:RefreshBackdrop(button)
        end
    else
        local ar, ag, ab = RUI:GetAccentColor()
        if isStealable and UnitCanAttack("player", unit) then
            RUI:SetBorderColor(button, ar, ag, ab, 1)
        else
            RUI:RefreshBackdrop(button)
        end
    end

    button:Show()
    return true
end

local AURA_SETTING_KEYS = {
    player = { show = "showPlayerAuras", buffs = "playerBuffPosition", debuffs = "playerDebuffPosition" },
    target = { show = "showTargetAuras", buffs = "targetBuffPosition", debuffs = "targetDebuffPosition" },
    focus = { show = "showFocusAuras", buffs = "focusBuffPosition", debuffs = "focusDebuffPosition" },
    pet = { show = "showPetAuras", buffs = "petBuffPosition", debuffs = "petDebuffPosition" },
}

local function NormalizeAuraPosition(value, fallback)
    value = string.upper(tostring(value or fallback or "TOP"))
    if value == "BOTTOM" then return "BOTTOM" end
    return "TOP"
end

function UnitFrames:UpdateUnitAuras(unit)
    local container = self.auraContainers and self.auraContainers[unit]
    local settings = RUI.db and RUI.db.unitframes
    local keys = AURA_SETTING_KEYS[unit]
    local allowed = container and self.active and settings and settings.enabled and keys and settings[keys.show] and UnitExists(unit)
    if unit == "focus" and settings and settings.showFocus == false then allowed = false end
    if unit == "pet" and settings and settings.showPet == false then allowed = false end

    if not allowed then
        if container then container:Hide() end
        return
    end

    for i = 1, container.maxAuras or MAX_AURAS_PER_ROW do
        self:UpdateAuraButton(container.debuffs[i], "debuff", i)
        self:UpdateAuraButton(container.buffs[i], "buff", i)
    end
    container:Show()
end

function UnitFrames:UpdateAuras()
    self:UpdateUnitAuras("player")
    self:UpdateUnitAuras("target")
    self:UpdateUnitAuras("focus")
    self:UpdateUnitAuras("pet")
end

function UnitFrames:LayoutAuraContainer(unit, frame, bottomAnchor, bottomX)
    local container = self.auraContainers and self.auraContainers[unit]
    local settings = RUI.db and RUI.db.unitframes
    local keys = AURA_SETTING_KEYS[unit]
    if not container or not frame or not settings or not keys then return end

    local buffRow = container.buffRow
    local debuffRow = container.debuffRow
    buffRow:ClearAllPoints()
    debuffRow:ClearAllPoints()

    local buffPosition = NormalizeAuraPosition(settings[keys.buffs], unit == "target" and "TOP" or "TOP")
    local debuffPosition = NormalizeAuraPosition(settings[keys.debuffs], "BOTTOM")

    -- Buffs sit closest to the unit frame on the top edge. If both aura types
    -- share the top edge, debuffs stack outward above the buff row.
    local topAnchor = frame
    local topUsed = false
    if buffPosition == "TOP" then
        buffRow:SetPoint("BOTTOMLEFT", topAnchor, "TOPLEFT", 0, topUsed and AURA_SPACING or 3)
        topAnchor = buffRow
        topUsed = true
    end
    if debuffPosition == "TOP" then
        debuffRow:SetPoint("BOTTOMLEFT", topAnchor, "TOPLEFT", 0, topUsed and AURA_SPACING or 3)
        topAnchor = debuffRow
        topUsed = true
    end

    -- Debuffs sit closest on the bottom edge. Bottom means below any attached
    -- cast/resource/target-of-target element so aura icons never cover it.
    local lowerAnchor = bottomAnchor or frame
    local lowerX = tonumber(bottomX) or 0
    local bottomUsed = false
    if debuffPosition == "BOTTOM" then
        debuffRow:SetPoint("TOPLEFT", lowerAnchor, "BOTTOMLEFT", lowerX, bottomUsed and -AURA_SPACING or -3)
        lowerAnchor = debuffRow
        bottomUsed = true
    end
    if buffPosition == "BOTTOM" then
        buffRow:SetPoint("TOPLEFT", lowerAnchor, "BOTTOMLEFT", bottomUsed and 0 or lowerX, bottomUsed and -AURA_SPACING or -3)
    end
end

function UnitFrames:UpdateClassResources()
    local resource = self.classResource
    local settings = RUI.db and RUI.db.unitframes
    if not resource or not self.active or not settings or not settings.enabled or not settings.showClassResources or not self.resourceKind then
        if resource then resource:Hide() end
        return
    end

    local count = self.resourceKind == "runes" and 6 or 5
    local width = (FRAME_WIDTH - ((count - 1) * RESOURCE_SPACING)) / count

    for i = 1, 6 do
        local segment = resource.segments[i]
        segment:ClearAllPoints()
        if i <= count then
            segment:SetWidth(width)
            segment:SetPoint("TOPLEFT", resource, "TOPLEFT", (i - 1) * (width + RESOURCE_SPACING), 0)
            segment:Show()
            RUI:RefreshBackdrop(segment)
        else
            segment:Hide()
        end
    end

    if self.resourceKind == "combo" then
        if not UnitExists("target") then
            resource:Hide()
            return
        end

        local points = 0
        if GetComboPoints then
            local ok, value = pcall(GetComboPoints, "player", "target")
            if ok then
                points = value or 0
            else
                local fallbackOK, fallbackValue = pcall(GetComboPoints)
                if fallbackOK then points = fallbackValue or 0 end
            end
        end

        if self.playerClass == "DRUID" then
            local _, powerToken = UnitPowerType("player")
            if powerToken ~= "ENERGY" and points <= 0 then
                resource:Hide()
                return
            end
        end
        local ar, ag, ab = RUI:GetAccentColor()
        local innerWidth = max(1, width - 2)
        for i = 1, 5 do
            local segment = resource.segments[i]
            local fill = segment.fill
            segment.track:SetTexture(ar, ag, ab, 0.10)
            fill:SetWidth(innerWidth)
            fill:Show()
            if i <= points then
                fill:SetTexture(ar, ag, ab, 1)
            else
                fill:SetTexture(ar, ag, ab, 0.16)
            end
        end
        resource:Show()
        return
    end

    if self.resourceKind == "runes" then
        local now = GetTime()
        local innerWidth = max(1, width - 2)

        for i = 1, 6 do
            local segment = resource.segments[i]
            local runeType = GetRuneType and GetRuneType(i) or segment.runeType or 4
            runeType = runeType or segment.runeType or 4
            segment.runeType = runeType

            local color = runeColors[runeType] or runeColors[4]
            local progress = 1
            local ready = true

            if GetRuneCooldown then
                local startTime, duration, runeReady = GetRuneCooldown(i)

                -- runeReady is the important 3.3.5 signal. Ready runes can still
                -- expose short GCD timing; that timing must not drain/dim the slot.
                if runeReady == false or runeReady == 0 then
                    ready = false
                    startTime = tonumber(startTime) or 0
                    duration = tonumber(duration) or 0

                    if startTime > 0 and duration > 0 then
                        progress = Clamp((now - startTime) / duration, 0, 1)
                    else
                        progress = 0
                    end
                elseif runeReady == nil then
                    -- Defensive fallback for unusual 3.3.5 cores: a zero start time
                    -- means ready; a real cooldown start means independently recharging.
                    startTime = tonumber(startTime) or 0
                    duration = tonumber(duration) or 0
                    if startTime > 0 and duration > 1.5 then
                        ready = false
                        progress = Clamp((now - startTime) / duration, 0, 1)
                    end
                end
            end

            if ready then
                progress = 1
            end

            segment.rechargeProgress = progress
            segment.track:SetTexture(0.16, 0.16, 0.16, 0.95)
            segment.fill:SetTexture(color[1], color[2], color[3], 1)

            if progress <= 0 then
                segment.fill:Hide()
            else
                segment.fill:SetWidth(max(1, innerWidth * progress))
                segment.fill:Show()
            end
        end

        resource:Show()
    end
end

local function IsGroupLeaderUnit(unit, raidIndex)
    -- Raid leadership is authoritative from the raid roster rank. Rank 2 is
    -- the one raid leader; rank 1 is assistant and must never receive a crown.
    if raidIndex and GetRaidRosterInfo then
        local name, rank = GetRaidRosterInfo(raidIndex)
        if name then return tonumber(rank) == 2 end
    end

    if unit and UnitInRaid and GetRaidRosterInfo then
        local rosterIndex = UnitInRaid(unit)
        if rosterIndex then
            local name, rank = GetRaidRosterInfo(rosterIndex)
            if name then return tonumber(rank) == 2 end
        end
    end

    -- In a normal party there must be exactly one leader. Prefer
    -- GetPartyLeaderIndex because several private 3.3.5 cores can leave
    -- UnitIsPartyLeader() stale on a previous leader after leadership changes.
    -- GetPartyLeaderIndex returns 0 for the player and 1..4 for partyN.
    local partyCount = (GetNumPartyMembers and GetNumPartyMembers()) or 0
    if partyCount > 0 and GetPartyLeaderIndex then
        local leaderIndex = tonumber(GetPartyLeaderIndex())
        if leaderIndex ~= nil then
            if unit == "player" then
                return leaderIndex == 0
            end
            local partyIndex = unit and string.match(unit, "^party(%d+)$")
            if partyIndex then
                return leaderIndex == tonumber(partyIndex)
            end
            return false
        end
    end

    -- Last-resort compatibility only when the authoritative party index API is
    -- genuinely unavailable. Never combine this result with a valid index.
    if unit and UnitIsPartyLeader then
        local ok, leader = pcall(UnitIsPartyLeader, unit)
        if ok then return leader and true or false end
    end

    return false
end

function UnitFrames:UpdateGroupLeaderIndicator(frame)
    if not frame or not frame.leaderIcon or not frame.unit then return end
    SetGroupLeaderIcon(frame, IsGroupLeaderUnit(frame.unit, frame.raidIndex))
end

function UnitFrames:UpdateFrame(frame)
    if not frame or not frame.unit then return end
    local unit = GetDisplayUnit(frame)
    if not unit or not UnitExists(unit) then return end

    local health = UnitHealth(unit) or 0
    local maxHealth = UnitHealthMax(unit) or 0
    local power, maxPower = GetLivePowerValues(unit)

    if frame.isParty then CacheGroupPollState(frame, health, maxHealth, power, maxPower) end
    local preserveGroupValues = frame.isParty and ShouldPreserveGroupValues(unit)
    SetNormalizedBarValue(frame.health, health, maxHealth, preserveGroupValues)
    local hr, hg, hb = GetHealthColor(unit)
    frame.health:SetFillColor(hr, hg, hb, 0.90)

    SetNormalizedBarValue(frame.power, power, maxPower, preserveGroupValues)
    local pr, pg, pb = GetPowerColor(unit)
    frame.power:SetFillColor(pr, pg, pb, 0.88)

    local textSettings = GetTextSettings() or {}
    frame.nameText:SetText(textSettings.showName == false and "" or (UnitName(unit) or "Unknown"))
    frame.descriptorText:SetText(GetUnitDescriptor(unit))
    frame.healthText:SetText(GetHealthText(unit, health, maxHealth))
    frame.powerText:SetText(GetPowerText(power, maxPower))

    self:UpdatePortrait(frame)
    self:LayoutFrameText(frame)
    if frame.leaderIcon then self:UpdateGroupLeaderIndicator(frame) end
    if frame.isParty then
        self:UpdateGroupRangeState(frame)
    end
end

function UnitFrames:UpdateMiniFrame(frame)
    if not frame or not frame.unit or not UnitExists(frame.unit) then
        return
    end

    local unit = frame.unit
    local health = UnitHealth(unit) or 0
    local maxHealth = UnitHealthMax(unit) or 0
    SetNormalizedBarValue(frame.health, health, maxHealth)
    local r, g, b = GetHealthColor(unit)
    frame.health:SetFillColor(r, g, b, 0.88)
    local textSettings = GetTextSettings() or {}
    frame.nameText:SetText(textSettings.showName == false and "" or (UnitName(unit) or ""))
    frame.healthText:SetText(GetHealthText(unit, health, maxHealth))
    self:LayoutFrameText(frame)
end



local function IsInRaidGroup()
    local count = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    if count and count > 0 then return true, count end

    if UnitInRaid then
        local playerIndex = UnitInRaid("player")
        if playerIndex then return true, count or 0 end
    end

    -- A few 3.3.5 private-server cores can lag GetNumRaidMembers()/UnitInRaid
    -- during the roster transition even though raid unit tokens already exist.
    -- Treat any live raidN token as authoritative so Zen frames still appear.
    if UnitExists then
        for i = 1, RAID_MAX_MEMBERS do
            if UnitExists("raid" .. tostring(i)) then
                return true, count or 0
            end
        end
    end

    return false, count or 0
end

local function GetRaidRosterEntry(index)
    local unit = "raid" .. tostring(index)
    -- In Blizzard 3.3.5 the raidN token corresponds directly to raid roster
    -- index N.  Some private-server implementations return a boolean-like 1
    -- from UnitInRaid(unit) instead of the roster index, so never remap raidN
    -- through UnitInRaid here.
    local rosterIndex = index

    local name, rank, subgroup, level, class, classToken, zone, online, isDead, role, isML
    if GetRaidRosterInfo then
        name, rank, subgroup, level, class, classToken, zone, online, isDead, role, isML = GetRaidRosterInfo(rosterIndex)
    end

    -- UnitName is a secondary fallback only; roster data remains authoritative
    -- for subgroup/rank even on cores where UnitExists(raidN) lags behind.
    if not name and UnitName then
        name = UnitName(unit)
    end
    if name and not subgroup then
        subgroup = floor((index - 1) / RAID_MEMBERS_PER_GROUP) + 1
    end

    return name, rank, tonumber(subgroup), level, class, classToken, zone, online, isDead, role, isML, rosterIndex
end

function UnitFrames:SetRaidFrameActive(frame, enabled)
    if not frame then return end

    -- Raid visibility is driven by the roster entry, not UnitExists("raidN").
    -- A number of 3.3.5 private-server cores expose GetRaidRosterInfo() before
    -- (or more reliably than) UnitExists() for raid unit tokens. The secure
    -- button still keeps its fixed raidN unit attribute for targeting/clicks.
    if frame.ruiUnitWatch and UnregisterUnitWatch then
        UnregisterUnitWatch(frame)
    end
    frame.ruiUnitWatch = nil

    if enabled then
        frame:Show()
    else
        frame:Hide()
    end
end

function UnitFrames:GetGroupRosterSignature()
    local inRaid, count = IsInRaidGroup()
    local parts = {}

    if inRaid then
        parts[1] = "RAID"
        parts[2] = tostring(count or 0)
        for i = 1, RAID_MAX_MEMBERS do
            -- Track the roster API directly. This lets the watcher notice when
            -- GetRaidRosterInfo() becomes populated even if UnitExists(raidN)
            -- is still lagging on a private-server core.
            local name, _, subgroup = GetRaidRosterEntry(i)
            if name then
                parts[#parts + 1] = tostring(i) .. "=" .. tostring(name) .. "@" .. tostring(subgroup or 0)
            end
        end
    else
        parts[1] = "PARTY"
        for i = 1, PARTY_COUNT do
            local unit = "party" .. tostring(i)
            if UnitExists and UnitExists(unit) then
                parts[#parts + 1] = tostring(i) .. "=" .. tostring(UnitName(unit) or "?")
            end
        end
    end

    return concat(parts, "|")
end

local function GetRaidSettings()
    local settings = RUI.db and RUI.db.unitframes
    return settings and settings.raid or nil
end

local function GetRaidHealthText(unit, health, maxHealth)
    local raid = GetRaidSettings() or {}
    if UnitIsConnected and not UnitIsConnected(unit) then return "OFF" end
    if UnitIsDead and UnitIsDead(unit) then return "DEAD" end
    if UnitIsGhost and UnitIsGhost(unit) then return "GHOST" end

    local mode = raid.healthMode or "PERCENT"
    if mode == "NONE" or maxHealth <= 0 then return "" end
    if mode == "CURRENT" then return ShortValue(health) end
    if mode == "DEFICIT" then
        local deficit = max(0, maxHealth - health)
        return deficit > 0 and ("-" .. ShortValue(deficit)) or ""
    end
    return tostring(floor((health / maxHealth) * 100 + 0.5)) .. "%"
end

local PREVIEW_NAMES = {
    "Zen", "Gnocchi", "Tortellini", "Penne", "Rigatoni",
    "Fusilli", "Orzo", "Lasagne", "Farfalle", "Linguine",
}
local PREVIEW_CLASSES = {
    { "Warrior", 0.78, 0.61, 0.43 },
    { "Mage", 0.41, 0.80, 0.94 },
    { "Paladin", 0.96, 0.55, 0.73 },
    { "Druid", 1.00, 0.49, 0.04 },
    { "Priest", 0.95, 0.95, 0.95 },
    { "Rogue", 1.00, 0.96, 0.41 },
    { "Shaman", 0.00, 0.44, 0.87 },
    { "Warlock", 0.58, 0.51, 0.79 },
    { "Hunter", 0.67, 0.83, 0.45 },
    { "Death Knight", 0.77, 0.12, 0.23 },
}

local function HasLivePartyMembers()
    return UnitExists and UnitExists("party1") and true or false
end

local function PreviewName(index)
    local base = PREVIEW_NAMES[((index - 1) % #PREVIEW_NAMES) + 1]
    if index > #PREVIEW_NAMES then
        return base .. tostring(floor((index - 1) / #PREVIEW_NAMES) + 1)
    end
    return base
end

local function PreviewClass(index)
    return PREVIEW_CLASSES[((index - 1) % #PREVIEW_CLASSES) + 1]
end

local function PreviewHealthText(health, maxHealth)
    local settings = GetTextSettings() or {}
    local parts = {}
    if settings.showHealthValue ~= false then parts[#parts + 1] = ShortValue(health) end
    if settings.showHealthPercent ~= false and maxHealth > 0 then
        parts[#parts + 1] = tostring(floor((health / maxHealth) * 100 + 0.5)) .. "%"
    end
    return concat(parts, "  ")
end

local function PreviewPowerText(power, maxPower)
    local settings = GetTextSettings() or {}
    if settings.showPowerValue == false and settings.showPowerMax == false then return "" end
    if settings.showPowerValue ~= false and settings.showPowerMax ~= false then
        return ShortValue(power) .. " / " .. ShortValue(maxPower)
    elseif settings.showPowerValue ~= false then
        return ShortValue(power)
    end
    return "max " .. ShortValue(maxPower)
end

local function PreviewRaidHealthText(health, maxHealth)
    local raid = GetRaidSettings() or {}
    local mode = raid.healthMode or "PERCENT"
    if mode == "NONE" or maxHealth <= 0 then return "" end
    if mode == "CURRENT" then return ShortValue(health) end
    if mode == "DEFICIT" then
        local deficit = max(0, maxHealth - health)
        return deficit > 0 and ("-" .. ShortValue(deficit)) or ""
    end
    return tostring(floor((health / maxHealth) * 100 + 0.5)) .. "%"
end

local function CreateGroupPreviewStopButton(kind, relativeFrame)
    local button = CreateFrame("Button", nil, UIParent)
    button:SetWidth(92)
    button:SetHeight(20)
    button:SetFrameStrata("DIALOG")
    button:SetClampedToScreen(true)
    button:SetPoint("BOTTOMLEFT", relativeFrame, "TOPLEFT", 0, 6)

    button.RUIText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.RUIText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.RUIText:SetText("Stop Preview")
    RUI:StyleButton(button)
    RUI:StyleFontString(button.RUIText, 9)

    button:SetScript("OnClick", function()
        if UnitFrames:SetGroupPreview(kind, false) then
            local config = RUI:GetModule("Config")
            if config and config.Refresh then config:Refresh() end
        end
    end)
    button:Hide()
    return button
end


function UnitFrames:UpdatePartyPreviewFrame(frame, index)
    if not frame then return end
    local class = PreviewClass(index)
    local ratio = 0.58 + (((index * 13) % 38) / 100)
    local maxHealth = 24000 + (index * 4200)
    local health = floor(maxHealth * min(1, ratio) + 0.5)
    local maxPower = 10000 + (index * 900)
    local power = floor(maxPower * (0.28 + (((index * 17) % 58) / 100)) + 0.5)

    SetNormalizedBarValue(frame.health, health, maxHealth, false)
    frame.health:SetFillColor(class[2], class[3], class[4], 0.90)
    SetNormalizedBarValue(frame.power, power, maxPower, false)
    frame.power:SetFillColor(0.10, 0.35, 0.92, 0.88)

    local settings = GetTextSettings() or {}
    frame.nameText:SetText(settings.showName == false and "" or PreviewName(index))
    local descriptor = {}
    if settings.showLevel ~= false then descriptor[#descriptor + 1] = "80" end
    if settings.showClass ~= false then descriptor[#descriptor + 1] = class[1] end
    frame.descriptorText:SetText(concat(descriptor, "  "))
    frame.healthText:SetText(PreviewHealthText(health, maxHealth))
    frame.powerText:SetText(PreviewPowerText(power, maxPower))
    SetGroupLeaderIcon(frame, index == 1)

    if frame.portrait then
        if RUI.db and RUI.db.unitframes and RUI.db.unitframes.showPortraits then
            frame.portrait.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            frame.portrait:Show()
        else
            frame.portrait:Hide()
        end
    end
    if frame.health then frame.health:SetAlpha(1) end
    if frame.power then frame.power:SetAlpha(1) end
    if frame.textOverlay then frame.textOverlay:SetAlpha(1) end
    if frame.portrait then frame.portrait:SetAlpha(1) end
    self:LayoutFrameText(frame)
end

function UnitFrames:UpdateRaidPreviewFrame(frame, index)
    if not frame then return end
    local class = PreviewClass(index)
    local maxHealth = 26000 + ((index % 5) * 6200)
    local ratio = 0.52 + (((index * 11) % 46) / 100)
    local health = floor(maxHealth * min(1, ratio) + 0.5)
    local maxPower = 100
    local power = (index * 17) % 100

    SetNormalizedBarValue(frame.health, health, maxHealth, false)
    frame.health:SetFillColor(class[2], class[3], class[4], 0.90)
    SetNormalizedBarValue(frame.power, power, maxPower, false)
    frame.power:SetFillColor(0.10, 0.35, 0.92, 0.88)

    local settings = GetTextSettings() or {}
    frame.nameText:SetText(settings.showName == false and "" or PreviewName(index))
    frame.healthText:SetText(PreviewRaidHealthText(health, maxHealth))
    local previewShowRank = (GetRaidSettings() or {}).showRank ~= false
    SetGroupLeaderIcon(frame, previewShowRank and index == 1)
    frame.rankText:SetText(previewShowRank and index == 2 and "A" or "")

    local raid = GetRaidSettings() or {}
    if raid.showReady ~= false and index == 3 then
        frame.ready:SetTexture(0.20, 0.85, 0.30, 1)
        frame.ready:Show()
    else
        frame.ready:Hide()
    end
    if raid.showDebuffs ~= false and index == 4 then
        frame.debuff:SetTexture(0.70, 0.20, 0.80, 1)
        frame.debuff:Show()
    else
        frame.debuff:Hide()
    end
    if frame.health then frame.health:SetAlpha(1) end
    if frame.power then frame.power:SetAlpha(1) end
    if frame.textOverlay then frame.textOverlay:SetAlpha(1) end
    self:LayoutFrameText(frame)
end

function UnitFrames:SetGroupPreview(kind, enabled)
    if InCombatLockdown and InCombatLockdown() then
        RUI:Print("Group previews cannot be changed during combat.")
        return false
    end

    local inRaid = IsInRaidGroup()
    local inParty = HasLivePartyMembers()

    if kind == "party" then
        if enabled and (inRaid or inParty) then
            RUI:Print("Party preview is unnecessary while a real group is available.")
            enabled = false
        end
        self.previewParty = enabled and true or nil
        if enabled then self.previewRaid = nil end
    elseif kind == "raid" then
        if enabled and inRaid then
            RUI:Print("Raid preview is unnecessary while a real raid is available.")
            enabled = false
        end
        self.previewRaid = enabled and true or nil
        if enabled then self.previewParty = nil end
    elseif kind == "all" then
        self.previewParty = nil
        self.previewRaid = nil
    else
        return false
    end

    self:RefreshGroupRoster()
    self:ApplyAppearance()
    return true
end

function UnitFrames:ToggleGroupPreview(kind)
    if kind == "party" then
        return self:SetGroupPreview("party", not self.previewParty)
    elseif kind == "raid" then
        return self:SetGroupPreview("raid", not self.previewRaid)
    end
    return false
end

function UnitFrames:ApplyRaidFrameLayout(frame)
    if not frame or not frame.isRaid then return end
    local raid = GetRaidSettings() or {}
    frame.health:ClearAllPoints()
    frame.power:ClearAllPoints()

    if raid.showPower ~= false then
        frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.health:SetHeight(RAID_HEALTH_HEIGHT)
        frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        frame.power:SetHeight(RAID_POWER_HEIGHT)
        frame.power:Show()
    else
        frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        frame.power:Hide()
    end

    if frame.health and frame.health.SetRatio then frame.health:SetRatio(frame.health.ratio or 0) end
    if frame.power and frame.power.SetRatio then frame.power:SetRatio(frame.power.ratio or 0) end
end

function UnitFrames:UpdateRaidIndicators(frame)
    if not frame or not frame.isRaid then return end
    local raid = GetRaidSettings() or {}
    local name, rank = GetRaidRosterEntry(frame.raidIndex)

    if raid.showRank ~= false and name then
        if rank == 2 then
            SetGroupLeaderIcon(frame, true)
            frame.rankText:SetText("")
        elseif rank == 1 then
            SetGroupLeaderIcon(frame, false)
            frame.rankText:SetText("A")
        else
            SetGroupLeaderIcon(frame, false)
            frame.rankText:SetText("")
        end
    else
        SetGroupLeaderIcon(frame, false)
        frame.rankText:SetText("")
    end

    if raid.showReady ~= false and GetReadyCheckStatus then
        local ready = GetReadyCheckStatus(frame.unit)
        if ready == "ready" then
            frame.ready:SetTexture(0.20, 0.85, 0.30, 1)
            frame.ready:Show()
        elseif ready == "notready" then
            frame.ready:SetTexture(0.90, 0.20, 0.20, 1)
            frame.ready:Show()
        elseif ready == "waiting" then
            frame.ready:SetTexture(0.90, 0.75, 0.20, 1)
            frame.ready:Show()
        else
            frame.ready:Hide()
        end
    else
        frame.ready:Hide()
    end
end

function UnitFrames:UpdateRaidDebuff(frame)
    if not frame or not frame.isRaid then return end
    local raid = GetRaidSettings() or {}
    if raid.showDebuffs == false or not UnitExists(frame.unit) then
        frame.debuff:Hide()
        return
    end

    for i = 1, 16 do
        local name, _, _, _, debuffType = UnitDebuff(frame.unit, i)
        if not name then break end
        local color = DebuffTypeColor and DebuffTypeColor[debuffType or "none"]
        if color then
            frame.debuff:SetTexture(color.r, color.g, color.b, 1)
        else
            local ar, ag, ab = RUI:GetAccentColor()
            frame.debuff:SetTexture(ar, ag, ab, 1)
        end
        frame.debuff:Show()
        return
    end
    frame.debuff:Hide()
end

function UnitFrames:UpdateGroupRangeState(frame)
    if not frame or not frame.unit then return end

    local outOfRange = IsGroupUnitOutOfRange(frame.unit)
    local barAlpha = outOfRange and GROUP_RANGE_BAR_ALPHA or 1
    local textAlpha = outOfRange and GROUP_RANGE_TEXT_ALPHA or 1
    local portraitAlpha = outOfRange and GROUP_RANGE_PORTRAIT_ALPHA or 1

    -- Do not fade the protected SecureUnitButton itself, and do not fade the
    -- whole health/power frames.  The latter also fades their black background,
    -- causing class colors to visually disappear into Zen's dark backdrop.
    -- Fade only the owned colored fills plus text/portrait indicators instead.
    -- Reapply this every range refresh rather than short-circuiting on the
    -- cached state; appearance/layout refreshes can replace texture state while
    -- the unit's range result itself has not changed.
    if frame.health then
        frame.health:SetAlpha(1)
        if frame.health.RepairFillVisual then frame.health:RepairFillVisual() end
        if frame.health.fill then frame.health.fill:SetAlpha(barAlpha) end
        if frame.health.background then frame.health.background:SetAlpha(1) end
    end
    if frame.power then
        frame.power:SetAlpha(1)
        if frame.power.RepairFillVisual then frame.power:RepairFillVisual() end
        if frame.power.fill then frame.power.fill:SetAlpha(barAlpha) end
        if frame.power.background then frame.power.background:SetAlpha(1) end
    end
    if frame.textOverlay then frame.textOverlay:SetAlpha(textAlpha) end
    if frame.portrait then frame.portrait:SetAlpha(portraitAlpha) end
    if frame.separator then frame.separator:SetAlpha(textAlpha) end

    frame.ruiOutOfRange = outOfRange
end

function UnitFrames:UpdateRaidFrame(frame)
    if not frame or not frame.unit then return end

    local inRaid = IsInRaidGroup()
    if self.previewRaid and not inRaid then
        self:UpdateRaidPreviewFrame(frame, frame.raidIndex or 1)
        return
    end

    local unit = frame.unit
    local rosterName, _, _, _, _, rosterClassToken = GetRaidRosterEntry(frame.raidIndex)
    local liveName = UnitName and UnitName(unit)
    local name = liveName or rosterName
    if not name then return end

    -- Do not require UnitExists() here. On some 3.3.5 private-server cores
    -- roster metadata is valid while UnitExists("raidN") temporarily reports
    -- false. UnitHealth/UnitPower safely return 0 until the token catches up.
    local health = (UnitHealth and UnitHealth(unit)) or 0
    local maxHealth = (UnitHealthMax and UnitHealthMax(unit)) or 0
    local power = (UnitPower and UnitPower(unit)) or 0
    local maxPower = (UnitPowerMax and UnitPowerMax(unit)) or 0

    CacheGroupPollState(frame, health, maxHealth, power, maxPower)
    local preserveGroupValues = ShouldPreserveGroupValues(unit)
    SetNormalizedBarValue(frame.health, health, maxHealth, preserveGroupValues)
    local hr, hg, hb = GetHealthColor(unit)
    if rosterClassToken and UnitClass then
        local _, liveClassToken = UnitClass(unit)
        if not liveClassToken then
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[rosterClassToken]
            if color then hr, hg, hb = color.r, color.g, color.b end
        end
    end
    frame.health:SetFillColor(hr, hg, hb, 0.90)

    SetNormalizedBarValue(frame.power, power, maxPower, preserveGroupValues)
    local pr, pg, pb = GetPowerColor(unit)
    frame.power:SetFillColor(pr, pg, pb, 0.88)

    local textSettings = GetTextSettings() or {}
    frame.nameText:SetText(textSettings.showName == false and "" or name)
    frame.healthText:SetText(GetRaidHealthText(unit, health, maxHealth))
    self:LayoutFrameText(frame)
    self:UpdateRaidIndicators(frame)
    self:UpdateGroupRangeState(frame)
end

function UnitFrames:UpdateRaidFrames()
    if not self.raidFrames then return end
    for i = 1, RAID_MAX_MEMBERS do
        local frame = self.raidFrames[i]
        if frame and frame:IsShown() then
            self:UpdateRaidFrame(frame)
        end
    end
end

function UnitFrames:UpdateRaidDebuffs()
    if not self.raidFrames then return end
    for i = 1, RAID_MAX_MEMBERS do
        local frame = self.raidFrames[i]
        if frame and UnitExists(frame.unit) then self:UpdateRaidDebuff(frame) end
    end
end

function UnitFrames:LayoutRaidFrames()
    if not self.raidAnchor or not self.raidFrames or not RUI.db or not RUI.db.unitframes then return false end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingRaidLayout = true
        return false
    end

    self.pendingRaidLayout = nil
    local settings = RUI.db.unitframes
    local raid = settings.raid or {}
    local groups = Clamp(tonumber(raid.groups) or 5, 1, RAID_MAX_GROUPS)
    local orientation = raid.orientation or "HORIZONTAL"
    local inRaid = IsInRaidGroup()
    local usePreview = self.previewRaid and not inRaid
    local counts = {}
    for g = 1, RAID_MAX_GROUPS do counts[g] = 0 end

    -- Ebonhold can report unreliable subgroup numbers to non-leaders.  In the
    -- wild this has produced 10-player raids split 5/4/1 and even >5 members
    -- assigned to GROUP 1.  The raid roster itself remains stable and ordered,
    -- so lay the visible raid out in deterministic five-player blocks.  This
    -- mirrors the normal raid roster grouping and, unlike the subgroup field,
    -- does not change depending on raid permissions.
    local packedIndex = 0

    for i = 1, RAID_MAX_MEMBERS do
        local frame = self.raidFrames[i]
        local name, subgroup
        if usePreview and i <= (groups * RAID_MEMBERS_PER_GROUP) then
            name = PreviewName(i)
            packedIndex = packedIndex + 1
            subgroup = floor((packedIndex - 1) / RAID_MEMBERS_PER_GROUP) + 1
        else
            name = GetRaidRosterEntry(i)
            if name then
                packedIndex = packedIndex + 1
                subgroup = floor((packedIndex - 1) / RAID_MEMBERS_PER_GROUP) + 1
            end
        end

        frame.ruiSubgroup = subgroup
        frame:ClearAllPoints()

        if (settings.showRaid or usePreview) and name and subgroup and subgroup >= 1 and subgroup <= groups then
            counts[subgroup] = counts[subgroup] + 1
            local slot = counts[subgroup]
            local x, y
            if orientation == "VERTICAL" then
                -- Rows mode: members run horizontally inside each subgroup.
                local rowStride = RAID_GROUP_LABEL_HEIGHT + RAID_FRAME_HEIGHT + RAID_GROUP_SPACING
                x = (slot - 1) * (RAID_FRAME_WIDTH + RAID_MEMBER_SPACING)
                y = -((subgroup - 1) * rowStride) - RAID_GROUP_LABEL_HEIGHT
            else
                x = (subgroup - 1) * (RAID_FRAME_WIDTH + RAID_GROUP_SPACING)
                y = -RAID_GROUP_LABEL_HEIGHT - ((slot - 1) * (RAID_FRAME_HEIGHT + RAID_MEMBER_SPACING))
            end
            frame:SetPoint("TOPLEFT", self.raidAnchor, "TOPLEFT", x, y)
            self:SetRaidFrameActive(frame, true)
            if usePreview then self:UpdateRaidPreviewFrame(frame, i) end
        else
            frame.ruiSubgroup = nil
            self:SetRaidFrameActive(frame, false)
        end
    end

    local labelEnabled = raid.showGroupLabels ~= false
    for g = 1, RAID_MAX_GROUPS do
        local label = self.raidGroupLabels[g]
        label:SetText("GROUP " .. tostring(g))
        label:ClearAllPoints()
        if orientation == "VERTICAL" then
            local rowStride = RAID_GROUP_LABEL_HEIGHT + RAID_FRAME_HEIGHT + RAID_GROUP_SPACING
            label:SetPoint("TOPLEFT", self.raidAnchor, "TOPLEFT", 2, -((g - 1) * rowStride))
        else
            label:SetPoint("TOPLEFT", self.raidAnchor, "TOPLEFT", (g - 1) * (RAID_FRAME_WIDTH + RAID_GROUP_SPACING) + 2, -1)
        end
        if labelEnabled and g <= groups and counts[g] > 0 then label:Show() else label:Hide() end
    end

    -- Size to the groups that actually exist in a raid, while retaining the
    -- configured maximum as the solo/mover preview footprint. This means a
    -- normal 10-player raid naturally occupies two groups and a 25-player raid
    -- five groups without requiring separate presets.
    local activeGroups = 0
    for g = 1, groups do
        if counts[g] > 0 then activeGroups = g end
    end
    if activeGroups == 0 then activeGroups = groups end

    local width, height
    if orientation == "VERTICAL" then
        width = (RAID_FRAME_WIDTH * RAID_MEMBERS_PER_GROUP) + (RAID_MEMBER_SPACING * (RAID_MEMBERS_PER_GROUP - 1))
        height = activeGroups * (RAID_GROUP_LABEL_HEIGHT + RAID_FRAME_HEIGHT) + ((activeGroups - 1) * RAID_GROUP_SPACING)
    else
        width = activeGroups * RAID_FRAME_WIDTH + ((activeGroups - 1) * RAID_GROUP_SPACING)
        height = RAID_GROUP_LABEL_HEIGHT + (RAID_FRAME_HEIGHT * RAID_MEMBERS_PER_GROUP) + (RAID_MEMBER_SPACING * (RAID_MEMBERS_PER_GROUP - 1))
    end
    self.raidAnchor:SetWidth(width)
    self.raidAnchor:SetHeight(height)

    local scale = RUI:GetEffectiveScale("raid")
    RUI:UpdateMoverSize("RaidFrames", width * scale, height * scale)
    return true
end

function UnitFrames:UpdateGroupVisibility()
    if not RUI.db or not RUI.db.unitframes then return end
    local settings = RUI.db.unitframes
    local inRaid = IsInRaidGroup()
    local hasParty = HasLivePartyMembers()
    local partyPreview = self.previewParty and not inRaid and not hasParty
    local raidPreview = self.previewRaid and not inRaid

    if self.partyAnchor then
        if (settings.showParty and not inRaid and hasParty) or partyPreview then self.partyAnchor:Show() else self.partyAnchor:Hide() end
    end
    RUI:SetMoverEnabled("PartyFrames", (settings.showParty and not inRaid) or partyPreview)

    if self.raidAnchor then
        if (settings.showRaid and inRaid) or raidPreview then self.raidAnchor:Show() else self.raidAnchor:Hide() end
    end
    RUI:SetMoverEnabled("RaidFrames", settings.showRaid or raidPreview)

    -- Preview escape buttons live beside the preview itself so the user does not
    -- need to reopen /zenui just to dismiss a temporary Party/Raid preview.
    if self.partyPreviewStop then
        if partyPreview then self.partyPreviewStop:Show() else self.partyPreviewStop:Hide() end
    end
    if self.raidPreviewStop then
        if raidPreview then self.raidPreviewStop:Show() else self.raidPreviewStop:Hide() end
    end
end


function UnitFrames:RefreshGroupRoster()
    if not self.active or not RUI.db or not RUI.db.unitframes then return false end

    if InCombatLockdown and InCombatLockdown() then
        -- RegisterUnitWatch keeps already-configured secure frames safe in combat.
        -- Any structural roster repair is completed the moment combat ends.
        self.pendingGroupRefresh = true
        self:UpdatePartyFrames()
        self:UpdateRaidFrames()
        self:UpdateRaidDebuffs()
        return false
    end

    self.pendingGroupRefresh = nil
    local settings = RUI.db.unitframes
    local inRaid = IsInRaidGroup()
    local hasParty = HasLivePartyMembers()

    -- Previews are configuration-only. The moment live group data exists, the
    -- real roster becomes authoritative and the temporary preview is retired.
    if inRaid then
        self.previewParty = nil
        self.previewRaid = nil
    elseif hasParty then
        self.previewParty = nil
    end

    if self.partyFrames then
        local partyPreview = self.previewParty and not inRaid and not hasParty
        for i = 1, PARTY_COUNT do
            local frame = self.partyFrames[i]
            local enabled = settings.showParty and not inRaid
            if partyPreview then
                self:SetUnitWatch(frame, false)
                frame:Show()
                self:UpdatePartyPreviewFrame(frame, i)
            else
                self:SetUnitWatch(frame, enabled)
                if enabled and UnitExists(frame.unit) then
                    -- Explicitly recover frames after party/raid transitions instead
                    -- of depending on RegisterUnitWatch to fire another existence edge.
                    frame:Show()
                    self:UpdateFrame(frame)
                elseif not enabled or not UnitExists(frame.unit) then
                    frame:Hide()
                end
            end
        end
    end

    self:LayoutRaidFrames()
    self:UpdateGroupVisibility()
    self:UpdateRaidFrames()
    self:UpdateRaidDebuffs()
    self.groupRosterSignature = self:GetGroupRosterSignature()
    return true
end

function UnitFrames:UpdatePartyFrames()
    if self.player and self.player.leaderIcon then self:UpdateGroupLeaderIndicator(self.player) end
    if not self.partyFrames then return end
    local inRaid = IsInRaidGroup()
    local partyPreview = self.previewParty and not inRaid and not HasLivePartyMembers()
    for i = 1, PARTY_COUNT do
        local frame = self.partyFrames[i]
        if frame and frame:IsShown() and partyPreview then
            self:UpdatePartyPreviewFrame(frame, i)
        elseif frame and frame:IsShown() and UnitExists(frame.unit) then
            self:UpdateFrame(frame)
        elseif frame then
            self:UpdateGroupRangeState(frame)
        end
    end
end

function UnitFrames:UpdateTargetTarget()
    self:UpdateMiniFrame(self.targetTarget)
end

function UnitFrames:UpdateFocusTarget()
    self:UpdateMiniFrame(self.focusTarget)
end

function UnitFrames:UpdateCastbar(bar)
    if not bar then return end

    local settings = RUI.db and RUI.db.unitframes
    local unitDisabled = (bar.unit == "focus" and settings and not settings.showFocus) or
        (bar.unit == "pet" and settings and not settings.showPet)
    if not self.active or not settings or not settings.enabled or not settings.showCastbars or unitDisabled or not UnitExists(bar.unit) then
        bar.active = nil
        bar:Hide()
        return
    end

    local name, nameSubtext, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(bar.unit)
    local channeling = false

    if not name then
        name, nameSubtext, text, texture, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo(bar.unit)
        channeling = name and true or false
        castID = nil
    end

    if not name or not startTime or not endTime then
        bar.active = nil
        bar.casting = nil
        bar.channeling = nil
        bar:Hide()
        return
    end

    bar.startTime = startTime / 1000
    bar.endTime = endTime / 1000
    bar.castID = castID
    bar.notInterruptible = notInterruptible and true or false
    bar.channeling = channeling
    bar.casting = not channeling
    bar.active = true
    bar:SetMinMaxValues(0, max(0.001, bar.endTime - bar.startTime))
    bar.text:SetText(text or name)

    local r, g, b = RUI:GetAccentColor()
    if bar.notInterruptible and (bar.unit == "target" or bar.unit == "focus") then
        r = (r + 0.45) * 0.5
        g = (g + 0.45) * 0.5
        b = (b + 0.45) * 0.5
    end
    bar:SetStatusBarColor(r, g, b, 0.96)
    bar:Show()
end

function UnitFrames:UpdateAll()
    self:UpdateFrame(self.player)
    self:UpdateFrame(self.target)
    self:UpdateFrame(self.focus)
    self:UpdateFrame(self.pet)
    self:UpdatePartyFrames()
    self:UpdateRaidFrames()
    self:UpdateRaidDebuffs()
    self:UpdateTargetTarget()
    self:UpdateFocusTarget()
    self:UpdateCastbar(self.player and self.player.castbar)
    self:UpdateCastbar(self.target and self.target.castbar)
    self:UpdateCastbar(self.focus and self.focus.castbar)
    self:UpdateCastbar(self.pet and self.pet.castbar)
    self:UpdateAuras()
    self:UpdateClassResources()
end

function UnitFrames:UpdateLayout()
    if not self.targetTarget or not self.focusTarget or not RUI.db or not RUI.db.unitframes then
        return
    end

    local settings = RUI.db.unitframes
    local hasResources = settings.showClassResources and self.resourceKind and true or false
    local resourceExtra = hasResources and (RESOURCE_HEIGHT + 3) or 0
    local castExtra = settings.showCastbars and (CAST_HEIGHT + 3) or 0
    local targetTargetExtra = settings.showTargetTarget and (TOT_HEIGHT + 3) or 0
    local playerAuraExtra = settings.showPlayerAuras and (AURA_ROWS_HEIGHT + 3) or 0
    local targetAuraExtra = settings.showTargetAuras and (AURA_ROWS_HEIGHT + 3) or 0
    local focusAuraExtra = settings.showFocusAuras and (AURA_ROWS_HEIGHT + 3) or 0
    local petAuraExtra = settings.showPetAuras and (AURA_ROWS_HEIGHT + 3) or 0
    local focusTargetExtra = settings.showFocus and settings.showFocusTarget and (TOT_HEIGHT + 3) or 0
    local petCastExtra = settings.showCastbars and (PET_CAST_HEIGHT + 3) or 0

    self.classResource:ClearAllPoints()
    self.classResource:SetPoint("TOPLEFT", self.player, "BOTTOMLEFT", 0, -3)

    self.player.castbar:ClearAllPoints()
    if hasResources then
        self.player.castbar:SetPoint("TOPLEFT", self.classResource, "BOTTOMLEFT", 0, -3)
        self.player.castbar:SetPoint("TOPRIGHT", self.classResource, "BOTTOMRIGHT", 0, -3)
    else
        self.player.castbar:SetPoint("TOPLEFT", self.player, "BOTTOMLEFT", 0, -3)
        self.player.castbar:SetPoint("TOPRIGHT", self.player, "BOTTOMRIGHT", 0, -3)
    end

    self.target.castbar:ClearAllPoints()
    self.target.castbar:SetPoint("TOPLEFT", self.target, "BOTTOMLEFT", 0, -3)
    self.target.castbar:SetPoint("TOPRIGHT", self.target, "BOTTOMRIGHT", 0, -3)

    self.targetTarget:ClearAllPoints()
    if settings.showCastbars then
        self.targetTarget:SetPoint("TOPRIGHT", self.target, "BOTTOMRIGHT", 0, -(CAST_HEIGHT + 6))
    else
        self.targetTarget:SetPoint("TOPRIGHT", self.target, "BOTTOMRIGHT", 0, -3)
    end

    local playerBottom = self.player
    if settings.showClassResources and self.resourceKind then playerBottom = self.classResource end
    if settings.showCastbars then playerBottom = self.player.castbar end
    self:LayoutAuraContainer("player", self.player, playerBottom)

    local targetBottom = self.target
    if settings.showCastbars then targetBottom = self.target.castbar end
    if settings.showTargetTarget then targetBottom = self.targetTarget end
    self:LayoutAuraContainer("target", self.target, targetBottom, settings.showTargetTarget and -(FRAME_WIDTH - TOT_WIDTH) or 0)

    self.focus.castbar:ClearAllPoints()
    self.focus.castbar:SetPoint("TOPLEFT", self.focus, "BOTTOMLEFT", 0, -3)
    self.focus.castbar:SetPoint("TOPRIGHT", self.focus, "BOTTOMRIGHT", 0, -3)

    self.focusTarget:ClearAllPoints()
    if settings.showCastbars then
        self.focusTarget:SetPoint("TOPRIGHT", self.focus, "BOTTOMRIGHT", 0, -(CAST_HEIGHT + 6))
    else
        self.focusTarget:SetPoint("TOPRIGHT", self.focus, "BOTTOMRIGHT", 0, -3)
    end

    local focusBottom = self.focus
    if settings.showCastbars then focusBottom = self.focus.castbar end
    if settings.showFocusTarget then focusBottom = self.focusTarget end
    self:LayoutAuraContainer("focus", self.focus, focusBottom, settings.showFocusTarget and -(FRAME_WIDTH - TOT_WIDTH) or 0)

    self.pet.castbar:ClearAllPoints()
    self.pet.castbar:SetPoint("TOPLEFT", self.pet, "BOTTOMLEFT", 0, -3)
    self.pet.castbar:SetPoint("TOPRIGHT", self.pet, "BOTTOMRIGHT", 0, -3)
    self:LayoutAuraContainer("pet", self.pet, settings.showCastbars and self.pet.castbar or self.pet)

    local unitScale = RUI:GetEffectiveScale("unitframes")
    local partyScale = RUI:GetEffectiveScale("party")
    local raidScale = RUI:GetEffectiveScale("raid")
    RUI:UpdateMoverSize("PlayerFrame", FRAME_WIDTH * unitScale, (FRAME_HEIGHT + resourceExtra + castExtra + playerAuraExtra) * unitScale)
    RUI:UpdateMoverSize("TargetFrame", FRAME_WIDTH * unitScale, (FRAME_HEIGHT + castExtra + targetTargetExtra + targetAuraExtra) * unitScale)
    RUI:UpdateMoverSize("FocusFrame", FRAME_WIDTH * unitScale, (FRAME_HEIGHT + castExtra + focusTargetExtra + focusAuraExtra) * unitScale)
    RUI:UpdateMoverSize("PetFrame", PET_WIDTH * unitScale, (PET_HEIGHT + petCastExtra + petAuraExtra) * unitScale)
    RUI:UpdateMoverSize("PartyFrames", PARTY_WIDTH * partyScale, PARTY_STACK_HEIGHT * partyScale)

    if self.partyAnchor then
        self.partyAnchor:SetScale(partyScale)
    end
    if self.raidAnchor then
        self.raidAnchor:SetScale(raidScale)
        self:LayoutRaidFrames()
    end
end

function UnitFrames:ApplyAppearance()
    if not self.player or not self.target or not self.focus or not self.pet then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self.pendingAppearance = true
        return
    end

    self.pendingAppearance = nil
    local scale = RUI:GetEffectiveScale("unitframes")

    local frames = { self.player, self.target, self.focus, self.pet }
    for i = 1, #frames do
        local frame = frames[i]
        frame:SetScale(scale)
        RUI:RefreshBackdrop(frame)
        RUI:RefreshBackdrop(frame.castbar)
        RUI:RefreshBackdrop(frame.portrait)
        frame.castbar:SetStatusBarTexture(RUI:GetStatusBarTexture())
        frame.health.fill:SetTexture(RUI:GetStatusBarTexture())
        frame.power.fill:SetTexture(RUI:GetStatusBarTexture())

        -- Unit-frame typography has its own profile so readability can be tuned
        -- independently of ZenUI's general configuration-window typography.
        if frame.isPet then
            StyleUnitFrameText(frame.nameText, 10)
            StyleUnitFrameText(frame.descriptorText, 8)
            StyleUnitFrameText(frame.healthText, 9)
            StyleUnitFrameText(frame.powerText, 7)
            StyleUnitFrameText(frame.castbar.text, 8)
            StyleUnitFrameText(frame.castbar.time, 8)
        else
            StyleUnitFrameText(frame.nameText, 12)
            StyleUnitFrameText(frame.descriptorText, 9)
            StyleUnitFrameText(frame.healthText, 10)
            StyleUnitFrameText(frame.powerText, 8)
            StyleUnitFrameText(frame.castbar.text, 9)
            StyleUnitFrameText(frame.castbar.time, 9)
        end

        self:ApplyPortraitLayout(frame, RUI.db.unitframes.showPortraits)
    end

    if self.auraContainers then
        for _, container in pairs(self.auraContainers) do container:SetScale(scale) end
    end
    self.classResource:SetScale(scale)

    local miniFrames = { self.targetTarget, self.focusTarget }
    for i = 1, #miniFrames do
        local mini = miniFrames[i]
        RUI:RefreshBackdrop(mini)
        mini.health.fill:SetTexture(RUI:GetStatusBarTexture())
        StyleUnitFrameText(mini.nameText, 9)
        StyleUnitFrameText(mini.healthText, 8)
    end

    if self.partyFrames then
        for i = 1, PARTY_COUNT do
            local party = self.partyFrames[i]
            RUI:RefreshBackdrop(party)
            RUI:RefreshBackdrop(party.portrait)
            party.health.fill:SetTexture(RUI:GetStatusBarTexture())
            party.power.fill:SetTexture(RUI:GetStatusBarTexture())
            StyleUnitFrameText(party.nameText, 10)
            StyleUnitFrameText(party.descriptorText, 8)
            StyleUnitFrameText(party.healthText, 9)
            StyleUnitFrameText(party.powerText, 7)
            self:ApplyPortraitLayout(party, RUI.db.unitframes.showPortraits)
        end
    end

    if self.raidFrames then
        for i = 1, RAID_MAX_MEMBERS do
            local raidFrame = self.raidFrames[i]
            RUI:RefreshBackdrop(raidFrame)
            raidFrame.health.fill:SetTexture(RUI:GetStatusBarTexture())
            raidFrame.power.fill:SetTexture(RUI:GetStatusBarTexture())
            StyleUnitFrameText(raidFrame.nameText, 9)
            StyleUnitFrameText(raidFrame.healthText, 8)
            StyleUnitFrameText(raidFrame.rankText, 7)
            self:ApplyRaidFrameLayout(raidFrame)
        end
        if self.raidGroupLabels then
            local mr, mg, mb = RUI:GetTextColor(true)
            for i = 1, RAID_MAX_GROUPS do
                RUI:StyleFontString(self.raidGroupLabels[i], 8, mr, mg, mb)
            end
        end
    end

    if self.auraContainers then
        for _, container in pairs(self.auraContainers) do
            for i = 1, container.maxAuras or MAX_AURAS_PER_ROW do
                local buff = container.buffs[i]
                local debuff = container.debuffs[i]
                RUI:RefreshBackdrop(buff)
                RUI:RefreshBackdrop(debuff)
                StyleUnitFrameText(buff.count, 9)
                StyleUnitFrameText(debuff.count, 9)
            end
        end
    end

    self:UpdateLayout()
    self:UpdateAll()
end

function UnitFrames:HideBlizzardFrames()
    if self.blizzardHidden then return end

    self.hider = self.hider or CreateFrame("Frame", "ZenUIBlizzardUnitFrameHider", UIParent)
    self.hider:Hide()
    self.blizzardParents = self.blizzardParents or {}

    if PlayerFrame then
        self.blizzardParents.player = self.blizzardParents.player or PlayerFrame:GetParent()
        PlayerFrame:SetParent(self.hider)
    end

    if TargetFrame then
        self.blizzardParents.target = self.blizzardParents.target or TargetFrame:GetParent()
        TargetFrame:SetParent(self.hider)
    end

    if FocusFrame then
        self.blizzardParents.focus = self.blizzardParents.focus or FocusFrame:GetParent()
        FocusFrame:SetParent(self.hider)
    end

    if PetFrame then
        self.blizzardParents.pet = self.blizzardParents.pet or PetFrame:GetParent()
        PetFrame:SetParent(self.hider)
    end

    for i = 1, PARTY_COUNT do
        local partyFrame = _G["PartyMemberFrame" .. tostring(i)]
        if partyFrame then
            local key = "party" .. tostring(i)
            self.blizzardParents[key] = self.blizzardParents[key] or partyFrame:GetParent()
            partyFrame:SetParent(self.hider)
        end
    end

    if ComboFrame then
        self.blizzardParents.combo = self.blizzardParents.combo or ComboFrame:GetParent()
        ComboFrame:SetParent(self.hider)
    end

    if RuneFrame then
        self.blizzardParents.runes = self.blizzardParents.runes or RuneFrame:GetParent()
        RuneFrame:SetParent(self.hider)
    end

    self.blizzardHidden = true
end

function UnitFrames:SetBlizzardCastbarHidden(hidden)
    self.blizzardParents = self.blizzardParents or {}
    self.hider = self.hider or CreateFrame("Frame", "ZenUIBlizzardUnitFrameHider", UIParent)
    self.hider:Hide()

    if CastingBarFrame then
        self.blizzardParents.castbar = self.blizzardParents.castbar or CastingBarFrame:GetParent()
        if hidden then
            CastingBarFrame:SetParent(self.hider)
        elseif self.blizzardCastbarHidden then
            CastingBarFrame:SetParent(self.blizzardParents.castbar or UIParent)
        end
    end

    -- The stock pet casting bar is top-level rather than a child of PetFrame,
    -- so it needs the same explicit treatment as the player's CastingBarFrame.
    if PetCastingBarFrame then
        self.blizzardParents.petCastbar = self.blizzardParents.petCastbar or PetCastingBarFrame:GetParent()
        if hidden then
            PetCastingBarFrame:SetParent(self.hider)
        elseif self.blizzardCastbarHidden then
            PetCastingBarFrame:SetParent(self.blizzardParents.petCastbar or UIParent)
        end
    end

    self.blizzardCastbarHidden = hidden and true or nil
end

function UnitFrames:RestoreBlizzardFrames()
    if not self.blizzardHidden then return end

    if PlayerFrame then
        PlayerFrame:SetParent((self.blizzardParents and self.blizzardParents.player) or UIParent)
        PlayerFrame:Show()
    end

    if TargetFrame then
        TargetFrame:SetParent((self.blizzardParents and self.blizzardParents.target) or UIParent)
        if UnitExists("target") then TargetFrame:Show() else TargetFrame:Hide() end
    end

    if FocusFrame then
        FocusFrame:SetParent((self.blizzardParents and self.blizzardParents.focus) or UIParent)
        if UnitExists("focus") then FocusFrame:Show() else FocusFrame:Hide() end
    end

    if PetFrame then
        PetFrame:SetParent((self.blizzardParents and self.blizzardParents.pet) or PlayerFrame or UIParent)
        if UnitExists("pet") then PetFrame:Show() else PetFrame:Hide() end
    end

    for i = 1, PARTY_COUNT do
        local partyFrame = _G["PartyMemberFrame" .. tostring(i)]
        if partyFrame then
            local key = "party" .. tostring(i)
            partyFrame:SetParent((self.blizzardParents and self.blizzardParents[key]) or UIParent)
            if UnitExists("party" .. tostring(i)) then partyFrame:Show() else partyFrame:Hide() end
        end
    end

    if ComboFrame then
        ComboFrame:SetParent((self.blizzardParents and self.blizzardParents.combo) or UIParent)
    end

    if RuneFrame then
        RuneFrame:SetParent((self.blizzardParents and self.blizzardParents.runes) or UIParent)
    end

    self.blizzardHidden = nil
end

function UnitFrames:Activate()
    local settings = RUI.db.unitframes
    self.active = true
    self:UpdateLayout()
    self.player:Show()

    self:SetUnitWatch(self.target, true)
    self:SetUnitWatch(self.targetTarget, settings.showTargetTarget)
    self:SetUnitWatch(self.focus, settings.showFocus)
    self:SetUnitWatch(self.focusTarget, settings.showFocus and settings.showFocusTarget)
    self:SetUnitWatch(self.pet, settings.showPet)
    if self.partyFrames then
        for i = 1, PARTY_COUNT do
            -- Group-specific watches are finalized by RefreshGroupRoster below,
            -- which also handles party <-> raid transitions explicitly.
            self:SetUnitWatch(self.partyFrames[i], false)
        end
    end
    self:LayoutRaidFrames()

    RUI:SetMoverEnabled("PlayerFrame", true)
    RUI:SetMoverEnabled("TargetFrame", true)
    RUI:SetMoverEnabled("FocusFrame", settings.showFocus)
    RUI:SetMoverEnabled("PetFrame", settings.showPet)
    RUI:SetMoverEnabled("PartyFrames", settings.showParty)
    RUI:SetMoverEnabled("RaidFrames", settings.showRaid)

    if settings.hideBlizzard then
        self:HideBlizzardFrames()
    else
        self:RestoreBlizzardFrames()
    end
    self:SetBlizzardCastbarHidden(settings.hideBlizzard and settings.showCastbars)

    if self.auraContainers then
        for unit, container in pairs(self.auraContainers) do
            local keys = AURA_SETTING_KEYS[unit]
            if not keys or not settings[keys.show] then container:Hide() end
        end
    end
    if not settings.showClassResources then self.classResource:Hide() end
    if not settings.showFocus then
        self.focus.castbar:Hide()
        self.focusTarget:Hide()
    elseif not settings.showFocusTarget then
        self.focusTarget:Hide()
    end
    if not settings.showPet then self.pet.castbar:Hide() end
    self:RefreshGroupRoster()

    self:UpdateAll()
end

function UnitFrames:Deactivate()
    self.active = false
    self:SetUnitWatch(self.target, false)
    self:SetUnitWatch(self.targetTarget, false)
    self:SetUnitWatch(self.focus, false)
    self:SetUnitWatch(self.focusTarget, false)
    self:SetUnitWatch(self.pet, false)
    if self.partyFrames then
        for i = 1, PARTY_COUNT do self:SetUnitWatch(self.partyFrames[i], false) end
    end
    if self.partyAnchor then self.partyAnchor:Hide() end
    if self.partyPreviewStop then self.partyPreviewStop:Hide() end
    if self.raidPreviewStop then self.raidPreviewStop:Hide() end
    if self.raidFrames then
        for i = 1, RAID_MAX_MEMBERS do self:SetRaidFrameActive(self.raidFrames[i], false) end
    end
    if self.raidAnchor then self.raidAnchor:Hide() end
    self.player:Hide()
    self.player.castbar:Hide()
    self.target.castbar:Hide()
    self.focus.castbar:Hide()
    self.pet.castbar:Hide()
    if self.auraContainers then
        for _, container in pairs(self.auraContainers) do container:Hide() end
    end
    self.classResource:Hide()
    RUI:SetMoverEnabled("PlayerFrame", false)
    RUI:SetMoverEnabled("TargetFrame", false)
    RUI:SetMoverEnabled("FocusFrame", false)
    RUI:SetMoverEnabled("PetFrame", false)
    RUI:SetMoverEnabled("PartyFrames", false)
    RUI:SetMoverEnabled("RaidFrames", false)
    self:RestoreBlizzardFrames()
    self:SetBlizzardCastbarHidden(false)
end

function UnitFrames:ApplySettings()
    if not RUI.db or not RUI.db.unitframes then return end

    if InCombatLockdown and InCombatLockdown() then
        self.pendingSettings = true
        RUI:Print("Unit-frame setting queued until combat ends.")
        return false
    end

    self.pendingSettings = nil
    if RUI.db.unitframes.enabled then
        self:Activate()
    else
        self:Deactivate()
    end

    self:ApplyAppearance()
    return true
end

function UnitFrames:OnEvent(event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        if self.pendingSettings then self:ApplySettings() end
        if self.pendingAppearance then self:ApplyAppearance() end
        if self.pendingRaidLayout or self.pendingGroupRefresh then
            self:RefreshGroupRoster()
        end
        return
    end

    if not self.active or not RUI.db or not RUI.db.unitframes then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        self.lastPlayerPower = nil
        self.lastPlayerMaxPower = nil
        self.lastPlayerPowerType = nil
        self.lastPlayerPowerToken = nil
        self:RefreshGroupRoster()
        self:UpdateAll()
        return
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" or event == "PLAYER_GAINS_VEHICLE_DATA" or event == "PLAYER_LOSES_VEHICLE_DATA" then
        local unit = ...
        if unit == nil or unit == "player" then
            self.lastPlayerPower = nil
            self.lastPlayerMaxPower = nil
            self.lastPlayerPowerType = nil
            self.lastPlayerPowerToken = nil
            self:UpdateFrame(self.player)
            self:UpdatePortrait(self.player)
        end
        return
    elseif event == "PLAYER_TARGET_CHANGED" then
        self:UpdateFrame(self.target)
        self:UpdateTargetTarget()
        self:UpdateCastbar(self.target.castbar)
        self:UpdateUnitAuras("target")
        self:UpdateClassResources()
        return
    elseif event == "PLAYER_FOCUS_CHANGED" then
        self:UpdateFrame(self.focus)
        self:UpdateFocusTarget()
        self:UpdateCastbar(self.focus.castbar)
        self:UpdateUnitAuras("focus")
        return
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "PARTY_LEADER_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        self:RefreshGroupRoster()
        if self.player and self.player.leaderIcon then self:UpdateGroupLeaderIndicator(self.player) end
        return
    elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
        self:UpdateRaidFrames()
        return
    elseif event == "UNIT_PET" then
        local owner = ...
        if owner == "player" then
            self:UpdateFrame(self.pet)
            self:UpdateCastbar(self.pet.castbar)
            self:UpdateUnitAuras("pet")
        end
        return
    elseif event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" or event == "UNIT_COMBO_POINTS" then
        self:UpdateClassResources()
        return
    elseif event == "UNIT_TARGET" then
        local unit = ...
        if unit == "target" then
            self:UpdateTargetTarget()
        elseif unit == "focus" then
            self:UpdateFocusTarget()
        end
        return
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" or unit == "target" or unit == "focus" or unit == "pet" then
            self:UpdateUnitAuras(unit)
        elseif string.sub(unit or "", 1, 4) == "raid" then
            local index = tonumber(string.sub(unit, 5))
            if index and self.raidFrames and self.raidFrames[index] then
                self:UpdateRaidDebuff(self.raidFrames[index])
            end
        end
        return
    elseif event == "UNIT_PORTRAIT_UPDATE" then
        local unit = ...
        if unit == "player" or unit == "vehicle" then
            self:UpdatePortrait(self.player)
        elseif unit == "target" then
            self:UpdatePortrait(self.target)
        elseif unit == "focus" then
            self:UpdatePortrait(self.focus)
        elseif unit == "pet" then
            self:UpdatePortrait(self.pet)
        elseif self.partyFrames then
            for i = 1, PARTY_COUNT do
                if unit == self.partyFrames[i].unit then
                    self:UpdatePortrait(self.partyFrames[i])
                    break
                end
            end
        end
        return
    end

    local unit = ...
    if string.sub(event, 1, 14) == "UNIT_SPELLCAST" then
        if unit == "player" then
            self:UpdateCastbar(self.player.castbar)
        elseif unit == "target" then
            self:UpdateCastbar(self.target.castbar)
        elseif unit == "focus" then
            self:UpdateCastbar(self.focus.castbar)
        elseif unit == "pet" then
            self:UpdateCastbar(self.pet.castbar)
        end
        return
    end

    if unit == "player" or unit == "vehicle" then
        self:UpdateFrame(self.player)
    elseif unit == "target" then
        self:UpdateFrame(self.target)
    elseif unit == "focus" then
        self:UpdateFrame(self.focus)
    elseif unit == "pet" then
        self:UpdateFrame(self.pet)
    elseif string.sub(unit or "", 1, 5) == "party" then
        local index = tonumber(string.sub(unit, 6))
        if index and self.partyFrames and self.partyFrames[index] then
            self:UpdateFrame(self.partyFrames[index])
        end
    elseif string.sub(unit or "", 1, 4) == "raid" then
        local index = tonumber(string.sub(unit, 5))
        if index and self.raidFrames and self.raidFrames[index] then
            self:UpdateRaidFrame(self.raidFrames[index])
        end
    elseif unit == "targettarget" then
        self:UpdateTargetTarget()
    elseif unit == "focus-target" or unit == "focustarget" then
        self:UpdateFocusTarget()
    end
end

function UnitFrames:OnAppearanceChanged()
    self:ApplyAppearance()
end

function UnitFrames:OnProfileReset()
    self:ApplySettings()
end

function UnitFrames:OnComponentScaleChanged(key)
    if key == "all" or key == "unitframes" or key == "party" or key == "raid" then
        self:ApplyAppearance()
    end
end

function UnitFrames:OnInitialize()
    self.player = CreateUnitFrame("ZenUIPlayerFrame", "player", false)
    self.target = CreateUnitFrame("ZenUITargetFrame", "target", true)
    self.focus = CreateUnitFrame("ZenUIFocusFrame", "focus", true)
    self.pet = CreatePetFrame()

    self.partyAnchor = CreateFrame("Frame", "ZenUIPartyAnchor", UIParent)
    self.partyAnchor:SetWidth(PARTY_WIDTH)
    self.partyAnchor:SetHeight(PARTY_STACK_HEIGHT)
    self.partyAnchor:Hide()
    self.partyPreviewStop = CreateGroupPreviewStopButton("party", self.partyAnchor)
    self.partyFrames = {}
    for i = 1, PARTY_COUNT do
        local party = CreatePartyFrame(i, self.partyAnchor)
        party:ClearAllPoints()
        if i == 1 then
            party:SetPoint("TOPLEFT", self.partyAnchor, "TOPLEFT", 0, 0)
        else
            party:SetPoint("TOPLEFT", self.partyFrames[i - 1], "BOTTOMLEFT", 0, -PARTY_SPACING)
        end
        party:Hide()
        self.partyFrames[i] = party
    end


    self.raidAnchor = CreateFrame("Frame", "ZenUIRaidAnchor", UIParent)
    self.raidAnchor:SetWidth((RAID_FRAME_WIDTH * 5) + (RAID_GROUP_SPACING * 4))
    self.raidAnchor:SetHeight(RAID_GROUP_LABEL_HEIGHT + (RAID_FRAME_HEIGHT * RAID_MEMBERS_PER_GROUP) + (RAID_MEMBER_SPACING * (RAID_MEMBERS_PER_GROUP - 1)))
    self.raidAnchor:Hide()
    self.raidPreviewStop = CreateGroupPreviewStopButton("raid", self.raidAnchor)
    self.raidFrames = {}
    self.raidGroupLabels = {}
    for i = 1, RAID_MAX_MEMBERS do
        self.raidFrames[i] = CreateRaidFrame(i, self.raidAnchor)
    end
    for g = 1, RAID_MAX_GROUPS do
        local label = self.raidAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetText("GROUP " .. tostring(g))
        label:SetWidth(RAID_FRAME_WIDTH)
        label:SetHeight(RAID_GROUP_LABEL_HEIGHT)
        label:SetJustifyH("LEFT")
        label:Hide()
        self.raidGroupLabels[g] = label
    end

    self.targetTarget = CreateMiniUnitFrame("ZenUITargetTargetFrame", self.target, "targettarget")
    self.focusTarget = CreateMiniUnitFrame("ZenUIFocusTargetFrame", self.focus, "focus-target")
    self.target.targetTarget = self.targetTarget
    self.focus.focusTarget = self.focusTarget

    self.auraContainers = {
        player = CreateAuraContainer("ZenUIPlayerAuras", "player", FRAME_WIDTH),
        target = CreateAuraContainer("ZenUITargetAuras", "target", FRAME_WIDTH),
        focus = CreateAuraContainer("ZenUIFocusAuras", "focus", FRAME_WIDTH),
        pet = CreateAuraContainer("ZenUIPetAuras", "pet", PET_WIDTH),
    }
    -- Compatibility alias for older internal code/debug helpers.
    self.targetAuras = self.auraContainers.target
    self.classResource = CreateClassResourceFrame()

    local _, classToken = UnitClass("player")
    self.playerClass = classToken
    if classToken == "DEATHKNIGHT" then
        self.resourceKind = "runes"
    elseif classToken == "ROGUE" or classToken == "DRUID" then
        self.resourceKind = "combo"
    end

    self.classResource:SetScript("OnUpdate", function(frame, elapsed)
        if UnitFrames.resourceKind ~= "runes" or not frame:IsShown() then return end
        frame.elapsed = (frame.elapsed or 0) + elapsed
        if frame.elapsed >= 0.05 then
            frame.elapsed = 0
            UnitFrames:UpdateClassResources()
        end
    end)

    -- Player power is deliberately polled at a low cost in addition to the
    -- normal UNIT_MANA/UNIT_RAGE/UNIT_ENERGY/UNIT_RUNIC_POWER events. Project
    -- Ebonhold can miss one or more of those events on fast-changing resources,
    -- which left Rogue Energy and Warrior Rage visually stale. This also covers
    -- Death Knight Runic Power without rebuilding the whole UI every frame.
    self.playerPowerWatcher = CreateFrame("Frame", "ZenUIPlayerPowerWatcher", UIParent)
    self.playerPowerWatcher.elapsed = 0
    self.playerPowerWatcher:SetScript("OnUpdate", function(frame, elapsed)
        if not UnitFrames.active or not UnitFrames.player or not UnitExists("player") then return end
        frame.elapsed = (frame.elapsed or 0) + (tonumber(elapsed) or 0)
        if frame.elapsed < 0.10 then return end
        frame.elapsed = 0

        local power, maxPower = GetLivePowerValues("player")
        local powerType, powerToken = UnitPowerType("player")
        if power ~= UnitFrames.lastPlayerPower
            or maxPower ~= UnitFrames.lastPlayerMaxPower
            or powerType ~= UnitFrames.lastPlayerPowerType
            or powerToken ~= UnitFrames.lastPlayerPowerToken then
            UnitFrames.lastPlayerPower = power
            UnitFrames.lastPlayerMaxPower = maxPower
            UnitFrames.lastPlayerPowerType = powerType
            UnitFrames.lastPlayerPowerToken = powerToken
            UnitFrames:UpdateFrame(UnitFrames.player)
        end
    end)

    -- Stay hidden until OnEnable applies the active profile. This avoids a brief
    -- frame flash during loading before unit watches and profile toggles are active.
    self.player:Hide()
    self.target:Hide()
    self.targetTarget:Hide()
    self.focus:Hide()
    self.focusTarget:Hide()
    self.pet:Hide()
    for i = 1, PARTY_COUNT do self.partyFrames[i]:Hide() end
    self.partyAnchor:Hide()
    for i = 1, RAID_MAX_MEMBERS do self.raidFrames[i]:Hide() end
    self.raidAnchor:Hide()
    for _, container in pairs(self.auraContainers) do container:Hide() end
    self.classResource:Hide()

    self.playerMover = RUI:RegisterMover("PlayerFrame", self.player, {
        label = "Player Frame",
        width = FRAME_WIDTH,
        height = FRAME_HEIGHT + CAST_HEIGHT + 4,
        point = "CENTER",
        relativePoint = "CENTER",
        x = -250,
        y = -185,
        targetPoint = "TOP",
        moverPoint = "TOP",
    })

    self.targetMover = RUI:RegisterMover("TargetFrame", self.target, {
        label = "Target Frame",
        width = FRAME_WIDTH,
        height = FRAME_HEIGHT + CAST_HEIGHT + TOT_HEIGHT + 9,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 250,
        y = -185,
        targetPoint = "TOP",
        moverPoint = "TOP",
    })

    self.focusMover = RUI:RegisterMover("FocusFrame", self.focus, {
        label = "Focus Frame",
        width = FRAME_WIDTH,
        height = FRAME_HEIGHT + CAST_HEIGHT + TOT_HEIGHT + 9,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 250,
        y = -300,
        targetPoint = "TOP",
        moverPoint = "TOP",
    })

    self.petMover = RUI:RegisterMover("PetFrame", self.pet, {
        label = "Pet Frame",
        width = PET_WIDTH,
        height = PET_HEIGHT + PET_CAST_HEIGHT + 3,
        point = "CENTER",
        relativePoint = "CENTER",
        x = -250,
        y = -300,
        targetPoint = "TOP",
        moverPoint = "TOP",
    })

    self.partyMover = RUI:RegisterMover("PartyFrames", self.partyAnchor, {
        label = "Party Frames",
        width = PARTY_WIDTH,
        height = PARTY_STACK_HEIGHT,
        point = "CENTER",
        relativePoint = "CENTER",
        x = -430,
        y = 70,
        targetPoint = "TOP",
        moverPoint = "TOP",
    })

    self.raidMover = RUI:RegisterMover("RaidFrames", self.raidAnchor, {
        label = "Raid Frames",
        width = (RAID_FRAME_WIDTH * 5) + (RAID_GROUP_SPACING * 4),
        height = RAID_GROUP_LABEL_HEIGHT + (RAID_FRAME_HEIGHT * RAID_MEMBERS_PER_GROUP) + (RAID_MEMBER_SPACING * (RAID_MEMBERS_PER_GROUP - 1)),
        point = "TOPLEFT",
        relativePoint = "TOPLEFT",
        x = 24,
        y = -190,
        targetPoint = "TOPLEFT",
        moverPoint = "TOPLEFT",
    })

    -- Private 3.3.5 server cores are inconsistent about firing raid roster
    -- events at exactly the point raidN units become usable.  A tiny signature
    -- watcher repairs missed/delayed transitions without rebuilding frames every
    -- tick. It only runs structural refreshes out of combat.
    self.groupWatcher = CreateFrame("Frame", "ZenUIGroupRosterWatcher", UIParent)
    self.groupWatcher.elapsed = 0
    self.groupWatcher.visualElapsed = 0
    self.groupWatcher:SetScript("OnUpdate", function(frame, elapsed)
        if not UnitFrames.active or not RUI.db or not RUI.db.unitframes then return end

        -- Private-server fallback only: normal UNIT_* events remain the primary
        -- update path. Poll cheap numeric state at a modest cadence and rebuild
        -- a group frame only when its values actually changed. Unchanged frames
        -- receive only the lightweight range-alpha check.
        frame.visualElapsed = (frame.visualElapsed or 0) + elapsed
        if frame.visualElapsed >= GROUP_VISUAL_REFRESH then
            frame.visualElapsed = 0
            if UnitFrames.partyFrames then
                for i = 1, PARTY_COUNT do
                    local party = UnitFrames.partyFrames[i]
                    if party and party:IsShown() and UnitExists(party.unit) then
                        if GroupPollStateChanged(party) then
                            UnitFrames:UpdateFrame(party)
                        else
                            UnitFrames:UpdateGroupRangeState(party)
                        end
                    end
                end
            end
            if UnitFrames.raidFrames then
                for i = 1, RAID_MAX_MEMBERS do
                    local raid = UnitFrames.raidFrames[i]
                    if raid and raid:IsShown() then
                        if GroupPollStateChanged(raid) then
                            UnitFrames:UpdateRaidFrame(raid)
                        else
                            UnitFrames:UpdateGroupRangeState(raid)
                        end
                    end
                end
            end
        end

        frame.elapsed = (frame.elapsed or 0) + elapsed
        if frame.elapsed < 0.75 then return end
        frame.elapsed = 0
        if InCombatLockdown and InCombatLockdown() then return end

        local signature = UnitFrames:GetGroupRosterSignature()
        local inRaid = IsInRaidGroup()
        local raidShouldShow = inRaid and RUI.db.unitframes.showRaid
        local raidMissing = raidShouldShow and UnitFrames.raidAnchor and not UnitFrames.raidAnchor:IsShown()

        if signature ~= UnitFrames.groupRosterSignature or raidMissing then
            UnitFrames:RefreshGroupRoster()
        end
    end)

    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "OnAppearanceChanged")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED", self, "OnComponentScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET", self, "OnProfileReset")

    local events = {
        "PLAYER_ENTERING_WORLD",
        "UNIT_ENTERED_VEHICLE",
        "UNIT_EXITED_VEHICLE",
        "PLAYER_GAINS_VEHICLE_DATA",
        "PLAYER_LOSES_VEHICLE_DATA",
        "PLAYER_TARGET_CHANGED",
        "PLAYER_FOCUS_CHANGED",
        "PARTY_MEMBERS_CHANGED",
        "PARTY_LEADER_CHANGED",
        "RAID_ROSTER_UPDATE",
        "READY_CHECK",
        "READY_CHECK_CONFIRM",
        "READY_CHECK_FINISHED",
        "PLAYER_REGEN_ENABLED",
        "UNIT_PET",
        "UNIT_HEALTH",
        "UNIT_MAXHEALTH",
        "UNIT_MANA",
        "UNIT_MAXMANA",
        "UNIT_RAGE",
        "UNIT_MAXRAGE",
        "UNIT_FOCUS",
        "UNIT_MAXFOCUS",
        "UNIT_ENERGY",
        "UNIT_MAXENERGY",
        "UNIT_HAPPINESS",
        "UNIT_MAXHAPPINESS",
        "UNIT_RUNIC_POWER",
        "UNIT_MAXRUNIC_POWER",
        "UNIT_DISPLAYPOWER",
        "UNIT_NAME_UPDATE",
        "UNIT_LEVEL",
        "UNIT_FACTION",
        "UNIT_FLAGS",
        "UNIT_DYNAMIC_FLAGS",
        "UNIT_CONNECTION",
        "UNIT_CLASSIFICATION_CHANGED",
        "UNIT_TARGET",
        "UNIT_AURA",
        "UNIT_PORTRAIT_UPDATE",
        "UNIT_COMBO_POINTS",
        "RUNE_POWER_UPDATE",
        "RUNE_TYPE_UPDATE",
        "UNIT_SPELLCAST_START",
        "UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_INTERRUPTIBLE",
        "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    }

    for i = 1, #events do
        self:RegisterEvent(events[i], "OnEvent")
    end

    self:ApplyAppearance()
end

function UnitFrames:OnEnable()
    self:ApplySettings()
end
