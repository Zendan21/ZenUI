-- ZenUI 0.4.0 tooltip skin.
-- Styles the original Wrath GameTooltip family without replacing tooltip data logic.

local RUI = ZenUI
local Tooltip = RUI:NewModule("Tooltip")

local TOOLTIP_NAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ShoppingTooltip3",
    "WorldMapTooltip",
}

local STOCK_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

local RUI_BACKDROP = {
    bgFile = RUI.Media.textures.white,
    edgeFile = RUI.Media.textures.white,
    tile = false,
    edgeSize = 1,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function AuraSpellID(unit, index, filter, isDebuff)
    if not unit or not index then return nil end

    -- Native Wrath player BuffFrame/DebuffFrame tooltips use SetUnitAura, so
    -- prefer UnitAura when it exists.  Keep UnitBuff/UnitDebuff as fallbacks
    -- for Zen target auras and private-server clients with partial APIs.
    local getter = UnitAura
    if getter then
        local ok, spellID = pcall(function() return select(11, getter(unit, index, filter)) end)
        spellID = ok and tonumber(spellID) or nil
        if spellID and spellID > 0 then return spellID end
    end

    getter = isDebuff and UnitDebuff or UnitBuff
    if not getter then return nil end
    local ok, spellID = pcall(function() return select(11, getter(unit, index, filter)) end)
    spellID = ok and tonumber(spellID) or nil
    if spellID and spellID > 0 then return spellID end
    return nil
end

local function SpellbookSpellID(slot, bookType)
    if not slot then return nil end
    if GetSpellBookItemInfo then
        local ok, _, spellID = pcall(GetSpellBookItemInfo, slot, bookType)
        spellID = ok and tonumber(spellID) or nil
        if spellID and spellID > 0 then return spellID end
    end
    if GetSpellLink then
        local ok, spellLink, tradeSkillLink = pcall(GetSpellLink, slot, bookType)
        local link = ok and (tradeSkillLink or spellLink) or nil
        local spellID = link and string.match(link, "|Hspell:(%d+)")
        spellID = tonumber(spellID)
        if spellID and spellID > 0 then return spellID end
    end
    return nil
end

local function AppendSpellID(tooltip, spellID)
    if not tooltip then return end
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then return end

    -- Avoid duplicate lines when a private-server tooltip method delegates to
    -- another hooked tooltip method internally.
    local wanted = "Spell ID: " .. tostring(spellID)
    if tooltip.GetName and tooltip.NumLines then
        local name = tooltip:GetName()
        local lines = tooltip:NumLines() or 0
        if name and lines > 0 then
            local line = _G[name .. "TextLeft" .. lines]
            if line and line.GetText and line:GetText() == wanted then return end
        end
    end
    tooltip:AddLine(wanted, 0.55, 0.72, 0.90)

    -- The extra line is appended after the tooltip content is already built,
    -- so explicitly reshow it to force a width/height recalculation. Without
    -- this, Wrath/Ebonhold can leave the Spell ID line hanging below the
    -- bottom border even though the text exists.
    if tooltip.Show then tooltip:Show() end
end

function Tooltip:GetSettings()
    return RUI.db and RUI.db.tooltip
end

function Tooltip:GetUnitBorder(tooltip)
    local settings = self:GetSettings() or {}
    if settings.unitBorder == false or not tooltip or not tooltip.GetUnit then
        return RUI:GetAccentColor()
    end

    local _, unit = tooltip:GetUnit()
    if not unit or not UnitExists or not UnitExists(unit) then
        return RUI:GetAccentColor()
    end

    if UnitIsPlayer and UnitIsPlayer(unit) and UnitClass then
        local _, class = UnitClass(unit)
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r or 1, c.g or 1, c.b or 1 end
    end

    if UnitReaction then
        local reaction = UnitReaction(unit, "player")
        local c = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
        if c then return c.r or 1, c.g or 1, c.b or 1 end
    end

    return RUI:GetAccentColor()
end

function Tooltip:StyleFrame(frame, unitAware)
    if not frame or not frame.SetBackdrop then return end
    local settings = self:GetSettings() or {}
    if settings.enabled == false then
        frame:SetBackdrop(STOCK_BACKDROP)
        frame:SetBackdropColor(0.09, 0.09, 0.09, 0.94)
        frame:SetBackdropBorderColor(1, 1, 1, 1)
        frame:SetScale(1)
        return
    end

    frame:SetBackdrop(RUI_BACKDROP)
    local br, bg, bb = RUI:GetBackgroundColor()
    frame:SetBackdropColor(br, bg, bb, math.max(0.90, RUI:GetPanelAlpha()))
    local r, g, b
    if unitAware then r, g, b = self:GetUnitBorder(frame) else r, g, b = RUI:GetAccentColor() end
    frame:SetBackdropBorderColor(r, g, b, 1)
    frame:SetScale(RUI:GetUIScale() * (tonumber(settings.scale) or 1))
end

function Tooltip:StyleHealthBar()
    if not GameTooltipStatusBar then return end
    local settings = self:GetSettings() or {}
    if settings.enabled == false then
        GameTooltipStatusBar:Show()
        return
    end

    if settings.showHealthBar == false then
        GameTooltipStatusBar:Hide()
        return
    end

    GameTooltipStatusBar:Show()
    GameTooltipStatusBar:SetStatusBarTexture(RUI:GetStatusBarTexture())
    GameTooltipStatusBar:SetHeight(5)
    local r, g, b = RUI:GetAccentColor()
    GameTooltipStatusBar:SetStatusBarColor(r, g, b, 1)
end

function Tooltip:StyleGameTooltip()
    self:StyleFrame(GameTooltip, true)
    self:StyleHealthBar()
end


local function HideComparisonTooltips(tooltip)
    local hidden = false
    if tooltip and type(tooltip.shoppingTooltips) == "table" then
        for _, frame in pairs(tooltip.shoppingTooltips) do
            if frame and frame.Hide then frame:Hide(); hidden = true end
        end
    end
    if not hidden then
        for i = 1, 3 do
            local frame = _G["ShoppingTooltip" .. tostring(i)]
            if frame and frame.Hide then frame:Hide() end
        end
    end
end

function Tooltip:RefreshItemComparison()
    local tooltip = GameTooltip
    if not tooltip or not tooltip.IsShown or not tooltip:IsShown() or not tooltip.GetItem then return end

    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if not ok or not link then
        if tooltip.ZenComparingItems then
            HideComparisonTooltips(tooltip)
            tooltip.ZenComparingItems = nil
        end
        return
    end

    local compare = false
    if IsModifiedClick then
        local modOK, result = pcall(IsModifiedClick, "COMPAREITEMS")
        compare = modOK and result and true or false
    end
    -- Preserve the stock Wrath/Ebonhold Shift comparison gesture even when a
    -- private-server modified-click lookup fails to refresh until re-hover.
    if not compare and IsShiftKeyDown then
        local shiftOK, result = pcall(IsShiftKeyDown)
        compare = shiftOK and result and true or false
    end

    if compare then
        if GameTooltip_ShowCompareItem then
            pcall(GameTooltip_ShowCompareItem, tooltip)
            tooltip.ZenComparingItems = true
        end
    elseif tooltip.ZenComparingItems then
        HideComparisonTooltips(tooltip)
        tooltip.ZenComparingItems = nil
    end
end

function Tooltip:OnModifierStateChanged()
    self:RefreshItemComparison()
end

function Tooltip:ApplySettings()
    local settings = self:GetSettings()
    if not settings then return end
    for i = 1, #TOOLTIP_NAMES do
        local frame = _G[TOOLTIP_NAMES[i]]
        if frame then self:StyleFrame(frame, frame == GameTooltip) end
    end
    self:StyleHealthBar()
end

function Tooltip:InstallHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled = true

    for i = 1, #TOOLTIP_NAMES do
        local frame = _G[TOOLTIP_NAMES[i]]
        if frame and frame.HookScript then
            frame:HookScript("OnShow", function(self)
                Tooltip:StyleFrame(self, self == GameTooltip)
                if self == GameTooltip then Tooltip:StyleHealthBar() end
            end)
        end
    end

    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetUnit", function(self)
            Tooltip:StyleFrame(self, true)
            Tooltip:StyleHealthBar()
        end)
    end

    -- Spell IDs are appended only when an aura tooltip is requested, so this
    -- adds no background polling or aura scanning. Hook the native tooltip
    -- methods so Zen and Blizzard/Ebonhold aura buttons behave the same.
    if GameTooltip and hooksecurefunc then
        if GameTooltip.SetUnitAura then
            hooksecurefunc(GameTooltip, "SetUnitAura", function(self, unit, index, filter)
                local isDebuff = filter and string.find(string.upper(tostring(filter)), "HARMFUL", 1, true) and true or false
                AppendSpellID(self, AuraSpellID(unit, index, filter, isDebuff))
            end)
        end
        if GameTooltip.SetUnitBuff then
            hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, unit, index, filter)
                AppendSpellID(self, AuraSpellID(unit, index, filter or "HELPFUL", false))
            end)
        end
        if GameTooltip.SetUnitDebuff then
            hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, unit, index, filter)
                AppendSpellID(self, AuraSpellID(unit, index, filter or "HARMFUL", true))
            end)
        end
        if GameTooltip.SetSpellBookItem then
            hooksecurefunc(GameTooltip, "SetSpellBookItem", function(self, slot, bookType)
                AppendSpellID(self, SpellbookSpellID(slot, bookType))
            end)
        end
    end
end

function Tooltip:OnInitialize()
    self:InstallHooks()
    self:RegisterEvent("MODIFIER_STATE_CHANGED", "OnModifierStateChanged")
    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "ApplySettings")
    RUI:RegisterCallback("PROFILE_RESET", self, "ApplySettings")
end

function Tooltip:OnEnable()
    self:ApplySettings()
end
