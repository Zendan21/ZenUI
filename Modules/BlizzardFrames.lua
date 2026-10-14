-- ZenUI 0.9.82 Zen replacement panels - hidden live Ebonhold Clear IDs bootstrap.
--
-- Major Blizzard windows are no longer skinned in-place.  Phase A owns four
-- standalone Zen panels (Spellbook, Social/Friends, Guild, Raid and
-- Dungeon Finder) and uses the Wrath 3.3.5 APIs underneath.  The stock windows remain
-- available as a fallback whenever an individual replacement is disabled.

local RUI = ZenUI
local Panels = RUI:NewModule("BlizzardFrames")

local PANEL_INFO = {
    spellbook = { scale = "zenSpellbook", mover = "ZenSpellbook", label = "Spellbook", width = 650, height = 520, x = -300, y = 10 },
    social = { scale = "zenSocial", mover = "ZenSocial", label = "Social / Guild / Raid", width = 470, height = 440, x = -215, y = 5 },
    guild = { scale = "zenGuild", mover = "ZenSocial", label = "Social / Guild / Raid", width = 690, height = 520, x = -215, y = 5 },
    raid = { scale = "zenSocial", mover = "ZenSocial", label = "Social / Guild / Raid", width = 690, height = 520, x = -215, y = 5 },
    dungeon = { scale = "zenDungeonFinder", mover = "ZenDungeonFinder", label = "Dungeon Finder", width = 620, height = 520, x = -240, y = 0 },
}

local function GetSettings()
    if not RUI.db then return nil end
    RUI.db.blizzard = RUI.db.blizzard or {}
    return RUI.db.blizzard
end

local function IsEnabled(key)
    local settings = GetSettings()
    if not settings or settings.enabled == false then return false end
    if settings[key] == nil then return true end
    return settings[key] and true or false
end

local function SafeCall(label, fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if not ok then
        RUI:Debug("Zen panel " .. tostring(label) .. " failed: " .. tostring(a))
        return false
    end
    return true, a, b, c, d, e, f, g, h, i, j
end

-- Spell pickup is special on Wrath/Ebonhold.  Zen's spell rows are secure
-- action buttons so normal click-to-cast remains usable in combat, but calling
-- PickupSpell through an ordinary addon pcall from that protected frame can be
-- rejected by some Ebonhold builds during combat.  Prefer Blizzard's securecall
-- trampoline when available, then fall back to the direct API for clients that
-- do not expose it.  This changes only cursor pickup; action-bar placement stays
-- owned by the native ActionBarButtonTemplate OnReceiveDrag path.
local function PickupBookSpell(slot, bookType)
    if not slot or type(PickupSpell) ~= "function" then return false end
    if type(securecall) == "function" then
        local ok = pcall(securecall, "PickupSpell", slot, bookType)
        if ok then return true end
    end
    return SafeCall("pickup spell", PickupSpell, slot, bookType)
end

local function AddSpecialFrame(frame)
    if not frame or not frame.GetName or not frame:GetName() then return end
    UISpecialFrames = UISpecialFrames or {}
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == frame:GetName() then return end
    end
    table.insert(UISpecialFrames, frame:GetName())
end

local function CreateText(parent, text, size, point, relativeTo, relativePoint, x, y, muted)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint(point or "TOPLEFT", relativeTo or parent, relativePoint or point or "TOPLEFT", x or 0, y or 0)
    local r, g, b = RUI:GetTextColor(muted and true or false)
    RUI:StyleFontString(fs, size or 10, r, g, b)
    fs:SetText(text or "")
    return fs
end

local function StyleOwnText(fs, size, muted)
    if not fs then return end
    local r, g, b = RUI:GetTextColor(muted and true or false)
    RUI:StyleFontString(fs, size or 10, r, g, b)
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width or 100)
    button:SetHeight(height or 24)
    button.RUIText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.RUIText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.RUIText:SetText(text or "Button")
    RUI:StyleButton(button)
    return button
end

local function SetButtonEnabled(button, enabled)
    if not button then return end
    if enabled then
        button:Enable()
        if button.RUIText then
            local r, g, b = RUI:GetTextColor(false)
            button.RUIText:SetTextColor(r, g, b)
        end
    else
        button:Disable()
        if button.RUIText then
            local r, g, b = RUI:GetTextColor(true)
            button.RUIText:SetTextColor(r, g, b)
        end
    end
end

local function CreateEditBox(parent, width, height, placeholder)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetWidth(width or 180)
    box:SetHeight(height or 24)
    box:SetAutoFocus(false)
    box:SetFont(RUI:GetFontPath(), 10)
    box:SetTextInsets(8, 8, 0, 0)
    -- Keep edit boxes above later-created list/content siblings. Several Phase A
    -- panels deliberately overlap the top edge of their content area, and a
    -- normal sibling frame level lets the content swallow the edit box.
    box:SetFrameLevel((tonumber(parent:GetFrameLevel()) or 1) + 20)
    RUI:CreateBackdrop(box)
    box.placeholder = CreateText(box, placeholder or "", 9, "LEFT", box, "LEFT", 8, 0, true)
    box:SetScript("OnEditFocusGained", function(self) self.placeholder:Hide() end)
    box:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then self.placeholder:Show() end end)
    box:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" and not self:HasFocus() then self.placeholder:Show() else self.placeholder:Hide() end
        if self.RUIOnTextChanged then self:RUIOnTextChanged() end
    end)
    return box
end

local function CreateCheck(parent, label, x, y, callback)
    local check = CreateFrame("CheckButton", nil, parent)
    check:SetWidth(150)
    check:SetHeight(22)
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    check.box = CreateFrame("Frame", nil, check)
    check.box:SetWidth(14)
    check.box:SetHeight(14)
    check.box:SetPoint("LEFT", check, "LEFT", 0, 0)
    RUI:CreateBackdrop(check.box)
    check.mark = check.box:CreateTexture(nil, "OVERLAY")
    check.mark:SetPoint("TOPLEFT", check.box, "TOPLEFT", 3, -3)
    check.mark:SetPoint("BOTTOMRIGHT", check.box, "BOTTOMRIGHT", -3, 3)
    RUI:SetAccentTexture(check.mark)
    check.mark:Hide()
    check.label = CreateText(check, label, 10, "LEFT", check.box, "RIGHT", 8, 0, false)
    check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        if on then self.mark:Show() else self.mark:Hide() end
        if callback then callback(on) end
    end)
    function check:SetRUIValue(value)
        self:SetChecked(value and true or false)
        if value then self.mark:Show() else self.mark:Hide() end
    end
    return check
end

local function CreatePanel(name, key, title)
    local info = PANEL_INFO[key]
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetWidth(info.width)
    frame:SetHeight(info.height)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    frame.RUIPanelKey = key
    RUI:CreateBackdrop(frame)
    frame.accent = RUI:CreateAccentLine(frame, 2)

    frame.title = CreateText(frame, title, 15, "TOPLEFT", frame, "TOPLEFT", 16, -17, false)
    frame.subtitle = CreateText(frame, "Zen replacement panel", 8, "LEFT", frame.title, "RIGHT", 10, -1, true)
    frame.close = CreateButton(frame, "X", 28, 24)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -48)
    frame.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)

    AddSpecialFrame(frame)
    if RUI.RegisterExclusivePanel then RUI:RegisterExclusivePanel(frame) end
    return frame
end

local function CreateListRow(parent, width, height)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(width)
    row:SetHeight(height)
    RUI:CreateBackdrop(row)
    if row.RUIBackground then row.RUIBackground:SetAlpha(0.35) end
    row.highlight = row:CreateTexture(nil, "ARTWORK")
    row.highlight:SetAllPoints(row)
    row.highlight:Hide()
    row:SetScript("OnEnter", function(self)
        local r, g, b = RUI:GetAccentColor()
        self.highlight:SetTexture(r, g, b, 0.10)
        self.highlight:Show()
        if self.RUIOnEnter then self:RUIOnEnter() end
    end)
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        if self.RUIOnLeave then self:RUIOnLeave() end
    end)
    return row
end

local function SetSelectedRow(row, selected)
    if not row or not row.RUIBorder then return end
    -- Row refreshes should not erase per-row presence shading. Preserve the
    -- current background alpha while restoring the normal border colour.
    local backgroundAlpha = row.RUIBackground and row.RUIBackground:GetAlpha()
    if selected then
        local r, g, b = RUI:GetAccentColor()
        RUI:SetBorderColor(row, r, g, b, 1)
    else
        RUI:RefreshBackdrop(row)
        if backgroundAlpha and row.RUIBackground then row.RUIBackground:SetAlpha(backgroundAlpha) end
    end
end

local function ClampOffset(offset, total, visible)
    local maxOffset = math.max(0, (total or 0) - (visible or 0))
    if offset < 0 then offset = 0 end
    if offset > maxOffset then offset = maxOffset end
    return offset
end

-- Paged panels need page-aligned offsets rather than list-style offsets.
-- Example: 26 spells at 12 per page must allow offsets 0, 12 and 24; using
-- ClampOffset would incorrectly clamp the last page to 14.
local function ClampPageOffset(offset, total, pageSize)
    total = tonumber(total) or 0
    pageSize = math.max(1, tonumber(pageSize) or 1)
    local maxOffset = total > 0 and (math.floor((total - 1) / pageSize) * pageSize) or 0
    offset = math.floor((tonumber(offset) or 0) / pageSize) * pageSize
    if offset < 0 then offset = 0 end
    if offset > maxOffset then offset = maxOffset end
    return offset
end

-- Wrath 3.3.5 uses the original LFG return layout. Prefer Blizzard's own
-- cached info table because private-server clients commonly retain that exact
-- FrameXML contract even when some C API return lists differ slightly.
local function GetDungeonInfoCompat(id)
    if not id then return nil end

    if LFGGetDungeonInfoByID then
        local ok, info = SafeCall("cached dungeon info", LFGGetDungeonInfoByID, id)
        if ok and type(info) == "table" then
            local rv = LFG_RETURN_VALUES or {}
            return {
                id = id,
                name = info[rv.name or 1],
                typeID = info[rv.typeID or 2],
                minLevel = info[rv.minLevel or 3],
                maxLevel = info[rv.maxLevel or 4],
                recLevel = info[rv.recLevel or 5],
                minRecLevel = info[rv.minRecLevel or 6],
                maxRecLevel = info[rv.maxRecLevel or 7],
                expansionLevel = info[rv.expansionLevel or 8],
                groupID = info[rv.groupID or 9],
                texture = info[rv.texture or 10],
                difficulty = info[rv.difficulty or 11],
                maxPlayers = info[rv.maxPlayers or 12],
                description = info[13],
                isHoliday = info[14],
            }
        end
    end

    if GetLFGDungeonInfo then
        local ok, name, typeID, minLevel, maxLevel, recLevel, minRecLevel, maxRecLevel, expansionLevel, groupID, texture, difficulty, maxPlayers, description, isHoliday = SafeCall("dungeon info", GetLFGDungeonInfo, id)
        if ok and name then
            return {
                id=id, name=name, typeID=typeID, minLevel=minLevel, maxLevel=maxLevel,
                recLevel=recLevel, minRecLevel=minRecLevel, maxRecLevel=maxRecLevel,
                expansionLevel=expansionLevel, groupID=groupID, texture=texture,
                difficulty=difficulty, maxPlayers=maxPlayers, description=description,
                isHoliday=isHoliday,
            }
        end
    end
    return nil
end

local function FormatRewardMoney(copper)
    copper = tonumber(copper) or 0
    if copper <= 0 then return "" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local coin = copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = tostring(gold) .. "g" end
    if silver > 0 or gold > 0 then parts[#parts + 1] = tostring(silver) .. "s" end
    parts[#parts + 1] = tostring(coin) .. "c"
    return table.concat(parts, " ")
end

local function Truthy(value)
    if value == true then return true end
    local n = tonumber(value)
    if n then return n ~= 0 end
    local text = string.lower(tostring(value or ""))
    return text == "true" or text == "yes" or text == "on"
end

local function HideStock(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then return end
    if HideUIPanel then
        SafeCall("hide stock", HideUIPanel, frame)
    elseif frame.Hide then
        frame:Hide()
    end
end

function Panels:HideOtherPanels(except)
    if InCombatLockdown and InCombatLockdown() then return end
    if RUI.ActivateExclusivePanel then RUI:ActivateExclusivePanel(except) end
    for key, frame in pairs(self.frames or {}) do
        if frame ~= except and frame:IsShown() then frame:Hide() end
    end
end

-- Social/Friends and Guild are two views of the same Zen system.  They
-- deliberately share one mover so /zenui move exposes the user-facing concept
-- rather than the two implementation frames behind it.
function Panels:UpdateSocialMoverSize()
    local mover = RUI:GetMover("ZenSocial")
    if not mover then return end

    local social = PANEL_INFO.social
    local guild = PANEL_INFO.guild
    local raid = PANEL_INFO.raid
    local socialScale = RUI:GetEffectiveScale(social.scale)
    local guildScale = RUI:GetEffectiveScale(guild.scale)
    local raidScale = RUI:GetEffectiveScale(raid.scale)
    local width = math.max(social.width * socialScale, guild.width * guildScale, raid.width * raidScale)
    local height = math.max(social.height * socialScale, guild.height * guildScale, raid.height * raidScale)
    RUI:UpdateMoverSize("ZenSocial", width, height)
end

function Panels:ApplyPanelScale(key)
    local frame = self.frames and self.frames[key]
    local info = PANEL_INFO[key]
    if not frame or not info then return end
    local scale = RUI:GetEffectiveScale(info.scale)
    frame:SetScale(scale)
    if key == "social" or key == "guild" or key == "raid" then
        self:UpdateSocialMoverSize()
    else
        RUI:UpdateMoverSize(info.mover, info.width * scale, info.height * scale)
    end
end

function Panels:RegisterPanelMover(key, frame)
    local info = PANEL_INFO[key]
    if not info or not frame then return end

    -- Friends/Ignore, Guild and Raid are different-sized views of one Social
    -- system. They share one mover and one selectable lock corner (TL/TR/BL/BR).
    if key == "guild" or key == "raid" then
        RUI:AddMoverLinkedTarget("ZenSocial", frame)
        if RUI.EnableDirectPanelDrag then RUI:EnableDirectPanelDrag(frame, "ZenSocial") end
        self:ApplyPanelScale(key)
        return
    end

    RUI:RegisterMover(info.mover, frame, {
        label = info.label,
        width = info.width,
        height = info.height,
        point = "CENTER",
        relativePoint = "CENTER",
        x = info.x,
        y = info.y,
        targetPoint = "TOPLEFT",
        moverPoint = "TOPLEFT",
        enabled = IsEnabled(key == "dungeon" and "dungeonFinder" or key),
    })
    if RUI.EnableDirectPanelDrag then RUI:EnableDirectPanelDrag(frame, info.mover) end
    self:ApplyPanelScale(key)
end

-- -------------------------------------------------------------------------
-- Spellbook
-- -------------------------------------------------------------------------
local function SpellbookSpellID(slot, bookType)
    if not slot then return nil end
    if GetSpellBookItemInfo then
        local ok, spellType, spellID = pcall(GetSpellBookItemInfo, slot, bookType)
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

function Panels:CreateSpellbook()
    local frame = CreatePanel("ZenUISpellbookFrame", "spellbook", "Spellbook")
    self.frames.spellbook = frame
    -- Secure spell rows make this hierarchy protected once combat starts.
    -- The exclusive-panel coordinator must never try to Hide() it from an
    -- insecure OnShow callback during lockdown.
    frame.RUIExclusiveCombatProtected = true
    frame.RUIExclusiveCombatSafeClose = false
    frame.bookType = BOOKTYPE_SPELL or "spell"
    frame.selectedTab = 1
    frame.spellOffset = 0
    frame.filteredSlots = {}

    frame.search = CreateEditBox(frame.body, 250, 24, "Search spells...")
    frame.search:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -2, -2)
    frame.search.RUIOnTextChanged = function() Panels:RefreshSpellbook() end
    frame.search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:SetText("") end)

    frame.skillPane = CreateFrame("Frame", nil, frame.body)
    frame.skillPane:SetWidth(150)
    frame.skillPane:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -2)
    frame.skillPane:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 2)
    RUI:CreateBackdrop(frame.skillPane)
    frame.skillTitle = CreateText(frame.skillPane, "SPELL LINES", 9, "TOPLEFT", frame.skillPane, "TOPLEFT", 10, -12, true)
    frame.skillButtons = {}
    for i = 1, 10 do
        local button = CreateButton(frame.skillPane, "", 130, 30)
        button:SetPoint("TOPLEFT", frame.skillPane, "TOPLEFT", 10, -34 - ((i - 1) * 34))
        button.RUIText:ClearAllPoints()
        button.RUIText:SetPoint("LEFT", button, "LEFT", 10, 0)
        button.RUIText:SetJustifyH("LEFT")
        button:SetScript("OnClick", function(self)
            if self.tabIndex then
                frame.selectedTab = self.tabIndex
                frame.spellOffset = 0
                Panels:RefreshSpellbook()
            end
        end)
        frame.skillButtons[i] = button
    end

    frame.petLabel = CreateText(frame.skillPane, "Pet spellbook", 10, "TOPLEFT", frame.skillPane, "TOPLEFT", 10, -36, false)
    frame.petLabel:Hide()

    frame.showRanks = CreateCheck(frame.skillPane, "Show lower ranks", 10, -414, function(value)
        -- Keep the replacement panel's state authoritative. Stock Wrath calls
        -- UpdateSpells() immediately after changing this CVar; without that
        -- refresh some 3.3.5/private-server clients keep returning the compact
        -- highest-rank spell mapping until the spell cache is rebuilt.
        frame.showAllRanks = value and true or false
        if SetCVar then SafeCall("show all spell ranks", SetCVar, "ShowAllSpellRanks", value and true or false) end
        if UpdateSpells then SafeCall("refresh spell rank cache", UpdateSpells) end
        frame.spellOffset = 0
        Panels:RefreshSpellbook()
    end)
    frame.showRanks:SetWidth(132)
    frame.showRanks:ClearAllPoints()
    frame.showRanks:SetPoint("BOTTOMLEFT", frame.skillPane, "BOTTOMLEFT", 10, 10)
    local initialShowRanks = GetCVarBool and GetCVarBool("ShowAllSpellRanks") or false
    frame.showAllRanks = initialShowRanks and true or false
    frame.showRanks:SetRUIValue(frame.showAllRanks)

    frame.content = CreateFrame("Frame", nil, frame.body)
    -- Reserve a dedicated header strip for Search so it never sits on
    -- top of the first spell row. The spell grid begins below this strip.
    frame.content:SetPoint("TOPLEFT", frame.skillPane, "TOPRIGHT", 12, -34)
    frame.content:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -2, 42)
    RUI:CreateBackdrop(frame.content)
    frame.empty = CreateText(frame.content, "", 10, "CENTER", frame.content, "CENTER", 0, 0, true)
    frame.empty:SetWidth(380)
    frame.empty:SetJustifyH("CENTER")
    frame.empty:Hide()
    frame.content:EnableMouseWheel(true)
    frame.content:SetScript("OnMouseWheel", function(_, delta)
        local step = 12
        if delta > 0 then
            frame.spellOffset = (frame.spellOffset or 0) - step
        elseif delta < 0 then
            frame.spellOffset = (frame.spellOffset or 0) + step
        end
        Panels:RefreshSpellbook()
    end)

    frame.spellButtons = {}
    for i = 1, 12 do
        local col = (i > 6) and 1 or 0
        local rowIndex = ((i - 1) % 6)
        local button = CreateFrame("Button", nil, frame.content, "SecureActionButtonTemplate")
        button:SetWidth(212)
        button:SetHeight(58)
        button:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 10 + (col * 220), -10 - (rowIndex * 62))
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")
        RUI:CreateBackdrop(button)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetWidth(38)
        button.icon:SetHeight(38)
        button.icon:SetPoint("LEFT", button, "LEFT", 9, 0)
        button.nameText = CreateText(button, "", 11, "TOPLEFT", button.icon, "TOPRIGHT", 9, -3, false)
        button.nameText:SetWidth(150)
        button.nameText:SetJustifyH("LEFT")
        button.rankText = CreateText(button, "", 8, "TOPLEFT", button.nameText, "BOTTOMLEFT", 0, -4, true)
        button.rankText:SetWidth(150)
        button.rankText:SetJustifyH("LEFT")
        button.passiveText = CreateText(button, "PASSIVE", 8, "BOTTOMRIGHT", button, "BOTTOMRIGHT", -8, 6, true)
        button.passiveText:Hide()
        button.highlight = button:CreateTexture(nil, "ARTWORK")
        button.highlight:SetAllPoints(button)
        button.highlight:Hide()
        button:SetScript("OnEnter", function(self)
            local r, g, b = RUI:GetAccentColor()
            self.highlight:SetTexture(r, g, b, 0.10)
            self.highlight:Show()
            if self.slot and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if GameTooltip.SetSpell then
                    SafeCall("spell tooltip", GameTooltip.SetSpell, GameTooltip, self.slot, self.bookType)
                else
                    GameTooltip:SetText(self.spellName or "Spell")
                end
                local spellID = SpellbookSpellID(self.slot, self.bookType)
                if spellID then
                    GameTooltip:AddLine("Spell ID: " .. tostring(spellID), 0.55, 0.72, 0.90)
                end
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function(self) self.highlight:Hide(); if GameTooltip then GameTooltip:Hide() end end)
        -- Normal spell casting must remain on Blizzard's secure click path.
        -- Calling CastSpell() from Zen's Lua OnClick taints protected spells
        -- on Ebonhold and produces the "blocked from an action" popup.  The
        -- SecureActionButtonTemplate owns the actual left-click spell action;
        -- PostClick is reserved for non-cast helpers such as linking/pet autocast.
        button:SetAttribute("type1", "spell")
        button:SetAttribute("shift-type1", "macro")
        button:SetAttribute("shift-macrotext1", "")
        button:SetAttribute("ctrl-type1", "macro")
        button:SetAttribute("ctrl-macrotext1", "")
        button:SetAttribute("type2", nil)
        button:SetScript("PostClick", function(self, mouseButton)
            if not self.slot then return end
            if IsModifiedClick and IsModifiedClick("CHATLINK") and GetSpellLink and ChatEdit_InsertLink then
                local spellLink, tradeSkillLink = GetSpellLink(self.slot, self.bookType)
                if tradeSkillLink or spellLink then ChatEdit_InsertLink(tradeSkillLink or spellLink) end
                return
            end
            if IsModifiedClick and IsModifiedClick("PICKUPACTION") and PickupSpell then
                -- Match the native Wrath spellbook: picking a spell up for an
                -- action-slot drop is allowed during combat. Only secure frame
                -- attribute/layout changes remain combat-locked.
                PickupBookSpell(self.slot, self.bookType)
                return
            end
            if mouseButton ~= "LeftButton" and self.bookType == (BOOKTYPE_PET or "pet") and ToggleSpellAutocast then
                SafeCall("toggle pet autocast", ToggleSpellAutocast, self.slot, self.bookType)
            end
        end)
        button:SetScript("OnDragStart", function(self)
            if self.slot and PickupSpell then
                -- Do not block spell pickup in combat; the native action-bar
                -- drop path owns PlaceAction() and can handle the cursor spell.
                PickupBookSpell(self.slot, self.bookType)
            end
        end)
        button:EnableMouseWheel(true)
        button:SetScript("OnMouseWheel", function(_, delta)
            if delta > 0 then
                frame.spellOffset = (frame.spellOffset or 0) - 12
            elseif delta < 0 then
                frame.spellOffset = (frame.spellOffset or 0) + 12
            end
            Panels:RefreshSpellbook()
        end)
        frame.spellButtons[i] = button
    end

    frame.prev = CreateButton(frame.body, "<", 34, 24)
    frame.prev:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -104, 6)
    frame.prev:SetScript("OnClick", function() frame.spellOffset = math.max(0, (frame.spellOffset or 0) - 12); Panels:RefreshSpellbook() end)
    frame.page = CreateText(frame.body, "1 / 1", 9, "RIGHT", frame.prev, "LEFT", -10, 0, true)
    frame.next = CreateButton(frame.body, ">", 34, 24)
    frame.next:SetPoint("LEFT", frame.prev, "RIGHT", 54, 0)
    frame.next:SetScript("OnClick", function() frame.spellOffset = (frame.spellOffset or 0) + 12; Panels:RefreshSpellbook() end)
    frame.hint = CreateText(frame.body, "Click to cast  •  drag to action bars", 8, "BOTTOMLEFT", frame.body, "BOTTOMLEFT", 166, 12, true)

    frame:SetScript("OnShow", function()
        Panels:HideOtherPanels(frame)
        if not (InCombatLockdown and InCombatLockdown()) then
            HideStock(SpellBookFrame)
            Panels:RefreshSpellbook()
        end
    end)
    return frame
