-- ZenUI 0.9.111 micro menu, progression shortcuts and bag launcher.
-- Uses the original Wrath UI toggle functions while presenting a compact Zen shell.

local RUI = ZenUI
local MicroMenu = RUI:NewModule("MicroMenu")

-- Expose real WoW binding names for each Project Ebonhold Character
-- Progression page. These bindings are saved by Blizzard's normal binding
-- system, so they persist independently of Zen profiles and can also be
-- edited from the stock Key Bindings window.
BINDING_HEADER_ZENUI = BINDING_HEADER_ZENUI or "ZenUI"
BINDING_NAME_ZEN_PROGRESSION_MAIN = "Character Progression: Open / Close"
BINDING_NAME_ZEN_PROGRESSION_ECHOES = "Character Progression: Echoes"
BINDING_NAME_ZEN_PROGRESSION_SKILLTREE = "Character Progression: Skill Tree"
BINDING_NAME_ZEN_PROGRESSION_TRANSMOGRIFY = "Character Progression: Transmogrify"
BINDING_NAME_ZEN_PROGRESSION_MOUNTS = "Character Progression: Mounts"
BINDING_NAME_ZEN_PROGRESSION_COMPANIONS = "Character Progression: Companions"
BINDING_NAME_ZEN_PROGRESSION_PRESTIGE = "Character Progression: Prestige"

local PROGRESSION_BINDINGS = {
    { command = "ZEN_PROGRESSION_MAIN", label = "Progression" },
    { command = "ZEN_PROGRESSION_ECHOES", label = "Echoes" },
    { command = "ZEN_PROGRESSION_SKILLTREE", label = "Skill Tree" },
    { command = "ZEN_PROGRESSION_TRANSMOGRIFY", label = "Transmogrify" },
    { command = "ZEN_PROGRESSION_MOUNTS", label = "Mounts" },
    { command = "ZEN_PROGRESSION_COMPANIONS", label = "Companions" },
    { command = "ZEN_PROGRESSION_PRESTIGE", label = "Prestige" },
}

local LEGACY_PROGRESSION_BINDINGS = {
    ["RAVIOLI_PROGRESSION_ECHOES"] = "ZEN_PROGRESSION_ECHOES",
    ["RAVIOLI_PROGRESSION_SKILLTREE"] = "ZEN_PROGRESSION_SKILLTREE",
    ["RAVIOLI_PROGRESSION_TRANSMOGRIFY"] = "ZEN_PROGRESSION_TRANSMOGRIFY",
    ["RAVIOLI_PROGRESSION_MOUNTS"] = "ZEN_PROGRESSION_MOUNTS",
    ["RAVIOLI_PROGRESSION_COMPANIONS"] = "ZEN_PROGRESSION_COMPANIONS",
    ["RAVIOLI_PROGRESSION_PRESTIGE"] = "ZEN_PROGRESSION_PRESTIGE",
}

local PROGRESSION_PAGE_LABELS = {
    echoes = "Echoes",
    ["skill tree"] = "Skill Tree",
    skilltree = "Skill Tree",
    transmogrify = "Transmogrify",
    transmog = "Transmogrify",
    mounts = "Mounts",
    mount = "Mounts",
    companions = "Companions",
    companion = "Companions",
    prestige = "Prestige",
}

local NATIVE_CONTROLS = {
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "SocialsMicroButton",
    "PVPMicroButton",
    "LFDMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "KeyRingButton",
}

local NATIVE_CONTROL_LOOKUP = {}
for i = 1, #NATIVE_CONTROLS do NATIVE_CONTROL_LOOKUP[NATIVE_CONTROLS[i]] = true end

-- Project Ebonhold adds one extra control to the stock micro-button strip.  Its
-- exact global name has changed between client revisions, so Zen discovers
-- it by name/parent instead of hard-coding one build.  The visible Zen menu
-- still delegates to the original button whenever possible, preserving whatever
-- server/client behavior Ebonhold attaches to that click.
local EBONHOLD_BUTTON_NAMES = {
    "ProjectEbonholdMicroButton",
    "EbonholdMicroButton",
    "CharacterProgressionMicroButton",
    "ProjectEbonholdCharacterProgressionButton",
    "CharacterProgressionButton",
    "ProgressionMicroButton",
}

local EBONHOLD_ECHO_TAB_NAMES = {
    "ProjectEbonholdEchoesButton",
    "ProjectEbonholdEchoesTab",
    "EchoesButton",
    "EchoesTab",
    "EmpowermentButton",
    "EmpowermentTab",
}

-- _G on the Ebonhold client contains several non-frame userdata values.
-- Indexing one of those directly (value.GetObjectType) raises a Lua error before
-- we ever get a chance to reject it. Character Progression discovery scans _G,
-- so every object probe must be protected.
local function SafeObjectMember(value, key)
    local ok, member = pcall(function() return value[key] end)
    if ok then return member end
    return nil
end

local function IsButtonObject(value)
    local kind = type(value)
    if not value or (kind ~= "table" and kind ~= "userdata") then return false end

    local getObjectType = SafeObjectMember(value, "GetObjectType")
    local getScript = SafeObjectMember(value, "GetScript")
    if type(getObjectType) ~= "function" or type(getScript) ~= "function" then return false end

    local ok, objectType = pcall(getObjectType, value)
    -- Ebonhold has shipped the Character Progression launcher as both a normal
    -- Button and a CheckButton. Treat both as clickable controls; requiring the
    -- exact "Button" object type made Zen miss the live blue launcher on
    -- newer clients, which also prevented it from being hidden.
    return ok and (objectType == "Button" or objectType == "CheckButton")
end

local function IsFrameObject(value)
    local kind = type(value)
    if kind ~= "table" and kind ~= "userdata" then return false end
    return type(SafeObjectMember(value, "GetObjectType")) == "function"
end

local function IsMicroBarParent(frame)
    local parent = frame and frame.GetParent and frame:GetParent()
    local depth = 0
    while parent and depth < 4 do
        if parent == _G.MainMenuBarArtFrame or parent == _G.MainMenuBar then return true end
        parent = parent.GetParent and parent:GetParent() or nil
        depth = depth + 1
    end
    return false
end

local function IsAnchoredToNativeControl(frame)
    if not frame or not frame.GetNumPoints or not frame.GetPoint then return false end
    local count = tonumber(frame:GetNumPoints()) or 0
    for i = 1, count do
        local ok, _, relativeTo = pcall(frame.GetPoint, frame, i)
        if ok and relativeTo and relativeTo.GetName then
            local name = relativeTo:GetName()
            if name and NATIVE_CONTROL_LOOKUP[name] then return true end
        end
    end
    return false
end

local function IsZenFrame(frame)
    if not frame then return false end
    local getName = SafeObjectMember(frame, "GetName")
    if type(getName) ~= "function" then return false end
    local ok, name = pcall(getName, frame)
    return ok and type(name) == "string" and string.find(name, "ZenUI", 1, true) == 1
end

local function ProgressionTooltipMatch(button)
    if not GameTooltip or not button or not button.GetScript then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local enter = button:GetScript("OnEnter")
    if type(enter) ~= "function" then return false end

    -- Ebonhold's progression launcher is not consistently named between client
    -- revisions, but its native tooltip is stable: "Character Progression" and
    -- a description mentioning echoes / skill tree / transmogrify / mounts.
    local ok = pcall(enter, button)
    if not ok then return false end
    local title = _G.GameTooltipTextLeft1 and _G.GameTooltipTextLeft1:GetText() or ""
    local detail = _G.GameTooltipTextLeft2 and _G.GameTooltipTextLeft2:GetText() or ""
    local joined = string.lower(tostring(title or "") .. " " .. tostring(detail or ""))
    local match = string.find(joined, "character progression", 1, true)
        or (string.find(joined, "echo", 1, true) and string.find(joined, "skill tree", 1, true))

    local leave = button:GetScript("OnLeave")
    if type(leave) == "function" then pcall(leave, button) elseif GameTooltip then GameTooltip:Hide() end
    return match and true or false
end

