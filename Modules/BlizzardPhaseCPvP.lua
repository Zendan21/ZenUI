-- ZenUI 0.9.10 Phase C PvP replacement.
-- Zen owns the visible Honor / Battleground / Arena window while the
-- Wrath 3.3.5 PvP APIs remain authoritative for stats, queues and arena teams.

local RUI = ZenUI
local PvP = RUI:NewModule("BlizzardPhaseCPvP")

local WIDTH, HEIGHT = 760, 600
local MOVER = "ZenPvP"
local SCALE_KEY = "zenPVP"
local BG_ROWS = 10
local ARENA_ROWS = 10
local MAX_QUEUES_FALLBACK = 3

local function Settings()
    if not RUI.db then return nil end
    RUI.db.blizzard = RUI.db.blizzard or {}
    return RUI.db.blizzard
end

local function Enabled()
    local s=Settings()
    if not s or s.enabled==false then return false end
    if s.pvp==nil then return true end
    return s.pvp and true or false
end

local function Text(parent,text,size,point,rel,relPoint,x,y,muted)
    local fs=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    fs:SetPoint(point or "TOPLEFT",rel or parent,relPoint or point or "TOPLEFT",x or 0,y or 0)
    local r,g,b=RUI:GetTextColor(muted and true or false)
    RUI:StyleFontString(fs,size or 10,r,g,b)
    fs:SetText(text or "")
    return fs
end

local function Button(parent,label,width,height)
    local b=CreateFrame("Button",nil,parent)
    b:SetWidth(width or 100); b:SetHeight(height or 24)
    b.RUIText=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    b.RUIText:SetPoint("CENTER")
    b.RUIText:SetText(label or "Button")
    RUI:StyleButton(b)
    return b
end

local function SetButtonEnabled(button,enabled)
    if not button then return end
    if enabled then button:Enable() else button:Disable() end
    local r,g,b=RUI:GetTextColor(not enabled)
    if button.RUIText then button.RUIText:SetTextColor(r,g,b) end
    button:SetAlpha(enabled and 1 or 0.45)
end

local function AddSpecial(frame)
    if not frame or not frame.GetName or not frame:GetName() then return end
    UISpecialFrames=UISpecialFrames or {}
    for i=1,#UISpecialFrames do if UISpecialFrames[i]==frame:GetName() then return end end
    table.insert(UISpecialFrames,frame:GetName())
end

local function MoneyLike(value)
    value=tonumber(value) or 0
    if BreakUpLargeNumbers then
        local ok,text=pcall(BreakUpLargeNumbers,value)
        if ok and text then return text end
    end
    return tostring(value)
end

local function CreateValueCard(parent,title,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent)
    f:SetWidth(w); f:SetHeight(h); f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    RUI:CreateBackdrop(f)
    f.label=Text(f,title,8,"TOPLEFT",f,"TOPLEFT",10,-10,true)
    f.value=Text(f,"0",22,"TOPLEFT",f,"TOPLEFT",10,-28,false)
    f.sub=Text(f,"",8,"BOTTOMLEFT",f,"BOTTOMLEFT",10,9,true)
    f.sub:SetWidth(w-20); f.sub:SetJustifyH("LEFT")
    return f
end

local function ArenaSizeLabel(size)
    size=tonumber(size)
    if size==2 then return "2v2" end
    if size==3 then return "3v3" end
    if size==5 then return "5v5" end
    return tostring(size or "?").."v"..tostring(size or "?")
end

local function IsGroupLeaderForBG()
    local party=(GetNumPartyMembers and GetNumPartyMembers()) or 0
    local raid=(GetNumRaidMembers and GetNumRaidMembers()) or 0
    if party<=0 and raid<=0 then return false end
    if IsPartyLeader then return IsPartyLeader() and true or false end
    return false
end