end

function Panels:CollectSpellSlots(frame)
    local result = {}
    local filter = string.lower(frame.search and frame.search:GetText() or "")
    local bookType = frame.bookType or BOOKTYPE_SPELL or "spell"

    local function AddResolvedSpell(displaySlot, resolveHighestRank)
        local candidates = {}
        -- Only map through GetKnownSlotFromHighestRankSlot while the panel is
        -- in compact/highest-rank mode. Mapping raw slots while Show lower
        -- ranks is enabled collapses every older rank back onto the newest
        -- known rank, which makes the checkbox appear to do nothing.
        if resolveHighestRank and GetKnownSlotFromHighestRankSlot then
            local ok, known = SafeCall("map highest-rank spell slot", GetKnownSlotFromHighestRankSlot, displaySlot)
            if ok and tonumber(known) and tonumber(known) > 0 then table.insert(candidates, tonumber(known)) end
        end
        table.insert(candidates, displaySlot)

        local seen = {}
        for i = 1, #candidates do
            local slot = candidates[i]
            if slot and not seen[slot] then
                seen[slot] = true
                local spellName = GetSpellName and GetSpellName(slot, bookType)
                if spellName then
                    if filter == "" or string.find(string.lower(spellName), filter, 1, true) then
                        table.insert(result, { slot=slot, displaySlot=displaySlot })
                    end
                    return true
                end
            end
        end
        return false
    end

    if bookType == (BOOKTYPE_PET or "pet") then
        local numPet = 0
        if HasPetSpells then
            local a = HasPetSpells()
            if type(a) == "number" then numPet = a elseif a then numPet = 20 end
        end
        for slot = 1, numPet do
            local name = GetSpellName and GetSpellName(slot, bookType)
            if name and (filter == "" or string.find(string.lower(name), filter, 1, true)) then
                table.insert(result, { slot=slot, displaySlot=slot })
            end
        end
        return result
    end

    local tabIndex = frame.selectedTab or 1
    local name, texture, rawOffset, rawNumSpells, highestRankOffset, highestRankNumSpells
    if GetSpellTabInfo then
        name, texture, rawOffset, rawNumSpells, highestRankOffset, highestRankNumSpells = GetSpellTabInfo(tabIndex)
    end

    rawOffset = tonumber(rawOffset) or 0
    rawNumSpells = tonumber(rawNumSpells) or 0
    highestRankOffset = tonumber(highestRankOffset)
    highestRankNumSpells = tonumber(highestRankNumSpells)

    local showAllRanks = frame.showAllRanks and true or false
    local useHighest = not showAllRanks and highestRankOffset and highestRankNumSpells and highestRankNumSpells > 0
    local primaryOffset = useHighest and highestRankOffset or rawOffset
    local primaryCount = useHighest and highestRankNumSpells or rawNumSpells

    for displaySlot = primaryOffset + 1, primaryOffset + primaryCount do
        AddResolvedSpell(displaySlot, useHighest)
    end

    -- Compatibility fallback for private-server custom tabs. If their
    -- highest-rank range does not map to actual spell slots, retry the raw
    -- range directly before declaring the tab empty.
    if #result == 0 and useHighest and rawNumSpells > 0 and (rawOffset ~= primaryOffset or rawNumSpells ~= primaryCount) then
        for displaySlot = rawOffset + 1, rawOffset + rawNumSpells do AddResolvedSpell(displaySlot, false) end
    end

    return result
end

function Panels:RefreshSpellbook()
    local frame = self.frames and self.frames.spellbook
    if not frame then return end
    -- Never rewrite SecureActionButton spell attributes during combat.  Keep
    -- the last fully armed page visually intact until PLAYER_REGEN_ENABLED.
    if InCombatLockdown and InCombatLockdown() then
        self.pendingSpellRefresh=true
        return
    end
    local bookType = frame.bookType or BOOKTYPE_SPELL or "spell"
    local isPet = bookType == (BOOKTYPE_PET or "pet")
    local numTabs = isPet and 0 or ((GetNumSpellTabs and GetNumSpellTabs()) or 0)
    if frame.selectedTab > numTabs and numTabs > 0 then frame.selectedTab = 1 end

    for i = 1, #frame.skillButtons do
        local button = frame.skillButtons[i]
        if i <= numTabs then
            local name = GetSpellTabInfo(i)
            button.tabIndex = i
            button.RUIText:SetText(name or ("Line " .. i))
            button:Show()
            if i == frame.selectedTab then
                local r, g, b = RUI:GetAccentColor(); RUI:SetBorderColor(button, r, g, b, 1)
            else RUI:RefreshBackdrop(button) end
        else
            button.tabIndex = nil
            button:Hide()
        end
    end
    if isPet then
        frame.petLabel:Show()
        frame.showRanks:Hide()
    else
        frame.petLabel:Hide()
        frame.showRanks:Show()
        -- The panel owns this state after creation so private-server CVar
        -- propagation cannot immediately undo a click before UpdateSpells has
        -- refreshed the book.
        local showAllRanks = frame.showAllRanks and true or false
        frame.showRanks:SetRUIValue(showAllRanks)
    end

    frame.filteredSlots = self:CollectSpellSlots(frame)
    local total = #frame.filteredSlots
    frame.spellOffset = ClampPageOffset(frame.spellOffset or 0, total, 12)
    if total == 0 then
        frame.empty:SetText("No spells were returned for this spell line.")
        frame.empty:Show()
    else
        frame.empty:Hide()
    end

    for i = 1, #frame.spellButtons do
        local button = frame.spellButtons[i]
        local spellEntry = frame.filteredSlots[(frame.spellOffset or 0) + i]
        local slot = spellEntry and (spellEntry.slot or spellEntry)
        if slot then
            local name, rank = GetSpellName(slot, bookType)
            local texture = GetSpellTexture and GetSpellTexture(slot, bookType)
            local passive = IsPassiveSpell and IsPassiveSpell(slot, bookType)
            button.slot = slot
            button.displaySlot = spellEntry.displaySlot or slot
            button.bookType = bookType
            button.spellName = name
            if button.SetAttribute and not (InCombatLockdown and InCombatLockdown()) then
                if passive then
                    button:SetAttribute("type1", nil)
                    button:SetAttribute("spell1", nil)
                    button:SetAttribute("spell", nil)
                else
                    button:SetAttribute("type1", "spell")
                    button:SetAttribute("spell1", name)
                    button:SetAttribute("spell", name)
                end
            end
            button.nameText:SetText(name or "")
            button.rankText:SetText(rank or "")
            button.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            if passive then button.passiveText:Show() else button.passiveText:Hide() end
            button:Show()
        else
            button.slot = nil
            button.displaySlot = nil
            if button.SetAttribute and not (InCombatLockdown and InCombatLockdown()) then
                button:SetAttribute("type1", nil)
                button:SetAttribute("spell1", nil)
                button:SetAttribute("spell", nil)
            end
            button:Hide()
        end
    end

    local pages = math.max(1, math.ceil(total / 12))
    local current = math.floor((frame.spellOffset or 0) / 12) + 1
    frame.page:SetText(tostring(current) .. " / " .. tostring(pages))
    SetButtonEnabled(frame.prev, (frame.spellOffset or 0) > 0)
    SetButtonEnabled(frame.next, ((frame.spellOffset or 0) + 12) < total)
end

function Panels:ToggleSpellbook(bookType)
    -- The Zen window itself is combat-safe.  Keep presentation consistent in
    -- and out of combat; only protected spellbook mutations remain locked.
    -- The currently armed secure spell rows are prepared out of combat and are
    -- left untouched during lockdown so their visual labels can never drift
    -- away from the secure spell attributes behind them.
    local frame = self.frames.spellbook
    local requested = bookType or BOOKTYPE_SPELL or "spell"

    if InCombatLockdown and InCombatLockdown() then
        if frame:IsShown() then frame:Hide() else frame:Show() end
        return
    end

    if frame:IsShown() and frame.bookType == requested then frame:Hide(); return end
    frame.bookType = requested
    frame.selectedTab = 1
    frame.spellOffset = 0
    frame.search:SetText("")
    HideStock(SpellBookFrame)
    frame:Show()
    self:RefreshSpellbook()
end

-- -------------------------------------------------------------------------
-- Social / Friends + Ignore
-- -------------------------------------------------------------------------
local function NormalizeFriendName(name)
    name = tostring(name or "")
    name = string.match(name, "^([^%-]+)") or name
    return string.lower(name)
end

-- Ebonhold can occasionally return a stale/false `connected` flag from
-- GetFriendInfo even while the friend is online. Stock Wrath also relies on
-- GetNumFriends()'s second return value (online count), with online friends
-- occupying the first part of the friend list. Use both sources, and treat a
-- matching live unit token as definitive evidence that the character is
-- online.
local function FriendObservedOnline(name)
    local wanted = NormalizeFriendName(name)
    if wanted == "" or not UnitExists or not UnitName then return false end

    local function Matches(unit)
        if not UnitExists(unit) then return false end
        local unitName = UnitName(unit)
        if NormalizeFriendName(unitName) ~= wanted then return false end
        if UnitIsConnected and UnitIsConnected(unit) == false then return false end
        return true
    end

    if Matches("target") or Matches("focus") or Matches("mouseover") then return true end
    for i = 1, 4 do if Matches("party" .. i) then return true end end
    for i = 1, 40 do if Matches("raid" .. i) then return true end end
    return false
end

local function GetRUIFriendInfo(index)
    if not GetFriendInfo then return nil, nil, nil, nil, false, nil end
    local name, level, class, area, connected, status = GetFriendInfo(index)
    local onlineCount = 0
    if GetNumFriends then
        local total, online = GetNumFriends()
        onlineCount = tonumber(online) or 0
    end

    local isOnline = connected and true or false
    if not isOnline and onlineCount > 0 and tonumber(index) and index <= onlineCount then
        isOnline = true
    end
    if not isOnline and name and FriendObservedOnline(name) then
        isOnline = true
    end
    return name, level, class, area, isOnline, status
end

