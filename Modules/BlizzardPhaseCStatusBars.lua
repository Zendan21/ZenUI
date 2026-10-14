-- ZenUI 0.9.20 Phase C Experience / Reputation bars.
-- Native Wrath XP and watched-reputation APIs remain authoritative; Zen
-- only owns presentation, movement and tooltips.

local RUI = ZenUI
local Bars = RUI:NewModule("BlizzardPhaseCStatusBars")

local WIDTH = 430
local HEIGHT = 18
local XP_MOVER = "ExperienceBar"
local REP_MOVER = "ReputationBar"
local SCALE_KEY = "zenStatusBars"

local function BlizzardSettings()
    if not RUI.db then return nil end
    RUI.db.blizzard = RUI.db.blizzard or {}
    return RUI.db.blizzard
end

local function XPEnabled()
    local s=BlizzardSettings()
    return not s or s.xpBar~=false
end

local function RepEnabled()
    local s=BlizzardSettings()
    return not s or s.reputationBar~=false
end

local function Number(v)
    v=math.floor((tonumber(v) or 0)+0.5)
    local text=tostring(v)
    local sign=""
    if string.sub(text,1,1)=="-" then sign="-"; text=string.sub(text,2) end
    while true do
        local changed
        text,changed=string.gsub(text,"^(%d+)(%d%d%d)","%1,%2")
        if changed==0 then break end
    end
    return sign..text
end

local function Percent(value,maxValue)
    value=tonumber(value) or 0
    maxValue=tonumber(maxValue) or 0
    if maxValue<=0 then return 0 end
    return math.max(0,math.min(100,(value/maxValue)*100))
end

local function Text(parent,size)
    local fs=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    local r,g,b=RUI:GetTextColor(false)
    RUI:StyleFontString(fs,size or 9,r,g,b)
    fs:SetShadowOffset(1,-1)
    return fs
end

local function CreateBar(name)
    local bar=CreateFrame("StatusBar",name,UIParent)
    bar:SetWidth(WIDTH); bar:SetHeight(HEIGHT)
    bar:SetFrameStrata("MEDIUM")
    bar:EnableMouse(true)
    bar:SetMinMaxValues(0,1); bar:SetValue(0)
    bar:SetStatusBarTexture(RUI.Media.textures.white)
    RUI:CreateBackdrop(bar)

    bar.text=Text(bar,9)
    bar.text:SetPoint("CENTER",bar,"CENTER",0,0)
    bar.text:SetWidth(WIDTH-12)
    bar.text:SetJustifyH("CENTER")

    bar:SetScript("OnEnter",function(self) Bars:ShowTooltip(self) end)
    bar:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    return bar
end

function Bars:CreateFrames()
    self.xp=CreateBar("ZenUIExperienceBar")
    self.xp.kind="xp"
    self.xp.rested=self.xp:CreateTexture(nil,"ARTWORK")
    self.xp.rested:SetTexture(RUI.Media.textures.white)
    if self.xp.rested.SetDrawLayer then self.xp.rested:SetDrawLayer("ARTWORK",-1) end
    self.xp.rested:SetVertexColor(0.18,0.48,0.95,0.55)
    self.xp.rested:Hide()

    self.rep=CreateBar("ZenUIReputationBar")
    self.rep.kind="rep"
end

function Bars:RegisterMovers()
    RUI:RegisterMover(XP_MOVER,self.xp,{ label="Experience Bar",width=WIDTH,height=HEIGHT,point="CENTER",relativePoint="CENTER",x=0,y=-335,targetPoint="CENTER",moverPoint="CENTER",enabled=XPEnabled() })
    RUI:RegisterMover(REP_MOVER,self.rep,{ label="Reputation Bar",width=WIDTH,height=HEIGHT,point="CENTER",relativePoint="CENTER",x=0,y=-313,targetPoint="CENTER",moverPoint="CENTER",enabled=RepEnabled() })
    self:ApplyScale()
end

function Bars:ApplyScale()
    local scale=RUI:GetEffectiveScale(SCALE_KEY)
    if self.xp then self.xp:SetScale(scale) end
    if self.rep then self.rep:SetScale(scale) end
    RUI:UpdateMoverSize(XP_MOVER,WIDTH*scale,HEIGHT*scale)
    RUI:UpdateMoverSize(REP_MOVER,WIDTH*scale,HEIGHT*scale)
end

local function MaxPlayerLevel()
    if type(GetMaxPlayerLevel)=="function" then
        local ok,value=pcall(GetMaxPlayerLevel)
        if ok and tonumber(value) then return tonumber(value) end
    end
    if tonumber(MAX_PLAYER_LEVEL) then return tonumber(MAX_PLAYER_LEVEL) end
    return 80
