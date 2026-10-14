-- Lightweight ZenUI module system.

local RUI = ZenUI

local ModulePrototype = {}

function ModulePrototype:RegisterEvent(event, method)
    return RUI:RegisterEvent(event, self, method)
end

function ModulePrototype:UnregisterEvent(event)
    RUI:UnregisterEvent(event, self)
end

function ModulePrototype:Print(message)
    RUI:Print(self.name .. ": " .. tostring(message))
end

function RUI:NewModule(name)
    if type(name) ~= "string" or name == "" then
        error("ZenUI:NewModule requires a module name.")
    end

    if self.modules[name] then
        error("ZenUI module already exists: " .. name)
    end

    local module = {
        name = name,
        initialized = false,
        enabled = false,
        initializationError = nil,
        enableError = nil,
    }

    setmetatable(module, { __index = ModulePrototype })
    self.modules[name] = module
    table.insert(self.moduleOrder, name)
    return module
end

function RUI:GetModule(name)
    return self.modules[name]
end

function RUI:InitializeModules()
    for i = 1, #self.moduleOrder do
        local module = self.modules[self.moduleOrder[i]]

        if module and not module.initialized then
            local ok = true
            local err

            if type(module.OnInitialize) == "function" then
                ok, err = pcall(module.OnInitialize, module)
            end

            if ok then
                module.initialized = true
                module.initializationError = nil
            else
                module.initializationError = tostring(err)
                self:Print("Module init failed (" .. module.name .. "): " .. module.initializationError)
            end
        end
    end
end

function RUI:EnableModules()
    for i = 1, #self.moduleOrder do
        local module = self.modules[self.moduleOrder[i]]

        if module and module.initialized and not module.enabled then
            local ok = true
            local err

            if type(module.OnEnable) == "function" then
                ok, err = pcall(module.OnEnable, module)
            end

            if ok then
                module.enabled = true
                module.enableError = nil
            else
                module.enableError = tostring(err)
                self:Print("Module enable failed (" .. module.name .. "): " .. module.enableError)
            end
        end
    end
end
