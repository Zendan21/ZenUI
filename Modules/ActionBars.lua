-- ZenUI 0.9.129 ActionBars.
-- Normal bars use Zen-owned ActionBarButtonTemplate buttons, following the
-- robust ownership model used by ElvUI on Ebonhold. Blizzard bar frames remain
-- alive under a hidden parent so native state/data APIs continue to function.

local RUI = ZenUI
local ActionBars = RUI:NewModule("ActionBars")

local ROW_ORDER = { 1, 2, 3, 4, 6, 12 }
local VEHICLE_BUTTON_COUNT = tonumber(_G.VEHICLE_MAX_ACTIONBUTTONS) or 6

-- Native 3.3.5 binding command prefixes. Zen Bar numbers are page-aligned,
-- while Blizzard's MULTIACTIONBAR binding numbers are screen-bar aligned.
local BINDING_PREFIX = {
    [1] = "ACTIONBUTTON",
    [3] = "MULTIACTIONBAR3BUTTON", -- right / page 3
    [4] = "MULTIACTIONBAR4BUTTON", -- left / page 4
    [5] = "MULTIACTIONBAR2BUTTON", -- bottom-right / page 5
    [6] = "MULTIACTIONBAR1BUTTON", -- bottom-left / page 6
}

local PURE_MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
}

-- Keep Zen bar numbers aligned to Wrath action pages:
-- 1 = main/paged, 2 = fixed page 2, 3 = right, 4 = left,
-- 5 = bottom-right, 6 = bottom-left.
local BAR_DEFS = {
    [1] = { id = "Bar1", mover = "ActionBar1", label = "Action Bar 1 / Main", count = 12, page = 1, custom = true },
    [2] = { id = "Bar2", mover = "ActionBar2", label = "Action Bar 2 / Page 2", count = 12, page = 2, custom = true },
    [3] = { id = "Bar3", mover = "ActionBar3", label = "Action Bar 3 / Right", count = 12, page = 3, custom = true },
    [4] = { id = "Bar4", mover = "ActionBar4", label = "Action Bar 4 / Left", count = 12, page = 4, custom = true },
    [5] = { id = "Bar5", mover = "ActionBar5", label = "Action Bar 5 / Bottom Right", count = 12, page = 5, custom = true },
    [6] = { id = "Bar6", mover = "ActionBar6", label = "Action Bar 6 / Bottom Left", count = 12, page = 6, custom = true },
}

local MOVER_DEFAULTS = {
    ActionBar1 = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -370 },
    ActionBar2 = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -210 },
    ActionBar3 = { point = "CENTER", relativePoint = "CENTER", x = 470, y = -35 },
    ActionBar4 = { point = "CENTER", relativePoint = "CENTER", x = 510, y = -35 },
    ActionBar5 = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -290 },
    ActionBar6 = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -330 },
    PetActionBar = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -245 },
    StanceBar = { point = "CENTER", relativePoint = "CENTER", x = -255, y = -245 },
    TotemBar = { point = "CENTER", relativePoint = "CENTER", x = -255, y = -285 },
    TotemTimerBar = { point = "CENTER", relativePoint = "CENTER", x = -255, y = -325 },
}

local ART_TEXTURES = {
    "MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
    "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
    "BonusActionBarTexture0", "BonusActionBarTexture1",
    "SlidingActionBarTexture0", "SlidingActionBarTexture1",
    "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight",
    "PossessBackground1", "PossessBackground2",
}

local function GetButton(prefix, index)
    return prefix and _G[prefix .. tostring(index)] or nil
end

local function GetVehicleButton(index)
    return _G["VehicleMenuBarActionButton" .. tostring(index)]
end

local function GetButtonRegion(button, suffix)
    if not button or not button.GetName then return nil end
    local name = button:GetName()
    if not name then return nil end
    return _G[name .. suffix]
end

local TOTEM_BUTTON_NAMES = {
    "MultiCastSummonSpellButton",
    "MultiCastSlotButton1",
    "MultiCastSlotButton2",
    "MultiCastSlotButton3",
    "MultiCastSlotButton4",
    "MultiCastRecallSpellButton",
}

local TOTEM_ELEMENT_NAMES = { "Fire", "Earth", "Water", "Air" }

local function TotemSlotColor(slot)
    slot=tonumber(slot)
    if slot and _G.FIRE_TOTEM_SLOT and slot==_G.FIRE_TOTEM_SLOT then return 0.95,0.28,0.08 end
    if slot and _G.EARTH_TOTEM_SLOT and slot==_G.EARTH_TOTEM_SLOT then return 0.35,0.82,0.18 end
    if slot and _G.WATER_TOTEM_SLOT and slot==_G.WATER_TOTEM_SLOT then return 0.10,0.55,0.95 end
    if slot and _G.AIR_TOTEM_SLOT and slot==_G.AIR_TOTEM_SLOT then return 0.58,0.28,0.95 end
    local fallback={
        [1]={0.95,0.28,0.08}, [2]={0.35,0.82,0.18},
        [3]={0.10,0.55,0.95}, [4]={0.58,0.28,0.95},
    }
    local c=fallback[slot or 0]
    if c then return c[1],c[2],c[3] end
    return 0.75,0.75,0.75
end

