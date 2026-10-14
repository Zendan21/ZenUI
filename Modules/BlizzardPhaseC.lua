-- ZenUI 0.9.20 Phase C replacement panels.
-- Initial Phase C scope: player Talents.  The visible frame is Zen-owned,
-- while all learning, preview, spec activation, links and tooltips remain backed
-- by the native Wrath 3.3.5 talent APIs.

local RUI = ZenUI
local PhaseC = RUI:NewModule("BlizzardPhaseC")

local INFO = {
    talents = {
        setting = "talents",
        scale = "zenTalents",
        mover = "ZenTalents",
        label = "Talents",
        width = 760,
        height = 660,
        x = -300,
        y = 5,
    },
}

local TALENT_COLUMNS = 4
local BUTTON_SIZE = 42
local BUTTON_PITCH_X = 112
local BUTTON_PITCH_Y = 58
local BUTTON_START_X = 54
local BUTTON_START_Y = -40
local TREE_VIEW_WIDTH = 520
local TREE_VIEW_HEIGHT = 486
local MAX_TALENT_BUTTONS = 60
local MAX_TALENT_GROUPS = 5
local MAX_TREE_TABS = 3

local function Settings()
    if not RUI.db then return nil end
    RUI.db.blizzard = RUI.db.blizzard or {}
    return RUI.db.blizzard
end

local function Enabled()
    local settings = Settings()
    if not settings or settings.enabled == false then return false end
    if settings.talents == nil then return true end
    return settings.talents and true or false
end

local function Safe(label, fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p = pcall(fn, ...)
    if not ok then
        RUI:Debug("Phase C "..tostring(label).." failed: "..tostring(a))
        return false
    end
    return true,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p
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
    b:SetWidth(width or 100)
    b:SetHeight(height or 24)
    b.RUIText = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.RUIText:SetPoint("CENTER")
    b.RUIText:SetText(label or "Button")
    RUI:StyleButton(b)
    return b
end

local function SetButtonEnabled(button, enabled)
    if not button then return end
    if enabled then button:Enable() else button:Disable() end
    local r,g,b = RUI:GetTextColor(not enabled)
    if button.RUIText then button.RUIText:SetTextColor(r,g,b) end
end

local function AddSpecial(frame)
    if not frame or not frame.GetName or not frame:GetName() then return end
    UISpecialFrames = UISpecialFrames or {}
    for i=1,#UISpecialFrames do
        if UISpecialFrames[i] == frame:GetName() then return end
    end
    table.insert(UISpecialFrames, frame:GetName())
end

local function Panel(name, title)
    local info = INFO.talents
    local f = CreateFrame("Frame", name, UIParent)
    f:SetWidth(info.width)
    f:SetHeight(info.height)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()
    f.RUIPhaseCKey = "talents"
    RUI:CreateBackdrop(f)
    f.accent = RUI:CreateAccentLine(f, 2)
    f.title = Text(f, title, 15, "TOPLEFT", f, "TOPLEFT", 16, -17, false)
    f.subtitle = Text(f, "Zen talent planner", 8, "LEFT", f.title, "RIGHT", 10, -1, true)
    f.close = Button(f, "X", 28, 24)
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.body = CreateFrame("Frame", nil, f)
    f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -48)
    f.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    AddSpecial(f)
    if RUI.RegisterExclusivePanel then RUI:RegisterExclusivePanel(f) end
    return f
end

local function HasEbonholdSpecSystem()
    local pe=_G.ProjectEbonhold
    if type(pe)~="table" then return false end
    if type(pe.SpecService)=="table" and type(pe.SpecService.ApplySpec)=="function" then return true end
    if type(pe.sendToServer)=="function" and type(pe.CS)=="table" and pe.CS.REQUEST_APPLY_SPECS then return true end
    return false
end

local function GetNumGroups()
    -- Ebonhold's five specs are a separate server-backed layer; they are not
    -- GetNumTalentGroups() indices.  Keep five entries in our selector while
    -- passing only the real Wrath group index to talent APIs.
    if HasEbonholdSpecSystem() then return MAX_TALENT_GROUPS end
    if type(GetNumTalentGroups) ~= "function" then return 1 end
    local ok, value = pcall(GetNumTalentGroups, false, false)
    if not ok then ok, value = pcall(GetNumTalentGroups) end
    value = tonumber(value) or 1
    if value < 1 then value = 1 end
    if value > MAX_TALENT_GROUPS then value = MAX_TALENT_GROUPS end
    return value
end

local function TalentGroupLabel(group)
    group=tonumber(group) or 1
    if group==1 then return "Primary Specialization" end
    if group==2 then return "Secondary Specialization" end
    if group==3 then return "Third Specialization" end
    if group==4 then return "Fourth Specialization" end
    if group==5 then return "Fifth Specialization" end
    return "Specialization "..tostring(group)
end

local function CharacterSpecVisualTable(key)
    local settings=Settings()
    if not settings then return {} end
    settings[key]=settings[key] or {}
    local character=(RUI.GetCharacterKey and RUI:GetCharacterKey()) or "Unknown"
    settings[key][character]=settings[key][character] or {}
    return settings[key][character]
end

local function SpecNameTable()
    return CharacterSpecVisualTable("talentSpecNames")
end

local function SpecIconTable()
    return CharacterSpecVisualTable("talentSpecIcons")
end

local function SpecDisplayName(spec)
    spec=tonumber(spec) or 1
    local custom=SpecNameTable()[spec]
    if type(custom)=="string" and string.find(custom,"%S") then return custom end
    return TalentGroupLabel(spec)
end

local function SetSpecDisplayName(spec,name)
    spec=tonumber(spec)
    if not spec or spec<1 or spec>MAX_TALENT_GROUPS then return end
    name=tostring(name or "")
    name=string.gsub(name,"^%s+","")
    name=string.gsub(name,"%s+$","")
    if #name>24 then name=string.sub(name,1,24) end
    if name=="" or name==TalentGroupLabel(spec) then
        SpecNameTable()[spec]=nil
    else
        SpecNameTable()[spec]=name
    end
end

local function ReadEbonholdSpecIndex()
    -- Once Zen has received/observed a confirmed Ebonhold spec index, that
    -- value is authoritative. Some ProjectEbonhold builds expose fields named
    -- selectedSpec/currentSpec that remain at 1 even while another persistent
    -- spec is active; consulting those first made the selector snap back to
    -- "Primary" although the server had already loaded spec 2-5 correctly.
    local cached=tonumber(PhaseC.ebonholdSpecIndex)
    if cached and cached>=1 and cached<=MAX_TALENT_GROUPS then return cached end

    local pe=_G.ProjectEbonhold
    if type(pe)=="table" and type(pe.Spec)=="table" then
        local keys={"selectedSpecIndex","currentSpecIndex","activeSpecIndex","selectedSpec","currentSpec","activeSpec"}
        for i=1,#keys do
            local value=tonumber(pe.Spec[keys[i]])
            if value and value>=1 and value<=MAX_TALENT_GROUPS then return value end
        end
    end
    return 1
end

local function RequestEbonholdCurrentSpec()
    local pe=_G.ProjectEbonhold
    if type(pe)~="table" then return false end
    if type(pe.sendToServer)=="function" and type(pe.CS)=="table" and pe.CS.REQUEST_CURRENT_SPEC then
        local ok=pcall(pe.sendToServer,pe.CS.REQUEST_CURRENT_SPEC,"")
        return ok and true or false
    end
    return false
end

local function ApplyEbonholdSpec(index)
    index=tonumber(index)
    if not index or index<1 or index>MAX_TALENT_GROUPS then return false end
    local pe=_G.ProjectEbonhold
    if type(pe)~="table" then return false end
    if type(pe.SpecService)=="table" and type(pe.SpecService.ApplySpec)=="function" then
        PhaseC.ebonholdSpecSwitchPending=index
        PhaseC.ebonholdSpecDataReadyIndex=nil
        local ok=pcall(pe.SpecService.ApplySpec,index)
        if ok then
            -- Update the visible selection immediately. The server callback /
            -- UpdateSelectedSpec hook will confirm the same index afterwards.
            if PhaseC.SetEbonholdSpecIndex then PhaseC:SetEbonholdSpecIndex(index) end
            return true
        end
        PhaseC.ebonholdSpecSwitchPending=nil
    end
    if type(pe.sendToServer)=="function" and type(pe.CS)=="table" and pe.CS.REQUEST_APPLY_SPECS then
        PhaseC.ebonholdSpecSwitchPending=index
        PhaseC.ebonholdSpecDataReadyIndex=nil
        local ok=pcall(pe.sendToServer,pe.CS.REQUEST_APPLY_SPECS,tostring(index))
        if ok and PhaseC.SetEbonholdSpecIndex then PhaseC:SetEbonholdSpecIndex(index) end
        if not ok then PhaseC.ebonholdSpecSwitchPending=nil end
        return ok and true or false
    end
    return false
end

local function LoadNativeTalentUI()
    if _G.PlayerTalentFrame then return _G.PlayerTalentFrame end
    if type(TalentFrame_LoadUI)=="function" then pcall(TalentFrame_LoadUI) end
    if not _G.PlayerTalentFrame and type(LoadAddOn)=="function" then
        pcall(LoadAddOn,"Blizzard_TalentUI")
    end
    return _G.PlayerTalentFrame
end

local function SyncNativeTalentGroup(group)
    local stock=LoadNativeTalentUI()
    if not stock then return nil end
    group=tonumber(group) or 1
    stock.talentGroup=group
    stock.selectedTalentGroup=group
    return stock
end

local function ButtonText(button)
    if not button then return nil end
    if type(button.GetText)=="function" then
        local ok,text=pcall(button.GetText,button)
        if ok and text then return tostring(text) end
    end
    return nil
end

local function IsTalentResetButton(button)
    if not button then return false end
    if PhaseC.frame and PhaseC.frame.resetTalents and button==PhaseC.frame.resetTalents then return false end
    local okGet, getScript = pcall(function() return button.GetScript end)
    if not okGet or type(getScript)~="function" then return false end

    local okName,name=pcall(function() return button.GetName and button:GetName() end)
    name=okName and name and string.lower(tostring(name)) or ""
    -- Blizzard's PlayerTalentFrameResetButton is *preview reset*, not a
    -- character talent wipe. 0.9.01/02 accidentally matched it by name, which
    -- is why our Reset Talents button appeared to do nothing.
    if name=="playertalentframeresetbutton" or name=="playertalentframe_resetbutton" then return false end
    if string.find(name,"preview",1,true) and string.find(name,"reset",1,true) then return false end

    local text=ButtonText(button)
    local lower=text and string.lower(text) or ""
    if string.find(lower,"reset talents",1,true) then return true end
    -- Accept explicit custom names such as EbonholdResetTalentsButton, but do
    -- not accept generic TalentFrameResetButton names (the stock preview trap).
    if string.find(name,"resettalents",1,true) or string.find(name,"talentsreset",1,true) then return true end
    return false
end

local function FindNativeTalentResetButton()
    if IsTalentResetButton(PhaseC.nativeTalentResetButton) then return PhaseC.nativeTalentResetButton end
    local stock=LoadNativeTalentUI()

    local candidateNames={
        "PlayerTalentFrameResetTalentsButton",
        "PlayerTalentFrameResetTalents",
        "EbonholdResetTalentsButton",
        "TalentResetTalentsButton",
        "ResetTalentsButton",
    }
    for i=1,#candidateNames do
        local button=_G[candidateNames[i]]
        if IsTalentResetButton(button) then
            PhaseC.nativeTalentResetButton=button
            return button
        end
    end

    -- Ebonhold adds its specialization controls outside the stock Wrath frame
    -- on some client builds.  Search the loaded talent-frame tree first, then
    -- named global UI objects, for the actual visible "Reset Talents" button.
    local seen={}
    local function Scan(frame,depth)
        if not frame or seen[frame] or depth>8 then return nil end
        seen[frame]=true
        if IsTalentResetButton(frame) then return frame end
        local okChildren,getChildren=pcall(function() return frame.GetChildren end)
        if okChildren and type(getChildren)=="function" then
            local ok,list=pcall(function() return {frame:GetChildren()} end)
            if ok and list then
                for i=1,#list do
                    local found=Scan(list[i],depth+1)
                    if found then return found end
                end
            end
        end
        return nil
    end
    local found=stock and Scan(stock,0) or nil
    if found then PhaseC.nativeTalentResetButton=found; return found end

    for name,obj in pairs(_G) do
        if type(name)=="string" then
            local lower=string.lower(name)
            if string.find(lower,"talent",1,true) or string.find(lower,"spec",1,true) then
                if IsTalentResetButton(obj) then
                    PhaseC.nativeTalentResetButton=obj
                    return obj
                end
            end
        end
    end

    -- Last resort: Ebonhold can create unnamed controls under its own UI root.
    -- Scan UIParent once, excluding Zen's own Reset Talents button above.
    found=UIParent and Scan(UIParent,0) or nil
    if found then PhaseC.nativeTalentResetButton=found; return found end
    return nil
