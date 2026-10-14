-- ZenUI 1.0.25 configuration window.
-- Native 3.3.5 controls with sectioned page navigation; no external config library.

local RUI = ZenUI
local Config = RUI:NewModule("Config")

local function Round(value)
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
end

local function ConfigMoney(copper)
    copper=tonumber(copper) or 0
    if type(GetCoinTextureString)=="function" then return GetCoinTextureString(copper) end
    local gold=math.floor(copper/10000)
    local silver=math.floor((copper%10000)/100)
    local coin=copper%100
    return string.format("%dg %ds %dc",gold,silver,coin)
end

local ACTION_ROW_CHOICES = { 1, 2, 3, 4, 6, 12 }
local VISIBILITY_ORDER = { "ALWAYS", "COMBAT", "OOC" }
local VISIBILITY_LABELS = { ALWAYS = "Always", COMBAT = "Combat", OOC = "Out of Combat" }
local BANK_QUICK_MODIFIER_ORDER = { "SHIFT", "CTRL", "ALT" }
local BANK_QUICK_MODIFIER_LABELS = { SHIFT = "Shift + Right-click", CTRL = "Ctrl + Right-click", ALT = "Alt + Right-click" }
local LOOT_AUTO_ACTION_ORDER = { "MANUAL", "PASS", "GREED", "DISENCHANT" }
local LOOT_AUTO_ACTION_LABELS = { MANUAL = "Manual", PASS = "Auto Pass", GREED = "Auto Greed", DISENCHANT = "Auto Disenchant" }
local LOOT_QUALITY_LABELS = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }

local function NextLootAutoAction(action)
    action = string.upper(tostring(action or "MANUAL"))
    for i = 1, #LOOT_AUTO_ACTION_ORDER do
        if LOOT_AUTO_ACTION_ORDER[i] == action then
            return LOOT_AUTO_ACTION_ORDER[(i % #LOOT_AUTO_ACTION_ORDER) + 1]
        end
    end
    return "MANUAL"
end

local function LootAutoActionLabel(action)
    return LOOT_AUTO_ACTION_LABELS[string.upper(tostring(action or "MANUAL"))] or "Manual"
end

local function NextVisibilityMode(mode)
    mode = string.upper(tostring(mode or "ALWAYS"))
    for i = 1, #VISIBILITY_ORDER do
        if VISIBILITY_ORDER[i] == mode then return VISIBILITY_ORDER[(i % #VISIBILITY_ORDER) + 1] end
    end
    return VISIBILITY_ORDER[1]
end

local function VisibilityLabel(mode)
    return VISIBILITY_LABELS[string.upper(tostring(mode or "ALWAYS"))] or "Always"
end

local PURE_BIND_MODIFIERS = {
    LSHIFT=true, RSHIFT=true, LCTRL=true, RCTRL=true, LALT=true, RALT=true,
    SHIFT=true, CTRL=true, ALT=true,
}

local function FormatCapturedBindingKey(rawKey)
    if not rawKey or rawKey == "" then return nil end
    rawKey = string.upper(tostring(rawKey))
    if PURE_BIND_MODIFIERS[rawKey] then return nil end
    local prefix = ""
    if IsAltKeyDown and IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    return prefix .. rawKey
end

local function PrettyBindingKey(key)
    if not key or key == "" then return "Unbound" end
    if GetBindingText then
        local text = GetBindingText(key, "KEY_", 1)
        if text and text ~= "" then return text end
    end
    return key
end

local function BindingLabel(command)
    if not command or not GetBindingKey then return "Unbound" end
    local key1, key2 = GetBindingKey(command)
    if not key1 then return "Unbound" end
    if key2 then return PrettyBindingKey(key1) .. " / " .. PrettyBindingKey(key2) end
    return PrettyBindingKey(key1)
end

local function SaveCurrentBindings()
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
end

local function ClearCommandBindings(command)
    if not command or not GetBindingKey or not SetBinding then return false end
    local key1, key2 = GetBindingKey(command)
    if key1 then SetBinding(key1) end
    if key2 then SetBinding(key2) end
    SaveCurrentBindings()
    return key1 or key2
end

local function BindCommandKey(command, key)
    if not command or not key or not SetBinding then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local ok = SetBinding(key, command)
    if ok then SaveCurrentBindings() end
    return ok and true or false
end

local function RowsToSliderIndex(rows)
    rows = tonumber(rows) or 1
    for i = 1, #ACTION_ROW_CHOICES do
        if ACTION_ROW_CHOICES[i] == rows then return i end
    end
    return 1
end

local function SliderIndexToRows(index)
    index = math.max(1, math.min(#ACTION_ROW_CHOICES, Round(index)))
    return ACTION_ROW_CHOICES[index]
end

local function OpenColorPicker(r, g, b, changedCallback)
    if not ColorPickerFrame or not changedCallback then return end

    r, g, b = r or 1, g or 1, b or 1
    local previous = { r, g, b }

    local function ApplyPickerColor(restore)
        local nr, ng, nb
        if restore then
            nr = restore[1] or restore.r or previous[1]
            ng = restore[2] or restore.g or previous[2]
            nb = restore[3] or restore.b or previous[3]
        else
            nr, ng, nb = ColorPickerFrame:GetColorRGB()
        end
        changedCallback(nr, ng, nb)
    end

    ColorPickerFrame.func = function() ApplyPickerColor(nil) end
    ColorPickerFrame.opacityFunc = nil
    ColorPickerFrame.cancelFunc = function(restore) ApplyPickerColor(restore) end
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.previousValues = previous
    ColorPickerFrame:Hide()
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:Show()
end

local function RegisterText(fs, size, muted)
    fs.RUISize = size or 10
    fs.RUIMuted = muted and true or false
    table.insert(Config.texts, fs)
    return fs
end

local function CreateText(parent, text, size, point, relativeTo, relativePoint, x, y, muted)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint(point or "TOPLEFT", relativeTo or parent, relativePoint or point or "TOPLEFT", x or 0, y or 0)
    local r, g, b = RUI:GetTextColor(muted)
    RUI:StyleFontString(fs, size or 10, r, g, b)
    fs:SetText(text or "")
    return RegisterText(fs, size, muted)
end

local function TrackBackdrop(frame)
    table.insert(Config.backdrops, frame)
    return frame
end

local function TrackButton(button)
    table.insert(Config.buttons, button)
    return button
end

local function TrackControl(control)
    table.insert(Config.controls, control)
    return control
end

local function CreateSection(parent, title, x, y, width, height)
    local section = CreateFrame("Frame", nil, parent)
    section:SetWidth(width)
    section:SetHeight(height)
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    RUI:CreateBackdrop(section, "section")
    TrackBackdrop(section)
    section.title = CreateText(section, title, 11, "TOPLEFT", section, "TOPLEFT", 10, -10, false)

    -- Top-level config pages grow as sections are added. The scroll frame stays
    -- dormant on short pages and becomes available only when content overflows.
    if parent.EnsureRUIContentHeight then
        parent:EnsureRUIContentHeight(math.abs(y or 0) + (height or 0) + 12)
    end
    return section
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width or 100)
    button:SetHeight(height or 24)
    button.RUIText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.RUIText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.RUIText:SetWidth(math.max(20, (width or 100) - 12))
    button.RUIText:SetHeight(height or 24)
    button.RUIText:SetJustifyH("CENTER")
    button.RUIText:SetText(text or "Button")
    RegisterText(button.RUIText, 10, false)
    RUI:StyleButton(button)
    return TrackButton(button)
end

local function CreateEditBox(parent, placeholder, width, height)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetWidth(width or 180)
    box:SetHeight(height or 24)
    box:SetAutoFocus(false)
    box:SetFont(RUI:GetFontPath(), 10)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetMaxLetters(250000)
    RUI:CreateBackdrop(box, "input")
    TrackBackdrop(box)
    box.placeholder = CreateText(box, placeholder or "", 9, "LEFT", box, "LEFT", 8, 0, true)
    box:SetScript("OnEditFocusGained", function(self) self.placeholder:Hide() end)
    box:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then self.placeholder:Show() end end)
    box:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" and not self:HasFocus() then self.placeholder:Show() else self.placeholder:Hide() end
        if self.RUIOnTextChanged then self:RUIOnTextChanged() end
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    function box:RefreshStyle()
        RUI:RefreshBackdrop(self)
        self:SetFont(RUI:GetFontPath(), 10)
    end
    return TrackControl(box)
end

local function NormalizeAutoInviteTriggerString(value)
    local source=tostring(value or "inv")
    source=string.gsub(source,"[\r\n;]+",",")
    local out,seen={},{}
    for token in string.gmatch(source..",","(.-),") do
        token=string.gsub(token,"^%s+","")
        token=string.gsub(token,"%s+$","")
        if token~="" then
            local key=string.lower(token)
            if not seen[key] then
                seen[key]=true
                out[#out+1]=token
                if #out>=20 then break end
            end
        end
    end
    if #out==0 then out[1]="inv" end
    return table.concat(out,", ")
end

local function CreateColorSwatch(parent, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width or 28)
    button:SetHeight(height or 24)
    RUI:CreateBackdrop(button, "button")
    TrackBackdrop(button)

    button.color = button:CreateTexture(nil, "ARTWORK")
    button.color:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    button.color:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    button.color:SetTexture(1, 1, 1, 1)

    function button:SetRUIColor(r, g, b)
        self.color:SetTexture(r or 1, g or 1, b or 1, 1)
    end

    function button:RefreshStyle()
        RUI:RefreshBackdrop(self)
    end

    return TrackControl(button)
end

local function CreateCheck(parent, labelText, x, y, callback, width)
    local check = CreateFrame("CheckButton", nil, parent)
    check:SetWidth(width or ((parent:GetWidth() or 250) - 24))
    check:SetHeight(20)
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    check.box = CreateFrame("Frame", nil, check)
    check.box:SetWidth(14)
    check.box:SetHeight(14)
    check.box:SetPoint("LEFT", check, "LEFT", 0, 0)
    RUI:CreateBackdrop(check.box, "input")

    check.mark = check.box:CreateTexture(nil, "OVERLAY")
    check.mark:SetPoint("TOPLEFT", check.box, "TOPLEFT", 3, -3)
    check.mark:SetPoint("BOTTOMRIGHT", check.box, "BOTTOMRIGHT", -3, 3)
    RUI:SetAccentTexture(check.mark)
    check.mark:Hide()

    check.label = CreateText(check, labelText, 10, "LEFT", check.box, "RIGHT", 8, 0, false)
    -- Keep labels inside the control hit rectangle. Long explanatory copy should
    -- live in muted helper text rather than bleeding into neighbouring columns.
    check.label:SetWidth(math.max(40, check:GetWidth() - 24))
    check.label:SetHeight(18)
    check.label:SetJustifyH("LEFT")

    check:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        if checked then self.mark:Show() else self.mark:Hide() end
        if callback then callback(checked) end
    end)

    function check:SetRUIValue(value)
        self:SetChecked(value and true or false)
        if value then self.mark:Show() else self.mark:Hide() end
    end

    function check:RefreshStyle()
        RUI:RefreshBackdrop(self.box)
        RUI:SetAccentTexture(self.mark)
    end

    return TrackControl(check)
end

local function CreateSlider(parent, labelText, x, y, width, minValue, maxValue, step, formatter, callback)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetWidth(width)
    holder:SetHeight(34)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    holder.label = CreateText(holder, labelText, 9, "TOPLEFT", holder, "TOPLEFT", 0, 0, true)
    holder.valueText = CreateText(holder, "", 9, "TOPRIGHT", holder, "TOPRIGHT", 0, 0, false)
    holder.valueText:SetJustifyH("RIGHT")

    local slider = CreateFrame("Slider", nil, holder)
    slider:SetOrientation("HORIZONTAL")
    slider:SetWidth(width)
    slider:SetHeight(14)
    slider:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 1)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)

    slider.track = slider:CreateTexture(nil, "BACKGROUND")
    slider.track:SetHeight(3)
    slider.track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    slider.track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)

    slider:SetThumbTexture(RUI.Media.textures.white)
    slider.thumb = slider:GetThumbTexture()
    slider.thumb:SetWidth(8)
    slider.thumb:SetHeight(14)
    RUI:SetAccentTexture(slider.thumb)

    slider:SetScript("OnValueChanged", function(self, value)
        holder.valueText:SetText(formatter and formatter(value) or tostring(Round(value)))
        if not holder.silent and callback then callback(value) end
    end)

    function holder:SetRUIValue(value)
        self.silent = true
        slider:SetValue(value)
        self.silent = false
        self.valueText:SetText(formatter and formatter(value) or tostring(Round(value)))
    end

    function holder:RefreshStyle()
        local br, bg, bb = RUI:GetBorderColor()
        slider.track:SetTexture(br, bg, bb, 0.85)
        RUI:SetAccentTexture(slider.thumb)
    end

    holder.slider = slider
    return TrackControl(holder)
end

local function ApplyUnitFrameSetting(key, value)
    if not RUI.db or not RUI.db.unitframes then return end
    RUI.db.unitframes[key] = value and true or false
    local unitFrames = RUI:GetModule("UnitFrames")
    if unitFrames and unitFrames.ApplySettings then unitFrames:ApplySettings() end
end

local function ApplyUnitFrameValue(key, value)
    if not RUI.db or not RUI.db.unitframes then return end
    RUI.db.unitframes[key] = value
    local unitFrames = RUI:GetModule("UnitFrames")
    if unitFrames and unitFrames.ApplySettings then unitFrames:ApplySettings() end
end

local function NextAuraPosition(value)
    return string.upper(tostring(value or "TOP")) == "TOP" and "BOTTOM" or "TOP"
end

local function AuraPositionLabel(value)
    return string.upper(tostring(value or "TOP")) == "BOTTOM" and "Bottom" or "Top"
end

local function ApplyRaidSetting(key, value, needsSettings)
    if not RUI.db or not RUI.db.unitframes or not RUI.db.unitframes.raid then return end
    RUI.db.unitframes.raid[key] = value
    local unitFrames = RUI:GetModule("UnitFrames")
    if not unitFrames then return end
    if needsSettings and unitFrames.ApplySettings then
        unitFrames:ApplySettings()
    elseif unitFrames.ApplyAppearance then
        unitFrames:ApplyAppearance()
    end
end

local function ApplyUnitTextSetting(key, value)
    if not RUI.db or not RUI.db.unitframes or not RUI.db.unitframes.text then return end
    RUI.db.unitframes.text[key] = value
    local unitFrames = RUI:GetModule("UnitFrames")
    if unitFrames and unitFrames.ApplyAppearance then unitFrames:ApplyAppearance() end
end

local function ApplyActionBarSetting(key, value)
    if not RUI.db or not RUI.db.actionbars then return end
    RUI.db.actionbars[key] = value
    local actionBars = RUI:GetModule("ActionBars")
    if actionBars and actionBars.ApplySettings then actionBars:ApplySettings() end
end

local function ApplyActionBarBarSetting(index, key, value)
    if not RUI.db or not RUI.db.actionbars or not RUI.db.actionbars.bars then return end
    local bar = RUI.db.actionbars.bars[index]
    if not bar then return end
    bar[key] = value
    local actionBars = RUI:GetModule("ActionBars")
    if actionBars and actionBars.ApplySettings then actionBars:ApplySettings() end
end

local function ApplySpecialBarBehavior(kind, key, value)
    if not RUI.db or not RUI.db.actionbars then return end
    local field = kind == "pet" and "petBehavior" or "stanceBehavior"
    RUI.db.actionbars[field] = RUI.db.actionbars[field] or {}
    RUI.db.actionbars[field][key] = value
    local actionBars = RUI:GetModule("ActionBars")
    if actionBars and actionBars.ApplySettings then actionBars:ApplySettings() end
end

local function ApplyMenuSetting(key, value)
    if not RUI.db then return end
    RUI.db.menu = RUI.db.menu or {}
    RUI.db.menu[key] = value
    local menu = RUI:GetModule("MicroMenu")
    if menu and menu.ApplySettings then menu:ApplySettings() end
end

local function ApplyMinimapSetting(key, value)
    if not RUI.db then return end
    RUI.db.minimap = RUI.db.minimap or {}
    RUI.db.minimap[key] = value
    local minimap = RUI:GetModule("Minimap")
    if minimap and minimap.ApplySettings then minimap:ApplySettings() end
end

local function ApplyTooltipSetting(key, value)
    if not RUI.db then return end
    RUI.db.tooltip = RUI.db.tooltip or {}
    RUI.db.tooltip[key] = value
    local tooltip = RUI:GetModule("Tooltip")
    if tooltip and tooltip.ApplySettings then tooltip:ApplySettings() end
end

local function ApplyChatSetting(key, value)
    if not RUI.db then return end
    RUI.db.chat = RUI.db.chat or {}
    RUI.db.chat[key] = value
    local chat = RUI:GetModule("Chat")
    if chat and chat.ApplySettings then chat:ApplySettings() end
end

local function ApplyMailSetting(key, value)
    if not RUI.db then return end
    RUI.db.mail = RUI.db.mail or {}
    RUI.db.mail[key] = value
    local phaseB = RUI:GetModule("BlizzardPhaseB")
    if phaseB and phaseB.RefreshMail and phaseB.frames and phaseB.frames.mail and phaseB.frames.mail:IsShown() then
        phaseB:RefreshMail()
    end
end

local function ApplyBagSetting(key, value)
    if not RUI.db then return end
    RUI.db.bags = RUI.db.bags or {}
    RUI.db.bags[key] = value
    local bags = RUI:GetModule("Bags")
    if bags and bags.ApplySettings then bags:ApplySettings() end
    if bags and bags.frame and bags.frame:IsShown() and bags.Update then bags:Update() end
end

local function ApplyBagContainerSetting(key, value)
    if not RUI.db then return end
    RUI.db.bags = RUI.db.bags or {}
    RUI.db.bags.containers = RUI.db.bags.containers or {}
    RUI.db.bags.containers[key] = value
    local bags = RUI:GetModule("Bags")
    if bags and bags.ApplySettings then bags:ApplySettings() end
    if bags and bags.frame and bags.frame:IsShown() and bags.Update then bags:Update() end
end

local function ApplyLootSetting(key, value)
    if not RUI.db then return end
    RUI.db.loot = RUI.db.loot or {}
    RUI.db.loot[key] = value
    local loot = RUI:GetModule("LootRolls")
    if loot and loot.ApplySettings then loot:ApplySettings() end
end

local function ApplyLootAutoRule(quality, action)
    if not RUI.db then return end
    RUI.db.loot = RUI.db.loot or {}
    RUI.db.loot.autoRollRules = RUI.db.loot.autoRollRules or {}
    RUI.db.loot.autoRollRules[tonumber(quality) or 0] = string.upper(tostring(action or "MANUAL"))
end

local function ApplyBlizzardSetting(key, value)
    if not RUI.db then return end
    RUI.db.blizzard = RUI.db.blizzard or {}
    RUI.db.blizzard[key] = value and true or false
    local module = RUI:GetModule("BlizzardFrames")
    if module and module.ApplySettings then module:ApplySettings() end
    local phaseB = RUI:GetModule("BlizzardPhaseB")
    if phaseB and phaseB.ApplySettings then phaseB:ApplySettings() end
    local phaseC = RUI:GetModule("BlizzardPhaseC")
    if phaseC and phaseC.ApplySettings then phaseC:ApplySettings() end
    local phaseCPvP = RUI:GetModule("BlizzardPhaseCPvP")
    if phaseCPvP and phaseCPvP.ApplySettings then phaseCPvP:ApplySettings() end
    local phaseCBars = RUI:GetModule("BlizzardPhaseCStatusBars")
    if phaseCBars and phaseCBars.ApplySettings then phaseCBars:ApplySettings() end
    local phaseCAchievements = RUI:GetModule("BlizzardPhaseCAchievements")
    if phaseCAchievements and phaseCAchievements.ApplySettings then phaseCAchievements:ApplySettings() end
    local phaseD = RUI:GetModule("BlizzardPhaseDInteractions")
    if phaseD and phaseD.ApplySettings then phaseD:ApplySettings() end
end

local function ApplyBankContainerSetting(key, value)
    if not RUI.db then return end
    RUI.db.blizzard = RUI.db.blizzard or {}
    RUI.db.blizzard.bankContainers = RUI.db.blizzard.bankContainers or {}
    RUI.db.blizzard.bankContainers[key] = value and true or false
    local phaseB = RUI:GetModule("BlizzardPhaseB")
    if phaseB and phaseB.RefreshBank then phaseB:RefreshBank() end
end

local function ApplyBankQuickDropModifier(value)
    if not RUI.db then return end
    RUI.db.blizzard = RUI.db.blizzard or {}
    value = string.upper(tostring(value or "SHIFT"))
    if not BANK_QUICK_MODIFIER_LABELS[value] then value = "SHIFT" end
    RUI.db.blizzard.bankQuickDropModifier = value
    local bags = RUI:GetModule("Bags")
    if bags and bags.RefreshSecureBagClicks then bags:RefreshSecureBagClicks() end
end

local function ResetBankContainerSettings()
    if not RUI.db then return end
    RUI.db.blizzard = RUI.db.blizzard or {}
    RUI.db.blizzard.bankContainers = { bank=true, bag1=true, bag2=true, bag3=true, bag4=true, bag5=true, bag6=true, bag7=true, void=false }
    local phaseB = RUI:GetModule("BlizzardPhaseB")
    if phaseB and phaseB.RefreshBank then phaseB:RefreshBank() end
end

local function ApplyComponentScale(key, value)
    RUI:SetComponentScale(key, value)
end

local CONFIG_PAGE_HEIGHT = 522
local CONFIG_PAGE_WIDTH = 570
local CONFIG_SCROLL_STEP = 36

local function CreatePage(frame, key, title, description)
    local scroll = CreateFrame("ScrollFrame", nil, frame.content)
    scroll:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 1, -1)
    scroll:SetPoint("BOTTOMRIGHT", frame.content, "BOTTOMRIGHT", -14, 1)
    scroll:EnableMouseWheel(true)

    local page = CreateFrame("Frame", nil, scroll)
    page:SetWidth(CONFIG_PAGE_WIDTH)
    page:SetHeight(CONFIG_PAGE_HEIGHT)
    scroll:SetScrollChild(page)
    page.viewport = scroll
    page.contentHeight = CONFIG_PAGE_HEIGHT

    local scrollbar = CreateFrame("Slider", nil, frame.content)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetWidth(10)
    scrollbar:SetPoint("TOPRIGHT", frame.content, "TOPRIGHT", -3, -8)
    scrollbar:SetPoint("BOTTOMRIGHT", frame.content, "BOTTOMRIGHT", -3, 8)
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValueStep(1)
    scrollbar:Hide()
    page.scrollbar = scrollbar

    scrollbar.track = scrollbar:CreateTexture(nil, "BACKGROUND")
    scrollbar.track:SetWidth(2)
    scrollbar.track:SetPoint("TOP", scrollbar, "TOP", 0, -2)
    scrollbar.track:SetPoint("BOTTOM", scrollbar, "BOTTOM", 0, 2)

    scrollbar:SetThumbTexture(RUI.Media.textures.white)
    scrollbar.thumb = scrollbar:GetThumbTexture()
    scrollbar.thumb:SetWidth(8)
    scrollbar.thumb:SetHeight(30)
    RUI:SetAccentTexture(scrollbar.thumb)

    function scrollbar:RefreshStyle()
        local br, bg, bb = RUI:GetBorderColor()
        self.track:SetTexture(br, bg, bb, 0.85)
        RUI:SetAccentTexture(self.thumb)
    end
    TrackControl(scrollbar)
    scrollbar:RefreshStyle()

    function scroll:UpdateRUIScroll()
        local viewportHeight = self:GetHeight() or CONFIG_PAGE_HEIGHT
        if viewportHeight <= 0 then viewportHeight = CONFIG_PAGE_HEIGHT end
        local maxScroll = math.max(0, (page:GetHeight() or CONFIG_PAGE_HEIGHT) - viewportHeight)
        scrollbar:SetMinMaxValues(0, maxScroll)

        local current = math.max(0, math.min(maxScroll, self:GetVerticalScroll() or 0))
        self:SetVerticalScroll(current)
        self.syncingScrollbar = true
        scrollbar:SetValue(maxScroll - current)
        self.syncingScrollbar = false

        if maxScroll > 0 and self:IsShown() then
            scrollbar:Show()
        else
            scrollbar:Hide()
        end
    end

    function page:SetRUIContentHeight(height)
        height = math.max(CONFIG_PAGE_HEIGHT, Round(height or CONFIG_PAGE_HEIGHT))
        if height == self.contentHeight then return end
        self.contentHeight = height
        self:SetHeight(height)
        if self.viewport and self.viewport.UpdateRUIScroll then self.viewport:UpdateRUIScroll() end
    end

    function page:EnsureRUIContentHeight(height)
        if (height or 0) > (self.contentHeight or CONFIG_PAGE_HEIGHT) then
            self:SetRUIContentHeight(height)
        end
    end

    scrollbar:SetScript("OnValueChanged", function(self, value)
        if scroll.syncingScrollbar then return end
        local _, maxScroll = self:GetMinMaxValues()
        scroll:SetVerticalScroll(math.max(0, maxScroll - value))
    end)

    local function ScrollByWheel(delta)
        local _, maxScroll = scrollbar:GetMinMaxValues()
        if not maxScroll or maxScroll <= 0 then return end
        local target = math.max(0, math.min(maxScroll, (scroll:GetVerticalScroll() or 0) - (delta * CONFIG_SCROLL_STEP)))
        scroll:SetVerticalScroll(target)
        scroll.syncingScrollbar = true
        scrollbar:SetValue(maxScroll - target)
        scroll.syncingScrollbar = false
    end

    scroll:SetScript("OnMouseWheel", function(self, delta) ScrollByWheel(delta) end)
    page:EnableMouseWheel(true)
    page:SetScript("OnMouseWheel", function(self, delta) ScrollByWheel(delta) end)
    scroll:SetScript("OnShow", function(self) self:UpdateRUIScroll() end)

    page.key = key
    page.title = CreateText(page, title, 16, "TOPLEFT", page, "TOPLEFT", 16, -16, false)
    page.description = CreateText(page, description or "", 9, "TOPLEFT", page.title, "BOTTOMLEFT", 0, -7, true)
    page.description:SetWidth(526)
    page.description:SetJustifyH("LEFT")

    scroll:Hide()
    frame.pages[key] = page
    return page
