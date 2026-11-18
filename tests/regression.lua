-- Focused unit/integration tests, each case names the API or WoW integration under test.
-- Executed under both Lua 5.1 (legacy WoW) and Lua 5.4.
local failures, results = 0, {}
local function assertEqual(actual, expected)
  if actual ~= expected then error("expected ["..tostring(expected).."] but got ["..tostring(actual).."]", 2) end
end
local function assertContains(value, needle)
  assert(type(value)=="string" and value:find(needle, 1, true), "expected message to contain "..needle)
end
local function case(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  results[#results+1] = {name=name, passed=ok, error=err}
  if ok then print("PASS "..name) else failures=failures+1; io.stderr:write("FAIL "..name.."\n"..tostring(err).."\n") end
end

local function setup(opts)
  opts = opts or {}
  _G.Wortfilter = nil
  _G.WortfilterDB = opts.saved
  _G.C_Timer = nil
  _G.ChatFrameUtil = nil
  _G.TooltipDataProcessor = nil
  _G.Enum = nil
  _G.GameTooltip = nil
  _G.PlayerSpellsFrame = nil
  _G.CastingBarFrame = nil
  _G.ActionBarFrame = nil
  _G.issecretvalue = nil
  _G.SlashCmdList = {}
  _G.UISpecialFrames = {}
  local frames, filters, messages, eventFrames, calls = {}, {}, {}, {}, {}
  local fsMethods = {}
  local fsMeta = {__index=fsMethods}
  function fsMethods:SetText(value) self.value = value end
  function fsMethods:GetText() return self.value end
  function fsMethods:GetObjectType() return "FontString" end
  function fsMethods:SetFormattedText(format, ...) self.value = string.format(format, ...) end
  function fsMethods:SetTextToFit(text) self.value = text end
  function fsMethods:SetPoint() end
  function fsMethods:SetWidth() end
  function fsMethods:SetJustifyH() end
  function fsMethods:SetTextColor(red,green,blue) self.color={red,green,blue} end
  local frameMethods={}
  local noop={"SetSize","SetFrameStrata","SetMovable","EnableMouse","RegisterForDrag","SetAutoFocus","SetMaxLetters","SetHeight","SetWidth","SetJustifyH","ClearFocus","StartMoving","StopMovingOrSizing","SetScrollChild"}
  for _,n in ipairs(noop) do frameMethods[n]=function() end end
  function frameMethods:SetPoint(point, parent, relative, x, y) self.position={x,y} end
  function frameMethods:GetRegions() return (table.unpack or unpack)(self.regions) end
  function frameMethods:GetChildren() return (table.unpack or unpack)(self.children) end
  function frameMethods:CreateFontString()
    local fs=setmetatable({parent=self},fsMeta)
    self.regions[#self.regions+1]=fs
    return fs
  end
  function frameMethods:SetScript(event, callback) self.scripts[event]=callback end
  function frameMethods:GetFontString() return self.font end
  function frameMethods:SetText(text)
    self.value = text
    if self.font then self.font:SetText(text) end
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
  end
  function frameMethods:GetText() return self.value or "" end
  function frameMethods:SetChecked(value) self.checked = value end
  function frameMethods:GetChecked() return self.checked end
  function frameMethods:Show() self.visible=true end
  function frameMethods:Hide() self.visible=false end
  function frameMethods:IsShown() return self.visible end
  local function makeFrame(typeName,name,parent,template)
    local frame=setmetatable({kind=typeName, name=name,template=template,children={},regions={},scripts={},visible=false}, {__index=frameMethods})
    frames[#frames+1]=frame
    if parent then parent.children[#parent.children+1]=frame end
    if name then _G[name]=frame end
    if template=="UIPanelButtonTemplate" then frame.font=frame:CreateFontString() end
    if template=="UICheckButtonTemplate" then frame.Text=frame:CreateFontString() end
    if template=="BasicFrameTemplateWithInset" then
      frame.TitleText=frame:CreateFontString()
      frame.CloseButton=makeFrame("Button",nil,frame,nil)
    end
    if typeName=="Frame" and parent==nil then eventFrames[#eventFrames+1]=frame end
    function frame:RegisterEvent(event) self.registered=self.registered or {}; self.registered[event]=true end
    return frame
  end
  _G.UIParent=makeFrame("Frame","UIParent",nil)
  _G.CreateFrame=makeFrame
  _G.ChatFrame_AddMessageEventFilter=function(event, cb) filters[event]=cb end
  _G.DEFAULT_CHAT_FRAME={AddMessage=function(_, message) messages[#messages+1]=message end}
  _G.hooksecurefunc=function(target,method, cb)
    calls[method]=(calls[method] or 0)+1
    if opts.hookFails then error("mock hook refused") end
    local orig=target[method]
    target[method]=function(...)
      local result=orig(...)
      cb(...)
      return result
    end
  end
  if opts.noUI then _G.UIParent=nil end
  if opts.noHook then _G.hooksecurefunc=nil end
  if opts.useChatFrameUtil then
    _G.ChatFrameUtil={AddMessageEventFilter=function(event,cb) filters[event]=cb end}
  end
  if opts.noChatAPI then _G.ChatFrame_AddMessageEventFilter=nil end
  if opts.delayedScan then
    _G.C_Timer={After=function(delay,cb) calls.timer=delay; cb() end}
  end
  dofile("Wortfilter/Wortfilter_Defaults.lua")
  assert(loadfile("Wortfilter/Wortfilter_Core.lua"))("Wortfilter")
  local eventFrame=eventFrames[#eventFrames]
  assert(eventFrame.scripts.OnEvent)
  local function emit(event,addon) eventFrame.scripts.OnEvent(eventFrame,event,addon) end
  if opts.beforeLoad then opts.beforeLoad() end
  if not opts.skipLoad then emit("ADDON_LOADED",opts.wrongAddon and "other-addon" or "Wortfilter") end
  local wf=_G.Wortfilter
  if opts.ui ~= false then dofile("Wortfilter/Wortfilter_UI.lua") end
  local function findButton(text)
    for _,f in ipairs(frames) do
      if f.kind=="Button" and f.value==text then return f end
    end
  end
  local function click(text)
    local btn=findButton(text)
    assert(btn and btn.scripts.OnClick, "Missing or unclickable button "..text)
    btn.scripts.OnClick(btn)
  end
  local function inputs()
    local all={}
    for _,f in ipairs(frames) do if f.kind=="EditBox" then all[#all+1]=f end end
    return all
  end
  return {wf=wf,frames=frames,filters=filters,messages=messages,calls=calls,emit=emit,
      create=makeFrame,fsMethods=fsMethods, click=click,inputs=inputs,
      slash=function(s) SlashCmdList.WORTFILTER(s) end}
end

case("WF.CopyRules copies tables, excludes invalid entries",function()
  local c=setup(); local src={{pattern="x",replacement="y",enabled=false,usePattern=false},{pattern=15,replacement="y"}}
  local clone=c.wf.CopyRules(src)
  assertEqual(#clone,1); assert(clone~=src and clone[1]~=src[1]); assertEqual(clone[1].enabled,false)
  src[1].replacement="changed"; assertEqual(clone[1].replacement,"y")
end)
case("WF.GetRules returns initialized defaults",function()
  local c=setup(); assertEqual(#c.wf.GetRules(),3); assert(c.wf.GetRules()==WortfilterDB.rules)
end)
case("WF.GetRules fallback before initialization",function()
  local c=setup({skipLoad=true}); assert(c.wf.GetRules()==c.wf.DEFAULT_RULES)
end)
case("WF.IsEnabled default and persisted disabled setting",function()
  local c=setup(); assert(c.wf.IsEnabled()); c.wf.SetEnabled(false); assert(not c.wf.IsEnabled())
end)
case("WF.Echo uses chat output",function()
  local c=setup(); c.wf.Echo("Hallo"); assertContains(c.messages[#c.messages],"Hallo")
end)
case("WF.ValidateRule accepts literal, pattern and captures",function()
  local c=setup(); for _,r in ipairs({
    {pattern="(Gott)",replacement="%1",usePattern=true},
    {pattern="a.b",replacement="x",usePattern=false},
    {pattern="g",replacement="",usePattern=false},
  }) do local ok,msg=c.wf.ValidateRule(r); assert(ok,msg) end
end)
case("WF.ValidateRule rejects malformed and empty search",function()
  local c=setup(); local invalid={nil,{}, {pattern="",replacement="x"},
    {pattern="[",replacement="z",usePattern=true},
    {pattern="%s*",replacement="z",usePattern=true},
    {pattern="x",replacement="%z",usePattern=false},
    {pattern="x",replacement="%",usePattern=false},
    {pattern=string.rep("a",161),replacement=""},
    {pattern="x",replacement=string.rep("a",321)},
    {pattern=1,replacement="x"}}
  for i,r in ipairs(invalid) do local ok=c.wf.ValidateRule(r); assert(not ok,"accepted invalid rule #"..i) end
end)
case("WF.Replace basic Gott/Gött substitution and case",function()
  local c=setup(); assertEqual(c.wf.Replace("Gott Gottes Göttin Götter gottgleich GÖTTLICH"),"ott ottes öttin ötter ottgleich ÖTTLICH")
end)
case("WF.Replace literal metacharacter and capture patterns",function()
  local c=setup(); assert(c.wf.AddRule({pattern="a.b",replacement="X",usePattern=false}))
  assertEqual(c.wf.Replace("a.b a-b"),"X a-b")
  assert(c.wf.AddRule({pattern="(%d+) Wölfe",replacement="%1 Füchse",usePattern=true}))
  assertEqual(c.wf.Replace("10 Wölfe"),"10 Füchse")
end)
case("WF.Replace disabled rule, disabled filter, nonstring",function()
  local c=setup(); assert(c.wf.AddRule({pattern="x",replacement="y",usePattern=false,enabled=false}))
  assertEqual(c.wf.Replace("x"),"x"); assertEqual(c.wf.Replace(nil),nil); assertEqual(c.wf.Replace(42),42)
  c.wf.SetEnabled(false); assertEqual(c.wf.Replace("Gott"),"Gott")
  assertEqual(c.wf.Replace("Gott",true),"ott")
end)
case("WF.Replace executes multiple rules in specified order",function()
  local c=setup(); assert(c.wf.AddRule({pattern="a",replacement="b",usePattern=false}))
  assert(c.wf.AddRule({pattern="b",replacement="c",usePattern=false}))
  assertEqual(c.wf.Replace("a"),"c")
end)
case("WF.AddRule persists and re-filters existing FontStrings",function()
  local c=setup(); local font=UIParent:CreateFontString(); font:SetText("König")
  local ok,index=c.wf.AddRule({pattern="König",replacement="Kaiser",usePattern=false})
  assert(ok); assertEqual(index,4); assertEqual(font:GetText(),"Kaiser")
end)
case("WF.AddRule rejects invalid and max 100 entries",function()
  local c=setup(); assert(not c.wf.AddRule({pattern="[",replacement="y"}))
  while #c.wf.GetRules()<100 do assert(c.wf.AddRule({pattern="unused-"..#c.wf.GetRules(),replacement="r",usePattern=false})) end
  local ok,message=c.wf.AddRule({pattern="another",replacement="z",usePattern=false}); assert(not ok); assertContains(message,"100")
end)
case("WF.UpdateRule replaces selected rule and rejects index/errors",function()
  local c=setup(); assert(c.wf.UpdateRule(1,{pattern="abc",replacement="def",usePattern=false}))
  assertEqual(c.wf.Replace("abc"),"def")
  assert(not c.wf.UpdateRule(0,{pattern="x",replacement="y"}))
  assert(not c.wf.UpdateRule(1,{pattern="[",replacement="x"}))
end)
case("WF.DeleteRule removes rule and rejects invalid index",function()
  local c=setup(); assert(c.wf.DeleteRule(1)); assertEqual(#c.wf.GetRules(),2)
  assert(not c.wf.DeleteRule(15)); assert(not c.wf.DeleteRule(0))
end)
case("WF.MoveRule reorders sequential replacements",function()
  local c=setup(); assert(c.wf.AddRule({pattern="a",replacement="b",usePattern=false}))
  assert(c.wf.AddRule({pattern="b",replacement="c",usePattern=false}))
  assert(c.wf.MoveRule(5,-1)); assertEqual(c.wf.Replace("a"),"b")
  assert(not c.wf.MoveRule(1,-1)); assert(not c.wf.MoveRule(5,1))
end)
case("WF.RestoreDefaults deletes custom rules and retains enabled switch",function()
  local c=setup(); assert(c.wf.AddRule({pattern="foo",replacement="bar",usePattern=false}))
  c.wf.SetEnabled(false); c.wf.RestoreDefaults(); assertEqual(#c.wf.GetRules(),3)
  assertEqual(c.wf.Replace("foo",true),"foo"); assert(not c.wf.IsEnabled())
end)
case("WF.IgnoreFontString bypasses filter and reapply",function()
  local c=setup(); local fs=UIParent:CreateFontString(); c.wf.IgnoreFontString(fs)
  fs:SetText("Gott"); assertEqual(fs:GetText(),"Gott"); c.wf.Reapply(); assertEqual(fs:GetText(),"Gott")
end)
case("WF.ScanFonts transforms preexisting or nested UI text",function()
  local c=setup(); local parent=c.create("Frame",nil,UIParent); local fs=parent:CreateFontString()
  c.fsMethods.SetText(fs,"Gott")
  c.wf.ScanFonts(); assertEqual(fs:GetText(),"ott")
end)
case("WF.Reapply reprocesses raw text without compounding",function()
  local c=setup(); local fs=UIParent:CreateFontString(); fs:SetText("Gott")
  assertEqual(fs:GetText(),"ott"); c.wf.Reapply(); assertEqual(fs:GetText(),"ott")
  c.wf.SetEnabled(false); assertEqual(fs:GetText(),"Gott")
end)
case("WF.SetEnabled toggles global setting and live text",function()
  local c=setup(); local fs=UIParent:CreateFontString(); fs:SetText("Gott")
  c.wf.SetEnabled(false); assertEqual(fs:GetText(),"Gott")
  c.wf.SetEnabled(true); assertEqual(fs:GetText(),"ott")
end)
case("FontString SetText/FormattedText/SetTextToFit hooks",function()
  local c=setup(); local fs=UIParent:CreateFontString()
  fs:SetText("Gott"); assertEqual(fs:GetText(),"ott")
  fs:SetFormattedText("Gott %d",4); assertEqual(fs:GetText(),"ott 4")
  fs:SetTextToFit("Göttin"); assertEqual(fs:GetText(),"öttin")
  assert(c.calls.SetText and c.calls.SetFormattedText and c.calls.SetTextToFit)
end)
case("FontString nil text clears raw value",function()
  local c=setup(); local fs=UIParent:CreateFontString()
  fs:SetText("Gott"); fs:SetText(nil); c.wf.Reapply(); assertEqual(fs:GetText(),nil)
end)
case("Chat filters replace text and preserve sender",function()
  local c=setup(); local f=c.filters.CHAT_MSG_SAY; assert(type(f)=="function")
  local rejected, msg, sender, extra=f(nil,nil,"Gott","Player",17)
  assert(not rejected); assertEqual(msg,"ott"); assertEqual(sender,"Player"); assertEqual(extra,17)
  local r=f(nil,nil,"und","Player"); assertEqual(r,false)
  c.wf.SetEnabled(false); assertEqual(f(nil,nil,"Gott","Player"),false)
end)
case("ChatFrameUtil preference and no chat API graceful fallback",function()
  local c=setup({useChatFrameUtil=true}); assert(type(c.filters.CHAT_MSG_GUILD)=="function")
  local d=setup({noChatAPI=true}); assertEqual(next(d.filters),nil)
end)
case("SavedVariables persist custom rules and disabled state",function()
  local db={enabled=false,rules={{pattern="Welt",replacement="Mars",usePattern=false,enabled=true}}}
  local c=setup({saved=db}); assert(not c.wf.IsEnabled()); assertEqual(c.wf.Replace("Welt",true),"Mars")
  assertEqual(#c.wf.GetRules(),1)
end)
case("SavedVariables initialize missing/malformed data",function()
  local c=setup({saved={rules="bad", enabled="yes"}}); assertEqual(#c.wf.GetRules(),3); assert(c.wf.IsEnabled())
  local d=setup({saved={rules={{pattern="ok",replacement="done"},{pattern=9,replacement="bad"}}}})
  assertEqual(#d.wf.GetRules(),1)
end)
case("ADDON_LOADED + PLAYER_ENTERING_WORLD initialize exactly once",function()
  local c=setup({skipLoad=true, delayedScan=true}); assertEqual(WortfilterDB,nil)
  c.emit("ADDON_LOADED","unrelated"); assertEqual(WortfilterDB,nil)
  c.emit("PLAYER_ENTERING_WORLD"); assert(type(WortfilterDB)=="table"); assertEqual(c.calls.timer,1)
  local orig=WortfilterDB; c.emit("ADDON_LOADED","Wortfilter"); assertEqual(WortfilterDB,orig)
end)
case("Missing FontString hook leaves chat filter usable",function()
  local c=setup({noHook=true}); assert(type(c.filters.CHAT_MSG_SAY)=="function")
  assertContains(c.messages[#c.messages],"nicht verfügbar")
  assertEqual(c.wf.ScanFonts(),0)
end)
case("Hook errors disable FontString handling gracefully",function()
  local c=setup({hookFails=true}); assertContains(c.messages[#c.messages],"nicht installiert")
  assertEqual(c.wf.ScanFonts(),0)
end)
case("Slash /wf on/off/test/scan/reset command paths",function()
  local c=setup(); c.slash("off"); assert(not c.wf.IsEnabled())
  c.slash("on"); assert(c.wf.IsEnabled())
  c.slash("test Gott"); assertContains(c.messages[#c.messages],"ott")
  c.slash("scan"); assertContains(c.messages[#c.messages],"überprüft")
  c.slash("reset"); assertEqual(#c.wf.GetRules(),3)
  c.slash("nonsense"); assertContains(c.messages[#c.messages],"/wf")
end)
case("WF.ToggleUI opens/closes panel and retains state",function()
  local c=setup(); c.wf.ToggleUI(); assert(WortfilterOptions:IsShown())
  c.wf.ToggleUI(); assert(not WortfilterOptions:IsShown())
  c.wf.ToggleUI(); assert(WortfilterOptions:IsShown())
end)
case("WF.RefreshUI reports rules, enables checkbox, renders rows",function()
  local c=setup(); c.wf.ToggleUI(); c.wf.RefreshUI()
  assertEqual(WortfilterOptions.TitleText:GetText(),"Jemand könnte sagen ")
  assert(#UISpecialFrames==1)
  assert(c.wf.IsEnabled())
end)
case("UI heading is first and shows Jemand könnte sagen",function()
  local c=setup()
  c.wf.ToggleUI()
  assertEqual(WortfilterOptions.TitleText:GetText(),"Jemand könnte sagen ")
  assert(WortfilterOptions.TitleText.parent == WortfilterOptions)
  -- The word filter must never rewrite its own title.
  assert(c.wf.AddRule({pattern="Jemand",replacement="Niemand",usePattern=false}))
  c.wf.Reapply()
  assertEqual(WortfilterOptions.TitleText:GetText(),"Jemand könnte sagen ")
end)
case("Editor Neu/Speichern updates pattern and live preview",function()
  local c=setup(); c.wf.ToggleUI(); c.click("Neu")
  local fields=c.inputs(); assert(#fields==3)
  fields[1]:SetText("Stormwind"); fields[2]:SetText("Sun City")
  c.click("Speichern"); assertEqual(c.wf.Replace("Stormwind"),"Sun City")
  fields[3]:SetText("Stormwind Gott")
  local seen=false
  for _,f in ipairs(c.frames) do if f.kind=="Frame" then
    for _,r in ipairs(f.regions) do if (r.value or ""):find("Sun City ott",1,true) then seen=true end end
  end end
  assert(seen,"Preview did not show replacement")
end)
case("Editor toggle, delete, order and restore defaults",function()
  local c=setup(); c.wf.ToggleUI(); c.click("Neu")
  local fields=c.inputs(); fields[1]:SetText("König"); fields[2]:SetText("Kaiser")
  c.click("Speichern"); assertEqual(#c.wf.GetRules(),4)
  c.click("Nach oben"); assertEqual(c.wf.GetRules()[3].pattern,"König")
  c.click("Nach unten"); assertEqual(c.wf.GetRules()[4].pattern,"König")
  c.click("Löschen"); assertEqual(#c.wf.GetRules(),3)
  c.click("Neu"); c.click("Löschen"); assertEqual(#c.wf.GetRules(),3)
  c.click("Standard"); assertEqual(#c.wf.GetRules(),3)
end)
case("Editor invalid pattern shows validation feedback",function()
  local c=setup(); c.wf.ToggleUI(); c.click("Neu")
  local fields=c.inputs(); fields[1]:SetText("["); fields[2]:SetText("test")
  for _,f in ipairs(c.frames) do if f.kind=="CheckButton" and f.Text and (f.Text:GetText() or ""):find("Lua-Pattern",1,true) then f:SetChecked(true) end end
  c.click("Speichern"); assertEqual(#c.wf.GetRules(),3)
end)


case("WF.ScanFrame handles tooltip regions outside UIParent",function()
  local c=setup()
  local popup=c.create("Frame",nil,nil)
  local fs=popup:CreateFontString()
  fs.value="Gottesurteil und Göttlicher Schlag" -- Text written by an opaque tooltip renderer
  assert(c.wf.ScanFrame(popup)>0)
  assertEqual(fs:GetText(),"ottesurteil und öttlicher Schlag")
  assertEqual(c.wf.ScanFrame(nil),0)
end)
case("WF.ScanFrame detects recycled tooltip text after rewrite",function()
  local c=setup()
  local popup=c.create("Frame",nil,nil)
  local fs=popup:CreateFontString()
  fs:SetText("Gottesurteil")
  assertEqual(fs:GetText(),"ottesurteil")
  fs.value="Göttlicher Zorn" -- recycled without SetText
  c.wf.ScanFrame(popup)
  assertEqual(fs:GetText(),"öttlicher Zorn")
  c.wf.SetEnabled(false)
  assertEqual(fs:GetText(),"Göttlicher Zorn")
end)
case("WF.RefreshAbilityText processes spellbook and castbar text",function()
  local c=setup()
  local book=c.create("Frame","PlayerSpellsFrame",UIParent)
  local bar=c.create("Frame","CastingBarFrame",UIParent)
  local spell=book:CreateFontString()
  local cast=bar:CreateFontString()
  spell.value="Göttlicher Schutz"
  cast.value="Gottesstrahl"
  dofile("Wortfilter/Wortfilter_Abilities.lua")
  assert(c.wf.RefreshAbilityText()>0)
  assertEqual(spell:GetText(),"öttlicher Schutz")
  assertEqual(cast:GetText(),"ottesstrahl")
  spell.value="Gott"
  assert(c.wf.RefreshAbilityText(book)>0)
  assertEqual(spell:GetText(),"ott")
end)
case("WF.RefreshAbilityText guards missing or unsupported frames",function()
  local c=setup({noHook=true})
  dofile("Wortfilter/Wortfilter_Abilities.lua")
  assertEqual(c.wf.RefreshAbilityText(),0)
  assertEqual(c.wf.RefreshAbilityText({}),0)
end)
case("WF.RegisterAbilityHooks installs spell and aura postprocessors once",function()
  local c=setup()
  local installed = {}
  _G.Enum={TooltipDataType={Spell=1,UnitAura=7,Item=2}}
  _G.TooltipDataProcessor={AddTooltipPostCall=function(id, callback)
    assert(not installed[id],"duplicate tooltip postprocessor")
    installed[id]=callback
  end}
  local tooltip=c.create("Frame","GameTooltip",nil)
  local line=tooltip:CreateFontString()
  dofile("Wortfilter/Wortfilter_Abilities.lua")
  assert(type(installed[1])=="function" and type(installed[7])=="function" and type(installed[2])=="function")
  assertEqual(installed[999],nil)
  line.value="Göttlicher Zorn"
  installed[1](tooltip,{id=1234})
  assertEqual(line:GetText(),"öttlicher Zorn")
  c.wf.RegisterAbilityHooks() -- must not add duplicate callbacks
  line.value="Gottesurteil"
  installed[7](tooltip,{id=4321})
  assertEqual(line:GetText(),"ottesurteil")
  _G.TooltipDataProcessor=nil; _G.Enum=nil
end)
case("WF.RegisterAbilityHooks installs OnShow fallback for late spellbook",function()
  local c=setup()
  _G.Enum=nil; _G.TooltipDataProcessor=nil
  dofile("Wortfilter/Wortfilter_Abilities.lua")
  local book=c.create("Frame","PlayerSpellsFrame",UIParent)
  book.HookScript=function(self,event,callback) self.scripts[event]=callback end
  local name=book:CreateFontString()
  name.value="Göttlicher Angriff"
  local watcher
  for _,f in ipairs(c.frames) do
    if f.registered and f.registered.SPELLS_CHANGED then watcher=f end
  end
  assert(watcher and watcher.scripts.OnEvent)
  watcher.scripts.OnEvent(watcher,"ADDON_LOADED","Blizzard_PlayerSpells")
  assert(type(book.scripts.OnShow)=="function")
  book.scripts.OnShow(book)
  assertEqual(name:GetText(),"öttlicher Angriff")
end)
case("Ability events rescan actionbar and active casts",function()
  local c=setup()
  _G.Enum=nil; _G.TooltipDataProcessor=nil
  local bar=c.create("Frame","ActionBarFrame",UIParent)
  local cast=c.create("Frame","CastingBarFrame",UIParent)
  local ability=bar:CreateFontString()
  local currentCast=cast:CreateFontString()
  dofile("Wortfilter/Wortfilter_Abilities.lua")
  local watcher
  for _,f in ipairs(c.frames) do
    if f.registered and f.registered.ACTIONBAR_SLOT_CHANGED then watcher=f end
  end
  assert(watcher and watcher.registered.UNIT_SPELLCAST_START)
  ability.value="Gottes Wut"
  watcher.scripts.OnEvent(watcher,"ACTIONBAR_SLOT_CHANGED")
  assertEqual(ability:GetText(),"ottes Wut")
  currentCast.value="Göttlicher Schlag"
  watcher.scripts.OnEvent(watcher,"UNIT_SPELLCAST_START")
  assertEqual(currentCast:GetText(),"öttlicher Schlag")
end)
case("Ability rules are editable and reversible with global filter",function()
  local c=setup()
  local spellbook=c.create("Frame","PlayerSpellsFrame",UIParent)
  local name=spellbook:CreateFontString()
  dofile("Wortfilter/Wortfilter_Abilities.lua")
  name:SetText("Feuerball")
  assert(c.wf.AddRule({pattern="Feuerball",replacement="Sternenball",usePattern=false,enabled=true}))
  assertEqual(name:GetText(),"Sternenball")
  c.wf.SetEnabled(false); assertEqual(name:GetText(),"Feuerball")
  c.wf.SetEnabled(true); assertEqual(name:GetText(),"Sternenball")
end)

-- JUnit document per runtime gives precise test name, stack trace and direct failure context.
local target=arg and arg[1] or "test-results.xml"
local function xml(s)
  return tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&apos;")
end
local file=assert(io.open(target,"w"))
file:write('<?xml version="1.0" encoding="UTF-8"?>\n<testsuite name="Wortfilter" tests="',#results,'" failures="',failures,'">\n')
for _,r in ipairs(results) do
  file:write('  <testcase name="',xml(r.name),'">')
  if not r.passed then file:write('<failure message="',xml(r.error),'">',xml(r.error),'</failure>') end
  file:write('</testcase>\n')
end
file:write('</testsuite>\n'); file:close()
print(string.format("Completed %d named tests; %d failure(s). Report: %s",#results,failures,target))
if failures>0 then os.exit(1) end