function PvP:CreateFrame()
    local f=CreateFrame("Frame","ZenUIPVPFrame",UIParent)
    self.frame=f
    f:SetWidth(WIDTH); f:SetHeight(HEIGHT); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true); f:Hide()
    RUI:CreateBackdrop(f); f.accent=RUI:CreateAccentLine(f,2)
    f.title=Text(f,"PvP",15,"TOPLEFT",f,"TOPLEFT",16,-17,false)
    f.subtitle=Text(f,"Honor, battlegrounds and arena",8,"LEFT",f.title,"RIGHT",10,-1,true)
    f.close=Button(f,"X",28,24); f.close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-10,-10); f.close:SetScript("OnClick",function() f:Hide() end)
    AddSpecial(f)
    if RUI.RegisterExclusivePanel then RUI:RegisterExclusivePanel(f) end

    f.tabs={}
    local tabDefs={{"honor","Honor"},{"battlegrounds","Battlegrounds"},{"arena","Arena"}}
    for i,def in ipairs(tabDefs) do
        local b=Button(f,def[2],145,28)
        b:SetPoint("TOPLEFT",f,"TOPLEFT",16+((i-1)*153),-50)
        b.page=def[1]
        b:SetScript("OnClick",function(self) PvP:SetPage(self.page) end)
        f.tabs[def[1]]=b
    end

    f.pageHolder=CreateFrame("Frame",nil,f)
    f.pageHolder:SetPoint("TOPLEFT",f,"TOPLEFT",14,-86)
    f.pageHolder:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-14,14)

    self:CreateHonorPage()
    self:CreateBattlegroundPage()
    self:CreateArenaPage()

    f:SetScript("OnShow",function()
        if PlaySound then pcall(PlaySound,"igCharacterInfoOpen") end
        PvP:Refresh()
        if UpdateMicroButtons then pcall(UpdateMicroButtons) end
    end)
    f:SetScript("OnHide",function()
        if PlaySound then pcall(PlaySound,"igCharacterInfoClose") end
        if UpdateMicroButtons then pcall(UpdateMicroButtons) end
        GameTooltip:Hide()
    end)
    f:SetScript("OnUpdate",function(_,elapsed)
        if PvP.bgInfoDelay then
            PvP.bgInfoDelay=PvP.bgInfoDelay-(tonumber(elapsed) or 0)
            if PvP.bgInfoDelay<=0 then
                PvP.bgInfoDelay=nil
                PvP:RefreshBattlegroundInfo()
            end
        end
    end)

    self:SetPage("honor")
end

function PvP:CreateHonorPage()
    local page=CreateFrame("Frame",nil,self.frame.pageHolder)
    page:SetAllPoints(self.frame.pageHolder); page:Hide(); self.frame.honorPage=page

    page.heading=Text(page,"Honor Overview",14,"TOPLEFT",page,"TOPLEFT",6,-4,false)
    page.note=Text(page,"Live Wrath PvP currency and kill statistics",8,"LEFT",page.heading,"RIGHT",10,-1,true)

    page.honor=CreateValueCard(page,"HONOR POINTS",6,-36,220,94)
    page.arena=CreateValueCard(page,"ARENA POINTS",238,-36,220,94)
    page.season=CreateValueCard(page,"ARENA SEASON",470,-36,248,94)

    page.today=CreateValueCard(page,"TODAY",6,-144,220,112)
    page.yesterday=CreateValueCard(page,"YESTERDAY",238,-144,220,112)
    page.lifetime=CreateValueCard(page,"LIFETIME",470,-144,248,112)

    page.tip=CreateFrame("Frame",nil,page); page.tip:SetPoint("TOPLEFT",page,"TOPLEFT",6,-276); page.tip:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-6,6); RUI:CreateBackdrop(page.tip)
    page.tipTitle=Text(page.tip,"PVP STATUS",9,"TOPLEFT",page.tip,"TOPLEFT",12,-12,true)
    page.tipFaction=Text(page.tip,"",16,"TOPLEFT",page.tip,"TOPLEFT",12,-36,false)
    page.tipText=Text(page.tip,"Honor and Arena values update directly from the client. Battleground queues and Arena team details are available from the tabs above.",9,"TOPLEFT",page.tip,"TOPLEFT",12,-68,true)
    page.tipText:SetWidth(670); page.tipText:SetJustifyH("LEFT")
end

