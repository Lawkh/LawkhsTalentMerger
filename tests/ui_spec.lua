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
function GetSpecializationInfoForSpecID() return 71, "Arms" end
C_SpecializationInfo = {
    GetSpecialization = function() return 1 end,
    GetSpecializationInfo = function() return 71 end,
    GetNumSpecializationsForClassID = function() return 1 end,
}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }

local methods = {}
for _, name in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetPoint", "SetFrameStrata", "SetClampedToScreen",
    "SetMovable", "EnableMouse", "RegisterForDrag", "SetBackdropColor", "SetJustifyH", "SetScrollChild",
    "SetAutoFocus", "SetMaxLetters", "SetFocus", "HighlightText", "SetVerticalScroll", "StartMoving", "StopMovingOrSizing" }) do
    methods[name] = function() end
end
function methods:SetScript(name, fn) self.scripts[name] = fn end
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
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function CreateFrame(_, name)
    local frame = setmetatable({ scripts = {}, hooks = {}, events = {}, shown = true }, { __index = methods })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function methods:CreateFontString() return CreateFrame("FontString") end
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
test("late loaded talents attach and native names use group colors", function()
    PlayerSpellsFrame = { TalentsFrame = talents }
    events.scripts.OnEvent(events, "ADDON_LOADED", "Blizzard_PlayerSpells"); flush()
    assert(TM.attached == talents)
    assert(talents.LoadSystem.translator(1) == "|cff66ccffRaid|r")
    assert(talents.LoadSystem.translator(2) == "|cff66ccffMythic|r")
    assert(talents.configIDToName[1] == "Raid")
end)
test("inspect mode does not overwrite native translator", function()
    local translator = talents.LoadSystem.translator
    talents.inspecting = true; TM:ColorNative(talents)
    assert(talents.LoadSystem.translator == translator)
    talents.inspecting = false
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
test("combat closes a pending confirmation, enables again after combat", function()
    combat = true; events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED"); flush()
    assert(not TM.dialog:IsShown() and not TM.cleanButton.enabled)
    combat = false; events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED"); flush()
    assert(TM.cleanButton.enabled and TM.nukeButton.enabled)
end)
test("Classic skips UI initialization", function()
    local before = #frames
    WOW_PROJECT_ID = 2
    assert(loadfile("LawkhsTalentMerger/UI.lua"))("LawkhsTalentMerger", TM)
    assert(#frames == before)
    WOW_PROJECT_ID = 1
end)
print(passed .. " UI tests passed")
