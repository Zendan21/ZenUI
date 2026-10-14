-- ZenUI 0.9.164 - integrated Ebonhold Callboard cooldown / raid-save tracker.
-- Inspired by the workflow of CallBoard CD Tracker v2.12, but implemented as a
-- ZenUI-owned, event-driven module with no permanent polling loop.

local RUI = ZenUI
local Tracker = RUI:NewModule("CallboardTracker")

local RAID_ORDER = { 600600, 600601, 600602, 600603 }
local RAID_QUESTS = {
    [600600] = { title = "The Fall of Sartharion", instance = "Obsidian Sanctum", label = "The Obsidian Sanctum", icon = "Interface\\Icons\\Achievement_Boss_Sartharion_01" },
    [600601] = { title = "Malygos Must Die!", instance = "Eye of Eternity", label = "The Eye of Eternity", icon = "Interface\\Icons\\Achievement_Boss_Malygos_01" },
    [600602] = { title = "End of the Line: Kelthuzad", instance = "Naxxramas", label = "Naxxramas", icon = "Interface\\Icons\\Achievement_Boss_KelThuzad_01" },
    [600603] = { title = "Topple the Tyrant: Yogg-Saron", instance = "Ulduar", label = "Ulduar", icon = "Interface\\Icons\\Achievement_Boss_YoggSaron_01" },
}

-- Known Ebonhold Board quests from the supplied tracker. Zen learns unknown
-- Board quests encountered in the live quest log as well, so this table does
-- not need to be exhaustive forever.
local KNOWN_QUESTS = {
    [600642]={title="A Blade for Keristrasza",objective="Slay Keristrasza in The Nexus."},
    [600666]={title="A Growing Menace: Ravaged Ghoul",objective="Kill 10 Ravaged Ghoul in Icecrown."},
    [600638]={title="Bring Down Ingvar the Plunderer",objective="Slay Ingvar the Plunderer in Utgarde Keep."},
    [600875]={title="Bulk Order: Eternal Earth",objective="Collect 20 Eternal Earth."},
    [600646]={title="By Sword and Shield: Ingvar the Plunderer",objective="Slay Ingvar the Plunderer in Utgarde Keep."},
    [600639]={title="Clear the Path: King Ymiron",objective="Slay King Ymiron in Utgarde Pinnacle."},
    [600663]={title="Clear the Roads of Winterspring",objective="Kill 10 Wandering Shadow in Wintergrasp."},
    [600836]={title="Collect Saronite Bar",objective="Collect 200 Saronite Bar."},
    [600930]={title="Constrictor Grass Supply",objective="Collect 40 Constrictor Grass."},
    [600931]={title="Crafting Materials: Adder's Tongue",objective="Collect 40 Adder's Tongue."},
    [600841]={title="Crafting Materials: Hardened Saronite Bar",objective="Collect 5 Hardened Saronite Bar."},
    [600667]={title="Crystalsong Forest Under Siege",objective="Kill 10 Azure Spellweaver in Crystalsong Forest."},
    [600660]={title="Culling of the Water Revenant",objective="Kill 10 Water Revenant in Wintergrasp."},
    [600665]={title="Drive Them Back: Skeletal Archmage",objective="Kill 10 Skeletal Archmage in Icecrown."},
    [600645]={title="Dungeon Crawl: Loken",objective="Slay Loken in Halls of Lightning."},
    [600602]={title="End of the Line: Kelthuzad",objective="Slay Kelthuzad in Naxxramas."},
    [600643]={title="End the Threat: The Prophet Tharon'ja",objective="Slay The Prophet Tharon'ja in Drak'Tharon Keep."},
    [600874]={title="Eternal Air Wanted",objective="Collect 20 Eternal Air."},
    [600970]={title="Gather Heavy Borean Leather",objective="Collect 40 Heavy Borean Leather."},
    [50206]={title="Icecrown Trophy",objective="Kill 1 Rare in Icecrown"},
    [600934]={title="Icethorn Wanted",objective="Collect 40 Icethorn."},
    [600640]={title="Into the Depths: Anub'arak",objective="Slay Anub'arak in Azjol-Nerub."},
    [600601]={title="Malygos Must Die!",objective="Slay Malygos in The Nexus Eye of Eternity."},
    [600877]={title="Material Requisition: Eternal Shadow",objective="Collect 20 Eternal Shadow."},
    [600669]={title="No Mercy: Azure Scalebane",objective="Kill 10 Azure Scalebane in Crystalsong Forest."},
    [600772]={title="Order Restored: The Oculus",objective="Kill 10 Centrifuge Construct in The Oculus."},
    [600664]={title="Pacify Winterspring: Whispering Wind",objective="Kill 10 Whispering Wind in Wintergrasp."},
    [50095]={title="Peak Predators",objective="Kill 75 Beasts in The Storm Peaks"},
    [600661]={title="Population Management: Earthbound Revenant",objective="Kill 10 Earthbound Revenant in Wintergrasp."},
    [600662]={title="Raging Flame Infestation",objective="Kill 10 Raging Flame in Wintergrasp."},
    [600842]={title="Resource Acquisition: Titanium Bar",objective="Collect 20 Titanium Bar."},
    [600876]={title="Stockpile: Eternal Life",objective="Collect 20 Eternal Life."},
    [600936]={title="Stockpile: Frost Lotus",objective="Collect 5 Frost Lotus."},
    [50205]={title="Storm Peaks Trophy",objective="Kill 1 Rare in The Storm Peaks"},
    [600644]={title="Storm the Gates: Gal'darah",objective="Slay Gal'darah in Gundrak."},
    [600878]={title="Supply Run: Eternal Fire",objective="Collect 20 Eternal Fire."},
    [600668]={title="Sweep and Clear: Azure Manashaper",objective="Kill 10 Azure Manashaper in Crystalsong Forest."},
    [600600]={title="The Fall of Sartharion",objective="Slay Sartharion in Obsidian Sanctum."},
    [600641]={title="The Menace of Ahn'kahet: Old Kingdom",objective="Slay Herald Volazj in Ahn'kahet: Old Kingdom."},
    [600658]={title="Thinning the Herd in Winterspring",objective="Kill 10 Flame Revenant in Wintergrasp."},
    [600840]={title="Titansteel Bar Supply",objective="Collect 2 Titansteel Bar."},
    [600603]={title="Topple the Tyrant: Yogg-Saron",objective="Slay Yogg-Saron in Ulduar."},
    [600873]={title="Trade Goods: Eternal Water",objective="Collect 20 Eternal Water."},
    [600933]={title="Trade Goods: Lichbloom",objective="Collect 40 Lichbloom."},
    [600637]={title="Wanted: Loken",objective="Slay Loken in Halls of Lightning."},
}

