-- ZenUI profile management and safe import/export.
-- Profiles are UI configuration only; account/character history stays outside exports.

local RUI = ZenUI

local EXPORT_PREFIX = "ZUI1:"
local LEGACY_EXPORT_PREFIX = "RUI1:"
local EXPORT_FORMAT = 1
local MAX_IMPORT_BYTES = 250000
local MAX_DECODE_DEPTH = 40
local MAX_TABLE_ITEMS = 20000
local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Trim(text)
    return string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1")
end

local function DeepCopy(source, seen)
    if type(source) ~= "table" then return source end
    seen = seen or {}
    if seen[source] then return seen[source] end
    local destination = {}
    seen[source] = destination
    for key, value in pairs(source) do
        local keyType = type(key)
        local valueType = type(value)
        if (keyType == "string" or keyType == "number") and
           (valueType == "table" or valueType == "string" or valueType == "number" or valueType == "boolean") then
            destination[DeepCopy(key, seen)] = DeepCopy(value, seen)
        end
    end
    return destination
end

local function SanitizeProfileName(name)
    name = Trim(name)
    name = string.gsub(name, "[%c]", "")
    if name == "" then return nil end
    if string.len(name) > 40 then name = string.sub(name, 1, 40) end
    return name
end

local function SortedKeys(tbl)
    local keys = {}
    for key, value in pairs(tbl or {}) do
        local keyType = type(key)
        local valueType = type(value)
        if (keyType == "string" or keyType == "number") and
           (valueType == "table" or valueType == "string" or valueType == "number" or valueType == "boolean") then
            table.insert(keys, key)
        end
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta == "number" end
        if ta == "number" then return a < b end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function SerializeValue(value, out, depth)
    depth = (depth or 0) + 1
    if depth > MAX_DECODE_DEPTH then return false, "Profile data is nested too deeply." end

    local kind = type(value)
    if kind == "boolean" then
        table.insert(out, value and "B1" or "B0")
        return true
    elseif kind == "number" then
        local text = tostring(value)
        table.insert(out, "N" .. tostring(string.len(text)) .. ":" .. text)
        return true
    elseif kind == "string" then
        table.insert(out, "S" .. tostring(string.len(value)) .. ":" .. value)
        return true
    elseif kind == "table" then
        local keys = SortedKeys(value)
        if #keys > MAX_TABLE_ITEMS then return false, "Profile table contains too many entries." end
        table.insert(out, "T" .. tostring(#keys) .. ":")
        for i = 1, #keys do
            local key = keys[i]
            local ok, err = SerializeValue(key, out, depth)
            if not ok then return false, err end
            ok, err = SerializeValue(value[key], out, depth)
            if not ok then return false, err end
        end
        return true
    end
    return false, "Unsupported profile value type: " .. tostring(kind)
end

local function Serialize(value)
    local out = {}
    local ok, err = SerializeValue(value, out, 0)
    if not ok then return nil, err end
    return table.concat(out)
end

local function ReadCount(data, position)
    local colon = string.find(data, ":", position, true)
    if not colon then return nil, position, "Malformed profile data." end
    local raw = string.sub(data, position, colon - 1)
    if raw == "" or string.find(raw, "[^0-9]") then return nil, position, "Malformed profile length." end
    local value = tonumber(raw)
    if not value or value < 0 then return nil, position, "Invalid profile length." end
    return value, colon + 1
end

local function DeserializeValue(data, position, depth)
    depth = (depth or 0) + 1
    if depth > MAX_DECODE_DEPTH then return nil, position, "Profile data is nested too deeply." end
    if position > string.len(data) then return nil, position, "Profile data ended unexpectedly." end

    local tag = string.sub(data, position, position)
    position = position + 1
    if tag == "B" then
        local flag = string.sub(data, position, position)
        if flag == "1" then return true, position + 1 end
        if flag == "0" then return false, position + 1 end
        return nil, position, "Invalid boolean in profile data."
    elseif tag == "N" or tag == "S" then
        local length, nextPosition, err = ReadCount(data, position)
        if not length then return nil, position, err end
        if length > MAX_IMPORT_BYTES then return nil, position, "Profile field is too large." end
        local finish = nextPosition + length - 1
        if finish > string.len(data) then return nil, position, "Profile field is truncated." end
        local raw = string.sub(data, nextPosition, finish)
        if tag == "N" then
            local number = tonumber(raw)
            if number == nil then return nil, position, "Invalid number in profile data." end
            return number, finish + 1
        end
        return raw, finish + 1
    elseif tag == "T" then
        local count, nextPosition, err = ReadCount(data, position)
        if not count then return nil, position, err end
        if count > MAX_TABLE_ITEMS then return nil, position, "Profile table contains too many entries." end
        local result = {}
        position = nextPosition
        for i = 1, count do
            local key
            key, position, err = DeserializeValue(data, position, depth)
            if err then return nil, position, err end
            local keyType = type(key)
            if keyType ~= "string" and keyType ~= "number" then return nil, position, "Invalid table key in profile data." end
            local value
            value, position, err = DeserializeValue(data, position, depth)
            if err then return nil, position, err end
            result[key] = value
        end
        return result, position
    end
    return nil, position, "Unknown profile data tag."
end

local function Deserialize(data)
    local value, position, err = DeserializeValue(data, 1, 0)
    if err then return nil, err end
    if position ~= string.len(data) + 1 then return nil, "Profile data has trailing content." end
    return value
end

local function Base64Encode(data)
    local out = {}
    local length = string.len(data)
    local index = 1
    while index <= length do
        local a = string.byte(data, index) or 0
        local b = string.byte(data, index + 1)
        local c = string.byte(data, index + 2)
        local bValue = b or 0
        local cValue = c or 0
        local value = a * 65536 + bValue * 256 + cValue
        local c1 = math.floor(value / 262144) % 64
        local c2 = math.floor(value / 4096) % 64
        local c3 = math.floor(value / 64) % 64
        local c4 = value % 64
        table.insert(out, string.sub(BASE64_ALPHABET, c1 + 1, c1 + 1))
        table.insert(out, string.sub(BASE64_ALPHABET, c2 + 1, c2 + 1))
        table.insert(out, b and string.sub(BASE64_ALPHABET, c3 + 1, c3 + 1) or "=")
        table.insert(out, c and string.sub(BASE64_ALPHABET, c4 + 1, c4 + 1) or "=")
        index = index + 3
    end
    return table.concat(out)
end

local BASE64_REVERSE = {}
for i = 1, string.len(BASE64_ALPHABET) do
    BASE64_REVERSE[string.sub(BASE64_ALPHABET, i, i)] = i - 1
end

local function Base64Decode(text)
    text = string.gsub(tostring(text or ""), "%s", "")
    if text == "" or (string.len(text) % 4) ~= 0 then return nil, "Invalid profile encoding." end
    local out = {}
    local index = 1
    while index <= string.len(text) do
        local s1 = string.sub(text, index, index)
        local s2 = string.sub(text, index + 1, index + 1)
        local s3 = string.sub(text, index + 2, index + 2)
        local s4 = string.sub(text, index + 3, index + 3)
        local a, b = BASE64_REVERSE[s1], BASE64_REVERSE[s2]
        local c = s3 == "=" and 0 or BASE64_REVERSE[s3]
        local d = s4 == "=" and 0 or BASE64_REVERSE[s4]
        if a == nil or b == nil or c == nil or d == nil then return nil, "Invalid profile encoding." end
        if s3 == "=" and s4 ~= "=" then return nil, "Invalid profile padding." end
        local value = a * 262144 + b * 4096 + c * 64 + d
        table.insert(out, string.char(math.floor(value / 65536) % 256))
        if s3 ~= "=" then table.insert(out, string.char(math.floor(value / 256) % 256)) end
        if s4 ~= "=" then table.insert(out, string.char(value % 256)) end
        index = index + 4
    end
    return table.concat(out)
end

local function CopyForExport(profile)
    local copy = DeepCopy(profile or {})
    -- These describe one character's Ebonhold spec slots, not the shared UI.
    if type(copy.blizzard) == "table" then
        copy.blizzard.talentSpecNames = nil
        copy.blizzard.talentSpecIcons = nil
    end
    -- Legacy development preview state is intentionally not portable.
    copy.testFrame = nil
    if type(copy.movers) == "table" then copy.movers.TestPanel = nil end
    return copy
end

local function UniqueProfileName(base)
    base = SanitizeProfileName(base) or "Imported"
    if not RUI.dbRoot or not RUI.dbRoot.profiles then return base end
    if not RUI.dbRoot.profiles[base] then return base end
    local stem = base .. " (Imported)"
    if not RUI.dbRoot.profiles[stem] then return stem end
    local index = 2
    while RUI.dbRoot.profiles[stem .. " " .. tostring(index)] do index = index + 1 end
    return stem .. " " .. tostring(index)
end

function RUI:GetProfileNames()
    local names = {}
    local profiles = self.dbRoot and self.dbRoot.profiles or {}
    for name in pairs(profiles) do table.insert(names, tostring(name)) end
    table.sort(names, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return string.lower(a) < string.lower(b)
    end)
    return names
end

local function ApplyModuleSettingsPass(rui)
    -- PROFILE_RESET remains the normal public notification, but a live profile
    -- switch needs a deterministic second pass after the database pointer has
    -- changed. Several modules rebuild/resize holders in ApplySettings(); on a
    -- reload that naturally happens before movers are positioned, while the old
    -- live-switch path could let a later module rebuild overwrite the mover
    -- position that had just been restored.
    for i = 1, #(rui.moduleOrder or {}) do
        local module = rui.modules and rui.modules[rui.moduleOrder[i]]
        if module and module.enabled and type(module.ApplySettings) == "function" then
            local ok, err = pcall(module.ApplySettings, module)
            if not ok then rui:ReportRuntimeError("Profile", module.name or "ApplySettings", err) end
        end
    end
end

local function ScheduleProfileFinalize(rui, profileName)
    if not CreateFrame then return end
    if not rui.profileFinalizeFrame then
        local frame = CreateFrame("Frame", "ZenUIProfileFinalize", UIParent)
        frame:Hide()
        frame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + (tonumber(elapsed) or 0)
            if self.elapsed < (self.delay or 0.12) then return end
            self:Hide()
            self.elapsed = 0

            if InCombatLockdown and InCombatLockdown() then return end
            if not self.profileName or rui.profileName ~= self.profileName then return end

            -- Some Ebonhold frames rebuild one frame after a profile change.
            -- Mirror login ordering once more after that delayed work, then put
            -- movers last. This is a one-shot finalize, never a background poll.
            ApplyModuleSettingsPass(rui)
            if rui.ApplyAllMovers then rui:ApplyAllMovers() end
            local actionBars = rui.GetModule and rui:GetModule("ActionBars")
            if actionBars and actionBars.ScheduleNativeLayoutRepair then
                actionBars:ScheduleNativeLayoutRepair(1.0)
            end
            if rui.RefreshMoverControlWindow then rui:RefreshMoverControlWindow() end
        end)
        rui.profileFinalizeFrame = frame
    end

    local frame = rui.profileFinalizeFrame
    frame.profileName = profileName
    frame.elapsed = 0
    frame.delay = 0.12
    frame:Show()
end

function RUI:ApplyProfile(name, reason)
    name = SanitizeProfileName(name)
    if not name or not self.dbRoot or not self.dbRoot.profiles or not self.dbRoot.profiles[name] then
        return false, "Profile not found."
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Profiles cannot be switched during combat."
    end
    if self.moverMode and self.SetMoverMode then self:SetMoverMode(false) end

    if self.EnsureProfileDefaults then self:EnsureProfileDefaults(self.dbRoot.profiles[name]) end
    local characterKey = self:GetCharacterKey()
    self.dbRoot.profileKeys[characterKey] = name
    self.profileName = name
    self.db = self.dbRoot.profiles[name]

    -- Tell every existing subsystem that its backing profile table changed.
    self:FireCallback("PROFILE_RESET", name)
    self:FireCallback("COMPONENT_SCALE_CHANGED", "all")
    self:ApplyAppearance(reason or "profile-change")

    -- Re-run settings in module load order, then position movers LAST. This
    -- mirrors the effective login order and prevents Action Bars, Unit Frames,
    -- Chat, Minimap, panels, etc. from clearing/replacing profile mover anchors
    -- after they have been restored.
    ApplyModuleSettingsPass(self)
    if self.ApplyAllMovers then self:ApplyAllMovers() end
    if self.RefreshMoverControlWindow then self:RefreshMoverControlWindow() end
    ScheduleProfileFinalize(self, name)

    self:FireCallback("PROFILE_CHANGED", name)
    return true
end

function RUI:SaveProfileAs(name)
    name = SanitizeProfileName(name)
    if not name then return false, "Enter a profile name." end
    if not self.dbRoot or not self.db then return false, "Profile database is unavailable." end
    if self.dbRoot.profiles[name] then return false, "A profile named '" .. name .. "' already exists." end
    if InCombatLockdown and InCombatLockdown() then return false, "Profiles cannot be created during combat." end

    self.dbRoot.profiles[name] = DeepCopy(self.db)
    return self:ApplyProfile(name, "profile-save-as")
end

function RUI:DeleteProfile(name)
    name = SanitizeProfileName(name)
    if not name or not self.dbRoot or not self.dbRoot.profiles[name] then return false, "Profile not found." end
    if name == "Default" then return false, "The Default profile cannot be deleted." end
    if name == self.profileName then return false, "Switch to another profile before deleting this one." end
    self.dbRoot.profiles[name] = nil
    for characterKey, profileName in pairs(self.dbRoot.profileKeys or {}) do
        if profileName == name then self.dbRoot.profileKeys[characterKey] = "Default" end
    end
    self:FireCallback("PROFILE_LIST_CHANGED")
    return true
end

function RUI:ExportProfile(name)
    name = SanitizeProfileName(name or self.profileName)
    if not name or not self.dbRoot or not self.dbRoot.profiles[name] then return nil, "Profile not found." end
    local envelope = {
        format = EXPORT_FORMAT,
        addon = "ZenUI",
        version = tostring(self.version or "unknown"),
        schema = tonumber(self:GetDatabaseSchema()) or 0,
        name = name,
        profile = CopyForExport(self.dbRoot.profiles[name]),
    }
    local serialized, err = Serialize(envelope)
    if not serialized then return nil, err end
    return EXPORT_PREFIX .. Base64Encode(serialized)
end

function RUI:ImportProfile(text, requestedName)
    if InCombatLockdown and InCombatLockdown() then return false, "Profiles cannot be imported during combat." end
    text = Trim(text)
    if string.len(text) > MAX_IMPORT_BYTES then return false, "Import string is too large." end
    local prefix = nil
    if string.sub(text, 1, string.len(EXPORT_PREFIX)) == EXPORT_PREFIX then
        prefix = EXPORT_PREFIX
    elseif string.sub(text, 1, string.len(LEGACY_EXPORT_PREFIX)) == LEGACY_EXPORT_PREFIX then
        prefix = LEGACY_EXPORT_PREFIX
    else
        return false, "This is not a ZenUI profile string."
    end
    local decoded, err = Base64Decode(string.sub(text, string.len(prefix) + 1))
    if not decoded then return false, err end
    if string.len(decoded) > MAX_IMPORT_BYTES then return false, "Decoded profile is too large." end
    local envelope
    envelope, err = Deserialize(decoded)
    if not envelope then return false, err end
    local sourceAddon = type(envelope) == "table" and envelope.addon or nil
    if type(envelope) ~= "table" or (sourceAddon ~= "ZenUI" and sourceAddon ~= "RavioliUI") or tonumber(envelope.format) ~= EXPORT_FORMAT then
        return false, "Unsupported ZenUI profile format."
    end
    local importedSchema = tonumber(envelope.schema) or 0
    local currentSchema = tonumber(self:GetDatabaseSchema()) or 0
    if importedSchema > currentSchema then
        return false, "This profile was created by a newer ZenUI database. Update ZenUI before importing it."
    end
    if type(envelope.profile) ~= "table" then return false, "The profile string does not contain UI settings." end

    local name = requestedName and SanitizeProfileName(requestedName) or nil
    if not name then name = SanitizeProfileName(envelope.name) or "Imported" end
    name = UniqueProfileName(name)

    local profile = DeepCopy(envelope.profile)
    if self.MigrateLegacyBrandKeys then self:MigrateLegacyBrandKeys(profile) end
    if self.EnsureProfileDefaults then self:EnsureProfileDefaults(profile) end
    -- Never accept character-specific data even if a future/hand-edited string includes it.
    if type(profile.blizzard) == "table" then
        profile.blizzard.talentSpecNames = {}
        profile.blizzard.talentSpecIcons = {}
    end
    self.dbRoot.profiles[name] = profile
    self:FireCallback("PROFILE_LIST_CHANGED")
    local ok, applyErr = self:ApplyProfile(name, "profile-import")
    if not ok then
        self.dbRoot.profiles[name] = nil
        return false, applyErr
    end
    return true, name
end
