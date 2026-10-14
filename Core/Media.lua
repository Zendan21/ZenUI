-- ZenUI 0.1.3 media registry.
-- Keep media paths centralized so UI modules and companion addons share one visual language.

local RUI = ZenUI

RUI.Media = RUI.Media or {}
RUI.Media.root = "Interface\\AddOns\\ZenUI\\Media\\"

RUI.Media.textures = {
    white = RUI.Media.root .. "Textures\\White.tga",
    statusbar = RUI.Media.root .. "Textures\\White.tga",
}

RUI.Media.fonts = {
    Narrow = "Fonts\\ARIALN.TTF",
    Default = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
    Morpheus = "Fonts\\MORPHEUS.TTF",
    Skurri = "Fonts\\SKURRI.TTF",
}

RUI.Media.fontOrder = { "Narrow", "Default", "Morpheus", "Skurri" }

function RUI:GetFontPath(key)
    local appearance = self.GetAppearanceSettings and self:GetAppearanceSettings() or (self.db and self.db.appearance)
    key = key or (appearance and appearance.font) or "Narrow"
    return self.Media.fonts[key] or self.Media.fonts.Narrow or STANDARD_TEXT_FONT
end

function RUI:GetFontName(key)
    local appearance = self.GetAppearanceSettings and self:GetAppearanceSettings() or (self.db and self.db.appearance)
    key = key or (appearance and appearance.font) or "Narrow"
    if key == "Narrow" then return "Narrow" end
    if key == "Morpheus" then return "Morpheus" end
    if key == "Skurri" then return "Skurri" end
    return "Default"
end

function RUI:GetStatusBarTexture()
    return self.Media.textures.statusbar
end

function RUI:GetNextFontKey(current)
    local order = self.Media.fontOrder
    current = current or "Narrow"

    for i = 1, #order do
        if order[i] == current then
            local nextIndex = i + 1
            if nextIndex > #order then
                nextIndex = 1
            end
            return order[nextIndex]
        end
    end

    return order[1]
end
