-- ZenUI 0.9.56 unified bag window + native equipped-bag manager.
-- Uses the native 3.3.5 ContainerFrame item-button template for item interactions.

local RUI = ZenUI
local Bags = RUI:NewModule("Bags")

local BAG_MIN, BAG_MAX = 0, 4
local KEYRING_ID = KEYRING_CONTAINER or -2
local BANK_ID = BANK_CONTAINER or -1
local BANK_BAG_FIRST = (NUM_BAG_SLOTS or 4) + 1
local BANK_BAG_LAST = BANK_BAG_FIRST + (NUM_BANKBAGSLOTS or 7) - 1
local HEADER_HEIGHT = 54
local FOOTER_HEIGHT = 36
local PADDING = 12

local CONTAINER_TOGGLES = {
    { key = "backpack", label = "BP", tooltip = "Backpack" },
    { key = "bag1", label = "1", tooltip = "Bag 1" },
    { key = "bag2", label = "2", tooltip = "Bag 2" },
    { key = "bag3", label = "3", tooltip = "Bag 3" },
    { key = "bag4", label = "4", tooltip = "Bag 4" },
    { key = "keyring", label = "K", tooltip = "Keyring" },
    { key = "bank", label = "BNK", tooltip = "Bank container", bankOnly = true },
    { key = "bankBags", label = "B+", tooltip = "Bank bags", bankOnly = true },
}

local function GetSettings()
    return RUI.db and RUI.db.bags
end

local function CreateText(parent, text, size, muted)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local r, g, b = RUI:GetTextColor(muted and true or false)
    RUI:StyleFontString(fs, size or 10, r, g, b)
    fs:SetText(text or "")
    return fs
end

local function CreateButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width or 28)
    button:SetHeight(height or 24)
    button:EnableMouse(true)
    RUI:StyleButton(button)
    button.label = CreateText(button, label or "", 10, false)
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    return button
end

local function ItemNameFromLink(link)
    if not link then return nil end
    if GetItemInfo then
        local name = GetItemInfo(link)
        if name then return name end
    end
    return string.match(link, "%[(.-)%]")
end

local function IsBankOpen()
    -- When Zen's dedicated Bank replacement owns the banker session the
    -- native BankFrame remains logically shown at alpha 0.  Treat that as NOT
    -- being a Bags-window bank mode; otherwise opening normal Bags while the
    -- Zen Bank is open duplicates the entire bank inside the bag window.
    if BankFrame and BankFrame.RUIPhaseBSuppressed then return false end
    return BankFrame and BankFrame.IsShown and BankFrame:IsShown() and true or false
end

