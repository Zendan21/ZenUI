-- ZenUI 1.0.25 bridge for the embedded ZenStylingPack 1.1.0 design system.
-- ZenStylingPack owns appearance state and may optionally synchronize it through
-- EbonAPI. ZenUI keeps its existing layout/mover/component-scale systems.

local _, ns = ...
local RUI = ZenUI
local UI = ns and ns.UI

RUI.StylingPack = UI

local function LegacyStyleFromAppearance(appearance)
    if type(appearance) ~= "table" then return "CLASSIC" end
    local key = appearance.style or appearance.visualStyle
    if type(key) == "string" then key = string.upper(key) end
    if UI and UI.Themes and UI.Themes[key] then return key end
    if appearance.darkMode == true then return "OBSIDIAN" end
    return "CLASSIC"
end

local function SyncLegacyFields(appearance, resolved)
    if type(appearance) ~= "table" then return end
    local settings = type(resolved) == "table" and resolved or appearance
    local style = type(settings.style) == "string" and string.upper(settings.style) or "CLASSIC"
    appearance.visualStyle = style
    appearance.darkMode = (style == "OBSIDIAN")
end

function RUI:InitializeStylingPack()
    if not UI or type(UI.AttachSettings) ~= "function" then return false end
    if not self.db or type(self.db.appearance) ~= "table" then return false end

    local appearance = self.db.appearance
    if not appearance.style then appearance.style = LegacyStyleFromAppearance(appearance) end
    if appearance.mode ~= "LOCAL" and appearance.mode ~= "GLOBAL" then
        -- ZenStylingPack's intended default: shared when EbonAPI is available,
        -- transparent local fallback when it is not.
        appearance.mode = "GLOBAL"
    end

    if not UI._zenUIHostListener then
        UI:OnAppearanceChanged(function()
            local resolved = UI:GetSettings()
            if RUI.db and RUI.db.appearance then
                SyncLegacyFields(RUI.db.appearance, resolved)
            end
            RUI:FireCallback("APPEARANCE_CHANGED", "styling-pack")
        end)
        UI._zenUIHostListener = true
    end

    UI:AttachSettings(appearance)
    SyncLegacyFields(appearance, UI:GetSettings())
    return true
end

function RUI:GetAppearanceSettings()
    if UI and type(UI.GetSettings) == "function" then
        local settings = UI:GetSettings()
        if type(settings) == "table" then return settings end
    end
    return self.db and self.db.appearance or nil
end

function RUI:GetAppearanceMode()
    if UI and type(UI.GetAppearanceMode) == "function" then
        return UI:GetAppearanceMode()
    end
    return "LOCAL"
end

function RUI:IsGlobalAppearanceAvailable()
    return UI and type(UI.IsGlobalAvailable) == "function" and UI:IsGlobalAvailable() or false
end

function RUI:SetAppearanceMode(mode)
    if not UI or type(UI.SetAppearanceMode) ~= "function" then return false end
    local ok = UI:SetAppearanceMode(mode)
    if ok and self.db and self.db.appearance then
        self.db.appearance.mode = mode
        SyncLegacyFields(self.db.appearance, UI:GetSettings())
    end
    return ok and true or false
end

function RUI:SetAppearanceStyle(key)
    if UI and type(UI.SetStyle) == "function" then
        local ok = UI:SetStyle(key)
        if ok and self.db and self.db.appearance then
            SyncLegacyFields(self.db.appearance, UI:GetSettings())
        end
        return ok and true or false
    end
    return false
end

function RUI:SetAppearanceAccent(r, g, b)
    if not UI or type(UI.SetAccent) ~= "function" then return false end
    UI:SetAccent(r, g, b)
    return true
end

function RUI:SetAppearancePanelAlpha(value)
    if not UI or type(UI.SetPanelAlpha) ~= "function" then return false end
    UI:SetPanelAlpha(value)
    return true
end

function RUI:SetAppearanceScale(value)
    if not UI or type(UI.SetScale) ~= "function" then return false end
    UI:SetScale(value)
    return true
end

function RUI:SetAppearanceFont(key)
    if not UI or type(UI.SetFont) ~= "function" then return false end
    return UI:SetFont(key) and true or false
end

function RUI:GetAppearanceThemes()
    return UI and UI.Themes or nil
end

function RUI:GetAppearanceThemeOrder()
    return UI and UI.ThemeOrder or nil
end

function RUI:GetAppearanceAccentPresets()
    return UI and UI.AccentPresets or nil
end

function RUI:GetAppearanceFontOptions()
    return UI and UI.Media and UI.Media.fontOptions or nil
end

function RUI:GetStylingTheme()
    if UI and type(UI.Theme) == "function" then return UI:Theme() end
    return nil
end

function RUI:RefreshStylingPack()
    if not UI then return false end
    if self.db and self.db.appearance and UI._localSettings ~= self.db.appearance then
        return self:InitializeStylingPack()
    end
    if type(UI.RefreshAll) == "function" then UI:RefreshAll() return true end
    return false
end