function PvP:CreateBattlegroundPage()
    local page=CreateFrame("Frame",nil,self.frame.pageHolder)
    page:SetAllPoints(self.frame.pageHolder); page:Hide(); self.frame.bgPage=page

    page.list=CreateFrame("Frame",nil,page); page.list:SetWidth(250); page.list:SetPoint("TOPLEFT",page,"TOPLEFT",6,-4); page.list:SetPoint("BOTTOMLEFT",page,"BOTTOMLEFT",6,6); RUI:CreateBackdrop(page.list)
    page.listTitle=Text(page.list,"BATTLEGROUNDS",9,"TOPLEFT",page.list,"TOPLEFT",10,-10,true)
    page.rows={}
    for i=1,BG_ROWS do
        local b=Button(page.list,"",230,34); b:SetPoint("TOPLEFT",page.list,"TOPLEFT",10,-30-((i-1)*37)); b.row=i
        b.RUIText:ClearAllPoints(); b.RUIText:SetPoint("LEFT",b,"LEFT",9,0); b.RUIText:SetWidth(168); b.RUIText:SetJustifyH("LEFT")
        b.status=Text(b,"",8,"RIGHT",b,"RIGHT",-7,0,true); b.status:SetJustifyH("RIGHT")
        b:SetScript("OnClick",function(self)
            if self.bgIndex then PvP:SelectBattleground(self.bgIndex) end
        end)
        page.rows[i]=b
    end
    page.up=Button(page.list,"^",30,24); page.up:SetPoint("BOTTOMLEFT",page.list,"BOTTOMLEFT",10,9)
    page.down=Button(page.list,"v",30,24); page.down:SetPoint("LEFT",page.up,"RIGHT",5,0)
    page.up:SetScript("OnClick",function() PvP:SetBGOffset((PvP.bgOffset or 0)-1) end)
    page.down:SetScript("OnClick",function() PvP:SetBGOffset((PvP.bgOffset or 0)+1) end)

    page.info=CreateFrame("Frame",nil,page); page.info:SetPoint("TOPLEFT",page,"TOPLEFT",268,-4); page.info:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-6,6); RUI:CreateBackdrop(page.info)
    page.name=Text(page.info,"Select a battleground",16,"TOPLEFT",page.info,"TOPLEFT",14,-14,false)
    page.flags=Text(page.info,"",8,"TOPLEFT",page.info,"TOPLEFT",14,-41,true)
    page.description=Text(page.info,"",9,"TOPLEFT",page.info,"TOPLEFT",14,-68,true); page.description:SetWidth(420); page.description:SetHeight(210); page.description:SetJustifyH("LEFT"); page.description:SetJustifyV("TOP")
    page.queueTitle=Text(page.info,"QUEUE STATUS",8,"TOPLEFT",page.info,"TOPLEFT",14,-294,true)
    page.queue=Text(page.info,"Not queued",10,"TOPLEFT",page.info,"TOPLEFT",14,-316,false); page.queue:SetWidth(420); page.queue:SetJustifyH("LEFT")
    page.solo=Button(page.info,"Join Battle",130,28); page.solo:SetPoint("BOTTOMLEFT",page.info,"BOTTOMLEFT",14,15)
    page.group=Button(page.info,"Join as Group",140,28); page.group:SetPoint("LEFT",page.solo,"RIGHT",8,0)
    page.queueAction=Button(page.info,"",130,28); page.queueAction:SetPoint("LEFT",page.group,"RIGHT",8,0); page.queueAction:Hide()
    page.solo:SetScript("OnClick",function() PvP:JoinSelectedBattleground(false) end)
    page.group:SetScript("OnClick",function() PvP:JoinSelectedBattleground(true) end)
    page.queueAction:SetScript("OnClick",function() PvP:HandleQueueAction() end)
end

