-- ZenUI 0.9.97 loot + loot roll replacement.
-- Replaces only the visible Wrath GroupLoot frames; the native RollOnLoot and
-- confirmation paths remain authoritative for Project Ebonhold compatibility.

local RUI = ZenUI
local LootRolls = RUI:NewModule("LootRolls")

local CARD_WIDTH = 438
local CARD_HEIGHT = 88
local CARD_GAP = 7
local MAX_ROLL_FRAMES = 4
local LOOT_WINDOW_WIDTH = 222
local LOOT_WINDOW_HEIGHT = 244
local LOOT_ROW_HEIGHT = 42
local LOOT_ROW_GAP = 5

local ROLL_PASS = 0
local ROLL_NEED = 1
local ROLL_GREED = 2
local ROLL_DISENCHANT = 3

local rollChatPatterns = nil

local function EscapePatternCharacter(character)
    if string.find("^$()%.[]*+-?", character, 1, true) then
        return "%" .. character
    end
    return character
end

local function FormatStringToPattern(formatString)
    if type(formatString) ~= "string" or formatString == "" then return nil end
    local output = { "^" }
    local i = 1
    while i <= string.len(formatString) do
        local character = string.sub(formatString, i, i)
        if character == "%" then
            local j = i + 1
            if string.sub(formatString, j, j) == "%" then
                table.insert(output, "%%")
                i = j + 1
            else
                -- Wrath format globals use both %s/%d and positional forms
                -- such as %1$s. Skip the position before reading the type.
                while j <= string.len(formatString) and string.find(string.sub(formatString, j, j), "%d") do
                    j = j + 1
                end
                if string.sub(formatString, j, j) == "$" then j = j + 1 end
                local specifier = string.sub(formatString, j, j)
                if specifier == "d" or specifier == "i" then
                    table.insert(output, "%-?%d+")
                    i = j + 1
                elseif specifier == "s" then
                    table.insert(output, ".-")
                    i = j + 1
                else
                    -- Unknown formatter: match it permissively rather than
                    -- risking a false positive against unrelated loot text.
                    table.insert(output, ".-")
                    i = math.max(j + 1, i + 2)
                end
            end
        else
            table.insert(output, EscapePatternCharacter(character))
            i = i + 1
        end
    end
    table.insert(output, "$")
    return table.concat(output)
end

local function BuildRollChatPatterns()
    local patterns = {}
    -- Use the client's own localized LOOT_ROLL_* strings so this remains
    -- compatible with Ebonhold/Wrath wording and localization. Actual loot
    -- receipt messages use different LOOT_ITEM* globals and are not filtered.
    for key, value in pairs(_G) do
        if type(key) == "string" and string.find(key, "^LOOT_ROLL_") and type(value) == "string" and value ~= "" then
            local pattern = FormatStringToPattern(value)
            if pattern then table.insert(patterns, pattern) end
        end
    end
    return patterns
end

local function IsRollChatMessage(message)
    if type(message) ~= "string" or message == "" then return false end
    if not rollChatPatterns then rollChatPatterns = BuildRollChatPatterns() end
    for i = 1, #rollChatPatterns do
        if string.find(message, rollChatPatterns[i]) then return true end
    end

    -- Ebonhold occasionally emits custom English variants that do not use a
    -- stock global. Keep these fallbacks deliberately specific and only apply
    -- them to CHAT_MSG_LOOT.
    local plain = string.lower(message)
    if string.find(plain, " has selected need for:", 1, true) then return true end
    if string.find(plain, " has selected greed for:", 1, true) then return true end
    if string.find(plain, " has selected disenchant for:", 1, true) then return true end
    if string.find(plain, "need roll -", 1, true) then return true end
    if string.find(plain, "greed roll -", 1, true) then return true end
    if string.find(plain, "disenchant roll -", 1, true) then return true end
    if string.find(plain, " passed on:", 1, true) then return true end
    if string.find(plain, "roll started on:", 1, true) then return true end
    return false
end

local function LootRollChatFilter(_, event, message, ...)
    local loot = RUI.db and RUI.db.loot
    if not loot or loot.hideRollChat ~= true then return false end
    if event ~= "CHAT_MSG_LOOT" then return false end
    if IsRollChatMessage(message) then return true end
    return false
end

local AUTO_ACTION_LABELS = {
    MANUAL = "Manual",
    PASS = "Auto Pass",
    GREED = "Auto Greed",
    DISENCHANT = "Auto Disenchant",
}

local function SafeQualityColor(quality)
    local colors = ITEM_QUALITY_COLORS
    local color = colors and colors[tonumber(quality) or 1]
    if color then return color.r or 1, color.g or 1, color.b or 1 end
    return 1, 1, 1
end

local function GetIneligibleReason(reasonIndex, skillRequired)
    if not reasonIndex then return "Not available for this item." end
    local text = _G["LOOT_ROLL_INELIGIBLE_REASON" .. tostring(reasonIndex)]
    if not text or text == "" then return "Not available for this item." end
    if skillRequired and string.find(text, "%%") then
        local ok, formatted = pcall(format, text, skillRequired)
        if ok and formatted then return formatted end
    end
    return text
end

local function CreateFont(parent, size, muted)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local r, g, b = RUI:GetTextColor(muted and true or false)
    RUI:StyleFontString(fs, size or 10, r, g, b)
    fs.RUISize = size or 10
    fs.RUIMuted = muted and true or false
    return fs
end

local function RefreshFont(fs)
    if not fs then return end
    local r, g, b = RUI:GetTextColor(fs.RUIMuted and true or false)
    RUI:StyleFontString(fs, fs.RUISize or 10, r, g, b)