end

local function AddPageMover(frame, page, group, label, returnPage)
    if not page or not group then return nil end
    local button = CreateButton(page, "Move " .. (label or "Section"), 142, 24)
    button:SetPoint("TOPRIGHT", page, "TOPRIGHT", -16, -12)
    button:SetScript("OnClick", function()
        frame:Hide()
        RUI:SetMoverMode(true, group, returnPage or page.key, label)
    end)
    page.moverButton = button
    return button
end

function Config:LayoutNavigation()
    local frame = self.frame
    if not frame or not frame.navGroupOrder then return end
    local y = -12
    for i=1,#frame.navGroupOrder do
        local group = frame.navGroups[frame.navGroupOrder[i]]
        if group then
            group.header:ClearAllPoints()
            group.header:SetPoint("TOPLEFT", frame.sidebar, "TOPLEFT", 11, y)
            group.header.RUIText:SetText((group.expanded and "v  " or ">  ") .. group.label)
            y = y - 30
            if group.expanded then
                for j=1,#group.items do
                    local key = group.items[j][1]
                    local button = frame.navButtons[key]
                    if button then
                        button:ClearAllPoints()
                        button:SetPoint("TOPLEFT", frame.sidebar, "TOPLEFT", 20, y)
                        button:Show()
                        y = y - 27
                    end
                end
            else
                for j=1,#group.items do
                    local button = frame.navButtons[group.items[j][1]]
                    if button then button:Hide() end
                end
            end
        end
    end
end

function Config:SetNavGroup(groupKey)
    local frame = self.frame
    if not frame or not frame.navGroups[groupKey] then return end
    local target = frame.navGroups[groupKey]
    local newState = not target.expanded
    for key, group in pairs(frame.navGroups) do group.expanded = (key == groupKey) and newState or false end
    self:LayoutNavigation()
    self:RefreshNavigation()
end

function Config:SetPage(key)
    local frame = self.frame
    if not frame or not frame.pages[key] then return end
    for pageKey, page in pairs(frame.pages) do
        local viewport = page.viewport or page
        if pageKey == key then
            viewport:Show()
            if viewport.UpdateRUIScroll then viewport:UpdateRUIScroll() end
        else
            viewport:Hide()
            if page.scrollbar then page.scrollbar:Hide() end
        end
    end
    frame.activePage = key
    local groupKey = frame.pageGroups and frame.pageGroups[key]
    if groupKey and frame.navGroups and frame.navGroups[groupKey] then
        for navKey, group in pairs(frame.navGroups) do group.expanded = navKey == groupKey end
        self:LayoutNavigation()
    end
    self:RefreshNavigation()
end

function Config:RefreshNavigation()
    local frame = self.frame
    if not frame then return end
    local ar, ag, ab = RUI:GetAccentColor()
    for key, button in pairs(frame.navButtons) do
        RUI:StyleButton(button)
        if key == frame.activePage then
            RUI:SetBorderColor(button, ar, ag, ab, 1)
            button.activeLine:Show()
            RUI:SetAccentTexture(button.activeLine)
        else
            RUI:RefreshBackdrop(button)
            button.activeLine:Hide()
        end
    end
    if frame.navGroups then
        local activeGroup = frame.pageGroups and frame.pageGroups[frame.activePage]
        for key, group in pairs(frame.navGroups) do
            RUI:StyleButton(group.header)
            if key == activeGroup then RUI:SetBorderColor(group.header, ar, ag, ab, 0.85) else RUI:RefreshBackdrop(group.header) end
        end
    end
end

local function ConfigSearchNormalize(value)
    return string.lower(tostring(value or "")):gsub("[^%w]+","")
end

local function CollectConfigSearchText(node,chunks,seen,depth)
    if not node or seen[node] or (depth or 0)>8 then return end
    seen[node]=true
    if node.GetRegions then
        local regions={node:GetRegions()}
        for i=1,#regions do
            local region=regions[i]
            if region and region.GetText then
                local ok,text=pcall(region.GetText,region)
                if ok and text and tostring(text)~="" then table.insert(chunks,tostring(text)) end
            end
        end
    end
    if node.GetChildren then
        local children={node:GetChildren()}
        for i=1,#children do CollectConfigSearchText(children[i],chunks,seen,(depth or 0)+1) end
    end
end

local CONFIG_SEARCH_ALIASES={
    ACTIONBARS="actionbar actionbars hotbar hotbars ability abilities buttons paging stance pet totem",
    BARBEHAVIOR="bar behavior mouseover visibility alpha",
    GROUPS="party raid groups group frames ready check",
    AUTO_INVITE="auto invite autoinvite whisper trigger triggers inv plus me group invite",
    UNITFRAMES="player target focus pet castbar resources portraits",
    AURAS="aura auras buff buffs debuff debuffs player target focus pet top bottom",
    KEYBINDS="keybind keybinds hotkey hotkeys bindings character progression skill tree mounts",
    MENU="quick menu launcher floating button q button",
    MINIMAP="clock timezone time zone minimap tracking",
    CHAT="chat transparency opacity input editbox",
    BAGS="bag bags inventory sort split stack",
    BANK="bank void extended bank",
    LOOT="loot rolls autoloot auto loot",
    PANELS_A="character spellbook social friends guild quest mail core panels",
    PANELS_B="merchant trade trainer service panels",
    PANELS_C="talents glyphs progression echoes skill tree mounts companions prestige",
    PANELS_D="gossip conversation npc interaction inspect trainer",
    APPEARANCE="dark mode darkmode opacity transparency colour color theme",
    LAYOUT="move mover movers snapping grid position",
    PROFILES="profile profiles import export",
}

function Config:BuildSearchIndex()
    local frame=self.frame
    if not frame or not frame.pages then return end
    frame.searchIndex={}
    for key,page in pairs(frame.pages) do
        if not (frame.hiddenPages and frame.hiddenPages[key]) then
        local chunks={tostring(key)}
        local button=frame.navButtons and frame.navButtons[key]
        local label=(button and button.RUIText and button.RUIText.GetText and button.RUIText:GetText()) or key
        table.insert(chunks,tostring(label or key))
        local groupKey=frame.pageGroups and frame.pageGroups[key]
        local group=groupKey and frame.navGroups and frame.navGroups[groupKey]
        if group and group.label then table.insert(chunks,tostring(group.label)) end
        if CONFIG_SEARCH_ALIASES[key] then table.insert(chunks,CONFIG_SEARCH_ALIASES[key]) end
        CollectConfigSearchText(page,chunks,{},0)
        local combined=table.concat(chunks," ")
        frame.searchIndex[#frame.searchIndex+1]={
            key=key,
            label=tostring(label or key),
            group=(group and group.label) or "ZenUI",
            normalized=ConfigSearchNormalize(combined),
            labelNormalized=ConfigSearchNormalize(label),
        }
        end
    end
end