local function FormatTotemTime(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    end
    return string.format("%.1f", seconds)
end

local function TotemFlagTrue(value)
    return value == true or value == 1 or value == "1"
end

local function SetShownAlpha(frame, shown)
    if not frame then return end
    frame:SetAlpha(shown and 1 or 0)
    if frame.EnableMouse then frame:EnableMouse(shown and true or false) end
end

local function ClampRows(rows, count)
    rows = tonumber(rows) or 1
    if rows < 1 then rows = 1 end
    if rows > count then rows = count end
    return math.floor(rows + 0.5)
end

local function ClampButtonCount(count)
    count = tonumber(count) or 12
    if count < 1 then count = 1 end
    if count > 12 then count = 12 end
    return math.floor(count + 0.5)
end

local function ClampAlpha(alpha)
    alpha = tonumber(alpha) or 1
    if alpha < 0.10 then alpha = 0.10 end
    if alpha > 1 then alpha = 1 end
    return alpha
end

local function CalculateLayout(count, rows, size, spacing)
    rows = ClampRows(rows, count)
    local columns = math.ceil(count / rows)
    local actualRows = math.ceil(count / columns)
    local width = (columns * size) + ((columns - 1) * spacing)
    local height = (actualRows * size) + ((actualRows - 1) * spacing)
    return actualRows, columns, width, height
end

local function PositionButton(button, holder, index, count, rows, size, spacing)
    if not button or not holder then return end
    local _, columns = CalculateLayout(count, rows, size, spacing)
    local zero = index - 1
    local row = math.floor(zero / columns)
    local column = zero % columns

    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", holder, "TOPLEFT", column * (size + spacing), -(row * (size + spacing)))
    button:SetWidth(size)
    button:SetHeight(size)
end

function ActionBars:GetSettings()
    return RUI.db and RUI.db.actionbars
end

function ActionBars:GetLayoutScale()
    return RUI:GetEffectiveScale("actionbars")
end

function ActionBars:GetBarSettings(index)
    local settings = self:GetSettings()
    return settings and settings.bars and settings.bars[index]
end

function ActionBars:GetBarButton(index, buttonIndex)
    return self.customButtons and self.customButtons[index] and self.customButtons[index][buttonIndex] or nil
end

function ActionBars:GetBindingCommand(index, buttonIndex)
    if index == 2 then
        local button = self:GetBarButton(index, buttonIndex)
        local name = button and button.GetName and button:GetName()
        if name then return "CLICK " .. name .. ":LeftButton" end
        return nil
    end

    local prefix = BINDING_PREFIX[index]
    if prefix then return prefix .. tostring(buttonIndex) end
    return nil
end

function ActionBars:RegisterBindingButton(button, index, buttonIndex)
    if not button then return end
    self.bindingButtons = self.bindingButtons or {}
    self.bindingButtons[button] = { kind = "bar", bar = index, button = buttonIndex }
end

function ActionBars:RegisterPetBindingButton(button, buttonIndex)
    if not button then return end
    self.bindingButtons = self.bindingButtons or {}
    self.bindingButtons[button] = { kind = "pet", button = buttonIndex }
end

function ActionBars:GetPetBindingCommand(buttonIndex)
    buttonIndex = tonumber(buttonIndex)
    if not buttonIndex or buttonIndex < 1 or buttonIndex > 10 then return nil end
    -- Wrath's native PetActionButton hotkeys are BONUSACTIONBUTTON1..10.
    -- BonusActionButtonDown/Up delegate directly to PetActionButtonDown/Up,
    -- preserving Blizzard/Ebonhold's protected pet-action path in combat.
    return "BONUSACTIONBUTTON" .. tostring(buttonIndex)
end

function ActionBars:GetBindingCommandForMeta(meta)
    if not meta then return nil end
    if meta.kind == "pet" then return self:GetPetBindingCommand(meta.button) end
    return self:GetBindingCommand(meta.bar, meta.button)
end

function ActionBars:GetBindingDescription(meta)
    if not meta then return "Action button" end
    if meta.kind == "pet" then return "Pet Button " .. tostring(meta.button) end
    return "Bar " .. tostring(meta.bar) .. " Button " .. tostring(meta.button)
end

function ActionBars:GetHoveredBinding()
    if not GetMouseFocus then return nil end
    local focus = GetMouseFocus()
    local guard = 0
    while focus and guard < 8 do
        local meta = self.bindingButtons and self.bindingButtons[focus]
        if meta then return focus, meta end
        if not focus.GetParent then break end
        focus = focus:GetParent()
        guard = guard + 1
    end
    return nil
end

function ActionBars:FormatBindingKey(key)
    if not key or key == "" then return nil end
    key = string.upper(key)
    if PURE_MODIFIER_KEYS[key] then return nil end

    local prefix = ""
    if IsAltKeyDown and IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    return prefix .. key
end

function ActionBars:GetBindingLabel(command)
    if not command or not GetBindingKey then return "Unbound" end
    local key1, key2 = GetBindingKey(command)
    if not key1 then return "Unbound" end
    local function Pretty(key)
        if GetBindingText then
            local text = GetBindingText(key, "KEY_", 1)
            if text and text ~= "" then return text end
        end
        return key
    end
    if key2 then return Pretty(key1) .. " / " .. Pretty(key2) end
    return Pretty(key1)
end

function ActionBars:ClearBindingCommand(command)
    if not command or not GetBindingKey or not SetBinding then return false end
    local key1, key2 = GetBindingKey(command)
    if key1 then SetBinding(key1) end
    if key2 then SetBinding(key2) end
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
    return (key1 or key2) and true or false
end

function ActionBars:BindKeyToCommand(key, command)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not command or not SetBinding then return false end
    local ok = SetBinding(key, command)
    if ok and SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
    return ok and true or false
end

function ActionBars:BindKeyToButton(key, index, buttonIndex)
    return self:BindKeyToCommand(key, self:GetBindingCommand(index, buttonIndex))
end

function ActionBars:UpdatePetBindingHotkeys()
    local settings = self:GetSettings()
    for i = 1, 10 do
        local button = GetButton("PetActionButton", i)
        local hotkey = GetButtonRegion(button, "HotKey")
        if button and hotkey then
            local command = self:GetPetBindingCommand(i)
            local key1 = command and GetBindingKey and GetBindingKey(command)
            local text = ""
            if key1 then
                if GetBindingText then text = GetBindingText(key1, "KEY_", 1) or "" end
                if text == "" then text = key1 end
            end
            hotkey:SetText(text)
            if settings and settings.showHotkeys == false then hotkey:Hide()
            elseif text ~= "" then hotkey:Show() end
        end
    end
end

local function NormalizeVisibilityMode(mode)
    mode = string.upper(tostring(mode or "ALWAYS"))
    if mode ~= "COMBAT" and mode ~= "OOC" then return "ALWAYS" end
    return mode
end

function ActionBars:GetVisibilityCondition(mode)
    mode = NormalizeVisibilityMode(mode)
    if mode == "COMBAT" then return "[combat] show; hide" end
    if mode == "OOC" then return "[combat] hide; show" end
    return nil
end

function ActionBars:CreateBehaviorController(name, buttons)
    if not SecureHandlerSetFrameRef or not SecureHandlerWrapScript then return nil end

    local controller = CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
    controller:SetAttribute("rui-base-alpha", 1)
    controller:SetAttribute("rui-mouseover", false)
    controller:SetAttribute("rui-visible", true)
    controller:SetAttribute("rui-ref-count", 0)
    controller:SetAttribute("_rui_apply", [[
        local visible = self:GetAttribute("rui-visible")
        local mouseover = self:GetAttribute("rui-mouseover")
        local alpha = tonumber(self:GetAttribute("rui-base-alpha")) or 1
        local count = tonumber(self:GetAttribute("rui-ref-count")) or 0
        for i = 1, count do
            local button = self:GetFrameRef("button" .. i)
            local active = self:GetAttribute("rui-active" .. i)
            if button and active and button:IsShown() then
                if visible then
                    button:SetAlpha(alpha)
                elseif mouseover then
                    -- Keep the secure button present with zero alpha so the
                    -- hidden bar still has a real hover target. This is what
                    -- makes Combat/OOC visibility and rollover reveal coexist.
                    button:SetAlpha(0)
                end
            end
        end
    ]])
    controller:SetAttribute("_rui_enter", [[
        if self:GetAttribute("rui-mouseover") then
            local count = tonumber(self:GetAttribute("rui-ref-count")) or 0
            for i = 1, count do
                local button = self:GetFrameRef("button" .. i)
                if button and self:GetAttribute("rui-active" .. i) and button:IsShown() then
                    button:SetAlpha(1)
                end
            end
        end
    ]])
    controller:SetAttribute("_rui_leave", [[
        control:RunAttribute("_rui_apply")
    ]])
    controller:SetAttribute("_rui_guard_show", [[
        local button, index = ...
        local active = self:GetAttribute("rui-active" .. tostring(index))
        local visible = self:GetAttribute("rui-visible")
        local mouseover = self:GetAttribute("rui-mouseover")
        if button and (not active) then
            button:Hide(true)
        elseif button and (not visible) then
            if mouseover then
                button:SetAlpha(0)
            else
                button:Hide(true)
            end
        end
    ]])
    controller:SetAttribute("_onstate-ruivis", [[
        local visible = newstate ~= "hide"
        self:SetAttribute("rui-visible", visible)
        local mouseover = self:GetAttribute("rui-mouseover")
        local alpha = tonumber(self:GetAttribute("rui-base-alpha")) or 1
        local count = tonumber(self:GetAttribute("rui-ref-count")) or 0
        for i = 1, count do
            local button = self:GetFrameRef("button" .. i)
            local active = self:GetAttribute("rui-active" .. i)
            if button then
                if visible then
                    if active and self:GetAttribute("rui-wasshown" .. i) then
                        button:Show(true)
                    end
                    if active and button:IsShown() then button:SetAlpha(alpha) end
                    self:SetAttribute("rui-wasshown" .. i, nil)
                else
                    if mouseover then
                        -- Visually hidden, but deliberately still mouse-active.
                        -- The secure OnEnter wrapper can reveal it in combat.
                        if active and button:IsShown() then button:SetAlpha(0) end
                    else
                        self:SetAttribute("rui-wasshown" .. i, button:IsShown())
                        button:SetAlpha(0)
                        button:Hide(true)
                    end
                end
            end
        end
    ]])

    controller.RUIButtons = {}
    local refCount = 0
    local function Add(button)
        if not button then return end
        local nextRef = refCount + 1
        local okRef = pcall(SecureHandlerSetFrameRef, controller, "button" .. tostring(nextRef), button)
        if not okRef then return end
        refCount = nextRef
        controller.RUIButtons[refCount] = button
        controller:SetAttribute("rui-active" .. tostring(refCount), true)
        pcall(SecureHandlerWrapScript, button, "OnEnter", controller, [[ control:RunAttribute("_rui_enter") ]])
        pcall(SecureHandlerWrapScript, button, "OnLeave", controller, [[ control:RunAttribute("_rui_leave") ]])
        local showGuard = string.format([[ control:RunAttribute("_rui_guard_show", self, %d) ]], nextRef)
        pcall(SecureHandlerWrapScript, button, "OnShow", controller, showGuard)
    end

    for i = 1, #(buttons or {}) do Add(buttons[i]) end
    controller:SetAttribute("rui-ref-count", refCount)
    return controller
end

function ActionBars:CreateSecureBarControllers()
    self.barControllers = {}

    for index = 1, 6 do
        local buttons = {}
        for n = 1, 12 do table.insert(buttons, self:GetBarButton(index, n)) end
        if index == 1 then
            for n = 1, 12 do table.insert(buttons, GetButton("BonusActionButton", n)) end
        end
        self.barControllers[index] = self:CreateBehaviorController("ZenUIActionBarSecureController" .. tostring(index), buttons)
    end

    local petButtons = {}
    for n = 1, 10 do table.insert(petButtons, GetButton("PetActionButton", n)) end
    self.petController = self:CreateBehaviorController("ZenUIPetBarSecureController", petButtons)

    local stanceButtons = {}
    for n = 1, 10 do table.insert(stanceButtons, GetButton("ShapeshiftButton", n)) end
    for n = 1, 2 do table.insert(stanceButtons, GetButton("PossessButton", n)) end
    self.stanceController = self:CreateBehaviorController("ZenUIStanceBarSecureController", stanceButtons)
end

function ActionBars:SetControllerActiveCount(controller, activeCount, secondaryStart, secondaryCount)
    if not controller then return end
    activeCount = tonumber(activeCount) or 0
    local count = tonumber(controller:GetAttribute("rui-ref-count")) or 0
    for i = 1, count do
        local active
        if secondaryStart and i >= secondaryStart then
            active = i < (secondaryStart + (secondaryCount or activeCount))
        else
            active = i <= activeCount
        end
        controller:SetAttribute("rui-active" .. tostring(i), active and true or false)
    end
end

function ActionBars:ApplyControllerVisibility(controller, mode)
    if not controller then return end
    mode = NormalizeVisibilityMode(mode)

    if controller.RUIVisibilityMode ~= mode then
        if controller.RUIVisibilityMode and controller.RUIVisibilityMode ~= "ALWAYS" and UnregisterStateDriver then
            pcall(UnregisterStateDriver, controller, "ruivis")
        end
        controller.RUIVisibilityMode = mode
        local condition = self:GetVisibilityCondition(mode)
        if condition and RegisterStateDriver then
            pcall(RegisterStateDriver, controller, "ruivis", condition)
        end
    end

    local visible = true
    if mode == "COMBAT" then
        visible = InCombatLockdown and InCombatLockdown() and true or false
    elseif mode == "OOC" then
        visible = not (InCombatLockdown and InCombatLockdown())
    end
    controller:SetAttribute("rui-visible", visible and true or false)
end

function ActionBars:ApplyControllerBehavior(controller, behavior)
    if not controller or not behavior then return end
    local alpha = ClampAlpha(behavior.alpha)
    controller:SetAttribute("rui-base-alpha", alpha)
    controller:SetAttribute("rui-mouseover", behavior.mouseover and true or false)
    self:ApplyControllerVisibility(controller, behavior.visibility)

    local visible = controller:GetAttribute("rui-visible") ~= false
    local buttons = controller.RUIButtons or {}
    local count = tonumber(controller:GetAttribute("rui-ref-count")) or #buttons
    for i = 1, count do
        local button = buttons[i]
        local active = controller:GetAttribute("rui-active" .. tostring(i)) ~= false
        if button then
            local wasKey = "rui-wasshown" .. tostring(i)
            if active and visible then
                local wasShown = controller:GetAttribute(wasKey)
                if wasShown and not button:IsShown() then button:Show() end
                controller:SetAttribute(wasKey, nil)
                button:SetAlpha(alpha)
                button:EnableMouse(true)
            elseif not visible then
                if behavior.mouseover then
                    -- Zero-alpha secure buttons remain mouse-active so a bar
                    -- hidden by Combat/OOC state can still reveal on rollover.
                    -- If this bar was previously hard-hidden, restore only the
                    -- buttons that had actually been shown before suppression.
                    local wasShown = controller:GetAttribute(wasKey)
                    if wasShown and not button:IsShown() then button:Show() end
                    button:SetAlpha(0)
                    button:EnableMouse(true)
                else
                    if controller:GetAttribute(wasKey) == nil then
                        controller:SetAttribute(wasKey, button:IsShown() and true or false)
                    end
                    button:SetAlpha(0)
                    button:Hide()
                    button:EnableMouse(false)
                end
            else
                button:SetAlpha(0)
                button:Hide()
                button:EnableMouse(false)
            end
        end
    end
end

function ActionBars:ApplyBarBehavior(index)
    local bar = self:GetBarSettings(index)
    local controller = self.barControllers and self.barControllers[index]
    if not bar then return end

    local buttonCount = ClampButtonCount(bar.buttons)
    if controller then
        if index == 1 then
            self:SetControllerActiveCount(controller, buttonCount, 13, buttonCount)
        else
            self:SetControllerActiveCount(controller, buttonCount)
        end
        self:ApplyControllerBehavior(controller, bar)
    else
        local alpha = ClampAlpha(bar.alpha)
        for n = 1, 12 do
            local button = self:GetBarButton(index, n)
            if button then button:SetAlpha(n <= buttonCount and alpha or 0) end
            if index == 1 then
                local bonus = GetButton("BonusActionButton", n)
                if bonus then bonus:SetAlpha(n <= buttonCount and alpha or 0) end
            end
        end
    end
end

function ActionBars:ApplySpecialBarBehavior(kind)
    local settings = self:GetSettings()
    if not settings then return end
    if kind == "pet" then
        -- Only treat the ten native pet buttons as active when the client says
        -- a real pet action bar exists.  LayoutPetBar explicitly shows those
        -- native protected buttons before the controller applies alpha/visibility.
        local active = settings.showPetBar and self.petBarAvailable ~= false
        self:SetControllerActiveCount(self.petController, active and 10 or 0)
        self:ApplyControllerBehavior(self.petController, settings.petBehavior or {})
    elseif kind == "stance" then
        local numForms = settings.showStanceBar and ((GetNumShapeshiftForms and GetNumShapeshiftForms()) or 0) or 0
        local possessVisible = false
        if settings.showStanceBar and type(IsPossessBarVisible) == "function" then
            local ok, shown = pcall(IsPossessBarVisible)
            possessVisible = ok and (shown == true or shown == 1) or false
        end
        -- The controller refs are ShapeshiftButton1..10 followed by
        -- PossessButton1..2.  Only mark forms that actually exist active; the
        -- old all-12 behavior could resurrect otherwise-hidden possess buttons
        -- on classes such as Warrior and visually cover stance buttons.
        self:SetControllerActiveCount(self.stanceController, numForms, 11, possessVisible and 2 or 0)
        self:ApplyControllerBehavior(self.stanceController, settings.stanceBehavior or {})
    end
end

function ActionBars:ForceBindingVisibility(enabled)
    local settings = self:GetSettings()
    if not settings then return end
    if enabled then
        self.bindingOriginalShown = self.bindingOriginalShown or {}
        for index = 1, 6 do
            local controller = self.barControllers and self.barControllers[index]
            if controller then
                if controller.RUIVisibilityMode and controller.RUIVisibilityMode ~= "ALWAYS" and UnregisterStateDriver then
                    pcall(UnregisterStateDriver, controller, "ruivis")
                end
                controller.RUIVisibilityMode = nil
                controller:SetAttribute("rui-visible", true)
            end
            local bar = self:GetBarSettings(index)
            if bar and bar.enabled then
                local count = ClampButtonCount(bar.buttons)
                for n = 1, count do
                    local button = self:GetBarButton(index, n)
                    if button then
                        if self.bindingOriginalShown[button] == nil then self.bindingOriginalShown[button] = button:IsShown() and true or false end
                        button:Show()
                        button:SetAlpha(1)
                        button:EnableMouse(true)
                    end
                end
            end
        end

        -- Pet buttons use native BONUSACTIONBUTTON bindings.  Temporarily force
        -- the live pet bar visible just like Combat/OOC normal bars so every
        -- pet slot can be hovered and rebound in the same Zen keybind mode.
        if settings.showPetBar ~= false and self:PetBarIsAvailable() then
            local controller = self.petController
            if controller then
                if controller.RUIVisibilityMode and controller.RUIVisibilityMode ~= "ALWAYS" and UnregisterStateDriver then
                    pcall(UnregisterStateDriver, controller, "ruivis")
                end
                controller.RUIVisibilityMode = nil
                controller:SetAttribute("rui-visible", true)
            end
            for n = 1, 10 do
                local button = GetButton("PetActionButton", n)
                if button then
                    if self.bindingOriginalShown[button] == nil then self.bindingOriginalShown[button] = button:IsShown() and true or false end
                    button:Show()
                    button:SetAlpha(1)
                    button:EnableMouse(true)
                end
            end
        end
    else
        if self.bindingOriginalShown then
            for button, wasShown in pairs(self.bindingOriginalShown) do
                if button then
                    if wasShown then button:Show() else button:Hide() end
                end
            end
            self.bindingOriginalShown = nil
        end
        for index = 1, 6 do self:ApplyBarBehavior(index) end
        self:ApplySpecialBarBehavior("pet")
        self:UpdatePetBindingHotkeys()
    end
end

function ActionBars:CreateKeybindFrame()
    local frame = CreateFrame("Frame", "ZenUIKeybindFrame", UIParent)
    frame:SetWidth(410)
    frame:SetHeight(138)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -70)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(2000)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:Hide()
    RUI:CreateBackdrop(frame)
    frame.accent = RUI:CreateAccentLine(frame, 2)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -14)
    RUI:StyleFontString(frame.title, 14)
    frame.title:SetText("Keybind Mode")

    frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.help:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
    frame.help:SetWidth(382)
    frame.help:SetJustifyH("LEFT")
    RUI:StyleFontString(frame.help, 9, RUI:GetTextColor(true))
    frame.help:SetText("Hover a normal or pet action button and press a key.  Delete/Backspace clears that button.  Esc finishes.")

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.status:SetPoint("TOPLEFT", frame.help, "BOTTOMLEFT", 0, -10)
    frame.status:SetWidth(382)
    frame.status:SetJustifyH("LEFT")
    RUI:StyleFontString(frame.status, 10)
    frame.status:SetText("Hover an action button...")

    frame.finish = CreateFrame("Button", nil, frame)
    frame.finish:SetWidth(190)
    frame.finish:SetHeight(24)
    frame.finish:EnableMouse(true)
    frame.finish:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.finish:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    frame.finish.text = frame.finish:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.finish.text:SetPoint("CENTER")
    RUI:StyleFontString(frame.finish.text, 10)
    frame.finish.text:SetText("Finish & Return to Settings")
    RUI:StyleButton(frame.finish)
    frame.finish:SetScript("OnClick", function() ActionBars:SetKeybindMode(false, true) end)

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.08 then return end
        self.elapsed = 0
        local _, meta = ActionBars:GetHoveredBinding()
        if meta then
            local command = ActionBars:GetBindingCommandForMeta(meta)
            self.status:SetText(ActionBars:GetBindingDescription(meta) .. "   -   " .. ActionBars:GetBindingLabel(command))
        else
            self.status:SetText("Hover an action or pet button...")
        end
    end)

    frame:SetScript("OnKeyDown", function(self, rawKey)
        if rawKey == "ESCAPE" then
            ActionBars:SetKeybindMode(false, true)
            return
        end
        local _, meta = ActionBars:GetHoveredBinding()
        if not meta then return end
        local command = ActionBars:GetBindingCommandForMeta(meta)
        local description = ActionBars:GetBindingDescription(meta)
        if rawKey == "DELETE" or rawKey == "BACKSPACE" then
            ActionBars:ClearBindingCommand(command)
            ActionBars:UpdatePetBindingHotkeys()
            RUI:Print("Cleared bindings for " .. description .. ".")
            return
        end
        local key = ActionBars:FormatBindingKey(rawKey)
        if not key then return end
        if ActionBars:BindKeyToCommand(key, command) then
            ActionBars:RefreshOverrideBindings()
            ActionBars:UpdatePetBindingHotkeys()
            RUI:Print("Bound " .. key .. " to " .. description .. ".")
        end
    end)

    self.keybindFrame = frame
