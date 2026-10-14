-- ZenUI event dispatcher and lifecycle.

local RUI = ZenUI
local eventFrame = CreateFrame("Frame", "ZenUIEventFrame")

RUI.eventFrame = eventFrame
RUI.eventHandlers = RUI.eventHandlers or {}

function RUI:RegisterEvent(event, owner, method)
    if type(event) ~= "string" or not owner or not method then
        return false
    end

    self.eventHandlers[event] = self.eventHandlers[event] or {}
    for i = 1, #self.eventHandlers[event] do
        local existing = self.eventHandlers[event][i]
        if existing.owner == owner and existing.method == method then return true end
    end
    table.insert(self.eventHandlers[event], {
        owner = owner,
        method = method,
    })

    eventFrame:RegisterEvent(event)
    return true
end

function RUI:UnregisterEvent(event, owner)
    local handlers = self.eventHandlers[event]
    if not handlers then
        return
    end

    for i = #handlers, 1, -1 do
        if handlers[i].owner == owner then
            table.remove(handlers, i)
        end
    end

    if #handlers == 0 then
        self.eventHandlers[event] = nil
        eventFrame:UnregisterEvent(event)
    end
end

local function DispatchEvent(event, ...)
    local handlers = RUI.eventHandlers[event]
    if not handlers then
        return
    end

    for i = 1, #handlers do
        local handler = handlers[i]
        local method = handler.method

        if type(method) == "string" then
            method = handler.owner[method]
        end

        if type(method) == "function" then
            local ok, err = pcall(method, handler.owner, event, ...)
            if not ok then
                RUI:ReportRuntimeError("Event", event, err)
            end
        end
    end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "ZenUI" and not RUI.initialized then
            RUI:InitializeDatabase()
            if RUI.InitializeStylingPack then RUI:InitializeStylingPack() end
            RUI:InitializeModules()
            RUI:RegisterSlashCommands()
            RUI.initialized = true
            RUI:FireCallback("RUI_INITIALIZED")
            RUI:Debug("Core initialized.")
        end
    elseif event == "PLAYER_LOGIN" then
        if RUI.initialized and not RUI.enabled then
            RUI:EnableModules()
            RUI.enabled = true
            RUI:FireCallback("RUI_ENABLED")
            RUI:Print("v" .. RUI.version .. " loaded. Type |cffffffff/zenui|r for settings.")
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if RUI.moverMode then
            RUI:SetMoverMode(false)
            RUI:Print("Mover mode closed because combat started.")
        end
    end

    DispatchEvent(event, ...)
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