end

function LootRolls:IsZenEnabled()
    local loot = RUI.db and RUI.db.loot
    return loot and loot.enabled ~= false
end

function LootRolls:GetAutoSettings()
    local loot = RUI.db and RUI.db.loot
    if not loot then return nil end
    loot.autoRollRules = loot.autoRollRules or {}
    return loot
end

function LootRolls:GetQualityAutoAction(quality)
    local loot = self:GetAutoSettings()
    if not loot then return "MANUAL" end
    local action = loot.autoRollRules and loot.autoRollRules[tonumber(quality) or 0]
    action = string.upper(tostring(action or "MANUAL"))
    if action ~= "PASS" and action ~= "GREED" and action ~= "DISENCHANT" then
        action = "MANUAL"
    end
    return action
end

function LootRolls:EvaluateAutoRoll(card)
    local loot = self:GetAutoSettings()
    if not loot or loot.autoRollEnabled ~= true or not card or not card.rollID then return nil end

    -- Group-loot automation should never try to second-guess master-looter
    -- control. START_LOOT_ROLL normally does not occur here, but keep the
    -- guard for private-server variants.
    if GetLootMethod then
        local method = GetLootMethod()
        if method == "master" then return nil end
    end

    if loot.autoPassBoPNoNeed == true and card.bindOnPickUp and card.canNeed == false then
        return ROLL_PASS, "Auto Pass", "BoP item cannot be Needed"
    end

    local action = self:GetQualityAutoAction(card.quality)
    if action == "PASS" then
        return ROLL_PASS, AUTO_ACTION_LABELS.PASS
    elseif action == "GREED" then
        if card.canGreed then return ROLL_GREED, AUTO_ACTION_LABELS.GREED end
        return nil
    elseif action == "DISENCHANT" then
        if card.canDisenchant then return ROLL_DISENCHANT, AUTO_ACTION_LABELS.DISENCHANT end
        return nil
    end
    return nil
end

function LootRolls:TryAutoRoll(card)
    if not card or card.autoRollAttempted then return false end
    card.autoRollAttempted = true

    local rollType, label, reason = self:EvaluateAutoRoll(card)
    if rollType == nil or type(RollOnLoot) ~= "function" then return false end

    card.autoRollType = rollType
    card.autoRollLabel = label
    if card.info then
        card.info:SetText(reason and (label .. " - " .. reason) or (label .. " selected"))
    end

    local loot = self:GetAutoSettings()
    if loot and loot.autoRollNotify ~= false then
        local itemName = card.itemName or "loot"
        RUI:Print((label or "Auto Roll") .. ": " .. itemName)
    end

    -- Wrath may require one or more confirmation events after an automatic
    -- Greed/Disenchant choice (especially BoP + Disenchant). Keep the roll
    -- marked until CANCEL_LOOT_ROLL so only Zen's own automatic choices
    -- can be confirmed without user input. Manual rolls are never added here.
    self.pendingAutoConfirm = self.pendingAutoConfirm or {}
    self.pendingAutoConfirm[card.rollID] = {
        rollType = rollType,
        itemName = card.itemName,
    }

    RollOnLoot(card.rollID, rollType)
    return true
end

function LootRolls:SetNativeLootFrameSuppressed(suppressed)
    local frame = _G.LootFrame
    if not frame then return end
    if self.nativeLootFrameAlpha == nil then
        self.nativeLootFrameAlpha = frame:GetAlpha() or 1
    end
    if suppressed then
        frame:SetAlpha(0)
    else
        frame:SetAlpha(self.nativeLootFrameAlpha or 1)
    end
end