function PvP:CreateArenaPage()
    local page=CreateFrame("Frame",nil,self.frame.pageHolder)
    page:SetAllPoints(self.frame.pageHolder); page:Hide(); self.frame.arenaPage=page

    page.teamList=CreateFrame("Frame",nil,page); page.teamList:SetWidth(250); page.teamList:SetPoint("TOPLEFT",page,"TOPLEFT",6,-4); page.teamList:SetPoint("BOTTOMLEFT",page,"BOTTOMLEFT",6,6); RUI:CreateBackdrop(page.teamList)
    page.teamTitle=Text(page.teamList,"ARENA TEAMS",9,"TOPLEFT",page.teamList,"TOPLEFT",10,-10,true)
    page.teams={}
    for row,size in ipairs({2,3,5}) do
        local b=Button(page.teamList,"",230,74); b:SetPoint("TOPLEFT",page.teamList,"TOPLEFT",10,-32-((row-1)*80)); b.arenaSize=size
        b.RUIText:ClearAllPoints(); b.RUIText:SetPoint("TOPLEFT",b,"TOPLEFT",10,-10); b.RUIText:SetWidth(200); b.RUIText:SetJustifyH("LEFT")
        b.stats=Text(b,"",8,"BOTTOMLEFT",b,"BOTTOMLEFT",10,10,true); b.stats:SetWidth(200); b.stats:SetJustifyH("LEFT")
        b:SetScript("OnClick",function(self) if self.teamIndex then PvP:SelectArenaTeam(self.teamIndex) end end)
        page.teams[row]=b
    end
    page.mode=Button(page.teamList,"Showing: This Week",230,26); page.mode:SetPoint("BOTTOMLEFT",page.teamList,"BOTTOMLEFT",10,12)
    page.mode:SetScript("OnClick",function() PvP.arenaSeason=not PvP.arenaSeason; PvP:RefreshArena() end)

    page.detail=CreateFrame("Frame",nil,page); page.detail:SetPoint("TOPLEFT",page,"TOPLEFT",268,-4); page.detail:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-6,6); RUI:CreateBackdrop(page.detail)
    page.detailName=Text(page.detail,"Select an Arena team",16,"TOPLEFT",page.detail,"TOPLEFT",14,-14,false)
    page.detailStats=Text(page.detail,"",9,"TOPLEFT",page.detail,"TOPLEFT",14,-42,true); page.detailStats:SetWidth(420); page.detailStats:SetJustifyH("LEFT")
    page.headers=Text(page.detail,"PLAYER                                  W-L       RATING",8,"TOPLEFT",page.detail,"TOPLEFT",14,-76,true)
    page.roster={}
    for i=1,ARENA_ROWS do
        local row=CreateFrame("Frame",nil,page.detail); row:SetWidth(420); row:SetHeight(30); row:SetPoint("TOPLEFT",page.detail,"TOPLEFT",14,-94-((i-1)*32)); RUI:CreateBackdrop(row)
        row.name=Text(row,"",9,"LEFT",row,"LEFT",8,0,false); row.name:SetWidth(245); row.name:SetJustifyH("LEFT")
        row.record=Text(row,"",8,"LEFT",row,"LEFT",260,0,true); row.record:SetWidth(70); row.record:SetJustifyH("LEFT")
        row.rating=Text(row,"",8,"RIGHT",row,"RIGHT",-8,0,false); row.rating:SetWidth(65); row.rating:SetJustifyH("RIGHT")
        row:Hide(); page.roster[i]=row
    end
    page.empty=Text(page.detail,"No Arena team selected.",10,"CENTER",page.detail,"CENTER",0,-10,true)
end

function PvP:SetPage(page)
    local f=self.frame; if not f then return end
    page=page or "honor"; f.activePage=page
    for key,b in pairs(f.tabs) do
        if key==page then
            local r,g,bl=RUI:GetAccentColor(); RUI:SetBorderColor(b,r,g,bl,1); b:SetAlpha(1)
        else
            RUI:RefreshBackdrop(b); b:SetAlpha(0.72)
        end
    end
    if page=="honor" then f.honorPage:Show() else f.honorPage:Hide() end
    if page=="battlegrounds" then f.bgPage:Show() else f.bgPage:Hide() end
    if page=="arena" then f.arenaPage:Show() else f.arenaPage:Hide() end
    if page=="battlegrounds" then self:RefreshBattlegrounds()
    elseif page=="arena" then self:RefreshArena()
    else self:RefreshHonor() end
end

function PvP:RefreshHonor()
    local page=self.frame and self.frame.honorPage; if not page then return end
    local honor=(GetHonorCurrency and GetHonorCurrency()) or 0
    local arena=(GetArenaCurrency and GetArenaCurrency()) or 0
    page.honor.value:SetText(MoneyLike(honor)); page.honor.sub:SetText("Current spendable honor")
    page.arena.value:SetText(MoneyLike(arena)); page.arena.sub:SetText("Current spendable arena points")
    local season=(GetCurrentArenaSeason and GetCurrentArenaSeason()) or 0
    page.season.value:SetText(season>0 and tostring(season) or "Off-season"); page.season.sub:SetText(season>0 and "Current arena season" or "Arena season currently inactive")

    local hk,cp=0,0
    if GetPVPSessionStats then hk,cp=GetPVPSessionStats() end
    page.today.value:SetText(MoneyLike(hk or 0).." HK"); page.today.sub:SetText(MoneyLike(cp or 0).." honor earned")
    if GetPVPYesterdayStats then hk,cp=GetPVPYesterdayStats() else hk,cp=0,0 end
    page.yesterday.value:SetText(MoneyLike(hk or 0).." HK"); page.yesterday.sub:SetText(MoneyLike(cp or 0).." honor earned")
    if GetPVPLifetimeStats then hk,cp=GetPVPLifetimeStats() else hk,cp=0,0 end
    page.lifetime.value:SetText(MoneyLike(hk or 0).." HK"); page.lifetime.sub:SetText("Lifetime honorable kills")
    local faction=(UnitFactionGroup and UnitFactionGroup("player")) or "Neutral"
    page.tipFaction:SetText(tostring(faction))