end

local function BootstrapNativeTalentControls()
    local stock=LoadNativeTalentUI()
    if not stock then return nil end

    local wasShown=stock.IsShown and stock:IsShown()
    local oldAlpha=(stock.GetAlpha and stock:GetAlpha()) or 1
    PhaseC.nativeTalentBootstrap=true

    -- Project Ebonhold creates/initializes its extra specialization controls
    -- from the native talent frame's show path on some client revisions. Show
    -- it invisibly for this single operation so the real Reset Talents button
    -- exists and its normal server-side handler is initialized.
    if not wasShown then
        if stock.SetAlpha then stock:SetAlpha(0) end
        stock:Show()
    end

    local native=FindNativeTalentResetButton()
    return stock,native,wasShown,oldAlpha
end

local function FinishNativeTalentBootstrap(stock,wasShown,oldAlpha)
    if stock and not wasShown and stock.Hide then stock:Hide() end
    if stock and stock.SetAlpha then stock:SetAlpha(oldAlpha or 1) end
    PhaseC.nativeTalentBootstrap=nil
end

local function ResetSelectedTalents(group)
    SyncNativeTalentGroup(group)
    local stock,native,wasShown,oldAlpha=BootstrapNativeTalentControls()
    if native then
        -- Prefer Button:Click() while the native talent frame is initialized;
        -- this preserves Ebonhold's own confirmation/cost logic and any XML
        -- PreClick/PostClick handling attached to the button.
        local okClick,click=pcall(function() return native.Click end)
        if okClick and type(click)=="function" then
            local ok=pcall(click,native,"LeftButton")
            if ok then
                FinishNativeTalentBootstrap(stock,wasShown,oldAlpha)
                return true
            end
        end
        local okScript,script=pcall(native.GetScript,native,"OnClick")
        if okScript and type(script)=="function" then
            local ok=pcall(script,native,"LeftButton")
            if ok then
                FinishNativeTalentBootstrap(stock,wasShown,oldAlpha)
                return true
            end
        end
    end

    FinishNativeTalentBootstrap(stock,wasShown,oldAlpha)

    -- Some Ebonhold revisions expose the reset directly on the spec service.
    local pe=_G.ProjectEbonhold
    if type(pe)=="table" then
        local owners={pe.SpecService,pe.Spec}
        local methods={"ResetTalents","ResetTalentSpec","ResetSpecTalents"}
        for i=1,#owners do
            local owner=owners[i]
            if type(owner)=="table" then
                for j=1,#methods do
                    local fn=owner[methods[j]]
                    if type(fn)=="function" then
                        local index=ReadEbonholdSpecIndex()
                        local ok=pcall(fn,index)
                        if not ok then ok=pcall(fn,owner,index) end
                        if ok then return true end
                    end
                end
            end
        end
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Ebonhold's Reset Talents control was not found on this client build.")
    end
    return false
end

local function GetActiveGroup()
    if type(GetActiveTalentGroup) ~= "function" then return 1 end
    local ok, value = pcall(GetActiveTalentGroup, false, false)
    if not ok then ok, value = pcall(GetActiveTalentGroup) end
    value = tonumber(value) or 1
    if value < 1 then value = 1 end
    return value
end


function PhaseC:SetEbonholdSpecIndex(index)
    index=tonumber(index)
    if not index or index<1 or index>MAX_TALENT_GROUPS then return end
    local previous=tonumber(self.ebonholdSpecIndex)
    if tonumber(self.ebonholdSpecDataReadyIndex)==index then
        self.ebonholdSpecSwitchPending=nil
        self.ebonholdSpecDataReadyIndex=nil
    elseif previous and previous~=index and not self.ebonholdSpecSwitchPending then
        self.ebonholdSpecSwitchPending=index
    end
    self.ebonholdSpecIndex=index
    if self.frame then
        self.frame.selectedSpec=index
        self.frame.selectedGroup=GetActiveGroup()
        self.frame.selectedTab=1
        self.frame.treeScrollOffset=0
        if self.frame:IsShown() then self:Refresh() end
    end
end

function PhaseC:InstallEbonholdSpecBridge()
    if not HasEbonholdSpecSystem() then return false end
    local pe=_G.ProjectEbonhold
    if type(pe)~="table" then return false end

    local observed=false

    -- ProjectEbonhold's own integration pattern wraps these two functions
    -- directly. hooksecurefunc is not dependable for these table methods on
    -- every 3.3.5 client build, so use a guarded post-wrapper and preserve the
    -- original return values.
    if type(pe.SpecService)=="table" and type(pe.SpecService.ApplySpec)=="function" then
        if not self.ebonholdApplyWrapper or pe.SpecService.ApplySpec~=self.ebonholdApplyWrapper then
            local original=pe.SpecService.ApplySpec
            local wrapper=function(index,...)
                local a,b,c,d=original(index,...)
                index=tonumber(index)
                if index and index>=1 and index<=MAX_TALENT_GROUPS then PhaseC:SetEbonholdSpecIndex(index) end
                return a,b,c,d
            end
            self.ebonholdOriginalApplySpec=original
            self.ebonholdApplyWrapper=wrapper
            pe.SpecService.ApplySpec=wrapper
        end
        observed=true
    end

    if type(pe.Spec)=="table" and type(pe.Spec.UpdateSelectedSpec)=="function" then
        if not self.ebonholdUpdateWrapper or pe.Spec.UpdateSelectedSpec~=self.ebonholdUpdateWrapper then
            local original=pe.Spec.UpdateSelectedSpec
            local wrapper=function(index,...)
                local a,b,c,d=original(index,...)
                index=tonumber(index)
                if index and index>=1 and index<=MAX_TALENT_GROUPS then PhaseC:SetEbonholdSpecIndex(index) end
                return a,b,c,d
            end
            self.ebonholdOriginalUpdateSelectedSpec=original
            self.ebonholdUpdateWrapper=wrapper
            pe.Spec.UpdateSelectedSpec=wrapper
        end
        observed=true
    end

    -- Server event remains the authoritative fallback/confirmation path.
    if not self.ebonholdSpecEventInstalled and type(pe.onEventReceived)=="function" and type(pe.SS)=="table" and pe.SS.SEND_PLAYER_SPEC_INDEX then
        local ok=pcall(pe.onEventReceived,pe.SS.SEND_PLAYER_SPEC_INDEX,function(body)
            local index=tonumber(body)
            if index then PhaseC:SetEbonholdSpecIndex(index) end
        end)
        if ok then self.ebonholdSpecEventInstalled=true; observed=true end
    elseif self.ebonholdSpecEventInstalled then
        observed=true
    end

    self.ebonholdSpecBridgeInstalled=observed and true or false
    RequestEbonholdCurrentSpec()
    return observed
end

local function IsPreviewMode()
    return GetCVarBool and GetCVarBool("previewTalents") and true or false
end

local function GetUnspent(group)
    if type(GetUnspentTalentPoints) ~= "function" then return 0 end
    local ok, value = pcall(GetUnspentTalentPoints, false, false, group)
    if not ok then ok, value = pcall(GetUnspentTalentPoints) end
    value = tonumber(value) or 0

    -- Blizzard's Wrath talent frame subtracts points already staged in Talent
    -- Preview from the displayed/usable unspent total.  Without this, Zen
    -- could make a preview build look as if it still had points available after
    -- those points had already been allocated in the preview.
    if IsPreviewMode() and type(GetGroupPreviewTalentPointsSpent)=="function" then
        local previewOK, previewSpent = pcall(GetGroupPreviewTalentPointsSpent, false, group)
        if previewOK then value = value - (tonumber(previewSpent) or 0) end
    end
    if value < 0 then value = 0 end
    return value
end

local function GetTabInfo(tab, group)
    if type(GetTalentTabInfo) ~= "function" then return nil end
    local ok, name, icon, spent, background, previewSpent = pcall(GetTalentTabInfo, tab, false, false, group)
    if not ok then
        ok, name, icon, spent, background, previewSpent = pcall(GetTalentTabInfo, tab)
    end
    if not ok then return nil end
    return name, icon, tonumber(spent) or 0, background, tonumber(previewSpent) or 0
end

local function GetTalent(tab, index, group)
    if type(GetTalentInfo) ~= "function" then return nil end
    local ok, name, icon, tier, column, rank, maxRank, exceptional, meetsPrereq, previewRank, meetsPreviewPrereq =
        pcall(GetTalentInfo, tab, index, false, false, group)
    if not ok then
        ok, name, icon, tier, column, rank, maxRank, exceptional, meetsPrereq = pcall(GetTalentInfo, tab, index)
        previewRank = rank
        meetsPreviewPrereq = meetsPrereq
    end
    if not ok or not name then return nil end
    return {
        name = name,
        icon = icon,
        tier = tonumber(tier) or 1,
        column = tonumber(column) or 1,
        rank = tonumber(rank) or 0,
        maxRank = tonumber(maxRank) or 1,
        exceptional = exceptional,
        meetsPrereq = meetsPrereq,
        previewRank = tonumber(previewRank) or tonumber(rank) or 0,
        meetsPreviewPrereq = meetsPreviewPrereq,
    }
end

local function GetDisplayedRank(info)
    if not info then return 0 end
    if IsPreviewMode() then return tonumber(info.previewRank) or tonumber(info.rank) or 0 end
    return tonumber(info.rank) or 0
end

local function GetSelectedTabSpent(frame)
    local _,_,spent,_,previewSpent = GetTabInfo(frame.selectedTab or 1, frame.selectedGroup or 1)
    return (tonumber(spent) or 0) + (IsPreviewMode() and (tonumber(previewSpent) or 0) or 0)
end

local function GetBestTab(group)
    local tabs = type(GetNumTalentTabs)=="function" and (tonumber(GetNumTalentTabs(false,false)) or 0) or 0
    if tabs <= 0 and type(GetNumTalentTabs)=="function" then tabs = tonumber(GetNumTalentTabs()) or 0 end
    local best, bestPoints = 1, -1
    for tab=1,math.max(1, math.min(MAX_TREE_TABS, tabs)) do
        local name,_,spent,_,previewSpent = GetTabInfo(tab, group)
        if name then
            local points = (spent or 0) + (previewSpent or 0)
            if points > bestPoints then best, bestPoints = tab, points end
        end
    end
    return best
end

local function GetSpecIcon(group)
    local tabs = type(GetNumTalentTabs)=="function" and (tonumber(GetNumTalentTabs(false,false)) or 0) or 0
    if tabs <= 0 and type(GetNumTalentTabs)=="function" then tabs = tonumber(GetNumTalentTabs()) or 0 end
    local bestIcon, bestPoints
    for tab=1,math.max(1, math.min(MAX_TREE_TABS, tabs)) do
        local name,icon,spent,_,previewSpent = GetTabInfo(tab, group)
        if name then
            local points = (spent or 0) + (previewSpent or 0)
            if not bestPoints or points > bestPoints then
                bestPoints = points
                bestIcon = icon
            end
        end
    end
    return bestIcon,bestPoints or 0
end

local function GetDefaultSpecIcon(group)
    -- With no points spent there is no dominant tree. Use the first available
    -- class talent-tree icon as the neutral/default visual for that saved spec
    -- instead of leaving the previous build's dominant-tree icon behind.
    local tabs = type(GetNumTalentTabs)=="function" and (tonumber(GetNumTalentTabs(false,false)) or 0) or 0
    if tabs <= 0 and type(GetNumTalentTabs)=="function" then tabs = tonumber(GetNumTalentTabs()) or 0 end
    for tab=1,math.max(1, math.min(MAX_TREE_TABS, tabs)) do
        local name,icon = GetTabInfo(tab, group)
        if name and icon then return icon end
    end
    return "Interface\\Icons\\Ability_Marksmanship"