function LootRolls:CreateLootWindow()
    if self.lootWindow or not _G.LootFrame then return end

    local frame = CreateFrame("Frame", "ZenUILootWindow", UIParent)
    frame:SetWidth(LOOT_WINDOW_WIDTH)
    frame:SetHeight(LOOT_WINDOW_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetPoint("TOPLEFT", _G.LootFrame, "TOPLEFT", 12, -8)
    frame:Hide()
    RUI:CreateBackdrop(frame)
    frame.accent = RUI:CreateAccentLine(frame, 2)

    frame.title = CreateFont(frame, 12, false)
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -11)
    frame.title:SetText("Loot")

    frame.close = CreateFrame("Button", nil, frame)
    frame.close:SetWidth(24)
    frame.close:SetHeight(24)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -7)
    frame.close.RUIText = CreateFont(frame.close, 13, false)
    frame.close.RUIText:SetPoint("CENTER", frame.close, "CENTER", 0, 0)
    frame.close.RUIText:SetText("x")
    RUI:StyleButton(frame.close)
    frame.close:SetScript("OnClick", function()
        if HideUIPanel and _G.LootFrame then
            HideUIPanel(_G.LootFrame)
        elseif _G.LootFrame then
            _G.LootFrame:Hide()
        end
    end)

    frame.rows = {}
    for i = 1, 4 do
        local row = CreateFrame("Button", "ZenUILootItem" .. tostring(i), frame)
        row:SetWidth(LOOT_WINDOW_WIDTH - 24)
        row:SetHeight(LOOT_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -42 - ((i - 1) * (LOOT_ROW_HEIGHT + LOOT_ROW_GAP)))
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:Hide()
        RUI:CreateBackdrop(row)

        row.iconFrame = CreateFrame("Frame", nil, row)
        row.iconFrame:SetWidth(34)
        row.iconFrame:SetHeight(34)
        row.iconFrame:SetPoint("LEFT", row, "LEFT", 4, 0)
        RUI:CreateBackdrop(row.iconFrame)

        row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("TOPLEFT", row.iconFrame, "TOPLEFT", 2, -2)
        row.icon:SetPoint("BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", -2, 2)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.count = CreateFont(row.iconFrame, 9, false)
        row.count:SetPoint("BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", -3, 3)
        row.count:SetJustifyH("RIGHT")

        row.name = CreateFont(row, 10, false)
        row.name:SetPoint("LEFT", row.iconFrame, "RIGHT", 8, 0)
        row.name:SetWidth(145)
        row.name:SetHeight(34)
        row.name:SetJustifyH("LEFT")

        row:SetScript("OnEnter", function(self)
            if not self.slot then return end
            if LootSlotIsItem and LootSlotIsItem(self.slot) then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetLootItem(self.slot)
                GameTooltip:Show()
            end
            if CursorUpdate then CursorUpdate(self) end
            self:SetScript("OnUpdate", function(button)
                if button.slot and GameTooltip and GameTooltip:IsOwned(button) and LootSlotIsItem and LootSlotIsItem(button.slot) then
                    GameTooltip:SetLootItem(button.slot)
                end
                if CursorOnUpdate then CursorOnUpdate(button) end
            end)
        end)
        row:SetScript("OnLeave", function(self)
            self:SetScript("OnUpdate", nil)
            GameTooltip:Hide()
            if ResetCursor then ResetCursor() end
        end)
        row:SetScript("OnClick", function(self, button)
            if not self.slot then return end
            local link = GetLootSlotLink and GetLootSlotLink(self.slot)
            if link and RUI.HandleModifiedLinkClick and RUI:HandleModifiedLinkClick(link, button) then return end

            if _G.LootFrame then
                _G.LootFrame.selectedLootButton = self:GetName()
                _G.LootFrame.selectedSlot = self.slot
                _G.LootFrame.selectedQuality = self.quality
                _G.LootFrame.selectedItemName = self.itemName
            end
            if LootSlot then LootSlot(self.slot) end
        end)

        frame.rows[i] = row
    end

    frame.prev = CreateFrame("Button", nil, frame)
    frame.prev:SetWidth(84)
    frame.prev:SetHeight(23)
    frame.prev:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 9)
    frame.prev.RUIText = CreateFont(frame.prev, 9, false)
    frame.prev.RUIText:SetPoint("CENTER", frame.prev, "CENTER", 0, 0)
    frame.prev.RUIText:SetText("Previous")
    RUI:StyleButton(frame.prev)
    frame.prev:SetScript("OnClick", function()
        if LootFrame_PageUp then LootFrame_PageUp() end
        LootRolls:RefreshLootWindow()
    end)

    frame.next = CreateFrame("Button", nil, frame)
    frame.next:SetWidth(84)
    frame.next:SetHeight(23)
    frame.next:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 9)
    frame.next.RUIText = CreateFont(frame.next, 9, false)
    frame.next.RUIText:SetPoint("CENTER", frame.next, "CENTER", 0, 0)
    frame.next.RUIText:SetText("Next")
    RUI:StyleButton(frame.next)
    frame.next:SetScript("OnClick", function()
        if LootFrame_PageDown then LootFrame_PageDown() end
        LootRolls:RefreshLootWindow()
    end)

    self.lootWindow = frame
end

function LootRolls:RefreshLootWindowAppearance()
    local frame = self.lootWindow
    if not frame then return end
    RUI:RefreshBackdrop(frame)
    RUI:SetAccentTexture(frame.accent)
    frame.accent:SetHeight(RUI:GetPixelSize(frame, 2))
    RefreshFont(frame.title)
    RefreshFont(frame.close.RUIText)
    RefreshFont(frame.prev.RUIText)
    RefreshFont(frame.next.RUIText)
    RUI:RefreshBackdrop(frame.close)
    RUI:RefreshBackdrop(frame.prev)
    RUI:RefreshBackdrop(frame.next)
    for i = 1, #frame.rows do
        local row = frame.rows[i]
        RUI:RefreshBackdrop(row)
        RUI:RefreshBackdrop(row.iconFrame)
        RefreshFont(row.name)
        RefreshFont(row.count)
        if row.quality then
            local qr, qg, qb = SafeQualityColor(row.quality)
            RUI:SetBorderColor(row, qr, qg, qb, 0.82)
            RUI:SetBorderColor(row.iconFrame, qr, qg, qb, 1)
        end
    end
end

function LootRolls:RefreshLootWindow()
    self:CreateLootWindow()
    local frame = self.lootWindow
    local stock = _G.LootFrame
    if not frame or not stock then return end

    if not self:IsZenEnabled() or not stock:IsShown() then
        frame:Hide()
        return
    end

    self:SetNativeLootFrameSuppressed(true)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", stock, "TOPLEFT", 12, -8)
    frame:SetScale(RUI:GetEffectiveScale("zenLootRolls"))

    local numItems = GetNumLootItems and GetNumLootItems() or 0
    local perPage = numItems > 4 and 3 or 4
    local page = tonumber(stock.page) or 1
    local maxPage = 1
    if numItems > 0 then maxPage = math.ceil(numItems / perPage) end
    if page < 1 then page = 1 end
    if page > maxPage then page = maxPage end

    for i = 1, 4 do
        local row = frame.rows[i]
        local slot = ((page - 1) * perPage) + i
        local valid = i <= perPage and slot <= numItems
        if valid and ((LootSlotIsItem and LootSlotIsItem(slot)) or (LootSlotIsCoin and LootSlotIsCoin(slot))) then
            local texture, itemName, quantity, quality, locked = GetLootSlotInfo(slot)
            quality = tonumber(quality) or 0
            row.slot = slot
            row.quality = quality
            row.itemName = itemName or "Loot"
            row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(row.itemName)
            if (tonumber(quantity) or 0) > 1 then
                row.count:SetText(tostring(quantity))
                row.count:Show()
            else
                row.count:SetText("")
                row.count:Hide()
            end
            local qr, qg, qb = SafeQualityColor(quality)
            row.name:SetTextColor(qr, qg, qb)
            RUI:SetBorderColor(row, qr, qg, qb, 0.82)
            RUI:SetBorderColor(row.iconFrame, qr, qg, qb, 1)
            row:SetAlpha(locked and 0.55 or 1)
            row:Show()
        else
            row.slot = nil
            row.quality = nil
            row.itemName = nil
            row:Hide()
        end
    end

    if page > 1 then frame.prev:Show() else frame.prev:Hide() end
    if page < maxPage then frame.next:Show() else frame.next:Hide() end

    self:RefreshLootWindowAppearance()
    frame:Show()