end

function ActionBars:SetKeybindMode(enabled, returnToSettings)
    enabled = enabled and true or false
    if enabled and InCombatLockdown and InCombatLockdown() then
        RUI:Print("Keybind mode cannot be entered during combat.")
        return false
    end

    if not self.keybindFrame then self:CreateKeybindFrame() end
    self.keybindMode = enabled
    self.returnFromKeybind = returnToSettings and true or false

    if enabled then
        local config = RUI:GetModule("Config")
        if config and config.Hide then config:Hide() end
        self:ForceBindingVisibility(true)
        self.keybindFrame:Show()
        self.keybindFrame:EnableKeyboard(true)
        if self.keybindFrame.Raise then self.keybindFrame:Raise() end
        RUI:Print("Keybind mode enabled. Hover a normal or pet action button and press a key; Esc finishes.")
    else
        if self.keybindFrame then self.keybindFrame:Hide() end
        self:ForceBindingVisibility(false)
        if (not InCombatLockdown or not InCombatLockdown()) and SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
        RUI:Print("Keybind mode disabled.")
        if returnToSettings or self.returnFromKeybind then
            local config = RUI:GetModule("Config")
            if config and config.ShowPage then config:ShowPage("KEYBINDS") end
        end
        self.returnFromKeybind = false
    end
    return true
end

function ActionBars:ToggleKeybindMode(returnToSettings)
    return self:SetKeybindMode(not self.keybindMode, returnToSettings)
end

function ActionBars:CreateHolder(name, secure)
    local template = secure and "SecureHandlerStateTemplate" or nil
    local holder = CreateFrame("Frame", name, UIParent, template)
    holder:SetWidth(100)
    holder:SetHeight(36)
    holder:Show()
    return holder
end

function ActionBars:CaptureButton(button)
    if not button or button.RUIOriginalLayout then return end
    local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
    button.RUIOriginalLayout = {
        parent = button.GetParent and button:GetParent() or nil,
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x or 0,
        y = y or 0,
        width = button:GetWidth(),
        height = button:GetHeight(),
        statehidden = button.GetAttribute and button:GetAttribute("statehidden") or nil,
    }
end

function ActionBars:RestoreButton(button)
    if not button or not button.RUIOriginalLayout then return end
    local data = button.RUIOriginalLayout
    if data.parent and button.GetParent and button.SetParent and button:GetParent() ~= data.parent then
        pcall(button.SetParent, button, data.parent)
    end
    button:ClearAllPoints()
    if data.point then
        button:SetPoint(data.point, data.relativeTo, data.relativePoint or data.point, data.x or 0, data.y or 0)
    end
    if data.width and data.width > 0 then button:SetWidth(data.width) end
    if data.height and data.height > 0 then button:SetHeight(data.height) end
    if button.SetAttribute then button:SetAttribute("statehidden", data.statehidden) end
    button:SetAlpha(1)
    button:EnableMouse(true)
end

function ActionBars:CaptureOriginalLayout()
    self.originalMultiBars = {
        SHOW_MULTI_ACTIONBAR_1,
        SHOW_MULTI_ACTIONBAR_2,
        SHOW_MULTI_ACTIONBAR_3,
        SHOW_MULTI_ACTIONBAR_4,
    }
    self.originalPage2Viewable = VIEWABLE_ACTION_BAR_PAGES and VIEWABLE_ACTION_BAR_PAGES[2]

    for i = 1, 6 do
        local def = BAR_DEFS[i]
        if not def.custom then
            for n = 1, def.count do
                self:CaptureButton(GetButton(def.prefix, n))
                if i == 1 then self:CaptureButton(GetButton("BonusActionButton", n)) end
            end
        end
    end
    for i = 1, 10 do
        self:CaptureButton(GetButton("PetActionButton", i))
        self:CaptureButton(GetButton("ShapeshiftButton", i))
    end
    for i = 1, 2 do self:CaptureButton(GetButton("PossessButton", i)) end
    -- Wrath vehicles use a separate six-button action set. Capture it at login
    -- so Zen can place it on Bar 1 while retaining a clean native restore.
    for i = 1, VEHICLE_BUTTON_COUNT do self:CaptureButton(GetVehicleButton(i)) end