function Config:UpdateSearchResults()
    local frame=self.frame
    if not frame or not frame.searchBox or not frame.searchResults then return end
    local raw=frame.searchBox:GetText() or ""
    local query=ConfigSearchNormalize(raw)
    if query=="" then frame.searchResults:Hide(); return end
    if not frame.searchIndex then self:BuildSearchIndex() end

    local matches={}
    for i=1,#(frame.searchIndex or {}) do
        local entry=frame.searchIndex[i]
        local pos=entry.normalized and string.find(entry.normalized,query,1,true)
        if pos then
            local score=20+(pos or 999)
            if entry.labelNormalized==query then score=0
            elseif entry.labelNormalized and string.find(entry.labelNormalized,query,1,true)==1 then score=5 end
            matches[#matches+1]={entry=entry,score=score}
        end
    end
    table.sort(matches,function(a,b)
        if a.score==b.score then return a.entry.label<b.entry.label end
        return a.score<b.score
    end)

    frame.searchFirstPage=nil
    for i=1,#frame.searchResultButtons do
        local button=frame.searchResultButtons[i]
        local match=matches[i]
        if match then
            button.pageKey=match.entry.key
            button.RUIText:SetText(match.entry.label.."   |cff777777"..match.entry.group.."|r")
            button:Show()
            if not frame.searchFirstPage then frame.searchFirstPage=match.entry.key end
        else
            button.pageKey=nil
            button:Hide()
        end
    end
    if #matches>0 then
        frame.searchResults:SetHeight(10+(math.min(#matches,#frame.searchResultButtons)*25))
        frame.searchResults:Show()
    else
        frame.searchResults:SetHeight(36)
        frame.searchNoResults:Show()
        frame.searchResults:Show()
    end
    if #matches>0 then frame.searchNoResults:Hide() end
end

function Config:OnInitialize()
    self.texts = {}
    self.backdrops = {}
    self.buttons = {}
    self.controls = {}

    local frame = CreateFrame("Frame", "ZenUIConfigFrame", UIParent)
    frame:SetWidth(780)
    frame:SetHeight(620)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    if RUI.RegisterExclusivePanel then RUI:RegisterExclusivePanel(frame) end
    RUI:CreateBackdrop(frame)
    TrackBackdrop(frame)
    frame.accent = RUI:CreateAccentLine(frame, 2)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    frame.title = CreateText(frame, "ZenUI", 15, "TOPLEFT", frame, "TOPLEFT", 16, -18, false)
    frame.subtitle = CreateText(frame, tostring(RUI.version or "1.0.3") .. "  •  Profiles & sharing", 9, "LEFT", frame.title, "RIGHT", 10, -1, true)
    frame.close = CreateButton(frame, "X", 26, 22)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    frame.searchBox = CreateEditBox(frame, "Search settings...", 250, 24)
    frame.searchBox:SetPoint("TOPRIGHT", frame.close, "TOPLEFT", -8, 0)
    frame.searchBox:SetMaxLetters(64)

    frame.searchResults = CreateFrame("Frame", nil, frame)
    frame.searchResults:SetWidth(318)
    frame.searchResults:SetHeight(36)
    frame.searchResults:SetPoint("TOPRIGHT", frame.searchBox, "BOTTOMRIGHT", 0, -4)
    frame.searchResults:SetFrameStrata("DIALOG")
    frame.searchResults:SetFrameLevel(frame:GetFrameLevel()+80)
    RUI:CreateBackdrop(frame.searchResults)
    TrackBackdrop(frame.searchResults)
    frame.searchResults:Hide()
    frame.searchResultButtons={}
    for i=1,8 do
        local result=CreateButton(frame.searchResults, "", 300, 22)
        result:SetPoint("TOPLEFT", frame.searchResults, "TOPLEFT", 9, -7-((i-1)*25))
        result.RUIText:SetJustifyH("LEFT")
        result.RUIText:ClearAllPoints(); result.RUIText:SetPoint("LEFT", result, "LEFT", 9, 0)
        result:SetScript("OnClick",function(self)
            if not self.pageKey then return end
            Config:SetPage(self.pageKey)
            frame.searchResults:Hide()
            frame.searchBox:ClearFocus()
        end)
        frame.searchResultButtons[i]=result
    end
    frame.searchNoResults=CreateText(frame.searchResults,"No matching ZenUI settings.",9,"TOPLEFT",frame.searchResults,"TOPLEFT",10,-12,true)
    frame.searchNoResults:Hide()
    frame.searchBox.RUIOnTextChanged=function() Config:UpdateSearchResults() end
    frame.searchBox:SetScript("OnEnterPressed",function(self)
        if frame.searchFirstPage then Config:SetPage(frame.searchFirstPage); frame.searchResults:Hide() end
        self:ClearFocus()
    end)
    frame.searchBox:SetScript("OnEscapePressed",function(self)
        if self:GetText()~="" then self:SetText(""); frame.searchResults:Hide() else self:ClearFocus() end
    end)

    frame.sidebar = CreateFrame("Frame", nil, frame)
    frame.sidebar:SetWidth(154)
    frame.sidebar:SetHeight(524)
    frame.sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -54)
    RUI:CreateBackdrop(frame.sidebar)
    TrackBackdrop(frame.sidebar)

    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetWidth(584)
    frame.content:SetHeight(524)
    frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 182, -54)
    RUI:CreateBackdrop(frame.content)
    TrackBackdrop(frame.content)

    frame.pages = {}
    frame.navButtons = {}
    frame.navGroups = {}
    -- Developer-only pages remain compiled and callable, but never appear in
    -- release navigation or settings search.
    frame.hiddenPages = { SYSTEM = true }
    frame.navGroupOrder = { "GENERAL", "HUD", "INTERFACE", "PANELS", "SYSTEM" }
    local navGroups = {
        { "GENERAL", "GENERAL", { {"GENERAL","General"}, {"APPEARANCE","Appearance"} } },
        { "HUD", "HUD & COMBAT", { {"UNITFRAMES","Unit Frames"}, {"AURAS","Aura Layout"}, {"GROUPS","Party & Raid"}, {"AUTO_INVITE","Auto Invite"}, {"TEXT","Unit Text"}, {"ACTIONBARS","Action Bars"}, {"BARBEHAVIOR","Bar Behavior"}, {"KEYBINDS","Keybinds"} } },
        { "INTERFACE", "INTERFACE", { {"MENU","Menu & Launcher"}, {"MINIMAP","Minimap"}, {"TOOLTIP","Tooltip"}, {"CHAT","Chat"}, {"BAGS","Bags"}, {"LOOT","Loot & Rolls"}, {"BANK","Bank & Void"} } },
        { "PANELS", "ZEN PANELS", { {"PANELS_A","Core Panels"}, {"PANELS_B","Service Panels"}, {"MAIL","Mail"}, {"PANELS_C","Progression"}, {"PANELS_D","Interactions"} } },
        { "SYSTEM", "SYSTEM", { {"LAYOUT","Layout"}, {"PROFILES","Profiles"} } },
    }
    frame.pageGroups = {}
    for i=1,#navGroups do
        local def = navGroups[i]
        local groupKey, groupLabel, items = def[1], def[2], def[3]
        local header = CreateButton(frame.sidebar, groupLabel, 132, 24)
        header.RUIText:SetJustifyH("LEFT")
        header.RUIText:ClearAllPoints(); header.RUIText:SetPoint("LEFT", header, "LEFT", 10, 0)
        header.RUIText:SetWidth(120)
        local group = { key=groupKey, label=groupLabel, items=items, header=header, expanded=(groupKey=="GENERAL") }
        frame.navGroups[groupKey] = group
        local headerKey = groupKey
        header:SetScript("OnClick", function() Config:SetNavGroup(headerKey) end)
        for j=1,#items do
            local key, label = items[j][1], items[j][2]
            frame.pageGroups[key] = groupKey
            local button = CreateButton(frame.sidebar, label, 123, 22)
            button.RUIText:SetJustifyH("LEFT")
            button.RUIText:ClearAllPoints(); button.RUIText:SetPoint("LEFT", button, "LEFT", 11, 0)
            button.RUIText:SetWidth(110)
            button.activeLine = button:CreateTexture(nil, "OVERLAY")
            button.activeLine:SetWidth(2)
            button.activeLine:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            button.activeLine:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
            button.activeLine:Hide()
            local pageKey = key
            button:SetScript("OnClick", function() Config:SetPage(pageKey) end)
            frame.navButtons[key] = button
        end
    end
    self:LayoutNavigation()

    -- GENERAL
    local general = CreatePage(frame, "GENERAL", "General", "ZenUI status and package overview.")
    general.status = CreateSection(general, "CURRENT BUILD", 16, -74, 552, 126)
    general.versionLabel = CreateText(general.status, "VERSION", 9, "TOPLEFT", general.status, "TOPLEFT", 12, -42, true)
    general.versionValue = CreateText(general.status, RUI.version or "1.0.25", 11, "TOPRIGHT", general.status, "TOPRIGHT", -12, -42, false)
    general.interfaceLabel = CreateText(general.status, "CLIENT", 9, "TOPLEFT", general.status, "TOPLEFT", 12, -70, true)
    general.interfaceValue = CreateText(general.status, "3.3.5a / 30300", 11, "TOPRIGHT", general.status, "TOPRIGHT", -12, -70, false)
    general.profileLabel = CreateText(general.status, "PROFILE", 9, "TOPLEFT", general.status, "TOPLEFT", 12, -98, true)
    general.profileValue = CreateText(general.status, "Default", 11, "TOPRIGHT", general.status, "TOPRIGHT", -12, -98, false)
    general.note = CreateText(general, "ZenUI now covers gameplay frames, action bars, group layouts, launcher, minimap, tooltip, chat, unified bags and common Blizzard panel styling. Companion addons can register into the Zen menu automatically.", 10, "TOPLEFT", general, "TOPLEFT", 24, -250, true)
    general.note:SetWidth(520)
    general.note:SetJustifyH("LEFT")

    -- APPEARANCE / ZENSTYLINGPACK
    local appearance = CreatePage(frame, "APPEARANCE", "Appearance", "ZenStylingPack visuals with optional shared settings through EbonAPI.")

    appearance.source = CreateSection(appearance, "STYLE SOURCE", 16, -74, 552, 92)
    frame.appearanceModeLabel = CreateText(appearance.source, "THEME SETTINGS", 9, "TOPLEFT", appearance.source, "TOPLEFT", 14, -38, true)
    frame.appearanceModeButton = CreateButton(appearance.source, "Global (EbonAPI)", 190, 26)
    frame.appearanceModeButton:SetPoint("TOPLEFT", appearance.source, "TOPLEFT", 122, -30)
    frame.appearanceModeStatus = CreateText(appearance.source, "", 9, "LEFT", frame.appearanceModeButton, "RIGHT", 12, 0, true)
    frame.appearanceModeStatus:SetWidth(210)
    frame.appearanceModeButton:SetScript("OnClick", function()
        local current = RUI.GetAppearanceMode and RUI:GetAppearanceMode() or "LOCAL"
        local target = current == "GLOBAL" and "LOCAL" or "GLOBAL"
        if not (RUI.SetAppearanceMode and RUI:SetAppearanceMode(target)) then
            RUI:Print("Global styling requires EbonAPI. ZenUI is staying on local appearance settings.")
        end
        Config:Refresh()
    end)

    appearance.style = CreateSection(appearance, "VISUAL STYLE & ACCENT", 16, -178, 552, 276)
    frame.appearanceStyleButtons = {}
    local themes = RUI.GetAppearanceThemes and RUI:GetAppearanceThemes() or {}
    local themeOrder = RUI.GetAppearanceThemeOrder and RUI:GetAppearanceThemeOrder() or {"CLASSIC","OBSIDIAN","GLASS"}
    for i = 1, #themeOrder do
        local key = themeOrder[i]
        local preset = themes and themes[key]
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local button = CreateButton(appearance.style, (preset and preset.label) or key, 166, 40)
        button:SetPoint("TOPLEFT", appearance.style, "TOPLEFT", 14 + (col * 174), -36 - (row * 46))
        button.RUIText:SetJustifyH("LEFT")
        button.RUIText:ClearAllPoints(); button.RUIText:SetPoint("LEFT", button, "LEFT", 42, 0)
        button.RUIText:SetWidth(114)
        button.RUIStyleKey = key
        button.preview = button:CreateTexture(nil, "ARTWORK")
        button.preview:SetWidth(24); button.preview:SetHeight(22)
        button.preview:SetPoint("LEFT", button, "LEFT", 10, 0)
        local bg = preset and preset.background or {0.04,0.04,0.05}
        button.preview:SetTexture(bg[1] or 0.04, bg[2] or 0.04, bg[3] or 0.05, 1)
        button.previewBorder = button:CreateTexture(nil, "OVERLAY")
        button.previewBorder:SetPoint("TOPLEFT", button.preview, "TOPLEFT", 0, 0)
        button.previewBorder:SetPoint("TOPRIGHT", button.preview, "TOPRIGHT", 0, 0)
        button.previewBorder:SetHeight(2)
        local border = preset and preset.border or {0.15,0.16,0.18}
        button.previewBorder:SetTexture(border[1] or .15, border[2] or .16, border[3] or .18, 1)
        button:SetScript("OnClick", function(self)
            if RUI.SetAppearanceStyle and RUI:SetAppearanceStyle(self.RUIStyleKey) then Config:Refresh() end
        end)
        frame.appearanceStyleButtons[key] = button
    end

    frame.appearanceAccentLabel = CreateText(appearance.style, "ACCENT COLOUR", 9, "TOPLEFT", appearance.style, "TOPLEFT", 14, -137, true)
    frame.appearanceAccentButtons = {}
    local accentDefs = RUI.GetAppearanceAccentPresets and RUI:GetAppearanceAccentPresets() or {}
    for i = 1, #accentDefs do
        local def = accentDefs[i]
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local button = CreateButton(appearance.style, def.label or def.key or "Accent", 124, 28)
        button:SetPoint("TOPLEFT", appearance.style, "TOPLEFT", 14 + (col * 130), -156 - (row * 34))
        button.RUIText:SetJustifyH("LEFT")
        button.RUIText:ClearAllPoints(); button.RUIText:SetPoint("LEFT", button, "LEFT", 29, 0)
        button.RUIText:SetWidth(88)
        button.RUIAccentPreset = def.rgb
        button.swatch = button:CreateTexture(nil, "ARTWORK")
        button.swatch:SetWidth(12); button.swatch:SetHeight(12)
        button.swatch:SetPoint("LEFT", button, "LEFT", 8, 0)
        local c = def.rgb or {1,1,1}
        button.swatch:SetTexture(c[1] or 1, c[2] or 1, c[3] or 1, 1)
        button:SetScript("OnClick", function(self)
            local rgb = self.RUIAccentPreset
            if rgb and RUI.SetAppearanceAccent then
                RUI:SetAppearanceAccent(rgb[1], rgb[2], rgb[3])
                Config:Refresh()
            end
        end)
        frame.appearanceAccentButtons[i] = button
    end

    appearance.preview = CreateSection(appearance, "LIVE PREVIEW", 16, -466, 552, 150)
    frame.appearancePreviewPanel = CreateFrame("Frame", nil, appearance.preview)
    frame.appearancePreviewPanel:SetPoint("TOPLEFT", appearance.preview, "TOPLEFT", 14, -36)
    frame.appearancePreviewPanel:SetWidth(522); frame.appearancePreviewPanel:SetHeight(98)
    RUI:CreateBackdrop(frame.appearancePreviewPanel); TrackBackdrop(frame.appearancePreviewPanel)
    frame.appearancePreviewAccent = RUI:CreateAccentLine(frame.appearancePreviewPanel, 2)
    frame.appearancePreviewTitle = CreateText(frame.appearancePreviewPanel, "ZenUI", 12, "TOPLEFT", frame.appearancePreviewPanel, "TOPLEFT", 12, -13, false)
    frame.appearancePreviewSub = CreateText(frame.appearancePreviewPanel, "ZenStylingPack", 9, "LEFT", frame.appearancePreviewTitle, "RIGHT", 10, 0, true)
    frame.appearancePreviewSelected = CreateButton(frame.appearancePreviewPanel, "Selected", 112, 26)
    frame.appearancePreviewSelected:SetPoint("TOPLEFT", frame.appearancePreviewPanel, "TOPLEFT", 12, -42)
    frame.appearancePreviewTab = CreateButton(frame.appearancePreviewPanel, "Tab", 112, 26)
    frame.appearancePreviewTab:SetPoint("LEFT", frame.appearancePreviewSelected, "RIGHT", 8, 0)
    frame.appearancePreviewAction = CreateButton(frame.appearancePreviewPanel, "Button", 112, 26)
    frame.appearancePreviewAction:SetPoint("LEFT", frame.appearancePreviewTab, "RIGHT", 8, 0)
    frame.appearancePreviewStatus = CreateText(frame.appearancePreviewPanel, "Ready", 10, "LEFT", frame.appearancePreviewAction, "RIGHT", 20, 0, true)

    appearance.main = CreateSection(appearance, "FINE TUNING", 16, -628, 552, 272)
    frame.scale = CreateSlider(appearance.main, "UI SCALE", 14, -42, 250, 70, 140, 5, function(v) return tostring(Round(v)) .. "%" end, function(v)
        if RUI.SetAppearanceScale then RUI:SetAppearanceScale(Round(v) / 100) end
    end)
    frame.alpha = CreateSlider(appearance.main, "PANEL OPACITY", 286, -42, 250, 30, 100, 1, function(v) return tostring(Round(v)) .. "%" end, function(v)
        if RUI.SetAppearancePanelAlpha then RUI:SetAppearancePanelAlpha(Round(v) / 100) end
    end)
    frame.fontLabel = CreateText(appearance.main, "TYPE STYLE", 9, "TOPLEFT", appearance.main, "TOPLEFT", 14, -103, true)
    frame.fontButton = CreateButton(appearance.main, "Narrow", 146, 24)
    frame.fontButton:SetPoint("TOPLEFT", appearance.main, "TOPLEFT", 118, -95)
    frame.fontButton:SetScript("OnClick", function()
        local a = RUI.GetAppearanceSettings and RUI:GetAppearanceSettings() or RUI.db.appearance
        local nextFont = RUI:GetNextFontKey(a and a.font)
        if RUI.SetAppearanceFont then RUI:SetAppearanceFont(nextFont) end
        Config:Refresh()
    end)

    frame.accentPickerLabel = CreateText(appearance.main, "CUSTOM ACCENT", 9, "TOPLEFT", appearance.main, "TOPLEFT", 286, -103, true)
    frame.accentPicker = CreateButton(appearance.main, "Pick Colour", 128, 24)
    frame.accentPicker:SetPoint("TOPRIGHT", appearance.main, "TOPRIGHT", -16, -95)
    local function OpenAccentPicker()
        local r, g, b = RUI:GetAccentColor()
        OpenColorPicker(r, g, b, function(nr, ng, nb)
            if RUI.SetAppearanceAccent then RUI:SetAppearanceAccent(nr, ng, nb) end
            Config:Refresh()
        end)
    end
    frame.accentPicker:SetScript("OnClick", OpenAccentPicker)
    frame.accentSwatch = CreateColorSwatch(appearance.main, 28, 24)
    frame.accentSwatch:SetPoint("RIGHT", frame.accentPicker, "LEFT", -8, 0)
    frame.accentSwatch:SetScript("OnClick", OpenAccentPicker)

    local function SetAccentChannel(channel, value)
        local r, g, b = RUI:GetAccentColor()
        if channel == 1 then r = Round(value) / 100 elseif channel == 2 then g = Round(value) / 100 else b = Round(value) / 100 end
        if RUI.SetAppearanceAccent then RUI:SetAppearanceAccent(r, g, b) end
    end
    frame.red = CreateSlider(appearance.main, "RED", 14, -154, 160, 0, 100, 1, function(v) return tostring(Round(v)) end, function(v) SetAccentChannel(1, v) end)
    frame.green = CreateSlider(appearance.main, "GREEN", 194, -154, 160, 0, 100, 1, function(v) return tostring(Round(v)) end, function(v) SetAccentChannel(2, v) end)
    frame.blue = CreateSlider(appearance.main, "BLUE", 374, -154, 160, 0, 100, 1, function(v) return tostring(Round(v)) end, function(v) SetAccentChannel(3, v) end)

    frame.resetAppearance = CreateButton(appearance.main, "Reset Current Style", 146, 24)
    frame.resetAppearance:SetPoint("BOTTOMLEFT", appearance.main, "BOTTOMLEFT", 14, 14)
    frame.resetAppearance:SetScript("OnClick", function()
        if RUI:GetAppearanceMode() == "GLOBAL" and RUI.StylingPack then
            RUI:SetAppearanceStyle("CLASSIC")
            RUI:SetAppearanceAccent(0.92, 0.63, 0.40)
            RUI:SetAppearancePanelAlpha(0.96)
            RUI:SetAppearanceScale(1)
            RUI:SetAppearanceFont("Narrow")
        else
            RUI:ResetAppearance()
        end
        Config:Refresh(); RUI:Print("Current appearance scope reset to Zen defaults.")
    end)
    frame.resetScales = CreateButton(appearance.main, "Reset Section Scales", 158, 24)
    frame.resetScales:SetPoint("LEFT", frame.resetAppearance, "RIGHT", 10, 0)
    frame.resetScales:SetScript("OnClick", function()
        RUI:ResetComponentScales(); Config:Refresh(); RUI:Print("Section scales reset to 100%.")
    end)
    local appearanceNote = CreateText(appearance.main, "Global shares this style with other ZenStylingPack addons through EbonAPI. Local keeps an independent ZenUI appearance. Layout and per-panel scales remain ZenUI profile settings.", 9, "BOTTOMLEFT", appearance.main, "BOTTOMLEFT", 14, 50, true)
    appearanceNote:SetWidth(520); appearanceNote:SetJustifyH("LEFT")

    -- UNIT FRAMES
    local uf = CreatePage(frame, "UNITFRAMES", "Unit Frames", "Solo combat frames and their attached elements.")
    AddPageMover(frame, uf, "unitframes", "Unit Frames", "UNITFRAMES")
    uf.main = CreateSection(uf, "PLAYER / TARGET / FOCUS / PET", 16, -74, 552, 344)
    frame.ufEnable = CreateCheck(uf.main, "Enable ZenUI unit frames", 14, -42, function(v) ApplyUnitFrameSetting("enabled", v) end)
    frame.ufBlizzard = CreateCheck(uf.main, "Hide Blizzard unit / party frames", 14, -72, function(v) ApplyUnitFrameSetting("hideBlizzard", v) end)
    frame.ufCastbars = CreateCheck(uf.main, "Show unit castbars", 14, -102, function(v) ApplyUnitFrameSetting("showCastbars", v) end)
    frame.ufTargetTarget = CreateCheck(uf.main, "Show target-of-target", 14, -132, function(v) ApplyUnitFrameSetting("showTargetTarget", v) end)
    frame.ufResources = CreateCheck(uf.main, "Show class resources", 14, -162, function(v) ApplyUnitFrameSetting("showClassResources", v) end)
    frame.ufPortraits = CreateCheck(uf.main, "Show unit portraits", 286, -42, function(v) ApplyUnitFrameSetting("showPortraits", v) end)
    frame.ufFocus = CreateCheck(uf.main, "Show focus frame", 286, -72, function(v) ApplyUnitFrameSetting("showFocus", v) end)
    frame.ufFocusTarget = CreateCheck(uf.main, "Show focus target", 286, -102, function(v) ApplyUnitFrameSetting("showFocusTarget", v) end)
    frame.ufPet = CreateCheck(uf.main, "Show pet frame", 286, -132, function(v) ApplyUnitFrameSetting("showPet", v) end)
    frame.scaleUnitFrames = CreateSlider(uf.main, "FRAME SCALE", 286, -186, 244, 50, 150, 5,
        function(v) return tostring(Round(v)) .. "%" end,
        function(v) ApplyComponentScale("unitframes", Round(v) / 100) end)
    -- Keep two-column CheckButton hit rectangles inside their own columns.
    -- In 0.2.0 the default full-section width let left controls cover the right side.
    local ufColumnChecks = { frame.ufEnable, frame.ufBlizzard, frame.ufCastbars, frame.ufTargetTarget, frame.ufResources, frame.ufPortraits, frame.ufFocus, frame.ufFocusTarget, frame.ufPet }
    for i = 1, #ufColumnChecks do
        ufColumnChecks[i]:SetWidth(244)
        if ufColumnChecks[i].label then ufColumnChecks[i].label:SetWidth(220) end
    end
    local ufNote = CreateText(uf.main, "This scale affects Player, Target, Focus and Pet together. Party/Raid scales live on their own page.", 9, "BOTTOMLEFT", uf.main, "BOTTOMLEFT", 14, 16, true)

    -- AURA LAYOUT
    local auras = CreatePage(frame, "AURAS", "Aura Layout", "Choose which solo unit frames show buffs/debuffs and place each row above or below the frame.")

    local function BuildAuraSection(parent, title, x, y, showKey, buffKey, debuffKey, prefix)
        local section = CreateSection(parent, title, x, y, 264, 184)
        frame[prefix .. "Enable"] = CreateCheck(section, "Show buffs / debuffs", 14, -42, function(v) ApplyUnitFrameSetting(showKey, v) end, 232)

        CreateText(section, "BUFFS", 9, "TOPLEFT", section, "TOPLEFT", 14, -82, true)
        frame[prefix .. "Buff"] = CreateButton(section, "Top", 104, 24)
        frame[prefix .. "Buff"]:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14, -70)
        frame[prefix .. "Buff"]:SetScript("OnClick", function()
            local ufdb = RUI.db and RUI.db.unitframes
            if not ufdb then return end
            ApplyUnitFrameValue(buffKey, NextAuraPosition(ufdb[buffKey]))
            Config:Refresh()
        end)

        CreateText(section, "DEBUFFS", 9, "TOPLEFT", section, "TOPLEFT", 14, -126, true)
        frame[prefix .. "Debuff"] = CreateButton(section, "Bottom", 104, 24)
        frame[prefix .. "Debuff"]:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14, -114)
        frame[prefix .. "Debuff"]:SetScript("OnClick", function()
            local ufdb = RUI.db and RUI.db.unitframes
            if not ufdb then return end
            ApplyUnitFrameValue(debuffKey, NextAuraPosition(ufdb[debuffKey]))
            Config:Refresh()
        end)
        return section
    end

    BuildAuraSection(auras, "PLAYER", 16, -74, "showPlayerAuras", "playerBuffPosition", "playerDebuffPosition", "auraPlayer")
    BuildAuraSection(auras, "TARGET", 304, -74, "showTargetAuras", "targetBuffPosition", "targetDebuffPosition", "auraTarget")
    BuildAuraSection(auras, "FOCUS", 16, -270, "showFocusAuras", "focusBuffPosition", "focusDebuffPosition", "auraFocus")
    BuildAuraSection(auras, "PET", 304, -270, "showPetAuras", "petBuffPosition", "petDebuffPosition", "auraPet")

    local auraNote = CreateText(auras, "If Buffs and Debuffs use the same side, ZenUI stacks them automatically. Bottom rows sit below attached cast/resource/target-of-target elements so icons do not cover them.", 9, "BOTTOMLEFT", auras, "BOTTOMLEFT", 24, 18, true)
    auraNote:SetWidth(520); auraNote:SetJustifyH("LEFT")

    -- PARTY & RAID
    local groups = CreatePage(frame, "GROUPS", "Party & Raid", "Configure group frames while grouped or use preview mode while solo.")
    AddPageMover(frame, groups, "groups", "Party & Raid", "GROUPS")
    groups.party = CreateSection(groups, "PARTY", 16, -74, 552, 152)
    frame.ufParty = CreateCheck(groups.party, "Show party frames", 14, -42, function(v) ApplyUnitFrameSetting("showParty", v) end, 250)
    local partyNote = CreateText(groups.party, "Hidden automatically while you are in a raid.", 8, "TOPLEFT", groups.party, "TOPLEFT", 36, -66, true)
    partyNote:SetWidth(226); partyNote:SetJustifyH("LEFT")
    frame.scaleParty = CreateSlider(groups.party, "PARTY SCALE", 286, -42, 250, 50, 150, 5,
        function(v) return tostring(Round(v)) .. "%" end,
        function(v) ApplyComponentScale("party", Round(v) / 100) end)
    frame.previewParty = CreateButton(groups.party, "Preview Party", 132, 24)
    frame.previewParty:SetPoint("BOTTOMLEFT", groups.party, "BOTTOMLEFT", 14, 14)
    frame.previewParty:SetScript("OnClick", function()
        local m = RUI:GetModule("UnitFrames")
        if m and m.ToggleGroupPreview then m:ToggleGroupPreview("party"); Config:Refresh() end
    end)

    groups.raid = CreateSection(groups, "RAID", 16, -238, 552, 296)
    frame.ufRaid = CreateCheck(groups.raid, "Show ZenUI raid frames", 14, -42, function(v) ApplyUnitFrameSetting("showRaid", v) end, 244)
    frame.scaleRaid = CreateSlider(groups.raid, "RAID SCALE", 286, -42, 250, 50, 150, 5,
        function(v) return tostring(Round(v)) .. "%" end,
        function(v) ApplyComponentScale("raid", Round(v) / 100) end)
    frame.raidGroups = CreateSlider(groups.raid, "MAX RAID GROUPS", 14, -94, 248, 1, 8, 1, function(v) return tostring(Round(v)) .. " / " .. tostring(Round(v) * 5) end, function(v)
        ApplyRaidSetting("groups", Round(v), true)
    end)
    frame.raidOrientationLabel = CreateText(groups.raid, "GROUP LAYOUT", 9, "TOPLEFT", groups.raid, "TOPLEFT", 286, -94, true)
    frame.raidOrientationButton = CreateButton(groups.raid, "Columns", 148, 24)
    frame.raidOrientationButton:SetPoint("TOPRIGHT", groups.raid, "TOPRIGHT", -14, -86)
    frame.raidOrientationButton:SetScript("OnClick", function()
        local raid = RUI.db.unitframes.raid
        raid.orientation = raid.orientation == "VERTICAL" and "HORIZONTAL" or "VERTICAL"
        ApplyRaidSetting("orientation", raid.orientation, true); Config:Refresh()
    end)
    frame.raidGroupLabels = CreateCheck(groups.raid, "Show group labels", 14, -146, function(v) ApplyRaidSetting("showGroupLabels", v, false) end, 244)
    frame.raidPower = CreateCheck(groups.raid, "Show compact power bars", 14, -174, function(v) ApplyRaidSetting("showPower", v, false) end, 244)
    frame.raidDebuffs = CreateCheck(groups.raid, "Show debuff indicator", 14, -202, function(v) ApplyRaidSetting("showDebuffs", v, false) end, 244)
    frame.raidReady = CreateCheck(groups.raid, "Show ready-check indicator", 286, -146, function(v) ApplyRaidSetting("showReady", v, false) end, 244)
    frame.raidRank = CreateCheck(groups.raid, "Show leader / assistant mark", 286, -174, function(v) ApplyRaidSetting("showRank", v, false) end, 244)
    frame.raidHealthLabel = CreateText(groups.raid, "HEALTH TEXT", 9, "TOPLEFT", groups.raid, "TOPLEFT", 286, -212, true)
    frame.raidHealthButton = CreateButton(groups.raid, "Percent", 148, 24)
    frame.raidHealthButton:SetPoint("TOPRIGHT", groups.raid, "TOPRIGHT", -14, -204)
    frame.raidHealthButton:SetScript("OnClick", function()
        local raid = RUI.db.unitframes.raid
        local order = { "PERCENT", "DEFICIT", "CURRENT", "NONE" }
        local current = raid.healthMode or "PERCENT"
        local nextMode = order[1]
        for i = 1, #order do if order[i] == current then nextMode = order[(i % #order) + 1]; break end end
        raid.healthMode = nextMode
        local unitFrames = RUI:GetModule("UnitFrames"); if unitFrames then unitFrames:UpdateRaidFrames() end
        Config:Refresh()
    end)
    frame.previewRaid = CreateButton(groups.raid, "Preview Raid", 132, 24)
    frame.previewRaid:SetPoint("BOTTOMLEFT", groups.raid, "BOTTOMLEFT", 14, 14)
    frame.previewRaid:SetScript("OnClick", function()
        local m = RUI:GetModule("UnitFrames")
        if m and m.ToggleGroupPreview then m:ToggleGroupPreview("raid"); Config:Refresh() end
    end)
    local previewNote = CreateText(groups.raid, "Preview is temporary and turns itself off when a real party/raid becomes available.", 8, "BOTTOMRIGHT", groups.raid, "BOTTOMRIGHT", -14, 19, true)
    previewNote:SetWidth(330); previewNote:SetJustifyH("RIGHT")

    -- AUTO INVITE
    local autoInvite = CreatePage(frame, "AUTO_INVITE", "Auto Invite", "Queue whisper-triggered group invites reliably and choose the messages that are allowed to request one.")
    autoInvite.main = CreateSection(autoInvite, "AUTO INVITE", 16, -74, 552, 286)
    frame.autoInviteEnable = CreateCheck(autoInvite.main, "Enable Auto Invite", 14, -42, function(v)
        local panels=RUI:GetModule("BlizzardFrames")
        if panels and panels.SetAutoInviteEnabled then panels:SetAutoInviteEnabled(v) end
    end, 250)
    local autoInviteNote = CreateText(autoInvite.main, "Matching whispers are queued and sent one at a time, so two people messaging at nearly the same moment are not lost to invite throttling.", 9, "TOPLEFT", autoInvite.main, "TOPLEFT", 14, -74, true)
    autoInviteNote:SetWidth(520); autoInviteNote:SetJustifyH("LEFT")
    local triggerLabel = CreateText(autoInvite.main, "ALLOWED INVITE MESSAGES", 9, "TOPLEFT", autoInvite.main, "TOPLEFT", 14, -120, true)
    frame.autoInviteTriggers = CreateEditBox(autoInvite.main, "inv, +, me", 520, 26)
    frame.autoInviteTriggers:SetPoint("TOPLEFT", autoInvite.main, "TOPLEFT", 14, -140)
    frame.autoInviteTriggers:SetMaxLetters(220)
    local triggerHelp = CreateText(autoInvite.main, "Comma-separated, case-insensitive. Custom entries match the complete whisper after spaces are trimmed. The original 'inv' trigger also keeps its standalone-word behavior.", 8, "TOPLEFT", autoInvite.main, "TOPLEFT", 14, -174, true)
    triggerHelp:SetWidth(520); triggerHelp:SetJustifyH("LEFT")
    frame.autoInviteSave = CreateButton(autoInvite.main, "Save Invite Messages", 170, 24)
    frame.autoInviteSave:SetPoint("TOPLEFT", autoInvite.main, "TOPLEFT", 14, -224)
    frame.autoInviteDefaults = CreateButton(autoInvite.main, "Reset to inv", 120, 24)
    frame.autoInviteDefaults:SetPoint("LEFT", frame.autoInviteSave, "RIGHT", 10, 0)
    local function SaveAutoInviteTriggers()
        if not RUI.db then return end
        RUI.db.groupTools=RUI.db.groupTools or {}
        local normalized=NormalizeAutoInviteTriggerString(frame.autoInviteTriggers:GetText())
        RUI.db.groupTools.autoInviteTriggers=normalized
        frame.autoInviteTriggers:SetText(normalized)
        frame.autoInviteTriggers:ClearFocus()
        RUI:Print("Auto Invite messages: "..normalized)
    end
    frame.autoInviteSave:SetScript("OnClick", SaveAutoInviteTriggers)
    frame.autoInviteDefaults:SetScript("OnClick", function()
        frame.autoInviteTriggers:SetText("inv")
        SaveAutoInviteTriggers()
    end)
    frame.autoInviteTriggers:SetScript("OnEnterPressed", function(self) SaveAutoInviteTriggers() end)
    frame.autoInviteTriggers:SetScript("OnEscapePressed", function(self) Config:Refresh(); self:ClearFocus() end)

    -- UNIT TEXT
    local text = CreatePage(frame, "TEXT", "Unit Text", "Typography and visible data fields for Player, Target, Focus, Pet, Party and Raid frames.")
    AddPageMover(frame, text, "unitframes", "Unit Frames", "TEXT")
    text.style = CreateSection(text, "STYLE", 16, -74, 268, 344)
    text.content = CreateSection(text, "CONTENT / AUTO-FIT", 300, -74, 268, 344)
    frame.ufTextFontLabel = CreateText(text.style, "FONT", 9, "TOPLEFT", text.style, "TOPLEFT", 14, -42, true)
    frame.ufTextFontButton = CreateButton(text.style, "Default", 132, 24)
    frame.ufTextFontButton:SetPoint("TOPRIGHT", text.style, "TOPRIGHT", -14, -34)
    frame.ufTextFontButton:SetScript("OnClick", function()
        RUI.db.unitframes.text.font = RUI:GetNextFontKey(RUI.db.unitframes.text.font)
        local m=RUI:GetModule("UnitFrames"); if m then m:ApplyAppearance() end; Config:Refresh()
    end)
    frame.ufTextSize = CreateSlider(text.style, "TEXT SIZE", 14, -82, 240, 80, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v)
        ApplyUnitTextSetting("size", Round(v) / 100)
    end)
    frame.ufTextStyleLabel = CreateText(text.style, "STYLE", 9, "TOPLEFT", text.style, "TOPLEFT", 14, -136, true)
    frame.ufTextStyleButton = CreateButton(text.style, "Outline", 132, 24)
    frame.ufTextStyleButton:SetPoint("TOPRIGHT", text.style, "TOPRIGHT", -14, -128)
    frame.ufTextStyleButton:SetScript("OnClick", function()
        local t=RUI.db.unitframes.text; local order={"SHADOW","OUTLINE","BOLD","PLAIN"}; local n=order[1]
        for i=1,#order do if order[i]==(t.style or "OUTLINE") then n=order[(i%#order)+1]; break end end
        ApplyUnitTextSetting("style",n); Config:Refresh()
    end)
    frame.ufTextColorLabel = CreateText(text.style, "COLOUR", 9, "TOPLEFT", text.style, "TOPLEFT", 14, -176, true)
    frame.ufTextPicker = CreateColorSwatch(text.style, 28, 24)
    frame.ufTextPicker:SetPoint("TOPLEFT", text.style, "TOPLEFT", 86, -168)
    frame.ufTextPicker:SetScript("OnClick", function()
        local t = RUI.db.unitframes.text
        local c = t.customColor or { 1, 1, 1 }
        OpenColorPicker(c[1], c[2], c[3], function(r, g, b)
            t.customColor[1], t.customColor[2], t.customColor[3] = r, g, b
            t.colorMode = "CUSTOM"
            local m = RUI:GetModule("UnitFrames"); if m then m:ApplyAppearance() end
            Config:Refresh()
        end)
    end)
    frame.ufTextColorButton = CreateButton(text.style, "Light", 132, 24)
    frame.ufTextColorButton:SetPoint("TOPRIGHT", text.style, "TOPRIGHT", -14, -168)
    frame.ufTextColorButton:SetScript("OnClick", function()
        local t=RUI.db.unitframes.text; local order={"LIGHT","ACCENT","CUSTOM"}; local n=order[1]
        for i=1,#order do if order[i]==(t.colorMode or "LIGHT") then n=order[(i%#order)+1]; break end end
        ApplyUnitTextSetting("colorMode",n); Config:Refresh()
    end)
    local function SetUFColor(index,v)
        RUI.db.unitframes.text.customColor[index]=Round(v)/100
        if RUI.db.unitframes.text.colorMode=="CUSTOM" then local m=RUI:GetModule("UnitFrames"); if m then m:ApplyAppearance() end end
    end
    frame.ufTextRed = CreateSlider(text.style, "CUSTOM RED", 14, -214, 240, 0, 100, 1, function(v) return tostring(Round(v)) end, function(v) SetUFColor(1,v) end)
    frame.ufTextGreen = CreateSlider(text.style, "CUSTOM GREEN", 14, -254, 240, 0, 100, 1, function(v) return tostring(Round(v)) end, function(v) SetUFColor(2,v) end)
    frame.ufTextBlue = CreateSlider(text.style, "CUSTOM BLUE", 14, -294, 240, 0, 100, 1, function(v) return tostring(Round(v)) end, function(v) SetUFColor(3,v) end)

    frame.ufTextAutoFit = CreateCheck(text.content, "Auto-fit long text", 14, -42, function(v) ApplyUnitTextSetting("autoFit", v) end)
    frame.ufTextMinScale = CreateSlider(text.content, "MIN AUTO SIZE", 14, -76, 240, 50, 100, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyUnitTextSetting("minScale",Round(v)/100) end)
    frame.ufTextShowName = CreateCheck(text.content, "Show name", 14, -126, function(v) ApplyUnitTextSetting("showName",v) end)
    frame.ufTextShowLevel = CreateCheck(text.content, "Show level", 14, -153, function(v) ApplyUnitTextSetting("showLevel",v) end)
    frame.ufTextShowClass = CreateCheck(text.content, "Show class / type", 14, -180, function(v) ApplyUnitTextSetting("showClass",v) end)
    frame.ufTextShowHealthValue = CreateCheck(text.content, "Show health value", 14, -207, function(v) ApplyUnitTextSetting("showHealthValue",v) end)
    frame.ufTextShowHealthPercent = CreateCheck(text.content, "Show health percent", 14, -234, function(v) ApplyUnitTextSetting("showHealthPercent",v) end)
    frame.ufTextShowPowerValue = CreateCheck(text.content, "Show power value", 14, -261, function(v) ApplyUnitTextSetting("showPowerValue",v) end)
    frame.ufTextShowPowerMax = CreateCheck(text.content, "Show power maximum", 14, -288, function(v) ApplyUnitTextSetting("showPowerMax",v) end)
    frame.resetUFText = CreateButton(text, "Reset Unit Text", 140, 24)
    frame.resetUFText:SetPoint("BOTTOMLEFT", text, "BOTTOMLEFT", 16, 18)
    frame.resetUFText:SetScript("OnClick", function()
        RUI.db.unitframes.text = { font="Default",size=1.10,style="OUTLINE",colorMode="LIGHT",customColor={1,1,1},autoFit=true,minScale=0.70,showName=true,showLevel=true,showClass=true,showHealthValue=true,showHealthPercent=true,showPowerValue=true,showPowerMax=true }
        local m=RUI:GetModule("UnitFrames"); if m then m:ApplyAppearance() end; Config:Refresh(); RUI:Print("Unit-frame text reset to defaults.")
    end)

    -- ACTION BARS
    local action = CreatePage(frame, "ACTIONBARS", "Action Bars", "All six normal Wrath action pages, plus pet and stance/form controls. Structural changes are deferred in combat.")
    AddPageMover(frame, action, "actionbars", "Action Bars", "ACTIONBARS")
    action.style = CreateSection(action, "STYLE / BEHAVIOR", 16, -74, 552, 194)
    frame.abEnable = CreateCheck(action.style, "Enable ZenUI action bars", 14, -40, function(v) ApplyActionBarSetting("enabled", v) end, 244)
    frame.abHideArt = CreateCheck(action.style, "Hide Blizzard bar artwork", 286, -40, function(v) ApplyActionBarSetting("hideBlizzardArt", v) end, 244)
    frame.abHotkeys = CreateCheck(action.style, "Show hotkeys", 14, -68, function(v) ApplyActionBarSetting("showHotkeys", v) end, 150)
    frame.abMacro = CreateCheck(action.style, "Show macro names", 180, -68, function(v) ApplyActionBarSetting("showMacroText", v) end, 164)
    frame.abEmpty = CreateCheck(action.style, "Show empty buttons", 360, -68, function(v) ApplyActionBarSetting("showEmptyButtons", v) end, 176)
    frame.abSize = CreateSlider(action.style, "BUTTON SIZE", 14, -100, 250, 24, 48, 1, function(v) return tostring(Round(v)) .. "px" end, function(v)
        ApplyActionBarSetting("buttonSize", Round(v))
    end)
    frame.abSpacing = CreateSlider(action.style, "BUTTON SPACING", 286, -100, 250, 0, 12, 1, function(v) return tostring(Round(v)) .. "px" end, function(v)
        ApplyActionBarSetting("spacing", Round(v))
    end)
    frame.scaleActionBars = CreateSlider(action.style, "ACTION BAR SCALE", 14, -146, 250, 50, 150, 5,
        function(v) return tostring(Round(v)) .. "%" end,
        function(v) ApplyComponentScale("actionbars", Round(v) / 100) end)

    action.bars = CreateSection(action, "NORMAL ACTION PAGES", 16, -278, 552, 186)
    frame.abBarChecks = {}
    frame.abRowSliders = {}
    frame.abButtonSliders = {}
    local barPositions = {
        { 1, "Bar 1 / Main", 14, -34, 14, -52 },
        { 2, "Bar 2 / Page 2", 14, -84, 14, -102 },
        { 3, "Bar 3 / Right", 14, -134, 14, -152 },
        { 4, "Bar 4 / Left", 286, -34, 286, -52 },
        { 5, "Bar 5 / Bottom Right", 286, -84, 286, -102 },
        { 6, "Bar 6 / Bottom Left", 286, -134, 286, -152 },
    }
    for i = 1, #barPositions do
        local data = barPositions[i]
        local index = data[1]
        local check = CreateCheck(action.bars, data[2], data[3], data[4], function(v) ApplyActionBarBarSetting(index, "enabled", v) end, 244)
        frame.abBarChecks[index] = check
        local rowSlider = CreateSlider(action.bars, "ROWS", data[5], data[6], 112, 1, #ACTION_ROW_CHOICES, 1,
            function(v)
                local rows = SliderIndexToRows(v)
                return tostring(rows)
            end,
            function(v)
                ApplyActionBarBarSetting(index, "rows", SliderIndexToRows(v))
            end)
        frame.abRowSliders[index] = rowSlider
        local buttonSlider = CreateSlider(action.bars, "BUTTONS", data[5] + 132, data[6], 112, 1, 12, 1,
            function(v) return tostring(Round(v)) end,
            function(v) ApplyActionBarBarSetting(index, "buttons", Round(v)) end)
        frame.abButtonSliders[index] = buttonSlider
    end

    action.special = CreateSection(action, "SPECIAL BARS", 16, -474, 552, 96)
    frame.abPet = CreateCheck(action.special, "Pet action bar", 14, -38, function(v) ApplyActionBarSetting("showPetBar", v) end, 244)
    frame.abStance = CreateCheck(action.special, "Stance / form bar", 286, -38, function(v) ApplyActionBarSetting("showStanceBar", v) end, 244)
    frame.abTotem = CreateCheck(action.special, "Shaman totem bar", 14, -70, function(v) ApplyActionBarSetting("showTotemBar", v) end, 244)
    frame.abTotemTimers = CreateCheck(action.special, "Shaman totem timers", 286, -70, function(v) ApplyActionBarSetting("showTotemTimers", v) end, 244)

    action.description:SetWidth(370)
    frame.resetActionBars = CreateButton(action, "Reset Action Bars", 132, 24)
    frame.resetActionBars:SetPoint("TOPRIGHT", action, "TOPRIGHT", -16, -34)
    frame.resetActionBars:SetScript("OnClick", function()
        RUI:ResetActionBars()
        Config:Refresh()
        RUI:Print("ActionBar settings reset to ZenUI defaults. Mover positions were preserved.")
    end)

    -- BAR BEHAVIOR
    local behavior = CreatePage(frame, "BARBEHAVIOR", "Bar Behavior", "Secure visibility states, idle opacity and mouseover behavior for normal and special action bars.")
    AddPageMover(frame, behavior, "actionbars", "Action Bars", "BARBEHAVIOR")
    behavior.normal = CreateSection(behavior, "NORMAL BAR BEHAVIOR", 16, -74, 552, 314)
    frame.abAlphaSliders = {}
    frame.abMouseoverChecks = {}
    frame.abVisibilityButtons = {}
    local behaviorPositions = {
        { 1, "Bar 1 / Main", 14, -38 },
        { 2, "Bar 2 / Page 2", 14, -126 },
        { 3, "Bar 3 / Right", 14, -214 },
        { 4, "Bar 4 / Left", 286, -38 },
        { 5, "Bar 5 / Bottom Right", 286, -126 },
        { 6, "Bar 6 / Bottom Left", 286, -214 },
    }
    for i = 1, #behaviorPositions do
        local data = behaviorPositions[i]
        local index, label, x, y = data[1], data[2], data[3], data[4]
        local labelText = CreateText(behavior.normal, label, 10, "TOPLEFT", behavior.normal, "TOPLEFT", x, y, false)
        frame.abVisibilityButtons[index] = CreateButton(behavior.normal, "Always", 104, 22)
        frame.abVisibilityButtons[index]:SetPoint("TOPRIGHT", behavior.normal, "TOPLEFT", x + 244, y + 4)
        frame.abVisibilityButtons[index]:SetScript("OnClick", function()
            local bar = RUI.db and RUI.db.actionbars and RUI.db.actionbars.bars and RUI.db.actionbars.bars[index]
            if not bar then return end
            bar.visibility = NextVisibilityMode(bar.visibility)
            ApplyActionBarBarSetting(index, "visibility", bar.visibility)
            frame.abVisibilityButtons[index].RUIText:SetText(VisibilityLabel(bar.visibility))
        end)
        frame.abMouseoverChecks[index] = CreateCheck(behavior.normal, "Reveal on hover", x, y - 28, function(v)
            ApplyActionBarBarSetting(index, "mouseover", v)
        end, 122)
        frame.abAlphaSliders[index] = CreateSlider(behavior.normal, "IDLE ALPHA", x + 132, y - 30, 112, 10, 100, 5,
            function(v) return tostring(Round(v)) .. "%" end,
            function(v) ApplyActionBarBarSetting(index, "alpha", Round(v) / 100) end)
    end

    behavior.special = CreateSection(behavior, "SPECIAL BAR BEHAVIOR", 16, -400, 552, 148)

    local petTitle = CreateText(behavior.special, "PET BAR", 10, "TOPLEFT", behavior.special, "TOPLEFT", 14, -34, false)
    frame.abPetVisibility = CreateButton(behavior.special, "Visibility: Always", 144, 22)
    frame.abPetVisibility:SetPoint("TOPRIGHT", behavior.special, "TOPLEFT", 258, -26)
    frame.abPetVisibility:SetScript("OnClick", function()
        local b = RUI.db and RUI.db.actionbars and RUI.db.actionbars.petBehavior
        if not b then return end
        b.visibility = NextVisibilityMode(b.visibility)
        ApplySpecialBarBehavior("pet", "visibility", b.visibility)
        frame.abPetVisibility.RUIText:SetText("Visibility: " .. VisibilityLabel(b.visibility))
    end)
    frame.abPetMouseover = CreateCheck(behavior.special, "Reveal on hover", 14, -68, function(v) ApplySpecialBarBehavior("pet", "mouseover", v) end, 238)
    frame.abPetAlpha = CreateSlider(behavior.special, "IDLE ALPHA", 14, -96, 238, 10, 100, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplySpecialBarBehavior("pet", "alpha", Round(v) / 100) end)

    local stanceTitle = CreateText(behavior.special, "STANCE / FORM BAR", 10, "TOPLEFT", behavior.special, "TOPLEFT", 286, -34, false)
    frame.abStanceVisibility = CreateButton(behavior.special, "Visibility: Always", 144, 22)
    frame.abStanceVisibility:SetPoint("TOPRIGHT", behavior.special, "TOPRIGHT", -14, -26)
    frame.abStanceVisibility:SetScript("OnClick", function()
        local b = RUI.db and RUI.db.actionbars and RUI.db.actionbars.stanceBehavior
        if not b then return end
        b.visibility = NextVisibilityMode(b.visibility)
        ApplySpecialBarBehavior("stance", "visibility", b.visibility)
        frame.abStanceVisibility.RUIText:SetText("Visibility: " .. VisibilityLabel(b.visibility))
    end)
    frame.abStanceMouseover = CreateCheck(behavior.special, "Reveal on hover", 286, -68, function(v) ApplySpecialBarBehavior("stance", "mouseover", v) end, 238)
    frame.abStanceAlpha = CreateSlider(behavior.special, "IDLE ALPHA", 286, -96, 238, 10, 100, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplySpecialBarBehavior("stance", "alpha", Round(v) / 100) end)

    local stateHint = CreateText(behavior, "Hidden + mouseover keeps the secure button footprint active at zero alpha, so Combat/OOC bars can still reveal on rollover.", 8, "BOTTOMLEFT", behavior, "BOTTOMLEFT", 18, 4, true)
    stateHint:SetWidth(540)
    stateHint:SetJustifyH("LEFT")

    -- KEYBINDS
    local keybinds = CreatePage(frame, "KEYBINDS", "Keybinds", "Hover-based binding for the six normal action bars and the native pet action bar, using WoW's native binding commands.")
    AddPageMover(frame, keybinds, "actionbars", "Action Bars", "KEYBINDS")
    keybinds.main = CreateSection(keybinds, "ZEN KEYBIND MODE", 16, -74, 552, 210)
    local bindHelp = CreateText(keybinds.main, "Enter keybind mode, hover a normal action button or pet ability and press a key. Delete or Backspace clears the hovered button. Escape or the Finish button exits and returns here. Combat automatically closes keybind mode.", 10, "TOPLEFT", keybinds.main, "TOPLEFT", 14, -40, true)
    bindHelp:SetWidth(520)
    bindHelp:SetJustifyH("LEFT")
    local bindNote = CreateText(keybinds.main, "Bars configured as Combat Only are temporarily revealed while keybind mode is active. If a pet action bar is available, its ten native slots are also revealed and can be rebound the same way.", 9, "TOPLEFT", bindHelp, "BOTTOMLEFT", 0, -18, true)
    bindNote:SetWidth(520)
    bindNote:SetJustifyH("LEFT")
    frame.bindModeButton = CreateButton(keybinds.main, "Enter Keybind Mode", 180, 28)
    frame.bindModeButton:SetPoint("BOTTOMLEFT", keybinds.main, "BOTTOMLEFT", 14, 18)
    frame.bindModeButton:SetScript("OnClick", function()
        local module = RUI:GetModule("ActionBars")
        if module and module.SetKeybindMode then module:SetKeybindMode(true, true) end
    end)

    keybinds.progression = CreateSection(keybinds, "CHARACTER PROGRESSION SHORTCUTS", 16, -304, 552, 294)
    keybinds:SetRUIContentHeight(620)
    local progressionHelp = CreateText(keybinds.progression, "Bind any Ebonhold Character Progression page directly. Click a binding button, then press the key combination you want. Delete/Backspace clears it; Escape cancels.", 9, "TOPLEFT", keybinds.progression, "TOPLEFT", 14, -36, true)
    progressionHelp:SetWidth(520); progressionHelp:SetJustifyH("LEFT")

    frame.progressionBindingButtons = {}
    local progressionDefs = {
        { "ZEN_PROGRESSION_MAIN", "Progression" },
        { "ZEN_PROGRESSION_ECHOES", "Echoes" },
        { "ZEN_PROGRESSION_SKILLTREE", "Skill Tree" },
        { "ZEN_PROGRESSION_TRANSMOGRIFY", "Transmogrify" },
        { "ZEN_PROGRESSION_MOUNTS", "Mounts" },
        { "ZEN_PROGRESSION_COMPANIONS", "Companions" },
        { "ZEN_PROGRESSION_PRESTIGE", "Prestige" },
    }
    for i = 1, #progressionDefs do
        local command, label = progressionDefs[i][1], progressionDefs[i][2]
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = column == 0 and 14 or 284
        local y = -82 - (row * 42)
        local labelText = CreateText(keybinds.progression, label, 10, "TOPLEFT", keybinds.progression, "TOPLEFT", x, y, false)
        labelText:SetWidth(92); labelText:SetJustifyH("LEFT")
        local button = CreateButton(keybinds.progression, "Unbound", 150, 24)
        button:SetPoint("TOPLEFT", keybinds.progression, "TOPLEFT", x + 98, y + 6)
        button.RUIBindingCommand = command
        button.RUIBindingLabel = label
        button:SetScript("OnClick", function(self)
            if InCombatLockdown and InCombatLockdown() then RUI:Print("Key bindings cannot be changed during combat."); return end
            Config:BeginProgressionBinding(self.RUIBindingCommand, self.RUIBindingLabel)
        end)
        frame.progressionBindingButtons[command] = button
    end

    frame.progressionMountDefault = CreateButton(keybinds.progression, "Restore Mounts: Shift+P", 196, 24)
    frame.progressionMountDefault:SetPoint("BOTTOMLEFT", keybinds.progression, "BOTTOMLEFT", 14, 14)
    frame.progressionMountDefault:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then RUI:Print("Key bindings cannot be changed during combat."); return end
        if BindCommandKey("ZEN_PROGRESSION_MOUNTS", "SHIFT-P") then
            RUI:Print("Character Progression: Mounts bound to Shift+P.")
            Config:RefreshProgressionBindings()
        else
            RUI:Print("Unable to bind Shift+P right now.")
        end
    end)
    local bindingNote = CreateText(keybinds.progression, "These are real WoW key bindings and also appear under ZenUI in the normal Key Bindings menu.", 8, "BOTTOMLEFT", keybinds.progression, "BOTTOMLEFT", 222, 20, true)
    bindingNote:SetWidth(314); bindingNote:SetJustifyH("LEFT")

    -- One compact keyboard-capture dialog is reused by all six page actions.
    local capture = CreateFrame("Frame", "ZenUIProgressionBindingCapture", UIParent)
    capture:SetWidth(420); capture:SetHeight(132); capture:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    capture:SetFrameStrata("FULLSCREEN_DIALOG"); capture:EnableMouse(true); capture:EnableKeyboard(true); capture:SetClampedToScreen(true); capture:Hide()
    RUI:CreateBackdrop(capture); TrackBackdrop(capture)
    capture.accent = RUI:CreateAccentLine(capture, 2)
    capture.title = CreateText(capture, "Set Character Progression Keybind", 12, "TOPLEFT", capture, "TOPLEFT", 16, -18, false)
    capture.message = CreateText(capture, "Press a key...", 10, "TOPLEFT", capture, "TOPLEFT", 16, -50, true)
    capture.message:SetWidth(388); capture.message:SetJustifyH("LEFT")
    capture.cancel = CreateButton(capture, "Cancel", 94, 24); capture.cancel:SetPoint("BOTTOMRIGHT", capture, "BOTTOMRIGHT", -14, 12)
    capture.cancel:SetScript("OnClick", function() capture:Hide() end)
    capture:SetScript("OnShow", function(self) self:EnableKeyboard(true); if self.Raise then self:Raise() end end)
    capture:SetScript("OnHide", function(self) self.command=nil; self.label=nil end)
    capture:SetScript("OnKeyDown", function(self, rawKey)
        if rawKey == "ESCAPE" then self:Hide(); return end
        local command, label = self.command, self.label
        if not command then self:Hide(); return end
        if rawKey == "DELETE" or rawKey == "BACKSPACE" then
            ClearCommandBindings(command)
            RUI:Print("Cleared Character Progression: " .. tostring(label) .. " binding.")
            self:Hide(); Config:RefreshProgressionBindings(); return
        end
        local key = FormatCapturedBindingKey(rawKey)
        if not key then return end
        if BindCommandKey(command, key) then
            RUI:Print("Bound " .. key .. " to Character Progression: " .. tostring(label) .. ".")
            self:Hide(); Config:RefreshProgressionBindings()
        end
    end)
    frame.progressionBindingCapture = capture

    -- MENU & BAGS
    local menu = CreatePage(frame, "MENU", "Menu & Launcher", "ZenUI launcher, bag access and the companion-addon hub.")
    AddPageMover(frame, menu, "menu", "Menu & Launcher", "MENU")
    menu.main = CreateSection(menu, "ZEN LAUNCHER", 16, -74, 552, 244)
    frame.menuEnable = CreateCheck(menu.main, "Enable Zen menu launcher", 14, -42, function(v) ApplyMenuSetting("enabled", v) end, 250)
    frame.menuHideBlizzard = CreateCheck(menu.main, "Hide Blizzard micro menu / bag buttons", 286, -42, function(v) ApplyMenuSetting("hideBlizzard", v) end, 250)
    frame.menuBag = CreateCheck(menu.main, "Show Zen bag button", 14, -76, function(v) ApplyMenuSetting("showBagButton", v) end, 250)
    frame.menuFreeSlots = CreateCheck(menu.main, "Show free-slot count", 286, -76, function(v) ApplyMenuSetting("showFreeSlots", v) end, 250)
    frame.menuCloseOnClick = CreateCheck(menu.main, "Close menu after selection", 14, -110, function(v) ApplyMenuSetting("closeOnClick", v) end, 250)
    frame.menuQuick = CreateCheck(menu.main, "Show floating Quick Menu button", 14, -144, function(v) ApplyMenuSetting("showQuickMenu", v) end, 250)
    frame.scaleMenu = CreateSlider(menu.main, "LAUNCHER / MENU SCALE", 286, -116, 250, 50, 150, 5,
        function(v) return tostring(Round(v)) .. "%" end,
        function(v) ApplyComponentScale("menu", Round(v) / 100) end)
    frame.menuOpenButton = CreateButton(menu.main, "Open Zen Menu", 160, 26)
    frame.menuOpenButton:SetPoint("BOTTOMLEFT", menu.main, "BOTTOMLEFT", 14, 18)
    frame.menuOpenButton:SetScript("OnClick", function()
        local m = RUI:GetModule("MicroMenu")
        if m and m.ToggleMenu then m:ToggleMenu() end
    end)
    frame.menuAddonCount = CreateText(menu.main, "Registered companion addons: 0", 9, "BOTTOMRIGHT", menu.main, "BOTTOMRIGHT", -14, 24, true)
    frame.menuAddonCount:SetJustifyH("RIGHT")

    menu.echoSwap = CreateSection(menu, "ECHO SAVED BUILDS", 16, -330, 552, 120)
    local echoInfo = CreateText(menu.echoSwap, "The floating Q menu shows Ebonhold Saved Builds only. When EbonAPI 2.1+ is enabled, ZenUI uses its normalized server build state and live update events; otherwise ZenUI falls back to Ebonhold's native Saved Build service. ZenUI never stores or recreates Echo choices.", 9, "TOPLEFT", menu.echoSwap, "TOPLEFT", 14, -40, true)
    echoInfo:SetWidth(520)
    echoInfo:SetJustifyH("LEFT")
    frame.menuEchoRefresh = CreateButton(menu.echoSwap, "Refresh Saved Builds", 180, 26)
    frame.menuEchoRefresh:SetPoint("BOTTOMLEFT", menu.echoSwap, "BOTTOMLEFT", 14, 14)
    frame.menuEchoRefresh:SetScript("OnClick", function()
        local m = RUI:GetModule("MicroMenu")
        if m and m.RefreshEchoBuildList then
            local builds = m:RefreshEchoBuildList(false, true)
            if builds and #builds > 0 then RUI:Print("Found " .. tostring(#builds) .. " Echo Saved Build(s).") end
        end
    end)

    menu.info = CreateSection(menu, "COMPANION ADDONS", 16, -466, 552, 144)
    local menuInfo = CreateText(menu.info, "Addons can register with ZenUI:RegisterAddon(id, data). Registered addons appear automatically under the ZEN ADDONS section of the popup. Left-click launches OnClick; right-click can open OnConfig when supplied.", 9, "TOPLEFT", menu.info, "TOPLEFT", 14, -42, true)
    menuInfo:SetWidth(520)
    menuInfo:SetJustifyH("LEFT")

    -- MINIMAP
    local minimap = CreatePage(frame, "MINIMAP", "Minimap", "ZenUI shell, native Wrath minimap controls and addon-button dock.")
    AddPageMover(frame, minimap, "minimap", "Minimap", "MINIMAP")
    minimap.main = CreateSection(minimap, "MINIMAP FRAME", 16, -74, 552, 234)
    frame.mmEnable = CreateCheck(minimap.main, "Enable ZenUI minimap", 14, -42, function(v) ApplyMinimapSetting("enabled", v) end, 250)
    frame.mmZone = CreateCheck(minimap.main, "Show zone text", 286, -42, function(v) ApplyMinimapSetting("showZone", v) end, 250)
    frame.mmClock = CreateCheck(minimap.main, "Show clock", 14, -74, function(v) ApplyMinimapSetting("showClock", v) end, 250)
    frame.mmClock24 = CreateCheck(minimap.main, "24-hour clock", 286, -74, function(v) ApplyMinimapSetting("clock24", v) end, 250)
    frame.mmWheel = CreateCheck(minimap.main, "Mouse-wheel zoom", 14, -106, function(v) ApplyMinimapSetting("mouseWheelZoom", v) end, 250)
    frame.mmZoomButtons = CreateCheck(minimap.main, "Show native zoom buttons", 286, -106, function(v) ApplyMinimapSetting("showZoomButtons", v) end, 250)
    frame.mmWorldMap = CreateCheck(minimap.main, "Show world-map button", 14, -138, function(v) ApplyMinimapSetting("showWorldMapButton", v) end, 250)
    frame.mmSize = CreateSlider(minimap.main, "MINIMAP SIZE", 286, -140, 250, 120, 260, 2, function(v) return tostring(Round(v)) .. "px" end, function(v) ApplyMinimapSetting("size", Round(v)) end)
    frame.mmClockOffset = CreateSlider(minimap.main, "CLOCK OFFSET", 14, -186, 250, -720, 840, 30,
        function(v)
            local minutes = Round(v)
            if minutes == 0 then return "Server time" end
            local sign = minutes >= 0 and "+" or "-"
            local absMinutes = math.abs(minutes)
            local hh = math.floor(absMinutes / 60)
            local mm = absMinutes % 60
            return "Server " .. sign .. tostring(hh) .. (mm > 0 and (":" .. string.format("%02d", mm)) or "h")
        end,
        function(v) ApplyMinimapSetting("clockOffsetMinutes", Round(v)) end)
    frame.scaleMinimap = CreateSlider(minimap.main, "MINIMAP SCALE", 286, -186, 250, 50, 150, 5,
        function(v) return tostring(Round(v)) .. "%" end,
        function(v) ApplyComponentScale("minimap", Round(v) / 100) end)

    minimap.icons = CreateSection(minimap, "NATIVE & ADDON BUTTONS", 16, -320, 552, 220)
    frame.mmTracking = CreateCheck(minimap.icons, "Show tracking button", 14, -42, function(v) ApplyMinimapSetting("showTracking", v) end, 250)
    frame.mmMail = CreateCheck(minimap.icons, "Show mail indicator", 286, -42, function(v) ApplyMinimapSetting("showMail", v) end, 250)
    frame.mmLFG = CreateCheck(minimap.icons, "Show dungeon-finder indicator", 14, -74, function(v) ApplyMinimapSetting("showLFG", v) end, 250)
    frame.mmDifficulty = CreateCheck(minimap.icons, "Show instance difficulty", 286, -74, function(v) ApplyMinimapSetting("showDifficulty", v) end, 250)
    frame.mmBattlefield = CreateCheck(minimap.icons, "Show battlefield indicator", 14, -106, function(v) ApplyMinimapSetting("showBattlefield", v) end, 250)
    frame.mmCollector = CreateCheck(minimap.icons, "Collect addon minimap buttons", 286, -106, function(v) ApplyMinimapSetting("collectAddonButtons", v) end, 250)
    frame.mmRaidIdentifier = CreateCheck(minimap.icons, "Show raid size / difficulty", 14, -138, function(v) ApplyMinimapSetting("showRaidIdentifier", v) end, 250)
    frame.mmCollectorColumns = CreateSlider(minimap.icons, "DOCK COLUMNS", 286, -140, 250, 1, 8, 1, function(v) return tostring(Round(v)) end, function(v) ApplyMinimapSetting("collectorColumns", Round(v)) end)
    frame.mmCollectorScan = CreateButton(minimap.icons, "Rescan Addon Buttons", 180, 24)
    frame.mmCollectorScan:SetPoint("BOTTOMRIGHT", minimap.icons, "BOTTOMRIGHT", -14, 14)
    frame.mmCollectorScan:SetScript("OnClick", function()
        local m = RUI:GetModule("Minimap")
        if m and m.ScanAddonButtons then m:ScanAddonButtons(true) end
    end)

    -- TOOLTIP
    local tooltip = CreatePage(frame, "TOOLTIP", "Tooltip", "Zen styling for the original Wrath tooltip system.")
    tooltip.main = CreateSection(tooltip, "GAME TOOLTIP", 16, -74, 552, 236)
    frame.ttEnable = CreateCheck(tooltip.main, "Enable ZenUI tooltip skin", 14, -42, function(v) ApplyTooltipSetting("enabled", v) end, 250)
    frame.ttUnitBorder = CreateCheck(tooltip.main, "Class / reaction border for units", 286, -42, function(v) ApplyTooltipSetting("unitBorder", v) end, 250)
    frame.ttHealth = CreateCheck(tooltip.main, "Show tooltip health bar", 14, -76, function(v) ApplyTooltipSetting("showHealthBar", v) end, 250)
    frame.ttScale = CreateSlider(tooltip.main, "TOOLTIP SCALE", 286, -76, 250, 80, 125, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyTooltipSetting("scale", Round(v) / 100) end)
    local ttNote = CreateText(tooltip.main, "Unit tooltips use class colour for players and reaction colour for NPCs. Non-unit tooltips use the current Zen accent border.", 9, "TOPLEFT", tooltip.main, "TOPLEFT", 14, -132, true)
    ttNote:SetWidth(520); ttNote:SetJustifyH("LEFT")

    -- CHAT
    local chat = CreatePage(frame, "CHAT", "Chat", "Zen styling and positioning for the original Wrath chat dock.")
    AddPageMover(frame, chat, "chat", "Chat", "CHAT")
    chat.main = CreateSection(chat, "CHAT PANEL", 16, -74, 552, 420)
    frame.chatEnable = CreateCheck(chat.main, "Enable ZenUI chat panel", 14, -42, function(v) ApplyChatSetting("enabled", v) end, 250)
    frame.chatLocked = CreateCheck(chat.main, "Lock chat windows", 286, -42, function(v) ApplyChatSetting("locked", v) end, 250)
    frame.chatHideButtons = CreateCheck(chat.main, "Hide native chat buttons", 14, -76, function(v) ApplyChatSetting("hideButtons", v) end, 250)
    frame.chatFade = CreateCheck(chat.main, "Fade inactive chat text", 286, -76, function(v) ApplyChatSetting("fade", v) end, 250)
    frame.chatFontSize = CreateSlider(chat.main, "FONT SIZE", 14, -118, 250, 8, 20, 1, function(v) return tostring(Round(v)) .. "px" end, function(v) ApplyChatSetting("fontSize", Round(v)) end)
    frame.chatBackground = CreateSlider(chat.main, "BACKGROUND OPACITY", 286, -118, 250, 0, 100, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyChatSetting("backgroundAlpha", Round(v) / 100) end)
    frame.chatWidth = CreateSlider(chat.main, "PANEL WIDTH", 14, -178, 250, 320, 624, 4, function(v) return tostring(Round(v)) .. "px" end, function(v) ApplyChatSetting("width", Round(v)) end)
    frame.chatHeight = CreateSlider(chat.main, "PANEL HEIGHT", 286, -178, 250, 160, 434, 2, function(v) return tostring(Round(v)) .. "px" end, function(v) ApplyChatSetting("height", Round(v)) end)
    frame.scaleChat = CreateSlider(chat.main, "CHAT SCALE", 14, -238, 250, 50, 150, 5,
        function(v) return tostring(Round(v)) .. "%" end,
        function(v) ApplyComponentScale("chat", Round(v) / 100) end)
    frame.chatEditAlpha = CreateSlider(chat.main, "INPUT OPACITY", 286, -238, 250, 10, 100, 5,
        function(v) return tostring(Round(v)) .. "%" end,
        function(v) ApplyChatSetting("editBoxAlpha", Round(v) / 100) end)
    frame.chatEditHeight = CreateSlider(chat.main, "INPUT HEIGHT", 14, -298, 250, 20, 48, 1,
        function(v) return tostring(Round(v)) .. "px" end,
        function(v) ApplyChatSetting("editBoxHeight", Round(v)) end)
    frame.chatEditFont = CreateSlider(chat.main, "INPUT FONT SIZE", 286, -298, 250, 8, 20, 1,
        function(v) return tostring(Round(v)) .. "px" end,
        function(v) ApplyChatSetting("editBoxFontSize", Round(v)) end)
    local chatNote = CreateText(chat.main, "Panel controls affect the chat dock; Input controls affect the box you type into. Message routing, hyperlinks and history remain Blizzard-managed.", 9, "TOPLEFT", chat.main, "TOPLEFT", 14, -350, true)
    chatNote:SetWidth(520); chatNote:SetJustifyH("LEFT")

    -- BAGS
    local bags = CreatePage(frame, "BAGS", "Bags", "One unified bag window built from native Wrath container item buttons, with per-container inclusion.")
    AddPageMover(frame, bags, "bags", "Bags", "BAGS")
    bags.main = CreateSection(bags, "UNIFIED BAGS", 16, -74, 552, 462)
    frame.bagEnable = CreateCheck(bags.main, "Enable ZenUI unified bags", 14, -42, function(v) ApplyBagSetting("enabled", v) end, 250)
    frame.bagSearch = CreateCheck(bags.main, "Show search box", 286, -42, function(v) ApplyBagSetting("showSearch", v) end, 250)
    frame.bagQuality = CreateCheck(bags.main, "Item quality borders", 14, -76, function(v) ApplyBagSetting("showQuality", v) end, 250)
    frame.bagColumns = CreateSlider(bags.main, "COLUMNS", 286, -76, 250, 6, 18, 1, function(v) return tostring(Round(v)) end, function(v) ApplyBagSetting("columns", Round(v)) end)
    frame.bagButtonSize = CreateSlider(bags.main, "BUTTON SIZE", 14, -136, 250, 24, 48, 1, function(v) return tostring(Round(v)) .. "px" end, function(v) ApplyBagSetting("buttonSize", Round(v)) end)
    frame.bagSpacing = CreateSlider(bags.main, "BUTTON SPACING", 286, -136, 250, 0, 12, 1, function(v) return tostring(Round(v)) .. "px" end, function(v) ApplyBagSetting("spacing", Round(v)) end)

    frame.bagContainerLabel = CreateText(bags.main, "INCLUDE CONTAINERS", 9, "TOPLEFT", bags.main, "TOPLEFT", 14, -198, true)
    frame.bagBackpack = CreateCheck(bags.main, "Backpack", 14, -222, function(v) ApplyBagContainerSetting("backpack", v) end, 250)
    frame.bagBag1 = CreateCheck(bags.main, "Bag 1", 286, -222, function(v) ApplyBagContainerSetting("bag1", v) end, 250)
    frame.bagBag2 = CreateCheck(bags.main, "Bag 2", 14, -250, function(v) ApplyBagContainerSetting("bag2", v) end, 250)
    frame.bagBag3 = CreateCheck(bags.main, "Bag 3", 286, -250, function(v) ApplyBagContainerSetting("bag3", v) end, 250)
    frame.bagBag4 = CreateCheck(bags.main, "Bag 4", 14, -278, function(v) ApplyBagContainerSetting("bag4", v) end, 250)
    frame.bagKeyring = CreateCheck(bags.main, "Keyring", 286, -278, function(v) ApplyBagContainerSetting("keyring", v) end, 250)
    frame.bagBank = CreateCheck(bags.main, "Bank container (at bank)", 14, -306, function(v) ApplyBagContainerSetting("bank", v) end, 250)
    frame.bagBankBags = CreateCheck(bags.main, "Bank bags (at bank)", 286, -306, function(v) ApplyBagContainerSetting("bankBags", v) end, 250)
    frame.scaleBags = CreateSlider(bags.main, "BAG WINDOW SCALE", 286, -346, 250, 50, 150, 5,
        function(v) return tostring(Round(v)) .. "%" end,
        function(v) ApplyComponentScale("bags", Round(v) / 100) end)

    frame.bagOpen = CreateButton(bags.main, "Open Bags", 132, 24)
    frame.bagOpen:SetPoint("TOPLEFT", bags.main, "TOPLEFT", 14, -352)
    frame.bagOpen:SetScript("OnClick", function() local b=RUI:GetModule("Bags"); if b and b.Toggle then b:Toggle() end end)
    local bagNote = CreateText(bags.main, "Disabled regular/keyring containers fall back to Blizzard when opened directly. Bank selections are added only while the bank is open. Native item clicks, stack split and modified-click dialogs remain Blizzard-managed.", 8, "TOPLEFT", bags.main, "TOPLEFT", 14, -394, true)
    bagNote:SetWidth(520); bagNote:SetJustifyH("LEFT")

    -- LOOT & ROLLS
    local loot = CreatePage(frame, "LOOT", "Loot & Rolls", "Zen loot presentation plus opt-in D2 automatic Pass, Greed and Disenchant rules.")
    AddPageMover(frame, loot, "loot", "Loot Rolls", "LOOT")
    loot.main = CreateSection(loot, "GROUP LOOT", 16, -74, 552, 190)
    frame.lootEnable = CreateCheck(loot.main, "Enable Zen loot + roll frames", 14, -42, function(v) ApplyLootSetting("enabled", v) end, 250)
    frame.lootHideRollChat = CreateCheck(loot.main, "Hide group loot-roll chat", 14, -72, function(v) ApplyLootSetting("hideRollChat", v) end, 250)
    frame.scaleZenLootRolls = CreateSlider(loot.main, "LOOT ROLL SCALE", 286, -42, 250, 50, 150, 5,
        function(v) return tostring(Round(v)) .. "%" end,
        function(v) ApplyComponentScale("zenLootRolls", Round(v) / 100) end)
    local lootManual = CreateText(loot.main, "Native Ebonhold/Wrath loot sessions, RollOnLoot decisions and BoP confirmations remain authoritative. Multiple active rolls stack from the Loot Rolls mover anchor.", 9, "TOPLEFT", loot.main, "TOPLEFT", 14, -104, true)
    lootManual:SetWidth(520); lootManual:SetJustifyH("LEFT")
    local lootLink = CreateText(loot.main, "Hide group loot-roll chat removes roll selections/results only; actual loot received messages remain visible. Hover or modified-click items for normal tooltip/link behavior.", 9, "TOPLEFT", loot.main, "TOPLEFT", 14, -150, true)
    lootLink:SetWidth(520); lootLink:SetJustifyH("LEFT")

    loot.auto = CreateSection(loot, "AUTO LOOT ROLLER", 16, -278, 552, 310)
    frame.lootAutoEnable = CreateCheck(loot.auto, "Enable automatic loot rolls", 14, -42, function(v) ApplyLootSetting("autoRollEnabled", v) end, 250)
    frame.lootAutoNotify = CreateCheck(loot.auto, "Show auto-roll messages", 286, -42, function(v) ApplyLootSetting("autoRollNotify", v) end, 250)
    frame.lootAutoBoPNoNeed = CreateCheck(loot.auto, "Auto Pass BoP when Need is unavailable", 14, -72, function(v) ApplyLootSetting("autoPassBoPNoNeed", v) end, 380)

    local autoHelp = CreateText(loot.auto, "Rules run once when a roll starts. Auto Need is intentionally unavailable. If Greed/Disenchant is not allowed for an item, Zen leaves that roll Manual rather than choosing a fallback.", 9, "TOPLEFT", loot.auto, "TOPLEFT", 14, -108, true)
    autoHelp:SetWidth(520); autoHelp:SetJustifyH("LEFT")

    frame.lootAutoRuleButtons = {}
    local qualityLayout = {
        {0, 14, -168}, {1, 286, -168},
        {2, 14, -208}, {3, 286, -208},
        {4, 14, -248},
    }
    for i = 1, #qualityLayout do
        local quality, x, y = qualityLayout[i][1], qualityLayout[i][2], qualityLayout[i][3]
        local label = CreateText(loot.auto, string.upper(LOOT_QUALITY_LABELS[quality] or "Quality"), 9, "TOPLEFT", loot.auto, "TOPLEFT", x, y, true)
        label:SetWidth(82)
        local button = CreateButton(loot.auto, "Manual", 156, 24)
        button:SetPoint("TOPLEFT", loot.auto, "TOPLEFT", x + 92, y + 8)
        button.quality = quality
        button:SetScript("OnClick", function(self)
            local rules = RUI.db and RUI.db.loot and RUI.db.loot.autoRollRules or {}
            local nextAction = NextLootAutoAction(rules[self.quality])
            ApplyLootAutoRule(self.quality, nextAction)
            self.RUIText:SetText(LootAutoActionLabel(nextAction))
        end)
        frame.lootAutoRuleButtons[quality] = button
    end

    frame.lootAutoReset = CreateButton(loot.auto, "Reset Rules to Manual", 176, 24)
    frame.lootAutoReset:SetPoint("BOTTOMRIGHT", loot.auto, "BOTTOMRIGHT", -14, 14)
    frame.lootAutoReset:SetScript("OnClick", function()
        if not RUI.db then return end
        RUI.db.loot = RUI.db.loot or {}
        RUI.db.loot.autoRollRules = RUI.db.loot.autoRollRules or {}
        for quality = 0, 4 do RUI.db.loot.autoRollRules[quality] = "MANUAL" end
        Config:Refresh()
    end)

    -- BANK & VOID STORAGE
    local bank = CreatePage(frame, "BANK", "Bank & Void", "Unified Bank and Ebonhold Extended Bank controls, filters and quick-move behavior.")
    AddPageMover(frame, bank, "bank", "Bank & Void", "BANK")
    bank.main = CreateSection(bank, "BANK WINDOW", 16, -74, 552, 232)
    frame.bankEnable = CreateCheck(bank.main, "Enable Zen Bank replacement", 14, -42, function(v) ApplyBlizzardSetting("bank", v) end, 250)
    frame.bankScale = CreateSlider(bank.main, "BANK SCALE", 286, -42, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenBank", Round(v)/100) end)
    frame.bankDefaultMain = CreateCheck(bank.main, "Show main Bank (BNK)", 14, -86, function(v) ApplyBankContainerSetting("bank", v) end, 250)
    frame.bankDefault1 = CreateCheck(bank.main, "Show Bank bag 1", 286, -86, function(v) ApplyBankContainerSetting("bag1", v) end, 250)
    frame.bankDefault2 = CreateCheck(bank.main, "Show Bank bag 2", 14, -116, function(v) ApplyBankContainerSetting("bag2", v) end, 250)
    frame.bankDefault3 = CreateCheck(bank.main, "Show Bank bag 3", 286, -116, function(v) ApplyBankContainerSetting("bag3", v) end, 250)
    frame.bankDefault4 = CreateCheck(bank.main, "Show Bank bag 4", 14, -146, function(v) ApplyBankContainerSetting("bag4", v) end, 250)
    frame.bankDefault5 = CreateCheck(bank.main, "Show Bank bag 5", 286, -146, function(v) ApplyBankContainerSetting("bag5", v) end, 250)
    frame.bankDefault6 = CreateCheck(bank.main, "Show Bank bag 6", 14, -176, function(v) ApplyBankContainerSetting("bag6", v) end, 250)
    frame.bankDefault7 = CreateCheck(bank.main, "Show Bank bag 7", 286, -176, function(v) ApplyBankContainerSetting("bag7", v) end, 250)
    frame.bankQuickModifierLabel = CreateText(bank.main, "QUICK DROP MODIFIER", 9, "TOPLEFT", bank.main, "TOPLEFT", 14, -211, true)
    frame.bankQuickModifier = CreateButton(bank.main, "Shift + Right-click", 170, 24)
    frame.bankQuickModifier:SetPoint("TOPRIGHT", bank.main, "TOPRIGHT", -14, -200)
    frame.bankQuickModifier:SetScript("OnClick", function()
        local blizzard = RUI.db.blizzard or {}
        local current = string.upper(tostring(blizzard.bankQuickDropModifier or "SHIFT"))
        local nextValue = BANK_QUICK_MODIFIER_ORDER[1]
        for i=1,#BANK_QUICK_MODIFIER_ORDER do
            if BANK_QUICK_MODIFIER_ORDER[i] == current then
                nextValue = BANK_QUICK_MODIFIER_ORDER[(i % #BANK_QUICK_MODIFIER_ORDER) + 1]
                break
            end
        end
        ApplyBankQuickDropModifier(nextValue)
        Config:Refresh()
    end)

    bank.void = CreateSection(bank, "EXTENDED / VOID STORAGE", 16, -318, 552, 218)
    frame.bankVoidRule = CreateText(bank.void, "V starts hidden each banker visit. Right-click uses the normal Bag <-> Bank / Void -> Bag route; your chosen modifier + Right-click routes Bag/Bank -> Void and Void -> Bank. ALL toggles BNK + bags 1-7 + V.", 9, "TOPLEFT", bank.void, "TOPLEFT", 14, -40, true)
    frame.bankVoidRule:SetWidth(520); frame.bankVoidRule:SetJustifyH("LEFT")
    frame.bankExtSlots = CreateText(bank.void, "Storage: open the bank to load status", 10, "TOPLEFT", bank.void, "TOPLEFT", 14, -104, false)
    frame.bankExtPrice = CreateText(bank.void, "Next unlock: --", 10, "TOPLEFT", bank.void, "TOPLEFT", 14, -136, false)
    frame.bankResetFilters = CreateButton(bank.void, "Reset Bank Filters", 150, 24)
    frame.bankResetFilters:SetPoint("BOTTOMLEFT", bank.void, "BOTTOMLEFT", 14, 14)
    frame.bankResetFilters:SetScript("OnClick", function() ResetBankContainerSettings(); Config:Refresh() end)

    -- ZEN REPLACEMENT PANELS
    local panelsA = CreatePage(frame, "PANELS_A", "Core Panels", "Spellbook, Social / Guild / Raid and Dungeon Finder replacements.")
    AddPageMover(frame, panelsA, "panelsA", "Core Panels", "PANELS_A")
    panelsA.main = CreateSection(panelsA, "CORE REPLACEMENTS", 16, -74, 552, 396)
    frame.blizzEnable = CreateCheck(panelsA.main, "Enable Zen replacement panels", 14, -42, function(v) ApplyBlizzardSetting("enabled", v) end, 520)
    frame.blizzSpellbook = CreateCheck(panelsA.main, "Spellbook", 14, -82, function(v) ApplyBlizzardSetting("spellbook", v) end, 250)
    frame.scaleZenSpellbook = CreateSlider(panelsA.main, "SPELLBOOK SCALE", 14, -112, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenSpellbook", Round(v) / 100) end)
    frame.blizzSocial = CreateCheck(panelsA.main, "Social / Friends / Raid", 286, -82, function(v) ApplyBlizzardSetting("social", v) end, 250)
    frame.scaleZenSocial = CreateSlider(panelsA.main, "SOCIAL SCALE", 286, -112, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenSocial", Round(v) / 100) end)
    frame.blizzGuild = CreateCheck(panelsA.main, "Guild", 14, -176, function(v) ApplyBlizzardSetting("guild", v) end, 250)
    frame.scaleZenGuild = CreateSlider(panelsA.main, "GUILD SCALE", 14, -206, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenGuild", Round(v) / 100) end)
    frame.blizzDungeon = CreateCheck(panelsA.main, "Dungeon Finder", 286, -176, function(v) ApplyBlizzardSetting("dungeonFinder", v) end, 250)
    frame.scaleZenDungeon = CreateSlider(panelsA.main, "DUNGEON FINDER SCALE", 286, -206, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenDungeonFinder", Round(v) / 100) end)
    frame.guildOffline = CreateCheck(panelsA.main, "Guild: show offline members", 14, -258, function(v) ApplyBlizzardSetting("guildShowOffline", v) end, 250)
    local phaseANote = CreateText(panelsA.main, "Core panels are mutually exclusive: opening another full-size Zen panel closes the one already open.", 9, "TOPLEFT", panelsA.main, "TOPLEFT", 14, -306, true)
    phaseANote:SetWidth(520); phaseANote:SetJustifyH("LEFT")

    local panelsB = CreatePage(frame, "PANELS_B", "Service Panels", "Character, Quest Log, Mail, Merchant, Bank and Trade replacements.")
    AddPageMover(frame, panelsB, "panelsB", "Service Panels", "PANELS_B")
    panelsB.main = CreateSection(panelsB, "SERVICE REPLACEMENTS", 16, -74, 552, 430)
    frame.blizzCharacter = CreateCheck(panelsB.main, "Character", 14, -42, function(v) ApplyBlizzardSetting("character", v) end, 250)
    frame.scaleZenCharacter = CreateSlider(panelsB.main, "CHARACTER SCALE", 14, -72, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenCharacter", Round(v)/100) end)
    frame.blizzQuestLog = CreateCheck(panelsB.main, "Quest Log", 286, -42, function(v) ApplyBlizzardSetting("questLog", v) end, 250)
    frame.scaleZenQuestLog = CreateSlider(panelsB.main, "QUEST LOG SCALE", 286, -72, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenQuestLog", Round(v)/100) end)
    frame.blizzMail = CreateCheck(panelsB.main, "Mail", 14, -142, function(v) ApplyBlizzardSetting("mail", v) end, 250)
    frame.scaleZenMail = CreateSlider(panelsB.main, "MAIL SCALE", 14, -172, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenMail", Round(v)/100) end)
    frame.blizzMerchant = CreateCheck(panelsB.main, "Merchant", 286, -142, function(v) ApplyBlizzardSetting("merchant", v) end, 250)
    frame.scaleZenMerchant = CreateSlider(panelsB.main, "MERCHANT SCALE", 286, -172, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenMerchant", Round(v)/100) end)
    frame.blizzBank = CreateCheck(panelsB.main, "Bank", 14, -242, function(v) ApplyBlizzardSetting("bank", v) end, 250)
    frame.scaleZenBank = CreateSlider(panelsB.main, "BANK SCALE", 14, -272, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenBank", Round(v)/100) end)
    frame.blizzTrade = CreateCheck(panelsB.main, "Trade", 286, -242, function(v) ApplyBlizzardSetting("trade", v) end, 250)
    frame.scaleZenTrade = CreateSlider(panelsB.main, "TRADE SCALE", 286, -272, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenTrade", Round(v)/100) end)
    local phaseBNote = CreateText(panelsB.main, "Service panels keep native server interactions authoritative while Zen owns the visible window.", 9, "TOPLEFT", panelsB.main, "TOPLEFT", 14, -350, true)
    phaseBNote:SetWidth(520); phaseBNote:SetJustifyH("LEFT")

    local mailPage = CreatePage(frame, "MAIL", "Mail", "Batch collection safety and Zen Mail quality-of-life behavior.")
    mailPage.main = CreateSection(mailPage, "MAIL QUALITY OF LIFE", 16, -74, 552, 260)
    frame.mailKeepFree = CreateSlider(mailPage.main, "KEEP REGULAR BAG SLOTS FREE", 14, -48, 250, 0, 10, 1,
        function(v) return tostring(Round(v)) end,
        function(v) ApplyMailSetting("keepFreeSlots", Round(v)) end)
    frame.mailSessionTotal = CreateCheck(mailPage.main, "Report gold collected when mailbox closes", 286, -48, function(v)
        ApplyMailSetting("showSessionTotal", v)
    end, 250)
    local mailInfo = CreateText(mailPage.main,
        "Open All and Open Selected are paced one action at a time and always skip C.O.D. / GM mail. Shift-click an inbox row to collect it quickly; Ctrl-click returns it when allowed. Selection mode supports Shift ranges and Ctrl same-sender selection.",
        9, "TOPLEFT", mailPage.main, "TOPLEFT", 14, -104, true)
    mailInfo:SetWidth(520); mailInfo:SetJustifyH("LEFT")
    local contactsInfo = CreateText(mailPage.main,
        "The Send Mail Contacts menu includes saved contacts, recent recipients, same-realm alts, friends and guild members. Type a name first, then use Contacts to add or remove it from your saved list.",
        9, "TOPLEFT", mailPage.main, "TOPLEFT", 14, -174, true)
    contactsInfo:SetWidth(520); contactsInfo:SetJustifyH("LEFT")

    local panelsC = CreatePage(frame, "PANELS_C", "Progression", "Talents, PvP, Experience / Reputation and Achievements / Statistics.")
    AddPageMover(frame, panelsC, "panelsC", "Progression", "PANELS_C")
    panelsC.main = CreateSection(panelsC, "PROGRESSION & PVP", 16, -74, 552, 430)
    frame.blizzTalents = CreateCheck(panelsC.main, "Talents & Glyphs", 14, -42, function(v) ApplyBlizzardSetting("talents", v) end, 250)
    frame.scaleZenTalents = CreateSlider(panelsC.main, "TALENTS SCALE", 286, -42, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenTalents", Round(v)/100) end)
    frame.blizzPVP = CreateCheck(panelsC.main, "PvP", 14, -112, function(v) ApplyBlizzardSetting("pvp", v) end, 250)
    frame.scaleZenPVP = CreateSlider(panelsC.main, "PVP SCALE", 286, -112, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenPVP", Round(v)/100) end)
    frame.blizzXPBar = CreateCheck(panelsC.main, "Experience bar", 14, -182, function(v) ApplyBlizzardSetting("xpBar", v) end, 250)
    frame.blizzRepBar = CreateCheck(panelsC.main, "Reputation bar", 286, -182, function(v) ApplyBlizzardSetting("reputationBar", v) end, 250)
    frame.scaleZenStatusBars = CreateSlider(panelsC.main, "XP / REPUTATION SCALE", 14, -218, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenStatusBars", Round(v)/100) end)
    frame.blizzAchievements = CreateCheck(panelsC.main, "Achievements / Statistics", 14, -286, function(v) ApplyBlizzardSetting("achievements", v) end, 250)
    frame.scaleZenAchievements = CreateSlider(panelsC.main, "ACHIEVEMENTS SCALE", 286, -286, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenAchievements", Round(v)/100) end)
    local phaseCNote = CreateText(panelsC.main, "Raid Finder remains omitted because Zen's existing Raid window already covers Wrath raid management.", 9, "TOPLEFT", panelsC.main, "TOPLEFT", 14, -354, true)
    phaseCNote:SetWidth(520); phaseCNote:SetJustifyH("LEFT")

    local panelsD = CreatePage(frame, "PANELS_D", "Interactions", "Inspect, Trainer and Conversation panels used by normal Wrath and Project Ebonhold interactions.")
    AddPageMover(frame, panelsD, "panelsD", "Interactions", "PANELS_D")
    panelsD.main = CreateSection(panelsD, "INTERACTION PANELS", 16, -74, 552, 330)
    frame.blizzInspect = CreateCheck(panelsD.main, "Inspect", 14, -42, function(v) ApplyBlizzardSetting("inspect", v) end, 250)
    frame.scaleZenInspect = CreateSlider(panelsD.main, "INSPECT SCALE", 14, -72, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenInspect", Round(v)/100) end)
    frame.blizzTrainer = CreateCheck(panelsD.main, "Trainer", 286, -42, function(v) ApplyBlizzardSetting("trainer", v) end, 250)
    frame.scaleZenTrainer = CreateSlider(panelsD.main, "TRAINER SCALE", 286, -72, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenTrainer", Round(v)/100) end)
    frame.blizzNPCDialog = CreateCheck(panelsD.main, "Conversation / Gossip", 14, -142, function(v) ApplyBlizzardSetting("npcDialog", v) end, 250)
    frame.scaleZenNPCInteraction = CreateSlider(panelsD.main, "CONVERSATION SCALE", 14, -172, 250, 50, 150, 5, function(v) return tostring(Round(v)) .. "%" end, function(v) ApplyComponentScale("zenNPCInteraction", Round(v)/100) end)
    local phaseDNote = CreateText(panelsD.main, "Ebonhold custom-object handoffs (such as the Affix Forge) are resolved before Zen opens Conversation, so custom interfaces can take ownership cleanly.", 9, "TOPLEFT", panelsD.main, "TOPLEFT", 14, -234, true)
    phaseDNote:SetWidth(520); phaseDNote:SetJustifyH("LEFT")

    -- LAYOUT
    local layout = CreatePage(frame, "LAYOUT", "Layout", "Mover anchors and grid snapping for ZenUI modules, including Phase A, Phase B and Phase C replacement panels.")
    layout.main = CreateSection(layout, "MOVERS", 16, -74, 552, 250)
    frame.snapCheck = CreateCheck(layout.main, "Enable grid snapping", 14, -42, function(v) RUI:SetSnapEnabled(v) end)
    frame.snapSize = CreateSlider(layout.main, "SNAP SIZE", 14, -78, 250, 1, 32, 1, function(v) return tostring(Round(v)) .. "px" end, function(v) RUI:SetSnapSize(Round(v)) end)
    frame.moveButton = CreateButton(layout.main, "Move All Panels", 148, 24)
    frame.moveButton:SetPoint("BOTTOMLEFT", layout.main, "BOTTOMLEFT", 14, 16)
    frame.moveButton:SetScript("OnClick", function() frame:Hide(); RUI:SetMoverMode(true, nil, "LAYOUT", nil) end)
    frame.resetMovers = CreateButton(layout.main, "Reset Movers", 132, 24)
    frame.resetMovers:SetPoint("BOTTOMLEFT", layout.main, "BOTTOMLEFT", 174, 16)
    frame.resetMovers:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then RUI:Print("Mover positions cannot be reset during combat."); return end
        RUI:ResetAllMovers(); RUI:Print("Mover positions reset to defaults.")
    end)

    -- PROFILES
    local profiles = CreatePage(frame, "PROFILES", "Profiles", "Save complete Zen layouts locally, switch between them, or share them using a portable import/export string.")
    profiles.saved = CreateSection(profiles, "SAVED PROFILES", 16, -74, 552, 360)
    frame.profileCurrentLabel = CreateText(profiles.saved, "ACTIVE PROFILE", 9, "TOPLEFT", profiles.saved, "TOPLEFT", 14, -40, true)
    frame.profileCurrentValue = CreateText(profiles.saved, "Default", 12, "TOPLEFT", profiles.saved, "TOPLEFT", 14, -60, false)
    frame.profileCurrentValue:SetWidth(510); frame.profileCurrentValue:SetJustifyH("LEFT")

    frame.profileNameInput = CreateEditBox(profiles.saved, "New profile name", 330, 24)
    frame.profileNameInput:SetPoint("TOPLEFT", profiles.saved, "TOPLEFT", 14, -92)
    frame.profileSaveAs = CreateButton(profiles.saved, "Save Current As", 160, 24)
    frame.profileSaveAs:SetPoint("LEFT", frame.profileNameInput, "RIGHT", 10, 0)
    frame.profileSaveAs:SetScript("OnClick", function()
        local ok, err = RUI:SaveProfileAs(frame.profileNameInput:GetText())
        if ok then
            frame.profileNameInput:SetText(""); frame.profileNameInput:ClearFocus()
            frame.profileStatus:SetText("Saved and switched to the new profile.")
        else
            frame.profileStatus:SetText(tostring(err or "Could not save profile."))
        end
        Config:Refresh()
    end)

    frame.profileListLabel = CreateText(profiles.saved, "AVAILABLE PROFILES", 9, "TOPLEFT", profiles.saved, "TOPLEFT", 14, -132, true)
    frame.profileRows = {}
    for i = 1, 6 do
        local row = {}
        row.use = CreateButton(profiles.saved, "Profile", 386, 26)
        row.use:SetPoint("TOPLEFT", profiles.saved, "TOPLEFT", 14, -150 - ((i - 1) * 30))
        row.use.RUIText:SetJustifyH("LEFT")
        row.use.RUIText:ClearAllPoints(); row.use.RUIText:SetPoint("LEFT", row.use, "LEFT", 10, 0)
        row.use:SetScript("OnClick", function(self)
            if not self.profileName or self.profileName == RUI.profileName then return end
            local ok, err = RUI:ApplyProfile(self.profileName, "profile-switch")
            frame.profileStatus:SetText(ok and ("Switched to " .. tostring(self.profileName) .. ".") or tostring(err or "Could not switch profile."))
            Config:Refresh()
        end)
        row.delete = CreateButton(profiles.saved, "Delete", 94, 26)
        row.delete:SetPoint("LEFT", row.use, "RIGHT", 10, 0)
        row.delete:SetScript("OnClick", function(self)
            if not self.profileName then return end
            local target = self.profileName
            if StaticPopupDialogs and StaticPopup_Show then
                StaticPopupDialogs.ZENUI_DELETE_PROFILE = StaticPopupDialogs.ZENUI_DELETE_PROFILE or {
                    text = "Delete ZenUI profile '%s'?",
                    button1 = YES, button2 = NO, timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
                    OnAccept = function(_, data)
                        local ok, err = RUI:DeleteProfile(data)
                        frame.profileStatus:SetText(ok and ("Deleted " .. tostring(data) .. ".") or tostring(err or "Could not delete profile."))
                        Config:Refresh()
                    end,
                }
                StaticPopup_Show("ZENUI_DELETE_PROFILE", target, nil, target)
            else
                local ok, err = RUI:DeleteProfile(target)
                frame.profileStatus:SetText(ok and ("Deleted " .. tostring(target) .. ".") or tostring(err or "Could not delete profile."))
                Config:Refresh()
            end
        end)
        frame.profileRows[i] = row
    end
    frame.profilePrev = CreateButton(profiles.saved, "< Previous", 108, 22)
    frame.profilePrev:SetPoint("BOTTOMLEFT", profiles.saved, "BOTTOMLEFT", 14, 14)
    frame.profilePageLabel = CreateText(profiles.saved, "Page 1 / 1", 9, "LEFT", frame.profilePrev, "RIGHT", 14, 0, true)
    frame.profileNext = CreateButton(profiles.saved, "Next >", 108, 22)
    frame.profileNext:SetPoint("BOTTOMRIGHT", profiles.saved, "BOTTOMRIGHT", -14, 14)
    frame.profileListPage = 1
    frame.profilePrev:SetScript("OnClick", function() frame.profileListPage = math.max(1, (frame.profileListPage or 1) - 1); Config:RefreshProfiles() end)
    frame.profileNext:SetScript("OnClick", function() frame.profileListPage = (frame.profileListPage or 1) + 1; Config:RefreshProfiles() end)

    profiles.transfer = CreateSection(profiles, "IMPORT / EXPORT", 16, -452, 552, 260)
    local transferNote = CreateText(profiles.transfer, "Export creates a shareable ZenUI string containing layout, movers, appearance and module settings. Character history and character-specific spec labels are excluded.", 9, "TOPLEFT", profiles.transfer, "TOPLEFT", 14, -38, true)
    transferNote:SetWidth(520); transferNote:SetJustifyH("LEFT")
    frame.profileImportName = CreateEditBox(profiles.transfer, "Imported profile name (optional)", 520, 24)
    frame.profileImportName:SetPoint("TOPLEFT", profiles.transfer, "TOPLEFT", 14, -82)
    frame.profileString = CreateEditBox(profiles.transfer, "Paste a ZUI1: profile string here", 520, 28)
    frame.profileString:SetPoint("TOPLEFT", profiles.transfer, "TOPLEFT", 14, -116)
    frame.profileString:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.profileExport = CreateButton(profiles.transfer, "Export Current", 132, 24)
    frame.profileExport:SetPoint("TOPLEFT", profiles.transfer, "TOPLEFT", 14, -160)
    frame.profileExport:SetScript("OnClick", function()
        local text, err = RUI:ExportProfile()
        if not text then frame.profileStatus:SetText(tostring(err or "Export failed.")); return end
        frame.profileString:SetText(text)
        frame.profileString:SetFocus(); frame.profileString:HighlightText(0, string.len(text))
        frame.profileStatus:SetText("Export ready. Press Ctrl+C to copy the highlighted string.")
    end)
    frame.profileImport = CreateButton(profiles.transfer, "Import & Apply", 132, 24)
    frame.profileImport:SetPoint("LEFT", frame.profileExport, "RIGHT", 10, 0)
    frame.profileImport:SetScript("OnClick", function()
        local requested = frame.profileImportName:GetText()
        if requested == "" then requested = nil end
        local ok, result = RUI:ImportProfile(frame.profileString:GetText(), requested)
        if ok then
            frame.profileImportName:SetText(""); frame.profileString:SetText("")
            frame.profileStatus:SetText("Imported and applied profile: " .. tostring(result) .. ".")
        else
            frame.profileStatus:SetText(tostring(result or "Import failed."))
        end
        Config:Refresh()
    end)
    frame.profileClear = CreateButton(profiles.transfer, "Clear", 90, 24)
    frame.profileClear:SetPoint("LEFT", frame.profileImport, "RIGHT", 10, 0)
    frame.profileClear:SetScript("OnClick", function() frame.profileString:SetText(""); frame.profileImportName:SetText(""); frame.profileStatus:SetText("") end)
    frame.profileStatus = CreateText(profiles.transfer, "", 9, "TOPLEFT", profiles.transfer, "TOPLEFT", 14, -204, true)
    frame.profileStatus:SetWidth(520); frame.profileStatus:SetJustifyH("LEFT")

    -- SYSTEM
    local system = CreatePage(frame, "SYSTEM", "Developer Diagnostics", "Internal health checks and compatibility diagnostics.")
    system.main = CreateSection(system, "ADDON HEALTH", 16, -74, 552, 252)
    frame.healthLabel = CreateText(system.main, "SESSION HEALTH", 9, "TOPLEFT", system.main, "TOPLEFT", 14, -42, true)
    frame.healthValue = CreateText(system.main, "Healthy", 14, "TOPLEFT", system.main, "TOPLEFT", 14, -62, false)
    frame.healthValue:SetWidth(510); frame.healthValue:SetJustifyH("LEFT")
    frame.healthDetail = CreateText(system.main, "No module or runtime errors recorded.", 9, "TOPLEFT", system.main, "TOPLEFT", 14, -88, true)
    frame.healthDetail:SetWidth(510); frame.healthDetail:SetJustifyH("LEFT")
    frame.healthRun = CreateButton(system.main, "Run Health Check", 150, 24)
    frame.healthRun:SetPoint("TOPLEFT", system.main, "TOPLEFT", 14, -126)
    frame.healthRun:SetScript("OnClick", function()
        if SlashCmdList and SlashCmdList["ZENUI"] then SlashCmdList["ZENUI"]("doctor") end
        Config:Refresh()
    end)
    frame.healthClear = CreateButton(system.main, "Clear Error History", 150, 24)
    frame.healthClear:SetPoint("TOPLEFT", system.main, "TOPLEFT", 176, -126)
    frame.healthClear:SetScript("OnClick", function() RUI:ClearRuntimeErrors(); Config:Refresh() end)
    frame.debugCheck = CreateCheck(system.main, "Developer debug messages", 14, -172, function(v) RUI.global.debug=v end, 250)
    local cmd = CreateText(system.main, "Developer diagnostics remain available through /zenui devhelp.", 9, "TOPLEFT", system.main, "TOPLEFT", 14, -210, true)
    cmd:SetWidth(520)

    frame.footer = CreateText(frame, "Drag empty space to move  •  Esc closes  •  /zenui move for layout", 9, "BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 12, true)
    self.frame = frame
    self:BuildSearchIndex()
    frame.activePage = "GENERAL"
    self:SetPage("GENERAL")

    if UISpecialFrames then table.insert(UISpecialFrames, "ZenUIConfigFrame") end
    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "OnAppearanceChanged")
    RUI:RegisterCallback("PROFILE_RESET", self, "OnProfileReset")
    RUI:RegisterCallback("PROFILE_LIST_CHANGED", self, "OnProfileListChanged")
    RUI:RegisterCallback("PROFILE_CHANGED", self, "OnProfileListChanged")
    RUI:RegisterCallback("MOVER_MODE_CHANGED", self, "OnMoverModeChanged")
    RUI:RegisterCallback("ADDON_REGISTERED", self, "OnAddonRegistered")
    self:Refresh()
end

function Config:BeginProgressionBinding(command, label)
    if not self.frame or not self.frame.progressionBindingCapture then return end
    local capture = self.frame.progressionBindingCapture
    capture.command = command
    capture.label = label
    capture.message:SetText("Press a key for " .. tostring(label) .. ".  Delete/Backspace clears the current binding; Escape cancels.")
    capture:Show()
end

function Config:RefreshProgressionBindings()
    local frame = self.frame
    if not frame or not frame.progressionBindingButtons then return end
    for command, button in pairs(frame.progressionBindingButtons) do
        if button and button.RUIText then button.RUIText:SetText(BindingLabel(command)) end
    end
end

function Config:OnEnable() self:Refresh() end
function Config:OnAppearanceChanged() self:RefreshStyle() end
function Config:OnProfileReset() self:Refresh() end
function Config:OnProfileListChanged() if self.frame then self:RefreshProfiles(); if self.frame:IsShown() then self:Refresh() end end end
function Config:OnAddonRegistered() if self.frame and self.frame:IsShown() then self:Refresh() end end
function Config:OnMoverModeChanged(enabled) if enabled and self.frame then self.frame:Hide() end end

function Config:RefreshProfiles()
    local frame = self.frame
    if not frame or not frame.profileRows then return end
    local names = RUI.GetProfileNames and RUI:GetProfileNames() or { RUI.profileName or "Default" }
    local pageSize = #frame.profileRows
    local pages = math.max(1, math.ceil(#names / pageSize))
    frame.profileListPage = math.max(1, math.min(pages, tonumber(frame.profileListPage) or 1))
    local startIndex = ((frame.profileListPage - 1) * pageSize) + 1
    for i = 1, pageSize do
        local row = frame.profileRows[i]
        local name = names[startIndex + i - 1]
        if name then
            row.use.profileName = name; row.delete.profileName = name
            row.use.RUIText:SetText((name == RUI.profileName and "• " or "") .. name .. (name == RUI.profileName and "  (Active)" or ""))
            row.use:Show(); row.delete:Show()
            if name == RUI.profileName then row.delete:Disable() else row.delete:Enable() end
            if name == "Default" then row.delete:Disable() end
        else
            row.use.profileName = nil; row.delete.profileName = nil
            row.use:Hide(); row.delete:Hide()
        end
    end
    if frame.profileCurrentValue then frame.profileCurrentValue:SetText(RUI.profileName or "Default") end
    if frame.profilePageLabel then frame.profilePageLabel:SetText("Page " .. tostring(frame.profileListPage) .. " / " .. tostring(pages)) end
    if frame.profilePrev then if frame.profileListPage > 1 then frame.profilePrev:Enable() else frame.profilePrev:Disable() end end
    if frame.profileNext then if frame.profileListPage < pages then frame.profileNext:Enable() else frame.profileNext:Disable() end end
end

function Config:RefreshAppearanceChoices()
    local frame = self.frame
    if not frame or not RUI.db or not RUI.db.appearance then return end
    local styleKey = RUI.GetAppearanceStyleKey and RUI:GetAppearanceStyleKey() or "CLASSIC"
    local ar, ag, ab = RUI:GetAccentColor()
    local settings = RUI.GetAppearanceSettings and RUI:GetAppearanceSettings() or RUI.db.appearance

    if frame.appearanceModeButton then
        local mode = RUI.GetAppearanceMode and RUI:GetAppearanceMode() or "LOCAL"
        frame.appearanceModeButton.RUIText:SetText(mode == "GLOBAL" and "Global (EbonAPI)" or "This addon only")
        if frame.appearanceModeStatus then
            if not (RUI.IsGlobalAppearanceAvailable and RUI:IsGlobalAppearanceAvailable()) then
                frame.appearanceModeStatus:SetText("EbonAPI unavailable - local fallback")
            elseif mode == "GLOBAL" then
                frame.appearanceModeStatus:SetText("Shared across ZenStylingPack addons")
            else
                frame.appearanceModeStatus:SetText("Independent ZenUI appearance")
            end
        end
    end

    for key, button in pairs(frame.appearanceStyleButtons or {}) do
        RUI:StyleButton(button)
        if key == styleKey then RUI:SetBorderColor(button, ar, ag, ab, 1) end
    end

    local accent = settings and settings.accent or { ar, ag, ab }
    for i = 1, #(frame.appearanceAccentButtons or {}) do
        local button = frame.appearanceAccentButtons[i]
        RUI:StyleButton(button)
        local c = button.RUIAccentPreset
        if c and math.abs((accent[1] or 0) - c[1]) < 0.01 and math.abs((accent[2] or 0) - c[2]) < 0.01 and math.abs((accent[3] or 0) - c[3]) < 0.01 then
            RUI:SetBorderColor(button, ar, ag, ab, 1)
        end
    end

    if frame.appearancePreviewAccent then RUI:SetAccentTexture(frame.appearancePreviewAccent) end
    if frame.appearancePreviewSelected then
        RUI:StyleButton(frame.appearancePreviewSelected)
        RUI:SetBorderColor(frame.appearancePreviewSelected, ar, ag, ab, 1)
    end
    if frame.appearancePreviewStatus then
        local style = RUI.GetAppearanceStyle and RUI:GetAppearanceStyle()
        frame.appearancePreviewStatus:SetText(style and style.label or styleKey)
    end
end

function Config:RefreshStyle()
    local frame=self.frame; if not frame then return end
    for i=1,#self.backdrops do RUI:RefreshBackdrop(self.backdrops[i]) end
    RUI:SetAccentTexture(frame.accent); frame.accent:SetHeight(RUI:GetPixelSize(frame,2))
    for i=1,#self.texts do
        local fs=self.texts[i]; local r,g,b=RUI:GetTextColor(fs.RUIMuted)
        RUI:StyleFontString(fs,fs.RUISize,r,g,b)
    end
    for i=1,#self.buttons do RUI:StyleButton(self.buttons[i]) end
    for i=1,#self.controls do if self.controls[i].RefreshStyle then self.controls[i]:RefreshStyle() end end
    self:RefreshAppearanceChoices()
    self:RefreshNavigation()
end

function Config:Refresh()
    if not self.frame or not RUI.db then return end
    local a=(RUI.GetAppearanceSettings and RUI:GetAppearanceSettings()) or RUI.db.appearance; local accent=a.accent; local scales=RUI.db.scales or {}; local l=RUI.db.layout; local uf=RUI.db.unitframes; local t=uf.text or {}; local raid=uf.raid or {}; local ab=RUI.db.actionbars or {}; local abb=ab.bars or {}; local menu=RUI.db.menu or {}; local mm=RUI.db.minimap or {}; local tt=RUI.db.tooltip or {}; local chat=RUI.db.chat or {}; local mail=RUI.db.mail or {}; local bags=RUI.db.bags or {}; local loot=RUI.db.loot or {}; local groupTools=RUI.db.groupTools or {}; local blizzard=RUI.db.blizzard or {}

    self.frame.scale:SetRUIValue((a.scale or 1)*100)
    self.frame.alpha:SetRUIValue((a.panelAlpha or .96)*100)
    self.frame.red:SetRUIValue((accent[1] or .92)*100); self.frame.green:SetRUIValue((accent[2] or .63)*100); self.frame.blue:SetRUIValue((accent[3] or .40)*100)
    self.frame.accentSwatch:SetRUIColor(accent[1] or .92, accent[2] or .63, accent[3] or .40)
    self.frame.fontButton.RUIText:SetText(RUI:GetFontName(a.font))
    self:RefreshAppearanceChoices()
    self.frame.scaleUnitFrames:SetRUIValue((scales.unitframes or 1) * 100)
    self.frame.scaleParty:SetRUIValue((scales.party or 1) * 100)
    self.frame.scaleRaid:SetRUIValue((scales.raid or 1) * 100)
    self.frame.scaleActionBars:SetRUIValue((scales.actionbars or 1) * 100)
    self.frame.scaleMinimap:SetRUIValue((scales.minimap or 1) * 100)
    self.frame.scaleChat:SetRUIValue((scales.chat or 1) * 100)
    self.frame.scaleBags:SetRUIValue((scales.bags or 1) * 100)
    self.frame.scaleMenu:SetRUIValue((scales.menu or 1) * 100)
    if self.frame.scaleZenLootRolls then self.frame.scaleZenLootRolls:SetRUIValue((scales.zenLootRolls or 1) * 100) end
    self.frame.scaleZenSpellbook:SetRUIValue((scales.zenSpellbook or 1) * 100)
    self.frame.scaleZenSocial:SetRUIValue((scales.zenSocial or 1) * 100)
    self.frame.scaleZenGuild:SetRUIValue((scales.zenGuild or 1) * 100)
    self.frame.scaleZenDungeon:SetRUIValue((scales.zenDungeonFinder or 1) * 100)
    self.frame.scaleZenCharacter:SetRUIValue((scales.zenCharacter or 1) * 100)
    self.frame.scaleZenQuestLog:SetRUIValue((scales.zenQuestLog or 1) * 100)
    self.frame.scaleZenMail:SetRUIValue((scales.zenMail or 1) * 100)
    self.frame.scaleZenMerchant:SetRUIValue((scales.zenMerchant or 1) * 100)
    self.frame.scaleZenBank:SetRUIValue((scales.zenBank or 1) * 100)
    self.frame.scaleZenTrade:SetRUIValue((scales.zenTrade or 1) * 100)
    if self.frame.scaleZenTalents then self.frame.scaleZenTalents:SetRUIValue((scales.zenTalents or 1) * 100) end
    if self.frame.scaleZenPVP then self.frame.scaleZenPVP:SetRUIValue((scales.zenPVP or 1) * 100) end
    if self.frame.scaleZenStatusBars then self.frame.scaleZenStatusBars:SetRUIValue((scales.zenStatusBars or 1) * 100) end
    if self.frame.scaleZenAchievements then self.frame.scaleZenAchievements:SetRUIValue((scales.zenAchievements or 1) * 100) end
    if self.frame.scaleZenInspect then self.frame.scaleZenInspect:SetRUIValue((scales.zenInspect or 1) * 100) end
    if self.frame.scaleZenTrainer then self.frame.scaleZenTrainer:SetRUIValue((scales.zenTrainer or 1) * 100) end
    if self.frame.scaleZenNPCInteraction then self.frame.scaleZenNPCInteraction:SetRUIValue((scales.zenNPCInteraction or 1) * 100) end

    self.frame.ufEnable:SetRUIValue(uf.enabled); self.frame.ufBlizzard:SetRUIValue(uf.hideBlizzard); self.frame.ufCastbars:SetRUIValue(uf.showCastbars)
    self.frame.ufTargetTarget:SetRUIValue(uf.showTargetTarget); self.frame.ufResources:SetRUIValue(uf.showClassResources)
    self.frame.ufPortraits:SetRUIValue(uf.showPortraits); self.frame.ufFocus:SetRUIValue(uf.showFocus); self.frame.ufFocusTarget:SetRUIValue(uf.showFocusTarget); self.frame.ufPet:SetRUIValue(uf.showPet)
    if self.frame.auraPlayerEnable then self.frame.auraPlayerEnable:SetRUIValue(uf.showPlayerAuras == true) end
    if self.frame.auraTargetEnable then self.frame.auraTargetEnable:SetRUIValue(uf.showTargetAuras ~= false) end
    if self.frame.auraFocusEnable then self.frame.auraFocusEnable:SetRUIValue(uf.showFocusAuras == true) end
    if self.frame.auraPetEnable then self.frame.auraPetEnable:SetRUIValue(uf.showPetAuras == true) end
    if self.frame.auraPlayerBuff then self.frame.auraPlayerBuff.RUIText:SetText(AuraPositionLabel(uf.playerBuffPosition)) end
    if self.frame.auraPlayerDebuff then self.frame.auraPlayerDebuff.RUIText:SetText(AuraPositionLabel(uf.playerDebuffPosition or "BOTTOM")) end
    if self.frame.auraTargetBuff then self.frame.auraTargetBuff.RUIText:SetText(AuraPositionLabel(uf.targetBuffPosition)) end
    if self.frame.auraTargetDebuff then self.frame.auraTargetDebuff.RUIText:SetText(AuraPositionLabel(uf.targetDebuffPosition or "BOTTOM")) end
    if self.frame.auraFocusBuff then self.frame.auraFocusBuff.RUIText:SetText(AuraPositionLabel(uf.focusBuffPosition)) end
    if self.frame.auraFocusDebuff then self.frame.auraFocusDebuff.RUIText:SetText(AuraPositionLabel(uf.focusDebuffPosition or "BOTTOM")) end
    if self.frame.auraPetBuff then self.frame.auraPetBuff.RUIText:SetText(AuraPositionLabel(uf.petBuffPosition)) end
    if self.frame.auraPetDebuff then self.frame.auraPetDebuff.RUIText:SetText(AuraPositionLabel(uf.petDebuffPosition or "BOTTOM")) end
    self.frame.ufParty:SetRUIValue(uf.showParty); self.frame.ufRaid:SetRUIValue(uf.showRaid)
    local ufModule = RUI:GetModule("UnitFrames")
    if self.frame.previewParty then self.frame.previewParty.RUIText:SetText(ufModule and ufModule.previewParty and "Stop Party Preview" or "Preview Party") end
    if self.frame.previewRaid then self.frame.previewRaid.RUIText:SetText(ufModule and ufModule.previewRaid and "Stop Raid Preview" or "Preview Raid") end
    self.frame.raidGroups:SetRUIValue(raid.groups or 5)
    self.frame.raidOrientationButton.RUIText:SetText((raid.orientation or "HORIZONTAL") == "VERTICAL" and "Rows" or "Columns")
    self.frame.raidGroupLabels:SetRUIValue(raid.showGroupLabels ~= false); self.frame.raidPower:SetRUIValue(raid.showPower ~= false); self.frame.raidDebuffs:SetRUIValue(raid.showDebuffs ~= false)
    self.frame.raidReady:SetRUIValue(raid.showReady ~= false); self.frame.raidRank:SetRUIValue(raid.showRank ~= false)
    local healthNames={PERCENT="Percent",DEFICIT="Deficit",CURRENT="Current",NONE="Hidden"}; self.frame.raidHealthButton.RUIText:SetText(healthNames[raid.healthMode or "PERCENT"] or "Percent")
    if self.frame.autoInviteEnable then self.frame.autoInviteEnable:SetRUIValue(groupTools.autoInvite == true) end
    if self.frame.autoInviteTriggers and not self.frame.autoInviteTriggers:HasFocus() then self.frame.autoInviteTriggers:SetText(NormalizeAutoInviteTriggerString(groupTools.autoInviteTriggers or "inv")) end

    self.frame.ufTextFontButton.RUIText:SetText(RUI:GetFontName(t.font or "Default")); self.frame.ufTextSize:SetRUIValue((t.size or 1.10)*100)
    local styles={SHADOW="Shadow",OUTLINE="Outline",BOLD="Bold",PLAIN="Plain"}; local colors={LIGHT="Light",ACCENT="Accent",CUSTOM="Custom"}
    self.frame.ufTextStyleButton.RUIText:SetText(styles[t.style or "OUTLINE"] or "Outline"); self.frame.ufTextColorButton.RUIText:SetText(colors[t.colorMode or "LIGHT"] or "Light")
    local c=t.customColor or {1,1,1}; self.frame.ufTextRed:SetRUIValue((c[1] or 1)*100); self.frame.ufTextGreen:SetRUIValue((c[2] or 1)*100); self.frame.ufTextBlue:SetRUIValue((c[3] or 1)*100)
    self.frame.ufTextPicker:SetRUIColor(c[1] or 1, c[2] or 1, c[3] or 1)
    self.frame.ufTextAutoFit:SetRUIValue(t.autoFit ~= false); self.frame.ufTextMinScale:SetRUIValue((t.minScale or .70)*100)
    self.frame.ufTextShowName:SetRUIValue(t.showName ~= false); self.frame.ufTextShowLevel:SetRUIValue(t.showLevel ~= false); self.frame.ufTextShowClass:SetRUIValue(t.showClass ~= false)
    self.frame.ufTextShowHealthValue:SetRUIValue(t.showHealthValue ~= false); self.frame.ufTextShowHealthPercent:SetRUIValue(t.showHealthPercent ~= false)
    self.frame.ufTextShowPowerValue:SetRUIValue(t.showPowerValue ~= false); self.frame.ufTextShowPowerMax:SetRUIValue(t.showPowerMax ~= false)

    self.frame.abEnable:SetRUIValue(ab.enabled ~= false); self.frame.abHideArt:SetRUIValue(ab.hideBlizzardArt ~= false)
    self.frame.abHotkeys:SetRUIValue(ab.showHotkeys ~= false); self.frame.abMacro:SetRUIValue(ab.showMacroText == true); self.frame.abEmpty:SetRUIValue(ab.showEmptyButtons == true)
    self.frame.abSize:SetRUIValue(ab.buttonSize or 34); self.frame.abSpacing:SetRUIValue(ab.spacing or 4)
    for i=1,6 do
        local b=abb[i] or {}; self.frame.abBarChecks[i]:SetRUIValue(b.enabled == true)
        self.frame.abRowSliders[i]:SetRUIValue(RowsToSliderIndex(b.rows or 1))
        self.frame.abButtonSliders[i]:SetRUIValue(b.buttons or 12)
        self.frame.abAlphaSliders[i]:SetRUIValue((b.alpha or 1) * 100)
        self.frame.abMouseoverChecks[i]:SetRUIValue(b.mouseover == true)
        self.frame.abVisibilityButtons[i].RUIText:SetText(VisibilityLabel(b.visibility))
    end
    self.frame.abPet:SetRUIValue(ab.showPetBar ~= false); self.frame.abStance:SetRUIValue(ab.showStanceBar ~= false); self.frame.abTotem:SetRUIValue(ab.showTotemBar ~= false); self.frame.abTotemTimers:SetRUIValue(ab.showTotemTimers ~= false)
    local petBehavior = ab.petBehavior or {}; local stanceBehavior = ab.stanceBehavior or {}
    self.frame.abPetAlpha:SetRUIValue((petBehavior.alpha or 1) * 100); self.frame.abPetMouseover:SetRUIValue(petBehavior.mouseover == true); self.frame.abPetVisibility.RUIText:SetText("Visibility: " .. VisibilityLabel(petBehavior.visibility))
    self.frame.abStanceAlpha:SetRUIValue((stanceBehavior.alpha or 1) * 100); self.frame.abStanceMouseover:SetRUIValue(stanceBehavior.mouseover == true); self.frame.abStanceVisibility.RUIText:SetText("Visibility: " .. VisibilityLabel(stanceBehavior.visibility))

    self.frame.menuEnable:SetRUIValue(menu.enabled ~= false); self.frame.menuHideBlizzard:SetRUIValue(menu.hideBlizzard ~= false)
    self.frame.menuBag:SetRUIValue(menu.showBagButton ~= false); self.frame.menuFreeSlots:SetRUIValue(menu.showFreeSlots ~= false); self.frame.menuCloseOnClick:SetRUIValue(menu.closeOnClick ~= false)
    if self.frame.menuQuick then self.frame.menuQuick:SetRUIValue(menu.showQuickMenu ~= false) end
    local addonCount=0; for _ in pairs(RUI.registeredAddons or {}) do addonCount=addonCount+1 end
    self.frame.menuAddonCount:SetText("Registered companion addons: " .. tostring(addonCount))

    self.frame.mmEnable:SetRUIValue(mm.enabled ~= false); self.frame.mmZone:SetRUIValue(mm.showZone ~= false); self.frame.mmClock:SetRUIValue(mm.showClock ~= false)
    self.frame.mmClock24:SetRUIValue(mm.clock24 ~= false); if self.frame.mmClockOffset then self.frame.mmClockOffset:SetRUIValue(mm.clockOffsetMinutes or 0) end; self.frame.mmWheel:SetRUIValue(mm.mouseWheelZoom ~= false)
    self.frame.mmZoomButtons:SetRUIValue(mm.showZoomButtons == true); self.frame.mmWorldMap:SetRUIValue(mm.showWorldMapButton == true); self.frame.mmSize:SetRUIValue(mm.size or 180)
    self.frame.mmTracking:SetRUIValue(mm.showTracking ~= false); self.frame.mmMail:SetRUIValue(mm.showMail ~= false); self.frame.mmLFG:SetRUIValue(mm.showLFG ~= false); self.frame.mmDifficulty:SetRUIValue(mm.showDifficulty ~= false)
    self.frame.mmBattlefield:SetRUIValue(mm.showBattlefield ~= false); self.frame.mmCollector:SetRUIValue(mm.collectAddonButtons ~= false); if self.frame.mmRaidIdentifier then self.frame.mmRaidIdentifier:SetRUIValue(mm.showRaidIdentifier ~= false) end; self.frame.mmCollectorColumns:SetRUIValue(mm.collectorColumns or 4)

    self.frame.ttEnable:SetRUIValue(tt.enabled ~= false); self.frame.ttUnitBorder:SetRUIValue(tt.unitBorder ~= false); self.frame.ttHealth:SetRUIValue(tt.showHealthBar ~= false); self.frame.ttScale:SetRUIValue((tt.scale or 1) * 100)

    self.frame.chatEnable:SetRUIValue(chat.enabled ~= false); self.frame.chatLocked:SetRUIValue(chat.locked ~= false); self.frame.chatHideButtons:SetRUIValue(chat.hideButtons ~= false); self.frame.chatFade:SetRUIValue(chat.fade == true)
    self.frame.chatFontSize:SetRUIValue(chat.fontSize or 12); self.frame.chatBackground:SetRUIValue((chat.backgroundAlpha or .45) * 100); self.frame.chatWidth:SetRUIValue(chat.width or 430); self.frame.chatHeight:SetRUIValue(chat.height or 180)
    if self.frame.chatEditAlpha then self.frame.chatEditAlpha:SetRUIValue((chat.editBoxAlpha or .72) * 100) end
    if self.frame.chatEditHeight then self.frame.chatEditHeight:SetRUIValue(chat.editBoxHeight or 28) end
    if self.frame.chatEditFont then self.frame.chatEditFont:SetRUIValue(chat.editBoxFontSize or 12) end

    if self.frame.mailKeepFree then self.frame.mailKeepFree:SetRUIValue(mail.keepFreeSlots or 1) end
    if self.frame.mailSessionTotal then self.frame.mailSessionTotal:SetRUIValue(mail.showSessionTotal ~= false) end

    self.frame.bagEnable:SetRUIValue(bags.enabled ~= false); self.frame.bagSearch:SetRUIValue(bags.showSearch ~= false); self.frame.bagQuality:SetRUIValue(bags.showQuality ~= false)
    self.frame.bagColumns:SetRUIValue(bags.columns or 12); self.frame.bagButtonSize:SetRUIValue(bags.buttonSize or 34); self.frame.bagSpacing:SetRUIValue(bags.spacing or 4)
    local bc = bags.containers or {}
    self.frame.bagBackpack:SetRUIValue(bc.backpack ~= false); self.frame.bagBag1:SetRUIValue(bc.bag1 ~= false); self.frame.bagBag2:SetRUIValue(bc.bag2 ~= false)
    self.frame.bagBag3:SetRUIValue(bc.bag3 ~= false); self.frame.bagBag4:SetRUIValue(bc.bag4 ~= false); self.frame.bagKeyring:SetRUIValue(bc.keyring ~= false)
    self.frame.bagBank:SetRUIValue(bc.bank == true); self.frame.bagBankBags:SetRUIValue(bc.bankBags == true)
    if self.frame.lootEnable then self.frame.lootEnable:SetRUIValue(loot.enabled ~= false) end
    if self.frame.lootHideRollChat then self.frame.lootHideRollChat:SetRUIValue(loot.hideRollChat == true) end
    if self.frame.lootAutoEnable then self.frame.lootAutoEnable:SetRUIValue(loot.autoRollEnabled == true) end
    if self.frame.lootAutoNotify then self.frame.lootAutoNotify:SetRUIValue(loot.autoRollNotify ~= false) end
    if self.frame.lootAutoBoPNoNeed then self.frame.lootAutoBoPNoNeed:SetRUIValue(loot.autoPassBoPNoNeed == true) end
    if self.frame.lootAutoRuleButtons then
        local rules = loot.autoRollRules or {}
        for quality = 0, 4 do
            local button = self.frame.lootAutoRuleButtons[quality]
            if button and button.RUIText then button.RUIText:SetText(LootAutoActionLabel(rules[quality])) end
        end
    end

    self.frame.blizzEnable:SetRUIValue(blizzard.enabled ~= false)
    self.frame.blizzSpellbook:SetRUIValue(blizzard.spellbook ~= false)
    self.frame.blizzSocial:SetRUIValue(blizzard.social ~= false)
    self.frame.blizzGuild:SetRUIValue(blizzard.guild ~= false)
    self.frame.blizzDungeon:SetRUIValue(blizzard.dungeonFinder ~= false)
    self.frame.blizzCharacter:SetRUIValue(blizzard.character ~= false)
    self.frame.blizzQuestLog:SetRUIValue(blizzard.questLog ~= false)
    self.frame.blizzMail:SetRUIValue(blizzard.mail ~= false)
    self.frame.blizzMerchant:SetRUIValue(blizzard.merchant ~= false)
    self.frame.blizzBank:SetRUIValue(blizzard.bank ~= false)
    self.frame.blizzTrade:SetRUIValue(blizzard.trade ~= false)
    if self.frame.blizzTalents then self.frame.blizzTalents:SetRUIValue(blizzard.talents ~= false) end
    if self.frame.blizzPVP then self.frame.blizzPVP:SetRUIValue(blizzard.pvp ~= false) end
    if self.frame.blizzXPBar then self.frame.blizzXPBar:SetRUIValue(blizzard.xpBar ~= false) end
    if self.frame.blizzRepBar then self.frame.blizzRepBar:SetRUIValue(blizzard.reputationBar ~= false) end
    if self.frame.blizzAchievements then self.frame.blizzAchievements:SetRUIValue(blizzard.achievements ~= false) end
    if self.frame.blizzInspect then self.frame.blizzInspect:SetRUIValue(blizzard.inspect ~= false) end
    if self.frame.blizzTrainer then self.frame.blizzTrainer:SetRUIValue(blizzard.trainer ~= false) end
    if self.frame.blizzNPCDialog then self.frame.blizzNPCDialog:SetRUIValue(blizzard.npcDialog ~= false) end
    if self.frame.guildOffline then self.frame.guildOffline:SetRUIValue(blizzard.guildShowOffline ~= false) end

    local bankContainers=blizzard.bankContainers or {}
    if self.frame.bankEnable then self.frame.bankEnable:SetRUIValue(blizzard.bank ~= false) end
    if self.frame.bankScale then self.frame.bankScale:SetRUIValue((scales.zenBank or 1)*100) end
    if self.frame.bankDefaultMain then self.frame.bankDefaultMain:SetRUIValue(bankContainers.bank ~= false) end
    for i=1,7 do
        local control=self.frame["bankDefault"..tostring(i)]
        if control then control:SetRUIValue(bankContainers["bag"..tostring(i)] ~= false) end
    end
    if self.frame.bankQuickModifier then
        local modifier=string.upper(tostring(blizzard.bankQuickDropModifier or "SHIFT"))
        self.frame.bankQuickModifier.RUIText:SetText(BANK_QUICK_MODIFIER_LABELS[modifier] or BANK_QUICK_MODIFIER_LABELS.SHIFT)
    end
    local phaseB=RUI:GetModule("BlizzardPhaseB")
    local bankFrame=phaseB and phaseB.frames and phaseB.frames.bank
    local state=bankFrame and bankFrame.extBankState
    if self.frame.bankExtSlots then
        if state and state.decoded then
            self.frame.bankExtSlots:SetText("Storage: "..tostring(state.unlockedBagSlots or 0).." / 70 positions unlocked  •  "..tostring(state.itemCount or 0).." items stored")
        else
            self.frame.bankExtSlots:SetText("Storage: open the bank to load Extended Bank status")
        end
    end
    if self.frame.bankExtPrice then
        local unlocked=(state and tonumber(state.unlockedBagSlots) or 0)
        local nextSlot=unlocked+1
        local sourceCosts={50,125,250,500,1250,2500,5000,10000}
        local gold=(nextSlot<=70) and sourceCosts[math.min(nextSlot,#sourceCosts)] or nil
        local cost=gold and gold*10000 or nil
        self.frame.bankExtPrice:SetText(nextSlot<=70 and ("Next unlock: slot "..tostring(nextSlot).."  •  "..ConfigMoney(cost)) or "All 70 Extended Bank positions purchased")
    end
    self.frame.snapCheck:SetRUIValue(l.snapEnabled); self.frame.snapSize:SetRUIValue(l.snapSize or 4); self.frame.debugCheck:SetRUIValue(RUI.global.debug)
    if self.frame.healthValue and self.frame.healthDetail then
        local health, failed, errors = RUI:GetHealthSummary()
        self.frame.healthValue:SetText(health)
        self.frame.healthDetail:SetText(tostring(failed).." module failure(s)  •  "..tostring(errors).." runtime error(s) recorded this session")
    end
    local g=self.frame.pages.GENERAL; g.versionValue:SetText(RUI.version or "1.0.3"); g.interfaceValue:SetText("3.3.5a / "..tostring(RUI.interface or 30300)); g.profileValue:SetText(RUI.profileName or "Default")
    self:RefreshProfiles()
    self:RefreshProgressionBindings()
    self:RefreshStyle()
end

function Config:Show(page)
    if not self.frame then RUI:Print("Config module is not initialized. Use /zenui status for details."); return end
    if RUI.moverMode then RUI:SetMoverMode(false) end
    if RUI.ActivateExclusivePanel then RUI:ActivateExclusivePanel(self.frame) end
    self:Refresh(); self:SetPage(page or self.frame.activePage or "GENERAL"); self.frame:Show()
end
function Config:ShowPage(page) self:Show(page) end
function Config:Hide() if self.frame then self.frame:Hide() end end
function Config:Toggle() if not self.frame then return end; if self.frame:IsShown() then self.frame:Hide() else self:Show() end end