local function NewCharacterData()
    return { history = {}, active = nil, learned = {}, window = nil }
end

local function SafeObjectType(value)
    if value == nil then return nil end
    local ok, fn = pcall(function() return value.GetObjectType end)
    if not ok or type(fn) ~= "function" then return nil end
    local ok2, kind = pcall(fn, value)
    return ok2 and kind or nil
end

local function CreateText(parent, text, size, muted)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local r, g, b = RUI:GetTextColor(muted and true or false)
    RUI:StyleFontString(fs, size or 10, r, g, b)
    fs:SetText(text or "")
    return fs
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width or 100)
    button:SetHeight(height or 24)
    button.RUIText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.RUIText:SetPoint("CENTER")
    button.RUIText:SetText(text or "Button")
    RUI:StyleButton(button)
    return button
end

local function Trim(value)
    value = tostring(value or "")
    return string.gsub(string.gsub(value, "^%s+", ""), "%s+$", "")
end

local function CharacterKey()
    return RUI:GetCharacterKey()
end

function Tracker:InitDB()
    RUI.global.callboardTracker = RUI.global.callboardTracker or {}
    local root = RUI.global.callboardTracker
    root.characters = root.characters or {}
    local key = CharacterKey()
    root.characters[key] = root.characters[key] or NewCharacterData()
    self.rootDB = root
    self.db = root.characters[key]
    self.db.history = self.db.history or {}
    self.db.learned = self.db.learned or {}
end

