-- ZenUI 0.9.47 Phase C Achievements / Statistics replacement.
-- Zen owns the visible browser while Wrath's native achievement APIs remain
-- authoritative for completion, criteria, tracking, points and statistics.

local RUI = ZenUI
local Ach = RUI:NewModule("BlizzardPhaseCAchievements")

local WIDTH, HEIGHT = 820, 650
local MOVER = "ZenAchievements"
local SCALE_KEY = "zenAchievements"
local CATEGORY_ROWS = 13
local ACHIEVEMENT_ROWS = 3
local STAT_ROWS = 12
local DETAIL_CRITERIA_ROWS = 11

local function Settings()
    if not RUI.db then return nil end
    RUI.db.blizzard = RUI.db.blizzard or {}
    return RUI.db.blizzard
end

local function Enabled()
    local s=Settings()
    if not s or s.enabled==false then return false end
    if s.achievements==nil then return true end
    return s.achievements and true or false
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
    b.RUIText:SetPoint("CENTER"); b.RUIText:SetText(label or "Button")
    RUI:StyleButton(b)
    return b
end

local function Edit(parent,width,height,placeholder)
    local e=CreateFrame("EditBox",nil,parent)
    e:SetWidth(width or 220); e:SetHeight(height or 24)
    e:SetAutoFocus(false); e:SetFont(RUI:GetFontPath(),11)
    e:SetTextInsets(8,8,4,4)
    RUI:CreateBackdrop(e)
    e.placeholder=Text(e,placeholder or "",9,"LEFT",e,"LEFT",8,0,true)
    e:SetScript("OnEditFocusGained",function(self) self.placeholder:Hide() end)
    e:SetScript("OnEditFocusLost",function(self) if self:GetText()=="" then self.placeholder:Show() end end)
    e:SetScript("OnTextChanged",function(self)
        if self:GetText()=="" and not self:HasFocus() then self.placeholder:Show() else self.placeholder:Hide() end
        if self.RUIOnTextChanged then self:RUIOnTextChanged() end
    end)
    return e
end

local function AddSpecial(frame)
    if not frame or not frame.GetName or not frame:GetName() then return end
    UISpecialFrames=UISpecialFrames or {}
    for i=1,#UISpecialFrames do if UISpecialFrames[i]==frame:GetName() then return end end
    table.insert(UISpecialFrames,frame:GetName())
end