local function AddChildButtons(root, output, seen, depth)
    if not root or depth > 4 or not root.GetChildren then return end
    local children = { root:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and not seen[child] then
            seen[child] = true
            if IsButtonObject(child) and not IsZenFrame(child) then output[#output + 1] = child end
            AddChildButtons(child, output, seen, depth + 1)
        end
    end
end

local function ButtonText(button)
    if not button then return nil end
    if button.GetText then
        local ok, text = pcall(button.GetText, button)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    if button.GetRegions then
        local regions = { button:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region and region.GetText then
                local ok, text = pcall(region.GetText, region)
                if ok and type(text) == "string" and text ~= "" then return text end
            end
        end
    end
    return nil
end

local function ClickButton(button)
    if not IsButtonObject(button) then return false end

    -- Prefer the real Button:Click() pipeline. Ebonhold progression controls
    -- can use template/PreClick/PostClick behavior in addition to OnClick;
    -- calling only GetScript("OnClick") can therefore play the click sound
    -- without actually opening or switching the progression page.
    if button.Click then
        local ok = pcall(button.Click, button, "LeftButton")
        if ok then return true end
        ok = pcall(button.Click, button)
        if ok then return true end
    end

    -- Compatibility fallback for unusual custom buttons without a working
    -- Click method. This is intentionally second choice.
    local script = button.GetScript and button:GetScript("OnClick")
    if type(script) == "function" then
        local ok = pcall(script, button, "LeftButton")
        if ok then return true end
    end
    return false
end

local function NormalizeProgressionLabel(text)
    text = tostring(text or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, "%s+", " ")
    return string.lower(text)
end

local function CanonicalProgressionPage(page)
    local normalized = NormalizeProgressionLabel(page)
    return PROGRESSION_PAGE_LABELS[normalized]
end

local function ProgressionRoots()
    local roots, seen = {}, {}
    local function Add(root)
        if root and not seen[root] then roots[#roots + 1] = root; seen[root] = true end
    end
    Add(_G.ProjectEbonholdEmpowermentFrame)
    Add(_G.skillTreeFrame)
    if _G.ProjectEbonholdEmpowermentFrame and _G.ProjectEbonholdEmpowermentFrame.GetParent then
        Add(_G.ProjectEbonholdEmpowermentFrame:GetParent())
    end
    if _G.skillTreeFrame and _G.skillTreeFrame.GetParent then Add(_G.skillTreeFrame:GetParent()) end
    return roots, seen
end

local function IsDescendantOfProgression(frame, rootLookup)
    local parent = frame
    local depth = 0
    while parent and depth < 8 do
        if rootLookup[parent] then return true end
        parent = parent.GetParent and parent:GetParent() or nil
        depth = depth + 1
    end
    return false
end

local function FindProgressionTabButton(page)
    local label = CanonicalProgressionPage(page)
    if not label then return nil end
    local wanted = NormalizeProgressionLabel(label)
    local roots, rootLookup = ProgressionRoots()

    -- Prefer controls in the known progression hierarchy. Ebonhold's six bottom
    -- tabs are frequently unnamed, but their visible labels are stable.
    for r = 1, #roots do
        local candidates, seen = {}, {}
        AddChildButtons(roots[r], candidates, seen, 0)
        for i = 1, #candidates do
            if NormalizeProgressionLabel(ButtonText(candidates[i])) == wanted then return candidates[i] end
        end
    end

    -- Fall back to a global scan because different Ebonhold client revisions
    -- have moved/renamed the progression container. Score likely progression
    -- descendants and visible controls above unrelated buttons with the same label.
    local best, bestScore = nil, -1
    for name, value in pairs(_G) do
        if IsButtonObject(value) and not IsZenFrame(value) and NormalizeProgressionLabel(ButtonText(value)) == wanted then
            local score = 0
            if value.IsShown and value:IsShown() then score = score + 10 end
            if IsDescendantOfProgression(value, rootLookup) then score = score + 40 end
            local lowerName = type(name) == "string" and string.lower(name) or ""
            local compact = string.gsub(wanted, "%s+", "")
            if compact ~= "" and string.find(string.gsub(lowerName, "[%s_%-]", ""), compact, 1, true) then score = score + 8 end
            if score > bestScore then best, bestScore = value, score end
        end
    end
    return best
end

-- A progression tab can remain globally available while Ebonhold's combined
-- Character Progression window is hidden. Clicking that hidden tab updates the
-- selected page internally but does not reveal the window, which made keybinds
-- appear to work only when Character Progression was already open.
--
-- Reveal the tab's real Ebonhold parent hierarchy first. This deliberately uses
-- the discovered progression tab itself as the anchor instead of any Blizzard
-- Mount Journal API: Ebonhold moved Mounts/Companions/etc. into this custom UI.
local function RevealProgressionTabHierarchy(tab)
    if not tab then return false end

    local chain = {}
    local frame = tab
    local depth = 0
    while frame and frame ~= _G.UIParent and depth < 12 do
        chain[#chain + 1] = frame
        frame = frame.GetParent and frame:GetParent() or nil
        depth = depth + 1
    end

    -- Show parents before children so Ebonhold OnShow handlers initialize the
    -- shared progression panel before the requested tab receives its click.
    for i = #chain, 1, -1 do
        local node = chain[i]
        if node and node.Show then pcall(node.Show, node) end
    end

    local parent = tab.GetParent and tab:GetParent() or nil
    if parent and parent.IsShown and parent:IsShown() then return true end
    if tab.IsShown and tab:IsShown() then return true end
    return #chain > 1
end

-- Resolve the actual top-level Ebonhold Character Progression window from a
-- discovered progression tab. The bottom tabs can stay alive while the window
-- itself is hidden, so the tab is a much more reliable anchor than a guessed
-- global frame name.
local function ProgressionWindowFromTab(tab)
    if not tab then return nil end
    local frame = tab
    local candidate = nil
    local depth = 0
    while frame and frame ~= _G.UIParent and depth < 16 do
        if IsFrameObject(frame) then candidate = frame end
        local parent = frame.GetParent and frame:GetParent() or nil
        if parent == _G.UIParent then return frame end
        frame = parent
        depth = depth + 1
    end
    return candidate
end

local function RemoveLegacyProgressionEscapeController()
    -- Older ZenUI builds used an invisible UISpecialFrames surrogate so Escape
    -- could close Ebonhold's sometimes-unnamed Character Progression root.  On
    -- some client states that surrogate can outlive the visible progression UI
    -- and consume ESC forever, preventing the normal Game Menu from opening.
    -- Never use an invisible special-frame proxy for this purpose again.
    local controller = MicroMenu.progressionEscapeController or _G.ZenUIProgressionEscapeFrame
    if controller then
        controller.RUISuppressClose = true
        if controller.Hide then pcall(controller.Hide, controller) end
        controller.RUISuppressClose = nil
        if controller.SetScript then
            controller:SetScript("OnHide", nil)
            controller:SetScript("OnShow", nil)
            controller:SetScript("OnUpdate", nil)
            controller:SetScript("OnKeyDown", nil)
        end
    end
    MicroMenu.progressionEscapeController = nil

    if UISpecialFrames then
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == "ZenUIProgressionEscapeFrame" then
                table.remove(UISpecialFrames, i)
            end
        end
    end
end

local function RegisterProgressionWindow(root)
    if not root or root == _G.UIParent then return nil end
    MicroMenu.progressionWindow = root

    -- Prefer WoW's real Escape handling whenever Ebonhold exposes a named
    -- top-level frame.  If the root is unnamed, deliberately do not create a
    -- surrogate: preserving the global ESC -> Game Menu path is more important
    -- than forcing Escape support onto one custom progression window.
    local rootName = root.GetName and root:GetName() or nil
    if rootName and rootName ~= "" then
        UISpecialFrames = UISpecialFrames or {}
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == rootName then found = true; break end
        end
        if not found then table.insert(UISpecialFrames, rootName) end
    end

    MicroMenu.progressionRegisteredRoots = MicroMenu.progressionRegisteredRoots or {}
    if not MicroMenu.progressionRegisteredRoots[root] and root.HookScript then
        MicroMenu.progressionRegisteredRoots[root] = true
        root:HookScript("OnShow", function(self)
            MicroMenu.progressionWindow = self
        end)
        root:HookScript("OnHide", function(self)
            if MicroMenu.progressionWindow == self then
                MicroMenu.currentProgressionPage = nil
            end
        end)
    end

    return root
end

local function RegisterProgressionTabWindow(tab)
    return RegisterProgressionWindow(ProgressionWindowFromTab(tab))
end

local function FindVisibleProgressionWindow()
    local root = MicroMenu.progressionWindow
    if root and root.IsShown and root:IsShown() then return root end

    -- Prefer the combined-window tabs because they exist even when the custom
    -- progression frame does not expose a stable global name on Ebonhold.
    local probePages = { "Mounts", "Transmogrify", "Companions", "Prestige", "Echoes", "Skill Tree" }
    for i = 1, #probePages do
        local tab = FindProgressionTabButton(probePages[i])
        if tab then
            root = ProgressionWindowFromTab(tab)
            if root and root.IsShown and root:IsShown() then
                RegisterProgressionWindow(root)
                return root
            end
        end
    end

    return nil
end

local function IsProgressionPageActive(page)
    local label = CanonicalProgressionPage(page)
    if not label then return false end
    if MicroMenu.currentProgressionPage == label then return true end
    local tab = FindProgressionTabButton(label)
    if tab and tab.GetChecked then
        local ok, checked = pcall(tab.GetChecked, tab)
        if ok and checked then return true end
    end
    return false
end

local function CloseProgressionWindow()
    -- Inline the retry shutdown here because this helper is declared before the
    -- local StopProgressionRetry() function below. Keeping it local avoids any
    -- dependency on a global with the same name on private-server clients.
    local retry = MicroMenu.progressionRetryFrame
    if retry then
        retry:SetScript("OnUpdate", nil)
        retry:Hide()
        retry.pageLabel = nil
        retry.elapsed = 0
        retry.tick = 0
    end
    local root = FindVisibleProgressionWindow()
    if not root then return false end
    if root.Hide then pcall(root.Hide, root) end
    MicroMenu.currentProgressionPage = nil
    return true
end

local function OpenKnownProgressionContainer()
    local frame = _G.ProjectEbonholdEmpowermentFrame
    if frame and frame.Show then frame:Show(); return true end
    local tree = _G.skillTreeFrame
    if tree and tree.Show then tree:Show(); return true end
    return false
end

local function StopProgressionRetry()
    local retry = MicroMenu.progressionRetryFrame
    if not retry then return end
    retry:SetScript("OnUpdate", nil)
    retry:Hide()
    retry.pageLabel = nil
    retry.elapsed = 0
    retry.tick = 0
end

local function ScheduleProgressionPage(page)
    local label = CanonicalProgressionPage(page)
    if not label then return false end

    local retry = MicroMenu.progressionRetryFrame
    if not retry then
        retry = CreateFrame("Frame")
        retry:Hide()
        MicroMenu.progressionRetryFrame = retry
    end

    retry.pageLabel = label
    retry.elapsed = 0
    retry.tick = 0
    retry:SetScript("OnUpdate", function(self, dt)
        self.elapsed = (self.elapsed or 0) + (dt or 0)
        self.tick = (self.tick or 0) + (dt or 0)
        if self.tick < 0.05 then return end
        self.tick = 0

        local wanted = self.pageLabel
        if not wanted then StopProgressionRetry(); return end

        local tab = FindProgressionTabButton(wanted)
        if tab then
            RevealProgressionTabHierarchy(tab)
            RegisterProgressionTabWindow(tab)
            if ClickButton(tab) then
                MicroMenu.currentProgressionPage = wanted
                StopProgressionRetry()
                return
            end
        end

        -- The Character Progression launcher can build/show its shared frame on
        -- the following frame rather than synchronously. If the requested tab
        -- has not appeared yet, reveal a known progression container once; this
        -- is the same direct frame path used successfully by other Ebonhold QoL
        -- addons for Echoes and the Skill Tree.
        if self.elapsed >= 0.15 and not self.revealedKnown then
            self.revealedKnown = true
            -- Echoes must never be initialized by showing
            -- ProjectEbonholdEmpowermentFrame directly: on this Ebonhold build
            -- that is only the inner Echoes content frame and creates an orphan
            -- mini-window. The native launcher/tab path above is authoritative.
            if wanted ~= "Echoes" then
                OpenKnownProgressionContainer()
            end
        end

        if self.elapsed >= 1.25 then
            StopProgressionRetry()
            RUI:Print("Character Progression page '" .. tostring(wanted) .. "' could not be opened on this Ebonhold build.")
        end
    end)
    retry.revealedKnown = false
    retry:Show()
    return true
end

local function OpenEbonholdProgressionPage(page)
    local label = CanonicalProgressionPage(page)
    if not label then return false end

    StopProgressionRetry()

    -- Do not open ProjectEbonholdEmpowermentFrame or skillTreeFrame directly.
    -- On the current Ebonhold build these are inner page/content frames, not the
    -- complete Character Progression window. Showing the Echoes frame directly
    -- produces the narrow orphaned Echoes panel without the surrounding native
    -- progression chrome/tabs. Resolve the real combined-window tab/launcher
    -- below so hardware shortcuts open exactly the same UI as Ebonhold itself.

    -- If the combined progression UI is already initialized, its tab buttons
    -- may still exist while the parent window is hidden. Reveal the actual
    -- Ebonhold Character Progression hierarchy first, then click the requested
    -- tab. Merely clicking a hidden tab changes its state without opening the
    -- window.
    local tab = FindProgressionTabButton(label)
    if tab then
        RevealProgressionTabHierarchy(tab)
        RegisterProgressionTabWindow(tab)
        if ClickButton(tab) then
            MicroMenu.currentProgressionPage = label
            return true
        end
    end

    -- Initialize the combined window through Ebonhold's real launcher. Do not
    -- assume its tabs exist in the same Lua frame: schedule a short one-shot
    -- retry and select the requested page once Ebonhold has finished opening it.
    local launcher = MicroMenu:DiscoverEbonholdMicroButton(true)
    if launcher and ClickButton(launcher) then
        ScheduleProgressionPage(label)
        return true
    end

    -- Last-resort initialization for client revisions that expose only the
    -- progression frames and no discoverable launcher. Never use this for
    -- Echoes: ProjectEbonholdEmpowermentFrame is an inner content frame on the
    -- live Ebonhold UI and showing it directly creates the wrong mini-window.
    if label ~= "Echoes" and OpenKnownProgressionContainer() then
        ScheduleProgressionPage(label)
        return true
    end
    if label == "Skill Tree" and _G.skillTreeFrame and _G.skillTreeFrame.Show then
        _G.skillTreeFrame:Show()
        ScheduleProgressionPage(label)
        return true
    end
    return false
end

local function FindEchoesTabButton()
    return FindProgressionTabButton("Echoes")
end

local function OpenEbonholdEchoes()
    return OpenEbonholdProgressionPage("Echoes")
end

local function OwnFrameTexts(frame)
    local result = {}
    local seen = {}
    local function Add(value)
        if type(value) ~= "string" or value == "" or seen[value] then return end
        seen[value] = true
        result[#result + 1] = value
    end

    local getText = SafeObjectMember(frame, "GetText")
    if type(getText) == "function" then
        local ok, value = pcall(getText, frame)
        if ok then Add(value) end
    end

    local fields = { "RUIText", "label", "text", "title", "name", "Name" }
    for i = 1, #fields do
        local value = SafeObjectMember(frame, fields[i])
        local memberGetText = SafeObjectMember(value, "GetText")
        if type(memberGetText) == "function" then
            local ok, text = pcall(memberGetText, value)
            if ok then Add(text) end
        end
    end

    local getRegions = SafeObjectMember(frame, "GetRegions")
    if type(getRegions) == "function" then
        local ok, regions = pcall(function() return { getRegions(frame) } end)
        if ok and regions then
            for i = 1, #regions do
                local region = regions[i]
                local regionGetText = SafeObjectMember(region, "GetText")
                if type(regionGetText) == "function" then
                    local rok, text = pcall(regionGetText, region)
                    if rok then Add(text) end
                end
            end
        end
    end
    return result
end

local function AddDescendantFrames(root, out, seen, depth)
    if not root or seen[root] or (depth or 0) > 10 then return end
    seen[root] = true
    out[#out + 1] = root
    local getChildren = SafeObjectMember(root, "GetChildren")
    if type(getChildren) ~= "function" then return end
    local ok, children = pcall(function() return { getChildren(root) } end)
    if not ok or not children then return end
    for i = 1, #children do
        AddDescendantFrames(children[i], out, seen, (depth or 0) + 1)
    end
end

-- Echo Saved Builds quick access mirrors Ebonhold's native "Saved Builds"
-- dropdown. ZenUI does not copy Echo data and does not invent its own loadout
-- slots; it discovers the native rows and invokes the same row click Ebonhold
-- uses when the player selects a build from Character Progression -> Echoes.
local ECHO_BUILD_MAX = 10
local ECHO_BUILD_CACHE_VERSION = 6
local cachedEchoBuildContainer = nil

local ECHO_BUILD_RESERVED = {
    ["saved builds"] = true,
    ["saved build"] = true,
    ["wishlists"] = true,
    ["wishlist"] = true,
    ["new wishlist"] = true,
    ["new"] = true,
    ["import"] = true,
    ["export"] = true,
    ["my class"] = true,
    ["search"] = true,
}

local function TrimEchoBuildName(text)
    text = tostring(text or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, "%s+", " ")
    if string.len(text) > 64 then text = string.sub(text, 1, 64) end
    return text
end

local function IsEchoBuildName(text)
    local clean = TrimEchoBuildName(text)
    local normalized = NormalizeProgressionLabel(clean)
    if clean == "" or normalized == "" or ECHO_BUILD_RESERVED[normalized] then return false end
    if string.find(normalized, "empty slot", 1, true) == 1 then return false end
    if string.find(normalized, "unlock slot", 1, true) == 1 then return false end
    if string.find(normalized, "locked slot", 1, true) == 1 then return false end
    if string.find(normalized, "save your run", 1, true) then return false end
    return true
end

local function IsDescendantOf(frame, ancestor)
    if not frame or not ancestor then return false end
    local current = frame
    for _ = 1, 14 do
        if current == ancestor then return true end
        local getParent = SafeObjectMember(current, "GetParent")
        if type(getParent) ~= "function" then break end
        local ok, parent = pcall(getParent, current)
        if not ok or not parent or parent == current then break end
        current = parent
    end
    return false
end

local function FrameOwnsText(frame, wanted)
    wanted = NormalizeProgressionLabel(wanted)
    local texts = OwnFrameTexts(frame)
    for i = 1, #texts do
        if NormalizeProgressionLabel(texts[i]) == wanted then return true end
    end
    return false
end

local function SafeFrameTop(frame)
    local method = SafeObjectMember(frame, "GetTop")
    if type(method) ~= "function" then return 0 end
    local ok, value = pcall(method, frame)
    if ok and type(value) == "number" then return value end
    return 0
end

local function SafeFrameWidth(frame)
    local method = SafeObjectMember(frame, "GetWidth")
    if type(method) ~= "function" then return 0 end
    local ok, value = pcall(method, frame)
    if ok and type(value) == "number" then return value end
    return 0
end

local function SafeFrameHeight(frame)
    local method = SafeObjectMember(frame, "GetHeight")
    if type(method) ~= "function" then return 0 end
    local ok, value = pcall(method, frame)
    if ok and type(value) == "number" then return value end
    return 0
end

local function SafeObjectCenterY(object)
    local method = SafeObjectMember(object, "GetCenter")
    if type(method) ~= "function" then return nil end
    local ok, _, y = pcall(method, object)
    if ok and type(y) == "number" then return y end
    return nil
end

local function SafeIsShown(frame)
    local method = SafeObjectMember(frame, "IsShown")
    if type(method) ~= "function" then return false end
    local ok, value = pcall(method, frame)
    return ok and value == true
end

-- Return actual screen Y coordinates for section labels. Ebonhold's Saved
-- Builds and Wishlists labels are FontStrings, so using only the parent frame
-- center can accidentally include controls from the rest of the Echoes page.
local function CollectTextMarkerY(root, wanted, output, seen, depth)
    if not root or seen[root] or (depth or 0) > 7 then return end
    seen[root] = true
    wanted = NormalizeProgressionLabel(wanted)

    local function ConsiderTextObject(object, fallback)
        if not object then return end
        local getText = SafeObjectMember(object, "GetText")
        if type(getText) ~= "function" then return end
        local ok, value = pcall(getText, object)
        if not ok or NormalizeProgressionLabel(value) ~= wanted then return end
        local y = SafeObjectCenterY(object) or SafeObjectCenterY(fallback)
        if type(y) == "number" then output[#output + 1] = y end
    end

    ConsiderTextObject(root, root)

    local fields = { "RUIText", "label", "text", "title", "name", "Name" }
    for i = 1, #fields do
        ConsiderTextObject(SafeObjectMember(root, fields[i]), root)
    end

    local getRegions = SafeObjectMember(root, "GetRegions")
    if type(getRegions) == "function" then
        local ok, regions = pcall(function() return { getRegions(root) } end)
        if ok and regions then
            for i = 1, #regions do ConsiderTextObject(regions[i], root) end
        end
    end

    local getChildren = SafeObjectMember(root, "GetChildren")
    if type(getChildren) == "function" then
        local ok, children = pcall(function() return { getChildren(root) } end)
        if ok and children then
            for i = 1, #children do
                CollectTextMarkerY(children[i], wanted, output, seen, (depth or 0) + 1)
            end
        end
    end
end

local function SavedBuildSectionBand(container)
    if not container then return nil, nil end
    local savedYs, wishYs = {}, {}
    CollectTextMarkerY(container, "Saved Builds", savedYs, {}, 0)
    CollectTextMarkerY(container, "Wishlists", wishYs, {}, 0)
    if #savedYs == 0 or #wishYs == 0 then return nil, nil end

    local bestSaved, bestWish, bestDistance = nil, nil, nil
    for s = 1, #savedYs do
        for w = 1, #wishYs do
            local distance = savedYs[s] - wishYs[w]
            if distance > 8 and (not bestDistance or distance < bestDistance) then
                bestSaved, bestWish, bestDistance = savedYs[s], wishYs[w], distance
            end
        end
    end
    return bestSaved, bestWish
end

local function ButtonInSavedBuildBand(button, savedY, wishY)
    if not button or not savedY or not wishY then return false end
    local y = SafeObjectCenterY(button)
    if not y then
        local top = SafeFrameTop(button)
        local height = SafeFrameHeight(button)
        if top ~= 0 then y = top - (height * 0.5) end
    end
    return type(y) == "number" and y < (savedY - 2) and y > (wishY + 2)
end

local function SavedBuildRows(container)
    local rows = {}
    local savedY, wishY = SavedBuildSectionBand(container)
    if not savedY or not wishY then return rows, savedY, wishY end

    local buttons, seen = {}, {}
    AddChildButtons(container, buttons, seen, 0)
    local namesSeen = {}
    for i = 1, #buttons do
        local button = buttons[i]
        local label = TrimEchoBuildName(ButtonText(button))
        local normalized = NormalizeProgressionLabel(label)
        if ButtonInSavedBuildBand(button, savedY, wishY)
            and IsEchoBuildName(label)
            and SafeFrameWidth(button) >= 96
            and not namesSeen[normalized] then
            namesSeen[normalized] = true
            rows[#rows + 1] = {
                name = label,
                button = button,
                top = SafeFrameTop(button),
                centerY = SafeObjectCenterY(button) or 0,
            }
        end
    end
    return rows, savedY, wishY
end

local function SavedBuildContainerScore(container)
    if not container or not IsFrameObject(container) then return -1 end
    local rows, savedY, wishY = SavedBuildRows(container)
    if not savedY or not wishY or #rows == 0 then return -1 end

    local score = 120 + math.min(#rows, ECHO_BUILD_MAX) * 12
    local area = SafeFrameWidth(container) * SafeFrameHeight(container)
    if area > 0 then score = score - math.min(area / 100000, 20) end
    return score
end

local function FindSavedBuildContainer()
    -- Prefer the smallest frame containing the complete Saved Builds ->
    -- Wishlists section. Older discovery rewarded ancestors with more buttons,
    -- which let wishlist/mount controls leak into the Quick Menu.
    if cachedEchoBuildContainer and IsFrameObject(cachedEchoBuildContainer) then
        local score = SavedBuildContainerScore(cachedEchoBuildContainer)
        if score >= 120 then return cachedEchoBuildContainer, score end
        cachedEchoBuildContainer = nil
    end

    local best, bestScore, bestArea = nil, -1, nil

    local function ConsiderHeader(frame)
        if not frame or not IsFrameObject(frame) or not FrameOwnsText(frame, "Saved Builds") then return end
        local candidate = frame
        for _ = 0, 4 do
            if not candidate then break end
            local score = SavedBuildContainerScore(candidate)
            if score >= 120 then
                local area = SafeFrameWidth(candidate) * SafeFrameHeight(candidate)
                local normalizedArea = area > 0 and area or 999999999
                if not best
                    or normalizedArea < bestArea
                    or (normalizedArea == bestArea and score > bestScore) then
                    best, bestScore, bestArea = candidate, score, normalizedArea
                end
            end
            local getParent = SafeObjectMember(candidate, "GetParent")
            if type(getParent) ~= "function" then break end
            local ok, parent = pcall(getParent, candidate)
            if not ok or not parent or parent == candidate then break end
            candidate = parent
        end
    end

    local roots = ProgressionRoots()
    for r = 1, #roots do
        local frames, seen = {}, {}
        AddDescendantFrames(roots[r], frames, seen, 0)
        for i = 1, #frames do ConsiderHeader(frames[i]) end
    end

    if not best and _G.UIParent and type(_G.UIParent.GetChildren) == "function" then
        local children = { _G.UIParent:GetChildren() }
        for i = 1, #children do
            local frames, seen = {}, {}
            AddDescendantFrames(children[i], frames, seen, 0)
            for f = 1, #frames do ConsiderHeader(frames[f]) end
        end
    end

    if best then cachedEchoBuildContainer = best end
    return best, bestScore
end

local function GetEchoBuildCacheBucket(create)
    if not RUI.global then return nil end
    if create then RUI.global.echoBuildCache = RUI.global.echoBuildCache or {} end
    local store = RUI.global.echoBuildCache
    if not store then return nil end
    local key = RUI.GetCharacterKey and RUI:GetCharacterKey() or tostring(UnitName("player") or "player")
    if create and type(store[key]) ~= "table" then store[key] = { names = {} } end
    return store[key]
end

local function SaveEchoBuildCache(builds, current, currentSlot)
    local bucket = GetEchoBuildCacheBucket(true)
    if not bucket then return end
    bucket.version = ECHO_BUILD_CACHE_VERSION
    bucket.names = {}
    bucket.slots = {}
    bucket.verified = {}
    for i = 1, math.min(#builds, ECHO_BUILD_MAX) do
        bucket.names[i] = builds[i].name
        bucket.slots[i] = tonumber(builds[i].slot)
        bucket.verified[i] = builds[i].verified == true
    end
    if current and current ~= "" then bucket.current = current end
    if tonumber(currentSlot) then bucket.currentSlot = tonumber(currentSlot) end
end

local function CachedEchoBuilds()
    local result = {}
    local bucket = GetEchoBuildCacheBucket(false)
    -- Older cache formats came from native UI scraping and could include rows
    -- outside Saved Builds. Version 3 stores the authoritative server slot too.
    if not bucket or bucket.version ~= ECHO_BUILD_CACHE_VERSION then return result, nil, nil end
    local names = bucket.names
    if type(names) == "table" then
        for i = 1, math.min(#names, ECHO_BUILD_MAX) do
            local name = TrimEchoBuildName(names[i])
            local slot = bucket.slots and tonumber(bucket.slots[i]) or nil
            local verified = bucket.verified and bucket.verified[i] == true or false
            if IsEchoBuildName(name) and verified and slot and slot >= 1 and slot <= ECHO_BUILD_MAX then
                result[#result + 1] = {
                    name = name,
                    slot = slot,
                    verified = true,
                    cached = true,
                }
            end
        end
    end
    return result, bucket.current, tonumber(bucket.currentSlot)
end

local function EchoEbonAPIBridge()
    local bridge = RUI.EbonAPIBridge
    if bridge and type(bridge.Connect) == "function" and not bridge:IsAvailable() then
        bridge:Connect()
    end
    if bridge and type(bridge.IsAvailable) == "function" and bridge:IsAvailable() then return bridge end
    return nil
end

local function EchoPerkService()
    local bridge = EchoEbonAPIBridge()
    if bridge and type(bridge.GetPerkService) == "function" then
        local service = bridge:GetPerkService()
        if type(service) == "table" then return service end
    end
    local ebonhold = _G.ProjectEbonhold
    local service = ebonhold and ebonhold.PerkService
    return type(service) == "table" and service or nil
end

-- Prefer normalized EbonAPI build state when that standalone community addon
-- is installed. ZenUI does not bundle EbonAPI; without it, use Ebonhold's direct
-- PerkService and retain the old UI scanner only as a legacy compatibility path.
local function DirectEchoSavedBuilds(requestRefresh)
    -- Preferred path when the community EbonAPI addon is installed: consume
    -- its normalized BUILD_LIST state. This is authoritative server data and
    -- avoids Zen having to distinguish Saved Builds from Wishlist/loadout rows
    -- exposed by Ebonhold's UI/service tables.
    local bridge = EchoEbonAPIBridge()
    if bridge then
        if requestRefresh and type(bridge.RequestBuilds) == "function" then
            bridge:RequestBuilds()
        end
        if type(bridge.GetSavedBuilds) == "function" then
            local builds, current, currentSlot = bridge:GetSavedBuilds(ECHO_BUILD_MAX)
            if type(builds) == "table" then
                local clean = {}
                for i = 1, math.min(#builds, ECHO_BUILD_MAX) do
                    local build = builds[i]
                    local slot = build and tonumber(build.slot)
                    local name = build and TrimEchoBuildName(build.name) or ""
                    if slot and slot >= 1 and slot <= ECHO_BUILD_MAX and IsEchoBuildName(name) then
                        clean[#clean + 1] = {
                            name = name,
                            slot = slot,
                            verified = true,
                            direct = true,
                            ebonapi = true,
                        }
                    end
                end
                table.sort(clean, function(a, b)
                    if a.slot == b.slot then return a.name < b.name end
                    return a.slot < b.slot
                end)
                SaveEchoBuildCache(clean, current, currentSlot)
                return clean, current, currentSlot, true, "ebonapi"
            end
        end

        -- EbonAPI is connected but has not received BUILD_LIST yet. Do not
        -- scrape the Echoes UI in this window; use only the last verified cache
        -- until its sticky SERVER_BUILDS event arrives.
        return nil, nil, nil, true, "ebonapi"
    end

    -- Standalone fallback: use Ebonhold's direct PerkService. This preserves
    -- current ZenUI behavior for users who do not have EbonAPI enabled.
    local service = EchoPerkService()
    if not service or type(service.GetServerBuildSlots) ~= "function" then
        return nil, nil, nil, false, nil
    end

    if requestRefresh and type(service.RequestServerBuildSlots) == "function" then
        local ok, err = pcall(service.RequestServerBuildSlots)
        if not ok and RUI.RecordRuntimeError then
            RUI:RecordRuntimeError("echo", "RequestServerBuildSlots", err)
        end
    end

    local okSlots, slots = pcall(service.GetServerBuildSlots)
    if not okSlots then
        if RUI.RecordRuntimeError then RUI:RecordRuntimeError("echo", "GetServerBuildSlots", slots) end
        return nil, nil, nil, true, "service"
    end
    if type(slots) ~= "table" then return nil, nil, nil, true, "service" end

    local currentSlot = 0
    if type(service.GetServerActiveSlot) == "function" then
        local okCurrent, value = pcall(service.GetServerActiveSlot)
        if okCurrent then currentSlot = tonumber(value) or 0 end
    end

    local builds = {}
    for slotKey, info in pairs(slots) do
        local slot = tonumber(slotKey) or (type(info) == "table" and tonumber(info.slot))
        -- The native Ebonhold service may expose wishlist/loadout records as well.
        -- Without EbonAPI, retain Zen's strict verified-slot rule.
        if slot and slot >= 1 and slot <= ECHO_BUILD_MAX and type(info) == "table" and info.verified == true then
            local name = TrimEchoBuildName(info.name or ("Build " .. tostring(slot)))
            if IsEchoBuildName(name) then
                builds[#builds + 1] = {
                    name = name,
                    slot = slot,
                    verified = true,
                    direct = true,
                }
            end
        end
    end

    table.sort(builds, function(a, b)
        if a.slot == b.slot then return a.name < b.name end
        return (a.slot or 999) < (b.slot or 999)
    end)
    while #builds > ECHO_BUILD_MAX do table.remove(builds) end

    local current = nil
    for i = 1, #builds do
        if builds[i].slot == currentSlot then current = builds[i].name; break end
    end
    SaveEchoBuildCache(builds, current, currentSlot)
    return builds, current, currentSlot, true, "service"
end

local function FindNativeCurrentEchoBuild(builds, menuRoot)
    if not builds or #builds == 0 then return nil end
    local wanted = {}
    for i = 1, #builds do wanted[NormalizeProgressionLabel(builds[i].name)] = builds[i].name end

    local roots = ProgressionRoots()
    local bestName, bestScore = nil, -1
    for r = 1, #roots do
        local buttons, seen = {}, {}
        AddChildButtons(roots[r], buttons, seen, 0)
        for i = 1, #buttons do
            local button = buttons[i]
            if not IsDescendantOf(button, menuRoot) then
                local name = wanted[NormalizeProgressionLabel(ButtonText(button))]
                if name then
                    local score = 0
                    if SafeIsShown(button) then score = score + 30 end
                    local width = SafeFrameWidth(button)
                    if width >= 100 then score = score + 10 end
                    score = score + math.min(SafeFrameTop(button) / 100, 10)
                    if score > bestScore then bestName, bestScore = name, score end
                end
            end
        end
    end
    return bestName
end

function MicroMenu:DiscoverEchoSavedBuilds(requestDirectRefresh)
    local directBuilds, directCurrent, directSlot, directAvailable, directSource = DirectEchoSavedBuilds(requestDirectRefresh == true)
    if directAvailable then
        if directBuilds then
            return directBuilds, directCurrent, directSlot, directSource or "service"
        end
        -- If the direct service exists but its slot payload is momentarily not
        -- ready (commonly just after RequestServerBuildSlots), do not fall back
        -- to scanning the Echoes page. That UI also contains Wishlists and can
        -- transiently present those rows as build-like buttons. Use only the
        -- last verified direct cache until the service answers again.
        local cached, current, currentSlot = CachedEchoBuilds()
        return cached, current, currentSlot, directSource == "ebonapi" and "ebonapi-cache" or "cache"
    end

    local container = FindSavedBuildContainer()
    if not container then
        local cached, current, currentSlot = CachedEchoBuilds()
        return cached, current, currentSlot, directAvailable and "cache" or "cache"
    end

    -- Only rows physically between the native Saved Builds and Wishlists
    -- headings count. This deliberately excludes Wishlist entries and Echo/
    -- mount controls that can sit behind the dropdown at similar coordinates.
    local builds = SavedBuildRows(container)

    table.sort(builds, function(a, b)
        if a.top == b.top then return a.name < b.name end
        return a.top > b.top
    end)
    while #builds > ECHO_BUILD_MAX do table.remove(builds) end

    if #builds == 0 then return CachedEchoBuilds() end

    local current = nil
    for i = 1, #builds do
        local getChecked = SafeObjectMember(builds[i].button, "GetChecked")
        if type(getChecked) == "function" then
            local ok, checked = pcall(getChecked, builds[i].button)
            if ok and checked then current = builds[i].name; break end
        end
    end

    if not current then
        local bucket = GetEchoBuildCacheBucket(false)
        if bucket and bucket.version == ECHO_BUILD_CACHE_VERSION then current = bucket.current end
    end
    SaveEchoBuildCache(builds, current, nil)
    return builds, current, nil, "ui"
end

local function FindEchoBuildSelector(root, builds, menuRoot)
    if not root then return nil end
    local wanted = {}
    for i = 1, #(builds or {}) do wanted[NormalizeProgressionLabel(builds[i].name)] = true end
    if next(wanted) == nil then
        local cached = CachedEchoBuilds()
        for i = 1, #cached do wanted[NormalizeProgressionLabel(cached[i].name)] = true end
    end

    local allowAnyBuildLabel = next(wanted) == nil
    local buttons, seen = {}, {}
    AddChildButtons(root, buttons, seen, 0)
    local best, bestScore = nil, -1
    for i = 1, #buttons do
        local button = buttons[i]
        local rawLabel = TrimEchoBuildName(ButtonText(button))
        local normalized = NormalizeProgressionLabel(rawLabel)
        local width = SafeFrameWidth(button)
        local matches = wanted[normalized] == true
        if allowAnyBuildLabel and IsEchoBuildName(rawLabel) and width >= 100 then matches = true end
        if matches and not IsDescendantOf(button, menuRoot) then
            local score = SafeIsShown(button) and 40 or 0
            if width >= 100 then score = score + 20 end
            score = score + math.min(SafeFrameTop(button) / 100, 10)
            if score > bestScore then best, bestScore = button, score end
        end
    end
    return best
end

function MicroMenu:StopEchoBuildRetry()
    local retry = self.echoBuildRetryFrame
    if not retry then return end
    retry:SetScript("OnUpdate", nil)
    retry:Hide()
    retry.buildName = nil
    retry.elapsed = 0
    retry.tick = 0
    retry.selectorClicked = false
    retry.openedProgression = false
end

function MicroMenu:StopEchoBuildConfirm()
    local frame = self.echoBuildConfirmFrame
    if not frame then return end
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
    frame.elapsed = 0
    frame.tick = 0
    frame.targetSlot = nil
    frame.targetName = nil
end

function MicroMenu:StartEchoBuildConfirm(targetSlot, targetName)
    self:StopEchoBuildConfirm()
    local frame = self.echoBuildConfirmFrame
    if not frame then
        frame = CreateFrame("Frame")
        frame:Hide()
        self.echoBuildConfirmFrame = frame
    end
    frame.elapsed = 0
    frame.tick = 0
    frame.targetSlot = tonumber(targetSlot)
    frame.targetName = targetName
    frame:SetScript("OnUpdate", function(selfFrame, dt)
        selfFrame.elapsed = (selfFrame.elapsed or 0) + (dt or 0)
        selfFrame.tick = (selfFrame.tick or 0) + (dt or 0)
        if selfFrame.tick < 0.20 then return end
        selfFrame.tick = 0

        local active = nil
        local bridge = EchoEbonAPIBridge()
        if bridge and type(bridge.GetActiveBuildSlot) == "function" then
            active = tonumber(bridge:GetActiveBuildSlot())
        end
        if not active then
            local service = EchoPerkService()
            if service and type(service.GetServerActiveSlot) == "function" then
                local ok, value = pcall(service.GetServerActiveSlot)
                if ok then active = tonumber(value) end
            end
        end
        if active and active == selfFrame.targetSlot then
            local name = selfFrame.targetName
            local slot = selfFrame.targetSlot
            MicroMenu:StopEchoBuildConfirm()
            local builds, current = DirectEchoSavedBuilds(false)
            local bucket = GetEchoBuildCacheBucket(true)
            if bucket then bucket.current = name; bucket.currentSlot = slot end
            if MicroMenu.quickFrame and MicroMenu.quickFrame:IsShown() then
                MicroMenu:RefreshEchoBuildList(true, false)
                MicroMenu:PositionQuickMenu()
            end
            RUI:Print("Echo build selected: " .. tostring(name) .. ".")
            return
        end

        if selfFrame.elapsed >= 5.0 then
            local name = selfFrame.targetName
            MicroMenu:StopEchoBuildConfirm()
            RUI:Print("Echo build change was requested, but Ebonhold did not confirm '" .. tostring(name) .. "' yet.")
        end
    end)
    frame:Show()
end

function MicroMenu:ActivateEchoBuildByName(buildName)
    buildName = TrimEchoBuildName(buildName)
    if not IsEchoBuildName(buildName) then
        RUI:Print("No valid Echo Saved Build was selected.")
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        RUI:Print("Echo builds cannot be swapped while in combat.")
        return false
    end

    self:StopEchoBuildRetry()
    self:StopEchoBuildConfirm()
    if self.StopEchoBuildDiscovery then self:StopEchoBuildDiscovery() end

    -- Primary path: use Ebonhold's own saved-build service directly. This works
    -- without opening Character Progression or constructing the Echo icon grid.
    local directBuilds, _, currentSlot, directAvailable = DirectEchoSavedBuilds(false)
    if directAvailable and directBuilds then
        local wanted = NormalizeProgressionLabel(buildName)
        local selected = nil
        for i = 1, #directBuilds do
            if NormalizeProgressionLabel(directBuilds[i].name) == wanted then
                selected = directBuilds[i]
                break
            end
        end
        if selected and selected.slot then
            if tonumber(currentSlot) == tonumber(selected.slot) then
                RUI:Print("Echo build already active: " .. tostring(selected.name) .. ".")
                return true
            end
            local bridge = EchoEbonAPIBridge()
            if bridge and type(bridge.ActivateBuildSlot) == "function" then
                if bridge:ActivateBuildSlot(selected.slot) then
                    self:StartEchoBuildConfirm(selected.slot, selected.name)
                    return true
                end
                RUI:Print("Ebonhold rejected the Echo build change. Try again once you are alive and out of combat.")
                return false
            end

            local service = EchoPerkService()
            if service and type(service.ActivateServerBuildSlot) == "function" then
                local ok, sent = pcall(service.ActivateServerBuildSlot, selected.slot)
                if not ok then
                    if RUI.RecordRuntimeError then RUI:RecordRuntimeError("echo", "ActivateServerBuildSlot", sent) end
                    RUI:Print("Ebonhold could not switch Echo builds: " .. tostring(sent))
                    return false
                end
                if sent then
                    self:StartEchoBuildConfirm(selected.slot, selected.name)
                    return true
                end
                RUI:Print("Ebonhold rejected the Echo build change. Try again once you are alive and out of combat.")
                return false
            end
        end
    end

    -- Compatibility fallback for older Ebonhold builds: click an already-loaded
    -- native Saved Builds row, preserving the previous ZenUI behavior.
    local builds = self:DiscoverEchoSavedBuilds(false)
    local wanted = NormalizeProgressionLabel(buildName)
    for i = 1, #builds do
        if NormalizeProgressionLabel(builds[i].name) == wanted and builds[i].button then
            if ClickButton(builds[i].button) then
                local bucket = GetEchoBuildCacheBucket(true)
                if bucket then bucket.current = builds[i].name end
                RUI:Print("Echo build selected: " .. tostring(builds[i].name) .. ".")
                return true
            end
        end
    end

    RUI:Print("Echo Saved Build '" .. tostring(buildName) .. "' is not available through Ebonhold's build service or a loaded native row.")
    return false
end

function MicroMenu:StopEchoBuildDiscovery()
    local frame = self.echoBuildDiscoveryFrame
    if not frame then return end
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
    frame.elapsed = 0
    frame.tick = 0
    frame.selectorClicked = false
    frame.openedProgression = false
end

function MicroMenu:StartEchoBuildDiscovery()
    if InCombatLockdown and InCombatLockdown() then return false end
    local frame = self.echoBuildDiscoveryFrame
    if frame and frame:IsShown() then return true end

    local wasOpen = FindVisibleProgressionWindow() ~= nil
    if not OpenEbonholdEchoes() then return false end

    if not frame then
        frame = CreateFrame("Frame")
        frame:Hide()
        self.echoBuildDiscoveryFrame = frame
    end
    frame.elapsed = 0
    frame.tick = 0
    frame.selectorClicked = false
    frame.openedProgression = not wasOpen
    frame:SetScript("OnUpdate", function(selfFrame, dt)
        selfFrame.elapsed = (selfFrame.elapsed or 0) + (dt or 0)
        selfFrame.tick = (selfFrame.tick or 0) + (dt or 0)
        if selfFrame.tick < 0.25 then return end
        selfFrame.tick = 0

        local builds = MicroMenu:DiscoverEchoSavedBuilds()
        local hasNative = false
        for i = 1, #builds do
            if builds[i].button then hasNative = true; break end
        end
        if hasNative and #builds > 0 then
            local shouldClose = selfFrame.openedProgression
            MicroMenu:StopEchoBuildDiscovery()
            if shouldClose and FindVisibleProgressionWindow() then CloseProgressionWindow() end
            MicroMenu:RefreshEchoBuildList(true, false)
            MicroMenu:PositionQuickMenu()
            return
        end

        if not selfFrame.selectorClicked then
            local root = FindVisibleProgressionWindow() or _G.ProjectEbonholdEmpowermentFrame
            local container = FindSavedBuildContainer()
            local selector = FindEchoBuildSelector(root, builds, container)
            if selector and ClickButton(selector) then
                selfFrame.selectorClicked = true
                return
            end
        end

        if selfFrame.elapsed >= 1.8 then
            local shouldClose = selfFrame.openedProgression
            MicroMenu:StopEchoBuildDiscovery()
            if shouldClose and FindVisibleProgressionWindow() then CloseProgressionWindow() end
            if MicroMenu.quickFrame and MicroMenu.quickFrame.echoEmpty then
                MicroMenu.quickFrame.echoEmpty:SetText("Open Echoes -> Saved Builds once")
            end
        end
    end)
    frame:Show()
    return true
end

function MicroMenu:RefreshEchoBuildList(silent, allowDiscovery)
    local builds, current, currentSlot, source = self:DiscoverEchoSavedBuilds(allowDiscovery == true)
    builds = builds or {}

    if self.quickFrame and self.quickFrame.echoRows then
        local rows = self.quickFrame.echoRows
        local count = math.min(#builds, #rows)
        for i = 1, #rows do
            local row = rows[i]
            local build = builds[i]
            if build then
                row.buildName = build.name
                row.buildSlot = build.slot
                row.buildVerified = build.verified == true
                row.buildDirect = build.direct == true
                local active = (currentSlot and build.slot and tonumber(currentSlot) == tonumber(build.slot))
                    or (current and NormalizeProgressionLabel(current) == NormalizeProgressionLabel(build.name))
                row.label:SetText((active and "|cffffcc00> |r" or "") .. build.name)
                row:Show()
            else
                row.buildName = nil
                row.buildSlot = nil
                row.buildVerified = nil
                row.buildDirect = nil
                row:Hide()
            end
        end
        if self.quickFrame.echoEmpty then
            if count == 0 then
                if source == "ebonapi" then
                    self.quickFrame.echoEmpty:SetText("No EbonAPI Saved Builds found")
                elseif source == "ebonapi-cache" then
                    self.quickFrame.echoEmpty:SetText("Waiting for EbonAPI Saved Builds")
                elseif source == "service" then
                    self.quickFrame.echoEmpty:SetText("No Ebonhold Saved Builds found")
                elseif source == "cache" then
                    self.quickFrame.echoEmpty:SetText("Waiting for Ebonhold Saved Builds")
                else
                    self.quickFrame.echoEmpty:SetText("No Saved Builds found")
                end
                self.quickFrame.echoEmpty:Show()
            else
                self.quickFrame.echoEmpty:Hide()
            end
        end
        self.quickFrame:SetHeight(232 + math.max(count, 1) * 27)
    end

    if not silent and #builds == 0 then
        if EchoEbonAPIBridge() then
            RUI:Print("EbonAPI is connected; waiting for Ebonhold's Saved Builds state.")
        elseif EchoPerkService() then
            RUI:Print("No Ebonhold Saved Builds are available yet. Refreshing the server build list.")
        else
            RUI:Print("Ebonhold's direct Saved Build service is unavailable; ZenUI will use its compatibility fallback.")
        end
    end
    return builds, current, currentSlot, source
end

function MicroMenu:RequestEchoBuildServiceRefresh()
    local bridge = EchoEbonAPIBridge()
    if bridge and type(bridge.RequestBuilds) == "function" then
        local requested = bridge:RequestBuilds()
        -- EbonAPI will push SERVER_BUILDS / SERVER_BUILD_ACTIVE back through
        -- OnEbonAPIBuildsUpdated. Refresh immediately too so cached sticky state
        -- is reflected without waiting for a round trip.
        if self.quickFrame and self.quickFrame:IsShown() then
            self:RefreshEchoBuildList(true, false)
            self:PositionQuickMenu()
        end
        return requested
    end

    local service = EchoPerkService()
    if not service or type(service.RequestServerBuildSlots) ~= "function" then return false end
    local ok, err = pcall(service.RequestServerBuildSlots)
    if not ok then
        if RUI.RecordRuntimeError then RUI:RecordRuntimeError("echo", "RequestServerBuildSlots", err) end
        return false
    end

    local frame = self.echoServiceRefreshFrame
    if not frame then
        frame = CreateFrame("Frame")
        frame:Hide()
        self.echoServiceRefreshFrame = frame
    end
    frame.elapsed = 0
    frame.tick = 0
    frame:SetScript("OnUpdate", function(selfFrame, dt)
        selfFrame.elapsed = (selfFrame.elapsed or 0) + (dt or 0)
        selfFrame.tick = (selfFrame.tick or 0) + (dt or 0)
        if selfFrame.tick < 0.20 then return end
        selfFrame.tick = 0
        if MicroMenu.quickFrame and MicroMenu.quickFrame:IsShown() then
            MicroMenu:RefreshEchoBuildList(true, false)
            MicroMenu:PositionQuickMenu()
        end
        if selfFrame.elapsed >= 1.2 then
            selfFrame:SetScript("OnUpdate", nil)
            selfFrame:Hide()
        end
    end)
    frame:Show()
    return true
end

function MicroMenu:OnEbonAPIBuildsUpdated()
    -- Consume the sticky normalized state immediately so the active marker and
    -- build list follow server events without opening/scanning Echoes.
    self:DiscoverEchoSavedBuilds(false)
    if self.quickFrame and self.quickFrame:IsShown() then
        self:RefreshEchoBuildList(true, false)
        self:PositionQuickMenu()
    end
end

function MicroMenu:PrintEchoHotSwapDoctor()
    local bridge = EchoEbonAPIBridge()
    if bridge then
        local builds, current, currentSlot, source = self:DiscoverEchoSavedBuilds(true)
        RUI:Print("Echo build doctor: source=" .. tostring(source or "ebonapi") .. " EbonAPI=" .. tostring(bridge:GetVersion() or "unknown") .. " discovered=" .. tostring(#builds) .. " current=" .. tostring(current or "unknown") .. " slot=" .. tostring(currentSlot or "?"))
        for i = 1, #builds do
            RUI:Print("- slot " .. tostring(builds[i].slot or "?") .. ": " .. tostring(builds[i].name))
        end
        return
    end

    OpenEbonholdEchoes()
    local container, score = FindSavedBuildContainer()
    if not container then
        RUI:Print("Echo build doctor: Saved Builds popup/container not found. Open the native Saved Builds dropdown and run this again.")
        return
    end
    local rootName = SafeObjectMember(container, "GetName")
    local name = type(rootName) == "function" and select(2, pcall(rootName, container)) or nil
    RUI:Print("Echo build doctor: container=" .. tostring(name or container) .. " score=" .. tostring(score))
    local builds, current, currentSlot, source = self:DiscoverEchoSavedBuilds(true)
    RUI:Print("Echo build doctor: source=" .. tostring(source or "unknown") .. " discovered=" .. tostring(#builds) .. " current=" .. tostring(current or "unknown") .. " slot=" .. tostring(currentSlot or "?"))
    for i = 1, #builds do
        RUI:Print("- " .. tostring(builds[i].name) .. (builds[i].button and " [native row]" or " [cached]"))
    end
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then return false end
    local ok, err = pcall(func, ...)
    if not ok then
        RUI:Print("Menu action failed: " .. tostring(err))
        return false
    end
    return true
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
    button:SetWidth(width or 32)
    button:SetHeight(height or 32)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    RUI:StyleButton(button)

    button.label = CreateText(button, label or "", 10, false)
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    return button
end

local function AnyBagOpen()
    if not IsBagOpen then return false end
    for bag = 0, 4 do
        if IsBagOpen(bag) then return true end
    end
    return false
end

function MicroMenu:GetSettings()
    if not RUI.db then return nil end
    RUI.db.menu = RUI.db.menu or {}
    return RUI.db.menu
end

function MicroMenu:CreateLauncher()
    local holder = CreateFrame("Frame", "ZenUIMicroMenuHolder", UIParent)
    holder:SetWidth(72)
    holder:SetHeight(34)
    holder:SetFrameStrata("MEDIUM")
    holder:EnableMouse(false)

    self.holder = holder

    self.menuButton = CreateButton(holder, "R", 34, 34)
    self.menuButton:SetPoint("LEFT", holder, "LEFT", 0, 0)
    self.menuButton.label.RUISize = 13
    local ar, ag, ab = RUI:GetAccentColor()
    RUI:StyleFontString(self.menuButton.label, 13, ar, ag, ab)
    self.menuButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("MENU") end
            MicroMenu:HideMenu()
        else
            MicroMenu:ToggleMenu()
        end
    end)
    self.menuButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("ZenUI", 1, 1, 1)
        GameTooltip:AddLine("Left-click: open Zen menu", 0.75, 0.78, 0.82)
        GameTooltip:AddLine("Right-click: menu settings", 0.75, 0.78, 0.82)
        GameTooltip:Show()
    end)
    self.menuButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.bagButton = CreateButton(holder, "", 34, 34)
    self.bagButton:SetPoint("LEFT", self.menuButton, "RIGHT", 4, 0)
    self.bagButton.icon = self.bagButton:CreateTexture(nil, "ARTWORK")
    self.bagButton.icon:SetPoint("TOPLEFT", self.bagButton, "TOPLEFT", 4, -4)
    self.bagButton.icon:SetPoint("BOTTOMRIGHT", self.bagButton, "BOTTOMRIGHT", -4, 4)
    self.bagButton.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    self.bagButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.bagButton.count = CreateText(self.bagButton, "", 9, false)
    self.bagButton.count:SetPoint("BOTTOMRIGHT", self.bagButton, "BOTTOMRIGHT", -3, 3)
    self.bagButton.count:SetJustifyH("RIGHT")
    self.bagButton:SetScript("OnClick", function(_, button)
        local bags = RUI:GetModule("Bags")
        if bags and bags.enabled and bags.Toggle then
            bags:Toggle()
            return
        end
        if button == "RightButton" then
            if AnyBagOpen() then
                if CloseAllBags then CloseAllBags() end
            else
                if OpenAllBags then OpenAllBags() elseif ToggleBackpack then ToggleBackpack() end
            end
        else
            if ToggleBackpack then ToggleBackpack() end
        end
    end)
    self.bagButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Bags", 1, 1, 1)
        GameTooltip:AddLine("Open / close unified bags", 0.75, 0.78, 0.82)
        GameTooltip:Show()
    end)
    self.bagButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    RUI:RegisterMover("MicroMenu", holder, {
        label = "Zen Menu / Bags",
        width = 72,
        height = 34,
        point = "BOTTOMRIGHT",
        relativePoint = "BOTTOMRIGHT",
        x = -22,
        y = 18,
    })
end

-- Lightweight floating shortcut panel.  It deliberately owns only fast,
-- low-risk toggles/actions; the full Zen menu remains the place for normal
-- navigation and configuration.
function MicroMenu:IsAutoInviteEnabled()
    local settings = RUI.db and RUI.db.groupTools
    return settings and settings.autoInvite == true or false
end

local function StyleQuickToggleRow(button, enabled)
    if not button then return end
    if enabled then
        local ar, ag, ab = RUI:GetAccentColor()
        if button.RUIActiveFill then
            button.RUIActiveFill:SetTexture(ar, ag, ab, 0.96)
            button.RUIActiveFill:Show()
        end
        RUI:SetBorderColor(button, ar, ag, ab, 1)
        if button.label then button.label:SetTextColor(0.04, 0.04, 0.04, 1) end
        if button.state then button.state:SetText("ON"); button.state:SetTextColor(0.04, 0.04, 0.04, 1) end
    else
        if button.RUIActiveFill then button.RUIActiveFill:Hide() end
        RUI:RefreshBackdrop(button)
        local tr, tg, tb = RUI:GetTextColor(false)
        local mr, mg, mb = RUI:GetTextColor(true)
        if button.label then button.label:SetTextColor(tr, tg, tb, 1) end
        if button.state then button.state:SetText("OFF"); button.state:SetTextColor(mr, mg, mb, 1) end
    end
end

function MicroMenu:CreateQuickMenu()
    local holder = CreateFrame("Frame", "ZenUIQuickMenuHolder", UIParent)
    holder:SetWidth(34)
    holder:SetHeight(34)
    holder:SetFrameStrata("MEDIUM")
    holder:EnableMouse(false)
    self.quickHolder = holder

    local button = CreateButton(holder, "Q", 34, 34)
    button:SetPoint("CENTER", holder, "CENTER", 0, 0)
    button.label.RUISize = 13
    self.quickButton = button

    button.status = button:CreateTexture(nil, "OVERLAY")
    button.status:SetWidth(7)
    button.status:SetHeight(7)
    button.status:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.status:Hide()

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("GROUPS") end
            MicroMenu:HideQuickMenu()
        else
            MicroMenu:ToggleQuickMenu()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Zen Quick Menu", 1, 1, 1)
        GameTooltip:AddLine("Left-click: group tools & Echo Saved Builds", 0.75, 0.78, 0.82)
        GameTooltip:AddLine("Right-click: Party & Raid settings", 0.75, 0.78, 0.82)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local frame = CreateFrame("Frame", "ZenUIQuickMenuPopup", UIParent)
    frame:SetWidth(240)
    frame:SetHeight(347)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(3100)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    RUI:CreateBackdrop(frame)
    frame.accent = RUI:CreateAccentLine(frame, 2)
    self.quickFrame = frame

    -- Wrath/Ebonhold does not reliably place child Frames above textures owned
    -- by a very high-level parent Frame.  The Quick Menu popup lives at a high
    -- TOOLTIP frame level so it can sit above secure action buttons; without an
    -- explicit child level its own RUIBackground can therefore paint over the
    -- interactive rows.  Direct font strings (title/subtitle) remain visible,
    -- which made the controls look like black-on-black/empty rows.
    local quickControlLevel = frame:GetFrameLevel() + 10
    local function LiftQuickControl(control)
        if control and control.SetFrameLevel then
            control:SetFrameLevel(quickControlLevel)
        end
        return control
    end

    frame.title = CreateText(frame, "QUICK MENU", 11, false)
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -13)
    frame.subtitle = CreateText(frame, "Fast tools & Echo builds", 8, true)
    frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 8, 0)

    frame.close = LiftQuickControl(CreateButton(frame, "X", 22, 20))
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -7)
    frame.close:SetScript("OnClick", function() MicroMenu:HideQuickMenu() end)

    local auto = LiftQuickControl(CreateFrame("Button", nil, frame))
    auto:SetWidth(216)
    auto:SetHeight(32)
    auto:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -42)
    auto:EnableMouse(true)
    auto:RegisterForClicks("LeftButtonUp")
    RUI:StyleButton(auto)
    -- This must be above the backdrop texture. BACKGROUND put the accent fill
    -- behind Zen's button backdrop, leaving the ON state's dark text on a
    -- visually black row. ARTWORK keeps the fill visible below OVERLAY text.
    auto.RUIActiveFill = auto:CreateTexture(nil, "ARTWORK")
    auto.RUIActiveFill:SetPoint("TOPLEFT", auto, "TOPLEFT", 1, -1)
    auto.RUIActiveFill:SetPoint("BOTTOMRIGHT", auto, "BOTTOMRIGHT", -1, 1)
    auto.RUIActiveFill:Hide()
    auto.label = CreateText(auto, "Auto Invite", 10, false)
    auto.label:SetPoint("LEFT", auto, "LEFT", 10, 0)
    auto.state = CreateText(auto, "OFF", 9, true)
    auto.state:SetWidth(34)
    auto.state:SetJustifyH("RIGHT")
    auto.state:SetPoint("RIGHT", auto, "RIGHT", -9, 0)
    auto:SetScript("OnClick", function()
        local panels = RUI:GetModule("BlizzardFrames")
        if panels and panels.SetAutoInviteEnabled then
            panels:SetAutoInviteEnabled(not MicroMenu:IsAutoInviteEnabled())
        else
            RUI:Print("Auto Invite is not available yet.")
        end
        MicroMenu:RefreshQuickMenuState()
    end)
    auto:SetScript("OnEnter", function(self)
        local ar, ag, ab = RUI:GetAccentColor()
        if not MicroMenu:IsAutoInviteEnabled() and self.RUIHighlight then
            self.RUIHighlight:SetTexture(ar, ag, ab, 0.12)
            self.RUIHighlight:Show()
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Auto Invite", 1, 1, 1)
        GameTooltip:AddLine("When ON, configured whisper triggers automatically queue an invite for the sender. Edit triggers in /zenui > Auto Invite.", 0.75, 0.78, 0.82, true)
        GameTooltip:Show()
    end)
    auto:SetScript("OnLeave", function(self)
        if self.RUIHighlight then self.RUIHighlight:Hide() end
        GameTooltip:Hide()
    end)
    frame.autoInvite = auto

    frame.ready = LiftQuickControl(CreateButton(frame, "Ready Check", 104, 28))
    frame.ready:SetPoint("TOPLEFT", auto, "BOTTOMLEFT", 0, -10)
    frame.ready:SetScript("OnClick", function()
        local panels = RUI:GetModule("BlizzardFrames")
        local raidFrame = panels and panels.frames and panels.frames.raid
        if raidFrame and raidFrame.ready and raidFrame.ready.Click then
            raidFrame.ready:Click()
        elseif type(DoReadyCheck) == "function" then
            local ok, err = pcall(DoReadyCheck)
            if not ok then RUI:Print("Ready Check failed: " .. tostring(err)) end
        else
            RUI:Print("Ready Check is not available on this client.")
        end
        MicroMenu:HideQuickMenu()
    end)

    frame.raid = LiftQuickControl(CreateButton(frame, "Raid / Group", 104, 28))
    frame.raid:SetPoint("TOPRIGHT", auto, "BOTTOMRIGHT", 0, -10)
    frame.raid:SetScript("OnClick", function()
        local panels = RUI:GetModule("BlizzardFrames")
        if panels and panels.ToggleRaid then panels:ToggleRaid(true) end
        MicroMenu:HideQuickMenu()
    end)

    frame.callboard = LiftQuickControl(CreateButton(frame, "Callboard Tracker", 216, 26))
    frame.callboard:SetPoint("TOPLEFT", frame.ready, "BOTTOMLEFT", 0, -9)
    frame.callboard:SetScript("OnClick", function()
        local tracker = RUI:GetModule("CallboardTracker")
        MicroMenu:HideQuickMenu()
        if tracker and tracker.Toggle then tracker:Toggle() else RUI:Print("Callboard Tracker is unavailable.") end
    end)
    frame.callboard:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Callboard Tracker", 1, 1, 1)
        GameTooltip:AddLine("Board cooldown history and Level 80 raid-save status.", 0.75, 0.78, 0.82, true)
        GameTooltip:Show()
    end)
    frame.callboard:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.echoLabel = CreateText(frame, "ECHO SAVED BUILDS", 8, true)
    frame.echoLabel:SetPoint("TOPLEFT", frame.callboard, "BOTTOMLEFT", 0, -12)

    frame.echoRefresh = LiftQuickControl(CreateButton(frame, "Refresh Echo Builds", 216, 22))
    frame.echoRefresh:SetPoint("TOPLEFT", frame.echoLabel, "BOTTOMLEFT", 0, -7)
    frame.echoRefresh:SetScript("OnClick", function()
        -- Request Ebonhold's authoritative server-side saved-build slots. This
        -- does not open Character Progression or initialize the heavy Echo UI.
        MicroMenu:RequestEchoBuildServiceRefresh()
        local builds = MicroMenu:RefreshEchoBuildList(false, false)
        if builds and #builds > 0 then
            RUI:Print("Found " .. tostring(#builds) .. " Echo Saved Build(s).")
        end
        MicroMenu:PositionQuickMenu()
    end)

    frame.echoRows = {}
    for i = 1, ECHO_BUILD_MAX do
        local row = LiftQuickControl(CreateButton(frame, "", 216, 24))
        if i == 1 then
            row:SetPoint("TOPLEFT", frame.echoRefresh, "BOTTOMLEFT", 0, -4)
        else
            row:SetPoint("TOPLEFT", frame.echoRows[i - 1], "BOTTOMLEFT", 0, -3)
        end
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 9, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -9, 0)
        row.label:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self)
            local buildName = self.buildName
            if not buildName then return end
            MicroMenu:HideQuickMenu()
            MicroMenu:ActivateEchoBuildByName(buildName)
        end)
        row:SetScript("OnEnter", function(self)
            if not self.buildName then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.buildName, 1, 1, 1)
            GameTooltip:AddLine("Ebonhold Saved Build", 0.75, 0.78, 0.82)
            if self.buildSlot then GameTooltip:AddLine("Server slot " .. tostring(self.buildSlot), 0.55, 0.58, 0.62) end
            GameTooltip:AddLine("Click to activate this build through Ebonhold's saved-build service.", 0.75, 0.78, 0.82, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:Hide()
        frame.echoRows[i] = row
    end

    frame.echoEmpty = CreateText(frame, "No Saved Builds discovered yet", 9, true)
    frame.echoEmpty:SetWidth(216)
    frame.echoEmpty:SetJustifyH("LEFT")
    frame.echoEmpty:SetPoint("TOPLEFT", frame.echoRefresh, "BOTTOMLEFT", 4, -8)
    frame.echoEmpty:Hide()

    frame.settings = LiftQuickControl(CreateButton(frame, "Party & Raid Settings", 216, 26))
    frame.settings:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame.settings:SetScript("OnClick", function()
        local config = RUI:GetModule("Config")
        if config and config.ShowPage then config:ShowPage("GROUPS") end
        MicroMenu:HideQuickMenu()
    end)

    RUI:RegisterMover("QuickMenu", holder, {
        label = "Zen Quick Menu",
        groups = { menu = true },
        width = 34,
        height = 34,
        point = "BOTTOMRIGHT",
        relativePoint = "BOTTOMRIGHT",
        x = -104,
        y = 18,
    })
end

function MicroMenu:PositionQuickMenu()
    local frame, holder = self.quickFrame, self.quickHolder
    if not frame or not holder then return end
    frame:ClearAllPoints()

    local hx, hy = holder:GetCenter()
    local ux, uy = UIParent:GetCenter()
    hx, hy, ux, uy = hx or 0, hy or 0, ux or 0, uy or 0

    local above = hy <= uy
    local leftSide = hx <= ux
    if above and leftSide then
        frame:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 0, 8)
    elseif above then
        frame:SetPoint("BOTTOMRIGHT", holder, "TOPRIGHT", 0, 8)
    elseif leftSide then
        frame:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -8)
    else
        frame:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -8)
    end
end

function MicroMenu:RefreshQuickMenuState(allowEchoDiscovery)
    -- Keep the interactive controls above the popup's backdrop.  Some Wrath
    -- clients can reset/recompute child levels when a high-level TOOLTIP frame
    -- is raised, so reassert the relationship on every state refresh.
    if self.quickFrame then
        local level = self.quickFrame:GetFrameLevel() + 10
        local controls = { self.quickFrame.close, self.quickFrame.autoInvite, self.quickFrame.ready, self.quickFrame.raid, self.quickFrame.callboard, self.quickFrame.echoRefresh, self.quickFrame.settings }
        for i = 1, #controls do
            local control = controls[i]
            if control and control.SetFrameLevel then control:SetFrameLevel(level) end
        end
        for i = 1, #(self.quickFrame.echoRows or {}) do
            local control = self.quickFrame.echoRows[i]
            if control and control.SetFrameLevel then control:SetFrameLevel(level) end
        end
    end

    local enabled = self:IsAutoInviteEnabled()
    if self.quickFrame and self.quickFrame.autoInvite then
        StyleQuickToggleRow(self.quickFrame.autoInvite, enabled)
    end
    self:RefreshEchoBuildList(true, allowEchoDiscovery == true)
    if self.quickButton and self.quickButton.status then
        if enabled then
            local ar, ag, ab = RUI:GetAccentColor()
            self.quickButton.status:SetTexture(ar, ag, ab, 1)
            self.quickButton.status:Show()
            RUI:SetBorderColor(self.quickButton, ar, ag, ab, 1)
        else
            self.quickButton.status:Hide()
            RUI:RefreshBackdrop(self.quickButton)
        end
    end
end

function MicroMenu:ToggleQuickMenu()
    if not self.quickFrame or not self.quickHolder or not self.quickHolder:IsShown() then return end
    if self.quickFrame:IsShown() then
        self:HideQuickMenu()
        return
    end
    self:HideMenu()
    -- Opening Q stays lightweight: request Ebonhold's saved-build service, but
    -- never initialize the heavy native Echoes page just to populate this menu.
    self:RequestEchoBuildServiceRefresh()
    self:RefreshQuickMenuState(false)
    self:PositionQuickMenu()
    self.quickFrame:SetFrameStrata("TOOLTIP")
    self.quickFrame:SetFrameLevel(3100)
    self.quickFrame:Show()
    if self.quickFrame.Raise then self.quickFrame:Raise() end
end

function MicroMenu:HideQuickMenu()
    if self.quickFrame then self.quickFrame:Hide() end
end

function MicroMenu:OnMoverModeChanged(enabled)
    if enabled then self:HideQuickMenu() end
end

function MicroMenu:CreateMenuFrame()
    local frame = CreateFrame("Frame", "ZenUIMicroMenuPopup", UIParent)
    frame:SetWidth(330)
    frame:SetHeight(320)
    -- The popup must sit above hidden/mouseover action-button footprints and
    -- any other interactive Zen layers.  DIALOG was visually high enough
    -- but could still lose mouse hit-testing to higher-strata secure frames.
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(3000)
    if frame.SetToplevel then frame:SetToplevel(true) end
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    RUI:CreateBackdrop(frame)
    frame.accent = RUI:CreateAccentLine(frame, 2)

    frame.title = CreateText(frame, "ZEN", 12, false)
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -14)
    frame.subtitle = CreateText(frame, "UI & system menu", 9, true)
    frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 8, 0)

    frame.close = CreateButton(frame, "X", 24, 22)
    frame.close:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.close:EnableMouse(true)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    frame.close:SetScript("OnClick", function() MicroMenu:HideMenu() end)

    frame.buttons = {}
    frame.headers = {}
    self.menuFrame = frame
end

local function SetEbonholdLauncherHidden(button, hidden)
    if not IsButtonObject(button) then return end
    if button.RUIEbonholdOriginalAlpha == nil then
        button.RUIEbonholdOriginalAlpha = button.GetAlpha and button:GetAlpha() or 1
    end
    if hidden then
        if button.SetAlpha then button:SetAlpha(0) end
        if button.EnableMouse then button:EnableMouse(false) end
    else
        if button.SetAlpha then button:SetAlpha(button.RUIEbonholdOriginalAlpha or 1) end
        if button.EnableMouse then button:EnableMouse(true) end
    end
end

function MicroMenu:DiscoverEbonholdMicroButton(force)
    local current = self.ebonholdMicroButton
    if IsButtonObject(current) then return current end

    -- Check only names that may represent the Character Progression launcher.
    -- Do NOT include SkillTreeMicroButton-style names here: those open the Skill
    -- Tree tab directly and are not equivalent to the native progression button,
    -- whose default destination is Echoes.
    for i = 1, #EBONHOLD_BUTTON_NAMES do
        local candidate = _G[EBONHOLD_BUTTON_NAMES[i]]
        if IsButtonObject(candidate) then
            self.ebonholdMicroButton = candidate
            self.ebonholdMicroButtonName = EBONHOLD_BUTTON_NAMES[i]
            break
        end
    end

    -- Then find the Character Progression launcher even when Ebonhold creates it
    -- without a useful global name. It normally lives on/near the stock micro or
    -- bag strip and advertises itself with the stable "Character Progression"
    -- tooltip shown by the Ebonhold client.
    local now = (GetTime and GetTime()) or 0
    local canBroadScan = _G.ProjectEbonhold or _G.ProjectEbonholdEmpowermentFrame or _G.skillTreeFrame
    if not self.ebonholdMicroButton and (canBroadScan or force) and (force or not self.ebonholdLastScan or now == 0 or (now - self.ebonholdLastScan) >= 0.5) then
        self.ebonholdLastScan = now
        local best, bestName, bestScore = nil, nil, 0
        local candidates, seen = {}, {}

        -- Named globals catch the common builds.
        for name, value in pairs(_G) do
            if type(name) == "string" and not NATIVE_CONTROL_LOOKUP[name] and IsButtonObject(value) and not IsZenFrame(value) then
                candidates[#candidates + 1] = value
                seen[value] = name
            end
        end

        -- Ebonhold has also shipped this launcher as an unnamed child. Walk only
        -- the main action-bar hierarchy so discovery stays cheap and predictable.
        local roots = { _G.MainMenuBar, _G.MainMenuBarArtFrame }
        local rootSeen = {}
        for i = 1, #roots do if roots[i] then rootSeen[roots[i]] = true end end
        local backpack = _G.MainMenuBarBackpackButton
        if backpack and backpack.GetParent then
            local parent = backpack:GetParent()
            if parent and not rootSeen[parent] then roots[#roots + 1] = parent; rootSeen[parent] = true end
        end

        -- Newer Ebonhold builds place Character Progression inside their own
        -- mini/run bar rather than directly under Blizzard's MainMenuBar. Add
        -- likely Ebonhold/progression container globals as local scan roots so
        -- unnamed child buttons are still discoverable without walking all of
        -- UIParent every half-second.
        for name, value in pairs(_G) do
            if type(name) == "string" and IsFrameObject(value) and type(SafeObjectMember(value, "GetChildren")) == "function" and not IsZenFrame(value) then
                local lower = string.lower(name)
                if string.find(lower, "ebonhold", 1, true)
                    or string.find(lower, "progress", 1, true)
                    or string.find(lower, "minirun", 1, true)
                    or string.find(lower, "runframe", 1, true) then
                    if not rootSeen[value] then roots[#roots + 1] = value; rootSeen[value] = true end
                end
            end
        end
        for i = 1, #roots do AddChildButtons(roots[i], candidates, seen, 0) end

        -- The live Ebonhold Character Progression launcher can live on a
        -- completely separate action-bar frame. When the scoped roots above do
        -- not catch it, walk the visible UI hierarchy and add small clickable
        -- controls as candidates. The native tooltip is the final authority, so
        -- this does not depend on the launcher being related to MainMenuBar.
        if _G.UIParent and type(_G.UIParent.GetChildren) == "function" then
            local uiCandidates, uiSeen = {}, {}
            AddChildButtons(_G.UIParent, uiCandidates, uiSeen, 0)
            for i = 1, #uiCandidates do
                local child = uiCandidates[i]
                if child and not seen[child] and not IsZenFrame(child) then
                    local shown = not child.IsShown or child:IsShown()
                    local width = child.GetWidth and tonumber(child:GetWidth()) or 0
                    local height = child.GetHeight and tonumber(child:GetHeight()) or 0
                    if shown and width >= 12 and height >= 12 and width <= 96 and height <= 96 then
                        seen[child] = true
                        candidates[#candidates + 1] = child
                    end
                end
            end
        end

        for i = 1, #candidates do
            local value = candidates[i]
            local name = value.GetName and value:GetName() or seen[value]
            name = type(name) == "string" and name or ""
            if not NATIVE_CONTROL_LOOKUP[name] then
                local lower = string.lower(name)
                local score = 0
                if string.find(lower, "progress", 1, true) then score = score + 14 end
                if string.find(lower, "microbutton", 1, true) then score = score + 6 end
                if string.find(lower, "ebon", 1, true) or string.find(lower, "project", 1, true) then score = score + 7 end
                if string.find(lower, "skill", 1, true) or string.find(lower, "soul", 1, true) or string.find(lower, "echo", 1, true) then score = score + 4 end
                if IsMicroBarParent(value) then score = score + 4 end
                if IsAnchoredToNativeControl(value) then score = score + 8 end
                local click = value.GetScript and value:GetScript("OnClick")
                if type(click) == "function" then score = score + 2 end

                -- The exact native tooltip is authoritative. Probe only small
                -- visible controls (or strongly named candidates) so discovery
                -- cannot fire arbitrary hidden UI OnEnter handlers across _G.
                local shown = not value.IsShown or value:IsShown()
                local width = value.GetWidth and tonumber(value:GetWidth()) or 0
                local height = value.GetHeight and tonumber(value:GetHeight()) or 0
                local smallVisible = shown and width >= 12 and height >= 12 and width <= 96 and height <= 96
                if (smallVisible or score >= 6) and ProgressionTooltipMatch(value) then score = score + 100 end
                if score > bestScore and score >= 12 then
                    best, bestName, bestScore = value, (name ~= "" and name or "unnamed Character Progression"), score
                end
            end
        end
        self.ebonholdMicroButton = best
        self.ebonholdMicroButtonName = bestName
    end

    local button = self.ebonholdMicroButton
    if button and not button.RUIEbonholdHooked and button.HookScript then
        button.RUIEbonholdHooked = true
        if button.RUIEbonholdOriginalAlpha == nil then
            button.RUIEbonholdOriginalAlpha = button.GetAlpha and button:GetAlpha() or 1
        end
        button:HookScript("OnShow", function(self)
            local settings = RUI.db and RUI.db.menu
            if settings and settings.enabled ~= false and settings.hideBlizzard ~= false then
                SetEbonholdLauncherHidden(self, true)
            end
        end)
        button:HookScript("OnEnable", function(self)
            local settings = RUI.db and RUI.db.menu
            if settings and settings.enabled ~= false and settings.hideBlizzard ~= false then
                SetEbonholdLauncherHidden(self, true)
            end
        end)
        RUI:Debug("Integrated Ebonhold micro button: " .. tostring(self.ebonholdMicroButtonName or "unnamed"))
    end
    return button
end

function MicroMenu:GetProgressionBindings()
    return PROGRESSION_BINDINGS
end

function MicroMenu:OpenEbonholdProgressionPage(page, quiet)
    local label = CanonicalProgressionPage(page)
    if not label then
        if not quiet then RUI:Print("Unknown Character Progression page: " .. tostring(page)) end
        return false
    end

    -- Page keybinds are true toggles. Pressing the same shortcut again while
    -- that Ebonhold progression page is open closes the whole progression
    -- window. A different progression shortcut still switches pages normally.
    local visibleProgression = FindVisibleProgressionWindow()
    if visibleProgression and IsProgressionPageActive(label) then
        return CloseProgressionWindow()
    end

    -- On this Ebonhold build the native Character Progression launcher is not
    -- always discoverable until Zen's own micro menu has been built/shown
    -- once.  A hardware keybind therefore worked only while that menu happened
    -- to be open.  Reproduce that initialization context invisibly so bindings
    -- work from normal gameplay without making the player open Zen first.
    local primedMenu = false
    local frame = self.menuFrame
    local oldAlpha
    if frame and not frame:IsShown() and self.holder then
        self:RebuildMenu()
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMRIGHT", self.holder, "TOPRIGHT", 0, 8)
        frame:SetFrameStrata("TOOLTIP")
        frame:SetFrameLevel(3000)
        oldAlpha = frame.GetAlpha and frame:GetAlpha() or 1
        if frame.SetAlpha then frame:SetAlpha(0) end
        frame:Show()
        primedMenu = true
    end

    -- Force a fresh launcher scan after the menu has been primed.  The normal
    -- discovery path is throttled for performance; a deliberate key press must
    -- not be lost merely because a background scan ran a fraction of a second
    -- earlier before Ebonhold finished creating its controls.
    self:DiscoverEbonholdMicroButton(true)
    local opened = OpenEbonholdProgressionPage(label)

    if primedMenu then
        frame:Hide()
        if frame.SetAlpha then frame:SetAlpha(oldAlpha or 1) end
    end

    if opened then return true end
    if not quiet then RUI:Print("Character Progression page '" .. label .. "' is not available yet.") end
    return false
end

-- Bindings.xml executes this global from the user's hardware key press. Keeping
-- the page selection inside that event is also the safest path for Ebonhold UI
-- controls that expect a real click/key interaction.
function ZenUI_OpenProgressionPage(page)
    local module = ZenUI and ZenUI.GetModule and ZenUI:GetModule("MicroMenu")
    if module and module.OpenEbonholdProgressionPage then
        return module:OpenEbonholdProgressionPage(page)
    end
end

function ZenUI_ToggleProgression()
    local module = ZenUI and ZenUI.GetModule and ZenUI:GetModule("MicroMenu")
    if module and module.ToggleEbonholdMenuAction then
        return module:ToggleEbonholdMenuAction()
    end
end

-- Compatibility for the pre-ZenUI standalone hotkey addon.
_G.RavioliUI_OpenProgressionPage = _G.RavioliUI_OpenProgressionPage or ZenUI_OpenProgressionPage

function MicroMenu:HasEbonholdMenuAction()
    if self:DiscoverEbonholdMicroButton() then return true end
    if _G.ProjectEbonholdEmpowermentFrame or _G.skillTreeFrame then return true end
    local pe = _G.ProjectEbonhold
    return pe and pe.SkillTree and true or false
end

function MicroMenu:GetEbonholdMenuLabel()
    return "Character Progression"
end

function MicroMenu:ToggleEbonholdMenuAction()
    if FindVisibleProgressionWindow() then return CloseProgressionWindow() end

    -- Preferred path: execute the exact native Character Progression click.
    -- The real launcher opens Character Progression on Echoes by default.
    local button = self:DiscoverEbonholdMicroButton()
    if button and ClickButton(button) then
        ScheduleProgressionPage("Echoes")
        return true
    end

    -- Do not fall back to Skill Tree as the destination. If the launcher cannot
    -- be resolved, explicitly open/select Echoes so the Zen entry always
    -- matches the native Character Progression button shown by Ebonhold.
    if OpenEbonholdEchoes() then return true end

    RUI:Print("Character Progression is not available yet.")
    return false
end

local function ToggleNativeGameMenuPanel()
    -- Do not call ToggleGameMenu() from addon code on this Ebonhold client.
    -- Its Escape-style cleanup path calls protected targeting/casting actions
    -- and triggers the blocked-action popup. Showing the native panel itself
    -- is the part we actually want from a menu button and is not that cleanup.
    if not GameMenuFrame then return end
    if GameMenuFrame:IsShown() then
        if HideUIPanel then pcall(HideUIPanel,GameMenuFrame) end
        if GameMenuFrame:IsShown() then GameMenuFrame:Hide() end
        return
    end
    if UIParent and UIParent.IsShown and not UIParent:IsShown() then
        UIParent:Show()
        if SetUIVisibility then pcall(SetUIVisibility,true) end
    end
    if ShowUIPanel then pcall(ShowUIPanel,GameMenuFrame) end
    if not GameMenuFrame:IsShown() then GameMenuFrame:Show() end
end

function MicroMenu:GetBuiltInEntries()
    -- Call Zen modules directly instead of routing the Q menu through Blizzard
    -- globals that can become taint-sensitive during combat. Native functions
    -- remain as fallbacks only when the corresponding Zen replacement is not
    -- available/enabled.
    local entries = {
        { name = "Character", action = function()
            local m=RUI:GetModule("BlizzardPhaseB")
            if m and m.ToggleCharacter then m:ToggleCharacter("PaperDollFrame") elseif ToggleCharacter then ToggleCharacter("PaperDollFrame") end
        end },
        { name = "Spellbook", action = function()
            local m=RUI:GetModule("BlizzardFrames")
            if m and m.ToggleSpellbook then m:ToggleSpellbook(BOOKTYPE_SPELL or "spell") elseif ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL) end
        end },
        { name = "Talents", action = function()
            local m=RUI:GetModule("BlizzardPhaseC")
            if m and m.Toggle then m:Toggle() elseif ToggleTalentFrame then ToggleTalentFrame() end
        end },
    }
    if self:HasEbonholdMenuAction() then
        table.insert(entries, { name = self:GetEbonholdMenuLabel(), action = function() MicroMenu:ToggleEbonholdMenuAction() end })
    end
    local tail = {
        { name = "Achievements", action = function()
            local m=RUI:GetModule("BlizzardPhaseCAchievements")
            if m and m.Toggle then m:Toggle("achievements") elseif ToggleAchievementFrame then ToggleAchievementFrame() end
        end },
        { name = "Quest Log", action = function()
            local m=RUI:GetModule("BlizzardPhaseB")
            if m and m.ToggleQuestLog then m:ToggleQuestLog() elseif QuestLogFrame and ToggleFrame then ToggleFrame(QuestLogFrame) elseif ToggleQuestLog then ToggleQuestLog() end
        end },
        { name = "Social", action = function()
            local m=RUI:GetModule("BlizzardFrames")
            if m and m.ToggleSocial then m:ToggleSocial(false,"friends") elseif ToggleFriendsFrame then ToggleFriendsFrame() end
        end },
        { name = "PvP", action = function()
            local m=RUI:GetModule("BlizzardPhaseCPvP")
            if m and m.Toggle then m:Toggle() elseif TogglePVPFrame then TogglePVPFrame() end
        end },
        { name = "Dungeon Finder", action = function()
            local m=RUI:GetModule("BlizzardFrames")
            if m and m.ToggleDungeonFinder then m:ToggleDungeonFinder(false) elseif ToggleLFDParentFrame then ToggleLFDParentFrame() end
        end },
        { name = "ZenUI Settings", action = function()
            local config = RUI:GetModule("Config")
            if config and config.Show then config:Show() end
        end },
        { name = "Game Menu", action = ToggleNativeGameMenuPanel },
        { name = "Help", action = function() if ToggleHelpFrame then ToggleHelpFrame() end end },
    }
    for i = 1, #tail do table.insert(entries, tail[i]) end
    return entries
end

function MicroMenu:GetCompanionEntries()
    local list = {}
    for id, data in pairs(RUI.registeredAddons or {}) do
        table.insert(list, { id = id, data = data })
    end
    table.sort(list, function(a, b)
        local ao = tonumber(a.data.order) or 100
        local bo = tonumber(b.data.order) or 100
        if ao == bo then return tostring(a.data.name or a.id) < tostring(b.data.name or b.id) end
        return ao < bo
    end)
    return list
end

function MicroMenu:GetMenuButton(index)
    local frame = self.menuFrame
    if frame.buttons[index] then return frame.buttons[index] end

    -- Keep menu entries ordinary buttons. SecureActionButtonTemplate makes the
    -- popup's children protected, which prevents Zen from laying out/showing
    -- the menu after combat lockdown begins. Protected actions are handled by
    -- their own native panel paths rather than making the whole menu protected.
    local button = CreateFrame("Button", nil, frame)
    button:SetWidth(144); button:SetHeight(26)
    button:EnableMouse(true); button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    RUI:StyleButton(button)
    button.label = CreateText(button, "", 10, false)
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button:SetFrameLevel(frame:GetFrameLevel() + 20)
    button:EnableMouse(true)
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.label:SetJustifyH("LEFT")
    button:SetScript("OnEnter", function(self)
        local ar, ag, ab = RUI:GetAccentColor()
        if self.RUIHighlight then self.RUIHighlight:SetTexture(ar, ag, ab, 0.12); self.RUIHighlight:Show() end
        if self.tooltipTitle then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipTitle, 1, 1, 1)
            if self.tooltipText then GameTooltip:AddLine(self.tooltipText, 0.75, 0.78, 0.82, true) end
            if self.tooltipConfig then GameTooltip:AddLine("Right-click: configuration", 0.75, 0.78, 0.82) end
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        if self.RUIHighlight then self.RUIHighlight:Hide() end
        GameTooltip:Hide()
    end)
    frame.buttons[index] = button
    return button
end

function MicroMenu:RebuildMenu()
    local frame = self.menuFrame
    if not frame then return end
    self:DiscoverEbonholdMicroButton()

    for i = 1, #frame.buttons do frame.buttons[i]:Hide() end
    for i = 1, #frame.headers do frame.headers[i]:Hide() end

    local settings = self:GetSettings() or {}
    local builtins = self:GetBuiltInEntries()
    local companions = self:GetCompanionEntries()
    local buttonIndex = 0
    local headerIndex = 0
    local y = -50

    local function AddHeader(text)
        headerIndex = headerIndex + 1
        local header = frame.headers[headerIndex]
        if not header then
            header = CreateText(frame, "", 8, true)
            frame.headers[headerIndex] = header
        end
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
        header:SetText(text)
        header:Show()
        y = y - 18
    end

    local function AddEntries(entries, companion)
        local count = #entries
        local rows = math.ceil(count / 2)
        for i = 1, count do
            buttonIndex = buttonIndex + 1
            local button = self:GetMenuButton(buttonIndex)
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (col * 158), y - (row * 32))
            button:Show()

            if companion then
                local entry = entries[i]
                local data = entry.data
                button.label:SetText(data.name or entry.id)
                button.tooltipTitle = data.name or entry.id
                button.tooltipText = data.tooltip and tostring(data.tooltip) or nil
                button.tooltipConfig = data.OnConfig and true or false
                button:SetScript("OnClick", function(_, mouseButton)
                    local callback
                    if mouseButton == "RightButton" then callback = data.OnConfig or data.OnClick else callback = data.OnClick or data.OnConfig end
                    if callback then SafeCall(callback, data) end
                    if settings.closeOnClick ~= false then MicroMenu:HideMenu() end
                end)
            else
                local entry = entries[i]
                button.label:SetText(entry.name)
                button.tooltipTitle = nil
                button.tooltipText = nil
                button.tooltipConfig = nil

                button:SetScript("OnClick", function()
                    if entry.action then SafeCall(entry.action) end
                    if settings.closeOnClick ~= false then MicroMenu:HideMenu() end
                end)
            end
        end
        y = y - (rows * 32)
    end

    AddHeader("WORLD OF WARCRAFT")
    AddEntries(builtins, false)

    if #companions > 0 then
        y = y - 2
        AddHeader("ZEN ADDONS")
        AddEntries(companions, true)
    end

    local contentHeight = math.abs(y) + 12
    if contentHeight < 248 then contentHeight = 248 end
    if contentHeight > 500 then contentHeight = 500 end
    frame:SetHeight(contentHeight)
    self:RefreshAppearance()
end

function MicroMenu:ToggleMenu()
    if not self.menuFrame then return end
    if self.menuFrame:IsShown() then
        self:HideMenu()
    else
        self:RebuildMenu()
        self.menuFrame:ClearAllPoints()
        self.menuFrame:SetPoint("BOTTOMRIGHT", self.holder, "TOPRIGHT", 0, 8)
        self.menuFrame:SetFrameStrata("TOOLTIP")
        self.menuFrame:SetFrameLevel(3000)
        self.menuFrame:Show()
        if self.menuFrame.Raise then self.menuFrame:Raise() end
    end
end

function MicroMenu:HideMenu()
    if self.menuFrame then self.menuFrame:Hide() end
end

function MicroMenu:CountFreeSlots()
    if not GetContainerNumSlots or not GetContainerItemInfo then return nil end
    local free = 0
    local total = 0
    for bag = 0, 4 do
        local slots = tonumber(GetContainerNumSlots(bag)) or 0
        total = total + slots
        for slot = 1, slots do
            local texture = GetContainerItemInfo(bag, slot)
            if not texture then free = free + 1 end
        end
    end
    return free, total
end

function MicroMenu:UpdateBagCount()
    if not self.bagButton or not self.bagButton.count then return end
    local settings = self:GetSettings() or {}
    if settings.showFreeSlots == false or settings.showBagButton == false then
        self.bagButton.count:SetText("")
        return
    end
    local free = self:CountFreeSlots()
    if free then self.bagButton.count:SetText(tostring(free)) else self.bagButton.count:SetText("") end
end

function MicroMenu:InstallNativeHooks()
    if self.nativeHooksInstalled then return end
    self.nativeHooksInstalled = true

    for i = 1, #NATIVE_CONTROLS do
        local control = _G[NATIVE_CONTROLS[i]]
        if control and control.HookScript then
            control:HookScript("OnShow", function(self)
                local settings = RUI.db and RUI.db.menu
                if settings and settings.hideBlizzard ~= false then
                    self:SetAlpha(0)
                    self:EnableMouse(false)
                end
            end)
            control:HookScript("OnEnable", function(self)
                local settings = RUI.db and RUI.db.menu
                if settings and settings.hideBlizzard ~= false then
                    self:SetAlpha(0)
                    self:EnableMouse(false)
                end
            end)
        end
    end
    self:DiscoverEbonholdMicroButton()
end

function MicroMenu:ApplyNativeVisibility()
    local settings = self:GetSettings() or {}
    local hide = settings.enabled ~= false and settings.hideBlizzard ~= false
    for i = 1, #NATIVE_CONTROLS do
        local control = _G[NATIVE_CONTROLS[i]]
        if control then
            if hide then
                control:SetAlpha(0)
                control:EnableMouse(false)
            else
                control:SetAlpha(1)
                control:EnableMouse(true)
            end
        end
    end

    local ebonhold = self:DiscoverEbonholdMicroButton()
    if ebonhold then SetEbonholdLauncherHidden(ebonhold, hide) end

    if not hide and UpdateMicroButtons then UpdateMicroButtons() end
end

function MicroMenu:ApplySettings()
    local settings = self:GetSettings()
    if not settings or not self.holder then return end

    local enabled = settings.enabled ~= false
    local showBag = enabled and settings.showBagButton ~= false
    local showQuick = settings.showQuickMenu ~= false
    local scale = RUI:GetEffectiveScale("menu")
    self.holder:SetScale(scale)
    if self.menuFrame then self.menuFrame:SetScale(scale) end
    if self.quickHolder then self.quickHolder:SetScale(scale) end
    if self.quickFrame then self.quickFrame:SetScale(scale) end
    self.holder:SetWidth(showBag and 72 or 34)
    if enabled then self.holder:Show() else self.holder:Hide(); self:HideMenu() end
    if showBag then self.bagButton:Show() else self.bagButton:Hide() end
    if self.quickHolder then
        if showQuick then self.quickHolder:Show() else self.quickHolder:Hide(); self:HideQuickMenu() end
    end

    RUI:UpdateMoverSize("MicroMenu", self.holder:GetWidth() * scale, 34 * scale)
    RUI:SetMoverEnabled("MicroMenu", enabled)
    RUI:UpdateMoverSize("QuickMenu", 34 * scale, 34 * scale)
    RUI:SetMoverEnabled("QuickMenu", showQuick)
    self:ApplyNativeVisibility()
    self:UpdateBagCount()
    self:RefreshQuickMenuState()
end

function MicroMenu:RefreshAppearance()
    if not self.holder then return end
    local scale = RUI:GetEffectiveScale("menu")
    self.holder:SetScale(scale)
    if self.menuFrame then self.menuFrame:SetScale(scale) end
    if self.quickHolder then self.quickHolder:SetScale(scale) end
    if self.quickFrame then self.quickFrame:SetScale(scale) end
    RUI:UpdateMoverSize("MicroMenu", self.holder:GetWidth() * scale, 34 * scale)
    RUI:UpdateMoverSize("QuickMenu", 34 * scale, 34 * scale)
    RUI:StyleButton(self.menuButton)
    RUI:StyleButton(self.bagButton)
    if self.quickButton then RUI:StyleButton(self.quickButton) end
    local ar, ag, ab = RUI:GetAccentColor()
    RUI:StyleFontString(self.menuButton.label, 13, ar, ag, ab)
    if self.quickButton and self.quickButton.label then RUI:StyleFontString(self.quickButton.label, 13, ar, ag, ab) end
    local tr, tg, tb = RUI:GetTextColor(false)
    RUI:StyleFontString(self.bagButton.count, 9, tr, tg, tb)

    local frame = self.menuFrame
    if frame then
        RUI:RefreshBackdrop(frame)
        RUI:SetAccentTexture(frame.accent)
        local r, g, b = RUI:GetTextColor(false)
        RUI:StyleFontString(frame.title, 12, r, g, b)
        local mr, mg, mb = RUI:GetTextColor(true)
        RUI:StyleFontString(frame.subtitle, 9, mr, mg, mb)
        RUI:StyleButton(frame.close)
        for i = 1, #frame.buttons do RUI:StyleButton(frame.buttons[i]) end
        for i = 1, #frame.headers do RUI:StyleFontString(frame.headers[i], 8, mr, mg, mb) end
    end

    local quick = self.quickFrame
    if quick then
        RUI:RefreshBackdrop(quick)
        RUI:SetAccentTexture(quick.accent)
        local r, g, b = RUI:GetTextColor(false)
        local mr, mg, mb = RUI:GetTextColor(true)
        RUI:StyleFontString(quick.title, 11, r, g, b)
        RUI:StyleFontString(quick.subtitle, 8, mr, mg, mb)
        RUI:StyleButton(quick.close)
        RUI:StyleButton(quick.ready)
        RUI:StyleButton(quick.raid)
        RUI:StyleButton(quick.settings)
        RUI:StyleButton(quick.autoInvite)
        RUI:StyleFontString(quick.autoInvite.label, 10, r, g, b)
        RUI:StyleFontString(quick.autoInvite.state, 9, mr, mg, mb)
        if quick.ready and quick.ready.label then RUI:StyleFontString(quick.ready.label, 9, r, g, b) end
        if quick.raid and quick.raid.label then RUI:StyleFontString(quick.raid.label, 9, r, g, b) end
        if quick.settings and quick.settings.label then RUI:StyleFontString(quick.settings.label, 9, r, g, b) end
    end
    self:RefreshQuickMenuState()
end

function MicroMenu:OnComponentScaleChanged(key)
    if key == "all" or key == "menu" then self:ApplySettings(); self:RefreshAppearance() end
end

function MicroMenu:OnAddonRegistered()
    if self.menuFrame and self.menuFrame:IsShown() then self:RebuildMenu() end
end

function MicroMenu:StartEbonholdDiscoveryRetry()
    if not self.holder or self.ebonholdMicroButton then return end
    self.ebonholdDiscoveryRemaining = 30
    self.ebonholdDiscoveryElapsed = 0
    self.holder:SetScript("OnUpdate", function(_, elapsed)
        if MicroMenu.ebonholdMicroButton then
            MicroMenu.holder:SetScript("OnUpdate", nil)
            return
        end
        MicroMenu.ebonholdDiscoveryRemaining = (MicroMenu.ebonholdDiscoveryRemaining or 0) - (tonumber(elapsed) or 0)
        MicroMenu.ebonholdDiscoveryElapsed = (MicroMenu.ebonholdDiscoveryElapsed or 0) + (tonumber(elapsed) or 0)
        if MicroMenu.ebonholdDiscoveryElapsed >= 1 then
            MicroMenu.ebonholdDiscoveryElapsed = 0
            local found = MicroMenu:DiscoverEbonholdMicroButton()
            if found then
                MicroMenu:ApplyNativeVisibility()
                if MicroMenu.menuFrame and MicroMenu.menuFrame:IsShown() then MicroMenu:RebuildMenu() end
            end
        end
        if (MicroMenu.ebonholdDiscoveryRemaining or 0) <= 0 then
            MicroMenu.holder:SetScript("OnUpdate", nil)
        end
    end)
end

function MicroMenu:OnEvent(event, addonName)
    if event == "BAG_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        self:UpdateBagCount()
    end
    if event == "ADDON_LOADED" and addonName == "EbonAPI" and RUI.EbonAPIBridge then
        RUI.EbonAPIBridge:Connect()
    end
    if event == "PLAYER_ENTERING_WORLD" or (event == "ADDON_LOADED" and (addonName == "ProjectEbonhold" or addonName == "EbonAPI")) then
        self:RequestEchoBuildServiceRefresh()
    end
    if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        local before = self.ebonholdMicroButton
        self:DiscoverEbonholdMicroButton()
        self:ApplyNativeVisibility()
        if event == "PLAYER_ENTERING_WORLD" and not self.ebonholdMicroButton then self:StartEbonholdDiscoveryRetry() end
        if self.menuFrame and self.menuFrame:IsShown() and self.ebonholdMicroButton ~= before then self:RebuildMenu() end
    end
end

function MicroMenu:MigrateLegacyProgressionBindings()
    if type(GetBindingKey) ~= "function" or type(SetBinding) ~= "function" then return end
    local changed = false
    for oldCommand, newCommand in pairs(LEGACY_PROGRESSION_BINDINGS) do
        local newKey1 = GetBindingKey(newCommand)
        if not newKey1 then
            local oldKey1, oldKey2 = GetBindingKey(oldCommand)
            if oldKey1 then SetBinding(oldKey1, newCommand); changed = true end
            if oldKey2 then SetBinding(oldKey2, newCommand); changed = true end
        end
    end
    if changed and type(SaveBindings) == "function" and type(GetCurrentBindingSet) == "function" then
        SaveBindings(GetCurrentBindingSet())
    end
end

function MicroMenu:OnInitialize()
    RemoveLegacyProgressionEscapeController()
    self:MigrateLegacyProgressionBindings()
    self:CreateLauncher()
    self:CreateQuickMenu()
    self:CreateMenuFrame()
    self:InstallNativeHooks()
    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "RefreshAppearance")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED", self, "OnComponentScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET", self, "ApplySettings")
    RUI:RegisterCallback("ADDON_REGISTERED", self, "OnAddonRegistered")
    RUI:RegisterCallback("MOVER_MODE_CHANGED", self, "OnMoverModeChanged")
    RUI:RegisterCallback("EBONAPI_BUILDS_UPDATED", self, "OnEbonAPIBuildsUpdated")
end

function MicroMenu:OnEnable()
    self:RegisterEvent("BAG_UPDATE", "OnEvent")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
    self:RegisterEvent("ADDON_LOADED", "OnEvent")
    self:ApplySettings()
    self:RefreshAppearance()
end