function Tracker:QuestSnapshot()
    local out = {}
    local count = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for i = 1, count do
        local title, _, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
        if title and not isHeader then
            out[#out + 1] = { index = i, id = tonumber(questID), title = title, complete = isComplete }
        end
    end
    return out
end

function Tracker:GetQuestMeta(id)
    id = tonumber(id)
    local known = id and KNOWN_QUESTS[id]
    if known then return { id=id, title=known.title, objective=known.objective or "" } end
    local learned = self.db and self.db.learned and id and self.db.learned[id]
    if learned then return { id=id, title=learned.title or ("Quest "..tostring(id)), objective=learned.objective or "" } end
    return { id=id, title="Quest "..tostring(id or "?"), objective="" }
end

function Tracker:IsKnownBoardQuest(id)
    id = tonumber(id)
    return id and (KNOWN_QUESTS[id] ~= nil or (self.db and self.db.learned and self.db.learned[id] ~= nil))
end

function Tracker:FindByID(id, snapshot)
    id = tonumber(id)
    if not id then return nil end
    for i = 1, #(snapshot or {}) do if tonumber(snapshot[i].id) == id then return snapshot[i] end end
end

function Tracker:FindByTitle(title, snapshot)
    if not title then return nil end
    for i = 1, #(snapshot or {}) do if snapshot[i].title == title then return snapshot[i] end end
end

function Tracker:GetCooldownRemaining(id)
    id = tonumber(id)
    if not id or not self.db then return 0 end
    for i = 1, #(self.db.history or {}) do
        if tonumber(self.db.history[i]) == id then return 4 - i end
    end
    return 0
end

function Tracker:GetBoardStatus(id)
    id = tonumber(id)
    if self.db and self.db.active and tonumber(self.db.active.id) == id then return "ACTIVE", 0 end
    local remaining = self:GetCooldownRemaining(id)
    if remaining > 0 then return "COOLDOWN", remaining end
    return "AVAILABLE", 0
end

function Tracker:SetActive(id, title, objective, source)
    id = tonumber(id)
    if not id or not title or not self.db then return end
    self.db.active = { id=id, title=title, objective=objective or "", source=source or "questlog", acceptedAt=time() }
    self.db.learned[id] = self.db.learned[id] or {}
    self.db.learned[id].title = title
    if objective and objective ~= "" then self.db.learned[id].objective = objective end
    self.sessionSeenActive = true
    self.missingSince = nil
    self.pendingCompletionID = nil
    self.boardGuardUntil = 0
    self:RefreshUI()
end

function Tracker:RecordCompletion(active)
    if not active or not active.id or not self.db then return end
    local id = tonumber(active.id)
    local history = self.db.history or {}
    for i = #history, 1, -1 do if tonumber(history[i]) == id then table.remove(history, i) end end
    table.insert(history, 1, id)
    while #history > 3 do table.remove(history) end
    self.db.history = history
    self.db.active = nil
    self.sessionSeenActive = false
    self.missingSince = nil
    self.pendingCompletionID = nil
    RUI:Print("Callboard completed: " .. tostring(active.title or id) .. ". Cooldown history updated.")
    if PlaySound then pcall(PlaySound, "QUESTCOMPLETED") end
    self:RefreshUI()
end

function Tracker:ClearActive(reason)
    if self.db and self.db.active then
        if reason then RUI:Debug("Callboard active cleared: " .. tostring(reason)) end
        self.db.active = nil
    end
    self.sessionSeenActive = false
    self.missingSince = nil
    self.pendingCompletionID = nil
    self:RefreshUI()
end

function Tracker:ScanQuestLog(reason)
    if not self.db then return end
    local snapshot = self:QuestSnapshot()
    local active = self.db.active

    if active and active.id then
        local present = self:FindByID(active.id, snapshot)
        if present then
            self.sessionSeenActive = true
            self.missingSince = nil
            self.pendingCompletionID = nil
            return
        end

        if self.boardGuardUntil and GetTime() < self.boardGuardUntil then
            self:ClearActive("board replaced/rerolled")
            return
        end

        if self.abandonGuardID and tonumber(self.abandonGuardID) == tonumber(active.id) then
            self.abandonGuardID = nil
            self:ClearActive("abandoned")
            return
        end

        if self.deathPending or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
            return
        end

        if self.sessionSeenActive then
            if not self.missingSince then
                self.missingSince = GetTime()
                self.pendingCompletionID = tonumber(active.id)
                self:ArmShortTicker()
                return
            end
            if GetTime() - self.missingSince >= 1.0 then
                self:RecordCompletion(active)
            end
        end
        return
    end

    -- Discover known Board quests already present in the quest log. At level 80
    -- this catches shared raid Board quests without needing the custom Board UI.
    for i = 1, #snapshot do
        local q = snapshot[i]
        if q.id and self:IsKnownBoardQuest(q.id) then
            local meta = self:GetQuestMeta(q.id)
            self:SetActive(q.id, q.title, meta.objective, "questlog")
            return
        end
    end

    -- Resolve a Board row that Zen captured by title before the server exposed
    -- its quest ID in the log.
    if self.pendingBoardTitle and GetTime() - (self.pendingBoardAt or 0) < 15 then
        local q = self:FindByTitle(self.pendingBoardTitle, snapshot)
        if q and q.id then
            self.db.learned[q.id] = self.db.learned[q.id] or { title=q.title }
            self.pendingBoardTitle = nil
            self:SetActive(q.id, q.title, "", "board")
        end
    else
        self.pendingBoardTitle = nil
    end
end

function Tracker:ArmShortTicker()
    if not self.ticker then
        self.ticker = CreateFrame("Frame")
    end
    self.ticker.elapsed = 0
    self.ticker:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = (frame.elapsed or 0) + elapsed
        if frame.elapsed < 0.20 then return end
        frame.elapsed = 0
        if Tracker.missingSince then
            Tracker:ScanQuestLog("missing-confirm")
        else
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

local function ReadEntryTitle(entry)
    if not entry then return nil end
    local fields = { "title", "Title", "questTitle", "QuestTitle", "titleText", "TitleText", "nameText", "NameText" }
    for i = 1, #fields do
        local value = entry[fields[i]]
        if type(value) == "string" and value ~= "" then return value end
        if value and SafeObjectType(value) == "FontString" and value.GetText then
            local ok, text = pcall(value.GetText, value)
            if ok and text and text ~= "" and string.lower(text) ~= "select" then return text end
        end
    end
    if entry.GetRegions then
        local ok, regions = pcall(function() return { entry:GetRegions() } end)
        if ok then
            for i = 1, #regions do
                local region = regions[i]
                if SafeObjectType(region) == "FontString" and region.GetText then
                    local ok2, text = pcall(region.GetText, region)
                    if ok2 and text and text ~= "" and string.lower(text) ~= "select" then return text end
                end
            end
        end
    end
end

local function FindSelectButton(entry)
    if not entry then return nil end
    local direct = entry.selectBtn or entry.SelectBtn or entry.selectButton or entry.SelectButton
    if SafeObjectType(direct) == "Button" then return direct end
    if not entry.GetChildren then return nil end
    local ok, children = pcall(function() return { entry:GetChildren() } end)
    if not ok then return nil end
    for i = 1, #children do
        local child = children[i]
        if SafeObjectType(child) == "Button" and child.GetText then
            local ok2, text = pcall(child.GetText, child)
            if ok2 and text and string.lower(Trim(text)) == "select" then return child end
        end
    end
end

function Tracker:CaptureBoardSelection(entry)
    local title = ReadEntryTitle(entry)
    if not title or title == "" then return end
    self.boardGuardUntil = GetTime() + 8
    self.pendingBoardTitle = title
    self.pendingBoardAt = GetTime()
end

function Tracker:CaptureBoardInteraction()
    if self.db and self.db.active then self.boardGuardUntil = GetTime() + 5 end
end

local function HookBoardTree(frame, depth)
    if not frame or depth > 8 then return end
    if SafeObjectType(frame) == "Button" and frame.HookScript and not frame.ZenCallboardAnyHook then
        frame:HookScript("OnMouseDown", function() Tracker:CaptureBoardInteraction() end)
        frame.ZenCallboardAnyHook = true
    end
    if frame.GetChildren then
        local ok, children = pcall(function() return { frame:GetChildren() } end)
        if ok then for i = 1, #children do HookBoardTree(children[i], depth + 1) end end
    end
end

function Tracker:HookBoard()
    local board = _G.ObjectivesMainFrame
    if not board then return false end
    HookBoardTree(board, 0)
    if board.HookScript and not board.ZenCallboardShowHook then
        board:HookScript("OnShow", function() Tracker:HookBoard() end)
        board.ZenCallboardShowHook = true
    end
    for i = 1, 20 do
        local entry = _G["ObjectiveFrame" .. tostring(i)]
        local button = entry and FindSelectButton(entry)
        if button and not button.ZenCallboardSelectHook then
            button:HookScript("OnMouseDown", function() Tracker:CaptureBoardSelection(entry) end)
            button:HookScript("OnClick", function() Tracker:ScanQuestLog("board-select") end)
            button.ZenCallboardSelectHook = true
        end
    end
    return true
end

function Tracker:HookAbandon()
    local abandon = _G.QuestLogFrameAbandonButton
    if abandon and abandon.HookScript and not abandon.ZenCallboardAbandonHook then
        abandon:HookScript("OnMouseDown", function()
            local active = Tracker.db and Tracker.db.active
            if not active then return end
            local index = GetQuestLogSelection and GetQuestLogSelection() or 0
            if index and index > 0 then
                local _, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
                if not isHeader and tonumber(questID) == tonumber(active.id) then Tracker.abandonCandidateID = tonumber(active.id) end
            end
        end)
        abandon.ZenCallboardAbandonHook = true
    end
    for i = 1, 4 do
        local popup, yes = _G["StaticPopup"..i], _G["StaticPopup"..i.."Button1"]
        if popup and yes and yes.HookScript and not yes.ZenCallboardAbandonConfirmHook then
            yes:HookScript("OnMouseDown", function()
                if (popup.which == "ABANDON_QUEST" or popup.which == "ABANDON_QUEST_WITH_ITEMS") and Tracker.abandonCandidateID then
                    Tracker.abandonGuardID = Tracker.abandonCandidateID
                    Tracker.abandonCandidateID = nil
                end
            end)
            yes.ZenCallboardAbandonConfirmHook = true
        end
    end
end

function Tracker:RefreshRaidSaves()
    local saves = {}
    for i = 1, #RAID_ORDER do saves[RAID_ORDER[i]] = { ten=false, twentyfive=false, known=false } end
    if GetNumSavedInstances and GetSavedInstanceInfo then
        local count = GetNumSavedInstances() or 0
        for i = 1, count do
            local name, _, _, difficulty, locked, _, _, isRaid, maxPlayers = GetSavedInstanceInfo(i)
            if name and isRaid and locked then
                local lname = string.lower(name)
                for id, meta in pairs(RAID_QUESTS) do
                    local key = string.lower(meta.instance or "")
                    if key ~= "" and string.find(lname, key, 1, true) then
                        local state = saves[id]
                        state.known = true
                        local diff, maxp = tonumber(difficulty), tonumber(maxPlayers)
                        if maxp == 10 or diff == 1 or diff == 3 then state.ten = true
                        elseif maxp == 25 or diff == 2 or diff == 4 then state.twentyfive = true end
                    end
                end
            end
        end
        for i = 1, #RAID_ORDER do saves[RAID_ORDER[i]].known = true end
    end
    self.raidSaves = saves
    self:RefreshUI()
end

function Tracker:RequestRaidRefresh()
    if RequestRaidInfo then pcall(RequestRaidInfo) end
    self:RefreshRaidSaves()
end

local function SetTextColor(fs, r, g, b)
    if fs then fs:SetTextColor(r, g, b) end
end

function Tracker:CreateUI()
    if self.frame then return end
    local frame = CreateFrame("Frame", "ZenUICallboardTrackerFrame", UIParent)
    frame:SetWidth(690); frame:SetHeight(500); frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true); frame:EnableMouse(true); frame:Hide()
    RUI:CreateBackdrop(frame)
    frame.accent = RUI:CreateAccentLine(frame, 2)
    if RUI.RegisterExclusivePanel then RUI:RegisterExclusivePanel(frame) end
    frame.RUIExclusiveClose = function(self) self:Hide() end
    UISpecialFrames = UISpecialFrames or {}; table.insert(UISpecialFrames, "ZenUICallboardTrackerFrame")
    self.frame = frame

    frame.title = CreateText(frame, "Callboard Tracker", 13, false); frame.title:SetPoint("TOPLEFT", 16, -15)
    frame.subtitle = CreateText(frame, "Board cooldowns & raid save status", 9, true); frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 10, 0)
    frame.close = CreateButton(frame, "X", 28, 24); frame.close:SetPoint("TOPRIGHT", -10, -8); frame.close:SetScript("OnClick", function() frame:Hide() end)
    frame.refresh = CreateButton(frame, "Refresh Raid Saves", 132, 24); frame.refresh:SetPoint("TOPRIGHT", frame.close, "TOPLEFT", -8, 0); frame.refresh:SetScript("OnClick", function() Tracker:RequestRaidRefresh() end)

    frame.activeLabel = CreateText(frame, "ACTIVE BOARD QUEST", 8, true); frame.activeLabel:SetPoint("TOPLEFT", 18, -54)
    frame.active = CreateText(frame, "None detected", 11, false); frame.active:SetPoint("TOPLEFT", frame.activeLabel, "BOTTOMLEFT", 0, -5); frame.active:SetWidth(500); frame.active:SetJustifyH("LEFT")

    frame.raidLabel = CreateText(frame, "LEVEL 80 RAID BOARD QUESTS", 8, true); frame.raidLabel:SetPoint("TOPLEFT", 18, -93)
    frame.headers = {}
    local headers = { {"Quest",18,300}, {"Board",326,110}, {"10 Player",452,92}, {"25 Player",560,92} }
    for i=1,#headers do local h=CreateText(frame,headers[i][1],9,true); h:SetPoint("TOPLEFT",headers[i][2],-113); h:SetWidth(headers[i][3]); h:SetJustifyH(i==1 and "LEFT" or "CENTER"); frame.headers[i]=h end

    frame.raidRows = {}
    for i=1,#RAID_ORDER do
        local id=RAID_ORDER[i]; local meta=RAID_QUESTS[id]
        local row=CreateFrame("Frame",nil,frame); row:SetWidth(654); row:SetHeight(52); row:SetPoint("TOPLEFT",18,-132-(i-1)*57); RUI:CreateBackdrop(row)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetTexture(meta.icon or "Interface\\Icons\\INV_Misc_Note_01"); row.icon:SetWidth(34); row.icon:SetHeight(34); row.icon:SetPoint("LEFT",9,0)
        row.title=CreateText(row,meta.title,10,false); row.title:SetPoint("TOPLEFT",50,-10); row.title:SetWidth(235); row.title:SetJustifyH("LEFT")
        row.instance=CreateText(row,meta.label,8,true); row.instance:SetPoint("TOPLEFT",50,-28); row.instance:SetWidth(235); row.instance:SetJustifyH("LEFT")
        row.board=CreateText(row,"AVAILABLE",10,false); row.board:SetPoint("LEFT",300,0); row.board:SetWidth(110); row.board:SetJustifyH("CENTER")
        row.ten=CreateText(row,"UNKNOWN",9,false); row.ten:SetPoint("LEFT",424,0); row.ten:SetWidth(92); row.ten:SetJustifyH("CENTER")
        row.twentyfive=CreateText(row,"UNKNOWN",9,false); row.twentyfive:SetPoint("LEFT",532,0); row.twentyfive:SetWidth(92); row.twentyfive:SetJustifyH("CENTER")
        frame.raidRows[id]=row
    end

    frame.coolLabel=CreateText(frame,"RECENT BOARD COOLDOWNS",8,true); frame.coolLabel:SetPoint("TOPLEFT",18,-368)
    frame.coolRows={}
    for i=1,3 do
        local row=CreateFrame("Frame",nil,frame); row:SetWidth(654); row:SetHeight(28); row:SetPoint("TOPLEFT",18,-386-(i-1)*32); RUI:CreateBackdrop(row)
        row.title=CreateText(row,"-",9,false); row.title:SetPoint("LEFT",9,0); row.title:SetWidth(470); row.title:SetJustifyH("LEFT")
        row.status=CreateText(row,"",9,true); row.status:SetPoint("RIGHT",-9,0); row.status:SetWidth(150); row.status:SetJustifyH("RIGHT")
        frame.coolRows[i]=row
    end
    frame.hint=CreateText(frame,"Tracks the last 3 completed Board quests. Raid saves refresh only on events or when you press Refresh.",8,true); frame.hint:SetPoint("BOTTOMLEFT",18,12); frame.hint:SetWidth(650); frame.hint:SetJustifyH("LEFT")