end

function ActionBars:RestoreNativeLayout()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingSettings = true
        return false
    end

    local controllers = {}
    for i = 1, 6 do
        if self.barControllers and self.barControllers[i] then table.insert(controllers, self.barControllers[i]) end
    end
    if self.petController then table.insert(controllers, self.petController) end
    if self.stanceController then table.insert(controllers, self.stanceController) end
    for i = 1, #controllers do
        local controller = controllers[i]
        if controller.RUIVisibilityMode and controller.RUIVisibilityMode ~= "ALWAYS" and UnregisterStateDriver then
            pcall(UnregisterStateDriver, controller, "ruivis")
        end
        controller.RUIVisibilityMode = "ALWAYS"
        controller:SetAttribute("rui-base-alpha", 1)
        controller:SetAttribute("rui-mouseover", false)
        controller:SetAttribute("rui-visible", true)
    end

    for i = 1, 6 do
        local def = BAR_DEFS[i]
        RUI:SetMoverEnabled(def.mover, false)
        for n = 1, def.count do
            local button = self:GetBarButton(i, n)
            if button and button.RUIGridForced and ActionButton_HideGrid then
                ActionButton_HideGrid(button)
                button.RUIGridForced = false
            end
            if def.custom then
                SetShownAlpha(button, false)
            else
                self:RestoreButton(button)
            end
            if i == 1 then self:RestoreButton(GetButton("BonusActionButton", n)) end
        end
    end

    RUI:SetMoverEnabled("PetActionBar", false)
    RUI:SetMoverEnabled("StanceBar", false)
    self:RestoreTotemBar()
    for i = 1, 10 do
        self:RestoreButton(GetButton("PetActionButton", i))
        self:RestoreButton(GetButton("ShapeshiftButton", i))
    end
    for i = 1, 2 do self:RestoreButton(GetButton("PossessButton", i)) end
    for i = 1, VEHICLE_BUTTON_COUNT do self:RestoreButton(GetVehicleButton(i)) end

    if self.originalMultiBars then
        SHOW_MULTI_ACTIONBAR_1 = self.originalMultiBars[1]
        SHOW_MULTI_ACTIONBAR_2 = self.originalMultiBars[2]
        SHOW_MULTI_ACTIONBAR_3 = self.originalMultiBars[3]
        SHOW_MULTI_ACTIONBAR_4 = self.originalMultiBars[4]
        if MultiActionBar_Update then MultiActionBar_Update() end
    end
    if VIEWABLE_ACTION_BAR_PAGES then
        VIEWABLE_ACTION_BAR_PAGES[2] = self.originalPage2Viewable == nil and 1 or self.originalPage2Viewable
    end
    return true
end

function ActionBars:CreateHolders()
    self.holders = {}

    for i = 1, 6 do
        local def = BAR_DEFS[i]
        local holder = self:CreateHolder("ZenUIActionBarHolder" .. tostring(i), true)
        self.holders[i] = holder
        local d = MOVER_DEFAULTS[def.mover]
        RUI:RegisterMover(def.mover, holder, {
            label = def.label,
            width = 452,
            height = 36,
            point = d.point,
            relativePoint = d.relativePoint,
            x = d.x,
            y = d.y,
        })
    end

    self.petHolder = self:CreateHolder("ZenUIPetActionBarHolder")
    local pd = MOVER_DEFAULTS.PetActionBar
    RUI:RegisterMover("PetActionBar", self.petHolder, {
        label = "Pet Action Bar",
        width = 376,
        height = 32,
        point = pd.point,
        relativePoint = pd.relativePoint,
        x = pd.x,
        y = pd.y,
    })

    self.stanceHolder = self:CreateHolder("ZenUIStanceBarHolder")
    local sd = MOVER_DEFAULTS.StanceBar
    RUI:RegisterMover("StanceBar", self.stanceHolder, {
        label = "Stance / Form Bar",
        width = 376,
        height = 32,
        point = sd.point,
        relativePoint = sd.relativePoint,
        x = sd.x,
        y = sd.y,
    })

    self.totemHolder = self:CreateHolder("ZenUITotemBarHolder")
    local td = MOVER_DEFAULTS.TotemBar
    RUI:RegisterMover("TotemBar", self.totemHolder, {
        label = "Shaman Totem Bar",
        width = 224,
        height = 32,
        point = td.point,
        relativePoint = td.relativePoint,
        x = td.x,
        y = td.y,
    })
    self.totemHolder:Hide()
    RUI:SetMoverEnabled("TotemBar", false)

    self.totemTimerHolder = self:CreateHolder("ZenUITotemTimerBarHolder")
    local ttd = MOVER_DEFAULTS.TotemTimerBar
    RUI:RegisterMover("TotemTimerBar", self.totemTimerHolder, {
        label = "Shaman Totem Timers",
        width = 292,
        height = 38,
        point = ttd.point,
        relativePoint = ttd.relativePoint,
        x = ttd.x,
        y = ttd.y,
    })
    self.totemTimerHolder:Hide()
    RUI:SetMoverEnabled("TotemTimerBar", false)
    self:CreateTotemTimerBar()
end

function ActionBars:ConfigureCustomActionPages()
    if not self.holders then return end

    -- Bars 2-6 are fixed pages. Bar 1 follows Wrath's normal paging and
    -- bonus/vehicle pages through a secure state driver, so page changes that
    -- happen during combat do not require insecure SetAttribute calls.
    for barIndex = 2, 6 do
        local holder = self.holders[barIndex]
        if holder and holder.SetAttribute then holder:SetAttribute("actionpage", barIndex) end
    end

    local main = self.holders[1]
    if main and main.SetAttribute then
        main:SetAttribute("actionpage", self:GetMainActionPage())
        main:SetAttribute("_onstate-page", [[
            local page = tonumber(newstate) or 1
            self:SetAttribute("actionpage", page)
        ]])
        if RegisterStateDriver then
            pcall(RegisterStateDriver, main, "page",
                "[bonusbar:5] 11; [bonusbar:4] 10; [bonusbar:3] 9; [bonusbar:2] 8; [bonusbar:1] 7; [bar:6] 6; [bar:5] 5; [bar:4] 4; [bar:3] 3; [bar:2] 2; 1")
        end
    end
end

function ActionBars:GetMainActionPage()
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return 11 end
    local current = tonumber(_G.CURRENT_ACTIONBAR_PAGE) or (GetActionBarPage and tonumber(GetActionBarPage())) or 1
    if current == 1 and GetBonusBarOffset then
        local offset = tonumber(GetBonusBarOffset()) or 0
        if offset > 0 then return 6 + offset end
    end
    if current < 1 then current = 1 end
    return current
end

function ActionBars:UpdateCustomActionSlots()
    if not self.customButtons then return end
    for barIndex = 1, 6 do
        for i = 1, 12 do
            local button = self.customButtons[barIndex] and self.customButtons[barIndex][i]
            if button then
                -- ActionButton_UpdateAction reads the secure actionpage from the
                -- Zen holder. This is the native Wrath path and keeps the
                -- button's display, drag/drop slot and secure click action in sync.
                if ActionButton_UpdateAction then ActionButton_UpdateAction(button)
                elseif ActionButton_Update then ActionButton_Update(button) end
                if ActionButton_UpdateHotkeys then ActionButton_UpdateHotkeys(button, button.buttonType) end
            end
        end
    end
end

function ActionBars:CreateCustomActionButtons()
    if self.customButtons then return end
    self.customButtons = {}
    self:ConfigureCustomActionPages()

    for barIndex = 1, 6 do
        local holder = self.holders and self.holders[barIndex]
        if holder then
            self.customButtons[barIndex] = {}
            for i = 1, 12 do
                local name = "ZenUIActionBar" .. tostring(barIndex) .. "Button" .. tostring(i)
                local button = CreateFrame("CheckButton", name, holder, "ActionBarButtonTemplate")
                button:SetID(i)
                button.RUIBarIndex = barIndex
                button.buttonType = BINDING_PREFIX[barIndex] or ("RUIACTIONBAR" .. tostring(barIndex) .. "BUTTON")
                button:SetAttribute("useparent-actionpage", true)
                self.customButtons[barIndex][i] = button

                if ActionButton_UpdateAction then ActionButton_UpdateAction(button) end
                if ActionButton_UpdateHotkeys then ActionButton_UpdateHotkeys(button, button.buttonType) end
            end
        end
    end
end

function ActionBars:CreateBindingOwner()
    if self.bindingOwner then return end
    self.bindingOwner = CreateFrame("Frame", "ZenUIActionBarBindingOwner", UIParent)
end

function ActionBars:RefreshOverrideBindings()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingBindings = true
        return false
    end
    self:CreateBindingOwner()
    if not self.bindingOwner or not ClearOverrideBindings or not SetOverrideBindingClick then return false end
    ClearOverrideBindings(self.bindingOwner)
    for barIndex = 1, 6 do
        if barIndex ~= 2 then
            for i = 1, 12 do
                local command = self:GetBindingCommand(barIndex, i)
                local button = self:GetBarButton(barIndex, i)
                if command and button and GetBindingKey then
                    local key1, key2 = GetBindingKey(command)
                    if key1 then SetOverrideBindingClick(self.bindingOwner, false, key1, button:GetName(), "LeftButton") end
                    if key2 then SetOverrideBindingClick(self.bindingOwner, false, key2, button:GetName(), "LeftButton") end
                end
            end
        end
    end
    self.pendingBindings = false
    return true
end

function ActionBars:CaptureBlizzardBarFrames()
    if self.blizzardBarFrames then return end
    self.blizzardBarFrames = {}
    local names = { "MainMenuBar", "MainMenuBarArtFrame", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "BonusActionBarFrame", "VehicleMenuBar" }
    for i = 1, #names do
        local frame = _G[names[i]]
        if frame then
            self.blizzardBarFrames[names[i]] = { frame = frame, parent = frame:GetParent(), shown = frame:IsShown() }
        end
    end
end

function ActionBars:SuppressBlizzardNormalBars()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingSettings = true
        return false
    end
    self:CaptureBlizzardBarFrames()
    if not self.blizzardHider then
        self.blizzardHider = CreateFrame("Frame", "ZenUIBlizzardActionBarHider", UIParent)
        self.blizzardHider:Hide()
    end
    for _, row in pairs(self.blizzardBarFrames or {}) do
        if row.frame then
            if row.frame.Hide then row.frame:Hide() end
            if row.frame.SetParent then row.frame:SetParent(self.blizzardHider) end
        end
    end
    return true
end

function ActionBars:RestoreBlizzardNormalBars()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingSettings = true
        return false
    end
    for _, row in pairs(self.blizzardBarFrames or {}) do
        if row.frame and row.frame.SetParent then
            row.frame:SetParent(row.parent or UIParent)
            if row.shown then row.frame:Show() else row.frame:Hide() end
        end
    end
    return true