end

function Bars:RefreshXP()
    local bar=self.xp
    if not bar then return end
    if not XPEnabled() then bar:Hide(); return end

    local level=UnitLevel and (tonumber(UnitLevel("player")) or 0) or 0
    local current=UnitXP and (tonumber(UnitXP("player")) or 0) or 0
    local maximum=UnitXPMax and (tonumber(UnitXPMax("player")) or 0) or 0
    if level>=MaxPlayerLevel() or maximum<=0 then
        bar:Hide(); return
    end

    bar:SetMinMaxValues(0,maximum)
    bar:SetValue(math.max(0,math.min(current,maximum)))
    local ar,ag,ab=RUI:GetAccentColor()
    bar:SetStatusBarColor(ar,ag,ab,0.95)

    local rested=(GetXPExhaustion and tonumber(GetXPExhaustion())) or 0
    if rested>0 and maximum>0 then
        local startFrac=math.max(0,math.min(1,current/maximum))
        local endFrac=math.max(startFrac,math.min(1,(current+rested)/maximum))
        local width=WIDTH*(endFrac-startFrac)
        if width>0.5 then
            bar.rested:ClearAllPoints()
            bar.rested:SetPoint("TOPLEFT",bar,"TOPLEFT",WIDTH*startFrac,-2)
            bar.rested:SetPoint("BOTTOMLEFT",bar,"BOTTOMLEFT",WIDTH*startFrac,2)
            bar.rested:SetWidth(width)
            bar.rested:Show()
        else
            bar.rested:Hide()
        end
    else
        bar.rested:Hide()
    end

    local disabled=false
    if type(IsXPUserDisabled)=="function" then
        local raw=IsXPUserDisabled()
        disabled=(raw==true or raw==1) and true or false
    end
    local label="XP  "..Number(current).." / "..Number(maximum).."  •  "..string.format("%.1f%%",Percent(current,maximum))
    if disabled then label=label.."  •  XP gain disabled" end
    bar.text:SetText(label)
    bar.current=current; bar.maximum=maximum; bar.restedXP=rested; bar.level=level; bar.xpDisabled=disabled and true or false
    bar:Show()
end

local function StandingLabel(reaction)
    reaction=tonumber(reaction) or 0
    local label=_G["FACTION_STANDING_LABEL"..tostring(reaction)]
    if label and label~="" then return label end
    local fallbacks={"Hated","Hostile","Unfriendly","Neutral","Friendly","Honored","Revered","Exalted"}
    return fallbacks[reaction] or "Unknown"
end

function Bars:RefreshReputation()
    local bar=self.rep
    if not bar then return end
    if not RepEnabled() then bar:Hide(); return end
    if type(GetWatchedFactionInfo)~="function" then bar:Hide(); return end

    local name,reaction,bottom,top,value,factionID=GetWatchedFactionInfo()
    if not name or name=="" then bar:Hide(); return end
    bottom=tonumber(bottom) or 0; top=tonumber(top) or 0; value=tonumber(value) or bottom
    local current=value-bottom
    local maximum=top-bottom
    if maximum<=0 then maximum=1 end
    current=math.max(0,math.min(current,maximum))

    bar:SetMinMaxValues(0,maximum)
    bar:SetValue(current)
    local c=FACTION_BAR_COLORS and FACTION_BAR_COLORS[tonumber(reaction) or 0]
    if c then bar:SetStatusBarColor(c.r or 0.8,c.g or 0.8,c.b or 0.8,0.95)
    else local ar,ag,ab=RUI:GetAccentColor(); bar:SetStatusBarColor(ar,ag,ab,0.95) end

    local standing=StandingLabel(reaction)
    bar.text:SetText(tostring(name).."  •  "..standing.."  •  "..Number(current).." / "..Number(maximum))
    bar.factionName=name; bar.reaction=reaction; bar.bottom=bottom; bar.top=top; bar.value=value; bar.current=current; bar.maximum=maximum; bar.factionID=factionID
    bar:Show()
end

