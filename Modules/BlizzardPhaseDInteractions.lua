-- ZenUI 0.9.74 Phase D interaction timing hardening.
-- Adds Zen-owned Inspect, Trainer, Gossip and Quest interaction panels while
-- preserving the native 3.3.5 server APIs underneath.

local RUI = ZenUI
local PhaseD = RUI:NewModule("BlizzardPhaseDInteractions")

local function Settings()
    if not RUI.db then return nil end
    RUI.db.blizzard = RUI.db.blizzard or {}
    return RUI.db.blizzard
end

local function Enabled(key)
    local s = Settings()
    if not s or s.enabled == false then return false end
    if s[key] == nil then return true end
    return s[key] and true or false
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
    b:SetWidth(width or 110); b:SetHeight(height or 24)
    b.RUIText = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.RUIText:SetPoint("CENTER")
    b.RUIText:SetText(label or "Button")
    RUI:StyleButton(b)
    return b
end

local function Row(parent, width, height)
    local r = CreateFrame("Button", nil, parent)
    r:SetWidth(width or 520); r:SetHeight(height or 40)
    RUI:CreateBackdrop(r)
    if r.RUIBackground then r.RUIBackground:SetAlpha(.30) end
    r.hl = r:CreateTexture(nil, "ARTWORK"); r.hl:SetAllPoints(); r.hl:Hide()
    r:SetScript("OnEnter", function(self)
        local ar,ag,ab=RUI:GetAccentColor(); self.hl:SetTexture(ar,ag,ab,.10); self.hl:Show()
        if self.RUIOnEnter then self:RUIOnEnter() end
    end)
    r:SetScript("OnLeave", function(self)
        self.hl:Hide(); if self.RUIOnLeave then self:RUIOnLeave() end
    end)
    return r
end

local function ItemSlot(parent, size)
    local b=CreateFrame("Button",nil,parent); b:SetWidth(size or 40); b:SetHeight(size or 40); RUI:CreateBackdrop(b)
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOPLEFT",3,-3); b.icon:SetPoint("BOTTOMRIGHT",-3,3)
    return b
end

local function AddSpecial(frame)
    if not frame or not frame.GetName or not frame:GetName() then return end
    UISpecialFrames = UISpecialFrames or {}
    for i=1,#UISpecialFrames do if UISpecialFrames[i]==frame:GetName() then return end end
    table.insert(UISpecialFrames,frame:GetName())
end

local PANEL_INFO = {
    inspect={name="ZenUIInspectFrame",title="Inspect",width=720,height=590,mover="ZenInspect",scale="zenInspect",x=-310,y=10},
    trainer={name="ZenUITrainerFrame",title="Trainer",width=650,height=540,mover="ZenTrainer",scale="zenTrainer",x=-260,y=0},
    npc={name="ZenUINPCInteractionFrame",title="Conversation",width=780,height=650,mover="ZenNPCInteraction",scale="zenNPCInteraction",x=-325,y=0},
}

local function Panel(key)
    local info=PANEL_INFO[key]
    local f=CreateFrame("Frame",info.name,UIParent)
    f:SetWidth(info.width); f:SetHeight(info.height); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true); f:Hide()
    RUI:CreateBackdrop(f); f.accent=RUI:CreateAccentLine(f,2)
    f.title=Text(f,info.title,15,"TOPLEFT",f,"TOPLEFT",16,-17,false)
    f.subtitle=Text(f,"Zen interaction panel",8,"LEFT",f.title,"RIGHT",10,-1,true)
    f.close=Button(f,"X",28,24); f.close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-10,-10)
    f.body=CreateFrame("Frame",nil,f); f.body:SetPoint("TOPLEFT",f,"TOPLEFT",12,-48); f.body:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-12,12)
    AddSpecial(f)
    if RUI.RegisterExclusivePanel then RUI:RegisterExclusivePanel(f) end
    return f
end

local function SuppressNative(frame)
    if not frame then return end
    if not frame.RUIPhaseDSuppressed then
        frame.RUIPhaseDSuppressed=true
        frame.RUIPhaseDOldAlpha=frame.GetAlpha and frame:GetAlpha() or 1
        frame.RUIPhaseDOldMouse=frame.IsMouseEnabled and frame:IsMouseEnabled() or true
        if frame.IsKeyboardEnabled then frame.RUIPhaseDOldKeyboard=frame:IsKeyboardEnabled() and true or false end
    end
    if frame.SetAlpha then frame:SetAlpha(0) end
    if frame.EnableMouse then frame:EnableMouse(false) end
    -- Ebonhold can attach keyboard handlers to otherwise stock-looking quest or
    -- gossip frames. An alpha-zero frame must not continue consuming movement
    -- keys (notably Space) while Zen owns the visible interaction.
    if frame.EnableKeyboard then frame:EnableKeyboard(false) end
end

local function RestoreNative(frame)
    if not frame or not frame.RUIPhaseDSuppressed then return end
    if frame.SetAlpha then frame:SetAlpha(frame.RUIPhaseDOldAlpha or 1) end
    if frame.EnableMouse then frame:EnableMouse(frame.RUIPhaseDOldMouse~=false) end
    if frame.EnableKeyboard and frame.RUIPhaseDOldKeyboard~=nil then frame:EnableKeyboard(frame.RUIPhaseDOldKeyboard and true or false) end
    frame.RUIPhaseDOldKeyboard=nil
    frame.RUIPhaseDSuppressed=nil
end

-- When Zen cannot safely decode an Ebonhold gossip hand-off, native UI must
-- always win. Keep an explicit fallback flag so our GossipFrame OnShow hook
-- does not immediately suppress the very frame we are trying to restore.
local function ShowNativeGossipFallback(forceShow)
    PhaseD.allowNativeGossip=true
    local frame=_G.GossipFrame
    RestoreNative(frame)
    if forceShow and frame and frame.IsShown and not frame:IsShown() and frame.Show then
        pcall(frame.Show,frame)
    end
end

-- Quest interactions need the same hard fallback guarantee as Gossip.  Some
-- Ebonhold quest packets can reach QUEST_* events while one of the quest APIs
-- is still incomplete.  If Zen cannot finish rendering that page, never leave
-- the already-open native QuestFrame alpha-zero and mouse-disabled.
local function ShowNativeQuestFallback(forceShow)
    PhaseD.allowNativeQuest=true
    local frame=_G.QuestFrame
    RestoreNative(frame)
    if forceShow and frame and frame.IsShown and not frame:IsShown() and frame.Show then
        pcall(frame.Show,frame)
    end
end

local function ShowExclusive(frame)
    if RUI.ActivateExclusivePanel then RUI:ActivateExclusivePanel(frame) end
    if frame then frame:Show() end
end

local function ApplyScale(key)
    local f=PhaseD.frames and PhaseD.frames[key]
    local info=PANEL_INFO[key]
    if not f or not info then return end
    f:SetScale(RUI:GetEffectiveScale(info.scale))
end

-- -------------------------------------------------------------------------
-- Inspect
-- -------------------------------------------------------------------------
local EQUIP={
    {1,"Head"},{2,"Neck"},{3,"Shoulder"},{15,"Back"},{5,"Chest"},{4,"Shirt"},{19,"Tabard"},{9,"Wrist"},
    {10,"Hands"},{6,"Waist"},{7,"Legs"},{8,"Feet"},{11,"Finger 1"},{12,"Finger 2"},{13,"Trinket 1"},{14,"Trinket 2"},
    {16,"Main Hand"},{17,"Off Hand"},{18,"Ranged / Relic"},
}
local LEFT_SLOTS={1,2,3,15,5,4,19,9}
local RIGHT_SLOTS={10,6,7,8,11,12,13,14}

local function Contains(list,value)
    for i=1,#list do if list[i]==value then return i end end
    return nil
end

-- Keep third-party Inspect addons useful even though Zen owns the visible
-- frame. Many Wrath addons add buttons (for example a dressing-room/outfit
-- action) as children of Blizzard's InspectFrame. The stock frame stays alive
-- but transparent, so we can delegate our visible action to that addon button.
local function InspectButtonText(button)
    if not button then return nil end
    if button.GetText then
        local ok,text=pcall(button.GetText,button)
        if ok and type(text)=="string" and text~="" then return text end
    end
    local regions={button.Text,button.text,button.Label,button.label}
    for i=1,#regions do
        local region=regions[i]
        if region and region.GetText then
            local ok,text=pcall(region.GetText,region)
            if ok and type(text)=="string" and text~="" then return text end
        end
    end
    return nil
end

local function FindInspectDressingButton(root)
    if not root or not root.GetChildren then return nil end
    local seen={}
    local function scan(parent,depth)
        if not parent or seen[parent] or depth>7 or not parent.GetChildren then return nil end
        seen[parent]=true
        local children={parent:GetChildren()}
        for i=1,#children do
            local child=children[i]
            if child then
                local text=InspectButtonText(child)
                local name=(child.GetName and child:GetName()) or ""
                local hay=string.lower(tostring(text or "").." "..tostring(name or ""))
                if (string.find(hay,"dressing room",1,true) or string.find(hay,"dressup",1,true) or string.find(hay,"dress up",1,true))
                    and child~=PhaseD.frames.inspect then
                    return child
                end
                local found=scan(child,depth+1)
                if found then return found end
            end
        end
        return nil
    end
    return scan(root,0)
end

local function ActivateInspectDressingRoom(frame)
    local stock=_G.InspectFrame
    local proxy=FindInspectDressingButton(stock)
    if proxy then
        -- Prefer Click() so any addon hooks and PreClick/PostClick handlers run.
        if proxy.Click then
            local ok=pcall(proxy.Click,proxy,"LeftButton")
            if ok then return true end
        end
        local script=proxy.GetScript and proxy:GetScript("OnClick")
        if type(script)=="function" then
            local ok=pcall(script,proxy,"LeftButton")
            if ok then return true end
        end
    end
    local unit=(frame and frame.unit) or "target"
    if DressUpUnit and UnitExists and UnitExists(unit) then
        local ok=pcall(DressUpUnit,unit)
        return ok and true or false
    end
    return false
end