end

local function RememberSpecIcon(spec,icon)
    spec=tonumber(spec)
    if not spec or spec<1 or spec>MAX_TALENT_GROUPS or not icon then return end
    SpecIconTable()[spec]=icon
end

local function StoredSpecIcon(spec)
    return SpecIconTable()[tonumber(spec) or 1]
end

local function SpecDisplayIcon(spec,activeSpec,group)
    spec=tonumber(spec) or 1
    activeSpec=tonumber(activeSpec) or 1
    if spec==activeSpec and not PhaseC.ebonholdSpecSwitchPending then
        local icon,points=GetSpecIcon(group)
        if icon and (tonumber(points) or 0)>0 then
            RememberSpecIcon(spec,icon)
            return icon
        end
        -- A true zero-point build means Reset Talents has completed (or this
        -- saved spec has never been built). Replace any stale dominant-tree
        -- cache with the neutral class-tree icon immediately and persist it.
        local defaultIcon=GetDefaultSpecIcon(group)
        if defaultIcon then RememberSpecIcon(spec,defaultIcon) end
        return defaultIcon
    end
    return StoredSpecIcon(spec) or "Interface\\Icons\\Ability_Marksmanship"
end

local function ShowRenameSpecPopup(spec)
    spec=tonumber(spec) or 1
    if not StaticPopupDialogs or not StaticPopup_Show then return false end
    if not StaticPopupDialogs["ZEN_RENAME_TALENT_SPEC"] then
        StaticPopupDialogs["ZEN_RENAME_TALENT_SPEC"]={
            text="Rename %s",
            button1=OKAY or "Okay",
            button2=CANCEL or "Cancel",
            hasEditBox=1,
            maxLetters=24,
            timeout=0, whileDead=1, hideOnEscape=1, preferredIndex=STATICPOPUP_NUMDIALOGS,
            OnShow=function(self)
                local index=tonumber(PhaseC.renameSpecIndex) or 1
                if self.editBox then
                    self.editBox:SetText(SpecDisplayName(index))
                    self.editBox:HighlightText()
                    self.editBox:SetFocus()
                end
            end,
            OnAccept=function(self)
                local index=tonumber(PhaseC.renameSpecIndex) or 1
                SetSpecDisplayName(index,self.editBox and self.editBox:GetText() or "")
                if PhaseC.frame and PhaseC.frame:IsShown() then PhaseC:RefreshSpecs() end
            end,
            EditBoxOnEscapePressed=function(self) self:GetParent():Hide() end,
        }
    end
    PhaseC.renameSpecIndex=spec
    StaticPopup_Show("ZEN_RENAME_TALENT_SPEC",TalentGroupLabel(spec))
    return true
end

local function TalentTierUnlocked(frame, tier)
    local spent = GetSelectedTabSpent(frame)
    return (((tonumber(tier) or 1) - 1) * 5) <= spent
end

local function GetPrereqTuples(tab, index, group)
    local result = {}
    if type(GetTalentPrereqs) ~= "function" then return result end

    -- Preserve the exact number of multi-return values.  A plain {...} plus #
    -- is unsafe here because nils can legitimately appear inside the tuples.
    local values, valueCount
    local function Capture(...)
        valueCount = select("#", ...)
        values = {...}
    end
    local ok = pcall(function() Capture(GetTalentPrereqs(tab, index, false, false, group)) end)
    if not ok or not valueCount or valueCount == 0 then
        values, valueCount = nil, nil
        ok = pcall(function() Capture(GetTalentPrereqs(tab, index)) end)
    end
    if not ok or not values or not valueCount then return result end

    local i = 1
    while i <= valueCount do
        local tier = tonumber(values[i])
        local column = tonumber(values[i+1])
        if tier and column then
            result[#result+1] = {
                tier = tier,
                column = column,
                learnable = values[i+2],
                previewLearnable = values[i+3],
            }
        end
        i = i + 4
    end
    return result
end

local function IsTalentAvailable(frame, info)
    if not info then return false end
    if frame.selectedGroup ~= GetActiveGroup() then return false end
    if GetUnspent(frame.selectedGroup) <= 0 then return false end
    if GetDisplayedRank(info) >= (tonumber(info.maxRank) or 1) then return false end
    if not TalentTierUnlocked(frame, info.tier) then return false end
    if IsPreviewMode() then return info.meetsPreviewPrereq and true or false end
    return info.meetsPrereq and true or false
end

local function StyleTalentButton(frame, button, info)
    if not button or not info then return end
    local rank = GetDisplayedRank(info)
    local maxRank = tonumber(info.maxRank) or 1
    local available = IsTalentAvailable(frame, info)
    button.rank:SetText(tostring(rank).."/"..tostring(maxRank))
    button.icon:SetTexture(info.icon or "")

    local activeGroup = frame.selectedGroup == GetActiveGroup()
    local usable = activeGroup and TalentTierUnlocked(frame, info.tier) and
        ((IsPreviewMode() and info.meetsPreviewPrereq) or ((not IsPreviewMode()) and info.meetsPrereq))

    if rank >= maxRank and maxRank > 0 then
        button.icon:SetVertexColor(1,1,1)
        RUI:SetBorderColor(button, 1, 0.82, 0.15, 1)
        button.rank:SetTextColor(1,0.82,0.15)
    elseif available then
        button.icon:SetVertexColor(1,1,1)
        local r,g,b = RUI:GetAccentColor()
        RUI:SetBorderColor(button, r,g,b,1)
        button.rank:SetTextColor(0.35,1,0.35)
    elseif rank > 0 then
        button.icon:SetVertexColor(activeGroup and 0.88 or 0.62, activeGroup and 0.88 or 0.62, activeGroup and 0.88 or 0.62)
        RUI:RefreshBackdrop(button)
        button.rank:SetTextColor(0.78,0.78,0.78)
    elseif usable then
        button.icon:SetVertexColor(0.74,0.74,0.74)
        RUI:RefreshBackdrop(button)
        button.rank:SetTextColor(0.62,0.64,0.68)
    else
        button.icon:SetVertexColor(0.34,0.34,0.34)
        RUI:RefreshBackdrop(button)
        button.rank:SetTextColor(0.45,0.45,0.45)
    end
end

function PhaseC:RegisterMover()
    local info = INFO.talents
    RUI:RegisterMover(info.mover, self.frame, {
        label = info.label,
        width = info.width,
        height = info.height,
        point = "CENTER",
        relativePoint = "CENTER",
        x = info.x,
        y = info.y,
        targetPoint = "TOPLEFT",
        moverPoint = "TOPLEFT",
        enabled = Enabled(),
    })
    if RUI.EnableDirectPanelDrag then RUI:EnableDirectPanelDrag(self.frame, info.mover) end
    self:ApplyScale()
end

function PhaseC:ApplyScale()
    if not self.frame then return end
    local info = INFO.talents
    local scale = RUI:GetEffectiveScale(info.scale)
    self.frame:SetScale(scale)
    RUI:UpdateMoverSize(info.mover, info.width*scale, info.height*scale)
end