end

function LootRolls:HideLootWindow()
    if self.lootWindow then self.lootWindow:Hide() end
end

function LootRolls:HookNativeLootFrame()
    local stock = _G.LootFrame
    if not stock or stock.RUILootWindowHooked then return end
    stock.RUILootWindowHooked = true

    if stock.HookScript then
        stock:HookScript("OnEvent", function(_, event)
            if event == "LOOT_OPENED" or event == "LOOT_SLOT_CLEARED" or event == "LOOT_SLOT_CHANGED" or event == "OPEN_MASTER_LOOT_LIST" or event == "UPDATE_MASTER_LOOT_LIST" then
                LootRolls:RefreshLootWindow()
            elseif event == "LOOT_CLOSED" then
                LootRolls:HideLootWindow()
            end
        end)
        stock:HookScript("OnHide", function()
            LootRolls:HideLootWindow()
        end)
    end
end

function LootRolls:CreateChoiceButton(parent, label, rollType, tooltipText)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(76)
    button:SetHeight(24)
    button.rollType = rollType
    button.tooltipText = tooltipText or label
    button.RUIText = CreateFont(button, 9, false)
    button.RUIText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.RUIText:SetText(label)
    RUI:StyleButton(button)

    button:SetScript("OnEnter", function(self)
        if self.RUIHighlight then
            local r, g, b = RUI:GetAccentColor()
            self.RUIHighlight:SetTexture(r, g, b, 0.12)
            self.RUIHighlight:Show()
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText or "Loot Roll", 1, 1, 1)
        if self.eligible == false and self.reason then
            GameTooltip:AddLine(self.reason, 1, 0.25, 0.25, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if self.RUIHighlight then self.RUIHighlight:Hide() end
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(self)
        if self.eligible == false then
            if UIErrorsFrame and UIErrorsFrame.AddMessage then
                UIErrorsFrame:AddMessage(self.reason or "That roll is not available.", 1, 0.2, 0.2)
            end
            return
        end
        local card = self:GetParent()
        if not card or not card.rollID or type(RollOnLoot) ~= "function" then return end
        RollOnLoot(card.rollID, self.rollType)
    end)

    return button
end

function LootRolls:SetChoiceState(button, eligible, reason)
    if not button then return end
    button.eligible = eligible and true or false
    button.reason = eligible and nil or reason
    button:SetAlpha(eligible and 1 or 0.36)
    if button.RUIText then
        local r, g, b = RUI:GetTextColor(not eligible)
        RUI:StyleFontString(button.RUIText, 9, r, g, b)
    end
end