function PhaseD:CreateInspect()
    local f=Panel("inspect"); self.frames.inspect=f; f.unit="target"; f.modelRotation=.61
    f.name=Text(f.body,"",15,"TOP",f.body,"TOP",0,-8,false)
    f.info=Text(f.body,"",10,"TOP",f.name,"BOTTOM",0,-3,true)
    f.dress=Button(f.body,"View in Dressing Room",170,24); f.dress:SetPoint("TOP",f.info,"BOTTOM",0,-10)
    f.dress:SetScript("OnClick",function() ActivateInspectDressingRoom(f) end)
    f.dress:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText("View in Dressing Room")
        GameTooltip:AddLine("Uses the Inspect addon action when one is installed; otherwise opens the native dressing room.",.78,.78,.78,true)
        GameTooltip:Show()
    end)
    f.dress:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    f.model=CreateFrame("PlayerModel",nil,f.body); f.model:SetWidth(390); f.model:SetHeight(330); f.model:SetPoint("TOP",f.body,"TOP",0,-92); f.model:EnableMouse(true)
    if Model_OnLoad then Model_OnLoad(f.model) end
    f.model:SetScript("OnMouseDown",function(self,button) if button=="LeftButton" then self.RUIRotating=true; self.RUILastX=GetCursorPosition() end end)
    f.model:SetScript("OnMouseUp",function(self) self.RUIRotating=nil end)
    f.model:SetScript("OnUpdate",function(self)
        if not self.RUIRotating then return end
        local x=GetCursorPosition(); local dx=x-(self.RUILastX or x); self.RUILastX=x; f.modelRotation=(f.modelRotation or .61)+(dx*.012)
        if self.SetRotation then self:SetRotation(f.modelRotation) end
    end)
    f.itemLevel=Text(f.body,"",16,"BOTTOM",f.model,"BOTTOM",0,2,false)
    f.itemLevelLabel=Text(f.body,"Average item level",8,"TOP",f.itemLevel,"BOTTOM",0,-2,true)
    f.slots={}
    for i=1,#EQUIP do
        local slotID,label=EQUIP[i][1],EQUIP[i][2]
        local b=ItemSlot(f.body,42); b.slotID=slotID; b.slotName=label
        local li=Contains(LEFT_SLOTS,slotID); local ri=Contains(RIGHT_SLOTS,slotID)
        if li then b:SetPoint("TOPLEFT",f.body,"TOPLEFT",22,-76-((li-1)*49))
        elseif ri then b:SetPoint("TOPRIGHT",f.body,"TOPRIGHT",-22,-76-((ri-1)*49))
        else
            local offset=(slotID==16 and -54) or (slotID==17 and 0) or 54
            b:SetPoint("BOTTOM",f.body,"BOTTOM",offset,28)
        end
        b:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            local unit=f.unit or "target"
            local shown=false

            -- Stock SetInventoryItem() is preferable because it can attach the
            -- inspected unit/slot directly, but some Ebonhold builds return
            -- false here even though GetInventoryItemLink() already has the
            -- inspected item's complete link. Fall back to that link instead
            -- of degrading the tooltip to only "Head", "Legs", etc.
            if GameTooltip.SetInventoryItem then
                local ok,result=pcall(GameTooltip.SetInventoryItem,GameTooltip,unit,self.slotID)
                shown=ok and result and true or false
            end
            if not shown and GetInventoryItemLink and GameTooltip.SetHyperlink then
                local ok,link=pcall(GetInventoryItemLink,unit,self.slotID)
                if ok and type(link)=="string" and link~="" then
                    local linkOK=pcall(GameTooltip.SetHyperlink,GameTooltip,link)
                    shown=linkOK and true or false
                end
            end
            if not shown then GameTooltip:SetText(self.slotName) end
            GameTooltip:Show()

            -- If Shift was already held before entering the slot, make the
            -- comparison state immediate rather than waiting for another
            -- MODIFIER_STATE_CHANGED event.
            local tooltipModule=RUI.GetModule and RUI:GetModule("Tooltip")
            if tooltipModule and tooltipModule.RefreshItemComparison then
                pcall(tooltipModule.RefreshItemComparison,tooltipModule)
            end
        end)
        b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        b:SetScript("OnClick",function(self,button)
            if button~="LeftButton" then return end
            local unit=f.unit or "target"
            local link=GetInventoryItemLink and GetInventoryItemLink(unit,self.slotID)
            if link and RUI.HandleModifiedLinkClick then RUI:HandleModifiedLinkClick(link,button) end
        end)
        f.slots[#f.slots+1]=b
    end
    f.close:SetScript("OnClick",function() f:Hide() end)
    f:SetScript("OnHide",function()
        local stock=_G.InspectFrame
        if stock and stock.IsShown and stock:IsShown() then RestoreNative(stock); stock:Hide() end
        if ClearInspectPlayer then pcall(ClearInspectPlayer) end
    end)
end

function PhaseD:RequestInspect(unit)
    unit=unit or "target"
    if not UnitExists or not UnitExists(unit) then return false end
    if UnitIsPlayer and not UnitIsPlayer(unit) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    -- Ask Blizzard/Ebonhold to create a real inspect session first. Zen's
    -- visible panel then stays synchronized with INSPECT_READY and any
    -- third-party InspectFrame extensions instead of merely reading stale
    -- inventory links from the unit token.
    if IsAddOnLoaded and not IsAddOnLoaded("Blizzard_InspectUI") and LoadAddOn then
        pcall(LoadAddOn,"Blizzard_InspectUI")
    end

    local requested=false
    if type(InspectUnit)=="function" then
        local ok=pcall(InspectUnit,unit)
        requested=ok and true or false
    elseif type(NotifyInspect)=="function" then
        local ok=pcall(NotifyInspect,unit)
        requested=ok and true or false
    end

    if Enabled("inspect") then
        self:OpenInspect(unit)
    end
    return requested or (Enabled("inspect") and true or false)
end

function PhaseD:RefreshInspect()
    local f=self.frames.inspect; if not f or not f:IsShown() then return end
    local unit=f.unit or "target"
    if not UnitExists or not UnitExists(unit) then f:Hide(); return end
    local name=UnitName(unit) or "Unknown"
    local level=UnitLevel and UnitLevel(unit) or 0
    local race=UnitRace and UnitRace(unit) or ""
    local class=UnitClass and UnitClass(unit) or ""
    f.name:SetText(name)
    f.info:SetText("Level "..tostring(level or "?").." "..tostring(race or "").." "..tostring(class or ""))
    if f.model.SetUnit then f.model:SetUnit(unit) end
    if f.model.SetPortraitZoom then f.model:SetPortraitZoom(0) end
    if f.model.SetCamDistanceScale then f.model:SetCamDistanceScale(1.0) end
    if f.model.SetRotation then f.model:SetRotation(f.modelRotation or .61) end
    local total,count=0,0
    for i=1,#f.slots do
        local b=f.slots[i]
        local tex=GetInventoryItemTexture and GetInventoryItemTexture(unit,b.slotID)
        b.icon:SetTexture(tex or "")
        if tex then
            b:Show()
            local link=GetInventoryItemLink and GetInventoryItemLink(unit,b.slotID)
            if link and GetItemInfo then
                local _,_,quality,itemLevel=GetItemInfo(link)
                if tonumber(itemLevel) then total=total+itemLevel; count=count+1 end
                if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
                    local c=ITEM_QUALITY_COLORS[quality]; RUI:SetBorderColor(b,c.r or 1,c.g or 1,c.b or 1,1)
                else RUI:RefreshBackdrop(b) end
            else RUI:RefreshBackdrop(b) end
        else
            RUI:RefreshBackdrop(b)
        end
    end
    if count>0 then f.itemLevel:SetText(tostring(math.floor((total/count)+.5))) else f.itemLevel:SetText("--") end
end

function PhaseD:OpenInspect(unit)
    if not Enabled("inspect") then return false end
    local f=self.frames.inspect; unit=unit or (InspectFrame and InspectFrame.unit) or "target"
    if not UnitExists or not UnitExists(unit) then return false end
    f.unit=unit
    -- Keep Blizzard's hidden InspectFrame synchronized for third-party addons
    -- that read InspectFrame.unit or attach controls to the native frame.
    if _G.InspectFrame then _G.InspectFrame.unit=unit end
    ShowExclusive(f)
    self:RefreshInspect()
    SuppressNative(_G.InspectFrame)
    return true
end

-- -------------------------------------------------------------------------
-- Trainer
-- -------------------------------------------------------------------------
function PhaseD:CreateTrainer()
    local f=Panel("trainer"); self.frames.trainer=f; f.selected=nil; f.offset=0
    local function PageTrainer(delta)
        local total=GetNumTrainerServices and tonumber(GetNumTrainerServices()) or 0
        local maxOffset=math.max(0,total-8)
        local step=(tonumber(delta) or 0)<0 and 8 or -8
        local nextOffset=math.max(0,math.min(maxOffset,(f.offset or 0)+step))
        if nextOffset~=(f.offset or 0) then f.offset=nextOffset; PhaseD:RefreshTrainer() end
    end
    f.vendor=Text(f.body,"",14,"TOPLEFT",f.body,"TOPLEFT",4,-3,false)
    f.greeting=Text(f.body,"",9,"TOPLEFT",f.vendor,"BOTTOMLEFT",0,-5,true); f.greeting:SetWidth(590); f.greeting:SetJustifyH("LEFT")
    f.list=CreateFrame("Frame",nil,f.body); f.list:SetPoint("TOPLEFT",f.body,"TOPLEFT",2,-62); f.list:SetWidth(594); f.list:SetHeight(330); RUI:CreateBackdrop(f.list)
    f.rows={}
    for i=1,8 do
        local r=Row(f.list,574,36); r:SetPoint("TOPLEFT",f.list,"TOPLEFT",10,-8-((i-1)*39)); r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetWidth(28); r.icon:SetHeight(28); r.icon:SetPoint("LEFT",r,"LEFT",5,0)
        r.name=Text(r,"",11,"TOPLEFT",r,"TOPLEFT",40,-5,false); r.req=Text(r,"",8,"BOTTOMLEFT",r,"BOTTOMLEFT",40,5,true); r.cost=Text(r,"",10,"RIGHT",r,"RIGHT",-8,0,false); r.cost:SetJustifyH("RIGHT")
        r:SetScript("OnClick",function(self) if self.serviceIndex then f.selected=self.serviceIndex; PhaseD:RefreshTrainer() end end)
        r:EnableMouseWheel(true); r:SetScript("OnMouseWheel",function(_,delta) PageTrainer(delta) end)
        f.rows[i]=r
    end
    f.list:EnableMouseWheel(true); f.list:SetScript("OnMouseWheel",function(_,delta) PageTrainer(delta) end)
    f.prev=Button(f.body,"^",32,22); f.prev:SetPoint("TOPRIGHT",f.list,"BOTTOMRIGHT",-40,-6)
    f.next=Button(f.body,"v",32,22); f.next:SetPoint("LEFT",f.prev,"RIGHT",6,0)
    f.prev:SetScript("OnClick",function() PageTrainer(1) end)
    f.next:SetScript("OnClick",function() PageTrainer(-1) end)
    f.detail=CreateFrame("Frame",nil,f.body); f.detail:SetPoint("BOTTOMLEFT",f.body,"BOTTOMLEFT",2,2); f.detail:SetWidth(594); f.detail:SetHeight(88); RUI:CreateBackdrop(f.detail)
    f.detailName=Text(f.detail,"Select a service",12,"TOPLEFT",f.detail,"TOPLEFT",10,-9,false)
    f.detailText=Text(f.detail,"",9,"TOPLEFT",f.detailName,"BOTTOMLEFT",0,-6,true); f.detailText:SetWidth(420); f.detailText:SetJustifyH("LEFT")
    f.train=Button(f.detail,"Train",110,26); f.train:SetPoint("BOTTOMRIGHT",f.detail,"BOTTOMRIGHT",-10,10)
    f.train:SetScript("OnClick",function() if f.selected and BuyTrainerService then BuyTrainerService(f.selected) end end)
    f.close:SetScript("OnClick",function() if CloseTrainer then CloseTrainer() else f:Hide() end end)
end

function PhaseD:RefreshTrainer()
    local f=self.frames.trainer; if not f or not f:IsShown() then return end
    f.vendor:SetText(UnitName and (UnitName("npc") or "Trainer") or "Trainer")
    f.greeting:SetText(GetTrainerGreetingText and (GetTrainerGreetingText() or "") or "")
    local total=GetNumTrainerServices and tonumber(GetNumTrainerServices()) or 0
    local maxOffset=math.max(0,total-8); if f.offset>maxOffset then f.offset=maxOffset end
    for i=1,#f.rows do
        local idx=(f.offset or 0)+i; local r=f.rows[i]
        if idx<=total then
            local name,rank,category=GetTrainerServiceInfo(idx)
            local icon=GetTrainerServiceIcon and GetTrainerServiceIcon(idx)
            local cost=GetTrainerServiceCost and GetTrainerServiceCost(idx) or 0
            local lvl=GetTrainerServiceLevelReq and tonumber(GetTrainerServiceLevelReq(idx)) or 0
            local skill,skillReq=nil,nil
            if GetTrainerServiceSkillReq then skill,skillReq=GetTrainerServiceSkillReq(idx) end
            r.serviceIndex=idx; r.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark"); r.name:SetText((name or "Service")..((rank and rank~="") and ("  "..rank) or ""))
            local req={}; if lvl and lvl>0 then req[#req+1]="Level "..lvl end; if skill and skill~="" and tonumber(skillReq) and skillReq>0 then req[#req+1]=skill.." "..skillReq end; r.req:SetText(table.concat(req,"  •  "))
            r.cost:SetText(cost>0 and ((GetCoinTextureString and GetCoinTextureString(cost)) or tostring(cost)) or "")
            r:Show(); RUI:RefreshBackdrop(r)
            if category=="available" then local ar,ag,ab=RUI:GetAccentColor(); r.name:SetTextColor(ar,ag,ab)
            elseif category=="used" then r.name:SetTextColor(.45,.85,.45)
            else r.name:SetTextColor(.9,.35,.35) end
            if f.selected==idx then local ar,ag,ab=RUI:GetAccentColor(); RUI:SetBorderColor(r,ar,ag,ab,1) end
        else r.serviceIndex=nil; r:Hide() end
    end
    if not f.selected or f.selected>total then f.selected=(total>0 and 1 or nil) end
    if f.selected then
        local name,rank,category=GetTrainerServiceInfo(f.selected); local desc=GetTrainerServiceDescription and GetTrainerServiceDescription(f.selected) or ""
        f.detailName:SetText((name or "Service")..((rank and rank~="") and ("  "..rank) or "")); f.detailText:SetText(desc or "")
        if category=="available" then f.train:Enable() else f.train:Disable() end
    else f.detailName:SetText("No trainer services"); f.detailText:SetText(""); f.train:Disable() end
end

-- -------------------------------------------------------------------------
-- Gossip / Quest interaction
-- -------------------------------------------------------------------------
local function QuestFlagTrue(value)
    if value==true then return true end
    if value==false or value==nil then return false end
    local numeric=tonumber(value)
    if numeric~=nil then return numeric~=0 end
    local text=string.lower(tostring(value))
    return text=="true" or text=="daily" or text=="repeatable" or text=="yes"
end

local function NonBlankText(value)
    if value==nil then return nil end
    local text=tostring(value)
    if not string.find(text,"%S") then return nil end
    return text
end

-- Native Blizzard/Ebonhold gossip buttons can carry inline color escapes that
-- were chosen for the parchment GossipFrame. Copying those escapes into
-- Zen's dark interaction panel can make quest titles nearly black. Keep
-- the title text, but let Zen own all presentation colors.
local function CleanQuestTitle(value)
    local text=NonBlankText(value)
    if not text then return nil end
    text=string.gsub(text,"|c%x%x%x%x%x%x%x%x","")
    text=string.gsub(text,"|r","")
    return NonBlankText(text)
end

local function SafeQuestCall(fn,...)
    if type(fn)~="function" then return nil,false end
    local ok,a,b,c,d,e=pcall(fn,...)
    if not ok then return nil,false end
    return a,true,b,c,d,e
end

-- QUEST_GREETING is already rendered by Blizzard/Ebonhold into the hidden
-- QuestFrame.  Mirror those native QuestTitleButton rows first instead of
-- depending on private-server quest APIs being coherent a second time.  This
-- is the quest-list equivalent of BuildNativeGossipEntries().
local function BuildNativeQuestGreetingEntries()
    local output={}
    local greeting=nil
    local greetingFS=_G.GreetingText
    if greetingFS and greetingFS.GetText then
        local ok,text=pcall(greetingFS.GetText,greetingFS)
        if ok then greeting=NonBlankText(text) end
    end

    local maxButtons=tonumber(_G.MAX_NUM_QUESTS) or 32
    for i=1,maxButtons do
        local button=_G["QuestTitleButton"..tostring(i)]
        if button and button.IsShown and button:IsShown() then
            local title=nil
            if button.GetText then
                local ok,text=pcall(button.GetText,button)
                if ok then title=text end
            end
            if not NonBlankText(title) and button.GetFontString then
                local ok,fs=pcall(button.GetFontString,button)
                if ok and fs and fs.GetText then
                    local ok2,text=pcall(fs.GetText,fs)
                    if ok2 then title=text end
                end
            end
            title=CleanQuestTitle(title)
            if title then
                local isActive=(button.isActive==1 or button.isActive==true)
                local index=(button.GetID and button:GetID()) or i
                local icon=_G[(button.GetName and button:GetName() or "").."QuestIcon"] or button.QuestIcon
                local texture=icon and icon.GetTexture and icon:GetTexture() or nil
                local lower=type(texture)=="string" and string.lower(texture) or ""
                local state=nil
                local isDaily=false
                local isRepeatable=false
                if isActive then
                    local incomplete=string.find(lower,"incompletequesticon",1,true)~=nil
                    state=incomplete and "progress" or "ready"
                else
                    if string.find(lower,"dailyquesticon",1,true) then state="daily"; isDaily=true
                    elseif string.find(lower,"dailyactivequesticon",1,true) then state="repeatable"; isRepeatable=true
                    else state="available" end
                end
                output[#output+1]={
                    kind=isActive and "questActive" or "questAvailable",
                    index=index,
                    title=title,
                    state=state,
                    isDaily=isDaily,
                    isRepeatable=isRepeatable,
                }
            end
        end
    end
    return greeting,output
end

local function ColorEscape(r,g,b)
    local function channel(v)
        v=math.max(0,math.min(1,tonumber(v) or 1))
        return math.floor((v*255)+0.5)
    end
    return string.format("|cff%02x%02x%02x",channel(r),channel(g),channel(b))
end

local function QuestRowText(status,sr,sg,sb,title)
    local tr,tg,tb=RUI:GetTextColor(false)
    local mr,mg,mb=RUI:GetTextColor(true)
    title=CleanQuestTitle(title) or "Quest"
    return ColorEscape(sr,sg,sb)..status.."|r  "..ColorEscape(mr,mg,mb).."•|r  "..ColorEscape(tr,tg,tb)..title.."|r"
end

-- Ebonhold can render the correct blue Daily quest icon in the stock Gossip
-- frame even when its GetGossipAvailableQuests daily flag is absent or uses a
-- non-standard value. Mirror the icon state Blizzard/Ebonhold actually chose
-- so Zen presents the exact same Daily/Repeatable classification.
local function NativeGossipAvailableQuestState(index)
    index=tonumber(index)
    if not index or index<1 then return nil end
    local button=_G["GossipTitleButton"..tostring(index)]
    local icon=button and (_G[button:GetName().."GossipIcon"] or button.GossipIcon)
    local texture=icon and icon.GetTexture and icon:GetTexture()
    if type(texture)~="string" then return nil end
    local lower=string.lower(texture)
    if string.find(lower,"dailyquesticon",1,true) then return "daily" end
    if string.find(lower,"dailyactivequesticon",1,true) then return "repeatable" end
    return nil
end

local function IsQuestTitleDaily(title)
    if not title or not GetNumQuestLogEntries or not GetQuestLogTitle then return false end
    local total=tonumber(GetNumQuestLogEntries()) or 0
    for i=1,total do
        local qTitle,_,_,_,isHeader,_,_,isDaily=GetQuestLogTitle(i)
        if not isHeader and qTitle==title and QuestFlagTrue(isDaily) then return true end
    end
    return false
end

local function AddVarargRows(output,kind,step,...)
    local n=select("#",...); local index=1
    for i=1,n,step do
        local title=CleanQuestTitle(select(i,...))
        if title then
            local d1,d2,d3,d4,d5=title,select(i+1,...),select(i+2,...),select(i+3,...),select(i+4,...)
            local state=nil
            local isDaily=false
            local isRepeatable=false
            if kind=="available" then
                -- Wrath GetGossipAvailableQuests returns:
                -- title, level, isTrivial, isDaily, isRepeatable. Ebonhold can
                -- omit/alter those flags while still rendering the correct blue
                -- icon in its stock frame, so the rendered native icon is our
                -- final fallback/source of truth.
                isDaily=QuestFlagTrue(d4)
                isRepeatable=QuestFlagTrue(d5)
                local nativeState=NativeGossipAvailableQuestState(index)
                if nativeState=="daily" then isDaily=true; isRepeatable=false
                elseif nativeState=="repeatable" then isRepeatable=true; isDaily=false end
                state=isDaily and "daily" or (isRepeatable and "repeatable" or "available")
            elseif kind=="active" then
                isDaily=IsQuestTitleDaily(title)
                state=QuestFlagTrue(d4) and (isDaily and "dailyReady" or "ready") or (isDaily and "dailyProgress" or "progress")
            end
            output[#output+1]={kind=kind,index=index,title=title,state=state,isDaily=isDaily,isRepeatable=isRepeatable,data={d1,d2,d3,d4,d5}}
            index=index+1
        end
    end
end

-- Prefer the stock GossipFrame's already-rendered buttons when available.
-- Ebonhold can briefly expose empty strings through the gossip APIs while its
-- own GossipFrameUpdate has already populated the correct visible titles. The
-- native frame stays alpha-suppressed, but its button text/type/IDs remain a
-- reliable compatibility source.
local function BuildNativeGossipEntries()
    local output={}
    local maxButtons=tonumber(_G.NUMGOSSIPBUTTONS) or 32
    for i=1,maxButtons do
        local button=_G["GossipTitleButton"..tostring(i)]
        if button and button.IsShown and button:IsShown() then
            local title=button.GetText and button:GetText() or nil
            if not NonBlankText(title) and button.GetFontString then
                local fontString=button:GetFontString()
                title=fontString and fontString.GetText and fontString:GetText() or title
            end
            title=CleanQuestTitle(title)
            if title then
                local nativeType=tostring(button.type or "Gossip")
                local kind="gossip"
                if nativeType=="Available" then kind="available"
                elseif nativeType=="Active" then kind="active" end

                local state=nil
                local isDaily=false
                local isRepeatable=false
                local icon=_G[(button.GetName and button:GetName() or "").."GossipIcon"] or button.GossipIcon
                local texture=icon and icon.GetTexture and icon:GetTexture() or nil
                local lower=type(texture)=="string" and string.lower(texture) or ""
                if kind=="available" then
                    if string.find(lower,"dailyquesticon",1,true) then state="daily"; isDaily=true
                    elseif string.find(lower,"dailyactivequesticon",1,true) then state="repeatable"; isRepeatable=true
                    else state="available" end
                elseif kind=="active" then
                    isDaily=IsQuestTitleDaily(title)
                    local ready=string.find(lower,"activequesticon",1,true)~=nil and string.find(lower,"incomplete",1,true)==nil
                    state=ready and (isDaily and "dailyReady" or "ready") or (isDaily and "dailyProgress" or "progress")
                end

                output[#output+1]={
                    kind=kind,
                    index=(button.GetID and button:GetID()) or #output+1,
                    title=title,
                    state=state,
                    isDaily=isDaily,
                    isRepeatable=isRepeatable,
                }
            end
        end
    end
    return output
end

function PhaseD:CreateNPC()
    local f=Panel("npc"); self.frames.npc=f; f.mode="gossip"; f.rows={}; f.rewardChoice=nil; f.offset=0; f.entries={}
    local function PageNPC(delta)
        local total=#(f.entries or {})
        local maxOffset=math.max(0,total-8)
        local step=(tonumber(delta) or 0)<0 and 8 or -8
        local nextOffset=math.max(0,math.min(maxOffset,(f.offset or 0)+step))
        if nextOffset~=(f.offset or 0) then f.offset=nextOffset; PhaseD:RefreshNPCRows() end
    end
    f.npcName=Text(f.body,"",13,"TOPLEFT",f.body,"TOPLEFT",6,-4,true)
    f.heading=Text(f.body,"",18,"TOPLEFT",f.npcName,"BOTTOMLEFT",0,-7,false)

    -- Gossip/greeting presentation. Quest detail/progress/reward pages use the
    -- dedicated structured quest view below. The NPC panel is intentionally
    -- wider than the original Blizzard parchment so quest prose remains
    -- readable at normal UI scales.
    f.text=Text(f.body,"",12,"TOPLEFT",f.heading,"BOTTOMLEFT",0,-10,false); f.text:SetWidth(704); f.text:SetHeight(104); f.text:SetJustifyH("LEFT"); f.text:SetJustifyV("TOP"); if f.text.SetWordWrap then f.text:SetWordWrap(true) end; if f.text.SetSpacing then f.text:SetSpacing(3) end
    f.options=CreateFrame("Frame",nil,f.body); f.options:SetPoint("TOPLEFT",f.body,"TOPLEFT",2,-184); f.options:SetWidth(714); f.options:SetHeight(350); RUI:CreateBackdrop(f.options)
    for i=1,8 do
        local r=Row(f.options,694,36); r:SetPoint("TOPLEFT",f.options,"TOPLEFT",10,-9-((i-1)*41)); r.name=Text(r,"",12,"LEFT",r,"LEFT",12,0,false); r.name:SetWidth(666); r.name:SetJustifyH("LEFT")
        r:SetScript("OnClick",function(self) PhaseD:ActivateNPCRow(self) end)
        r:EnableMouseWheel(true); r:SetScript("OnMouseWheel",function(_,delta) PageNPC(delta) end); f.rows[i]=r
    end
    f.options:EnableMouseWheel(true); f.options:SetScript("OnMouseWheel",function(_,delta) PageNPC(delta) end)
    f.prev=Button(f.body,"^",32,22); f.prev:SetPoint("BOTTOMLEFT",f.body,"BOTTOMLEFT",2,2); f.prev:Hide()
    f.next=Button(f.body,"v",32,22); f.next:SetPoint("LEFT",f.prev,"RIGHT",6,0); f.next:Hide()
    f.prev:SetScript("OnClick",function() PageNPC(1) end)
    f.next:SetScript("OnClick",function() PageNPC(-1) end)

    -- Quest pages get a dedicated clipped reading surface instead of reusing
    -- the gossip text + option list. A single flowing FontString is used for
    -- description/objectives so Wrath clients that report unreliable
    -- GetStringHeight values cannot make two independent text blocks overlap.
    f.questView=CreateFrame("Frame",nil,f.body)
    f.questView:SetPoint("TOPLEFT",f.heading,"BOTTOMLEFT",0,-14)
    f.questView:SetPoint("BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-2,48)
    f.questView:SetFrameLevel((f.body:GetFrameLevel() or 1)+6)
    f.questView:Hide()

    f.questTextPanel=CreateFrame("Frame",nil,f.questView); f.questTextPanel:SetPoint("TOPLEFT",0,0); f.questTextPanel:SetPoint("BOTTOMRIGHT",0,0); RUI:CreateBackdrop(f.questTextPanel)
    if f.questTextPanel.RUIBackground then f.questTextPanel.RUIBackground:SetAlpha(.48) end
    f.questScroll=CreateFrame("ScrollFrame",nil,f.questTextPanel)
    f.questScroll:SetPoint("TOPLEFT",f.questTextPanel,"TOPLEFT",14,-14); f.questScroll:SetPoint("BOTTOMRIGHT",f.questTextPanel,"BOTTOMRIGHT",-14,14)
    f.questScroll:EnableMouseWheel(true)
    f.questContent=CreateFrame("Frame",nil,f.questScroll); f.questContent:SetWidth(692); f.questContent:SetHeight(1800); f.questScroll:SetScrollChild(f.questContent)
    f.questBodyText=Text(f.questContent,"",14,"TOPLEFT",f.questContent,"TOPLEFT",4,-4,false)
    f.questBodyText:SetWidth(668); f.questBodyText:SetHeight(1760); f.questBodyText:SetJustifyH("LEFT"); f.questBodyText:SetJustifyV("TOP")
    if f.questBodyText.SetWordWrap then f.questBodyText:SetWordWrap(true) end
    if f.questBodyText.SetNonSpaceWrap then f.questBodyText:SetNonSpaceWrap(true) end
    if f.questBodyText.SetSpacing then f.questBodyText:SetSpacing(5) end
    f.questScroll:SetScript("OnMouseWheel",function(self,delta)
        local current=(self.GetVerticalScroll and self:GetVerticalScroll()) or 0
        local range=(self.GetVerticalScrollRange and self:GetVerticalScrollRange()) or 0
        local nextValue=current-(delta*54)
        if nextValue<0 then nextValue=0 elseif nextValue>range then nextValue=range end
        if self.SetVerticalScroll then self:SetVerticalScroll(nextValue) end
    end)

    f.questRewards=CreateFrame("Frame",nil,f.questView); f.questRewards:SetHeight(118); f.questRewards:SetPoint("BOTTOMLEFT",f.questView,"BOTTOMLEFT",0,0); f.questRewards:SetPoint("BOTTOMRIGHT",f.questView,"BOTTOMRIGHT",0,0); RUI:CreateBackdrop(f.questRewards); f.questRewards:Hide()
    f.rewardLabel=Text(f.questRewards,"",11,"TOPLEFT",f.questRewards,"TOPLEFT",12,-10,false); f.rewardLabel:Hide()
    f.rewardHint=Text(f.questRewards,"Hover a reward for details",10,"TOPRIGHT",f.questRewards,"TOPRIGHT",-12,-11,true); f.rewardHint:Hide()
    f.rewards={}
    for i=1,6 do
        local b=ItemSlot(f.questRewards,52); b:SetPoint("TOPLEFT",f.questRewards,"TOPLEFT",14+((i-1)*60),-42); b.index=i; b:Hide()
        b.count=Text(b,"",10,"BOTTOMRIGHT",b,"BOTTOMRIGHT",-3,3,false)
        b:SetScript("OnClick",function(self) f.rewardChoice=self.index; PhaseD:RefreshQuestInteraction() end)
        b:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            local choiceType=(GetNumQuestChoices and GetNumQuestChoices()>0) and "choice" or "reward"
            if GameTooltip.SetQuestItem then GameTooltip:SetQuestItem(choiceType,self.index) end; GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        f.rewards[i]=b
    end

    f.action=Button(f.body,"Continue",150,30); f.action:SetPoint("BOTTOMRIGHT",f.body,"BOTTOMRIGHT",-2,2)
    f.goodbye=Button(f.body,"Goodbye",150,30); f.goodbye:SetPoint("RIGHT",f.action,"LEFT",-10,0)
    f.goodbye:SetScript("OnClick",function()
        if f.mode=="gossip" and CloseGossip then CloseGossip() elseif CloseQuest then CloseQuest() else f:Hide() end
    end)
    f.action:SetScript("OnClick",function() PhaseD:ActivateNPCAction() end)
    f.close:SetScript("OnClick",function() f.goodbye:Click() end)
end

function PhaseD:RefreshNPCRows()
    local f=self.frames.npc; if not f then return end
    local entries=f.entries or {}; local total=#entries; local maxOffset=math.max(0,total-8)
    if (f.offset or 0)>maxOffset then f.offset=maxOffset end
    for i=1,#f.rows do
        local r=f.rows[i]; local e=entries[(f.offset or 0)+i]
        if e then
            r.entry=e
            local state=e.state
            if not state then
                if e.kind=="available" or e.kind=="questAvailable" then state="available"
                elseif e.kind=="active" or e.kind=="questActive" then state="progress" end
            end
            -- Keep status and title visually distinct. Native/Ebonhold quest
            -- titles may contain their own dark inline color codes, so quest
            -- rows are rebuilt with Zen-owned colors instead of inheriting
            -- those parchment-oriented colors.
            r.name:SetTextColor(1,1,1)
            if state=="available" then
                r.name:SetText(QuestRowText("AVAILABLE",1,.82,.15,e.title))
            elseif state=="daily" then
                r.name:SetText(QuestRowText("DAILY",.35,.72,1,e.title))
            elseif state=="repeatable" then
                r.name:SetText(QuestRowText("REPEATABLE",.45,.78,1,e.title))
            elseif state=="dailyReady" then
                r.name:SetText(QuestRowText("DAILY  •  READY TO TURN IN",.35,1,.45,e.title))
            elseif state=="dailyProgress" then
                r.name:SetText(QuestRowText("DAILY  •  IN PROGRESS",.35,.72,1,e.title))
            elseif state=="ready" then
                r.name:SetText(QuestRowText("READY TO TURN IN",.35,1,.45,e.title))
            elseif state=="progress" then
                r.name:SetText(QuestRowText("IN PROGRESS",.88,.78,.50,e.title))
            else
                r.name:SetText(CleanQuestTitle(e.title) or "")
                local tr,tg,tb=RUI:GetTextColor(false); r.name:SetTextColor(tr,tg,tb)
            end
            r:Show()
        else r.entry=nil; r:Hide() end
    end
    if total>8 then f.prev:Show(); f.next:Show() else f.prev:Hide(); f.next:Hide() end
    if f.prev then if (f.offset or 0)>0 then f.prev:Enable() else f.prev:Disable() end end
    if f.next then if (f.offset or 0)+8<total then f.next:Enable() else f.next:Disable() end end
end

local function GossipReportedCounts()
    local available=GetNumGossipAvailableQuests and (tonumber(GetNumGossipAvailableQuests()) or 0) or 0
    local active=GetNumGossipActiveQuests and (tonumber(GetNumGossipActiveQuests()) or 0) or 0
    local options=GetNumGossipOptions and (tonumber(GetNumGossipOptions()) or 0) or 0
    return available,active,options
end

function PhaseD:RefreshGossip()
    local f=self.frames.npc; if not f then return false end
    f.mode="gossip"; f.rewardChoice=nil
    -- Put the controls into their final gossip state before touching any
    -- Ebonhold API. If a custom gossip provider errors or returns partial data,
    -- a stale quest Continue/Accept button can no longer remain visible.
    f.action:Hide(); f.goodbye:Show()

    -- Let the stock/Ebonhold Gossip renderer populate its hidden title buttons
    -- first. The native frame remains visually suppressed, but its rendered
    -- button labels are often more reliable than transient API payloads.
    if type(_G.GossipFrameUpdate)=="function" then pcall(_G.GossipFrameUpdate) end
    f.npcName:SetText(UnitName and (UnitName("npc") or "Conversation") or "Conversation")
    f.heading:SetText("Conversation")
    f.questView:Hide(); f.text:Show()
    f.text:SetText(GetGossipText and (GetGossipText() or "") or "")
    f.options:Show(); f.rewardLabel:Hide(); f.rewardHint:Hide(); for i=1,#f.rewards do f.rewards[i]:Hide() end

    local entries=BuildNativeGossipEntries()
    if #entries==0 then
        if GetGossipAvailableQuests then AddVarargRows(entries,"available",5,GetGossipAvailableQuests()) end
        if GetGossipActiveQuests then AddVarargRows(entries,"active",4,GetGossipActiveQuests()) end
        if GetGossipOptions then AddVarargRows(entries,"gossip",2,GetGossipOptions()) end
    end

    -- Never present blank clickable rows. Ebonhold occasionally reports a
    -- positive gossip/quest count while the corresponding title payload is not
    -- yet available to Lua. In that case the stock frame is a safer fallback
    -- than an unusable Zen Conversation panel.
    local reportedAvailable,reportedActive,reportedOptions=GossipReportedCounts()
    local reported=reportedAvailable+reportedActive+reportedOptions
    if reported>0 and #entries==0 then
        -- Never swallow a real quest giver. If Ebonhold reports entries but the
        -- title payload is temporarily undecodable, reveal its already-active
        -- native GossipFrame immediately. Functionality wins over styling.
        f.entries={}; f.offset=0; self:RefreshNPCRows(); f:Hide()
        ShowNativeGossipFallback(true)
        return false
    end

    f.entries=entries; f.offset=math.min(f.offset or 0,math.max(0,#entries-8)); self:RefreshNPCRows()
    return true
end

function PhaseD:ActivateNPCRow(row)
    local e=row and row.entry; if not e then return end
    if e.kind=="available" and SelectGossipAvailableQuest then SelectGossipAvailableQuest(e.index)
    elseif e.kind=="active" and SelectGossipActiveQuest then SelectGossipActiveQuest(e.index)
    elseif e.kind=="gossip" and SelectGossipOption then SelectGossipOption(e.index)
    elseif e.kind=="questActive" and SelectActiveQuest then SelectActiveQuest(e.index)
    elseif e.kind=="questAvailable" and SelectAvailableQuest then SelectAvailableQuest(e.index) end
end

local function QuestTitle()
    -- GetTitleText is only authoritative after a specific quest has been
    -- selected. Some Ebonhold QUEST_GREETING providers throw instead of
    -- returning nil while the NPC is still showing its quest list, so never
    -- let an unsafe title lookup force the whole Zen interaction to fall back.
    if type(GetTitleText)=="function" then
        local ok,title=pcall(GetTitleText)
        if ok and NonBlankText(title) then return tostring(title) end
    end
    return "Quest"
end

local function QuestNPCName()
    -- Stock QuestFrame uses the questnpc unit; gossip normally exposes npc.
    -- Prefer questnpc for direct quest pages and retain npc as an Ebonhold
    -- compatibility fallback.
    if type(UnitName)=="function" then
        local ok,name=pcall(UnitName,"questnpc")
        if ok and NonBlankText(name) then return tostring(name) end
        ok,name=pcall(UnitName,"npc")
        if ok and NonBlankText(name) then return tostring(name) end
    end
    return "Quest"
end

local function QuestTextHeight(fs,text)
    -- Some Wrath/Ebonhold builds report GetStringHeight for only the first
    -- visual line even when the FontString is wrapping several paragraphs.
    -- Always combine the measured value with a character/newline-based estimate
    -- so long quest text gets enough vertical space to render fully.
    text=tostring(text or "")
    local measured=0
    if fs and fs.GetStringHeight then measured=(fs:GetStringHeight() or 0) end
    measured=tonumber(measured) or 0

    local explicitLines=1
    for _ in string.gmatch(text,"\n") do explicitLines=explicitLines+1 end

    -- Estimate wrapped lines conservatively for a ~680px quest text column.
    local longest=0
    for line in string.gmatch(text.."\n","([^\n]*)\n") do
        if #line>longest then longest=#line end
    end
    local approxWrapped=math.ceil(#text/58)
    local approxLongest=math.ceil(longest/58)
    local estimatedLines=math.max(explicitLines, approxWrapped, approxLongest)
    local estimated=math.max(96, estimatedLines * 20)

    if measured < estimated then return estimated end
    return math.max(measured, 96)
end

local function LayoutQuestText(f,primaryTitle,primaryText,secondaryTitle,secondaryText,showRewards)
    if not f or not f.questView or not f.questBodyText then return end
    primaryText=tostring(primaryText or "")
    secondaryText=tostring(secondaryText or "")
    local chunks={}
    if primaryTitle and primaryTitle~="" then chunks[#chunks+1]="|cffffd36b"..tostring(primaryTitle).."|r" end
    if primaryText~="" then chunks[#chunks+1]="|cffdfe2e8"..primaryText.."|r" end
    if secondaryText~="" then
        chunks[#chunks+1]="|cffffd36b"..tostring(secondaryTitle or "OBJECTIVES").."|r"
        chunks[#chunks+1]="|cffdfe2e8"..secondaryText.."|r"
    end
    local combined=table.concat(chunks,"\n\n")
    f.questBodyText:SetText(combined)
    local h=QuestTextHeight(f.questBodyText,combined)
    local viewport=(f.questScroll.GetHeight and f.questScroll:GetHeight()) or 330
    -- Ebonhold/Wrath can report an incorrect FontString height immediately
    -- after setting long quest prose.  Give the text a generous document area
    -- first, then size the scroll child from the larger of the estimate and
    -- measured height. This guarantees paragraph wrapping instead of clipping
    -- the text to the first visual line.
    local documentHeight=math.max(viewport, h+30, 900)
    f.questBodyText:SetHeight(documentHeight-16)
    f.questContent:SetHeight(documentHeight)
    if f.questScroll.SetVerticalScroll then f.questScroll:SetVerticalScroll(0) end

    f.questTextPanel:ClearAllPoints(); f.questTextPanel:SetPoint("TOPLEFT",f.questView,"TOPLEFT",0,0); f.questTextPanel:SetPoint("RIGHT",f.questView,"RIGHT",0,0)
    if showRewards then
        f.questRewards:Show(); f.questTextPanel:SetPoint("BOTTOM",f.questRewards,"TOP",0,10)
    else
        f.questRewards:Hide(); f.questTextPanel:SetPoint("BOTTOM",f.questView,"BOTTOM",0,0)
    end
end

function PhaseD:RefreshQuestInteraction()
    local f=self.frames.npc; if not f then return end
    f.npcName:SetText(QuestNPCName())
    -- A greeting is a conversation/list, not a selected quest. Calling
    -- GetTitleText here is unsafe on at least one Ebonhold quest giver and was
    -- the reason Zen 1.0.7 correctly fell back to the parchment QuestFrame.
    -- Match the normal Zen gossip presentation until a quest row is selected.
    if f.mode=="greeting" then f.heading:SetText("Conversation") else f.heading:SetText(QuestTitle()) end
    for i=1,#f.rows do f.rows[i]:Hide(); f.rows[i].entry=nil end
    f.entries={}; f.prev:Hide(); f.next:Hide()
    f.rewardLabel:Hide(); f.rewardHint:Hide(); for i=1,#f.rewards do f.rewards[i]:Hide(); if f.rewards[i].count then f.rewards[i].count:SetText("") end end
    f.goodbye:Show(); f.action:Show()

    if f.mode=="greeting" then
        -- Quest greeting/list keeps the compact conversation list layout.
        -- Prefer the native QuestFrame's already-rendered rows.  This NPC path
        -- is Ebonhold-sensitive: individual GetActive/GetAvailable calls can be
        -- transient or throw even though Blizzard has successfully painted the
        -- parchment list.  Mirroring the rendered native buttons keeps Zen's
        -- visible shell without re-decoding the server packet.
        f.questView:Hide(); f.text:Show(); f.options:Show()
        local greeting,entries=BuildNativeQuestGreetingEntries()
        if not greeting then
            local text=SafeQuestCall(_G.GetGreetingText)
            greeting=NonBlankText(text) or ""
        end
        f.text:SetText(greeting or "")

        if #entries==0 then
            -- API fallback for clients where the native title buttons have not
            -- been laid out yet. Every private-server call is guarded.
            local active=SafeQuestCall(_G.GetNumActiveQuests)
            active=tonumber(active) or 0
            for i=1,active do
                local title,ok,isComplete=SafeQuestCall(_G.GetActiveTitle,i)
                if ok and NonBlankText(title) then
                    entries[#entries+1]={kind="questActive",index=i,title=title,state=QuestFlagTrue(isComplete) and "ready" or "progress"}
                end
            end
            local available=SafeQuestCall(_G.GetNumAvailableQuests)
            available=tonumber(available) or 0
            for i=1,available do
                local title,ok=SafeQuestCall(_G.GetAvailableTitle,i)
                if ok and NonBlankText(title) then
                    local isTrivial,isDaily,isRepeatable=nil,false,false
                    local _,infoOK,daily,repeatable=SafeQuestCall(_G.GetAvailableQuestInfo,i)
                    if infoOK then isDaily,isRepeatable=daily,repeatable end
                    local state=QuestFlagTrue(isDaily) and "daily" or (QuestFlagTrue(isRepeatable) and "repeatable" or "available")
                    entries[#entries+1]={kind="questAvailable",index=i,title=title,state=state,isDaily=QuestFlagTrue(isDaily),isRepeatable=QuestFlagTrue(isRepeatable)}
                end
            end
        end

        -- If Blizzard reports quest rows but Zen still cannot decode/mirror any
        -- of them, do not show a blank Zen panel. Let TryOpenNPC restore native.
        local active=SafeQuestCall(_G.GetNumActiveQuests)
        local available=SafeQuestCall(_G.GetNumAvailableQuests)
        if ((tonumber(active) or 0)+(tonumber(available) or 0))>0 and #entries==0 then return false end

        f.entries=entries; f.offset=0; self:RefreshNPCRows(); f.action:Hide()
        return true
    end

    -- Dedicated structured quest page. Hide the gossip controls completely so
    -- description/objective text cannot render into the option box underneath.
    f.text:Hide(); f.options:Hide(); f.questView:Show()

    if f.mode=="detail" then
        local body=(GetQuestText and GetQuestText() or "")
        local obj=(GetObjectiveText and GetObjectiveText() or "")
        if not obj or obj=="" then
            -- Some Ebonhold quest packets omit GetObjectiveText on the initial
            -- offer even though the request is described in the quest prose.
            -- Keep the full multiline description visible and provide a clear
            -- fallback rather than leaving the objectives area blank.
            obj="Accept this quest to begin tracking its exact objectives."
        end
        LayoutQuestText(f,"QUEST DESCRIPTION",body,"OBJECTIVES / WHAT TO DO",obj,false)
        f.action.RUIText:SetText("Accept"); f.action:Enable()
    elseif f.mode=="progress" then
        local progress=(GetProgressText and (GetProgressText() or "") or "")
        local obj=(GetObjectiveText and GetObjectiveText() or "")
        local ready=IsQuestCompletable and IsQuestCompletable()
        LayoutQuestText(f,ready and "READY TO TURN IN" or "IN PROGRESS",progress,"OBJECTIVES",obj,false)
        f.action.RUIText:SetText(ready and "Complete Quest" or "Requirements Incomplete")
        if ready then f.action:Enable() else f.action:Disable() end
    elseif f.mode=="complete" then
        local rewardText=(GetRewardText and (GetRewardText() or "") or "")
        LayoutQuestText(f,"READY TO TURN IN",rewardText,nil,nil,true)
        f.action.RUIText:SetText("Complete Quest")
        local choices=GetNumQuestChoices and tonumber(GetNumQuestChoices()) or 0; local rewards=GetNumQuestRewards and tonumber(GetNumQuestRewards()) or 0
        local kind=(choices>0) and "choice" or "reward"; local count=(choices>0) and choices or rewards
        if count>0 then
            f.rewardLabel:SetText((choices>0) and "CHOOSE YOUR REWARD" or "REWARDS"); f.rewardLabel:Show(); f.rewardHint:Show()
            for i=1,math.min(count,#f.rewards) do
                local name,texture,numItems=nil,nil,nil
                if GetQuestItemInfo then name,texture,numItems=GetQuestItemInfo(kind,i) end
                local b=f.rewards[i]; b.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark"); b:Show(); RUI:RefreshBackdrop(b)
                if b.count then b.count:SetText((tonumber(numItems) or 1)>1 and tostring(numItems) or "") end
                if f.rewardChoice==i then local ar,ag,ab=RUI:GetAccentColor(); RUI:SetBorderColor(b,ar,ag,ab,1) end
            end
        else
            f.rewardLabel:SetText("NO ITEM REWARD"); f.rewardLabel:Show()
        end
        if choices>0 and not f.rewardChoice then f.action:Disable() else f.action:Enable() end
    end
    return true
end

function PhaseD:ActivateNPCAction()
    local f=self.frames.npc; if not f then return end
    if f.mode=="detail" then
        if QuestFlagsPVP and QuestFlagsPVP() and StaticPopup_Show then
            StaticPopup_Show("CONFIRM_ACCEPT_PVP_QUEST")
        elseif AcceptQuest then
            AcceptQuest()
            -- Accept is terminal for this quest page. Some Ebonhold paths omit
            -- QUEST_FINISHED, so explicitly allow the next gossip/list event to
            -- take ownership instead of leaving Conversation permanently stuck.
            self.questTerminalActionPending=true
        end
    elseif f.mode=="progress" then
        if IsQuestCompletable and IsQuestCompletable() and CompleteQuest then CompleteQuest() end
    elseif f.mode=="complete" then
        if GetQuestReward then
            GetQuestReward(f.rewardChoice or 0)
            self.questTerminalActionPending=true
        end
    end
end

function PhaseD:OpenNPC(mode)
    if not Enabled("npcDialog") then return end
    local f=self.frames.npc; f.mode=mode or "gossip"
    if mode=="gossip" then
        if self:RefreshGossip()==false then return end
    else
        if self:RefreshQuestInteraction()==false then return end
    end
    ShowExclusive(f)
    SuppressNative(_G.GossipFrame); SuppressNative(_G.QuestFrame)
end

-- Open Conversation as an all-or-nothing handoff.  Native interaction frames
-- are the safety net: only keep them suppressed if the Zen panel actually made
-- it on screen.  pcall is deliberate here because private-server quest payloads
-- can expose transient API values that differ from stock Wrath.
function PhaseD:TryOpenNPC(mode)
    mode=mode or "gossip"
    if mode=="gossip" then self.allowNativeGossip=false else self.allowNativeQuest=false end

    local ok,err=pcall(self.OpenNPC,self,mode)
    if not ok and RUI and RUI.RecordRuntimeError then
        RUI:RecordRuntimeError("Conversation",mode,err)
    end
    local f=self.frames and self.frames.npc
    if ok and f and f.IsShown and f:IsShown() then
        if mode=="gossip" then self.allowNativeGossip=false else self.allowNativeQuest=false end
        return true
    end

    if f and f.IsShown and f:IsShown() then f:Hide() end
    if mode=="gossip" then
        ShowNativeGossipFallback(true)
    else
        ShowNativeQuestFallback(true)
    end
    return false
end

-- -------------------------------------------------------------------------
-- Native-frame hooks and events
-- -------------------------------------------------------------------------
function PhaseD:InstallInspectHooks()
    if not Enabled("inspect") then return end
    if IsAddOnLoaded and not IsAddOnLoaded("Blizzard_InspectUI") and LoadAddOn then pcall(LoadAddOn,"Blizzard_InspectUI") end
    if _G.InspectFrame and not _G.InspectFrame.RUIPhaseDHooked then
        _G.InspectFrame.RUIPhaseDHooked=true
        _G.InspectFrame:HookScript("OnShow",function(stock)
            if not Enabled("inspect") then return end
            local unit=stock.unit or "target"
            PhaseD:OpenInspect(unit)
            SuppressNative(stock)
        end)
    end
end

-- Ebonhold callboards/objective boards reuse the stock GOSSIP_SHOW event as a
-- transport trigger, but render their own dedicated board UI. Treating them as
-- ordinary NPC gossip creates a blank Zen Conversation window on top of the
-- real board. Keep those interactions entirely in Ebonhold's native/custom UI.
local function ShouldBypassNPCDialog()
    local name=(UnitName and UnitName("npc")) or ""
    name=string.lower(tostring(name or ""))
    if name=="" then return false end
    local patterns={
        "objectives board",
        "objective board",
        "callboard",
        "call board",
        "hero's call board",
        "warchief's command board",
        "command board",
        "mission board",
        -- Ebonhold custom interaction object. It can emit GOSSIP_SHOW as a
        -- transport event before its own Affix Forge UI takes over.
        "affix forge",
    }
    for i=1,#patterns do
        if string.find(name,patterns[i],1,true) then return true end
    end
    return false
end

-- A late GOSSIP_SHOW can arrive after QUEST_GREETING/DETAIL on Ebonhold. The
-- stock QuestFrame remains shown even while Zen suppresses it by alpha, so
-- use that visibility (plus Zen's own non-gossip mode) as an ownership
-- signal. Gossip must never steal the panel back while a quest page is active.
local function QuestInteractionOwnsNPCPanel()
    -- While a direct QUEST_* payload is still settling, it already owns this
    -- interaction. Ebonhold can emit a late GOSSIP_SHOW during that transition;
    -- do not let Gossip cancel/race the pending quest probe.
    if PhaseD.pendingQuestMode then return true end

    -- Zen's visible quest page is the normal ownership signal. A terminal quest
    -- action (AcceptQuest/GetQuestReward) is different: after the click, the
    -- *next* GOSSIP_SHOW belongs to the next conversation/list and must be
    -- allowed to replace the old quest page even if Ebonhold never sends the
    -- expected QUEST_FINISHED event.
    local f=PhaseD.frames and PhaseD.frames.npc
    if PhaseD.questTerminalActionPending then
        PhaseD.questTerminalActionPending=false
        PhaseD.questInteractionActive=false
        if f and f.IsShown and f:IsShown() and f.mode and f.mode~="gossip" then f:Hide() end
        return false
    end

    if f and f.IsShown and f:IsShown() and f.mode and f.mode~="gossip" then return true end

    -- Defensive stale-state recovery. Ebonhold does not consistently emit
    -- QUEST_FINISHED for every accept/close path. Never let an invisible old
    -- lifecycle flag suppress a later real NPC conversation.
    if PhaseD.questInteractionActive then PhaseD.questInteractionActive=false end
    return false
end

local function IsDescendantOf(frame,parent)
    if not frame or not parent then return false end
    local current=frame
    for _=1,16 do
        if current==parent then return true end
        if not current.GetParent then break end
        current=current:GetParent()
        if not current then break end
    end
    return false
end

function PhaseD:ReleaseNPCKeyboardFocus()
    -- The Zen conversation itself has no edit box, but some private-server
    -- quest/gossip implementations can leave an internal keyboard-focus owner
    -- alive for a frame after the visible page closes. Only clear focus when it
    -- belongs to this interaction tree; never disturb chat or another editor.
    if type(_G.GetCurrentKeyBoardFocus)~="function" then return end
    local ok,focus=pcall(_G.GetCurrentKeyBoardFocus)
    if not ok or not focus then return end
    local f=self.frames and self.frames.npc
    if IsDescendantOf(focus,f) or IsDescendantOf(focus,_G.GossipFrame) or IsDescendantOf(focus,_G.QuestFrame) then
        if focus.ClearFocus then pcall(focus.ClearFocus,focus) end
    end
end

function PhaseD:FinishQuestInteraction()
    self.questInteractionActive=false
    self.questTerminalActionPending=false
    self:CancelPendingGossip()
    self:CancelPendingQuest()
    self.allowNativeGossip=true
    local f=self.frames and self.frames.npc
    if f then
        f.mode="gossip"
        if f:IsShown() then f:Hide() end
    end
    RestoreNative(_G.GossipFrame)
    RestoreNative(_G.QuestFrame)
    self:ReleaseNPCKeyboardFocus()
end

-- GOSSIP_SHOW is not always a final "show an NPC conversation" instruction on
-- Ebonhold. Some custom objects fire it as a transport event and open their own
-- UI a fraction of a second later. Probe the payload after a short grace period
-- instead of immediately putting Zen's Conversation frame on screen.
local function HasMeaningfulGossipPayload()
    -- Ebonhold can populate the stock GossipTitleButtons before the public
    -- vararg APIs become coherent. Treat those rendered native rows as valid
    -- gossip too; this avoids falsely classifying a real NPC as an empty handoff.
    if type(_G.GossipFrameUpdate)=="function" then pcall(_G.GossipFrameUpdate) end
    local nativeEntries=BuildNativeGossipEntries()
    if #nativeEntries>0 then return true end

    local hasEntries=false
    if GetGossipAvailableQuests then
        local first=GetGossipAvailableQuests()
        if first~=nil and tostring(first)~="" then hasEntries=true end
    end
    if not hasEntries and GetGossipActiveQuests then
        local first=GetGossipActiveQuests()
        if first~=nil and tostring(first)~="" then hasEntries=true end
    end
    if not hasEntries and GetGossipOptions then
        local first=GetGossipOptions()
        if first~=nil and tostring(first)~="" then hasEntries=true end
    end
    if hasEntries then return true end

    -- Text-only gossip is valid for a real NPC. For anonymous game objects,
    -- however, a text-only/empty GOSSIP_SHOW is much more likely to be a custom
    -- interaction hand-off, so leave Zen closed.
    local npcName=(UnitName and UnitName("npc")) or ""
    local text=(GetGossipText and GetGossipText()) or ""
    if tostring(npcName or "")~="" and string.find(tostring(text or ""),"%S") then return true end
    return false
end


-- Direct quest pages (especially a single ready-to-turn-in quest) can arrive on
-- Ebonhold without a preceding GOSSIP_SHOW.  Those QUEST_* events may fire one
-- or two frames before GetTitleText/GetProgressText/etc. are populated.  Gossip
-- already has a bounded coherence probe; give the direct quest path the same
-- protection instead of trying to render transient data immediately.
local function SafeQuestValue(fn,...)
    return SafeQuestCall(fn,...)
end

local function QuestPayloadReady(mode)
    mode=tostring(mode or "")
    local title=SafeQuestValue(_G.GetTitleText)
    if NonBlankText(title) then return true end

    if mode=="greeting" then
        local nativeText,nativeEntries=BuildNativeQuestGreetingEntries()
        if NonBlankText(nativeText) or #nativeEntries>0 then return true end
        local text=SafeQuestValue(_G.GetGreetingText)
        if NonBlankText(text) then return true end
        local active=SafeQuestValue(_G.GetNumActiveQuests)
        local available=SafeQuestValue(_G.GetNumAvailableQuests)
        if (tonumber(active) or 0)>0 or (tonumber(available) or 0)>0 then return true end
    elseif mode=="detail" then
        local body=SafeQuestValue(_G.GetQuestText)
        local objective=SafeQuestValue(_G.GetObjectiveText)
        if NonBlankText(body) or NonBlankText(objective) then return true end
    elseif mode=="progress" then
        local progress=SafeQuestValue(_G.GetProgressText)
        local objective=SafeQuestValue(_G.GetObjectiveText)
        if NonBlankText(progress) or NonBlankText(objective) then return true end
    elseif mode=="complete" then
        local rewardText=SafeQuestValue(_G.GetRewardText)
        if NonBlankText(rewardText) then return true end
    end
    return false
end

function PhaseD:CancelPendingQuest()
    self.pendingQuestMode=nil
    self.questProbeElapsed=0
    self.questProbeNext=0
    self.questProbeAttempts=0
    if self.questProbe then self.questProbe:Hide() end
end

function PhaseD:QueueQuestOpen(mode)
    self:CancelPendingQuest()
    self.allowNativeQuest=false
    self.questInteractionActive=true
    self.questTerminalActionPending=false
    self:CancelPendingGossip()
    RestoreNative(_G.GossipFrame)

    if ShouldBypassNPCDialog() then
        self.questInteractionActive=false
        if self.frames.npc and self.frames.npc:IsShown() then self.frames.npc:Hide() end
        ShowNativeQuestFallback(false)
        return
    end
    if not Enabled("npcDialog") then
        self.questInteractionActive=false
        ShowNativeQuestFallback(false)
        return
    end

    -- Keep the already-open stock frame alive but invisible while its own
    -- event/update code finishes filling the quest APIs.
    SuppressNative(_G.QuestFrame)
    self.pendingQuestMode=mode
    self.questProbeElapsed=0
    self.questProbeNext=0.04
    self.questProbeAttempts=0
    if self.questProbe then self.questProbe:Show() else self:ResolvePendingQuest(true) end
end

function PhaseD:ResolvePendingQuest(forceFinal)
    local mode=self.pendingQuestMode
    if not mode then return end
    local elapsed=tonumber(self.questProbeElapsed) or 0
    self.questProbeAttempts=(tonumber(self.questProbeAttempts) or 0)+1

    if not Enabled("npcDialog") or ShouldBypassNPCDialog() then
        self:CancelPendingQuest()
        self.questInteractionActive=false
        ShowNativeQuestFallback(true)
        return
    end

    if QuestPayloadReady(mode) then
        self:CancelPendingQuest()
        if self:TryOpenNPC(mode) then return end
        self.questInteractionActive=false
        ShowNativeQuestFallback(true)
        return
    end

    -- A few frames is enough for the stock Wrath quest provider, while
    -- Ebonhold sometimes needs longer.  Keep this bounded and interaction-local.
    if not forceFinal and elapsed < 0.56 then
        self.questProbeNext=elapsed+0.04
        return
    end

    self:CancelPendingQuest()
    self.questInteractionActive=false
    if self.frames.npc and self.frames.npc:IsShown() then self.frames.npc:Hide() end
    ShowNativeQuestFallback(true)
end

function PhaseD:CancelPendingGossip()
    self.pendingGossip=false
    self.gossipProbeElapsed=0
    self.gossipProbeNext=0
    self.gossipProbeAttempts=0
    if self.gossipProbe then self.gossipProbe:Hide() end
end

function PhaseD:QueueGossipOpen()
    self:CancelPendingGossip()
    self.allowNativeGossip=false
    if not Enabled("npcDialog") then return end
    if QuestInteractionOwnsNPCPanel() then
        -- Ebonhold sometimes emits this after the quest event. Keep the hidden
        -- native GossipFrame quiet and leave the active quest page untouched.
        SuppressNative(_G.GossipFrame)
        return
    end
    if ShouldBypassNPCDialog() then
        if self.frames.npc and self.frames.npc:IsShown() and self.frames.npc.mode=="gossip" then self.frames.npc:Hide() end
        ShowNativeGossipFallback(false)
        return
    end

    -- Ebonhold uses GOSSIP_SHOW both for normal NPC gossip and as a transport
    -- event into custom interfaces. Give the client a short, bounded handoff
    -- window instead of deciding from the first transient payload.
    SuppressNative(_G.GossipFrame)
    self.pendingGossip=true
    self.gossipProbeElapsed=0
    self.gossipProbeNext=0.08
    self.gossipProbeAttempts=0
    if self.gossipProbe then self.gossipProbe:Show() else self:ResolvePendingGossip(true) end
end

function PhaseD:ResolvePendingGossip(forceFinal)
    if not self.pendingGossip then return end

    local elapsed=tonumber(self.gossipProbeElapsed) or 0
    self.gossipProbeAttempts=(tonumber(self.gossipProbeAttempts) or 0)+1

    if not Enabled("npcDialog") then
        self:CancelPendingGossip(); ShowNativeGossipFallback(false); return
    end
    if ShouldBypassNPCDialog() then
        self:CancelPendingGossip(); ShowNativeGossipFallback(false); return
    end
    if QuestInteractionOwnsNPCPanel() then
        self:CancelPendingGossip(); SuppressNative(_G.GossipFrame); return
    end

    -- A stronger service event winning during the grace window means the
    -- initial gossip event was only a transition. Do not stack Conversation on
    -- top of Merchant/Trainer.
    if (_G.MerchantFrame and _G.MerchantFrame.IsShown and _G.MerchantFrame:IsShown())
        or (_G.ClassTrainerFrame and _G.ClassTrainerFrame.IsShown and _G.ClassTrainerFrame:IsShown())
        or (_G.TrainerFrame and _G.TrainerFrame.IsShown and _G.TrainerFrame:IsShown()) then
        self:CancelPendingGossip(); ShowNativeGossipFallback(false); return
    end

    local reportedAvailable,reportedActive,reportedOptions=GossipReportedCounts()
    local meaningful=HasMeaningfulGossipPayload()
    if (reportedAvailable+reportedActive+reportedOptions)>0 or meaningful then
        self:CancelPendingGossip()
        self.allowNativeGossip=false
        self:TryOpenNPC("gossip")
        return
    end

    -- Data is still empty. Ebonhold frequently needs a few frames to populate
    -- custom/quest handoffs, so retry briefly. The probe exists only while this
    -- one interaction is unresolved; there is no permanent OnUpdate polling.
    if not forceFinal and elapsed < 0.64 then
        self.gossipProbeNext=elapsed+0.08
        return
    end

    -- Final safety rule: never leave the player with neither Zen nor native UI.
    -- If Zen cannot prove it owns a usable conversation, hand control back.
    self:CancelPendingGossip()
    if self.frames.npc and self.frames.npc:IsShown() and self.frames.npc.mode=="gossip" then self.frames.npc:Hide() end
    ShowNativeGossipFallback(true)
end

function PhaseD:InstallServiceHooks()
    local frames={_G.ClassTrainerFrame,_G.TrainerFrame}
    for i=1,#frames do local frame=frames[i]; if frame and not frame.RUIPhaseDHooked and frame.HookScript then frame.RUIPhaseDHooked=true; frame:HookScript("OnShow",function(self) if Enabled("trainer") then SuppressNative(self) end end) end end
    if _G.GossipFrame and not _G.GossipFrame.RUIPhaseDHooked and _G.GossipFrame.HookScript then
        _G.GossipFrame.RUIPhaseDHooked=true
        _G.GossipFrame:HookScript("OnShow",function(self)
            if Enabled("npcDialog") and not ShouldBypassNPCDialog() and not PhaseD.allowNativeGossip then SuppressNative(self) end
        end)
    end
    if _G.QuestFrame and not _G.QuestFrame.RUIPhaseDHooked and _G.QuestFrame.HookScript then
        _G.QuestFrame.RUIPhaseDHooked=true
        _G.QuestFrame:HookScript("OnShow",function(self)
            if Enabled("npcDialog") and not ShouldBypassNPCDialog() and not PhaseD.allowNativeQuest then SuppressNative(self) end
        end)
    end
end

function PhaseD:OnEvent(event,...)
    if event=="ADDON_LOADED" then
        local addon=...; if addon=="Blizzard_InspectUI" then self:InstallInspectHooks() end; self:InstallServiceHooks(); return
    end
    if event=="PLAYER_LOGIN" then self:InstallInspectHooks(); self:InstallServiceHooks(); return end
    if event=="INSPECT_READY" then if self.frames.inspect:IsShown() then self:RefreshInspect() end; return end
    if event=="PLAYER_TARGET_CHANGED" then
        if self.frames.inspect:IsShown() then
            if self.frames.inspect.unit=="target" then self.frames.inspect:Hide() else self:RefreshInspect() end
        end
        return
    end
    if event=="TRAINER_SHOW" then
        self:CancelPendingGossip(); RestoreNative(_G.GossipFrame)
        if Enabled("trainer") then SuppressNative(_G.ClassTrainerFrame); SuppressNative(_G.TrainerFrame); ShowExclusive(self.frames.trainer); self.frames.trainer.selected=nil; self.frames.trainer.offset=0; self:RefreshTrainer() end; return
    end
    if event=="TRAINER_UPDATE" then if self.frames.trainer:IsShown() then self:RefreshTrainer() end; return end
    if event=="TRAINER_CLOSED" then self.frames.trainer:Hide(); RestoreNative(_G.ClassTrainerFrame); RestoreNative(_G.TrainerFrame); return end
    if event=="GOSSIP_SHOW" then self:QueueGossipOpen(); return end
    if event=="GOSSIP_CLOSED" then
        self:CancelPendingGossip()
        self.allowNativeGossip=false
        local npc=self.frames and self.frames.npc
        local questVisible=npc and npc.IsShown and npc:IsShown() and npc.mode and npc.mode~="gossip"
        if not self.pendingQuestMode and not questVisible then self.questInteractionActive=false end
        if npc and npc.mode=="gossip" then npc:Hide() end
        RestoreNative(_G.GossipFrame)
        self:ReleaseNPCKeyboardFocus()
        return
    end
    if event=="MERCHANT_SHOW" then self:CancelPendingGossip(); RestoreNative(_G.GossipFrame); return end
    if event=="QUEST_GREETING" then self:QueueQuestOpen("greeting"); return end
    if event=="QUEST_DETAIL" then self:QueueQuestOpen("detail"); return end
    if event=="QUEST_PROGRESS" then self:QueueQuestOpen("progress"); return end
    if event=="QUEST_COMPLETE" then self:QueueQuestOpen("complete"); return end
    if event=="QUEST_ACCEPTED" then
        -- Successful acceptance is authoritative proof that the offer page no
        -- longer owns the interaction. This closes the lifecycle even on
        -- Ebonhold paths that fail to emit QUEST_FINISHED afterward.
        self:FinishQuestInteraction()
        return
    end
    if event=="QUEST_ITEM_UPDATE" then
        -- Blizzard only uses QUEST_ITEM_UPDATE to refresh an already-open quest
        -- page. It is also fired for unrelated quest-item changes, so never use
        -- it as a reason to open or switch Zen to the completion page.
        local f=self.frames and self.frames.npc
        if f and f.IsShown and f:IsShown() and f.mode and f.mode~="gossip" and f.mode~="greeting" then
            self:RefreshQuestInteraction()
        end
        return
    end
    if event=="QUEST_FINISHED" then self:FinishQuestInteraction(); return end
end

function PhaseD:OnInitialize()
    self.frames={}
    self:CreateInspect(); self:CreateTrainer(); self:CreateNPC()
    self.questInteractionActive=false
    self.questTerminalActionPending=false
    self.allowNativeGossip=false
    self.allowNativeQuest=false
    self.questProbe=CreateFrame("Frame")
    self.questProbe:Hide()
    self.questProbeElapsed=0
    self.questProbeNext=0
    self.questProbeAttempts=0
    self.questProbe:SetScript("OnUpdate",function(_,elapsed)
        if not PhaseD.pendingQuestMode then PhaseD.questProbe:Hide(); return end
        PhaseD.questProbeElapsed=(PhaseD.questProbeElapsed or 0)+(elapsed or 0)
        if PhaseD.questProbeElapsed >= (PhaseD.questProbeNext or 0.04) then
            local final=PhaseD.questProbeElapsed>=0.56
            local ok,err=pcall(PhaseD.ResolvePendingQuest,PhaseD,final)
            if not ok then
                PhaseD:CancelPendingQuest()
                PhaseD.questInteractionActive=false
                if RUI.RecordRuntimeError then RUI:RecordRuntimeError("interaction","quest probe",err) end
                ShowNativeQuestFallback(true)
            end
        end
    end)
    self.gossipProbe=CreateFrame("Frame")
    self.gossipProbe:Hide()
    self.gossipProbeElapsed=0
    self.gossipProbeNext=0
    self.gossipProbeAttempts=0
    self.gossipProbe:SetScript("OnUpdate",function(_,elapsed)
        if not PhaseD.pendingGossip then PhaseD.gossipProbe:Hide(); return end
        PhaseD.gossipProbeElapsed=(PhaseD.gossipProbeElapsed or 0)+(elapsed or 0)
        if PhaseD.gossipProbeElapsed >= (PhaseD.gossipProbeNext or 0.08) then
            local final=PhaseD.gossipProbeElapsed>=0.64
            local ok,err=pcall(PhaseD.ResolvePendingGossip,PhaseD,final)
            if not ok then
                PhaseD:CancelPendingGossip()
                if RUI.RecordRuntimeError then RUI:RecordRuntimeError("interaction","gossip probe",err) end
                if PhaseD.frames.npc and PhaseD.frames.npc:IsShown() and PhaseD.frames.npc.mode=="gossip" then PhaseD.frames.npc:Hide() end
                ShowNativeGossipFallback(true)
            end
        end
    end)
    for key,info in pairs(PANEL_INFO) do
        RUI:RegisterMover(info.mover,self.frames[key],{label=info.title,width=info.width,height=info.height,point="CENTER",relativePoint="CENTER",x=info.x,y=info.y})
        if RUI.EnableDirectPanelDrag then RUI:EnableDirectPanelDrag(self.frames[key], info.mover) end
    end
end

function PhaseD:ApplySettings()
    for key,info in pairs(PANEL_INFO) do
        local setting = key=="npc" and "npcDialog" or key
        local enabled = Enabled(setting)
        RUI:SetMoverEnabled(info.mover,enabled)
        ApplyScale(key)
        if not enabled then
            if self.frames and self.frames[key] then self.frames[key]:Hide() end
            if key=="inspect" then
                RestoreNative(_G.InspectFrame)
            elseif key=="trainer" then
                RestoreNative(_G.ClassTrainerFrame); RestoreNative(_G.TrainerFrame)
            elseif key=="npc" then
                self:CancelPendingGossip()
                RestoreNative(_G.GossipFrame); RestoreNative(_G.QuestFrame)
            end
        end
    end
end

function PhaseD:OnEnable()
    self:ApplySettings()
    local events={"ADDON_LOADED","PLAYER_LOGIN","INSPECT_READY","PLAYER_TARGET_CHANGED","TRAINER_SHOW","TRAINER_UPDATE","TRAINER_CLOSED","GOSSIP_SHOW","GOSSIP_CLOSED","MERCHANT_SHOW","QUEST_GREETING","QUEST_DETAIL","QUEST_PROGRESS","QUEST_COMPLETE","QUEST_ACCEPTED","QUEST_FINISHED","QUEST_ITEM_UPDATE"}
    for i=1,#events do self:RegisterEvent(events[i],"OnEvent") end
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED",self,"OnScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET",self,"ApplySettings")
    self:InstallInspectHooks(); self:InstallServiceHooks()
end

function PhaseD:OnScaleChanged(key)
    for name,info in pairs(PANEL_INFO) do if key=="all" or key==info.scale then ApplyScale(name) end end
end
