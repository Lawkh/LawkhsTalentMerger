-- Runs the actual UI module against a minimal retail frame/event harness.
-- This checks lifecycle and callbacks, not rendering or secure/taint behavior.
local TM, combat, frames, timers = {}, false, {}, {}
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
    "RegisterForClicks", "SetToplevel", "SetFrameLevel", "SetTextColor", "SetAllPoints", "SetColorTexture", "ClearFocus" }) do
    methods[name] = function() end
end
function methods:GetFrameLevel() return 1 end
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
function methods:SetShown(value) self.shown = value end
function methods:Show() self.shown = true end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, name = name, parent = parent, scripts = {}, hooks = {}, events = {}, shown = true }, { __index = methods })
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
    assert(root.items[1].text == "Merge" and root.items[2].text == "Nuke" and root.items[3].text == "Clean")
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
    TM:ShowNuke(); TM.dialog.input:SetText("NUKE")
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
print(passed .. " UI tests passed")