function Bars:ShowTooltip(bar)
    if not GameTooltip or not bar then return end
    GameTooltip:SetOwner(bar,"ANCHOR_TOP")
    if bar.kind=="xp" then
        local current=tonumber(bar.current) or 0
        local maximum=tonumber(bar.maximum) or 0
        local rested=tonumber(bar.restedXP) or 0
        GameTooltip:SetText("Experience",1,1,1)
        GameTooltip:AddDoubleLine("Level",tostring(bar.level or UnitLevel("player") or ""),0.75,0.75,0.75,1,1,1)
        GameTooltip:AddDoubleLine("Progress",Number(current).." / "..Number(maximum),0.75,0.75,0.75,1,1,1)
        GameTooltip:AddDoubleLine("Remaining",Number(math.max(0,maximum-current)),0.75,0.75,0.75,1,1,1)
        if rested>0 then
            GameTooltip:AddDoubleLine("Rested bonus remaining",Number(rested),0.55,0.75,1,0.55,0.75,1)
            GameTooltip:AddLine(string.format("Rested bonus covers %.1f%% of this level.",Percent(rested,maximum)),0.65,0.75,0.9,true)
        end
        if bar.xpDisabled then GameTooltip:AddLine("Experience gain is currently disabled.",1,0.45,0.35,true) end
    elseif bar.kind=="rep" then
        GameTooltip:SetText(bar.factionName or "Reputation",1,1,1)
        GameTooltip:AddDoubleLine("Standing",StandingLabel(bar.reaction),0.75,0.75,0.75,1,1,1)
        GameTooltip:AddDoubleLine("Progress",Number(bar.current).." / "..Number(bar.maximum),0.75,0.75,0.75,1,1,1)
        GameTooltip:AddDoubleLine("Remaining",Number(math.max(0,(tonumber(bar.maximum) or 0)-(tonumber(bar.current) or 0))),0.75,0.75,0.75,1,1,1)
        GameTooltip:AddLine("Choose a tracked faction from Zen Character → Reputation.",0.65,0.75,0.9,true)
    end
    GameTooltip:Show()
end

function Bars:Refresh()
    self:RefreshXP()
    self:RefreshReputation()
    self:SuppressStockBars()
end

function Bars:ShouldSuppress(name)
    if name=="ReputationWatchBar" then return RepEnabled() end
    if name=="MainMenuExpBar" or name=="MainMenuBarMaxLevelBar" or name=="ExhaustionTick" then return XPEnabled() end
    return false
end

function Bars:HookStockFrame(name)
    local frame=_G[name]
    if not frame or frame.RUIStatusBarsHooked or not frame.HookScript then return end
    frame.RUIStatusBarsHooked=true
    frame:HookScript("OnShow",function(self)
        if Bars:ShouldSuppress(name) then self:Hide() end
    end)
end

function Bars:SuppressStockBars()
    local names={"MainMenuExpBar","MainMenuBarMaxLevelBar","ExhaustionTick","ReputationWatchBar"}
    for i=1,#names do
        local name=names[i]
        self:HookStockFrame(name)
        local frame=_G[name]
        if frame and self:ShouldSuppress(name) and frame.Hide then frame:Hide() end
    end
end

function Bars:RestoreStockBars()
    if not XPEnabled() and type(MainMenuBar_UpdateExperienceBars)=="function" then pcall(MainMenuBar_UpdateExperienceBars) end
    if not RepEnabled() and type(ReputationWatchBar_Update)=="function" then pcall(ReputationWatchBar_Update) end
end

function Bars:ApplySettings()
    if not self.xp or not self.rep then return end
    RUI:SetMoverEnabled(XP_MOVER,XPEnabled())
    RUI:SetMoverEnabled(REP_MOVER,RepEnabled())
    self:ApplyScale()
    self:Refresh()
    self:RestoreStockBars()
end

function Bars:OnAppearance()
    if not self.xp then return end
    RUI:RefreshBackdrop(self.xp); RUI:RefreshBackdrop(self.rep)
    self:ApplyScale(); self:Refresh()
end

function Bars:OnScaleChanged(key)
    if key=="all" or key==SCALE_KEY then self:ApplyScale() end
end

function Bars:OnEvent(event,...)
    if event=="ADDON_LOADED" then self:SuppressStockBars(); return end
    self:Refresh()
end

function Bars:OnInitialize()
    self:CreateFrames(); self:RegisterMovers(); self:SuppressStockBars(); self:Refresh()
    RUI:RegisterCallback("APPEARANCE_CHANGED",self,"OnAppearance")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED",self,"OnScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET",self,"ApplySettings")
end

function Bars:OnEnable()
    local events={"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_XP_UPDATE","UPDATE_EXHAUSTION","PLAYER_LEVEL_UP","UPDATE_FACTION","PLAYER_UPDATE_RESTING"}
    for i=1,#events do self:RegisterEvent(events[i],"OnEvent") end
    self:ApplySettings()
end