local function SafeCall(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c,d,e,f,g,h,i,j,k,l=pcall(fn,...)
    if not ok then return nil end
    return a,b,c,d,e,f,g,h,i,j,k,l
end

local function CriteriaIsComplete(value)
    -- Most Wrath clients return a boolean here, but custom 3.3.5 forks may
    -- expose 0/1 instead. Lua treats numeric 0 as truthy, so normalize it.
    if value==true then return true end
    if type(value)=="number" then return value~=0 end
    if type(value)=="string" then
        local lower=string.lower(value)
        return lower=="1" or lower=="true" or lower=="yes"
    end
    return false
end

local function FormatNumber(value)
    value=tonumber(value) or 0
    if BreakUpLargeNumbers then
        local ok,text=pcall(BreakUpLargeNumbers,value)
        if ok and text then return text end
    end
    return tostring(value)
end

local function AchievementDate(month,day,year)
    month=tonumber(month); day=tonumber(day); year=tonumber(year)
    if not month or not day or month<=0 or day<=0 then return nil end
    if year and year>0 then
        if year<100 then year=2000+year end
        return string.format("%02d/%02d/%04d",day,month,year)
    end
    return string.format("%02d/%02d",day,month)
end

local function CategoryTotal(id)
    if type(GetCategoryNumAchievements)~="function" then return 0,0 end
    local total,completed=SafeCall(GetCategoryNumAchievements,id)
    return tonumber(total) or 0,tonumber(completed) or 0
end

local function IsAchievementTracked(id)
    if type(GetTrackedAchievements)~="function" then return false end
    local values={SafeCall(GetTrackedAchievements)}
    if #values==1 and type(values[1])=="table" then values=values[1] end
    for _,value in pairs(values) do if tonumber(value)==tonumber(id) then return true end end
    return false
end

local function ToggleAchievementTracked(id)
    if not id then return end
    if IsAchievementTracked(id) then
        if RemoveTrackedAchievement then pcall(RemoveTrackedAchievement,id) end
    else
        if AddTrackedAchievement then pcall(AddTrackedAchievement,id) end
    end
end

local function GetAchievementRecord(category,indexOrID,byID)
    if type(GetAchievementInfo)~="function" then return nil end
    local id,name,points,completed,month,day,year,description,flags,icon,rewardText
    if byID then
        id,name,points,completed,month,day,year,description,flags,icon,rewardText=SafeCall(GetAchievementInfo,indexOrID)
    else
        id,name,points,completed,month,day,year,description,flags,icon,rewardText=SafeCall(GetAchievementInfo,category,indexOrID)
    end
    id=tonumber(id)
    if not id then return nil end
    return {id=id,name=name or ("Achievement "..id),points=tonumber(points) or 0,completed=CriteriaIsComplete(completed),month=month,day=day,year=year,description=description or "",flags=flags,icon=icon,rewardText=rewardText or ""}
end

local function GetAchievementCriteriaLines(id,maxLines)
    local out={}
    if type(GetAchievementNumCriteria)~="function" or type(GetAchievementCriteriaInfo)~="function" then return out end
    local count=tonumber(SafeCall(GetAchievementNumCriteria,id)) or 0
    for i=1,count do
        local desc,criteriaType,completed,quantity,reqQuantity,charName,flags,assetID,quantityString,criteriaID=SafeCall(GetAchievementCriteriaInfo,id,i)
        if desc then
            local text=tostring(desc)
            local q=tonumber(quantity); local req=tonumber(reqQuantity)
            -- Boolean/list criteria often expose quantityString="0" even when
            -- completion is tracked by the separate completed flag. Do not show
            -- that meaningless zero next to raid/zone/etc. criteria. Only show
            -- quantities when this criterion has a real numeric target.
            if req and req>1 and q then
                local qs=quantityString and tostring(quantityString) or ""
                if qs~="" and qs~="0" then text=text.."  "..qs
                else text=text.."  "..tostring(q).."/"..tostring(req) end
            end
            out[#out+1]={
                text=text,
                rawText=tostring(desc),
                completed=CriteriaIsComplete(completed),
                quantity=q,
                required=req,
                quantityString=quantityString,
                criteriaType=tonumber(criteriaType),
                assetID=tonumber(assetID),
                criteriaID=tonumber(criteriaID),
                parentAchievementID=tonumber(id),
            }
            if maxLines and #out>=maxLines then break end
        end
    end
    return out,count
end

local COMPLETE_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"

local function FormatCriteriaLine(row)
    if not row then return "" end
    local text=tostring(row.text or "")
    if row.completed then
        return COMPLETE_ICON.." |cff66ff66"..text.."|r"
    end
    return "|cffb0b0b0- "..text.."|r"
end

local function GetAchievementProgress(id)
    if type(GetAchievementNumCriteria)~="function" or type(GetAchievementCriteriaInfo)~="function" then return nil end
    local count=tonumber(SafeCall(GetAchievementNumCriteria,id)) or 0
    if count<=0 then return nil end
    local completedCount=0
    local firstNumeric=nil
    for i=1,count do
        local desc,criteriaType,completed,quantity,reqQuantity,charName,flags,assetID,quantityString=SafeCall(GetAchievementCriteriaInfo,id,i)
        if CriteriaIsComplete(completed) then completedCount=completedCount+1 end
        local q=tonumber(quantity); local req=tonumber(reqQuantity)
        if not firstNumeric and q and req and req>1 then
            firstNumeric={current=math.max(0,q),maximum=math.max(1,req),label="Complete",text=tostring(math.max(0,q)).." / "..tostring(math.max(1,req))}
        end
    end
    if firstNumeric then return firstNumeric end
    if count>1 then
        return {current=completedCount,maximum=count,label="Complete",text=tostring(completedCount).." / "..tostring(count)}
    end
    return nil
end

local function NormalizeSearchText(value)
    value=string.lower(tostring(value or ""))
    value=string.gsub(value,"^%s+","")
    value=string.gsub(value,"%s+$","")
    return value
end

local function AchievementMatchesSearch(rec,query)
    if not rec or not query or query=="" then return false end
    local function matches(value)
        value=string.lower(tostring(value or ""))
        return string.find(value,query,1,true) and true or false
    end
    if matches(rec.name) or matches(rec.description) or matches(rec.rewardText) then return true end
    local criteria=GetAchievementCriteriaLines(rec.id,nil)
    for i=1,#criteria do
        local row=criteria[i]
        if matches(row.rawText) or matches(row.text) then return true end
    end
    return false
end

local function CriteriaLinkedAchievementID(row)
    if not row then return nil end
    -- Wrath criteria type 8 means "complete another achievement" and assetID
    -- is that child achievement's ID. Validate the record before making a row
    -- clickable so custom Ebonhold criteria cannot accidentally jump elsewhere.
    if tonumber(row.criteriaType)~=8 then return nil end
    local childID=tonumber(row.assetID)
    if not childID or childID<=0 or childID==tonumber(row.parentAchievementID) then return nil end
    local rec=GetAchievementRecord(nil,childID,true)
    if not rec then return nil end
    return childID
end

local function ShowCriterionTooltip(owner,row)
    if not GameTooltip or not owner or not row then return end
    local childID=CriteriaLinkedAchievementID(row)
    if childID then
        local rec=GetAchievementRecord(nil,childID,true)
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
        GameTooltip:SetText(rec and rec.name or tostring(row.rawText or row.text or "Achievement"),1,0.82,0.2)
        if rec and rec.description and rec.description~="" then GameTooltip:AddLine(rec.description,1,1,1,true) end
        GameTooltip:AddLine(" ")
        if rec and rec.completed then
            GameTooltip:AddLine(COMPLETE_ICON.." |cff66ff66Completed|r",1,1,1,true)
        else
            local progress=GetAchievementProgress(childID)
            if progress then GameTooltip:AddLine("Progress: "..tostring(progress.text or ""),0.75,0.85,1,true)
            else GameTooltip:AddLine("Incomplete",0.75,0.75,0.75,true) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: open this achievement",0.65,0.82,1,true)
        GameTooltip:AddLine("Shift-click: link achievement",0.7,0.7,0.7,true)
        GameTooltip:Show()
        return
    end

    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    GameTooltip:SetText(tostring(row.rawText or row.text or "Criterion"),1,0.82,0.2)
    if row.completed then GameTooltip:AddLine(COMPLETE_ICON.." |cff66ff66Completed|r",1,1,1,true)
    else GameTooltip:AddLine("Incomplete",0.75,0.75,0.75,true) end
    local q=tonumber(row.quantity); local req=tonumber(row.required)
    if q and req and req>1 then GameTooltip:AddLine("Progress: "..tostring(q).." / "..tostring(req),0.75,0.85,1,true) end
    GameTooltip:Show()
end

local function ShowAchievementTooltip(owner,id)
    if not GameTooltip or not id then return end
    local rec=GetAchievementRecord(nil,id,true)
    if not rec then return end
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    GameTooltip:SetText(rec.name,1,0.82,0.2)
    if rec.description~="" then GameTooltip:AddLine(rec.description,1,1,1,true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Points",tostring(rec.points),0.7,0.7,0.7,1,0.82,0.2)
    if rec.completed then
        local date=AchievementDate(rec.month,rec.day,rec.year)
        GameTooltip:AddLine(date and ("Completed "..date) or "Completed",0.35,0.9,0.45,true)
    else
        GameTooltip:AddLine("Incomplete",0.75,0.75,0.75,true)
    end
    local criteria,total=GetAchievementCriteriaLines(id,8)
    if total and total>0 then
        GameTooltip:AddLine(" ")
        for i=1,#criteria do
            local row=criteria[i]
            GameTooltip:AddLine(FormatCriteriaLine(row),1,1,1,true)
        end
        if total>#criteria then
            GameTooltip:AddLine("...and "..tostring(total-#criteria).." more",0.6,0.6,0.6,true)
            GameTooltip:AddLine("Left-click: view all "..tostring(total).." criteria",0.65,0.82,1,true)
        end
    end
    if rec.rewardText~="" then GameTooltip:AddLine(" "); GameTooltip:AddLine("Reward: "..rec.rewardText,0.55,0.8,1,true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(IsAchievementTracked(id) and "Right-click: stop tracking" or "Right-click: track achievement",0.7,0.7,0.7,true)
    GameTooltip:AddLine("Left-click: view achievement details",0.7,0.7,0.7,true)
    GameTooltip:AddLine("Shift-click: link achievement",0.7,0.7,0.7,true)
    GameTooltip:Show()
end

local function CreateCategoryRow(parent,index)
    local b=Button(parent,"",196,32); b.index=index
    b.toggle=Button(b,"",18,18); b.toggle:SetPoint("LEFT",b,"LEFT",6,0); b.toggle:SetFrameLevel((b:GetFrameLevel() or 1)+2); b.toggle:Hide()
    b.toggle.RUIText:SetText("-")
    local tr,tg,tb=RUI:GetTextColor(false)
    RUI:StyleFontString(b.toggle.RUIText,10,tr,tg,tb)
    b.toggle:SetScript("OnClick",function(self)
        local row=self:GetParent()
        if row and row.categoryID~=nil then Ach:ToggleCategory(row.categoryID) end
    end)
    b.RUIText:ClearAllPoints(); b.RUIText:SetPoint("LEFT",b,"LEFT",10,0); b.RUIText:SetWidth(140); b.RUIText:SetJustifyH("LEFT")
    RUI:StyleFontString(b.RUIText,11,tr,tg,tb)
    b.count=Text(b,"",10,"RIGHT",b,"RIGHT",-7,0,true); b.count:SetJustifyH("RIGHT")
    b:SetScript("OnClick",function(self)
        if self.categoryID~=nil then Ach:SelectCategory(self.categoryID) end
    end)
    return b
end

local function CreateAchievementRow(parent,index)
    local b=CreateFrame("Button",nil,parent); b:SetWidth(558); b:SetHeight(148); b.index=index
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    RUI:CreateBackdrop(b)
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetWidth(64); b.icon:SetHeight(64); b.icon:SetPoint("TOPLEFT",b,"TOPLEFT",12,-14); b.icon:SetTexCoord(0.07,0.93,0.07,0.93)
    b.name=Text(b,"",14,"TOPLEFT",b,"TOPLEFT",88,-12,false); b.name:SetWidth(352); b.name:SetJustifyH("LEFT")
    b.points=Text(b,"",11,"TOPRIGHT",b,"TOPRIGHT",-12,-13,false); b.points:SetJustifyH("RIGHT")
    b.desc=Text(b,"",12,"TOPLEFT",b,"TOPLEFT",88,-39,true); b.desc:SetWidth(452); b.desc:SetHeight(38); b.desc:SetJustifyH("LEFT"); b.desc:SetJustifyV("TOP")
    -- Rewards have their own high-contrast line so titles/items/mounts are
    -- visible without hovering the achievement card.
    b.reward=Text(b,"",11,"TOPLEFT",b,"TOPLEFT",88,-82,false); b.reward:SetWidth(440); b.reward:SetJustifyH("LEFT")
    b.criteria=Text(b,"",11,"TOPLEFT",b,"TOPLEFT",88,-104,true); b.criteria:SetWidth(440); b.criteria:SetJustifyH("LEFT")
    b.state=Text(b,"",10,"TOPRIGHT",b,"TOPRIGHT",-12,-34,true); b.state:SetJustifyH("RIGHT")
    b.progress=CreateFrame("StatusBar",nil,b); b.progress:SetWidth(452); b.progress:SetHeight(16); b.progress:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",88,11); RUI:CreateBackdrop(b.progress)
    b.progress:SetStatusBarTexture((RUI.Media and RUI.Media.textures and RUI.Media.textures.white) or "Interface\\Buttons\\WHITE8X8")
    b.progressBg=b.progress:CreateTexture(nil,"BACKGROUND"); b.progressBg:SetAllPoints(b.progress); b.progressBg:SetTexture((RUI.Media and RUI.Media.textures and RUI.Media.textures.white) or "Interface\\Buttons\\WHITE8X8"); b.progressBg:SetVertexColor(0.08,0.08,0.08,0.9)
    b.progressText=Text(b.progress,"",11,"CENTER",b.progress,"CENTER",0,0,false); b.progressText:SetJustifyH("CENTER")
    b.progress:Hide()
    b:SetScript("OnEnter",function(self) if self.achievementID then ShowAchievementTooltip(self,self.achievementID) end end)
    b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnClick",function(self,mouseButton)
        local id=self.achievementID; if not id then return end
        if mouseButton=="RightButton" then ToggleAchievementTracked(id); Ach:RefreshAchievements(); return end
        local link=GetAchievementLink and GetAchievementLink(id)
        if link and HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
        Ach:ShowAchievementDetails(id)
    end)
    return b
end

function Ach:BuildCategoryList(statistics)
    local source
    if statistics and type(GetStatisticsCategoryList)=="function" then source=SafeCall(GetStatisticsCategoryList)
    elseif not statistics and type(GetCategoryList)=="function" then source=SafeCall(GetCategoryList) end
    if type(source)~="table" then source={} end
    local list={}
    if not statistics then list[#list+1]={id="summary",name="Summary",parent=nil,hasChildren=false} end
    local info={}
    for i=1,#source do
        local id=tonumber(source[i])
        if id then
            local name,parent=SafeCall(GetCategoryInfo,id)
            if name then info[id]={id=id,name=name,parent=tonumber(parent),hasChildren=false} end
        end
    end
    for _,data in pairs(info) do
        if data.parent and data.parent~=-1 and info[data.parent] then info[data.parent].hasChildren=true end
    end
    -- Wrath categories are one level deep: a parent followed by its children.
    -- Keep the full ordered tree here; RefreshCategoryVisibility filters out
    -- children when their parent is collapsed.
    for i=1,#source do
        local id=tonumber(source[i]); local data=id and info[id]
        if data and (not data.parent or data.parent==-1) then
            list[#list+1]=data
            for j=1,#source do
                local childID=tonumber(source[j]); local child=childID and info[childID]
                if child and child.parent==id then list[#list+1]=child end
            end
        end
    end
    return list
end

function Ach:GetCollapsedStore()
    self.collapsedCategories=self.collapsedCategories or {achievements={},statistics={}}
    local key=self.page=="statistics" and "statistics" or "achievements"
    self.collapsedCategories[key]=self.collapsedCategories[key] or {}
    return self.collapsedCategories[key]
end

function Ach:ApplyDefaultCollapsedCategories()
    local key=self.page=="statistics" and "statistics" or "achievements"
    self.collapsedDefaultsApplied=self.collapsedDefaultsApplied or {}
    if self.collapsedDefaultsApplied[key] then return end
    local collapsed=self:GetCollapsedStore()
    for i=1,#(self.categoryTreeList or {}) do
        local data=self.categoryTreeList[i]
        if data.hasChildren then collapsed[data.id]=true end
    end
    self.collapsedDefaultsApplied[key]=true
end

function Ach:RefreshCategoryVisibility()
    local full=self.categoryTreeList or {}
    local collapsed=self:GetCollapsedStore()
    local visible={}
    for i=1,#full do
        local data=full[i]
        if not data.parent or data.parent==-1 or not collapsed[data.parent] then visible[#visible+1]=data end
    end
    self.categoriesList=visible
    local max=math.max(0,#visible-CATEGORY_ROWS)
    self.categoryOffset=math.max(0,math.min(max,tonumber(self.categoryOffset) or 0))
end

function Ach:ToggleCategory(id)
    id=tonumber(id)
    if not id then return end
    local data
    for i=1,#(self.categoryTreeList or {}) do
        if self.categoryTreeList[i].id==id then data=self.categoryTreeList[i]; break end
    end
    if not data or not data.hasChildren then return end
    local collapsed=self:GetCollapsedStore()
    collapsed[id]=not collapsed[id]
    if collapsed[id] then
        for i=1,#(self.categoryTreeList or {}) do
            local child=self.categoryTreeList[i]
            if child.id==self.selectedCategory and child.parent==id then
                self.selectedCategory=id
                if self.page=="statistics" then self.selectedStatCategory=id else self.selectedAchievementCategory=id end
                self.achievementOffset=0; self.statisticOffset=0
                break
            end
        end
    end
    self:RefreshCategoryVisibility()
    self:Refresh()
end

function Ach:ToggleAllCategories()
    local collapsed=self:GetCollapsedStore()
    local anyExpanded=false
    for i=1,#(self.categoryTreeList or {}) do
        local data=self.categoryTreeList[i]
        if data.hasChildren and not collapsed[data.id] then anyExpanded=true; break end
    end
    for i=1,#(self.categoryTreeList or {}) do
        local data=self.categoryTreeList[i]
        if data.hasChildren then collapsed[data.id]=anyExpanded and true or nil end
    end
    if anyExpanded then
        for i=1,#(self.categoryTreeList or {}) do
            local data=self.categoryTreeList[i]
            if data.id==self.selectedCategory and data.parent and data.parent~=-1 then
                self.selectedCategory=data.parent
                if self.page=="statistics" then self.selectedStatCategory=data.parent else self.selectedAchievementCategory=data.parent end
                self.achievementOffset=0; self.statisticOffset=0
                break
            end
        end
    end
    self.categoryOffset=0
    self:RefreshCategoryVisibility()
    self:Refresh()
end

function Ach:CreateFrame()
    local f=CreateFrame("Frame","ZenUIAchievementsFrame",UIParent)
    self.frame=f
    f:SetWidth(WIDTH); f:SetHeight(HEIGHT); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true); f:Hide()
    RUI:CreateBackdrop(f); f.accent=RUI:CreateAccentLine(f,2)
    f.title=Text(f,"Achievements",15,"TOPLEFT",f,"TOPLEFT",16,-17,false)
    f.subtitle=Text(f,"Progress, criteria and character statistics",8,"LEFT",f.title,"RIGHT",10,-1,true)
    f.points=Text(f,"0 points",10,"TOPRIGHT",f,"TOPRIGHT",-54,-19,false); f.points:SetJustifyH("RIGHT")
    f.close=Button(f,"X",28,24); f.close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-10,-10); f.close:SetScript("OnClick",function() f:Hide() end)
    AddSpecial(f); if RUI.RegisterExclusivePanel then RUI:RegisterExclusivePanel(f) end

    f.tabs={}
    for i,def in ipairs({{"achievements","Achievements"},{"statistics","Statistics"}}) do
        local b=Button(f,def[2],150,28); b:SetPoint("TOPLEFT",f,"TOPLEFT",16+((i-1)*158),-48); b.page=def[1]
        b:SetScript("OnClick",function(self) Ach:SetPage(self.page) end); f.tabs[def[1]]=b
    end

    -- Global achievement search. It searches names, descriptions, rewards and
    -- criterion text across every achievement category rather than only the
    -- currently selected branch.
    f.search=Edit(f,286,28,"Search achievements...")
    f.search:SetPoint("TOPRIGHT",f,"TOPRIGHT",-56,-48)
    f.search:SetMaxLetters(80)
    f.search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    f.search:SetScript("OnEscapePressed",function(self)
        if self:GetText()~="" then self:SetText("") else self:ClearFocus() end
    end)
    f.search.RUIOnTextChanged=function(self) Ach:SetSearchQuery(self:GetText()) end

    f.categories=CreateFrame("Frame",nil,f); f.categories:SetWidth(216); f.categories:SetPoint("TOPLEFT",f,"TOPLEFT",14,-86); f.categories:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",14,14); RUI:CreateBackdrop(f.categories)
    f.categoryTitle=Text(f.categories,"CATEGORIES",10,"TOPLEFT",f.categories,"TOPLEFT",10,-10,true)
    f.categoryRows={}
    for i=1,CATEGORY_ROWS do
        local b=CreateCategoryRow(f.categories,i); b:SetPoint("TOPLEFT",f.categories,"TOPLEFT",10,-34-((i-1)*34)); f.categoryRows[i]=b
    end
    -- Reserve a real footer for navigation so the last category row can never
    -- overlap the buttons. Parent categories can also be collapsed individually
    -- (the +/- control on each row) or all at once here.
    f.catUp=Button(f.categories,"^",28,22); f.catUp:SetPoint("BOTTOMLEFT",f.categories,"BOTTOMLEFT",10,9)
    f.catDown=Button(f.categories,"v",28,22); f.catDown:SetPoint("LEFT",f.catUp,"RIGHT",5,0)
    f.catCollapse=Button(f.categories,"Collapse All",92,22); f.catCollapse:SetPoint("BOTTOMRIGHT",f.categories,"BOTTOMRIGHT",-10,9)
    f.catUp:SetScript("OnClick",function() Ach:SetCategoryOffset((Ach.categoryOffset or 0)-1) end)
    f.catDown:SetScript("OnClick",function() Ach:SetCategoryOffset((Ach.categoryOffset or 0)+1) end)
    f.catCollapse:SetScript("OnClick",function() Ach:ToggleAllCategories() end)
    f.categories:EnableMouseWheel(true); f.categories:SetScript("OnMouseWheel",function(_,delta) Ach:SetCategoryOffset((Ach.categoryOffset or 0)-delta) end)

    f.content=CreateFrame("Frame",nil,f); f.content:SetPoint("TOPLEFT",f,"TOPLEFT",240,-86); f.content:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-14,14)

    f.summary=CreateFrame("Frame",nil,f.content); f.summary:SetAllPoints(f.content); f.summary:Hide()
    f.summaryTitle=Text(f.summary,"Achievement Summary",16,"TOPLEFT",f.summary,"TOPLEFT",4,-2,false)
    f.summarySub=Text(f.summary,"",9,"TOPLEFT",f.summary,"TOPLEFT",4,-29,true)
    f.summaryCards={}
    local cardDefs={{"TOTAL POINTS",4},{"COMPLETED",186},{"TRACKED",368}}
    for i,def in ipairs(cardDefs) do
        local c=CreateFrame("Frame",nil,f.summary); c:SetWidth(174); c:SetHeight(82); c:SetPoint("TOPLEFT",f.summary,"TOPLEFT",def[2],-55); RUI:CreateBackdrop(c)
        c.label=Text(c,def[1],8,"TOPLEFT",c,"TOPLEFT",10,-10,true); c.value=Text(c,"0",22,"TOPLEFT",c,"TOPLEFT",10,-31,false); f.summaryCards[i]=c
    end
    f.recentLabel=Text(f.summary,"RECENTLY COMPLETED",9,"TOPLEFT",f.summary,"TOPLEFT",4,-156,true)
    f.recent={}
    for i=1,5 do
        local row=CreateFrame("Button",nil,f.summary); row:SetWidth(544); row:SetHeight(68); row:SetPoint("TOPLEFT",f.summary,"TOPLEFT",4,-176-((i-1)*72)); row:RegisterForClicks("LeftButtonUp","RightButtonUp"); RUI:CreateBackdrop(row)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetWidth(38); row.icon:SetHeight(38); row.icon:SetPoint("LEFT",row,"LEFT",9,0); row.icon:SetTexCoord(0.07,0.93,0.07,0.93)
        row.name=Text(row,"",11,"TOPLEFT",row,"TOPLEFT",56,-10,false); row.name:SetWidth(365); row.name:SetJustifyH("LEFT")
        row.detail=Text(row,"",9,"BOTTOMLEFT",row,"BOTTOMLEFT",56,10,true); row.detail:SetWidth(400); row.detail:SetJustifyH("LEFT")
        row.points=Text(row,"",10,"RIGHT",row,"RIGHT",-10,0,false); row.points:SetJustifyH("RIGHT")
        row:SetScript("OnEnter",function(self) if self.achievementID then ShowAchievementTooltip(self,self.achievementID) end end)
        row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        row:SetScript("OnClick",function(self,mouseButton)
            if not self.achievementID then return end
            if mouseButton=="RightButton" then ToggleAchievementTracked(self.achievementID); Ach:RefreshSummary(); return end
            local link=GetAchievementLink and GetAchievementLink(self.achievementID)
            if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
        end)
        f.recent[i]=row
    end

    f.achievementList=CreateFrame("Frame",nil,f.content); f.achievementList:SetAllPoints(f.content); f.achievementList:Hide()
    f.listTitle=Text(f.achievementList,"",17,"TOPLEFT",f.achievementList,"TOPLEFT",4,-2,false)
    f.listCount=Text(f.achievementList,"",10,"TOPRIGHT",f.achievementList,"TOPRIGHT",-4,-7,true); f.listCount:SetJustifyH("RIGHT")
    f.achievementRows={}
    for i=1,ACHIEVEMENT_ROWS do
        local row=CreateAchievementRow(f.achievementList,i); row:SetPoint("TOPLEFT",f.achievementList,"TOPLEFT",4,-38-((i-1)*154)); f.achievementRows[i]=row
    end
    f.achUp=Button(f.achievementList,"^",28,22); f.achUp:SetPoint("BOTTOMRIGHT",f.achievementList,"BOTTOMRIGHT",-42,8)
    f.achDown=Button(f.achievementList,"v",28,22); f.achDown:SetPoint("BOTTOMRIGHT",f.achievementList,"BOTTOMRIGHT",-8,8)
    f.achUp:SetScript("OnClick",function() Ach:SetAchievementOffset((Ach.achievementOffset or 0)-1) end)
    f.achDown:SetScript("OnClick",function() Ach:SetAchievementOffset((Ach.achievementOffset or 0)+1) end)
    f.achievementList:EnableMouseWheel(true); f.achievementList:SetScript("OnMouseWheel",function(_,delta) Ach:SetAchievementOffset((Ach.achievementOffset or 0)-delta) end)

    -- Full achievement details viewer. Normal left-click on an achievement card
    -- opens this panel so very large meta-achievements can show every criterion
    -- without relying on an oversized GameTooltip.
    f.details=CreateFrame("Frame",nil,f.content); f.details:SetAllPoints(f.content); f.details:Hide()
    f.detailBack=Button(f.details,"< Back",92,24); f.detailBack:SetPoint("TOPRIGHT",f.details,"TOPRIGHT",-4,-2); f.detailBack:SetScript("OnClick",function() Ach:CloseAchievementDetails() end)
    f.detailIcon=f.details:CreateTexture(nil,"ARTWORK"); f.detailIcon:SetWidth(58); f.detailIcon:SetHeight(58); f.detailIcon:SetPoint("TOPLEFT",f.details,"TOPLEFT",4,-4); f.detailIcon:SetTexCoord(0.07,0.93,0.07,0.93)
    f.detailName=Text(f.details,"",16,"TOPLEFT",f.details,"TOPLEFT",74,-5,false); f.detailName:SetWidth(350); f.detailName:SetJustifyH("LEFT")
    f.detailPoints=Text(f.details,"",11,"TOPRIGHT",f.details,"TOPRIGHT",-104,-9,false); f.detailPoints:SetJustifyH("RIGHT")
    f.detailDesc=Text(f.details,"",12,"TOPLEFT",f.details,"TOPLEFT",74,-34,true); f.detailDesc:SetWidth(470); f.detailDesc:SetHeight(42); f.detailDesc:SetJustifyH("LEFT"); f.detailDesc:SetJustifyV("TOP")
    f.detailReward=Text(f.details,"",11,"TOPLEFT",f.details,"TOPLEFT",74,-79,false); f.detailReward:SetWidth(470); f.detailReward:SetJustifyH("LEFT")
    f.detailStatus=Text(f.details,"",10,"TOPLEFT",f.details,"TOPLEFT",74,-101,true); f.detailStatus:SetWidth(470); f.detailStatus:SetJustifyH("LEFT")
    f.detailCriteriaTitle=Text(f.details,"CRITERIA",10,"TOPLEFT",f.details,"TOPLEFT",4,-130,true)
    f.detailCriteriaCount=Text(f.details,"",10,"TOPRIGHT",f.details,"TOPRIGHT",-4,-130,true); f.detailCriteriaCount:SetJustifyH("RIGHT")
    f.detailCriteriaRows={}
    for i=1,DETAIL_CRITERIA_ROWS do
        local row=CreateFrame("Button",nil,f.details); row:SetWidth(548); row:SetHeight(30); row:SetPoint("TOPLEFT",f.details,"TOPLEFT",4,-151-((i-1)*32)); RUI:CreateBackdrop(row)
        row:EnableMouse(true); row:RegisterForClicks("LeftButtonUp","RightButtonUp")
        row.text=Text(row,"",12,"LEFT",row,"LEFT",10,0,false); row.text:SetWidth(526); row.text:SetJustifyH("LEFT")
        row:SetScript("OnEnter",function(self) if self.criteriaData then ShowCriterionTooltip(self,self.criteriaData) end end)
        row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        row:SetScript("OnClick",function(self,mouseButton)
            local data=self.criteriaData; if not data then return end
            local childID=CriteriaLinkedAchievementID(data)
            if not childID then return end
            local link=GetAchievementLink and GetAchievementLink(childID)
            if IsModifiedClick and IsModifiedClick("CHATLINK") and link and HandleModifiedItemClick then
                HandleModifiedItemClick(link); return
            end
            if mouseButton=="LeftButton" then Ach:ShowAchievementDetails(childID,true) end
        end)
        f.detailCriteriaRows[i]=row
    end
    f.detailUp=Button(f.details,"^",28,22); f.detailUp:SetPoint("BOTTOMRIGHT",f.details,"BOTTOMRIGHT",-42,8)
    f.detailDown=Button(f.details,"v",28,22); f.detailDown:SetPoint("BOTTOMRIGHT",f.details,"BOTTOMRIGHT",-8,8)
    f.detailUp:SetScript("OnClick",function() Ach:SetDetailCriteriaOffset((Ach.detailCriteriaOffset or 0)-1) end)
    f.detailDown:SetScript("OnClick",function() Ach:SetDetailCriteriaOffset((Ach.detailCriteriaOffset or 0)+1) end)
    f.details:EnableMouseWheel(true); f.details:SetScript("OnMouseWheel",function(_,delta) Ach:SetDetailCriteriaOffset((Ach.detailCriteriaOffset or 0)-delta) end)

    f.statistics=CreateFrame("Frame",nil,f.content); f.statistics:SetAllPoints(f.content); f.statistics:Hide()
    f.statTitle=Text(f.statistics,"Statistics",17,"TOPLEFT",f.statistics,"TOPLEFT",4,-2,false)
    f.statSub=Text(f.statistics,"Native Wrath character statistics",10,"LEFT",f.statTitle,"RIGHT",10,-1,true)
    f.statRows={}
    for i=1,STAT_ROWS do
        local row=CreateFrame("Frame",nil,f.statistics); row:SetWidth(548); row:SetHeight(36); row:SetPoint("TOPLEFT",f.statistics,"TOPLEFT",4,-38-((i-1)*39)); RUI:CreateBackdrop(row)
        row.name=Text(row,"",11,"LEFT",row,"LEFT",10,0,false); row.name:SetWidth(390); row.name:SetJustifyH("LEFT")
        row.value=Text(row,"",12,"RIGHT",row,"RIGHT",-10,0,false); row.value:SetJustifyH("RIGHT")
        f.statRows[i]=row
    end
    f.statUp=Button(f.statistics,"^",28,22); f.statUp:SetPoint("BOTTOMRIGHT",f.statistics,"BOTTOMRIGHT",-42,8)
    f.statDown=Button(f.statistics,"v",28,22); f.statDown:SetPoint("BOTTOMRIGHT",f.statistics,"BOTTOMRIGHT",-8,8)
    f.statUp:SetScript("OnClick",function() Ach:SetStatisticOffset((Ach.statisticOffset or 0)-1) end)
    f.statDown:SetScript("OnClick",function() Ach:SetStatisticOffset((Ach.statisticOffset or 0)+1) end)
    f.statistics:EnableMouseWheel(true); f.statistics:SetScript("OnMouseWheel",function(_,delta) Ach:SetStatisticOffset((Ach.statisticOffset or 0)-delta) end)

    f:SetAttribute("ZenAchievementPage","achievements")
    f:SetScript("OnAttributeChanged",function(self,name,value)
        if name=="ZenAchievementPage" and value and value~=Ach.page then Ach:SetPage(value) end
    end)
    f:SetScript("OnShow",function()
        if RUI.ActivateExclusivePanel then RUI:ActivateExclusivePanel(f) end
        local requested=f.GetAttribute and f:GetAttribute("ZenAchievementPage") or nil
        if requested and requested~=Ach.page then Ach:SetPage(requested) end
        Ach:Refresh()
        if UpdateMicroButtons then pcall(UpdateMicroButtons) end
    end)
    f:SetScript("OnHide",function() if GameTooltip then GameTooltip:Hide() end; if UpdateMicroButtons then pcall(UpdateMicroButtons) end end)
    self:SetPage("achievements")
end

function Ach:SetPage(page)
    if not self.frame then return end
    if page~="statistics" then page="achievements" end
    self.page=page; self.categoryOffset=0; self.achievementOffset=0; self.statisticOffset=0; self.detailAchievementID=nil; self.detailCriteriaOffset=0; self.detailHistory={}
    for key,b in pairs(self.frame.tabs) do
        if key==page then local r,g,bl=RUI:GetAccentColor(); RUI:SetBorderColor(b,r,g,bl,1) else RUI:RefreshBackdrop(b) end
    end
    if self.frame.search then
        if page=="achievements" then self.frame.search:Show() else self.frame.search:Hide() end
    end
    self.categoryTreeList=self:BuildCategoryList(page=="statistics")
    self:ApplyDefaultCollapsedCategories()
    self:RefreshCategoryVisibility()
    if page=="statistics" then
        self.selectedCategory=self.selectedStatCategory or (self.categoriesList[1] and self.categoriesList[1].id)
    else
        self.selectedCategory=self.selectedAchievementCategory or "summary"
    end
    self:Refresh()
end

function Ach:SetCategoryOffset(offset)
    local max=math.max(0,#(self.categoriesList or {})-CATEGORY_ROWS)
    self.categoryOffset=math.max(0,math.min(max,tonumber(offset) or 0)); self:RefreshCategories()
end

function Ach:SelectCategory(id)
    self.selectedCategory=id; self.achievementOffset=0; self.statisticOffset=0; self.detailAchievementID=nil; self.detailCriteriaOffset=0; self.detailHistory={}
    if self.page=="statistics" then self.selectedStatCategory=id else self.selectedAchievementCategory=id end
    self:Refresh()
end

function Ach:RefreshCategories()
    local f=self.frame; if not f then return end
    local list=self.categoriesList or {}
    local full=self.categoryTreeList or list
    local collapsed=self:GetCollapsedStore()
    local offset=self.categoryOffset or 0
    local anyExpanded=false
    for i=1,#full do
        local d=full[i]
        if d.hasChildren and not collapsed[d.id] then anyExpanded=true; break end
    end
    if f.catCollapse and f.catCollapse.RUIText then f.catCollapse.RUIText:SetText(anyExpanded and "Collapse All" or "Expand All") end
    for i=1,CATEGORY_ROWS do
        local row=f.categoryRows[i]; local data=list[offset+i]
        if data then
            row.categoryID=data.id
            row.RUIText:ClearAllPoints()
            if data.hasChildren then
                row.toggle:Show(); row.toggle.RUIText:SetText(collapsed[data.id] and "+" or "-")
                row.RUIText:SetPoint("LEFT",row,"LEFT",30,0); row.RUIText:SetWidth(120)
            elseif data.parent and data.parent~=-1 then
                row.toggle:Hide(); row.RUIText:SetPoint("LEFT",row,"LEFT",28,0); row.RUIText:SetWidth(122)
            else
                row.toggle:Hide(); row.RUIText:SetPoint("LEFT",row,"LEFT",10,0); row.RUIText:SetWidth(140)
            end
            row.RUIText:SetText((data.parent and data.parent~=-1 and "• " or "")..tostring(data.name or data.id))
            if type(data.id)=="number" then
                local total,completed=CategoryTotal(data.id)
                if data.hasChildren then
                    for _,child in ipairs(full) do
                        if child.parent==data.id then
                            local ct,cc=CategoryTotal(child.id); total=total+ct; completed=completed+cc
                        end
                    end
                end
                row.count:SetText(total>0 and (tostring(completed).."/"..tostring(total)) or "")
            else row.count:SetText("") end
            if data.id==self.selectedCategory then local r,g,b=RUI:GetAccentColor(); RUI:SetBorderColor(row,r,g,b,1) else RUI:RefreshBackdrop(row) end
            row:Show()
        else
            row.categoryID=nil; row.toggle:Hide(); row:Hide()
        end
    end
end

function Ach:RefreshSummary()
    local f=self.frame; if not f then return end
    local total,completed=0,0
    if GetNumCompletedAchievements then total,completed=SafeCall(GetNumCompletedAchievements) end
    total=tonumber(total) or 0; completed=tonumber(completed) or 0
    local points=tonumber(SafeCall(GetTotalAchievementPoints)) or 0
    local tracked=0
    if GetTrackedAchievements then
        local vals={SafeCall(GetTrackedAchievements)}
        if #vals==1 and type(vals[1])=="table" then for _ in pairs(vals[1]) do tracked=tracked+1 end else for i=1,#vals do if tonumber(vals[i]) then tracked=tracked+1 end end end
    end
    f.summaryCards[1].value:SetText(FormatNumber(points))
    f.summaryCards[2].value:SetText(tostring(completed).." / "..tostring(total))
    f.summaryCards[3].value:SetText(tostring(tracked))
    f.summarySub:SetText(total>0 and string.format("%d%% of achievements completed",math.floor((completed/total)*100+0.5)) or "Achievement progress")

    local ids={}
    if GetLatestCompletedAchievements then
        local values={SafeCall(GetLatestCompletedAchievements)}
        if #values==1 and type(values[1])=="table" then values=values[1] end
        for _,v in pairs(values) do if tonumber(v) then ids[#ids+1]=tonumber(v) end end
    end
    for i=1,5 do
        local row=f.recent[i]; local rec=ids[i] and GetAchievementRecord(nil,ids[i],true) or nil
        if rec then
            row.achievementID=rec.id; row.icon:SetTexture(rec.icon or "")
            row.name:SetText(rec.name)
            local date=AchievementDate(rec.month,rec.day,rec.year)
            local detail=date and ("Completed "..date) or "Recently completed"
            if rec.rewardText~="" then detail=detail.."  •  Reward: "..rec.rewardText end
            row.detail:SetText(detail)
            row.points:SetText(tostring(rec.points).." pts"); row:Show()
        else row.achievementID=nil; row:Hide() end
    end
end

function Ach:BuildSearchResults(query)
    query=NormalizeSearchText(query)
    local results={}
    if query=="" then return results end
    local seen={}
    local full=self.categoryTreeList
    -- SetPage(statistics) swaps categoryTreeList, so always build from the
    -- Achievement category source when searching.
    if self.page~="achievements" or type(full)~="table" then full=self:BuildCategoryList(false) end
    for i=1,#full do
        local data=full[i]
        local category=tonumber(data and data.id)
        if category then
            local total=select(1,CategoryTotal(category))
            for index=1,total do
                local rec=GetAchievementRecord(category,index,false)
                if rec and not seen[rec.id] and AchievementMatchesSearch(rec,query) then
                    seen[rec.id]=true
                    rec.searchCategory=category
                    rec.searchCategoryName=data.name
                    results[#results+1]=rec
                end
            end
        end
    end
    table.sort(results,function(a,b)
        if a.completed~=b.completed then return not a.completed end
        return string.lower(tostring(a.name or ""))<string.lower(tostring(b.name or ""))
    end)
    return results
end

function Ach:SetSearchQuery(value)
    local query=NormalizeSearchText(value)
    if query==tostring(self.searchQuery or "") then return end
    self.searchQuery=query
    self.achievementOffset=0
    self.detailAchievementID=nil; self.detailCriteriaOffset=0; self.detailHistory={}
    if query~="" then self.searchResults=self:BuildSearchResults(query) else self.searchResults={} end
    self:Refresh()
end

function Ach:SetAchievementOffset(offset)
    local total=0
    if self.searchQuery and self.searchQuery~="" then total=#(self.searchResults or {})
    elseif type(self.selectedCategory)=="number" then total=select(1,CategoryTotal(self.selectedCategory)) end
    local max=math.max(0,total-ACHIEVEMENT_ROWS)
    self.achievementOffset=math.max(0,math.min(max,tonumber(offset) or 0)); self:RefreshAchievements()
end

function Ach:RefreshAchievements()
    local f=self.frame; if not f then return end
    local cat=self.selectedCategory
    local searching=self.searchQuery and self.searchQuery~=""
    local total,completed=0,0
    if searching then
        self.searchResults=self:BuildSearchResults(self.searchQuery)
        total=#self.searchResults
        f.listTitle:SetText('Search: "'..tostring(self.searchQuery)..'"')
        f.listCount:SetText(tostring(total)..(total==1 and " match" or " matches"))
    else
        if cat=="summary" or type(cat)~="number" then return end
        local name=SafeCall(GetCategoryInfo,cat) or "Achievements"
        total,completed=CategoryTotal(cat)
        f.listTitle:SetText(name); f.listCount:SetText(tostring(completed).." / "..tostring(total).." completed")
    end
    local offset=self.achievementOffset or 0
    local max=math.max(0,total-ACHIEVEMENT_ROWS)
    self.achievementOffset=math.max(0,math.min(max,offset)); offset=self.achievementOffset
    for i=1,ACHIEVEMENT_ROWS do
        local row=f.achievementRows[i]
        local rec=searching and self.searchResults[offset+i] or GetAchievementRecord(cat,offset+i,false)
        if rec then
            row.achievementID=rec.id; row.icon:SetTexture(rec.icon or ""); row.name:SetText(rec.name); row.points:SetText(tostring(rec.points).." pts")
            row.desc:SetText(rec.description)
            if rec.rewardText~="" then
                row.reward:SetText("|cff66ccffREWARD:|r "..rec.rewardText)
                row.reward:Show()
            else
                row.reward:SetText(""); row.reward:Hide()
            end
            local lines,totalCriteria=GetAchievementCriteriaLines(rec.id,1)
            if lines[1] then row.criteria:SetText(FormatCriteriaLine(lines[1])) else row.criteria:SetText("") end
            local progress=GetAchievementProgress(rec.id)
            if progress and progress.maximum and progress.maximum>0 then
                row.progress:SetMinMaxValues(0,progress.maximum)
                row.progress:SetValue(math.min(progress.maximum,progress.current or 0))
                local ar,ag,ab=RUI:GetAccentColor(); row.progress:SetStatusBarColor(ar,ag,ab,0.9)
                row.progressText:SetText((progress.label and progress.label~="" and (progress.label.."   ") or "")..tostring(progress.text or ""))
                row.progress:Show()
            else
                row.progressText:SetText(""); row.progress:Hide()
            end
            if rec.completed then
                row.state:SetText(AchievementDate(rec.month,rec.day,rec.year) or "Complete")
                local r,g,b=RUI:GetAccentColor(); RUI:SetBorderColor(row,r,g,b,0.9)
            elseif IsAchievementTracked(rec.id) then row.state:SetText("TRACKED"); RUI:SetBorderColor(row,0.45,0.72,1,0.9)
            else row.state:SetText(""); RUI:RefreshBackdrop(row) end
            row:SetAlpha(rec.completed and 1 or 0.92); row:Show()
        else
            row.achievementID=nil
            if row.reward then row.reward:SetText(""); row.reward:Hide() end
            if row.progress then row.progressText:SetText(""); row.progress:Hide() end
            row:Hide()
        end
    end
end

function Ach:BuildStatisticEntries(category)
    local out={}
    if type(category)~="number" then return out end
    local total=select(1,CategoryTotal(category))
    for i=1,total do
        local rec=GetAchievementRecord(category,i,false)
        if rec then
            local value=GetStatistic and SafeCall(GetStatistic,rec.id) or nil
            if value~=nil and tostring(value)~="" then out[#out+1]={name=rec.name,value=tostring(value)} end
        end
    end
    return out
end

function Ach:SetStatisticOffset(offset)
    local max=math.max(0,#(self.statEntries or {})-STAT_ROWS)
    self.statisticOffset=math.max(0,math.min(max,tonumber(offset) or 0)); self:RefreshStatistics()
end

function Ach:ShowAchievementDetails(id,pushHistory)
    id=tonumber(id); if not id then return end
    if pushHistory and self.detailAchievementID and tonumber(self.detailAchievementID)~=id then
        self.detailHistory=self.detailHistory or {}
        self.detailHistory[#self.detailHistory+1]={id=self.detailAchievementID,offset=self.detailCriteriaOffset or 0}
    end
    self.detailAchievementID=id; self.detailCriteriaOffset=0
    if GameTooltip then GameTooltip:Hide() end
    self:Refresh()
end

function Ach:CloseAchievementDetails()
    if self.detailHistory and #self.detailHistory>0 then
        local previous=table.remove(self.detailHistory)
        self.detailAchievementID=previous and previous.id or nil
        self.detailCriteriaOffset=previous and previous.offset or 0
    else
        self.detailAchievementID=nil; self.detailCriteriaOffset=0
    end
    if GameTooltip then GameTooltip:Hide() end
    self:Refresh()
end

function Ach:SetDetailCriteriaOffset(offset)
    local total=0
    if self.detailAchievementID and GetAchievementNumCriteria then total=tonumber(SafeCall(GetAchievementNumCriteria,self.detailAchievementID)) or 0 end
    local max=math.max(0,total-DETAIL_CRITERIA_ROWS)
    self.detailCriteriaOffset=math.max(0,math.min(max,tonumber(offset) or 0))
    self:RefreshAchievementDetails()
end

function Ach:RefreshAchievementDetails()
    local f=self.frame; local id=self.detailAchievementID
    if not f or not id then return end
    local rec=GetAchievementRecord(nil,id,true)
    if not rec then self.detailAchievementID=nil; return end
    f.detailIcon:SetTexture(rec.icon or ""); f.detailName:SetText(rec.name); f.detailPoints:SetText(tostring(rec.points).." pts")
    f.detailDesc:SetText(rec.description or "")
    if rec.rewardText~="" then f.detailReward:SetText("|cff66ccffREWARD:|r "..rec.rewardText); f.detailReward:Show() else f.detailReward:SetText(""); f.detailReward:Hide() end
    if rec.completed then
        local date=AchievementDate(rec.month,rec.day,rec.year)
        f.detailStatus:SetText("|cff66ff66Completed"..(date and ("  "..date) or "").."|r")
    elseif IsAchievementTracked(id) then f.detailStatus:SetText("|cff73b7ffTracked|r")
    else f.detailStatus:SetText("Incomplete") end

    local all,total=GetAchievementCriteriaLines(id,nil)
    total=tonumber(total) or #all
    local max=math.max(0,total-DETAIL_CRITERIA_ROWS)
    self.detailCriteriaOffset=math.max(0,math.min(max,tonumber(self.detailCriteriaOffset) or 0))
    local offset=self.detailCriteriaOffset or 0
    for i=1,DETAIL_CRITERIA_ROWS do
        local row=f.detailCriteriaRows[i]; local data=all[offset+i]
        row.criteriaData=data
        if data then
            local childID=CriteriaLinkedAchievementID(data)
            row.text:SetText(FormatCriteriaLine(data)..(childID and "  |cff73b7ff>|r" or ""))
            row:Show()
        else
            row.text:SetText(""); row.criteriaData=nil; row:Hide()
        end
    end
    if total>0 then
        local first=math.min(total,offset+1); local last=math.min(total,offset+DETAIL_CRITERIA_ROWS)
        f.detailCriteriaCount:SetText(tostring(first).." - "..tostring(last).." of "..tostring(total))
    else f.detailCriteriaCount:SetText("No criteria") end
    f.detailUp:SetEnabled(offset>0); f.detailDown:SetEnabled(offset<max)
    f.detailUp:SetAlpha(offset>0 and 1 or 0.35); f.detailDown:SetAlpha(offset<max and 1 or 0.35)
end

function Ach:RefreshStatistics()
    local f=self.frame; if not f then return end
    local cat=self.selectedCategory
    local name=type(cat)=="number" and SafeCall(GetCategoryInfo,cat) or "Statistics"
    f.statTitle:SetText(name or "Statistics")
    self.statEntries=self:BuildStatisticEntries(cat)
    local offset=self.statisticOffset or 0
    for i=1,STAT_ROWS do
        local row=f.statRows[i]; local data=self.statEntries[offset+i]
        if data then row.name:SetText(data.name); row.value:SetText(data.value); row:Show() else row:Hide() end
    end
end

function Ach:Refresh()
    local f=self.frame; if not f or not f:IsShown() then return end
    local points=tonumber(SafeCall(GetTotalAchievementPoints)) or 0; f.points:SetText(FormatNumber(points).." points")
    self:RefreshCategories()
    f.summary:Hide(); f.achievementList:Hide(); f.statistics:Hide(); if f.details then f.details:Hide() end
    if self.page=="statistics" then
        f.statistics:Show(); self:RefreshStatistics()
    elseif self.detailAchievementID then
        f.details:Show(); self:RefreshAchievementDetails()
    elseif self.searchQuery and self.searchQuery~="" then
        f.achievementList:Show(); self:RefreshAchievements()
    elseif self.selectedCategory=="summary" then
        f.summary:Show(); self:RefreshSummary()
    else
        f.achievementList:Show(); self:RefreshAchievements()
    end
end

function Ach:Show(page)
    if not self.frame then return end
    if RUI.ActivateExclusivePanel then RUI:ActivateExclusivePanel(self.frame) end
    if page then self:SetPage(page) end
    self.frame:Show(); self:Refresh()
end

function Ach:Toggle(page)
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide() else self:Show(page) end
end

function Ach:RegisterMover()
    RUI:RegisterMover(MOVER,self.frame,{label="Achievements",width=WIDTH,height=HEIGHT,point="CENTER",relativePoint="CENTER",x=-290,y=10,targetPoint="TOPLEFT",moverPoint="TOPLEFT",enabled=Enabled()})
    self:ApplyScale()
end

function Ach:ApplyScale()
    if not self.frame then return end
    local scale=RUI:GetEffectiveScale(SCALE_KEY); self.frame:SetScale(scale); RUI:UpdateMoverSize(MOVER,WIDTH*scale,HEIGHT*scale)
end

function Ach:HookStock()
    local stock=_G.AchievementFrame
    if not stock or stock.RUIAchievementHook or not stock.HookScript then return end
    stock.RUIAchievementHook=true
    stock:HookScript("OnShow",function(self)
        if not Enabled() or Ach.stockRedirect then return end
        Ach.stockRedirect=true; self:Hide(); Ach.stockRedirect=false; Ach:Show("achievements")
    end)
end

function Ach:InstallCombatMenuBindings()
    if not RUI.RegisterCombatMenuRoute then return end
    RUI:RegisterCombatMenuRoute("Achievements","TOGGLEACHIEVEMENT",function()
        Ach:Toggle("achievements")
    end,Enabled())
    RUI:RegisterCombatMenuRoute("Statistics","TOGGLESTATISTICS",function()
        Ach:Toggle("statistics")
    end,Enabled())
end

function Ach:InstallOverride()
    if not self.ruiToggle then
        self.ruiToggle=function(toggleStatistics,...)
            if Enabled() then Ach:Toggle(toggleStatistics and "statistics" or "achievements"); return end
            if type(Ach.originalToggle)=="function" then return Ach.originalToggle(toggleStatistics,...) end
            if AchievementFrame_LoadUI then pcall(AchievementFrame_LoadUI) end
            if _G.AchievementFrame then if _G.AchievementFrame:IsShown() then _G.AchievementFrame:Hide() else _G.AchievementFrame:Show() end end
        end
    end
    if _G.ToggleAchievementFrame~=self.ruiToggle then
        if type(_G.ToggleAchievementFrame)=="function" and _G.ToggleAchievementFrame~=self.ruiToggle then self.originalToggle=_G.ToggleAchievementFrame end
        _G.ToggleAchievementFrame=self.ruiToggle
    end
    self:HookStock()
end

function Ach:ApplySettings()
    if not self.frame then return end
    RUI:SetMoverEnabled(MOVER,Enabled()); self:ApplyScale()
    if not Enabled() and self.frame:IsShown() then self.frame:Hide() end
    self:InstallCombatMenuBindings()
end

function Ach:OnAppearance()
    if not self.frame then return end
    RUI:RefreshBackdrop(self.frame); RUI:SetAccentTexture(self.frame.accent); self:ApplyScale(); if self.frame:IsShown() then self:Refresh() end
end

function Ach:OnScaleChanged(key)
    if key=="all" or key==SCALE_KEY then self:ApplyScale() end
end

function Ach:OnEvent(event,...)
    if event=="UPDATE_BINDINGS" or event=="PLAYER_REGEN_ENABLED" then self:InstallCombatMenuBindings(); return end
    if event=="PLAYER_ENTERING_WORLD" or event=="ADDON_LOADED" then self:InstallOverride(); self:HookStock(); self:ApplySettings() end
    if self.frame and self.frame:IsShown() and (event=="ACHIEVEMENT_EARNED" or event=="CRITERIA_UPDATE" or event=="TRACKED_ACHIEVEMENT_LIST_CHANGED") then self:Refresh() end
end

function Ach:OnInitialize()
    self.page="achievements"; self.searchQuery=""; self.searchResults={}; self.categoryTreeList=self:BuildCategoryList(false); self:ApplyDefaultCollapsedCategories(); self:RefreshCategoryVisibility(); self.selectedAchievementCategory="summary"; self.categoryOffset=0; self.achievementOffset=0; self.statisticOffset=0
    self:CreateFrame(); self:RegisterMover(); self:InstallOverride(); self:HookStock(); self:InstallCombatMenuBindings()
    RUI:RegisterCallback("APPEARANCE_CHANGED",self,"OnAppearance")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED",self,"OnScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET",self,"ApplySettings")
end

function Ach:OnEnable()
    local events={"ADDON_LOADED","PLAYER_ENTERING_WORLD","UPDATE_BINDINGS","PLAYER_REGEN_ENABLED","ACHIEVEMENT_EARNED","CRITERIA_UPDATE","TRACKED_ACHIEVEMENT_LIST_CHANGED"}
    for i=1,#events do self:RegisterEvent(events[i],"OnEvent") end
    self:ApplySettings()
end