end

function ActionBars:StyleButton(button)
    if not button then return end

    -- CreateBackdrop already refreshes existing/new Zen backdrop regions.
    -- Avoid doing the same work twice whenever a button is styled.
    RUI:CreateBackdrop(button)

    local br, bg, bb = RUI:GetBackgroundColor()
    if button.RUIBackground then button.RUIBackground:SetTexture(br, bg, bb, 0.92) end

    local icon = GetButtonRegion(button, "Icon")
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if icon.SetDrawLayer then icon:SetDrawLayer("ARTWORK") end
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if not normal then normal = GetButtonRegion(button, "NormalTexture") or GetButtonRegion(button, "NormalTexture2") end
    if normal then normal:SetAlpha(0) end

    local flash = GetButtonRegion(button, "Flash")
    if flash and icon then flash:ClearAllPoints(); flash:SetAllPoints(icon) end

    local cooldown = GetButtonRegion(button, "Cooldown")
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    end

    local border = GetButtonRegion(button, "Border")
    if border then
        local size = button:GetWidth() or 36
        border:SetWidth(size * 1.7)
        border:SetHeight(size * 1.7)
        border:ClearAllPoints()
        border:SetPoint("CENTER", button, "CENTER", 0, 0)
    end

    local textScale = self:GetLayoutScale()
    local hotkey = GetButtonRegion(button, "HotKey")
    if hotkey then
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
        hotkey:SetJustifyH("RIGHT")
        hotkey:SetFont(RUI:GetFontPath("Default"), math.max(7, 9 * textScale), "OUTLINE")
        hotkey:SetShadowColor(0, 0, 0, 1)
        hotkey:SetShadowOffset(1, -1)
    end

    local count = GetButtonRegion(button, "Count")
    if count then
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        count:SetFont(RUI:GetFontPath("Default"), math.max(7, 9 * textScale), "OUTLINE")
        count:SetShadowColor(0, 0, 0, 1)
        count:SetShadowOffset(1, -1)
    end

    local macro = GetButtonRegion(button, "Name")
    if macro then
        macro:ClearAllPoints()
        macro:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
        macro:SetWidth(math.max(1, (button:GetWidth() or 36) - 4))
        macro:SetHeight(math.max(8, 10 * textScale))
        macro:SetJustifyH("CENTER")
        macro:SetFont(RUI:GetFontPath("Default"), math.max(6, 8 * textScale), "OUTLINE")
        macro:SetShadowColor(0, 0, 0, 1)
        macro:SetShadowOffset(1, -1)
    end

    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
        local ar, ag, ab = RUI:GetAccentColor()
        highlight:SetTexture(ar, ag, ab, 0.22)
        highlight:ClearAllPoints()
        highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    end

    button.RUIActionBarStyled = true
    self:ApplyButtonTextVisibility(button)
end

function ActionBars:ApplyButtonTextVisibility(button)
    local settings = self:GetSettings()
    if not settings or not button then return end

    local hotkey = GetButtonRegion(button, "HotKey")
    if hotkey then
        if settings.showHotkeys then
            -- Binding text is maintained by Blizzard's UPDATE_BINDINGS handler.
            -- Do not force the unbound range-indicator dot visible here.
            if hotkey:GetText() ~= RANGE_INDICATOR then hotkey:Show() end
        else
            hotkey:Hide()
        end
    end

    local macro = GetButtonRegion(button, "Name")
    if macro then if settings.showMacroText then macro:Show() else macro:Hide() end end
end

function ActionBars:StyleAllButtons()
    for i = 1, 6 do
        local def = BAR_DEFS[i]
        for n = 1, def.count do
            self:StyleButton(self:GetBarButton(i, n))
            if i == 1 then self:StyleButton(GetButton("BonusActionButton", n)) end
        end
    end

    for i = 1, 10 do
        self:StyleButton(GetButton("PetActionButton", i))
        self:StyleButton(GetButton("ShapeshiftButton", i))
    end
    for i = 1, 2 do self:StyleButton(GetButton("PossessButton", i)) end
    if self.playerClass == "SHAMAN" then
        local buttons = self:GetTotemButtons()
        for i = 1, #buttons do self:StyleButton(buttons[i]) end
    end
end

