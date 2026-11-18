-- Wortfilter 0.2.0 | World of Warcraft: Forever (Interface 16001)
-- All substitutions are local display changes. No client files or server data are modified.
local addonName = ...
local WF = Wortfilter
local FONTSTRING_SCAN_LIMIT = 20000
local MAX_RULES = 100
local MAX_PATTERN_BYTES = 160
local MAX_REPLACEMENT_BYTES = 320
local rawTexts = setmetatable({}, { __mode = "k" })
local ignoredFontStrings = setmetatable({}, { __mode = "k" })
local originalSetText
local internalWrite = false
local initialized = false

local function safeString(value)
    if issecretvalue and issecretvalue(value) then return false end
    return type(value) == "string"
end

local function echo(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff68d9ffWortfilter:|r " .. tostring(message))
    elseif print then
        print("Wortfilter: " .. tostring(message))
    end
end
WF.Echo = echo

local function duplicateRules(source)
    local copy = {}
    for i = 1, #source do
        local r = source[i]
        if type(r) == "table" and safeString(r.pattern) and safeString(r.replacement) then
            copy[#copy + 1] = {
                pattern = r.pattern,
                replacement = r.replacement,
                usePattern = r.usePattern ~= false,
                enabled = r.enabled ~= false,
            }
        end
    end
    return copy
end
WF.CopyRules = duplicateRules

function WF.GetRules()
    return (type(WortfilterDB) == "table" and WortfilterDB.rules) or WF.DEFAULT_RULES
end

function WF.IsEnabled()
    return type(WortfilterDB) ~= "table" or WortfilterDB.enabled ~= false
end

local function escapedLiteral(pattern)
    return (pattern:gsub("(%W)", "%%%1"))
end

function WF.ValidateRule(rule)
    if type(rule) ~= "table" or not safeString(rule.pattern) or not safeString(rule.replacement) then
        return false, "Suchmuster und Ersetzung müssen Texte sein."
    end
    if rule.pattern == "" then return false, "Das Suchmuster darf nicht leer sein." end
    if #rule.pattern > MAX_PATTERN_BYTES or #rule.replacement > MAX_REPLACEMENT_BYTES then
        return false, "Suchmuster oder Ersetzung ist zu lang."
    end
    if rule.usePattern ~= false then
        local ok, errorText = pcall(string.find, "", rule.pattern)
        if not ok then return false, "Ungültiges Lua-Muster: " .. tostring(errorText) end
        -- Reject patterns capable of matching the empty string; these can rewrite all text.
        local okEmpty, start, finish = pcall(string.find, "", rule.pattern)
        if okEmpty and start ~= nil and finish < start then
            return false, "Das Lua-Muster darf keine leere Zeichenfolge treffen."
        end
    end
    -- Lua gsub interprets % escapes in replacement strings in both modes.
    for escape in rule.replacement:gmatch("%%(.)") do
        if escape ~= "%" and not escape:match("^[0-9]$") then
            return false, "In Ersetzungen sind nur %%0 bis %%9 und %%%% erlaubt."
        end
    end
    if rule.replacement:sub(-1) == "%" and not rule.replacement:sub(-2):match("%%%%$") then
        return false, "Ein einzelnes %% am Ende ist ungültig."
    end
    return true
end

-- Returns the translated output; rules are applied sequentially in list order.
function WF.Replace(text, ignoreMasterSwitch)
    if not safeString(text) or (not ignoreMasterSwitch and not WF.IsEnabled()) then return text end
    for _, rule in ipairs(WF.GetRules()) do
        if rule.enabled ~= false and safeString(rule.pattern) and rule.pattern ~= "" and safeString(rule.replacement) then
            local pattern = rule.usePattern == false and escapedLiteral(rule.pattern) or rule.pattern
            local ok, replaced = pcall(string.gsub, text, pattern, rule.replacement)
            if ok then text = replaced end
        end
    end
    return text
end

function WF.IgnoreFontString(fontString)
    if fontString then ignoredFontStrings[fontString] = true end
end

local function putFontText(fontString, original)
    if not originalSetText or ignoredFontStrings[fontString] or not safeString(original) then return end
    local translated = WF.Replace(original)
    if translated == original then return end
    internalWrite = true
    pcall(originalSetText, fontString, translated)
    internalWrite = false
end

local function catchSetText(fontString, original)
    if internalWrite or ignoredFontStrings[fontString] then return end
    if safeString(original) then
        rawTexts[fontString] = original
        putFontText(fontString, original)
    elseif original == nil then
        rawTexts[fontString] = nil
    end
end

local function inspectFontString(fontString)
    if ignoredFontStrings[fontString] then return end
    local ok, current = pcall(fontString.GetText, fontString)
    if not ok or not safeString(current) then return end
    if rawTexts[fontString] == nil then rawTexts[fontString] = current end
    local original = rawTexts[fontString]
    local translated = WF.Replace(original)
    if current ~= translated and originalSetText then
        internalWrite = true
        pcall(originalSetText, fontString, translated)
        internalWrite = false
    end
end

function WF.ScanFonts()
    if not originalSetText or not UIParent then return 0 end
    local stack, processed = { UIParent }, 0
    while #stack > 0 and processed < FONTSTRING_SCAN_LIMIT do
        local frame = stack[#stack]
        stack[#stack] = nil
        processed = processed + 1
        if frame then
            if type(frame.GetRegions) == "function" then
                local result = { pcall(frame.GetRegions, frame) }
                if table.remove(result, 1) then
                    for _, region in ipairs(result) do
                        local ok, objectType = pcall(region.GetObjectType, region)
                        if ok and objectType == "FontString" then inspectFontString(region) end
                    end
                end
            end
            if type(frame.GetChildren) == "function" then
                local result = { pcall(frame.GetChildren, frame) }
                if table.remove(result, 1) then
                    for _, child in ipairs(result) do stack[#stack + 1] = child end
                end
            end
        end
    end
    return processed
end

function WF.Reapply()
    if originalSetText then
        for fontString, original in pairs(rawTexts) do
            if safeString(original) and not ignoredFontStrings[fontString] then
                local text = WF.Replace(original)
                internalWrite = true
                pcall(originalSetText, fontString, text)
                internalWrite = false
            end
        end
    end
    WF.ScanFonts()
end

function WF.SetEnabled(value)
    if type(WortfilterDB) ~= "table" then return end
    WortfilterDB.enabled = (value == true)
    WF.Reapply()
end

function WF.AddRule(rule)
    local valid, reason = WF.ValidateRule(rule)
    if not valid then return false, reason end
    local rules = WF.GetRules()
    if #rules >= MAX_RULES then return false, "Maximal " .. MAX_RULES .. " Regeln möglich." end
    rules[#rules + 1] = {
        pattern = rule.pattern, replacement = rule.replacement,
        usePattern = rule.usePattern ~= false, enabled = rule.enabled ~= false,
    }
    WF.Reapply()
    return true, #rules
end

function WF.UpdateRule(index, rule)
    local rules = WF.GetRules()
    if type(index) ~= "number" or index < 1 or index > #rules then return false, "Regel nicht gefunden." end
    local valid, reason = WF.ValidateRule(rule)
    if not valid then return false, reason end
    rules[index] = {
        pattern = rule.pattern, replacement = rule.replacement,
        usePattern = rule.usePattern ~= false, enabled = rule.enabled ~= false,
    }
    WF.Reapply()
    return true
end

function WF.DeleteRule(index)
    local rules = WF.GetRules()
    if type(index) ~= "number" or index < 1 or index > #rules then return false end
    table.remove(rules, index)
    WF.Reapply()
    return true
end

function WF.MoveRule(index, direction)
    local rules = WF.GetRules()
    local to = index + direction
    if index < 1 or index > #rules or to < 1 or to > #rules then return false end
    rules[index], rules[to] = rules[to], rules[index]
    WF.Reapply()
    return true
end

function WF.RestoreDefaults()
    WortfilterDB.rules = duplicateRules(WF.DEFAULT_RULES)
    WF.Reapply()
end

local function installFontHooks()
    if not UIParent or not UIParent.CreateFontString or type(hooksecurefunc) ~= "function" then
        echo("Die benötigten FontString-Hooks sind nicht verfügbar.")
        return
    end
    local sample = UIParent:CreateFontString(nil, "OVERLAY")
    local meta = getmetatable(sample)
    local methods = type(meta) == "table" and meta.__index
    if type(methods) ~= "table" or type(methods.SetText) ~= "function" then
        echo("FontString:SetText ist nicht hookbar; Chatfilter bleiben aktiv.")
        return
    end
    originalSetText = methods.SetText
    local ok = pcall(hooksecurefunc, methods, "SetText", catchSetText)
    if not ok then
        originalSetText = nil
        echo("Globaler FontString-Hook konnte nicht installiert werden.")
        return
    end
    if type(methods.SetFormattedText) == "function" then
        pcall(hooksecurefunc, methods, "SetFormattedText", function(self)
            if not internalWrite then
                local okRead, current = pcall(self.GetText, self)
                if okRead and safeString(current) then
                    rawTexts[self] = current
                    putFontText(self, current)
                end
            end
        end)
    end
    if type(methods.SetTextToFit) == "function" then
        pcall(hooksecurefunc, methods, "SetTextToFit", function(self)
            if not internalWrite then
                local okRead, current = pcall(self.GetText, self)
                if okRead and safeString(current) then
                    rawTexts[self] = current
                    putFontText(self, current)
                end
            end
        end)
    end
end

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_CURRENCY",
    "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE",
    "CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT",
}

local function chatFilter(_, _, message, sender, ...)
    if not safeString(message) or not WF.IsEnabled() then return false end
    local translated = WF.Replace(message)
    if translated == message then return false end
    return false, translated, sender, ...
end

local function installChatFilters()
    local register = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if type(register) ~= "function" then return end
    for _, eventName in ipairs(CHAT_EVENTS) do pcall(register, eventName, chatFilter) end
end

local function initialize()
    if initialized then return end
    initialized = true
    if type(WortfilterDB) ~= "table" then WortfilterDB = {} end
    if type(WortfilterDB.rules) ~= "table" then
        WortfilterDB.rules = duplicateRules(WF.DEFAULT_RULES)
    else
        WortfilterDB.rules = duplicateRules(WortfilterDB.rules)
    end
    if type(WortfilterDB.enabled) ~= "boolean" then WortfilterDB.enabled = true end
    installFontHooks()
    installChatFilters()
end

local function slash(message)
    message = (message or ""):match("^%s*(.-)%s*$")
    local command, arg = message:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""
    if command == "on" then
        WF.SetEnabled(true)
        echo("Aktiviert.")
    elseif command == "off" then
        WF.SetEnabled(false)
        echo("Deaktiviert; vorhandene Texte werden nach Möglichkeit zurückgesetzt.")
    elseif command == "test" then
        arg = arg ~= "" and arg or "Gott Gottes Göttin Götter gottgleich GÖTTLICH"
        echo(WF.Replace(arg, true))
    elseif command == "reset" then
        WF.RestoreDefaults()
        echo("Standardregeln wiederhergestellt.")
        if WF.RefreshUI then WF.RefreshUI() end
    elseif command == "scan" then
        echo("UI-Textobjekte überprüft: " .. tostring(WF.ScanFonts()))
    elseif command == "" or command == "ui" then
        if WF.ToggleUI then WF.ToggleUI() else echo("Oberfläche ist nicht verfügbar.") end
    else
        echo("/wf (Fenster) | /wf on | /wf off | /wf test [Text] | /wf scan | /wf reset")
    end
end
SLASH_WORTFILTER1 = "/wortfilter"
SLASH_WORTFILTER2 = "/wort"
SLASH_WORTFILTER3 = "/wf"
SlashCmdList.WORTFILTER = slash

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and (name == addonName or name == "Wortfilter") then
        initialize()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not initialized then initialize() end
        if C_Timer and C_Timer.After then C_Timer.After(1, WF.ScanFonts) else WF.ScanFonts() end
    end
end)