end

function Tracker:RefreshUI()
    local frame=self.frame; if not frame or not self.db then return end
    local active=self.db.active
    if active then frame.active:SetText(tostring(active.title).."  |cff888888("..tostring(active.id)..")|r") else frame.active:SetText("None detected") end
    for i=1,#RAID_ORDER do
        local id=RAID_ORDER[i]; local row=frame.raidRows[id]
        local status, remaining=self:GetBoardStatus(id)
        if status=="ACTIVE" then row.board:SetText("ACTIVE"); SetTextColor(row.board,1.0,0.72,0.20)
        elseif status=="COOLDOWN" then row.board:SetText(tostring(remaining).." / 3"); SetTextColor(row.board,1.0,remaining==1 and 0.25 or 0.55,0.16)
        else row.board:SetText("AVAILABLE"); SetTextColor(row.board,0.35,1.0,0.50) end
        local save=self.raidSaves and self.raidSaves[id]
        local function ApplySave(fs, locked)
            if not save or not save.known then fs:SetText("UNKNOWN"); SetTextColor(fs,0.55,0.57,0.61)
            elseif locked then fs:SetText("SAVED"); SetTextColor(fs,1.0,0.30,0.30)
            else fs:SetText("AVAILABLE"); SetTextColor(fs,0.35,1.0,0.50) end
        end
        ApplySave(row.ten, save and save.ten); ApplySave(row.twentyfive, save and save.twentyfive)
    end
    local history=self.db.history or {}
    for i=1,3 do
        local row=frame.coolRows[i]; local id=history[i]
        if id then
            local meta=self:GetQuestMeta(id); row.title:SetText(meta.title); row.status:SetText(tostring(4-i).." more completion"..((4-i)==1 and "" or "s").." to unlock")
        else row.title:SetText("-"); row.status:SetText("") end
    end
