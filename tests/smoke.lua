-- Standalone Lua smoke test (outside WoW). Run via lua tests/smoke.lua
local frames = {}
local chatFilters = {}
local fsMethods = {}
local fsMeta = { __index = fsMethods }
function fsMethods:SetText(text) self.value = text end
function fsMethods:GetText() return self.value end
function fsMethods:GetObjectType() return "FontString" end

local function newFS()
    local fs = setmetatable({}, fsMeta)
    frames[#frames + 1] = fs
    return fs
end
UIParent = {
    CreateFontString = function() return newFS() end,
    GetRegions = function() return (table.unpack or unpack)(frames) end,
    GetChildren = function() end,
}
local eventFrame = {events = {}}
function eventFrame:RegisterEvent(event) self.events[event] = true end
function eventFrame:SetScript(_, callback) self.callback = callback end
function CreateFrame() return eventFrame end
function hooksecurefunc(tbl, name, callback)
    local original = tbl[name]
    tbl[name] = function(...)
        local result = original(...)
        callback(...)
        return result
    end
end
function ChatFrame_AddMessageEventFilter(event, callback) chatFilters[event] = callback end
SlashCmdList = {}

local path = "Wortfilter/"
dofile(path .. "Wortfilter_Defaults.lua")
assert(loadfile(path .. "Wortfilter_Core.lua"))("Wortfilter")
eventFrame.callback(eventFrame, "ADDON_LOADED", "Wortfilter")
local WF = Wortfilter

local function eq(actual, expected)
    assert(actual == expected, "EXPECTED " .. tostring(expected) .. " but GOT " .. tostring(actual))
end

eq(WF.Replace("Gott Gottes Göttin Götter gottgleich GÖTTLICH"),
   "ott ottes öttin ötter ottgleich ÖTTLICH")
eq(WF.Replace("Ein göttlicher Gott"), "Ein öttlicher ott")
eq(#WF.GetRules(), 3)
local first = newFS()
first:SetText("Gott und Götter")
eq(first:GetText(), "ott und ötter")

local ok = WF.AddRule({pattern="König", replacement="Kaiser", usePattern=false, enabled=true})
assert(ok)
eq(WF.Replace("Der König dankt Gott."), "Der Kaiser dankt ott.")
local third = newFS()
third:SetText("Der König dankt Gott.")
eq(third:GetText(), "Der Kaiser dankt ott.")
WF.SetEnabled(false)
eq(first:GetText(), "Gott und Götter")
eq(third:GetText(), "Der König dankt Gott.")
WF.SetEnabled(true)
eq(third:GetText(), "Der Kaiser dankt ott.")

ok = WF.AddRule({pattern="(%d+) Wölfe", replacement="%1 Füchse", usePattern=true})
assert(ok)
eq(WF.Replace("Töte 10 Wölfe"), "Töte 10 Füchse")
local invalid = WF.AddRule({pattern="[", replacement="x", usePattern=true})
assert(not invalid)
invalid = WF.AddRule({pattern="%s*", replacement="x", usePattern=true})
assert(not invalid)
invalid = WF.AddRule({pattern="foo", replacement="%z", usePattern=false})
assert(not invalid)
assert(WF.MoveRule(5, -1))
assert(WF.DeleteRule(5))
WF.RestoreDefaults()
eq(#WF.GetRules(), 3)
eq(WF.Replace("Der König ist ein Gott."), "Der König ist ein ott.")
assert(type(chatFilters.CHAT_MSG_SAY) == "function")
local rejected, text = chatFilters.CHAT_MSG_SAY(nil, nil, "Gott!", "Tester")
assert(rejected == false and text == "ott!")
-- UI constructor and button interactions under a small WoW frame mock.
local createdWidgets = {}
function fsMethods:SetPoint() end
function fsMethods:SetWidth() end
function fsMethods:SetJustifyH() end
function fsMethods:SetTextColor() end
local frameMethods = {}
for _, method in ipairs({ "SetSize", "SetPoint", "SetFrameStrata", "SetMovable", "EnableMouse",
    "RegisterForDrag", "SetAutoFocus", "SetMaxLetters", "SetScrollChild", "SetHeight",
    "SetWidth", "SetJustifyH", "ClearFocus", "StartMoving", "StopMovingOrSizing"}) do
    frameMethods[method] = function() end
end
function frameMethods:SetScript(event, action) self.scripts[event] = action end
function frameMethods:CreateFontString() return newFS() end
function frameMethods:SetText(value)
    self.value = value
    if self.fontString then self.fontString:SetText(value) end
end
function frameMethods:GetText() return self.value or "" end
function frameMethods:GetFontString() return self.fontString end
function frameMethods:SetChecked(value) self.checked = value end
function frameMethods:GetChecked() return self.checked end
function frameMethods:Show() self.visible = true end
function frameMethods:Hide() self.visible = false end
function frameMethods:IsShown() return self.visible end
function CreateFrame(frameType, name, parent, template)
    local frame = setmetatable({ scripts = {}, visible = false }, { __index = frameMethods })
    frame.frameType, frame.template, frame.name = frameType, template, name
    createdWidgets[#createdWidgets + 1] = frame
    if name then _G[name] = frame end
    if template == "UIPanelButtonTemplate" then frame.fontString = newFS() end
    if template == "UICheckButtonTemplate" then frame.Text = newFS() end
    if template == "BasicFrameTemplateWithInset" then
        frame.TitleText = newFS()
        frame.CloseButton = setmetatable({ scripts = {} }, {__index = frameMethods})
    end
    return frame
end
UISpecialFrames = {}
dofile(path .. "Wortfilter_UI.lua")
WF.ToggleUI()
assert(WortfilterOptions and WortfilterOptions:IsShown())
local function widgetByText(text)
    for _, w in ipairs(createdWidgets) do if w.value == text then return w end end
end
local function widgetByPosition(x, y)
    for _, w in ipairs(createdWidgets) do
        if w.x == x and w.y == y then return w end
    end
end
-- Position-aware test for buttons and text inputs.
frameMethods.SetPoint = function(self, _, _, _, x, y) self.x, self.y = x, y end
local newButton = widgetByText("Neu")
assert(newButton and newButton.scripts.OnClick)
newButton.scripts.OnClick(newButton)
local patterns = {}
for _, w in ipairs(createdWidgets) do
    if w.frameType == "EditBox" then patterns[#patterns + 1] = w end
end
assert(#patterns == 3)
patterns[1]:SetText("Sturmwind")
patterns[2]:SetText("Sonnenstadt")
local saveButton = widgetByText("Speichern")
assert(saveButton and saveButton.scripts.OnClick)
saveButton.scripts.OnClick(saveButton)
eq(WF.Replace("Sturmwind und Gott"), "Sonnenstadt und ott")
assert(#WF.GetRules() == 4)
print("PASS: rule engine, font hooks, runtime changes, validation, chat, UI window and in-game add/save")