function LootRolls:CreateRollFrame(index)
    local card = CreateFrame("Frame", "ZenUILootRollFrame" .. tostring(index), self.anchor or UIParent)
    card:SetWidth(CARD_WIDTH)
    card:SetHeight(CARD_HEIGHT)
    card:SetFrameStrata("HIGH")
    card:SetClampedToScreen(true)
    card:EnableMouse(true)
    card:Hide()
    RUI:CreateBackdrop(card)
    card.accent = RUI:CreateAccentLine(card, 2)

    card.iconButton = CreateFrame("Button", nil, card)
    card.iconButton:SetWidth(50)
    card.iconButton:SetHeight(50)
    card.iconButton:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -13)
    card.iconButton:EnableMouse(true)
    RUI:CreateBackdrop(card.iconButton)

    card.icon = card.iconButton:CreateTexture(nil, "ARTWORK")
    card.icon:SetPoint("TOPLEFT", card.iconButton, "TOPLEFT", 2, -2)
    card.icon:SetPoint("BOTTOMRIGHT", card.iconButton, "BOTTOMRIGHT", -2, 2)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    card.count = CreateFont(card.iconButton, 10, false)
    card.count:SetPoint("BOTTOMRIGHT", card.iconButton, "BOTTOMRIGHT", -4, 4)
    card.count:SetJustifyH("RIGHT")

    card.name = CreateFont(card, 12, false)
    card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 74, -14)
    card.name:SetWidth(188)
    card.name:SetHeight(18)
    card.name:SetJustifyH("LEFT")

    card.info = CreateFont(card, 9, true)
    card.info:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
    card.info:SetWidth(188)
    card.info:SetHeight(14)
    card.info:SetJustifyH("LEFT")

    card.timeText = CreateFont(card, 9, true)
    card.timeText:SetPoint("TOPLEFT", card.info, "BOTTOMLEFT", 0, -4)
    card.timeText:SetWidth(188)
    card.timeText:SetHeight(14)
    card.timeText:SetJustifyH("LEFT")

    card.need = self:CreateChoiceButton(card, "Need", ROLL_NEED, NEED or "Need")
    card.need:SetPoint("TOPLEFT", card, "TOPLEFT", 274, -14)
    card.greed = self:CreateChoiceButton(card, "Greed", ROLL_GREED, GREED or "Greed")
    card.greed:SetPoint("LEFT", card.need, "RIGHT", 6, 0)
    card.disenchant = self:CreateChoiceButton(card, "Disenchant", ROLL_DISENCHANT, _G.ROLL_DISENCHANT or "Disenchant")
    card.disenchant:SetWidth(100)
    card.disenchant:SetPoint("TOPLEFT", card.need, "BOTTOMLEFT", 0, -6)
    card.pass = self:CreateChoiceButton(card, "Pass", ROLL_PASS, PASS or "Pass")
    card.pass:SetWidth(52)
    card.pass:SetPoint("LEFT", card.disenchant, "RIGHT", 6, 0)

    card.timer = CreateFrame("StatusBar", nil, card)
    card.timer:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 12, 8)
    card.timer:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 8)
    card.timer:SetHeight(5)
    card.timer:SetStatusBarTexture(RUI:GetStatusBarTexture())
    card.timer:SetMinMaxValues(0, 1)
    card.timer:SetValue(1)
    card.timer.background = card.timer:CreateTexture(nil, "BACKGROUND")
    card.timer.background:SetAllPoints(card.timer)
    card.timer.background:SetTexture(0, 0, 0, 0.45)

    local function ShowItemTooltip(self)
        local rollID = self:GetParent() and self:GetParent().rollID
        if not rollID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetLootRollItem then GameTooltip:SetLootRollItem(rollID) end
        GameTooltip:Show()
    end
    local function HideItemTooltip() GameTooltip:Hide() end
    local function HandleItemClick(self, button)
        local rollID = self:GetParent() and self:GetParent().rollID
        if not rollID then return end
        local link = GetLootRollItemLink and GetLootRollItemLink(rollID)
        if link and RUI.HandleModifiedLinkClick then RUI:HandleModifiedLinkClick(link, button) end
    end

    card.iconButton:SetScript("OnEnter", ShowItemTooltip)
    card.iconButton:SetScript("OnLeave", HideItemTooltip)
    card.iconButton:SetScript("OnClick", HandleItemClick)

    card.nameButton = CreateFrame("Button", nil, card)
    card.nameButton:SetPoint("TOPLEFT", card.name, "TOPLEFT", -2, 2)
    card.nameButton:SetPoint("BOTTOMRIGHT", card.timeText, "BOTTOMRIGHT", 2, -2)
    card.nameButton:SetFrameLevel(card:GetFrameLevel() + 2)
    card.nameButton:EnableMouse(true)
    card.nameButton:SetScript("OnEnter", function(self)
        local rollID = self:GetParent() and self:GetParent().rollID
        if not rollID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetLootRollItem then GameTooltip:SetLootRollItem(rollID) end
        GameTooltip:Show()
    end)
    card.nameButton:SetScript("OnLeave", HideItemTooltip)
    card.nameButton:SetScript("OnClick", function(self, button)
        local rollID = self:GetParent() and self:GetParent().rollID
        if not rollID then return end
        local link = GetLootRollItemLink and GetLootRollItemLink(rollID)
        if link and RUI.HandleModifiedLinkClick then RUI:HandleModifiedLinkClick(link, button) end
    end)

    self.frames[index] = card
    return card
end

function LootRolls:RefreshCardAppearance(card)
    if not card then return end
    RUI:RefreshBackdrop(card)
    RUI:RefreshBackdrop(card.iconButton)
    RUI:SetAccentTexture(card.accent)
    card.accent:SetHeight(RUI:GetPixelSize(card, 2))

    RefreshFont(card.name)
    RefreshFont(card.info)
    RefreshFont(card.timeText)
    RefreshFont(card.count)
    RefreshFont(card.need.RUIText)
    RefreshFont(card.greed.RUIText)
    RefreshFont(card.disenchant.RUIText)
    RefreshFont(card.pass.RUIText)
    RUI:RefreshBackdrop(card.need)
    RUI:RefreshBackdrop(card.greed)
    RUI:RefreshBackdrop(card.disenchant)
    RUI:RefreshBackdrop(card.pass)

    local ar, ag, ab = RUI:GetAccentColor()
    card.timer:SetStatusBarTexture(RUI:GetStatusBarTexture())
    card.timer:SetStatusBarColor(ar, ag, ab, 0.95)

    if card.quality then
        local qr, qg, qb = SafeQualityColor(card.quality)
        RUI:SetBorderColor(card, qr, qg, qb, 0.88)
        RUI:SetBorderColor(card.iconButton, qr, qg, qb, 1)
        card.name:SetTextColor(qr, qg, qb)
    end

    if card.need.eligible ~= nil then self:SetChoiceState(card.need, card.need.eligible, card.need.reason) end
    if card.greed.eligible ~= nil then self:SetChoiceState(card.greed, card.greed.eligible, card.greed.reason) end
    if card.disenchant.eligible ~= nil then self:SetChoiceState(card.disenchant, card.disenchant.eligible, card.disenchant.reason) end
    if card.pass.eligible ~= nil then self:SetChoiceState(card.pass, card.pass.eligible, card.pass.reason) end
end