function Panels:CreateSocial()
    local frame = CreatePanel("ZenUISocialFrame", "social", "Social")
    self.frames.social = frame
    frame.mode = "friends"
    frame.offset = 0
    frame.selected = nil

    frame.friendsTab = CreateButton(frame.body, "Friends", 100, 26)
    frame.friendsTab:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -2)
    frame.ignoreTab = CreateButton(frame.body, "Ignore", 100, 26)
    frame.ignoreTab:SetPoint("LEFT", frame.friendsTab, "RIGHT", 8, 0)
    frame.guildButton = CreateButton(frame.body, "Guild", 100, 26)
    frame.guildButton:SetPoint("LEFT", frame.ignoreTab, "RIGHT", 8, 0)
    frame.raidButton = CreateButton(frame.body, "Raid", 100, 26)
    frame.raidButton:SetPoint("LEFT", frame.guildButton, "RIGHT", 8, 0)
    frame.friendsTab:SetScript("OnClick", function() frame.mode = "friends"; frame.offset = 0; frame.selected = nil; Panels:RefreshSocial() end)
    frame.ignoreTab:SetScript("OnClick", function() frame.mode = "ignore"; frame.offset = 0; frame.selected = nil; Panels:RefreshSocial() end)
    frame.guildButton:SetScript("OnClick", function() Panels:ToggleGuild(true, frame) end)
    frame.raidButton:SetScript("OnClick", function() Panels:ToggleRaid(true, frame) end)

    frame.list = CreateFrame("Frame", nil, frame.body)
    frame.list:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -42)
    frame.list:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -2, 108)
    RUI:CreateBackdrop(frame.list)
    frame.rows = {}
    for i = 1, 6 do
        local row = CreateListRow(frame.list, 428, 34)
        row:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 8, -8 - ((i - 1) * 36))
        row.nameText = CreateText(row, "", 11, "TOPLEFT", row, "TOPLEFT", 10, -5, false)
        row.nameText:SetWidth(290)
        row.detailText = CreateText(row, "", 9, "BOTTOMLEFT", row, "BOTTOMLEFT", 10, 5, true)
        row.detailText:SetWidth(290)
        row.detailText:SetJustifyH("LEFT")
        row.divider = row:CreateTexture(nil, "ARTWORK")
        row.divider:SetWidth(1)
        row.divider:SetPoint("TOPLEFT", row, "TOPLEFT", 318, -4)
        row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 318, 4)
        local br, bg, bb = RUI:GetBorderColor()
        row.divider:SetTexture(br, bg, bb, 0.9)
        row.presence = row:CreateTexture(nil, "ARTWORK")
        row.presence:SetWidth(6)
        row.presence:SetHeight(6)
        row.presence:SetPoint("LEFT", row, "LEFT", 330, 0)
        row.statusText = CreateText(row, "", 10, "RIGHT", row, "RIGHT", -10, 0, true)
        row.statusText:SetWidth(74)
        row.statusText:SetJustifyH("RIGHT")
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" and frame.mode == "friends" and self.dataIndex then
                local name, _, _, _, connected = GetRUIFriendInfo(self.dataIndex)
                if name and connected and ChatFrame_SendTell then ChatFrame_SendTell(name) end
                return
            end
            frame.selected = self.dataIndex
            Panels:RefreshSocial()
        end)
        frame.rows[i] = row
    end
    frame.list:EnableMouseWheel(true)
    frame.list:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = ClampOffset((frame.offset or 0) - delta, frame.total or 0, #frame.rows)
        Panels:RefreshSocial()
    end)

    frame.input = CreateEditBox(frame.body, 198, 25, "Player name...")
    frame.input:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 68)
    frame.add = CreateButton(frame.body, "Add Friend", 104, 25)
    frame.add:SetPoint("LEFT", frame.input, "RIGHT", 8, 0)
    frame.add:SetScript("OnClick", function()
        local name = frame.input:GetText()
        if name and name ~= "" then
            if frame.mode == "friends" and AddFriend then AddFriend(name) elseif frame.mode == "ignore" and AddIgnore then AddIgnore(name) end
            frame.input:SetText("")
        end
    end)
    frame.input:SetScript("OnEnterPressed", function(self) frame.add:Click(); self:ClearFocus() end)

    frame.remove = CreateButton(frame.body, "Remove", 88, 25)
    frame.remove:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -2, 36)
    frame.remove:SetScript("OnClick", function()
        if not frame.selected then return end
        if frame.mode == "friends" then
            local name = GetFriendInfo and GetFriendInfo(frame.selected)
            if name and RemoveFriend then RemoveFriend(name) end
        else
            local name = GetIgnoreName and GetIgnoreName(frame.selected)
            if name and DelIgnore then DelIgnore(name) end
        end
        frame.selected = nil
    end)

    frame.whisper = CreateButton(frame.body, "Whisper", 88, 25)
    frame.whisper:SetPoint("RIGHT", frame.remove, "LEFT", -8, 0)
    frame.whisper:SetScript("OnClick", function()
        if frame.mode ~= "friends" or not frame.selected then return end
        local name, _, _, _, connected = GetRUIFriendInfo(frame.selected)
        if name and connected and ChatFrame_SendTell then ChatFrame_SendTell(name) end
    end)
    frame.invite = CreateButton(frame.body, "Invite", 88, 25)
    frame.invite:SetPoint("RIGHT", frame.whisper, "LEFT", -8, 0)
    frame.invite:SetScript("OnClick", function()
        if frame.mode ~= "friends" or not frame.selected then return end
        local name, _, _, _, connected = GetRUIFriendInfo(frame.selected)
        if name and connected and InviteUnit then InviteUnit(name) end
    end)
    frame.summary = CreateText(frame.body, "", 9, "BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 10, true)

    frame:SetScript("OnShow", function()
        Panels:HideOtherPanels(frame)
        HideStock(FriendsFrame)
        if ShowFriends then SafeCall("request friends", ShowFriends) end
        frame.friendRefreshElapsed = 0
        frame.friendRefreshRemaining = 2.0
        Panels:RefreshSocial()
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if self.mode ~= "friends" or not self.friendRefreshRemaining or self.friendRefreshRemaining <= 0 then return end
        self.friendRefreshElapsed = (self.friendRefreshElapsed or 0) + (elapsed or 0)
        self.friendRefreshRemaining = self.friendRefreshRemaining - (elapsed or 0)
        if self.friendRefreshElapsed >= 0.35 then
            self.friendRefreshElapsed = 0
            Panels:RefreshSocial()
        end
        if self.friendRefreshRemaining <= 0 then
            self.friendRefreshRemaining = nil
            self.friendRefreshElapsed = nil
        end
    end)
    return frame
end

function Panels:RefreshSocial()
    local frame = self.frames and self.frames.social
    if not frame or not frame:IsShown() then return end
    local friends = frame.mode == "friends"
    local total = friends and ((GetNumFriends and GetNumFriends()) or 0) or ((GetNumIgnores and GetNumIgnores()) or 0)
    frame.total = total
    frame.offset = ClampOffset(frame.offset or 0, total, #frame.rows)

    for i = 1, #frame.rows do
        local row = frame.rows[i]
        if row.divider then
            local br, bg, bb = RUI:GetBorderColor()
            row.divider:SetTexture(br, bg, bb, 0.9)
        end
        local index = (frame.offset or 0) + i
        if index <= total then
            row.dataIndex = index
            if friends then
                local name, level, class, area, connected, status = GetRUIFriendInfo(index)
                row.nameText:SetText(name or "Unknown")
                local details = {}
                if tonumber(level) and tonumber(level) > 0 then table.insert(details, "Lv " .. tostring(level)) end
                if class and class ~= "" and class ~= UNKNOWN and class ~= "Unknown" then table.insert(details, class) end
                if area and area ~= UNKNOWN and area ~= "Unknown" then table.insert(details, area) end
                row.detailText:SetText(table.concat(details, "  •  "))
                row.statusText:SetText(connected and ((status and status ~= "") and status or "Online") or "Offline")
                if connected then
                    local nr, ng, nb = RUI:GetTextColor(false)
                    local mr, mg, mb = RUI:GetTextColor(true)
                    row.nameText:SetTextColor(nr, ng, nb, 1)
                    row.detailText:SetTextColor(mr, mg, mb, 0.95)
                    row.statusText:SetTextColor(0.35, 1.00, 0.45, 1)
                    row.presence:SetTexture(0.35, 1.00, 0.45, 1)
                    if row.RUIBackground then row.RUIBackground:SetAlpha(0.42) end
                else
                    local mr, mg, mb = RUI:GetTextColor(true)
                    row.nameText:SetTextColor(mr, mg, mb, 0.62)
                    row.detailText:SetTextColor(mr, mg, mb, 0.42)
                    row.statusText:SetTextColor(mr, mg, mb, 0.62)
                    row.presence:SetTexture(mr, mg, mb, 0.55)
                    if row.RUIBackground then row.RUIBackground:SetAlpha(0.14) end
                end
            else
                local name = GetIgnoreName(index)
                local mr, mg, mb = RUI:GetTextColor(true)
                row.nameText:SetText(name or "Unknown")
                row.detailText:SetText("")
                row.statusText:SetText("Ignored")
                row.nameText:SetTextColor(mr, mg, mb, 0.85)
                row.detailText:SetTextColor(mr, mg, mb, 0.65)
                row.statusText:SetTextColor(mr, mg, mb, 0.75)
                row.presence:SetTexture(mr, mg, mb, 0.45)
                if row.RUIBackground then row.RUIBackground:SetAlpha(0.24) end
            end
            SetSelectedRow(row, frame.selected == index)
            row:Show()
        else
            row.dataIndex = nil
            row:Hide()
        end
    end

    frame.friendsTab.RUIText:SetText("Friends")
    frame.ignoreTab.RUIText:SetText("Ignore")
    RUI:RefreshBackdrop(frame.guildButton)
    RUI:RefreshBackdrop(frame.raidButton)
    if friends then
        local r, g, b = RUI:GetAccentColor(); RUI:SetBorderColor(frame.friendsTab, r, g, b, 1); RUI:RefreshBackdrop(frame.ignoreTab)
        frame.add.RUIText:SetText("Add Friend")
    else
        local r, g, b = RUI:GetAccentColor(); RUI:SetBorderColor(frame.ignoreTab, r, g, b, 1); RUI:RefreshBackdrop(frame.friendsTab)
        frame.add.RUIText:SetText("Add Ignore")
    end
    SetButtonEnabled(frame.whisper, friends and frame.selected ~= nil)
    SetButtonEnabled(frame.invite, friends and frame.selected ~= nil)
    SetButtonEnabled(frame.remove, frame.selected ~= nil)
    frame.summary:SetText(tostring(total) .. (friends and " friends  •  wheel scrolls  •  right-click whisper  •  Shift-click chat name to add" or " ignored players  •  mouse wheel scrolls"))
end

local function HideOtherSocialFamilyFrames(target)
    local frames = Panels.frames or {}
    local keys = { "social", "guild", "raid" }
    for i = 1, #keys do
        local other = frames[keys[i]]
        if other and other ~= target and other.IsShown and other:IsShown() and other.Hide then
            pcall(other.Hide, other)
        end
    end
end

function Panels:ToggleSocial(forceShow, mode, sourceFrame)
    local frame = self.frames.social
    if frame:IsShown() and not forceShow then frame:Hide(); return end
    HideOtherSocialFamilyFrames(frame)
    frame.mode = mode or "friends"
    frame.offset = 0
    frame.selected = nil
    HideStock(FriendsFrame)
    frame:Show()
end

-- -------------------------------------------------------------------------
-- Guild
-- -------------------------------------------------------------------------
-- Wrath filters GetGuildRosterInfo itself when the global "show offline" flag
-- is disabled.  The Zen checkbox performs its own local filtering, so keep
-- Blizzard's roster source expanded while this replacement panel is open.
-- Restore the user's stock setting when the Zen panel closes.
function Panels:EnableFullGuildRoster(frame)
    if not frame then return end
    if frame.stockShowOffline == nil and type(GetGuildRosterShowOffline) == "function" then
        local ok, value = pcall(GetGuildRosterShowOffline)
        if ok then frame.stockShowOffline = value and true or false end
    end
    if type(SetGuildRosterShowOffline) == "function" then
        SafeCall("show full guild roster", SetGuildRosterShowOffline, true)
    end
end

function Panels:RestoreGuildRosterFilter(frame)
    if not frame or frame.stockShowOffline == nil then return end
    if type(SetGuildRosterShowOffline) == "function" then
        SafeCall("restore guild roster filter", SetGuildRosterShowOffline, frame.stockShowOffline)
    end
    frame.stockShowOffline = nil
end

local function PlayerNameFromChatLink(link)
    if type(link) ~= "string" then return nil end

    local payload
    if string.sub(link, 1, 7) == "player:" then
        payload = string.sub(link, 8)
    elseif string.sub(link, 1, 9) == "BNplayer:" then
        payload = string.sub(link, 10)
    else
        return nil
    end

    local name = string.match(payload or "", "^([^:]+)")
    if not name or name == "" then return nil end
    return name
end

function Panels:TryPopulateSocialFriendFromChatLink(link, button)
    local frame = self.frames and self.frames.social
    if not frame or not frame:IsShown() or frame.mode ~= "friends" or not frame.input or not frame.input:IsShown() then return false end
    if button and button ~= "LeftButton" then return false end

    local modified = false
    if type(IsModifiedClick) == "function" then
        modified = IsModifiedClick("CHATLINK") and true or false
    elseif type(IsShiftKeyDown) == "function" then
        modified = IsShiftKeyDown() and true or false
    end
    if not modified then return false end

    local name = PlayerNameFromChatLink(link)
    if not name then return false end

    frame.input:SetText(name)
    if frame.input.SetCursorPosition then frame.input:SetCursorPosition(string.len(name)) end
    if frame.input.SetFocus then frame.input:SetFocus() end
    if frame.input.HighlightText then frame.input:HighlightText() end
    return true
end

function Panels:TryPopulateGuildInviteFromChatLink(link, button)
    local frame = self.frames and self.frames.guild
    if not frame or not frame:IsShown() or not frame.input or not frame.input:IsShown() then return false end
    if button and button ~= "LeftButton" then return false end

    local modified = false
    if type(IsModifiedClick) == "function" then
        modified = IsModifiedClick("CHATLINK") and true or false
    elseif type(IsShiftKeyDown) == "function" then
        modified = IsShiftKeyDown() and true or false
    end
    if not modified then return false end

    local name = PlayerNameFromChatLink(link)
    if not name then return false end

    frame.input:SetText(name)
    if frame.input.SetFocus then frame.input:SetFocus() end
    if frame.input.HighlightText then frame.input:HighlightText() end
    return true
end

function Panels:InstallGuildChatLinkBridge()
    if self.guildChatLinkBridgeInstalled then return end
    if type(ChatFrame_OnHyperlinkShow) ~= "function" then return end

    local original = ChatFrame_OnHyperlinkShow
    self.guildChatLinkOriginal = original
    ChatFrame_OnHyperlinkShow = function(chatFrame, link, text, button)
        -- Context priority within the Social system: when the Friends view is
        -- open, Shift-clicking a player link fills Add Friend. Guild keeps its
        -- existing invite-field shortcut when the Guild panel is the active
        -- destination. Mail wraps this bridge later and remains higher priority
        -- whenever the Send Mail panel is open.
        if Panels:TryPopulateSocialFriendFromChatLink(link, button) then
            return
        end
        if Panels:TryPopulateGuildInviteFromChatLink(link, button) then
            return
        end
        return original(chatFrame, link, text, button)
    end
    self.guildChatLinkBridgeInstalled = true
end

function Panels:ShowStockFriendsTab(tab)
    tab = tonumber(tab) or 1
    -- Prefer Blizzard's original dispatcher when Zen captured it successfully.
    if type(self.originalToggleFriendsFrame) == "function" and self.originalToggleFriendsFrame ~= self.ruiToggleFriendsFrame then
        local ok = pcall(self.originalToggleFriendsFrame, tab)
        if ok then return true end
    end

    -- Hard fallback for private-server builds that replace ToggleFriendsFrame
    -- after login. This keeps disabling an individual Zen Social/Guild view a
    -- real opt-out instead of leaving the native window inaccessible.
    if not FriendsFrame then return false end
    self.allowStockSocial = true
    if tab == 3 and type(GuildStatus_Update) == "function" then
        pcall(GuildStatus_Update)
    else
        if type(PanelTemplates_SetTab) == "function" then pcall(PanelTemplates_SetTab, FriendsFrame, tab) end
        local subframe = tab == 1 and "FriendsListFrame" or tab == 3 and "GuildFrame" or tab == 5 and "RaidFrame" or nil
        if subframe and type(FriendsFrame_ShowSubFrame) == "function" then pcall(FriendsFrame_ShowSubFrame, subframe) end
        if type(ShowUIPanel) == "function" then pcall(ShowUIPanel, FriendsFrame) elseif FriendsFrame.Show then FriendsFrame:Show() end
    end
    self.allowStockSocial = nil
    return FriendsFrame.IsShown and FriendsFrame:IsShown() or true
end

local function HideNativeTexture(region)
    if not region or type(region.GetObjectType) ~= "function" or region:GetObjectType() ~= "Texture" then return end
    local texture = type(region.GetTexture) == "function" and region:GetTexture() or nil
    if type(texture) ~= "string" then return end
    local lower = string.lower(texture)
    if string.find(lower, "macropopup-", 1, true) then
        region:SetTexture(nil)
    end
end

local function SkinGuildNativeButton(button)
    if not button then return end
    if type(button.GetNormalTexture) == "function" then
        local tex = button:GetNormalTexture(); if tex then tex:SetAlpha(0) end
    end
    if type(button.GetPushedTexture) == "function" then
        local tex = button:GetPushedTexture(); if tex then tex:SetAlpha(0) end
    end
    if type(button.GetDisabledTexture) == "function" then
        local tex = button:GetDisabledTexture(); if tex then tex:SetAlpha(0) end
    end
    if type(button.GetHighlightTexture) == "function" then
        local tex = button:GetHighlightTexture(); if tex then tex:SetAlpha(0) end
    end
    RUI:CreateBackdrop(button)
    local text = type(button.GetFontString) == "function" and button:GetFontString() or nil
    if text then RUI:StyleFontString(text, 10) end
    if not button.ZenUIHover then
        button.ZenUIHover = button:CreateTexture(nil, "ARTWORK")
        button.ZenUIHover:SetAllPoints(button)
        button.ZenUIHover:Hide()
        if button.HookScript then
            button:HookScript("OnEnter", function(self)
                local r, g, b = RUI:GetAccentColor()
                self.ZenUIHover:SetTexture(r, g, b, 0.12)
                self.ZenUIHover:Show()
            end)
            button:HookScript("OnLeave", function(self)
                if self.ZenUIHover then self.ZenUIHover:Hide() end
            end)
        end
    end
end

local function SkinGuildNativeEditBox(box)
    if not box then return end
    local name = box.GetName and box:GetName()
    if name then
        local left = _G[name .. "Left"]
        local middle = _G[name .. "Middle"]
        local right = _G[name .. "Right"]
        if left then left:SetAlpha(0) end
        if middle then middle:SetAlpha(0) end
        if right then right:SetAlpha(0) end
    end
    RUI:CreateBackdrop(box)
    if box.SetFont then box:SetFont(RUI:GetFontPath(), 10) end
    if box.SetTextInsets then box:SetTextInsets(7, 7, 0, 0) end
end

function Panels:SkinGuildControlPopup(popup)
    if not popup then return end

    -- Keep Blizzard's secure/authoritative controls and scripts, but remove the
    -- parchment/macro art so the GM editor visually belongs to the Zen Guild
    -- panel.  No protected GuildControl API is reimplemented here.
    local regions = { popup:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        HideNativeTexture(region)
        if region and type(region.GetObjectType) == "function" and region:GetObjectType() == "FontString" then
            RUI:StyleFontString(region, 10)
        end
    end
    RUI:CreateBackdrop(popup)
    if not popup.ZenUIAccent then popup.ZenUIAccent = RUI:CreateAccentLine(popup, 2) end

    SkinGuildNativeButton(_G.GuildControlPopupAcceptButton)
    SkinGuildNativeButton(_G.GuildControlPopupFrameCancelButton)
    SkinGuildNativeEditBox(_G.GuildControlPopupFrameEditBox)
    SkinGuildNativeEditBox(_G.GuildControlWithdrawGoldEditBox)
    SkinGuildNativeEditBox(_G.GuildControlWithdrawItemsEditBox)

    local dropDown = _G.GuildControlPopupFrameDropDown
    if dropDown then
        local name = dropDown.GetName and dropDown:GetName()
        if name then
            local left = _G[name .. "Left"]
            local middle = _G[name .. "Middle"]
            local right = _G[name .. "Right"]
            if left then left:SetAlpha(0) end
            if middle then middle:SetAlpha(0) end
            if right then right:SetAlpha(0) end
            local text = _G[name .. "Text"]
            if text then RUI:StyleFontString(text, 10) end
        end
        RUI:CreateBackdrop(dropDown)
    end

    for i = 1, 17 do
        local check = _G["GuildControlPopupFrameCheckbox" .. i]
        local text = _G["GuildControlPopupFrameCheckbox" .. i .. "Text"]
        if check then
            RUI:CreateBackdrop(check)
            if check.RUIBackground then check.RUIBackground:SetAlpha(0.30) end
        end
        if text then RUI:StyleFontString(text, 9) end
    end
    local bankChecks = {
        _G.GuildControlTabPermissionsViewTab,
        _G.GuildControlTabPermissionsDepositItems,
        _G.GuildControlTabPermissionsUpdateText,
    }
    for i = 1, #bankChecks do
        local check = bankChecks[i]
        if check then
            RUI:CreateBackdrop(check)
            if check.RUIBackground then check.RUIBackground:SetAlpha(0.30) end
            local text = check.GetName and _G[check:GetName() .. "Text"] or nil
            if text then RUI:StyleFontString(text, 9) end
        end
    end

    local permissions = _G.GuildControlPopupFrameTabPermissions
    if permissions then
        if permissions.SetBackdrop then permissions:SetBackdrop(nil) end
        RUI:CreateBackdrop(permissions)
        if permissions.RUIBackground then permissions.RUIBackground:SetAlpha(0.28) end
    end

    local labels = {
        _G.GuildControlWithdrawGoldText,
        _G.GuildControlWithdrawGoldAmountText,
        _G.GuildBankTabLabel,
        _G.GuildControlTabPermissionsWithdrawItemsText,
    }
    for i = 1, #labels do
        if labels[i] then RUI:StyleFontString(labels[i], 9) end
    end

    popup.ZenUISkinned = true
end

function Panels:GuildControlHasSelectedRank()
    local popup = _G.GuildControlPopupFrame
    local dropDown = _G.GuildControlPopupFrameDropDown
    if not popup or not dropDown or type(UIDropDownMenu_GetSelectedID) ~= "function" then return false end
    local ok, selected = pcall(UIDropDownMenu_GetSelectedID, dropDown)
    return ok and tonumber(selected) and tonumber(selected) > 0 or false
end

function Panels:TryInitializeGuildControl()
    if self:GuildControlHasSelectedRank() then return true end

    local popup = _G.GuildControlPopupFrame
    local dropDown = _G.GuildControlPopupFrameDropDown
    if not popup or not dropDown then return false end
    if type(GuildControlPopupFrame_Initialize) ~= "function" then return false end

    local ranksReady = false
    if type(GuildControlGetNumRanks) == "function" then
        local ok, numRanks = pcall(GuildControlGetNumRanks)
        ranksReady = ok and tonumber(numRanks) and tonumber(numRanks) > 0 or false
    end
    if not ranksReady then return false end

    -- Prefer the normal Blizzard GUILD_ROSTER_UPDATE path.  This helper is a
    -- fallback for Ebonhold revisions where the rank data is ready but the
    -- stock initializer did not run before our Guild Settings click.
    if popup.initialized and not self:GuildControlHasSelectedRank() then
        popup.initialized = nil
    end

    local called = false
    if type(securecall) == "function" then
        called = pcall(securecall, GuildControlPopupFrame_Initialize)
        if not called then called = pcall(securecall, "GuildControlPopupFrame_Initialize") end
    end
    if not called then pcall(GuildControlPopupFrame_Initialize) end

    return self:GuildControlHasSelectedRank()
end

function Panels:FinishGuildControlOpen()
    local frame = self.frames and self.frames.guild
    local popup = _G.GuildControlPopupFrame
    if not frame or not popup or not self:GuildControlHasSelectedRank() then return false end

    local button = _G.GuildFrameControlButton
    if button and button.Enable then pcall(button.Enable, button) end
    if button and button.Click and not popup:IsShown() then pcall(button.Click, button) end
    if popup.Show and not popup:IsShown() then popup:Show() end

    if not popup:IsShown() then return false end

    -- Refresh only after a real rank is selected.  Calling this with a nil
    -- dropdown selection is what produced the blank/inert 1.0.1-1.0.3 panel.
    if type(GuildControlPopupframe_Update) == "function" then
        pcall(GuildControlPopupframe_Update)
    end

    if not popup.ZenUIOriginalPoints and popup.GetNumPoints and popup.GetPoint then
        popup.ZenUIOriginalPoints = {}
        for i = 1, (popup:GetNumPoints() or 0) do
            local point, relativeTo, relativePoint, x, y = popup:GetPoint(i)
            popup.ZenUIOriginalPoints[#popup.ZenUIOriginalPoints + 1] = { point, relativeTo, relativePoint, x, y }
        end
    end
    if popup.ZenUIOriginalStrata == nil and popup.GetFrameStrata then
        popup.ZenUIOriginalStrata = popup:GetFrameStrata()
    end
    if popup.ZenUIOriginalLevel == nil and popup.GetFrameLevel then
        popup.ZenUIOriginalLevel = popup:GetFrameLevel()
    end

    if FriendsFrame then
        if self.guildControlFriendsAlpha == nil and FriendsFrame.GetAlpha then
            self.guildControlFriendsAlpha = FriendsFrame:GetAlpha()
        end
        -- Do not disable FriendsFrame mouse input here.  Some Ebonhold builds
        -- keep part of the Guild Control lifecycle attached to the native host
        -- even though GuildControlPopupFrame itself is a top-level UI child.
        -- Zen is on DIALOG above it, so transparency is enough visually.
        if FriendsFrame.SetAlpha then FriendsFrame:SetAlpha(0) end
    end

    popup.ZenUIHostedByGuild = true
    self:SkinGuildControlPopup(popup)
    if popup.ClearAllPoints and popup.SetPoint then
        popup:ClearAllPoints()
        popup:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -50)
    end
    if popup.SetFrameStrata then popup:SetFrameStrata("FULLSCREEN_DIALOG") end
    if popup.SetFrameLevel then popup:SetFrameLevel((frame:GetFrameLevel() or 1) + 20) end
    if popup.EnableMouse then popup:EnableMouse(true) end
    popup:Show()

    self.ebonholdDiscoveryActive = nil
    self.allowStockSocial = nil

    if popup.HookScript and not popup.ZenUINativeReturnHooked then
        popup.ZenUINativeReturnHooked = true
        popup:HookScript("OnHide", function()
            Panels:RestoreGuildControlParent()
        end)
    end
    return true
end

function Panels:AbortGuildControlOpen(message)
    if self.guildControlOpenRetry then self.guildControlOpenRetry:Hide() end
    self.guildControlRetryElapsed = nil
    self.guildControlInitAttempted = nil
    self.ebonholdDiscoveryActive = nil
    self.allowStockSocial = nil
    self.nativeGuildControlActive = nil
    if FriendsFrame then HideStock(FriendsFrame) end
    local frame = self.frames and self.frames.guild
    if frame and not frame:IsShown() then frame:Show() end
    if message then RUI:Print(message) end
end

function Panels:OpenGuildControl()
    local frame = self.frames and self.frames.guild
    if not frame then return end
    if type(IsGuildLeader) == "function" and not IsGuildLeader() then
        RUI:Print("Guild Settings are only available to the Guild Master.")
        return
    end

    -- The native Friends/Guild lifecycle must stay alive because Ebonhold uses
    -- Blizzard's authoritative rank/permission editor.  Zen only changes the
    -- presentation after Blizzard has a valid selected rank.
    self:RestoreGuildControlParent()
    self.nativeGuildControlActive = true
    self.allowStockSocial = true
    self.ebonholdDiscoveryActive = true

    self:ShowStockFriendsTab(3)
    if FriendsFrame and type(PanelTemplates_SetTab) == "function" then
        pcall(PanelTemplates_SetTab, FriendsFrame, 3)
    end
    if type(FriendsFrame_ShowSubFrame) == "function" then
        pcall(FriendsFrame_ShowSubFrame, "GuildFrame")
    end
    if type(GuildRoster) == "function" then pcall(GuildRoster) end
    if type(GuildStatus_Update) == "function" then pcall(GuildStatus_Update) end

    local popup = _G.GuildControlPopupFrame
    if not popup then
        self:AbortGuildControlOpen("Guild Settings are not available on this client right now.")
        return
    end

    -- Usually the stock GUILD_ROSTER_UPDATE handler has already initialized
    -- the dropdown.  If not, give it a short bounded window to do so before we
    -- fall back to Blizzard's initializer ourselves.  Never show a blank editor.
    if self:GuildControlHasSelectedRank() and self:FinishGuildControlOpen() then return end

    if not self.guildControlOpenRetry then
        local retry = CreateFrame("Frame")
        retry:Hide()
        retry:SetScript("OnUpdate", function(_, elapsed)
            if not Panels.nativeGuildControlActive then retry:Hide(); return end
            Panels.guildControlRetryElapsed = (Panels.guildControlRetryElapsed or 0) + (elapsed or 0)

            if Panels:GuildControlHasSelectedRank() then
                retry:Hide()
                Panels.guildControlRetryElapsed = nil
                Panels.guildControlInitAttempted = nil
                if not Panels:FinishGuildControlOpen() then
                    Panels:AbortGuildControlOpen("Guild Settings could not be opened safely.")
                end
                return
            end

            -- Let the native roster event initialize first. After a quarter
            -- second, use the same Blizzard FrameXML initializer as fallback.
            if Panels.guildControlRetryElapsed >= 0.25 and not Panels.guildControlInitAttempted then
                Panels.guildControlInitAttempted = true
                Panels:TryInitializeGuildControl()
            end

            if Panels.guildControlRetryElapsed >= 1.50 then
                retry:Hide()
                if Panels:TryInitializeGuildControl() and Panels:FinishGuildControlOpen() then
                    Panels.guildControlRetryElapsed = nil
                    Panels.guildControlInitAttempted = nil
                    return
                end
                Panels:AbortGuildControlOpen("Guild Settings did not receive valid rank data from Ebonhold.")
            end
        end)
        self.guildControlOpenRetry = retry
    end

    self.guildControlRetryElapsed = 0
    self.guildControlInitAttempted = nil
    self.guildControlOpenRetry:Show()
end

function Panels:OpenGuildNotes()
    local frame = self.frames and self.frames.guild
    if not frame or not frame.selected or not frame.noteEditor then return end
    local name, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(frame.selected)
    if not name then return end
    frame.noteEditor.memberIndex = frame.selected
    frame.noteEditor.memberName = name
    frame.noteEditor.title:SetText("Guild Notes — " .. tostring(name))
    frame.noteEditor.public:SetText(note or "")
    local canViewOfficer = type(CanViewOfficerNote) ~= "function" or CanViewOfficerNote()
    frame.noteEditor.officer:SetText(canViewOfficer and (officerNote or "") or "")
    -- Some Ebonhold revisions omit the stock CanEdit* helpers even though the
    -- GuildRosterSet*Note APIs work and the server still enforces permissions.
    local canPublic = type(CanEditPublicNote) ~= "function" or CanEditPublicNote()
    local canOfficer = canViewOfficer and (type(CanEditOfficerNote) ~= "function" or CanEditOfficerNote())
    frame.noteEditor.public:EnableMouse(canPublic and true or false)
    frame.noteEditor.officer:EnableMouse(canOfficer and true or false)
    frame.noteEditor.public:SetTextColor(canPublic and 1 or .6, canPublic and 1 or .6, canPublic and 1 or .6)
    frame.noteEditor.officer:SetTextColor(canOfficer and 1 or .6, canOfficer and 1 or .6, canOfficer and 1 or .6)
    SetButtonEnabled(frame.noteEditor.save, canPublic or canOfficer)
    frame.noteEditor:Show()
end

function Panels:CreateGuild()
    local frame = CreatePanel("ZenUIGuildFrame", "guild", "Guild")
    self.frames.guild = frame
    frame.offset = 0
    frame.selected = nil
    local guildSettings = GetSettings()
    frame.showOffline = not guildSettings or guildSettings.guildShowOffline ~= false

    frame.guildName = CreateText(frame.body, "Not in a guild", 13, "TOPLEFT", frame.body, "TOPLEFT", 2, -4, false)
    frame.motd = CreateText(frame.body, "", 9, "TOPLEFT", frame.guildName, "BOTTOMLEFT", 0, -5, true)
    frame.motd:SetWidth(650)
    frame.motd:SetJustifyH("LEFT")

    frame.offline = CreateCheck(frame.body, "Show offline", 522, -2, function(v)
        frame.showOffline = v
        local settings = GetSettings()
        if settings then settings.guildShowOffline = v and true or false end
        frame.offset = 0
        Panels:EnableFullGuildRoster(frame)
        if GuildRoster then SafeCall("refresh guild roster", GuildRoster) end
        Panels:RefreshGuild()
    end)
    frame.offline:SetRUIValue(frame.showOffline)

    frame.guildSettings = CreateButton(frame.body, "Guild Settings", 108, 22)
    frame.guildSettings:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -2, -24)
    frame.guildSettings:SetScript("OnClick", function() Panels:OpenGuildControl() end)
    frame.memberNotes = CreateButton(frame.body, "Member Notes", 104, 22)
    frame.memberNotes:SetPoint("RIGHT", frame.guildSettings, "LEFT", -6, 0)
    frame.memberNotes:SetScript("OnClick", function() Panels:OpenGuildNotes() end)

    -- Keep Social navigation available while viewing the guild roster. The
    -- guild content remains its own sized panel, but switching tabs no longer
    -- traps the user in a separate window with no way back.
    frame.friendsTab = CreateButton(frame, "Friends", 72, 22)
    frame.friendsTab:SetPoint("TOPRIGHT", frame.close, "TOPLEFT", -240, 0)
    frame.friendsTab:SetScript("OnClick", function() Panels:ToggleSocial(true, "friends", frame) end)
    frame.ignoreTab = CreateButton(frame, "Ignore", 72, 22)
    frame.ignoreTab:SetPoint("LEFT", frame.friendsTab, "RIGHT", 6, 0)
    frame.ignoreTab:SetScript("OnClick", function() Panels:ToggleSocial(true, "ignore", frame) end)
    frame.guildTab = CreateButton(frame, "Guild", 72, 22)
    frame.guildTab:SetPoint("LEFT", frame.ignoreTab, "RIGHT", 6, 0)
    frame.raidTab = CreateButton(frame, "Raid", 72, 22)
    frame.raidTab:SetPoint("LEFT", frame.guildTab, "RIGHT", 6, 0)
    frame.raidTab:SetScript("OnClick", function() Panels:ToggleRaid(true, frame) end)
    local gr, gg, gb = RUI:GetAccentColor()
    RUI:SetBorderColor(frame.guildTab, gr, gg, gb, 1)

    frame.header = CreateFrame("Frame", nil, frame.body)
    frame.header:SetHeight(22)
    frame.header:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -48)
    frame.header:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -2, -48)
    frame.hName = CreateText(frame.header, "NAME", 9, "LEFT", frame.header, "LEFT", 22, 0, true)
    frame.hLevel = CreateText(frame.header, "LVL", 9, "LEFT", frame.header, "LEFT", 200, 0, true)
    frame.hClass = CreateText(frame.header, "CLASS", 9, "LEFT", frame.header, "LEFT", 240, 0, true)
    frame.hZone = CreateText(frame.header, "ZONE", 9, "LEFT", frame.header, "LEFT", 335, 0, true)
    frame.hRank = CreateText(frame.header, "RANK", 9, "LEFT", frame.header, "LEFT", 485, 0, true)
    frame.hStatus = CreateText(frame.header, "STATUS", 9, "RIGHT", frame.header, "RIGHT", -10, 0, true)
    frame.hStatus:SetWidth(64)
    frame.hStatus:SetJustifyH("RIGHT")

    frame.list = CreateFrame("Frame", nil, frame.body)
    frame.list:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -70)
    frame.list:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -2, 84)
    RUI:CreateBackdrop(frame.list)
    frame.rows = {}
    for i = 1, 10 do
        local row = CreateListRow(frame.list, 648, 28)
        row:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 8, -8 - ((i - 1) * 30))
        row.presence = row:CreateTexture(nil, "ARTWORK")
        row.presence:SetWidth(6)
        row.presence:SetHeight(6)
        row.presence:SetPoint("LEFT", row, "LEFT", 9, 0)
        row.nameText = CreateText(row, "", 11, "LEFT", row, "LEFT", 22, 0, false); row.nameText:SetWidth(168)
        row.levelText = CreateText(row, "", 10, "LEFT", row, "LEFT", 200, 0, true); row.levelText:SetWidth(32)
        row.classText = CreateText(row, "", 10, "LEFT", row, "LEFT", 240, 0, true); row.classText:SetWidth(86)
        row.zoneText = CreateText(row, "", 10, "LEFT", row, "LEFT", 335, 0, true); row.zoneText:SetWidth(140)
        row.rankText = CreateText(row, "", 10, "LEFT", row, "LEFT", 485, 0, true); row.rankText:SetWidth(80)
        row.statusText = CreateText(row, "", 9, "RIGHT", row, "RIGHT", -10, 0, true); row.statusText:SetWidth(64); row.statusText:SetJustifyH("RIGHT")
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" and self.dataIndex then
                local name, rank, rankIndex, level, class, zone, note, officerNote, online = GetGuildRosterInfo(self.dataIndex)
                if name and online and ChatFrame_SendTell then ChatFrame_SendTell(name) end
                return
            end
            frame.selected = self.dataIndex
            if SetGuildRosterSelection and self.dataIndex then SetGuildRosterSelection(self.dataIndex) end
            Panels:RefreshGuild()
        end)
        frame.rows[i] = row
    end
    frame.list:EnableMouseWheel(true)
    frame.list:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = ClampOffset((frame.offset or 0) - delta, frame.total or 0, #frame.rows)
        Panels:RefreshGuild()
    end)

    -- One deliberate footer layout: the invite controls own the left side and
    -- the selected-member controls own the right side, with a guaranteed gap
    -- between the two groups at the Guild panel's normal width.
    frame.input = CreateEditBox(frame.body, 200, 25, "Invite player...")
    frame.input:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 44)
    frame.invite = CreateButton(frame.body, "Invite", 82, 25)
    frame.invite:SetPoint("LEFT", frame.input, "RIGHT", 8, 0)
    frame.invite:SetScript("OnClick", function()
        local name = frame.input:GetText()
        if name and name ~= "" and GuildInvite then GuildInvite(name); frame.input:SetText("") end
    end)
    frame.input:SetScript("OnEnterPressed", function(self) frame.invite:Click(); self:ClearFocus() end)
    frame.input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)

    frame.remove = CreateButton(frame.body, "Remove", 82, 25)
    frame.remove:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -2, 44)
    frame.demote = CreateButton(frame.body, "Demote", 82, 25)
    frame.demote:SetPoint("RIGHT", frame.remove, "LEFT", -6, 0)
    frame.promote = CreateButton(frame.body, "Promote", 82, 25)
    frame.promote:SetPoint("RIGHT", frame.demote, "LEFT", -6, 0)
    frame.whisper = CreateButton(frame.body, "Whisper", 82, 25)
    frame.whisper:SetPoint("RIGHT", frame.promote, "LEFT", -6, 0)
    frame.whisper:SetScript("OnClick", function()
        if not frame.selected then return end
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(frame.selected)
        if name and online and ChatFrame_SendTell then ChatFrame_SendTell(name) end
    end)
    frame.promote:SetScript("OnClick", function() if frame.selected then local name=GetGuildRosterInfo(frame.selected); if name and GuildPromote then GuildPromote(name) end end end)
    frame.demote:SetScript("OnClick", function() if frame.selected then local name=GetGuildRosterInfo(frame.selected); if name and GuildDemote then GuildDemote(name) end end end)
    -- Removing a guild member is destructive, so keep confirmation inside the
    -- Zen-owned panel instead of falling back to Blizzard's stock popup.
    frame.confirm = CreateFrame("Frame", nil, frame)
    frame.confirm:SetWidth(330)
    frame.confirm:SetHeight(118)
    frame.confirm:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.confirm:SetFrameLevel((tonumber(frame:GetFrameLevel()) or 1) + 50)
    frame.confirm:EnableMouse(true)
    RUI:CreateBackdrop(frame.confirm)
    frame.confirm.accent = RUI:CreateAccentLine(frame.confirm, 2)
    frame.confirm.title = CreateText(frame.confirm, "Remove guild member?", 12, "TOPLEFT", frame.confirm, "TOPLEFT", 14, -15, false)
    frame.confirm.text = CreateText(frame.confirm, "", 9, "TOPLEFT", frame.confirm.title, "BOTTOMLEFT", 0, -10, true)
    frame.confirm.text:SetWidth(300)
    frame.confirm.text:SetJustifyH("LEFT")
    frame.confirm.yes = CreateButton(frame.confirm, "Remove", 92, 24)
    frame.confirm.yes:SetPoint("BOTTOMRIGHT", frame.confirm, "BOTTOMRIGHT", -14, 12)
    frame.confirm.no = CreateButton(frame.confirm, "Cancel", 92, 24)
    frame.confirm.no:SetPoint("RIGHT", frame.confirm.yes, "LEFT", -8, 0)
    frame.confirm.no:SetScript("OnClick", function() frame.confirm:Hide(); frame.confirm.memberName=nil end)
    frame.confirm.yes:SetScript("OnClick", function()
        local name = frame.confirm.memberName
        frame.confirm:Hide()
        frame.confirm.memberName = nil
        if name and GuildUninvite then GuildUninvite(name) end
        frame.selected = nil
    end)
    frame.confirm:Hide()

    frame.noteEditor = CreateFrame("Frame", nil, frame)
    frame.noteEditor:SetWidth(430); frame.noteEditor:SetHeight(210)
    frame.noteEditor:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.noteEditor:SetFrameLevel((frame:GetFrameLevel() or 1) + 60)
    frame.noteEditor:EnableMouse(true); RUI:CreateBackdrop(frame.noteEditor)
    frame.noteEditor.accent = RUI:CreateAccentLine(frame.noteEditor, 2)
    frame.noteEditor.title = CreateText(frame.noteEditor, "Guild Notes", 12, "TOPLEFT", frame.noteEditor, "TOPLEFT", 14, -16, false)
    frame.noteEditor.publicLabel = CreateText(frame.noteEditor, "PUBLIC NOTE", 9, "TOPLEFT", frame.noteEditor, "TOPLEFT", 14, -48, true)
    frame.noteEditor.public = CreateEditBox(frame.noteEditor, 400, 28, "")
    frame.noteEditor.public:SetPoint("TOPLEFT", frame.noteEditor, "TOPLEFT", 14, -64)
    frame.noteEditor.officerLabel = CreateText(frame.noteEditor, "OFFICER NOTE", 9, "TOPLEFT", frame.noteEditor, "TOPLEFT", 14, -104, true)
    frame.noteEditor.officer = CreateEditBox(frame.noteEditor, 400, 28, "")
    frame.noteEditor.officer:SetPoint("TOPLEFT", frame.noteEditor, "TOPLEFT", 14, -120)
    frame.noteEditor.save = CreateButton(frame.noteEditor, "Save Notes", 106, 24)
    frame.noteEditor.save:SetPoint("BOTTOMRIGHT", frame.noteEditor, "BOTTOMRIGHT", -14, 14)
    frame.noteEditor.cancel = CreateButton(frame.noteEditor, "Cancel", 90, 24)
    frame.noteEditor.cancel:SetPoint("RIGHT", frame.noteEditor.save, "LEFT", -8, 0)
    frame.noteEditor.cancel:SetScript("OnClick", function() frame.noteEditor:Hide() end)
    frame.noteEditor.save:SetScript("OnClick", function()
        local idx = frame.noteEditor.memberIndex
        if not idx then return end
        if (type(CanEditPublicNote) ~= "function" or CanEditPublicNote()) and type(GuildRosterSetPublicNote) == "function" then
            pcall(GuildRosterSetPublicNote, idx, frame.noteEditor.public:GetText() or "")
        end
        if (type(CanViewOfficerNote) ~= "function" or CanViewOfficerNote()) and (type(CanEditOfficerNote) ~= "function" or CanEditOfficerNote()) and type(GuildRosterSetOfficerNote) == "function" then
            pcall(GuildRosterSetOfficerNote, idx, frame.noteEditor.officer:GetText() or "")
        end
        frame.noteEditor:Hide()
        if GuildRoster then pcall(GuildRoster) end
    end)
    frame.noteEditor:Hide()

    frame.remove:SetScript("OnClick", function()
        if not frame.selected then return end
        local name = GetGuildRosterInfo(frame.selected)
        if not name then return end
        frame.confirm.memberName = name
        frame.confirm.text:SetText("Remove " .. tostring(name) .. " from the guild?")
        frame.confirm:Show()
    end)
    frame.summary = CreateText(frame.body, "", 9, "BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 13, true)

    frame:SetScript("OnShow", function()
        Panels:HideOtherPanels(frame)
        HideStock(FriendsFrame)
        local settings = GetSettings()
        if settings and settings.guildShowOffline ~= nil then
            frame.showOffline = settings.guildShowOffline and true or false
            frame.offline:SetRUIValue(frame.showOffline)
        end
        Panels:EnableFullGuildRoster(frame)
        if GuildRoster then SafeCall("refresh guild roster", GuildRoster) end
        Panels:RefreshGuild()
    end)
    frame:SetScript("OnHide", function()
        if Panels.nativeGuildControlActive then Panels:RestoreGuildControlParent(true) end
        Panels:RestoreGuildRosterFilter(frame)
    end)
    return frame
end

function Panels:RefreshGuild()
    local frame = self.frames and self.frames.guild
    if not frame or not frame:IsShown() then return end
    local guildName = GetGuildInfo and GetGuildInfo("player")
    if not guildName then
        frame.guildName:SetText("Not in a guild")
        frame.motd:SetText("Join a guild to use the Zen roster.")
        frame.total = 0
        frame.memberIndices = {}
        for i = 1, #frame.rows do frame.rows[i]:Hide() end
        frame.summary:SetText("")
        SetButtonEnabled(frame.invite, false); SetButtonEnabled(frame.whisper, false); SetButtonEnabled(frame.promote, false); SetButtonEnabled(frame.demote, false); SetButtonEnabled(frame.remove, false)
        SetButtonEnabled(frame.memberNotes, false); SetButtonEnabled(frame.guildSettings, false)
        return
    end

    frame.guildName:SetText(guildName)
    local motd = GetGuildRosterMOTD and GetGuildRosterMOTD() or ""
    frame.motd:SetText(motd ~= "" and ("MOTD: " .. motd) or "No guild message of the day.")

    local rosterTotal = (GetNumGuildMembers and GetNumGuildMembers()) or 0
    rosterTotal = tonumber(rosterTotal) or 0
    local memberIndices, onlineCount = {}, 0
    for rosterIndex = 1, rosterTotal do
        local _, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(rosterIndex)
        if isOnline then onlineCount = onlineCount + 1 end
        if frame.showOffline or isOnline then table.insert(memberIndices, rosterIndex) end
    end
    frame.memberIndices = memberIndices
    frame.total = #memberIndices
    frame.offset = ClampOffset(frame.offset or 0, frame.total, #frame.rows)

    for i = 1, #frame.rows do
        local row = frame.rows[i]
        local visibleIndex = (frame.offset or 0) + i
        local rosterIndex = memberIndices[visibleIndex]
        if rosterIndex then
            local name, rank, rankIndex, level, class, zone, note, officerNote, isOnline, status, classFile = GetGuildRosterInfo(rosterIndex)
            row.dataIndex = rosterIndex
            row.nameText:SetText(name or "Unknown")
            row.levelText:SetText(level or "")
            row.classText:SetText(class or "")
            row.zoneText:SetText(zone or "")
            row.rankText:SetText(rank or "")
            local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
            local mr, mg, mb = RUI:GetTextColor(true)
            if isOnline then
                if color then row.nameText:SetTextColor(color.r, color.g, color.b, 1)
                else local nr,ng,nb=RUI:GetTextColor(false); row.nameText:SetTextColor(nr,ng,nb,1) end
                row.levelText:SetTextColor(mr, mg, mb, 0.95)
                row.classText:SetTextColor(mr, mg, mb, 0.95)
                row.zoneText:SetTextColor(mr, mg, mb, 0.95)
                row.rankText:SetTextColor(mr, mg, mb, 0.95)
                row.statusText:SetText("Online")
                row.statusText:SetTextColor(0.35, 1.00, 0.45, 1)
                row.presence:SetTexture(0.35, 1.00, 0.45, 1)
                if row.RUIBackground then row.RUIBackground:SetAlpha(0.38) end
            else
                row.nameText:SetTextColor(mr, mg, mb, 0.58)
                row.levelText:SetTextColor(mr, mg, mb, 0.42)
                row.classText:SetTextColor(mr, mg, mb, 0.42)
                row.zoneText:SetTextColor(mr, mg, mb, 0.42)
                row.rankText:SetTextColor(mr, mg, mb, 0.42)
                row.statusText:SetText("Offline")
                row.statusText:SetTextColor(mr, mg, mb, 0.58)
                row.presence:SetTexture(mr, mg, mb, 0.50)
                if row.RUIBackground then row.RUIBackground:SetAlpha(0.12) end
            end
            row.tooltipText = note
            row.RUIOnEnter = function(self)
                if self.tooltipText and self.tooltipText ~= "" and GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(self.tooltipText); GameTooltip:Show() end
            end
            row.RUIOnLeave = function() if GameTooltip then GameTooltip:Hide() end end
            SetSelectedRow(row, frame.selected == rosterIndex)
            row:Show()
        else row.dataIndex=nil; row:Hide() end
    end

    local selectedName, selectedOnline, selectedRankIndex
    if frame.selected then
        local sName, _, sRankIndex, _, _, _, _, _, sOnline = GetGuildRosterInfo(frame.selected)
        selectedName, selectedOnline, selectedRankIndex = sName, sOnline, sRankIndex
        if not selectedName then frame.selected = nil end
    end

    local _, _, playerGuildRankIndex = GetGuildInfo("player")
    playerGuildRankIndex = tonumber(playerGuildRankIndex) or 99
    selectedRankIndex = tonumber(selectedRankIndex)
    local canManageSelected = selectedName and selectedRankIndex and selectedRankIndex > playerGuildRankIndex

    local canInvite = (type(CanGuildInvite) ~= "function") or CanGuildInvite()
    local canPromote = (type(CanGuildPromote) ~= "function") or CanGuildPromote()
    local canDemote = (type(CanGuildDemote) ~= "function") or CanGuildDemote()
    local canRemove = (type(CanGuildRemove) ~= "function") or CanGuildRemove()
    SetButtonEnabled(frame.invite, canInvite)
    SetButtonEnabled(frame.whisper, selectedName and selectedOnline)
    SetButtonEnabled(frame.promote, canManageSelected and canPromote)
    SetButtonEnabled(frame.demote, canManageSelected and canDemote)
    SetButtonEnabled(frame.remove, canManageSelected and canRemove and selectedName ~= UnitName("player"))
    SetButtonEnabled(frame.memberNotes, selectedName ~= nil)
    SetButtonEnabled(frame.guildSettings, type(IsGuildLeader) ~= "function" or IsGuildLeader())
    frame.summary:SetText(tostring(rosterTotal) .. " members  •  " .. tostring(onlineCount) .. " online" .. (frame.showOffline and "" or "  •  online only") .. "  •  right-click whisper  •  Shift-click chat name to invite")
end

function Panels:ToggleGuild(forceShow, sourceFrame)
    local frame = self.frames.guild
    if frame:IsShown() and not forceShow then frame:Hide(); return end
    HideOtherSocialFamilyFrames(frame)
    HideStock(FriendsFrame)
    frame:Show()
end

-- -------------------------------------------------------------------------
-- Raid (the fifth Wrath Social tab)
-- -------------------------------------------------------------------------
local function GetRaidMemberCountCompat()
    if type(GetNumRaidMembers) == "function" then
        return tonumber(GetNumRaidMembers()) or 0
    end
    if type(IsInRaid) == "function" and IsInRaid() and type(GetNumGroupMembers) == "function" then
        return tonumber(GetNumGroupMembers()) or 0
    end
    return 0
end

local function GetPartyMemberCountCompat()
    if type(GetNumPartyMembers) == "function" then return tonumber(GetNumPartyMembers()) or 0 end
    if type(GetNumSubgroupMembers) == "function" then return tonumber(GetNumSubgroupMembers()) or 0 end
    return 0
end

local function CanManageRaid()
    if type(IsRaidLeader) == "function" and IsRaidLeader() then return true end
    if type(IsRaidOfficer) == "function" and IsRaidOfficer() then return true end
    return false
end

local function CanConvertPartyToRaid()
    if GetRaidMemberCountCompat() > 0 or GetPartyMemberCountCompat() <= 0 then return false end
    if type(IsPartyLeader) == "function" then return IsPartyLeader() and true or false end
    if type(UnitIsPartyLeader) == "function" then return UnitIsPartyLeader("player") and true or false end
    return false
end

local function GetGroupToolsSettings()
    if not RUI.db then return nil end
    RUI.db.groupTools = RUI.db.groupTools or { autoInvite = false, autoInviteTriggers = "inv" }
    if not RUI.db.groupTools.autoInviteTriggers or tostring(RUI.db.groupTools.autoInviteTriggers) == "" then
        RUI.db.groupTools.autoInviteTriggers = "inv"
    end
    return RUI.db.groupTools
end

local function IsPartyLeaderCompat()
    if GetPartyMemberCountCompat() <= 0 then return true end
    if type(IsPartyLeader) == "function" then return IsPartyLeader() and true or false end
    if type(UnitIsPartyLeader) == "function" then return UnitIsPartyLeader("player") and true or false end
    return false
end

local function CanInviteCurrentGroup()
    if GetRaidMemberCountCompat() > 0 then return CanManageRaid() end
    return IsPartyLeaderCompat()
end

local function NormalizeInviteName(name)
    local value = tostring(name or "")
    local short = string.match(value, "^([^%-]+)") or value
    return string.lower(short)
end

local function TrimInviteText(value)
    local text = tostring(value or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function ParseInviteTriggers(value)
    local source = tostring(value or "inv")
    source = string.gsub(source, "[\r\n;]+", ",")
    local triggers, seen = {}, {}
    for token in string.gmatch(source .. ",", "(.-),") do
        local cleaned = string.lower(TrimInviteText(token))
        if cleaned ~= "" and not seen[cleaned] then
            seen[cleaned] = true
            table.insert(triggers, cleaned)
            if #triggers >= 20 then break end
        end
    end
    if #triggers == 0 then triggers[1] = "inv" end
    return triggers
end

local function WhisperRequestsInvite(message)
    local clean = string.lower(TrimInviteText(message))
    if clean == "" then return false end
    local settings = GetGroupToolsSettings()
    local triggers = ParseInviteTriggers(settings and settings.autoInviteTriggers or "inv")
    for i = 1, #triggers do
        local trigger = triggers[i]
        -- Every configured entry can be sent as the complete whisper. Preserve
        -- Zen's original convenience behavior for the legacy "inv" trigger,
        -- which also matches as a standalone word inside a longer whisper.
        if clean == trigger then return true end
        if trigger == "inv" then
            local padded = " " .. clean .. " "
            if string.find(padded, "[^%w_]inv[^%w_]") then return true end
        end
    end
    return false
end

local function IsNameInCurrentGroup(name)
    local target = NormalizeInviteName(name)
    if target == "" then return false end
    if NormalizeInviteName(UnitName and UnitName("player")) == target then return true end

    local raidCount = GetRaidMemberCountCompat()
    if raidCount > 0 and type(GetRaidRosterInfo) == "function" then
        for i = 1, raidCount do
            local memberName = GetRaidRosterInfo(i)
            if NormalizeInviteName(memberName) == target then return true end
        end
        return false
    end

    local partyCount = GetPartyMemberCountCompat()
    if type(UnitName) == "function" then
        for i = 1, partyCount do
            local memberName = UnitName("party" .. tostring(i))
            if NormalizeInviteName(memberName) == target then return true end
        end
    end
    return false
end

function Panels:StopAutoInviteWorker()
    if self.autoInviteWorker then
        self.autoInviteWorker:Hide()
        self.autoInviteWorker.elapsed = 0
    end
end

function Panels:ClearAutoInviteQueue()
    self.autoInviteQueue = {}
    self.autoInviteQueued = {}
    self:StopAutoInviteWorker()
end

function Panels:QueueAutoInviteName(name)
    if not name or name == "" or IsNameInCurrentGroup(name) then return false end
    self.autoInviteQueue = self.autoInviteQueue or {}
    self.autoInviteQueued = self.autoInviteQueued or {}
    local key = NormalizeInviteName(name)
    if key == "" or self.autoInviteQueued[key] then return false end
    if #self.autoInviteQueue >= 40 then return false end
    self.autoInviteQueued[key] = true
    table.insert(self.autoInviteQueue, name)
    return true
end

function Panels:EnsureAutoInviteWorker()
    if self.autoInviteWorker then return self.autoInviteWorker end
    local worker = CreateFrame("Frame", nil, UIParent)
    worker.elapsed = 0
    worker:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        if self.elapsed < 0.25 then return end
        self.elapsed = 0
        Panels:ProcessAutoInviteQueue()
    end)
    worker:Hide()
    self.autoInviteWorker = worker
    return worker
end

function Panels:StartAutoInviteWorker(immediate)
    local worker = self:EnsureAutoInviteWorker()
    if not worker then return end
    worker.elapsed = immediate and 0.25 or 0
    worker:Show()
end

function Panels:ProcessAutoInviteQueue()
    local settings = GetGroupToolsSettings()
    if not settings or settings.autoInvite ~= true then self:ClearAutoInviteQueue(); return end
    local queue = self.autoInviteQueue or {}
    if #queue == 0 then self:StopAutoInviteWorker(); return end
    if type(InviteUnit) ~= "function" or not CanInviteCurrentGroup() then self:StopAutoInviteWorker(); return end

    local raidCount = GetRaidMemberCountCompat()
    if raidCount > 0 then
        if raidCount >= 40 then
            self:StopAutoInviteWorker()
            return
        end
    else
        local partyCount = GetPartyMemberCountCompat()
        if partyCount >= 4 then
            self:StopAutoInviteWorker()
            self:ShowAutoInviteRaidPrompt(false)
            return
        end
    end

    local name = table.remove(queue, 1)
    if not name then self:StopAutoInviteWorker(); return end
    self.autoInviteQueued[NormalizeInviteName(name)] = nil
    if not IsNameInCurrentGroup(name) then
        SafeCall("auto invite " .. tostring(name), InviteUnit, name)
    end
    if #queue == 0 then self:StopAutoInviteWorker() end
end

function Panels:FlushAutoInviteQueue()
    local settings = GetGroupToolsSettings()
    if not settings or settings.autoInvite ~= true then self:ClearAutoInviteQueue(); return end
    if #(self.autoInviteQueue or {}) > 0 then self:StartAutoInviteWorker(true) end
end

function Panels:EnsureAutoInviteRaidPopup()
    if not StaticPopupDialogs or not StaticPopup_Show then return false end
    if not StaticPopupDialogs.ZEN_AUTO_INVITE_CONVERT_RAID then
        StaticPopupDialogs.ZEN_AUTO_INVITE_CONVERT_RAID = {
            text = "Your party is full. Convert it to a raid so Auto Invite can keep accepting configured whisper requests?",
            button1 = "Convert to Raid",
            button2 = "Stay as Party",
            OnAccept = function() Panels:AcceptAutoInviteRaidConversion() end,
            OnCancel = function() Panels:DeclineAutoInviteRaidConversion() end,
            OnHide = function() Panels.autoInvitePromptShown = nil end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
    end
    return true
end

function Panels:ShowAutoInviteRaidPrompt(force)
    local settings = GetGroupToolsSettings()
    if not settings or settings.autoInvite ~= true then return false end
    if GetRaidMemberCountCompat() > 0 or GetPartyMemberCountCompat() < 4 then return false end
    if not CanConvertPartyToRaid() then return false end
    if self.autoInvitePromptShown then return true end
    if self.fullPartyPromptDismissed and not force then return false end
    if not self:EnsureAutoInviteRaidPopup() then return false end

    self.autoInvitePromptShown = true
    local popup = StaticPopup_Show("ZEN_AUTO_INVITE_CONVERT_RAID")
    if not popup then
        self.autoInvitePromptShown = nil
        return false
    end
    return true
end

function Panels:AcceptAutoInviteRaidConversion()
    self.autoInvitePromptShown = nil
    self.fullPartyPromptDismissed = nil
    if not CanConvertPartyToRaid() or type(ConvertToRaid) ~= "function" then
        self.pendingAutoInviteRaidConversion = nil
        RUI:Print("Auto Invite could not convert this party to a raid.")
        return false
    end

    self.pendingAutoInviteRaidConversion = true
    local ok = SafeCall("auto-invite convert to raid", ConvertToRaid)
    if ok then return true end
    self.pendingAutoInviteRaidConversion = nil
    return false
end

function Panels:DeclineAutoInviteRaidConversion()
    self.autoInvitePromptShown = nil
    self.fullPartyPromptDismissed = true
    self.pendingAutoInviteRaidConversion = nil
    self:ClearAutoInviteQueue()
end

function Panels:RefreshAutoInviteButton()
    local frame = self.frames and self.frames.raid
    if not frame or not frame.autoInvite then return end
    local settings = GetGroupToolsSettings()
    local enabled = settings and settings.autoInvite == true
    local button = frame.autoInvite

    button.RUIText:SetText(enabled and "Auto Invite: ON" or "Auto Invite: OFF")
    if enabled then
        local ar, ag, ab = RUI:GetAccentColor()
        if button.RUIActiveFill then
            button.RUIActiveFill:SetTexture(ar, ag, ab, 0.96)
            button.RUIActiveFill:Show()
        end
        RUI:SetBorderColor(button, ar, ag, ab, 1)
        button.RUIText:SetTextColor(0.04, 0.04, 0.04, 1)
    else
        if button.RUIActiveFill then button.RUIActiveFill:Hide() end
        RUI:RefreshBackdrop(button)
        local tr, tg, tb = RUI:GetTextColor(false)
        button.RUIText:SetTextColor(tr, tg, tb, 1)
    end
end

function Panels:SetAutoInviteEnabled(enabled)
    local settings = GetGroupToolsSettings()
    if not settings then return false end
    settings.autoInvite = enabled and true or false

    if not settings.autoInvite then
        self.pendingAutoInviteRaidConversion = nil
        self.fullPartyPromptDismissed = nil
        self:ClearAutoInviteQueue()
        if self.autoInvitePromptShown and type(StaticPopup_Hide) == "function" then
            StaticPopup_Hide("ZEN_AUTO_INVITE_CONVERT_RAID")
        end
        RUI:Print("Auto Invite disabled.")
    else
        RUI:Print("Auto Invite enabled. Configure whisper triggers in /zenui > Auto Invite.")
        if GetPartyMemberCountCompat() >= 4 and GetRaidMemberCountCompat() <= 0 then
            self:ShowAutoInviteRaidPrompt(false)
        end
    end

    self:RefreshAutoInviteButton()
    local quickMenu = RUI:GetModule("MicroMenu")
    if quickMenu and quickMenu.RefreshQuickMenuState then quickMenu:RefreshQuickMenuState() end
    return true
end

function Panels:HandleAutoInviteWhisper(message, sender)
    local settings = GetGroupToolsSettings()
    if not settings or settings.autoInvite ~= true or not WhisperRequestsInvite(message) then return end
    if not sender or sender == "" or IsNameInCurrentGroup(sender) then return end
    if NormalizeInviteName(sender) == NormalizeInviteName(UnitName and UnitName("player")) then return end

    self.recentAutoInviteRequests = self.recentAutoInviteRequests or {}
    local key = NormalizeInviteName(sender)
    local now = (type(GetTime) == "function" and GetTime()) or 0
    local previous = self.recentAutoInviteRequests[key]
    if previous and now > 0 and (now - previous) < 5 then return end
    self.recentAutoInviteRequests[key] = now

    local raidCount = GetRaidMemberCountCompat()
    if raidCount >= 40 then
        RUI:Print("Auto Invite: raid is full; could not invite " .. tostring(sender) .. ".")
        return
    end
    if not CanInviteCurrentGroup() then
        RUI:Print("Auto Invite: leader or assistant permission is required to invite " .. tostring(sender) .. ".")
        return
    end

    if not self:QueueAutoInviteName(sender) then return end
    if raidCount <= 0 and GetPartyMemberCountCompat() >= 4 then
        self:ShowAutoInviteRaidPrompt(true)
        return
    end

    -- Always use the paced queue, even when there is room right now. Some
    -- Ebonhold clients drop a second InviteUnit fired immediately after the
    -- first; spacing requests by a quarter-second keeps rapid whispers reliable.
    self:StartAutoInviteWorker(true)
end

function Panels:HandleAutoInviteGroupChanged()
    local settings = GetGroupToolsSettings()
    if not settings or settings.autoInvite ~= true then return end

    local raidCount = GetRaidMemberCountCompat()
    if raidCount > 0 then
        self.fullPartyPromptDismissed = nil
        if self.autoInvitePromptShown and type(StaticPopup_Hide) == "function" then
            StaticPopup_Hide("ZEN_AUTO_INVITE_CONVERT_RAID")
        end
        if self.pendingAutoInviteRaidConversion or #(self.autoInviteQueue or {}) > 0 then
            self.pendingAutoInviteRaidConversion = nil
            self:FlushAutoInviteQueue()
        end
        return
    end

    local partyCount = GetPartyMemberCountCompat()
    if partyCount < 4 then
        self.fullPartyPromptDismissed = nil
        if self.autoInvitePromptShown and type(StaticPopup_Hide) == "function" then
            StaticPopup_Hide("ZEN_AUTO_INVITE_CONVERT_RAID")
        end
        if #(self.autoInviteQueue or {}) > 0 then self:FlushAutoInviteQueue() end
        return
    end

    self:ShowAutoInviteRaidPrompt(false)
end

local function FindRaidMemberIndexByName(targetName)
    if not targetName or targetName == "" or type(GetRaidRosterInfo) ~= "function" then return nil end
    local total = GetRaidMemberCountCompat()
    for i = 1, total do
        local name = GetRaidRosterInfo(i)
        if name == targetName then return i end
    end
    return nil
end

local function GetRaidGroupCounts()
    local counts = { 0, 0, 0, 0, 0, 0, 0, 0 }
    if type(GetRaidRosterInfo) ~= "function" then return counts end
    local total = GetRaidMemberCountCompat()
    for i = 1, total do
        local _, _, subgroup = GetRaidRosterInfo(i)
        subgroup = tonumber(subgroup)
        if subgroup and subgroup >= 1 and subgroup <= 8 then
            counts[subgroup] = (counts[subgroup] or 0) + 1
        end
    end
    return counts
end

local function RaidGroupMoveAvailable()
    if not CanManageRaid() then return false end
    if type(SetRaidSubgroup) ~= "function" then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    return true
end

local function FormatRaidReset(seconds)
    seconds = tonumber(seconds) or 0
    if type(SecondsToTime) == "function" then
        local ok, text = pcall(SecondsToTime, seconds, false, false, 2)
        if ok and text and text ~= "" then return text end
    end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    if days > 0 then return tostring(days) .. "d " .. tostring(hours) .. "h" end
    if hours > 0 then return tostring(hours) .. "h " .. tostring(mins) .. "m" end
    return tostring(math.max(0, mins)) .. "m"
end

local RAID_DIFFICULTY_FALLBACK = {
    [3] = "10 Player",
    [4] = "25 Player",
    [5] = "10 Player Heroic",
    [6] = "25 Player Heroic",
}

local function HasResetInstancesAPI()
    return type(ResetInstances) == "function"
end

-- Project Ebonhold replaces normal raid-ID resets with a custom "Clear IDs"
-- control on the stock Social -> Raid panel.  We intentionally proxy that
-- native control instead of guessing the server's private API, preserving the
-- server-owned Soul Ash cost, confirmation and eligibility checks.
local function CleanControlText(text)
    text = tostring(text or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, "%s+", " ")
    return string.lower(text)
end

local function GetControlText(control)
    if not control then return "" end
    if type(control.GetText) == "function" then
        local ok, text = pcall(control.GetText, control)
        if ok and text and text ~= "" then return tostring(text) end
    end
    local candidates = { control.Text, control.text, control.RUIText, control.Label, control.label }
    for i = 1, #candidates do
        local fs = candidates[i]
        if fs and type(fs.GetText) == "function" then
            local ok, text = pcall(fs.GetText, fs)
            if ok and text and text ~= "" then return tostring(text) end
        end
    end
    return ""
end

local function IsClearIDsButton(control)
    if not control then return false end
    local ok, objectType = pcall(function() return control:GetObjectType() end)
    if not ok or objectType ~= "Button" then return false end
    local text = CleanControlText(GetControlText(control))
    return text == "clear ids" or text == "clear id" or string.find(text, "clear ids", 1, true) ~= nil
end

local function FindClearIDsInChildren(root, depth, seen)
    if not root or (depth or 0) > 10 then return nil end
    seen = seen or {}
    if seen[root] then return nil end
    seen[root] = true
    if IsClearIDsButton(root) then return root end
    if type(root.GetChildren) ~= "function" then return nil end
    local children = { root:GetChildren() }
    for i = 1, #children do
        local found = FindClearIDsInChildren(children[i], (depth or 0) + 1, seen)
        if found then return found end
    end
    return nil
end

function Panels:FindEbonholdClearIDsButton(forceRescan)
    local cached = self.ebonholdClearIDsButton
    if not forceRescan and cached and IsClearIDsButton(cached) then return cached end
    self.ebonholdClearIDsButton = nil

    -- Search the expected Social/Raid hierarchy first. This also finds unnamed
    -- buttons injected as children by a custom client patch.
    local roots = { _G.RaidFrame, _G.FriendsFrame, _G.RaidInfoFrame }
    for i = 1, #roots do
        local found = FindClearIDsInChildren(roots[i], 0, {})
        if found then self.ebonholdClearIDsButton = found; return found end
    end

    -- Fallback for Ebonhold implementations that parent the button elsewhere.
    -- This scan only identifies Button objects whose visible label is Clear IDs;
    -- it never invokes arbitrary globals/functions by name.
    for _, object in pairs(_G) do
        local kind = type(object)
        if (kind == "table" or kind == "userdata") then
            local ok = pcall(function() return object.GetObjectType end)
            if ok and IsClearIDsButton(object) then
                self.ebonholdClearIDsButton = object
                return object
            end
        end
    end
    return nil
end


function Panels:ForceHideEbonholdStockSocial(restoreRaid)
    local stock = _G.FriendsFrame
    if stock then
        -- HideUIPanel alone is not reliable on every 3.3.5/private-server
        -- client.  Force the frame hidden as well so the temporary Ebonhold
        -- bridge can never leak the restored Friends tab onto the screen.
        if type(HideUIPanel) == "function" then pcall(HideUIPanel, stock) end
        if type(stock.Hide) == "function" then stock:Hide() end
    end
    if _G.RaidFrame and type(_G.RaidFrame.Hide) == "function" then
        _G.RaidFrame:Hide()
    end

    if restoreRaid and IsEnabled("social") and self.frames and self.frames.raid then
        self:HideOtherPanels(self.frames.raid)
        self:ApplyPanelScale("raid")
        if not self.frames.raid:IsShown() then self.frames.raid:Show() end
        self:RefreshRaid()
    end
end

function Panels:QueueEbonholdStockSocialSuppress(restoreRaid)
    if not self.ebonholdSocialSuppressor then
        local guard = CreateFrame("Frame", nil, UIParent)
        guard:Hide()
        guard:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + (elapsed or 0)
            if self.elapsed < 0.02 then return end
            self.elapsed = 0
            self.passes = (self.passes or 1) - 1
            Panels:ForceHideEbonholdStockSocial(self.restoreRaid)
            if self.passes <= 0 then self:Hide() end
        end)
        self.ebonholdSocialSuppressor = guard
    end
    local guard = self.ebonholdSocialSuppressor
    guard.elapsed = 0
    guard.passes = 4
    guard.restoreRaid = restoreRaid and true or false
    guard:Show()
end

local function OpenEbonholdRaidPageHidden(owner)
    local stock = _G.FriendsFrame
    local raid = _G.RaidFrame
    if not stock then return nil end

    local state = {
        stock = stock,
        raid = raid,
        stockAlpha = type(stock.GetAlpha) == "function" and stock:GetAlpha() or 1,
        raidAlpha = raid and type(raid.GetAlpha) == "function" and raid:GetAlpha() or 1,
        selectedTab = stock.selectedTab,
    }
    if type(PanelTemplates_GetSelectedTab) == "function" then
        local ok, selected = pcall(PanelTemplates_GetSelectedTab, stock)
        if ok and selected then state.selectedTab = selected end
    end

    owner.ebonholdDiscoveryActive = true
    if type(stock.SetAlpha) == "function" then stock:SetAlpha(0) end
    if raid and type(raid.SetAlpha) == "function" then raid:SetAlpha(0) end

    local opened = false
    if type(owner.originalToggleFriendsFrame) == "function" then
        local ok = pcall(owner.originalToggleFriendsFrame, 5)
        opened = ok and true or false
    end

    if not opened then
        if type(PanelTemplates_SetTab) == "function" then pcall(PanelTemplates_SetTab, stock, 5) end
        stock.selectedTab = 5
        if type(ShowUIPanel) == "function" then
            pcall(ShowUIPanel, stock)
        elseif type(stock.Show) == "function" then
            stock:Show()
        end
        if type(FriendsFrame_ShowSubFrame) == "function" then
            pcall(FriendsFrame_ShowSubFrame, "RaidFrame")
        elseif raid and type(raid.Show) == "function" then
            raid:Show()
        end
    end

    -- Some Ebonhold clients build the custom controls from the RaidFrame's
    -- actual Show/OnShow path rather than FriendsFrame's tab change alone.
    if raid and not raid:IsShown() and type(raid.Show) == "function" then raid:Show() end
    if type(FriendsFrame_Update) == "function" then pcall(FriendsFrame_Update) end
    if type(RaidFrame_Update) == "function" then pcall(RaidFrame_Update) end

    return state
end

local function CloseEbonholdRaidPageHidden(owner, state)
    if not state then
        owner.ebonholdDiscoveryActive = false
        return
    end

    local stock, raid = state.stock, state.raid
    if raid and type(raid.Hide) == "function" then raid:Hide() end
    if stock then
        if type(HideUIPanel) == "function" then pcall(HideUIPanel, stock) end
        if type(stock.Hide) == "function" then stock:Hide() end
    end

    if stock and type(stock.SetAlpha) == "function" then stock:SetAlpha(state.stockAlpha or 1) end
    if raid and type(raid.SetAlpha) == "function" then raid:SetAlpha(state.raidAlpha or 1) end

    if stock and state.selectedTab then
        stock.selectedTab = state.selectedTab
        if type(PanelTemplates_SetTab) == "function" then pcall(PanelTemplates_SetTab, stock, state.selectedTab) end
    end

    owner.ebonholdDiscoveryActive = false
    owner:ForceHideEbonholdStockSocial(true)
    owner:QueueEbonholdStockSocialSuppress(true)
end

function Panels:BootstrapEbonholdRaidControl()
    local found = self:FindEbonholdClearIDsButton(true)
    if found then return found end

    local state = OpenEbonholdRaidPageHidden(self)
    found = self:FindEbonholdClearIDsButton(true)
    if found then self.ebonholdClearIDsButton = found end
    CloseEbonholdRaidPageHidden(self, state)
    return found
end

function Panels:RunEbonholdClearIDs()
    if GetRaidMemberCountCompat() > 0 or GetPartyMemberCountCompat() > 0 then
        RUI:Print("Project Ebonhold Clear IDs requires you to leave your group first.")
        return false
    end

    -- Execute the Ebonhold button while its real stock Raid page is genuinely
    -- shown, but with the entire stock UI at alpha 0.  This matters on clients
    -- where the custom OnClick checks live frame state or where its server hook
    -- is only attached while the Raid page is active.
    local state = OpenEbonholdRaidPageHidden(self)
    local button = self:FindEbonholdClearIDsButton(true)

    if not button then
        CloseEbonholdRaidPageHidden(self, state)
        RUI:Print("Project Ebonhold Clear IDs control could not be initialized on this client.")
        return false
    end

    self.ebonholdClearIDsButton = button
    local action = type(button.GetScript) == "function" and button:GetScript("OnClick") or nil
    local invoked = false

    -- Keep the call in Zen's hardware click stack and while Ebonhold's
    -- native button is live/visible (although transparent).  Do not pre-gate
    -- on IsEnabled; Ebonhold's own action owns Soul Ash and eligibility checks.
    if type(action) == "function" then
        action(button, "LeftButton")
        invoked = true
    elseif type(button.Click) == "function" then
        button:Click("LeftButton")
        invoked = true
    end

    CloseEbonholdRaidPageHidden(self, state)

    if invoked then return true end
    RUI:Print("Project Ebonhold Clear IDs was found, but its native click action could not be invoked.")
    return false
end

local function IsSavedRaidCompat(difficulty, isRaid, maxPlayers)
    if isRaid then return true end
    if (tonumber(maxPlayers) or 0) > 5 then return true end
    local diff = tonumber(difficulty)
    -- Wrath raid difficulties are 3-6. Some private-server clients omit the
    -- later isRaid/maxPlayers return values, so difficulty is the final fallback.
    return diff and diff >= 3 and diff <= 6 or false
end

function Panels:GetSavedRaidLockouts()
    local entries = {}
    if type(GetNumSavedInstances) ~= "function" or type(GetSavedInstanceInfo) ~= "function" then
        return entries
    end

    local okCount, count = pcall(GetNumSavedInstances)
    count = okCount and tonumber(count) or 0
    for i = 1, count do
        local ok, name, id, reset, difficulty, locked, extended, _, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = pcall(GetSavedInstanceInfo, i)
        if ok and name and IsSavedRaidCompat(difficulty, isRaid, maxPlayers) then
            local diff = tonumber(difficulty)
            local progress = ""
            if tonumber(numEncounters) and tonumber(numEncounters) > 0 then
                progress = tostring(tonumber(encounterProgress) or 0) .. " / " .. tostring(tonumber(numEncounters))
            end
            local state
            if extended then
                state = "Extended"
            elseif locked == false then
                state = "Historic"
            else
                -- GetSavedInstanceInfo represents a saved lockout. Older/private
                -- clients sometimes omit the explicit locked boolean, so nil is
                -- treated as locked rather than silently dropping the entry.
                state = "Locked"
            end
            table.insert(entries, {
                index = i,
                name = name or "Unknown instance",
                id = id,
                reset = tonumber(reset) or 0,
                difficultyName = difficultyName or RAID_DIFFICULTY_FALLBACK[diff] or (diff and ("Difficulty " .. tostring(diff)) or "Raid"),
                state = state,
                progress = progress,
                locked = locked ~= false,
                extended = extended and true or false,
            })
        end
    end
    return entries
end

function Panels:RequestRaidLockoutRefresh()
    local frame = self.frames and self.frames.raid
    if type(RequestRaidInfo) == "function" then SafeCall("request raid info", RequestRaidInfo) end
    if frame then
        -- UPDATE_INSTANCE_INFO should refresh this normally, but several 3.3.5
        -- private-server cores are inconsistent about firing it. Poll briefly
        -- after the request so lockouts still populate reliably.
        frame.raidInfoPollElapsed = 0
        frame.raidInfoPolls = 6
    end
end

function Panels:CreateRaid()
    local frame = CreatePanel("ZenUIRaidFrame", "raid", "Raid")
    self.frames.raid = frame
    frame.offset = 0
    frame.selected = nil
    frame.infoMode = false

    -- Social-system navigation. Raid shares the Social mover and scale.
    frame.friendsTab = CreateButton(frame, "Friends", 72, 22)
    frame.friendsTab:SetPoint("TOPRIGHT", frame.close, "TOPLEFT", -240, 0)
    frame.friendsTab:SetScript("OnClick", function() Panels:ToggleSocial(true, "friends", frame) end)
    frame.ignoreTab = CreateButton(frame, "Ignore", 72, 22)
    frame.ignoreTab:SetPoint("LEFT", frame.friendsTab, "RIGHT", 6, 0)
    frame.ignoreTab:SetScript("OnClick", function() Panels:ToggleSocial(true, "ignore", frame) end)
    frame.guildTab = CreateButton(frame, "Guild", 72, 22)
    frame.guildTab:SetPoint("LEFT", frame.ignoreTab, "RIGHT", 6, 0)
    frame.guildTab:SetScript("OnClick", function() Panels:ToggleGuild(true, frame) end)
    frame.raidTab = CreateButton(frame, "Raid", 72, 22)
    frame.raidTab:SetPoint("LEFT", frame.guildTab, "RIGHT", 6, 0)
    local ar, ag, ab = RUI:GetAccentColor()
    RUI:SetBorderColor(frame.raidTab, ar, ag, ab, 1)

    frame.status = CreateText(frame.body, "", 11, "TOPLEFT", frame.body, "TOPLEFT", 2, -5, false)
    frame.status:SetWidth(392)
    frame.infoToggle = CreateButton(frame.body, "Raid Info", 110, 24)
    frame.infoToggle:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -2, -1)
    frame.resetInstances = CreateButton(frame.body, "Reset Instances", 118, 24)
    frame.resetInstances:SetPoint("RIGHT", frame.infoToggle, "LEFT", -8, 0)
    frame.infoToggle:SetScript("OnClick", function()
        frame.infoMode = not frame.infoMode
        frame.offset = 0
        frame.selected = nil
        frame.selectedName = nil
        if frame.groupPicker then frame.groupPicker:Hide() end
        if frame.infoMode then Panels:RequestRaidLockoutRefresh() end
        Panels:RefreshRaid()
    end)

    -- Project Ebonhold uses its own Clear IDs flow rather than ResetInstances().
    -- Proxy the hidden stock button so Ebonhold keeps ownership of Soul Ash
    -- pricing, the native confirmation and server-side validation.
    frame.resetInstances.RUIText:SetText("Clear IDs")
    frame.resetInstances:SetScript("OnClick", function()
        Panels:RunEbonholdClearIDs()
    end)
    frame.resetInstances:Enable()
    if frame.resetInstances.RUIText then
        local rr, rg, rb = RUI:GetTextColor(false)
        frame.resetInstances.RUIText:SetTextColor(rr, rg, rb, 1)
    end

    frame.header = CreateFrame("Frame", nil, frame.body)
    frame.header:SetHeight(22)
    frame.header:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -42)
    frame.header:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -2, -42)
    frame.hGroup = CreateText(frame.header, "GROUP", 9, "LEFT", frame.header, "LEFT", 22, 0, true)
    frame.hName = CreateText(frame.header, "NAME", 9, "LEFT", frame.header, "LEFT", 72, 0, true)
    frame.hLevel = CreateText(frame.header, "LVL", 9, "LEFT", frame.header, "LEFT", 235, 0, true)
    frame.hClass = CreateText(frame.header, "CLASS", 9, "LEFT", frame.header, "LEFT", 275, 0, true)
    frame.hZone = CreateText(frame.header, "ZONE", 9, "LEFT", frame.header, "LEFT", 375, 0, true)
    frame.hRole = CreateText(frame.header, "ROLE", 9, "LEFT", frame.header, "LEFT", 515, 0, true)
    frame.hStatus = CreateText(frame.header, "STATUS", 9, "RIGHT", frame.header, "RIGHT", -10, 0, true)
    frame.hStatus:SetWidth(64); frame.hStatus:SetJustifyH("RIGHT")

    frame.list = CreateFrame("Frame", nil, frame.body)
    frame.list:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -64)
    frame.list:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -2, 82)
    RUI:CreateBackdrop(frame.list)
    frame.rows = {}
    for i = 1, 10 do
        local row = CreateListRow(frame.list, 648, 28)
        row:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 8, -8 - ((i - 1) * 30))
        row.presence = row:CreateTexture(nil, "ARTWORK"); row.presence:SetWidth(6); row.presence:SetHeight(6); row.presence:SetPoint("LEFT", row, "LEFT", 9, 0)
        row.groupText = CreateText(row, "", 10, "LEFT", row, "LEFT", 22, 0, true); row.groupText:SetWidth(42)
        row.nameText = CreateText(row, "", 11, "LEFT", row, "LEFT", 72, 0, false); row.nameText:SetWidth(153)
        row.levelText = CreateText(row, "", 10, "LEFT", row, "LEFT", 235, 0, true); row.levelText:SetWidth(32)
        row.classText = CreateText(row, "", 10, "LEFT", row, "LEFT", 275, 0, true); row.classText:SetWidth(92)
        row.zoneText = CreateText(row, "", 10, "LEFT", row, "LEFT", 375, 0, true); row.zoneText:SetWidth(132)
        row.roleText = CreateText(row, "", 9, "LEFT", row, "LEFT", 515, 0, true); row.roleText:SetWidth(66)
        row.statusText = CreateText(row, "", 9, "RIGHT", row, "RIGHT", -10, 0, true); row.statusText:SetWidth(64); row.statusText:SetJustifyH("RIGHT")
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" and self.dataIndex then
                local name, _, _, _, _, _, _, online = GetRaidRosterInfo(self.dataIndex)
                if name and online and ChatFrame_SendTell then ChatFrame_SendTell(name) end
                return
            end
            frame.selected = self.dataIndex
            local selectedName = self.dataIndex and GetRaidRosterInfo(self.dataIndex)
            frame.selectedName = selectedName
            if frame.groupPicker then frame.groupPicker:Hide() end
            Panels:RefreshRaid()
        end)
        frame.rows[i] = row
    end
    frame.list:EnableMouseWheel(true)
    frame.list:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = ClampOffset((frame.offset or 0) - delta, frame.total or 0, #frame.rows)
        Panels:RefreshRaid()
    end)

    frame.infoList = CreateFrame("Frame", nil, frame.body)
    frame.infoList:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -64)
    frame.infoList:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -2, 82)
    RUI:CreateBackdrop(frame.infoList)
    frame.infoHeader = CreateFrame("Frame", nil, frame.body)
    frame.infoHeader:SetHeight(22)
    frame.infoHeader:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -42)
    frame.infoHeader:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -2, -42)
    frame.iName = CreateText(frame.infoHeader, "INSTANCE", 9, "LEFT", frame.infoHeader, "LEFT", 12, 0, true)
    frame.iDiff = CreateText(frame.infoHeader, "DIFFICULTY", 9, "LEFT", frame.infoHeader, "LEFT", 292, 0, true)
    frame.iLock = CreateText(frame.infoHeader, "LOCK", 9, "LEFT", frame.infoHeader, "LEFT", 430, 0, true)
    frame.iReset = CreateText(frame.infoHeader, "RESET", 9, "RIGHT", frame.infoHeader, "RIGHT", -12, 0, true); frame.iReset:SetWidth(112); frame.iReset:SetJustifyH("RIGHT")
    frame.infoRows = {}
    for i = 1, 10 do
        local row = CreateListRow(frame.infoList, 648, 28)
        row:SetPoint("TOPLEFT", frame.infoList, "TOPLEFT", 8, -8 - ((i - 1) * 30))
        row.nameText = CreateText(row, "", 10, "LEFT", row, "LEFT", 12, 0, false); row.nameText:SetWidth(270)
        row.diffText = CreateText(row, "", 9, "LEFT", row, "LEFT", 292, 0, true); row.diffText:SetWidth(130)
        row.lockText = CreateText(row, "", 9, "LEFT", row, "LEFT", 430, 0, true); row.lockText:SetWidth(92)
        row.resetText = CreateText(row, "", 9, "RIGHT", row, "RIGHT", -12, 0, true); row.resetText:SetWidth(112); row.resetText:SetJustifyH("RIGHT")
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", function(self)
            if not self.lockoutIndex then return end
            frame.selectedLockout = self.lockoutIndex
            Panels:RefreshRaidInfo()
        end)
        frame.infoRows[i] = row
    end
    frame.infoList:EnableMouseWheel(true)
    frame.infoList:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = ClampOffset((frame.offset or 0) - delta, frame.total or 0, #frame.infoRows)
        Panels:RefreshRaid()
    end)
    frame.infoList:Hide(); frame.infoHeader:Hide()

    frame.lockAction = CreateButton(frame.body, "Extend Raid Lock", 168, 25)
    frame.lockAction:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 42)
    frame.lockAction:SetScript("OnClick", function()
        local selected = frame.selectedLockout
        if not selected or type(SetSavedInstanceExtend) ~= "function" then return end
        local target
        for i = 1, #(frame.savedInstances or {}) do
            local data = frame.savedInstances[i]
            if data.index == selected then target = data; break end
        end
        if not target then return end
        -- Stock Wrath uses true both to extend an active lock and reactivate an
        -- expired lock, and false to unextend a currently extended lock.
        SetSavedInstanceExtend(target.index, not target.extended)
        Panels:RequestRaidLockoutRefresh()
        Panels:RefreshRaidInfo()
    end)
    frame.lockAction:Hide()

    frame.convert = CreateButton(frame.body, "Convert to Raid", 120, 25)
    frame.convert:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 42)
    frame.convert:SetScript("OnClick", function() if CanConvertPartyToRaid() and type(ConvertToRaid) == "function" then SafeCall("convert to raid", ConvertToRaid) end end)

    frame.moveGroup = CreateButton(frame.body, "Move Group", 120, 25)
    frame.moveGroup:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 42)
    frame.moveGroup:SetScript("OnClick", function()
        if not frame.selected then return end
        if frame.groupPicker:IsShown() then
            frame.groupPicker:Hide()
        else
            Panels:RefreshRaidGroupPicker()
            frame.groupPicker:Show()
        end
    end)
    frame.moveGroup:Hide()

    frame.ready = CreateButton(frame.body, "Ready Check", 110, 25)
    frame.ready:SetPoint("LEFT", frame.convert, "RIGHT", 8, 0)
    frame.ready:SetScript("OnClick", function() if CanManageRaid() and type(DoReadyCheck) == "function" then SafeCall("ready check", DoReadyCheck) end end)

    frame.autoInvite = CreateButton(frame.body, "Auto Invite: OFF", 142, 25)
    frame.autoInvite:SetPoint("LEFT", frame.ready, "RIGHT", 8, 0)
    frame.autoInvite.RUIActiveFill = frame.autoInvite:CreateTexture(nil, "BACKGROUND")
    frame.autoInvite.RUIActiveFill:SetPoint("TOPLEFT", frame.autoInvite, "TOPLEFT", 1, -1)
    frame.autoInvite.RUIActiveFill:SetPoint("BOTTOMRIGHT", frame.autoInvite, "BOTTOMRIGHT", -1, 1)
    frame.autoInvite.RUIActiveFill:Hide()
    frame.autoInvite:SetScript("OnClick", function()
        local settings = GetGroupToolsSettings()
        Panels:SetAutoInviteEnabled(not (settings and settings.autoInvite == true))
    end)

    frame.whisper = CreateButton(frame.body, "Whisper", 92, 25)
    frame.whisper:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -2, 42)
    frame.whisper:SetScript("OnClick", function()
        if not frame.selected then return end
        local name, _, _, _, _, _, _, online = GetRaidRosterInfo(frame.selected)
        if name and online and ChatFrame_SendTell then ChatFrame_SendTell(name) end
    end)

    frame.groupPicker = CreateFrame("Frame", nil, frame.body)
    frame.groupPicker:SetWidth(430)
    frame.groupPicker:SetHeight(62)
    frame.groupPicker:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 74)
    frame.groupPicker:SetFrameLevel((frame.body:GetFrameLevel() or 1) + 30)
    RUI:CreateBackdrop(frame.groupPicker)
    frame.groupPicker.title = CreateText(frame.groupPicker, "Move selected member to group", 9, "TOPLEFT", frame.groupPicker, "TOPLEFT", 9, -8, false)
    frame.groupPicker.buttons = {}
    for group = 1, 8 do
        local button = CreateButton(frame.groupPicker, "G" .. tostring(group), 49, 24)
        button:SetPoint("BOTTOMLEFT", frame.groupPicker, "BOTTOMLEFT", 8 + ((group - 1) * 52), 7)
        button.group = group
        button:SetScript("OnClick", function(self)
            Panels:MoveSelectedRaidMemberToGroup(self.group)
        end)
        button:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Raid Group " .. tostring(self.group))
            local count = self.memberCount or 0
            GameTooltip:AddLine(tostring(count) .. "/5 members", 0.85, 0.85, 0.85)
            if self.isCurrent then
                GameTooltip:AddLine("Selected member is already in this group.", 0.55, 0.85, 1.0)
            elseif count >= 5 then
                GameTooltip:AddLine("This group is full.", 1.0, 0.35, 0.35)
            elseif not CanManageRaid() then
                GameTooltip:AddLine("Raid leader or assistant permission required.", 1.0, 0.55, 0.35)
            elseif InCombatLockdown and InCombatLockdown() then
                GameTooltip:AddLine("Raid groups cannot be changed during combat.", 1.0, 0.55, 0.35)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        frame.groupPicker.buttons[group] = button
    end
    frame.groupPicker:Hide()

    frame.lockSummary = CreateText(frame.body, "", 9, "BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 72, true)
    frame.lockSummary:SetWidth(648)
    frame.lockSummary:SetJustifyH("LEFT")
    frame.summary = CreateText(frame.body, "", 9, "BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 13, true)

    frame:SetScript("OnUpdate", function(self, elapsed)
        if (self.raidInfoPolls or 0) <= 0 then return end
        self.raidInfoPollElapsed = (self.raidInfoPollElapsed or 0) + (elapsed or 0)
        if self.raidInfoPollElapsed < 0.5 then return end
        self.raidInfoPollElapsed = 0
        self.raidInfoPolls = (self.raidInfoPolls or 1) - 1
        Panels:RefreshRaid()
    end)

    frame:SetScript("OnShow", function()
        Panels:HideOtherPanels(frame)
        HideStock(FriendsFrame)
        Panels:RequestRaidLockoutRefresh()
        Panels:RefreshRaid()
    end)
    return frame
end

function Panels:RefreshRaidGroupPicker()
    local frame = self.frames and self.frames.raid
    if not frame or not frame.groupPicker then return end

    local selectedIndex = frame.selected
    if frame.selectedName then
        selectedIndex = FindRaidMemberIndexByName(frame.selectedName) or selectedIndex
    end
    if not selectedIndex then
        frame.groupPicker:Hide()
        return
    end

    local name, _, subgroup = GetRaidRosterInfo(selectedIndex)
    if not name then
        frame.selected = nil
        frame.selectedName = nil
        frame.groupPicker:Hide()
        return
    end
    frame.selected = selectedIndex
    frame.selectedName = name
    subgroup = tonumber(subgroup) or 0

    local counts = GetRaidGroupCounts()
    frame.groupPicker.title:SetText("Move " .. tostring(name) .. " to group")
    for group = 1, 8 do
        local button = frame.groupPicker.buttons[group]
        local count = counts[group] or 0
        button.memberCount = count
        button.isCurrent = subgroup == group
        button.RUIText:SetText("G" .. tostring(group) .. " " .. tostring(count) .. "/5")
        local enabled = RaidGroupMoveAvailable() and subgroup ~= group and count < 5
        SetButtonEnabled(button, enabled)
        if subgroup == group then
            local ar, ag, ab = RUI:GetAccentColor()
            RUI:SetBorderColor(button, ar, ag, ab, 1)
        else
            RUI:RefreshBackdrop(button)
        end
    end
end

function Panels:MoveSelectedRaidMemberToGroup(group)
    local frame = self.frames and self.frames.raid
    group = tonumber(group)
    if not frame or not group or group < 1 or group > 8 then return end
    if not CanManageRaid() then
        RUI:Print("Only the raid leader or an assistant can move raid members between groups.")
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        RUI:Print("Raid groups cannot be changed during combat.")
        return
    end
    if type(SetRaidSubgroup) ~= "function" then
        RUI:Print("This client does not expose SetRaidSubgroup(), so Zen cannot move raid members.")
        return
    end

    local selectedIndex = frame.selectedName and FindRaidMemberIndexByName(frame.selectedName) or frame.selected
    if not selectedIndex then return end
    local name, _, subgroup = GetRaidRosterInfo(selectedIndex)
    subgroup = tonumber(subgroup) or 0
    if not name or subgroup == group then
        if frame.groupPicker then frame.groupPicker:Hide() end
        return
    end

    local counts = GetRaidGroupCounts()
    if (counts[group] or 0) >= 5 then
        RUI:Print("Raid group " .. tostring(group) .. " is full.")
        self:RefreshRaidGroupPicker()
        return
    end

    local ok = SafeCall("move raid member", SetRaidSubgroup, selectedIndex, group)
    if ok then
        frame.selectedName = name
        frame.selected = FindRaidMemberIndexByName(name) or selectedIndex
        if frame.groupPicker then frame.groupPicker:Hide() end
        self:RefreshRaid()
    end
end

function Panels:RefreshRaidInfo()
    local frame = self.frames and self.frames.raid
    if not frame or not frame:IsShown() then return end
    local entries = self:GetSavedRaidLockouts()
    frame.savedInstances = entries
    frame.total = #entries
    frame.offset = ClampOffset(frame.offset or 0, frame.total, #frame.infoRows)
    for i = 1, #frame.infoRows do
        local row = frame.infoRows[i]
        local data = entries[(frame.offset or 0) + i]
        if data then
            row.lockoutIndex = data.index
            local label = data.name
            if data.progress and data.progress ~= "" then label = label .. "  •  " .. data.progress end
            row.nameText:SetText(label)
            row.diffText:SetText(data.difficultyName or "")
            row.lockText:SetText(data.state or "Locked")
            if data.state == "Extended" then
                local ar, ag, ab = RUI:GetAccentColor()
                row.lockText:SetTextColor(ar, ag, ab, 1)
            elseif data.state == "Locked" then
                row.lockText:SetTextColor(1.0, 0.72, 0.25, 1)
            else
                local mr, mg, mb = RUI:GetTextColor(true)
                row.lockText:SetTextColor(mr, mg, mb, 0.75)
            end
            row.resetText:SetText(FormatRaidReset(data.reset))
            SetSelectedRow(row, frame.selectedLockout == data.index)
            row:Show()
        else
            row.lockoutIndex = nil
            row:Hide()
        end
    end

    local selectedData
    if frame.selectedLockout then
        for i = 1, #entries do
            if entries[i].index == frame.selectedLockout then selectedData = entries[i]; break end
        end
        if not selectedData then frame.selectedLockout = nil end
    end
    if selectedData and type(SetSavedInstanceExtend) == "function" then
        if selectedData.extended then
            frame.lockAction.RUIText:SetText("Unextend Raid Lock")
        elseif selectedData.locked then
            frame.lockAction.RUIText:SetText("Extend Raid Lock")
        else
            frame.lockAction.RUIText:SetText("Reactivate Raid Lock")
        end
        frame.lockAction:Enable()
        if frame.lockAction.RUIText then
            local tr, tg, tb = RUI:GetTextColor(false)
            frame.lockAction.RUIText:SetTextColor(tr, tg, tb, 1)
        end
    else
        frame.lockAction.RUIText:SetText("Select a Raid Lock")
        -- Keep the hitbox live and use a guarded handler rather than Blizzard's
        -- disabled button state; some 3.3.5 clients can leave dynamic buttons
        -- stuck disabled after their state changes.
        frame.lockAction:Enable()
        if frame.lockAction.RUIText then
            local mr, mg, mb = RUI:GetTextColor(true)
            frame.lockAction.RUIText:SetTextColor(mr, mg, mb, 0.65)
        end
    end

    frame.status:SetText("Saved Raid Lockouts")
    if #entries > 0 then
        frame.lockSummary:SetText("Project Ebonhold: Clear IDs uses Soul Ash and requires you to be out of group. Select a raid lock for Extend / Unextend actions.")
        frame.summary:SetText(tostring(#entries) .. " saved raid lockout" .. (#entries == 1 and "" or "s") .. "  •  click a row for lock actions  •  mouse wheel scrolls")
    else
        frame.lockSummary:SetText("No saved raid lockouts reported by the server.")
        frame.summary:SetText("Raid lockout information refreshes automatically after RequestRaidInfo().")
    end
end

function Panels:RefreshRaid()
    local frame = self.frames and self.frames.raid
    if not frame or not frame:IsShown() then return end

    local ar, ag, ab = RUI:GetAccentColor()
    RUI:RefreshBackdrop(frame.friendsTab); RUI:RefreshBackdrop(frame.ignoreTab); RUI:RefreshBackdrop(frame.guildTab)
    RUI:SetBorderColor(frame.raidTab, ar, ag, ab, 1)

    if frame.infoMode then
        frame.header:Hide(); frame.list:Hide(); frame.infoHeader:Show(); frame.infoList:Show()
        frame.convert:Hide(); frame.moveGroup:Hide(); frame.ready:Hide(); frame.autoInvite:Hide(); frame.whisper:Hide(); frame.lockAction:Show()
        if frame.groupPicker then frame.groupPicker:Hide() end
        frame.infoToggle.RUIText:SetText("Raid Roster")
        -- Keep reset action live; never push this button through Blizzard disabled state.
        frame.resetInstances:Enable()
        self:RefreshRaidInfo()
        return
    end

    frame.infoHeader:Hide(); frame.infoList:Hide(); frame.header:Show(); frame.list:Show()
    frame.ready:Show(); frame.autoInvite:Show(); frame.whisper:Show(); frame.lockAction:Hide()
    self:RefreshAutoInviteButton()
    local lockouts = self:GetSavedRaidLockouts()
    frame.infoToggle.RUIText:SetText("Raid Info (" .. tostring(#lockouts) .. ")")
    if #lockouts > 0 then
        local names = {}
        for i = 1, math.min(3, #lockouts) do names[#names + 1] = lockouts[i].name end
        local extra = #lockouts > 3 and (" +" .. tostring(#lockouts - 3)) or ""
        frame.lockSummary:SetText("Locked raids: " .. table.concat(names, ", ") .. extra)
    else
        frame.lockSummary:SetText("Locked raids: none reported")
    end

    local total = GetRaidMemberCountCompat()
    frame.total = total
    if frame.selectedName then
        frame.selected = FindRaidMemberIndexByName(frame.selectedName)
        if not frame.selected then frame.selectedName = nil end
    elseif frame.selected then
        local selectedName = GetRaidRosterInfo(frame.selected)
        frame.selectedName = selectedName
    end
    frame.offset = ClampOffset(frame.offset or 0, total, #frame.rows)
    local onlineCount = 0
    for i = 1, #frame.rows do
        local row = frame.rows[i]
        local index = (frame.offset or 0) + i
        if index <= total then
            local name, rank, subgroup, level, class, fileName, zone, online, isDead, role = GetRaidRosterInfo(index)
            row.dataIndex = index
            row.groupText:SetText(subgroup and ("G" .. tostring(subgroup)) or "")
            row.nameText:SetText(name or "Unknown")
            row.levelText:SetText((tonumber(level) and tonumber(level) > 0) and tostring(level) or "")
            row.classText:SetText(class or "")
            row.zoneText:SetText(zone or "")
            local roleText = ""
            if tonumber(rank) == 2 then roleText = "Leader" elseif tonumber(rank) == 1 then roleText = "Assist" end
            if role == "MAINTANK" then roleText = roleText ~= "" and (roleText .. "/MT") or "MT"
            elseif role == "MAINASSIST" then roleText = roleText ~= "" and (roleText .. "/MA") or "MA" end
            row.roleText:SetText(roleText)
            local mr, mg, mb = RUI:GetTextColor(true)
            local color = fileName and RAID_CLASS_COLORS and RAID_CLASS_COLORS[fileName]
            if online then
                onlineCount = onlineCount + 1
                if isDead then
                    row.nameText:SetTextColor(1.0, 0.25, 0.25, 1)
                    row.statusText:SetText("Dead"); row.statusText:SetTextColor(1.0, 0.35, 0.35, 1); row.presence:SetTexture(1.0, 0.25, 0.25, 1)
                else
                    if color then row.nameText:SetTextColor(color.r, color.g, color.b, 1) else local nr,ng,nb=RUI:GetTextColor(false); row.nameText:SetTextColor(nr,ng,nb,1) end
                    row.statusText:SetText("Online"); row.statusText:SetTextColor(0.35, 1.00, 0.45, 1); row.presence:SetTexture(0.35, 1.00, 0.45, 1)
                end
                row.groupText:SetTextColor(mr,mg,mb,0.95); row.levelText:SetTextColor(mr,mg,mb,0.95); row.classText:SetTextColor(mr,mg,mb,0.95); row.zoneText:SetTextColor(mr,mg,mb,0.95); row.roleText:SetTextColor(mr,mg,mb,0.95)
                if row.RUIBackground then row.RUIBackground:SetAlpha(0.38) end
            else
                row.nameText:SetTextColor(mr,mg,mb,0.58); row.groupText:SetTextColor(mr,mg,mb,0.42); row.levelText:SetTextColor(mr,mg,mb,0.42); row.classText:SetTextColor(mr,mg,mb,0.42); row.zoneText:SetTextColor(mr,mg,mb,0.42); row.roleText:SetTextColor(mr,mg,mb,0.42)
                row.statusText:SetText("Offline"); row.statusText:SetTextColor(mr,mg,mb,0.58); row.presence:SetTexture(mr,mg,mb,0.50)
                if row.RUIBackground then row.RUIBackground:SetAlpha(0.12) end
            end
            SetSelectedRow(row, frame.selected == index)
            row:Show()
        else row.dataIndex=nil; row:Hide() end
    end

    if total > 0 then
        frame.status:SetText("Current Raid  •  " .. tostring(total) .. " members")
        frame.summary:SetText(tostring(total) .. " members  •  " .. tostring(onlineCount) .. " online  •  select a member to move groups  •  right-click to whisper")
        frame.convert:Hide()
        frame.moveGroup:Show()
    elseif GetPartyMemberCountCompat() > 0 then
        frame.status:SetText("Current Party  •  convert to a raid when ready")
        frame.summary:SetText("Not currently in a raid.")
        frame.convert:Show()
        frame.moveGroup:Hide()
        if frame.groupPicker then frame.groupPicker:Hide() end
    else
        frame.status:SetText("Not currently in a raid")
        frame.summary:SetText("Raid Info remains available for saved raid lockouts.")
        frame.convert:Show()
        frame.moveGroup:Hide()
        if frame.groupPicker then frame.groupPicker:Hide() end
    end
    SetButtonEnabled(frame.convert, CanConvertPartyToRaid())
    SetButtonEnabled(frame.ready, total > 0 and CanManageRaid() and type(DoReadyCheck) == "function")
    SetButtonEnabled(frame.moveGroup, total > 0 and frame.selected and RaidGroupMoveAvailable())
    if frame.groupPicker and frame.groupPicker:IsShown() then self:RefreshRaidGroupPicker() end
    -- Keep reset action live; click-time guard reports if the API is unavailable.
    frame.resetInstances:Enable()
    local selectedOnline = false
    if frame.selected then
        local name, _, _, _, _, _, _, online = GetRaidRosterInfo(frame.selected)
        selectedOnline = name and online and true or false
        if not name then frame.selected = nil; frame.selectedName = nil end
    end
    SetButtonEnabled(frame.whisper, selectedOnline)
end

function Panels:ToggleRaid(forceShow, sourceFrame)
    local frame = self.frames.raid
    if frame:IsShown() and not forceShow then frame:Hide(); return end
    HideOtherSocialFamilyFrames(frame)
    HideStock(FriendsFrame)
    frame:Show()
end

-- Ask the 3.3.5 LFG backend for the same lock/eligibility state that the
-- stock Blizzard Dungeon Finder requests when it is shown. Because Zen
-- intercepts the stock panel before its OnShow can run, Phase A must make
-- these requests explicitly or the dungeon lists can remain empty/locked.
function Panels:RequestLFDState()
    if RequestLFDPlayerLockInfo then SafeCall("request LFD player locks", RequestLFDPlayerLockInfo) end
    if RequestLFDPartyLockInfo then SafeCall("request LFD party locks", RequestLFDPartyLockInfo) end
    if RequestLFDPlayerRewardInfo then SafeCall("request LFD reward info", RequestLFDPlayerRewardInfo) end
end

-- -------------------------------------------------------------------------
-- Dungeon Finder
-- -------------------------------------------------------------------------
function Panels:CreateDungeonFinder()
    local frame = CreatePanel("ZenUIDungeonFinderFrame", "dungeon", "Dungeon Finder")
    self.frames.dungeon = frame
    frame.mode = "random"
    frame.offset = 0
    frame.selectedDungeon = nil

    frame.randomTab = CreateButton(frame.body, "Random", 120, 26)
    frame.randomTab:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -2)
    frame.specificTab = CreateButton(frame.body, "Specific", 120, 26)
    frame.specificTab:SetPoint("LEFT", frame.randomTab, "RIGHT", 8, 0)
    frame.randomTab:SetScript("OnClick", function() frame.mode="random"; frame.offset=0; Panels:RefreshDungeonFinder() end)
    frame.specificTab:SetScript("OnClick", function() frame.mode="specific"; frame.offset=0; Panels:RefreshDungeonFinder() end)

    frame.roleLabel = CreateText(frame.body, "ROLES", 8, "TOPLEFT", frame.body, "TOPLEFT", 286, -9, true)
    frame.tank = CreateCheck(frame.body, "Tank", 330, -3, function() Panels:ApplyLFDRoles() end)
    frame.healer = CreateCheck(frame.body, "Healer", 410, -3, function() Panels:ApplyLFDRoles() end)
    frame.damage = CreateCheck(frame.body, "Damage", 500, -3, function() Panels:ApplyLFDRoles() end)
    frame.tank:SetWidth(78); frame.healer:SetWidth(88); frame.damage:SetWidth(95)

    frame.list = CreateFrame("Frame", nil, frame.body)
    frame.list:SetWidth(290)
    frame.list:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 2, -42)
    frame.list:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 52)
    RUI:CreateBackdrop(frame.list)
    frame.rows = {}
    for i = 1, 11 do
        local row = CreateListRow(frame.list, 274, 30)
        row:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 8, -8 - ((i - 1) * 32))
        row.check = CreateCheck(row, "", 7, -4, function() Panels:SelectDungeonRow(row) end)
        row.check:SetWidth(20)
        row.nameText = CreateText(row, "", 10, "LEFT", row, "LEFT", 32, 0, false); row.nameText:SetWidth(232); row.nameText:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self) Panels:SelectDungeonRow(self) end)
        frame.rows[i] = row
    end
    frame.list:EnableMouseWheel(true)
    frame.list:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = ClampOffset((frame.offset or 0) - delta, frame.total or 0, #frame.rows)
        Panels:RefreshDungeonFinder()
    end)

    frame.details = CreateFrame("Frame", nil, frame.body)
    frame.details:SetPoint("TOPLEFT", frame.list, "TOPRIGHT", 12, 0)
    frame.details:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -2, 52)
    RUI:CreateBackdrop(frame.details)
    frame.dungeonName = CreateText(frame.details, "Choose a dungeon", 14, "TOPLEFT", frame.details, "TOPLEFT", 14, -16, false)
    frame.dungeonName:SetWidth(275); frame.dungeonName:SetJustifyH("LEFT")
    frame.level = CreateText(frame.details, "", 9, "TOPLEFT", frame.dungeonName, "BOTTOMLEFT", 0, -6, true)
    frame.description = CreateText(frame.details, "", 11, "TOPLEFT", frame.level, "BOTTOMLEFT", 0, -18, false)
    frame.description:SetWidth(275); frame.description:SetHeight(70); frame.description:SetJustifyH("LEFT")
    frame.description:SetJustifyV("TOP")
    frame.rewardHeader = CreateText(frame.details, "REWARDS", 11, "TOPLEFT", frame.details, "TOPLEFT", 14, -154, true)
    frame.rewardContext = CreateText(frame.details, "", 9, "TOPLEFT", frame.rewardHeader, "BOTTOMLEFT", 0, -5, true)
    frame.rewardContext:SetWidth(260); frame.rewardContext:SetJustifyH("LEFT")
    frame.rewardMisc = CreateText(frame.details, "", 11, "TOPLEFT", frame.rewardContext, "BOTTOMLEFT", 0, -8, false)
    frame.rewardMisc:SetWidth(260); frame.rewardMisc:SetJustifyH("LEFT")
    frame.rewardRows = {}
    for i=1,4 do
        local reward = CreateListRow(frame.details, 260, 36)
        reward:SetPoint("TOPLEFT", frame.details, "TOPLEFT", 14, -206 - ((i-1)*39))
        reward.icon = reward:CreateTexture(nil,"ARTWORK"); reward.icon:SetWidth(30); reward.icon:SetHeight(30); reward.icon:SetPoint("LEFT",reward,"LEFT",4,0)
        reward.nameText = CreateText(reward,"",11,"LEFT",reward.icon,"RIGHT",8,4,false); reward.nameText:SetWidth(198); reward.nameText:SetJustifyH("LEFT")
        reward.countText = CreateText(reward,"",9,"LEFT",reward.icon,"RIGHT",8,-10,true); reward.countText:SetWidth(198); reward.countText:SetJustifyH("LEFT")
        reward:SetScript("OnEnter",function(self)
            if not self.dungeonID or not self.rewardIndex then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            if GameTooltip.SetLFGDungeonReward then GameTooltip:SetLFGDungeonReward(self.dungeonID,self.rewardIndex) else GameTooltip:AddLine(self.rewardName or "Reward") end
            GameTooltip:Show()
        end)
        reward:SetScript("OnLeave",function() GameTooltip:Hide() end)
        reward:Hide(); frame.rewardRows[i]=reward
    end
    frame.status = CreateText(frame.details, "", 10, "BOTTOMLEFT", frame.details, "BOTTOMLEFT", 14, 16, true)
    frame.status:SetWidth(275); frame.status:SetJustifyH("LEFT")

    frame.queue = CreateButton(frame.body, "Find Group", 150, 28)
    frame.queue:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -2, 12)
    frame.queue:SetScript("OnClick", function() Panels:QueueOrLeaveLFD() end)
    frame.note = CreateText(frame.body, "Role checks and ready proposals remain handled by WoW's secure LFG backend.", 9, "BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2, 18, true)
    frame.note:SetWidth(410); frame.note:SetJustifyH("LEFT")

    frame:SetScript("OnShow", function()
        Panels:HideOtherPanels(frame)
        local inCombat=InCombatLockdown and InCombatLockdown()
        if not inCombat then
            Panels:EnsureLFDBackend()
            Panels:RequestLFDState()
            HideStock(LFDParentFrame)
            if LFGDungeonList_Setup then SafeCall("LFG setup", LFGDungeonList_Setup) end
            if LFDQueueFrame_Update then SafeCall("LFD backend update", LFDQueueFrame_Update) end
        end
        Panels:RefreshDungeonFinder()
        -- Some private-server cores return lock/list data a little later than
        -- the panel open. Never drive the native LFD backend from insecure Lua
        -- during lockdown; use the data cached before combat and resume the
        -- bounded refresh as soon as combat ends.
        frame.RUIBackendRefreshLeft = inCombat and 0 or 5
        frame.RUIBackendRefreshElapsed = 0
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not self.RUIBackendRefreshLeft or self.RUIBackendRefreshLeft <= 0 then return end
        self.RUIBackendRefreshElapsed = (self.RUIBackendRefreshElapsed or 0) + (elapsed or 0)
        if self.RUIBackendRefreshElapsed >= 0.5 then
            self.RUIBackendRefreshElapsed = 0
            self.RUIBackendRefreshLeft = self.RUIBackendRefreshLeft - 0.5
            if not (InCombatLockdown and InCombatLockdown()) and LFDQueueFrame_Update then SafeCall("LFD delayed backend update", LFDQueueFrame_Update) end
            Panels:RefreshDungeonFinder()
        end
    end)
    return frame
end

function Panels:ApplyLFDRoles()
    local frame = self.frames and self.frames.dungeon
    if not frame or not SetLFGRoles then return end
    if InCombatLockdown and InCombatLockdown() then
        RUI:Print("Dungeon Finder role changes are unavailable during combat.")
        self:RefreshDungeonFinder()
        return
    end
    local leader = false
    if GetLFGRoles then leader = GetLFGRoles() and true or false end
    SafeCall("set LFD roles", SetLFGRoles, leader, frame.tank:GetChecked() and true or false, frame.healer:GetChecked() and true or false, frame.damage:GetChecked() and true or false)
end

function Panels:GetDungeonEntries()
    local frame = self.frames.dungeon
    local entries = {}

    if frame.mode == "random" then
        local count = (GetNumRandomDungeons and GetNumRandomDungeons()) or 0
        for i = 1, count do
            local id, name = GetLFGRandomDungeonInfo(i)
            if id and name then
                local joinable = true
                if type(IsLFGDungeonJoinable) == "function" then
                    local ok, value = SafeCall("random dungeon joinable", IsLFGDungeonJoinable, id)
                    if ok and value ~= nil then joinable = value and true or false end
                end
                table.insert(entries, { id=id, name=name, header=false, random=true, locked=not joinable })
            end
        end
        if #entries == 0 and GetRandomDungeonBestChoice then
            local id = GetRandomDungeonBestChoice()
            local info = GetDungeonInfoCompat(id)
            if id and info and info.name then table.insert(entries, {id=id,name=info.name,random=true,locked=false}) end
        end
    else
        local inCombat=InCombatLockdown and InCombatLockdown()
        if not inCombat then
            if LFGDungeonList_Setup then SafeCall("LFG list setup", LFGDungeonList_Setup) end
            if LFDQueueFrame_Update then SafeCall("LFD list refresh", LFDQueueFrame_Update) end
        end

        local source = LFDDungeonList
        if type(source) ~= "table" or #source == 0 then
            local ok, raw = SafeCall("LFD choice order", GetLFDChoiceOrder, source or {})
            if ok and type(raw) == "table" and #raw > 0 then source = raw end
        end
        if type(source) ~= "table" or #source == 0 then
            local ok, raw = SafeCall("LFD choice order fallback", GetLFDChoiceOrder)
            if ok and type(raw) == "table" and #raw > 0 then source = raw end
        end
        -- Final compatibility fallback: Blizzard's setup cache is keyed by
        -- dungeon ID on 3.3.5. Some private-server FrameXML variants populate
        -- that cache but do not expose LFDDungeonList until the stock frame
        -- performs its first visible update. Build a stable ID list ourselves.
        if (type(source) ~= "table" or #source == 0) and type(LFGDungeonInfo) == "table" then
            source = {}
            for id, info in pairs(LFGDungeonInfo) do
                if type(id) == "number" and type(info) == "table" then table.insert(source, id) end
            end
            table.sort(source, function(a, b)
                local ah = a < 0 and 0 or 1
                local bh = b < 0 and 0 or 1
                if ah ~= bh then return ah < bh end
                return a < b
            end)
        end

        if type(source) == "table" then
            for i = 1, #source do
                local id = source[i]
                local header = LFGIsIDHeader and LFGIsIDHeader(id)
                local info = GetDungeonInfoCompat(id)
                local name = info and info.name
                if name then
                    local enabledState = LFGEnabledList and LFGEnabledList[id]
                    local lockedState = LFGLockList and LFGLockList[id]
                    local enabled = enabledState == true or enabledState == 1 or enabledState == 2
                    local locked = lockedState == true or lockedState == 1
                    table.insert(entries, { id=id, name=name, header=header and true or false, enabled=enabled, locked=locked, collapsed=LFGCollapseList and LFGCollapseList[id] })
                end
            end
        end
    end
    return entries
end

function Panels:SelectDungeonRow(row)
    local frame = self.frames.dungeon
    local entry = row and row.entry
    if not entry then return end
    if InCombatLockdown and InCombatLockdown() then
        RUI:Print("Dungeon selections are unavailable during combat.")
        return
    end

    if entry.header then
        if LFDList_SetHeaderCollapsed then
            SafeCall("toggle LFD header", LFDList_SetHeaderCollapsed, entry.id, not entry.collapsed)
        end
        self:RefreshDungeonFinder()
        return
    end

    if frame.mode == "random" then
        if entry.locked then return end
        frame.selectedDungeon = entry.id
        if LFDQueueFrame_SetType then
            SafeCall("set random dungeon type", LFDQueueFrame_SetType, entry.id)
        elseif LFDQueueFrame then
            LFDQueueFrame.type = entry.id
        end
    else
        if entry.locked then return end
        local enabled = not entry.enabled
        if LFDList_SetDungeonEnabled then SafeCall("set specific dungeon", LFDList_SetDungeonEnabled, entry.id, enabled)
        elseif SetLFGDungeonEnabled then SafeCall("set specific dungeon", SetLFGDungeonEnabled, entry.id, enabled) end
        if LFGListUpdateHeaderEnabledAndLockedStates and LFDDungeonList and LFGEnabledList and LFGLockList and LFDHiddenByCollapseList then
            SafeCall("refresh LFD headers", LFGListUpdateHeaderEnabledAndLockedStates, LFDDungeonList, LFGEnabledList, LFGLockList, LFDHiddenByCollapseList)
        end
        if LFDQueueFrame_SetType then SafeCall("set specific mode", LFDQueueFrame_SetType, "specific") elseif LFDQueueFrame then LFDQueueFrame.type = "specific" end
    end
    self:RefreshDungeonFinder()
end

function Panels:RefreshDungeonRewards(dungeonID)
    local frame = self.frames and self.frames.dungeon
    if not frame or not frame.rewardHeader then return end
    for _,row in ipairs(frame.rewardRows or {}) do row:Hide(); row.dungeonID=nil; row.rewardIndex=nil end
    frame.rewardMisc:SetText("")
    frame.rewardContext:SetText("")

    if not dungeonID or type(GetLFGDungeonRewards) ~= "function" then
        frame.rewardContext:SetText("No reward data reported for this selection.")
        return
    end

    local ok, doneToday, moneyBase, moneyVar, experienceBase, experienceVar, numRewards = SafeCall("dungeon rewards", GetLFGDungeonRewards, dungeonID)
    if not ok then
        frame.rewardContext:SetText("Reward data is not available yet.")
        return
    end

    local partyCount = GetPartyMemberCountCompat()
    local numRandoms = math.max(0, 4 - (tonumber(partyCount) or 0))
    local money = (tonumber(moneyBase) or 0) + ((tonumber(moneyVar) or 0) * numRandoms)
    local xp = (tonumber(experienceBase) or 0) + ((tonumber(experienceVar) or 0) * numRandoms)
    numRewards = math.max(0, tonumber(numRewards) or 0)

    frame.rewardContext:SetText(Truthy(doneToday) and "Repeat completion reward" or "Completion reward")
    local misc = {}
    if money > 0 then misc[#misc+1] = FormatRewardMoney(money) end
    if xp > 0 then misc[#misc+1] = tostring(math.floor(xp+0.5)) .. " XP" end
    frame.rewardMisc:SetText(#misc>0 and table.concat(misc,"   •   ") or "")

    local shown = 0
    if type(GetLFGDungeonRewardInfo) == "function" then
        for i=1,math.min(numRewards,#(frame.rewardRows or {})) do
            local okReward,name,texture,quantity = SafeCall("dungeon reward item", GetLFGDungeonRewardInfo, dungeonID, i)
            if okReward and (name or texture) then
                shown=shown+1
                local row=frame.rewardRows[shown]
                row.dungeonID=dungeonID; row.rewardIndex=i; row.rewardName=name
                row.icon:SetTexture(texture or "")
                row.nameText:SetText(name or "Reward")
                quantity=tonumber(quantity) or 1
                row.countText:SetText(quantity>1 and ("Quantity: "..tostring(quantity)) or "")
                row:Show()
            end
        end
    end

    if money<=0 and xp<=0 and shown==0 then
        frame.rewardContext:SetText("No completion reward reported by the server.")
    end
end

function Panels:RefreshDungeonFinder()
    local frame = self.frames and self.frames.dungeon
    if not frame or not frame:IsShown() then return end
    local inCombat=InCombatLockdown and InCombatLockdown()

    local leader, tank, healer, damage = false, false, false, false
    if GetLFGRoles then leader, tank, healer, damage = GetLFGRoles() end
    frame.tank:SetRUIValue(tank); frame.healer:SetRUIValue(healer); frame.damage:SetRUIValue(damage)

    if GetAvailableRoles then
        local canTank, canHeal, canDamage = GetAvailableRoles()
        if canTank then frame.tank:Enable() else frame.tank:Disable() end
        if canHeal then frame.healer:Enable() else frame.healer:Disable() end
        if canDamage then frame.damage:Enable() else frame.damage:Disable() end
    end

    local entries = self:GetDungeonEntries()
    frame.entries = entries
    frame.total = #entries
    frame.offset = ClampOffset(frame.offset or 0, #entries, #frame.rows)

    if frame.mode == "random" then
        local best = GetRandomDungeonBestChoice and GetRandomDungeonBestChoice()
        local selectedValid = false
        for i = 1, #entries do
            if entries[i].id == frame.selectedDungeon and not entries[i].locked then selectedValid = true; break end
        end
        if not selectedValid then
            frame.selectedDungeon = nil
            if best then
                for i = 1, #entries do if entries[i].id == best then frame.selectedDungeon = best; break end end
            end
            if not frame.selectedDungeon then
                for i = 1, #entries do if not entries[i].locked then frame.selectedDungeon = entries[i].id; break end end
            end
        end
        if frame.selectedDungeon and not inCombat then
            if LFDQueueFrame_SetType then SafeCall("sync random dungeon", LFDQueueFrame_SetType, frame.selectedDungeon) elseif LFDQueueFrame then LFDQueueFrame.type = frame.selectedDungeon end
        end
    else
        if not inCombat then
            if LFDQueueFrame_SetType then SafeCall("sync specific dungeon mode", LFDQueueFrame_SetType, "specific") elseif LFDQueueFrame then LFDQueueFrame.type = "specific" end
        end
    end

    for i = 1, #frame.rows do
        local row = frame.rows[i]
        local entry = entries[(frame.offset or 0) + i]
        if entry then
            row.entry = entry
            row.nameText:SetText(entry.name)
            if entry.header then
                row.check:Hide()
                row.nameText:ClearAllPoints(); row.nameText:SetPoint("LEFT", row, "LEFT", 9, 0)
                local r,g,b=RUI:GetAccentColor(); row.nameText:SetTextColor(r,g,b)
            else
                row.check:Show()
                row.nameText:ClearAllPoints(); row.nameText:SetPoint("LEFT", row, "LEFT", 32, 0)
                if frame.mode == "random" then row.check:SetRUIValue(frame.selectedDungeon == entry.id) else row.check:SetRUIValue(entry.enabled) end
                if entry.locked then local r,g,b=RUI:GetTextColor(true); row.nameText:SetTextColor(r,g,b) else local r,g,b=RUI:GetTextColor(false); row.nameText:SetTextColor(r,g,b) end
            end
            SetSelectedRow(row, frame.mode == "random" and frame.selectedDungeon == entry.id)
            row:Show()
        else row.entry=nil; row:Hide() end
    end

    local r,g,b=RUI:GetAccentColor()
    if frame.mode == "random" then RUI:SetBorderColor(frame.randomTab,r,g,b,1); RUI:RefreshBackdrop(frame.specificTab)
    else RUI:SetBorderColor(frame.specificTab,r,g,b,1); RUI:RefreshBackdrop(frame.randomTab) end

    local selected = frame.selectedDungeon
    if frame.mode == "specific" then
        selected = nil
        for i = 1, #entries do if not entries[i].header and entries[i].enabled then selected = entries[i].id; break end end
    end
    local info = GetDungeonInfoCompat(selected)
    if info and info.name then
        frame.dungeonName:SetText(info.name)
        if info.minLevel and info.maxLevel then
            frame.level:SetText("Level " .. tostring(info.minLevel) .. " - " .. tostring(info.maxLevel) .. (info.maxPlayers and ("  •  " .. tostring(info.maxPlayers) .. " players") or ""))
        else frame.level:SetText("") end
        frame.description:SetText((info.description and info.description ~= "") and info.description or (frame.mode == "random" and "Queue for this random dungeon category." or "Select one or more specific dungeons from the list."))
    else
        frame.dungeonName:SetText(frame.mode == "random" and "Random Dungeon" or "Specific Dungeons")
        frame.level:SetText("")
        frame.description:SetText(frame.mode == "random" and "No queueable random dungeon is currently available." or (#entries == 0 and "The Wrath LFG backend has not returned the dungeon list yet." or "Select one or more specific dungeons from the list."))
    end

    self:RefreshDungeonRewards(selected)

    local mode, subMode = GetLFGMode and GetLFGMode()
    local queued = mode == "queued" or mode == "rolecheck" or mode == "proposal"
    frame.queue.RUIText:SetText(queued and "Leave Queue" or ((GetNumPartyMembers and GetNumPartyMembers() > 0) and "Join as Party" or "Find Group"))
    local anyRole = tank or healer or damage
    local empowered = not LFD_IsEmpowered or LFD_IsEmpowered()
    local hasChoice = frame.mode == "random" and frame.selectedDungeon ~= nil or selected ~= nil
    SetButtonEnabled(frame.queue, (not inCombat) and (queued or (anyRole and empowered and hasChoice)))
    if inCombat then
        frame.status:SetText("Combat: Dungeon Finder is view-only until combat ends")
    else
        frame.status:SetText(mode and ("Status: " .. tostring(mode) .. (subMode and (" / " .. tostring(subMode)) or "")) or "Not queued")
    end
end

function Panels:QueueOrLeaveLFD()
    local frame = self.frames.dungeon
    if not frame then return end
    if InCombatLockdown and InCombatLockdown() then
        RUI:Print("Dungeon Finder queue changes are unavailable during combat.")
        return
    end
    local mode = GetLFGMode and GetLFGMode()
    if mode == "queued" or mode == "rolecheck" or mode == "proposal" then
        if LeaveLFG then SafeCall("leave LFD queue", LeaveLFG) end
        return
    end

    self:ApplyLFDRoles()
    if LFD_IsEmpowered and not LFD_IsEmpowered() then
        RUI:Print("Only the party leader can queue this group for Dungeon Finder.")
        return
    end

    if frame.mode == "random" then
        if not frame.selectedDungeon then
            RUI:Print("No queueable random dungeon is selected.")
            return
        end
        if LFDQueueFrame_SetType then SafeCall("select random queue", LFDQueueFrame_SetType, frame.selectedDungeon) elseif LFDQueueFrame then LFDQueueFrame.type = frame.selectedDungeon end
    else
        local any = false
        for i = 1, #(frame.entries or {}) do
            local entry = frame.entries[i]
            if entry and not entry.header and entry.enabled and not entry.locked then any = true; break end
        end
        if not any then
            RUI:Print("Select at least one specific dungeon before queueing.")
            return
        end
        if LFDQueueFrame_SetType then SafeCall("select specific queue", LFDQueueFrame_SetType, "specific") elseif LFDQueueFrame then LFDQueueFrame.type = "specific" end
    end

    if LFDQueueFrame_Join then
        SafeCall("join LFD queue", LFDQueueFrame_Join)
        return
    end

    -- Fallback for private-server FrameXML variants missing Blizzard's helper.
    if ClearAllLFGDungeons then ClearAllLFGDungeons() end
    if frame.mode == "random" then
        if SetLFGDungeon then SetLFGDungeon(frame.selectedDungeon) end
    else
        for i = 1, #(frame.entries or {}) do
            local entry = frame.entries[i]
            if entry and not entry.header and entry.enabled and not entry.locked and SetLFGDungeon then SetLFGDungeon(entry.id) end
        end
    end
    if JoinLFG then JoinLFG() end
end

function Panels:ToggleDungeonFinder(forceShow)
    local frame = self.frames.dungeon
    if frame:IsShown() and not forceShow then frame:Hide(); return end
    local inCombat=InCombatLockdown and InCombatLockdown()
    if not inCombat then
        self:EnsureLFDBackend()
        HideStock(LFDParentFrame)
    end
    frame:Show()
end

-- -------------------------------------------------------------------------
-- Integration / lifecycle
-- -------------------------------------------------------------------------
function Panels:EnsureLFDBackend()
    -- Blizzard_LookingForGroupUI is load-on-demand on many 3.3.5 clients.
    -- Loading an addon is combat-restricted on some Ebonhold builds, so the
    -- Zen window must still open even if that backend was not primed yet.
    if not (InCombatLockdown and InCombatLockdown()) and IsAddOnLoaded and not IsAddOnLoaded("Blizzard_LookingForGroupUI") and LoadAddOn then
        SafeCall("load LFG backend", LoadAddOn, "Blizzard_LookingForGroupUI")
    end
    self:InstallOverrides()
    self:RequestLFDState()
end

function Panels:InstallOverrides()
    -- Do NOT replace Blizzard's ToggleSpellBook global.  The stock keybinding
    -- and native SpellBookFrame form part of the secure combat path on Wrath /
    -- Ebonhold.  Replacing that global works out of combat but taints the very
    -- path we need when the player tries to cast or drag a spell during combat.
    -- Instead, cache the native function and redirect presentation from the
    -- SpellBookFrame OnShow hook only while out of combat.
    if type(_G.ToggleSpellBook) == "function" and _G.ToggleSpellBook ~= self.ruiToggleSpellBook then
        self.originalToggleSpellBook = _G.ToggleSpellBook
    elseif self.ruiToggleSpellBook and _G.ToggleSpellBook == self.ruiToggleSpellBook and type(self.originalToggleSpellBook) == "function" then
        _G.ToggleSpellBook = self.originalToggleSpellBook
    end

    if not self.ruiToggleFriendsFrame then
        self.ruiToggleFriendsFrame = function(tab)
            tab = tab or 1
            if tab == 1 and IsEnabled("social") then Panels:ToggleSocial(false, "friends"); return end
            if tab == 3 and IsEnabled("guild") then Panels:ToggleGuild(false); return end
            if tab == 5 and IsEnabled("social") then Panels:ToggleRaid(false); return end
            return Panels:ShowStockFriendsTab(tab)
        end
    end
    if _G.ToggleFriendsFrame ~= self.ruiToggleFriendsFrame then
        self.originalToggleFriendsFrame = _G.ToggleFriendsFrame
        _G.ToggleFriendsFrame = self.ruiToggleFriendsFrame
    end

    if not self.ruiToggleLFDParentFrame then
        self.ruiToggleLFDParentFrame = function()
            if IsEnabled("dungeonFinder") then Panels:ToggleDungeonFinder(false); return end
            if Panels.originalToggleLFDParentFrame then return Panels.originalToggleLFDParentFrame() end
        end
    end
    if _G.ToggleLFDParentFrame ~= self.ruiToggleLFDParentFrame then
        self.originalToggleLFDParentFrame = _G.ToggleLFDParentFrame
        _G.ToggleLFDParentFrame = self.ruiToggleLFDParentFrame
    end

    if SpellBookFrame and SpellBookFrame.HookScript and not SpellBookFrame.RUIReplacementHooked then
        SpellBookFrame.RUIReplacementHooked = true
        SpellBookFrame:HookScript("OnShow", function(stock)
            if IsEnabled("spellbook") then
                -- Normal Zen keybinds are routed around the protected native
                -- ToggleSpellBook path before combat starts.  If another addon
                -- opens the stock frame out of combat, keep the old redirect.
                -- During combat do not attempt to hide a protected Blizzard
                -- frame from insecure Lua; the combat override binding prevents
                -- the normal P key from reaching this path in the first place.
                if InCombatLockdown and InCombatLockdown() then return end
                HideStock(stock)
                if Panels.frames and Panels.frames.spellbook and not Panels.frames.spellbook:IsShown() then Panels:ToggleSpellbook(BOOKTYPE_SPELL or "spell") end
            end
        end)
    end

    if FriendsFrame and FriendsFrame.HookScript and not FriendsFrame.RUIReplacementHooked then
        FriendsFrame.RUIReplacementHooked = true
        FriendsFrame:HookScript("OnShow", function(stock)
            if Panels.ebonholdDiscoveryActive or Panels.allowStockSocial or Panels.nativeGuildControlActive then return end
            local tab = stock.selectedTab or 1
            if PanelTemplates_GetSelectedTab then tab = PanelTemplates_GetSelectedTab(stock) or tab end
            if tab == 1 and IsEnabled("social") then
                HideStock(stock)
                if Panels.frames and Panels.frames.social and not Panels.frames.social:IsShown() then Panels:ToggleSocial(true, "friends") end
            elseif tab == 3 and IsEnabled("guild") then
                HideStock(stock)
                if Panels.frames and Panels.frames.guild and not Panels.frames.guild:IsShown() then Panels:ToggleGuild(true) end
            elseif tab == 5 and IsEnabled("social") then
                HideStock(stock)
                if Panels.frames and Panels.frames.raid and not Panels.frames.raid:IsShown() then Panels:ToggleRaid(true) end
            end
        end)
    end

    -- Ebonhold has custom code on RaidFrame itself and can show it without
    -- going through ToggleFriendsFrame/FriendsFrame's normal path.  Treat any
    -- visible stock Raid frame as a backend leak and immediately return to the
    -- Zen Raid view.
    if RaidFrame and RaidFrame.HookScript and not RaidFrame.RUIReplacementHooked then
        RaidFrame.RUIReplacementHooked = true
        RaidFrame:HookScript("OnShow", function(stockRaid)
            if Panels.ebonholdDiscoveryActive then return end
            if not IsEnabled("social") then return end
            if stockRaid and type(stockRaid.Hide) == "function" then stockRaid:Hide() end
            if FriendsFrame then
                if type(HideUIPanel) == "function" then pcall(HideUIPanel, FriendsFrame) end
                if type(FriendsFrame.Hide) == "function" then FriendsFrame:Hide() end
            end
            if Panels.frames and Panels.frames.raid and not Panels.frames.raid:IsShown() then
                Panels:ToggleRaid(true)
            end
        end)
    end

    -- If the user is looking at a stock Who/Chat social tab and clicks one of
    -- Zen-owned Friends/Guild/Raid tabs, switch cleanly into our panel.
    if FriendsFrameTab1 and FriendsFrameTab1.HookScript and not FriendsFrameTab1.RUIReplacementHooked then
        FriendsFrameTab1.RUIReplacementHooked = true
        FriendsFrameTab1:HookScript("OnClick", function()
            if IsEnabled("social") then HideStock(FriendsFrame); Panels:ToggleSocial(true, "friends") end
        end)
    end
    if FriendsFrameTab3 and FriendsFrameTab3.HookScript and not FriendsFrameTab3.RUIReplacementHooked then
        FriendsFrameTab3.RUIReplacementHooked = true
        FriendsFrameTab3:HookScript("OnClick", function()
            if Panels.nativeGuildControlActive then return end
            if IsEnabled("guild") then HideStock(FriendsFrame); Panels:ToggleGuild(true) end
        end)
    end
    if FriendsFrameTab5 and FriendsFrameTab5.HookScript and not FriendsFrameTab5.RUIReplacementHooked then
        FriendsFrameTab5.RUIReplacementHooked = true
        FriendsFrameTab5:HookScript("OnClick", function()
            if IsEnabled("social") then HideStock(FriendsFrame); Panels:ToggleRaid(true) end
        end)
    end

    if LFDParentFrame and LFDParentFrame.HookScript and not LFDParentFrame.RUIReplacementHooked then
        LFDParentFrame.RUIReplacementHooked = true
        LFDParentFrame:HookScript("OnShow", function(stock)
            if IsEnabled("dungeonFinder") then
                HideStock(stock)
                if Panels.frames and Panels.frames.dungeon and not Panels.frames.dungeon:IsShown() then Panels.frames.dungeon:Show() end
            end
        end)
    end
end

function Panels:RestoreGuildControlParent(keepZenHidden)
    if self.restoringGuildControl then return end
    self.restoringGuildControl = true

    local popup = _G.GuildControlPopupFrame
    local wasActive = self.nativeGuildControlActive and true or false

    if popup and popup.ZenUIHostedByGuild then
        -- Clear our flag before Hide() so the popup's OnHide hook cannot start
        -- a second restoration pass while this one is already in progress.
        popup.ZenUIHostedByGuild = nil
        if popup.Hide and popup.IsShown and popup:IsShown() then popup:Hide() end
        if popup.ZenUIOriginalParent and popup.SetParent then popup:SetParent(popup.ZenUIOriginalParent) end
        if popup.ClearAllPoints then popup:ClearAllPoints() end
        if popup.ZenUIOriginalPoints and popup.SetPoint then
            for i = 1, #popup.ZenUIOriginalPoints do
                local a = popup.ZenUIOriginalPoints[i]
                popup:SetPoint(a[1], a[2], a[3], a[4], a[5])
            end
        end
        if popup.ZenUIOriginalStrata and popup.SetFrameStrata then
            popup:SetFrameStrata(popup.ZenUIOriginalStrata)
        end
        if popup.ZenUIOriginalLevel and popup.SetFrameLevel then
            popup:SetFrameLevel(popup.ZenUIOriginalLevel)
        end
    end

    if FriendsFrame then
        if self.guildControlFriendsAlpha ~= nil and FriendsFrame.SetAlpha then
            FriendsFrame:SetAlpha(self.guildControlFriendsAlpha)
        end
    end
    self.guildControlFriendsAlpha = nil

    if wasActive then
        self.nativeGuildControlActive = nil

        -- The native Guild frame only stayed alive invisibly to service
        -- Blizzard's protected control logic. Remove that host now.
        self.allowStockSocial = true
        HideStock(FriendsFrame)
        self.allowStockSocial = nil

        local frame = self.frames and self.frames.guild
        if frame and IsEnabled("guild") and not keepZenHidden then
            if not frame:IsShown() then frame:Show() end
            self:RefreshGuild()
        end
    end

    self.restoringGuildControl = nil
end

function Panels:ApplySettings()
    if not self.frames then return end
    local enabled = GetSettings() and GetSettings().enabled ~= false
    local mapping = { spellbook="spellbook", social="social", guild="guild", raid="social", dungeon="dungeonFinder" }
    for key, settingKey in pairs(mapping) do
        local frame = self.frames[key]
        local active = enabled and IsEnabled(settingKey)
        if not active and frame and frame:IsShown() then frame:Hide() end
        if key ~= "social" and key ~= "guild" and key ~= "raid" then
            local info = PANEL_INFO[key]
            if info then RUI:SetMoverEnabled(info.mover, active) end
        end
        self:ApplyPanelScale(key)
    end

    -- One Social / Guild / Raid anchor is enabled whenever any Social-system view is enabled.
    local socialActive = enabled and (IsEnabled("social") or IsEnabled("guild"))
    RUI:SetMoverEnabled("ZenSocial", socialActive)
    if not (enabled and IsEnabled("guild")) then
        if self.frames.guild and self.frames.guild:IsShown() then self.frames.guild:Hide() end
        self:RestoreGuildControlParent()
    end
    self:UpdateSocialMoverSize()
    self:InstallSpellbookCombatBinding()
end

function Panels:RefreshAppearance()
    for key, frame in pairs(self.frames or {}) do
        RUI:RefreshBackdrop(frame)
        RUI:SetAccentTexture(frame.accent)
        StyleOwnText(frame.title, 15, false)
        StyleOwnText(frame.subtitle, 8, true)
        self:ApplyPanelScale(key)
    end
    if self.frames.spellbook then self:RefreshSpellbook() end
    if self.frames.social then self:RefreshSocial() end
    if self.frames.guild then self:RefreshGuild() end
    if self.frames.raid then self:RefreshRaid() end
    if self.frames.dungeon then self:RefreshDungeonFinder() end
end


local function EnsureCombatMenuToggle(module, key, frame, name)
    if not module or not frame then return nil end
    module.combatMenuToggles = module.combatMenuToggles or {}
    local button = module.combatMenuToggles[key]
    if not button then
        button = CreateFrame("Button", name, UIParent, "SecureHandlerClickTemplate")
        button:SetFrameRef("target", frame)
        button:SetAttribute("_onclick", [[
            local f = self:GetFrameRef("target")
            if f then
                if f:IsShown() then f:Hide() else f:Show() end
            end
        ]])
        module.combatMenuToggles[key] = button
    end
    return button
end

local function EnsurePlainCombatMenuToggle(module, key, name, callback)
    if not module or type(callback)~="function" then return nil end
    module.plainCombatMenuToggles=module.plainCombatMenuToggles or {}
    local button=module.plainCombatMenuToggles[key]
    if not button then
        button=CreateFrame("Button",name,UIParent)
        button:SetWidth(1); button:SetHeight(1)
        button:SetPoint("TOPLEFT",UIParent,"TOPLEFT",-20,20)
        if button.RegisterForClicks then button:RegisterForClicks("AnyUp") end
        button:SetScript("OnClick",callback)
        module.plainCombatMenuToggles[key]=button
    end
    return button
end

function Panels:InstallSpellbookCombatBinding()
    if not RUI.RegisterCombatMenuRoute then return end

    -- Spellbook contains SecureActionButton spell rows, so its ancestor frame
    -- is protected in combat.  Let the central binding router toggle that one
    -- frame directly from secure code; its OnShow keeps the pre-armed combat
    -- page intact and refreshes normally out of combat.
    if RUI.RegisterCombatSecureFrameRoute then
        RUI:RegisterCombatSecureFrameRoute("Spellbook","TOGGLESPELLBOOK",self.frames and self.frames.spellbook,IsEnabled("spellbook"))
    end

    RUI:RegisterCombatMenuRoute("Social","TOGGLESOCIAL",function()
        Panels:ToggleSocial(false,"friends")
    end,IsEnabled("social"))
    RUI:RegisterCombatMenuRoute("FriendsTab","TOGGLEFRIENDSTAB",function()
        Panels:ToggleSocial(false,"friends")
    end,IsEnabled("social"))
    RUI:RegisterCombatMenuRoute("GuildTab","TOGGLEGUILDTAB",function()
        Panels:ToggleGuild(false)
    end,IsEnabled("guild"))
    RUI:RegisterCombatMenuRoute("RaidTab","TOGGLERAIDTAB",function()
        Panels:ToggleRaid(false)
    end,IsEnabled("social"))
    RUI:RegisterCombatMenuRoute("DungeonFinder","TOGGLELFGPARENT",function()
        Panels:ToggleDungeonFinder(false)
    end,IsEnabled("dungeonFinder"))
end

function Panels:OnComponentScaleChanged(key)
    for panelKey, info in pairs(PANEL_INFO) do if key == "all" or key == info.scale then self:ApplyPanelScale(panelKey) end end
end

function Panels:OnProfileReset()
    self:ApplySettings()
    self:RefreshAppearance()
end

function Panels:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        -- Re-wrap any load-on-demand Blizzard toggle functions and install
        -- stock-frame guards as soon as their FrameXML becomes available.
        self:InstallOverrides()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        self:InstallSpellbookCombatBinding()
        if self.pendingSpellRefresh then self.pendingSpellRefresh=nil; self:RefreshSpellbook() end
        if self.frames.raid and self.frames.raid:IsShown() then self:RefreshRaid() end
        if self.frames.dungeon and self.frames.dungeon:IsShown() then
            self:EnsureLFDBackend(); self:RequestLFDState(); self:RefreshDungeonFinder()
            self.frames.dungeon.RUIBackendRefreshLeft=5
            self.frames.dungeon.RUIBackendRefreshElapsed=0
        end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        if self.frames.raid and self.frames.raid:IsShown() then self:RefreshRaid() end
        return
    end
    if event == "UPDATE_BINDINGS" then self:InstallSpellbookCombatBinding(); return end
    if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "PET_BAR_UPDATE" then
        if InCombatLockdown and InCombatLockdown() then
            self.pendingSpellRefresh=true
        else
            self:RefreshSpellbook()
        end
        return
    end
    if event == "FRIENDLIST_UPDATE" or event == "IGNORELIST_UPDATE" then self:RefreshSocial(); return end
    if event == "GUILD_ROSTER_UPDATE" or event == "GUILD_MOTD" or event == "PLAYER_GUILD_UPDATE" then self:RefreshGuild(); return end
    if event == "CHAT_MSG_WHISPER" then
        local message, sender = ...
        self:HandleAutoInviteWhisper(message, sender)
        return
    end
    if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" or event == "PARTY_LEADER_CHANGED" then
        self:HandleAutoInviteGroupChanged()
        self:RefreshRaid()
        return
    end
    if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then self:RefreshRaid(); return end
    if event == "UPDATE_INSTANCE_INFO" then if self.frames.raid and self.frames.raid:IsShown() then self:RefreshRaid() end; return end
    if event == "LFG_OPEN_FROM_GOSSIP" then
        if IsEnabled("dungeonFinder") then
            local dungeonID = ...
            if dungeonID then self.frames.dungeon.selectedDungeon = dungeonID end
            self:ToggleDungeonFinder(true)
            HideStock(LFDParentFrame)
        end
        return
    end
    if string.sub(event, 1, 4) == "LFG_" then self:RefreshDungeonFinder(); return end
    if event == "PLAYER_ENTERING_WORLD" then
        self:ApplySettings()
        self:HandleAutoInviteGroupChanged()
        -- Prime the load-on-demand LFD backend before combat so the I-key Zen
        -- panel can remain useful even if the player's first open happens in
        -- lockdown. This is a one-time/event-driven setup, not polling.
        if IsEnabled("dungeonFinder") and not (InCombatLockdown and InCombatLockdown()) then
            self:EnsureLFDBackend(); self:RequestLFDState()
        end
        if self.frames.social and self.frames.social:IsShown() and ShowFriends then SafeCall("friends refresh", ShowFriends) end
        if self.frames.guild and self.frames.guild:IsShown() and GuildRoster then GuildRoster() end
        if self.frames.raid and self.frames.raid:IsShown() then if RequestRaidInfo then SafeCall("request raid info", RequestRaidInfo) end; self:RefreshRaid() end
        if self.frames.dungeon and self.frames.dungeon:IsShown() then self:EnsureLFDBackend(); self:RequestLFDState(); self:RefreshDungeonFinder() end
    end
end

function Panels:OnInitialize()
    self.frames = {}
    self:CreateSpellbook()
    self:CreateSocial()
    self:CreateGuild()
    self:InstallGuildChatLinkBridge()
    self:CreateRaid()
    self:CreateDungeonFinder()
    self:RegisterPanelMover("spellbook", self.frames.spellbook)
    self:RegisterPanelMover("social", self.frames.social)
    self:RegisterPanelMover("guild", self.frames.guild)
    self:RegisterPanelMover("raid", self.frames.raid)
    self:RegisterPanelMover("dungeon", self.frames.dungeon)
    self:InstallOverrides()
    self:InstallSpellbookCombatBinding()

    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "RefreshAppearance")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED", self, "OnComponentScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET", self, "OnProfileReset")
end

function Panels:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "OnEvent")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
    self:RegisterEvent("UPDATE_BINDINGS", "OnEvent")
    self:RegisterEvent("SPELLS_CHANGED", "OnEvent")
    self:RegisterEvent("LEARNED_SPELL_IN_TAB", "OnEvent")
    self:RegisterEvent("PET_BAR_UPDATE", "OnEvent")
    self:RegisterEvent("FRIENDLIST_UPDATE", "OnEvent")
    self:RegisterEvent("IGNORELIST_UPDATE", "OnEvent")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnEvent")
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnEvent")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "OnEvent")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnEvent")
    self:RegisterEvent("PARTY_LEADER_CHANGED", "OnEvent")
    self:RegisterEvent("READY_CHECK", "OnEvent")
    self:RegisterEvent("READY_CHECK_CONFIRM", "OnEvent")
    self:RegisterEvent("READY_CHECK_FINISHED", "OnEvent")
    self:RegisterEvent("UPDATE_INSTANCE_INFO", "OnEvent")
    self:RegisterEvent("GUILD_MOTD", "OnEvent")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "OnEvent")
    self:RegisterEvent("LFG_UPDATE", "OnEvent")
    self:RegisterEvent("LFG_LOCK_INFO_RECEIVED", "OnEvent")
    self:RegisterEvent("LFG_ROLE_UPDATE", "OnEvent")
    self:RegisterEvent("LFG_UPDATE_RANDOM_INFO", "OnEvent")
    self:RegisterEvent("LFG_PROPOSAL_SHOW", "OnEvent")
    self:RegisterEvent("LFG_PROPOSAL_UPDATE", "OnEvent")
    self:RegisterEvent("LFG_PROPOSAL_FAILED", "OnEvent")
    self:RegisterEvent("LFG_PROPOSAL_SUCCEEDED", "OnEvent")
    self:RegisterEvent("LFG_ROLE_CHECK_SHOW", "OnEvent")
    self:RegisterEvent("LFG_ROLE_CHECK_HIDE", "OnEvent")
    self:RegisterEvent("LFG_OPEN_FROM_GOSSIP", "OnEvent")
    self:ApplySettings()
    -- Arm the first Zen spellbook page while the client is out of combat so
    -- its SecureActionButton spell attributes are already valid if combat
    -- starts before the player opens the book for the first time.
    if not (InCombatLockdown and InCombatLockdown()) then self:RefreshSpellbook() end
    self:InstallSpellbookCombatBinding()
end