local function FormatMoney(copper)
    copper = math.max(0, tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local coins = copper % 100

    return string.format(
        "|cffffd700%dg|r  |cffc7c7cf%02ds|r  |cffeda55f%02dc|r",
        gold, silver, coins
    )
end

local function GetMoneyStore()
    if not RUI.dbRoot then return nil end
    RUI.dbRoot.global = RUI.dbRoot.global or {}
    RUI.dbRoot.global.characterMoney = RUI.dbRoot.global.characterMoney or {}
    return RUI.dbRoot.global.characterMoney
end

function Bags:UpdateMoneyCache()
    local store = GetMoneyStore()
    if not store or not GetMoney then return end

    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Unknown"
    local key = RUI.GetCharacterKey and RUI:GetCharacterKey() or (name .. " - " .. realm)
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil

    store[key] = store[key] or {}
    store[key].name = name
    store[key].realm = realm
    store[key].faction = faction
    store[key].money = math.max(0, tonumber(GetMoney()) or 0)
    if time then store[key].updated = time() end
end

function Bags:ShowMoneyTooltip(owner)
    if not GameTooltip then return end
    self:UpdateMoneyCache()

    local store = GetMoneyStore() or {}
    local currentKey = RUI.GetCharacterKey and RUI:GetCharacterKey() or nil
    local currentRealm = GetRealmName and GetRealmName() or "Unknown"
    local rows = {}
    local total = 0

    for key, data in pairs(store) do
        if type(data) == "table" then
            local money = math.max(0, tonumber(data.money) or 0)
            total = total + money
            table.insert(rows, {
                key = key,
                name = data.name or string.match(key, "^(.-) %- ") or key,
                realm = data.realm or "Unknown",
                money = money,
            })
        end
    end

    table.sort(rows, function(a, b)
        if a.key == currentKey and b.key ~= currentKey then return true end
        if b.key == currentKey and a.key ~= currentKey then return false end
        local aSame = a.realm == currentRealm
        local bSame = b.realm == currentRealm
        if aSame ~= bSame then return aSame end
        if a.realm ~= b.realm then return tostring(a.realm) < tostring(b.realm) end
        return tostring(a.name) < tostring(b.name)
    end)

    GameTooltip:SetOwner(owner or self.frame, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("Zen Gold", 1, 0.82, 0.20)
    GameTooltip:AddLine("Last-known character balances", 0.62, 0.64, 0.68)

    if #rows == 0 then
        GameTooltip:AddLine("No character balances recorded yet.", 0.75, 0.75, 0.75)
    else
        for i = 1, #rows do
            local row = rows[i]
            local label = row.name
            if row.realm ~= currentRealm then
                label = label .. " - " .. row.realm
            end
            if row.key == currentKey then label = "|cffffffff" .. label .. "|r" end
            GameTooltip:AddDoubleLine(label, FormatMoney(row.money), 0.86, 0.87, 0.90, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total", FormatMoney(total), 1, 0.82, 0.20, 1, 1, 1)
    end

    GameTooltip:AddLine("Balances update when each character is played.", 0.52, 0.54, 0.58, true)
    GameTooltip:Show()
end

local function BagFrameToken(bag)
    if bag == KEYRING_ID then return "Keyring" end
    if bag == BANK_ID then return "Bank" end
    return tostring(bag):gsub("%-", "N")
end

local function GetCarriedBagInventorySlot(bag)
    bag=tonumber(bag)
    if not bag or bag<1 or bag>(tonumber(NUM_BAG_SLOTS) or 4) then return nil end
    local native=_G["CharacterBag"..tostring(bag-1).."Slot"]
    if native and native.GetID then
        local ok,id=pcall(native.GetID,native)
        if ok and tonumber(id) and tonumber(id)>0 then return tonumber(id) end
    end
    if ContainerIDToInventoryID then
        local ok,slot=pcall(ContainerIDToInventoryID,bag)
        if ok and tonumber(slot) then return tonumber(slot) end
    end
    return (tonumber(_G.INVSLOT_BAG1) or 20)+(bag-1)
end

local function GetContainerSlotCount(bag)
    if bag == KEYRING_ID and GetKeyRingSize then
        return tonumber(GetKeyRingSize()) or 0
    end
    -- On this client GetContainerNumSlots can briefly retain the removed bag's
    -- old capacity after the equipped-bag slot has already been emptied.  The
    -- inventory slot is authoritative for whether bags 1-4 actually exist, so
    -- collapse that container immediately instead of leaving ghost slots until
    -- the next unrelated BAG_UPDATE.
    if tonumber(bag) and tonumber(bag)>=1 and tonumber(bag)<=(tonumber(NUM_BAG_SLOTS) or 4) then
        local inv=GetCarriedBagInventorySlot(bag)
        if inv and GetInventoryItemTexture and not GetInventoryItemTexture("player",inv) then
            return 0
        end
    end
    return tonumber(GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
end

local function NativeEquippedBagButton(bag)
    bag=tonumber(bag)
    if not bag or bag<1 or bag>(tonumber(NUM_BAG_SLOTS) or 4) then return nil end
    return _G["CharacterBag"..tostring(bag-1).."Slot"]
end

local function EquippedBagInventorySlot(bag)
    -- Shared with the unified-grid slot-count guard above so both the bag
    -- manager and layout use the exact same authoritative inventory mapping.
    return GetCarriedBagInventorySlot(bag)
end

local function BagItemNameFromInventorySlot(invSlot)
    if not invSlot or not GetInventoryItemLink then return nil end
    local link=GetInventoryItemLink("player",invSlot)
    return ItemNameFromLink(link)
end

local function GetContainerSettings()
    local settings = GetSettings() or {}
    settings.containers = settings.containers or {}
    return settings.containers
end

function Bags:IsContainerIncluded(bag)
    local c = GetContainerSettings()
    if bag == 0 then return c.backpack ~= false end
    if bag >= 1 and bag <= 4 then return c["bag" .. tostring(bag)] ~= false end
    if bag == KEYRING_ID then return c.keyring ~= false end
    if bag == BANK_ID then return c.bank == true and IsBankOpen() end
    if bag >= BANK_BAG_FIRST and bag <= BANK_BAG_LAST then return c.bankBags == true and IsBankOpen() end
    return false
end

function Bags:GetActiveContainerIDs()
    local ids = {}
    for bag = BAG_MIN, BAG_MAX do
        if self:IsContainerIncluded(bag) then table.insert(ids, bag) end
    end
    if self:IsContainerIncluded(KEYRING_ID) then table.insert(ids, KEYRING_ID) end
    if self:IsContainerIncluded(BANK_ID) then table.insert(ids, BANK_ID) end
    if IsBankOpen() then
        for bag = BANK_BAG_FIRST, BANK_BAG_LAST do
            if self:IsContainerIncluded(bag) then table.insert(ids, bag) end
        end
    end
    return ids
end


-- Native bag sorting did not exist on every 3.3.5 client, while some Ebonhold
-- builds expose a backported sorter. Prefer the client's own implementation
-- when present. Otherwise Zen performs a deliberately paced, event-light sort:
-- one inventory click is issued per short step, and the sorter waits for the
-- client to finish each move before continuing. Inventory changes caused by the
-- sorter itself are expected and are never treated as an error.
local function ModifierDown(name)
    name=string.upper(tostring(name or ""))
    if name=="SHIFT" then return IsShiftKeyDown and IsShiftKeyDown() and true or false end
    if name=="CTRL" then return IsControlKeyDown and IsControlKeyDown() and true or false end
    if name=="ALT" then return IsAltKeyDown and IsAltKeyDown() and true or false end
    return false
end

local function BagDebugName(frame)
    if not frame then return "nil" end
    if frame.GetName then
        local ok,name=pcall(frame.GetName,frame)
        if ok and name and name~="" then return tostring(name) end
    end
    return tostring(frame)
end

local function BagBool(value)
    return value and "true" or "false"
end

function Bags:DebugPrint(message)
    RUI:Print("BAGTRACE: "..tostring(message or ""))
end

function Bags:SetBagTrace(enabled)
    self.bagTrace=enabled and true or false
    self:DebugPrint("click trace "..(self.bagTrace and "ON" or "OFF"))
end

function Bags:PrintBagDoctor()
    RUI:Print("=== ZenUI Bag Doctor ===")
    local splitMod="unknown"
    if GetModifiedClick then
        local ok,value=pcall(GetModifiedClick,"SPLITSTACK")
        if ok and value then splitMod=tostring(value) end
    end
    local socketMod="unknown"
    if GetModifiedClick then
        local ok,value=pcall(GetModifiedClick,"SOCKETITEM")
        if ok and value then socketMod=tostring(value) end
    end
    RUI:Print("Modifiers: SPLITSTACK="..splitMod.." SOCKETITEM="..socketMod.." physicalShift="..BagBool(IsShiftKeyDown and IsShiftKeyDown()))
    RUI:Print("Split APIs: OpenStackSplitFrame="..tostring(type(OpenStackSplitFrame)).." SplitContainerItem="..tostring(type(SplitContainerItem)).." StackSplitFrame="..BagDebugName(_G.StackSplitFrame))
    if _G.StackSplitFrame then
        local f=_G.StackSplitFrame
        RUI:Print("StackSplitFrame shown="..BagBool(f.IsShown and f:IsShown()).." parent="..BagDebugName(f.GetParent and f:GetParent()).." strata="..tostring(f.GetFrameStrata and f:GetFrameStrata() or "?").." level="..tostring(f.GetFrameLevel and f:GetFrameLevel() or "?"))
    end
    RUI:Print("Sort APIs: SortBags="..tostring(type(_G.SortBags)).." SortBankBags="..tostring(type(_G.SortBankBags)).." C_Container="..tostring(type(_G.C_Container)))
    if type(_G.C_Container)=="table" then
        RUI:Print("C_Container.SortBags="..tostring(type(_G.C_Container.SortBags)).." C_Container.SortBankBags="..tostring(type(_G.C_Container.SortBankBags)))
    end
    local focus=GetMouseFocus and GetMouseFocus() or nil
    RUI:Print("Mouse focus="..BagDebugName(focus))
    local node=focus
    for depth=1,6 do
        if not node then break end
        local bag=node.RUIBag
        local slot=node.RUISlot
        if bag~=nil and slot~=nil then
            local _,count,locked=GetContainerItemInfo and GetContainerItemInfo(bag,slot)
            local link=GetContainerItemLink and GetContainerItemLink(bag,slot)
            RUI:Print("Hovered Zen slot: bag="..tostring(bag).." slot="..tostring(slot).." count="..tostring(count or 0).." locked="..BagBool(locked).." link="..tostring(link or "nil"))
            if node.GetAttribute then
                RUI:Print("Secure attrs: type1="..tostring(node:GetAttribute("type1")).." shift-type1="..tostring(node:GetAttribute("shift-type1")).." type2="..tostring(node:GetAttribute("type2")).." shift-type2="..tostring(node:GetAttribute("shift-type2")))
            end
            break
        end
        node=node.GetParent and node:GetParent() or nil
    end
    RUI:Print("Queued Zen physical sorter available="..BagBool(self:HasAtomicSort()))
    RUI:Print("Use /zenui bagtrace on, then Shift+Left Click and Shift+Right Click a stack.")
    RUI:Print("=== End Bag Doctor ===")
end

local function ContainerFamily(bag)
    if GetContainerNumFreeSlots then
        local ok,_,family=pcall(GetContainerNumFreeSlots,bag)
        if ok then return tonumber(family) or 0 end
    end
    return 0
end

local function ReadSortRecord(bag,slot)
    local link=GetContainerItemLink and GetContainerItemLink(bag,slot)
    if not link then return nil end
    local _,count,locked=GetContainerItemInfo and GetContainerItemInfo(bag,slot)
    if locked then return nil,"locked" end
    local name,quality,class,subclass,equipLoc
    if GetItemInfo then
        local ok,a,_,c,_,_,f,g,_,i=pcall(GetItemInfo,link)
        if ok then name,quality,class,subclass,equipLoc=a,c,f,g,i end
    end
    local itemID=tonumber(string.match(link,"item:(%-?%d+)")) or 0
    return {
        link=link,
        count=tonumber(count) or 1,
        name=string.lower(tostring(name or link)),
        quality=tonumber(quality) or -1,
        class=string.lower(tostring(class or "")),
        subclass=string.lower(tostring(subclass or "")),
        equipLoc=string.lower(tostring(equipLoc or "")),
        itemID=itemID,
    }
end

local function SortRecordLess(a,b)
    if a.class~=b.class then return a.class<b.class end
    if a.subclass~=b.subclass then return a.subclass<b.subclass end
    if a.equipLoc~=b.equipLoc then return a.equipLoc<b.equipLoc end
    if a.quality~=b.quality then return a.quality>b.quality end
    if a.name~=b.name then return a.name<b.name end
    return a.itemID<b.itemID
end

-- Physical sorting keeps Zen's displayed slot positions identical to the real
-- server inventory. The retired 0.9.182 visual-sort helpers are intentionally
-- gone so a visible slot can never point at a different hidden bag position.

local function PositionLink(pos)
    return pos and GetContainerItemLink and GetContainerItemLink(pos.bag,pos.slot) or nil
end

local function PositionLocked(pos)
    if not pos or not GetContainerItemInfo then return false end
    local _,_,locked=GetContainerItemInfo(pos.bag,pos.slot)
    return locked and true or false
end

local function BuildWantedForPositions(positions)
    local wanted={}
    for _,pos in ipairs(positions) do
        local rec,err=ReadSortRecord(pos.bag,pos.slot)
        if err=="locked" then return nil,"locked" end
        if rec then wanted[#wanted+1]=rec end
    end
    table.sort(wanted,SortRecordLess)
    return wanted
end

local function FindNextSortMove(positions)
    local wanted,err=BuildWantedForPositions(positions)
    if not wanted then return nil,nil,nil,nil,err end

    for i=1,#wanted do
        local target=positions[i]
        local current=PositionLink(target)
        local desired=wanted[i].link
        if current~=desired then
            local source
            for j=i+1,#positions do
                local pos=positions[j]
                if PositionLink(pos)==desired then source=pos; break end
            end
            if not source then return nil,nil,nil,nil,"wait" end
            return target,source,current,desired,nil
        end
    end
    return nil,nil,nil,nil,"done"
end

local CursorOccupied, RestoreSorterCursor

function Bags:StopSort(message)
    local state=self.sortState
    if state and state.pending and CursorOccupied() then RestoreSorterCursor(state.pending.source) end
    self.sortState=nil
    if self.sortDriver then self.sortDriver:SetScript("OnUpdate",nil); self.sortDriver:Hide() end
    self:RefreshSortButtonState()
    if message and message~="" then RUI:Print(message) end
    if self.Update and self.frame and self.frame:IsShown() then self:Update() end
end

function Bags:EnsureSortDriver()
    if self.sortDriver then return self.sortDriver end
    local f=CreateFrame("Frame")
    f:Hide()
    self.sortDriver=f
    return f
end

CursorOccupied = function()
    return GetCursorInfo and GetCursorInfo() and true or false
end

local function LinkItemID(link)
    return link and tonumber(string.match(link,"item:(%-?%d+)")) or nil
end

RestoreSorterCursor = function(source)
    if not CursorOccupied() then return true end
    if source and PickupContainerItem and not PositionLocked(source) then
        pcall(PickupContainerItem,source.bag,source.slot)
    end
    if CursorOccupied() and ClearCursor then
        -- This is only used for a cursor item Zen itself picked up. On Wrath,
        -- ClearCursor returns a container pickup to its originating slot.
        pcall(ClearCursor)
    end
    return not CursorOccupied()
end

local function BeginQueuedMove(state,source,target,desiredLink)
    if not source or not target or not PickupContainerItem then return false,"api" end
    if CursorOccupied() then return false,"cursor" end
    if PositionLocked(source) or PositionLocked(target) then return false,"locked" end

    local sourceLink=PositionLink(source)
    local targetLink=PositionLink(target)
    if not sourceLink then return false,"source-empty" end
    if desiredLink and sourceLink~=desiredLink then return false,"changed" end

    local pending={
        source=source,
        target=target,
        sourceLink=sourceLink,
        targetLink=targetLink,
        sourceID=LinkItemID(sourceLink),
        targetID=LinkItemID(targetLink),
        started=(GetTime and GetTime()) or 0,
        phase="pickup",
        retries=0,
    }
    state.pending=pending

    -- Same two native calls used by established Wrath bag sorters. Do not
    -- inspect the destination synchronously; Ebonhold applies bag locks and
    -- BAG_UPDATE asynchronously, so immediate verification creates false
    -- failures. We track the expected move and wait for the slots to settle.
    pcall(PickupContainerItem,source.bag,source.slot)
    if not CursorOccupied() then
        state.pending=nil
        return false,"pickup"
    end

    pcall(PickupContainerItem,target.bag,target.slot)
    pending.phase=CursorOccupied() and "return" or "settle"
    pending.started=(GetTime and GetTime()) or 0
    return true
end

local function PendingMoveSettled(pending)
    local sourceNow=PositionLink(pending.source)
    local targetNow=PositionLink(pending.target)
    if targetNow~=pending.sourceLink then return false end
    if pending.targetLink then
        return sourceNow==pending.targetLink
    end
    return sourceNow==nil
end

function Bags:AdvancePendingSortMove(state)
    local pending=state and state.pending
    if not pending then return true end
    local now=(GetTime and GetTime()) or 0

    if pending.phase=="return" then
        if not CursorOccupied() then
            pending.phase="settle"
            pending.started=now
            return false
        end

        -- An occupied destination can leave its displaced item on the cursor.
        -- Return that item to the source slot once Ebonhold releases the lock.
        if not PositionLocked(pending.source) and PickupContainerItem then
            local cursorType,cursorID=GetCursorInfo and GetCursorInfo()
            if cursorType=="item" and pending.targetID and cursorID and tonumber(cursorID)~=tonumber(pending.targetID) then
                RestoreSorterCursor(pending.source)
                self:StopSort("Sorting stopped because the cursor changed unexpectedly.")
                return false
            end
            pcall(PickupContainerItem,pending.source.bag,pending.source.slot)
            pending.retries=(pending.retries or 0)+1
            if not CursorOccupied() then
                pending.phase="settle"
                pending.started=now
                return false
            end
        end

        if (now-(pending.started or now))>1.25 or (pending.retries or 0)>30 then
            RestoreSorterCursor(pending.source)
            self:StopSort("Sorting stopped because an item move did not finish in time.")
        end
        return false
    end

    if CursorOccupied() then
        pending.phase="return"
        pending.started=now
        return false
    end

    if PositionLocked(pending.source) or PositionLocked(pending.target) then
        if (now-(pending.started or now))>1.25 then
            state.pending=nil
            state.failures=(state.failures or 0)+1
            if state.failures>8 then self:StopSort("Sorting stopped because item slots remained locked.") end
        end
        return false
    end

    if PendingMoveSettled(pending) then
        if self.bagTrace then
            self:DebugPrint("sort settled "..tostring(pending.source.bag)..":"..tostring(pending.source.slot).." -> "..tostring(pending.target.bag)..":"..tostring(pending.target.slot))
        end
        state.pending=nil
        state.moves=(state.moves or 0)+1
        state.failures=0
        return true
    end

    -- Give BAG_UPDATE a little time before deciding the move failed. If it
    -- genuinely did not commit, drop the pending record and recompute from
    -- authoritative bag state instead of trying to force stale coordinates.
    if (now-(pending.started or now))>0.45 then
        state.pending=nil
        state.failures=(state.failures or 0)+1
        if state.failures>8 then
            self:StopSort("Sorting stopped because Ebonhold did not confirm the item move.")
        end
    end
    return false
end

function Bags:AdvanceSort()
    local state=self.sortState
    if not state then return end

    if state.pending then
        self:AdvancePendingSortMove(state)
        return
    end

    if CursorOccupied() then
        self:StopSort("Sorting stopped because the cursor is occupied. Clear it and press Sort again.")
        return
    end

    local group=state.groups[state.groupIndex]
    if not group then
        self:StopSort("Finished sorting "..tostring(state.label or "items")..".")
        return
    end

    local target,source,targetLink,desiredLink,err=FindNextSortMove(group.positions)
    if err=="locked" or err=="wait" then return end
    if err=="done" then
        state.groupIndex=state.groupIndex+1
        return
    end

    local ok,why=BeginQueuedMove(state,source,target,desiredLink)
    if ok then
        if self.bagTrace then
            self:DebugPrint("sort move "..tostring(source.bag)..":"..tostring(source.slot).." -> "..tostring(target.bag)..":"..tostring(target.slot))
        end
        return
    end

    if why=="locked" or why=="changed" or why=="pickup" then
        state.failures=(state.failures or 0)+1
        if state.failures<12 then return end
    end

    self:StopSort("Sorting stopped safely ("..tostring(why or "unknown")..").")
end

function Bags:SortContainerIDs(ids,label)
    if self.sortState then
        RUI:Print("A sort is already running.")
        return false
    end
    if GetCursorInfo and GetCursorInfo() then
        RUI:Print("Clear your cursor before sorting "..tostring(label or "items")..".")
        return false
    end

    local byFamily={}
    local families={}
    for _,bag in ipairs(ids or {}) do
        local slots=tonumber(GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
        if slots>0 then
            local family=ContainerFamily(bag)
            if not byFamily[family] then
                byFamily[family]={}
                families[#families+1]=family
            end
            for slot=1,slots do byFamily[family][#byFamily[family]+1]={bag=bag,slot=slot} end
        end
    end
    table.sort(families)

    local groups={}
    for _,family in ipairs(families) do
        groups[#groups+1]={family=family,positions=byFamily[family]}
    end
    if #groups==0 then return false end

    self.sortState={groups=groups,groupIndex=1,label=label or "items",failures=0,moves=0}
    local driver=self:EnsureSortDriver()
    driver.elapsed=0
    driver:SetScript("OnUpdate",function(_,elapsed)
        driver.elapsed=(driver.elapsed or 0)+(elapsed or 0)
        if driver.elapsed<0.05 then return end
        driver.elapsed=0
        Bags:AdvanceSort()
    end)
    driver:Show()
    self:RefreshSortButtonState()
    RUI:Print("Sorting "..tostring(label or "items").."...")
    return true
end

function Bags:HasNativeBagSort()
    local c=_G.C_Container
    return type(_G.SortBags)=="function" or (type(c)=="table" and type(c.SortBags)=="function")
end

function Bags:HasNativeBankSort()
    local c=_G.C_Container
    return type(_G.SortBankBags)=="function" or (type(c)=="table" and type(c.SortBankBags)=="function")
end

function Bags:HasAtomicSort()
    -- Zen provides a real queued 3.3.5 sorter when the client has no native
    -- sorting API. It plans/rechecks moves against authoritative bag slots and
    -- waits for Ebonhold item locks between operations.
    return type(PickupContainerItem)=="function"
end

-- Kept as compatibility shims for profiles made by 0.9.182/0.9.183. Visual
-- sorting is retired because a displayed position must always match the real
-- inventory slot the player is interacting with.
function Bags:IsVisualBagSortEnabled() return false end
function Bags:IsVisualBankSortEnabled() return false end

function Bags:CanSortPlayerBags()
    return self:HasNativeBagSort() or self:HasAtomicSort()
end

function Bags:CanSortBankBags()
    return self:HasNativeBankSort() or self:HasAtomicSort()
end

function Bags:RefreshSortButtonState()
    local running=self.sortState and true or false
    if self.frame and self.frame.sort and self.frame.sort.label then
        self.frame.sort.label:SetText(running and "SORTING" or "SORT")
    end
    local phaseB=RUI:GetModule("BlizzardPhaseB")
    local bank=phaseB and phaseB.frames and phaseB.frames.bank
    if bank and bank.sort then
        if bank.sort.SetText then bank.sort:SetText(running and "SORTING" or "SORT") end
        if bank.sort.label then bank.sort.label:SetText(running and "SORTING" or "SORT") end
    end
end

function Bags:SortPlayerBags()
    if self.sortState then
        self:StopSort("Bag sorting cancelled.")
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        RUI:Print("Cannot sort bags in combat.")
        return false
    end
    local c=_G.C_Container
    if type(_G.SortBags)=="function" then
        local ok,err=pcall(_G.SortBags)
        if not ok then RUI:Print("Native bag sort failed: "..tostring(err)) end
        return ok
    elseif type(c)=="table" and type(c.SortBags)=="function" then
        local ok,err=pcall(c.SortBags)
        if not ok then RUI:Print("Native bag sort failed: "..tostring(err)) end
        return ok
    end
    local ids={}
    for bag=BAG_MIN,BAG_MAX do ids[#ids+1]=bag end
    return self:SortContainerIDs(ids,"bags")
end

function Bags:SortBankBags()
    if self.sortState then
        self:StopSort("Bank sorting cancelled.")
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        RUI:Print("Cannot sort the bank in combat.")
        return false
    end
    local c=_G.C_Container
    if type(_G.SortBankBags)=="function" then
        local ok,err=pcall(_G.SortBankBags)
        if not ok then RUI:Print("Native bank sort failed: "..tostring(err)) end
        return ok
    elseif type(c)=="table" and type(c.SortBankBags)=="function" then
        local ok,err=pcall(c.SortBankBags)
        if not ok then RUI:Print("Native bank sort failed: "..tostring(err)) end
        return ok
    end
    local ids={BANK_ID}
    for bag=BANK_BAG_FIRST,BANK_BAG_LAST do ids[#ids+1]=bag end
    return self:SortContainerIDs(ids,"bank")
end

function Bags:GetContainerLabel(bag)
    if bag == 0 then return "Backpack" end
    if bag >= 1 and bag <= 4 then return "Bag " .. tostring(bag) end
    if bag == KEYRING_ID then return "Keyring" end
    if bag == BANK_ID then return "Bank" end
    if bag >= BANK_BAG_FIRST and bag <= BANK_BAG_LAST then return "Bank Bag " .. tostring(bag - BANK_BAG_FIRST + 1) end
    return "Bag " .. tostring(bag)
end

function Bags:CreateFrame()
    local frame = CreateFrame("Frame", "ZenUIBagFrame", UIParent)
    frame:SetWidth(500)
    frame:SetHeight(280)
    -- Keep the bag shell below Blizzard's DIALOG/FULLSCREEN_DIALOG layers.
    -- StaticPopup, StackSplitFrame and other native interaction windows must
    -- always appear above the bag window.
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(80)
    frame:SetClampedToScreen(true)
    if frame.SetToplevel then frame:SetToplevel(true) end
    -- The shell itself does not need a mouse hit-region. Keeping it disabled
    -- prevents the large backdrop from ever winning hit-testing over slots.
    frame:EnableMouse(false)
    frame:Hide()
    -- The equipped-bag manager is a top-level FULLSCREEN_DIALOG frame so it can
    -- receive mouse input above the unified inventory. Tie its lifetime back to
    -- the Bags shell explicitly: every fresh bag-open starts with the manager
    -- closed, and any path that hides Bags also closes the pop-out.
    frame:SetScript("OnShow",function(self)
        if self.bagManager and self.bagManager:IsShown() then self.bagManager:Hide() end
        if self.dragHandle then self.dragHandle:Show() end
        Bags:RefreshContents()
    end)
    frame:SetScript("OnHide",function(self)
        if self.bagManager and self.bagManager:IsShown() then self.bagManager:Hide() end
        if self.dragHandle then self.dragHandle:Hide() end
        Bags:ClearEquippedBagContentHighlight()
    end)
    -- Bag equip/remove state is asynchronous on Ebonhold.  Poll briefly after
    -- structural equipment changes so the unified grid collapses/expands as
    -- soon as the client finishes updating the container rather than waiting
    -- for the player to interact with another item.
    frame:SetScript("OnUpdate",function(_,elapsed) Bags:ProcessStructureRefresh(elapsed) end)
    RUI:CreateBackdrop(frame)
    frame.accent = RUI:CreateAccentLine(frame, 2)

    frame.title = CreateText(frame, "BAGS", 12, false)
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -14)

    -- Bags deliberately keeps its large outer shell mouse-disabled so the
    -- unified item containers always win slot hit-testing.  On Ebonhold, a
    -- mouse-disabled parent can also prevent an enabled child header from ever
    -- receiving drag events (the 0.9.186 regression).  Make the drag strip an
    -- independent UIParent child anchored to the Bags title instead.  It follows
    -- the panel/mover but is not inside the mouse-disabled hierarchy.
    frame.dragHandle = CreateFrame("Frame", "ZenUIBagDirectDragHandle", UIParent)
    frame.dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
    frame.dragHandle:SetWidth(190)
    frame.dragHandle:SetHeight(34)
    frame.dragHandle:SetFrameStrata("HIGH")
    frame.dragHandle:SetFrameLevel(frame:GetFrameLevel() + 19)
    frame.dragHandle:EnableMouse(true)
    frame.dragHandle:Hide()

    frame.count = CreateText(frame, "", 9, true)
    frame.count:SetPoint("LEFT", frame.title, "RIGHT", 10, 0)

    frame.moneyHit = CreateFrame("Button", nil, frame)
    frame.moneyHit:SetWidth(210)
    frame.moneyHit:SetHeight(22)
    frame.moneyHit:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.moneyHit:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -28)
    frame.moneyHit:RegisterForClicks("LeftButtonUp")
    frame.moneyHit:SetScript("OnEnter", function(self) Bags:ShowMoneyTooltip(self) end)
    frame.moneyHit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    frame.money = CreateText(frame.moneyHit, "", 9, false)
    frame.money:SetPoint("RIGHT", frame.moneyHit, "RIGHT", 0, 0)
    frame.money:SetJustifyH("RIGHT")

    frame.close = CreateButton(frame, "X", 24, 22)
    frame.close:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    frame.close:SetScript("OnClick", function() Bags:Hide() end)

    frame.search = CreateFrame("EditBox", "ZenUIBagSearch", frame)
    frame.search:SetWidth(190)
    frame.search:SetHeight(22)
    frame.search:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.search:EnableMouse(true)
    frame.search:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -9)
    frame.search:SetAutoFocus(false)
    frame.search:SetMaxLetters(64)
    RUI:CreateBackdrop(frame.search)
    local fr, fg, fb = RUI:GetTextColor(false)
    frame.search:SetFont(RUI:GetFontPath(), 10, "")
    frame.search:SetTextColor(fr, fg, fb)
    frame.search:SetTextInsets(7, 7, 0, 0)
    frame.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.search:SetScript("OnTextChanged", function() Bags:UpdateSearch() end)

    frame.searchHint = CreateText(frame.search, "Search bags...", 9, true)
    frame.searchHint:SetPoint("LEFT", frame.search, "LEFT", 7, 0)

    frame.sort = CreateButton(frame, "SORT", 60, 22)
    frame.sort:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.sort:SetPoint("RIGHT", frame.search, "LEFT", -8, 0)
    frame.sort:SetScript("OnClick", function() Bags:SortPlayerBags() end)
    frame.sort:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Sort Bags")
        GameTooltip:AddLine("Physically sorts the real bag slots using Zen's queued Wrath-safe mover.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Zen waits for Ebonhold item locks between moves. Click again while sorting to cancel safely.", 0.6, 0.62, 0.66, true)
        GameTooltip:Show()
    end)
    frame.sort:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    frame.footer = CreateText(frame, "Click a container to show / hide it", 9, true)
    frame.footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)

    self.frame = frame
    self.containers = {}
    self.buttons = {}
    self.containerToggleButtons = {}

    for i = 1, #CONTAINER_TOGGLES do
        local def = CONTAINER_TOGGLES[i]
        local width = (def.label == "BP" and 34) or (def.label == "BNK" and 40) or 26
        local button = CreateButton(frame, def.label, width, 22)
        button:SetFrameLevel(frame:GetFrameLevel() + 20)
        button.RUIContainerKey = def.key
        button.RUITooltip = def.tooltip
        button.RUIBankOnly = def.bankOnly
        button:SetScript("OnClick", function(self) Bags:ToggleContainerSetting(self.RUIContainerKey) end)
        button:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local settings = GetContainerSettings()
            local enabled = settings[self.RUIContainerKey]
            if enabled == nil then enabled = self.RUIContainerKey ~= "bank" and self.RUIContainerKey ~= "bankBags" end
            GameTooltip:SetText((self.RUITooltip or self.RUIContainerKey) .. (enabled and " |cff66ff66shown|r" or " |cffff7777hidden|r"))
            GameTooltip:AddLine("Click to toggle this container in the unified bag window.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        self.containerToggleButtons[def.key] = button
    end

    -- Equipped bag management is intentionally separate from the BP/1-4
    -- visibility toggles. The toggles decide which containers are flattened
    -- into the unified grid; this pop-out replaces Blizzard's hidden bag-bar
    -- equipment controls so bags can still be inspected/replaced/removed.
    frame.manageBags = CreateButton(frame, "BAGS", 50, 22)
    frame.manageBags:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.manageBags:SetScript("OnClick", function() Bags:ToggleBagManager() end)
    frame.manageBags:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText("Equipped Bags")
        GameTooltip:AddLine("View, replace or remove bags 1-4.",.8,.8,.8,true)
        GameTooltip:AddLine("The Backpack is fixed and cannot be replaced.",.65,.65,.65,true)
        GameTooltip:Show()
    end)
    frame.manageBags:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    frame.bagManager=CreateFrame("Frame","ZenUIBagManager",UIParent)
    frame.bagManager:SetWidth(326); frame.bagManager:SetHeight(174)
    frame.bagManager:SetPoint("BOTTOMRIGHT",frame,"BOTTOMLEFT",-8,0)
    -- Keep this pop-out completely outside the unified bag-frame hierarchy.
    -- Zen bag containers cover the full bag window for reliable item hit
    -- testing; on some 3.3.5 clients those children can still swallow mouse
    -- input from siblings positioned outside the parent.  UIParent ownership
    -- makes the manager an independent top-level interaction surface.
    frame.bagManager:SetFrameStrata("FULLSCREEN_DIALOG"); frame.bagManager:SetFrameLevel(500)
    frame.bagManager:SetClampedToScreen(true); frame.bagManager:EnableMouse(true); frame.bagManager:Hide()
    RUI:CreateBackdrop(frame.bagManager); frame.bagManagerAccent=RUI:CreateAccentLine(frame.bagManager,2)
    frame.bagManagerTitle=CreateText(frame.bagManager,"EQUIPPED BAGS",12,false); frame.bagManagerTitle:SetPoint("TOPLEFT",frame.bagManager,"TOPLEFT",12,-13)
    frame.bagManagerClose=CreateButton(frame.bagManager,"X",24,22); frame.bagManagerClose:SetFrameLevel((frame.bagManager:GetFrameLevel() or 500)+20); frame.bagManagerClose:SetPoint("TOPRIGHT",frame.bagManager,"TOPRIGHT",-8,-8); frame.bagManagerClose:SetScript("OnClick",function() frame.bagManager:Hide() end)
    frame.backpackInfo=CreateText(frame.bagManager,"Backpack",10,true); frame.backpackInfo:SetPoint("TOPLEFT",frame.bagManager,"TOPLEFT",12,-39)
    frame.bagManagerHint=CreateText(frame.bagManager,"Drag a bag onto a slot to equip/replace it. Click or drag an equipped bag to pick it up.",9,true); frame.bagManagerHint:SetWidth(302); frame.bagManagerHint:SetJustifyH("LEFT"); frame.bagManagerHint:SetPoint("BOTTOMLEFT",frame.bagManager,"BOTTOMLEFT",12,10)
    frame.bagManager:SetScript("OnShow",function(self)
        self:ClearAllPoints(); self:SetPoint("BOTTOMRIGHT",frame,"BOTTOMLEFT",-8,0)
        self:Raise()
    end)
    frame.bagManager:SetScript("OnHide",function()
        Bags:ClearEquippedBagContentHighlight()
        if GameTooltip then GameTooltip:Hide() end
    end)
    frame.bagEquipSlots={}
    for bag=1,(tonumber(NUM_BAG_SLOTS) or 4) do
        local slot=CreateFrame("Button",nil,frame.bagManager)
        slot:SetFrameStrata("FULLSCREEN_DIALOG"); slot:SetFrameLevel((frame.bagManager:GetFrameLevel() or 500)+10)
        slot:SetWidth(48); slot:SetHeight(48); slot:SetHitRectInsets(0,0,0,0); slot:SetPoint("TOPLEFT",frame.bagManager,"TOPLEFT",18+((bag-1)*72),-66)
        slot:EnableMouse(true); slot:Enable(); slot:RegisterForClicks("LeftButtonUp","RightButtonUp"); slot:RegisterForDrag("LeftButton")
        RUI:CreateBackdrop(slot)
        slot.iconBg=slot:CreateTexture(nil,"ARTWORK"); slot.iconBg:SetPoint("TOPLEFT",slot,"TOPLEFT",2,-2); slot.iconBg:SetPoint("BOTTOMRIGHT",slot,"BOTTOMRIGHT",-2,2); slot.iconBg:SetTexture(RUI.Media.textures.white); slot.iconBg:SetVertexColor(.03,.03,.03,.96)
        slot.icon=slot:CreateTexture(nil,"OVERLAY"); slot.icon:SetPoint("TOPLEFT",slot,"TOPLEFT",3,-3); slot.icon:SetPoint("BOTTOMRIGHT",slot,"BOTTOMRIGHT",-3,3); slot.icon:SetTexCoord(.08,.92,.08,.92); slot.icon:SetVertexColor(1,1,1,1)
        slot.highlight=slot:CreateTexture(nil,"HIGHLIGHT"); slot.highlight:SetAllPoints(slot.icon); slot.highlight:SetTexture(RUI.Media.textures.white); local ar,ag,ab=RUI:GetAccentColor(); slot.highlight:SetVertexColor(ar,ag,ab,.24); slot.highlight:SetBlendMode("ADD")
        slot.label=CreateText(slot,"Bag "..tostring(bag),9,false); slot.label:SetPoint("TOP",slot,"BOTTOM",0,-2)
        slot.capacity=CreateText(slot,"",8,true); slot.capacity:SetPoint("TOP",slot.label,"BOTTOM",0,-2)
        slot.state=CreateText(slot,"READY",7,false); slot.state:SetPoint("BOTTOM",slot,"TOP",0,2)
        slot.RUIBag=bag; slot.RUIInventorySlot=EquippedBagInventorySlot(bag)
        slot:SetScript("OnClick",function(self) Bags:UseEquippedBagSlot(self,false) end)
        slot:SetScript("OnDragStart",function(self) Bags:UseEquippedBagSlot(self,true) end)
        slot:SetScript("OnReceiveDrag",function(self) Bags:PutCursorBagInSlot(self) end)
        slot:SetScript("OnEnter",function(self)
            Bags:HighlightEquippedBagContents(self.RUIBag)
            Bags:ShowEquippedBagTooltip(self)
        end)
        slot:SetScript("OnLeave",function()
            Bags:ClearEquippedBagContentHighlight()
            if GameTooltip then GameTooltip:Hide() end
        end)
        frame.bagEquipSlots[bag]=slot
    end

    for bag = BAG_MIN, BAG_MAX do self:EnsureContainer(bag) end
    self:EnsureContainer(KEYRING_ID)

    RUI:RegisterMover("Bags", frame, {
        label = "Unified Bags",
        width = 500,
        height = 280,
        point = "BOTTOMRIGHT",
        relativePoint = "BOTTOMRIGHT",
        x = -24,
        y = 78,
    })
    if RUI.EnableDirectPanelDrag then RUI:EnableDirectPanelDrag(frame.dragHandle, "Bags") end
end

function Bags:EnsureContainer(bag)
    if self.containers[bag] then return self.containers[bag] end
    local token = BagFrameToken(bag)
    local container = CreateFrame("Frame", "ZenUIBagContainer" .. token, self.frame)
    container:SetID(bag)
    -- ContainerFrameItemButtonTemplate resolves its bag through
    -- self:GetParent():GetID(). The parent therefore remains per-container,
    -- but covers the full unified window for reliable 3.3.5 hit-testing.
    container:SetAllPoints(self.frame)
    container:SetFrameLevel(self.frame:GetFrameLevel() + 10)
    container:EnableMouse(false)
    self.containers[bag] = container
    self.buttons[bag] = self.buttons[bag] or {}
    return container
end

function Bags:OpenStackSplitNow(owner,itemCount)
    -- RequestStackSplit has already performed the authoritative container read
    -- and verified count > 1 / not locked. Do NOT immediately re-read the slot
    -- here: on Ebonhold the item can report a transient lock during PostClick,
    -- which was causing Zen to abort before OpenStackSplitFrame was ever called.
    local count=math.floor(tonumber(itemCount) or 0)
    if not owner or count<=1 or not OpenStackSplitFrame then return false end

    if Bags.bagTrace then Bags:DebugPrint("Direct split opening count="..tostring(count).." owner="..BagDebugName(owner)) end
    local okOpen,openErr=pcall(OpenStackSplitFrame,count,owner,"BOTTOMRIGHT","TOPRIGHT")
    if Bags.bagTrace then Bags:DebugPrint("OpenStackSplitFrame pcall="..BagBool(okOpen).." err="..tostring(openErr or "nil")) end
    if not okOpen then return false end

    local escape=RUI:GetModule("BlizzardEscapeSkins")
    if escape and escape.StyleStackSplit then escape:StyleStackSplit() end

    local split=_G.StackSplitFrame
    if split then
        if split.SetParent then split:SetParent(UIParent) end
        if split.SetFrameStrata then split:SetFrameStrata("TOOLTIP") end
        if split.SetFrameLevel then split:SetFrameLevel(3000) end
        if split.SetClampedToScreen then split:SetClampedToScreen(true) end
        if split.ClearAllPoints and split.SetPoint then
            split:ClearAllPoints()
            split:SetPoint("BOTTOMRIGHT",owner,"TOPRIGHT",0,8)
        end
        if split.Show then split:Show() end
        if split.Raise then split:Raise() end
        if Bags.bagTrace then Bags:DebugPrint("StackSplitFrame after open shown="..BagBool(split.IsShown and split:IsShown()).." parent="..BagDebugName(split.GetParent and split:GetParent()).." strata="..tostring(split.GetFrameStrata and split:GetFrameStrata() or "?").." level="..tostring(split.GetFrameLevel and split:GetFrameLevel() or "?")) end
    elseif Bags.bagTrace then
        Bags:DebugPrint("StackSplitFrame global is nil after OpenStackSplitFrame")
    end
    return true
end

function Bags:RequestStackSplit(owner)
    if not owner or not GetContainerItemInfo then
        if self.bagTrace then self:DebugPrint("RequestStackSplit rejected: owner/GetContainerItemInfo missing") end
        return false
    end
    local _,itemCount,locked=GetContainerItemInfo(owner.RUIBag,owner.RUISlot)
    itemCount=tonumber(itemCount) or 0
    if self.bagTrace then self:DebugPrint("RequestStackSplit bag="..tostring(owner.RUIBag).." slot="..tostring(owner.RUISlot).." count="..tostring(itemCount).." locked="..BagBool(locked).." OpenStackSplitFrame="..tostring(type(OpenStackSplitFrame))) end
    if itemCount<=1 or locked or not OpenStackSplitFrame then return false end
    owner.SplitStack=function(splitOwner,split)
        split=math.floor(tonumber(split) or 0)
        if Bags.bagTrace then Bags:DebugPrint("SplitStack callback amount="..tostring(split).." bag="..tostring(splitOwner.RUIBag).." slot="..tostring(splitOwner.RUISlot)) end
        if split>0 and SplitContainerItem then
            SplitContainerItem(splitOwner.RUIBag,splitOwner.RUISlot,split)
        end
    end
    owner.RUIStackSplitMax=itemCount
    local result=self:OpenStackSplitNow(owner,itemCount)
    if self.bagTrace then self:DebugPrint("RequestStackSplit opened="..BagBool(result)) end
    return result
end

function Bags:GetItemButton(bag, slot)
    local existing = self.buttons[bag] and self.buttons[bag][slot]
    if existing then return existing end

    local parent = self:EnsureContainer(bag)
    if not parent then return nil end
    local name = "ZenUIBag" .. BagFrameToken(bag) .. "Slot" .. tostring(slot)
    local button = CreateFrame("Button", name, parent, "ContainerFrameItemButtonTemplate,SecureActionButtonTemplate")
    button:SetID(slot)
    button:SetFrameLevel(parent:GetFrameLevel() + 1)
    button:EnableMouse(true)
    if button.Enable then button:Enable() end
    if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    if button.RegisterForDrag then button:RegisterForDrag("LeftButton") end
    button.RUIBag = bag
    button.RUISlot = slot
    button:Show()

    local icon = _G[name .. "IconTexture"]
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    button.RUIIcon = icon

    local count = _G[name .. "Count"]
    if count then
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        local tr, tg, tb = RUI:GetTextColor(false)
        RUI:StyleFontString(count, 9, tr, tg, tb)
    end

    if button.SetNormalTexture then
        button:SetNormalTexture(RUI.Media.textures.white)
        local normal = button:GetNormalTexture()
        if normal then normal:SetAlpha(0) end
    end
    if button.SetPushedTexture then
        button:SetPushedTexture(RUI.Media.textures.white)
        local pushed = button:GetPushedTexture()
        if pushed then pushed:SetAlpha(0.15) end
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture(RUI.Media.textures.white)
        local highlight = button:GetHighlightTexture()
        if highlight then
            local ar, ag, ab = RUI:GetAccentColor()
            highlight:SetVertexColor(ar, ag, ab, 0.22)
            highlight:SetBlendMode("ADD")
        end
    end

    RUI:CreateBackdrop(button)

    -- Protected Ebonhold consumables must reach Blizzard's native container
    -- click path from secure code. A SecureActionButton "item" action is not
    -- quite equivalent to ContainerFrameItemButton_OnClick (merchant handling,
    -- modified clicks, custom client hooks, etc.), so delegate secure clicks to
    -- an invisible stock ContainerFrameItemButtonTemplate proxy on the exact
    -- same bag/slot instead of trying to reimplement item use in Zen.
    local proxyName = name .. "NativeClickProxy"
    local proxy = CreateFrame("Button", proxyName, parent, "ContainerFrameItemButtonTemplate")
    proxy:SetID(slot)
    proxy:SetAllPoints(button)
    proxy:SetFrameLevel(math.max(parent:GetFrameLevel(), button:GetFrameLevel() - 1))
    proxy:SetAlpha(0)
    proxy:EnableMouse(false)
    proxy:Show()
    button.RUINativeClickProxy = proxy

    local function RefreshSecureClicks(self)
        if not self.SetAttribute then return end
        local clickProxy = self.RUINativeClickProxy
        if not clickProxy then return end

        -- Ordinary clicks go through Blizzard's original container click
        -- handler in secure context. This preserves protected item use and the
        -- stock bag semantics. Modified gestures that Zen must repair on
        -- Ebonhold are reserved below and handled exactly once in PostClick.
        self:SetAttribute("type1", "click")
        self:SetAttribute("type2", "click")
        self:SetAttribute("clickbutton1", clickProxy)
        self:SetAttribute("clickbutton2", clickProxy)
        -- Start with native left-click delegation for all common modifiers.
        -- Zen reserves only the gestures that Ebonhold has proven unreliable
        -- through the secure proxy (DRESSUP and SPLITSTACK) and repairs them in
        -- PostClick. This is especially important for Shift+Left Click: with an
        -- active chat box it must link the item, otherwise it must open the
        -- native Stack Split popup for stacks larger than one.
        self:SetAttribute("shift-type1", "click")
        self:SetAttribute("ctrl-type1", "click")
        self:SetAttribute("alt-type1", "click")
        self:SetAttribute("ctrl-type1", "") -- Ctrl/DRESSUP is Zen-owned.

        local splitModifier = "SHIFT"
        if GetModifiedClick then
            local ok, value = pcall(GetModifiedClick, "SPLITSTACK")
            value = ok and type(value) == "string" and string.upper(value) or nil
            if value == "SHIFT" or value == "CTRL" or value == "ALT" then
                splitModifier = value
            end
        end
        self.RUISplitModifier = splitModifier
        if splitModifier == "SHIFT" then self:SetAttribute("shift-type1", "") end
        if splitModifier == "CTRL"  then self:SetAttribute("ctrl-type1", "") end
        if splitModifier == "ALT"   then self:SetAttribute("alt-type1", "") end

        local configured = "SHIFT"
        local db = RUI.db and RUI.db.blizzard
        if db and db.bankQuickDropModifier then configured = string.upper(tostring(db.bankQuickDropModifier)) end

        -- SOCKETITEM is Shift+Right Click by default. Some Ebonhold builds lose
        -- the modifier when a SecureActionButton delegates to our invisible
        -- ContainerFrameItemButton proxy. Reserve the configured socket gesture
        -- up front so the proxy cannot consume it before Zen calls the native
        -- SocketContainerItem API in PostClick.
        local socketModifier = "SHIFT"
        if GetModifiedClick then
            local ok, value = pcall(GetModifiedClick, "SOCKETITEM")
            value = ok and type(value) == "string" and string.upper(value) or nil
            if value == "SHIFT" or value == "CTRL" or value == "ALT" then
                socketModifier = value
            end
        end
        self.RUISocketModifier = socketModifier

        local phaseB = RUI:GetModule("BlizzardPhaseB")
        local bank = phaseB and phaseB.frames and phaseB.frames.bank
        local quickDropActive = bank and bank.bankOpen and true or false

        -- Start with native right-click delegation for every modifier, then
        -- blank only the gestures Zen owns. Bank quick-drop keeps precedence
        -- when it intentionally shares the same modifier as socketing.
        self:SetAttribute("shift-type2", "click")
        self:SetAttribute("ctrl-type2", "click")
        self:SetAttribute("alt-type2", "click")
        if socketModifier == "SHIFT" then self:SetAttribute("shift-type2", "") end
        if socketModifier == "CTRL"  then self:SetAttribute("ctrl-type2", "") end
        if socketModifier == "ALT"   then self:SetAttribute("alt-type2", "") end
        if quickDropActive and configured == "SHIFT" then self:SetAttribute("shift-type2", "") end
        if quickDropActive and configured == "CTRL"  then self:SetAttribute("ctrl-type2", "") end
        if quickDropActive and configured == "ALT"   then self:SetAttribute("alt-type2", "") end
    end
    button.RUIRefreshSecureRightClick = RefreshSecureClicks
    RefreshSecureClicks(button)

    -- Do not replace OnClick: SecureActionButtonTemplate owns it. Keep a tiny
    -- PreClick snapshot of the active chat edit box so PostClick can detect
    -- whether Ebonhold's delegated native proxy actually inserted a Shift-click
    -- item link. Some client builds lose that modified-click while routing the
    -- click through the secure proxy; Zen only supplies the missing chat link
    -- when the native path did nothing, avoiding duplicate links when it works.
    button.RUINativePreClick = button:GetScript("PreClick")
    button:SetScript("PreClick", function(self, mouseButton, ...)
        if self.RUINativePreClick then
            self.RUINativePreClick(self, mouseButton, ...)
        end
        self.RUIShiftChatEditBox = nil
        self.RUIShiftChatTextBefore = nil
        self.RUISplitWasDown = ModifierDown(self.RUISplitModifier or "SHIFT")
        self.RUIShiftWasDown = IsShiftKeyDown and IsShiftKeyDown() and true or false
        if Bags.bagTrace then
            local _,count,locked=GetContainerItemInfo and GetContainerItemInfo(self.RUIBag,self.RUISlot)
            Bags:DebugPrint("PreClick mouse="..tostring(mouseButton).." bag="..tostring(self.RUIBag).." slot="..tostring(self.RUISlot).." count="..tostring(count or 0).." locked="..BagBool(locked).." shift="..BagBool(self.RUIShiftWasDown).." splitMod="..tostring(self.RUISplitModifier).." splitDown="..BagBool(self.RUISplitWasDown).." shift-type1="..tostring(self.GetAttribute and self:GetAttribute("shift-type1")).." shift-type2="..tostring(self.GetAttribute and self:GetAttribute("shift-type2")))
        end
        if mouseButton == "LeftButton" and self.RUIShiftWasDown and ChatEdit_GetActiveWindow then
            local editBox = ChatEdit_GetActiveWindow()
            local visible = editBox and (not editBox.IsShown or editBox:IsShown())
            local focused = editBox and (not editBox.HasFocus or editBox:HasFocus())
            if editBox and editBox.GetText and visible and focused then
                self.RUIShiftChatEditBox = editBox
                self.RUIShiftChatTextBefore = editBox:GetText() or ""
            end
        end
    end)

    button:SetScript("PostClick", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            local link = GetContainerItemLink and GetContainerItemLink(self.RUIBag, self.RUISlot)

            if IsControlKeyDown and IsControlKeyDown() then
                if link and RUI.HandleModifiedLinkClick then
                    RUI:HandleModifiedLinkClick(link, mouseButton)
                end
                self.RUIShiftChatEditBox = nil
                self.RUIShiftChatTextBefore = nil
                return
            end

            local shiftDown = self.RUIShiftWasDown or (IsShiftKeyDown and IsShiftKeyDown() and true or false)
            if shiftDown and link then
                local editBox = self.RUIShiftChatEditBox
                local before = self.RUIShiftChatTextBefore
                local after = editBox and editBox.GetText and (editBox:GetText() or "") or nil

                -- CHATLINK takes priority when a chat edit box is active. If the
                -- native proxy already changed it, do nothing; otherwise insert
                -- the item link ourselves. This preserves the normal Shift-click
                -- chat workflow while Zen owns the same modifier for stack split.
                if editBox and before ~= nil then
                    if after == before then
                        local inserted = false
                        if ChatEdit_InsertLink then
                            local ok = pcall(ChatEdit_InsertLink, link)
                            inserted = ok and true or false
                        end
                        if not inserted and RUI.HandleModifiedLinkClick then
                            RUI:HandleModifiedLinkClick(link, mouseButton)
                        end
                    end
                    self.RUIShiftChatEditBox = nil
                    self.RUIShiftChatTextBefore = nil
                    return
                end
            end

            -- Ebonhold can drop SPLITSTACK while a secure click is delegated to
            -- an invisible ContainerFrameItemButton proxy. Detect the configured
            -- split modifier physically as a fallback and open Blizzard's native
            -- StackSplitFrame directly. The owner's SplitStack callback still
            -- calls SplitContainerItem(), so only the unreliable modifier routing
            -- is replaced; the actual stack split remains native.
            local splitModifier = self.RUISplitModifier or "SHIFT"
            local splitModifierDown = self.RUISplitWasDown or ModifierDown(splitModifier)
            local nativeSplit = IsModifiedClick and IsModifiedClick("SPLITSTACK")
            local splitClick = nativeSplit or splitModifierDown
            if Bags.bagTrace then Bags:DebugPrint("Left PostClick split native="..BagBool(nativeSplit).." physical="..BagBool(splitModifierDown).." combined="..BagBool(splitClick)) end
            if splitClick and Bags:RequestStackSplit(self) then
                self.RUIShiftChatEditBox = nil
                self.RUIShiftChatTextBefore = nil
                self.RUISplitWasDown = nil
                self.RUIShiftWasDown = nil
                return
            end

            self.RUIShiftChatEditBox = nil
            self.RUIShiftChatTextBefore = nil
            self.RUISplitWasDown = nil
            self.RUIShiftWasDown = nil
            return
        end
        if mouseButton ~= "RightButton" then return end

        local phaseB = RUI:GetModule("BlizzardPhaseB")
        local bank = phaseB and phaseB.frames and phaseB.frames.bank
        local quickDropActive = bank and bank.bankOpen and true or false
        local configured = "SHIFT"
        local db = RUI.db and RUI.db.blizzard
        if db and db.bankQuickDropModifier then configured = string.upper(tostring(db.bankQuickDropModifier)) end
        local configuredDown = (configured == "SHIFT" and IsShiftKeyDown and IsShiftKeyDown())
            or (configured == "CTRL" and IsControlKeyDown and IsControlKeyDown())
            or (configured == "ALT" and IsAltKeyDown and IsAltKeyDown())

        -- Convenience/compatibility: Shift+Right Click on a real stack should
        -- split it too. Socketable equipment is not stackable, so stacks (>1)
        -- can safely take precedence here while Shift+Right Click on single
        -- equipment items continues to open the native socket UI below.
        local physicalShift = self.RUIShiftWasDown or (IsShiftKeyDown and IsShiftKeyDown() and true or false)
        if Bags.bagTrace then Bags:DebugPrint("Right PostClick physicalShift="..BagBool(physicalShift).." quickDropActive="..BagBool(quickDropActive).." configuredDown="..BagBool(configuredDown)) end
        if physicalShift and not (quickDropActive and configuredDown) and Bags:RequestStackSplit(self) then
            self.RUISplitWasDown = nil
            self.RUIShiftWasDown = nil
            return
        end

        -- Ebonhold does not consistently carry SOCKETITEM through delegated
        -- secure clicks. The matching modifier was reserved in
        -- RefreshSecureClicks, so detect the physical modifier as a fallback
        -- as well as Blizzard's IsModifiedClick() result and invoke the native
        -- socket API directly. This restores Shift+Right Click even on clients
        -- where IsModifiedClick("SOCKETITEM") intermittently returns false.
        local socketModifier = self.RUISocketModifier or "SHIFT"
        local socketModifierDown = (socketModifier == "SHIFT" and IsShiftKeyDown and IsShiftKeyDown())
            or (socketModifier == "CTRL" and IsControlKeyDown and IsControlKeyDown())
            or (socketModifier == "ALT" and IsAltKeyDown and IsAltKeyDown())
        local socketClick = (IsModifiedClick and IsModifiedClick("SOCKETITEM")) or socketModifierDown
        if socketClick and not (quickDropActive and configuredDown) then
            if GameTooltip then GameTooltip:Hide() end
            if SocketContainerItem then
                SocketContainerItem(self.RUIBag, self.RUISlot)
            end
            self.RUISplitWasDown = nil
            self.RUIShiftWasDown = nil
            return
        end

        if phaseB and phaseB.HandleContainerQuickDrop then
            phaseB:HandleContainerQuickDrop(self.RUIBag, self.RUISlot)
        end
        self.RUISplitWasDown = nil
        self.RUIShiftWasDown = nil
    end)

    button.RUINativeOnReceiveDrag = button:GetScript("OnReceiveDrag")
    button:SetScript("OnReceiveDrag", function(self, ...)
        local phaseB = RUI:GetModule("BlizzardPhaseB")
        if phaseB and phaseB.HandleVoidDropOnContainer and phaseB:HandleVoidDropOnContainer(self.RUIBag, self.RUISlot) then
            return
        end
        if self.RUINativeOnReceiveDrag then
            return self.RUINativeOnReceiveDrag(self, ...)
        end
    end)

    self.buttons[bag][slot] = button
    return button
end

function Bags:RefreshSecureBagClicks()
    if InCombatLockdown and InCombatLockdown() then return end
    for _, buttons in pairs(self.buttons or {}) do
        for _, button in pairs(buttons or {}) do
            if button and button.RUIRefreshSecureRightClick then
                button:RUIRefreshSecureRightClick()
            end
        end
    end
end


function Bags:ClearEquippedBagContentHighlight()
    self.highlightedEquippedBag=nil
    for _,buttons in pairs(self.buttons or {}) do
        for _,button in pairs(buttons or {}) do
            if button then
                if button.RUIBagHoverOriginalAlpha~=nil then
                    button:SetAlpha(button.RUIBagHoverOriginalAlpha)
                    button.RUIBagHoverOriginalAlpha=nil
                end
                if button.RUIEquippedBagHighlight then
                    button.RUIEquippedBagHighlight:Hide()
                end
            end
        end
    end
end

function Bags:HighlightEquippedBagContents(bag)
    bag=tonumber(bag)
    self:ClearEquippedBagContentHighlight()
    if not bag then return end

    local occupied={}
    local visibleOccupied=0
    local slots=GetContainerSlotCount(bag)
    for slotIndex=1,slots do
        local texture=GetContainerItemInfo and GetContainerItemInfo(bag,slotIndex)
        if texture then occupied[slotIndex]=true end
    end
    if not next(occupied) then return end

    for slotIndex in pairs(occupied) do
        local button=self.buttons[bag] and self.buttons[bag][slotIndex]
        if button and button:IsShown() then visibleOccupied=visibleOccupied+1 end
    end

    -- If this bag is currently hidden by the unified-bag filter, do not fade
    -- unrelated inventory into darkness. The tooltip tells the player how to
    -- expose the container instead.
    if visibleOccupied==0 then
        self.highlightedEquippedBag=bag
        return
    end

    self.highlightedEquippedBag=bag
    local ar,ag,ab=RUI:GetAccentColor()
    for _,buttons in pairs(self.buttons or {}) do
        for _,button in pairs(buttons or {}) do
            if button and button:IsShown() then
                if button.RUIBagHoverOriginalAlpha==nil then
                    button.RUIBagHoverOriginalAlpha=button:GetAlpha()
                end
                local isTarget=(tonumber(button.RUIBag)==bag) and occupied[tonumber(button.RUISlot)]
                if isTarget then
                    button:SetAlpha(1)
                    local glow=button.RUIEquippedBagHighlight
                    if not glow then
                        glow=button:CreateTexture(nil,"OVERLAY")
                        glow:SetPoint("TOPLEFT",button,"TOPLEFT",1,-1)
                        glow:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
                        glow:SetTexture(RUI.Media.textures.white)
                        glow:SetBlendMode("ADD")
                        button.RUIEquippedBagHighlight=glow
                    end
                    glow:SetVertexColor(ar,ag,ab,.32)
                    glow:Show()
                else
                    button:SetAlpha(math.min(button.RUIBagHoverOriginalAlpha or 1,.22))
                    if button.RUIEquippedBagHighlight then button.RUIEquippedBagHighlight:Hide() end
                end
            end
        end
    end
end

function Bags:ShowEquippedBagTooltip(button)
    if not GameTooltip or not button then return end
    GameTooltip:SetOwner(button,"ANCHOR_LEFT")
    local inv=button.RUIInventorySlot
    local hasItem=false
    if inv and GameTooltip.SetInventoryItem then
        local ok,result=pcall(GameTooltip.SetInventoryItem,GameTooltip,"player",inv)
        hasItem=ok and result and true or false
    end
    if not hasItem then GameTooltip:SetText("Empty Bag Slot "..tostring(button.RUIBag or "")) end
    local bag=tonumber(button.RUIBag)
    GameTooltip:AddLine(" ")
    if bag then
        local total=GetContainerSlotCount(bag)
        local free=0
        if GetContainerNumFreeSlots then free=tonumber((GetContainerNumFreeSlots(bag))) or 0 end
        local used=math.max(0,(tonumber(total) or 0)-free)
        if hasItem then
            GameTooltip:AddLine(tostring(total).." slots  •  "..tostring(used).." items inside",.72,.75,.80,true)
            if used>0 then
                local key="bag"..tostring(bag)
                local settings=GetContainerSettings()
                if settings and settings[key]==false then
                    GameTooltip:AddLine("This container is hidden in the unified grid. Enable bag "..tostring(bag).." in the footer to see its items.",1,.72,.25,true)
                else
                    GameTooltip:AddLine("Items belonging to this bag are highlighted in the unified grid.",.55,1,.65,true)
                end
            else
                GameTooltip:AddLine("This bag is empty and can be removed immediately.",.55,1,.65,true)
            end
            GameTooltip:AddLine("Left-click / drag: pick up equipped bag",.75,.85,.75,true)
            if used>0 then GameTooltip:AddLine("To remove it completely, empty the highlighted items first.",1,.72,.25,true) end
        end
        GameTooltip:AddLine("Drop a bag here: equip / replace",.75,.85,.75,true)
    end
    GameTooltip:Show()
end

local function InvokeNativeEquippedBagSlot(bag,mode)
    bag=tonumber(bag)
    local native=NativeEquippedBagButton(bag)
    if not native then return false end

    -- Delegate to the exact Blizzard/Ebonhold bag-slot handlers instead of
    -- reproducing PutItemInBag/PickupBagFromSlot ourselves.  Custom clients can
    -- hook or replace these handlers, so using the live CharacterBag button is
    -- the most compatible path and mirrors the original bag bar precisely.
    if mode=="drop" then
        if type(BagSlotButton_OnClick)=="function" then
            local ok=pcall(BagSlotButton_OnClick,native,"LeftButton")
            if ok then return true end
        end
        local script=native.GetScript and native:GetScript("OnClick")
        if type(script)=="function" then
            local ok=pcall(script,native,"LeftButton")
            if ok then return true end
        end
    else
        if type(BagSlotButton_OnDrag)=="function" then
            local ok=pcall(BagSlotButton_OnDrag,native,"LeftButton")
            if ok then return true end
        end
        local script=native.GetScript and native:GetScript("OnDragStart")
        if type(script)=="function" then
            local ok=pcall(script,native,"LeftButton")
            if ok then return true end
        end
    end
    return false
end

function Bags:UseEquippedBagSlot(button,isDrag)
    if not button then return end
    if InCombatLockdown and InCombatLockdown() then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Bags cannot be equipped or removed during combat.") end
        return
    end
    local bag=tonumber(button.RUIBag)
    local inv=EquippedBagInventorySlot(bag) or button.RUIInventorySlot
    button.RUIInventorySlot=inv
    if not bag or not inv then return end
    if IsInventoryItemLocked and IsInventoryItemLocked(inv) then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r That equipped bag slot is currently locked by the client.") end
        return
    end

    if CursorHasItem and CursorHasItem() then
        if InvokeNativeEquippedBagSlot(bag,"drop") then return end
        -- Last-resort fallback for clients that do not expose the stock handler.
        if PutItemInBag then PutItemInBag(inv)
        elseif PickupInventoryItem then PickupInventoryItem(inv) end
    else
        if InvokeNativeEquippedBagSlot(bag,"pickup") then return end
        if PickupBagFromSlot then PickupBagFromSlot(inv)
        elseif PickupInventoryItem then PickupInventoryItem(inv) end
    end
end

function Bags:PutCursorBagInSlot(button)
    if not button then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local bag=tonumber(button.RUIBag)
    local inv=EquippedBagInventorySlot(bag) or button.RUIInventorySlot
    button.RUIInventorySlot=inv
    if not bag or not inv or not (CursorHasItem and CursorHasItem()) then return end
    if IsInventoryItemLocked and IsInventoryItemLocked(inv) then return end
    if InvokeNativeEquippedBagSlot(bag,"drop") then return end
    if PutItemInBag then PutItemInBag(inv)
    elseif PickupInventoryItem then PickupInventoryItem(inv) end
end

function Bags:UpdateBagManager()
    local frame=self.frame
    if not frame or not frame.bagManager then return end
    local backpackSlots=GetContainerSlotCount(0)
    frame.backpackInfo:SetText("Backpack  •  "..tostring(backpackSlots).." slots  •  fixed")
    local combat=InCombatLockdown and InCombatLockdown() and true or false
    for bag,slot in pairs(frame.bagEquipSlots or {}) do
        local inv=EquippedBagInventorySlot(bag)
        slot.RUIInventorySlot=inv
        local texture=inv and GetInventoryItemTexture and GetInventoryItemTexture("player",inv) or nil
        slot.icon:SetTexture(texture or "Interface\PaperDoll\UI-PaperDoll-Slot-Bag")
        slot:SetAlpha(1)
        if slot.Enable then slot:Enable() end

        -- Do not inherit the stock micro-bar's disabled/desaturated presentation.
        -- These are independent Zen controls; only expose the actual client
        -- lock state as text, while keeping the bag image full-colour/readable.
        if SetDesaturation then SetDesaturation(slot.icon,nil) end
        if slot.icon.SetDesaturated then pcall(slot.icon.SetDesaturated,slot.icon,false) end
        slot.icon:SetVertexColor(1,1,1,1)

        local locked=(inv and IsInventoryItemLocked and IsInventoryItemLocked(inv)) and true or false
        if combat then
            slot.state:SetText("COMBAT")
            RUI:StyleFontString(slot.state,7,1,.48,.28)
        elseif locked then
            slot.state:SetText("LOCKED")
            RUI:StyleFontString(slot.state,7,1,.45,.35)
        else
            slot.state:SetText("READY")
            RUI:StyleFontString(slot.state,7,.45,1,.55)
        end

        local name=BagItemNameFromInventorySlot(inv)
        local slots=GetContainerSlotCount(bag)
        slot.label:SetText("Bag "..tostring(bag))
        if slot.capacity then slot.capacity:SetText(name and (tostring(slots).." slots") or "Empty") end
        local tr,tg,tb=RUI:GetTextColor(false); RUI:StyleFontString(slot.label,9,tr,tg,tb)
        if slot.capacity then local mr,mg,mb=RUI:GetTextColor(true); RUI:StyleFontString(slot.capacity,8,mr,mg,mb) end
        RUI:RefreshBackdrop(slot)
        local ar,ag,ab=RUI:GetAccentColor(); RUI:SetBorderColor(slot,ar,ag,ab,1)
    end
end

function Bags:ToggleBagManager()
    if not self.frame or not self.frame.bagManager then return end
    if self.frame.bagManager:IsShown() then self.frame.bagManager:Hide()
    else self:UpdateBagManager(); self.frame.bagManager:Show() end
end

function Bags:ToggleContainerSetting(key)
    local containers = GetContainerSettings()
    local current = containers[key]
    if current == nil then
        current = key ~= "bank" and key ~= "bankBags"
    end
    containers[key] = not current
    self:Update()

    local config = RUI:GetModule("Config")
    if config and config.frame and config.frame:IsShown() and config.Refresh then
        config:Refresh()
    end
end

function Bags:UpdateContainerToggles()
    if not self.frame or not self.containerToggleButtons then return end
    local containers = GetContainerSettings()
    local x = PADDING
    local bankOpen = IsBankOpen()
    local ar, ag, ab = RUI:GetAccentColor()
    local tr, tg, tb = RUI:GetTextColor(false)
    local mr, mg, mb = RUI:GetTextColor(true)

    for i = 1, #CONTAINER_TOGGLES do
        local def = CONTAINER_TOGGLES[i]
        local button = self.containerToggleButtons[def.key]
        if button then
            if def.bankOnly and not bankOpen then
                button:Hide()
            else
                local enabled = containers[def.key]
                if enabled == nil then enabled = def.key ~= "bank" and def.key ~= "bankBags" end
                button:ClearAllPoints()
                button:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x, 7)
                button:Show()
                button:SetAlpha(enabled and 1 or 0.42)
                if enabled then
                    RUI:SetBorderColor(button, ar, ag, ab, 1)
                    RUI:StyleFontString(button.label, 10, tr, tg, tb)
                else
                    RUI:RefreshBackdrop(button)
                    RUI:StyleFontString(button.label, 10, mr, mg, mb)
                end
                x = x + button:GetWidth() + 5
            end
        end
    end

    if self.frame.manageBags then
        self.frame.manageBags:ClearAllPoints()
        self.frame.manageBags:SetPoint("BOTTOMLEFT",self.frame,"BOTTOMLEFT",x,7)
        self.frame.manageBags:Show()
        x=x+self.frame.manageBags:GetWidth()+5
    end

    self.frame.footer:ClearAllPoints()
    self.frame.footer:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -14, 12)
    if self.frame:GetWidth() < (x + 180) then
        self.frame.footer:SetText("")
    else
        self.frame.footer:SetText("Click container buttons to show / hide")
    end
end

function Bags:CountSlots()
    local free, total = 0, 0
    local ids = self:GetActiveContainerIDs()
    for i = 1, #ids do
        local bag = ids[i]
        local slots = GetContainerSlotCount(bag)
        total = total + slots
        for slot = 1, slots do
            local texture = GetContainerItemInfo and GetContainerItemInfo(bag, slot)
            if not texture then free = free + 1 end
        end
    end
    return free, total
end

function Bags:Layout()
    local settings = GetSettings() or {}
    local scale = RUI:GetEffectiveScale("bags")
    self.frame:SetScale(scale)
    local size = tonumber(settings.buttonSize) or 34
    local spacing = tonumber(settings.spacing) or 4
    local columns = math.max(4, math.min(20, tonumber(settings.columns) or 12))
    local all = {}
    local ids = self:GetActiveContainerIDs()
    local active = {}

    for i = 1, #ids do active[ids[i]] = true end
    for bag, buttons in pairs(self.buttons) do
        if not active[bag] then
            for _, button in pairs(buttons) do button:Hide() end
        end
    end

    for i = 1, #ids do
        local bag = ids[i]
        self:EnsureContainer(bag)
        local slots = GetContainerSlotCount(bag)
        for slot = 1, slots do
            local button = self:GetItemButton(bag, slot)
            if button then table.insert(all, button) end
        end
        for slot, button in pairs(self.buttons[bag] or {}) do
            if slot > slots then button:Hide() end
        end
    end

    local rows = math.max(1, math.ceil(#all / columns))
    local width = (PADDING * 2) + (columns * size) + ((columns - 1) * spacing)
    width = math.max(width, 320)
    local height = HEADER_HEIGHT + FOOTER_HEIGHT + (rows * size) + ((rows - 1) * spacing) + PADDING

    self.frame:SetWidth(width)
    self.frame:SetHeight(height)
    RUI:UpdateMoverSize("Bags", width * scale, height * scale)

    for index = 1, #all do
        local button = all[index]
        local col = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        button:ClearAllPoints()
        button:SetWidth(size)
        button:SetHeight(size)
        button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PADDING + (col * (size + spacing)), -HEADER_HEIGHT - (row * (size + spacing)))
        button:Show()
    end
end

function Bags:UpdateButton(button)
    if not button then return end
    if button.RUIRefreshSecureRightClick and not (InCombatLockdown and InCombatLockdown()) then
        button:RUIRefreshSecureRightClick()
    end
    local bag, slot = button.RUIBag, button.RUISlot
    local texture, itemCount, locked, quality, readable = GetContainerItemInfo(bag, slot)

    if SetItemButtonTexture then SetItemButtonTexture(button, texture) end
    if SetItemButtonCount then SetItemButtonCount(button, itemCount) end
    if SetItemButtonDesaturated then SetItemButtonDesaturated(button, locked, 0.5, 0.5, 0.5) end
    button.hasItem = texture and 1 or nil
    button.readable = readable

    local cooldown = _G[button:GetName() .. "Cooldown"]
    if cooldown and GetContainerItemCooldown and CooldownFrame_SetTimer then
        local start, duration, enable = GetContainerItemCooldown(bag, slot)
        CooldownFrame_SetTimer(cooldown, start or 0, duration or 0, enable or 0)
    end

    local settings = GetSettings() or {}
    if settings.showQuality ~= false and texture and tonumber(quality) and tonumber(quality) > 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        RUI:SetBorderColor(button, c.r or 1, c.g or 1, c.b or 1, 1)
    else
        RUI:RefreshBackdrop(button)
    end

    local questTexture = _G[button:GetName() .. "IconQuestTexture"]
    if questTexture and GetContainerItemQuestInfo then
        local isQuestItem, questId, isActive = GetContainerItemQuestInfo(bag, slot)
        if questId and not isActive and TEXTURE_ITEM_QUEST_BANG then
            questTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG); questTexture:Show()
        elseif (questId or isQuestItem) and TEXTURE_ITEM_QUEST_BORDER then
            questTexture:SetTexture(TEXTURE_ITEM_QUEST_BORDER); questTexture:Show()
        else
            questTexture:Hide()
        end
    end
end

function Bags:UpdateSearch()
    if not self.frame then return end
    local settings = GetSettings() or {}
    local query = settings.showSearch ~= false and string.lower(self.frame.search:GetText() or "") or ""
    if query == "" then self.frame.searchHint:Show() else self.frame.searchHint:Hide() end

    for bag, buttons in pairs(self.buttons) do
        for slot, button in pairs(buttons or {}) do
            if button:IsShown() and button.RUIIcon then
                local match = true
                local texture = GetContainerItemInfo(bag, slot)
                if query ~= "" and texture then
                    local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
                    local name = ItemNameFromLink(link)
                    match = name and string.find(string.lower(name), query, 1, true) and true or false
                elseif query ~= "" and not texture then
                    match = false
                end
                if match then
                    button.RUIIcon:SetVertexColor(1, 1, 1, 1)
                else
                    button.RUIIcon:SetVertexColor(0.25, 0.25, 0.25, 0.35)
                end
            end
        end
    end
end


function Bags:ScheduleStructureRefresh(duration)
    if not self.frame then return end
    self.structureRefreshRemaining=math.max(tonumber(duration) or 0.8,self.structureRefreshRemaining or 0)
    self.structureRefreshElapsed=0
end

function Bags:ProcessStructureRefresh(elapsed)
    local remaining=tonumber(self.structureRefreshRemaining) or 0
    if remaining<=0 then return end
    elapsed=tonumber(elapsed) or 0
    remaining=remaining-elapsed
    self.structureRefreshRemaining=remaining
    self.structureRefreshElapsed=(tonumber(self.structureRefreshElapsed) or 0)+elapsed
    if self.structureRefreshElapsed<0.10 and remaining>0 then return end
    self.structureRefreshElapsed=0
    if self.frame and self.frame:IsShown() then
        if InCombatLockdown and InCombatLockdown() then self:RefreshContents() else self:Update() end
    end
    if remaining<=0 then self.structureRefreshRemaining=nil end
end

function Bags:RefreshContents()
    if not self.frame then return end
    local ids = self:GetActiveContainerIDs()
    for i = 1, #ids do
        local bag = ids[i]
        local slots = GetContainerSlotCount(bag)
        for slot = 1, slots do
            local button = self.buttons[bag] and self.buttons[bag][slot]
            if button then self:UpdateButton(button) end
        end
    end
    local free,total=self:CountSlots()
    self.frame.count:SetText(tostring(free).." free / "..tostring(total))
    self:UpdateMoneyCache()
    self.frame.money:SetText(FormatMoney(GetMoney and GetMoney() or 0))
    self:UpdateSearch()
    self:UpdateBagManager()
end

function Bags:InstallCombatToggleBinding()
    if InCombatLockdown and InCombatLockdown() then return end
    if not self.combatToggle then
        local toggle=CreateFrame("Button","ZenUIBagCombatToggle",UIParent,"SecureHandlerClickTemplate")
        toggle:SetFrameRef("bagFrame",self.frame)
        toggle:SetAttribute("_onclick",[[
            local f=self:GetFrameRef("bagFrame")
            if f then
                if f:IsShown() then f:Hide() else f:Show() end
            end
        ]])
        toggle:SetScript("PreClick",function()
            if not (InCombatLockdown and InCombatLockdown()) then Bags:Update() end
        end)
        self.combatToggle=toggle
    end
    if ClearOverrideBindings then ClearOverrideBindings(self.combatToggle) end
    if not (GetSettings() and GetSettings().enabled==false) and SetOverrideBindingClick and GetBindingKey then
        local key1,key2=GetBindingKey("TOGGLEBACKPACK")
        if key1 then SetOverrideBindingClick(self.combatToggle,true,key1,"ZenUIBagCombatToggle","LeftButton") end
        if key2 then SetOverrideBindingClick(self.combatToggle,true,key2,"ZenUIBagCombatToggle","LeftButton") end
    end
end
function Bags:Update()
    if not self.frame then return end
    self:Layout()
    local ids = self:GetActiveContainerIDs()
    for i = 1, #ids do
        local bag = ids[i]
        local slots = GetContainerSlotCount(bag)
        for slot = 1, slots do self:UpdateButton(self.buttons[bag] and self.buttons[bag][slot]) end
    end
    local free, total = self:CountSlots()
    self.frame.count:SetText(tostring(free) .. " free / " .. tostring(total))
    self:UpdateMoneyCache()
    self.frame.money:SetText(FormatMoney(GetMoney and GetMoney() or 0))
    self:UpdateContainerToggles()
    self:UpdateSearch()
    self:UpdateBagManager()
end

function Bags:RefreshAppearance()
    if not self.frame then return end
    self.frame:SetScale(RUI:GetEffectiveScale("bags"))
    RUI:RefreshBackdrop(self.frame)
    RUI:SetAccentTexture(self.frame.accent)
    RUI:RefreshBackdrop(self.frame.search)
    RUI:StyleButton(self.frame.close)
    if self.frame.manageBags then RUI:StyleButton(self.frame.manageBags) end
    if self.frame.bagManager then RUI:RefreshBackdrop(self.frame.bagManager); RUI:SetAccentTexture(self.frame.bagManagerAccent); RUI:StyleButton(self.frame.bagManagerClose) end
    local tr, tg, tb = RUI:GetTextColor(false)
    local mr, mg, mb = RUI:GetTextColor(true)
    RUI:StyleFontString(self.frame.title, 12, tr, tg, tb)
    RUI:StyleFontString(self.frame.count, 9, mr, mg, mb)
    RUI:StyleFontString(self.frame.money, 9, tr, tg, tb)
    RUI:StyleFontString(self.frame.footer, 9, mr, mg, mb)
    RUI:StyleFontString(self.frame.searchHint, 9, mr, mg, mb)
    self.frame.search:SetFont(RUI:GetFontPath(), 10, "")
    self.frame.search:SetTextColor(tr, tg, tb)

    for bag, buttons in pairs(self.buttons) do
        for _, button in pairs(buttons or {}) do
            RUI:RefreshBackdrop(button)
            local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
            if highlight then
                local ar, ag, ab = RUI:GetAccentColor()
                highlight:SetVertexColor(ar, ag, ab, 0.22)
            end
        end
    end
    self:Update()
end

function Bags:CloseNativeContainerFrames()
    if InCombatLockdown and InCombatLockdown() then return end
    local count = tonumber(NUM_CONTAINER_FRAMES) or 13
    for i = 1, count do
        local frame = _G["ContainerFrame" .. tostring(i)]
        if frame and frame.IsShown and frame:IsShown() then frame:Hide() end
    end
end

function Bags:Show()
    local settings = GetSettings()
    if not settings or settings.enabled == false then
        if self.native and self.native.OpenAllBags then return self.native.OpenAllBags() end
        return
    end
    if not (InCombatLockdown and InCombatLockdown()) then self:CloseNativeContainerFrames() end
    -- In combat the secure slot buttons cannot be structurally rebuilt. Their
    -- existing layout is already authoritative; BAG_UPDATE keeps contents live.
    if not (InCombatLockdown and InCombatLockdown()) then self:Update() end
    self.frame:Show()
end

function Bags:Hide()
    if self.frame then
        if self.frame.bagManager then self.frame.bagManager:Hide() end
        self.frame:Hide()
    end
end

function Bags:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end

function Bags:InstallBagFunctions()
    if not self.native then
        self.native = {
            ToggleBackpack = ToggleBackpack,
            OpenBackpack = OpenBackpack,
            CloseBackpack = CloseBackpack,
            ToggleAllBags = ToggleAllBags,
            OpenAllBags = OpenAllBags,
            CloseAllBags = CloseAllBags,
            ToggleBag = ToggleBag,
            OpenBag = OpenBag,
            CloseBag = CloseBag,
            ToggleKeyRing = ToggleKeyRing,
        }
    end
    if self.functionsInstalled then return end

    self.wrappers = self.wrappers or {}
    self.wrappers.ToggleBackpack = function() Bags:Toggle() end
    self.wrappers.OpenBackpack = function() Bags:Show() end
    self.wrappers.CloseBackpack = function() Bags:Hide() end
    self.wrappers.ToggleAllBags = function()
        if Bags.frame and Bags.frame:IsShown() then
            Bags:Hide(); if not (InCombatLockdown and InCombatLockdown()) then Bags:CloseNativeContainerFrames() end
        else
            Bags:Show()
        end
    end
    self.wrappers.OpenAllBags = function() Bags:Show() end
    self.wrappers.CloseAllBags = function() Bags:Hide(); if not (InCombatLockdown and InCombatLockdown()) then Bags:CloseNativeContainerFrames() end end
    self.wrappers.ToggleBag = function(bag)
        bag = tonumber(bag) or 0
        if Bags:IsContainerIncluded(bag) then return Bags:Toggle() end
        if Bags.native.ToggleBag then return Bags.native.ToggleBag(bag) end
    end
    self.wrappers.OpenBag = function(bag)
        bag = tonumber(bag) or 0
        if Bags:IsContainerIncluded(bag) then return Bags:Show() end
        if Bags.native.OpenBag then return Bags.native.OpenBag(bag) end
    end
    self.wrappers.CloseBag = function(bag)
        bag = tonumber(bag) or 0
        if Bags:IsContainerIncluded(bag) then return Bags:Hide() end
        if Bags.native.CloseBag then return Bags.native.CloseBag(bag) end
    end
    self.wrappers.ToggleKeyRing = function()
        if Bags:IsContainerIncluded(KEYRING_ID) then return Bags:Toggle() end
        if Bags.native.ToggleKeyRing then return Bags.native.ToggleKeyRing() end
    end

    ToggleBackpack = self.wrappers.ToggleBackpack
    OpenBackpack = self.wrappers.OpenBackpack
    CloseBackpack = self.wrappers.CloseBackpack
    if self.native.ToggleAllBags then ToggleAllBags = self.wrappers.ToggleAllBags end
    if self.native.OpenAllBags then OpenAllBags = self.wrappers.OpenAllBags end
    if self.native.CloseAllBags then CloseAllBags = self.wrappers.CloseAllBags end
    if self.native.ToggleBag then ToggleBag = self.wrappers.ToggleBag end
    if self.native.OpenBag then OpenBag = self.wrappers.OpenBag end
    if self.native.CloseBag then CloseBag = self.wrappers.CloseBag end
    if self.native.ToggleKeyRing then ToggleKeyRing = self.wrappers.ToggleKeyRing end
    self.functionsInstalled = true
end

function Bags:RestoreBagFunctions()
    if not self.native or not self.functionsInstalled then return end
    if ToggleBackpack == self.wrappers.ToggleBackpack then ToggleBackpack = self.native.ToggleBackpack end
    if OpenBackpack == self.wrappers.OpenBackpack then OpenBackpack = self.native.OpenBackpack end
    if CloseBackpack == self.wrappers.CloseBackpack then CloseBackpack = self.native.CloseBackpack end
    if self.native.ToggleAllBags and ToggleAllBags == self.wrappers.ToggleAllBags then ToggleAllBags = self.native.ToggleAllBags end
    if self.native.OpenAllBags and OpenAllBags == self.wrappers.OpenAllBags then OpenAllBags = self.native.OpenAllBags end
    if self.native.CloseAllBags and CloseAllBags == self.wrappers.CloseAllBags then CloseAllBags = self.native.CloseAllBags end
    if self.native.ToggleBag and ToggleBag == self.wrappers.ToggleBag then ToggleBag = self.native.ToggleBag end
    if self.native.OpenBag and OpenBag == self.wrappers.OpenBag then OpenBag = self.native.OpenBag end
    if self.native.CloseBag and CloseBag == self.wrappers.CloseBag then CloseBag = self.native.CloseBag end
    if self.native.ToggleKeyRing and ToggleKeyRing == self.wrappers.ToggleKeyRing then ToggleKeyRing = self.native.ToggleKeyRing end
    self.functionsInstalled = false
end

function Bags:ApplySettings()
    local settings = GetSettings()
    if not settings then return end
    local enabled = settings.enabled ~= false
    RUI:SetMoverEnabled("Bags", enabled)
    if enabled then
        self:InstallBagFunctions()
        self:InstallCombatToggleBinding()
        if self.frame:IsShown() then self:Update() end
    else
        self:Hide()
        self:RestoreBagFunctions()
        if self.combatToggle and ClearOverrideBindings and not (InCombatLockdown and InCombatLockdown()) then ClearOverrideBindings(self.combatToggle) end
    end
    if self.frame.search then
        if enabled and settings.showSearch ~= false then self.frame.search:Show() else self.frame.search:Hide() end
    end
end

function Bags:OnEvent(event)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MONEY" then
        self:UpdateMoneyCache()
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED" then
        self:ScheduleStructureRefresh(0.8)
    end
    if event == "BAG_UPDATE" or event == "BAG_UPDATE_COOLDOWN" or event == "ITEM_LOCK_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" or event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" or event == "PLAYER_MONEY" then
        if self.frame and self.frame:IsShown() then
            if self.sortState then
                self:RefreshContents()
            elseif InCombatLockdown and InCombatLockdown() then
                self:RefreshContents()
            else
                self:Update()
            end
        end
    end
    if event == "UPDATE_BINDINGS" or event == "PLAYER_REGEN_ENABLED" then self:InstallCombatToggleBinding() end
end

function Bags:OnComponentScaleChanged(key)
    if key == "all" or key == "bags" then self:RefreshAppearance() end
end

function Bags:OnInitialize()
    self:CreateFrame()
    if UISpecialFrames then table.insert(UISpecialFrames, "ZenUIBagFrame") end
    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "RefreshAppearance")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED", self, "OnComponentScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET", self, "ApplySettings")
end

function Bags:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
    self:RegisterEvent("BAG_UPDATE", "OnEvent")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN", "OnEvent")
    self:RegisterEvent("ITEM_LOCK_CHANGED", "OnEvent")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnEvent")
    self:RegisterEvent("PLAYER_MONEY", "OnEvent")
    self:RegisterEvent("BANKFRAME_OPENED", "OnEvent")
    self:RegisterEvent("BANKFRAME_CLOSED", "OnEvent")
    self:RegisterEvent("UPDATE_BINDINGS", "OnEvent")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
    self:ApplySettings()
    self:RefreshAppearance()
end