function LootRolls:PopulateRollFrame(card, rollID, rollTime)
    if not card then return false end
    local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant,
        reasonNeed, reasonGreed, reasonDisenchant, deSkillRequired = GetLootRollItemInfo(rollID)

    if not name then return false end

    local preserveAutoAttempt = card.rollID == rollID and card.autoRollAttempted == true
    card.rollID = rollID
    card.rollTime = tonumber(rollTime) or 0
    card.quality = tonumber(quality) or 1
    card.bindOnPickUp = bindOnPickUp and true or false
    card.itemName = name
    -- Preserve nil vs false where private-server APIs distinguish "unknown"
    -- from explicitly ineligible.  The BoP safety rule only fires on false.
    card.canNeed = canNeed
    card.canGreed = canGreed
    card.canDisenchant = canDisenchant
    card.autoRollAttempted = preserveAutoAttempt
    if not preserveAutoAttempt then
        card.autoRollType = nil
        card.autoRollLabel = nil
    end
    card.lastTimerText = nil

    card.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    card.name:SetText(name)
    if (tonumber(count) or 0) > 1 then
        card.count:SetText(tostring(count))
        card.count:Show()
    else
        card.count:SetText("")
        card.count:Hide()
    end

    if bindOnPickUp then
        card.info:SetText("Binds when picked up")
    else
        card.info:SetText("Group loot")
    end

    card.timer:SetMinMaxValues(0, math.max(1, card.rollTime))
    card.timer:SetValue(math.max(0, card.rollTime))

    self:SetChoiceState(card.need, canNeed, GetIneligibleReason(reasonNeed))
    self:SetChoiceState(card.greed, canGreed, GetIneligibleReason(reasonGreed))
    self:SetChoiceState(card.disenchant, canDisenchant, GetIneligibleReason(reasonDisenchant, deSkillRequired))
    self:SetChoiceState(card.pass, true, nil)

    self:RefreshCardAppearance(card)
    card:Show()
    return true
end

function LootRolls:AcquireRollFrame()
    for i = 1, MAX_ROLL_FRAMES do
        local card = self.frames[i]
        if card and not card.rollID then return card end
    end
    return nil
end

function LootRolls:LayoutRollFrames()
    if not self.anchor then return end
    local previous
    for i = 1, #self.order do
        local rollID = self.order[i]
        local card = self.active[rollID]
        if card and card:IsShown() then
            card:ClearAllPoints()
            if not previous then
                card:SetPoint("BOTTOM", self.anchor, "BOTTOM", 0, 0)
            else
                card:SetPoint("BOTTOM", previous, "TOP", 0, CARD_GAP)
            end
            previous = card
        end
    end
end

function LootRolls:RemoveRoll(rollID)
    local card = self.active[rollID]
    if card then
        card:Hide()
        card.rollID = nil
        card.rollTime = nil
        card.quality = nil
        card.bindOnPickUp = nil
        card.itemName = nil
        card.canNeed = nil
        card.canGreed = nil
        card.canDisenchant = nil
        card.autoRollAttempted = nil
        card.autoRollType = nil
        card.autoRollLabel = nil
        card.lastTimerText = nil
        self.active[rollID] = nil
    end
    if self.pendingAutoConfirm then self.pendingAutoConfirm[rollID] = nil end
    for i = #self.order, 1, -1 do
        if self.order[i] == rollID then table.remove(self.order, i) end
    end
    if StaticPopup_Hide then StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID) end
    self:LayoutRollFrames()
    self:UpdateTickerState()
end

function LootRolls:ClearRolls()
    for rollID in pairs(self.active) do
        local card = self.active[rollID]
        if card then
            card:Hide()
            card.rollID = nil
            card.rollTime = nil
            card.quality = nil
            card.bindOnPickUp = nil
            card.itemName = nil
            card.canNeed = nil
            card.canGreed = nil
            card.canDisenchant = nil
            card.autoRollAttempted = nil
            card.autoRollType = nil
            card.autoRollLabel = nil
            card.lastTimerText = nil
        end
        self.active[rollID] = nil
    end
    for i = #self.order, 1, -1 do self.order[i] = nil end
    if self.pendingAutoConfirm then
        for rollID in pairs(self.pendingAutoConfirm) do self.pendingAutoConfirm[rollID] = nil end
    end
    self:UpdateTickerState()
end

function LootRolls:UpdateTickerState()
    if not self.anchor then return end
    if #self.order > 0 then
        if not self.tickerActive then
            self.tickerActive = true
            self.timerElapsed = 0
            self.anchor:SetScript("OnUpdate", function(_, elapsed) LootRolls:OnTicker(elapsed) end)
        end
    elseif self.tickerActive then
        self.tickerActive = false
        self.anchor:SetScript("OnUpdate", nil)
    end
end

function LootRolls:OnTicker(elapsed)
    self.timerElapsed = (self.timerElapsed or 0) + (elapsed or 0)
    if self.timerElapsed < 0.10 then return end
    self.timerElapsed = 0

    local expired = nil
    for i = 1, #self.order do
        local rollID = self.order[i]
        local card = self.active[rollID]
        if card then
            local left = GetLootRollTimeLeft and GetLootRollTimeLeft(rollID)
            left = tonumber(left) or 0
            if left <= 0 then
                expired = expired or {}
                table.insert(expired, rollID)
            else
                local _, maxValue = card.timer:GetMinMaxValues()
                if left > maxValue then left = maxValue end
                card.timer:SetValue(left)
                local seconds = left / 1000
                local timerText
                if seconds >= 10 then
                    timerText = tostring(math.ceil(seconds)) .. "s remaining"
                else
                    timerText = string.format("%.1fs remaining", seconds)
                end
                if timerText ~= card.lastTimerText then
                    card.lastTimerText = timerText
                    card.timeText:SetText(timerText)
                end
            end
        end
    end

    if expired then
        for i = 1, #expired do self:RemoveRoll(expired[i]) end
    end
