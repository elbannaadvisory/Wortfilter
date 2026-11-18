-- Word replacement rule editor. /wf, /wort, /wortfilter
local WF = Wortfilter
local editor
local selected
local widgets = {}

local function ignoreLabel(region)
    if region then WF.IgnoreFontString(region) end
    return region
end

local function label(parent, text, x, y, size)
    local fs = ignoreLabel(parent:CreateFontString(nil, "OVERLAY", size or "GameFontNormal"))
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function button(parent, text, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    ignoreLabel(b.GetFontString and b:GetFontString())
    b:SetText(text)
    b:SetScript("OnClick", callback)
    return b
end

local function input(parent, x, y, width, maxLength)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width, 24)
    e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    e:SetAutoFocus(false)
    e:SetMaxLetters(maxLength)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

local function checkbox(parent, text, x, y)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local textRegion = b.Text or (b.GetFontString and b:GetFontString())
    if not textRegion then
        textRegion = label(parent, text, x + 28, y - 5, "GameFontNormalSmall")
    else
        ignoreLabel(textRegion)
        textRegion:SetText(text)
    end
    return b
end

local function status(text, isError)
    if not widgets.status then return end
    widgets.status:SetText(text)
    if isError then
        widgets.status:SetTextColor(1, 0.35, 0.35)
    else
        widgets.status:SetTextColor(0.42, 0.9, 0.62)
    end
end

local function preview()
    if not widgets.previewInput or not widgets.previewOutput then return end
    local inputText = widgets.previewInput:GetText() or ""
    widgets.previewOutput:SetText("Ergebnis: " .. WF.Replace(inputText, true))
end

local function selectRule(index)
    local rule = index and WF.GetRules()[index]
    selected = rule and index or nil
    if rule then
        widgets.pattern:SetText(rule.pattern)
        widgets.replacement:SetText(rule.replacement)
        widgets.isPattern:SetChecked(rule.usePattern ~= false)
        widgets.ruleEnabled:SetChecked(rule.enabled ~= false)
        status("Regel " .. index .. " ausgewählt.")
    else
        widgets.pattern:SetText("")
        widgets.replacement:SetText("")
        widgets.isPattern:SetChecked(false)
        widgets.ruleEnabled:SetChecked(true)
        status("Neue Regel: Suchtext und Ersetzung eingeben, dann speichern.")
    end
    if WF.RefreshUI then WF.RefreshUI() end
end