function PhaseC:GetTalentButton(index)
    local frame = self.frame
    local button = frame.talentButtons[index]
    if button then return button end

    button = CreateFrame("Button", nil, frame.treeChild)
    button:SetWidth(BUTTON_SIZE)
    button:SetHeight(BUTTON_SIZE)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    RUI:CreateBackdrop(button)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.icon:SetTexCoord(0.08,0.92,0.08,0.92)
    button.rankBox = CreateFrame("Frame", nil, button)
    button.rankBox:SetWidth(30)
    button.rankBox:SetHeight(15)
    button.rankBox:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 5, -4)
    button.rankBox:SetFrameLevel(button:GetFrameLevel()+4)
    RUI:CreateBackdrop(button.rankBox)
    button.rank = Text(button.rankBox, "0/0", 8, "CENTER", button.rankBox, "CENTER", 0, 0, false)
    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints(button)
    local ar,ag,ab = RUI:GetAccentColor()
    button.highlight:SetTexture(ar,ag,ab,0.20)

    button:SetScript("OnClick", function(self, mouseButton)
        local f = PhaseC.frame
        if not f or not self.talentIndex or not self.talentInfo then return end
        if IsModifiedClick and IsModifiedClick("CHATLINK") and GetTalentLink and ChatEdit_InsertLink then
            local ok, link = pcall(GetTalentLink, f.selectedTab, self.talentIndex, false, false, f.selectedGroup, IsPreviewMode())
            if ok and link then ChatEdit_InsertLink(link) end
            return
        end
        if f.selectedGroup ~= GetActiveGroup() then return end
        if mouseButton == "LeftButton" then
            if IsPreviewMode() and type(AddPreviewTalentPoints)=="function" then
                pcall(AddPreviewTalentPoints, f.selectedTab, self.talentIndex, 1, false, f.selectedGroup)
            elseif type(LearnTalent)=="function" then
                pcall(LearnTalent, f.selectedTab, self.talentIndex, false, f.selectedGroup)
            end
        elseif mouseButton == "RightButton" and IsPreviewMode() and type(AddPreviewTalentPoints)=="function" then
            pcall(AddPreviewTalentPoints, f.selectedTab, self.talentIndex, -1, false, f.selectedGroup)
        end
        PhaseC:Refresh()
    end)

    button:SetScript("OnEnter", function(self)
        local f = PhaseC.frame
        if not f or not self.talentIndex then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetTalent then
            local ok = pcall(GameTooltip.SetTalent, GameTooltip, f.selectedTab, self.talentIndex, false, false, f.selectedGroup, IsPreviewMode())
            if not ok and self.talentInfo then
                GameTooltip:SetText(self.talentInfo.name or "Talent")
                GameTooltip:AddLine("Rank "..tostring(GetDisplayedRank(self.talentInfo)).." / "..tostring(self.talentInfo.maxRank or 1), 0.8,0.8,0.8)
            end
        elseif self.talentInfo then
            GameTooltip:SetText(self.talentInfo.name or "Talent")
            GameTooltip:AddLine("Rank "..tostring(GetDisplayedRank(self.talentInfo)).." / "..tostring(self.talentInfo.maxRank or 1), 0.8,0.8,0.8)
        end
        if f.selectedGroup ~= GetActiveGroup() then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Activate this specialization before spending points.", 1,0.65,0.35, true)
        elseif IsPreviewMode() then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Left-click: add preview rank", 0.65,0.85,0.65)
            GameTooltip:AddLine("Right-click: remove preview rank", 0.85,0.75,0.55)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.talentButtons[index] = button
    return button
end

function PhaseC:GetLine(index)
    local frame = self.frame
    local line = frame.branchLines[index]
    if line then return line end
    line = frame.treeChild:CreateTexture(nil, "BACKGROUND")
    line:SetTexture(RUI.Media.textures.white)
    frame.branchLines[index] = line
    return line
end

function PhaseC:HideLines()
    local lines = self.frame and self.frame.branchLines
    if not lines then return end
    for i=1,#lines do lines[i]:Hide() end
end

function PhaseC:DrawLineSegment(index, x1, y1, x2, y2, met)
    local line = self:GetLine(index)
    line:ClearAllPoints()
    local ar,ag,ab = RUI:GetAccentColor()
    if met then line:SetVertexColor(ar,ag,ab,0.75) else line:SetVertexColor(0.34,0.35,0.38,0.72) end
    if math.abs(x2-x1) >= math.abs(y2-y1) then
        local left = math.min(x1,x2)
        line:SetPoint("TOPLEFT", self.frame.treeChild, "TOPLEFT", left, y1+1)
        line:SetWidth(math.max(2, math.abs(x2-x1)))
        line:SetHeight(2)
    else
        local top = math.max(y1,y2)
        line:SetPoint("TOPLEFT", self.frame.treeChild, "TOPLEFT", x1-1, top)
        line:SetWidth(2)
        line:SetHeight(math.max(2, math.abs(y2-y1)))
    end
    line:Show()
end

function PhaseC:DrawPrereqs(talentMap)
    self:HideLines()
    local lineIndex = 0
    local frame = self.frame
    for index=1,#frame.visibleTalents do
        local entry = frame.visibleTalents[index]
        if entry and entry.info then
            local prereqs = GetPrereqTuples(frame.selectedTab, entry.index, frame.selectedGroup)
            for p=1,#prereqs do
                local req = prereqs[p]
                local source = talentMap[tostring(req.tier)..":"..tostring(req.column)]
                if source and source.info then
                    local sourceX = source.x + (BUTTON_SIZE/2)
                    local sourceY = source.y - BUTTON_SIZE
                    local targetX = entry.x + (BUTTON_SIZE/2)
                    local targetY = entry.y
                    local met = IsPreviewMode() and req.previewLearnable or req.learnable
                    if sourceX == targetX then
                        lineIndex=lineIndex+1
                        self:DrawLineSegment(lineIndex, sourceX, sourceY, targetX, targetY, met)
                    else
                        local elbowY = targetY + 10
                        lineIndex=lineIndex+1
                        self:DrawLineSegment(lineIndex, sourceX, sourceY, sourceX, elbowY, met)
                        lineIndex=lineIndex+1
                        self:DrawLineSegment(lineIndex, sourceX, elbowY, targetX, elbowY, met)
                        lineIndex=lineIndex+1
                        self:DrawLineSegment(lineIndex, targetX, elbowY, targetX, targetY, met)
                    end
                end
            end
        end
    end
    for i=lineIndex+1,#frame.branchLines do frame.branchLines[i]:Hide() end
end

function PhaseC:UpdateTreeBackground(background, childHeight)
    local frame = self.frame
    local base = background and ("Interface\\TalentFrame\\"..tostring(background).."-") or nil
    local pieces = frame.backgroundPieces
    if not pieces then return end
    local suffix = {"TopLeft","TopRight","BottomLeft","BottomRight"}
    local halfHeight = math.max(TREE_VIEW_HEIGHT/2, (tonumber(childHeight) or TREE_VIEW_HEIGHT)/2)
    for i=1,4 do
        pieces[i]:SetHeight(halfHeight)
        if base then
            pieces[i]:SetTexture(base..suffix[i])
            pieces[i]:SetAlpha(0.24)
            pieces[i]:Show()
        else
            pieces[i]:Hide()
        end
    end
end

function PhaseC:RefreshTabs()
    local frame = self.frame
    local numTabs = type(GetNumTalentTabs)=="function" and (tonumber(GetNumTalentTabs(false,false)) or 0) or 0
    if numTabs <= 0 and type(GetNumTalentTabs)=="function" then numTabs = tonumber(GetNumTalentTabs()) or 0 end
    numTabs = math.min(MAX_TREE_TABS, numTabs)
    if numTabs < 1 then numTabs = 1 end
    if not frame.selectedTab or frame.selectedTab > numTabs then frame.selectedTab = GetBestTab(frame.selectedGroup) end

    for tab=1,MAX_TREE_TABS do
        local button = frame.treeTabs[tab]
        local name,icon,spent,_,previewSpent = GetTabInfo(tab, frame.selectedGroup)
        if tab <= numTabs and name then
            button.tabIndex=tab
            button.icon:SetTexture(icon or "")
            button.RUIText:SetText(name)
            local points=(spent or 0)+(IsPreviewMode() and (previewSpent or 0) or 0)
            button.points:SetText(tostring(points))
            button:Show()
            if frame.selectedTab==tab then
                local r,g,b=RUI:GetAccentColor(); RUI:SetBorderColor(button,r,g,b,1)
            else
                RUI:RefreshBackdrop(button)
            end
        else
            button:Hide()
        end
    end
end

function PhaseC:RefreshSpecs()
    local frame = self.frame
    if not frame then return end

    if HasEbonholdSpecSystem() then
        local activeSpec=ReadEbonholdSpecIndex()
        frame.selectedSpec=activeSpec
        -- Talent points still belong to Wrath's real active talent-group index.
        frame.selectedGroup=GetActiveGroup()
        if not frame.selectedTab then frame.selectedTab=GetBestTab(frame.selectedGroup) end

        frame.specSelect.RUIText:SetText(SpecDisplayName(activeSpec))
        frame.specSelect.icon:SetTexture(SpecDisplayIcon(activeSpec,activeSpec,frame.selectedGroup))
        for spec=1,MAX_TALENT_GROUPS do
            local button=frame.specMenuButtons and frame.specMenuButtons[spec]
            if button then
                button.group=spec
                button.RUIText:SetText(SpecDisplayName(spec))
                if button.icon then button.icon:SetTexture(SpecDisplayIcon(spec,activeSpec,frame.selectedGroup)) end
                button.active:SetText(spec==activeSpec and "ACTIVE" or "")
                button:Show()
                if spec==activeSpec then
                    local r,g,b=RUI:GetAccentColor(); RUI:SetBorderColor(button,r,g,b,1)
                else
                    RUI:RefreshBackdrop(button)
                end
            end
        end
        frame.activate:Hide()
        if frame.renameSpec then frame.renameSpec:Show() end
        frame.activeNote:SetText("Ebonhold specialization")
        SyncNativeTalentGroup(frame.selectedGroup)
        return
    end

    if frame.renameSpec then frame.renameSpec:Hide() end
    local groups = GetNumGroups()
    local active = GetActiveGroup()
    if not frame.selectedGroup or frame.selectedGroup > groups then frame.selectedGroup = active end
    if frame.selectedGroup < 1 then frame.selectedGroup=1 end

    if frame.specSelect then
        frame.specSelect.RUIText:SetText(TalentGroupLabel(frame.selectedGroup))
        frame.specSelect.icon:SetTexture(GetSpecIcon(frame.selectedGroup) or "Interface\\Icons\\Ability_Marksmanship")
    end
    for group=1,MAX_TALENT_GROUPS do
        local button=frame.specMenuButtons and frame.specMenuButtons[group]
        if button then
            if group<=groups then
                button.group=group
                button.RUIText:SetText(TalentGroupLabel(group))
                if button.icon then button.icon:SetTexture(GetSpecIcon(group) or "Interface\\Icons\\Ability_Marksmanship") end
                button.active:SetText(group==active and "ACTIVE" or "")
                button:Show()
                if frame.selectedGroup==group then
                    local r,g,b=RUI:GetAccentColor(); RUI:SetBorderColor(button,r,g,b,1)
                else
                    RUI:RefreshBackdrop(button)
                end
            else
                button:Hide()
            end
        end
    end

    SyncNativeTalentGroup(frame.selectedGroup)
    if groups>1 and frame.selectedGroup~=active then
        frame.activate:Show()
        frame.activeNote:SetText("Viewing inactive specialization")
    else
        frame.activate:Hide()
        frame.activeNote:SetText(groups>1 and "Active specialization" or "Single specialization")
    end
end

function PhaseC:RefreshControls()
    local frame=self.frame
    local unspent=GetUnspent(frame.selectedGroup)
    local active=GetActiveGroup()
    frame.pointsValue:SetText(tostring(unspent))
    if HasEbonholdSpecSystem() then
        frame.groupValue:SetText("Spec "..tostring(ReadEbonholdSpecIndex()).."  •  Active")
    else
        frame.groupValue:SetText("Spec "..tostring(frame.selectedGroup)..(frame.selectedGroup==active and "  •  Active" or "  •  Inactive"))
    end

    local preview=IsPreviewMode()
    local previewSpent=0
    if preview and type(GetGroupPreviewTalentPointsSpent)=="function" then
        local ok,value=pcall(GetGroupPreviewTalentPointsSpent,false,frame.selectedGroup)
        if ok then previewSpent=tonumber(value) or 0 end
    end
    frame.previewStatus:SetText(preview and ("Preview mode  •  "..tostring(previewSpent).." pending") or "Direct learning mode")
    if preview and previewSpent>0 and frame.selectedGroup==active then
        frame.applyPreview:Show(); frame.resetPreview:Show()
    else
        frame.applyPreview:Hide(); frame.resetPreview:Hide()
    end
end

function PhaseC:RefreshTree()
    local frame=self.frame
    frame.visibleTalents={}
    local talentMap={}
    local num=type(GetNumTalents)=="function" and (tonumber(GetNumTalents(frame.selectedTab,false,false)) or 0) or 0
    if num<=0 and type(GetNumTalents)=="function" then num=tonumber(GetNumTalents(frame.selectedTab)) or 0 end
    num=math.min(MAX_TALENT_BUTTONS,num)
    local maxTier=1

    for i=1,num do
        local info=GetTalent(frame.selectedTab,i,frame.selectedGroup)
        local button=self:GetTalentButton(i)
        if info then
            maxTier=math.max(maxTier,tonumber(info.tier) or 1)
            local column=math.max(1,math.min(TALENT_COLUMNS,tonumber(info.column) or 1))
            local tier=math.max(1,tonumber(info.tier) or 1)
            local x=BUTTON_START_X+((column-1)*BUTTON_PITCH_X)
            local y=BUTTON_START_Y-((tier-1)*BUTTON_PITCH_Y)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT",frame.treeChild,"TOPLEFT",x,y)
            button.talentIndex=i
            button.talentInfo=info
            StyleTalentButton(frame,button,info)
            button:Show()
            local entry={ index=i,info=info,x=x,y=y,button=button }
            frame.visibleTalents[#frame.visibleTalents+1]=entry
            talentMap[tostring(tier)..":"..tostring(column)]=entry
        else
            button:Hide()
        end
    end
    for i=num+1,#frame.talentButtons do frame.talentButtons[i]:Hide() end

    local name,_,spent,background,previewSpent=GetTabInfo(frame.selectedTab,frame.selectedGroup)
    frame.treeTitle:SetText(name or "Talent Tree")
    frame.treeSpent:SetText(tostring((spent or 0)+(IsPreviewMode() and (previewSpent or 0) or 0)).." points spent")

    local childHeight=math.max(TREE_VIEW_HEIGHT,60+(maxTier*BUTTON_PITCH_Y))
    frame.treeChild:SetHeight(childHeight)
    self:UpdateTreeBackground(background, childHeight)
    frame.maxTreeScroll=math.max(0,childHeight-TREE_VIEW_HEIGHT)
    frame.treeScrollOffset=math.max(0,math.min(frame.maxTreeScroll,frame.treeScrollOffset or 0))
    frame.treeScroll:SetVerticalScroll(frame.treeScrollOffset)
    frame.scrollUp:SetAlpha(frame.treeScrollOffset>0 and 1 or 0.35)
    frame.scrollDown:SetAlpha(frame.treeScrollOffset<frame.maxTreeScroll and 1 or 0.35)

    self:DrawPrereqs(talentMap)
end


-- Wrath glyph socket IDs are not alternating Major/Minor.  The native
-- layout uses Major sockets 1/4/6 and Minor sockets 2/3/5.  Keep these
-- explicit so the Zen two-column presentation always groups like types.
local GLYPH_MAJOR_IDS = {1,4,6}
local GLYPH_MINOR_IDS = {2,3,5}

local function EnsureGlyphBackend()
    -- Load Blizzard's glyph code for its authoritative API/confirmation support,
    -- but never embed or show the parchment GlyphFrame inside ZenUI.
    if type(TalentFrame_LoadUI)=="function" then pcall(TalentFrame_LoadUI) end
    if not _G.PlayerTalentFrame and type(LoadAddOn)=="function" then
        pcall(LoadAddOn,"Blizzard_TalentUI")
    end
    if not _G.GlyphFrame and type(LoadAddOn)=="function" then
        pcall(LoadAddOn,"Blizzard_GlyphUI")
    end

    local glyph=_G.GlyphFrame
    local stock=_G.PlayerTalentFrame
    if glyph then
        glyph:Hide()
        if stock and glyph:GetParent()~=stock then
            glyph:ClearAllPoints()
            glyph:SetParent(stock)
            glyph:SetAllPoints(stock)
            glyph:SetFrameLevel((stock:GetFrameLevel() or 1)+4)
        end
    end
    return type(GetGlyphSocketInfo)=="function"
end

local function GlyphGroup()
    return GetActiveGroup()
end

local function GlyphTypeName(glyphType)
    return tonumber(glyphType)==2 and "Minor" or "Major"
end

local function ResetGlyphCursor()
    if type(ResetCursor)=="function" then
        pcall(ResetCursor)
    elseif type(SetCursor)=="function" then
        pcall(SetCursor,nil)
    end
end

function PhaseC:RestoreNativeGlyphFrame()
    local glyph=_G.GlyphFrame
    local stock=_G.PlayerTalentFrame
    if not glyph or not stock then return end
    glyph:Hide()
    if glyph:GetParent()~=stock then
        glyph:ClearAllPoints()
        glyph:SetParent(stock)
        glyph:SetAllPoints(stock)
        glyph:SetFrameLevel((stock:GetFrameLevel() or 1)+4)
    end
end

-- Using a glyph item in Wrath opens the native GlyphFrame through a different
-- path than the normal Glyphs keybind/tab (GlyphFrame_Open /
-- PlayerTalentFrame_OpenGlyphFrame and, on some Ebonhold builds, a direct
-- native frame Show during USE_GLYPH). Zen owns the visible player Glyph UI,
-- so intercept every native open path while leaving CastGlyph /
-- PlaceGlyphInSocket and the underlying confirmation backend untouched.
function PhaseC:RedirectNativeGlyphUI()
    if not Enabled() or not self.frame then return false end

    local glyph=_G.GlyphFrame
    local stock=_G.PlayerTalentFrame
    if glyph and glyph:IsShown() then glyph:Hide() end
    if stock and stock:IsShown() and not stock.pet then stock:Hide() end

    self:ShowGlyphs()
    return true
end

function PhaseC:ScheduleGlyphRedirect(delay)
    if not Enabled() then return end
    delay=tonumber(delay) or 0.02
    self.pendingGlyphRedirect=true

    local f=self.glyphRedirectFrame
    if not f then
        f=CreateFrame("Frame")
        f:Hide()
        self.glyphRedirectFrame=f
        f:SetScript("OnUpdate",function(frame,elapsed)
            frame.elapsed=(frame.elapsed or 0)+elapsed
            if frame.elapsed<(frame.delay or 0.02) then return end
            frame:Hide()
            frame.elapsed=0
            PhaseC.pendingGlyphRedirect=nil
            PhaseC:RedirectNativeGlyphUI()
        end)
    end
    f.elapsed=0
    f.delay=delay
    f:Show()
end

function PhaseC:HookNativeGlyphFrame()
    local glyph=_G.GlyphFrame
    if not glyph or glyph.ZenGlyphRedirectHook or not glyph.HookScript then return end
    glyph.ZenGlyphRedirectHook=true
    glyph:HookScript("OnShow",function(self)
        if not Enabled() or PhaseC.nativeGlyphBootstrap then return end
        -- Hide immediately, then defer the Zen open until the current native
        -- Show/event stack has finished. This avoids Blizzard/Ebonhold showing
        -- PlayerTalentFrame again after our handler runs.
        self:Hide()
        PhaseC:ScheduleGlyphRedirect(0.01)
    end)
end

function PhaseC:UpdateGlyphCursor(card)
    if not card or not card.slotID or not card:IsMouseOver() then return end
    if type(SpellIsTargeting)~="function" or not SpellIsTargeting() then
        ResetGlyphCursor()
        return
    end
    local matches=false
    if type(GlyphMatchesSocket)=="function" then
        local ok,value=pcall(GlyphMatchesSocket,card.slotID)
        matches=ok and value and true or false
    end
    if type(SetCursor)=="function" then
        pcall(SetCursor,matches and "CAST_CURSOR" or "CAST_ERROR_CURSOR")
    end
end

function PhaseC:ShowGlyphTooltip(card)
    if not card or not card.slotID then return end
    local group=GlyphGroup()
    GameTooltip:SetOwner(card,"ANCHOR_RIGHT")
    local shown=false
    if GameTooltip.SetGlyph then
        local ok=pcall(GameTooltip.SetGlyph,GameTooltip,card.slotID,group)
        shown=ok and true or false
    end
    if not shown then
        GameTooltip:SetText(card.displayName or ("Glyph Slot "..tostring(card.slotID)))
        if card.enabled==false then
            GameTooltip:AddLine("This glyph slot is locked for your current level.",0.65,0.65,0.65,true)
        elseif card.glyphSpell then
            GameTooltip:AddLine("Shift+Right Click to remove this glyph.",0.75,0.75,0.75,true)
        else
            GameTooltip:AddLine("Use a glyph item, then click this slot to apply it.",0.75,0.75,0.75,true)
        end
    end
    GameTooltip:Show()
    self:UpdateGlyphCursor(card)
end

function PhaseC:GlyphSlotClick(card,mouseButton)
    if not card or not card.slotID then return end
    local id=card.slotID
    local group=GlyphGroup()
    SyncNativeTalentGroup(group)

    if type(IsModifiedClick)=="function" and IsModifiedClick("CHATLINK") and type(ChatEdit_GetActiveWindow)=="function" and ChatEdit_GetActiveWindow() then
        if type(GetGlyphLink)=="function" then
            local ok,link=pcall(GetGlyphLink,id,group)
            if ok and link and type(ChatEdit_InsertLink)=="function" then pcall(ChatEdit_InsertLink,link) end
        end
        return
    end

    if card.enabled==false or group~=GetActiveGroup() then return end

    if mouseButton=="RightButton" then
        if IsShiftKeyDown and IsShiftKeyDown() and card.glyphSpell and type(StaticPopup_Show)=="function" then
            local glyphName=card.displayName
            if (not glyphName or glyphName=="") and type(GetSpellInfo)=="function" then glyphName=GetSpellInfo(card.glyphSpell) end
            local dialog=StaticPopup_Show("CONFIRM_REMOVE_GLYPH",glyphName or "Glyph")
            if dialog then dialog.data=id end
        end
        return
    end

    if mouseButton~="LeftButton" then return end
    local matches=false
    if type(GlyphMatchesSocket)=="function" then
        local ok,value=pcall(GlyphMatchesSocket,id)
        matches=ok and value and true or false
    end
    if not matches then return end

    if card.glyphSpell and type(StaticPopup_Show)=="function" then
        local dialog=StaticPopup_Show("CONFIRM_GLYPH_PLACEMENT",id)
        if dialog then dialog.data=id end
    elseif type(PlaceGlyphInSocket)=="function" then
        pcall(PlaceGlyphInSocket,id)
    end
end

function PhaseC:RefreshGlyphSlot(card)
    if not card or not card.slotID then return end
    local group=GlyphGroup()
    local ok,enabled,glyphType,glyphSpell,iconFilename=Safe("GetGlyphSocketInfo",GetGlyphSocketInfo,card.slotID,group)
    if not ok then
        card.enabled=false
        card.glyphSpell=nil
        card.displayName="Unavailable"
        card.name:SetText("Unavailable")
        card.status:SetText("Glyph data is unavailable on this client.")
        card.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        card.icon:SetVertexColor(0.45,0.45,0.45)
        RUI:RefreshBackdrop(card)
        return
    end

    card.enabled=enabled and true or false
    card.glyphType=tonumber(glyphType) or card.expectedGlyphType
    card.glyphSpell=glyphSpell
    local typeName=GlyphTypeName(card.glyphType)
    card.typeLabel:SetText(typeName.." Glyph  •  Slot "..tostring(card.slotNumber or card.slotID))

    -- Keep unused sockets deliberately neutral. A socket only gains colour once
    -- an actual glyph is applied, making filled vs empty readable at a glance.
    RUI:RefreshBackdrop(card.iconFrame)
    card.icon:SetVertexColor(1,1,1)

    if not card.enabled then
        card.displayName="Locked "..typeName.." Slot"
        card.name:SetText(card.displayName)
        card.status:SetText("Locked at your current level")
        card.hint:SetText("Hover for the native unlock requirement.")
        card.icon:SetTexture("Interface\\Spellbook\\UI-GlyphFrame-Locked")
        card.icon:SetTexCoord(.1,.9,.1,.9)
        card.icon:SetVertexColor(0.32,0.32,0.32)
        RUI:SetBorderColor(card.iconFrame,0.24,0.24,0.24,1)
    elseif glyphSpell then
        local spellName
        if type(GetSpellInfo)=="function" then
            local sok,a=pcall(GetSpellInfo,glyphSpell)
            if sok then spellName=a end
        end
        card.displayName=spellName or (typeName.." Glyph")
        card.name:SetText(card.displayName)
        card.status:SetText("Applied to your active specialization")
        card.hint:SetText("Shift+Right Click to remove  •  Shift+Click to link")
        -- Keep the same socket-rune symbol in both states so the panel reads as
        -- empty=grey / filled=coloured, instead of changing to a different icon.
        card.icon:SetTexture(iconFilename or "Interface\Spellbook\UI-Glyph-Rune1")
        card.icon:SetTexCoord(.08,.92,.08,.92)
        if tonumber(card.glyphType)==2 then
            card.icon:SetVertexColor(0.25,0.55,1)
            RUI:SetBorderColor(card.iconFrame,0.25,0.55,1,1)
        else
            card.icon:SetVertexColor(1,0.45,0.10)
            RUI:SetBorderColor(card.iconFrame,1,0.35,0.08,1)
        end
    else
        card.displayName="Empty "..typeName.." Glyph"
        card.name:SetText(card.displayName)
        card.status:SetText("Empty socket")
        card.hint:SetText("Use a glyph item, then click this matching slot.")
        card.icon:SetTexture("Interface\\Spellbook\\UI-Glyph-Rune1")
        card.icon:SetTexCoord(.08,.92,.08,.92)
        card.icon:SetVertexColor(0.34,0.34,0.34)
        RUI:SetBorderColor(card.iconFrame,0.28,0.28,0.28,1)
    end

    RUI:RefreshBackdrop(card)
    if card.enabled then
        local targeting=type(SpellIsTargeting)=="function" and SpellIsTargeting()
        local matches=false
        if targeting and type(GlyphMatchesSocket)=="function" then
            local mok,value=pcall(GlyphMatchesSocket,card.slotID)
            matches=mok and value and true or false
        end
        if matches then
            local ar,ag,ab=RUI:GetAccentColor()
            RUI:SetBorderColor(card,ar,ag,ab,1)
            card.match:SetText("MATCH")
            card.match:Show()
        else
            card.match:Hide()
        end
    else
        card.match:Hide()
    end
    if card:IsMouseOver() then self:UpdateGlyphCursor(card) end
end

function PhaseC:RefreshGlyphs()
    local frame=self.frame
    if not frame or not frame.glyphPanel then return end
    local available=EnsureGlyphBackend()
    if not available then
        if frame.glyphUnavailable then frame.glyphUnavailable:Show() end
        if frame.glyphContent then frame.glyphContent:Hide() end
        return
    end
    if frame.glyphUnavailable then frame.glyphUnavailable:Hide() end
    if frame.glyphContent then frame.glyphContent:Show() end

    local group=GlyphGroup()
    SyncNativeTalentGroup(group)
    if frame.glyphSpecText then
        local specName
        if HasEbonholdSpecSystem() then specName=SpecDisplayName(ReadEbonholdSpecIndex()) else specName="Spec "..tostring(group) end
        frame.glyphSpecText:SetText("Active specialization: "..tostring(specName))
    end
    for i=1,#(frame.glyphCards or {}) do self:RefreshGlyphSlot(frame.glyphCards[i]) end
end

function PhaseC:RefreshModeTabs()
    local frame=self.frame
    if not frame then return end
    local mode=frame.mode or "talents"
    local ar,ag,ab=RUI:GetAccentColor()
    local function style(button,selected)
        if not button then return end
        RUI:RefreshBackdrop(button)
        if selected then
            RUI:SetBorderColor(button,ar,ag,ab,1)
            if button.RUIText then button.RUIText:SetTextColor(1,0.82,0.15) end
        else
            local r,g,b=RUI:GetTextColor(false)
            if button.RUIText then button.RUIText:SetTextColor(r,g,b) end
        end
    end
    style(frame.talentsModeButton,mode=="talents")
    style(frame.glyphsModeButton,mode=="glyphs")
end

function PhaseC:SetMode(mode)
    local frame=self.frame
    if not frame then return end
    mode=(mode=="glyphs") and "glyphs" or "talents"
    frame.mode=mode

    if mode=="glyphs" then
        frame.title:SetText("Glyphs")
        frame.subtitle:SetText("Zen glyph management")
        if frame.specMenu then frame.specMenu:Hide() end
        if frame.treePanel then frame.treePanel:Hide() end
        if frame.specPane then frame.specPane:Hide() end
        if frame.apiWarning then frame.apiWarning:Hide() end
        if frame.glyphPanel then frame.glyphPanel:Show() end
        self:RefreshGlyphs()
    else
        frame.title:SetText("Talents")
        frame.subtitle:SetText("Zen talent planner")
        if _G.GlyphFrame and not (InCombatLockdown and InCombatLockdown()) then _G.GlyphFrame:Hide() end
        if frame.glyphPanel then frame.glyphPanel:Hide() end
        if frame.specPane then frame.specPane:Show() end
        self:Refresh()
    end
    self:RefreshModeTabs()
end

function PhaseC:ShowGlyphs()
    if not self.frame then return end
    self.frame.selectedGroup=GetActiveGroup()
    if RUI.ActivateExclusivePanel then RUI:ActivateExclusivePanel(self.frame) end
    self.frame:Show()
    self:SetMode("glyphs")
end

function PhaseC:ToggleGlyphs()
    if not self.frame then return end
    if self.frame:IsShown() and self.frame.mode=="glyphs" then
        self.frame:Hide()
    else
        self:ShowGlyphs()
    end
end

function PhaseC:Refresh()
    local frame=self.frame
    if not frame then return end
    if frame.mode=="glyphs" then
        self:RefreshGlyphs()
        self:RefreshModeTabs()
        return
    end
    if type(GetTalentTabInfo)~="function" or type(GetTalentInfo)~="function" then
        frame.apiWarning:Show()
        frame.treePanel:Hide()
        return
    end
    frame.apiWarning:Hide()
    frame.treePanel:Show()
    self:RefreshSpecs()
    self:RefreshTabs()
    self:RefreshControls()
    self:RefreshTree()
end

function PhaseC:ScrollTree(delta)
    local frame=self.frame
    if not frame then return end
    local step=BUTTON_PITCH_Y*2
    local value=(frame.treeScrollOffset or 0) - ((tonumber(delta) or 0)*step)
    value=math.max(0,math.min(frame.maxTreeScroll or 0,value))
    frame.treeScrollOffset=value
    frame.treeScroll:SetVerticalScroll(value)
    frame.scrollUp:SetAlpha(value>0 and 1 or 0.35)
    frame.scrollDown:SetAlpha(value<(frame.maxTreeScroll or 0) and 1 or 0.35)
end

function PhaseC:CreateTalents()
    local frame=Panel("ZenUITalentFrame","Talents")
    self.frame=frame
    frame.selectedGroup=GetActiveGroup()
    frame.selectedSpec=ReadEbonholdSpecIndex()
    frame.selectedTab=GetBestTab(frame.selectedGroup)
    frame.treeScrollOffset=0
    frame.talentButtons={}
    frame.branchLines={}
    frame.visibleTalents={}
    frame.mode="talents"

    -- Talents and Glyphs share the same Zen panel. Keep these mode buttons in
    -- the header so the existing talent-tree layout does not lose vertical room.
    frame.talentsModeButton=Button(frame,"Talents",82,24)
    frame.talentsModeButton:SetPoint("TOP",frame,"TOP",-48,-10)
    frame.talentsModeButton:SetScript("OnClick",function() PhaseC:SetMode("talents") end)
    frame.glyphsModeButton=Button(frame,"Glyphs",82,24)
    frame.glyphsModeButton:SetPoint("LEFT",frame.talentsModeButton,"RIGHT",6,0)
    frame.glyphsModeButton:SetScript("OnClick",function() PhaseC:SetMode("glyphs") end)

    frame.glyphPanel=CreateFrame("Frame",nil,frame.body)
    frame.glyphPanel:SetAllPoints(frame.body)
    frame.glyphPanel:EnableMouse(true)
    RUI:CreateBackdrop(frame.glyphPanel)

    frame.glyphUnavailable=Text(frame.glyphPanel,"The native Wrath Glyph APIs are unavailable on this client.",11,"CENTER",frame.glyphPanel,"CENTER",0,0,false)
    frame.glyphUnavailable:SetWidth(420)
    frame.glyphUnavailable:SetJustifyH("CENTER")
    frame.glyphUnavailable:Hide()

    frame.glyphContent=CreateFrame("Frame",nil,frame.glyphPanel)
    frame.glyphContent:SetAllPoints(frame.glyphPanel)
    frame.glyphIntro=Text(frame.glyphContent,"Manage your active specialization's glyph sockets without leaving ZenUI.",9,"TOPLEFT",frame.glyphContent,"TOPLEFT",14,-14,true)
    frame.glyphIntro:SetWidth(360); frame.glyphIntro:SetJustifyH("LEFT")
    frame.glyphSpecText=Text(frame.glyphContent,"",9,"TOPRIGHT",frame.glyphContent,"TOPRIGHT",-14,-14,true)
    frame.glyphSpecText:SetWidth(300); frame.glyphSpecText:SetJustifyH("RIGHT")
    frame.glyphMajorTitle=Text(frame.glyphContent,"MAJOR GLYPHS",10,"TOPLEFT",frame.glyphContent,"TOPLEFT",14,-43,false)
    frame.glyphMinorTitle=Text(frame.glyphContent,"MINOR GLYPHS",10,"TOPLEFT",frame.glyphContent,"TOPLEFT",374,-43,false)

    local divider=frame.glyphContent:CreateTexture(nil,"ARTWORK")
    divider:SetWidth(1); divider:SetPoint("TOP",frame.glyphContent,"TOP",0,-42); divider:SetPoint("BOTTOM",frame.glyphContent,"BOTTOM",0,42)
    divider:SetTexture(1,1,1,0.08)

    frame.glyphCards={}
    local function CreateGlyphCard(slotID,slotNumber,expectedGlyphType,x,y)
        local card=CreateFrame("Button",nil,frame.glyphContent)
        card:SetWidth(342); card:SetHeight(142)
        card:SetPoint("TOPLEFT",frame.glyphContent,"TOPLEFT",x,y)
        card:RegisterForClicks("LeftButtonUp","RightButtonUp")
        card.slotID=slotID
        card.slotNumber=slotNumber
        card.expectedGlyphType=expectedGlyphType
        RUI:CreateBackdrop(card)

        card.hover=card:CreateTexture(nil,"ARTWORK")
        card.hover:SetAllPoints(card); card.hover:Hide()

        card.iconFrame=CreateFrame("Frame",nil,card)
        card.iconFrame:SetWidth(64); card.iconFrame:SetHeight(64)
        card.iconFrame:SetPoint("TOPLEFT",card,"TOPLEFT",12,-22)
        RUI:CreateBackdrop(card.iconFrame)
        card.icon=card.iconFrame:CreateTexture(nil,"ARTWORK")
        card.icon:SetAllPoints(card.iconFrame)
        card.icon:SetTexCoord(.08,.92,.08,.92)

        card.typeLabel=Text(card,"Glyph Slot",8,"TOPLEFT",card,"TOPLEFT",88,-16,true)
        card.name=Text(card,"Empty Glyph",12,"TOPLEFT",card,"TOPLEFT",88,-38,false)
        card.name:SetWidth(238); card.name:SetJustifyH("LEFT")
        card.status=Text(card,"",9,"TOPLEFT",card,"TOPLEFT",88,-64,true)
        card.status:SetWidth(238); card.status:SetJustifyH("LEFT")
        card.hint=Text(card,"",8,"BOTTOMLEFT",card,"BOTTOMLEFT",88,18,true)
        card.hint:SetWidth(238); card.hint:SetJustifyH("LEFT")
        card.match=Text(card,"MATCH",8,"TOPRIGHT",card,"TOPRIGHT",-10,-12,false)
        card.match:Hide()

        card:SetScript("OnEnter",function(self)
            local ar,ag,ab=RUI:GetAccentColor()
            self.hover:SetTexture(ar,ag,ab,0.08); self.hover:Show()
            PhaseC:ShowGlyphTooltip(self)
        end)
        card:SetScript("OnLeave",function(self)
            self.hover:Hide()
            GameTooltip:Hide()
            ResetGlyphCursor()
        end)
        card:SetScript("OnClick",function(self,button) PhaseC:GlyphSlotClick(self,button) end)
        frame.glyphCards[#frame.glyphCards+1]=card
        return card
    end

    for i=1,#GLYPH_MAJOR_IDS do CreateGlyphCard(GLYPH_MAJOR_IDS[i],i,1,14,-62-((i-1)*154)) end
    for i=1,#GLYPH_MINOR_IDS do CreateGlyphCard(GLYPH_MINOR_IDS[i],i,2,374,-62-((i-1)*154)) end

    frame.glyphHelp=Text(frame.glyphContent,"Use/right-click a glyph item, then click a matching socket. Shift+Right Click removes an applied glyph. Shift+Click links it to chat.",8,"BOTTOMLEFT",frame.glyphContent,"BOTTOMLEFT",14,16,true)
    frame.glyphHelp:SetWidth(700); frame.glyphHelp:SetJustifyH("LEFT")
    frame.glyphPanel:Hide()

    frame.specPane=CreateFrame("Frame",nil,frame.body)
    frame.specPane:SetWidth(174)
    frame.specPane:SetPoint("TOPRIGHT",frame.body,"TOPRIGHT",-2,-2)
    frame.specPane:SetPoint("BOTTOMRIGHT",frame.body,"BOTTOMRIGHT",-2,2)
    RUI:CreateBackdrop(frame.specPane)
    frame.specTitle=Text(frame.specPane,"SPECIALIZATION",9,"TOPLEFT",frame.specPane,"TOPLEFT",12,-12,true)

    -- Project Ebonhold extends Wrath's normal two talent groups to five. Keep
    -- the selector compact so all persistent specialization slots fit cleanly.
    frame.specSelect=Button(frame.specPane,"Primary Specialization",150,30)
    frame.specSelect:SetPoint("TOPLEFT",frame.specPane,"TOPLEFT",12,-34)
    frame.specSelect.RUIText:ClearAllPoints(); frame.specSelect.RUIText:SetPoint("LEFT",frame.specSelect,"LEFT",34,0); frame.specSelect.RUIText:SetWidth(98); frame.specSelect.RUIText:SetJustifyH("LEFT")
    frame.specSelect.icon=frame.specSelect:CreateTexture(nil,"ARTWORK"); frame.specSelect.icon:SetWidth(20); frame.specSelect.icon:SetHeight(20); frame.specSelect.icon:SetPoint("LEFT",frame.specSelect,"LEFT",7,0); frame.specSelect.icon:SetTexCoord(.08,.92,.08,.92)
    frame.specSelect.arrow=Text(frame.specSelect,"v",9,"RIGHT",frame.specSelect,"RIGHT",-8,0,true)

    frame.specMenu=CreateFrame("Frame",nil,frame.specPane)
    frame.specMenu:SetWidth(150); frame.specMenu:SetHeight((MAX_TALENT_GROUPS*28)+8)
    frame.specMenu:SetPoint("TOPLEFT",frame.specSelect,"BOTTOMLEFT",0,-3)
    frame.specMenu:SetFrameLevel((frame.specPane:GetFrameLevel() or 1)+30)
    frame.specMenu:EnableMouse(true); frame.specMenu:Hide()
    RUI:CreateBackdrop(frame.specMenu)
    frame.specMenuButtons={}
    for group=1,MAX_TALENT_GROUPS do
        local b=Button(frame.specMenu,TalentGroupLabel(group),142,26)
        b:SetPoint("TOPLEFT",frame.specMenu,"TOPLEFT",4,-4-((group-1)*28))
        b.group=group
        b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetWidth(18); b.icon:SetHeight(18); b.icon:SetPoint("LEFT",b,"LEFT",6,0); b.icon:SetTexCoord(.08,.92,.08,.92)
        b.RUIText:ClearAllPoints(); b.RUIText:SetPoint("LEFT",b,"LEFT",29,0); b.RUIText:SetWidth(84); b.RUIText:SetJustifyH("LEFT")
        b.active=Text(b,"",7,"RIGHT",b,"RIGHT",-5,0,true)
        b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        b:SetScript("OnClick",function(self,mouseButton)
            frame.specMenu:Hide()
            if HasEbonholdSpecSystem() then
                if mouseButton=="RightButton" then
                    ShowRenameSpecPopup(self.group)
                    return
                end
                if self.group~=ReadEbonholdSpecIndex() then
                    if ApplyEbonholdSpec(self.group) then
                        frame.activeNote:SetText("Switching specialization...")
                    elseif DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66ZenUI:|r Ebonhold specialization switch is unavailable.")
                    end
                end
                return
            end
            if frame.selectedGroup~=self.group then
                frame.selectedGroup=self.group
                frame.selectedTab=GetBestTab(self.group)
                frame.treeScrollOffset=0
                SyncNativeTalentGroup(self.group)
                PhaseC:Refresh()
            end
        end)
        frame.specMenuButtons[group]=b
    end
    frame.specSelect:SetScript("OnClick",function()
        if frame.specMenu:IsShown() then
            frame.specMenu:Hide()
        else
            PhaseC:RefreshSpecs()
            frame.specMenu:Show()
        end
    end)

    frame.activeNote=Text(frame.specPane,"",8,"TOPLEFT",frame.specPane,"TOPLEFT",12,-74,true)
    frame.activate=Button(frame.specPane,"Activate Spec",150,25)
    frame.activate:SetPoint("TOPLEFT",frame.specPane,"TOPLEFT",12,-94)
    frame.activate:SetScript("OnClick",function()
        if HasEbonholdSpecSystem() then return end
        if frame.selectedGroup~=GetActiveGroup() and type(SetActiveTalentGroup)=="function" then
            pcall(SetActiveTalentGroup,frame.selectedGroup)
        end
    end)

    frame.renameSpec=Button(frame.specPane,"Rename Spec",150,25)
    frame.renameSpec:SetPoint("TOPLEFT",frame.specPane,"TOPLEFT",12,-94)
    frame.renameSpec:SetScript("OnClick",function()
        if not HasEbonholdSpecSystem() then return end
        if frame.specMenu then frame.specMenu:Hide() end
        ShowRenameSpecPopup(ReadEbonholdSpecIndex())
    end)
    frame.renameSpec:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("Rename Specialization")
        GameTooltip:AddLine("Give this Ebonhold spec a short Zen display name. Clear the field to restore its default Primary / Secondary / Third / Fourth / Fifth label.",0.8,0.8,0.8,true)
        GameTooltip:Show()
    end)
    frame.renameSpec:SetScript("OnLeave",function() GameTooltip:Hide() end)
    frame.renameSpec:Hide()

    frame.resetTalents=Button(frame.specPane,"Reset Talents",150,25)
    frame.resetTalents:SetPoint("TOPLEFT",frame.specPane,"TOPLEFT",12,-126)
    frame.resetTalents:SetScript("OnClick",function()
        if frame.specMenu then frame.specMenu:Hide() end
        -- Ebonhold reset always applies to the currently active server spec;
        -- the Wrath group argument remains the real native talent group.
        ResetSelectedTalents(GetActiveGroup())
    end)
    frame.resetTalents:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("Reset Talents")
        GameTooltip:AddLine("Uses Project Ebonhold's native reset for the selected specialization, including its normal confirmation and cost rules.",0.8,0.8,0.8,true)
        GameTooltip:Show()
    end)
    frame.resetTalents:SetScript("OnLeave",function() GameTooltip:Hide() end)

    frame.summary=CreateFrame("Frame",nil,frame.specPane)
    frame.summary:SetWidth(150); frame.summary:SetHeight(126); frame.summary:SetPoint("TOPLEFT",frame.specPane,"TOPLEFT",12,-166)
    RUI:CreateBackdrop(frame.summary)
    frame.pointsLabel=Text(frame.summary,"UNSPENT POINTS",8,"TOPLEFT",frame.summary,"TOPLEFT",10,-11,true)
    frame.pointsValue=Text(frame.summary,"0",22,"TOPLEFT",frame.summary,"TOPLEFT",10,-29,false)
    frame.groupValue=Text(frame.summary,"",9,"TOPLEFT",frame.summary,"TOPLEFT",10,-62,false)
    frame.previewStatus=Text(frame.summary,"",8,"TOPLEFT",frame.summary,"TOPLEFT",10,-86,true)
    frame.previewStatus:SetWidth(130); frame.previewStatus:SetJustifyH("LEFT")

    frame.help=Text(frame.specPane,"Left-click spends a point. Shift-click links talents. When Blizzard Talent Preview is enabled, right-click removes preview ranks.",8,"BOTTOMLEFT",frame.specPane,"BOTTOMLEFT",12,92,true)
    frame.help:SetWidth(150); frame.help:SetJustifyH("LEFT")
    frame.applyPreview=Button(frame.specPane,"Apply Preview",150,24); frame.applyPreview:SetPoint("BOTTOMLEFT",frame.specPane,"BOTTOMLEFT",12,54)
    frame.resetPreview=Button(frame.specPane,"Reset Preview",150,24); frame.resetPreview:SetPoint("BOTTOMLEFT",frame.specPane,"BOTTOMLEFT",12,24)
    frame.applyPreview:SetScript("OnClick",function()
        if type(LearnPreviewTalents)~="function" then return end
        if StaticPopupDialogs and StaticPopup_Show then
            if not StaticPopupDialogs["ZEN_CONFIRM_PREVIEW_TALENTS"] then
                StaticPopupDialogs["ZEN_CONFIRM_PREVIEW_TALENTS"]={
                    text="Learn the previewed talent build?",
                    button1=YES,
                    button2=NO,
                    OnAccept=function() if type(LearnPreviewTalents)=="function" then pcall(LearnPreviewTalents,false) end end,
                    timeout=0, whileDead=1, hideOnEscape=1, preferredIndex=STATICPOPUP_NUMDIALOGS,
                }
            end
            StaticPopup_Show("ZEN_CONFIRM_PREVIEW_TALENTS")
        else
            pcall(LearnPreviewTalents,false)
        end
    end)
    frame.resetPreview:SetScript("OnClick",function()
        if type(ResetGroupPreviewTalentPoints)=="function" then
            pcall(ResetGroupPreviewTalentPoints,false,frame.selectedGroup)
            PhaseC:Refresh()
        end
    end)

    frame.treePanel=CreateFrame("Frame",nil,frame.body)
    frame.treePanel:SetPoint("TOPLEFT",frame.body,"TOPLEFT",2,-2)
    frame.treePanel:SetPoint("BOTTOMRIGHT",frame.specPane,"BOTTOMLEFT",-10,2)
    RUI:CreateBackdrop(frame.treePanel)
    frame.treeTitle=Text(frame.treePanel,"Talent Tree",13,"TOPLEFT",frame.treePanel,"TOPLEFT",12,-12,false)
    frame.treeSpent=Text(frame.treePanel,"0 points spent",8,"TOPRIGHT",frame.treePanel,"TOPRIGHT",-12,-16,true)

    frame.treeTabs={}
    for tab=1,MAX_TREE_TABS do
        local b=Button(frame.treePanel,"",157,34)
        b:SetPoint("TOPLEFT",frame.treePanel,"TOPLEFT",12+((tab-1)*163),-37)
        b.tabIndex=tab
        b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetWidth(23); b.icon:SetHeight(23); b.icon:SetPoint("LEFT",b,"LEFT",6,0); b.icon:SetTexCoord(.08,.92,.08,.92)
        b.RUIText:ClearAllPoints(); b.RUIText:SetPoint("LEFT",b.icon,"RIGHT",7,0); b.RUIText:SetWidth(95); b.RUIText:SetJustifyH("LEFT")
        b.points=Text(b,"0",8,"RIGHT",b,"RIGHT",-7,0,true)
        b:SetScript("OnClick",function(self)
            if self.tabIndex and frame.selectedTab~=self.tabIndex then
                frame.selectedTab=self.tabIndex
                frame.treeScrollOffset=0
                PhaseC:Refresh()
            end
        end)
        frame.treeTabs[tab]=b
    end

    frame.treeScroll=CreateFrame("ScrollFrame",nil,frame.treePanel)
    frame.treeScroll:SetWidth(TREE_VIEW_WIDTH)
    frame.treeScroll:SetHeight(TREE_VIEW_HEIGHT)
    frame.treeScroll:SetPoint("TOPLEFT",frame.treePanel,"TOPLEFT",12,-78)
    frame.treeScroll:EnableMouseWheel(true)
    frame.treeScroll:SetScript("OnMouseWheel",function(_,delta) PhaseC:ScrollTree(delta) end)
    frame.treeChild=CreateFrame("Frame",nil,frame.treeScroll)
    frame.treeChild:SetWidth(TREE_VIEW_WIDTH)
    frame.treeChild:SetHeight(TREE_VIEW_HEIGHT)
    frame.treeScroll:SetScrollChild(frame.treeChild)
    frame.treeChild:EnableMouseWheel(true)
    frame.treeChild:SetScript("OnMouseWheel",function(_,delta) PhaseC:ScrollTree(delta) end)

    frame.backgroundPieces={}
    for i=1,4 do
        local t=frame.treeChild:CreateTexture(nil,"BACKGROUND")
        frame.backgroundPieces[i]=t
    end
    frame.backgroundPieces[1]:SetPoint("TOPLEFT",frame.treeChild,"TOPLEFT",0,0); frame.backgroundPieces[1]:SetWidth(TREE_VIEW_WIDTH/2); frame.backgroundPieces[1]:SetHeight(TREE_VIEW_HEIGHT/2)
    frame.backgroundPieces[2]:SetPoint("TOPRIGHT",frame.treeChild,"TOPRIGHT",0,0); frame.backgroundPieces[2]:SetWidth(TREE_VIEW_WIDTH/2); frame.backgroundPieces[2]:SetHeight(TREE_VIEW_HEIGHT/2)
    frame.backgroundPieces[3]:SetPoint("TOPLEFT",frame.backgroundPieces[1],"BOTTOMLEFT",0,0); frame.backgroundPieces[3]:SetWidth(TREE_VIEW_WIDTH/2); frame.backgroundPieces[3]:SetHeight(TREE_VIEW_HEIGHT/2)
    frame.backgroundPieces[4]:SetPoint("TOPRIGHT",frame.backgroundPieces[2],"BOTTOMRIGHT",0,0); frame.backgroundPieces[4]:SetWidth(TREE_VIEW_WIDTH/2); frame.backgroundPieces[4]:SetHeight(TREE_VIEW_HEIGHT/2)

    frame.scrollUp=Button(frame.treePanel,"^",22,24); frame.scrollUp:SetPoint("TOPRIGHT",frame.treePanel,"TOPRIGHT",-6,-84)
    frame.scrollDown=Button(frame.treePanel,"v",22,24); frame.scrollDown:SetPoint("BOTTOMRIGHT",frame.treePanel,"BOTTOMRIGHT",-6,8)
    frame.scrollUp:SetScript("OnClick",function() PhaseC:ScrollTree(1) end)
    frame.scrollDown:SetScript("OnClick",function() PhaseC:ScrollTree(-1) end)

    frame.apiWarning=Text(frame.body,"The native Wrath talent APIs are not available on this client. Zen Talents cannot safely replace the frame until that backend is present.",11,"CENTER",frame.body,"CENTER",-70,0,false)
    frame.apiWarning:SetWidth(420); frame.apiWarning:SetJustifyH("CENTER"); frame.apiWarning:Hide()

    frame:SetScript("OnShow",function()
        if RUI.ActivateExclusivePanel then RUI:ActivateExclusivePanel(frame) end
        if SetButtonPulse and TalentMicroButton then SetButtonPulse(TalentMicroButton,0,1) end
        if PlaySound then pcall(PlaySound,"TalentScreenOpen") end
        if UpdateMicroButtons then pcall(UpdateMicroButtons) end
        if frame.mode=="glyphs" then PhaseC:SetMode("glyphs") else PhaseC:SetMode("talents") end
    end)
    frame:SetScript("OnHide",function()
        if frame.specMenu then frame.specMenu:Hide() end
        if _G.GlyphFrame and not (InCombatLockdown and InCombatLockdown()) then _G.GlyphFrame:Hide() end
        ResetGlyphCursor()
        if PlaySound then pcall(PlaySound,"TalentScreenClose") end
        if UpdateMicroButtons then pcall(UpdateMicroButtons) end
        GameTooltip:Hide()
    end)
end

function PhaseC:Show(group)
    if not self.frame then return end
    if group and tonumber(group) then
        if HasEbonholdSpecSystem() then
            local requested=math.max(1,math.min(MAX_TALENT_GROUPS,tonumber(group)))
            if requested~=ReadEbonholdSpecIndex() then ApplyEbonholdSpec(requested) end
        else
            self.frame.selectedGroup=math.max(1,math.min(GetNumGroups(),tonumber(group)))
        end
    end
    self.frame.selectedGroup=GetActiveGroup()
    if not self.frame.selectedTab then self.frame.selectedTab=GetBestTab(self.frame.selectedGroup) end
    if RUI.ActivateExclusivePanel then RUI:ActivateExclusivePanel(self.frame) end
    self.frame:Show()
    self:SetMode("talents")
end

function PhaseC:Toggle(group)
    if not self.frame then return end
    if self.frame:IsShown() then
        if self.frame.mode=="glyphs" then self:SetMode("talents") else self.frame:Hide() end
    else
        self:Show(group)
    end
end

function PhaseC:HookStockTalentFrame()
    local stock=_G.PlayerTalentFrame
    if not stock or stock.RUIPhaseCHook or not stock.HookScript then return end
    stock.RUIPhaseCHook=true

    -- Zen owns the normal player Talent and Glyph entry points. Do not hard
    -- suppress PlayerTalentFrame because Hunter pet talents still rely on the
    -- native frame and the native Glyph backend still uses its talentGroup state.
    stock:HookScript("OnShow",function()
        if PhaseC.nativeTalentBootstrap then return end
        if PhaseC.frame and PhaseC.frame:IsShown() then PhaseC.frame:Hide() end
    end)
end

function PhaseC:InstallCombatMenuBinding()
    if not RUI.RegisterCombatMenuRoute then return end
    RUI:RegisterCombatMenuRoute("Talents","TOGGLETALENTS",function()
        PhaseC:Toggle()
    end,Enabled())
    RUI:RegisterCombatMenuRoute("Glyphs","TOGGLEINSCRIPTION",function()
        PhaseC:ToggleGlyphs()
    end,Enabled())
end

function PhaseC:InstallOverrides()
    if not self.ruiToggleTalentFrame then
        self.ruiToggleTalentFrame=function(...)
            if Enabled() then PhaseC:Toggle(); return end
            local original=PhaseC.originalToggleTalentFrame
            if type(original)=="function" then return original(...) end

            -- If Zen Talents is disabled before Blizzard_TalentUI has ever
            -- loaded this session, restore the stock path on demand instead of
            -- leaving the Talents keybind/menu entry with nothing to open.
            if type(TalentFrame_LoadUI)=="function" then pcall(TalentFrame_LoadUI) end
            if type(PlayerTalentFrame_Toggle)=="function" then return PlayerTalentFrame_Toggle(false,...) end
            if type(LoadAddOn)=="function" then
                pcall(LoadAddOn,"Blizzard_TalentUI")
                if type(PlayerTalentFrame_Toggle)=="function" then return PlayerTalentFrame_Toggle(false,...) end
            end
        end
    end
    if _G.ToggleTalentFrame~=self.ruiToggleTalentFrame then
        if type(_G.ToggleTalentFrame)=="function" and _G.ToggleTalentFrame~=self.ruiToggleTalentFrame then
            self.originalToggleTalentFrame=_G.ToggleTalentFrame
        end
        _G.ToggleTalentFrame=self.ruiToggleTalentFrame
    end

    if not self.zenToggleGlyphFrame then
        self.zenToggleGlyphFrame=function(...)
            if Enabled() then PhaseC:ToggleGlyphs(); return end
            local original=PhaseC.originalToggleGlyphFrame
            if type(original)=="function" then return original(...) end
            EnsureGlyphBackend()
            if type(GlyphFrame_Toggle)=="function" then return GlyphFrame_Toggle(...) end
        end
    end
    if _G.ToggleGlyphFrame~=self.zenToggleGlyphFrame then
        if type(_G.ToggleGlyphFrame)=="function" and _G.ToggleGlyphFrame~=self.zenToggleGlyphFrame then
            self.originalToggleGlyphFrame=_G.ToggleGlyphFrame
        end
        _G.ToggleGlyphFrame=self.zenToggleGlyphFrame
    end

    -- Right-clicking a glyph item does not necessarily call ToggleGlyphFrame.
    -- Stock Wrath commonly uses GlyphFrame_Open / PlayerTalentFrame_OpenGlyphFrame,
    -- so own those entry points as well while Zen Talents/Glyphs is enabled.
    if type(_G.GlyphFrame_Open)=="function" and _G.GlyphFrame_Open~=self.zenGlyphFrameOpen then
        if not self.originalGlyphFrameOpen then self.originalGlyphFrameOpen=_G.GlyphFrame_Open end
    end
    if not self.zenGlyphFrameOpen then
        self.zenGlyphFrameOpen=function(...)
            if Enabled() then PhaseC:ScheduleGlyphRedirect(0); return end
            local original=PhaseC.originalGlyphFrameOpen
            if type(original)=="function" then return original(...) end
        end
    end
    if type(_G.GlyphFrame_Open)=="function" then _G.GlyphFrame_Open=self.zenGlyphFrameOpen end

    if type(_G.GlyphFrame_Toggle)=="function" and _G.GlyphFrame_Toggle~=self.zenGlyphFrameToggle then
        if not self.originalGlyphFrameToggle then self.originalGlyphFrameToggle=_G.GlyphFrame_Toggle end
    end
    if not self.zenGlyphFrameToggle then
        self.zenGlyphFrameToggle=function(...)
            if Enabled() then PhaseC:ToggleGlyphs(); return end
            local original=PhaseC.originalGlyphFrameToggle
            if type(original)=="function" then return original(...) end
        end
    end
    if type(_G.GlyphFrame_Toggle)=="function" then _G.GlyphFrame_Toggle=self.zenGlyphFrameToggle end

    if type(_G.PlayerTalentFrame_OpenGlyphFrame)=="function" and _G.PlayerTalentFrame_OpenGlyphFrame~=self.zenPlayerTalentOpenGlyphFrame then
        if not self.originalPlayerTalentOpenGlyphFrame then self.originalPlayerTalentOpenGlyphFrame=_G.PlayerTalentFrame_OpenGlyphFrame end
    end
    if not self.zenPlayerTalentOpenGlyphFrame then
        self.zenPlayerTalentOpenGlyphFrame=function(...)
            if Enabled() then PhaseC:ScheduleGlyphRedirect(0); return end
            local original=PhaseC.originalPlayerTalentOpenGlyphFrame
            if type(original)=="function" then return original(...) end
        end
    end
    if type(_G.PlayerTalentFrame_OpenGlyphFrame)=="function" then _G.PlayerTalentFrame_OpenGlyphFrame=self.zenPlayerTalentOpenGlyphFrame end

    self:HookNativeGlyphFrame()
    self:HookStockTalentFrame()
end

function PhaseC:ApplySettings()
    if not self.frame then return end
    RUI:SetMoverEnabled(INFO.talents.mover,Enabled())
    self:ApplyScale()
    if not Enabled() then
        if self.frame:IsShown() then self.frame:Hide() end
        self:RestoreNativeGlyphFrame()
    end
    self:InstallCombatMenuBinding()
end

function PhaseC:OnAppearance()
    if not self.frame then return end
    RUI:RefreshBackdrop(self.frame)
    RUI:SetAccentTexture(self.frame.accent)
    self:ApplyScale()
    if self.frame:IsShown() then self:Refresh() end
end

function PhaseC:OnScaleChanged(key)
    if key=="all" or key==INFO.talents.scale then self:ApplyScale() end
end

function PhaseC:OnEvent(event,...)
    if event=="UPDATE_BINDINGS" or event=="PLAYER_REGEN_ENABLED" then
        self:InstallCombatMenuBinding()
        return
    end
    if event=="ADDON_LOADED" then
        self:InstallOverrides()
        self:InstallEbonholdSpecBridge()
        local addon=...
        if addon=="Blizzard_TalentUI" then
            self.nativeTalentResetButton=nil
            self:HookStockTalentFrame()
            if self.frame:IsShown() then self:Refresh() end
        elseif addon=="Blizzard_GlyphUI" then
            -- Blizzard_GlyphUI defines GlyphFrame_Open / GlyphFrame_Toggle only
            -- when the load-on-demand addon initializes, so reinstall the Zen
            -- redirects here after those globals exist.
            self:InstallOverrides()
            self:HookNativeGlyphFrame()
            if _G.GlyphFrame and not (InCombatLockdown and InCombatLockdown()) then _G.GlyphFrame:Hide() end
            if self.frame and self.frame:IsShown() and self.frame.mode=="glyphs" then self:RefreshGlyphs() end
        end
        return
    end
    if event=="USE_GLYPH" then
        -- Right-clicking a glyph item starts the native glyph targeting mode.
        -- Preserve that backend action, but redirect the visual UI after the
        -- current event dispatch so Blizzard's parchment cannot win the race.
        if Enabled() then self:ScheduleGlyphRedirect(0.02) end
        if self.frame and self.frame:IsShown() and self.frame.mode=="glyphs" then self:RefreshGlyphs() end
        return
    end
    if event=="GLYPH_ADDED" or event=="GLYPH_REMOVED" or event=="GLYPH_UPDATED" then
        if self.frame and self.frame:IsShown() and self.frame.mode=="glyphs" then
            self:RefreshGlyphs()
            local focus=GetMouseFocus and GetMouseFocus()
            if focus and focus.slotID then self:ShowGlyphTooltip(focus) end
        end
        return
    end
    if event=="PLAYER_ENTERING_WORLD" then
        self:InstallOverrides(); self:ApplySettings(); self:InstallEbonholdSpecBridge(); RequestEbonholdCurrentSpec()
        self.frame.selectedGroup=GetActiveGroup()
        self.frame.selectedSpec=ReadEbonholdSpecIndex()
        if self.frame:IsShown() then self.frame.selectedTab=GetBestTab(self.frame.selectedGroup); self:Refresh() end
        return
    end
    if event=="ACTIVE_TALENT_GROUP_CHANGED" then
        if self.frame:IsShown() then
            self.frame.selectedGroup=GetActiveGroup()
            self.frame.selectedTab=GetBestTab(self.frame.selectedGroup)
            self.frame.treeScrollOffset=0
            self:Refresh()
        end
        return
    end
    if event=="PLAYER_TALENT_UPDATE" or event=="PREVIEW_TALENT_POINTS_CHANGED" or event=="PLAYER_LEVEL_UP" or event=="SPELLS_CHANGED" then
        if event=="PLAYER_TALENT_UPDATE" and HasEbonholdSpecSystem() then
            -- A spec swap has now delivered its real talent data. The talent
            -- update and Ebonhold's selected-spec callback can arrive in either
            -- order, so remember which slot this data belongs to and clear the
            -- pending guard only once both sides agree.
            local spec=tonumber(self.ebonholdSpecSwitchPending) or ReadEbonholdSpecIndex()
            local group=GetActiveGroup()
            local icon,points=GetSpecIcon(group)
            if icon and (tonumber(points) or 0)>0 then
                RememberSpecIcon(spec,icon)
            else
                -- Reset Talents has left this saved Ebonhold spec with no
                -- dominant tree. Persist the neutral/default icon so switching
                -- away does not resurrect the old main-tree image.
                RememberSpecIcon(spec,GetDefaultSpecIcon(group))
            end
            self.ebonholdSpecDataReadyIndex=spec
            if ReadEbonholdSpecIndex()==spec then
                self.ebonholdSpecSwitchPending=nil
                self.ebonholdSpecDataReadyIndex=nil
            end
        end
        if self.frame:IsShown() then self:Refresh() end
        return
    end
end

function PhaseC:OnInitialize()
    self:CreateTalents()
    self:RegisterMover()
    self:InstallOverrides()
    self:InstallCombatMenuBinding()
    self:InstallEbonholdSpecBridge()
    RUI:RegisterCallback("APPEARANCE_CHANGED",self,"OnAppearance")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED",self,"OnScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET",self,"ApplySettings")
end

function PhaseC:OnEnable()
    local events={"ADDON_LOADED","PLAYER_ENTERING_WORLD","UPDATE_BINDINGS","PLAYER_REGEN_ENABLED","PLAYER_TALENT_UPDATE","PREVIEW_TALENT_POINTS_CHANGED","ACTIVE_TALENT_GROUP_CHANGED","PLAYER_LEVEL_UP","SPELLS_CHANGED","GLYPH_ADDED","GLYPH_REMOVED","GLYPH_UPDATED","USE_GLYPH"}
    for i=1,#events do self:RegisterEvent(events[i],"OnEvent") end
    self:ApplySettings()
end