end

function LootRolls:PopupMatchesAutoRoll(popup, rollID, itemName)
    if not popup or popup.which ~= "CONFIRM_LOOT_ROLL" then return false end

    -- Once UIParent has finished handling the confirmation event it stores the
    -- roll ID on the popup. Prefer that exact match whenever it is available.
    if popup.data ~= nil and tonumber(popup.data) == tonumber(rollID) then
        return true
    end

    -- StaticPopup_OnShow can run before UIParent assigns popup.data, so retain
    -- the item-name fallback for that earlier stage of popup construction.
    if not popup.GetName or not itemName or itemName == "" then return false end
    local name = popup:GetName()
    local textRegion = name and _G[name .. "Text"]
    local popupText = textRegion and textRegion.GetText and textRegion:GetText() or nil
    return popupText and string.find(popupText, itemName, 1, true) and true or false
end

function LootRolls:DismissAutoConfirmPopup(rollID, itemName)
    local matched = false
    local count = tonumber(STATICPOPUP_NUMDIALOGS) or 4
    for i = 1, count do
        local popup = _G["StaticPopup" .. tostring(i)]
        if popup and popup.IsShown and popup:IsShown() and self:PopupMatchesAutoRoll(popup, rollID, itemName) then
            popup:Hide()
            matched = true
        end
    end
    return matched
end

function LootRolls:QueueAutoConfirmPopupCleanup(rollID, rollType, itemName)
    rollID = tonumber(rollID)
    if not rollID then return end

    self.recentAutoConfirm = self.recentAutoConfirm or {}
    self.recentAutoConfirm[rollID] = {
        rollType = tonumber(rollType),
        itemName = itemName,
        remaining = 0.50,
    }

    if not self.autoConfirmCleanupFrame then
        self.autoConfirmCleanupFrame = CreateFrame("Frame", nil, UIParent)
    end
    if self.autoConfirmCleanupActive then return end

    self.autoConfirmCleanupActive = true
    self.autoConfirmCleanupFrame:SetScript("OnUpdate", function(_, elapsed)
        local active = false
        local dt = tonumber(elapsed) or 0
        for id, recent in pairs(LootRolls.recentAutoConfirm or {}) do
            recent.remaining = (tonumber(recent.remaining) or 0) - dt

            -- UIParent may create the confirmation dialog after Zen's
            -- event frame has already confirmed the roll. Re-check for a very
            -- short window and dismiss only the popup belonging to this exact
            -- automatic roll.
            LootRolls:DismissAutoConfirmPopup(id, recent.itemName)

            if recent.remaining > 0 then
                active = true
            else
                LootRolls.recentAutoConfirm[id] = nil
            end
        end

        if not active then
            LootRolls.autoConfirmCleanupActive = false
            LootRolls.autoConfirmCleanupFrame:SetScript("OnUpdate", nil)
        end
    end)
end

function LootRolls:OnAutoRollConfirmation(event, rollID, rollType)
    rollID = tonumber(rollID)
    if not rollID or not self.pendingAutoConfirm then return end

    local pending = self.pendingAutoConfirm[rollID]
    if not pending then return end

    local expected = tonumber(pending.rollType)
    local confirmedType = tonumber(rollType)
    if event == "CONFIRM_DISENCHANT_ROLL" then
        confirmedType = ROLL_DISENCHANT
    elseif confirmedType == nil then
        confirmedType = expected
    end

    -- Never confirm a different action than the one Zen selected.
    if expected ~= nil and confirmedType ~= expected then return end
    if type(ConfirmLootRoll) ~= "function" then return end

    ConfirmLootRoll(rollID, confirmedType)
    self:QueueAutoConfirmPopupCleanup(rollID, confirmedType, pending.itemName)
end

function LootRolls:HideAutoConfirmPopup(popup)
    if not popup or popup.which ~= "CONFIRM_LOOT_ROLL" then return end

    -- First match rolls that are still awaiting confirmation.
    for rollID, pending in pairs(self.pendingAutoConfirm or {}) do
        if self:PopupMatchesAutoRoll(popup, rollID, pending and pending.itemName) then
            popup:Hide()
            return
        end
    end

    -- ConfirmLootRoll can synchronously end the roll before UIParent finishes
    -- creating its confirmation dialog. Keep a tiny recent-roll window so the
    -- late popup is still recognised and removed rather than becoming an
    -- orphaned Okay/Cancel dialog.
    for rollID, recent in pairs(self.recentAutoConfirm or {}) do
        if self:PopupMatchesAutoRoll(popup, rollID, recent and recent.itemName) then
            popup:Hide()
            return
        end
    end
end

function LootRolls:InstallAutoConfirmPopupHook()
    if self.autoConfirmPopupHooked or not hooksecurefunc or type(StaticPopup_OnShow) ~= "function" then return end
    self.autoConfirmPopupHooked = true
    hooksecurefunc("StaticPopup_OnShow", function(popup)
        LootRolls:HideAutoConfirmPopup(popup)
    end)
end

function LootRolls:OnStartLootRoll(event, rollID, rollTime)
    if not self:IsZenEnabled() then return end
    rollID = tonumber(rollID)
    if not rollID then return end

    if self.active[rollID] then
        local existing = self.active[rollID]
        self:PopulateRollFrame(existing, rollID, rollTime)
        self:TryAutoRoll(existing)
        self:UpdateTickerState()
        return
    end

    local card = self:AcquireRollFrame()
    if not card then
        RUI:Print("Loot Rolls: all four roll slots are already in use; leaving this roll to chat/server state.")
        return
    end

    if not self:PopulateRollFrame(card, rollID, rollTime) then return end
    self.active[rollID] = card
    table.insert(self.order, rollID)
    self:LayoutRollFrames()
    self:TryAutoRoll(card)
    self:UpdateTickerState()