function ActionBars:ApplyBlizzardArt()
    local settings = self:GetSettings()
    if not settings then return end
    -- Older/imported profiles may omit booleans that default to enabled.
    -- Treat nil the same way as the options UI: only explicit false disables it.
    local hidden = settings.enabled ~= false and settings.hideBlizzardArt ~= false
    local alpha = hidden and 0 or 1

    for i = 1, #ART_TEXTURES do
        local texture = _G[ART_TEXTURES[i]]
        if texture and texture.SetAlpha then texture:SetAlpha(alpha) end
    end

    -- Ebonhold can add/re-show artwork regions directly on MainMenuBarArtFrame.
    -- Suppress only texture regions; never hide/reparent the parent frame or
    -- native ActionButton children. This is the stable pre-ownership model.
    if MainMenuBarArtFrame and MainMenuBarArtFrame.GetRegions then
        local regions = { MainMenuBarArtFrame:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                if region.SetAlpha then region:SetAlpha(alpha) end
            end
        end
    end

    if MainMenuBarPageNumber then MainMenuBarPageNumber:SetAlpha(alpha) end
    SetShownAlpha(ActionBarUpButton, not hidden)
    SetShownAlpha(ActionBarDownButton, not hidden)
end

function ActionBars:ApplyMultiBarVisibility()
    local settings = self:GetSettings()
    if not settings or not settings.bars then return end

    local b2 = settings.bars[2] and settings.bars[2].enabled
    local b3 = settings.bars[3] and settings.bars[3].enabled
    local b4 = settings.bars[4] and settings.bars[4].enabled
    local b5 = settings.bars[5] and settings.bars[5].enabled
    local b6 = settings.bars[6] and settings.bars[6].enabled

    -- Native Wrath mappings: page 6 bottom-left, page 5 bottom-right,
    -- page 3 right, page 4 left (which depends on right being enabled).
    SHOW_MULTI_ACTIONBAR_1 = b6 and 1 or nil
    SHOW_MULTI_ACTIONBAR_2 = b5 and 1 or nil
    SHOW_MULTI_ACTIONBAR_3 = (b3 or b4) and 1 or nil
    SHOW_MULTI_ACTIONBAR_4 = b4 and 1 or nil

    if MultiActionBar_Update then MultiActionBar_Update() end

    if VIEWABLE_ACTION_BAR_PAGES then
        -- A page that is already visible as its own Zen bar should not also
        -- appear when paging Bar 1. Disabled physical bars stay pageable there.
        VIEWABLE_ACTION_BAR_PAGES[2] = b2 and nil or 1
        VIEWABLE_ACTION_BAR_PAGES[3] = b3 and nil or 1
        VIEWABLE_ACTION_BAR_PAGES[4] = b4 and nil or 1
        VIEWABLE_ACTION_BAR_PAGES[5] = b5 and nil or 1
        VIEWABLE_ACTION_BAR_PAGES[6] = b6 and nil or 1
    end
end

function ActionBars:ApplyGridVisibility()
    local settings = self:GetSettings()
    if not settings then return end

    local show = settings.showEmptyButtons and true or false
    for i = 1, 6 do
        local def = BAR_DEFS[i]
        for n = 1, def.count do
            local button = self:GetBarButton(i, n)
            if button then
                if show and (not button.RUIGridForced) and ActionButton_ShowGrid then
                    ActionButton_ShowGrid(button)
                    button.RUIGridForced = true
                elseif (not show) and button.RUIGridForced and ActionButton_HideGrid then
                    ActionButton_HideGrid(button)
                    button.RUIGridForced = false
                end
            end
        end
    end
end

function ActionBars:LayoutBar(index)
    local settings = self:GetSettings()
    local bar = self:GetBarSettings(index)
    local def = BAR_DEFS[index]
    local holder = self.holders and self.holders[index]
    if not settings or not bar or not def or not holder then return end

    local layoutScale = self:GetLayoutScale()
    local size = (tonumber(settings.buttonSize) or 34) * layoutScale
    local spacing = (tonumber(settings.spacing) or 4) * layoutScale
    local buttonCount = ClampButtonCount(bar.buttons)
    local rows, _, width, height = CalculateLayout(buttonCount, bar.rows or 1, size, spacing)
    local enabled = settings.enabled and bar.enabled and true or false

    holder:SetWidth(width)
    holder:SetHeight(height)
    RUI:UpdateMoverSize(def.mover, width, height)
    RUI:SetMoverEnabled(def.mover, enabled)

    for n = 1, def.count do
        local visible = enabled and n <= buttonCount
        local button = self:GetBarButton(index, n)
        if button then
            if n <= buttonCount then
                PositionButton(button, holder, n, buttonCount, rows, size, spacing)
            end
            self:StyleButton(button)
            if button.SetAttribute then
                if visible then button:SetAttribute("statehidden", nil) else button:SetAttribute("statehidden", true) end
            end
            if visible then
                button:EnableMouse(true)
                if ActionButton_Update then ActionButton_Update(button) else button:Show() end
                if settings.showEmptyButtons and button.GetAttribute and (tonumber(button:GetAttribute("showgrid")) or 0) > 0 then button:Show() end
            else
                button:Hide()
                button:EnableMouse(false)
            end
        end

    end

    self:ApplyBarBehavior(index)
end

function ActionBars:LayoutVehicleBar()
    local settings = self:GetSettings()
    local bar = self:GetBarSettings(1)
    local holder = self.holders and self.holders[1]
    if not settings or not bar or not holder then return end

    -- Vehicle action buttons are Blizzard's native secure buttons. Position and
    -- style them once outside combat, then let VehicleMenuBar's native show/hide
    -- state and action updates drive them during ridden encounters. This keeps
    -- ACTIONBUTTON1-6 bindings working exactly as Wrath expects in combat.
    local layoutScale = self:GetLayoutScale()
    local size = (tonumber(settings.buttonSize) or 34) * layoutScale
    local spacing = (tonumber(settings.spacing) or 4) * layoutScale
    local buttonCount = ClampButtonCount(bar.buttons)
    local rows = ClampRows(bar.rows or 1, buttonCount)

    for i = 1, VEHICLE_BUTTON_COUNT do
        local button = GetVehicleButton(i)
        if button then
            if i <= buttonCount then
                PositionButton(button, holder, i, buttonCount, rows, size, spacing)
                if button.SetAttribute then button:SetAttribute("statehidden", nil) end
                button:EnableMouse(true)
            end
            self:StyleButton(button)
        end
    end
end

function ActionBars:PetBarIsAvailable()
    -- Prefer Blizzard's own pet-bar predicates, then fall back to live pet
    -- action data.  Ebonhold builds are not fully consistent about which of
    -- these helpers they expose, so keep this deliberately tolerant.
    if type(PetHasActionBar) == "function" then
        local ok, value = pcall(PetHasActionBar)
        if ok and (value == true or value == 1) then return true end
    end
    if type(HasPetUI) == "function" then
        local ok, value = pcall(HasPetUI)
        if ok and (value == true or value == 1) then return true end
    end
    if type(GetPetActionInfo) == "function" then
        for i = 1, 10 do
            local ok, name, _, texture = pcall(GetPetActionInfo, i)
            if ok and (name or texture) then return true end
        end
    end
    if type(UnitExists) == "function" then
        local ok, value = pcall(UnitExists, "pet")
        if ok and value then return true end
    end
    return false
end

function ActionBars:LayoutPetBar()
    local settings = self:GetSettings()
    if not settings or not self.petHolder then return end

    -- Keep Blizzard/Ebonhold authoritative for pet-action contents/state, but
    -- reclaim the native protected buttons themselves.  The 0.9.185 pass
    -- reparented them correctly, but it never explicitly re-showed buttons
    -- which Blizzard had hidden with PetActionBarFrame.  The secure behavior
    -- controller only restores buttons it previously hid itself, so those
    -- native-hidden buttons stayed invisible forever.
    if type(PetActionBar_Update) == "function" then pcall(PetActionBar_Update) end

    local hasPetBar = self:PetBarIsAvailable()
    self.petBarAvailable = hasPetBar and true or false

    local layoutScale = self:GetLayoutScale()
    local size = math.max(20, ((tonumber(settings.buttonSize) or 34) - 4) * layoutScale)
    local spacing = (tonumber(settings.spacing) or 4) * layoutScale
    local _, _, width, height = CalculateLayout(10, 1, size, spacing)

    self.petHolder:SetWidth(width)
    self.petHolder:SetHeight(height)
    RUI:UpdateMoverSize("PetActionBar", width, height)
    RUI:SetMoverEnabled("PetActionBar", settings.enabled and settings.showPetBar)

    local shouldShow = settings.enabled and settings.showPetBar and hasPetBar
    for i = 1, 10 do
        local button = GetButton("PetActionButton", i)
        if button then
            -- Same ownership model as stance/form buttons: native secure
            -- control and scripts stay intact; Zen owns only parent/layout.
            if button.GetParent and button.SetParent and button:GetParent() ~= self.petHolder then
                pcall(button.SetParent, button, self.petHolder)
            end
            PositionButton(button, self.petHolder, i, 10, 1, size, spacing)
            if button.SetAttribute then pcall(button.SetAttribute, button, "statehidden", nil) end
            if type(PetActionButton_Update) == "function" then pcall(PetActionButton_Update, button) end
            self:StyleButton(button)
            -- This explicit Show is the important difference from 0.9.185/186.
            -- A child that was hidden by Blizzard remains hidden after reparenting
            -- unless Zen actively shows it again outside combat.
            if shouldShow and button.Show then button:Show() end
            SetShownAlpha(button, shouldShow)
        end
    end
    self:ApplySpecialBarBehavior("pet")
    self:UpdatePetBindingHotkeys()
end

function ActionBars:LayoutStanceBar()
    local settings = self:GetSettings()
    if not settings or not self.stanceHolder then return end

    -- Let Blizzard/Ebonhold refresh the native stance button data first, then
    -- immediately reclaim only their layout.  This is important for Warriors,
    -- whose stance icons/state can otherwise remain stale after Zen reparents
    -- the protected ShapeshiftButtons.
    if type(ShapeshiftBar_Update) == "function" then pcall(ShapeshiftBar_Update) end
    if type(ShapeshiftBar_UpdateState) == "function" then pcall(ShapeshiftBar_UpdateState) end

    local layoutScale = self:GetLayoutScale()
    local size = math.max(20, ((tonumber(settings.buttonSize) or 34) - 4) * layoutScale)
    local spacing = (tonumber(settings.spacing) or 4) * layoutScale
    local numForms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    if numForms < 0 then numForms = 0 elseif numForms > 10 then numForms = 10 end

    local possessVisible = false
    if type(IsPossessBarVisible) == "function" then
        local ok, shown = pcall(IsPossessBarVisible)
        possessVisible = ok and (shown == true or shown == 1) or false
    end

    local visibleCount = numForms + (possessVisible and 2 or 0)
    local layoutCount = math.max(1, visibleCount)
    local _, _, width, height = CalculateLayout(layoutCount, 1, size, spacing)

    self.stanceHolder:SetWidth(width)
    self.stanceHolder:SetHeight(height)
    RUI:UpdateMoverSize("StanceBar", width, height)
    RUI:SetMoverEnabled("StanceBar", settings.enabled and settings.showStanceBar and visibleCount > 0)

    for i = 1, 10 do
        local button = GetButton("ShapeshiftButton", i)
        if button then
            -- Shapeshift buttons are native protected controls.  Zen owns only
            -- their parent/layout; CastShapeshiftForm and all native state remain
            -- authoritative.
            if button.GetParent and button.SetParent and button:GetParent() ~= self.stanceHolder then
                pcall(button.SetParent, button, self.stanceHolder)
            end
            PositionButton(button, self.stanceHolder, i, math.max(1, numForms), 1, size, spacing)
            self:StyleButton(button)
            if settings.enabled and settings.showStanceBar and i <= numForms and button.Show then
                button:Show()
            end
            SetShownAlpha(button, settings.enabled and settings.showStanceBar and i <= numForms)
        end
    end

    for i = 1, 2 do
        local button = GetButton("PossessButton", i)
        if button then
            if button.GetParent and button.SetParent and button:GetParent() ~= self.stanceHolder then
                pcall(button.SetParent, button, self.stanceHolder)
            end
            -- Possess buttons must never occupy the same first two positions as
            -- Warrior/Druid/DK stance buttons.  Append them only while the native
            -- possess bar is genuinely active.
            PositionButton(button, self.stanceHolder, numForms + i, math.max(1, visibleCount), 1, size, spacing)
            self:StyleButton(button)
            if possessVisible and settings.enabled and settings.showStanceBar and button.Show then
                button:Show()
            end
            SetShownAlpha(button, possessVisible and settings.enabled and settings.showStanceBar)
        end
    end
    self:ApplySpecialBarBehavior("stance")
end

function ActionBars:CreateTotemTimerBar()
    if not self.totemTimerHolder or self.totemTimerCells then return end
    self.totemTimerCells = {}
    local holder = self.totemTimerHolder
    holder:SetHeight(38)
    for i = 1, 4 do
        local cell = CreateFrame("Frame", "ZenUITotemTimer" .. tostring(i), holder)
        cell:SetWidth(70)
        cell:SetHeight(38)
        cell:SetPoint("LEFT", holder, "LEFT", (i - 1) * 74, 0)
        RUI:CreateBackdrop(cell)
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetWidth(30); cell.icon:SetHeight(30)
        cell.icon:SetPoint("LEFT", cell, "LEFT", 4, 0)
        cell.icon:SetTexCoord(.08,.92,.08,.92)
        cell.name = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cell.name:SetPoint("TOPLEFT", cell.icon, "TOPRIGHT", 5, -2)
        cell.name:SetWidth(29); cell.name:SetJustifyH("LEFT")
        RUI:StyleFontString(cell.name, 7, RUI:GetTextColor(true))
        cell.time = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cell.time:SetPoint("BOTTOMLEFT", cell.icon, "BOTTOMRIGHT", 5, 2)
        cell.time:SetWidth(29); cell.time:SetJustifyH("LEFT")
        RUI:StyleFontString(cell.time, 9)
        cell.element = TOTEM_ELEMENT_NAMES[i]
        cell.slot = i
        cell.name:SetText(cell.element)
        cell:EnableMouse(true)
        cell:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local have, name, startTime, duration = GetTotemInfo and GetTotemInfo(self.slot)
            local active=TotemFlagTrue(have)
            GameTooltip:SetText((active and name) or (self.element .. " Totem"))
            if active and startTime and duration then
                local remain=(tonumber(startTime) or 0)+(tonumber(duration) or 0)-((GetTime and GetTime()) or 0)
                GameTooltip:AddLine("Remaining: " .. FormatTotemTime(remain), .8,.8,.8)
            else
                GameTooltip:AddLine("No active " .. string.lower(self.element) .. " totem.", .65,.65,.65)
            end
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        self.totemTimerCells[i] = cell
    end
end

function ActionBars:UpdateTotemTimers()
    if self.playerClass ~= "SHAMAN" or not self.totemTimerHolder then return end
    local settings = self:GetSettings()
    local enabled = settings and settings.enabled and settings.showTotemBar ~= false and settings.showTotemTimers ~= false
    if not enabled then
        if self.totemTimerVisible ~= false then
            self.totemTimerHolder:Hide()
            RUI:SetMoverEnabled("TotemTimerBar", false)
            self.totemTimerVisible = false
        end
        return
    end

    -- Holder geometry/mover state is static during normal play.  Do not rewrite
    -- it on every timer tick.
    if self.totemTimerVisible ~= true or (self.totemTimerHolder.IsShown and not self.totemTimerHolder:IsShown()) then
        self.totemTimerHolder:SetWidth(292); self.totemTimerHolder:SetHeight(38)
        self.totemTimerHolder:Show()
        RUI:UpdateMoverSize("TotemTimerBar", 292, 38)
        RUI:SetMoverEnabled("TotemTimerBar", true)
        self.totemTimerVisible = true
    end

    if not self.totemTimerCells then self:CreateTotemTimerBar() end
    local now=(GetTime and GetTime()) or 0
    local ar,ag,ab=RUI:GetAccentColor()
    for i=1,4 do
        local cell=self.totemTimerCells[i]
        local have,name,startTime,duration,icon = nil,nil,nil,nil,nil
        if GetTotemInfo then have,name,startTime,duration,icon = GetTotemInfo(i) end
        local active = TotemFlagTrue(have) and tonumber(duration) and tonumber(duration)>0
        if active then
            local texture=icon or "Interface\\Icons\\Spell_Nature_StoneClawTotem"
            if cell.RUITotemIcon ~= texture then
                cell.icon:SetTexture(texture)
                cell.RUITotemIcon = texture
            end

            local remaining=(tonumber(startTime) or 0)+(tonumber(duration) or 0)-now
            local text=FormatTotemTime(remaining)
            if cell.RUITotemTimeText ~= text then
                cell.time:SetText(text)
                cell.RUITotemTimeText = text
            end

            if cell.RUITotemActive ~= true then
                cell:SetAlpha(1)
                cell.RUITotemActive = true
            end
            if cell.RUITotemBorderR ~= ar or cell.RUITotemBorderG ~= ag or cell.RUITotemBorderB ~= ab then
                RUI:SetBorderColor(cell,ar,ag,ab,1)
                cell.RUITotemBorderR,cell.RUITotemBorderG,cell.RUITotemBorderB=ar,ag,ab
            end
        else
            if cell.RUITotemIcon ~= false then
                cell.icon:SetTexture(nil)
                cell.RUITotemIcon = false
            end
            if cell.RUITotemTimeText ~= "--" then
                cell.time:SetText("--")
                cell.RUITotemTimeText = "--"
            end
            if cell.RUITotemActive ~= false then
                cell:SetAlpha(.42)
                RUI:RefreshBackdrop(cell)
                cell.RUITotemActive = false
                cell.RUITotemBorderR,cell.RUITotemBorderG,cell.RUITotemBorderB=nil,nil,nil
            end
        end
    end
end

function ActionBars:GetTotemButtons()
    local buttons = {}
    for i = 1, #TOTEM_BUTTON_NAMES do
        local button = _G[TOTEM_BUTTON_NAMES[i]]
        if button then buttons[#buttons + 1] = button end
    end
    return buttons
end

function ActionBars:CaptureTotemFrame()
    if self.playerClass ~= "SHAMAN" then return nil end
    local frame = _G.MultiCastActionBarFrame
    if not frame then return nil end

    if not self.totemOriginalFrame then
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        self.totemOriginalFrame = {
            parent = frame:GetParent(),
            point = point, relativeTo = relativeTo, relativePoint = relativePoint,
            x = x or 0, y = y or 0,
            width = frame:GetWidth(), height = frame:GetHeight(),
            scale = frame:GetScale(), shown = frame:IsShown(),
        }
        self.totemFrameRegions = {}
        local regions = { frame:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region and region.GetAlpha and region.SetAlpha then
                self.totemFrameRegions[#self.totemFrameRegions + 1] = { region = region, alpha = region:GetAlpha() }
            end
        end
    end
    return frame
end

function ActionBars:RestoreTotemBar()
    if not self.totemOriginalFrame then
        RUI:SetMoverEnabled("TotemBar", false)
        if self.totemHolder then self.totemHolder:Hide() end
        return
    end
    local frame = _G.MultiCastActionBarFrame
    local data = self.totemOriginalFrame
    if frame and data then
        frame:SetParent(data.parent or UIParent)
        frame:ClearAllPoints()
        if data.point then frame:SetPoint(data.point, data.relativeTo, data.relativePoint or data.point, data.x or 0, data.y or 0) end
        if data.width and data.width > 0 then frame:SetWidth(data.width) end
        if data.height and data.height > 0 then frame:SetHeight(data.height) end
        frame:SetScale(data.scale or 1)
        if data.shown then frame:Show() else frame:Hide() end
    end
    for i = 1, #(self.totemFrameRegions or {}) do
        local row = self.totemFrameRegions[i]
        if row.region and row.region.SetAlpha then row.region:SetAlpha(row.alpha or 1) end
    end
    RUI:SetMoverEnabled("TotemBar", false)
    if self.totemHolder then self.totemHolder:Hide() end
    if self.totemTimerHolder then self.totemTimerHolder:Hide() end
    self.totemTimerVisible = false
    RUI:SetMoverEnabled("TotemTimerBar", false)
end


function ActionBars:StyleTotemSlotButton(button)
    if not button then return end
    -- Blizzard's slot background/overlay artwork deliberately extends above
    -- and between the buttons. It looks fine inside the stock MultiCast frame
    -- but clashes with Zen's square action-button layout and makes the row
    -- appear staggered. Keep the secure button/flyout behavior, but replace only
    -- those ornamental textures with a clean inset elemental fill + border.
    if button.background and button.background.SetAlpha then button.background:SetAlpha(0) end
    if button.overlay and button.overlay.SetAlpha then button.overlay:SetAlpha(0) end

    if not button.RUITotemFill then
        local fill=button:CreateTexture(nil,"BACKGROUND")
        fill:SetPoint("TOPLEFT",button,"TOPLEFT",2,-2)
        fill:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-2,2)
        button.RUITotemFill=fill
    end
    local slot=button.GetID and button:GetID() or nil
    local r,g,b=TotemSlotColor(slot)
    button.RUITotemFill:SetTexture(r,g,b,.16)
    if button.RUIBorder then RUI:SetBorderColor(button,r,g,b,1) end
end

local function TotemNumberNear(a,b)
    a=tonumber(a) or 0
    b=tonumber(b) or 0
    return math.abs(a-b) <= 0.10
end

local function TotemPointMatches(object,point,relativeTo,relativePoint,x,y)
    if not object or not object.GetPoint then return false end
    local p,r,rp,px,py=object:GetPoint(1)
    return p==point and r==relativeTo and rp==relativePoint and TotemNumberNear(px,x) and TotemNumberNear(py,y)
end

function ActionBars:TotemLayoutNeedsRepair()
    if self.playerClass~="SHAMAN" or not self.totemHolder then return false end
    local frame=_G.MultiCastActionBarFrame
    local size=tonumber(self.totemLayoutSize)
    local spacing=tonumber(self.totemLayoutSpacing)
    if not frame or not size or not spacing then return false end

    if frame:GetParent()~=self.totemHolder then return true end
    if not TotemPointMatches(frame,"TOPLEFT",self.totemHolder,"TOPLEFT",0,0) then return true end

    local buttons=self:GetTotemButtons()
    if #buttons==0 then return false end
    for i=1,#buttons do
        local button=buttons[i]
        local x=(i-1)*(size+spacing)
        if not TotemPointMatches(button,"TOPLEFT",frame,"TOPLEFT",x,0) then return true end
        if not TotemNumberNear(button:GetWidth(),size) or not TotemNumberNear(button:GetHeight(),size) then return true end
        if button.GetScale and not TotemNumberNear(button:GetScale(),1) then return true end
    end

    for slot=1,4 do
        local action=_G["MultiCastActionButton"..tostring(slot)]
        local slotButton=_G["MultiCastSlotButton"..tostring(slot)]
        if action and slotButton then
            if not TotemPointMatches(action,"TOPLEFT",slotButton,"TOPLEFT",0,0) then return true end
            if not TotemNumberNear(action:GetWidth(),size) or not TotemNumberNear(action:GetHeight(),size) then return true end
            if action.GetScale and not TotemNumberNear(action:GetScale(),1) then return true end
        end
    end

    return false
end

function ActionBars:EnforceTotemButtonLayout(refreshStyle)
    if self.playerClass~="SHAMAN" or not self.totemHolder then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local frame=_G.MultiCastActionBarFrame
    if not frame or frame:GetParent()~=self.totemHolder then return end
    local buttons=self:GetTotemButtons()
    if #buttons==0 then return end
    local size=tonumber(self.totemLayoutSize)
    local spacing=tonumber(self.totemLayoutSpacing)
    if not size or not spacing then return end

    -- The Wrath MultiCast bar uses two separate frames for each elemental
    -- position: MultiCastSlotButtonN is the coloured/flyout slot while
    -- MultiCastActionButtonN carries the currently selected totem icon and
    -- cooldown. Blizzard normally layers those frames on top of each other.
    -- Zen used to move only the slot buttons, leaving the four active
    -- action buttons at their old native anchors and producing two rows.
    for i=1,#buttons do
        local button=buttons[i]
        local x=(i-1)*(size+spacing)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT",frame,"TOPLEFT",x,0)
        button:SetScale(1)
        button:SetWidth(size); button:SetHeight(size)
        button:SetFrameLevel((frame:GetFrameLevel() or 1)+4)
        button:Show(); button:SetAlpha(1)
        if button.EnableMouse then button:EnableMouse(true) end
        if refreshStyle ~= false then self:StyleButton(button) end
        if string.find(button:GetName() or "","MultiCastSlotButton",1,true) then
            self:StyleTotemSlotButton(button)
        end
    end

    -- Overlay the four live action buttons exactly on their elemental slots.
    -- Keep them as native secure buttons so casts, cooldowns and flyout state
    -- remain Blizzard/Ebonhold-controlled; Zen owns only their geometry.
    for slot=1,4 do
        local action=_G["MultiCastActionButton"..tostring(slot)]
        local slotButton=_G["MultiCastSlotButton"..tostring(slot)]
        if action and slotButton then
            action:ClearAllPoints()
            action:SetPoint("TOPLEFT",slotButton,"TOPLEFT",0,0)
            action:SetScale(1)
            action:SetWidth(size); action:SetHeight(size)
            action:SetFrameLevel((slotButton:GetFrameLevel() or (frame:GetFrameLevel()+4))+2)
            action:Show(); action:SetAlpha(1)
            if action.EnableMouse then action:EnableMouse(true) end
            if refreshStyle ~= false then self:StyleButton(action) end
        end
    end
end

function ActionBars:LayoutTotemBar()
    local settings = self:GetSettings()
    if not settings or not self.totemHolder then return end
    if self.playerClass ~= "SHAMAN" then
        self.totemHolder:Hide()
        if self.totemTimerHolder then self.totemTimerHolder:Hide() end
        RUI:SetMoverEnabled("TotemBar", false)
        RUI:SetMoverEnabled("TotemTimerBar", false)
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingSettings = true
        return
    end

    local frame = self:CaptureTotemFrame()
    local buttons = self:GetTotemButtons()
    local enabled = settings.enabled and settings.showTotemBar ~= false and frame and #buttons > 0
    if not enabled then
        if frame and self.totemOriginalFrame then self:RestoreTotemBar() end
        return
    end

    local layoutScale = self:GetLayoutScale()
    local size = math.max(28, (tonumber(settings.buttonSize) or 34) * layoutScale)
    local spacing = math.max(3, (tonumber(settings.spacing) or 4) * layoutScale)
    local width = (#buttons * size) + ((#buttons - 1) * spacing)
    local height = size
    self.totemLayoutSize=size
    self.totemLayoutSpacing=spacing

    self.totemHolder:SetWidth(width)
    self.totemHolder:SetHeight(height)
    self.totemHolder:Show()
    RUI:UpdateMoverSize("TotemBar", width, height)
    RUI:SetMoverEnabled("TotemBar", true)

    frame:SetParent(self.totemHolder)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self.totemHolder, "TOPLEFT", 0, 0)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:SetScale(1)
    frame:Show()

    -- Hide only the ornamental regions owned directly by the Blizzard
    -- MultiCast frame; the secure native buttons remain fully functional.
    for i = 1, #(self.totemFrameRegions or {}) do
        local row = self.totemFrameRegions[i]
        if row.region and row.region.SetAlpha then row.region:SetAlpha(0) end
    end

    self:EnforceTotemButtonLayout()
    self:UpdateTotemTimers()
end

function ActionBars:SyncMoverStates()
    local settings = self:GetSettings()
    if not settings then return end
    local master = settings.enabled ~= false
    for i = 1, 6 do
        local def = BAR_DEFS[i]
        local bar = self:GetBarSettings(i)
        if def then
            RUI:SetMoverEnabled(def.mover, master and bar and bar.enabled == true)
        end
    end
    RUI:SetMoverEnabled("PetActionBar", master and settings.showPetBar ~= false)
    RUI:SetMoverEnabled("StanceBar", master and settings.showStanceBar ~= false)
    RUI:SetMoverEnabled("TotemBar", master and settings.showTotemBar ~= false and self.playerClass == "SHAMAN")
    RUI:SetMoverEnabled("TotemTimerBar", master and settings.showTotemTimers ~= false and self.playerClass == "SHAMAN")
end

function ActionBars:ApplySettings()
    if not self:GetSettings() then return false end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingSettings = true
        return false
    end

    self.pendingSettings = false
    if self:GetSettings().enabled == false then
        if self.customButtons then
            for barIndex = 1, 6 do
                for i = 1, 12 do
                    local button = self:GetBarButton(barIndex, i)
                    if button then button:Hide(); button:EnableMouse(false) end
                end
            end
        end
        if self.bindingOwner and ClearOverrideBindings then ClearOverrideBindings(self.bindingOwner) end
        self:RestoreBlizzardNormalBars()
        self:RestoreNativeLayout()
        self:ApplyBlizzardArt()
        self:SyncMoverStates()
        return true
    end

    -- ElvUI-style ownership: Zen's six normal bars use independent
    -- ActionBarButtonTemplate buttons. Blizzard's normal bar frames stay alive
    -- under an invisible parent so Ebonhold can update action data without ever
    -- reclaiming the visible layout.
    if not self.holders then self:CreateHolders() end
    if not self.customButtons then self:CreateCustomActionButtons() end
    self:SuppressBlizzardNormalBars()
    self:UpdateCustomActionSlots()
    for i = 1, 6 do self:LayoutBar(i) end
    self:LayoutPetBar()
    self:LayoutStanceBar()
    self:LayoutTotemBar()
    self:ApplyGridVisibility()
    self:RefreshOverrideBindings()
    self:SyncMoverStates()
    return true
end

function ActionBars:ApplyAppearance(reason)
    if reason == "scale" or reason == "appearance-reset" then
        self:ApplySettings()
    else
        self:StyleAllButtons()
        self:ApplyBlizzardArt()
        -- Timer cells cache their visual state during normal polling.  Invalidate
        -- that cache on an explicit appearance change so inactive cells also
        -- pick up new Zen backdrop/accent colours immediately.
        if self.playerClass == "SHAMAN" and self.totemTimerCells then
            for i=1,#self.totemTimerCells do
                local cell=self.totemTimerCells[i]
                cell.RUITotemActive=nil
                cell.RUITotemBorderR,cell.RUITotemBorderG,cell.RUITotemBorderB=nil,nil,nil
            end
            self:UpdateTotemTimers()
        end
    end
end

function ActionBars:OnComponentScaleChanged(key)
    if key == "all" or key == "actionbars" then self:ApplySettings() end
end

function ActionBars:OnEvent(event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        if self.pendingSettings then self:ApplySettings() end
        if self.pendingBindings then self:RefreshOverrideBindings() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if self.keybindMode then
            self.returnFromKeybind = false
            self:SetKeybindMode(false, false)
            RUI:Print("Keybind mode closed because combat started.")
        end
    elseif event == "UPDATE_BINDINGS" then
        self:RefreshOverrideBindings()
        self:StyleAllButtons()
        self:UpdatePetBindingHotkeys()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:ApplySettings()
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        local unit = ...
        if unit == "player" then self:UpdateCustomActionSlots() end
    elseif event == "UPDATE_BONUS_ACTIONBAR" or event == "ACTIONBAR_PAGE_CHANGED" then
        self:UpdateCustomActionSlots()
    elseif event == "CVAR_UPDATE" then
        self:ApplySettings()
    elseif event == "UPDATE_SHAPESHIFT_FORMS" or event == "UPDATE_SHAPESHIFT_USABLE" or event == "UPDATE_POSSESS_BAR" then
        -- Blizzard/Ebonhold refreshes the native stance buttons on these events.
        -- Reassert Zen's parent/layout after that refresh so DK Presences and
        -- other class stance/form controls cannot vanish or snap back.
        if not InCombatLockdown or not InCombatLockdown() then
            self:LayoutStanceBar()
        else
            self:StyleAllButtons()
            self.pendingSettings = true
        end
    elseif event == "PET_BAR_UPDATE" or event == "UNIT_PET" or event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" or event == "PLAYER_FARSIGHT_FOCUS_CHANGED" then
        -- PetActionBar_Update may show/hide the native buttons and Blizzard may
        -- also reassert its own bar state.  Outside combat immediately reclaim
        -- Zen's parent/layout; in combat defer protected reparenting.
        if not InCombatLockdown or not InCombatLockdown() then
            self:LayoutPetBar()
        else
            self:StyleAllButtons()
            self.pendingSettings = true
        end
    elseif event == "PLAYER_TOTEM_UPDATE" then
        if self.playerClass == "SHAMAN" then
            -- Totem state changes only need the small timer strip refreshed.
            -- Repair native geometry only when Blizzard has actually moved it.
            self:UpdateTotemTimers()
            if (not InCombatLockdown or not InCombatLockdown()) and self:TotemLayoutNeedsRepair() then
                self:EnforceTotemButtonLayout(false)
            end
        end
    end
end

function ActionBars:OnInitialize()
    self.pendingSettings = false
    self.keybindMode = false
    self.bindingButtons = {}
    local _, classToken = UnitClass("player")
    self.playerClass = classToken
    self:CaptureOriginalLayout()
    self:CreateHolders()
    self:CreateCustomActionButtons()

    -- Fail loudly during initialization instead of leaving Config controls
    -- attached to a half-created ActionBars module.
    for index = 1, 6 do
        if not (self.holders and self.holders[index]) then
            error("ZenUI ActionBars failed to create holder " .. tostring(index))
        end
        if not (self.customButtons and self.customButtons[index] and self.customButtons[index][1]) then
            error("ZenUI ActionBars failed to create buttons for bar " .. tostring(index))
        end
    end

    for index = 1, 6 do
        for n = 1, 12 do
            self:RegisterBindingButton(self:GetBarButton(index, n), index, n)
        end
    end
    for n = 1, 10 do
        self:RegisterPetBindingButton(GetButton("PetActionButton", n), n)
    end

    self:CreateSecureBarControllers()
    self:CreateKeybindFrame()
    self:StyleAllButtons()

    if self.playerClass == "SHAMAN" and hooksecurefunc and type(_G.MultiCastActionBarFrame_Update)=="function" and not self.RUITotemUpdateHooked then
        self.RUITotemUpdateHooked=true
        hooksecurefunc("MultiCastActionBarFrame_Update", function()
            if (not InCombatLockdown or not InCombatLockdown()) and ActionBars:TotemLayoutNeedsRepair() then
                ActionBars:EnforceTotemButtonLayout(false)
            end
        end)
    end

    self.totemWatcher = CreateFrame("Frame", "ZenUITotemBarWatcher", UIParent)
    self.totemWatcher.elapsed = 0
    self.totemWatcher.layoutElapsed = 0
    self.totemWatcher:SetScript("OnUpdate", function(frame, elapsed)
        if ActionBars.playerClass ~= "SHAMAN" then return end
        local settings = ActionBars:GetSettings()
        if not settings or not settings.enabled or settings.showTotemBar == false then return end
        frame.elapsed = (frame.elapsed or 0) + (tonumber(elapsed) or 0)
        frame.layoutElapsed = (frame.layoutElapsed or 0) + (tonumber(elapsed) or 0)
        -- Five timer refreshes per second is enough for the tenths display while
        -- cutting the old 10 Hz polling load in half.
        if frame.elapsed >= 0.20 then
            frame.elapsed = 0
            if settings.showTotemTimers ~= false then ActionBars:UpdateTotemTimers() end
        end
        if frame.layoutElapsed < 1.0 then return end
        frame.layoutElapsed = 0
        if InCombatLockdown and InCombatLockdown() then return end
        local native = _G.MultiCastActionBarFrame
        if native and ActionBars.totemHolder then
            if native:GetParent() ~= ActionBars.totemHolder then
                ActionBars:LayoutTotemBar()
            elseif ActionBars:TotemLayoutNeedsRepair() then
                -- Safety net only: the hook normally repairs this immediately.
                ActionBars:EnforceTotemButtonLayout(false)
            end
        end
    end)

    RUI:RegisterCallback("APPEARANCE_CHANGED", self, "ApplyAppearance")
    RUI:RegisterCallback("COMPONENT_SCALE_CHANGED", self, "OnComponentScaleChanged")
    RUI:RegisterCallback("PROFILE_RESET", self, "ApplySettings")
    RUI:RegisterCallback("ACTIONBARS_RESET", self, "ApplySettings")
    RUI:RegisterCallback("MOVER_MODE_CHANGED", self, "SyncMoverStates")
end

function ActionBars:OnEnable()
    -- Defensive bootstrap: if Ebonhold loaded its bar frames unusually late,
    -- ensure Zen still owns real holders/buttons before any settings pass.
    if not self.holders then self:CreateHolders() end
    if not self.customButtons then self:CreateCustomActionButtons() end
    RUI:RegisterEvent("PLAYER_REGEN_ENABLED", self, "OnEvent")
    RUI:RegisterEvent("PLAYER_REGEN_DISABLED", self, "OnEvent")
    RUI:RegisterEvent("PLAYER_ENTERING_WORLD", self, "OnEvent")
    RUI:RegisterEvent("UNIT_ENTERED_VEHICLE", self, "OnEvent")
    RUI:RegisterEvent("UNIT_EXITED_VEHICLE", self, "OnEvent")
    RUI:RegisterEvent("UPDATE_BONUS_ACTIONBAR", self, "OnEvent")
    RUI:RegisterEvent("ACTIONBAR_PAGE_CHANGED", self, "OnEvent")
    RUI:RegisterEvent("UPDATE_BINDINGS", self, "OnEvent")
    RUI:RegisterEvent("CVAR_UPDATE", self, "OnEvent")
    RUI:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", self, "OnEvent")
    RUI:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", self, "OnEvent")
    RUI:RegisterEvent("UPDATE_POSSESS_BAR", self, "OnEvent")
    RUI:RegisterEvent("PET_BAR_UPDATE", self, "OnEvent")
    RUI:RegisterEvent("UNIT_PET", self, "OnEvent")
    RUI:RegisterEvent("PLAYER_CONTROL_LOST", self, "OnEvent")
    RUI:RegisterEvent("PLAYER_CONTROL_GAINED", self, "OnEvent")
    RUI:RegisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED", self, "OnEvent")
    RUI:RegisterEvent("PLAYER_TOTEM_UPDATE", self, "OnEvent")
    self:ApplySettings()
end

function ActionBars:GetNextRows(current)
    current = tonumber(current) or 1
    for i = 1, #ROW_ORDER do
        if ROW_ORDER[i] == current then return ROW_ORDER[(i % #ROW_ORDER) + 1] end
    end
    return ROW_ORDER[1]
end
