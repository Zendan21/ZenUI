-- Optional EbonAPI interoperability for ZenUI.
--
-- ZenUI remains fully standalone. When the community EbonAPI addon is enabled,
-- this bridge consumes its normalized Project Ebonhold server state/events and
-- keeps Zen's existing direct/native code as a compatibility fallback.

local RUI = ZenUI

local Bridge = {
    requiredMajor = 2,
    requiredMinor = 1,
    available = false,
    handle = nil,
    state = nil,
    version = nil,
    connectError = nil,
}

RUI.EbonAPIBridge = Bridge

local function Record(context, err)
    Bridge.connectError = tostring(err or "unknown error")
    if RUI.RecordRuntimeError then
        RUI:RecordRuntimeError("EbonAPI", context, err)
    end
end

local function CallMethod(object, methodName, ...)
    if type(object) ~= "table" then return false, nil end
    local method = object[methodName]
    if type(method) ~= "function" then return false, nil end
    local ok, a, b, c, d = pcall(method, object, ...)
    if not ok then
        Record(methodName, a)
        return false, nil
    end
    return true, a, b, c, d
end

local function CallFunction(fn, context, ...)
    if type(fn) ~= "function" then return false, nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        Record(context, a)
        return false, nil
    end
    return true, a, b, c, d
end

function Bridge:IsAvailable()
    return self.available == true and type(self.handle) == "table" and type(self.state) == "table"
end

function Bridge:GetVersion()
    return self.version
end

function Bridge:GetState()
    return self:IsAvailable() and self.state or nil
end

function Bridge:GetPerkService()
    if self:IsAvailable() then
        local api = _G.EbonAPI
        local ebonhold = api and api.Ebonhold
        if type(ebonhold) == "table" and type(ebonhold.Perks) == "function" then
            local ok, service = CallFunction(ebonhold.Perks, "Ebonhold.Perks")
            if ok and type(service) == "table" then return service end
        end
    end

    local project = _G.ProjectEbonhold
    local service = type(project) == "table" and project.PerkService or nil
    return type(service) == "table" and service or nil
end

function Bridge:GetBuildState()
    if not self:IsAvailable() or type(self.state.GetBuilds) ~= "function" then return nil end
    local ok, builds = CallFunction(self.state.GetBuilds, "State.GetBuilds")
    if ok and type(builds) == "table" then return builds end
    return nil
end

-- EbonAPI's SERVER BUILD_LIST parser represents the authoritative numbered
-- server build slots. Unlike Ebonhold's UI/service tables, it does not require
-- ZenUI to infer Saved Builds from neighbouring Wishlist controls/records.
function Bridge:GetSavedBuilds(maxSlots)
    local state = self:GetBuildState()
    if not state or type(state.slots) ~= "table" then return nil, nil, nil end

    maxSlots = tonumber(maxSlots) or 10
    local list = {}
    for key, build in pairs(state.slots) do
        local slot = tonumber(key) or (type(build) == "table" and tonumber(build.slot))
        if slot and slot >= 1 and slot <= maxSlots and type(build) == "table" then
            local name = tostring(build.name or "")
            name = string.gsub(name, "^%s+", "")
            name = string.gsub(name, "%s+$", "")
            if name ~= "" then
                list[#list + 1] = {
                    name = name,
                    slot = slot,
                    verified = true,
                    direct = true,
                    ebonapi = true,
                }
            end
        end
    end

    table.sort(list, function(a, b)
        if a.slot == b.slot then return a.name < b.name end
        return a.slot < b.slot
    end)

    local activeSlot = tonumber(state.active) or 0
    local activeName = nil
    for i = 1, #list do
        if list[i].slot == activeSlot then
            activeName = list[i].name
            break
        end
    end

    return list, activeName, activeSlot
end

function Bridge:RequestBuilds()
    local service = self:GetPerkService()
    if not service or type(service.RequestServerBuildSlots) ~= "function" then return false end
    local ok, result = CallFunction(service.RequestServerBuildSlots, "RequestServerBuildSlots")
    if not ok then return false end
    return result ~= false
end

function Bridge:ActivateBuildSlot(slot)
    slot = tonumber(slot)
    if not slot then return false end
    local service = self:GetPerkService()
    if not service or type(service.ActivateServerBuildSlot) ~= "function" then return false end
    local ok, result = CallFunction(service.ActivateServerBuildSlot, "ActivateServerBuildSlot", slot)
    if not ok then return false end
    return result == true
end

function Bridge:GetActiveBuildSlot()
    local state = self:GetBuildState()
    if state then return tonumber(state.active) end

    local service = self:GetPerkService()
    if service and type(service.GetServerActiveSlot) == "function" then
        local ok, value = CallFunction(service.GetServerActiveSlot, "GetServerActiveSlot")
        if ok then return tonumber(value) end
    end
    return nil
end

function Bridge:OnBuildsChanged(event, builds)
    RUI:FireCallback("EBONAPI_BUILDS_UPDATED", builds, event)
end

function Bridge:OnReady(event, version)
    if version then self.version = tostring(version) end
    RUI:FireCallback("EBONAPI_READY", self.version)
end

function Bridge:Connect()
    if self:IsAvailable() then return true end

    local api = _G.EbonAPI
    if type(api) ~= "table" or type(api.NewAddon) ~= "function" then
        self.available = false
        return false
    end

    local ok, handle = pcall(api.NewAddon, api, "ZenUI", self.requiredMajor, self.requiredMinor)
    if not ok then
        Record("NewAddon", handle)
        self.available = false
        return false
    end
    if type(handle) ~= "table" then
        self.available = false
        return false
    end

    local okState, state = CallMethod(handle, "State")
    if not okState or type(state) ~= "table" then
        self.available = false
        return false
    end

    self.handle = handle
    self.state = state
    self.version = tostring(api.version or "unknown")
    self.available = true
    self.connectError = nil

    -- SERVER_BUILDS / SERVER_BUILD_ACTIVE are sticky in EbonAPI, so registering
    -- here also gives Zen the most recent authoritative state immediately.
    CallMethod(handle, "On", "SERVER_BUILDS", function(event, builds)
        Bridge:OnBuildsChanged(event, builds)
    end)
    CallMethod(handle, "On", "SERVER_BUILD_ACTIVE", function(event, slot, builds)
        Bridge:OnBuildsChanged(event, builds)
    end)
    CallMethod(handle, "On", "READY", function(event, version)
        Bridge:OnReady(event, version)
    end)

    return true
end

-- OptionalDeps normally makes EbonAPI load first when it is enabled. Connect
-- eagerly so its sticky build state is available before the Quick Menu opens.
Bridge:Connect()