end

function Tracker:Toggle()
    if not self.frame then self:CreateUI() end
    if self.frame:IsShown() then self.frame:Hide(); return end
    self:ScanQuestLog("open")
    self:RequestRaidRefresh()
    self:RefreshUI()
    self.frame:Show()
end

function Tracker:OnEvent(event)
    if event == "PLAYER_ENTERING_WORLD" then
        self.sessionSeenActive = false
        self.deathPending = false
        self:HookBoard(); self:HookAbandon(); self:ScanQuestLog("enter-world"); self:RefreshRaidSaves()
    elseif event == "QUEST_LOG_UPDATE" then
        self:HookBoard(); self:HookAbandon(); self:ScanQuestLog("quest-log"); self:RefreshUI()
    elseif event == "UPDATE_INSTANCE_INFO" then
        self:RefreshRaidSaves()
    elseif event == "PLAYER_DEAD" then
        self.deathPending = true; self.missingSince = nil; self.pendingCompletionID = nil
    elseif event == "PLAYER_ALIVE" then
        local wasDead = self.deathPending; self.deathPending = false
        if wasDead and self.db and self.db.active then
            local snapshot=self:QuestSnapshot()
            if not self:FindByID(self.db.active.id,snapshot) then self:ClearActive("lost on death") else self:ScanQuestLog("alive") end
        else self:ScanQuestLog("alive") end
    end
end

function Tracker:OnInitialize()
    self:InitDB()
    self:CreateUI()
    self:RefreshRaidSaves()
    RUI:RegisterCallback("APPEARANCE_CHANGED", self, function(module)
        if module.frame then
            RUI:RefreshBackdrop(module.frame); RUI:SetAccentTexture(module.frame.accent)
            RUI:StyleButton(module.frame.close); RUI:StyleButton(module.frame.refresh)
            for _, row in pairs(module.frame.raidRows or {}) do RUI:RefreshBackdrop(row) end
            for i=1,#(module.frame.coolRows or {}) do RUI:RefreshBackdrop(module.frame.coolRows[i]) end
        end
    end)
end

function Tracker:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
    self:RegisterEvent("QUEST_LOG_UPDATE", "OnEvent")
    self:RegisterEvent("UPDATE_INSTANCE_INFO", "OnEvent")
    self:RegisterEvent("PLAYER_DEAD", "OnEvent")
    self:RegisterEvent("PLAYER_ALIVE", "OnEvent")
    self:HookBoard(); self:HookAbandon(); self:ScanQuestLog("enable")
end

function Tracker:GetStatusSummary()
    local active = self.db and self.db.active
    return active and active.title or "No active Board quest"
end