end

function PvP:BuildBattlegroundList()
    self.battlegrounds={}
    local n=(GetNumBattlegroundTypes and GetNumBattlegroundTypes()) or 0
    for i=1,n do
        local name,canEnter,isHoliday,isRandom,bgID=GetBattlegroundInfo(i)
        if name and canEnter then
            self.battlegrounds[#self.battlegrounds+1]={ index=i,name=name,holiday=isHoliday and true or false,random=isRandom and true or false,id=bgID }
        end
    end
    if not self.selectedBG and self.battlegrounds[1] then self.selectedBG=self.battlegrounds[1].index end
    local found=false
    for _,bg in ipairs(self.battlegrounds) do if bg.index==self.selectedBG then found=true break end end
    if not found then self.selectedBG=self.battlegrounds[1] and self.battlegrounds[1].index or nil end
end

function PvP:QueueStatusForName(name)
    local max=tonumber(MAX_BATTLEFIELD_QUEUES) or MAX_QUEUES_FALLBACK
    for i=1,max do
        if GetBattlefieldStatus then
            local status,mapName=GetBattlefieldStatus(i)
            if status and status~="none" and mapName==name then return status,i end
        end
    end
    return nil,nil
end

function PvP:SetBGOffset(value)
    local max=math.max(0,#(self.battlegrounds or {})-BG_ROWS)
    self.bgOffset=math.max(0,math.min(max,tonumber(value) or 0))
    self:RefreshBattlegroundRows()
end

function PvP:RefreshBattlegroundRows()
    local page=self.frame and self.frame.bgPage; if not page then return end
    local list=self.battlegrounds or {}; local offset=self.bgOffset or 0
    for i=1,BG_ROWS do
        local b=page.rows[i]; local bg=list[offset+i]
        if bg then
            b.bgIndex=bg.index
            local label=bg.name
            if bg.holiday then label=label.." *" end
            b.RUIText:SetText(label)
            local status=self:QueueStatusForName(bg.name)
            if status=="queued" then b.status:SetText("QUEUED")
            elseif status=="confirm" then b.status:SetText("READY")
            elseif status=="active" then b.status:SetText("ACTIVE")
            else b.status:SetText("") end
            if bg.index==self.selectedBG then local r,g,bl=RUI:GetAccentColor(); RUI:SetBorderColor(b,r,g,bl,1) else RUI:RefreshBackdrop(b) end
            b:Show()
        else
            b.bgIndex=nil; b:Hide()
        end
    end
    local max=math.max(0,#list-BG_ROWS)
    SetButtonEnabled(page.up,(self.bgOffset or 0)>0)
    SetButtonEnabled(page.down,(self.bgOffset or 0)<max)
end

function PvP:SelectBattleground(index)
    index=tonumber(index); if not index then return end
    self.selectedBG=index
    if RequestBattlegroundInstanceInfo then pcall(RequestBattlegroundInstanceInfo,index) end
    self.bgInfoDelay=0.12
    self:RefreshBattlegroundRows()
    self:RefreshBattlegroundInfo()
end

function PvP:RefreshBattlegroundInfo()
    local page=self.frame and self.frame.bgPage; if not page then return end
    if not self.selectedBG or not GetBattlegroundInfo then
        page.name:SetText("No battleground available"); page.description:SetText("No queueable battlegrounds are currently exposed by the client.")
        SetButtonEnabled(page.solo,false); SetButtonEnabled(page.group,false); return
    end
    local name,canEnter,isHoliday,isRandom=GetBattlegroundInfo(self.selectedBG)
    page.name:SetText(name or "Battleground")
    local flags={}
    if isRandom then flags[#flags+1]="Random Battleground" end
    if isHoliday then flags[#flags+1]="Call to Arms / Holiday" end
    page.flags:SetText(#flags>0 and table.concat(flags,"  •  ") or "Standard battleground queue")
    local mapName,description,maxGroup=nil,nil,nil
    if GetBattlefieldInfo then mapName,description,maxGroup=GetBattlefieldInfo() end
    page.description:SetText(description or "Battleground information is requested from the server when this entry is selected.")
    page.group.RUIText:SetText((tonumber(maxGroup)==5) and "Join as Party" or "Join as Group")
    SetButtonEnabled(page.solo,canEnter and true or false)
    SetButtonEnabled(page.group,canEnter and IsGroupLeaderForBG())
    self:RefreshQueueStatus()
end

function PvP:RefreshQueueStatus()
    local page=self.frame and self.frame.bgPage; if not page then return end
    local lines={}; self.actionQueueSlot=nil; self.actionQueueStatus=nil
    local max=tonumber(MAX_BATTLEFIELD_QUEUES) or MAX_QUEUES_FALLBACK
    for i=1,max do
        if GetBattlefieldStatus then
            local status,mapName=GetBattlefieldStatus(i)
            if status and status~="none" then
                local label=status=="queued" and "Queued" or status=="confirm" and "Ready to enter" or status=="active" and "Active" or status
                lines[#lines+1]=label..": "..tostring(mapName or "Battleground")
                if not self.actionQueueSlot and (status=="confirm" or status=="queued") then self.actionQueueSlot=i; self.actionQueueStatus=status end
            end
        end
    end
    page.queue:SetText(#lines>0 and table.concat(lines,"\n") or "Not queued")
    if self.actionQueueSlot and type(AcceptBattlefieldPort)=="function" then
        page.queueAction:Show()
        page.queueAction.RUIText:SetText(self.actionQueueStatus=="confirm" and "Enter Battle" or "Leave Queue")
    else
        page.queueAction:Hide()
    end
    self:RefreshBattlegroundRows()
end

function PvP:HandleQueueAction()
    if not self.actionQueueSlot or type(AcceptBattlefieldPort)~="function" then return end
    pcall(AcceptBattlefieldPort,self.actionQueueSlot,self.actionQueueStatus=="confirm")
end

function PvP:JoinSelectedBattleground(asGroup)
    if not self.selectedBG or type(JoinBattlefield)~="function" then return end
    if RequestBattlegroundInstanceInfo then pcall(RequestBattlegroundInstanceInfo,self.selectedBG) end
    pcall(JoinBattlefield,0,asGroup and true or false)
end

function PvP:RefreshBattlegrounds()
    self:BuildBattlegroundList()
    self:SetBGOffset(self.bgOffset or 0)
    if self.selectedBG and RequestBattlegroundInstanceInfo then pcall(RequestBattlegroundInstanceInfo,self.selectedBG) end
    self.bgInfoDelay=0.12
    self:RefreshBattlegroundInfo()
end

function PvP:FindArenaTeamBySize(size)
    if type(GetArenaTeam)~="function" then return nil end
    for i=1,3 do
        local name,teamSize=GetArenaTeam(i)
        if name and tonumber(teamSize)==tonumber(size) then return i end
    end
    return nil
end

function PvP:SelectArenaTeam(index)
    index=tonumber(index); if not index then return end
    self.selectedArenaTeam=index
    if ArenaTeamRoster then pcall(ArenaTeamRoster,index) end
    self:RefreshArena()
end

function PvP:RefreshArena()
    local page=self.frame and self.frame.arenaPage; if not page then return end
    page.mode.RUIText:SetText(self.arenaSeason and "Showing: This Season" or "Showing: This Week")
    local selectedExists=false
    for row,size in ipairs({2,3,5}) do
        local b=page.teams[row]; local idx=self:FindArenaTeamBySize(size); b.teamIndex=idx
        if idx and GetArenaTeam then
            local name,teamSize,rating,played,wins,seasonPlayed,seasonWins,playerPlayed,seasonPlayerPlayed,rank,personalRating=GetArenaTeam(idx)
            b.RUIText:SetText((name or "Arena Team").."  •  "..ArenaSizeLabel(teamSize))
            local usePlayed=self.arenaSeason and (seasonPlayed or 0) or (played or 0)
            local useWins=self.arenaSeason and (seasonWins or 0) or (wins or 0)
            b.stats:SetText("Rating "..tostring(rating or 0).."  •  "..tostring(useWins or 0).."-"..tostring((usePlayed or 0)-(useWins or 0)))
            b:SetAlpha(1)
            if idx==self.selectedArenaTeam then local r,g,bl=RUI:GetAccentColor(); RUI:SetBorderColor(b,r,g,bl,1); selectedExists=true else RUI:RefreshBackdrop(b) end
        else
            b.RUIText:SetText("No "..ArenaSizeLabel(size).." team")
            b.stats:SetText("Not currently registered")
            b:SetAlpha(0.45); RUI:RefreshBackdrop(b)
        end
    end
    if self.selectedArenaTeam and not selectedExists then self.selectedArenaTeam=nil end
    if not self.selectedArenaTeam then
        for row=1,3 do if page.teams[row].teamIndex then self.selectedArenaTeam=page.teams[row].teamIndex; if ArenaTeamRoster then pcall(ArenaTeamRoster,self.selectedArenaTeam) end; break end end
    end
    self:RefreshArenaDetails()
end

function PvP:RefreshArenaDetails()
    local page=self.frame and self.frame.arenaPage; if not page then return end
    local idx=self.selectedArenaTeam
    if not idx or type(GetArenaTeam)~="function" then
        page.detailName:SetText("No Arena team")
        page.detailStats:SetText("Join or create an Arena team to see roster and rating information here.")
        page.empty:Show(); for i=1,#page.roster do page.roster[i]:Hide() end
        return
    end
    local name,size,rating,played,wins,seasonPlayed,seasonWins,playerPlayed,seasonPlayerPlayed,rank,personalRating=GetArenaTeam(idx)
    if not name then self.selectedArenaTeam=nil; self:RefreshArenaDetails(); return end
    page.detailName:SetText(name.."  •  "..ArenaSizeLabel(size))
    local usePlayed=self.arenaSeason and (seasonPlayed or 0) or (played or 0)
    local useWins=self.arenaSeason and (seasonWins or 0) or (wins or 0)
    page.detailStats:SetText("Team Rating: "..tostring(rating or 0).."  •  Rank: "..tostring(rank or 0).."  •  Record: "..tostring(useWins or 0).."-"..tostring((usePlayed or 0)-(useWins or 0)).."  •  Personal: "..tostring(personalRating or 0))
    local count=(GetNumArenaTeamMembers and GetNumArenaTeamMembers(idx,1)) or 0
    if count<=0 then page.empty:Show() else page.empty:Hide() end
    for i=1,ARENA_ROWS do
        local row=page.roster[i]
        if i<=count and GetArenaTeamRosterInfo then
            local playerName,memberRank,level,class,online,weekPlayed,weekWins,seasonP,seasonW,memberRating=GetArenaTeamRosterInfo(idx,i)
            if playerName then
                row.name:SetText((online and "|cff66ff66" or "|cff888888")..playerName.."|r"..(class and "  "..class or ""))
                local p=self.arenaSeason and (seasonP or 0) or (weekPlayed or 0)
                local w=self.arenaSeason and (seasonW or 0) or (weekWins or 0)
                row.record:SetText(tostring(w or 0).."-"..tostring((p or 0)-(w or 0)))
                row.rating:SetText(tostring(memberRating or 0)); row:Show()
            else row:Hide() end
        else row:Hide() end
    end
end

function PvP:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    local page=self.frame.activePage or "honor"
    if page=="battlegrounds" then self:RefreshBattlegrounds()
    elseif page=="arena" then self:RefreshArena()
    else self:RefreshHonor() end
end

function PvP:Show(page)
    if not self.frame then return end
    if RUI.ActivateExclusivePanel then RUI:ActivateExclusivePanel(self.frame) end
    if page then self:SetPage(page) end
    self.frame:Show(); self:Refresh()
end

function PvP:Toggle(page)
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide() else self:Show(page) end
end

function PvP:RegisterMover()
    RUI:RegisterMover(MOVER,self.frame,{ label="PvP",width=WIDTH,height=HEIGHT,point="CENTER",relativePoint="CENTER",x=-260,y=10,targetPoint="TOPLEFT",moverPoint="TOPLEFT",enabled=Enabled() })
    self:ApplyScale()
end

function PvP:ApplyScale()
    if not self.frame then return end
    local scale=RUI:GetEffectiveScale(SCALE_KEY)
    self.frame:SetScale(scale)
    RUI:UpdateMoverSize(MOVER,WIDTH*scale,HEIGHT*scale)
end

function PvP:HookStock()
    local stock=_G.PVPParentFrame
    if not stock or stock.RUIPvPHook or not stock.HookScript then return end
    stock.RUIPvPHook=true
    stock:HookScript("OnShow",function(self)
        if not Enabled() or PvP.stockRedirect then return end
        PvP.stockRedirect=true
        self:Hide()
        PvP.stockRedirect=false
        PvP:Show("battlegrounds")
    end)
end

function PvP:InstallCombatMenuBinding()
    if not RUI.RegisterCombatMenuRoute then return end
    RUI:RegisterCombatMenuRoute("PvP","TOGGLECHARACTER4",function()
        PvP:Toggle()
    end,Enabled())
end

function PvP:InstallOverride()
    if not self.ruiToggle then
        self.ruiToggle=function(...)
            if Enabled() then PvP:Toggle(); return end
            if type(PvP.originalToggle)=="function" then return PvP.originalToggle(...) end
        end
    end
    if _G.TogglePVPFrame~=self.ruiToggle then
        if type(_G.TogglePVPFrame)=="function" and _G.TogglePVPFrame~=self.ruiToggle then self.originalToggle=_G.TogglePVPFrame end
        _G.TogglePVPFrame=self.ruiToggle
    end
    self:HookStock()
end

function PvP:ApplySettings()
    if not self.frame then return end
    RUI:SetMoverEnabled(MOVER,Enabled())
    self:ApplyScale()
    if not Enabled() and self.frame:IsShown() then self.frame:Hide() end
    self:InstallCombatMenuBinding()
end

function PvP:OnAppearance()
    if not self.frame then return end
    RUI:RefreshBackdrop(self.frame); RUI:SetAccentTexture(self.frame.accent); self:ApplyScale()
    if self.frame:IsShown() then self:SetPage(self.frame.activePage or "honor") end
end

function PvP:OnScaleChanged(key)
    if key=="all" or key==SCALE_KEY then self:ApplyScale() end
end

function PvP:OnEvent(event,...)
    if event=="UPDATE_BINDINGS" or event=="PLAYER_REGEN_ENABLED" then self:InstallCombatMenuBinding(); return end
    if event=="PLAYER_ENTERING_WORLD" or event=="ADDON_LOADED" then
        self:InstallOverride(); self:HookStock(); self:ApplySettings()
    end
    if event=="NPC_PVPQUEUE_ANYWHERE" and Enabled() then
        self:Show("battlegrounds")
    end
    if event=="ARENA_TEAM_ROSTER_UPDATE" or event=="ARENA_TEAM_UPDATE" then
        if self.frame:IsShown() and self.frame.activePage=="arena" then self:RefreshArena() end
        return
    end
    if event=="UPDATE_BATTLEFIELD_STATUS" or event=="PVPQUEUE_ANYWHERE_SHOW" or event=="PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE" or event=="PARTY_MEMBERS_CHANGED" then
        if self.frame:IsShown() and self.frame.activePage=="battlegrounds" then self:RefreshBattlegrounds() end
        return
    end
    if event=="PLAYER_PVP_KILLS_CHANGED" or event=="PLAYER_PVP_RANK_CHANGED" or event=="HONOR_CURRENCY_UPDATE" then
        if self.frame:IsShown() and self.frame.activePage=="honor" then self:RefreshHonor() end
        return
    end
end

function PvP:OnInitialize()
    self:CreateFrame(); self:RegisterMover(); self:InstallOverride(); self:HookStock(); self:InstallCombatMenuBinding()
    RUI:RegisterCallback("APPEARANCE_CHANGED",self,"OnAppearance")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED",self,"OnScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET",self,"ApplySettings")
end

function PvP:OnEnable()
    local events={"ADDON_LOADED","PLAYER_ENTERING_WORLD","UPDATE_BINDINGS","PLAYER_REGEN_ENABLED","ARENA_TEAM_UPDATE","ARENA_TEAM_ROSTER_UPDATE","PLAYER_PVP_KILLS_CHANGED","PLAYER_PVP_RANK_CHANGED","HONOR_CURRENCY_UPDATE","UPDATE_BATTLEFIELD_STATUS","PVPQUEUE_ANYWHERE_SHOW","PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE","NPC_PVPQUEUE_ANYWHERE","PARTY_MEMBERS_CHANGED"}
    for i=1,#events do self:RegisterEvent(events[i],"OnEvent") end
    self:ApplySettings()
end