function WF.RefreshUI()
    if not editor then return end
    local rules = WF.GetRules()
    widgets.mainEnabled:SetChecked(WF.IsEnabled())
    widgets.count:SetText(tostring(#rules) .. " Regeln (Reihenfolge = Ausführungsreihenfolge)")
    widgets.scrollChild:SetHeight(math.max(175, #rules * 27))
    for i = 1, #rules do
        local rule = rules[i]
        local row = widgets.rows[i]
        if not row then
            row = CreateFrame("Button", nil, widgets.scrollChild, "UIPanelButtonTemplate")
            row:SetSize(660, 25)
            row:SetPoint("TOPLEFT", widgets.scrollChild, "TOPLEFT", 0, -((i - 1) * 27))
            ignoreLabel(row.GetFontString and row:GetFontString())
            row:SetScript("OnClick", function() selectRule(i) end)
            widgets.rows[i] = row
        end
        local prefix = (selected == i) and "> " or "  "
        local activeText = rule.enabled == false and "[AUS] " or ""
        local modeText = rule.usePattern == false and "[Text] " or "[Lua] "
        local shortPattern = rule.pattern:sub(1, 54)
        local shortReplacement = rule.replacement:sub(1, 45)
        row:SetText(prefix .. i .. ". " .. activeText .. modeText .. shortPattern .. "  =>  " .. shortReplacement)
        row:Show()
    end
    for i = #rules + 1, #widgets.rows do widgets.rows[i]:Hide() end
    preview()
end

local function editedRule()
    return {
        pattern = widgets.pattern:GetText() or "",
        replacement = widgets.replacement:GetText() or "",
        usePattern = widgets.isPattern:GetChecked() == true,
        enabled = widgets.ruleEnabled:GetChecked() == true,
    }
end

local function saveRule()
    local rule = editedRule()
    local ok, result
    if selected then
        ok, result = WF.UpdateRule(selected, rule)
    else
        ok, result = WF.AddRule(rule)
        if ok then selected = result end
    end
    if not ok then status(tostring(result), true); return end
    WF.RefreshUI()
    status("Regel gespeichert. Änderungen gelten sofort.")
end

function WF.ToggleUI()
    if editor then
        if editor:IsShown() then editor:Hide() else editor:Show(); WF.RefreshUI() end
        return
    end
    editor = CreateFrame("Frame", "WortfilterOptions", UIParent, "BasicFrameTemplateWithInset")
    editor:SetSize(760, 600)
    editor:SetPoint("CENTER")
    editor:SetFrameStrata("DIALOG")
    editor:SetMovable(true)
    editor:EnableMouse(true)
    editor:RegisterForDrag("LeftButton")
    editor:SetScript("OnDragStart", editor.StartMoving)
    editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
    if editor.TitleText then
        ignoreLabel(editor.TitleText)
        -- First visible line of the addon editor; exempted from filtering above.
        editor.TitleText:SetText("Jemand könnte sagen ")
    end
    if editor.CloseButton and editor.CloseButton.SetScript then
        editor.CloseButton:SetScript("OnClick", function() editor:Hide() end)
    end
    widgets.mainEnabled = checkbox(editor, "Wortfilter aktiviert", 20, -42)
    widgets.mainEnabled:SetScript("OnClick", function(self)
        WF.SetEnabled(self:GetChecked() == true)
        WF.RefreshUI()
    end)
    widgets.count = label(editor, "", 300, -52, "GameFontNormalSmall")
    label(editor, "Gespeicherte Regeln (anklicken zum Bearbeiten)", 20, -79)

    widgets.scroll = CreateFrame("ScrollFrame", nil, editor, "UIPanelScrollFrameTemplate")
    widgets.scroll:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -102)
    widgets.scroll:SetSize(700, 177)
    widgets.scrollChild = CreateFrame("Frame", nil, widgets.scroll)
    widgets.scrollChild:SetSize(667, 177)
    widgets.scroll:SetScrollChild(widgets.scrollChild)
    widgets.rows = {}

    label(editor, "Suchmuster / Wort", 28, -300)
    label(editor, "Ersetzen durch (leer = löschen)", 450, -300)
    widgets.pattern = input(editor, 35, -321, 391, 160)
    widgets.replacement = input(editor, 458, -321, 260, 320)
    widgets.isPattern = checkbox(editor, "Lua-Pattern (%, [], (), + usw.)", 30, -357)
    widgets.ruleEnabled = checkbox(editor, "Regel aktiv", 392, -357)

    button(editor, "Neu", 28, -397, 82, function() selectRule(nil) end)
    button(editor, "Speichern", 115, -397, 107, saveRule)
    button(editor, "Löschen", 228, -397, 94, function()
        if not selected then status("Bitte zuerst eine Regel auswählen.", true); return end
        WF.DeleteRule(selected)
        selectRule(nil)
        status("Regel gelöscht.")
    end)
    button(editor, "Nach oben", 329, -397, 102, function()
        if selected and WF.MoveRule(selected, -1) then selected = selected - 1; WF.RefreshUI() end
    end)
    button(editor, "Nach unten", 438, -397, 102, function()
        if selected and WF.MoveRule(selected, 1) then selected = selected + 1; WF.RefreshUI() end
    end)
    button(editor, "Standard", 548, -397, 100, function()
        WF.RestoreDefaults()
        selectRule(1)
        status("Die drei Gott-/Gött-Regeln wurden wiederhergestellt.")
    end)

    label(editor, "Live-Vorschau (unabhängig vom Ein-/Aus-Schalter)", 28, -445)
    widgets.previewInput = input(editor, 35, -469, 680, 500)
    widgets.previewOutput = label(editor, "", 28, -504, "GameFontHighlight")
    widgets.previewOutput:SetWidth(685)
    widgets.previewOutput:SetJustifyH("LEFT")
    widgets.previewInput:SetScript("OnTextChanged", preview)
    widgets.previewInput:SetText("Gott, Gottes, Göttin, Götter und GÖTTLICH")

    widgets.status = label(editor, "", 28, -548, "GameFontNormalSmall")
    widgets.status:SetWidth(690)
    widgets.status:SetJustifyH("LEFT")
    label(editor, "Tipp: Einfache Wörter ohne Lua-Pattern eintragen. /wf scan prüft vorhandene Texte erneut.", 28, -571, "GameFontDisableSmall")
    if UISpecialFrames then table.insert(UISpecialFrames, "WortfilterOptions") end
    selectRule(1)
    editor:Show()
end
