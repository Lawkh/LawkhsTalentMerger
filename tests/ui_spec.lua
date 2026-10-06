-- Runs the actual UI module against a minimal retail frame/event harness.
-- This checks lifecycle and callbacks, not rendering or secure/taint behavior.
local TM, combat, frames, timers = {}, false, {}, {}
function GetLocale() return "esES" end
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
UIParent, UISpecialFrames, SlashCmdList = {}, {}, {}
NORMAL_FONT_COLOR = {}
TALENT_FRAME_DROP_DOWN_STARTER_BUILD_TOOLTIP = "Starter"
local builds = { [1] = { name = "Raid", key = "AAA" }, [2] = { name = "Mythic", key = "AAA" } }
C_ClassTalents = {
    GetConfigIDsBySpecID = function() return { 1, 2 } end,
    GetActiveConfigID = function() return 99 end,
    DeleteConfig = function() error("Unexpected deletion during UI preview") end,
    RenameConfig = function() error("Unexpected rename during UI preview") end,
}
C_Traits = {
    GetConfigInfo = function(id) return builds[id] end,
    GenerateImportString = function(id) return builds[id].key end,
    ConfigHasStagedChanges = function() return false end,
}
function InCombatLockdown() return combat end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function time() return 123 end
function GetSpecializationInfoForSpecID() return 71, "Arms" end
C_SpecializationInfo = {
    GetSpecialization = function() return 1 end,
    GetSpecializationInfo = function() return 71 end,
    GetNumSpecializationsForClassID = function() return 1 end,
}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local menuCallbacks = {}
Menu = { ModifyMenu = function(tag, callback) menuCallbacks[tag] = callback end }
local function description(text, callback, data)
    local item = { text = text, callback = callback, data = data, initializers = {} }
    function item:GetData() return self.data end
    function item:SetEnabled(value) self.enabled = value end
    function item:AddInitializer(fn) self.initializers[#self.initializers + 1] = fn end
    return item
end
MenuUtil = { CreateButton = function(text, callback) return description(text, callback) end }
local function rootMenu()
    local root = { items = { description("Raid", function() end, 1), description("Mythic", function() end, 2), description("Share") } }
    function root:EnumerateElementDescriptions() return ipairs(self.items) end
    function root:Insert(item, index) table.insert(self.items, index, item) end
    return root
end

local methods = {}
for _, name in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetPoint", "SetFrameStrata", "SetClampedToScreen",
    "SetMovable", "EnableMouse", "RegisterForDrag", "SetBackdropColor", "SetJustifyH", "SetScrollChild",
    "SetAutoFocus", "SetMaxLetters", "SetFocus", "HighlightText", "SetVerticalScroll", "StartMoving", "StopMovingOrSizing",
    "RegisterForClicks", "SetToplevel", "SetFrameLevel", "SetTextColor", "SetAllPoints", "SetColorTexture", "ClearFocus",
    "ClearAllPoints", "SetTexture", "SetBackdropBorderColor" }) do
    methods[name] = function() end
end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:GetFrameLevel() return 1 end
function methods:GetTextWidth() return 80 end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:GetScript(name) return self.scripts[name] end
function methods:HookScript(name, fn) self.hooks[name] = fn end
function methods:RegisterEvent(name) self.events[name] = true end
function methods:SetBackdrop(value) self.backdrop = value end
function methods:GetBackdrop() return self.backdrop end
function methods:SetText(value)
    self.text = value
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text or "" end
function methods:GetStringHeight() return 100 end
function methods:SetEnabled(value) self.enabled = value end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetTexture(value) self.texture = value end
function methods:SetShown(value) self.shown = value end
function methods:Show() self.shown = true end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, name = name, parent = parent, scripts = {}, hooks = {}, events = {}, shown = true, enabled = true }, { __index = methods })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function methods:CreateFontString() return CreateFrame("FontString") end
function methods:CreateTexture() return CreateFrame("Texture", nil, self) end
function hooksecurefunc(object, method, hook) object.secureHook = hook end
local talents = CreateFrame("Frame")
talents.configIDs, talents.configIDToName = { 1, 2 }, { [1] = "Raid", [2] = "Mythic" }
talents.LoadSystem = { SetSelectionOptions = function(self, ids, translator) self.translator = translator end }
function talents:GetSpecID() return 71 end
function talents:IsStarterBuildConfig() return false end
function talents:IsInspecting() return self.inspecting end
function talents:RefreshLoadoutOptions() end

