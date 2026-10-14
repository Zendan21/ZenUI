-- ZenUI 1.0.25
-- Core namespace and shared helpers.

ZenUI = ZenUI or {}

-- Rename compatibility: old companion addons may still look up the previous
-- namespace. ZenUI remains authoritative; this alias is intentionally silent.
if _G.RavioliUI == nil then _G.RavioliUI = ZenUI end

local RUI = ZenUI

RUI.name = "ZenUI"
RUI.version = "1.0.25"
RUI.interface = 30300
RUI.modules = RUI.modules or {}
RUI.moduleOrder = RUI.moduleOrder or {}
RUI.registeredAddons = RUI.registeredAddons or {}
RUI.callbacks = RUI.callbacks or {}
RUI.movers = RUI.movers or {}
RUI.moverOrder = RUI.moverOrder or {}
RUI.moverMode = false
RUI.initialized = false
RUI.enabled = false
RUI.runtimeErrors = RUI.runtimeErrors or {}

local RUNTIME_ERROR_LIMIT = 20

function RUI:RecordRuntimeError(kind, context, err)
    local entry = {
        kind = tostring(kind or "runtime"),
        context = tostring(context or "unknown"),
        message = tostring(err or "unknown error"),
        time = (GetTime and GetTime()) or 0,
    }
    table.insert(self.runtimeErrors, entry)
    while #self.runtimeErrors > RUNTIME_ERROR_LIMIT do
        table.remove(self.runtimeErrors, 1)
    end
    return entry
end

function RUI:ReportRuntimeError(kind, context, err)
    local entry = self:RecordRuntimeError(kind, context, err)
    self:Print(entry.kind .. " error (" .. entry.context .. "): " .. entry.message)
    return entry
end

function RUI:ClearRuntimeErrors()
    self.runtimeErrors = {}
end

function RUI:GetRuntimeErrorCount()
    return #(self.runtimeErrors or {})
end

function RUI:GetModuleFailureCount()
    local count = 0
    for i = 1, #(self.moduleOrder or {}) do
        local module = self.modules and self.modules[self.moduleOrder[i]]
        if module and (module.initializationError or module.enableError) then count = count + 1 end
    end
    return count
end

function RUI:GetHealthSummary()
    local failed = self:GetModuleFailureCount()
    local errors = self:GetRuntimeErrorCount()
    if failed == 0 and errors == 0 then return "Healthy", failed, errors end
    return tostring(failed + errors) .. " issue" .. ((failed + errors) == 1 and "" or "s"), failed, errors
end

local prefix = "|cfff2d6b3Zen|r|cffffffffUI|r"

function RUI:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. ": " .. tostring(message))
end

function RUI:Debug(message)
    if self.global and self.global.debug then
        self:Print("|cff8fd3ffDebug:|r " .. tostring(message))
    end
end

function RUI:RegisterCallback(event, owner, method)
    if type(event) ~= "string" or not owner or not method then
        return
    end

    self.callbacks[event] = self.callbacks[event] or {}
    for i = 1, #self.callbacks[event] do
        local existing = self.callbacks[event][i]
        if existing.owner == owner and existing.method == method then return end
    end
    table.insert(self.callbacks[event], {
        owner = owner,
        method = method,
    })
end

function RUI:FireCallback(event, ...)
    local callbacks = self.callbacks[event]
    if not callbacks then
        return
    end

    for i = 1, #callbacks do
        local callback = callbacks[i]
        local method = callback.method

        if type(method) == "string" then
            method = callback.owner[method]
        end

        if type(method) == "function" then
            local ok, err = pcall(method, callback.owner, ...)
            if not ok then
                self:ReportRuntimeError("Callback", event, err)
            end
        end
    end
end

-- Companion addons register here and appear automatically in the Zen micro menu.
function RUI:RegisterAddon(id, data)
    if type(id) ~= "string" or id == "" or type(data) ~= "table" then
        self:Print("RegisterAddon requires an id and data table.")
        return false
    end

    data.id = id
    data.name = data.name or id
    data.order = data.order or 100

    self.registeredAddons[id] = data
    self:Debug("Registered companion addon: " .. id)
    self:FireCallback("ADDON_REGISTERED", id, data)
    return true
end

function RUI:GetRegisteredAddon(id)
    return self.registeredAddons[id]
end
