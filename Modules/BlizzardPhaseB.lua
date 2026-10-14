-- ZenUI 0.8.71 Phase B replacement panels.
-- Character, Quest Log, Mail, Merchant, Bank and Trade are Zen-owned
-- windows backed by the native Wrath 3.3.5 APIs.

local RUI = ZenUI
local PhaseB = RUI:NewModule("BlizzardPhaseB")

local INFO = {
    character = { setting="character", scale="zenCharacter", mover="ZenCharacter", label="Character", width=720, height=590, x=-310, y=10 },
    quest = { setting="questLog", scale="zenQuestLog", mover="ZenQuestLog", label="Quest Log", width=760, height=560, x=-300, y=5 },
    mail = { setting="mail", scale="zenMail", mover="ZenMail", label="Mail", width=760, height=560, x=-300, y=0 },
    merchant = { setting="merchant", scale="zenMerchant", mover="ZenMerchant", label="Merchant", width=560, height=445, x=-225, y=0 },
    bank = { setting="bank", scale="zenBank", mover="ZenBank", label="Bank", width=720, height=690, x=-290, y=0 },
    trade = { setting="trade", scale="zenTrade", mover="ZenTrade", label="Trade", width=680, height=560, x=-270, y=0 },
}

local function Settings()
    if not RUI.db then return nil end
    RUI.db.blizzard = RUI.db.blizzard or {}
    return RUI.db.blizzard
end

local function Enabled(key)
    local s = Settings()
    if not s or s.enabled == false then return false end
    local info = INFO[key]
    if not info then return false end
    if s[info.setting] == nil then return true end
    return s[info.setting] and true or false
end

local function BankQuickDropModifier()
    local s=Settings()
    local value=s and string.upper(tostring(s.bankQuickDropModifier or "SHIFT")) or "SHIFT"
    if value~="SHIFT" and value~="CTRL" and value~="ALT" then value="SHIFT" end
    return value
end

local function BankQuickDropModifierLabel()
    local modifier=BankQuickDropModifier()
    if modifier=="CTRL" then return "Ctrl" end
    if modifier=="ALT" then return "Alt" end
    return "Shift"
end

function PhaseB:IsBankQuickDropModifierDown()
    local modifier=BankQuickDropModifier()
    if modifier=="CTRL" then return IsControlKeyDown and IsControlKeyDown() and true or false end
    if modifier=="ALT" then return IsAltKeyDown and IsAltKeyDown() and true or false end
    return IsShiftKeyDown and IsShiftKeyDown() and true or false
end

local function Safe(label, fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, a,b,c,d,e,f,g,h,i,j,k,l,m,n = pcall(fn, ...)
    if not ok then
        RUI:Debug("Phase B "..tostring(label).." failed: "..tostring(a))
        return false
    end
    return true,a,b,c,d,e,f,g,h,i,j,k,l,m,n
end

local function Text(parent, text, size, point, rel, relPoint, x, y, muted)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint(point or "TOPLEFT", rel or parent, relPoint or point or "TOPLEFT", x or 0, y or 0)
    local r,g,b = RUI:GetTextColor(muted and true or false)
    RUI:StyleFontString(fs, size or 10, r,g,b)
    fs:SetText(text or "")
    return fs
end

local function Button(parent, label, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(width or 100); b:SetHeight(height or 24)
    b.RUIText = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.RUIText:SetPoint("CENTER")
    b.RUIText:SetText(label or "Button")
    RUI:StyleButton(b)
    return b
end

local function Edit(parent, width, height, placeholder, multiline)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetWidth(width or 180); e:SetHeight(height or 24)
    e:SetAutoFocus(false); e:SetFont(RUI:GetFontPath(), 11)
    e:SetTextInsets(8,8,4,4)
    if multiline and e.SetMultiLine then e:SetMultiLine(true) end
    RUI:CreateBackdrop(e)
    e.placeholder = Text(e, placeholder or "", 9, "TOPLEFT", e, "TOPLEFT", 8, -7, true)
    e:SetScript("OnEditFocusGained", function(self) self.placeholder:Hide() end)
    e:SetScript("OnEditFocusLost", function(self) if self:GetText()=="" then self.placeholder:Show() end end)
    e:SetScript("OnTextChanged", function(self)
        if self:GetText()=="" and not self:HasFocus() then self.placeholder:Show() else self.placeholder:Hide() end
        if self.RUIOnTextChanged then self:RUIOnTextChanged() end
    end)
    return e
end

local function Check(parent, label, x, y, callback, width)
    local c = CreateFrame("CheckButton", nil, parent)
    c:SetWidth(width or 160); c:SetHeight(22); c:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    c.box = CreateFrame("Frame", nil, c); c.box:SetWidth(14); c.box:SetHeight(14); c.box:SetPoint("LEFT")
    RUI:CreateBackdrop(c.box)
    c.mark = c.box:CreateTexture(nil,"OVERLAY"); c.mark:SetPoint("TOPLEFT",3,-3); c.mark:SetPoint("BOTTOMRIGHT",-3,3); RUI:SetAccentTexture(c.mark); c.mark:Hide()
    c.label = Text(c, label, 10, "LEFT", c.box, "RIGHT", 8,0,false)
    c:SetScript("OnClick", function(self)
        local v=self:GetChecked() and true or false; if v then self.mark:Show() else self.mark:Hide() end; if callback then callback(v) end
    end)
    function c:SetRUIValue(v) self:SetChecked(v and true or false); if v then self.mark:Show() else self.mark:Hide() end end
    return c
end

local function ShowIf(frame, shown)
    if not frame then return end
    if shown then frame:Show() else frame:Hide() end
end

local function AddSpecial(frame)
    if not frame or not frame.GetName or not frame:GetName() then return end
    UISpecialFrames = UISpecialFrames or {}
    for i=1,#UISpecialFrames do if UISpecialFrames[i]==frame:GetName() then return end end
    table.insert(UISpecialFrames, frame:GetName())
end

local function Panel(name, key, title)
    local i=INFO[key]
    local f=CreateFrame("Frame",name,UIParent)
    f:SetWidth(i.width); f:SetHeight(i.height); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true); f:Hide(); f.RUIPhaseBKey=key
    RUI:CreateBackdrop(f); f.accent=RUI:CreateAccentLine(f,2)
    f.title=Text(f,title,15,"TOPLEFT",f,"TOPLEFT",16,-17,false)
    f.subtitle=Text(f,"Zen replacement panel",8,"LEFT",f.title,"RIGHT",10,-1,true)
    f.close=Button(f,"X",28,24); f.close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-10,-10)
    f.close:SetScript("OnClick",function() f:Hide() end)
    f.body=CreateFrame("Frame",nil,f); f.body:SetPoint("TOPLEFT",f,"TOPLEFT",12,-48); f.body:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-12,12)
    AddSpecial(f)
    if RUI.RegisterExclusivePanel then RUI:RegisterExclusivePanel(f) end
    return f
end

local function Row(parent,w,h)
    local r=CreateFrame("Button",nil,parent); r:SetWidth(w); r:SetHeight(h); RUI:CreateBackdrop(r)
    if r.RUIBackground then r.RUIBackground:SetAlpha(.32) end
    r.hl=r:CreateTexture(nil,"ARTWORK"); r.hl:SetAllPoints(); r.hl:Hide()
    r:SetScript("OnEnter",function(self) local a,b,c=RUI:GetAccentColor(); self.hl:SetTexture(a,b,c,.11); self.hl:Show(); if self.RUIEnter then self:RUIEnter() end end)
    r:SetScript("OnLeave",function(self) self.hl:Hide(); if self.RUILeave then self:RUILeave() end end)
    return r
end

local function ItemSlot(parent,size)
    local b=CreateFrame("Button",nil,parent); b:SetWidth(size or 38); b:SetHeight(size or 38); RUI:CreateBackdrop(b)
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOPLEFT",3,-3); b.icon:SetPoint("BOTTOMRIGHT",-3,3)
    -- Never use the generic field name `count` on these custom buttons.
    -- Blizzard/Ebonhold code is free to reuse button.count as numeric state
    -- (stack split/use-item paths do this on some 3.3.5 clients). Keeping the
    -- visual FontString solely under a Zen-owned key prevents those native
    -- writes from poisoning BAG_UPDATE / ITEM_LOCK_CHANGED refreshes.
    b.RUICountText=Text(b,"",9,"BOTTOMRIGHT",b,"BOTTOMRIGHT",-3,3,false)
    b.RUICountText:SetJustifyH("RIGHT")
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    return b
end

local function SetItemSlotCount(button,value)
    local text=button and button.RUICountText
    if text and text.SetText then text:SetText(value or "") end
end

-- Return true when the client's configured SOCKETITEM modifier is currently
-- held. Ebonhold has occasionally reported IsModifiedClick("SOCKETITEM")
-- inconsistently through custom/proxy buttons, so mirror the hardened Bags
-- behavior and fall back to the physical configured modifier (Shift by
-- default).
-- Return the native Blizzard paper-doll button for a Zen equipment slot.
-- Ebonhold can hook these stock buttons to support custom item-attachment /
-- enchant targeting, so Zen should forward active cursor-target interactions
-- through the native button whenever possible instead of bypassing those hooks.
local function NativePaperDollSlot(slotKey)
    if not slotKey then return nil end
    local button = _G["Character" .. tostring(slotKey)]
    if button and button.GetScript then return button end
    return nil
end

local function InventoryCursorIsActive(slotID)
    if CursorHasItem then
        local ok, value = pcall(CursorHasItem)
        if ok and value then return true end
    end
    if CursorHasSpell then
        local ok, value = pcall(CursorHasSpell)
        if ok and value then return true end
    end
    if SpellIsTargeting then
        local ok, value = pcall(SpellIsTargeting)
        if ok and value then return true end
    end
    if CursorCanGoInSlot and slotID then
        local ok, value = pcall(CursorCanGoInSlot, slotID)
        if ok and value then return true end
    end
    return false
end

local function ForwardNativeEquipmentClick(slotKey, slotID, button)
    if button ~= "LeftButton" or not InventoryCursorIsActive(slotID) then return false end

    -- IMPORTANT: do not call the native PaperDoll OnClick or
    -- PickupInventoryItem() from this insecure Zen click while an enchant /
    -- item-target spell is active. Ebonhold protects that path and will raise
    -- the "action only available to the Blizzard UI" popup even though the
    -- user's click is a hardware event. 0.9.189 handles those target casts via
    -- a SecureActionButtonTemplate overlay with target-slot instead.
    if SpellCanTargetItem then
        local ok, canTarget = pcall(SpellCanTargetItem)
        if ok and canTarget then return false end
    end

    -- Keep the historical fallback for ordinary cursor-item equipment moves.
    -- This is not used for enchant/armor-kit/scope targeting anymore.
    local native = NativePaperDollSlot(slotKey)
    if native then
        local click = native.GetScript and native:GetScript("OnClick")
        if click then
            local ok = pcall(click, native, "LeftButton")
            if ok then return true end
        end
    end

    if PickupInventoryItem then
        local ok = pcall(PickupInventoryItem, slotID)
        if ok then return true end
    end
    return false
end

local function IsSocketItemModifierDown()
    if IsModifiedClick then
        local ok, active = pcall(IsModifiedClick, "SOCKETITEM")
        if ok and active then return true end
    end

    local modifier = "SHIFT"
    if GetModifiedClick then
        local ok, value = pcall(GetModifiedClick, "SOCKETITEM")
        value = ok and type(value)=="string" and string.upper(value) or nil
        if value=="SHIFT" or value=="CTRL" or value=="ALT" then modifier=value end
    end

    if modifier=="CTRL" then return IsControlKeyDown and IsControlKeyDown() and true or false end
    if modifier=="ALT" then return IsAltKeyDown and IsAltKeyDown() and true or false end
    return IsShiftKeyDown and IsShiftKeyDown() and true or false
end

-- Resolve item/currency textures defensively. Stock Wrath APIs normally return
-- texture paths, but custom 3.3.5 cores sometimes return item IDs or numeric
-- strings instead. Prefer a cached item texture whenever possible.
local function ResolveItemTexture(reference, fallbackName)
    local function FromItemInfo(ref)
        if not ref or not GetItemInfo then return nil end
        local _,_,_,_,_,_,_,_,_,texture=GetItemInfo(ref)
        return texture
    end

    if type(reference)=="string" and reference~="" then
        if string.find(reference,"\\") or string.find(reference,"/") then return reference end
        local itemID=tonumber(string.match(reference,"item:(%d+)")) or tonumber(reference)
        if itemID and GetItemIcon then
            local texture=GetItemIcon(itemID)
            if texture then return texture end
        end
        local texture=FromItemInfo(reference)
        if texture then return texture end
    elseif type(reference)=="number" and reference>0 then
        if GetItemIcon then
            local texture=GetItemIcon(reference)
            if texture then return texture end
        end
        local texture=FromItemInfo(reference)
        if texture then return texture end
    end

    if fallbackName and fallbackName~="" then
        local texture=FromItemInfo(fallbackName)
        if texture then return texture end
    end
    return nil
end

local function Money(copper)
    copper=tonumber(copper) or 0
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g=math.floor(copper/10000); local s=math.floor((copper%10000)/100); local c=copper%100
    return string.format("%dg %ds %dc",g,s,c)
end

-- Merchant vendors on Wrath can charge an "extended cost": item tokens (and,
-- on stock clients, honor/arena points) in addition to or instead of money.
-- Zen previously rendered every buy row through Money(), which turned
-- token-only prices into misleading 0-copper costs.
local function MerchantCostString(index, price, extendedCost)
    price=tonumber(price) or 0
    if not extendedCost or not GetMerchantItemCostInfo then
        return Money(price)
    end

    local parts={}
    if price>0 then parts[#parts+1]=Money(price) end

    local honorPoints,arenaPoints,itemCount=GetMerchantItemCostInfo(index)
    honorPoints=tonumber(honorPoints) or 0
    arenaPoints=tonumber(arenaPoints) or 0
    itemCount=tonumber(itemCount) or 0

    -- Ebonhold is PvE-only, but retain stock Wrath compatibility if these
    -- currency fields ever appear. Item-token costs are the important path.
    if honorPoints>0 then parts[#parts+1]=tostring(honorPoints).." Honor" end
    if arenaPoints>0 then parts[#parts+1]=tostring(arenaPoints).." Arena" end

    if GetMerchantItemCostItem then
        for costIndex=1,itemCount do
            local texture,value,itemLink=GetMerchantItemCostItem(index,costIndex)
            value=tonumber(value) or 0
            if texture and value>0 then
                local countText=tostring(value)
                if GetItemCount and itemLink then
                    local have=tonumber(GetItemCount(itemLink)) or 0
                    if have<value then countText="|cffff6666"..countText.."|r" end
                end
                parts[#parts+1]=countText.." |T"..tostring(texture)..":14:14:0:0|t"
            end
        end
    end

    -- Never lie with "0 copper" when the server says this is extended-cost
    -- but exposes its custom currency through a private API we do not know.
    if #parts==0 then return "Item cost" end
    return table.concat(parts,"  ")
end

local function MerchantMaxAffordable(index,maxStack,price,extendedCost)
    local maxPurchasable=math.max(1,tonumber(maxStack) or 1)
    price=tonumber(price) or 0

    -- Stock MerchantFrame treats GetMerchantItemInfo().price as the cost of
    -- one vendor purchase, even if that purchase yields a stack of items.
    if price>0 and GetMoney then
        maxPurchasable=math.min(maxPurchasable,math.floor((GetMoney() or 0)/price))
    end

    if extendedCost and GetMerchantItemCostInfo and GetMerchantItemCostItem and GetItemCount then
        local _,_,itemCount=GetMerchantItemCostInfo(index)
        itemCount=tonumber(itemCount) or 0
        for costIndex=1,itemCount do
            local _,value,itemLink=GetMerchantItemCostItem(index,costIndex)
            value=tonumber(value) or 0
            if itemLink and value>0 then
                local have=tonumber(GetItemCount(itemLink)) or 0
                maxPurchasable=math.min(maxPurchasable,math.floor(have/value))
            end
        end
    end

    return math.max(0,maxPurchasable)
end

local function Suppress(frame)
    if not frame or frame.RUIPhaseBSuppressed then return end
    frame.RUIPhaseBSuppressed=true
    frame.RUIPhaseBOldAlpha=frame:GetAlpha()
    frame.RUIPhaseBOldMouse=frame:IsMouseEnabled()
    frame:SetAlpha(0)
    frame:EnableMouse(false)
end

local function Restore(frame)
    if not frame or not frame.RUIPhaseBSuppressed then return end
    frame.RUIPhaseBSuppressed=nil
    frame:SetAlpha(frame.RUIPhaseBOldAlpha or 1)
    frame:EnableMouse(frame.RUIPhaseBOldMouse ~= false)
end

function PhaseB:RegisterMover(key, frame)
    local i=INFO[key]
    RUI:RegisterMover(i.mover,frame,{ label=i.label,width=i.width,height=i.height,point="CENTER",relativePoint="CENTER",x=i.x,y=i.y,targetPoint="TOPLEFT",moverPoint="TOPLEFT",enabled=Enabled(key) })
    if RUI.EnableDirectPanelDrag then RUI:EnableDirectPanelDrag(frame, i.mover) end
    self:ApplyScale(key)
end

function PhaseB:ApplyScale(key)
    local f=self.frames and self.frames[key]; local i=INFO[key]; if not f or not i then return end
    local s=RUI:GetEffectiveScale(i.scale); f:SetScale(s); RUI:UpdateMoverSize(i.mover,i.width*s,i.height*s)
end

function PhaseB:CloseBankSession(reason)
    local f=self.frames and self.frames.bank
    if not f or f.RUIBankClosing then return end

    f.RUIBankClosing=true
    f.bankOpen=false
    local bags=RUI:GetModule("Bags"); if bags and bags.RefreshSecureBagClicks then bags:RefreshSecureBagClicks() end
    f.extBankRequested=false
    f.RUIKeepVoidVisible=nil
    f.RUIKeepExtManagerOpen=nil
    f.pendingVoidToNative=nil
    f.pendingBankToVoid=nil
    if f.extManager then f.extManager:Hide() end

    -- Ebonhold's ExtBank transport can leave native-bank deposit suppression
    -- active. Always clear it when Zen's bank is being replaced/hidden.
    if type(ExtBankSetActive)=="function" then pcall(ExtBankSetActive,0) end
    if (f.voidReady or f.RUIBagnonVoidOpened) and type(CloseVoidStorageFrame)=="function" then
        pcall(CloseVoidStorageFrame)
    end
    if f.nativeVoidBagnonFrame then
        Restore(f.nativeVoidBagnonFrame)
        f.nativeVoidBagnonFrame=nil
    end
    f.RUIBagnonVoidOpened=nil

    -- Close the actual banker interaction as well as the Zen frame. Without
    -- this, replacing Bank with Character/Merchant/etc. only hid our window and
    -- WoW still considered BANKFRAME_OPENED active, preventing a clean reopen.
    if type(CloseBankFrame)=="function" then pcall(CloseBankFrame) end

    if f:IsShown() then f:Hide() end
    Restore(BankFrame)
    f.RUIBankClosing=nil
end

function PhaseB:HideOthers(except)
    if InCombatLockdown and InCombatLockdown() then return end
    if RUI.ActivateExclusivePanel then RUI:ActivateExclusivePanel(except) end
    for _,f in pairs(self.frames or {}) do
        if f~=except and f:IsShown() then
            if f.RUIPhaseBKey=="bank" and f.bankOpen then
                self:CloseBankSession("replaced")
            else
                f:Hide()
            end
        end
    end
end

-- -------------------------------------------------------------------------
-- Character
-- -------------------------------------------------------------------------
local EQUIP = {
    {"HeadSlot",1,"Head"},{"NeckSlot",2,"Neck"},{"ShoulderSlot",3,"Shoulder"},{"BackSlot",15,"Back"},{"ChestSlot",5,"Chest"},{"ShirtSlot",4,"Shirt"},{"TabardSlot",19,"Tabard"},{"WristSlot",9,"Wrist"},
    {"HandsSlot",10,"Hands"},{"WaistSlot",6,"Waist"},{"LegsSlot",7,"Legs"},{"FeetSlot",8,"Feet"},{"Finger0Slot",11,"Ring 1"},{"Finger1Slot",12,"Ring 2"},{"Trinket0Slot",13,"Trinket 1"},{"Trinket1Slot",14,"Trinket 2"},
    {"MainHandSlot",16,"Main Hand"},{"SecondaryHandSlot",17,"Off Hand"},{"RangedSlot",18,"Ranged / Relic"},
}

-- Keep the familiar Wrath paper-doll silhouette: armor down both sides and
-- the three weapon/relic slots centered beneath the character model.
local EQUIP_LAYOUT = {
    [1]={"LEFT",1}, [2]={"LEFT",2}, [3]={"LEFT",3}, [15]={"LEFT",4},
    [5]={"LEFT",5}, [4]={"LEFT",6}, [19]={"LEFT",7}, [9]={"LEFT",8},
    [10]={"RIGHT",1}, [6]={"RIGHT",2}, [7]={"RIGHT",3}, [8]={"RIGHT",4},
    [11]={"RIGHT",5}, [12]={"RIGHT",6}, [13]={"RIGHT",7}, [14]={"RIGHT",8},
    [16]={"BOTTOM",1}, [17]={"BOTTOM",2}, [18]={"BOTTOM",3},
}

local CHARACTER_LIST_ROWS = 10

-- Standard Wrath currencies can be present in the currency list even when the
-- item itself is not in the local item cache (most commonly zero-count tokens).
-- Give those entries a stable item-ID fallback so their icons still resolve.
local STANDARD_CURRENCY_ITEM_IDS = {
    ["Badge of Justice"] = 29434,
    ["Emblem of Heroism"] = 40752,
    ["Emblem of Valor"] = 40753,
    ["Emblem of Conquest"] = 45624,
    ["Emblem of Triumph"] = 47241,
    ["Emblem of Frost"] = 49426,
    ["Champion's Seal"] = 44990,
}

local CHARACTER_STAT_MODES = {
    { key="base", label="Base" },
    { key="melee", label="Melee" },
    { key="ranged", label="Ranged" },
    { key="spell", label="Spell" },
    { key="defense", label="Defense" },
}

local function Number(value, decimals)
    value = tonumber(value) or 0
    if decimals then return string.format("%."..tostring(decimals).."f", value) end
    return tostring(math.floor(value + 0.5))
end

-- Several 3.3.5/private-server APIs return 0/1 (and occasionally "0"/"1")
-- instead of Lua booleans.  In Lua, numeric 0 is truthy, so normalize first.
local function Flag(value)
    return value == true or value == 1 or value == "1"
end

local function TrimText(value)
    value=tostring(value or "")
    value=string.gsub(value,"^%s+","")
    value=string.gsub(value,"%s+$","")
    return value
end

local function CharacterTitleEntries()
    local entries={{ id=0, name="No Title", preview="Clear your displayed title." }}
    if not (GetNumTitles and GetTitleName and IsTitleKnown) then
        return entries, false
    end

    local playerName=UnitName("player") or "Player"
    local maxTitle=tonumber(GetNumTitles()) or 0
    for titleID=1,maxTitle do
        if Flag(IsTitleKnown(titleID)) then
            local raw=GetTitleName(titleID)
            if raw and raw~="" then
                raw=tostring(raw)
                local prefix=string.sub(raw,-1)==" "
                local clean=TrimText(raw)
                local preview
                if prefix then preview=clean.." "..playerName else preview=playerName..", "..clean end
                table.insert(entries,{ id=titleID, name=clean, preview=preview })
            end
        end
    end

    table.sort(entries,function(a,b)
        if a.id==0 then return true end
        if b.id==0 then return false end
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)
    return entries, true
end

local function RatingLine(name, ratingIndex)
    if not GetCombatRating or not ratingIndex then return nil end
    local rating = GetCombatRating(ratingIndex) or 0
    local bonus = GetCombatRatingBonus and GetCombatRatingBonus(ratingIndex) or 0
    return name, Number(rating).."  ("..Number(bonus, 2).."%)"
end

local STAT_HELP = {
    Health = "Your current and maximum health.",
    Power = "Your current and maximum class resource.",
    Mana = "Mana is your spellcasting resource. Intellect contributes to your maximum mana pool.",
    Rage = "Rage is generated through combat and spent on Warrior or Bear-form abilities.",
    Focus = "Focus is a regenerating combat resource.",
    Energy = "Energy regenerates continuously and is spent on Rogue or Cat-form abilities.",
    Happiness = "Happiness is the legacy pet resource used by some Wrath pet systems.",
    Runes = "Runes are a Death Knight resource. Your rune states are also shown on the HUD.",
    ["Runic Power"] = "Runic Power is generated by Death Knight abilities and spent on runic attacks.",
    Armor = "Armor reduces physical damage taken from enemies near your level.",
    Strength = "Strength increases melee power and benefits some class abilities.",
    Agility = "Agility contributes to attack power, critical strike and avoidance depending on class.",
    Stamina = "Stamina increases your maximum health.",
    Intellect = "Intellect increases mana and contributes to spell critical strike for mana users.",
    Spirit = "Spirit contributes to health and mana regeneration depending on class.",
    Damage = "The approximate damage range of your currently equipped weapon or attack type.",
    ["Off-hand Damage"] = "The approximate damage range of your off-hand weapon.",
    ["Attack Speed"] = "Time in seconds between attacks. Lower values attack faster.",
    ["Attack Power"] = "Attack Power increases the damage of physical attacks and abilities.",
    ["Hit Rating"] = "Hit Rating reduces your chance to miss attacks or spells.",
    ["Critical Strike"] = "Chance for eligible attacks or spells to critically strike.",
    ["Haste Rating"] = "Haste Rating increases attack or spell speed.",
    Expertise = "Expertise reduces the chance that your melee attacks are dodged or parried.",
    ["Armor Penetration"] = "Armor Penetration reduces the effective armor of targets for physical attacks.",
    ["Spell Power"] = "Spell Power increases the effect of damaging spells.",
    ["Spell Penetration"] = "Spell Penetration reduces enemy spell resistance; it does not increase spell hit chance.",
    Healing = "Healing power increases the effect of healing spells.",
    ["Mana Regen"] = "Approximate mana regenerated every five seconds while not casting.",
    ["While Casting"] = "Approximate mana regenerated every five seconds while casting.",
    Defense = "Defense skill reduces the chance enemies hit or critically strike you.",
    Dodge = "Chance to completely avoid a melee attack by dodging.",
    Parry = "Chance to completely avoid a melee attack by parrying.",
    Block = "Chance to block an incoming melee attack when a shield permits it.",
    ["Block Value"] = "The amount of physical damage removed by a successful shield block.",
    ["Defense Rating"] = "Defense Rating increases your Defense skill.",
    Resilience = "Resilience reduces the effectiveness of enemy player critical strikes and related PvP damage.",
}

local function Detail(left, right, good)
    return { left=tostring(left or ""), right=tostring(right or ""), good=good }
end

local function Note(text)
    return { text=tostring(text or ""), note=true }
end

local function RatingValues(ratingIndex)
    if not GetCombatRating or not ratingIndex then return 0, 0 end
    local rating=GetCombatRating(ratingIndex) or 0
    local bonus=GetCombatRatingBonus and GetCombatRatingBonus(ratingIndex) or 0
    return rating, bonus
end

local function CapDetails(details, label, current, cap, suffix)
    suffix=suffix or "%"
    current=tonumber(current) or 0
    cap=tonumber(cap) or 0
    table.insert(details,Detail(label,Number(cap,2)..suffix,current>=cap))
    table.insert(details,Detail("Gap from current",Number(math.max(0,cap-current),2)..suffix,current>=cap))
end

local function RatingDetails(ratingIndex, cap, capLabel, extraCap)
    local rating,bonus=RatingValues(ratingIndex)
    local details={
        Detail("Rating",Number(rating)),
        Detail("From rating",Number(bonus,2).."%"),
    }
    if cap then
        CapDetails(details,capLabel or "Raid boss cap",bonus,cap,"%")
        table.insert(details,Note("Wrath +3-level reference. Talents, racials, debuffs and Ebonhold effects can change the rating actually required."))
    end
    if extraCap then
        table.insert(details,Detail(extraCap.label,extraCap.value,nil))
    end
    return details,rating,bonus
end

local function AddStatLine(lines, name, value, details)
    if value == nil or value == "" then return end
    table.insert(lines, { name=name, value=tostring(value), help=STAT_HELP[name], details=details })
end

local SCHOOL_NAMES={ [2]="Holy",[3]="Fire",[4]="Nature",[5]="Frost",[6]="Shadow",[7]="Arcane" }

local POWER_TYPE_NAMES = {
    [0]="Mana", [1]="Rage", [2]="Focus", [3]="Energy", [4]="Happiness", [5]="Runes", [6]="Runic Power",
    MANA="Mana", RAGE="Rage", FOCUS="Focus", ENERGY="Energy", HAPPINESS="Happiness", RUNES="Runes", RUNIC_POWER="Runic Power",
}

local CLASS_RESOURCE_FALLBACK = {
    WARRIOR="Rage",
    ROGUE="Energy",
    DEATHKNIGHT="Runic Power",
    PALADIN="Mana",
    HUNTER="Mana", -- Wrath hunters still use mana.
    PRIEST="Mana",
    SHAMAN="Mana",
    MAGE="Mana",
    WARLOCK="Mana",
    DRUID="Mana", -- UnitPowerType overrides this while shifted.
}

local function PlayerResourceInfo()
    local powerType,powerToken
    if type(UnitPowerType)=="function" then
        powerType,powerToken=UnitPowerType("player")
    end

    local resourceName=POWER_TYPE_NAMES[powerToken] or POWER_TYPE_NAMES[powerType]
    if not resourceName then
        local _,classToken=UnitClass("player")
        resourceName=CLASS_RESOURCE_FALLBACK[classToken] or "Power"
    end

    local power,maxPower
    if type(UnitPower)=="function" and type(UnitPowerMax)=="function" then
        power=UnitPower("player") or 0
        maxPower=UnitPowerMax("player") or 0
    elseif type(UnitMana)=="function" and type(UnitManaMax)=="function" then
        power=UnitMana("player") or 0
        maxPower=UnitManaMax("player") or 0
    else
        power,maxPower=0,0
    end

    return resourceName,power,maxPower,powerType,powerToken
end

local function CharacterStatLines(mode)
    local lines = {}
    if mode == "base" then
        local hp, maxhp = UnitHealth("player") or 0, UnitHealthMax("player") or 0
        AddStatLine(lines, "Health", Number(hp).." / "..Number(maxhp), { Detail("Current",Number(hp)), Detail("Maximum",Number(maxhp)), Detail("Missing",Number(math.max(0,maxhp-hp))) })

        local resourceName,power,maxpower=PlayerResourceInfo()
        if (maxpower or 0) > 0 then
            local resourceDetails={
                Detail("Current",Number(power)),
                Detail("Maximum",Number(maxpower)),
            }
            if resourceName=="Mana" and type(UnitStat)=="function" then
                local _,intellect=UnitStat("player",4)
                if intellect then table.insert(resourceDetails,Detail("Intellect",Number(intellect))) end
                table.insert(resourceDetails,Note("Intellect contributes to your maximum mana. Talents, gear and Ebonhold effects can modify the final pool."))
            elseif resourceName=="Rage" then
                table.insert(resourceDetails,Note("Rage is generated in combat and spent on rage abilities."))
            elseif resourceName=="Energy" then
                table.insert(resourceDetails,Note("Energy regenerates continuously and is spent on energy abilities."))
            elseif resourceName=="Runic Power" then
                table.insert(resourceDetails,Note("Runic Power is generated by Death Knight abilities; rune cooldowns are tracked separately."))
            end
            AddStatLine(lines, resourceName, Number(power).." / "..Number(maxpower), resourceDetails)
        end

        local baseArmor,effectiveArmor,armor,posArmor,negArmor = UnitArmor("player")
        local armorDetails={ Detail("Base",Number(baseArmor or armor or 0)), Detail("Effective",Number(effectiveArmor or armor or 0)) }
        if (posArmor or 0)~=0 then table.insert(armorDetails,Detail("Positive modifiers","+"..Number(posArmor))) end
        if (negArmor or 0)~=0 then table.insert(armorDetails,Detail("Negative modifiers",Number(negArmor))) end
        if PaperDollFrame_GetArmorReduction then
            local reduction=PaperDollFrame_GetArmorReduction(effectiveArmor or armor or 0,UnitLevel("player") or 80)
            if reduction then table.insert(armorDetails,Detail("Physical reduction",Number(reduction,2).."%")) end
        end
        AddStatLine(lines, "Armor", Number(effectiveArmor or armor or 0), armorDetails)

        local statNames = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
        for i=1,5 do
            local base,effective,pos,neg=UnitStat("player",i)
            local details={ Detail("Base",Number(base or 0)), Detail("Effective",Number(effective or 0)) }
            if (pos or 0)~=0 then table.insert(details,Detail("Positive modifiers","+"..Number(pos))) end
            if (neg or 0)~=0 then table.insert(details,Detail("Negative modifiers",Number(neg))) end
            AddStatLine(lines, statNames[i], Number(effective or 0), details)
        end

    elseif mode == "melee" then
        local minD,maxD,offMin,offMax = UnitDamage("player")
        local mainSpeed,offSpeed=UnitAttackSpeed("player")
        local damageDetails={}
        if mainSpeed and mainSpeed>0 then
            table.insert(damageDetails,Detail("Main-hand speed",Number(mainSpeed,2).." sec"))
            table.insert(damageDetails,Detail("Main-hand DPS",Number((((minD or 0)+(maxD or 0))/2)/mainSpeed,2)))
        end
        if offMin and offMin>0 then
            table.insert(damageDetails,Detail("Off-hand damage",Number(offMin,1).." - "..Number(offMax or offMin,1)))
            if offSpeed and offSpeed>0 then
                table.insert(damageDetails,Detail("Off-hand speed",Number(offSpeed,2).." sec"))
                table.insert(damageDetails,Detail("Off-hand DPS",Number((((offMin or 0)+(offMax or offMin or 0))/2)/offSpeed,2)))
            end
        end
        AddStatLine(lines, "Damage", Number(minD,1).." - "..Number(maxD,1), damageDetails)

        local hasteRating,hasteBonus=RatingValues(_G.CR_HASTE_MELEE or 18)
        AddStatLine(lines, "Attack Speed", Number(mainSpeed or 0,2)..((offSpeed and offSpeed>0) and (" / "..Number(offSpeed,2)) or ""), { Detail("Melee haste rating",Number(hasteRating)), Detail("From rating",Number(hasteBonus,2).."%") })

        local base,pos,neg = UnitAttackPower("player")
        local total=(base or 0)+(pos or 0)+(neg or 0)
        AddStatLine(lines, "Attack Power", Number(total), { Detail("Base",Number(base or 0)), Detail("Positive modifiers","+"..Number(pos or 0)), Detail("Negative modifiers",Number(neg or 0)), Detail("Approx. weapon DPS from AP",Number(total/14,2)) })

        local hitDetails,hitRating,hitBonus=RatingDetails(_G.CR_HIT_MELEE or 6,8,"Special-attack cap (+3)")
        if offSpeed and offSpeed>0 then table.insert(hitDetails,Detail("Dual-wield auto cap (+3)","27.00%",hitBonus>=27)) end
        AddStatLine(lines,"Hit Rating",Number(hitRating).."  ("..Number(hitBonus,2).."%)",hitDetails)

        local crit=GetCritChance and GetCritChance() or 0
        local critRating,critBonus=RatingValues(_G.CR_CRIT_MELEE or 9)
        AddStatLine(lines, "Critical Strike", Number(crit,2).."%", { Detail("Total melee crit",Number(crit,2).."%"), Detail("Crit rating",Number(critRating)), Detail("From rating",Number(critBonus,2).."%"), Note("Critical strike has no single practical hard cap; encounter mechanics and hit-table limits matter.") })

        local hasteDetails,hRating,hBonus=RatingDetails(_G.CR_HASTE_MELEE or 18,nil)
        AddStatLine(lines,"Haste Rating",Number(hRating).."  ("..Number(hBonus,2).."%)",hasteDetails)

        if GetExpertise then
            local mh,oh=GetExpertise(); mh=tonumber(mh) or 0; oh=tonumber(oh) or mh
            local expRating=GetCombatRating and GetCombatRating(_G.CR_EXPERTISE or 24) or 0
            local details={ Detail("Expertise rating",Number(expRating)), Detail("Main-hand reduction",Number(mh*0.25,2).."% dodge/parry"), Detail("Dodge cap (+3)","26 expertise / 6.50%",mh>=26), Detail("Front parry reference","~56 expertise / 14.00%",mh>=56), Note("26 is the usual DPS soft cap when attacking from behind. Parry is normally only relevant from the front.") }
            AddStatLine(lines,"Expertise",Number(mh)..((oh~=mh) and (" / "..Number(oh)) or ""),details)
        end

        local arpRating,arpBonus=RatingValues(_G.CR_ARMOR_PENETRATION or 25)
        local arpPercent=GetArmorPenetration and GetArmorPenetration() or arpBonus
        local arpDetails={ Detail("Rating",Number(arpRating)), Detail("Armor ignored",Number(arpPercent,2).."%"), Detail("Hard cap","100.00%",arpPercent>=100), Detail("Gap",Number(math.max(0,100-arpPercent),2).."%",arpPercent>=100) }
        AddStatLine(lines,"Armor Penetration",Number(arpRating).."  ("..Number(arpPercent,2).."%)",arpDetails)

    elseif mode == "ranged" then
        local speed,minD,maxD = UnitRangedDamage("player")
        if speed and speed > 0 then
            AddStatLine(lines, "Damage", Number(minD or 0,1).." - "..Number(maxD or 0,1), { Detail("Attack speed",Number(speed,2).." sec"), Detail("Average DPS",Number((((minD or 0)+(maxD or 0))/2)/speed,2)) })
            local hasteRating,hasteBonus=RatingValues(_G.CR_HASTE_RANGED or 19)
            AddStatLine(lines, "Attack Speed", Number(speed,2), { Detail("Ranged haste rating",Number(hasteRating)), Detail("From rating",Number(hasteBonus,2).."%") })
        end
        local base,pos,neg = UnitRangedAttackPower("player")
        local total=(base or 0)+(pos or 0)+(neg or 0)
        AddStatLine(lines, "Attack Power", Number(total), { Detail("Base",Number(base or 0)), Detail("Positive modifiers","+"..Number(pos or 0)), Detail("Negative modifiers",Number(neg or 0)) })

        local hitDetails,hitRating,hitBonus=RatingDetails(_G.CR_HIT_RANGED or 7,8,"Ranged hit cap (+3)")
        AddStatLine(lines,"Hit Rating",Number(hitRating).."  ("..Number(hitBonus,2).."%)",hitDetails)

        local crit=GetRangedCritChance and GetRangedCritChance() or 0
        local critRating,critBonus=RatingValues(_G.CR_CRIT_RANGED or 10)
        AddStatLine(lines,"Critical Strike",Number(crit,2).."%",{ Detail("Total ranged crit",Number(crit,2).."%"), Detail("Crit rating",Number(critRating)), Detail("From rating",Number(critBonus,2).."%") })

        local hasteDetails,hRating,hBonus=RatingDetails(_G.CR_HASTE_RANGED or 19,nil)
        AddStatLine(lines,"Haste Rating",Number(hRating).."  ("..Number(hBonus,2).."%)",hasteDetails)

        local arpRating,arpBonus=RatingValues(_G.CR_ARMOR_PENETRATION or 25)
        local arpPercent=GetArmorPenetration and GetArmorPenetration() or arpBonus
        AddStatLine(lines,"Armor Penetration",Number(arpRating).."  ("..Number(arpPercent,2).."%)",{ Detail("Rating",Number(arpRating)), Detail("Armor ignored",Number(arpPercent,2).."%"), Detail("Hard cap","100.00%",arpPercent>=100), Detail("Gap",Number(math.max(0,100-arpPercent),2).."%",arpPercent>=100) })

    elseif mode == "spell" then
        local bestDamage = 0
        local spDetails={}
        if GetSpellBonusDamage then
            for school=2,7 do
                local value=GetSpellBonusDamage(school) or 0
                bestDamage=math.max(bestDamage,value)
                table.insert(spDetails,Detail(SCHOOL_NAMES[school] or ("School "..school),Number(value)))
            end
        end
        AddStatLine(lines, "Spell Power", Number(bestDamage), spDetails)

        if GetSpellBonusHealing then
            local healing=GetSpellBonusHealing() or 0
            AddStatLine(lines, "Healing", Number(healing), { Detail("Bonus healing",Number(healing)) })
        end

        local hitDetails,hitRating,hitBonus=RatingDetails(_G.CR_HIT_SPELL or 8,17,"Spell hit cap (+3)")
        if GetSpellPenetration then table.insert(hitDetails,Detail("Spell penetration",Number(GetSpellPenetration() or 0))) end
        AddStatLine(lines,"Hit Rating",Number(hitRating).."  ("..Number(hitBonus,2).."%)",hitDetails)

        local bestCrit=0
        local critDetails={}
        if GetSpellCritChance then
            for school=2,7 do
                local value=GetSpellCritChance(school) or 0
                bestCrit=math.max(bestCrit,value)
                table.insert(critDetails,Detail(SCHOOL_NAMES[school] or ("School "..school),Number(value,2).."%"))
            end
        end
        local critRating,critBonus=RatingValues(_G.CR_CRIT_SPELL or 11)
        table.insert(critDetails,1,Detail("Spell crit rating",Number(critRating)))
        table.insert(critDetails,2,Detail("From rating",Number(critBonus,2).."%"))
        AddStatLine(lines, "Critical Strike", Number(bestCrit,2).."%", critDetails)

        local hasteDetails,hRating,hBonus=RatingDetails(_G.CR_HASTE_SPELL or 20,nil)
        AddStatLine(lines,"Haste Rating",Number(hRating).."  ("..Number(hBonus,2).."%)",hasteDetails)

        if GetSpellPenetration then
            local pen=GetSpellPenetration() or 0
            AddStatLine(lines,"Spell Penetration",Number(pen),{ Detail("Current",Number(pen)), Note("Spell Penetration reduces enemy spell resistance; it does not increase spell hit chance.") })
        end

        if GetManaRegen then
            local base,casting=GetManaRegen(); base=(base or 0)*5; casting=(casting or 0)*5
            AddStatLine(lines,"Mana Regen",Number(base,1).." / "..Number(casting,1),{ Detail("Not casting",Number(base,1).." / 5 sec"), Detail("While casting",Number(casting,1).." / 5 sec") })
        end

    else
        local baseArmor,effectiveArmor,armor,posArmor,negArmor = UnitArmor("player")
        local armorDetails={ Detail("Base",Number(baseArmor or armor or 0)), Detail("Effective",Number(effectiveArmor or armor or 0)) }
        if PaperDollFrame_GetArmorReduction then
            local reduction=PaperDollFrame_GetArmorReduction(effectiveArmor or armor or 0,UnitLevel("player") or 80)
            if reduction then table.insert(armorDetails,Detail("Physical reduction",Number(reduction,2).."%")) end
        end
        AddStatLine(lines, "Armor", Number(effectiveArmor or armor or 0), armorDetails)

        if UnitDefense then
            local base,mod=UnitDefense("player"); local total=(base or 0)+(mod or 0)
            local level=UnitLevel("player") or 80
            local bossCap=(level*5)+140
            local defRating,defBonus=RatingValues(_G.CR_DEFENSE_SKILL or 2)
            local details={ Detail("Base skill",Number(base or 0)), Detail("Modifier",Number(mod or 0)), Detail("Defense rating",Number(defRating)), Detail("Skill from rating",Number(defBonus,2)), Detail("Crit-immunity reference (+3)",Number(bossCap).." defense",total>=bossCap), Detail("Skill remaining",Number(math.max(0,bossCap-total)),total>=bossCap), Note("Wrath raid-boss reference. Talents and Ebonhold mechanics can alter actual crit immunity requirements.") }
            AddStatLine(lines,"Defense",Number(total),details)
        end

        local dodge=GetDodgeChance and GetDodgeChance() or 0
        local dodgeRating,dodgeBonus=RatingValues(_G.CR_DODGE or 3)
        AddStatLine(lines,"Dodge",Number(dodge,2).."%",{ Detail("Total chance",Number(dodge,2).."%"), Detail("Dodge rating",Number(dodgeRating)), Detail("From rating",Number(dodgeBonus,2).."%") })

        local parry=GetParryChance and GetParryChance() or 0
        local parryRating,parryBonus=RatingValues(_G.CR_PARRY or 4)
        AddStatLine(lines,"Parry",Number(parry,2).."%",{ Detail("Total chance",Number(parry,2).."%"), Detail("Parry rating",Number(parryRating)), Detail("From rating",Number(parryBonus,2).."%") })

        local block=GetBlockChance and GetBlockChance() or 0
        local blockRating,blockBonus=RatingValues(_G.CR_BLOCK or 5)
        AddStatLine(lines,"Block",Number(block,2).."%",{ Detail("Total chance",Number(block,2).."%"), Detail("Block rating",Number(blockRating)), Detail("From rating",Number(blockBonus,2).."%"), Detail("Block value",Number(GetShieldBlock and GetShieldBlock() or 0)) })

        if GetShieldBlock then
            AddStatLine(lines,"Block Value",Number(GetShieldBlock() or 0),{ Detail("Damage blocked",Number(GetShieldBlock() or 0)) })
        end

        local defDetails,defRating,defBonus=RatingDetails(_G.CR_DEFENSE_SKILL or 2,nil)
        AddStatLine(lines,"Defense Rating",Number(defRating).."  (+"..Number(defBonus,2).." skill)",defDetails)

        if GetCombatRating then
            local melee=GetCombatRating(_G.CR_CRIT_TAKEN_MELEE or 15) or 0
            local ranged=GetCombatRating(_G.CR_CRIT_TAKEN_RANGED or 16) or 0
            local spell=GetCombatRating(_G.CR_CRIT_TAKEN_SPELL or 17) or 0
            local resilience=math.min(melee,ranged,spell)
            local bonus=GetCombatRatingBonus and GetCombatRatingBonus(_G.CR_CRIT_TAKEN_MELEE or 15) or 0
            AddStatLine(lines,"Resilience",Number(resilience),{ Detail("Rating",Number(resilience)), Detail("Crit reduction from rating",Number(bonus,2).."%"), Note("Primarily a PvP stat; ZenUI keeps it here for parity with the Wrath paper doll.") })
        end
    end
    return lines
end

local function ResetCharacterListRow(r)
    r:Hide(); r.index=nil; r:SetScript("OnClick",nil); r.icon:Hide(); r.sub:SetText(""); r.value:SetText(""); r.bar:Hide(); r.fill:Hide()
    r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT",r,"TOPLEFT",12,-6)
    local tr,tg,tb=RUI:GetTextColor(false); r.name:SetTextColor(tr,tg,tb)
    local mr,mg,mb=RUI:GetTextColor(true); r.sub:SetTextColor(mr,mg,mb); r.value:SetTextColor(mr,mg,mb)
end

local function SetCharacterListRow(r, data)
    r:Show(); r.index=data.index
    if data.header then
        r.name:ClearAllPoints(); r.name:SetPoint("LEFT",r,"LEFT",12,0)
        r.name:SetText((data.collapsed and "+ " or "− ")..(data.name or "")); r.sub:SetText(""); r.value:SetText("")
        local ar,ag,ab=RUI:GetAccentColor(); r.name:SetTextColor(ar,ag,ab)
        if r.RUIBackground then r.RUIBackground:SetAlpha(.50) end
    else
        if r.RUIBackground then r.RUIBackground:SetAlpha(.27) end
        r.name:ClearAllPoints()
        if data.icon then
            r.icon:SetTexture(data.icon); r.icon:Show(); r.name:SetPoint("TOPLEFT",r,"TOPLEFT",42,-5)
        else
            r.name:SetPoint("TOPLEFT",r,"TOPLEFT",14,-5)
        end
        r.name:SetText(data.name or ""); r.sub:SetText(data.sub or ""); r.value:SetText(data.value or "")
        if data.subBright then local tr,tg,tb=RUI:GetTextColor(false); r.sub:SetTextColor(tr,tg,tb) end
        if data.tracked then local ar,ag,ab=RUI:GetAccentColor(); r.name:SetTextColor(ar,ag,ab) end
        if data.progress ~= nil then
            local pct=math.max(0,math.min(1,tonumber(data.progress) or 0)); r.bar:Show()
            if pct > 0 then r.fill:Show(); r.fill:SetWidth(math.max(1,(r.RUIBarWidth or 622)*pct)) else r.fill:Hide() end
        end
    end
    if data.onclick then r:SetScript("OnClick",data.onclick) end
end

local EQUIPMENT_SET_ICON_INDEX_CACHE = {}

local function EquipmentSetAPIsAvailable()
    return type(GetNumEquipmentSets)=="function" and type(GetEquipmentSetInfo)=="function"
end

local function EquipmentSetFeatureEnabled()
    if not EquipmentSetAPIsAvailable() then return false end
    if type(GetCVar)=="function" then
        local ok,value=pcall(GetCVar,"equipmentManager")
        if ok and value~=nil and tostring(value)~="" and tonumber(value)==0 then return false end
    end
    return true
end

local function EquipmentSetIconTexture(icon)
    if not icon or tostring(icon)=="" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    local value=tostring(icon)
    if not string.find(value,"\\") and not string.find(value,"/") then
        value="Interface\\Icons\\"..value
    end
    return value
end

local function EquipmentSetIconKey(icon)
    local value=string.lower(tostring(icon or ""))
    value=string.gsub(value,"/","\\")
    value=string.gsub(value,"^interface\\icons\\","")
    return value
end

local function EquipmentSetIconIndex(icon)
    local key=EquipmentSetIconKey(icon)
    if key=="" then return 1 end
    if EQUIPMENT_SET_ICON_INDEX_CACHE[key] then return EQUIPMENT_SET_ICON_INDEX_CACHE[key] end
    if type(GetNumMacroIcons)~="function" or type(GetMacroIconInfo)~="function" then return 1 end
    local okCount,count=pcall(GetNumMacroIcons)
    if not okCount then return 1 end
    count=tonumber(count) or 0
    for i=1,count do
        local ok,texture=pcall(GetMacroIconInfo,i)
        if ok and EquipmentSetIconKey(texture)==key then
            EQUIPMENT_SET_ICON_INDEX_CACHE[key]=i
            return i
        end
    end
    return 1
end

local function CurrentEquipmentSetIconIndex()
    local texture=nil
    if GetInventoryItemTexture then
        texture=GetInventoryItemTexture("player",16) or GetInventoryItemTexture("player",1) or GetInventoryItemTexture("player",5)
    end
    return EquipmentSetIconIndex(texture)
end

local function EquipmentSetIsEquipped(name)
    if not name or type(GetEquipmentSetLocations)~="function" or type(EquipmentManager_UnpackLocation)~="function" then return false end
    local ok,locations=pcall(GetEquipmentSetLocations,name)
    if not ok or type(locations)~="table" then return false end
    local checked=false
    for slot=1,19 do
        local location=locations[slot]
        if location~=nil and location~=1 then
            checked=true
            if location==0 then
                if GetInventoryItemID and GetInventoryItemID("player",slot) then return false end
            elseif location==-1 then
                return false
            else
                local unpackOK,player,bank,bags,locationSlot=pcall(EquipmentManager_UnpackLocation,location)
                if not unpackOK or not player or bank or bags or tonumber(locationSlot)~=slot then return false end
            end
        end
    end
    return checked
end

local function TrimEquipmentSetName(value)
    value=tostring(value or "")
    value=string.gsub(value,"^%s+","")
    value=string.gsub(value,"%s+$","")
    return value
end

local CHARACTER_MODEL_DEFAULT_ROTATION = 0.61
local CHARACTER_MODEL_SCALE = {
    -- Fixed full-body fit per playable 3.3.5 race.  Character zoom is
    -- intentionally disabled: every open gets the same deterministic framing.
    Human=0.82, Dwarf=0.90, NightElf=0.74, Gnome=1.10, Draenei=0.73,
    Orc=0.80, Scourge=0.82, Tauren=0.67, Troll=0.73, BloodElf=0.82,
}

local function ApplyCharacterModelFit(frame)
    if not frame or not frame.model then return end
    local model=frame.model
    local _,raceFile=UnitRace("player")
    local scale=CHARACTER_MODEL_SCALE[raceFile or ""] or 0.82
    if model.SetPortraitZoom then model:SetPortraitZoom(0) end
    if model.SetCamDistanceScale then model:SetCamDistanceScale(1.0) end
    if model.SetModelScale then model:SetModelScale(scale) end
    frame.modelRotation=CHARACTER_MODEL_DEFAULT_ROTATION
    if model.SetRotation then model:SetRotation(frame.modelRotation) end
end

local function ResetCharacterModelView(frame, reloadUnit)
    if not frame or not frame.model then return end
    local model=frame.model
    if reloadUnit then
        if model.ClearModel then model:ClearModel() end
        if model.SetUnit then model:SetUnit("player") end
        frame.modelInitialized=true
        frame.modelNeedsUnitRefresh=nil
    end
    ApplyCharacterModelFit(frame)
    -- Ebonhold can restore the native model scale for a frame or two after
    -- SetUnit/show. Reassert the fixed fit briefly, then stop completely.
    model.RUIFitRefreshFrames=3
end

local function ReloadCharacterModel(frame)
    ResetCharacterModelView(frame,true)
end

local function PositionCharacterSecureItemTarget(button)
    local secure=button and button.RUISecureItemTarget
    if not secure or not UIParent or not button.GetLeft or not button.GetBottom then return false end

    local left,bottom=button:GetLeft(),button:GetBottom()
    local width,height=button:GetWidth(),button:GetHeight()
    if not left or not bottom or not width or not height then return false end

    -- IMPORTANT: keep the protected target-slot button outside the Character
    -- frame hierarchy. A SecureActionButton child makes its ancestors combat
    -- protected as well, which used to make the visible Equipment/Reputation/
    -- Skills/Currency/Titles tabs stop responding during raid combat.
    --
    -- Position the transparent secure overlay in absolute UIParent space only
    -- while out of combat. It has no anchor/parent dependency on the Zen panel,
    -- so the Character shell remains an ordinary frame that can be navigated
    -- freely during lockdown.
    local buttonScale=(button.GetEffectiveScale and button:GetEffectiveScale()) or 1
    local uiScale=(UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if not uiScale or uiScale==0 then uiScale=1 end
    local ratio=buttonScale/uiScale

    secure:ClearAllPoints()
    secure:SetWidth(width*ratio)
    secure:SetHeight(height*ratio)
    secure:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",left*ratio,bottom*ratio)
    if secure.SetFrameStrata and button.GetFrameStrata then secure:SetFrameStrata(button:GetFrameStrata() or "DIALOG") end
    if secure.SetFrameLevel and button.GetFrameLevel then secure:SetFrameLevel((button:GetFrameLevel() or 1)+20) end
    return true
end

function PhaseB:UpdateCharacterSecureItemTargets()
    local f=self.frames and self.frames.character
    if not f or not f.equipButtons then return end

    -- The external RUISecureItemTarget buttons are protected. Never reposition,
    -- show/hide or change their mouse routing from insecure Lua during combat.
    -- Their secure visibility driver hides them automatically in lockdown.
    if InCombatLockdown and InCombatLockdown() then return end

    local canTarget=false
    if f:IsShown() and f.mode=="equipment" and SpellCanTargetItem then
        local ok,value=pcall(SpellCanTargetItem)
        canTarget=ok and value and true or false
    end

    for _,button in ipairs(f.equipButtons) do
        local secure=button.RUISecureItemTarget
        if secure and secure.EnableMouse then
            local ready=canTarget and button:IsShown() and PositionCharacterSecureItemTarget(button)
            secure:EnableMouse(ready and true or false)
            if ready then secure:Show() else secure:Hide() end
        end
    end
end

function PhaseB:CreateCharacter()
    local f=Panel("ZenUICharacterFrame","character","Character")
    self.frames.character=f; f.mode="equipment"; f.offset=0; f.statMode="base"; f.modelRotation=CHARACTER_MODEL_DEFAULT_ROTATION
    f.content=CreateFrame("Frame",nil,f.body); f.content:SetPoint("TOPLEFT",f.body,"TOPLEFT",2,-36); f.content:SetPoint("BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-2,2); RUI:CreateBackdrop(f.content)
    -- Equipment artwork/buttons stay in their own ordinary layer. The protected
    -- target-slot helpers used for enchants are intentionally NOT children of
    -- this panel (see PositionCharacterSecureItemTarget above), so raid combat
    -- never turns the whole Character window into a protected frame.
    f.equipmentLayer=CreateFrame("Frame",nil,f.content); f.equipmentLayer:SetAllPoints(f.content)

    f.tabs={}
    local tabs={{"equipment","Equipment"},{"reputation","Reputation"},{"skills","Skills"},{"currency","Currency"},{"titles","Titles"}}
    for n,t in ipairs(tabs) do
        local mode,label=t[1],t[2]
        local b=Button(f.body,label,118,24)
        b:SetPoint("TOPLEFT",f.body,"TOPLEFT",(n-1)*126,-2)
        b:SetScript("OnClick",function()
            f.mode=mode
            f.offset=0
            ShowIf(f.equipmentLayer,mode=="equipment")
            PhaseB:UpdateCharacterSecureItemTargets()
            PhaseB:RefreshCharacter()
        end)
        f.tabs[mode]=b
    end

    f.model=CreateFrame("PlayerModel",nil,f.content); f.model:SetPoint("TOP",f.content,"TOP",0,-42); f.model:SetWidth(380); f.model:SetHeight(244); f.model:EnableMouse(true); f.model:EnableMouseWheel(false); if Model_OnLoad then Model_OnLoad(f.model) end
    f.model:SetScript("OnMouseDown",function(self,button)
        if button=="LeftButton" then local x=GetCursorPosition(); self.RUIRotating=true; self.RUILastX=x end
    end)
    f.model:SetScript("OnMouseUp",function(self,button)
        self.RUIRotating=nil
        if button=="LeftButton" and CursorHasItem and CursorHasItem() and AutoEquipCursorItem then AutoEquipCursorItem() end
    end)
    f.model:SetScript("OnUpdate",function(self)
        if (self.RUIFitRefreshFrames or 0)>0 then
            self.RUIFitRefreshFrames=self.RUIFitRefreshFrames-1
            ApplyCharacterModelFit(f)
        end
        if not self.RUIRotating then return end
        local x=GetCursorPosition(); local dx=x-(self.RUILastX or x); self.RUILastX=x; f.modelRotation=(f.modelRotation or 0)+(dx*.012); if self.SetRotation then self:SetRotation(f.modelRotation) end
    end)
    f:SetScript("OnShow",function(self)
        PhaseB:HideOthers(self)
        -- Ordinary reopen does not reload the unit.  It resets the same live
        -- PlayerModel to Wrath's stock zoom origin. Equipment changes are the
        -- only reason to call SetUnit again. SetUnit is avoided during combat;
        -- the already-built Zen panel remains fully accessible even if its
        -- model needs a later refresh.
        if not (InCombatLockdown and InCombatLockdown()) then
            ResetCharacterModelView(self,(not self.modelInitialized) or self.modelNeedsUnitRefresh)
        end
        PhaseB:UpdateCharacterSecureItemTargets()
        PhaseB:RefreshCharacter()
    end)
    f:SetScript("OnHide",function(self)
        self.modelRotation=CHARACTER_MODEL_DEFAULT_ROTATION
        if self.model then self.model.RUIFitRefreshFrames=0 end
        if self.setManager then self.setManager:Hide() end
        PhaseB:UpdateCharacterSecureItemTargets()
    end)
    f.close:SetScript("OnClick",function()
        f:Hide()
    end)
    f.name=Text(f.content,"",14,"TOP",f.content,"TOP",0,-12,false); f.info=Text(f.content,"",10,"TOP",f.name,"BOTTOM",0,-3,true)
    f.rotateHint=Text(f.content,"Drag model to rotate  •  auto-fit full body",8,"TOPRIGHT",f.content,"TOPRIGHT",-78,-15,true); f.rotateHint:SetJustifyH("RIGHT")

    f.setManagerToggle=Button(f.content,"Equipment Sets",112,22)
    f.setManagerToggle:SetPoint("TOPRIGHT",f.content,"TOPRIGHT",-12,-9)
    f.rotateHint:ClearAllPoints(); f.rotateHint:SetPoint("TOPRIGHT",f.content,"TOPRIGHT",-132,-15)

    local setManager=CreateFrame("Frame",nil,f)
    f.setManager=setManager
    setManager:SetWidth(270); setManager:SetHeight(486); setManager:SetFrameStrata("DIALOG"); setManager:SetFrameLevel(f:GetFrameLevel()+12); setManager:EnableMouse(true); setManager:EnableMouseWheel(true); setManager:Hide()
    RUI:CreateBackdrop(setManager); setManager.accent=RUI:CreateAccentLine(setManager,2)
    setManager.title=Text(setManager,"Equipment Sets",14,"TOPLEFT",setManager,"TOPLEFT",12,-14,false)
    setManager.subtitle=Text(setManager,"Blizzard / Ebonhold Equipment Manager",8,"TOPLEFT",setManager.title,"BOTTOMLEFT",0,-3,true)
    setManager.close=Button(setManager,"X",26,22); setManager.close:SetPoint("TOPRIGHT",setManager,"TOPRIGHT",-8,-8); setManager.close:SetScript("OnClick",function() setManager:Hide() end)
    setManager.rows={}; setManager.offset=0
    for i=1,8 do
        local r=Row(setManager,242,34); r:SetPoint("TOPLEFT",setManager,"TOPLEFT",14,-48-((i-1)*36)); r:RegisterForClicks("LeftButtonUp"); r:RegisterForDrag("LeftButton")
        r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetWidth(26); r.icon:SetHeight(26); r.icon:SetPoint("LEFT",r,"LEFT",5,0)
        r.name=Text(r,"",11,"LEFT",r.icon,"RIGHT",8,3,false); r.name:SetWidth(152); r.name:SetJustifyH("LEFT")
        r.status=Text(r,"",8,"BOTTOMLEFT",r.icon,"BOTTOMRIGHT",8,0,true); r.status:SetWidth(154); r.status:SetJustifyH("LEFT")
        r:SetScript("OnClick",function(self)
            if not self.setName then return end
            setManager.selectedName=self.setName; setManager.selectedIndex=self.setIndex; setManager.deleteConfirm=nil
            if setManager.deleteButton and setManager.deleteButton.RUIText then setManager.deleteButton.RUIText:SetText("Delete") end
            if setManager.nameEdit then setManager.nameEdit:SetText(self.setName); setManager.nameEdit:ClearFocus() end
            PhaseB:RefreshEquipmentSetManager()
        end)
        r:SetScript("OnDragStart",function(self)
            if not self.setIndex or type(PickupEquipmentSet)~="function" then return end
            if InCombatLockdown and InCombatLockdown() then RUI:Print("Equipment sets cannot be picked up in combat."); return end
            pcall(PickupEquipmentSet,self.setIndex)
        end)
        setManager.rows[i]=r
    end
    setManager.nameEdit=Edit(setManager,242,24,"Set name")
    setManager.nameEdit:SetPoint("TOPLEFT",setManager,"TOPLEFT",14,-342)
    setManager.equipButton=Button(setManager,"Equip",74,24); setManager.equipButton:SetPoint("TOPLEFT",setManager,"TOPLEFT",14,-374)
    setManager.saveButton=Button(setManager,"Save Current",92,24); setManager.saveButton:SetPoint("LEFT",setManager.equipButton,"RIGHT",6,0)
    setManager.newButton=Button(setManager,"New",64,24); setManager.newButton:SetPoint("LEFT",setManager.saveButton,"RIGHT",6,0)
    setManager.renameButton=Button(setManager,"Rename",76,24); setManager.renameButton:SetPoint("TOPLEFT",setManager,"TOPLEFT",14,-404)
    setManager.deleteButton=Button(setManager,"Delete",76,24); setManager.deleteButton:SetPoint("LEFT",setManager.renameButton,"RIGHT",6,0)
    setManager.hint=Text(setManager,"Select a set, then Equip / Save / Rename / Delete.\nDrag a set to place it on an action bar. Changes are blocked in combat.",8,"TOPLEFT",setManager,"TOPLEFT",14,-438,true); setManager.hint:SetWidth(242); setManager.hint:SetJustifyH("LEFT")

    setManager.newButton:SetScript("OnClick",function()
        setManager.selectedName=nil; setManager.selectedIndex=nil; setManager.deleteConfirm=nil
        setManager.nameEdit:SetText(""); setManager.nameEdit:SetFocus()
        if setManager.deleteButton.RUIText then setManager.deleteButton.RUIText:SetText("Delete") end
        PhaseB:RefreshEquipmentSetManager()
    end)
    setManager.equipButton:SetScript("OnClick",function()
        local name=setManager.selectedName
        if not name then RUI:Print("Select an equipment set first."); return end
        if InCombatLockdown and InCombatLockdown() then RUI:Print("Equipment sets cannot be equipped in combat."); return end
        if EquipmentSetContainsLockedItems then
            local ok,locked=pcall(EquipmentSetContainsLockedItems,name)
            if ok and locked then RUI:Print("That equipment set contains locked items."); return end
        end
        if type(EquipmentManager_EquipSet)=="function" then
            pcall(EquipmentManager_EquipSet,name)
        elseif type(UseEquipmentSet)=="function" then
            local ok,result=pcall(UseEquipmentSet,name)
            if not ok or not result then RUI:Print("Unable to equip "..tostring(name)..".") end
        end
    end)
    setManager.saveButton:SetScript("OnClick",function()
        if type(SaveEquipmentSet)~="function" then RUI:Print("Equipment Manager save API is unavailable on this client."); return end
        if InCombatLockdown and InCombatLockdown() then RUI:Print("Equipment sets cannot be saved in combat."); return end
        local name=setManager.selectedName or TrimEquipmentSetName(setManager.nameEdit:GetText())
        if name=="" then RUI:Print("Enter a name for the equipment set."); return end
        local iconIndex=CurrentEquipmentSetIconIndex()
        if setManager.selectedIndex and GetEquipmentSetInfo then
            local ok,existingName,icon=pcall(GetEquipmentSetInfo,setManager.selectedIndex)
            if ok and existingName==name and icon then iconIndex=EquipmentSetIconIndex(icon) end
        end
        local ok,err=pcall(SaveEquipmentSet,name,iconIndex)
        if not ok then RUI:Print("Unable to save equipment set: "..tostring(err)); return end
        setManager.selectedName=name
        PhaseB:RefreshEquipmentSetManager()
    end)
    setManager.renameButton:SetScript("OnClick",function()
        if type(RenameEquipmentSet)~="function" then RUI:Print("Equipment Manager rename API is unavailable on this client."); return end
        if InCombatLockdown and InCombatLockdown() then RUI:Print("Equipment sets cannot be renamed in combat."); return end
        local oldName=setManager.selectedName; local newName=TrimEquipmentSetName(setManager.nameEdit:GetText())
        if not oldName then RUI:Print("Select an equipment set first."); return end
        if newName=="" then RUI:Print("Enter the new set name first."); return end
        if newName==oldName then return end
        local ok,err=pcall(RenameEquipmentSet,oldName,newName)
        if not ok then RUI:Print("Unable to rename equipment set: "..tostring(err)); return end
        setManager.selectedName=newName; setManager.deleteConfirm=nil
        PhaseB:RefreshEquipmentSetManager()
    end)
    setManager.deleteButton:SetScript("OnClick",function()
        if type(DeleteEquipmentSet)~="function" then RUI:Print("Equipment Manager delete API is unavailable on this client."); return end
        if InCombatLockdown and InCombatLockdown() then RUI:Print("Equipment sets cannot be deleted in combat."); return end
        local name=setManager.selectedName
        if not name then RUI:Print("Select an equipment set first."); return end
        if setManager.deleteConfirm~=name then
            setManager.deleteConfirm=name
            setManager.deleteButton.RUIText:SetText("Confirm")
            RUI:Print("Click Confirm to delete equipment set '"..tostring(name).."'.")
            return
        end
        local ok,err=pcall(DeleteEquipmentSet,name)
        if not ok then RUI:Print("Unable to delete equipment set: "..tostring(err)); return end
        setManager.selectedName=nil; setManager.selectedIndex=nil; setManager.deleteConfirm=nil; setManager.nameEdit:SetText(""); setManager.deleteButton.RUIText:SetText("Delete")
        PhaseB:RefreshEquipmentSetManager()
    end)
    setManager:SetScript("OnMouseWheel",function(_,delta)
        local count=(GetNumEquipmentSets and tonumber(GetNumEquipmentSets())) or 0
        local maxOffset=math.max(0,count-#setManager.rows)
        setManager.offset=math.max(0,math.min(maxOffset,(setManager.offset or 0)-(delta>0 and 1 or -1)))
        PhaseB:RefreshEquipmentSetManager()
    end)
    f.setManagerToggle:SetScript("OnClick",function()
        if setManager:IsShown() then setManager:Hide(); return end
        PhaseB:PositionEquipmentSetManager()
        PhaseB:RefreshEquipmentSetManager()
        setManager:Show()
    end)

    f.equipButtons={}
    for n,e in ipairs(EQUIP) do
        local b=ItemSlot(f.equipmentLayer,42); b.slotID=e[2]; b.slotKey=e[1]; b.slotName=e[3]; b:RegisterForDrag("LeftButton")
        local layout=EQUIP_LAYOUT[b.slotID]
        if layout and layout[1]=="LEFT" then
            b:SetPoint("TOPLEFT",f.content,"TOPLEFT",20,-28-((layout[2]-1)*47))
        elseif layout and layout[1]=="RIGHT" then
            b:SetPoint("TOPRIGHT",f.content,"TOPRIGHT",-20,-28-((layout[2]-1)*47))
        else
            b:SetPoint("TOP",f.content,"TOP",(layout and ((layout[2]-2)*54) or 0),-292)
        end

        -- Secure item-target overlay. Wrath's SecureActionButtonTemplate has a
        -- built-in target-slot action that calls UseInventoryItem(slot) from
        -- secure code when SpellCanTargetItem() is active. This is the correct
        -- path for enchants, armor kits, scopes, stones and similar effects on
        -- Ebonhold; manually invoking PickupInventoryItem/native OnClick from
        -- Zen taints the protected action. The overlay is mouse-transparent at
        -- all other times, leaving normal Zen equipment clicks untouched.
        -- Keep the protected target-slot helper OUTSIDE the Character frame
        -- hierarchy. Anchoring/parenting a secure button to this panel makes the
        -- entire ancestor chain combat-protected and prevents ordinary tab
        -- navigation in raids. We position this transparent helper in absolute
        -- UIParent coordinates only when an item-target spell is active.
        local secureTarget=CreateFrame("Button",nil,UIParent,"SecureActionButtonTemplate")
        secureTarget:SetWidth(42); secureTarget:SetHeight(42)
        secureTarget:RegisterForClicks("LeftButtonUp")
        secureTarget:SetAttribute("target-slot",b.slotID)
        secureTarget:EnableMouse(false)
        secureTarget:Hide()
        if RegisterStateDriver then
            -- If targeting happened immediately before combat, secure code hides
            -- the overlay for lockdown. PLAYER_REGEN_ENABLED refreshes it again.
            pcall(RegisterStateDriver,secureTarget,"visibility","[combat] hide; show")
        end
        secureTarget:SetScript("OnEnter",function()
            GameTooltip:SetOwner(b,"ANCHOR_RIGHT")
            if not GameTooltip:SetInventoryItem("player",b.slotID) then GameTooltip:SetText(b.slotName) end
            if CursorUpdate then pcall(CursorUpdate) end
        end)
        secureTarget:SetScript("OnLeave",function() GameTooltip:Hide() end)
        secureTarget:SetScript("PostClick",function()
            if GameTooltip then GameTooltip:Hide() end
            PhaseB:UpdateCharacterSecureItemTargets()
        end)
        b.RUISecureItemTarget=secureTarget

        b:SetScript("OnEnter",function(self)
            -- CURSOR_UPDATE is the normal route, but also re-evaluate here so
            -- Ebonhold cannot miss the secure overlay if its cursor event is
            -- delayed until after the pointer is already over this slot.
            PhaseB:UpdateCharacterSecureItemTargets()
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            if not GameTooltip:SetInventoryItem("player",self.slotID) then GameTooltip:SetText(self.slotName) end
            -- Match Blizzard paper-doll cursor feedback while an enchant,
            -- armor kit, scope, stone, etc. is waiting for an item target.
            if CursorUpdate then pcall(CursorUpdate) end
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        local function SwapSlot(self)
            local link=GetInventoryItemLink("player",self.slotID)
            if not (CursorHasItem and CursorHasItem()) and link and RUI.HandleModifiedLinkClick and RUI:HandleModifiedLinkClick(link, "LeftButton") then return end
            if PickupInventoryItem then PickupInventoryItem(self.slotID) end
        end
        b:SetScript("OnClick",function(self,button)
            -- Safety net: an item-target spell must never fall through into
            -- Zen's insecure PickupInventoryItem path. Normally the secure
            -- overlay above receives this click; if Ebonhold delivered a late
            -- cursor-state event, consume this one and arm the overlay for the
            -- next hardware click instead of triggering a protected-action
            -- popup.
            if button=="LeftButton" and SpellCanTargetItem then
                local ok,canTarget=pcall(SpellCanTargetItem)
                if ok and canTarget then
                    PhaseB:UpdateCharacterSecureItemTargets()
                    return
                end
            end

            -- Equipped items use a different native socket API from container
            -- items. Reserve the configured SOCKETITEM right-click gesture
            -- directly on Zen's Character slot so it cannot be swallowed by
            -- the custom paper-doll replacement.
            if button=="RightButton" and IsSocketItemModifierDown() then
                local link=GetInventoryItemLink and GetInventoryItemLink("player",self.slotID)
                if link and SocketInventoryItem then
                    if GameTooltip then GameTooltip:Hide() end
                    SocketInventoryItem(self.slotID)
                    return
                end
            end

            -- If the cursor is carrying an item or is in spell/item-target
            -- mode, forward the click through Blizzard's real paper-doll slot.
            -- This is the path Ebonhold enchants, armor kits, scopes, weapon
            -- stones and other equipped-item attachments expect.
            if ForwardNativeEquipmentClick(self.slotKey, self.slotID, button) then
                if GameTooltip then GameTooltip:Hide() end
                return
            end

            if button=="LeftButton" then
                SwapSlot(self)
            elseif button=="RightButton" and UseInventoryItem then
                -- Restore Blizzard paper-doll behaviour for ordinary right
                -- clicks on equipped items (usable trinkets/items, etc.).
                UseInventoryItem(self.slotID)
            end
        end)
        b:SetScript("OnDragStart",SwapSlot); b:SetScript("OnReceiveDrag",SwapSlot)
        f.equipButtons[n]=b
    end
    f.gearHint=Text(f.content,"Main Hand          Off Hand          Ranged / Relic",8,"TOP",f.content,"TOP",0,-336,true)

    f.statButtons={}; local sx=165
    for n,mode in ipairs(CHARACTER_STAT_MODES) do
        local b=Button(f.content,mode.label,66,22); b:SetPoint("TOPLEFT",f.content,"TOPLEFT",sx+((n-1)*72),-356)
        b:SetScript("OnClick",function() f.statMode=mode.key; PhaseB:RefreshCharacterStats() end); f.statButtons[mode.key]=b
    end
    f.statBox=CreateFrame("Frame",nil,f.content); f.statBox:SetPoint("TOPLEFT",f.content,"TOPLEFT",164,-384); f.statBox:SetWidth(360); f.statBox:SetHeight(100); RUI:CreateBackdrop(f.statBox)
    f.statRows={}
    for i=1,8 do
        local col=(i<=4) and 1 or 2; local row=(i-1)%4
        local lx=(col==1) and 10 or 188; local rx=(col==1) and -190 or -10
        local label=Text(f.statBox,"",9,"TOPLEFT",f.statBox,"TOPLEFT",lx,-8-(row*22),true)
        local value=Text(f.statBox,"",9,"TOPRIGHT",f.statBox,"TOPRIGHT",rx,-8-(row*22),false); value:SetJustifyH("RIGHT")
        local hit=CreateFrame("Button",nil,f.statBox); hit:SetWidth(168); hit:SetHeight(20); hit:SetPoint("TOPLEFT",f.statBox,"TOPLEFT",(col==1) and 6 or 184,-3-(row*22)); hit:EnableMouse(true)
        hit:SetScript("OnEnter",function(self)
            local data=self.RUIStatData; if not data then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(data.name or "Stat")
            if data.help and data.help~="" then GameTooltip:AddLine(data.help,1,1,1,true) end
            GameTooltip:AddDoubleLine("Current",tostring(data.value or ""),.72,.72,.72,1,.82,.35)
            for _,detail in ipairs(data.details or {}) do
                if detail.text then
                    GameTooltip:AddLine(detail.text,.58,.62,.68,true)
                else
                    local rr,rg,rb=.88,.88,.88
                    if detail.good==true then rr,rg,rb=.30,1,.42 elseif detail.good==false then rr,rg,rb=1,.68,.20 end
                    GameTooltip:AddDoubleLine(detail.left or "",detail.right or "",.68,.72,.78,rr,rg,rb)
                end
            end
            GameTooltip:Show()
        end)
        hit:SetScript("OnLeave",function() GameTooltip:Hide() end)
        f.statRows[i]={label=label,value=value,hit=hit}
    end

    f.listRows={}
    for n=1,CHARACTER_LIST_ROWS do
        local r=Row(f.content,650,42); r:SetPoint("TOPLEFT",f.content,"TOPLEFT",14,-12-((n-1)*44)); r:RegisterForClicks("LeftButtonUp","RightButtonUp")
        r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetWidth(30); r.icon:SetHeight(30); r.icon:SetPoint("LEFT",r,"LEFT",7,0); r.icon:Hide()
        r.name=Text(r,"",13,"TOPLEFT",r,"TOPLEFT",12,-5,false); r.value=Text(r,"",12,"TOPRIGHT",r,"TOPRIGHT",-10,-5,true); r.value:SetJustifyH("RIGHT")
        r.sub=Text(r,"",11,"TOPLEFT",r,"TOPLEFT",14,-22,true); r.sub:SetWidth(500); r.sub:SetJustifyH("LEFT")
        r.bar=r:CreateTexture(nil,"BACKGROUND"); r.bar:SetTexture(1,1,1,.10); r.bar:SetHeight(4); r.bar:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",14,3); r.bar:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",-14,3); r.RUIBarWidth=622; r.bar:Hide()
        r.fill=r:CreateTexture(nil,"ARTWORK"); RUI:SetAccentTexture(r.fill); r.fill:SetHeight(4); r.fill:SetPoint("LEFT",r.bar,"LEFT",0,0); r.fill:Hide()
        f.listRows[n]=r
    end
    f.listHint=Text(f.content,"",10,"BOTTOMLEFT",f.content,"BOTTOMLEFT",16,7,false); f.listHint:SetWidth(620); f.listHint:SetJustifyH("LEFT")
    f.content:EnableMouseWheel(true); f.content:SetScript("OnMouseWheel",function(_,delta)
        if f.mode~="equipment" then
            f.offset=math.max(0,(f.offset or 0)-(delta*2)); PhaseB:RefreshCharacter()
        end
    end)
    f.close:SetScript("OnClick",function() f:Hide() end)
    return f
end

function PhaseB:PositionEquipmentSetManager()
    local f=self.frames and self.frames.character; local m=f and f.setManager
    if not f or not m then return end
    m:ClearAllPoints()
    local center=f.GetCenter and f:GetCenter() or nil
    local parentWidth=UIParent and UIParent.GetWidth and UIParent:GetWidth() or nil
    if center and parentWidth and center>(parentWidth/2) then
        m:SetPoint("TOPRIGHT",f,"TOPLEFT",-6,-48)
    else
        m:SetPoint("TOPLEFT",f,"TOPRIGHT",6,-48)
    end
end

function PhaseB:RefreshEquipmentSetManager()
    local f=self.frames and self.frames.character; local m=f and f.setManager
    if not m then return end
    if not EquipmentSetFeatureEnabled() then
        for _,r in ipairs(m.rows or {}) do r:Hide() end
        if m.hint then m.hint:SetText("Enable 'Use Equipment Manager' in Interface Options to use equipment sets.") end
        return
    end
    if m.hint then m.hint:SetText("Select a set, then Equip / Save / Rename / Delete.\nDrag a set to place it on an action bar. Changes are blocked in combat.") end
    local ok,count=pcall(GetNumEquipmentSets); count=ok and tonumber(count) or 0; count=count or 0
    local selectedExists=false
    for i=1,count do
        local okInfo,name=pcall(GetEquipmentSetInfo,i)
        if okInfo and name and name==m.selectedName then m.selectedIndex=i; selectedExists=true; break end
    end
    if m.selectedName and not selectedExists then m.selectedName=nil; m.selectedIndex=nil end
    local maxOffset=math.max(0,count-#m.rows)
    m.offset=math.max(0,math.min(tonumber(m.offset) or 0,maxOffset))
    for rowIndex,r in ipairs(m.rows) do
        local setIndex=m.offset+rowIndex
        local okInfo,name,icon=pcall(GetEquipmentSetInfo,setIndex)
        if setIndex<=count and okInfo and name then
            r.setName=name; r.setIndex=setIndex; r.icon:SetTexture(EquipmentSetIconTexture(icon)); r.name:SetText(name)
            local status=""
            if EquipmentSetIsEquipped(name) then status="Equipped"
            elseif EquipmentSetContainsLockedItems then
                local okLocked,locked=pcall(EquipmentSetContainsLockedItems,name)
                if okLocked and locked then status="Items locked" end
            end
            r.status:SetText(status)
            local ar,ag,ab=RUI:GetAccentColor()
            if m.selectedName==name then RUI:SetBorderColor(r,ar,ag,ab,1) else RUI:RefreshBackdrop(r) end
            r:Show()
        else
            r.setName=nil; r.setIndex=nil; r.name:SetText(""); r.status:SetText(""); r:Hide()
        end
    end
end

function PhaseB:RefreshCharacterStats()
    local f=self.frames.character; if not f then return end
    local ar,ag,ab=RUI:GetAccentColor()
    for key,b in pairs(f.statButtons or {}) do if key==f.statMode then RUI:SetBorderColor(b,ar,ag,ab,1) else RUI:RefreshBackdrop(b) end end
    local lines=CharacterStatLines(f.statMode or "base")
    for i,row in ipairs(f.statRows or {}) do
        local data=lines[i]
        if data then row.label:SetText(data.name); row.value:SetText(data.value); row.label:Show(); row.value:Show(); row.hit.RUIStatData=data; row.hit:Show()
        else row.label:Hide(); row.value:Hide(); row.hit.RUIStatData=nil; row.hit:Hide() end
    end
end

function PhaseB:RefreshCharacter()
    local f=self.frames.character; if not f then return end
    for mode,b in pairs(f.tabs) do local a,c,d=RUI:GetAccentColor(); if mode==f.mode then RUI:SetBorderColor(b,a,c,d,1) else RUI:RefreshBackdrop(b) end end
    local equip=f.mode=="equipment"
    ShowIf(f.model,equip); ShowIf(f.name,equip); ShowIf(f.info,equip); ShowIf(f.rotateHint,equip); ShowIf(f.gearHint,equip); ShowIf(f.statBox,equip)
    ShowIf(f.setManagerToggle,equip and EquipmentSetFeatureEnabled())
    if not equip and f.setManager then f.setManager:Hide() end
    if f.listHint then
        if f.mode=="reputation" then
            f.listHint:SetText("Hint: Right-click a faction to Track / Untrack reputation.")
            local ar,ag,ab=RUI:GetAccentColor(); f.listHint:SetTextColor(ar,ag,ab)
            f.listHint:Show()
        elseif f.mode=="skills" then
            f.listHint:SetText("Mouse wheel scrolls skill categories.")
            local mr,mg,mb=RUI:GetTextColor(true); f.listHint:SetTextColor(mr,mg,mb)
            f.listHint:Show()
        elseif f.mode=="currency" then
            f.listHint:SetText("Click a group heading to expand or collapse it.  Mouse wheel scrolls.")
            local mr,mg,mb=RUI:GetTextColor(true); f.listHint:SetTextColor(mr,mg,mb)
            f.listHint:Show()
        elseif f.mode=="titles" then
            f.listHint:SetText("Click an earned title to apply it.  Select No Title to clear your title.  Mouse wheel scrolls.")
            local ar,ag,ab=RUI:GetAccentColor(); f.listHint:SetTextColor(ar,ag,ab)
            f.listHint:Show()
        else f.listHint:Hide() end
    end
    if f.equipmentLayer then ShowIf(f.equipmentLayer,equip) end
    for _,b in pairs(f.statButtons) do ShowIf(b,equip) end
    self:UpdateCharacterSecureItemTargets()
    for _,r in ipairs(f.listRows) do ResetCharacterListRow(r) end
    if equip then
        if f.model.SetUnit and (not f.modelInitialized or f.modelNeedsUnitRefresh) then
            ReloadCharacterModel(f)
        elseif f.model.SetRotation then
            f.model:SetRotation(f.modelRotation or CHARACTER_MODEL_DEFAULT_ROTATION)
        end
        f.name:SetText(UnitName("player") or "Player"); local _,class=UnitClass("player"); f.info:SetText("Level "..tostring(UnitLevel("player") or 0).."  •  "..tostring(class or ""))
        for _,b in ipairs(f.equipButtons) do local tex=GetInventoryItemTexture("player",b.slotID); b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-Backpack-EmptySlot"); SetItemSlotCount(b,"") end
        self:RefreshCharacterStats()
        if f.setManager and f.setManager:IsShown() then self:RefreshEquipmentSetManager() end
        return
    end

    local total=0
    local titleEntries=nil
    local titleAPIAvailable=true
    if f.mode=="reputation" and GetNumFactions and GetFactionInfo then total=tonumber(GetNumFactions()) or 0
    elseif f.mode=="skills" and GetNumSkillLines and GetSkillLineInfo then total=tonumber(GetNumSkillLines()) or 0
    elseif f.mode=="currency" and GetCurrencyListSize and GetCurrencyListInfo then total=tonumber(GetCurrencyListSize()) or 0
    elseif f.mode=="titles" then titleEntries,titleAPIAvailable=CharacterTitleEntries(); total=#titleEntries end
    f.offset=math.min(f.offset or 0,math.max(0,total-CHARACTER_LIST_ROWS))
    for i=1,CHARACTER_LIST_ROWS do
        local idx=f.offset+i; if idx>total then break end; local r=f.listRows[i]
        if f.mode=="reputation" then
            local name,desc,standing,bottom,top,value,atWar,canToggle,isHeader,isCollapsed,hasRep,isWatched=GetFactionInfo(idx)
            if name then
                if Flag(isHeader) then
                    SetCharacterListRow(r,{index=idx,name=name,header=true,collapsed=Flag(isCollapsed),onclick=function(self)
                        local _,_,_,_,_,_,_,_,header,collapsed=GetFactionInfo(self.index)
                        if Flag(header) then if Flag(collapsed) and ExpandFactionHeader then ExpandFactionHeader(self.index) elseif CollapseFactionHeader then CollapseFactionHeader(self.index) end; PhaseB:RefreshCharacter() end
                    end})
                else
                    local labels={"Hated","Hostile","Unfriendly","Neutral","Friendly","Honored","Revered","Exalted"}
                    local btm,topv,val=tonumber(bottom) or 0,tonumber(top) or 0,tonumber(value) or 0
                    local cur=math.max(0,val-btm); local maxv=math.max(1,topv-btm)
                    local watched=Flag(isWatched)
                    SetCharacterListRow(r,{index=idx,name=name,sub="Standing: "..(labels[tonumber(standing) or 0] or "Unknown")..(watched and "  •  Tracked" or ""),subBright=true,value=Number(cur).." / "..Number(maxv),progress=cur/maxv,tracked=watched,onclick=function(self,button)
                        if button~="RightButton" or not SetWatchedFactionIndex then return end
                        local _,_,_,_,_,_,_,_,header,_,_,currentlyWatched=GetFactionInfo(self.index)
                        if Flag(header) then return end
                        SetWatchedFactionIndex(Flag(currentlyWatched) and 0 or self.index)
                        if ReputationWatchBar_Update then ReputationWatchBar_Update() end
                        PhaseB:RefreshCharacter()
                    end})
                end
            end
        elseif f.mode=="skills" then
            local name,isHeader,isExpanded,rank,temp,modifier,maxRank,isAbandonable,stepCost,rankCost,minLevel,skillCostType,description=GetSkillLineInfo(idx)
            if name then
                if Flag(isHeader) then
                    SetCharacterListRow(r,{index=idx,name=name,header=true,collapsed=not Flag(isExpanded),onclick=function(self)
                        local _,header,expanded=GetSkillLineInfo(self.index)
                        if Flag(header) then if Flag(expanded) and CollapseSkillHeader then CollapseSkillHeader(self.index) elseif ExpandSkillHeader then ExpandSkillHeader(self.index) end; PhaseB:RefreshCharacter() end
                    end})
                else
                    local rankN,modN,maxN=tonumber(rank) or 0,tonumber(modifier) or 0,tonumber(maxRank) or 0; local effective=rankN+modN
                    SetCharacterListRow(r,{index=idx,name=name,sub=(modN~=0) and ((modN>0 and "+" or "")..Number(modN).." bonus") or "",value=Number(effective).." / "..Number(maxN),progress=(maxN>0) and (effective/maxN) or nil})
                end
            end
        elseif f.mode=="currency" then
            local name,isHeader,isExpanded,isUnused,isWatched,count,icon,maximum,hasWeeklyLimit,currentWeeklyAmount,unknown,itemID=GetCurrencyListInfo(idx)
            if name then
                if Flag(isHeader) then
                    SetCharacterListRow(r,{index=idx,name=name,header=true,collapsed=not Flag(isExpanded),onclick=function(self)
                        local _,header,expanded=GetCurrencyListInfo(self.index)
                        if Flag(header) and ExpandCurrencyList then
                            -- Wrath expects numeric 0/1 here. Passing Lua booleans is not reliable on 3.3.5/private-server clients.
                            ExpandCurrencyList(self.index,Flag(expanded) and 0 or 1)
                            if TokenFrame_Update then TokenFrame_Update() end
                            PhaseB.frames.character.offset=0
                            PhaseB:RefreshCharacter()
                        end
                    end})
                else
                    local countN,maxN=tonumber(count) or 0,tonumber(maximum) or 0
                    local currencyLink=GetCurrencyListLink and GetCurrencyListLink(idx) or nil
                    local displayIcon=ResolveItemTexture(currencyLink,name) or ResolveItemTexture(itemID,name) or ResolveItemTexture(icon,name) or ResolveItemTexture(STANDARD_CURRENCY_ITEM_IDS[name],name)
                    -- A plain texture path is still valid even if no item-cache lookup succeeded.
                    if not displayIcon and type(icon)=="string" and icon~="" and not tonumber(icon) then displayIcon=icon end
                    SetCharacterListRow(r,{index=idx,name=name,sub=(maxN>0) and ("Maximum "..Number(maxN)) or "",value=Number(countN),icon=displayIcon,progress=(maxN>0) and (countN/maxN) or nil})
                end
            end
        elseif f.mode=="titles" then
            local entry=titleEntries and titleEntries[idx]
            if entry then
                local current=GetCurrentTitle and (tonumber(GetCurrentTitle()) or 0) or 0
                local active=current==entry.id
                local sub=entry.preview or ""
                if not titleAPIAvailable and entry.id==0 then sub="This client did not expose the title-selection API." end
                SetCharacterListRow(r,{
                    index=entry.id,
                    name=entry.name,
                    sub=sub,
                    subBright=active,
                    value=active and "Active" or "",
                    tracked=active,
                    onclick=function(self)
                        if not SetCurrentTitle then return end
                        local titleID=tonumber(self.index) or 0
                        if titleID~=0 and IsTitleKnown and not Flag(IsTitleKnown(titleID)) then return end
                        -- SetCurrentTitle is hardware-event protected in Wrath, so keep
                        -- this call directly inside the user's row click.
                        SetCurrentTitle(titleID)
                        PhaseB:RefreshCharacter()
                    end
                })
            end
        end
    end
end

function PhaseB:ToggleCharacter(tab)
    if not Enabled("character") then if self.originalToggleCharacter then return self.originalToggleCharacter(tab) end; return end
    local f=self.frames.character
    local mode="equipment"
    if tab=="ReputationFrame" then mode="reputation"
    elseif tab=="SkillFrame" then mode="skills"
    elseif tab=="TokenFrame" then mode="currency"
    elseif tab=="PlayerTitlePickerFrame" then mode="titles"
    elseif tab=="PetPaperDollFrame" then if self.originalToggleCharacter then return self.originalToggleCharacter(tab) end end

    local same=f:IsShown() and f.mode==mode
    f.mode=mode; f.offset=0
    if f.equipmentLayer then ShowIf(f.equipmentLayer,mode=="equipment") end
    self:UpdateCharacterSecureItemTargets()
    if same then f:Hide() else self:HideOthers(f); f:Show(); self:RefreshCharacter() end
end

-- -------------------------------------------------------------------------
-- Quest Log
-- -------------------------------------------------------------------------
function PhaseB:CreateQuestLog()
    local f=Panel("ZenUIQuestLogFrame","quest","Quest Log"); self.frames.quest=f; f.offset=0; f.selected=nil
    f.list=CreateFrame("Frame",nil,f.body); f.list:SetPoint("TOPLEFT",2,-2); f.list:SetWidth(300); f.list:SetHeight(474); RUI:CreateBackdrop(f.list)
    f.rows={}
    for i=1,18 do
        local r=Row(f.list,278,23); r:SetPoint("TOPLEFT",f.list,"TOPLEFT",10,-10-((i-1)*25)); r:RegisterForClicks("LeftButtonUp"); r.name=Text(r,"",10,"LEFT",r,"LEFT",7,0,false); r.name:SetWidth(258); r.name:SetJustifyH("LEFT")
        r.selected=r:CreateTexture(nil,"BACKGROUND"); r.selected:SetAllPoints(); local ar,ag,ab=RUI:GetAccentColor(); r.selected:SetTexture(ar,ag,ab,.12); r.selected:Hide(); f.rows[i]=r
    end
    f.list:EnableMouseWheel(true); f.list:SetScript("OnMouseWheel",function(_,d) f.offset=math.max(0,(f.offset or 0)-d*3); PhaseB:RefreshQuestLog() end)
    f.detail=CreateFrame("Frame",nil,f.body); f.detail:SetPoint("TOPLEFT",f.list,"TOPRIGHT",10,0); f.detail:SetPoint("BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-2,42); RUI:CreateBackdrop(f.detail)
    f.qtitle=Text(f.detail,"Select a quest",15,"TOPLEFT",f.detail,"TOPLEFT",14,-14,false); f.qtitle:SetWidth(395)
    f.qbody=Text(f.detail,"",10,"TOPLEFT",f.qtitle,"BOTTOMLEFT",0,-12,false); f.qbody:SetWidth(395); f.qbody:SetJustifyH("LEFT"); f.qbody:SetJustifyV("TOP")
    f.track=Button(f.body,"Track",92,24); f.track:SetPoint("BOTTOMLEFT",f.detail,"BOTTOMLEFT",0,-34)
    f.share=Button(f.body,"Share",92,24); f.share:SetPoint("LEFT",f.track,"RIGHT",8,0)
    f.abandon=Button(f.body,"Abandon",92,24); f.abandon:SetPoint("LEFT",f.share,"RIGHT",8,0)
    f.track:SetScript("OnClick",function() PhaseB:ToggleQuestWatch() end); f.share:SetScript("OnClick",function() if QuestLogPushQuest then QuestLogPushQuest() end end); f.abandon:SetScript("OnClick",function() PhaseB:AbandonSelectedQuest() end)
    f.compatNote=Text(f.body,"Mouse wheel scrolls  •  L opens / closes Quest Log",9,"BOTTOMLEFT",f.body,"BOTTOMLEFT",4,8,true); f.compatNote:SetWidth(292); f.compatNote:SetJustifyH("LEFT")
    -- Closing Zen must also close the invisible native mirror. This keeps
    -- the L binding, Blizzard micro button and companion quest addons in the
    -- same logical open/closed state.
    f:SetScript("OnHide",function()
        -- Closing the Zen window (X/Escape/menu) must close the real
        -- native QuestLogFrame as well, because that frame is the logical
        -- state used by the L binding and companion quest addons.
        if Enabled("quest") and not PhaseB.questCompatTransition and QuestLogFrame and QuestLogFrame:IsShown() then
            PhaseB:SetNativeQuestLogShown(false)
        end
    end)
    return f
end

local function QuestTitleInfo(index)
    if not GetQuestLogTitle then return nil end
    local title,level,tag,suggestedGroup,isHeader,isCollapsed,isComplete,isDaily,questID = GetQuestLogTitle(index)
    if title then
        title=string.gsub(tostring(title),"|c%x%x%x%x%x%x%x%x","")
        title=string.gsub(title,"|r","")
    end
    return title,level,tag,suggestedGroup,isHeader,isCollapsed,isComplete,isDaily,questID
end

-- Mirror Blizzard's QuestLogTitleButton modified-click behavior.  Zen
-- owns the visible quest rows, so the native CHATLINK path has to be
-- restored explicitly or Shift-clicking a quest title only selects it.
local function DispatchQuestClickToActivityFinder(row,index,button)
    -- ZenFamilyActivityFinder intentionally hooks Blizzard's native
    -- QuestLogTitleButton_OnClick so Shift-clicking a quest can populate its
    -- Create/Edit Listing form. Zen owns custom quest rows, so that native
    -- handler would never otherwise see the click. Only bridge the click while
    -- the companion's listing editor is actually visible; its OnShow installs
    -- the hook before the player can interact with the Quest Log.
    local finder=_G.ZenFamilyActivityFinderCreateFrame or _G.RavioliFamilyActivityFinderCreateFrame
    if not finder or not finder.IsShown or not finder:IsShown() then return false end
    if not IsShiftKeyDown or not IsShiftKeyDown() then return false end
    local handler=_G.QuestLogTitleButton_OnClick
    if type(handler)~="function" then return false end

    -- The companion hook only needs the native quest-row contract: GetID(),
    -- isHeader, and the mouse button. Temporarily give our visible row that
    -- identity and let the companion addon perform its own title/link update.
    local oldID=row.GetID and row:GetID() or 0
    local oldHeader=row.isHeader
    if row.SetID then row:SetID(index) end
    row.isHeader=false
    local ok=pcall(handler,row,button or "LeftButton")
    if row.SetID then row:SetID(oldID or 0) end
    row.isHeader=oldHeader
    return ok and true or false
end

local function InsertQuestChatLink(index)
    local modified=false
    if IsModifiedClick then
        modified=IsModifiedClick("CHATLINK") and true or false
    elseif IsShiftKeyDown then
        -- Compatibility fallback for custom 3.3.5 clients that do not expose
        -- IsModifiedClick reliably. Shift is Blizzard's default CHATLINK key.
        modified=IsShiftKeyDown() and true or false
    end
    if not modified then return false end

    if GetQuestLink and ChatEdit_InsertLink then
        local ok,link=pcall(GetQuestLink,index)
        if ok and link then ChatEdit_InsertLink(link) end
    end
    return true
end

function PhaseB:RefreshQuestLog()
    local f=self.frames.quest; if not f then return end
    local total=GetNumQuestLogEntries and GetNumQuestLogEntries() or 0; f.offset=math.min(f.offset or 0,math.max(0,total-18))
    local current=GetQuestLogSelection and GetQuestLogSelection() or 0; if current==0 then current=f.selected or 0 end
    for i,r in ipairs(f.rows) do
        local idx=f.offset+i; r.selected:Hide()
        if idx<=total then
            local title,level,tag,suggestedGroup,isHeader,isCollapsed,isComplete,isDaily=QuestTitleInfo(idx)
            if title then
                r:Show(); r.index=idx; r.isHeader=isHeader and true or false
                local prefix=isHeader and (isCollapsed and "+ " or "- ") or ((level and level>0) and ("["..level..((suggestedGroup and suggestedGroup>0) and "+" or "").."] ") or "")
                local stateText=""
                local complete=(isComplete==1 or isComplete==true)
                local daily=(isDaily==1 or isDaily==true)
                if not isHeader then
                    if daily then stateText=complete and "DAILY  •  READY  •  " or "DAILY  •  IN PROGRESS  •  "
                    else stateText=complete and "READY  •  " or "IN PROGRESS  •  " end
                end
                r.name:SetText(prefix..stateText..title..((not isHeader and tag and tag~="") and ("  "..tag) or ""))
                if isHeader then
                    local ar,ag,ab=RUI:GetAccentColor(); r.name:SetTextColor(ar,ag,ab)
                elseif complete then
                    r.name:SetTextColor(.35,1,.45)
                elseif daily then
                    r.name:SetTextColor(.35,.72,1)
                else
                    r.name:SetTextColor(.88,.78,.50)
                end
                if not isHeader and idx==current then r.selected:Show() end
                r:SetScript("OnClick",function(self,button)
                    local _,_,_,_,header,collapsed=QuestTitleInfo(self.index)
                    if header then
                        if collapsed and ExpandQuestHeader then ExpandQuestHeader(self.index) elseif CollapseQuestHeader then CollapseQuestHeader(self.index) end
                    else
                        -- Companion integrations get first refusal on their
                        -- explicit modified-click workflows. In particular,
                        -- the Zen Family Activity Finder uses Shift-click
                        -- to populate its Post/Create Activity form.
                        if DispatchQuestClickToActivityFinder(self,self.index,button) then return end
                        if InsertQuestChatLink(self.index) then return end
                        if SelectQuestLogEntry then SelectQuestLogEntry(self.index) end
                        f.selected=self.index
                    end
                    PhaseB:RefreshQuestLog()
                end)
            else r:Hide() end
        else r:Hide() end
    end
    local sel=GetQuestLogSelection and GetQuestLogSelection() or 0; if not sel or sel==0 then sel=f.selected or 0 end
    if not sel or sel==0 then f.qtitle:SetText("Select a quest"); f.qbody:SetText(""); return end
    local title,level,tag,suggestedGroup,isHeader=QuestTitleInfo(sel); if isHeader or not title then f.qtitle:SetText("Select a quest"); f.qbody:SetText(""); return end
    f.selected=sel; f.qtitle:SetText(((level and level>0) and ("["..level.."] ") or "")..title)
    local desc,obj="",""; if GetQuestLogQuestText then desc,obj=GetQuestLogQuestText() end
    local lines={}; if obj and obj~="" then table.insert(lines,obj); table.insert(lines,"") end
    local n=GetNumQuestLeaderBoards and GetNumQuestLeaderBoards() or 0; for i=1,n do local text,typ,done=GetQuestLogLeaderBoard(i); table.insert(lines,(done and "|cff55ff77DONE  •  |r" or "|cffffcc66TODO  •  |r")..(text or "")) end
    if n>0 then table.insert(lines,"") end; if desc and desc~="" then table.insert(lines,desc) end
    local reward=GetQuestLogRewardMoney and GetQuestLogRewardMoney() or 0; if reward>0 then table.insert(lines,""); table.insert(lines,"Reward: "..Money(reward)) end
    f.qbody:SetText(table.concat(lines,"\n")); local watched=IsQuestWatched and IsQuestWatched(sel); f.track.RUIText:SetText(watched and "Untrack" or "Track")
end

function PhaseB:ToggleQuestWatch()
    local f=self.frames.quest; local sel=GetQuestLogSelection and GetQuestLogSelection() or f.selected; if not sel or sel==0 then return end
    if IsQuestWatched and IsQuestWatched(sel) then if RemoveQuestWatch then RemoveQuestWatch(sel) end else if AddQuestWatch then AddQuestWatch(sel) end end; self:RefreshQuestLog()
end
function PhaseB:AbandonSelectedQuest()
    local f=self.frames.quest; local sel=GetQuestLogSelection and GetQuestLogSelection() or f.selected; if not sel or sel==0 then return end
    if SelectQuestLogEntry then SelectQuestLogEntry(sel) end
    if SetAbandonQuest then SetAbandonQuest() end
    local title=GetAbandonQuestName and GetAbandonQuestName() or "this quest"
    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs.ZEN_ABANDON_QUEST={ text="Abandon "..tostring(title).."?",button1=YES,button2=NO,OnAccept=function() if AbandonQuest then AbandonQuest() end end,timeout=0,whileDead=1,hideOnEscape=1 }
        StaticPopup_Show("ZEN_ABANDON_QUEST")
    elseif AbandonQuest then AbandonQuest() end
end

function PhaseB:RememberQuestNativeState(frame)
    if not frame or self.questNativeStateSaved then return end
    self.questNativeStateSaved=true
    self.questNativeOldAlpha=frame:GetAlpha()
    self.questNativeOldMouse=frame:IsMouseEnabled()
end

function PhaseB:SuppressNativeQuestLog(frame)
    frame=frame or QuestLogFrame
    if not frame then return end
    self:RememberQuestNativeState(frame)
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    self.questNativeMirror=true
end

function PhaseB:RestoreNativeQuestLog(frame)
    frame=frame or QuestLogFrame
    if not frame then return end
    if self.questNativeStateSaved then
        frame:SetAlpha(self.questNativeOldAlpha or 1)
        frame:EnableMouse(self.questNativeOldMouse~=false)
    end
    self.questNativeStateSaved=nil
    self.questNativeOldAlpha=nil
    self.questNativeOldMouse=nil
    self.questNativeMirror=nil
end

-- The Wrath 3.3.5 TOGGLEQUESTLOG keybinding calls ToggleFrame(QuestLogFrame)
-- directly. Keep that native frame as the authoritative logical open/closed
-- state and mirror Zen to it instead of trying to own a second toggle.
-- This also lets companion quest addons see the real QuestLogFrame OnShow /
-- OnHide lifecycle while the stock artwork remains invisible.
function PhaseB:SetNativeQuestLogShown(open)
    local stock=QuestLogFrame
    if not stock then return end
    if self.questCompatTransition then return end
    self.questCompatTransition=true

    if open then
        -- Keep the stock frame visually suppressed before showing it so there
        -- is no one-frame Blizzard flash. Its native OnShow still runs.
        self:SuppressNativeQuestLog(stock)
        if not stock:IsShown() then
            if ShowUIPanel then ShowUIPanel(stock) else stock:Show() end
        end
        self:SuppressNativeQuestLog(stock)
    else
        if stock:IsShown() then
            if HideUIPanel then HideUIPanel(stock) else stock:Hide() end
            if stock:IsShown() then stock:Hide() end
        end
        -- Do NOT restore alpha/mouse while the replacement is enabled. A
        -- later native Show must begin invisible before OnShow hooks execute.
    end

    self.questCompatTransition=nil
end

function PhaseB:OpenQuestLogEntry(index)
    index=tonumber(index or 0) or 0
    if index<=0 then return end
    local f=self.frames.quest
    if not f then return end

    if SelectQuestLogEntry then SelectQuestLogEntry(index) end
    f.selected=index

    -- Keep the selected quest visible in Zen's left-hand list.
    local visibleRows=18
    if index <= (f.offset or 0) then
        f.offset=math.max(0,index-1)
    elseif index > ((f.offset or 0)+visibleRows) then
        f.offset=math.max(0,index-visibleRows)
    end

    -- The real QuestLogFrame remains the logical owner so companion quest
    -- addons still receive its native OnShow lifecycle.  Zen is only the
    -- visible presentation.
    if QuestLogFrame and not QuestLogFrame:IsShown() then
        self:SetNativeQuestLogShown(true)
    end

    self:HideOthers(f)
    if not f:IsShown() then
        self.questCompatTransition=true
        f:Show()
        self.questCompatTransition=nil
    end
    self:RefreshQuestLog()

    -- QuestLog_OpenToQuest normally opens this stock detail frame.  Keep it
    -- suppressed in case another addon also touched the tracker click.
    if QuestLogDetailFrame and QuestLogDetailFrame:IsShown() then
        QuestLogDetailFrame:Hide()
    end
end

function PhaseB:InstallQuestTrackerBridge()
    local current=_G.WatchFrameLinkButtonTemplate_OnLeftClick
    if not current then return end
    if current==self.ruiWatchFrameQuestClick then return end

    -- Preserve the latest implementation so other addons keep their normal
    -- achievement / modified-click behavior.  ADDON_LOADED re-runs this
    -- installer, so a later wrapper can be adopted as the new fallback.
    self.originalWatchFrameQuestClick=current
    self.ruiWatchFrameQuestClick=function(buttonFrame, mouseButton)
        if Enabled("quest") and buttonFrame and buttonFrame.type=="QUEST" and not (IsModifiedClick and IsModifiedClick("QUESTWATCHTOGGLE")) then
            if CloseDropDownMenus then CloseDropDownMenus() end
            local watchIndex=buttonFrame.index
            local questIndex=GetQuestIndexForWatch and GetQuestIndexForWatch(watchIndex) or nil
            if questIndex and questIndex>0 then
                if GetQuestSortIndex and ExpandQuestHeader then
                    local sortIndex=GetQuestSortIndex(questIndex)
                    if sortIndex and sortIndex>0 then ExpandQuestHeader(sortIndex) end
                    -- Expanding a header can reorder the quest log, exactly
                    -- as Blizzard's WatchFrame code notes, so resolve again.
                    questIndex=GetQuestIndexForWatch(watchIndex) or questIndex
                end
                PhaseB:OpenQuestLogEntry(questIndex)
                return
            end
        end
        if PhaseB.originalWatchFrameQuestClick then
            return PhaseB.originalWatchFrameQuestClick(buttonFrame,mouseButton)
        end
    end
    _G.WatchFrameLinkButtonTemplate_OnLeftClick=self.ruiWatchFrameQuestClick
end

function PhaseB:ToggleQuestLog()
    if not Enabled("quest") then
        -- Do not replace another quest addon's ToggleQuestLog implementation.
        -- If Zen is disabled, use the normal native frame path.
        if QuestLogFrame and ToggleFrame then return ToggleFrame(QuestLogFrame) end
        return
    end

    -- During combat, never route L through ToggleFrame(QuestLogFrame).  That
    -- stock UIPanel path is taint/protection sensitive on Ebonhold and can make
    -- the key simply stop responding.  Zen's quest window is an ordinary frame,
    -- so toggle it directly and reconcile the hidden native lifecycle when
    -- lockdown ends.
    if InCombatLockdown and InCombatLockdown() then
        local f=self.frames and self.frames.quest
        if not f then return end
        self.questCombatDirect=true
        if f:IsShown() then
            f:Hide()
        else
            f:Show()
            self:RefreshQuestLog()
        end
        return
    end

    -- Out of combat retain the native QuestLogFrame lifecycle as the
    -- compatibility bridge for companion quest addons.
    if QuestLogFrame and ToggleFrame then
        return ToggleFrame(QuestLogFrame)
    elseif QuestLogFrame then
        if QuestLogFrame:IsShown() then
            self:SetNativeQuestLogShown(false)
        else
            self:SetNativeQuestLogShown(true)
        end
    else
        local f=self.frames.quest
        if f:IsShown() then f:Hide() else self:HideOthers(f); f:Show(); self:RefreshQuestLog() end
    end
end

-- -------------------------------------------------------------------------
-- Mail
-- -------------------------------------------------------------------------
local function RememberCurrentMailCharacter()
    if not RUI.dbRoot then return end
    RUI.dbRoot.global = RUI.dbRoot.global or {}
    RUI.dbRoot.global.characterMoney = RUI.dbRoot.global.characterMoney or {}

    local name = UnitName and UnitName("player") or nil
    if not name or name == "" then return end
    local realm = GetRealmName and GetRealmName() or "Unknown"
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local key = RUI.GetCharacterKey and RUI:GetCharacterKey() or (name .. " - " .. realm)
    local store = RUI.dbRoot.global.characterMoney
    store[key] = store[key] or {}
    store[key].name = name
    store[key].realm = realm
    store[key].faction = faction
end

local SetMailButtonEnabled

local function MailProfileSettings()
    if not RUI.db then return { keepFreeSlots=1, showSessionTotal=true } end
    RUI.db.mail = RUI.db.mail or {}
    local settings = RUI.db.mail
    if settings.keepFreeSlots == nil then settings.keepFreeSlots = 1 end
    if settings.showSessionTotal == nil then settings.showSessionTotal = true end
    return settings
end

local function MailAddressBook()
    if not RUI.dbRoot then return { contacts={}, recentRecipients={} } end
    RUI.dbRoot.global = RUI.dbRoot.global or {}
    RUI.dbRoot.global.mail = RUI.dbRoot.global.mail or {}
    local book=RUI.dbRoot.global.mail
    book.contacts=book.contacts or {}; book.recentRecipients=book.recentRecipients or {}
    return book
end

local function TrimMailName(value)
    value = tostring(value or "")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

local function MailNameEquals(a,b)
    return string.lower(TrimMailName(a)) == string.lower(TrimMailName(b))
end

local function AddUniqueMailName(list, seen, value)
    local name=TrimMailName(value)
    if name=="" then return end
    local key=string.lower(name)
    if seen[key] then return end
    seen[key]=true
    table.insert(list,name)
end

local function MailAltNames()
    RememberCurrentMailCharacter()
    local out,seen={},{}
    local global=RUI.dbRoot and RUI.dbRoot.global
    local store=global and global.characterMoney
    if type(store)~="table" then return out end
    local realm=GetRealmName and GetRealmName() or "Unknown"
    local faction=UnitFactionGroup and UnitFactionGroup("player") or nil
    local player=UnitName and UnitName("player") or ""
    for key,data in pairs(store) do
        if type(data)=="table" then
            local name=tostring(data.name or string.match(tostring(key),"^(.-) %- ") or "")
            local charRealm=data.realm or realm
            local charFaction=data.faction
            if name~="" and name~=player and charRealm==realm and (not faction or not charFaction or charFaction==faction) then
                AddUniqueMailName(out,seen,name)
            end
        end
    end
    table.sort(out,function(a,b) return string.lower(a)<string.lower(b) end)
    return out
end

local function MailContactNames()
    local out,seen={},{}
    for _,name in ipairs(MailAddressBook().contacts or {}) do AddUniqueMailName(out,seen,name) end
    table.sort(out,function(a,b) return string.lower(a)<string.lower(b) end)
    return out
end

local function MailRecentNames()
    local out,seen={},{}
    for _,name in ipairs(MailAddressBook().recentRecipients or {}) do AddUniqueMailName(out,seen,name) end
    return out
end

local function MailFriendNames()
    local out,seen={},{}
    local n=GetNumFriends and GetNumFriends() or 0
    for i=1,n do
        local name=GetFriendInfo and GetFriendInfo(i)
        AddUniqueMailName(out,seen,name)
    end
    table.sort(out,function(a,b) return string.lower(a)<string.lower(b) end)
    return out
end

local function MailGuildNames()
    local out,seen={},{}
    if not IsInGuild or not IsInGuild() then return out end
    local n=GetNumGuildMembers and GetNumGuildMembers(true) or 0
    for i=1,n do
        local name=GetGuildRosterInfo and GetGuildRosterInfo(i)
        AddUniqueMailName(out,seen,name)
    end
    table.sort(out,function(a,b) return string.lower(a)<string.lower(b) end)
    return out
end

local function GetMailRecipientList(kind)
    if kind=="contacts" then return MailContactNames() end
    if kind=="recent" then return MailRecentNames() end
    if kind=="alts" then return MailAltNames() end
    if kind=="friends" then return MailFriendNames() end
    if kind=="guild" then return MailGuildNames() end
    return {}
end

local function GetMailRecipientCompletion(prefix)
    prefix=TrimMailName(prefix)
    if prefix=="" then return nil end
    local wanted=string.lower(prefix)
    local order={"contacts","recent","alts","friends","guild"}
    for _,kind in ipairs(order) do
        for _,name in ipairs(GetMailRecipientList(kind)) do
            local lowerName=string.lower(name)
            if string.sub(lowerName,1,string.len(wanted))==wanted then return name end
        end
    end
    return nil
end

function PhaseB:RememberMailRecipient(name)
    name=TrimMailName(name)
    if name=="" then return end
    local recent=MailAddressBook().recentRecipients
    for i=#recent,1,-1 do if MailNameEquals(recent[i],name) then table.remove(recent,i) end end
    table.insert(recent,1,name)
    while #recent>10 do table.remove(recent) end
end

function PhaseB:AddMailContact(name)
    name=TrimMailName(name)
    if name=="" then RUI:Print("Type a recipient name first."); return end
    local contacts=MailAddressBook().contacts
    for _,existing in ipairs(contacts) do if MailNameEquals(existing,name) then RUI:Print(name.." is already in Mail Contacts."); return end end
    table.insert(contacts,name)
    table.sort(contacts,function(a,b) return string.lower(a)<string.lower(b) end)
    RUI:Print("Added Mail Contact: "..name)
    if self.RefreshMailContactsPopup then self:RefreshMailContactsPopup() end
end

function PhaseB:RemoveMailContact(name)
    name=TrimMailName(name)
    if name=="" then RUI:Print("Type a saved contact name first."); return end
    local contacts=MailAddressBook().contacts
    for i=#contacts,1,-1 do
        if MailNameEquals(contacts[i],name) then
            table.remove(contacts,i); RUI:Print("Removed Mail Contact: "..name)
            if self.RefreshMailContactsPopup then self:RefreshMailContactsPopup() end
            return
        end
    end
    RUI:Print(name.." is not in Mail Contacts.")
end

function PhaseB:SetMailRecipient(name)
    local f=self.frames and self.frames.mail
    name=TrimMailName(name)
    if not f or name=="" then return end
    if f.mode~="send" then self:SetMailMode("send") end
    f.to:SetText(name)
    if f.to.SetCursorPosition then f.to:SetCursorPosition(string.len(name)) end
    if f.subject and f.subject.SetFocus then f.subject:SetFocus() end
    if f.contactsPopup then f.contactsPopup:Hide() end
    if CloseDropDownMenus then CloseDropDownMenus() end
end

function PhaseB:RefreshMailContactsPopup(kind)
    local f=self.frames and self.frames.mail; local popup=f and f.contactsPopup
    if not f or not popup then return end
    if kind then popup.kind=kind; popup.offset=0 end
    popup.kind=popup.kind or "contacts"
    local names=GetMailRecipientList(popup.kind)
    local pageSize=#(popup.rows or {})
    popup.offset=math.max(0,math.min(tonumber(popup.offset) or 0,math.max(0,#names-pageSize)))
    local labels={contacts="Contacts",recent="Recent",alts="Alts",friends="Friends",guild="Guild"}
    if popup.heading then popup.heading:SetText((labels[popup.kind] or "Recipients").."  •  "..tostring(#names)) end
    for key,button in pairs(popup.categoryButtons or {}) do
        if key==popup.kind then local ar,ag,ab=RUI:GetAccentColor(); RUI:SetBorderColor(button,ar,ag,ab,1)
        else RUI:RefreshBackdrop(button) end
    end
    for i,row in ipairs(popup.rows or {}) do
        local name=names[popup.offset+i]
        if name then
            row.name=name; row.RUIText:SetText(name); row:Show()
        else row.name=nil; row:Hide() end
    end
    if popup.empty then popup.empty:SetText(#names==0 and "No recipients in this group." or "") end
    if popup.scrollText then
        if #names>pageSize then popup.scrollText:SetText(string.format("%d-%d of %d  •  Mouse wheel",popup.offset+1,math.min(popup.offset+pageSize,#names),#names))
        else popup.scrollText:SetText("") end
    end
    local current=TrimMailName(f.to and f.to:GetText() or "")
    local saved=false
    for _,name in ipairs(MailAddressBook().contacts or {}) do if MailNameEquals(name,current) then saved=true; break end end
    if popup.addCurrent then
        popup.addCurrent.RUIText:SetText(current~="" and "Save Current" or "Save Current")
        SetMailButtonEnabled(popup.addCurrent,current~="" and not saved)
    end
    if popup.removeCurrent then SetMailButtonEnabled(popup.removeCurrent,current~="" and saved) end
end

function PhaseB:AutoCompleteMailRecipient(editbox)
    if not editbox or not editbox.GetText then return end
    local typed = editbox:GetText() or ""
    if typed == "" then return end

    -- Only complete while the player is typing at the end of the field. This
    -- mirrors Postal's BlackBook behavior and avoids fighting edits in the
    -- middle of an existing recipient name.
    if editbox.GetCursorPosition and editbox:GetCursorPosition() ~= string.len(typed) then return end

    local match = GetMailRecipientCompletion(typed)
    if not match or string.lower(match) == string.lower(typed) then return end

    local typedLen = string.len(typed)
    editbox:SetText(match)
    if editbox.HighlightText then editbox:HighlightText(typedLen, -1) end
    if editbox.SetCursorPosition then editbox:SetCursorPosition(typedLen) end
end

local function MailRecipientNameFromChatLink(link)
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

function PhaseB:TryPopulateMailRecipientFromChatLink(link, button)
    local f = self.frames and self.frames.mail
    if not f or not f:IsShown() or not f.to then return false end
    if button and button ~= "LeftButton" then return false end

    local modified = false
    if type(IsModifiedClick) == "function" then
        modified = IsModifiedClick("CHATLINK") and true or false
    elseif type(IsShiftKeyDown) == "function" then
        modified = IsShiftKeyDown() and true or false
    end
    if not modified then return false end

    local name = MailRecipientNameFromChatLink(link)
    if not name then return false end

    if f.mode ~= "send" then self:SetMailMode("send") end
    f.to:SetText(name)
    if f.to.SetCursorPosition then f.to:SetCursorPosition(string.len(name)) end
    if f.to.SetFocus then f.to:SetFocus() end
    return true
end

function PhaseB:InstallMailChatLinkBridge()
    if self.mailChatLinkBridgeInstalled then return end
    if type(ChatFrame_OnHyperlinkShow) ~= "function" then return end

    -- BlizzardFrames installs the Guild invite bridge earlier in module load
    -- order. Wrap whichever handler is current and delegate whenever Mail is
    -- not the active destination so all existing Shift-click behavior remains.
    local original = ChatFrame_OnHyperlinkShow
    self.mailChatLinkOriginal = original
    ChatFrame_OnHyperlinkShow = function(chatFrame, link, text, button)
        if PhaseB:TryPopulateMailRecipientFromChatLink(link, button) then
            return
        end
        return original(chatFrame, link, text, button)
    end
    self.mailChatLinkBridgeInstalled = true
end

function PhaseB:UpdateAutomaticMailSubject(firstItemName)
    local f = self.frames and self.frames.mail
    if not f or not f.subject then return end

    local current = f.subject:GetText() or ""
    local previous = f.autoSubject

    if firstItemName and firstItemName ~= "" then
        -- Fill a blank subject, or keep an automatically generated subject in
        -- sync when the first attachment changes. Never overwrite a subject
        -- the player typed themselves.
        if current == "" or (previous and current == previous) then
            f.settingAutoSubject = true
            f.subject:SetText(firstItemName)
            f.settingAutoSubject = nil
            f.autoSubject = firstItemName
        elseif previous and current ~= previous then
            f.autoSubject = nil
        end
    else
        -- If the only subject was generated by Zen and all attachments are
        -- removed, clear it again. Player-written subjects remain untouched.
        if previous and current == previous then
            f.settingAutoSubject = true
            f.subject:SetText("")
            f.settingAutoSubject = nil
        end
        f.autoSubject = nil
    end
end

function PhaseB:CreateMail()
    local f=Panel("ZenUIMailFrame","mail","Mail"); self.frames.mail=f; f.mode="inbox"; f.offset=0; f.selected=nil
    f.selectionMode=false; f.mailSelection={}; f.lastMailCheck=nil; f.mailBusy=false; f.batch=nil; f.sessionStartMoney=nil; f.pendingRecipient=nil
    f.inboxTab=Button(f.body,"Inbox",110,24); f.inboxTab:SetPoint("TOPLEFT",2,-2); f.sendTab=Button(f.body,"Send Mail",110,24); f.sendTab:SetPoint("LEFT",f.inboxTab,"RIGHT",8,0)
    f.inboxTab:SetScript("OnClick",function() PhaseB:SetMailMode("inbox") end); f.sendTab:SetScript("OnClick",function() PhaseB:SetMailMode("send") end)

    -- Inbox toolbar. Open All is deliberately paced; selection controls only
    -- become visible while Select mode is active so the header stays compact.
    f.selectToggle=Button(f.body,"Select",70,24); f.selectToggle:SetPoint("TOPRIGHT",f.body,"TOPRIGHT",-2,-2)
    f.returnSelected=Button(f.body,"Return Selected",115,24); f.returnSelected:SetPoint("RIGHT",f.selectToggle,"LEFT",-8,0)
    f.openSelected=Button(f.body,"Open Selected",110,24); f.openSelected:SetPoint("RIGHT",f.returnSelected,"LEFT",-8,0)
    f.openAll=Button(f.body,"Open All",90,24); f.openAll:SetPoint("RIGHT",f.selectToggle,"LEFT",-8,0)
    f.collectGold=Button(f.body,"Collect Gold",105,24); f.collectGold:SetPoint("RIGHT",f.openAll,"LEFT",-8,0)
    f.collectGold:SetScript("OnClick",function() PhaseB:StartCollectMailGold() end)
    f.collectGold:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText("Collect Gold"); GameTooltip:AddLine("Collects money from inbox messages one at a time, including Auction House sale proceeds.",1,1,1,true); GameTooltip:Show() end)
    f.collectGold:SetScript("OnLeave",function() GameTooltip:Hide() end)
    f.openAll:SetScript("OnClick",function() PhaseB:StartMailBatch("open",nil,"Open All") end)
    f.openAll:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText("Open All"); GameTooltip:AddLine("Collects attachments and money one operation at a time. C.O.D. and GM mail are always skipped.",1,1,1,true); GameTooltip:Show() end)
    f.openAll:SetScript("OnLeave",function() GameTooltip:Hide() end)
    f.selectToggle:SetScript("OnClick",function() PhaseB:ToggleMailSelectionMode() end)
    f.openSelected:SetScript("OnClick",function() PhaseB:StartSelectedMailBatch("open") end)
    f.returnSelected:SetScript("OnClick",function() PhaseB:StartSelectedMailBatch("return") end)

    f.inbox=CreateFrame("Frame",nil,f.body); f.inbox:SetPoint("TOPLEFT",2,-36); f.inbox:SetPoint("BOTTOMRIGHT",-2,2)
    f.mailList=CreateFrame("Frame",nil,f.inbox); f.mailList:SetPoint("TOPLEFT"); f.mailList:SetWidth(300); f.mailList:SetPoint("BOTTOMLEFT"); RUI:CreateBackdrop(f.mailList)
    f.mailRows={}; for i=1,12 do
        local r=Row(f.mailList,280,32); r:SetPoint("TOPLEFT",f.mailList,"TOPLEFT",10,-10-((i-1)*35)); r:RegisterForClicks("LeftButtonUp")
        r.select=CreateFrame("CheckButton",nil,r); r.select:SetWidth(18); r.select:SetHeight(18); r.select:SetPoint("LEFT",r,"LEFT",7,0)
        r.select.box=CreateFrame("Frame",nil,r.select); r.select.box:SetWidth(14); r.select.box:SetHeight(14); r.select.box:SetPoint("CENTER"); RUI:CreateBackdrop(r.select.box)
        r.select.mark=r.select.box:CreateTexture(nil,"OVERLAY"); r.select.mark:SetPoint("TOPLEFT",3,-3); r.select.mark:SetPoint("BOTTOMRIGHT",-3,3); RUI:SetAccentTexture(r.select.mark); r.select.mark:Hide(); r.select:Hide()
        r.sender=Text(r,"",10,"TOPLEFT",r,"TOPLEFT",8,-5,false); r.sender:SetWidth(255); r.sender:SetJustifyH("LEFT")
        r.subject=Text(r,"",9,"BOTTOMLEFT",r,"BOTTOMLEFT",8,5,true); r.subject:SetWidth(255); r.subject:SetJustifyH("LEFT")
        r.select:SetScript("OnClick",function(self) if r.index then PhaseB:ToggleMailSelection(r.index,self:GetChecked() and true or false) end end)
        r.RUIEnter=function(self)
            if not self.index then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText("Inbox message")
            if f.selectionMode then GameTooltip:AddLine("Click the checkbox to select. Shift selects a range; Ctrl selects the same sender.",1,1,1,true)
            else GameTooltip:AddLine("Shift-click: collect contents   Ctrl-click: return to sender",1,1,1,true) end
            GameTooltip:Show()
        end
        r.RUILeave=function() GameTooltip:Hide() end
        f.mailRows[i]=r
    end
    f.mailList:EnableMouseWheel(true); f.mailList:SetScript("OnMouseWheel",function(_,d) f.offset=math.max(0,(f.offset or 0)-d*3); PhaseB:RefreshMailInbox() end)
    f.mailDetail=CreateFrame("Frame",nil,f.inbox); f.mailDetail:SetPoint("TOPLEFT",f.mailList,"TOPRIGHT",10,0); f.mailDetail:SetPoint("BOTTOMRIGHT"); RUI:CreateBackdrop(f.mailDetail)
    f.mailFrom=Text(f.mailDetail,"",10,"TOPLEFT",f.mailDetail,"TOPLEFT",14,-14,true); f.mailSubject=Text(f.mailDetail,"Select a message",14,"TOPLEFT",f.mailFrom,"BOTTOMLEFT",0,-5,false); f.mailSubject:SetWidth(400)
    f.mailBody=Text(f.mailDetail,"",10,"TOPLEFT",f.mailSubject,"BOTTOMLEFT",0,-12,false); f.mailBody:SetWidth(405); f.mailBody:SetHeight(255); f.mailBody:SetJustifyH("LEFT"); f.mailBody:SetJustifyV("TOP")
    f.mailTransaction=Text(f.mailDetail,"",10,"BOTTOMLEFT",f.mailDetail,"BOTTOMLEFT",14,148,false); f.mailTransaction:SetWidth(405); f.mailTransaction:SetJustifyH("LEFT")
    f.mailAttachLabel=Text(f.mailDetail,"ATTACHMENTS",8,"BOTTOMLEFT",f.mailDetail,"BOTTOMLEFT",14,126,true)
    f.takeMoney=Button(f.mailDetail,"Take Money",105,24); f.takeMoney:SetPoint("BOTTOMLEFT",f.mailDetail,"BOTTOMLEFT",14,14); f.reply=Button(f.mailDetail,"Reply",82,24); f.reply:SetPoint("LEFT",f.takeMoney,"RIGHT",8,0); f.del=Button(f.mailDetail,"Delete / Return",118,24); f.del:SetPoint("LEFT",f.reply,"RIGHT",8,0)
    f.takeMoney:SetScript("OnClick",function() if f.selected and not f.mailBusy and TakeInboxMoney then TakeInboxMoney(f.selected) end end)
    f.reply:SetScript("OnClick",function() PhaseB:ReplyMail() end); f.del:SetScript("OnClick",function() PhaseB:DeleteMail() end)
    f.attachments={}; for i=1,16 do
        local b=ItemSlot(f.mailDetail,34); local col=(i-1)%8; local row=math.floor((i-1)/8)
        b:SetPoint("BOTTOMLEFT",f.mailDetail,"BOTTOMLEFT",14+col*39,48+row*38); b.index=i
        b:SetScript("OnEnter",function(self)
            if f.selected and GetInboxItem(f.selected,self.index) then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetInboxItem(f.selected,self.index)
                local _,_,_,_,_,cod=GetInboxHeaderInfo(f.selected); cod=tonumber(cod) or 0
                if cod>0 then GameTooltip:AddLine(" "); GameTooltip:AddLine("C.O.D. due: "..Money(cod),1,.82,0,true) end
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        b:SetScript("OnClick",function(self,button)
            local link=(GetInboxItemLink and f.selected) and GetInboxItemLink(f.selected,self.index) or (RUI.GetTooltipItemLink and RUI:GetTooltipItemLink(self))
            if link and RUI.HandleModifiedLinkClick and RUI:HandleModifiedLinkClick(link,button) then return end
            PhaseB:TakeMailAttachment(self.index)
        end)
        f.attachments[i]=b
    end

    f.send=CreateFrame("Frame",nil,f.body); f.send:SetPoint("TOPLEFT",2,-36); f.send:SetPoint("BOTTOMRIGHT",-2,2); RUI:CreateBackdrop(f.send)
    f.to=Edit(f.send,205,26,"Recipient"); f.to:SetPoint("TOPLEFT",14,-14)
    f.contactsButton=Button(f.send,"Contacts",90,26); f.contactsButton:SetPoint("LEFT",f.to,"RIGHT",7,0)
    f.subject=Edit(f.send,390,26,"Subject"); f.subject:SetPoint("LEFT",f.contactsButton,"RIGHT",7,0)

    -- Zen-owned recipient picker. EbonPostal's BlackBook inspired the source
    -- groups, but keeping this popup Zen-owned avoids exposing a parchment
    -- UIDropDown menu inside an otherwise fully Zen mail window.
    f.contactsPopup=CreateFrame("Frame",nil,f.send)
    f.contactsPopup:SetWidth(300); f.contactsPopup:SetHeight(326); f.contactsPopup:SetPoint("TOPLEFT",f.to,"BOTTOMLEFT",0,-5)
    f.contactsPopup:SetFrameStrata("FULLSCREEN_DIALOG"); f.contactsPopup:SetFrameLevel((f:GetFrameLevel() or 1)+30); f.contactsPopup:EnableMouse(true); f.contactsPopup:EnableMouseWheel(true)
    RUI:CreateBackdrop(f.contactsPopup); f.contactsPopup.accent=RUI:CreateAccentLine(f.contactsPopup,2); f.contactsPopup:Hide()
    f.contactsPopup.title=Text(f.contactsPopup,"RECIPIENTS",10,"TOPLEFT",f.contactsPopup,"TOPLEFT",10,-12,false)
    f.contactsPopup.heading=Text(f.contactsPopup,"Contacts",8,"TOPRIGHT",f.contactsPopup,"TOPRIGHT",-34,-13,true); f.contactsPopup.heading:SetJustifyH("RIGHT")
    f.contactsPopup.close=Button(f.contactsPopup,"X",22,20); f.contactsPopup.close:SetPoint("TOPRIGHT",f.contactsPopup,"TOPRIGHT",-6,-6); f.contactsPopup.close:SetScript("OnClick",function() f.contactsPopup:Hide() end)
    f.contactsPopup.categoryButtons={}
    local recipientGroups={{"contacts","Contacts"},{"recent","Recent"},{"alts","Alts"},{"friends","Friends"},{"guild","Guild"}}
    for i,def in ipairs(recipientGroups) do
        local b=Button(f.contactsPopup,def[2],52,22); b:SetPoint("TOPLEFT",f.contactsPopup,"TOPLEFT",8+(i-1)*57,-34)
        local key=def[1]; b:SetScript("OnClick",function() PhaseB:RefreshMailContactsPopup(key) end)
        f.contactsPopup.categoryButtons[key]=b
    end
    f.contactsPopup.rows={}
    for i=1,8 do
        local r=Button(f.contactsPopup,"",276,25); r:SetPoint("TOPLEFT",f.contactsPopup,"TOPLEFT",12,-63-((i-1)*27)); r.RUIText:SetJustifyH("LEFT"); r.RUIText:ClearAllPoints(); r.RUIText:SetPoint("LEFT",r,"LEFT",9,0)
        r:SetScript("OnClick",function(self) if self.name then PhaseB:SetMailRecipient(self.name) end end)
        f.contactsPopup.rows[i]=r
    end
    f.contactsPopup.empty=Text(f.contactsPopup,"",9,"TOPLEFT",f.contactsPopup,"TOPLEFT",16,-76,true)
    f.contactsPopup.scrollText=Text(f.contactsPopup,"",8,"BOTTOM",f.contactsPopup,"BOTTOM",0,39,true)
    f.contactsPopup.addCurrent=Button(f.contactsPopup,"Save Current",126,23); f.contactsPopup.addCurrent:SetPoint("BOTTOMLEFT",f.contactsPopup,"BOTTOMLEFT",12,10)
    f.contactsPopup.removeCurrent=Button(f.contactsPopup,"Remove Current",126,23); f.contactsPopup.removeCurrent:SetPoint("BOTTOMRIGHT",f.contactsPopup,"BOTTOMRIGHT",-12,10)
    f.contactsPopup.addCurrent:SetScript("OnClick",function() PhaseB:AddMailContact(f.to:GetText() or "") end)
    f.contactsPopup.removeCurrent:SetScript("OnClick",function() PhaseB:RemoveMailContact(f.to:GetText() or "") end)
    f.contactsPopup:SetScript("OnMouseWheel",function(self,delta)
        local names=GetMailRecipientList(self.kind or "contacts"); local maxOffset=math.max(0,#names-#self.rows)
        self.offset=math.max(0,math.min(maxOffset,(self.offset or 0)-(delta or 0)*3)); PhaseB:RefreshMailContactsPopup()
    end)
    f.contactsButton:SetScript("OnClick",function()
        if f.contactsPopup:IsShown() then f.contactsPopup:Hide(); return end
        if GuildRoster and IsInGuild and IsInGuild() then pcall(GuildRoster) end
        f.contactsPopup.kind=f.contactsPopup.kind or "contacts"; f.contactsPopup.offset=0; PhaseB:RefreshMailContactsPopup(); f.contactsPopup:Show()
    end)
    f.autoSubject=nil; f.settingAutoSubject=nil
    f.to:SetScript("OnChar",function(self) PhaseB:AutoCompleteMailRecipient(self) end)
    f.to.RUIOnTextChanged=function() if f.contactsPopup and f.contactsPopup:IsShown() then PhaseB:RefreshMailContactsPopup() end end
    f.subject.RUIOnTextChanged=function(self)
        if f.settingAutoSubject then return end
        local current=self:GetText() or ""
        if f.autoSubject and current~=f.autoSubject then f.autoSubject=nil end
    end

    f.messageBox=CreateFrame("Frame",nil,f.send); f.messageBox:SetPoint("TOPLEFT",f.send,"TOPLEFT",14,-52); f.messageBox:SetPoint("BOTTOMRIGHT",f.send,"BOTTOMRIGHT",-14,164); RUI:CreateBackdrop(f.messageBox)
    f.messageLabel=Text(f.messageBox,"MESSAGE",8,"TOPLEFT",f.messageBox,"TOPLEFT",8,-7,true)
    f.bodyEdit=CreateFrame("EditBox",nil,f.messageBox); f.bodyEdit:SetPoint("TOPLEFT",f.messageBox,"TOPLEFT",8,-22); f.bodyEdit:SetPoint("BOTTOMRIGHT",f.messageBox,"BOTTOMRIGHT",-8,8); f.bodyEdit:SetAutoFocus(false); f.bodyEdit:SetFont(RUI:GetFontPath(),11); f.bodyEdit:SetMultiLine(true); f.bodyEdit:SetMaxLetters(500); f.bodyEdit:SetTextInsets(2,2,2,2)
    if f.bodyEdit.SetJustifyH then f.bodyEdit:SetJustifyH("LEFT") end; if f.bodyEdit.SetJustifyV then f.bodyEdit:SetJustifyV("TOP") end

    f.attachPanel=CreateFrame("Frame",nil,f.send); f.attachPanel:SetPoint("BOTTOMLEFT",f.send,"BOTTOMLEFT",14,48); f.attachPanel:SetWidth(300); f.attachPanel:SetHeight(116); RUI:CreateBackdrop(f.attachPanel)
    f.attachLabel=Text(f.attachPanel,"ATTACHMENTS",8,"TOPLEFT",f.attachPanel,"TOPLEFT",8,-7,true)
    f.attachHint=Text(f.attachPanel,"Right-click bag items to attach",8,"TOPRIGHT",f.attachPanel,"TOPRIGHT",-8,-7,true); f.attachHint:SetJustifyH("RIGHT")
    f.sendAttachments={}; for i=1,12 do
        local b=ItemSlot(f.attachPanel,34); local col=(i-1)%6; local row=math.floor((i-1)/6)
        b:SetPoint("TOPLEFT",f.attachPanel,"TOPLEFT",8+col*42,-24-row*38); b.index=i
        b:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            if GetSendMailItem(self.index) then GameTooltip:SetSendMailItem(self.index) else GameTooltip:SetText("Empty attachment slot"); GameTooltip:AddLine("Drop an item here or right-click it in your bags.",1,1,1,true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        b:SetScript("OnClick",function(self,button)
            local link=(GetSendMailItemLink and GetSendMailItemLink(self.index)) or (RUI.GetTooltipItemLink and RUI:GetTooltipItemLink(self))
            if link and RUI.HandleModifiedLinkClick and RUI:HandleModifiedLinkClick(link,button) then return end
            if ClickSendMailItemButton then ClickSendMailItemButton(self.index) end; PhaseB:RefreshSendMail()
        end)
        b:SetScript("OnReceiveDrag",function(self) if ClickSendMailItemButton then ClickSendMailItemButton(self.index) end; PhaseB:RefreshSendMail() end)
        f.sendAttachments[i]=b
    end

    f.paymentPanel=CreateFrame("Frame",nil,f.send); f.paymentPanel:SetPoint("BOTTOMLEFT",f.send,"BOTTOMLEFT",324,48); f.paymentPanel:SetPoint("BOTTOMRIGHT",f.send,"BOTTOMRIGHT",-14,48); f.paymentPanel:SetHeight(116); RUI:CreateBackdrop(f.paymentPanel)
    f.paymentLabel=Text(f.paymentPanel,"PAYMENT",8,"TOPLEFT",f.paymentPanel,"TOPLEFT",10,-8,true)
    f.paymentSummary=Text(f.paymentPanel,"No money attached",9,"TOPRIGHT",f.paymentPanel,"TOPRIGHT",-10,-8,true); f.paymentSummary:SetJustifyH("RIGHT")
    f.goldLabel=Text(f.paymentPanel,"Gold",8,"TOPLEFT",f.paymentPanel,"TOPLEFT",12,-31,true)
    f.silverLabel=Text(f.paymentPanel,"Silver",8,"TOPLEFT",f.paymentPanel,"TOPLEFT",116,-31,true)
    f.copperLabel=Text(f.paymentPanel,"Copper",8,"TOPLEFT",f.paymentPanel,"TOPLEFT",210,-31,true)
    f.gold=Edit(f.paymentPanel,92,25,""); f.gold:SetPoint("TOPLEFT",f.paymentPanel,"TOPLEFT",12,-43)
    f.silver=Edit(f.paymentPanel,82,25,""); f.silver:SetPoint("TOPLEFT",f.paymentPanel,"TOPLEFT",116,-43)
    f.copper=Edit(f.paymentPanel,82,25,""); f.copper:SetPoint("TOPLEFT",f.paymentPanel,"TOPLEFT",210,-43)
    for _,moneyBox in ipairs({f.gold,f.silver,f.copper}) do
        if moneyBox.SetNumeric then moneyBox:SetNumeric(true) end
        moneyBox:SetMaxLetters(7)
        if moneyBox.SetJustifyH then moneyBox:SetJustifyH("CENTER") end
        if moneyBox.SetTextInsets then moneyBox:SetTextInsets(3,3,0,0) end
    end
    if f.silver.SetMaxLetters then f.silver:SetMaxLetters(2) end
    if f.copper.SetMaxLetters then f.copper:SetMaxLetters(2) end
    f.cod=Check(f.paymentPanel,"C.O.D. (recipient pays)",12,-82,function(v)
        if v then
            local hasItem=false; for i=1,12 do if GetSendMailItem and GetSendMailItem(i) then hasItem=true; break end end
            if not hasItem then f.cod:SetRUIValue(false); RUI:Print("Attach at least one item before using C.O.D.") end
        end
        PhaseB:RefreshSendMail()
    end,200)
    f.sendButton=Button(f.send,"Send",110,26); f.sendButton:SetPoint("BOTTOMRIGHT",f.send,"BOTTOMRIGHT",-14,14); f.sendButton:SetScript("OnClick",function() PhaseB:SendMailNow() end)
    f.sendSummary=Text(f.send,"",8,"BOTTOMLEFT",f.send,"BOTTOMLEFT",14,19,true); f.sendSummary:SetWidth(420); f.sendSummary:SetJustifyH("LEFT")
    f.sendHint=Text(f.send,"Shift-click a player name in chat to fill recipient  •  Esc closes Mail",8,"BOTTOMRIGHT",f.sendButton,"TOPRIGHT",0,6,true); f.sendHint:SetWidth(360); f.sendHint:SetJustifyH("RIGHT")
    local function UpdatePayment() PhaseB:RefreshSendMail() end
    f.gold.RUIOnTextChanged=UpdatePayment; f.silver.RUIOnTextChanged=UpdatePayment; f.copper.RUIOnTextChanged=UpdatePayment

    local function EscapeMail()
        if CloseMail then CloseMail() else f:Hide() end
    end
    for _,box in ipairs({f.to,f.subject,f.bodyEdit,f.gold,f.silver,f.copper}) do box:SetScript("OnEscapePressed",EscapeMail) end
    f.close:SetScript("OnClick",EscapeMail)
    f.batchDriver=CreateFrame("Frame",nil,f); f.batchDriver:Hide(); f.batchDriver.delay=0
    f.batchDriver:SetScript("OnUpdate",function(self,elapsed)
        self.delay=(self.delay or 0)-elapsed
        if self.delay<=0 then self:Hide(); PhaseB:AdvanceMailBatch() end
    end)
    f:SetScript("OnHide",function()
        if f.batch then PhaseB:FinishMailBatch(true) end
        if f.RUIClosingMail then return end
        if MailFrame and MailFrame:IsShown() and CloseMail then f.RUIClosingMail=true; CloseMail(); f.RUIClosingMail=nil end
    end)
    return f
end

function PhaseB:SetMailMode(mode)
    local f=self.frames.mail; if not f then return end
    mode=(mode=="send") and "send" or "inbox"; f.mode=mode
    -- Keep Blizzard's hidden mail state synchronized. Besides addon
    -- compatibility this is what makes normal right-click UseContainerItem
    -- attach items to outgoing mail in Wrath 3.3.5.
    if MailFrame and MailFrame:IsShown() and MailFrameTab_OnClick then
        MailFrameTab_OnClick(nil,mode=="send" and 2 or 1)
    elseif SetSendMailShowing then
        SetSendMailShowing(mode=="send")
    end
    self:RefreshMail()
end

function PhaseB:TakeMailAttachment(index)
    local f=self.frames.mail; if not f or not f.selected or not index or f.mailBusy then return end
    local _,_,_,_,_,cod=GetInboxHeaderInfo(f.selected); cod=tonumber(cod) or 0
    if cod>0 then
        -- Reuse Blizzard's native C.O.D. payment confirmation/backend while
        -- keeping its mailbox hidden. The recipient pays when taking the item.
        if InboxFrame then InboxFrame.openMailID=f.selected end
        if OpenMailFrame then OpenMailFrame.cod=cod; OpenMailFrame.lastTakeAttachment=index end
        if OpenMailAttachment_OnClick then
            OpenMailAttachment_OnClick(nil,index)
        elseif cod>(GetMoney and GetMoney() or 0) then
            if StaticPopup_Show then StaticPopup_Show("COD_ALERT") end
        elseif StaticPopup_Show then
            StaticPopup_Show("COD_CONFIRMATION")
        end
    elseif TakeInboxItem then
        TakeInboxItem(f.selected,index)
    end
end

function PhaseB:StartCollectMailGold()
    -- Use the same event-confirmed queue as Open All. The old ascending cursor
    -- could skip a message when collecting money caused an inbox row to vanish.
    self:StartMailBatch("gold",nil,"Collect Gold")
end

SetMailButtonEnabled=function(button,enabled)
    if not button then return end
    if enabled then if button.Enable then button:Enable() end; button:SetAlpha(1) else if button.Disable then button:Disable() end; button:SetAlpha(.45) end
end

function PhaseB:RefreshMailToolbar()
    local f=self.frames and self.frames.mail; if not f then return end
    local inbox=f.mode=="inbox"
    local busy=f.mailBusy
    ShowIf(f.selectToggle,inbox)
    if not inbox then
        ShowIf(f.collectGold,false); ShowIf(f.openAll,false); ShowIf(f.openSelected,false); ShowIf(f.returnSelected,false)
        return
    end
    if f.selectionMode then
        f.selectToggle.RUIText:SetText("Done")
        ShowIf(f.collectGold,false); ShowIf(f.openAll,false); ShowIf(f.openSelected,true); ShowIf(f.returnSelected,true)
    else
        f.selectToggle.RUIText:SetText("Select")
        ShowIf(f.collectGold,true); ShowIf(f.openAll,true); ShowIf(f.openSelected,false); ShowIf(f.returnSelected,false)
    end
    SetMailButtonEnabled(f.selectToggle,not busy)
    SetMailButtonEnabled(f.collectGold,not busy)
    SetMailButtonEnabled(f.openAll,not busy)
    local hasSelection=false
    for _,v in pairs(f.mailSelection or {}) do if v then hasSelection=true; break end end
    SetMailButtonEnabled(f.openSelected,not busy and hasSelection)
    SetMailButtonEnabled(f.returnSelected,not busy and hasSelection)
end

function PhaseB:ToggleMailSelectionMode()
    local f=self.frames and self.frames.mail; if not f or f.mailBusy then return end
    f.selectionMode=not f.selectionMode
    f.lastMailCheck=nil
    if not f.selectionMode then f.mailSelection={} end
    self:RefreshMailInbox(); self:RefreshMailToolbar()
end

function PhaseB:ToggleMailSelection(index,checked)
    local f=self.frames and self.frames.mail; if not f or not f.selectionMode or f.mailBusy then return end
    index=tonumber(index); if not index then return end
    checked=checked and true or false
    if IsShiftKeyDown and IsShiftKeyDown() and f.lastMailCheck then
        local first=math.min(f.lastMailCheck,index); local last=math.max(f.lastMailCheck,index)
        for i=first,last do f.mailSelection[i]=checked or nil end
    elseif IsControlKeyDown and IsControlKeyDown() then
        local sender=select(3,GetInboxHeaderInfo(index))
        if sender then
            local num=GetInboxNumItems and GetInboxNumItems() or 0
            for i=1,num do if select(3,GetInboxHeaderInfo(i))==sender then f.mailSelection[i]=checked or nil end end
        end
    else
        f.mailSelection[index]=checked or nil
    end
    if checked then f.lastMailCheck=index elseif f.lastMailCheck==index then f.lastMailCheck=nil end
    self:RefreshMailInbox(); self:RefreshMailToolbar()
end

function PhaseB:StartSelectedMailBatch(mode)
    local f=self.frames and self.frames.mail; if not f then return end
    local targets={}; local count=0
    for index,selected in pairs(f.mailSelection or {}) do if selected then targets[index]=true; count=count+1 end end
    if count==0 then RUI:Print("Select at least one inbox message first."); return end
    self:StartMailBatch(mode,targets,mode=="return" and "Return Selected" or "Open Selected")
end

local function CountRegularBagFreeSlots()
    local total=0
    local maxBag=tonumber(NUM_BAG_SLOTS) or 4
    if not GetContainerNumFreeSlots then return nil end
    for bag=0,maxBag do
        local free,family=GetContainerNumFreeSlots(bag)
        if (tonumber(family) or 0)==0 then total=total+(tonumber(free) or 0) end
    end
    return total
end

function PhaseB:ScheduleMailBatch(delay)
    local f=self.frames and self.frames.mail; if not f or not f.batchDriver or not f.batch then return end
    f.batchDriver.delay=tonumber(delay) or .30
    f.batchDriver:Show()
end

function PhaseB:StartMailBatch(mode,targets,label)
    local f=self.frames and self.frames.mail
    if not f or not f:IsShown() or f.mode~="inbox" or f.mailBusy then return end
    local num=GetInboxNumItems and GetInboxNumItems() or 0
    if num<=0 then return end
    local copy=nil
    if type(targets)=="table" then copy={}; for index,value in pairs(targets) do if value then copy[tonumber(index) or index]=true end end end
    f.batch={
        mode=(mode=="return") and "return" or ((mode=="gold") and "gold" or "open"), targets=copy, label=label or "Mail batch",
        current=num, attach=tonumber(ATTACHMENTS_MAX_RECEIVE) or 16, wait=nil, stalls=0, headerStalls=0, attachmentStalls=0,
        skippedCOD=0, skippedGM=0, skippedReturn=0, failedActions=0, itemsBlocked=false, actions=0, waitRetries={},
    }
    f.mailBusy=true
    if f.collectGold then f.collectGold.RUIText:SetText(f.batch.mode=="gold" and "Collecting..." or "Collect Gold") end
    self:RefreshMailToolbar(); self:ScheduleMailBatch(.01)
end

function PhaseB:FinishMailBatch(cancelled)
    local f=self.frames and self.frames.mail; if not f then return end
    local batch=f.batch
    if f.batchDriver then f.batchDriver:Hide() end
    f.batch=nil; f.mailBusy=false
    if f.collectGold then f.collectGold.RUIText:SetText("Collect Gold") end
    if batch and batch.targets then f.mailSelection={}; f.selectionMode=false; f.lastMailCheck=nil end
    if not cancelled and batch then
        local notes={}
        if (batch.skippedCOD or 0)>0 then table.insert(notes,tostring(batch.skippedCOD).." C.O.D. skipped") end
        if (batch.skippedGM or 0)>0 then table.insert(notes,tostring(batch.skippedGM).." GM/system skipped") end
        if (batch.skippedReturn or 0)>0 then table.insert(notes,tostring(batch.skippedReturn).." could not be returned") end
        if batch.itemsBlocked then table.insert(notes,"item collection stopped to preserve bag space") end
        if (batch.failedActions or 0)>0 then table.insert(notes,tostring(batch.failedActions).." action(s) could not be confirmed") end
        if #notes>0 then RUI:Print((batch.label or "Mail batch").." finished: "..table.concat(notes,", ")..".") end
    end
    if CheckInbox and f:IsShown() and MailFrame and MailFrame:IsShown() then pcall(CheckInbox) end
    if f:IsShown() then self:RefreshMailInbox(); self:RefreshMailToolbar() end
end

local function MailHeaderSignature(index)
    local package,stationery,sender,subject,money,cod,_,itemCount=GetInboxHeaderInfo(index)
    return table.concat({
        tostring(package or ""), tostring(stationery or ""), tostring(sender or ""), tostring(subject or ""),
        tostring(tonumber(money) or 0), tostring(tonumber(cod) or 0), tostring(itemCount and 1 or 0),
    }, "\031")
end

function PhaseB:AdvanceMailBatch()
    local f=self.frames and self.frames.mail; local batch=f and f.batch
    if not f or not batch or not f:IsShown() then return end
    local num=GetInboxNumItems and GetInboxNumItems() or 0

    if batch.wait then
        local w=batch.wait; local confirmed=false
        if w.kind=="money" then
            local playerMoney=GetMoney and GetMoney() or 0
            local currentMoney=0
            if w.index<=num then currentMoney=tonumber(select(5,GetInboxHeaderInfo(w.index))) or 0 end
            confirmed=(playerMoney>(w.playerMoney or playerMoney)) or w.index>num or currentMoney<(w.amount or currentMoney)
        elseif w.kind=="item" then
            if w.link and GetItemCount then
                local ok,count=pcall(GetItemCount,w.link)
                if ok and tonumber(count) and tonumber(count)>(w.itemCount or 0) then confirmed=true end
            end
            if not confirmed then
                if w.index>num then confirmed=true else
                    local currentLink=GetInboxItemLink and GetInboxItemLink(w.index,w.attach) or nil
                    local currentName=GetInboxItem and select(1,GetInboxItem(w.index,w.attach)) or nil
                    if w.link then confirmed=(currentLink~=w.link) elseif w.name then confirmed=(currentName~=w.name) else confirmed=(currentName==nil) end
                end
            end
        elseif w.kind=="return" then
            confirmed=num<(w.numItems or num)
            if not confirmed and w.index<=num then confirmed=MailHeaderSignature(w.index)~=w.signature end
        end
        local retryKey=tostring(w.kind)..":"..tostring(w.index)..":"..tostring(w.attach or 0)
        if confirmed then
            batch.wait=nil; batch.stalls=0; batch.headerStalls=0; batch.attach=tonumber(ATTACHMENTS_MAX_RECEIVE) or 16
            if batch.waitRetries then batch.waitRetries[retryKey]=nil end
            if w.kind=="return" then batch.current=w.index-1 else batch.current=math.min(w.index,num) end
        else
            batch.stalls=(batch.stalls or 0)+1
            if batch.stalls>=5 then
                batch.stalls=0; batch.wait=nil; batch.waitRetries=batch.waitRetries or {}
                batch.waitRetries[retryKey]=(batch.waitRetries[retryKey] or 0)+1
                if batch.waitRetries[retryKey]>=3 then
                    batch.failedActions=(batch.failedActions or 0)+1
                    if w.kind=="item" then
                        -- Skip only the stubborn attachment and continue the same mail.
                        batch.attach=math.max(0,(tonumber(w.attach) or 1)-1)
                    else
                        -- Money/return could not be confirmed after bounded retries;
                        -- move on rather than leaving a permanent OnUpdate loop.
                        if batch.targets then batch.targets[w.index]=nil end
                        batch.current=w.index-1; batch.attach=tonumber(ATTACHMENTS_MAX_RECEIVE) or 16
                    end
                elseif CheckInbox then pcall(CheckInbox) end
            end
            self:ScheduleMailBatch(.30); return
        end
    end

    num=GetInboxNumItems and GetInboxNumItems() or 0
    if batch.current>num then batch.current=num end
    local index=batch.current
    while index>0 and batch.targets and not batch.targets[index] do index=index-1 end
    batch.current=index
    if index<=0 then self:FinishMailBatch(false); return end

    local package,stationery,sender,subject,money,cod,days,itemCount,wasRead,wasReturned,textCreated,canReply,isGM=GetInboxHeaderInfo(index)
    if money==nil then
        batch.headerStalls=(batch.headerStalls or 0)+1
        if batch.headerStalls>=20 then
            if batch.targets then batch.targets[index]=nil end
            batch.current=index-1; batch.headerStalls=0
        end
        self:ScheduleMailBatch(.30); return
    end
    batch.headerStalls=0; money=tonumber(money) or 0; cod=tonumber(cod) or 0

    if batch.mode=="return" then
        if not wasReturned and canReply and not isGM and ReturnInboxItem then
            batch.wait={kind="return",index=index,numItems=num,signature=MailHeaderSignature(index)}
            ReturnInboxItem(index); batch.actions=batch.actions+1; self:ScheduleMailBatch(.35); return
        end
        batch.skippedReturn=(batch.skippedReturn or 0)+1
        if batch.targets then batch.targets[index]=nil end
        batch.current=index-1; self:ScheduleMailBatch(.05); return
    end

    if batch.mode=="gold" then
        if cod>0 then
            batch.skippedCOD=(batch.skippedCOD or 0)+1
            batch.current=index-1; self:ScheduleMailBatch(.05); return
        end
        if money>0 and TakeInboxMoney then
            batch.wait={kind="money",index=index,playerMoney=GetMoney and GetMoney() or 0,amount=money}
            TakeInboxMoney(index); batch.actions=batch.actions+1; self:ScheduleMailBatch(.35); return
        end
        batch.current=index-1; self:ScheduleMailBatch(.05); return
    end

    -- Batch opening never auto-pays C.O.D. or operates on GM/system mail.
    if cod>0 then
        batch.skippedCOD=(batch.skippedCOD or 0)+1
        if batch.targets then batch.targets[index]=nil end
        batch.current=index-1; batch.attach=tonumber(ATTACHMENTS_MAX_RECEIVE) or 16; self:ScheduleMailBatch(.05); return
    end
    if isGM then
        batch.skippedGM=(batch.skippedGM or 0)+1
        if batch.targets then batch.targets[index]=nil end
        batch.current=index-1; batch.attach=tonumber(ATTACHMENTS_MAX_RECEIVE) or 16; self:ScheduleMailBatch(.05); return
    end

    local attach=math.min(batch.attach or (tonumber(ATTACHMENTS_MAX_RECEIVE) or 16),tonumber(ATTACHMENTS_MAX_RECEIVE) or 16)
    local attachmentName,attachmentLink
    while attach>0 do
        attachmentName=GetInboxItem and select(1,GetInboxItem(index,attach)) or nil
        attachmentLink=GetInboxItemLink and GetInboxItemLink(index,attach) or nil
        if attachmentName or attachmentLink then break end
        attach=attach-1
    end
    batch.attach=attach
    -- Some Ebonhold mail providers populate the header before attachment rows.
    -- If the header promises items but no attachment API row is coherent yet,
    -- wait briefly instead of silently skipping the message.
    if attach<=0 and itemCount and not batch.itemsBlocked then
        batch.attachmentStalls=(batch.attachmentStalls or 0)+1
        if batch.attachmentStalls<=6 then
            if CheckInbox then pcall(CheckInbox) end
            self:ScheduleMailBatch(.20); return
        end
    else
        batch.attachmentStalls=0
    end

    if attach>0 and not batch.itemsBlocked then
        local keep=math.max(0,tonumber(MailProfileSettings().keepFreeSlots) or 1)
        local free=CountRegularBagFreeSlots()
        if keep>0 and free~=nil and free<=keep then batch.itemsBlocked=true end
    end
    if attach>0 and not batch.itemsBlocked and TakeInboxItem then
        local before=0
        if attachmentLink and GetItemCount then local ok,count=pcall(GetItemCount,attachmentLink); if ok then before=tonumber(count) or 0 end end
        batch.wait={kind="item",index=index,attach=attach,link=attachmentLink,name=attachmentName,itemCount=before}
        TakeInboxItem(index,attach); batch.actions=batch.actions+1; self:ScheduleMailBatch(.35); return
    end

    if money>0 and TakeInboxMoney then
        batch.wait={kind="money",index=index,playerMoney=GetMoney and GetMoney() or 0,amount=money}
        TakeInboxMoney(index); batch.actions=batch.actions+1; self:ScheduleMailBatch(.35); return
    end

    if batch.targets then batch.targets[index]=nil end
    batch.current=index-1; batch.attach=tonumber(ATTACHMENTS_MAX_RECEIVE) or 16
    self:ScheduleMailBatch(.05)
end

function PhaseB:HandleMailBatchError(message)
    local f=self.frames and self.frames.mail; local batch=f and f.batch
    if not batch then return false end
    message=tostring(message or "")
    if (ERR_INV_FULL and message==ERR_INV_FULL) or string.find(string.lower(message),"inventory is full",1,true) then
        batch.itemsBlocked=true; batch.wait=nil; batch.attach=0; self:ScheduleMailBatch(.20); return true
    end
    if (ERR_ITEM_MAX_COUNT and message==ERR_ITEM_MAX_COUNT) then
        local attach=(batch.wait and batch.wait.attach) or batch.attach or 1
        batch.wait=nil; batch.attach=math.max(0,attach-1); self:ScheduleMailBatch(.20); return true
    end
    return false
end

function PhaseB:RefreshMailInbox()
    local f=self.frames.mail; if not f then return end
    local num=GetInboxNumItems and GetInboxNumItems() or 0
    f.offset=math.min(f.offset or 0,math.max(0,num-12))
    if f.selected and f.selected>num then f.selected=nil end
    for index in pairs(f.mailSelection or {}) do if tonumber(index) and tonumber(index)>num then f.mailSelection[index]=nil end end

    for i,r in ipairs(f.mailRows) do
        local idx=f.offset+i
        if idx<=num then
            local package,stationery,sender,subject,money,cod,days,count,read,wasReturned,textCreated,canReply,isGM=GetInboxHeaderInfo(idx)
            money=tonumber(money) or 0; cod=tonumber(cod) or 0
            r:Show(); r.index=idx
            r.sender:ClearAllPoints(); r.subject:ClearAllPoints()
            local textX=f.selectionMode and 31 or 8
            r.sender:SetPoint("TOPLEFT",r,"TOPLEFT",textX,-5); r.subject:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",textX,5)
            r.sender:SetWidth(f.selectionMode and 230 or 255); r.subject:SetWidth(f.selectionMode and 230 or 255)
            r.sender:SetText((read and "" or "• ")..(sender or "Unknown"))
            local subjectText=subject or "(No subject)"
            if cod>0 then subjectText=subjectText.."  |cffffcc00[C.O.D.]|r"
            elseif money>0 then subjectText=subjectText.."  |cff66ff66[Money]|r" end
            if isGM then subjectText=subjectText.."  |cff9ecbff[System]|r" end
            r.subject:SetText(subjectText)
            if f.selectionMode then
                r.select:Show(); r.select:SetChecked(f.mailSelection[idx] and true or false)
                if f.mailBusy then if r.select.Disable then r.select:Disable() end; r.select:SetAlpha(.45)
                else if r.select.Enable then r.select:Enable() end; r.select:SetAlpha(1) end
                if f.mailSelection[idx] then r.select.mark:Show() else r.select.mark:Hide() end
            else r.select:Hide(); r.select.mark:Hide() end
            r:SetScript("OnClick",function(self)
                if f.mailBusy then return end
                if not f.selectionMode and IsShiftKeyDown and IsShiftKeyDown() then
                    PhaseB:StartMailBatch("open",{[self.index]=true},"Quick Collect"); return
                end
                if not f.selectionMode and IsControlKeyDown and IsControlKeyDown() then
                    PhaseB:StartMailBatch("return",{[self.index]=true},"Quick Return"); return
                end
                f.selected=self.index; PhaseB:RefreshMailInbox()
            end)
        else
            r.index=nil; r:Hide(); r.select:Hide()
        end
    end

    if f.selected and f.selected<=num then
        local body=GetInboxText and GetInboxText(f.selected) or ""
        local _,_,sender,subject,money,cod,days,hasItem,read,wasReturned,textCreated,canReply,isGM=GetInboxHeaderInfo(f.selected)
        money=tonumber(money) or 0; cod=tonumber(cod) or 0
        f.mailFrom:SetText("From: "..tostring(sender or "Unknown").."   •   "..string.format("%.1f days",tonumber(days) or 0)); f.mailSubject:SetText(subject or "(No subject)"); f.mailBody:SetText(body or "")
        if money>0 then f.mailTransaction:SetText("Enclosed money: "..Money(money)); f.takeMoney.RUIText:SetText("Take "..Money(money)); f.takeMoney:Show()
        elseif cod>0 then f.mailTransaction:SetText("|cffffcc00C.O.D. due:|r "..Money(cod).."   •   Click an attached item to pay and collect it."); f.takeMoney:Hide()
        else f.mailTransaction:SetText(""); f.takeMoney:Hide() end
        local shown=0
        for i,b in ipairs(f.attachments) do
            local name,tex,cnt=GetInboxItem(f.selected,i)
            if name then b:Show(); b.icon:SetTexture(tex); SetItemSlotCount(b,(tonumber(cnt) or 1)>1 and tostring(cnt) or ""); shown=shown+1 else b:Hide() end
        end
        if money<=0 and cod<=0 and shown>0 then f.mailTransaction:SetText(tostring(shown).." attached item"..(shown==1 and "" or "s")) end
        ShowIf(f.mailAttachLabel,shown>0)

        local canDelete=InboxItemCanDelete and InboxItemCanDelete(f.selected)
        if canDelete then
            f.mailAction="delete"; f.del.RUIText:SetText("Delete"); SetMailButtonEnabled(f.del,not f.mailBusy)
        elseif not wasReturned and canReply and not isGM then
            f.mailAction="return"; f.del.RUIText:SetText("Return to Sender"); SetMailButtonEnabled(f.del,not f.mailBusy)
        else
            f.mailAction=nil; f.del.RUIText:SetText("No Action"); SetMailButtonEnabled(f.del,false)
        end
        SetMailButtonEnabled(f.reply,canReply and not f.mailBusy)
        SetMailButtonEnabled(f.takeMoney,money>0 and not f.mailBusy)
    else
        f.mailAction=nil
        f.mailFrom:SetText(""); f.mailSubject:SetText("Select a message"); f.mailBody:SetText(""); f.mailTransaction:SetText(""); f.takeMoney:Hide(); f.mailAttachLabel:Hide(); for _,b in ipairs(f.attachments) do b:Hide() end
        f.del.RUIText:SetText("Delete / Return"); SetMailButtonEnabled(f.del,false); SetMailButtonEnabled(f.reply,false)
    end
    self:RefreshMailToolbar()
end
function PhaseB:RefreshSendMail()
    local f=self.frames.mail; if not f then return end
    local itemCount=0; local firstName=nil
    for i,b in ipairs(f.sendAttachments) do
        local name,tex,cnt,quality=GetSendMailItem and GetSendMailItem(i)
        if name then
            itemCount=itemCount+1; firstName=firstName or name
            local displayTexture=ResolveItemTexture(tex,name) or ResolveItemTexture(name,name)
            if not displayTexture and type(tex)=="string" and tex~="" then displayTexture=tex end
            -- Last fallback: mirror Blizzard's hidden native send slot. This is
            -- especially useful on custom cores that feed their own texture
            -- representation to the stock button but not to plain textures.
            if not displayTexture then
                local native=_G["SendMailAttachment"..tostring(i)]
                local normal=native and native.GetNormalTexture and native:GetNormalTexture()
                displayTexture=normal and normal.GetTexture and normal:GetTexture() or nil
            end
            b.icon:SetTexture(displayTexture or ""); b.icon:SetAlpha(1); b.icon:Show(); SetItemSlotCount(b,(tonumber(cnt) or 1)>1 and tostring(cnt) or "")
            if quality and GetItemQualityColor then local r,g,bl=GetItemQualityColor(quality); RUI:SetBorderColor(b,r,g,bl,1) else RUI:RefreshBackdrop(b) end
        else b.icon:SetTexture(""); b.icon:Show(); SetItemSlotCount(b,""); RUI:RefreshBackdrop(b) end
    end
    self:UpdateAutomaticMailSubject(firstName)
    if itemCount==0 and f.cod:GetChecked() then f.cod:SetRUIValue(false) end
    local g=tonumber(f.gold:GetText()) or 0; local si=tonumber(f.silver:GetText()) or 0; local c=tonumber(f.copper:GetText()) or 0; local copper=g*10000+si*100+c
    if copper>0 then f.paymentSummary:SetText((f.cod:GetChecked() and "C.O.D.: " or "Sending: ")..Money(copper)) else f.paymentSummary:SetText("No money attached") end
    local postage=GetSendMailPrice and tonumber(GetSendMailPrice()) or 0
    local itemText=itemCount==0 and "No items attached" or (tostring(itemCount).." item"..(itemCount==1 and "" or "s").." attached")
    if firstName and itemCount==1 then itemText=itemText..": "..firstName end
    f.sendSummary:SetText(itemText..(postage>0 and ("   •   Postage: "..Money(postage)) or ""))
end
function PhaseB:RefreshMail()
    local f=self.frames.mail; if not f then return end
    if SetSendMailShowing then SetSendMailShowing(f.mode=="send") end
    ShowIf(f.inbox,f.mode=="inbox"); ShowIf(f.send,f.mode=="send")
    local ar,ag,ab=RUI:GetAccentColor()
    if f.mode=="inbox" then RUI:SetBorderColor(f.inboxTab,ar,ag,ab,1); RUI:RefreshBackdrop(f.sendTab); self:RefreshMailInbox()
    else RUI:RefreshBackdrop(f.inboxTab); RUI:SetBorderColor(f.sendTab,ar,ag,ab,1); self:RefreshSendMail(); self:RefreshMailToolbar() end
end
function PhaseB:ReplyMail()
    local f=self.frames.mail; if not f or not f.selected or f.mailBusy then return end; local _,_,sender,subject=GetInboxHeaderInfo(f.selected); f.to:SetText(sender or ""); local prefix="Re: "; subject=subject or ""; if string.sub(subject,1,4)~="Re: " then subject=prefix..subject end; f.subject:SetText(subject); self:SetMailMode("send"); f.bodyEdit:SetFocus()
end
function PhaseB:DeleteMail()
    local f=self.frames.mail; if not f or not f.selected or f.mailBusy then return end
    if f.mailAction=="delete" and DeleteInboxItem then DeleteInboxItem(f.selected)
    elseif f.mailAction=="return" and ReturnInboxItem then ReturnInboxItem(f.selected)
    else return end
    f.selected=nil; self:RefreshMailInbox()
end
function PhaseB:SendMailNow()
    local f=self.frames.mail; local name=f.to:GetText() or ""; if name=="" then RUI:Print("Enter a recipient before sending mail."); return end
    local g=tonumber(f.gold:GetText()) or 0; local s=tonumber(f.silver:GetText()) or 0; local c=tonumber(f.copper:GetText()) or 0; local copper=g*10000+s*100+c
    local itemCount=0; for i=1,12 do if GetSendMailItem and GetSendMailItem(i) then itemCount=itemCount+1 end end
    if f.cod:GetChecked() and itemCount==0 then RUI:Print("C.O.D. requires at least one attached item."); return end
    if SetSendMailMoney then SetSendMailMoney(f.cod:GetChecked() and 0 or copper) end
    if SetSendMailCOD then SetSendMailCOD(f.cod:GetChecked() and copper or 0) end
    f.pendingRecipient=TrimMailName(name)
    if SendMail then SendMail(name,f.subject:GetText() or "",f.bodyEdit:GetText() or "") end
end

-- -------------------------------------------------------------------------
-- Merchant
-- -------------------------------------------------------------------------
function PhaseB:CreateMerchant()
    local f=Panel("ZenUIMerchantFrame","merchant","Merchant"); self.frames.merchant=f; f.mode="buy"; f.page=1; f.previewMode=true; f.selectedIndex=nil
    f.buyTab=Button(f.body,"Buy",92,26); f.buyTab:SetPoint("TOPLEFT",2,-2)
    f.backTab=Button(f.body,"Buyback",92,26); f.backTab:SetPoint("LEFT",f.buyTab,"RIGHT",8,0)
    f.vendor=Text(f.body,"",10,"TOPRIGHT",f.body,"TOPRIGHT",-10,-10,true); f.vendor:SetJustifyH("RIGHT")
    f.buyTab:SetScript("OnClick",function() f.mode="buy"; f.page=1; f.selectedIndex=nil; PhaseB:RefreshMerchant() end); f.backTab:SetScript("OnClick",function() f.mode="buyback"; f.page=1; f.selectedIndex=nil; PhaseB:RefreshMerchant() end)

    f.itemHeader=Text(f.body,"ITEM",9,"TOPLEFT",f.body,"TOPLEFT",10,-38,true)
    f.priceHeader=Text(f.body,"COST",9,"TOPRIGHT",f.body,"TOPRIGHT",-12,-38,true); f.priceHeader:SetJustifyH("RIGHT")

    local function MerchantWheel(_,delta)
        if delta and delta>0 then f.page=math.max(1,(f.page or 1)-1) else f.page=(f.page or 1)+1 end
        PhaseB:RefreshMerchant()
    end
    f:EnableMouseWheel(true); f:SetScript("OnMouseWheel",MerchantWheel); f.body:EnableMouseWheel(true); f.body:SetScript("OnMouseWheel",MerchantWheel)

    f.rows={}
    for i=1,7 do
        local r=Row(f.body,514,38); r:SetPoint("TOPLEFT",f.body,"TOPLEFT",2,-52-((i-1)*40))
        r.icon=ItemSlot(r,34); r.icon:SetPoint("LEFT",r,"LEFT",4,0)
        r.name=Text(r,"",13,"LEFT",r.icon,"RIGHT",9,7,false); r.name:SetWidth(270); r.name:SetJustifyH("LEFT")
        r.stock=Text(r,"",10,"LEFT",r.icon,"RIGHT",9,-9,true); r.stock:SetWidth(270); r.stock:SetJustifyH("LEFT")
        r.price=Text(r,"",11,"RIGHT",r,"RIGHT",-10,0,false); r.price:SetWidth(180); r.price:SetJustifyH("RIGHT")
        local function MerchantItemAction(self,button)
            local row=self.RUIMerchantRow or self
            if not row.index then return end
            local link
            if f.mode=="buy" then link=GetMerchantItemLink and GetMerchantItemLink(row.index) end
            if link and RUI.HandleModifiedLinkClick and RUI:HandleModifiedLinkClick(link, button) then return end

            -- Match the stock Wrath merchant behavior: when the SPLITSTACK
            -- modifier (Shift by default) is held and the item-link modified
            -- click above did not consume the click, open the native quantity
            -- selector instead of purchasing immediately.  Keep StackSplitFrame
            -- native so high-level keyboard/amount handling stays compatible
            -- with Ebonhold; D3 skins that frame into Zen styling.
            if f.mode=="buy" and IsModifiedClick and IsModifiedClick("SPLITSTACK") then
                local maxStack=GetMerchantItemMaxStack and tonumber(GetMerchantItemMaxStack(row.index)) or 1
                local itemName,texture,price,stackCount,available,_,extendedCost=GetMerchantItemInfo(row.index)
                maxStack=math.max(1,maxStack or 1)
                stackCount=math.max(1,tonumber(stackCount) or 1)
                price=tonumber(price) or 0

                local maxPurchasable=MerchantMaxAffordable(row.index,maxStack,price,extendedCost)
                available=tonumber(available)
                if available and available>=0 then maxPurchasable=math.min(maxPurchasable,available) end

                if maxPurchasable>1 and OpenStackSplitFrame then
                    local owner=row.icon
                    owner:SetID(row.index)
                    owner.extendedCost=extendedCost and true or nil
                    owner.count=stackCount
                    owner.link=link
                    owner.texture=texture
                    owner.name=itemName
                    owner.SplitStack=function(splitButton,split)
                        split=math.floor(tonumber(split) or 0)
                        if split<=0 then return end
                        if splitButton.extendedCost and MerchantFrame_ConfirmExtendedItemCost then
                            MerchantFrame_ConfirmExtendedItemCost(splitButton,split)
                        elseif BuyMerchantItem then
                            BuyMerchantItem(splitButton:GetID(),split)
                        end
                    end
                    -- Close the item tooltip before opening the quantity chooser;
                    -- both legitimately use the top UI layer and the tooltip should
                    -- never sit over the amount controls.
                    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
                    OpenStackSplitFrame(maxPurchasable,owner,"BOTTOMLEFT","TOPLEFT")
                    local split=_G.StackSplitFrame
                    if split then
                        local escape=RUI:GetModule("BlizzardEscapeSkins", true)
                        if escape and escape.StyleStackSplit then escape:StyleStackSplit() end

                        -- Anchor the selector beside the Merchant rather than inside
                        -- the item row.  This makes the relationship obvious and also
                        -- avoids any private-server hit-test quirks over the row list.
                        if split.ClearAllPoints and split.SetPoint then
                            split:ClearAllPoints()
                            split:SetPoint("TOPLEFT",f,"TOPRIGHT",8,-70)
                        end
                        if split.SetFrameStrata then split:SetFrameStrata("TOOLTIP") end
                        if split.SetFrameLevel then split:SetFrameLevel(1000) end
                        if split.SetToplevel then split:SetToplevel(true) end
                        if split.EnableMouse then split:EnableMouse(true) end
                        if split.Raise then split:Raise() end
                    end
                end
                return
            end

            if button=="RightButton" then
                -- Purchasing is deliberately right-click only.  Left click is
                -- selection/preview so an ordinary inspection can never spend gold.
                if f.mode=="buy" then
                    local _,texture,price,stackCount,_,_,extendedCost=GetMerchantItemInfo(row.index)
                    if extendedCost and MerchantFrame_ConfirmExtendedItemCost then
                        local owner=row.icon
                        owner:SetID(row.index)
                        owner.extendedCost=true
                        owner.price=tonumber(price) or 0
                        owner.count=tonumber(stackCount) or 1
                        owner.link=GetMerchantItemLink and GetMerchantItemLink(row.index)
                        owner.texture=texture
                        MerchantFrame_ConfirmExtendedItemCost(owner,1)
                    elseif BuyMerchantItem then
                        BuyMerchantItem(row.index,1)
                    end
                else
                    if BuybackItem then BuybackItem(row.index) end
                end
                return
            end

            -- Left click only selects the row.  When View on Character is enabled
            -- (the default), selection also previews wearable items.
            f.selectedIndex=row.index
            if f.mode=="buy" and f.previewMode and link and DressUpItemLink then
                DressUpItemLink(link)
            end
            PhaseB:RefreshMerchant()
        end
        r:RegisterForClicks("LeftButtonUp","RightButtonUp")
        r:SetScript("OnClick",MerchantItemAction)
        r.icon.RUIMerchantRow=r
        r.icon:SetScript("OnClick",MerchantItemAction)
        r:SetScript("OnEnter",function(self) if self.index then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); if f.mode=="buy" and GameTooltip.SetMerchantItem then GameTooltip:SetMerchantItem(self.index) elseif f.mode=="buyback" and GameTooltip.SetBuybackItem then GameTooltip:SetBuybackItem(self.index) end end end)
        r:SetScript("OnLeave",function() GameTooltip:Hide() end)
        r.icon:SetScript("OnEnter",function(self) local row=self.RUIMerchantRow; if row and row.index then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); if f.mode=="buy" and GameTooltip.SetMerchantItem then GameTooltip:SetMerchantItem(row.index) elseif f.mode=="buyback" and GameTooltip.SetBuybackItem then GameTooltip:SetBuybackItem(row.index) end end end)
        r.icon:SetScript("OnLeave",function() GameTooltip:Hide() end)
        r:EnableMouseWheel(true); r:SetScript("OnMouseWheel",MerchantWheel); r.icon:EnableMouseWheel(true); r.icon:SetScript("OnMouseWheel",MerchantWheel)
        f.rows[i]=r
    end
    -- Keep help text on its own line above the controls.  The old single-row
    -- footer allowed the hint, page label and buttons to occupy the same space
    -- at narrower Merchant scales.
    f.wheelHint=Text(f.body,"Left click selects   •   Right click buys   •   Shift-click quantity   •   Mouse wheel pages",9,"BOTTOMLEFT",f.body,"BOTTOMLEFT",4,34,true)
    f.wheelHint:SetWidth(510); f.wheelHint:SetJustifyH("LEFT")

    f.prev=Button(f.body,"<",36,26); f.prev:SetPoint("BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-46,2)
    f.next=Button(f.body,">",36,26); f.next:SetPoint("LEFT",f.prev,"RIGHT",6,0)
    f.pageText=Text(f.body,"",10,"RIGHT",f.prev,"LEFT",-10,0,true); f.pageText:SetWidth(90); f.pageText:SetJustifyH("RIGHT")
    f.prev:SetScript("OnClick",function() f.page=math.max(1,f.page-1); PhaseB:RefreshMerchant() end); f.next:SetScript("OnClick",function() f.page=f.page+1; PhaseB:RefreshMerchant() end)
    f.repair=Button(f.body,"Repair All",104,26); f.repair:SetPoint("BOTTOMLEFT",f.body,"BOTTOMLEFT",2,2); f.repair:SetScript("OnClick",function() if RepairAllItems then RepairAllItems() end end)
    f.preview=Button(f.body,"View on Character",142,26); f.preview:SetPoint("LEFT",f.repair,"RIGHT",8,0)
    f.preview:SetScript("OnClick",function()
        if f.mode~="buy" then return end
        f.previewMode=not f.previewMode
        PhaseB:RefreshMerchant()
    end)
    f.preview:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText("View on Character",1,1,1)
        if f.previewMode then
            GameTooltip:AddLine("Enabled by default: left-click selection also previews the item on your character.",.75,.75,.75,true)
        else
            GameTooltip:AddLine("Disabled: left click only selects. Right click is always required to buy.",.75,.75,.75,true)
        end
        GameTooltip:Show()
    end)
    f.preview:SetScript("OnLeave",function() GameTooltip:Hide() end)
    f.close:SetScript("OnClick",function() if CloseMerchant then CloseMerchant() else f:Hide() end end)
    return f
end
function PhaseB:RefreshMerchant()
    local f=self.frames.merchant; if not f then return end; f.vendor:SetText(UnitName("NPC") or "Vendor"); local total=f.mode=="buy" and (GetMerchantNumItems and GetMerchantNumItems() or 0) or (GetNumBuybackItems and GetNumBuybackItems() or 0); local per=7; local pages=math.max(1,math.ceil(total/per)); if f.page>pages then f.page=pages end; f.pageText:SetText("Page "..f.page.." / "..pages); local ar,ag,ab=RUI:GetAccentColor(); if f.mode=="buy" then RUI:SetBorderColor(f.buyTab,ar,ag,ab,1); RUI:RefreshBackdrop(f.backTab) else RUI:RefreshBackdrop(f.buyTab); RUI:SetBorderColor(f.backTab,ar,ag,ab,1) end
    if f.preview then
        if f.mode=="buy" then
            f.preview:Enable(); f.preview:SetAlpha(1)
            if f.previewMode then RUI:SetBorderColor(f.preview,ar,ag,ab,1) else RUI:RefreshBackdrop(f.preview) end
        else
            f.preview:Disable(); f.preview:SetAlpha(.4); RUI:RefreshBackdrop(f.preview)
        end
    end
    for i,r in ipairs(f.rows) do local idx=(f.page-1)*per+i; if idx<=total then local name,tex,price,qty,avail,usable,extended; if f.mode=="buy" then name,tex,price,qty,avail,usable,extended=GetMerchantItemInfo(idx) else name,tex,price,qty,avail,usable=GetBuybackItemInfo(idx) end; r:Show(); r.index=idx; r.icon.icon:SetTexture(tex or ""); SetItemSlotCount(r.icon,(qty or 1)>1 and tostring(qty) or ""); r.name:SetText(name or ""); if f.mode=="buy" and avail and tonumber(avail) and tonumber(avail)>=0 then r.stock:SetText("Available: "..tostring(avail)) else r.stock:SetText("") end; r.price:SetText(f.mode=="buy" and MerchantCostString(idx,price or 0,extended) or Money(price or 0)); RUI:RefreshBackdrop(r); if f.selectedIndex==idx then RUI:SetBorderColor(r,ar,ag,ab,1) end; else r:Hide(); r.index=nil end end
    local cost,canRepair=GetRepairAllCost and GetRepairAllCost(); if cost and cost>0 then f.repair.RUIText:SetText("Repair "..Money(cost)) else f.repair.RUIText:SetText("Repair All") end
end

-- -------------------------------------------------------------------------
-- Bank
-- -------------------------------------------------------------------------
local BANK_ID = BANK_CONTAINER or -1
local BANK_BAG_FIRST = (NUM_BAG_SLOTS or 4) + 1
local BANK_BAG_LAST = BANK_BAG_FIRST + (NUM_BANKBAGSLOTS or 7) - 1
local BANK_GRID_COLUMNS = 16
local BANK_GRID_ROWS = 12
local BANK_SLOT_SIZE = 38
local BANK_SLOT_PITCH = 40
local BANK_GRID_CAPACITY = BANK_GRID_COLUMNS * BANK_GRID_ROWS
local VOID_STORAGE_SLOTS_PER_TAB = tonumber(VOID_STORAGE_MAX) or 80
local VOID_STORAGE_TABS = 2

local BANK_FILTERS = {
    { key="bank", label="BNK", tooltip="Main bank", bag=BANK_ID },
    { key="bag1", label="1", tooltip="Bank Bag 1", bag=BANK_BAG_FIRST },
    { key="bag2", label="2", tooltip="Bank Bag 2", bag=BANK_BAG_FIRST+1 },
    { key="bag3", label="3", tooltip="Bank Bag 3", bag=BANK_BAG_FIRST+2 },
    { key="bag4", label="4", tooltip="Bank Bag 4", bag=BANK_BAG_FIRST+3 },
    { key="bag5", label="5", tooltip="Bank Bag 5", bag=BANK_BAG_FIRST+4 },
    { key="bag6", label="6", tooltip="Bank Bag 6", bag=BANK_BAG_FIRST+5 },
    { key="bag7", label="7", tooltip="Bank Bag 7", bag=BANK_BAG_FIRST+6 },
    { key="void", label="V", tooltip="Void Storage", void=true },
}

local function BankFilterSettings()
    local s=Settings()
    if not s then return {} end
    s.bankContainers=s.bankContainers or {}
    return s.bankContainers
end

local function BankFilterEnabled(key)
    local value=BankFilterSettings()[key]
    -- Void Storage is deliberately opt-in when the bank opens.  Normal bank
    -- containers remain visible by default, matching Zen Bags.
    if value==nil then return key~="void" end
    return value and true or false
end

local function BankAllFiltersEnabled()
    for _,def in ipairs(BANK_FILTERS) do
        if not BankFilterEnabled(def.key) then return false end
    end
    return true
end

local function SetAllBankFilters(enabled)
    local settings=BankFilterSettings()
    for _,def in ipairs(BANK_FILTERS) do settings[def.key]=enabled and true or false end
end

local function BlizzardVoidStorageSupported()
    return type(GetVoidItemInfo)=="function" and type(ClickVoidStorageSlot)=="function"
end

local function EbonholdExtBankSupported()
    return type(ExtBankOpen)=="function" and type(ExtBankMove)=="function"
end

-- Ebonhold's visible Void Storage UI is shipped with the client rather than in
-- the user's ordinary AddOns folder.  Its Lua parser can therefore be
-- LoadOnDemand even though the ExtBank transport functions already exist.  Load
-- that parser/UI before installing our ExtBank callback so Zen can chain the
-- native packet decoder instead of seeing only raw hex.
function PhaseB:LoadNativeVoidStorageSupport()
    -- Keep Void support deterministic.  Earlier builds scanned every loaded
    -- global/addon looking for a decoder, which can hitch the client and can
    -- encounter non-frame globals supplied by other addons.  Only try known
    -- load-on-demand modules, once per session.
    if self.nativeVoidLoadAttempted then return end
    self.nativeVoidLoadAttempted=true
    local store; if RUI.global then RUI.global.extBankDebug=RUI.global.extBankDebug or {}; store=RUI.global.extBankDebug end
    local candidates={"Blizzard_VoidStorageUI","Bagnon_VoidStorage","Ebonhold_VoidStorage","Ebonhold_ExtBank","ExtBank"}
    local results={}
    if LoadAddOn then
        for _,name in ipairs(candidates) do
            local ok,loadedOrReason,reason=pcall(LoadAddOn,name)
            results[name]=ok and (loadedOrReason or reason or true) or tostring(loadedOrReason)
        end
    end
    if store then store.nativeVoidLoad=results end
end

local function IsFrameLikeObject(value)
    -- DiscoverNativeVoidStorageButtons scans _G as a last-resort compatibility
    -- path.  _G also contains functions, strings, numbers, etc.; indexing one of
    -- those as if it were a Frame raises a hard Lua error during BANKFRAME_OPENED.
    local kind=type(value)
    if kind~="table" and kind~="userdata" then return false end
    local ok,method=pcall(function() return value.GetObjectType end)
    return ok and type(method)=="function"
end

local function NativeVoidButtonText(button)
    if not IsFrameLikeObject(button) then return nil end
    if button.GetText then
        local ok,text=pcall(button.GetText,button)
        if ok and type(text)=="string" and text~="" then return text end
    end
    local name=button.GetName and button:GetName()
    if name then
        local fs=_G[name.."Text"]
        if fs and fs.GetText then
            local ok,text=pcall(fs.GetText,fs)
            if ok and type(text)=="string" and text~="" then return text end
        end
    end
    return nil
end

function PhaseB:FindNativeVoidStorageLauncher()
    -- Known-name lookup only. Never walk _G here: Ebonhold and many addons
    -- expose functions whose names contain "bank"/"void", and treating those
    -- as frames caused the /reload crash reported in 0.8.53.
    local f=self.frames and self.frames.bank
    local known={
        "BankFrameVoidStorageButton","BankFrameVoidStorage","VoidStorageButton","VoidStorageOpenButton",
        "VoidStorageFrameOpenButton","BankFrameExtBankButton","ExtBankButton","ExtBankOpenButton"
    }
    local best,bestName,bestText=nil,nil,nil
    for _,name in ipairs(known) do
        local button=_G[name]
        if IsFrameLikeObject(button) then
            local ok,obj=pcall(button.GetObjectType,button)
            if ok and obj=="Button" then
                best=button; bestName=name; bestText=NativeVoidButtonText(button); break
            end
        end
    end
    if f then f.nativeVoidLauncher=best end
    local store; if RUI.global then RUI.global.extBankDebug=RUI.global.extBankDebug or {}; store=RUI.global.extBankDebug end
    if store then
        store.nativeVoidLauncherName=bestName
        store.nativeVoidLauncherText=bestText
    end
    return best
end

function PhaseB:InvokeNativeVoidStorageLauncher()
    -- Lightweight compatibility path only.  The V filter must never perform a
    -- full global scan or repeated discovery pass.  If Ebonhold exposes one of
    -- the known launcher buttons, invoke it once; otherwise simply let ExtBank
    -- provide its server packet and keep the Zen bank responsive.
    self:LoadNativeVoidStorageSupport()
    local button=self:FindNativeVoidStorageLauncher()
    if not button then return false end
    local ok,err=false,"launcher has no OnClick/Click handler"
    local script=button.GetScript and button:GetScript("OnClick")
    if type(script)=="function" then
        ok,err=pcall(script,button,"LeftButton")
    elseif button.Click then
        ok,err=pcall(button.Click,button,"LeftButton")
    end
    local store; if RUI.global then RUI.global.extBankDebug=RUI.global.extBankDebug or {}; store=RUI.global.extBankDebug end
    if store then
        store.nativeVoidLauncherInvoked=true
        store.nativeVoidLauncherOK=ok and true or false
        store.nativeVoidLauncherError=ok and nil or tostring(err)
    end
    return ok and true or false
end

local function NativeVoidButtonIcon(button)
    if not IsFrameLikeObject(button) then return nil end
    local name=button.GetName and button:GetName()
    local icon=button.icon or button.Icon or button.IconTexture
    if not icon and name then icon=_G[name.."IconTexture"] or _G[name.."Icon"] end
    if icon and icon.GetTexture then
        local tex=icon:GetTexture()
        if tex and tex~="" then return tex,icon end
    end
    if button.GetRegions then
        local regions={button:GetRegions()}
        for _,region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType()=="Texture" and region.GetTexture then
                local tex=region:GetTexture()
                if tex and tex~="" then
                    local lower=string.lower(tostring(tex))
                    if string.find(lower,"interface\\icons",1,true) or string.find(lower,"interface/icons",1,true) then return tex,region end
                end
            end
        end
    end
    return nil,icon
end

function PhaseB:DiscoverNativeVoidStorageButtons()
    local f=self.frames and self.frames.bank
    if not f then return 0 end
    local found,seen={},{}
    f.nativeVoidPurchaseButton=nil
    local function ConsiderPurchase(name,button)
        if f.nativeVoidPurchaseButton or not IsFrameLikeObject(button) then return end
        local ok,obj=pcall(button.GetObjectType,button); if not ok or obj~="Button" then return end
        f.nativeVoidPurchaseButton=button
    end
    local function Add(name,button)
        if not IsFrameLikeObject(button) or seen[button] then return end
        local ok,obj=pcall(button.GetObjectType,button); if not ok or obj~="Button" then return end
        local id=tonumber(string.match(string.lower(tostring(name or "")),"(%d+)$"))
        if not id and button.GetID then local oki,v=pcall(button.GetID,button); if oki then id=tonumber(v) end end
        if not id or id<=0 then return end
        seen[button]=true
        found[#found+1]={button=button,id=id,name=tostring(name or "")}
    end
    for _,name in ipairs({"VoidStoragePurchaseButton","VoidStorageUnlockButton","ExtBankPurchaseButton","ExtBankUnlockButton"}) do
        ConsiderPurchase(name,_G[name])
    end
    -- Known stock/custom prefixes plus Bagnon's explicit VaultSlot prefix.  No
    -- fallback walk over _G: that was the source of both the hitch and crashes.
    local prefixes={
        "VoidStorageStorageButton","VoidStorageItemButton","VoidStorageSlotButton",
        "ExtBankStorageButton","ExtBankItemButton","ExtBankSlotButton","ExtBankSlot",
        "BagnonVaultItemSlot"
    }
    for _,prefix in ipairs(prefixes) do
        for i=1,320 do
            local b=_G[prefix..i]
            if b then Add(prefix..i,b) end
        end
    end
    table.sort(found,function(a,b) if a.id==b.id then return a.name<b.name end return a.id<b.id end)
    f.nativeVoidButtons={}
    for _,entry in ipairs(found) do f.nativeVoidButtons[#f.nativeVoidButtons+1]=entry.button end
    local store; if RUI.global then RUI.global.extBankDebug=RUI.global.extBankDebug or {}; store=RUI.global.extBankDebug end
    if store then
        store.nativeVoidButtonCount=#f.nativeVoidButtons
        store.nativeVoidPurchaseButton=f.nativeVoidPurchaseButton and ((f.nativeVoidPurchaseButton.GetName and f.nativeVoidPurchaseButton:GetName()) or true) or nil
    end
    return #f.nativeVoidButtons
end

function PhaseB:TryBagnonVoidBridge()
    -- The user's Ebonhold install includes the LoadOnDemand Bagnon_VoidStorage
    -- module.  Use it only as an optional compatibility bootstrap: it already
    -- knows how this client opens Void Storage.  We never require Bagnon for
    -- Zen to load, and we keep any Bagnon vault frame invisible.
    local f=self.frames and self.frames.bank
    if not f then return false end

    self:LoadNativeVoidStorageSupport()

    if type(_G.Bagnon)~="table" then
        return false
    end

    local vaultModule=nil
    if type(_G.Bagnon.GetModule)=="function" then
        local ok,module=pcall(_G.Bagnon.GetModule,_G.Bagnon,"VoidStorage",true)
        if ok then vaultModule=module end
    end

    -- If the addon loaded but its module has not yet run the normal open path,
    -- invoke that exact path once. This is a fixed, known call and replaces the
    -- old global discovery scans that caused hitches/crashes.
    if vaultModule and type(vaultModule.OnOpen)=="function" and not f.RUIBagnonVoidOpened then
        local ok=pcall(vaultModule.OnOpen,vaultModule)
        if ok then f.RUIBagnonVoidOpened=true end
    end

    local vaultFrame=nil
    if type(_G.Bagnon.GetFrame)=="function" then
        local ok,frame=pcall(_G.Bagnon.GetFrame,_G.Bagnon,"vault")
        if ok then vaultFrame=frame end
    end
    if IsFrameLikeObject(vaultFrame) then
        f.nativeVoidBagnonFrame=vaultFrame
        Suppress(vaultFrame)
    end

    local count=self:DiscoverNativeVoidStorageButtons()
    if BlizzardVoidStorageSupported() then
        f.voidReady=true
        return true
    end
    return count>0
end

local function NativeVoidStorageSupported(f)
    return f and f.nativeVoidButtons and #f.nativeVoidButtons>0
end

local function CallNativeVoidButton(button,mouseButton,receiveDrag)
    if not button then return false end
    local script=button.GetScript and button:GetScript(receiveDrag and "OnReceiveDrag" or "OnClick")
    if not script and receiveDrag and button.GetScript then script=button:GetScript("OnClick") end
    if type(script)=="function" then
        local ok=pcall(script,button,mouseButton or "LeftButton")
        return ok and true or false
    end
    return false
end

local function PositionBankTooltip(button)
    if not GameTooltip or not button then return end
    if GameTooltip.SetClampedToScreen then GameTooltip:SetClampedToScreen(true) end
    local x=button.GetCenter and button:GetCenter()
    local uiW=(UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 0
    local mid=uiW/2

    -- Keep tooltip placement conventional. The apparent "top two row" issue
    -- was not an anchor problem: those 28 cells are the base BANK_CONTAINER,
    -- which Wrath exposes as inventory slots rather than a normal bag.
    if x and mid>0 and x>mid then
        GameTooltip:SetOwner(button,"ANCHOR_LEFT")
    else
        GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
    end
end

local function ReanchorShownBankTooltip(button)
    if not GameTooltip or not button or not GameTooltip:IsShown() then return end
    local x=button.GetCenter and button:GetCenter()
    local uiW=(UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 0
    local mid=uiW/2

    -- Native Void buttons can populate a tooltip owned by a hidden backing
    -- button. Move points only; SetOwner() here would clear populated lines on
    -- the Ebonhold client.
    GameTooltip:ClearAllPoints()
    if x and mid>0 and x>mid then
        GameTooltip:SetPoint("TOPRIGHT",button,"TOPLEFT",-8,0)
    else
        GameTooltip:SetPoint("TOPLEFT",button,"TOPRIGHT",8,0)
    end
end

local function ShowNativeVoidButtonTooltip(proxy,button)
    if not GameTooltip or not button then return false end
    local script=button.GetScript and button:GetScript("OnEnter")
    if type(script)~="function" then return false end
    local ok=pcall(script,button)
    if ok and GameTooltip:IsShown() then
        -- Native Void buttons may anchor to their hidden backing frame. Keep
        -- their populated lines intact and move only the tooltip points.
        ReanchorShownBankTooltip(proxy)
        return true
    end
    return false
end

local function QueryVoidStorageReady()
    if not BlizzardVoidStorageSupported() then return false end
    if type(IsVoidStorageReady)~="function" then return false end
    local ok,ready=pcall(IsVoidStorageReady)
    return ok and ready and true or false
end

local function QueryVoidStorageUnlocked()
    if type(CanUseVoidStorage)~="function" then return true end
    local ok,unlocked=pcall(CanUseVoidStorage)
    return ok and unlocked and true or false
end

local function VoidGlobalIndex(tab,slot)
    return ((tonumber(tab) or 1)-1)*VOID_STORAGE_SLOTS_PER_TAB+(tonumber(slot) or 1)
end

local function GetVoidSlotInfo(tab,slot)
    if type(GetVoidItemInfo)~="function" then return nil end
    -- Legacy Blizzard-style Void Storage compatibility for clients that
    -- backported that API. Project Ebonhold itself uses ExtBank instead.
    local ok,a,b,c,d,e,f=pcall(GetVoidItemInfo,tab,slot)
    if ok then return a,b,c,d,e,f end
    ok,a,b,c,d,e,f=pcall(GetVoidItemInfo,VoidGlobalIndex(tab,slot))
    if ok then return a,b,c,d,e,f end
    return nil
end

local function GetVoidSlotLink(tab,slot)
    if type(GetVoidItemHyperlinkString)~="function" then return nil end
    local global=VoidGlobalIndex(tab,slot)
    local ok,link=pcall(GetVoidItemHyperlinkString,global)
    if ok and link then return link end
    ok,link=pcall(GetVoidItemHyperlinkString,tab,slot)
    if ok then return link end
    return nil
end

local function ClickVoidSlot(tab,slot,rightClick)
    if type(ClickVoidStorageSlot)~="function" then return false end
    local ok=pcall(ClickVoidStorageSlot,tab,slot,rightClick and true or false)
    if ok then return true end
    ok=pcall(ClickVoidStorageSlot,VoidGlobalIndex(tab,slot),rightClick and true or false)
    return ok and true or false
end

local function ShowVoidTooltip(tab,slot)
    if not GameTooltip then return end
    if GameTooltip.SetVoidItem then
        local ok=pcall(GameTooltip.SetVoidItem,GameTooltip,tab,slot)
        if ok then return end
        ok=pcall(GameTooltip.SetVoidItem,GameTooltip,VoidGlobalIndex(tab,slot))
        if ok then return end
    end
    local link=GetVoidSlotLink(tab,slot)
    if link and GameTooltip.SetHyperlink then GameTooltip:SetHyperlink(link) end
end

local function ExtBankDebugStore()
    if not RUI.global then return nil end
    RUI.global.extBankDebug=RUI.global.extBankDebug or {}
    return RUI.global.extBankDebug
end

local function SnapshotExtBankGlobals()
    local store=ExtBankDebugStore()
    if not store then return end
    local snapshot={}
    local names={}
    for name in pairs(_G) do
        if type(name)=="string" and string.find(string.lower(name),"extbank",1,true) then
            names[#names+1]=name
        end
    end
    table.sort(names)
    for i=1,#names do
        local name=names[i]
        local value=_G[name]
        local kind=type(value)
        local entry={ kind=kind }
        if kind=="string" then
            entry.value=string.sub(value,1,256)
        elseif kind=="number" or kind=="boolean" then
            entry.value=value
        elseif kind=="table" then
            local count=0
            local sample={}
            for k,v in pairs(value) do
                count=count+1
                if #sample<40 then
                    local vt=type(v)
                    local rendered
                    if vt=="string" then rendered=string.sub(v,1,128)
                    elseif vt=="number" or vt=="boolean" then rendered=v
                    elseif vt=="table" then rendered="{table}"
                    else rendered="{"..vt.."}" end
                    sample[#sample+1]={ key=tostring(k), value=rendered }
                end
            end
            entry.count=count
            entry.sample=sample
        end
        snapshot[name]=entry
    end
    store.globals=snapshot
end


-- Project Ebonhold Extended Bank wire format.
--
-- A real packet captured from this client is:
--   u8 status
--   u8 unlockedBagSlots
--   u8 bagCount
--   bagCount * {
--       u8  index
--       u32 bagItemID
--       u32 bagGUIDLow
--       u8  size
--   }
--   u16 itemCount
--   itemCount * {
--       u8  storageBag
--       u8  slot            -- zero based
--       u32 itemID
--       u32 count
--       u32 itemGUIDLow
--       u8  reserved[9]
--   }
--
-- Ebonhold sends storageBag values starting at 20.  The packet supplied by the
-- user contains four bags (16/16/16/20 slots) and 63 item records, exactly
-- consuming its 1494 bytes.  Decode that transport directly so Zen no
-- longer depends on a separate native Void Storage UI/parser being visible.
local EXTBANK_STORAGE_BAG_BASE=20
local EXTBANK_HEADER_BAG=19
local EXTBANK_AUTO_EXT=255
local EXTBANK_AUTO_INV=254
local EXTBANK_AUTO_BAGSLOT=255
-- Project Ebonhold's shipped extBank.lua is authoritative here.  It exposes a
-- 7-column x 10-row bag-position grid (70 positions) and a fixed unlock-cost
-- progression which caps at 10,000g from slot 8 onward.
local EXTBANK_CONFIRMED_MAX_SLOTS=70
local EXTBANK_UI_SLOT_CAP=EXTBANK_CONFIRMED_MAX_SLOTS
local EXTBANK_VISIBLE_SLOT_BUTTONS=12
local EXTBANK_SLOT_COSTS_GOLD={50,125,250,500,1250,2500,5000,10000}
local function ExactExtBankSlotCost(slot)
    slot=math.floor(tonumber(slot) or 0)
    if slot<1 or slot>EXTBANK_CONFIRMED_MAX_SLOTS then return nil end
    local gold=EXTBANK_SLOT_COSTS_GOLD[math.min(slot,#EXTBANK_SLOT_COSTS_GOLD)]
    return gold and (gold*10000) or nil
end

-- Track the real inventory source while an item is on the cursor. Ebonhold's
-- native extBank.lua does the same because WoW 3.3.5 has no API for asking the
-- cursor which bag/slot it came from.
local EXTBANK_CURSOR_SOURCE=nil
if hooksecurefunc and type(PickupContainerItem)=="function" then
    hooksecurefunc("PickupContainerItem",function(bag,slot)
        if CursorHasItem and CursorHasItem() then
            EXTBANK_CURSOR_SOURCE={bag=tonumber(bag),slot=tonumber(slot)}
        else
            EXTBANK_CURSOR_SOURCE=nil
        end
    end)
end

local function IsNativeBankContainer(bag)
    bag=tonumber(bag)
    if bag==nil then return false end
    return bag==BANK_ID or (bag>=BANK_BAG_FIRST and bag<=BANK_BAG_LAST)
end

local function IsCarriedContainer(bag)
    bag=tonumber(bag)
    if bag==nil then return false end
    return bag>=0 and bag<=(tonumber(NUM_BAG_SLOTS) or 4)
end

local function FindFreeCarriedBagSlot()
    local last=tonumber(NUM_BAG_SLOTS) or 4
    for bag=0,last do
        local slots=(GetContainerNumSlots and tonumber(GetContainerNumSlots(bag))) or 0
        for slot=1,slots do
            local texture=GetContainerItemInfo and GetContainerItemInfo(bag,slot)
            if not texture then return bag,slot end
        end
    end
    return nil,nil
end

local function ContainerItemID(bag,slot)
    if not GetContainerItemLink then return nil end
    local link=GetContainerItemLink(bag,slot)
    if type(link)~="string" then return nil end
    return tonumber(string.match(link,"item:(%d+)"))
end

local function ContainerSlotHasItem(bag,slot)
    if ContainerItemID(bag,slot) then return true end
    if GetContainerItemInfo then
        local texture=GetContainerItemInfo(bag,slot)
        return texture and true or false
    end
    return false
end

local function ContainerSlotReadyForMove(bag,slot,expectedItemID)
    if not GetContainerItemInfo then return false end
    local texture,_,locked=GetContainerItemInfo(bag,slot)
    if not texture or locked then return false end
    local itemID=ContainerItemID(bag,slot)
    -- Item links can populate a little later than the texture on Ebonhold. A
    -- missing link is acceptable once the slot is unlocked; a definite mismatch
    -- is not.
    if expectedItemID and itemID and itemID~=expectedItemID then return false end
    return true,itemID
end

local PreserveVoidUIState

local function SendExtBankMove(srcBag,srcSlot,dstBag,dstSlot,count)
    if type(ExtBankMove)~="function" then return false end
    local ok=pcall(ExtBankMove,srcBag,srcSlot,dstBag,dstSlot,count or 0)
    if ok then
        -- Ebonhold may answer a move with a tiny acknowledgement before the next
        -- full ExtBank state. Keep Zen's Void section alive and immediately
        -- request a fresh full snapshot; RequestExtBank also resets the native
        -- deposit suppressor so the normal Bank remains usable.
        local bank=PhaseB.frames and PhaseB.frames.bank
        if bank then
            BankFilterSettings().void=true
            bank.RUIKeepVoidVisible=true
            bank.extBankMovePending=true
            if bank.extManager and bank.extManager:IsShown() then bank.RUIKeepExtManagerOpen=true end
        end
        if PhaseB.RequestExtBank then PhaseB:RequestExtBank() end
    end
    return ok and true or false
end

local function StartVoidToNativeBridge(bank,src,dstBag,dstSlot)
    if not bank or not src or not src.bag or src.slot==nil then return false end
    local tempBag,tempSlot=FindFreeCarriedBagSlot()
    if tempBag==nil then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Void transfer needs one free carried-bag slot as a temporary transfer slot.") end
        return false
    end
    PreserveVoidUIState(bank)
    bank.pendingVoidToNative={
        mode="TARGET",
        tempBag=tempBag,tempSlot=tempSlot,
        dstBag=dstBag,dstSlot=dstSlot,
        srcBag=src.bag,srcSlot=src.slot,
        itemID=src.itemID,
        started=(GetTime and GetTime()) or 0,
    }
    if SendExtBankMove(src.bag,src.slot,tempBag,tempSlot,0) then
        return true
    end
    bank.pendingVoidToNative=nil
    return false
end

local function StartVoidToAutoBankBridge(bank,src)
    if not bank or not src or not src.bag or src.slot==nil then return false end
    local tempBag,tempSlot=FindFreeCarriedBagSlot()
    if tempBag==nil then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Void -> Bank quick drop needs one free carried-bag slot as a temporary transfer slot.") end
        return false
    end
    PreserveVoidUIState(bank)
    bank.pendingVoidToNative={
        mode="AUTOBANK",
        tempBag=tempBag,tempSlot=tempSlot,
        srcBag=src.bag,srcSlot=src.slot,
        itemID=src.itemID,
        started=(GetTime and GetTime()) or 0,
    }
    if SendExtBankMove(src.bag,src.slot,tempBag,tempSlot,0) then return true end
    bank.pendingVoidToNative=nil
    return false
end

local function StageCursorBankItemToVoid(bank,srcBag,srcSlot,dstBag,dstSlot,dstItemID)
    local tempBag,tempSlot=FindFreeCarriedBagSlot()
    if tempBag==nil then
        if PickupContainerItem and CursorHasItem and CursorHasItem() then
            PickupContainerItem(srcBag,srcSlot)
            EXTBANK_CURSOR_SOURCE=nil
        end
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Bank -> Void needs one free carried-bag slot as a temporary transfer slot.") end
        return false
    end
    if not PickupContainerItem then return false end
    PreserveVoidUIState(bank)
    PickupContainerItem(tempBag,tempSlot)
    local movedToTemp=not (CursorHasItem and CursorHasItem())
    if movedToTemp then
        local sourceItemID=ContainerItemID(tempBag,tempSlot)
        bank.pendingBankToVoid={
            tempBag=tempBag,tempSlot=tempSlot,
            srcBag=srcBag,srcSlot=srcSlot,
            sourceItemID=sourceItemID,
            displacedItemID=tonumber(dstItemID),
            started=(GetTime and GetTime()) or 0,
        }
        if SendExtBankMove(tempBag,tempSlot,dstBag,dstSlot,0) then
            EXTBANK_CURSOR_SOURCE=nil
            return true
        end
        bank.pendingBankToVoid=nil
        -- The custom move could not be sent. Put the staged item back where it
        -- came from so a failed quick drop never silently relocates it to Bags.
        PickupContainerItem(tempBag,tempSlot)
        if CursorHasItem and CursorHasItem() then PickupContainerItem(srcBag,srcSlot) end
        EXTBANK_CURSOR_SOURCE=nil
        return false
    end
    if CursorHasItem and CursorHasItem() then PickupContainerItem(srcBag,srcSlot) end
    EXTBANK_CURSOR_SOURCE=nil
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Could not stage the bank item in carried inventory; transfer cancelled.") end
    return false
end

function PhaseB:ProcessPendingBankToVoid()
    local bank=self.frames and self.frames.bank
    local p=bank and bank.pendingBankToVoid
    if not p then return false end
    local itemID=ContainerItemID(p.tempBag,p.tempSlot)

    -- Successful move to an empty/auto Void destination leaves the temporary
    -- carried slot empty. Nothing further is required.
    if not itemID then
        bank.pendingBankToVoid=nil
        return true
    end

    -- If the target Void slot was occupied and Ebonhold swapped that item into
    -- our staging slot, finish the true swap by returning it to the original
    -- native Bank position.
    if p.displacedItemID and itemID==p.displacedItemID and PickupContainerItem then
        PickupContainerItem(p.tempBag,p.tempSlot)
        if CursorHasItem and CursorHasItem() then PickupContainerItem(p.srcBag,p.srcSlot) end
        EXTBANK_CURSOR_SOURCE=nil
        bank.pendingBankToVoid=nil
        self:RefreshBank()
        return true
    end

    local now=(GetTime and GetTime()) or 0
    if p.started and now>0 and (now-p.started)>8 then
        -- A rejected/failed custom move normally leaves the original Bank item
        -- in the staging slot. Restore it rather than silently changing storage.
        if p.sourceItemID and itemID==p.sourceItemID and PickupContainerItem and not ContainerSlotHasItem(p.srcBag,p.srcSlot) then
            PickupContainerItem(p.tempBag,p.tempSlot)
            if CursorHasItem and CursorHasItem() then PickupContainerItem(p.srcBag,p.srcSlot) end
            EXTBANK_CURSOR_SOURCE=nil
        end
        bank.pendingBankToVoid=nil
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Bank -> Void transfer did not complete; the staged item was restored when possible.") end
        self:RefreshBank()
        return false
    end
    return false
end

function PhaseB:ProcessPendingVoidToNative()
    local bank=self.frames and self.frames.bank
    local p=bank and bank.pendingVoidToNative
    if not p then return false end
    local now=(GetTime and GetTime()) or 0
    if p.started and now>0 and (now-p.started)>12 then
        bank.pendingVoidToNative=nil
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Void transfer timed out safely; the item remains in carried inventory/Void Storage.") end
        return false
    end
    local ready,itemID=ContainerSlotReadyForMove(p.tempBag,p.tempSlot,p.itemID)
    if not ready then
        p.readySince=nil
        return false
    end

    -- The ExtBank packet can make the slot visible one frame before the client
    -- has completely released its internal item lock. Require one extra polling
    -- interval of stable, unlocked state before we touch the item with native
    -- PickupContainerItem/UseContainerItem calls.
    if not p.readySince then
        p.readySince=now
        return false
    end
    if now>0 and p.readySince>0 and (now-p.readySince)<0.20 then return false end

    PreserveVoidUIState(bank)
    if p.mode=="AUTOBANK" then
        -- Use the native carried-item -> Bank path after the custom Void
        -- withdrawal lands in our known temporary slot. This preserves normal
        -- bank auto-stack/first-free-slot behavior instead of guessing a Bank
        -- destination in Lua.
        if type(ExtBankSetActive)=="function" then pcall(ExtBankSetActive,0) end
        if UseContainerItem then UseContainerItem(p.tempBag,p.tempSlot) end
        EXTBANK_CURSOR_SOURCE=nil
        bank.pendingVoidToNative=nil
        bank.extPickSrc=nil
        self:RefreshBank()
        return true
    end

    if not PickupContainerItem then return false end
    -- Stage 2: carried temporary slot -> requested Bank slot.
    PickupContainerItem(p.tempBag,p.tempSlot)
    if CursorHasItem and not CursorHasItem() then
        p.readySince=nil
        return false
    end
    PickupContainerItem(p.dstBag,p.dstSlot)

    -- If the Bank destination was occupied, WoW leaves that displaced item on
    -- the cursor.  Put it in the now-empty temporary carried slot and, when
    -- possible, return it to the original Void source slot for a true swap.
    if CursorHasItem and CursorHasItem() then
        PickupContainerItem(p.tempBag,p.tempSlot)
        if not (CursorHasItem and CursorHasItem()) then
            SendExtBankMove(p.tempBag,p.tempSlot,p.srcBag,p.srcSlot,0)
        end
    end
    EXTBANK_CURSOR_SOURCE=nil
    bank.pendingVoidToNative=nil
    bank.extPickSrc=nil
    self:RefreshBank()
    return true
end

-- Backward-compatible internal alias for the 0.8.70 bridge name.
function PhaseB:ProcessPendingVoidToBank()
    return self:ProcessPendingVoidToNative()
end

function PhaseB:HandleVoidDropOnContainer(dstBag,dstSlot)
    local bank=self.frames and self.frames.bank
    local src=bank and bank.extPickSrc
    if not bank or not bank.bankOpen or not src then return false end
    -- A real WoW cursor item always wins over Zen's synthetic Void source.
    -- This prevents a stale Void selection from hijacking ordinary Bag/Bank
    -- drag-and-drop after the player starts dragging a native container item.
    if CursorHasItem and CursorHasItem() then return false end
    dstBag=tonumber(dstBag); dstSlot=tonumber(dstSlot)
    if dstBag==nil or dstSlot==nil then return false end
    if not IsCarriedContainer(dstBag) and not IsNativeBankContainer(dstBag) then return false end

    PreserveVoidUIState(bank)
    if IsCarriedContainer(dstBag) and not ContainerSlotHasItem(dstBag,dstSlot) then
        if SendExtBankMove(src.bag,src.slot,dstBag,dstSlot,0) then bank.extPickSrc=nil end
        return true
    end

    -- Occupied carried slots and every native Bank destination use the same
    -- safe two-stage bridge. If the destination is occupied, the displaced
    -- item is returned to the original Void source slot for a real swap.
    if StartVoidToNativeBridge(bank,src,dstBag,dstSlot) then bank.extPickSrc=nil end
    return true
end

function PhaseB:HandleContainerQuickDrop(bag,slot)
    local bank=self.frames and self.frames.bank
    if not bank or not bank.bankOpen or not Enabled("bank") then return false end
    if not self:IsBankQuickDropModifierDown() then return false end
    bag=tonumber(bag); slot=tonumber(slot)
    if not IsCarriedContainer(bag) or slot==nil or not ContainerSlotHasItem(bag,slot) then return false end

    if not EbonholdExtBankSupported() then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Void Storage transport is not available.") end
        return true
    end
    bank.extPickSrc=nil
    EXTBANK_CURSOR_SOURCE=nil
    PreserveVoidUIState(bank)
    SendExtBankMove(bag,slot,EXTBANK_AUTO_EXT,EXTBANK_AUTO_BAGSLOT,0)
    return true
end

function PhaseB:QuickDropBankToVoid(bag,slot)
    local bank=self.frames and self.frames.bank
    if not bank or not bank.bankOpen then return false end
    if not EbonholdExtBankSupported() then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Void Storage transport is not available.") end
        return true
    end
    if not IsNativeBankContainer(bag) or not ContainerSlotHasItem(bag,slot) then return true end
    if not PickupContainerItem then return true end

    bank.extPickSrc=nil
    PickupContainerItem(bag,slot)
    if CursorHasItem and not CursorHasItem() then return true end
    StageCursorBankItemToVoid(bank,bag,slot,EXTBANK_AUTO_EXT,EXTBANK_AUTO_BAGSLOT,nil)
    return true
end

function PhaseB:QuickDropVoidToBank(src)
    local bank=self.frames and self.frames.bank
    if not bank or not bank.bankOpen or not src then return false end
    EXTBANK_CURSOR_SOURCE=nil
    if StartVoidToAutoBankBridge(bank,src) then bank.extPickSrc=nil end
    return true
end

local function ExtHexByte(hex,offset)
    local p=(offset*2)+1
    if p<1 or p+1>#hex then return nil end
    return tonumber(string.sub(hex,p,p+1),16)
end

local function ExtHexLE16(hex,offset)
    local a=ExtHexByte(hex,offset)
    local b=ExtHexByte(hex,offset+1)
    if a==nil or b==nil then return nil end
    return a+(b*256)
end

local function ExtHexLE32(hex,offset)
    local a=ExtHexByte(hex,offset)
    local b=ExtHexByte(hex,offset+1)
    local c=ExtHexByte(hex,offset+2)
    local d=ExtHexByte(hex,offset+3)
    if a==nil or b==nil or c==nil or d==nil then return nil end
    return a+(b*256)+(c*65536)+(d*16777216)
end

local function DecodeExtBankPacket(hex)
    if type(hex)~="string" or (#hex%2)~=0 or #hex<10 then return nil,"invalid packet" end
    local byteCount=#hex/2
    local state={
        rawBytes=byteCount,
        status=ExtHexByte(hex,0) or 0,
        unlockedBagSlots=ExtHexByte(hex,1) or 0,
        bagCount=ExtHexByte(hex,2) or 0,
        bags={},
        bagsByIndex={},
        items={},
        itemsByPos={},
        totalCapacity=0,
    }
    if state.bagCount<0 or state.bagCount>EXTBANK_UI_SLOT_CAP then return nil,"invalid bag count" end

    local offset=3
    if byteCount < offset+(state.bagCount*10)+2 then return nil,"truncated bag header" end
    for i=1,state.bagCount do
        local index=ExtHexByte(hex,offset)
        local itemID=ExtHexLE32(hex,offset+1)
        local guid=ExtHexLE32(hex,offset+5)
        local size=ExtHexByte(hex,offset+9)
        if index==nil or itemID==nil or guid==nil or size==nil then return nil,"truncated bag record" end
        local bag={
            index=index,
            itemID=itemID,
            guid=guid,
            size=size,
            serverBag=EXTBANK_STORAGE_BAG_BASE+index,
        }
        state.bags[#state.bags+1]=bag
        state.bagsByIndex[index]=bag
        state.totalCapacity=state.totalCapacity+size
        offset=offset+10
    end
    table.sort(state.bags,function(a,b) return a.index<b.index end)

    state.itemCount=ExtHexLE16(hex,offset)
    if state.itemCount==nil then return nil,"missing item count" end
    offset=offset+2
    local expected=offset+(state.itemCount*23)
    if expected>#hex/2 then return nil,"truncated item records" end

    for i=1,state.itemCount do
        local storageBag=ExtHexByte(hex,offset)
        local slot=ExtHexByte(hex,offset+1)
        local itemID=ExtHexLE32(hex,offset+2)
        local count=ExtHexLE32(hex,offset+6)
        local guid=ExtHexLE32(hex,offset+10)
        if storageBag==nil or slot==nil or itemID==nil or count==nil or guid==nil then return nil,"truncated item record" end
        local item={bag=storageBag,slot=slot,itemID=itemID,count=count,guid=guid}
        state.items[#state.items+1]=item
        state.itemsByPos[tostring(storageBag)..":"..tostring(slot)]=item
        offset=offset+23
    end

    -- Reject accidental false-positive decodes.  Ebonhold's current packet has
    -- no trailing bytes; accepting a tiny future tail is harmless, but a large
    -- mismatch means this is a different protocol revision.
    state.trailingBytes=(#hex/2)-offset
    if state.trailingBytes<0 or state.trailingBytes>32 then return nil,"unexpected packet tail" end
    state.decoded=true
    return state
end

local function ExtBankItemLink(itemID)
    itemID=tonumber(itemID)
    if not itemID or itemID<=0 then return nil end
    if GetItemInfo then
        local _,link=GetItemInfo(itemID)
        if link then return link end
    end
    return "item:"..tostring(itemID)
end

local function ExtBankNormalizeUnlockCost(value)
    value=tonumber(value)
    if not value or value<=0 then return nil end
    -- Ebonhold UI data may store prices either as copper or as whole gold.
    -- Extended-bank unlocks are high-value purchases, so small values are gold.
    if value<100000 then return math.floor(value*10000) end
    return math.floor(value)
end

local function ExtBankCostFromText(text)
    if type(text)~="string" or text=="" then return nil end
    local plain=string.gsub(text,"|c%x%x%x%x%x%x%x%x","")
    plain=string.gsub(plain,"|r","")
    local amount=string.match(plain,"([%d,%.]+)%s*[gG]")
    if not amount then
        -- Native money buttons often use a gold texture instead of the letter g.
        if string.find(string.lower(plain),"goldicon",1,true) or string.find(string.lower(plain),"gold",1,true) then
            amount=string.match(plain,"([%d,%.]+)")
        end
    end
    if not amount then return nil end
    amount=string.gsub(amount,",","")
    return ExtBankNormalizeUnlockCost(tonumber(amount))
end

local function ExtBankRuntimeMetadata(state)
    local unlocked=tonumber(state and state.unlockedBagSlots) or 0
    local meta={
        unlocked=unlocked,
        maxSlots=EXTBANK_CONFIRMED_MAX_SLOTS,
        maxSource="ProjectEbonhold extBank.lua MAX_BAGS",
        nextCost=(unlocked<EXTBANK_CONFIRMED_MAX_SLOTS) and ExactExtBankSlotCost(unlocked+1) or nil,
        costSource=(unlocked<EXTBANK_CONFIRMED_MAX_SLOTS) and "ProjectEbonhold extBank.lua SLOT_COSTS" or nil,
    }
    local store=ExtBankDebugStore()
    if store then
        store.unlockCost=meta.nextCost
        store.unlockCostSource=meta.costSource
        store.detectedMaxSlots=meta.maxSlots
        store.detectedMaxSlotsSource=meta.maxSource
        store.runtimeInspectNodes=0
        store.runtimeInspectForUnlocked=unlocked
        -- Replace old screenshot-derived guesses with the exact client table.
        store.slotUnlockCosts=store.slotUnlockCosts or {}
        store.slotUnlockCostSources=store.slotUnlockCostSources or {}
        for slot=1,EXTBANK_CONFIRMED_MAX_SLOTS do
            store.slotUnlockCosts[tostring(slot)]=ExactExtBankSlotCost(slot)
            store.slotUnlockCostSources[tostring(slot)]="ProjectEbonhold extBank.lua SLOT_COSTS"
        end
    end
    PhaseB.extBankRuntimeMeta=meta
    PhaseB.extBankRuntimeMetaToken=tostring(unlocked)
    return meta
end

local function ExtBankRuntimeUnlockCost(state)
    local meta=ExtBankRuntimeMetadata(state)
    return meta and meta.nextCost or nil, meta and meta.costSource or nil
end

local function ExtBankRuntimeMaxSlots(state)
    local meta=ExtBankRuntimeMetadata(state)
    return meta and meta.maxSlots or nil, meta and meta.maxSource or nil
end

local function CaptureExtBankPriceDiagnostics()
    local store=ExtBankDebugStore()
    if not store then return nil,"debug store unavailable" end
    local capture={ frames={}, numericTables={}, unlocked=nil, visiblePurchaseCost=nil }
    if time then capture.time=time() end
    local bank=PhaseB.frames and PhaseB.frames.bank
    capture.unlocked=tonumber(bank and bank.extBankState and bank.extBankState.unlockedBagSlots) or tonumber(store.decodedUnlockedBagSlots) or 0

    local function textOf(obj)
        if not IsFrameLikeObject(obj) or not obj.GetText then return nil end
        local ok,text=pcall(obj.GetText,obj)
        if ok and type(text)=="string" and text~="" then return text end
        return nil
    end
    local function frameName(obj)
        if not IsFrameLikeObject(obj) or not obj.GetName then return nil end
        local ok,name=pcall(obj.GetName,obj)
        if ok and type(name)=="string" then return name end
        return nil
    end
    local function recordFrame(frame)
        if not IsFrameLikeObject(frame) then return end
        if frame.IsShown then
            local ok,shown=pcall(frame.IsShown,frame)
            if ok and not shown then return end
        end
        local name=frameName(frame) or ""
        local text=textOf(frame) or ""
        local regionText={}
        if frame.GetRegions then
            local rr={pcall(frame.GetRegions,frame)}
            if rr[1] then
                for i=2,math.min(#rr,12) do
                    local region=rr[i]
                    if region and region.GetText then
                        local ok,t=pcall(region.GetText,region)
                        if ok and type(t)=="string" and t~="" then regionText[#regionText+1]=t end
                    end
                end
            end
        end
        local blob=string.lower(name.." "..text.." "..table.concat(regionText," "))
        local interesting=string.find(blob,"void",1,true) or string.find(blob,"extbank",1,true) or string.find(blob,"purchase",1,true) or string.find(blob,"unlock",1,true) or string.find(blob,"buy slot",1,true)
        if not interesting then return end
        local rec={ name=name~="" and name or nil, text=text~="" and text or nil, regions=regionText }
        local okStatic,staticMoney=pcall(function() return frame.staticMoney end)
        if okStatic and type(staticMoney)=="number" and staticMoney>0 then rec.staticMoney=staticMoney end
        local cost=ExtBankCostFromText(text)
        if not cost then
            for _,t in ipairs(regionText) do cost=ExtBankCostFromText(t); if cost then break end end
        end
        if not cost and rec.staticMoney then cost=tonumber(rec.staticMoney) end
        if cost and cost>0 then
            rec.cost=cost
            if not capture.visiblePurchaseCost then capture.visiblePurchaseCost=cost end
        end
        capture.frames[#capture.frames+1]=rec
    end

    if type(EnumerateFrames)=="function" then
        local frame=EnumerateFrames()
        local scanned=0
        while frame and scanned<8000 and #capture.frames<120 do
            scanned=scanned+1
            recordFrame(frame)
            frame=EnumerateFrames(frame)
        end
        capture.framesScanned=scanned
    end

    -- On explicit request only, inspect the small set of known ExtBank Lua
    -- closures more deeply than the normal runtime path and preserve numeric
    -- arrays.  This is designed to reveal a hidden 80-slot price table if the
    -- native Ebonhold UI keeps one in an upvalue.
    local visited={}
    local nodes=0
    local function walk(value,label,depth)
        if depth>5 or nodes>1600 then return end
        local kind=type(value)
        if kind~="table" and kind~="function" then return end
        if visited[value] then return end
        visited[value]=true; nodes=nodes+1
        if kind=="function" then
            if debug and type(debug.getupvalue)=="function" then
                for i=1,64 do
                    local n,v=debug.getupvalue(value,i)
                    if not n then break end
                    walk(v,label..":"..tostring(n),depth+1)
                end
            end
            return
        end
        local values={}
        local numeric=0
        local maxKey=0
        for k,v in pairs(value) do
            if type(k)=="number" and k>=0 and k<=EXTBANK_CONFIRMED_MAX_SLOTS+1 and type(v)=="number" and v>0 then
                numeric=numeric+1
                if k>maxKey then maxKey=k end
                if numeric<=EXTBANK_CONFIRMED_MAX_SLOTS+2 then values[tostring(k)]=v end
            end
        end
        if numeric>=3 then
            capture.numericTables[#capture.numericTables+1]={ label=label, count=numeric, maxKey=maxKey, values=values }
        end
        local seen=0
        for k,v in pairs(value) do
            seen=seen+1; if seen>160 then break end
            if type(v)=="table" or type(v)=="function" then walk(v,label.."."..tostring(k),depth+1) end
        end
    end
    walk(_G.ExtBank_Redraw,"ExtBank_Redraw",0)
    walk(_G.ExtBank_Open,"ExtBank_Open",0)
    walk(_G.ExtBank_Close,"ExtBank_Close",0)
    walk(PhaseB.extBankOriginal,"ExtBank_OnPacket_original",0)
    capture.nodesInspected=nodes
    store.priceCapture=capture
    if capture.visiblePurchaseCost then RememberExtBankSlotCost((capture.unlocked or 0)+1,capture.visiblePurchaseCost,"native-visible-capture") end
    return capture
end

function PhaseB:CaptureExtBankPriceDiagnostics()
    return CaptureExtBankPriceDiagnostics()
end

local function ShowExtBankTooltip(button)
    if not GameTooltip or not button then return end
    if not button.extItemID then
        GameTooltip:Hide()
        return
    end
    if button.extItemID then
        local link=ExtBankItemLink(button.extItemID)
        if link and GameTooltip.SetHyperlink then
            local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,link)
            if not ok then GameTooltip:SetText("Item "..tostring(button.extItemID)) end
        else
            GameTooltip:SetText("Item "..tostring(button.extItemID))
        end
        GameTooltip:AddLine("Ebonhold Extended Bank",0.65,0.75,1)
        GameTooltip:AddLine("Storage bag "..tostring((button.extBag or EXTBANK_STORAGE_BAG_BASE)-EXTBANK_STORAGE_BAG_BASE+1).."  •  slot "..tostring((button.extSlot or 0)+1),0.7,0.7,0.7)
        GameTooltip:AddLine("Right-click: withdraw to your bags",0.75,0.85,0.75,true)
        GameTooltip:AddLine(BankQuickDropModifierLabel().." + Right-click: send to Bank",0.75,0.85,0.75,true)
        GameTooltip:AddLine("Drag: drop onto Bags or Bank",0.75,0.85,0.75,true)
        GameTooltip:AddLine("Left-click: select, then click another Void slot to move",0.75,0.85,0.75,true)
    end
    GameTooltip:Show()
end

local function RecordExtBankPacket(hex)
    if type(hex)~="string" then return end
    local store=ExtBankDebugStore()
    local bytes=math.floor(#hex/2)
    local decoded,decodeError=DecodeExtBankPacket(hex)
    local bank=PhaseB.frames and PhaseB.frames.bank
    local previous=bank and bank.extBankState or nil
    local previousUsable=previous and previous.decoded and (tonumber(previous.totalCapacity) or 0)>0

    -- Move/unlock acknowledgements can be only a few bytes long. They are valid
    -- transport packets but are NOT a replacement for the full storage snapshot.
    -- Preserve the last decoded state until the explicit ExtBankOpen refresh lands.
    local fullState=decoded and ((tonumber(decoded.bagCount) or 0)>0 or (tonumber(decoded.totalCapacity) or 0)>0 or not previousUsable)
    if previousUsable and bytes<16 and (not decoded or (tonumber(decoded.totalCapacity) or 0)==0) then fullState=false end

    if store then
        store.transport="Ebonhold ExtBank"
        store.packetCount=(tonumber(store.packetCount) or 0)+1
        store.lastTransportPacketBytes=bytes
        if time then store.lastPacketTime=time() end
        if fullState then
            store.lastPacket=hex
            store.lastPacketBytes=bytes
            store.decoded=true
            store.decodeError=nil
            store.decodedBagCount=decoded.bagCount
            store.decodedUnlockedBagSlots=decoded.unlockedBagSlots
            store.decodedCapacity=decoded.totalCapacity
            store.decodedItemCount=decoded.itemCount
        else
            store.lastAckPacket=hex
            store.lastAckPacketBytes=bytes
            store.lastAckDecodeError=decodeError and tostring(decodeError) or nil
        end
    end

    PhaseB.extBankRuntimeMeta=nil
    PhaseB.extBankRuntimeMetaToken=nil
    if bank then
        bank.extBankReady=true
        if fullState then
            bank.extBankPacketBytes=bytes
            bank.extBankPacket=hex
            bank.extBankState=decoded
            bank.extBankDecodeError=nil
            bank.extBankUnlockPending=false
            bank.extBankMovePending=false
        else
            bank.extBankLastAckBytes=bytes
            bank.extBankLastAckError=decodeError
        end
    end
end

local function ExtBankMoveTraceStore()
    local store=ExtBankDebugStore()
    if not store then return nil end
    store.moveTrace=store.moveTrace or { entries={} }
    store.moveTrace.entries=store.moveTrace.entries or {}
    return store.moveTrace
end

local function RecordExtBankMoveTrace(srcBag,srcSlot,dstBag,dstSlot,count)
    local trace=ExtBankMoveTraceStore()
    if not trace then return end
    local entry={
        srcBag=tonumber(srcBag), srcSlot=tonumber(srcSlot),
        dstBag=tonumber(dstBag), dstSlot=tonumber(dstSlot),
        count=tonumber(count),
    }
    if time then entry.time=time() end
    if GetCursorInfo then
        local ok,a,b,c=pcall(GetCursorInfo)
        if ok then
            entry.cursorType=a
            if type(b)=="number" or type(b)=="string" then entry.cursor1=b end
            if type(c)=="number" or type(c)=="string" then entry.cursor2=c end
        end
    end
    local entries=trace.entries
    entries[#entries+1]=entry
    while #entries>40 do table.remove(entries,1) end
    trace.count=(tonumber(trace.count) or 0)+1
    trace.last=entry
end

function PhaseB:InstallExtBankMoveTrace()
    local current=_G.ExtBankMove
    if type(current)~="function" then return false end
    if self.extBankMoveWrapper and current==self.extBankMoveWrapper then return true end

    -- If Ebonhold/load-on-demand code restores the native C function, adopt it
    -- as the backing function and wrap again. Never chain one Zen wrapper
    -- into another.
    if current~=self.extBankMoveWrapper then self.extBankMoveOriginal=current end
    local original=self.extBankMoveOriginal
    if type(original)~="function" then return false end

    self.extBankMoveWrapper=function(srcBag,srcSlot,dstBag,dstSlot,count)
        RecordExtBankMoveTrace(srcBag,srcSlot,dstBag,dstSlot,count)
        return original(srcBag,srcSlot,dstBag,dstSlot,count)
    end
    _G.ExtBankMove=self.extBankMoveWrapper
    local trace=ExtBankMoveTraceStore()
    if trace then trace.installed=true end
    return true
end

function PhaseB:GetExtBankMoveTrace()
    return ExtBankMoveTraceStore()
end

function PhaseB:ClearExtBankMoveTrace()
    local trace=ExtBankMoveTraceStore()
    if not trace then return false end
    trace.entries={}; trace.last=nil; trace.count=0
    return true
end

function PhaseB:InstallExtBankBridge()
    if not EbonholdExtBankSupported() then return false end
    if not self.extBankBridge then
        self.extBankBridge=function(hex)
            -- Guard against a third-party wrapper that calls the previous global
            -- callback.  Capture the packet once and never recurse indefinitely.
            if PhaseB.extBankBridgeBusy then
                RecordExtBankPacket(hex)
                return
            end
            PhaseB.extBankBridgeBusy=true
            RecordExtBankPacket(hex)
            local original=PhaseB.extBankOriginal
            if type(original)=="function" and original~=PhaseB.extBankBridge then
                local ok,err=pcall(original,hex)
                local store=ExtBankDebugStore()
                if store then
                    store.originalCallbackCalled=true
                    if not ok then store.originalCallbackError=tostring(err) else store.originalCallbackError=nil end
                end
            end
            local bank=PhaseB.frames and PhaseB.frames.bank
            if bank and BlizzardVoidStorageSupported() then bank.voidReady=true end
            PhaseB.extBankBridgeBusy=nil
            if bank and bank:IsShown() then
                if bank.RUIKeepVoidVisible then BankFilterSettings().void=true end
                PhaseB:RefreshBank()
                if bank.RUIKeepExtManagerOpen and bank.extManager and not bank.extManager:IsShown() then bank.extManager:Show() end
            end
        end
    end
    local current=_G.ExtBank_OnPacket
    if current~=self.extBankBridge then
        if type(current)=="function" then
            self.extBankOriginal=current
            local store=ExtBankDebugStore()
            if store then store.originalCallbackPresent=true end
        end
        _G.ExtBank_OnPacket=self.extBankBridge
    end
    local store=ExtBankDebugStore()
    if store then
        store.transportDetected=true
        store.bridgeInstalled=true
        store.hasOpen=type(ExtBankOpen)=="function"
        store.hasMove=type(ExtBankMove)=="function"
        store.hasUnlock=type(ExtBankUnlock)=="function"
        store.hasSetActive=type(ExtBankSetActive)=="function"
    end
    return true
end

function PhaseB:RequestExtBank()
    local f=self.frames and self.frames.bank
    if not EbonholdExtBankSupported() then return false end
    self:InstallExtBankBridge()
    local store=ExtBankDebugStore()
    if store then
        store.requestCount=(tonumber(store.requestCount) or 0)+1
        if time then store.lastRequestTime=time() end
    end
    local ok,err=pcall(ExtBankOpen)
    -- ExtBankOpen enables Ebonhold's native-bank deposit suppressor. Zen is
    -- still showing the normal bank, so immediately return that routing to normal.
    if type(ExtBankSetActive)=="function" then pcall(ExtBankSetActive,0) end
    if f then
        f.extBankRequested=ok and true or false
        if BlizzardVoidStorageSupported() then f.voidReady=true end
    end
    if store then
        store.lastRequestOK=ok and true or false
        if ok then store.lastRequestError=nil else store.lastRequestError=tostring(err) end
    end
    return ok and true or false
end

local function BankBagInventorySlot(bag)
    if BankButtonIDToInvSlotID then
        local ok,slot=pcall(BankButtonIDToInvSlotID,bag,1)
        if ok and slot then return slot end
    end
    if ContainerIDToInventoryID then
        local ok,slot=pcall(ContainerIDToInventoryID,bag)
        if ok and slot then return slot end
    end
    return nil
end

-- Ebonhold can leave GetContainerNumSlots(bankBag) at the removed bag's old
-- capacity for a short time after the equipment slot has already become empty.
-- The equipment slot is authoritative: if no bank bag is actually equipped,
-- that container contributes zero cells to Zen's unified bank immediately.
local function BankBagIsEquipped(bag)
    bag=tonumber(bag)
    if not bag or bag<BANK_BAG_FIRST or bag>BANK_BAG_LAST then return true end
    local inv=BankBagInventorySlot(bag)
    if not inv then return false end
    if GetInventoryItemTexture and GetInventoryItemTexture("player",inv) then return true end
    if GetInventoryItemLink and GetInventoryItemLink("player",inv) then return true end
    return false
end

local function BankContainerSlotCount(bag)
    bag=tonumber(bag)
    if bag and bag>=BANK_BAG_FIRST and bag<=BANK_BAG_LAST and not BankBagIsEquipped(bag) then
        return 0
    end
    return (GetContainerNumSlots and tonumber(GetContainerNumSlots(bag))) or 0
end

local function BuyNextBankBagSlot()
    local num,full=0,false
    if GetNumBankSlots then num,full=GetNumBankSlots() end
    if full then return end
    if StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs["CONFIRM_BUY_BANK_SLOT"] then
        StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
    elseif PurchaseSlot then
        PurchaseSlot()
    end
end

local function ConfirmVoidTransfer()
    if type(ExecuteVoidTransfer)~="function" then return end
    local deposits=type(GetNumVoidTransferDeposit)=="function" and (tonumber(GetNumVoidTransferDeposit()) or 0) or 0
    if deposits>0 and StaticPopup_Show and StaticPopupDialogs then
        if not StaticPopupDialogs["ZEN_VOID_TRANSFER_CONFIRM"] then
            StaticPopupDialogs["ZEN_VOID_TRANSFER_CONFIRM"]={
                text="Depositing items into Void Storage removes modifications and makes those items non-tradeable and non-refundable. Continue?",
                button1=YES,
                button2=NO,
                OnAccept=function() if ExecuteVoidTransfer then ExecuteVoidTransfer() end end,
                timeout=0,
                whileDead=1,
                hideOnEscape=1,
                preferredIndex=STATICPOPUP_NUMDIALOGS,
            }
        end
        StaticPopup_Show("ZEN_VOID_TRANSFER_CONFIRM")
    else
        ExecuteVoidTransfer()
    end
end

local function SetBankTooltipOwner(button)
    PositionBankTooltip(button)
end

local function PopulateNativeBankTooltip(bag,slot)
    if not GameTooltip or bag==nil or slot==nil then return false end

    -- Wrath 3.3.x does not treat the base bank as a real bag for tooltip data.
    -- Its 28 BANK_CONTAINER cells must be translated to player inventory slots.
    -- Using SetBagItem(BANK_CONTAINER, slot) is what produced the lower-only /
    -- "sliced" tooltip seen in Zen's first two 16-column grid rows.
    if tonumber(bag)==tonumber(BANK_ID) and BankButtonIDToInvSlotID and GameTooltip.SetInventoryItem then
        local okSlot,invSlot=pcall(BankButtonIDToInvSlotID,slot,nil)
        if okSlot and invSlot then
            local ok=pcall(GameTooltip.SetInventoryItem,GameTooltip,"player",invSlot)
            if ok and (not GameTooltip.NumLines or GameTooltip:NumLines()>0) then return true end
        end
    end

    if GameTooltip.SetBagItem then
        local ok=pcall(GameTooltip.SetBagItem,GameTooltip,bag,slot)
        if ok and (not GameTooltip.NumLines or GameTooltip:NumLines()>0) then return true end
    end

    -- Last-resort fallback keeps the item usable even on custom clients with a
    -- nonstandard bank slot mapping.
    local link=GetContainerItemLink and GetContainerItemLink(bag,slot)
    if link and GameTooltip.SetHyperlink then
        local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,link)
        if ok then return true end
    end
    return false
end

PreserveVoidUIState=function(bank)
    if not bank then return end
    BankFilterSettings().void=true
    bank.RUIKeepVoidVisible=true
    if bank.extManager and bank.extManager:IsShown() then bank.RUIKeepExtManagerOpen=true end
end

-- Zen's replacement Bank lives on the DIALOG strata. On the 3.3.5 client
-- StackSplitFrame can open at the same/lower level, leaving the native split
-- controls visually underneath the Bank and unable to receive mouse input.
-- Raise only the native split popup after it opens; the split logic itself
-- remains Blizzard's stock implementation.
local function RaiseBankStackSplitFrame(owner)
    local split=_G.StackSplitFrame
    if not split then return end
    if split.SetParent then split:SetParent(UIParent) end
    if split.SetFrameStrata then split:SetFrameStrata("TOOLTIP") end
    if split.SetFrameLevel then split:SetFrameLevel(1000) end
    if split.SetToplevel then split:SetToplevel(true) end
    if split.EnableMouse then split:EnableMouse(true) end
    local controls={_G.StackSplitLeftButton,_G.StackSplitRightButton,_G.StackSplitOkayButton,_G.StackSplitCancelButton}
    for i=1,#controls do
        local control=controls[i]
        if control then
            if control.SetFrameStrata then control:SetFrameStrata("TOOLTIP") end
            if control.SetFrameLevel then control:SetFrameLevel(1010+i) end
            if control.EnableMouse then control:EnableMouse(true) end
            if control.Raise then control:Raise() end
        end
    end
    if split.Raise then split:Raise() end
end

local function ConfigureBankItemButton(b)
    b:RegisterForDrag("LeftButton")
    b.SplitStack=function(self,count)
        if self.kind=="bank" and self.bag and self.slot and SplitContainerItem then SplitContainerItem(self.bag,self.slot,count) end
    end
    b:SetScript("OnEnter",function(self)
        SetBankTooltipOwner(self)
        if self.kind=="voidnative" and self.voidBacking then
            if ShowNativeVoidButtonTooltip(self,self.voidBacking) then return end
        elseif self.kind=="extbank" then
            ShowExtBankTooltip(self); return
        elseif self.kind=="void" then
            ShowVoidTooltip(self.voidTab,self.voidSlot)
        elseif self.bag and self.slot then
            local hasItem=ContainerSlotHasItem(self.bag,self.slot)
            if not hasItem then
                GameTooltip:Hide()
                return
            end
            if not PopulateNativeBankTooltip(self.bag,self.slot) then
                GameTooltip:Hide()
                return
            end
            if self.kind=="bank" then
                GameTooltip:AddLine(BankQuickDropModifierLabel().." + Right-click: send to Void",0.75,0.85,0.75,true)
            end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)

    b:SetScript("OnClick",function(self,button)
        if self.kind=="voidnative" and self.voidBacking then
            CallNativeVoidButton(self.voidBacking,button,false); return
        elseif self.kind=="extbank" then
            local bank=PhaseB.frames and PhaseB.frames.bank
            if button=="RightButton" and PhaseB:IsBankQuickDropModifierDown() then
                if self.extItemID and bank then
                    PhaseB:QuickDropVoidToBank({bag=self.extBag,slot=self.extSlot,itemID=self.extItemID})
                end
                return
            end
            if self.extItemID then
                local link=ExtBankItemLink(self.extItemID)
                if link and RUI.HandleModifiedLinkClick and RUI:HandleModifiedLinkClick(link, button) then return end
            end
            if button=="RightButton" then
                PreserveVoidUIState(bank)
                if self.extItemID and SendExtBankMove(self.extBag,self.extSlot,EXTBANK_AUTO_INV,0,0) then
                    if bank then bank.extPickSrc=nil end
                end
                return
            end
            if button=="LeftButton" then
                if bank and bank.extPickSrc then
                    local src=bank.extPickSrc
                    if src.bag==self.extBag and src.slot==self.extSlot then
                        bank.extPickSrc=nil; PhaseB:RefreshBank()
                    else
                        PreserveVoidUIState(bank)
                        if SendExtBankMove(src.bag,src.slot,self.extBag,self.extSlot,0) then bank.extPickSrc=nil end
                    end
                elseif self.extItemID and bank then
                    bank.extPickSrc={bag=self.extBag,slot=self.extSlot,itemID=self.extItemID}
                    PhaseB:RefreshBank()
                end
                return
            end
            return
        elseif self.kind=="void" then
            local link=GetVoidSlotLink(self.voidTab,self.voidSlot)
            if link and RUI.HandleModifiedLinkClick and RUI:HandleModifiedLinkClick(link, button) then return end
            ClickVoidSlot(self.voidTab,self.voidSlot,button=="RightButton"); return
        end
        if not self.bag or not self.slot then return end
        if self.kind=="bank" and button=="RightButton" and PhaseB:IsBankQuickDropModifierDown() then
            PhaseB:QuickDropBankToVoid(self.bag,self.slot)
            return
        end
        local link=GetContainerItemLink and GetContainerItemLink(self.bag,self.slot)
        if link and RUI.HandleModifiedLinkClick and RUI:HandleModifiedLinkClick(link, button) then return end
        if IsModifiedClick and IsModifiedClick("SPLITSTACK") then
            local _,cnt,locked=GetContainerItemInfo(self.bag,self.slot)
            if cnt and cnt>1 and not locked and OpenStackSplitFrame then
                -- OpenStackSplitFrame already receives the maximum stack size.
                -- Never store it in self.count: ItemSlot uses that name for the
                -- visible FontString and overwriting it poisons future refreshes.
                self.RUIStackSplitMax=cnt
                OpenStackSplitFrame(cnt,self,"BOTTOMLEFT","TOPLEFT")
                RaiseBankStackSplitFrame(self)
                return
            end
        end
        if button=="RightButton" and UseContainerItem then UseContainerItem(self.bag,self.slot)
        elseif PickupContainerItem then PickupContainerItem(self.bag,self.slot) end
    end)

    b:SetScript("OnDragStart",function(self)
        local bank=PhaseB.frames and PhaseB.frames.bank
        if self.kind=="extbank" then
            if bank and self.extItemID then
                bank.extPickSrc={bag=self.extBag,slot=self.extSlot,itemID=self.extItemID}
                PreserveVoidUIState(bank)
                PhaseB:RefreshBank()
            end
        elseif self.kind=="voidnative" and self.voidBacking then
            local fn=self.voidBacking.GetScript and self.voidBacking:GetScript("OnDragStart")
            if type(fn)=="function" then pcall(fn,self.voidBacking) end
        elseif self.kind=="bank" and self.bag and self.slot and PickupContainerItem then
            if bank then bank.extPickSrc=nil end
            PickupContainerItem(self.bag,self.slot)
        end
    end)

    b:SetScript("OnReceiveDrag",function(self)
        local bank=PhaseB.frames and PhaseB.frames.bank
        if self.kind=="voidnative" and self.voidBacking then
            CallNativeVoidButton(self.voidBacking,"LeftButton",true); return
        elseif self.kind=="extbank" then
            local cursorHasItem=CursorHasItem and CursorHasItem() and true or false
            if cursorHasItem and bank then bank.extPickSrc=nil end
            if bank and bank.extPickSrc and not cursorHasItem then
                local src=bank.extPickSrc
                PreserveVoidUIState(bank)
                if SendExtBankMove(src.bag,src.slot,self.extBag,self.extSlot,0) then bank.extPickSrc=nil end
                return
            end
            local src=EXTBANK_CURSOR_SOURCE
            if src and src.bag~=nil and src.slot~=nil and src.bag>=0 and src.bag<=4 then
                PreserveVoidUIState(bank)
                if SendExtBankMove(src.bag,src.slot,self.extBag,self.extSlot,0) then
                    if ClearCursor then ClearCursor() end
                    EXTBANK_CURSOR_SOURCE=nil
                end
            elseif src and IsNativeBankContainer(src.bag) then
                -- Ebonhold's native ExtBank deposit path accepts live inventory
                -- sources. Bridge a Bank -> Void drag through one free carried-bag
                -- slot. The normal PickupContainerItem packet is queued first, so
                -- the server sees the item in live inventory before ExtBankMove.
                StageCursorBankItemToVoid(bank,src.bag,src.slot,self.extBag,self.extSlot,self.extItemID)
            elseif DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Drop an item from carried bags or the Bank onto this Void slot.")
            end
            return
        elseif self.kind=="void" then
            ClickVoidSlot(self.voidTab,self.voidSlot,false); return
        elseif self.kind=="bank" and self.bag and self.slot then
            if PhaseB:HandleVoidDropOnContainer(self.bag,self.slot) then return end
            if PickupContainerItem then PickupContainerItem(self.bag,self.slot) end
        end
    end)
end

local function EnsureBankItemButton(f,index)
    local b=f.itemButtons[index]
    if b then return b end
    b=ItemSlot(f.grid,BANK_SLOT_SIZE)
    ConfigureBankItemButton(b)
    f.itemButtons[index]=b
    return b
end

local function BankSearchItemName(cell)
    if not cell then return nil end
    local itemID=nil
    local link=nil
    if cell.kind=="extbank" then
        itemID=cell.extItem and cell.extItem.itemID or nil
    elseif cell.kind=="bank" then
        if GetContainerItemLink then link=GetContainerItemLink(cell.bag,cell.slot) end
    elseif cell.kind=="void" then
        if GetVoidSlotInfo then
            local id=GetVoidSlotInfo(cell.voidTab,cell.voidSlot)
            itemID=tonumber(id)
        end
    elseif cell.kind=="voidnative" and cell.voidBacking then
        if cell.voidBacking.GetID then
            local ok,id=pcall(cell.voidBacking.GetID,cell.voidBacking)
            if ok then itemID=tonumber(id) end
        end
    end
    if itemID and itemID>0 and GetItemInfo then
        local name=GetItemInfo(itemID)
        if name then return name end
    end
    if link then
        if GetItemInfo then
            local name=GetItemInfo(link)
            if name then return name end
        end
        return string.match(link,"%[(.-)%]")
    end
    return nil
end

local function BankSearchMatches(cell,query)
    if not query or query=="" then return true end
    local name=BankSearchItemName(cell)
    if not name then return false end
    return string.find(string.lower(name),query,1,true) and true or false
end

local function BankVisualSortRecord(cell)
    local bag=tonumber(cell and cell.bag) or 0
    local slot=tonumber(cell and cell.slot) or 0
    local link=(cell and cell.kind=="bank" and GetContainerItemLink) and GetContainerItemLink(bag,slot) or nil
    if not link then
        return {empty=true,bag=bag,slot=slot,name="",quality=-1,class="",subclass="",equipLoc="",itemID=0}
    end
    local name,quality,class,subclass,equipLoc
    if GetItemInfo then
        local ok,a,_,c,_,_,f,g,_,i=pcall(GetItemInfo,link)
        if ok then name,quality,class,subclass,equipLoc=a,c,f,g,i end
    end
    return {
        empty=false,bag=bag,slot=slot,
        name=string.lower(tostring(name or link)),
        quality=tonumber(quality) or -1,
        class=string.lower(tostring(class or "")),
        subclass=string.lower(tostring(subclass or "")),
        equipLoc=string.lower(tostring(equipLoc or "")),
        itemID=tonumber(string.match(link,"item:(%-?%d+)")) or 0,
    }
end

local function BankVisualCellLess(a,b)
    local ar=BankVisualSortRecord(a)
    local br=BankVisualSortRecord(b)
    if ar.empty~=br.empty then return not ar.empty end
    if not ar.empty then
        if ar.class~=br.class then return ar.class<br.class end
        if ar.subclass~=br.subclass then return ar.subclass<br.subclass end
        if ar.equipLoc~=br.equipLoc then return ar.equipLoc<br.equipLoc end
        if ar.quality~=br.quality then return ar.quality>br.quality end
        if ar.name~=br.name then return ar.name<br.name end
        if ar.itemID~=br.itemID then return ar.itemID<br.itemID end
    end
    if ar.bag~=br.bag then return ar.bag<br.bag end
    return ar.slot<br.slot
end

local function CompactExtBankPrice(copper)
    copper=tonumber(copper)
    if not copper or copper<=0 then return nil end
    local gold=copper/10000
    if gold>=1000000 then
        local value=gold/1000000
        return (value>=10 and string.format("%.0fm",value) or string.format("%.1fm",value)):gsub("%.0m","m")
    elseif gold>=1000 then
        local value=gold/1000
        local text=value>=10 and string.format("%.0fk",value) or string.format("%.2fk",value)
        text=string.gsub(text,"0+k$","k")
        text=string.gsub(text,"%.k$","k")
        return text
    end
    return tostring(math.floor(gold+0.5)).."g"
end

local function ExtBankPriceStore()
    local store=ExtBankDebugStore()
    if not store then return nil end
    store.slotUnlockCosts=store.slotUnlockCosts or {}
    return store
end

local function RememberExtBankSlotCost(slot,cost,source)
    slot=tonumber(slot); cost=tonumber(cost)
    local store=ExtBankPriceStore()
    if not store or not slot or slot<1 or not cost or cost<=0 then return end
    local key=tostring(math.floor(slot))
    store.slotUnlockCosts[key]=math.floor(cost)
    store.slotUnlockCostSources=store.slotUnlockCostSources or {}
    if source then store.slotUnlockCostSources[key]=tostring(source) end
end

local function KnownExtBankSlotCost(slot)
    local store=ExtBankPriceStore()
    if not store or not store.slotUnlockCosts then return nil end
    return tonumber(store.slotUnlockCosts[tostring(math.floor(tonumber(slot) or 0))])
end

local function ToggleBankFilter(f,key)
    local settings=BankFilterSettings()
    settings[key]=not BankFilterEnabled(key)
    f.rowOffset=0
    PhaseB:RefreshBank()
end

local function ConfirmExtBankUnlock(frame)
    local state=frame and frame.extBankState
    local unlocked=tonumber(state and state.unlockedBagSlots) or 0
    local maxSlots=ExtBankRuntimeMaxSlots(state)
    if not state or not state.decoded or (maxSlots and unlocked>=maxSlots) or type(ExtBankUnlock)~="function" then return end
    local nextSlot=unlocked+1
    local cost=ExactExtBankSlotCost(nextSlot)
    if not StaticPopupDialogs or not StaticPopup_Show then
        pcall(ExtBankUnlock); frame.extBankUnlockPending=true; return
    end
    if not StaticPopupDialogs["ZEN_EXTBANK_UNLOCK_CONFIRM"] then
        StaticPopupDialogs["ZEN_EXTBANK_UNLOCK_CONFIRM"]={
            text="Purchase Void Storage bag slot %s for %s?",
            button1=YES,
            button2=NO,
            OnAccept=function()
                local f=PhaseB.frames and PhaseB.frames.bank
                if f and type(ExtBankUnlock)=="function" then
                    pcall(ExtBankUnlock)
                    f.extBankUnlockPending=true
                end
            end,
            timeout=0, whileDead=1, hideOnEscape=1, preferredIndex=STATICPOPUP_NUMDIALOGS,
        }
    end
    StaticPopup_Show("ZEN_EXTBANK_UNLOCK_CONFIRM",tostring(nextSlot),cost and Money(cost) or "the server price")
end

function PhaseB:CreateBank()
    local f=Panel("ZenUIBankFrame","bank","Bank")
    self.frames.bank=f; f.itemButtons={}; f.bankCells={}; f.nativeVoidButtons={}; f.rowOffset=0; f.bankOpen=false; f.voidReady=false; local dbg=ExtBankDebugStore(); f.extBankReady=dbg and dbg.lastPacket and true or false; f.extBankPacketBytes=dbg and tonumber(dbg.lastPacketBytes) or 0; f.extBankPacket=dbg and dbg.lastPacket or nil; if f.extBankPacket then f.extBankState,f.extBankDecodeError=DecodeExtBankPacket(f.extBankPacket) end

    -- Give Bank an explicit title-bar drag surface. This is intentionally kept
    -- above the bare panel chrome and away from the close/body controls so a
    -- drag can never steal clicks from bank slots, filters or Extended Bank.
    f.dragHandle=CreateFrame("Frame",nil,f)
    f.dragHandle:SetPoint("TOPLEFT",f,"TOPLEFT",8,-6)
    f.dragHandle:SetWidth(210); f.dragHandle:SetHeight(34)
    f.dragHandle:SetFrameLevel((f:GetFrameLevel() or 1)+10)
    f.dragHandle:EnableMouse(true)
    if RUI.EnableDirectPanelDrag then RUI:EnableDirectPanelDrag(f.dragHandle,"ZenBank") end
    -- Some rejected custom moves do not produce another BAG_UPDATE. Poll only
    -- while a bridge is pending so timeout/rollback logic always gets a chance
    -- to finish instead of leaving an item stranded in the temporary bag slot.
    f:SetScript("OnUpdate",function(self,elapsed)
        elapsed=tonumber(elapsed) or 0

        -- Bank-bag equip/remove packets on Ebonhold can settle over several
        -- frames. During a very short window after such an action, rebuild the
        -- bank from the live equipment slots so smaller/replaced bags converge
        -- to their new capacity without waiting for another unrelated click.
        if (self.RUIBankBagStructurePollRemaining or 0)>0 then
            self.RUIBankBagStructurePollRemaining=math.max(0,(self.RUIBankBagStructurePollRemaining or 0)-elapsed)
            self.RUIBankBagStructurePollElapsed=(self.RUIBankBagStructurePollElapsed or 0)+elapsed
            if self.RUIBankBagStructurePollElapsed>=0.15 then
                self.RUIBankBagStructurePollElapsed=0
                if self.bankOpen and self:IsShown() then PhaseB:RefreshBank() end
            end
        else
            self.RUIBankBagStructurePollElapsed=0
        end

        if not self.pendingVoidToNative and not self.pendingBankToVoid then
            self.RUIPendingTransferElapsed=0
            return
        end
        self.RUIPendingTransferElapsed=(self.RUIPendingTransferElapsed or 0)+elapsed
        if self.RUIPendingTransferElapsed<0.25 then return end
        self.RUIPendingTransferElapsed=0
        PhaseB:ProcessPendingVoidToNative()
        PhaseB:ProcessPendingBankToVoid()
    end)
    f.owner=Text(f.body,"",11,"TOPLEFT",f.body,"TOPLEFT",4,-4,true)
    f.summary=Text(f.body,"",9,"TOPRIGHT",f.body,"TOPRIGHT",-4,-5,true); f.summary:SetJustifyH("RIGHT")
    f.search=Edit(f.body,190,22,"Search bank / void...",false)
    f.search:SetPoint("TOP",f.body,"TOP",0,1)
    f.search:SetMaxLetters(64)
    f.search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    f.search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    f.search.RUIOnTextChanged=function()
        f.rowOffset=0
        PhaseB:RefreshBank()
    end

    do
        local bags=RUI:GetModule("Bags")
        f.sort=Button(f.body,"SORT",60,22)
        f.sort:SetPoint("LEFT",f.search,"RIGHT",8,0)
        f.sort:SetScript("OnClick",function()
            local liveBags=RUI:GetModule("Bags")
            if liveBags and liveBags.SortBankBags then liveBags:SortBankBags() end
        end)
        f.sort:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_TOP")
            GameTooltip:SetText("Sort Bank")
            GameTooltip:AddLine("Physically sorts normal Bank and bank-bag slots using Zen's queued Wrath-safe mover.",0.8,0.8,0.8,true)
            GameTooltip:AddLine("Extended/Void storage is never touched. Click again while sorting to cancel safely.",0.6,0.62,0.66,true)
            GameTooltip:Show()
        end)
        f.sort:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    end

    f.grid=CreateFrame("Frame",nil,f.body)
    f.grid:SetPoint("TOPLEFT",2,-28); f.grid:SetPoint("BOTTOMRIGHT",-2,96)
    RUI:CreateBackdrop(f.grid); f.grid:EnableMouseWheel(true)
    f.grid:SetScript("OnMouseWheel",function(_,delta)
        local total=#(f.bankCells or {})
        local rows=math.ceil(total/BANK_GRID_COLUMNS)
        local maxOffset=math.max(0,rows-BANK_GRID_ROWS)
        f.rowOffset=math.max(0,math.min(maxOffset,(f.rowOffset or 0)-delta))
        PhaseB:RefreshBank()
    end)
    -- Match Zen's main Bags window: compact container toggles control
    -- which storage containers participate in the single continuous grid.
    f.filterLabel=Text(f.body,"Click a container to show / hide it",9,"BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-2,84,true); f.filterLabel:SetJustifyH("RIGHT")
    f.filterButtons={}
    local BANK_BAG_FOOTER_X=54
    local BANK_BAG_FOOTER_PITCH=44
    for _,def in ipairs(BANK_FILTERS) do
        local width=(def.key=="bank" and 44) or (def.key=="void" and 34) or 38
        local x
        if def.key=="bank" then
            x=2
        elseif def.key=="void" then
            x=BANK_BAG_FOOTER_X+(7*BANK_BAG_FOOTER_PITCH)+6
        else
            local index=tonumber(string.match(def.key,"bag(%d+)")) or 1
            x=BANK_BAG_FOOTER_X+((index-1)*BANK_BAG_FOOTER_PITCH)
        end
        local b=Button(f.body,def.label,width,22)
        b:SetPoint("BOTTOMLEFT",f.body,"BOTTOMLEFT",x,60)
        b.RUIFilterDef=def
        b:SetScript("OnClick",function(self)
            local d=self.RUIFilterDef
            ToggleBankFilter(f,d.key)
            if d.void and BankFilterEnabled("void") then
                -- The Ebonhold packet is decoded directly in Zen.  No
                -- native-UI discovery, Bagnon bootstrap or global scanning is
                -- required. Request one fresh state snapshot when V is shown.
                if EbonholdExtBankSupported() then
                    PhaseB:RequestExtBank()
                end
                PhaseB:RefreshBank()
            end
        end)
        b:SetScript("OnEnter",function(self)
            local d=self.RUIFilterDef
            GameTooltip:SetOwner(self,"ANCHOR_TOP")
            GameTooltip:SetText((d.tooltip or d.key)..(BankFilterEnabled(d.key) and " |cff66ff66shown|r" or " |cffff7777hidden|r"))
            if d.void then
                if EbonholdExtBankSupported() then
                    GameTooltip:AddLine("Ebonhold Extended Bank transport detected.",0.8,0.8,0.8,true)
                    if f.extBankState and f.extBankState.decoded then
                        GameTooltip:AddLine("Direct Ebonhold packet decoder active.",0.55,0.85,0.55,true)
                        GameTooltip:AddLine(tostring(f.extBankState.bagCount or 0).." storage bags  •  "..tostring(f.extBankState.totalCapacity or 0).." slots  •  "..tostring(f.extBankState.itemCount or 0).." items",0.8,0.8,0.8,true)
                        local runtimeMax=ExtBankRuntimeMaxSlots(f.extBankState)
                        local unlocked=tonumber(f.extBankState.unlockedBagSlots) or 0
                        if runtimeMax then
                            GameTooltip:AddLine("Unlock positions: "..tostring(unlocked).." / "..tostring(runtimeMax),0.8,0.8,0.8,true)
                        else
                            GameTooltip:AddLine("Unlock positions: "..tostring(unlocked).." • server maximum not exposed",0.8,0.8,0.8,true)
                        end
                        if not runtimeMax or unlocked<runtimeMax then
                            local nextCost=ExtBankRuntimeUnlockCost(f.extBankState)
                            if nextCost then GameTooltip:AddLine("Next unlock: "..Money(nextCost),1,0.82,0.35,true) end
                        end
                        GameTooltip:AddLine("All Extended Bank bags are flattened into one Zen storage section.",0.8,0.8,0.8,true)
                    elseif BlizzardVoidStorageSupported() then
                        GameTooltip:AddLine("Native Void item API loaded: both tabs are merged into this grid.",0.55,0.85,0.55,true)
                    elseif NativeVoidStorageSupported(f) then
                        GameTooltip:AddLine("Native Void UI loaded: "..tostring(#f.nativeVoidButtons).." storage slots mirrored into this grid.",0.55,0.85,0.55,true)
                    elseif (f.extBankPacketBytes or 0)>0 then
                        GameTooltip:AddLine("Server state received: "..tostring(f.extBankPacketBytes).." bytes.",0.85,0.75,0.45,true)
                        GameTooltip:AddLine("Packet decode failed: "..tostring(f.extBankDecodeError or "unknown format"),0.9,0.55,0.45,true)
                    else
                        GameTooltip:AddLine("The server state has not been received yet. Click V or reopen the bank to request it.",0.8,0.8,0.8,true)
                    end
                elseif BlizzardVoidStorageSupported() then
                    if not f.voidReady then
                        GameTooltip:AddLine("Open Void Storage to make these slots available here.",0.8,0.8,0.8,true)
                    elseif not QueryVoidStorageUnlocked() then
                        GameTooltip:AddLine("Void Storage is not unlocked for this character.",0.8,0.8,0.8,true)
                    else
                        GameTooltip:AddLine("The two Void Storage tabs are merged into this bank grid.",0.8,0.8,0.8,true)
                    end
                else
                    GameTooltip:AddLine("No supported storage transport was detected.",0.8,0.8,0.8,true)
                end
            else
                GameTooltip:AddLine("Click to include / exclude this container from the unified bank.",0.8,0.8,0.8,true)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        f.filterButtons[def.key]=b
    end

    -- One-click master visibility control. If every container is already shown,
    -- ALL hides them; otherwise it enables every bank bag plus V together.
    f.allFilters=Button(f.body,"ALL",44,22)
    f.allFilters:SetPoint("BOTTOMLEFT",f.body,"BOTTOMLEFT",410,60)
    f.allFilters:SetScript("OnClick",function()
        local enable=not BankAllFiltersEnabled()
        SetAllBankFilters(enable)
        f.rowOffset=0
        if enable and EbonholdExtBankSupported() then PhaseB:RequestExtBank() end
        PhaseB:RefreshBank()
    end)
    f.allFilters:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        if BankAllFiltersEnabled() then
            GameTooltip:SetText("All containers |cff66ff66shown|r")
            GameTooltip:AddLine("Click to hide BNK, bank bags 1-7 and V together.",0.8,0.8,0.8,true)
        else
            GameTooltip:SetText("Activate All")
            GameTooltip:AddLine("Click to show BNK, bank bags 1-7 and V together.",0.8,0.8,0.8,true)
        end
        GameTooltip:Show()
    end)
    f.allFilters:SetScript("OnLeave",function() GameTooltip:Hide() end)

    -- Extended Bank bag management now lives in a compact pop-out instead of
    -- occupying permanent space in the unified Bank footer.  V continues to
    -- show/hide the flattened storage contents; this panel is only for the 70
    -- purchasable bag positions and their unlock state.
    local function PositionExtManager()
        if not f or not f.extManager then return end
        local mgr=f.extManager
        mgr:ClearAllPoints()
        local gap=10
        local width=(mgr.GetWidth and mgr:GetWidth()) or 370
        local left=(f.GetLeft and f:GetLeft()) or 0
        local right=(f.GetRight and f:GetRight()) or 0
        local parentLeft=(UIParent and UIParent.GetLeft and UIParent:GetLeft()) or 0
        local parentRight=(UIParent and UIParent.GetRight and UIParent:GetRight()) or 0
        if right>0 and (right + gap + width) <= (parentRight - 8) then
            mgr:SetPoint("TOPLEFT",f,"TOPRIGHT",gap,0)
        elseif left>0 and (left - gap - width) >= (parentLeft + 8) then
            mgr:SetPoint("TOPRIGHT",f,"TOPLEFT",-gap,0)
        else
            mgr:SetPoint("CENTER",f,"CENTER",0,0)
        end
    end

    f.extManager=CreateFrame("Frame",nil,f)
    f.extManager:SetWidth(370); f.extManager:SetHeight(486)
    PositionExtManager()
    f.extManager:SetClampedToScreen(true)
    f.extManager:SetFrameStrata("FULLSCREEN_DIALOG")
    f.extManager:SetFrameLevel((f:GetFrameLevel() or 1)+40)
    f.extManager:EnableMouse(true); f.extManager:Hide()
    f.extManager:SetScript("OnShow",PositionExtManager)
    RUI:CreateBackdrop(f.extManager); f.extManagerAccent=RUI:CreateAccentLine(f.extManager,2)
    f.extManagerTitle=Text(f.extManager,"Void Storage Bags",14,"TOPLEFT",f.extManager,"TOPLEFT",14,-15,false)
    f.extManagerSub=Text(f.extManager,"Manage Ebonhold Extended Bank bag positions",8,"LEFT",f.extManagerTitle,"RIGHT",10,-1,true)
    f.extManagerClose=Button(f.extManager,"X",26,22); f.extManagerClose:SetPoint("TOPRIGHT",f.extManager,"TOPRIGHT",-9,-9)
    f.extManagerClose:SetScript("OnClick",function() f.RUIKeepExtManagerOpen=nil; f.extManager:Hide() end)
    f.extManagerInfo=Text(f.extManager,"",10,"TOPLEFT",f.extManager,"TOPLEFT",16,-43,true)
    f.extManagerInfo:SetWidth(338); f.extManagerInfo:SetJustifyH("LEFT")
    f.extManagerSlots={}
    local MANAGER_COLS=7
    local MANAGER_SLOT_SIZE=30
    local MANAGER_PITCH=34
    local MANAGER_X=65
    local MANAGER_Y=-68
    for i=1,EXTBANK_CONFIRMED_MAX_SLOTS do
        local b=ItemSlot(f.extManager,MANAGER_SLOT_SIZE); b.index=i
        local col=(i-1)%MANAGER_COLS
        local row=math.floor((i-1)/MANAGER_COLS)
        b:SetPoint("TOPLEFT",f.extManager,"TOPLEFT",MANAGER_X+(col*MANAGER_PITCH),MANAGER_Y-(row*MANAGER_PITCH))
        b.RUIBagNumber=Text(b,tostring(i),7,"TOPLEFT",b,"TOPLEFT",3,-3,false)
        b.RUIPrice=Text(b,"",7,"BOTTOM",b,"BOTTOM",0,2,false)
        b.RUIPrice:SetJustifyH("CENTER")
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnClick",function(self,mouseButton)
            local state=f.extBankState
            local unlocked=tonumber(state and state.unlockedBagSlots) or 0
            local bag=state and state.bagsByIndex and state.bagsByIndex[self.index-1]
            if mouseButton=="RightButton" and self.index<=unlocked and bag then
                SendExtBankMove(EXTBANK_HEADER_BAG,self.index-1,EXTBANK_AUTO_INV,0,0)
                return
            end
            if self.index==unlocked+1 and type(ExtBankUnlock)=="function" then
                ConfirmExtBankUnlock(f)
                return
            end
            f.extManagerSelected=self.index
            PhaseB:RefreshBank()
        end)
        b:SetScript("OnReceiveDrag",function(self)
            local state=f.extBankState
            local unlocked=tonumber(state and state.unlockedBagSlots) or 0
            local src=EXTBANK_CURSOR_SOURCE
            if self.index<=unlocked and src and src.bag and src.slot and src.bag>=0 and src.bag<=4 then
                if SendExtBankMove(src.bag,src.slot,EXTBANK_HEADER_BAG,self.index-1,0) then
                    EXTBANK_CURSOR_SOURCE=nil
                end
            end
        end)
        b:SetScript("OnEnter",function(self)
            local state=f.extBankState
            local unlocked=tonumber(state and state.unlockedBagSlots) or 0
            local bag=state and state.bagsByIndex and state.bagsByIndex[self.index-1]
            SetBankTooltipOwner(self)
            if self.index<=unlocked then
                if bag and bag.itemID and bag.itemID>0 and GameTooltip.SetHyperlink then
                    local link=ExtBankItemLink(bag.itemID)
                    if link then pcall(GameTooltip.SetHyperlink,GameTooltip,link) end
                else
                    GameTooltip:SetText("Void Storage Bag Slot "..tostring(self.index))
                end
                if bag then
                    GameTooltip:AddLine("Installed storage bag • "..tostring(bag.size or 0).." slots",0.65,0.85,0.65,true)
                    GameTooltip:AddLine("Right-click to remove this bag to your inventory",0.8,0.8,0.8,true)
                else
                    GameTooltip:AddLine("Purchased bag position • currently empty",0.65,0.85,0.65,true)
                    GameTooltip:AddLine("Drag a bag here from backpack / bags 1-4",0.8,0.8,0.8,true)
                end
            elseif self.index==unlocked+1 then
                local cost=ExactExtBankSlotCost(self.index)
                GameTooltip:SetText("Purchase Void Storage Bag Slot "..tostring(self.index))
                if cost then GameTooltip:AddLine("Cost: "..Money(cost),1,0.82,0.35,true)
                else GameTooltip:AddLine("Price is controlled by the Ebonhold server.",0.8,0.8,0.8,true) end
                GameTooltip:AddLine("Click this slot or use the purchase button below.",0.8,0.8,0.8,true)
            else
                GameTooltip:SetText("Void Storage Bag Slot "..tostring(self.index))
                local known=ExactExtBankSlotCost(self.index)
                if known then
                    GameTooltip:AddLine("Unlock cost: "..Money(known),1,0.82,0.35,true)
                else
                    GameTooltip:AddLine("Unlock cost: not captured yet",0.75,0.75,0.75,true)
                end
                GameTooltip:AddLine("Locked • purchase the previous position first",0.75,0.75,0.75,true)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        f.extManagerSlots[i]=b
    end
    f.extManagerHint=Text(f.extManager,"The main Bank stays unified; these controls only manage Void Storage bag capacity.",8,"BOTTOMLEFT",f.extManager,"BOTTOMLEFT",16,48,true)
    f.extManagerHint:SetWidth(338); f.extManagerHint:SetJustifyH("CENTER")
    f.extManagerRefresh=Button(f.extManager,"Refresh",86,24)
    f.extManagerRefresh:SetPoint("BOTTOMLEFT",f.extManager,"BOTTOMLEFT",16,14)
    f.extManagerRefresh:SetScript("OnClick",function()
        if EbonholdExtBankSupported() then PhaseB:RequestExtBank() end
    end)
    f.extManagerBuy=Button(f.extManager,"Buy Next Slot",210,24)
    f.extManagerBuy:SetPoint("BOTTOMRIGHT",f.extManager,"BOTTOMRIGHT",-16,14)
    f.extManagerBuy:SetScript("OnClick",function()
        ConfirmExtBankUnlock(f)
    end)
    f.extManager:SetScript("OnShow",function()
        PositionExtManager()
        if EbonholdExtBankSupported() then PhaseB:RequestExtBank() end
        PhaseB:RefreshBank()
    end)

    f.bagLabel=Text(f.body,"Bank bags",9,"BOTTOMLEFT",f.body,"BOTTOMLEFT",2,20,true)
    f.bagSlots={}
    for i=1,7 do
        local bag=BANK_BAG_FIRST+i-1
        local b=ItemSlot(f.body,38); b.bag=bag; b.index=i
        -- Physical bank-bag slots share the exact same columns as the 1-7
        -- visibility toggles above, so bag numbers and icons cannot drift apart.
        b:SetPoint("BOTTOMLEFT",f.body,"BOTTOMLEFT",BANK_BAG_FOOTER_X+(i-1)*BANK_BAG_FOOTER_PITCH,6)
        b.RUIBagNumber=Text(b,tostring(i),8,"TOPLEFT",b,"TOPLEFT",4,-4,false)
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            local purchased=GetNumBankSlots and select(1,GetNumBankSlots()) or 0
            local inv=BankBagInventorySlot(self.bag)
            if self.index<=purchased and inv and GameTooltip.SetInventoryItem and GameTooltip:SetInventoryItem("player",inv) then
            else
                GameTooltip:SetText("Bank Bag Slot "..tostring(self.index))
                if self.index<=purchased then
                    GameTooltip:AddLine("Empty purchased slot - place a bag here.",0.75,0.75,0.75,true)
                elseif self.index==purchased+1 then
                    local cost=GetBankSlotCost and GetBankSlotCost(purchased) or 0
                    GameTooltip:AddLine("Locked - click to purchase for "..Money(cost)..".",0.75,0.75,0.75,true)
                else
                    GameTooltip:AddLine("Locked - purchase the previous bank bag slot first.",0.75,0.75,0.75,true)
                end
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        local function UseBankBagSlot(self)
            local purchased=GetNumBankSlots and select(1,GetNumBankSlots()) or 0
            if self.index>purchased then
                if self.index==purchased+1 then BuyNextBankBagSlot() end
                return
            end
            local inv=BankBagInventorySlot(self.bag)
            if inv and PickupInventoryItem then
                -- Start a short structural refresh before the pickup so the
                -- footer and unified grid remain synchronized as the client
                -- clears/replaces this equipment slot.
                f.RUIBankBagStructurePollRemaining=2.0
                f.RUIBankBagStructurePollElapsed=0
                PickupInventoryItem(inv)
            end
        end
        b:SetScript("OnClick",UseBankBagSlot)
        b:SetScript("OnDragStart",UseBankBagSlot)
        b:SetScript("OnReceiveDrag",UseBankBagSlot)
        f.bagSlots[i]=b
    end

    f.buySlot=Button(f.body,"Buy Next Bank Bag Slot",210,24)
    f.buySlot:SetPoint("BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-2,13)
    f.buySlot:SetScript("OnClick",BuyNextBankBagSlot)
    f.voidTransfer=Button(f.body,"Apply Void Transfer",210,24)
    f.voidTransfer:SetPoint("BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-2,43)
    f.voidTransfer:SetScript("OnClick",ConfirmVoidTransfer)
    f.voidTransfer:Hide()
    f.voidBags=Button(f.body,"Void Storage Bags",210,24)
    f.voidBags:SetPoint("BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-2,43)
    f.voidBags:SetScript("OnClick",function()
        if f.extManager:IsShown() then
            f.RUIKeepExtManagerOpen=nil
            f.extManager:Hide()
        else
            f.RUIKeepExtManagerOpen=true
            if PositionExtManager then PositionExtManager() end
            f.extManager:Show()
        end
    end)
    f.voidBags:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText("Void Storage Bags")
        GameTooltip:AddLine("Open the 70-position Extended Bank bag manager.",0.8,0.8,0.8,true)
        GameTooltip:AddLine("This does not change whether V contents are shown in the unified Bank.",0.65,0.75,0.9,true)
        GameTooltip:Show()
    end)
    f.voidBags:SetScript("OnLeave",function() GameTooltip:Hide() end)
    f.voidBags:Hide()
    f.voidPurchase=Button(f.body,"Buy Extended Bank Slot",210,24)
    f.voidPurchase:SetPoint("BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-2,92)
    f.voidPurchase:SetScript("OnClick",function()
        if f.extBankState and f.extBankState.decoded and type(ExtBankUnlock)=="function" then
            ConfirmExtBankUnlock(f)
            return
        end
        local backing=f.nativeVoidPurchaseButton
        if backing and CallNativeVoidButton(backing,"LeftButton",false) then return end
        if type(ExtBankUnlock)=="function" then pcall(ExtBankUnlock) end
    end)
    f.voidPurchase:Hide()
    f.slotInfo=Text(f.body,"",9,"BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-2,72,true); f.slotInfo:SetWidth(210); f.slotInfo:SetJustifyH("CENTER")
    f.RUIExclusiveClose=function() PhaseB:CloseBankSession("exclusive-panel") end
    f.close:SetScript("OnClick",function()
        PhaseB:CloseBankSession("close-button")
    end)
    f:SetScript("OnHide",function()
        -- Escape/CloseSpecialWindows and other Zen panels can hide the bank
        -- without going through its X button. Close the underlying banker
        -- session in that case so the next interaction can fire BANKFRAME_OPENED.
        if f.bankOpen and not f.RUIBankClosing then
            PhaseB:CloseBankSession("hidden")
        end
    end)
    return f
end

function PhaseB:RefreshBank()
    local f=self.frames.bank; if not f then return end
    if f.sort and f.sort.RUIText then
        local bags=RUI:GetModule("Bags")
        local sorted=bags and bags.IsVisualBankSortEnabled and bags:IsVisualBankSortEnabled()
        f.sort.RUIText:SetText(sorted and "UNSORT" or "SORT")
    end
    if not f.bankOpen and f.extManager and f.extManager:IsShown() then f.extManager:Hide() end
    local cells={}
    local nativeCount=0
    local voidCount=0

    if f.bankOpen then
        for _,def in ipairs(BANK_FILTERS) do
            if def.bag and BankFilterEnabled(def.key) then
                local slots=BankContainerSlotCount(def.bag)
                for slot=1,slots do
                    cells[#cells+1]={kind="bank",bag=def.bag,slot=slot}
                    nativeCount=nativeCount+1
                end
            end
        end
    end

    do
        local bags=RUI:GetModule("Bags")
        if bags and bags.IsVisualBankSortEnabled and bags:IsVisualBankSortEnabled() then
            table.sort(cells,BankVisualCellLess)
        end
    end

    -- Project Ebonhold's current client returns the Extended Bank itself as a
    -- compact raw packet.  Decode and flatten those bag containers first.  This
    -- is the primary path; legacy Blizzard/Bagnon Void APIs remain fallbacks for
    -- other 3.3.5 client variants.
    local extVoidUsable=f.extBankState and f.extBankState.decoded and (f.extBankState.totalCapacity or 0)>0
    local apiVoidUsable=BlizzardVoidStorageSupported() and (f.voidReady or f.extBankReady) and (EbonholdExtBankSupported() or QueryVoidStorageUnlocked())
    local nativeVoidUsable=NativeVoidStorageSupported(f)
    local voidUsable=extVoidUsable or apiVoidUsable or nativeVoidUsable
    if voidUsable and BankFilterEnabled("void") then
        if extVoidUsable then
            for _,bag in ipairs(f.extBankState.bags or {}) do
                for slot=0,(tonumber(bag.size) or 0)-1 do
                    local item=f.extBankState.itemsByPos[tostring(bag.serverBag)..":"..tostring(slot)]
                    cells[#cells+1]={
                        kind="extbank",
                        extBag=bag.serverBag,
                        extSlot=slot,
                        extBagIndex=bag.index,
                        extBagItemID=bag.itemID,
                        extItem=item,
                    }
                    voidCount=voidCount+1
                end
            end
        elseif apiVoidUsable then
            for tab=1,VOID_STORAGE_TABS do
                for slot=1,VOID_STORAGE_SLOTS_PER_TAB do
                    cells[#cells+1]={kind="void",voidTab=tab,voidSlot=slot}
                    voidCount=voidCount+1
                end
            end
        else
            for index,backing in ipairs(f.nativeVoidButtons or {}) do
                cells[#cells+1]={kind="voidnative",voidBacking=backing,voidIndex=index}
                voidCount=voidCount+1
            end
        end
    end
    f.bankCells=cells

    local total=#cells
    local rows=math.ceil(total/BANK_GRID_COLUMNS)
    local maxOffset=math.max(0,rows-BANK_GRID_ROWS)
    f.rowOffset=math.max(0,math.min(maxOffset,f.rowOffset or 0))
    local first=(f.rowOffset*BANK_GRID_COLUMNS)+1
    local last=math.min(total,first+BANK_GRID_CAPACITY-1)

    local searchQuery=""
    if f.search and f.search.GetText then searchQuery=string.lower(f.search:GetText() or "") end
    local visibleIndex=0
    for cellIndex=first,last do
        visibleIndex=visibleIndex+1
        local cell=cells[cellIndex]
        local b=EnsureBankItemButton(f,visibleIndex)
        b.kind=cell.kind; b.bag=cell.bag; b.slot=cell.slot; b.voidTab=cell.voidTab; b.voidSlot=cell.voidSlot; b.voidBacking=cell.voidBacking; b.voidIndex=cell.voidIndex; b.extBag=cell.extBag; b.extSlot=cell.extSlot; b.extItem=cell.extItem; b.extItemID=cell.extItem and cell.extItem.itemID or nil
        b:ClearAllPoints()
        local col=(visibleIndex-1)%BANK_GRID_COLUMNS
        local row=math.floor((visibleIndex-1)/BANK_GRID_COLUMNS)
        b.RUIBankGridRow=row
        b:SetPoint("TOPLEFT",f.grid,"TOPLEFT",10+col*BANK_SLOT_PITCH,-10-row*BANK_SLOT_PITCH)
        local tex,count,locked,filtered
        if cell.kind=="extbank" then
            local item=cell.extItem
            if item and item.itemID and item.itemID>0 then
                tex=ResolveItemTexture(item.itemID)
                count=tonumber(item.count) or 1
            else
                tex=nil
                count=0
            end
        elseif cell.kind=="voidnative" then
            tex=NativeVoidButtonIcon(cell.voidBacking)
            count=tex and 1 or 0
            locked=cell.voidBacking and cell.voidBacking.IsEnabled and not cell.voidBacking:IsEnabled()
        elseif cell.kind=="void" then
            local itemID,texture,isLocked,recent,isFiltered=GetVoidSlotInfo(cell.voidTab,cell.voidSlot)
            tex=texture
            if not tex and itemID and GetItemIcon then tex=GetItemIcon(itemID) end
            count=itemID and 1 or 0
            locked=isLocked
            filtered=isFiltered
        elseif GetContainerItemInfo then
            tex,count,locked=GetContainerItemInfo(cell.bag,cell.slot)
        end
        if searchQuery~="" and not BankSearchMatches(cell,searchQuery) then filtered=true end
        b.icon:SetTexture(tex or "")
        local countText=b.RUICountText
        if countText and countText.SetText then countText:SetText((count or 0)>1 and tostring(count) or "") end
        if filtered then b:SetAlpha(.30) elseif locked then b:SetAlpha(.55) else b:SetAlpha(1) end
        RUI:RefreshBackdrop(b)
        if cell.kind=="extbank" and f.extPickSrc and f.extPickSrc.bag==cell.extBag and f.extPickSrc.slot==cell.extSlot then
            local ar,ag,ab=RUI:GetAccentColor(); RUI:SetBorderColor(b,ar,ag,ab,1)
        end
        b:Show()
    end
    for i=visibleIndex+1,#f.itemButtons do
        local b=f.itemButtons[i]; b.kind=nil; b.bag=nil; b.slot=nil; b.voidTab=nil; b.voidSlot=nil; b.voidBacking=nil; b.voidIndex=nil; b.extBag=nil; b.extSlot=nil; b.extItem=nil; b.extItemID=nil; b.RUIBankGridRow=nil; b.icon:SetTexture(""); local countText=b.RUICountText; if countText and countText.SetText then countText:SetText("") end; b:Hide()
    end

    local num,full=0,false
    if GetNumBankSlots then num,full=GetNumBankSlots() end
    num=tonumber(num) or 0
    local cost=(not full and GetBankSlotCost and GetBankSlotCost(num)) or 0
    for i,b in ipairs(f.bagSlots or {}) do
        local inv=BankBagInventorySlot(b.bag)
        local tex=inv and GetInventoryItemTexture and GetInventoryItemTexture("player",inv)
        b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        local countText=b.RUICountText
        if countText and countText.SetText then countText:SetText("") end
        if i<=num then b:SetAlpha(tex and 1 or .55)
        elseif i==num+1 and not full then b:SetAlpha(.35)
        else b:SetAlpha(.16) end
    end

    local extState=f.extBankState and f.extBankState.decoded and f.extBankState or nil
    local extUnlocked=tonumber(extState and extState.unlockedBagSlots) or 0
    local extMax,extMaxSource=nil,nil
    if extState then extMax,extMaxSource=ExtBankRuntimeMaxSlots(extState) end
    f.extBankDetectedMax=extMax
    f.extBankDetectedMaxSource=extMaxSource

    -- Refresh the optional 70-position management pop-out.  It is independent
    -- from the V visibility filter, so players can manage/purchase bag capacity
    -- without forcing Void Storage contents into the main unified grid.
    if f.extManager then
        if extState then
            if extMax then
                f.extManagerInfo:SetText(tostring(extUnlocked).." / "..tostring(extMax).." Void Storage bag slots purchased")
            else
                f.extManagerInfo:SetText(tostring(extUnlocked).." Void Storage bag slots purchased")
            end
        else
            f.extManagerInfo:SetText("Waiting for Ebonhold Extended Bank data...")
        end
        local nextCost,nextCostSource=nil,nil
        if extState then nextCost,nextCostSource=ExtBankRuntimeUnlockCost(extState) end
        if nextCost and extState then RememberExtBankSlotCost(extUnlocked+1,nextCost,nextCostSource) end
        for i,b in ipairs(f.extManagerSlots or {}) do
            local bag=extState and extState.bagsByIndex and extState.bagsByIndex[i-1]
            local purchased=extState and i<=extUnlocked
            local nextSlot=extState and i==extUnlocked+1 and (not extMax or extUnlocked<extMax)
            b.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
            local countText=b.RUICountText
            if countText and countText.SetText then countText:SetText("") end
            if b.RUIPrice then
                if purchased then
                    b.RUIPrice:SetText("")
                else
                    local price=ExactExtBankSlotCost(i)
                    if nextSlot and nextCost then price=nextCost end
                    b.RUIPrice:SetText(price and (CompactExtBankPrice(price) or "") or "?")
                end
            end
            RUI:RefreshBackdrop(b)
            if purchased then
                if bag and bag.itemID and bag.itemID>0 then
                    b.icon:SetTexture(ResolveItemTexture(bag.itemID) or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
                    b:SetAlpha(1)
                else
                    b:SetAlpha(.52)
                end
            elseif nextSlot then
                b:SetAlpha(.38)
                local ar,ag,ab=RUI:GetAccentColor(); RUI:SetBorderColor(b,ar,ag,ab,1)
            else
                b:SetAlpha(.14)
            end
            if f.extManagerSelected==i and purchased then
                local ar,ag,ab=RUI:GetAccentColor(); RUI:SetBorderColor(b,ar,ag,ab,1)
            end
            b:Show()
        end
        local canBuy=extState and type(ExtBankUnlock)=="function" and (not extMax or extUnlocked<extMax)
        if canBuy then
            local nextSlot=extUnlocked+1
            if nextCost then
                f.extManagerBuy.RUIText:SetText("Buy Slot "..tostring(nextSlot).."  "..Money(nextCost))
                if GetMoney and GetMoney()<nextCost then f.extManagerBuy:SetAlpha(.55) else f.extManagerBuy:SetAlpha(1) end
            else
                f.extManagerBuy.RUIText:SetText("Buy Slot "..tostring(nextSlot))
                f.extManagerBuy:SetAlpha(1)
            end
            f.extManagerBuy:Enable()
        else
            if extState and extMax and extUnlocked>=extMax then
                f.extManagerBuy.RUIText:SetText("All "..tostring(extMax).." slots purchased")
            else
                f.extManagerBuy.RUIText:SetText("Buy Next Slot")
            end
            f.extManagerBuy:SetAlpha(.45); f.extManagerBuy:Disable()
        end
    end

    local ar,ag,ab=RUI:GetAccentColor()
    for _,def in ipairs(BANK_FILTERS) do
        local b=f.filterButtons and f.filterButtons[def.key]
        if b then
            local available=true
            if def.void then available=EbonholdExtBankSupported() or voidUsable
            elseif def.bag then
                local index=(def.bag==BANK_ID) and 0 or (def.bag-BANK_BAG_FIRST+1)
                available=f.bankOpen and (index==0 or index<=num)
            end
            if BankFilterEnabled(def.key) and available then
                b:SetAlpha(1); RUI:SetBorderColor(b,ar,ag,ab,1)
            elseif BankFilterEnabled(def.key) then
                b:SetAlpha(.28); RUI:RefreshBackdrop(b)
            else
                b:SetAlpha(.42); RUI:RefreshBackdrop(b)
            end
        end
    end
    if f.allFilters then
        if BankAllFiltersEnabled() then
            f.allFilters.RUIText:SetText("ALL"); f.allFilters:SetAlpha(1); RUI:SetBorderColor(f.allFilters,ar,ag,ab,1)
        else
            f.allFilters.RUIText:SetText("ALL"); f.allFilters:SetAlpha(.55); RUI:RefreshBackdrop(f.allFilters)
        end
    end
    if f.voidBags then
        local showManager=f.bankOpen and EbonholdExtBankSupported()
        ShowIf(f.voidBags,showManager)
        if showManager and f.extManager and f.extManager:IsShown() then
            RUI:SetBorderColor(f.voidBags,ar,ag,ab,1); f.voidBags:SetAlpha(1)
        elseif showManager then
            RUI:RefreshBackdrop(f.voidBags); f.voidBags:SetAlpha(.9)
        end
    end

    local owner=UnitName("NPC") or (f.voidReady and "Void Storage" or "Bank")
    f.owner:SetText(owner.."  •  Unified storage")
    local scrollText=maxOffset>0 and ("  •  rows "..tostring(f.rowOffset+1).."-"..tostring(math.min(rows,f.rowOffset+BANK_GRID_ROWS)).." / "..tostring(rows)) or ""
    local summary={}
    if f.bankOpen then summary[#summary+1]=tostring(nativeCount).." bank" end
    if voidUsable then
        summary[#summary+1]=tostring(voidCount).." void"
    elseif EbonholdExtBankSupported() then
        if (f.extBankPacketBytes or 0)>0 then summary[#summary+1]="Ext data "..tostring(f.extBankPacketBytes).."B" else summary[#summary+1]="Ext data pending" end
    elseif BlizzardVoidStorageSupported() and f.voidReady then
        summary[#summary+1]="Void locked"
    end
    if #summary==0 then
        summary[1]=tostring(total).." slots"
    else
        for i=1,#summary do
            if string.find(summary[i]," bank$") or string.find(summary[i]," void$") then summary[i]=summary[i].." slots" end
        end
    end
    f.summary:SetText(table.concat(summary,"  +  ")..scrollText)

    if full then
        f.slotInfo:SetText("All 7 bank bag slots purchased")
        ShowIf(f.buySlot,false)
    else
        f.buySlot.RUIText:SetText("Buy Next Slot  "..Money(cost))
        f.slotInfo:SetText(tostring(num).." / 7 bank bag slots purchased")
        ShowIf(f.buySlot,f.bankOpen)
        if GetMoney and GetMoney()<cost then f.buySlot:SetAlpha(.55) else f.buySlot:SetAlpha(1) end
    end

    local deposits=voidUsable and type(GetNumVoidTransferDeposit)=="function" and (tonumber(GetNumVoidTransferDeposit()) or 0) or 0
    local withdrawals=voidUsable and type(GetNumVoidTransferWithdrawal)=="function" and (tonumber(GetNumVoidTransferWithdrawal()) or 0) or 0
    local pending=deposits+withdrawals
    if pending>0 then
        local transferCost=type(GetVoidTransferCost)=="function" and (tonumber(GetVoidTransferCost()) or 0) or 0
        f.voidTransfer.RUIText:SetText("Apply Void Transfer  "..Money(transferCost))
        ShowIf(f.voidTransfer,true)
        ShowIf(f.voidPurchase,false)
        f.slotInfo:SetText(tostring(deposits).." deposit  •  "..tostring(withdrawals).." withdraw")
    else
        ShowIf(f.voidTransfer,false)
        -- Extended Bank purchases are intentionally kept out of the unified
        -- Bank footer.  The dedicated Void Storage Bags pop-out owns all of the
        -- 70-position capacity/purchase controls.  Preserve the legacy native
        -- Blizzard Void purchase proxy only when Ebonhold ExtBank is absent.
        if EbonholdExtBankSupported() then
            ShowIf(f.voidPurchase,false)
        else
            local purchase=f.nativeVoidPurchaseButton
            local purchaseVisible=false
            if purchase then
                local shown=true
                if purchase.IsShown then local ok,v=pcall(purchase.IsShown,purchase); if ok then shown=v and true or false end end
                local enabled=true
                if purchase.IsEnabled then local ok,v=pcall(purchase.IsEnabled,purchase); if ok then enabled=v and true or false end end
                purchaseVisible=shown and enabled and true or false
                local label=purchase.GetText and purchase:GetText()
                if label and label~="" then f.voidPurchase.RUIText:SetText(label) else f.voidPurchase.RUIText:SetText("Purchase Void Storage") end
            end
            ShowIf(f.voidPurchase,purchaseVisible)
        end
    end
end

-- -------------------------------------------------------------------------
-- Trade
-- -------------------------------------------------------------------------
local function CopperToTradeFields(copper)
    copper=math.max(0,math.floor(tonumber(copper) or 0))
    local gold=math.floor(copper/10000)
    local silver=math.floor((copper%10000)/100)
    local copperOnly=copper%100
    return gold,silver,copperOnly
end

local function TradeFieldsToCopper(f)
    local gold=math.max(0,math.floor(tonumber(f.tradeGold:GetText()) or 0))
    local silver=math.max(0,math.min(99,math.floor(tonumber(f.tradeSilver:GetText()) or 0)))
    local copper=math.max(0,math.min(99,math.floor(tonumber(f.tradeCopper:GetText()) or 0)))
    local amount=(gold*10000)+(silver*100)+copper
    if GetMoney then amount=math.min(amount,tonumber(GetMoney()) or amount) end
    return amount
end

-- Stock Wrath keeps a dedicated TARGET_TRADE MoneyFrame alive beside the
-- TradeFrame. Ebonhold can deliver TRADE_MONEY_CHANGED before
-- GetTargetTradeMoney() has converged for addon listeners, so Zen mirrors the
-- native frame as a second authoritative source and performs a short, bounded
-- event-driven recheck. This is intentionally not a permanent OnUpdate poll.
local function ReadNativeTargetTradeMoney()
    local direct=0
    if type(GetTargetTradeMoney)=="function" then
        local ok,value=pcall(GetTargetTradeMoney)
        if ok then direct=math.max(0,tonumber(value) or 0) end
    end

    local native=0
    local moneyFrame=_G.TradeRecipientMoneyFrame
    if moneyFrame then
        -- Refresh Blizzard's invisible authoritative money frame when possible.
        -- Its staticMoney field is the exact copper value last rendered.
        if type(MoneyFrame_UpdateMoney)=="function" and moneyFrame.info then
            pcall(MoneyFrame_UpdateMoney,moneyFrame)
        end
        native=math.max(0,tonumber(moneyFrame.staticMoney) or 0)

        -- Defensive fallback for clients that do not retain staticMoney.
        if native<=0 then
            local function CoinText(name)
                local fs=_G[name]
                if not fs or type(fs.GetText)~="function" then return 0 end
                local ok,text=pcall(fs.GetText,fs)
                if not ok or not text then return 0 end
                local digits=tostring(text):gsub("[^0-9]","")
                return tonumber(digits) or 0
            end
            local g=CoinText("TradeRecipientMoneyFrameGoldButtonText")
            local s=CoinText("TradeRecipientMoneyFrameSilverButtonText")
            local c=CoinText("TradeRecipientMoneyFrameCopperButtonText")
            native=(g*10000)+(s*100)+c
        end
    end

    return math.max(direct,native)
end

function PhaseB:SetTradeMoneyFromFields()
    local f=self.frames and self.frames.trade
    if not f or f.tradeMoneyUpdating or not SetTradeMoney then return end
    SetTradeMoney(TradeFieldsToCopper(f))
end

local function CreateTradeAcceptedVisual(parent)
    -- Keep acceptance feedback unmistakable without replacing the native trade
    -- state machine.  Textures do not intercept clicks, so the item/enchant
    -- slots remain fully interactive while the side is highlighted.
    local visual={}
    visual.fill=parent:CreateTexture(nil,"BACKGROUND",nil,2)
    visual.fill:SetPoint("TOPLEFT",parent,"TOPLEFT",2,-2)
    visual.fill:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-2,2)
    visual.fill:SetTexture(0.10,0.85,0.28,0.12)
    visual.fill:Hide()

    visual.border={}
    local top=parent:CreateTexture(nil,"OVERLAY"); top:SetTexture(0.20,1.00,0.35,0.95); top:SetHeight(2); top:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0); top:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,0)
    local bottom=parent:CreateTexture(nil,"OVERLAY"); bottom:SetTexture(0.20,1.00,0.35,0.95); bottom:SetHeight(2); bottom:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",0,0); bottom:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,0)
    local left=parent:CreateTexture(nil,"OVERLAY"); left:SetTexture(0.20,1.00,0.35,0.95); left:SetWidth(2); left:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0); left:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",0,0)
    local right=parent:CreateTexture(nil,"OVERLAY"); right:SetTexture(0.20,1.00,0.35,0.95); right:SetWidth(2); right:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,0); right:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,0)
    visual.border[1]=top; visual.border[2]=bottom; visual.border[3]=left; visual.border[4]=right
    for _,tex in ipairs(visual.border) do tex:Hide() end

    visual.label=Text(parent,"ACCEPTED",10,"TOPRIGHT",parent,"TOPRIGHT",-10,-11,false)
    visual.label:SetTextColor(0.35,1.00,0.45,1)
    visual.label:Hide()
    return visual
end

local function SetTradeAcceptedVisual(visual,accepted)
    if not visual then return end
    if accepted then
        visual.fill:Show()
        for _,tex in ipairs(visual.border) do tex:Show() end
        visual.label:Show()
    else
        visual.fill:Hide()
        for _,tex in ipairs(visual.border) do tex:Hide() end
        visual.label:Hide()
    end
end

local function TradeAcceptedValue(value)
    -- Stock clients commonly use 1/0 here, while some Ebonhold paths have
    -- surfaced boolean-like values.  Accept both forms instead of requiring
    -- the numeric representation.
    if value==true or value==1 or value=="1" then return true end
    return false
end

function PhaseB:CreateTrade()
    local f=Panel("ZenUITradeFrame","trade","Trade"); self.frames.trade=f; f.playerAccepted=false; f.targetAccepted=false
    f.left=CreateFrame("Frame",nil,f.body); f.left:SetPoint("TOPLEFT",2,-2); f.left:SetWidth(315); f.left:SetPoint("BOTTOMLEFT",2,52); RUI:CreateBackdrop(f.left)
    f.right=CreateFrame("Frame",nil,f.body); f.right:SetPoint("TOPRIGHT",-2,-2); f.right:SetWidth(315); f.right:SetPoint("BOTTOMRIGHT",-2,52); RUI:CreateBackdrop(f.right)
    f.leftAccepted=CreateTradeAcceptedVisual(f.left)
    f.rightAccepted=CreateTradeAcceptedVisual(f.right)
    f.playerName=Text(f.left,"You",13,"TOPLEFT",f.left,"TOPLEFT",12,-12,false); f.targetName=Text(f.right,"Trader",13,"TOPLEFT",f.right,"TOPLEFT",12,-12,false)
    f.playerItems={}; f.targetItems={}
    for i=1,7 do
        local y=-42-((i-1)*49)
        local p=ItemSlot(f.left,38); p:SetPoint("TOPLEFT",f.left,"TOPLEFT",12,y); p.index=i; p.name=Text(f.left,"",10,"TOPLEFT",f.left,"TOPLEFT",60,y-3,false)
        -- Match stock Wrath PlayerTradeItemTemplate behavior.  The special
        -- seventh trade slot is the non-traded/enchant slot, so preserving the
        -- native ClickTradeButton path is important for enchants and other item
        -- modifications as well as ordinary trade items.
        p:RegisterForDrag("LeftButton")
        p:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            if GameTooltip.SetTradePlayerItem then GameTooltip:SetTradePlayerItem(self.index) end
            if CursorUpdate then CursorUpdate(self) end
            -- Only the hovered trade slot needs live tooltip/cursor maintenance.
            -- Running OnUpdate on all fourteen custom trade buttons every frame
            -- was unnecessary overhead introduced in 0.9.142.
            self:SetScript("OnUpdate",function(button)
                if GameTooltip:IsOwned(button) and GameTooltip.SetTradePlayerItem then
                    GameTooltip:SetTradePlayerItem(button.index)
                end
                if CursorOnUpdate then CursorOnUpdate(button) end
            end)
        end)
        p:SetScript("OnLeave",function(self)
            self:SetScript("OnUpdate",nil)
            GameTooltip:Hide()
            if ResetCursor then ResetCursor() end
        end)
        p:SetScript("OnClick",function(self,button)
            local link=GetTradePlayerItemLink and GetTradePlayerItemLink(self.index)
            if IsModifiedClick and IsModifiedClick() and link and HandleModifiedItemClick then
                HandleModifiedItemClick(link)
            elseif ClickTradeButton then
                ClickTradeButton(self.index,button=="RightButton")
            end
        end)
        p:SetScript("OnDragStart",function(self) if ClickTradeButton then ClickTradeButton(self.index) end end)
        p:SetScript("OnReceiveDrag",function(self) if ClickTradeButton then ClickTradeButton(self.index) end end)
        f.playerItems[i]=p

        local t=ItemSlot(f.right,38); t:SetPoint("TOPLEFT",f.right,"TOPLEFT",12,y); t.index=i; t.name=Text(f.right,"",10,"TOPLEFT",f.right,"TOPLEFT",60,y-3,false)
        -- Stock RecipientTradeItemTemplate calls ClickTargetTradeButton here.
        -- Zen's old replacement omitted this entirely, which meant a targeted
        -- enchant/item modification could never be applied to the other
        -- player's non-traded slot.
        t:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            if GameTooltip.SetTradeTargetItem then GameTooltip:SetTradeTargetItem(self.index) end
            if CursorUpdate then CursorUpdate(self) end
            self:SetScript("OnUpdate",function(button)
                if GameTooltip:IsOwned(button) and GameTooltip.SetTradeTargetItem then
                    GameTooltip:SetTradeTargetItem(button.index)
                end
                if CursorOnUpdate then CursorOnUpdate(button) end
            end)
        end)
        t:SetScript("OnLeave",function(self)
            self:SetScript("OnUpdate",nil)
            GameTooltip:Hide()
            if ResetCursor then ResetCursor() end
        end)
        t:SetScript("OnClick",function(self)
            local link=GetTradeTargetItemLink and GetTradeTargetItemLink(self.index)
            if IsModifiedClick and IsModifiedClick() and link and HandleModifiedItemClick then
                HandleModifiedItemClick(link)
            elseif ClickTargetTradeButton then
                ClickTargetTradeButton(self.index)
            end
        end)
        f.targetItems[i]=t
    end

    -- Stock Wrath's money offer is part of TradeFrame, so suppressing that frame
    -- without recreating these controls made Zen trades item-only.  Keep the
    -- native SetTradeMoney/Get*TradeMoney backend and provide normal g/s/c entry.
    f.moneyLabel=Text(f.left,"Your money offer",9,"BOTTOMLEFT",f.left,"BOTTOMLEFT",12,43,true)
    f.tradeGold=Edit(f.left,72,24,"Gold"); f.tradeGold:SetPoint("BOTTOMLEFT",f.left,"BOTTOMLEFT",12,10)
    f.tradeSilver=Edit(f.left,58,24,"Silver"); f.tradeSilver:SetPoint("LEFT",f.tradeGold,"RIGHT",6,0)
    f.tradeCopper=Edit(f.left,58,24,"Copper"); f.tradeCopper:SetPoint("LEFT",f.tradeSilver,"RIGHT",6,0)
    for _,box in ipairs({f.tradeGold,f.tradeSilver,f.tradeCopper}) do
        if box.SetNumeric then box:SetNumeric(true) end
        box:SetMaxLetters(8)
        box:SetScript("OnEnterPressed",function(self) PhaseB:SetTradeMoneyFromFields(); self:ClearFocus() end)
        if box.HookScript then box:HookScript("OnEditFocusLost",function() PhaseB:SetTradeMoneyFromFields() end) end
    end
    f.clearMoney=Button(f.left,"Clear",48,24); f.clearMoney:SetPoint("LEFT",f.tradeCopper,"RIGHT",6,0)
    f.clearMoney:SetScript("OnClick",function()
        if SetTradeMoney then SetTradeMoney(0) end
        PhaseB:RefreshTrade()
    end)
    f.targetMoney=Text(f.right,"Partner money: 0",10,"BOTTOMLEFT",f.right,"BOTTOMLEFT",12,18,false)

    f.accept=Button(f.body,"Accept",130,26); f.accept:SetPoint("BOTTOMLEFT",f.body,"BOTTOMLEFT",2,8)
    f.cancel=Button(f.body,"Cancel",100,26); f.cancel:SetPoint("LEFT",f.accept,"RIGHT",8,0)
    f.status=Text(f.body,"",10,"RIGHT",f.body,"BOTTOMRIGHT",-2,20,true)
    f.accept:SetScript("OnClick",function() if f.playerAccepted and CancelTradeAccept then CancelTradeAccept() elseif AcceptTrade then AcceptTrade() end end)
    f.cancel:SetScript("OnClick",function() if CloseTrade then CloseTrade() end end)
    f.body:SetScript("OnMouseUp",function()
        if CursorHasItem and CursorHasItem() then
            for i=1,6 do local name=GetTradePlayerItemInfo(i); if not name and ClickTradeButton then ClickTradeButton(i); break end end
        elseif GetCursorMoney and GetCursorMoney()>0 and AddTradeMoney then
            AddTradeMoney()
        end
    end)
    f.close:SetScript("OnClick",function() if CloseTrade then CloseTrade() else f:Hide() end end)
    return f
end

function PhaseB:RefreshTrade()
    local f=self.frames.trade; if not f then return end
    f.playerName:SetText(UnitName("player") or "You"); f.targetName:SetText(UnitName("NPC") or "Trade Partner")
    for i=1,7 do
        local name,tex,count,usable,enchant=GetTradePlayerItemInfo(i); local p=f.playerItems[i]
        p.icon:SetTexture(tex or ""); SetItemSlotCount(p,(count or 0)>1 and tostring(count) or ""); p.name:SetText(i==7 and (enchant or name or "Enchant slot") or (name or ""))
        local tn,tt,tc,quality,tusable,tenchant=GetTradeTargetItemInfo(i); local t=f.targetItems[i]
        t.icon:SetTexture(tt or ""); SetItemSlotCount(t,(tc or 0)>1 and tostring(tc) or ""); t.name:SetText(i==7 and (tenchant or tn or "Enchant slot") or (tn or ""))
    end
    local playerMoney=type(GetPlayerTradeMoney)=="function" and (tonumber(GetPlayerTradeMoney()) or 0) or 0
    local targetMoney=ReadNativeTargetTradeMoney()
    -- Some Ebonhold builds include the new copper value as an event argument.
    -- Use that only during the short money-sync window and never as a long-term
    -- cached value, so removing money cannot leave a stale offer displayed.
    if (f.tradeMoneySyncRemaining or 0)>0 and tonumber(f.targetMoneyEventHint) then
        targetMoney=math.max(targetMoney,math.max(0,tonumber(f.targetMoneyEventHint) or 0))
    end
    local hasFocus=(f.tradeGold.HasFocus and f.tradeGold:HasFocus()) or (f.tradeSilver.HasFocus and f.tradeSilver:HasFocus()) or (f.tradeCopper.HasFocus and f.tradeCopper:HasFocus())
    if not hasFocus then
        local g,si,c=CopperToTradeFields(playerMoney)
        f.tradeMoneyUpdating=true
        f.tradeGold:SetText(g>0 and tostring(g) or "")
        f.tradeSilver:SetText(si>0 and tostring(si) or "")
        f.tradeCopper:SetText(c>0 and tostring(c) or "")
        f.tradeMoneyUpdating=nil
    end
    f.targetMoney:SetText("Partner money: "..Money(targetMoney))
    if f.targetMoney.SetTextColor then
        if targetMoney>0 then f.targetMoney:SetTextColor(0.35,1.0,0.35)
        else f.targetMoney:SetTextColor(0.82,0.82,0.82) end
    end
    f.accept.RUIText:SetText(f.playerAccepted and "Undo Accept" or "Accept")
    SetTradeAcceptedVisual(f.leftAccepted,f.playerAccepted)
    SetTradeAcceptedVisual(f.rightAccepted,f.targetAccepted)
    f.status:SetText((f.playerAccepted and "You accepted" or "Waiting").."  •  "..(f.targetAccepted and "Partner accepted" or "Partner waiting"))
end

function PhaseB:ScheduleTradeMoneySync(eventValue)
    local f=self.frames and self.frames.trade
    if not f or not f:IsShown() then return end

    if tonumber(eventValue) then
        f.targetMoneyEventHint=math.max(0,tonumber(eventValue) or 0)
    else
        f.targetMoneyEventHint=nil
    end

    -- Recheck for half a second at a low cadence. Ebonhold has a few custom
    -- trade paths where the API value settles just after TRADE_MONEY_CHANGED.
    f.tradeMoneySyncRemaining=0.55
    f.tradeMoneySyncElapsed=0
    f:SetScript("OnUpdate",function(frame,elapsed)
        frame.tradeMoneySyncRemaining=math.max(0,(frame.tradeMoneySyncRemaining or 0)-(tonumber(elapsed) or 0))
        frame.tradeMoneySyncElapsed=(frame.tradeMoneySyncElapsed or 0)+(tonumber(elapsed) or 0)
        if frame.tradeMoneySyncElapsed>=0.10 then
            frame.tradeMoneySyncElapsed=0
            if frame:IsShown() then PhaseB:RefreshTrade() end
        end
        if frame.tradeMoneySyncRemaining<=0 then
            frame.targetMoneyEventHint=nil
            frame.tradeMoneySyncElapsed=0
            frame:SetScript("OnUpdate",nil)
            if frame:IsShown() then PhaseB:RefreshTrade() end
        end
    end)
end

-- -------------------------------------------------------------------------
-- Overrides / events / lifecycle
-- -------------------------------------------------------------------------
function PhaseB:InstallCombatMenuBindings()
    if not RUI.RegisterCombatMenuRoute then return end

    local enabled=Enabled("character")
    RUI:RegisterCombatMenuRoute("CharacterEquipment","TOGGLECHARACTER0",function()
        PhaseB:ToggleCharacter("PaperDollFrame")
    end,enabled)
    RUI:RegisterCombatMenuRoute("CharacterSkills","TOGGLECHARACTER1",function()
        PhaseB:ToggleCharacter("SkillFrame")
    end,enabled)
    RUI:RegisterCombatMenuRoute("CharacterReputation","TOGGLECHARACTER2",function()
        PhaseB:ToggleCharacter("ReputationFrame")
    end,enabled)
    RUI:RegisterCombatMenuRoute("CharacterCurrency","TOGGLECURRENCY",function()
        PhaseB:ToggleCharacter("TokenFrame")
    end,enabled)

    -- Own the L binding as well.  Out of combat ToggleQuestLog still mirrors
    -- the stock QuestLogFrame lifecycle for companion-addon compatibility; in
    -- combat it toggles the already-created Zen frame directly so the protected
    -- Blizzard panel path cannot block access to the quest log.
    RUI:RegisterCombatMenuRoute("QuestLog","TOGGLEQUESTLOG",function()
        PhaseB:ToggleQuestLog()
    end,Enabled("quest"))
end

function PhaseB:InstallOverrides()
    if not self.ruiToggleCharacter then self.ruiToggleCharacter=function(tab) if Enabled("character") then return PhaseB:ToggleCharacter(tab or "PaperDollFrame") elseif PhaseB.originalToggleCharacter then return PhaseB.originalToggleCharacter(tab) end end end
    if _G.ToggleCharacter~=self.ruiToggleCharacter then self.originalToggleCharacter=_G.ToggleCharacter; _G.ToggleCharacter=self.ruiToggleCharacter end
    -- IMPORTANT: do not replace _G.ToggleQuestLog. Wrath's L binding calls
    -- ToggleFrame(QuestLogFrame) directly, and companion addons may own or
    -- wrap ToggleQuestLog themselves. The native QuestLogFrame lifecycle is
    -- the compatibility bridge.
    if QuestLogFrame and QuestLogFrame.HookScript and not QuestLogFrame.RUIPhaseBHook then
        QuestLogFrame.RUIPhaseBHook=true
        -- Save native presentation once, then keep it suppressed for as long
        -- as the Zen replacement is enabled (including while hidden).
        self:RememberQuestNativeState(QuestLogFrame)
        if Enabled("quest") then self:SuppressNativeQuestLog(QuestLogFrame) end

        QuestLogFrame:HookScript("OnShow",function(stock)
            if not Enabled("quest") then return end
            PhaseB:SuppressNativeQuestLog(stock)
            if not PhaseB.frames.quest:IsShown() then
                PhaseB.questCompatTransition=true
                PhaseB:HideOthers(PhaseB.frames.quest)
                PhaseB.frames.quest:Show()
                PhaseB.questCompatTransition=nil
            end
            PhaseB:RefreshQuestLog()
        end)

        QuestLogFrame:HookScript("OnHide",function(stock)
            if not Enabled("quest") then return end
            -- A second L press hides this exact native frame. Mirror that
            -- authoritative close into Zen. Keep the native presentation
            -- suppressed so its next Show cannot flash stock artwork.
            if not PhaseB.questCompatTransition and PhaseB.frames.quest and PhaseB.frames.quest:IsShown() then
                PhaseB.questCompatTransition=true
                PhaseB.frames.quest:Hide()
                PhaseB.questCompatTransition=nil
            end
            PhaseB:SuppressNativeQuestLog(stock)
        end)
    end
    self:InstallQuestTrackerBridge()

    -- Guard the stock quest-detail panel as well.  Tracker clicks, map POIs or
    -- companion addons may call QuestLog_OpenToQuest directly; when Zen's
    -- replacement is enabled, mirror the current native selection into
    -- Zen instead of allowing Blizzard's detail artwork to appear.
    if QuestLogDetailFrame and QuestLogDetailFrame.HookScript and not QuestLogDetailFrame.RUIPhaseBHook then
        QuestLogDetailFrame.RUIPhaseBHook=true
        QuestLogDetailFrame:HookScript("OnShow",function(stock)
            if not Enabled("quest") then return end
            local selected=GetQuestLogSelection and GetQuestLogSelection() or 0
            stock:Hide()
            if selected and selected>0 then PhaseB:OpenQuestLogEntry(selected) end
        end)
    end

    if MailFrame and MailFrame.HookScript and not MailFrame.RUIPhaseBHook then MailFrame.RUIPhaseBHook=true; MailFrame:HookScript("OnShow",function(stock) if Enabled("mail") then Suppress(stock) end end) end
    if MerchantFrame and MerchantFrame.HookScript and not MerchantFrame.RUIPhaseBHook then MerchantFrame.RUIPhaseBHook=true; MerchantFrame:HookScript("OnShow",function(stock) if Enabled("merchant") then Suppress(stock) end end) end
    if BankFrame and BankFrame.HookScript and not BankFrame.RUIPhaseBHook then BankFrame.RUIPhaseBHook=true; BankFrame:HookScript("OnShow",function(stock) if Enabled("bank") then Suppress(stock) end end) end
    if TradeFrame and TradeFrame.HookScript and not TradeFrame.RUIPhaseBHook then TradeFrame.RUIPhaseBHook=true; TradeFrame:HookScript("OnShow",function(stock) if Enabled("trade") then Suppress(stock) end end) end
end

function PhaseB:ApplySettings()
    for key,info in pairs(INFO) do local on=Enabled(key); RUI:SetMoverEnabled(info.mover,on); self:ApplyScale(key); if not on and self.frames[key] and self.frames[key]:IsShown() then self.frames[key]:Hide() end end
    if Enabled("quest") then
        if QuestLogFrame then self:SuppressNativeQuestLog(QuestLogFrame) end
    else
        -- If the replacement is disabled, return the native frame to its
        -- original appearance/input state. If it is logically open it will
        -- immediately become the visible Blizzard Quest Log again.
        self:RestoreNativeQuestLog(QuestLogFrame)
    end
    if not Enabled("mail") then Restore(MailFrame) end; if not Enabled("merchant") then Restore(MerchantFrame) end; if not Enabled("bank") then Restore(BankFrame); Restore(_G.VoidStorageFrame) end; if not Enabled("trade") then Restore(TradeFrame) end
    self:InstallCombatMenuBindings()
end
function PhaseB:OnScaleChanged(key) for k,i in pairs(INFO) do if key=="all" or key==i.scale then self:ApplyScale(k) end end end
function PhaseB:OnAppearance() for k,f in pairs(self.frames) do RUI:RefreshBackdrop(f); RUI:SetAccentTexture(f.accent); self:ApplyScale(k) end; local cf=self.frames and self.frames.character; if cf and cf.setManager then RUI:RefreshBackdrop(cf.setManager); RUI:SetAccentTexture(cf.setManager.accent) end; self:RefreshCharacter(); self:RefreshQuestLog(); if self.frames.mail:IsShown() then self:RefreshMail() end; if self.frames.merchant:IsShown() then self:RefreshMerchant() end; if self.frames.bank:IsShown() then self:RefreshBank() end; if self.frames.trade:IsShown() then self:RefreshTrade() end end

function PhaseB:OnEvent(event,...)
    if event=="UPDATE_BINDINGS" or event=="PLAYER_REGEN_ENABLED" then
        self:InstallCombatMenuBindings()
        if event=="PLAYER_REGEN_ENABLED" then
            self:UpdateCharacterSecureItemTargets()
            if self.questCombatDirect and Enabled("quest") then
                local q=self.frames and self.frames.quest
                self.questCombatDirect=nil
                if q and q:IsShown() then self:SetNativeQuestLogShown(true) else self:SetNativeQuestLogShown(false) end
            end
        end
        return
    end
    if event=="CURSOR_UPDATE" then
        self:UpdateCharacterSecureItemTargets()
        return
    end
    if event=="EQUIPMENT_SETS_CHANGED" then
        local cf=self.frames and self.frames.character
        if cf and cf.setManager and cf.setManager:IsShown() then self:RefreshEquipmentSetManager() end
        return
    end
    if event=="ADDON_LOADED" or event=="PLAYER_LOGIN" then
        self:InstallOverrides(); self:InstallExtBankBridge(); self:InstallExtBankMoveTrace()
        if event=="ADDON_LOADED" then
            local addonName=...
            if addonName=="Blizzard_VoidStorageUI" or addonName=="Bagnon_VoidStorage" or addonName=="Ebonhold_VoidStorage" or addonName=="Ebonhold_ExtBank" then
                self:DiscoverNativeVoidStorageButtons()
            end
        end
        return
    end
    if event=="PLAYER_EQUIPMENT_CHANGED" or event=="UNIT_STATS" or event=="PLAYER_LEVEL_UP" or event=="UPDATE_FACTION" or event=="SKILL_LINES_CHANGED" or event=="CURRENCY_DISPLAY_UPDATE" or event=="UNIT_ATTACK_POWER" or event=="UNIT_RANGED_ATTACK_POWER" or event=="UNIT_DAMAGE" or event=="UNIT_RANGEDDAMAGE" or event=="UNIT_RESISTANCES" or event=="COMBAT_RATING_UPDATE" or event=="UNIT_MAXHEALTH" or event=="UNIT_HEALTH" or event=="UNIT_MANA" or event=="UNIT_RAGE" or event=="UNIT_ENERGY" or event=="UNIT_RUNIC_POWER" or event=="UNIT_DISPLAYPOWER" then
        local unit=...
        if string.sub(event,1,5)=="UNIT_" and unit and unit~="player" then return end
        if event=="PLAYER_EQUIPMENT_CHANGED" and self.frames.character and self.frames.character.model then
            self.frames.character.modelNeedsUnitRefresh=true
        end
        if self.frames.character:IsShown() then self:RefreshCharacter() end; return
    end
    if event=="KNOWN_TITLES_UPDATE" or event=="UNIT_NAME_UPDATE" then
        local unit=...
        if event=="UNIT_NAME_UPDATE" and unit and unit~="player" then return end
        if self.frames.character:IsShown() and self.frames.character.mode=="titles" then self:RefreshCharacter() end
        return
    end
    if event=="QUEST_LOG_UPDATE" or event=="QUEST_WATCH_UPDATE" then if self.frames.quest:IsShown() then self:RefreshQuestLog() end; return end
    if event=="MAIL_SHOW" then
        RememberCurrentMailCharacter()
        local mailFrame=self.frames.mail
        local zenMail=Enabled("mail")
        mailFrame.sessionStartMoney=zenMail and (GetMoney and GetMoney() or 0) or nil; mailFrame.mailSelection={}; mailFrame.selectionMode=false; mailFrame.lastMailCheck=nil; mailFrame.pendingRecipient=nil
        if zenMail then Suppress(MailFrame); self:HideOthers(mailFrame); mailFrame:Show(); if CheckInbox then CheckInbox() end; self:SetMailMode("inbox") end
        return
    end
    if event=="MAIL_CLOSED" then
        local mailFrame=self.frames.mail
        if SetSendMailShowing then SetSendMailShowing(false) end
        if mailFrame.batch then self:FinishMailBatch(true) end
        mailFrame.mailBusy=false; mailFrame.pendingRecipient=nil
        if mailFrame.collectGold then mailFrame.collectGold.RUIText:SetText("Collect Gold") end
        local startMoney=tonumber(mailFrame.sessionStartMoney)
        if startMoney then
            local gained=(GetMoney and GetMoney() or 0)-startMoney
            if gained>0 and MailProfileSettings().showSessionTotal~=false then RUI:Print("Mail collected: "..Money(gained)) end
        end
        mailFrame.sessionStartMoney=nil; mailFrame:Hide(); Restore(MailFrame); return
    end
    if event=="MAIL_INBOX_UPDATE" or event=="MAIL_SEND_INFO_UPDATE" or event=="MAIL_SUCCESS" or event=="MAIL_SEND_SUCCESS" or event=="MAIL_FAILED" then
        local mailFrame=self.frames.mail
        if mailFrame:IsShown() then
            if event=="MAIL_SEND_SUCCESS" then
                if mailFrame.pendingRecipient and mailFrame.pendingRecipient~="" then self:RememberMailRecipient(mailFrame.pendingRecipient) end
                mailFrame.pendingRecipient=nil; mailFrame.autoSubject=nil; mailFrame.settingAutoSubject=true; mailFrame.to:SetText(""); mailFrame.subject:SetText(""); mailFrame.settingAutoSubject=nil; mailFrame.bodyEdit:SetText(""); mailFrame.gold:SetText(""); mailFrame.silver:SetText(""); mailFrame.copper:SetText(""); mailFrame.cod:SetRUIValue(false); self:SetMailMode("inbox")
            else self:RefreshMail() end
            if mailFrame.batch and (event=="MAIL_INBOX_UPDATE" or event=="MAIL_SUCCESS" or event=="MAIL_FAILED") then self:ScheduleMailBatch(.12) end
        end
        return
    end
    if event=="UI_ERROR_MESSAGE" then
        local a,b=...
        self:HandleMailBatchError(b or a)
        return
    end
    if event=="MERCHANT_SHOW" then if Enabled("merchant") then Suppress(MerchantFrame); self:HideOthers(self.frames.merchant); self.frames.merchant:Show(); self.frames.merchant.mode="buy"; self.frames.merchant.page=1; self.frames.merchant.previewMode=true; self.frames.merchant.selectedIndex=nil; self:RefreshMerchant() end; return end
    if event=="MERCHANT_CLOSED" then self.frames.merchant:Hide(); Restore(MerchantFrame); return end
    if event=="MERCHANT_UPDATE" or event=="PLAYER_MONEY" then if self.frames.merchant:IsShown() then self:RefreshMerchant() end; if self.frames.bank:IsShown() then self:RefreshBank() end; return end
    if event=="BANKFRAME_OPENED" then
        local f=self.frames.bank
        f.bankOpen=true
        f.extBankRequested=false
        f.RUIKeepVoidVisible=nil
        f.RUIKeepExtManagerOpen=nil
        f.voidReady=f.voidReady or QueryVoidStorageReady()
        -- Void is an optional extension of the unified bank. Start every banker
        -- visit with it hidden; clicking V explicitly opens/requests it.
        BankFilterSettings().void=false
        if Enabled("bank") then Suppress(BankFrame); self:HideOthers(f); f.rowOffset=0; f:Show(); self:RefreshBank() end
        local bags=RUI:GetModule("Bags"); if bags and bags.RefreshSecureBagClicks then bags:RefreshSecureBagClicks() end
        return
    end
    if event=="BANKFRAME_CLOSED" then
        local f=self.frames.bank
        f.bankOpen=false
        f.extBankRequested=false
        f.RUIKeepVoidVisible=nil
        f.RUIKeepExtManagerOpen=nil
        f.pendingVoidToNative=nil
        f.pendingBankToVoid=nil
        f.pendingVoidToBank=nil
        if type(ExtBankSetActive)=="function" then pcall(ExtBankSetActive,0) end
        Restore(BankFrame)
        if f:IsShown() then f:Hide() end
        local bags=RUI:GetModule("Bags"); if bags and bags.RefreshSecureBagClicks then bags:RefreshSecureBagClicks() end
        return
    end
    if event=="VOID_STORAGE_OPEN" then
        local f=self.frames.bank; f.voidReady=true; self:DiscoverNativeVoidStorageButtons()
        if Enabled("bank") then
            Suppress(_G.VoidStorageFrame)
            self:HideOthers(f); f.rowOffset=0; f:Show(); self:RefreshBank()
        end
        return
    end
    if event=="VOID_STORAGE_CLOSE" then
        local f=self.frames.bank; f.voidReady=false; Restore(_G.VoidStorageFrame)
        if f.bankOpen then self:RefreshBank() else f:Hide() end
        return
    end
    if event=="VOID_STORAGE_CONTENTS_UPDATE" or event=="VOID_STORAGE_UPDATE" or event=="VOID_STORAGE_DEPOSIT_UPDATE" or event=="VOID_TRANSFER_DONE" then
        if self.frames.bank:IsShown() then self:RefreshBank() end
        return
    end
    if event=="PLAYERBANKSLOTS_CHANGED" or event=="PLAYERBANKBAGSLOTS_CHANGED" or event=="BAG_UPDATE" or event=="ITEM_LOCK_CHANGED" then
        if self.frames.bank:IsShown() then
            if event=="PLAYERBANKBAGSLOTS_CHANGED" then
                local f=self.frames.bank
                f.RUIBankBagStructurePollRemaining=2.0
                f.RUIBankBagStructurePollElapsed=0
            end
            if event=="BAG_UPDATE" or event=="ITEM_LOCK_CHANGED" then
                self:ProcessPendingVoidToNative()
                self:ProcessPendingBankToVoid()
            end
            self:RefreshBank()
        end
        return
    end
    if event=="TRADE_SHOW" then
        if Enabled("trade") then
            -- A fresh trade must never inherit acceptance visuals from the
            -- previous session if TRADE_CLOSED/TRADE_ACCEPT_UPDATE ordering was
            -- unusual on the custom client.
            self.frames.trade.playerAccepted=false
            self.frames.trade.targetAccepted=false
            self.frames.trade.targetMoneyEventHint=nil
            self.frames.trade.tradeMoneySyncRemaining=0
            self.frames.trade.tradeMoneySyncElapsed=0
            self.frames.trade:SetScript("OnUpdate",nil)
            Suppress(TradeFrame); self:HideOthers(self.frames.trade); self.frames.trade:Show(); self:RefreshTrade()
        end
        return
    end
    if event=="TRADE_CLOSED" then
        self.frames.trade.playerAccepted=false
        self.frames.trade.targetAccepted=false
        self.frames.trade.targetMoneyEventHint=nil
        self.frames.trade.tradeMoneySyncRemaining=0
        self.frames.trade.tradeMoneySyncElapsed=0
        self.frames.trade:SetScript("OnUpdate",nil)
        SetTradeAcceptedVisual(self.frames.trade.leftAccepted,false)
        SetTradeAcceptedVisual(self.frames.trade.rightAccepted,false)
        self.frames.trade:Hide(); Restore(TradeFrame); return
    end
    if event=="TRADE_MONEY_CHANGED" then
        if self.frames.trade:IsShown() then
            local eventValue=...
            self:RefreshTrade()
            self:ScheduleTradeMoneySync(eventValue)
        end
        return
    end
    if event=="TRADE_UPDATE" or event=="TRADE_PLAYER_ITEM_CHANGED" or event=="TRADE_TARGET_ITEM_CHANGED" or event=="PLAYER_TRADE_MONEY" then if self.frames.trade:IsShown() then self:RefreshTrade() end; return end
    if event=="TRADE_ACCEPT_UPDATE" then
        local a,b=...
        self.frames.trade.playerAccepted=TradeAcceptedValue(a)
        self.frames.trade.targetAccepted=TradeAcceptedValue(b)
        if self.frames.trade:IsShown() then self:RefreshTrade() end
        return
    end
end

function PhaseB:OnInitialize()
    self.frames={}
    self:CreateCharacter(); self:CreateQuestLog(); self:CreateMail(); self:CreateMerchant(); self:CreateBank(); self:CreateTrade()
    self:InstallMailChatLinkBridge()
    for key,f in pairs(self.frames) do self:RegisterMover(key,f) end
    self:InstallExtBankBridge()
    self:InstallExtBankMoveTrace()
    self:InstallOverrides()
    self:InstallCombatMenuBindings()
    RUI:RegisterCallback("APPEARANCE_CHANGED",self,"OnAppearance"); RUI:RegisterCallback("COMPONENT_SCALE_CHANGED",self,"OnScaleChanged"); RUI:RegisterCallback("PROFILE_RESET",self,"ApplySettings")
end
function PhaseB:OnEnable()
    local ev={"ADDON_LOADED","PLAYER_LOGIN","UPDATE_BINDINGS","PLAYER_REGEN_ENABLED","CURSOR_UPDATE","EQUIPMENT_SETS_CHANGED","PLAYER_EQUIPMENT_CHANGED","UNIT_STATS","PLAYER_LEVEL_UP","UPDATE_FACTION","SKILL_LINES_CHANGED","CURRENCY_DISPLAY_UPDATE","UNIT_ATTACK_POWER","UNIT_RANGED_ATTACK_POWER","UNIT_DAMAGE","UNIT_RANGEDDAMAGE","UNIT_RESISTANCES","COMBAT_RATING_UPDATE","UNIT_MAXHEALTH","UNIT_HEALTH","UNIT_MANA","UNIT_RAGE","UNIT_ENERGY","UNIT_RUNIC_POWER","UNIT_DISPLAYPOWER","KNOWN_TITLES_UPDATE","UNIT_NAME_UPDATE","QUEST_LOG_UPDATE","QUEST_WATCH_UPDATE","MAIL_SHOW","MAIL_CLOSED","MAIL_INBOX_UPDATE","MAIL_SEND_INFO_UPDATE","MAIL_SUCCESS","MAIL_SEND_SUCCESS","MAIL_FAILED","UI_ERROR_MESSAGE","MERCHANT_SHOW","MERCHANT_CLOSED","MERCHANT_UPDATE","PLAYER_MONEY","BANKFRAME_OPENED","BANKFRAME_CLOSED","PLAYERBANKSLOTS_CHANGED","PLAYERBANKBAGSLOTS_CHANGED","BAG_UPDATE","ITEM_LOCK_CHANGED","TRADE_SHOW","TRADE_CLOSED","TRADE_UPDATE","TRADE_PLAYER_ITEM_CHANGED","TRADE_TARGET_ITEM_CHANGED","PLAYER_TRADE_MONEY","TRADE_MONEY_CHANGED","TRADE_ACCEPT_UPDATE"}
    for _,e in ipairs(ev) do self:RegisterEvent(e,"OnEvent") end
    local voidEvents={"VOID_STORAGE_OPEN","VOID_STORAGE_CLOSE","VOID_STORAGE_CONTENTS_UPDATE","VOID_STORAGE_UPDATE","VOID_STORAGE_DEPOSIT_UPDATE","VOID_TRANSFER_DONE"}
    for _,e in ipairs(voidEvents) do self:RegisterEvent(e,"OnEvent") end
    self:ApplySettings()
end