assert(loadfile("LawkhsTalentMerger/Localization.lua"))("LawkhsTalentMerger", TM)
assert(loadfile("LawkhsTalentMerger/Core.lua"))("LawkhsTalentMerger", TM)
TM.Message = function() end
assert(loadfile("LawkhsTalentMerger/UI.lua"))("LawkhsTalentMerger", TM)
local events = frames[#frames]
local function flush()
    local callbacks = timers; timers = {}
    for _, fn in ipairs(callbacks) do fn() end
end
local passed = 0
local function test(name, fn) fn(); passed = passed + 1; print("PASS " .. name) end
local function selectNukeColumns(context)
    for _, card in ipairs(context.dialog.nukeCards) do
        if #card.spec.rows > 0 then
            card.check:SetChecked(true)
            card.check.scripts.OnClick(card.check)
        end
    end
end

test("first slash use in combat is safe", function()
    combat = true
    SlashCmdList.LAWKHSTALENTMERGER("merge")
    SlashCmdList.LAWKHSTALENTMERGER("clean")
    SlashCmdList.LAWKHSTALENTMERGER("nuke")
    assert(not TM.dialog and not TM.mergeButton.enabled and not TM.nukeButton.enabled)
    combat = false
end)
test("login refresh works before Blizzard talent addon loads", function()
    events.scripts.OnEvent(events, "PLAYER_LOGIN"); flush()
    assert(#TM.groups == 1 and not TM.attached)
end)
test("late loaded talents attach without rewriting native selector", function()
    PlayerSpellsFrame = { TalentsFrame = talents }
    events.scripts.OnEvent(events, "ADDON_LOADED", "Blizzard_PlayerSpells"); flush()
    assert(TM.attached == talents)
    assert(not talents.LoadSystem.translator)
    assert(talents.configIDToName[1] == "Raid")
end)
test("native menu shows Merge first and Nuke above Clean, colors duplicates", function()
    local root = rootMenu()
    local originalCallback = root.items[1].callback
    menuCallbacks.MENU_CLASS_TALENT_PROFILE(nil, root)
    assert(root.items[1].text == TM:T("MERGE") and root.items[2].text == TM:T("NUKE") and root.items[3].text == TM:T("CLEAN"))
    assert(root.items[4].callback == originalCallback and root.items[4].text == "Raid")
    for i = 4, 5 do
        local font = { SetTextColor = function(self, r, g, b) self.r, self.g, self.b = r, g, b end }
        for _, initializer in ipairs(root.items[i].initializers) do initializer({ fontString = font }) end
        assert(font.r == 0.4 and font.g == 0.8 and font.b == 1)
    end
end)
test("inspect menu is unchanged", function()
    local root = rootMenu()
    talents.inspecting = true; TM:ModifyTalentMenu(nil, root)
    assert(#root.items == 3 and #root.items[1].initializers == 0)
    talents.inspecting = false
end)
test("native menu actions disable in combat", function()
    local root = rootMenu()
    combat = true; TM:ModifyTalentMenu(nil, root)
    for i = 1, 3 do assert(not root.items[i].enabled) end
    combat = false
end)
test("Merge opens a name preview without mutating builds", function()
    TM:ShowMerge()
    assert(TM.dialog:IsShown() and TM.dialog.input:GetText() == "Raid/Mythic")
    assert(TM.dialog.accept.enabled)
end)
test("Nuke confirmation requires exact token and resets between openings", function()
    TM:ShowNuke(); assert(not TM.dialog.accept.enabled)
    TM.dialog.input:SetText("NUKE"); assert(not TM.dialog.accept.enabled)
    selectNukeColumns(TM)
    TM.dialog.input:SetText("nuke"); assert(not TM.dialog.accept.enabled)
    TM.dialog.input:SetText("NUKE"); assert(TM.dialog.accept.enabled)
    TM:ShowNuke(); assert(not TM.dialog.accept.enabled)
end)
test("Clean confirmation works after Nuke dialog reuse", function()
    TM:ShowClean()
    assert(TM.dialog.accept.enabled and not TM.dialog.input:IsShown())
    assert(TM.dialog.report:GetText():find("CONSERVAR") and TM.dialog.report:GetText():find("BORRAR"))
end)
test("combat immediately blocks pending confirmation and preserves typed name", function()
    TM:ShowMerge(); TM.dialog.input:SetText("My custom name")
    combat = true; events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
    assert(TM.dialog:IsShown() and not TM.dialog.accept.enabled and not TM.cleanButton.enabled)
    assert(TM.dialog.input:GetText() == "My custom name" and TM.dialog.error:GetText():find("combate"))
    for _, widget in ipairs(TM.widgets) do assert(not widget.merge.enabled) end
    flush()
    combat = false; events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED"); flush()
    assert(TM.cleanButton.enabled and TM.nukeButton.enabled and TM.dialog.accept.enabled)
    assert(TM.dialog.input:GetText() == "My custom name" and TM.dialog.error:GetText() == "")
end)
test("Confirm rechecks combat even before the combat event arrives", function()
    TM:ShowMerge()
    combat = true
    TM.dialog.accept.scripts.OnClick(TM.dialog.accept, "LeftButton")
    assert(TM.dialog:IsShown() and TM.dialog.error:GetText():find("combate"))
    assert(builds[1].name == "Raid" and builds[2])
    combat = false
end)
test("menu generated before combat cannot open a mutation dialog during combat", function()
    local root = rootMenu(); TM:ModifyTalentMenu(nil, root)
    TM.dialog:Hide()
    combat = true
    for i = 1, 3 do root.items[i].callback() end
    assert(not TM.dialog:IsShown() and builds[1].name == "Raid" and builds[2])
    combat = false; TM:Refresh()
end)
test("Confirm performs real Merge callback then returns to list in same window", function()
    local rename, delete, getIDs = C_ClassTalents.RenameConfig, C_ClassTalents.DeleteConfig, C_ClassTalents.GetConfigIDsBySpecID
    C_ClassTalents.RenameConfig = function(id, name) builds[id].name = name; return true end
    C_ClassTalents.DeleteConfig = function(id) builds[id] = nil; return true end
    C_ClassTalents.GetConfigIDsBySpecID = function() return builds[2] and { 1, 2 } or { 1 } end
    TM:Refresh(); TM:ShowMerge()
    TM.dialog.input:SetText("Combined")
    TM.dialog.accept.scripts.OnClick(TM.dialog.accept, "LeftButton")
    assert(TM.operation and not TM.dialog.accept.enabled)
    flush()
    assert(not TM.dialog:IsShown() and builds[1].name == "Combined" and not builds[2])
    assert(TM.window:IsShown() and TM.listPanel:IsShown() and TM.view == "list")
    assert(TM.listHint:GetText():find("Borradas"))
    assert(LawkhsTalentMergerDB.backups[1].builds[1].export == "AAA")
    builds[1].name = "Raid"; builds[2] = { name = "Mythic", key = "AAA" }
    C_ClassTalents.RenameConfig, C_ClassTalents.DeleteConfig, C_ClassTalents.GetConfigIDsBySpecID = rename, delete, getIDs
    TM:Refresh()
end)
test("dead player sees reason in dialog after Confirm", function()
    TM:ShowMerge()
    UnitIsDeadOrGhost = function() return true end
    TM.dialog.accept.scripts.OnClick(TM.dialog.accept, "LeftButton")
    assert(TM.dialog:IsShown() and TM.dialog.error:GetText():find("Resucita"))
    UnitIsDeadOrGhost = nil
end)
test("API exceptions are visible and keep the confirmation open", function()
    TM:ShowMerge()
    TM.dialog.accept.scripts.OnClick(TM.dialog.accept, "LeftButton")
    assert(TM.dialog:IsShown() and TM.dialog.error:GetText():find("Unexpected rename"))
end)
test("all confirmations reuse a child view of the single window", function()
    local window, dialog = TM.window, TM.dialog
    TM:ShowClean(); assert(TM.window == window and TM.dialog == dialog)
    assert(dialog.parent == window and dialog:IsShown() and not TM.listPanel:IsShown())
    TM:ShowNuke(); assert(TM.window == window and TM.dialog == dialog and TM.view == "confirm")
    local rootWindows = 0
    for _, frame in ipairs(frames) do
        if frame.kind == "Frame" and frame.parent == UIParent then rootWindows = rootWindows + 1 end
    end
    assert(rootWindows == 1 and #UISpecialFrames == 1)
end)
test("Back returns to list and clears the pending destructive action", function()
    TM:ShowNuke(); TM.dialog.input:SetText("NUKE")
    TM.dialog.back.scripts.OnClick(TM.dialog.back, "LeftButton")
    assert(TM.view == "list" and TM.listPanel:IsShown() and not TM.dialog:IsShown())
    assert(TM.dialog.callback == nil and builds[1] and builds[2])
end)
test("background refresh preserves confirmation content and edited name", function()
    TM:ShowMerge(); TM.dialog.input:SetText("Keep my edit")
    local report, title, callback = TM.dialog.report:GetText(), TM.status:GetText(), TM.dialog.callback
    events.scripts.OnEvent(events, "TRAIT_CONFIG_UPDATED"); flush()
    assert(TM.view == "confirm" and not TM.listPanel:IsShown())
    assert(TM.dialog.input:GetText() == "Keep my edit" and TM.dialog.report:GetText() == report)
    assert(TM.status:GetText() == title and TM.dialog.callback == callback)
end)
test("closing and reopening the window resets to list safely", function()
    TM.window:Hide()
    assert(TM.dialog.callback == nil and not TM.dialog:IsShown() and TM.view == "list")
    TM:ShowList()
    assert(TM.window:IsShown() and TM.listPanel:IsShown() and not TM.dialog:IsShown())
end)
test("Nuke shows progress and blocks duplicate clicks until server events complete", function()
    local delete, getIDs = C_ClassTalents.DeleteConfig, C_ClassTalents.GetConfigIDsBySpecID
    local requested = {}
    C_ClassTalents.DeleteConfig = function(id) requested[#requested + 1] = id; return true end
    C_ClassTalents.GetConfigIDsBySpecID = function()
        local ids = {}; for id = 1, 2 do if builds[id] then ids[#ids + 1] = id end end; return ids
    end
    timers = {}
    TM:ShowNuke(); selectNukeColumns(TM); TM.dialog.input:SetText("NUKE")
    TM.dialog.accept.scripts.OnClick(TM.dialog.accept, "LeftButton")
    assert(#requested == 1 and TM.dialog:IsShown() and not TM.dialog.accept.enabled)
    assert(TM.dialog.error:GetText():find("0/2") and TM.dialog.back:GetText() == "Detener")
    TM.dialog.accept.scripts.OnClick(TM.dialog.accept, "LeftButton")
    TM:ShowNuke(); assert(#requested == 1 and TM.dialog.operation == TM.operation)
    builds[1] = nil; events.scripts.OnEvent(events, "TRAIT_CONFIG_DELETED", 1); flush()
    assert(#requested == 2 and TM.operation.deleted == 1)
    builds[2] = nil; events.scripts.OnEvent(events, "TRAIT_CONFIG_DELETED", 2); flush()
    assert(not TM.operation and TM.view == "list" and TM.listHint:GetText():find("Borradas: 2"))
    builds[1], builds[2] = { name = "Raid", key = "AAA" }, { name = "Mythic", key = "AAA" }
    C_ClassTalents.DeleteConfig, C_ClassTalents.GetConfigIDsBySpecID = delete, getIDs
    TM:Refresh()
end)
test("Classic skips UI initialization", function()
    local before = #frames
    WOW_PROJECT_ID = 2
    assert(loadfile("LawkhsTalentMerger/UI.lua"))("LawkhsTalentMerger", TM)
    assert(#frames == before)
    WOW_PROJECT_ID = 1
end)
test("Nuke columns have native spec names and icons; empty specs cannot be selected", function()
    local info, count, getIDs = C_SpecializationInfo.GetSpecializationInfo, C_SpecializationInfo.GetNumSpecializationsForClassID, C_ClassTalents.GetConfigIDsBySpecID
    C_SpecializationInfo.GetSpecializationInfo = function(index)
        return 70 + index, ({ "Arms", "Fury", "Protection", "Empty" })[index], "", 1000 + index
    end
    C_SpecializationInfo.GetNumSpecializationsForClassID = function() return 4 end
    builds[3], builds[4] = { name = "Fury build", key = "BBB" }, { name = "Tank build", key = "CCC" }
    C_ClassTalents.GetConfigIDsBySpecID = function(spec)
        if not spec or spec == 71 then return { 1, 2 } end
        if spec == 72 then return { 3 } end
        if spec == 73 then return { 4 } end
        return {}
    end
    TM:ShowNuke()
    local cards = TM.dialog.nukeCards
    assert(#cards == 4 and cards[2].name:GetText() == "Fury" and cards[2].icon.texture == 1002)
    assert(cards[2].builds:GetText() == "Fury build" and not cards[4].check.enabled)
    TM.dialog.input:SetText("NUKE"); assert(not TM.dialog.accept.enabled)
    cards[2].check:SetChecked(true); cards[2].check.scripts.OnClick(cards[2].check)
    assert(TM.dialog.input:GetText() == "" and #TM.dialog.nukeState.rows == 1 and TM.dialog.nukeState.rows[1].id == 3)
    TM.dialog.input:SetText("NUKE"); assert(TM.dialog.accept.enabled)
    combat = true; TM:UpdateCombatState(); assert(not cards[2].check.enabled and not TM.dialog.accept.enabled)
    combat = false; TM:UpdateCombatState()
    cards[2].check:SetChecked(false); cards[2].check.scripts.OnClick(cards[2].check)
    assert(#TM.dialog.nukeState.rows == 0 and not TM.dialog.accept.enabled)
    TM:ShowNuke(); assert(#TM.dialog.nukeState.rows == 0 and not cards[2].check:GetChecked())
    TM:ShowList(); assert(TM.view == "list" and not TM.dialog:IsShown())
    C_SpecializationInfo.GetSpecializationInfo, C_SpecializationInfo.GetNumSpecializationsForClassID, C_ClassTalents.GetConfigIDsBySpecID = info, count, getIDs
    builds[3], builds[4] = nil, nil
end)
test("single selected Nuke column sends deletion requests only for that spec", function()
    local info, count, getIDs, delete = C_SpecializationInfo.GetSpecializationInfo, C_SpecializationInfo.GetNumSpecializationsForClassID, C_ClassTalents.GetConfigIDsBySpecID, C_ClassTalents.DeleteConfig
    C_SpecializationInfo.GetSpecializationInfo = function(index) return 70 + index, index == 1 and "Arms" or "Fury", "", 1000 + index end
    C_SpecializationInfo.GetNumSpecializationsForClassID = function() return 2 end
    builds[3] = { name = "Fury only", key = "BBB" }
    C_ClassTalents.GetConfigIDsBySpecID = function(spec)
        if spec == 72 then return builds[3] and { 3 } or {} end
        return { 1, 2 }
    end
    local requests = {}
    C_ClassTalents.DeleteConfig = function(id) requests[#requests + 1] = id; return true end
    timers = {}
    TM:ShowNuke()
    local card = TM.dialog.nukeCards[2]
    card.check:SetChecked(true); card.check.scripts.OnClick(card.check)
    TM.dialog.input:SetText("NUKE"); TM.dialog.accept.scripts.OnClick(TM.dialog.accept)
    assert(#requests == 1 and requests[1] == 3 and not card.check.enabled)
    builds[3] = nil; events.scripts.OnEvent(events, "TRAIT_CONFIG_DELETED", 3); flush()
    assert(not TM.operation and builds[1] and builds[2] and TM.view == "list")
    C_SpecializationInfo.GetSpecializationInfo, C_SpecializationInfo.GetNumSpecializationsForClassID, C_ClassTalents.GetConfigIDsBySpecID, C_ClassTalents.DeleteConfig = info, count, getIDs, delete
    TM:Refresh()
end)
test("every WoW locale renders all views and preserves build names and NUKE", function()
    for _, locale in ipairs({ "enUS", "enGB", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }) do
        GetLocale = function() return locale end
        local context = {}
        assert(loadfile("LawkhsTalentMerger/Localization.lua"))("LawkhsTalentMerger", context)
        assert(loadfile("LawkhsTalentMerger/Core.lua"))("LawkhsTalentMerger", context)
        context.Message = function() end
        assert(loadfile("LawkhsTalentMerger/UI.lua"))("LawkhsTalentMerger", context)
        context:ShowList()
        assert(context.mergeButton:GetText() == context:T("MERGE"), locale)
        local menu = rootMenu(); context:ModifyTalentMenu(nil, menu)
        assert(menu.items[1].text == context:T("MERGE") and menu.items[2].text == context:T("NUKE"), locale)
        context:ShowMerge()
        assert(context.status:GetText() == context:T("MERGE_TITLE") and context.dialog.input:GetText() == "Raid/Mythic", locale)
        context:ShowClean()
        assert(context.dialog.report:GetText():find(context:T("REMOVE", ""), 1, true), locale)
        context:ShowNuke()
        selectNukeColumns(context)
        context.dialog.input:SetText("NUKE")
        assert(context.dialog.accept.enabled and context.dialog.required == "NUKE", locale)
        context.window:Hide()
    end
    GetLocale = function() return "esES" end
end)
assert(loadfile("LawkhsTalentMerger/Restore.lua"))("LawkhsTalentMerger", TM)
assert(loadfile("LawkhsTalentMerger/Dashboard.lua"))("LawkhsTalentMerger", TM)

test("main view owns specialization columns, separate scrolls and Undo action", function()
    local info,count,getIDs=C_SpecializationInfo.GetSpecializationInfo,C_SpecializationInfo.GetNumSpecializationsForClassID,C_ClassTalents.GetConfigIDsBySpecID
    C_SpecializationInfo.GetSpecializationInfo=function(i) return 70+i, i==1 and "Arms" or "Fury", "",1000+i end
    C_SpecializationInfo.GetNumSpecializationsForClassID=function() return 2 end
    C_ClassTalents.GetConfigIDsBySpecID=function(spec) return spec==72 and {} or {1,2} end
    TM:ShowList()
    assert(TM.dashboard and TM.undoButton and #TM.specCards==2 and not TM.listScroll:IsShown())
    assert(TM.specCards[1].icon.texture==1001 and TM.specCards[2].name:GetText()=="Fury")
    assert(TM.specCards[1].scroll~=TM.specCards[2].scroll and not TM.specCards[2].check.enabled)
    local oldDialog=TM.dialog
    TM:ShowNuke(); assert(TM.view=="list" and TM.dialog==oldDialog)
    local card=TM.specCards[1]
    card.check:SetChecked(true);card.check.scripts.OnClick(card.check)
    TM:ShowNuke();assert(TM.view=="confirm" and not TM.dialog.nukeState)
    assert(TM.dialog.report:GetText():find("Arms",1,true) and TM.dialog.required=="NUKE")
    TM.dialog.input:SetText("NUKE");assert(TM.dialog.accept.enabled)
    combat=true;TM:UpdateCombatState();assert(not card.check.enabled and not TM.undoButton.enabled)
    combat=false;TM:ShowList()
    C_SpecializationInfo.GetSpecializationInfo,C_SpecializationInfo.GetNumSpecializationsForClassID,C_ClassTalents.GetConfigIDsBySpecID=info,count,getIDs
end)

test("history and restore preview reuse the same root and reset controls", function()
    LawkhsTalentMergerDB={backups={{time=123,action="Clean",builds={{name="Deleted",spec=71,export="DELETED"}}}}}
    TM:ShowHistory()
    assert(TM.view=="history" and not TM.dialog.accept:IsShown())
    local root=TM.window
    local row=TM.dialog.historyRows[2]
    assert(row.button:IsShown() and row.callback)
    row.button.scripts.OnClick(row.button)
    assert(TM.window==root and TM.view=="confirm" and TM.dialog.accept:IsShown())
    assert(TM.dialog.report:GetText():find("Deleted",1,true) and not TM.dialog.historyRows[1]:IsShown())
    TM:ShowList();TM:ShowHistory()
    combat=true;TM:UpdateCombatState();assert(not row.button.enabled);combat=false
    TM:ShowList()
end)

test("new dashboard and history load in TOC order in every locale", function()
    for _,locale in ipairs({"enUS","enGB","deDE","esES","esMX","frFR","itIT","ptBR","ruRU","koKR","zhCN","zhTW"}) do
        GetLocale=function() return locale end
        local context={}
        for _,file in ipairs({"Localization","Core","UI","Restore","Dashboard"}) do
            assert(loadfile("LawkhsTalentMerger/"..file..".lua"))("LawkhsTalentMerger",context)
        end
        context.Message=function() end
        context:ShowList();assert(context.undoButton:GetText()==context:T("UNDO"))
        context.specCards[1].check:SetChecked(true);context.specCards[1].check.scripts.OnClick(context.specCards[1].check)
        context:ShowNuke();context.dialog.input:SetText("NUKE");assert(context.dialog.accept.enabled)
        context:ShowHistory();assert(context.view=="history" and not context.dialog.accept:IsShown())
        context:ShowMerge();assert(context.dialog.accept:IsShown() and context.dialog.mergeRows[1].input:GetText()=="Raid/Mythic")
        context.window:Hide()
    end
    GetLocale=function() return "esES" end
end)
test("dashboard cards contain no action buttons, centered headers and unique filter", function()
    TM:ShowList()
    local card=TM.specCards[1]
    assert(card.header and card.loadouts and card.duplicates)
    assert(card.loadouts.label:GetText()==TM:T("LOADOUT_CELL",2))
    for _,row in ipairs(card.lines) do assert(not row.merge) end
    TM.hideUnique:SetChecked(true);TM.hideUnique.scripts.OnClick(TM.hideUnique)
    assert(TM.hideUnique.label:GetText()==TM:T("HIDE_UNIQUE"))
    assert(card.lines[1].label:GetText():find(TM:T("GROUP_DUPLICATES",1,2),1,true))
    TM.hideUnique:SetChecked(false);TM.hideUnique.scripts.OnClick(TM.hideUnique)
end)

test("Merge and Clean previews honor selected specs and edit all names", function()
    local info,count,getIDs=C_SpecializationInfo.GetSpecializationInfo,C_SpecializationInfo.GetNumSpecializationsForClassID,C_ClassTalents.GetConfigIDsBySpecID
    C_SpecializationInfo.GetSpecializationInfo=function(i) return 70+i,i==1 and "Arms" or "Fury","",1000+i end
    C_SpecializationInfo.GetNumSpecializationsForClassID=function() return 2 end
    builds[3],builds[4]={name="Fury A",key="BBB"},{name="Fury B",key="BBB"}
    C_ClassTalents.GetConfigIDsBySpecID=function(spec) return spec==72 and {3,4} or {1,2} end
    TM:ShowList();TM.selectedSpecs={[72]=true};TM:UpdateDashboardSelection()
    TM:ShowClean()
    assert(TM.dialog.report:GetText():find("Fury A",1,true) and not TM.dialog.report:GetText():find("Raid",1,true))
    local clean=TM.Clean;local called
    TM.Clean=function(_,groups) called=groups;return true end
    TM.dialog.accept.scripts.OnClick(TM.dialog.accept)
    assert(#called==1 and called[1].rows[1].spec==72);TM.Clean=clean
    TM.selectedSpecs={[71]=true,[72]=true};TM:ShowMerge()
    assert(TM.dialog.mergeRows[1].input:GetText()=="Raid/Mythic" and TM.dialog.mergeRows[2].input:GetText()=="Fury A/Fury B")
    TM.dialog.mergeRows[1].input:SetText("My raid");TM.dialog.mergeRows[2].input:SetText("My Fury")
    local merge=TM.MergeMany
    TM.MergeMany=function(_,groups,names)
        assert(#groups==2 and names[1]=="My raid" and names[2]=="My Fury");return true
    end
    TM.dialog.accept.scripts.OnClick(TM.dialog.accept);assert(TM.view=="list");TM.MergeMany=merge
    TM.selectedSpecs={};TM:UpdateDashboardSelection()
    assert(not TM.mergeButton.enabled and not TM.cleanButton.enabled and not TM.nukeButton.enabled)
    C_SpecializationInfo.GetSpecializationInfo,C_SpecializationInfo.GetNumSpecializationsForClassID,C_ClassTalents.GetConfigIDsBySpecID=info,count,getIDs
    builds[3],builds[4]=nil,nil
end)

test("Nuke confirmation uses chosen scope, numeric token and width fitting content", function()
    TM:ShowList();TM.selectedSpecs={[71]=true};TM:ShowNuke()
    assert(TM.status:GetText()==TM:T("NUKE_CONFIRM_TITLE"))
    assert(TM.dialog.report:GetText():find("123123",1,true))
    assert(TM.dialog.report:GetWidth()<=TM.window:GetWidth()-60)
    assert(TM.window:GetHeight()==620)
    TM.dialog.input:SetText("123123");assert(TM.dialog.accept.enabled)
    local nuke=TM.Nuke;local called=false
    TM.Nuke=function(_,rows,token,scope) assert(token=="123123" and scope[71] and #rows==2);called=true;return true end
    TM.dialog.accept.scripts.OnClick(TM.dialog.accept);assert(called and TM.view=="list");TM.Nuke=nuke
    TM:ShowMerge();TM:ShowNuke()
    for _,row in ipairs(TM.dialog.mergeRows) do assert(not row:IsShown()) end
end)
print(passed .. " UI tests passed")