end

function LootRolls:OnCancelLootRoll(event, rollID)
    rollID = tonumber(rollID)
    if rollID then self:RemoveRoll(rollID) end
end

function LootRolls:EnsureAutoLootToggleModifier()
    -- Stock Wrath uses AUTOLOOTTOGGLE to invert the auto-loot default while
    -- interacting with loot. ZenUI intentionally restores the stock Shift
    -- modifier so: Auto Loot ON + hold Shift = open the loot window manually.
    if type(GetModifiedClick) ~= "function" or type(SetModifiedClick) ~= "function" then return end

    local ok, current = pcall(GetModifiedClick, "AUTOLOOTTOGGLE")
    if ok and current == "SHIFT" then return end

    local setOK = pcall(SetModifiedClick, "AUTOLOOTTOGGLE", "SHIFT")
    if setOK and type(SaveBindings) == "function" and type(GetCurrentBindingSet) == "function" then
        pcall(SaveBindings, GetCurrentBindingSet())
    end
end

function LootRolls:OnPlayerEnteringWorld()
    self:EnsureAutoLootToggleModifier()
    self:ClearRolls()
    self:HideStockRollFrames()
end

function LootRolls:HideStockRollFrames()
    for i = 1, MAX_ROLL_FRAMES do
        local frame = _G["GroupLootFrame" .. tostring(i)]
        if frame and frame:IsShown() then frame:Hide() end
    end
end

function LootRolls:SetStockEventEnabled(enabled)
    if not UIParent then return end
    if enabled then
        if self.stockStartEventWasRegistered ~= false then UIParent:RegisterEvent("START_LOOT_ROLL") end
    else
        UIParent:UnregisterEvent("START_LOOT_ROLL")
    end
end

function LootRolls:ApplySettings()
    if not self.anchor then return end
    local enabled = self:IsZenEnabled()
    self.anchor:SetScale(RUI:GetEffectiveScale("zenLootRolls"))
    RUI:SetMoverEnabled("ZenLootRolls", enabled)
    self:SetStockEventEnabled(not enabled)
    self:SetNativeLootFrameSuppressed(enabled)
    if enabled then
        self:HideStockRollFrames()
        self:RefreshLootWindow()
    else
        self:ClearRolls()
        self:HideLootWindow()
    end
end

function LootRolls:OnAppearanceChanged()
    if self.anchor then self.anchor:SetScale(RUI:GetEffectiveScale("zenLootRolls")) end
    if self.lootWindow then self.lootWindow:SetScale(RUI:GetEffectiveScale("zenLootRolls")) end
    for i = 1, #self.frames do self:RefreshCardAppearance(self.frames[i]) end
    self:RefreshLootWindowAppearance()
end

function LootRolls:OnScaleChanged(key)
    if key == "all" or key == "zenLootRolls" then self:ApplySettings() end
end

function LootRolls:OnProfileReset()
    self:ApplySettings()
    self:OnAppearanceChanged()
end

function LootRolls:OnInitialize()
    self.frames = {}
    self.active = {}
    self.order = {}
    self.pendingAutoConfirm = {}
    self.recentAutoConfirm = {}
    self:InstallAutoConfirmPopupHook()
    if ChatFrame_AddMessageEventFilter and not self.rollChatFilterInstalled then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", LootRollChatFilter)
        self.rollChatFilterInstalled = true
    end

    if UIParent and UIParent.IsEventRegistered then
        local ok, registered = pcall(UIParent.IsEventRegistered, UIParent, "START_LOOT_ROLL")
        if ok then self.stockStartEventWasRegistered = registered and true or false end
    end
    if self.stockStartEventWasRegistered == nil then self.stockStartEventWasRegistered = true end

    self.anchor = CreateFrame("Frame", "ZenUILootRollAnchor", UIParent)
    self.anchor:SetWidth(CARD_WIDTH)
    self.anchor:SetHeight(CARD_HEIGHT)
    self.anchor:SetFrameStrata("HIGH")
    self.anchor:SetClampedToScreen(true)

    self:CreateLootWindow()
    self:HookNativeLootFrame()

    for i = 1, MAX_ROLL_FRAMES do self:CreateRollFrame(i) end

    RUI:RegisterMover("ZenLootRolls", self.anchor, {
        label = "Loot Rolls",
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -120,
        groups = { loot = true },
    })

    for i = 1, MAX_ROLL_FRAMES do
        local stock = _G["GroupLootFrame" .. tostring(i)]
        if stock and stock.HookScript and not stock.RUILootRollGuard then
            stock.RUILootRollGuard = true
            stock:HookScript("OnShow", function(frame)
                if LootRolls:IsZenEnabled() then frame:Hide() end
            end)
        end
    end

    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "OnAppearanceChanged")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED", self, "OnScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET", self, "OnProfileReset")
end

function LootRolls:OnEnable()
    self:EnsureAutoLootToggleModifier()
    self:RegisterEvent("START_LOOT_ROLL", "OnStartLootRoll")
    self:RegisterEvent("CANCEL_LOOT_ROLL", "OnCancelLootRoll")
    self:RegisterEvent("CONFIRM_LOOT_ROLL", "OnAutoRollConfirmation")
    self:RegisterEvent("CONFIRM_DISENCHANT_ROLL", "OnAutoRollConfirmation")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:ApplySettings()
    self:OnAppearanceChanged()
end
