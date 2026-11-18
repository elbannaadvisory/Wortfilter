-- Wortfilter: attack/spell/ability display surfaces (client-only).
-- Never override C_Spell, spell IDs, action buttons' secure attributes or casting APIs.
local WF = Wortfilter
local installed = false
local hookedFrames = setmetatable({}, { __mode = "k" })

local TOOLTIP_TYPES = { "Spell", "UnitAura", "Aura", "Item", "Action" }
local TOOLTIP_NAMES = {
    "GameTooltip", "ItemRefTooltip",
    "ShoppingTooltip1", "ShoppingTooltip2",
    "GameSmallHeaderTooltip", "GameTooltipTooltip",
}
local ABILITY_FRAME_NAMES = {
    "PlayerSpellsFrame", "SpellBookFrame",
    "SpellBookFrameTabButton1", "PetSpellBookFrame",
    "SpellFlyout", "SpellFlyoutPopup",
    "CastingBarFrame", "PetCastingBarFrame",
    "TargetFrameSpellBar", "FocusFrameSpellBar",
    "ActionBarFrame", "MainMenuBar", "MultiBarBottomLeft",
    "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "PetActionBarFrame", "StanceBarFrame",
}

local function scan(frame)
    if not frame or type(WF.ScanFrame) ~= "function" then return 0 end
    local ok, count = pcall(WF.ScanFrame, frame)
    if ok and type(count) == "number" then return count end
    return 0
end

-- A public entry point for ability screens and post-processed tooltips.
-- A nil frame means rescan known spellbook, action bar and cast bar surfaces.
function WF.RefreshAbilityText(frame)
    if frame ~= nil then return scan(frame) end
    local count = 0
    for _, name in ipairs(TOOLTIP_NAMES) do
        count = count + scan(_G[name])
    end
    for _, name in ipairs(ABILITY_FRAME_NAMES) do
        count = count + scan(_G[name])
    end
    return count
end

local function attachOnShow(frame)
    if not frame or hookedFrames[frame] then return end
    if type(frame.HookScript) ~= "function" then return end
    local ok = pcall(frame.HookScript, frame, "OnShow", function(shown)
        WF.RefreshAbilityText(shown)
    end)
    if ok then hookedFrames[frame] = true end
end

local function hookKnownFrames()
    for _, name in ipairs(TOOLTIP_NAMES) do attachOnShow(_G[name]) end
    for _, name in ipairs(ABILITY_FRAME_NAMES) do attachOnShow(_G[name]) end
end

local function registerTooltipProcessor()
    local processor = TooltipDataProcessor
    local dataTypes = Enum and Enum.TooltipDataType
    if type(processor) ~= "table"
        or type(processor.AddTooltipPostCall) ~= "function"
        or type(dataTypes) ~= "table" then
        return false
    end
    local count = 0
    for _, kind in ipairs(TOOLTIP_TYPES) do
        local id = dataTypes[kind]
        if type(id) == "number" then
            local ok = pcall(processor.AddTooltipPostCall, id, function(tooltip)
                WF.RefreshAbilityText(tooltip)
            end)
            if ok then count = count + 1 end
        end
    end
    return count > 0
end

-- Called once at module initialization; safe to re-enter from later events.
function WF.RegisterAbilityHooks()
    if not installed then
        registerTooltipProcessor()
        installed = true
    end
    -- Frame lookups repeated for spellbook frames created by load-on-demand UI.
    hookKnownFrames()
end

local function scheduleScan()
    if C_Timer and type(C_Timer.After) == "function" then
        local ok = pcall(C_Timer.After, 0, WF.RefreshAbilityText)
        if ok then return end
    end
    WF.RefreshAbilityText()
end

if type(CreateFrame) == "function" then
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("SPELLS_CHANGED")
    watcher:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    watcher:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    watcher:RegisterEvent("UNIT_SPELLCAST_START")
    watcher:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    watcher:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
            WF.RegisterAbilityHooks()
        end
        if event ~= "ADDON_LOADED" then scheduleScan() end
    end)
end
WF.RegisterAbilityHooks()
