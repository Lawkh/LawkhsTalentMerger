local _, TM = ...
local function T(key, ...) return TM:T(key, ...) end
if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end

local function Button(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 25)
    button:SetText(label)
    button:SetWidth(math.max(width, button:GetTextWidth() + 24))
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", onClick)
    return button
end

function TM:CreateWindow()
    if self.window then return end
    local frame = CreateFrame("Frame", "LawkhsTalentMergerWindow", UIParent, "BackdropTemplate")
    self.window = frame
    frame:SetSize(600, 510)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.98)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.04, 0.04, 0.06, 0.97)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText("Lawkh's Talent Merger")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", 20, -52)
    status:SetWidth(550)
    status:SetJustifyH("LEFT")
    self.status = status
    local list = CreateFrame("Frame", nil, frame)
    list:SetAllPoints()
    self.listPanel, self.view = list, "list"
    local scroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -85)
    scroll:SetPoint("BOTTOMRIGHT", -42, 132)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(530, 1)
    scroll:SetScrollChild(content)
    self.listScroll = scroll
    self.content, self.widgets = content, {}
    -- Position 1 is Merge; Nuke sits immediately above Clean.
    self.mergeButton = Button(list, T("MERGE"), 110, function() self:ShowMerge() end)
    self.mergeButton:SetPoint("BOTTOMLEFT", 20, 22)
    self.nukeButton = Button(list, T("NUKE"), 110, function() self:ShowNuke() end)
    self.nukeButton:SetPoint("BOTTOMRIGHT", -20, 55)
    self.cleanButton = Button(list, T("CLEAN"), 110, function() self:ShowClean() end)
    self.cleanButton:SetPoint("BOTTOMRIGHT", -20, 22)
    local refresh = Button(list, T("REFRESH"), 110, function() self:Refresh() end)
    self.refreshButton = refresh
    refresh:SetPoint("LEFT", self.mergeButton, "RIGHT", 12, 0)
    local hint = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 20, 94)
    hint:SetWidth(550)
    hint:SetHeight(32)
    hint:SetJustifyH("LEFT")
    hint:SetText(T("SCOPE"))
    self.listHint = hint
    frame:SetScript("OnHide", function()
        if self.operation then self.operation.cancelled = true end
        if self.dialog then
            self.dialog:Hide()
            self.dialog.input:ClearFocus()
            self.dialog.callback = nil
        end
        self.view = "list"
        self.listPanel:Show()
    end)
    table.insert(UISpecialFrames, "LawkhsTalentMergerWindow")
    frame:Hide()
end

function TM:ShowList(message)
    self:CreateWindow()
    if self.dialog then
        self.dialog:Hide()
        self.dialog.input:ClearFocus()
        self.dialog.callback = nil
    end
    self.view = "list"
    self.window:SetSize(600, 510)
    self.status:SetWidth(550)
    self.listPanel:Show()
    self.window:Show()
    self:Refresh()
    self.listHint:SetText(message or T("SCOPE"))
end

function TM:Dialog(title, report, initial, required, callback)
    self:CreateWindow()
    if not self.dialog then
        local f = CreateFrame("Frame", nil, self.window)
        self.dialog = f
        f:SetPoint("TOPLEFT", 20, -85)
        f:SetPoint("BOTTOMRIGHT", -20, 20)
        f.title = self.status
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", -22, 185)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(530)
        scroll:SetScrollChild(content)
        f.report = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.report:SetPoint("TOPLEFT")
        f.report:SetWidth(530)
        f.report:SetJustifyH("LEFT")
        f.content, f.scroll = content, scroll
        f.input = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.input:SetSize(530, 28)
        f.input:SetPoint("BOTTOMLEFT", 5, 65)
        f.input:SetAutoFocus(false)
        f.input:SetMaxLetters(0)
        f.inputHint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.inputHint:SetPoint("BOTTOMLEFT", 5, 40)
        f.inputHint:SetJustifyH("LEFT")
        f.error = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.error:SetPoint("BOTTOMLEFT", 0, 105)
        f.error:SetWidth(530)
        f.error:SetHeight(64)
        f.error:SetJustifyH("LEFT")
        f.error:SetTextColor(1, 0.35, 0.35)
        f.accept = Button(f, T("CONFIRM"), 120, function()
            if self.operation or not f.callback then return end
            local value = f.input:GetText()
            if f.nukeState and #f.nukeState.rows == 0 then f.error:SetText(T("NUKE_NO_SELECTION")); return end
            if f.required and not self:MatchesConfirmation(value, f.required) then f.error:SetText(T("TYPE_EXACT", f.required == "NUKE" and "NUKE / 123123" or f.required)); return end
            if f.needsName and not value:match("%S") then f.error:SetText(T("NAME_REQUIRED")); return end
            if InCombatLockdown() then f.error:SetText(T("COMBAT")); return end
            local callback = f.callback
            f.accept:SetEnabled(false)
            local ok, result, reason = pcall(callback, value)
            if not ok or result == false then
                local message = not ok and (T("CONFIRM_ERROR", tostring(result))) or reason or T("OP_FAILED")
                f.error:SetText(message)
                self:Message(message)
                f.accept:SetEnabled(true)
                return
            end
            if result == "pending" then
                f.operation = self.operation
                self:UpdateCombatState()
                return
            end
            self:ShowList(reason or T("OP_DONE"))
        end)
        f.accept:SetPoint("BOTTOMRIGHT", 0, 0)
        f.back = Button(f, T("BACK"), 120, function()
            if self.operation then
                self.operation.cancelled = true
                if not self.operation.awaiting then
                    if self.operation.kind == "restore" then self:AdvanceRestore(self.operation)
                    else self:AdvanceDeletion(self.operation) end
                end
                self:UpdateCombatState()
            else self:ShowList() end
        end)
        f.back:SetPoint("BOTTOMLEFT", 0, 0)
        f.input:SetScript("OnTextChanged", function(box)
            self:UpdateCombatState()
        end)
        f.input:SetScript("OnEscapePressed", function() f.back:GetScript("OnClick")(f.back) end)
    end
    local f = self.dialog
    local width = self.dashboardWidth or 760
    self.window:SetSize(width, 620)
    self.status:SetWidth(width - 50)
    for _, row in ipairs(f.mergeRows or {}) do row:Hide() end
    f.accept:Show()
    for _, row in ipairs(f.historyRows or {}) do row:Hide() end
    f.report:Show()
    f.scroll:Show()
    local dialogWidth = width - 50
    f.content:SetWidth(dialogWidth - 20)
    f.report:SetWidth(dialogWidth - 20)
    f.input:SetWidth(dialogWidth)
    f.error:SetWidth(dialogWidth)
    f.scroll:ClearAllPoints()
    f.scroll:SetPoint("TOPLEFT", 0, 0)
    f.scroll:SetPoint("BOTTOMRIGHT", -22, initial ~= nil and 160 or 110)
    f.restoreSpec = nil
    f.nukeState = nil
    if f.nukeBoard then f.nukeBoard:Hide(); f.nukeIntro:Hide(); f.nukeSummary:Hide() end
    f.error:ClearAllPoints()
    f.error:SetPoint("BOTTOMLEFT", 0, initial ~= nil and 102 or 45)
    f.error:SetHeight(initial ~= nil and 44 or 50)
    f.report:SetHeight(0)
    self.view = "confirm"
    self.listPanel:Hide()
    f.callback, f.required, f.needsName = callback, required, initial ~= nil and not required
    f.operation = nil
    f.back:SetText(T("BACK"))
    f.error:SetText("")
    f.title:SetText(title)
    f.report:SetText(report)
    f.content:SetHeight(math.max(1, f.report:GetStringHeight() + 12))
    f.scroll:SetVerticalScroll(0)
    f.inputHint:SetWidth(dialogWidth)
    f.inputHint:SetShown(required ~= nil)
    f.inputHint:SetText(required == "NUKE" and T("NUKE_REQUIRED") or "")
    f.input:SetShown(initial ~= nil)
    f.input:SetText(initial or "")
    f.accept:SetEnabled(not InCombatLockdown() and
        (not required or self:MatchesConfirmation(f.input:GetText(), required)) and
        (not f.needsName or f.input:GetText():match("%S") ~= nil))
    f:Show()
    self.window:Show()
    if initial ~= nil then f.input:SetFocus(); f.input:HighlightText() end
end

function TM:ShowMerge(group)
    if self.operation then self:Message(T("BUSY")); return end
    if InCombatLockdown() then self:Message(T("COMBAT")); return end
    if not group then
        self:ShowList()
        if #self.groups == 0 then self:Message(T("NO_DUPLICATES")); return end
        if #self.groups > 1 then self:Message(T("PICK_GROUP")); return end
        group = self.groups[1]
    end
    local names = {}
    for _, row in ipairs(group.rows) do names[#names + 1] = self:Colored(row, group.color) end
    self:Dialog(T("MERGE_TITLE"),
        T("MERGE_INTRO") .. table.concat(names, "\n") ..
        T("MERGE_DETAIL"),
        self:SuggestedName(group), nil, function(name) return self:Merge(group, name) end)
end

function TM:ShowClean()
    if self.operation then self:Message(T("BUSY")); return end
    if InCombatLockdown() then self:Message(T("COMBAT")); return end
    self:CreateWindow()
    self:Refresh()
    if #self.groups == 0 then self:Message(T("NO_DUPLICATES")); return end
    local groups, lines = self.groups, { T("CLEAN_INTRO") }
    for i, group in ipairs(groups) do
        lines[#lines + 1] = T("GROUP_KEEP", i, self:Colored(group.rows[1], group.color))
        for j = 2, #group.rows do lines[#lines + 1] = T("REMOVE", self:Colored(group.rows[j], group.color)) end
        lines[#lines + 1] = ""
    end
    self:Dialog(T("CLEAN_TITLE"), table.concat(lines, "\n"), nil, nil,
        function() return self:Clean(groups) end)
end

function TM:ShowNuke()
    if self.operation then self:Message(T("BUSY")); return end
    if InCombatLockdown() then self:Message(T("COMBAT")); return end
    self:CreateWindow()
    local specs = self:Specializations()
    local total = 0
    for _, spec in ipairs(specs) do total = total + #spec.rows end
    if total == 0 then self:Message(T("NO_SAVED")); return end
    local state = { specs = specs, selected = {}, rows = {} }
    self:Dialog(T("NUKE_SELECT_TITLE"), "", "", "NUKE", function(token)
        local scope = {}
        for id, checked in pairs(state.selected) do if checked then scope[id] = true end end
        return self:Nuke(state.rows, token, scope)
    end)
    local f = self.dialog
    f.nukeState = state
    local width = math.max(600, #specs * 230 + 40)
    self.window:SetSize(width, 600)
    self.status:SetWidth(width - 50)
    f.input:SetWidth(width - 50)
    f.error:SetWidth(width - 40)
    f.scroll:Hide()
    if not f.nukeBoard then
        f.nukeBoard = CreateFrame("Frame", nil, f)
        f.nukeBoard:SetPoint("TOPLEFT", 0, -80)
        f.nukeBoard:SetPoint("BOTTOMRIGHT", 0, 185)
        f.nukeIntro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.nukeIntro:SetPoint("TOPLEFT", 0, 0)
        f.nukeIntro:SetJustifyH("LEFT")
        f.nukeSummary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.nukeSummary:SetPoint("BOTTOMLEFT", 0, 35)
        f.nukeSummary:SetJustifyH("LEFT")
        f.nukeCards = {}
    end
    f.nukeIntro:SetWidth(width - 40)
    f.nukeIntro:SetHeight(70)
    f.nukeIntro:SetText(T("NUKE_SELECT_INTRO"))
    f.nukeSummary:SetWidth(width - 40)
    f.nukeSummary:SetHeight(25)
    for _, card in ipairs(f.nukeCards) do card:Hide() end
    local cardWidth = (width - 40 - (#specs - 1) * 12) / #specs
    for i, spec in ipairs(specs) do
        local card = f.nukeCards[i]
        if not card then
            card = CreateFrame("Frame", nil, f.nukeBoard, "BackdropTemplate")
            card:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12 })
            card:SetBackdropColor(0.08, 0.10, 0.14, 0.95)
            card.check = CreateFrame("CheckButton", nil, card, "UICheckButtonTemplate")
            card.check:SetSize(26, 26)
            card.check:SetPoint("TOPLEFT", 8, -10)
            card.icon = card:CreateTexture(nil, "ARTWORK")
            card.icon:SetSize(32, 32)
            card.icon:SetPoint("TOPLEFT", 38, -8)
            card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            card.name:SetPoint("TOPLEFT", 78, -8)
            card.name:SetJustifyH("LEFT")
            card.count = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            card.count:SetPoint("TOPLEFT", 10, -48)
            local scroll = CreateFrame("ScrollFrame", nil, card, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 10, -72)
            scroll:SetPoint("BOTTOMRIGHT", -28, 12)
            card.content = CreateFrame("Frame", nil, scroll)
            scroll:SetScrollChild(card.content)
            card.builds = card.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            card.builds:SetPoint("TOPLEFT")
            card.builds:SetJustifyH("LEFT")
            card.scroll = scroll
            f.nukeCards[i] = card
        end
        card.spec = spec
        -- Replace the handler each opening so it captures the current selection snapshot.
        card.check:SetScript("OnClick", function(box)
            if self.operation or InCombatLockdown() then box:SetChecked(state.selected[card.spec.id] or false); return end
            state.selected[card.spec.id] = box:GetChecked()
            f.input:SetText("")
            self:UpdateNukeSelection()
        end)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", (i - 1) * (cardWidth + 12), 0)
        card:SetPoint("BOTTOMLEFT", (i - 1) * (cardWidth + 12), 0)
        card:SetWidth(cardWidth)
        card.icon:SetTexture(spec.icon or "Interface/Icons/INV_Misc_QuestionMark")
        card.name:SetWidth(cardWidth - 86)
        card.name:SetHeight(36)
        card.name:SetText(spec.name)
        card.count:SetText(T("SPEC_LOADOUT_COUNT", #spec.rows))
        card.content:SetWidth(cardWidth - 38)
        card.builds:SetWidth(cardWidth - 38)
        local _, colors = self:Group(spec.rows)
        local names = {}
        for _, row in ipairs(spec.rows) do names[#names + 1] = self:Colored(row, colors[row.id]) end
        card.builds:SetText(#names > 0 and table.concat(names, "\n") or T("NO_SAVED"))
        card.content:SetHeight(math.max(1, card.builds:GetStringHeight() + 12))
        card.scroll:SetVerticalScroll(0)
        card.check:SetChecked(false)
        card:Show()
    end
    f.nukeBoard:Show(); f.nukeIntro:Show(); f.nukeSummary:Show()
    self:UpdateNukeSelection()
end

function TM:UpdateNukeSelection()
    local f = self.dialog
    if not f or not f.nukeState then return end
    local state = f.nukeState
    state.rows = {}
    local count = 0
    for _, spec in ipairs(state.specs) do
        if state.selected[spec.id] then
            count = count + 1
            for _, row in ipairs(spec.rows) do state.rows[#state.rows + 1] = row end
        end
    end
    f.nukeSummary:SetText(T("NUKE_SELECTION_COUNT", count, #state.rows))
    self:UpdateCombatState()
end

-- Color from the last snapshot; never scan talents while generating the menu.
function TM:ModifyTalentMenu(_, root)
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if talents and talents:IsInspecting() then return end
    local colors = self.colorCache and self.colorCache[self:SpecID()] or {}
    for _, description in root:EnumerateElementDescriptions() do
        local color = colors[description:GetData()]
        if color then
            description:AddInitializer(function(button)
                if button.fontString then
                    button.fontString:SetTextColor(tonumber(color:sub(1,2),16)/255,
                        tonumber(color:sub(3,4),16)/255,tonumber(color:sub(5,6),16)/255)
                end
            end)
        end
    end
end
function TM:RegisterMenu()
    if self.menuRegistered or not Menu or not Menu.ModifyMenu then return end
    Menu.ModifyMenu("MENU_CLASS_TALENT_PROFILE", function(dropdown, root) self:ModifyTalentMenu(dropdown, root) end)
    self.menuRegistered = true
end

function TM:EnsureDuplicateCheck()
    if self.duplicateCheckAttempted or InCombatLockdown() or not self:Supported() then return end
    self:CheckDuplicates()
end

function TM:SetDuplicateStatus(count)
    self.lastDuplicateCount = count
    if not self.duplicateBadge then return end
    if count == nil then
        self.duplicateBadge.label:SetText(T(self.duplicateCheckAttempted and "CHECK_INCOMPLETE" or "NOT_CHECKED"))
        self.duplicateBadge.label:SetTextColor(0.65, 0.65, 0.65)
        self.duplicateBadge.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
    elseif count == 0 then
        self.duplicateBadge.label:SetText(T("NO_DUPLICATED"))
        self.duplicateBadge.label:SetTextColor(0.35, 1, 0.45)
        self.duplicateBadge.icon:SetTexture("Interface/RaidFrame/ReadyCheck-Ready")
    else
        self.duplicateBadge.label:SetText(T("DUPLICATED_FOUND"))
        self.duplicateBadge.label:SetTextColor(1, 0.82, 0.1)
        self.duplicateBadge.icon:SetTexture("Interface/DialogFrame/UI-Dialog-Icon-AlertNew")
    end
end

function TM:CheckDuplicates()
    if not self:Supported() or InCombatLockdown() then self:SetDuplicateStatus(nil); return end
    self.duplicateCheckAttempted = true
    self.colorCache = self.colorCache or {}
    local count, unknown = 0, false
    for _, spec in ipairs(self:Specializations()) do
        local groups, colors = self:Group(spec.rows)
        self.colorCache[spec.id] = colors
        count = count + #groups
        for _, row in ipairs(spec.rows) do if not row.key then unknown = true end end
    end
    if count == 0 and unknown then self:SetDuplicateStatus(nil) else self:SetDuplicateStatus(count) end
end

function TM:CheckCreatedLoadout(id, attempt)
    if self.lastCheckedCreation == id then return end
    if InCombatLockdown() or self.operation then self:SetDuplicateStatus(nil); return end
    local info = C_Traits.GetConfigInfo(id)
    if not info or id == C_ClassTalents.GetActiveConfigID() then return end
    local saved = false
    for _, savedID in ipairs(C_ClassTalents.GetConfigIDsBySpecID() or {}) do if savedID == id then saved = true; break end end
    local populated = not C_ClassTalents.IsConfigPopulated or C_ClassTalents.IsConfigPopulated(id)
    if not saved or not populated then
        if attempt < 4 then C_Timer.After(0.25, function() self:CheckCreatedLoadout(id, attempt + 1) end) end
        return
    end
    self.lastCheckedCreation = id
    if self.window and self.window:IsShown() and self.view == "list" then self:Refresh()
    else self:CheckDuplicates() end
end

function TM:OpenFromLauncher()
    local ok, reason = pcall(self.ShowList, self)
    if not ok then
        self.launcherLastError = tostring(reason)
        self:Message(T("LAUNCHER_ERROR", self.launcherLastError))
        return false
    end
    self.launcherLastError = nil
    self.window:SetFrameStrata("DIALOG")
    self.window:SetFrameLevel(200)
    self.window:SetToplevel(true)
    self.window:Raise()
    return true
end

function TM:LauncherReport()
    self:Message(T("LAUNCHER_REPORT", self.launcherMouseEvents or 0, self.launcherClickEvents or 0,
        self.window and self.window:IsShown() and T("OK") or T("UNAVAILABLE"), self.launcherLastError or "-"))
end

function TM:Attach()
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not talents or self.attached or InCombatLockdown() then return end
    self.attached = talents
    local launcher = CreateFrame("Frame", "LawkhsTalentMergerLauncherContainer", UIParent)
    launcher:SetPoint("TOPRIGHT", talents, "TOPRIGHT", -45, -38)
    launcher:SetSize(240, 62)
    launcher:SetFrameStrata("DIALOG")
    launcher:SetFrameLevel(100)
    launcher:SetToplevel(true)
    launcher:SetScale(talents:GetEffectiveScale() / UIParent:GetEffectiveScale())
    local open = CreateFrame("Button", "LawkhsTalentMergerOpenButton", launcher, "BackdropTemplate")
    open:SetSize(190, 25)
    open:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8 })
    local label = open:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    open:SetFontString(label)
    local function resetButton()
        open:SetBackdropColor(0.35, 0.055, 0.035, 1)
        open:SetBackdropBorderColor(0.70, 0.52, 0.24, 1)
        open:SetButtonState("NORMAL")
    end
    open:SetScript("OnEnter", function()
        open:SetBackdropColor(0.55, 0.12, 0.055, 1)
        open:SetBackdropBorderColor(1, 0.82, 0.25, 1)
    end)
    open:SetScript("OnLeave", resetButton)
    open:SetScript("OnShow", resetButton)
    resetButton()
    open:SetText("Lawkh's Talent Merger")
    open:SetWidth(math.max(190, open:GetTextWidth() + 24))
    open:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        open:SetBackdropColor(0.22, 0.035, 0.025, 1)
        self.launcherMouseEvents = (self.launcherMouseEvents or 0) + 1
        self.launcherPress = true
        self:OpenFromLauncher()
        resetButton()
    end)
    open:SetScript("OnClick", function(_, button)
        if button and button ~= "LeftButton" then return end
        self.launcherClickEvents = (self.launcherClickEvents or 0) + 1
        if not self.launcherPress then self:OpenFromLauncher() end
        self.launcherPress = nil
    end)
    -- Keep the launcher away from the loadout menu, which opens above its anchor.
    open:SetPoint("TOPRIGHT")
    open:EnableMouse(true)
    open:RegisterForClicks("AnyUp")
    open:SetEnabled(true)
    self.openButton = open
    local badge = CreateFrame("Frame", nil, launcher, "BackdropTemplate")
    badge:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -4)
    badge:SetSize(math.max(190, open:GetTextWidth() + 24), 28)
    badge:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8 })
    badge:SetBackdropColor(0.04, 0.07, 0.10, 0.95)
    badge.icon = badge:CreateTexture(nil, "ARTWORK")
    badge.icon:SetPoint("LEFT", 6, 0); badge.icon:SetSize(18, 18)
    badge.label = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge.label:SetPoint("LEFT", 29, 0); badge.label:SetWidth(155); badge.label:SetJustifyH("LEFT")
    self.duplicateBadge = badge
    self:SetDuplicateStatus(self.lastDuplicateCount)
    local function checkOnShow()
        C_Timer.After(0.1, function()
            if talents:IsVisible() then self:EnsureDuplicateCheck() end
        end)
    end
    talents:HookScript("OnShow", function() launcher:Show(); checkOnShow() end)
    talents:HookScript("OnHide", function() launcher:Hide(); self.launcherPress = nil end)
    if talents:IsVisible() then launcher:Show(); checkOnShow() else launcher:Hide() end
end

function TM:UpdateCombatState()
    local combat = InCombatLockdown()
    local ready = self:Supported() and not combat and not self.operation
    if self.window then
        self.mergeButton:SetEnabled(ready)
        self.cleanButton:SetEnabled(ready)
        self.nukeButton:SetEnabled(ready)
        for _, widget in ipairs(self.widgets) do widget.merge:SetEnabled(ready) end
        if combat and self.view == "list" then self.status:SetText(T("COMBAT_ACTIONS")) end
    end
    local f = self.dialog
    if f and f:IsShown() then
        local value = f.input:GetText()
        f.accept:SetEnabled(ready and f.callback ~= nil and (not f.nukeState or #f.nukeState.rows > 0) and (not f.required or self:MatchesConfirmation(value, f.required)) and
            (not f.needsName or value:match("%S") ~= nil))
        if self.operation then
            f.error:SetText(T("PROGRESS", self.operation.deleted, #self.operation.rows,
                self.operation.cancelled and T("STOPPING") or T("WAIT_CONFIRM")))
            f.back:SetText(T("STOP"))
        elseif combat then
            f.error:SetText(T("COMBAT"))
        elseif f.error:GetText() == T("COMBAT") then
            f.error:SetText("")
        end
        if f.nukeState then
            for _, card in ipairs(f.nukeCards) do
                card.check:SetEnabled(ready and #card.spec.rows > 0)
                card:SetBackdropBorderColor(f.nukeState.selected[card.spec.id] and 1 or 0.3,
                    f.nukeState.selected[card.spec.id] and 0.7 or 0.35, 0.2)
            end
        end
    end
end

function TM:DeletionFinished(op)
    local f = self.dialog
    if f and f.operation == op then
        f.operation = nil
        f.back:SetText(T("BACK"))
        if op.success then self:ShowList(op.message)
        else
            f.callback = nil
            f.accept:SetEnabled(false)
            f.error:SetText(op.message .. T("RETURN_REVIEW"))
        end
    elseif self.listHint then self.listHint:SetText(op.message) end
end

function TM:Refresh()
    self:CreateWindow()
    self:RegisterMenu()
    if not self:Supported() then
        self.status:SetText(T("API_UNAVAILABLE"))
        self.mergeButton:SetEnabled(false); self.cleanButton:SetEnabled(false); self.nukeButton:SetEnabled(false)
        return
    end
    if InCombatLockdown() then
        self:UpdateCombatState()
        return
    end
    local specID = self:SpecID()
    self.rows = specID and self:Read(specID) or {}
    self.groups, self.colors = self:Group(self.rows)
    self.colorCache = self.colorCache or {}
    self.colorCache[specID] = self.colors
    for _, widget in ipairs(self.widgets) do widget:Hide() end
    local widgetIndex, y = 0, 0
    local function line(text, group)
        widgetIndex = widgetIndex + 1
        local widget = self.widgets[widgetIndex]
        if not widget then
            widget = CreateFrame("Frame", nil, self.content)
            widget:SetSize(530, 30)
            widget.label = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            widget.label:SetPoint("LEFT", 0, 0)
            widget.label:SetWidth(415)
            widget.label:SetJustifyH("LEFT")
            widget.merge = Button(widget, T("MERGE"), 80, function() self:ShowMerge(widget.group) end)
            widget.merge:SetPoint("RIGHT")
            self.widgets[widgetIndex] = widget
        end
        widget:SetPoint("TOPLEFT", 0, -y)
        widget.group = group
        widget.label:SetText(text)
        widget.merge:SetShown(group ~= nil)
        widget:Show()
        y = y + 30
    end
    for i, group in ipairs(self.groups) do
        line("|cff" .. group.color .. T("GROUP_DUPLICATES", i, #group.rows) .. "|r", group)
        for _, row in ipairs(group.rows) do line("    " .. self:Colored(row, group.color)) end
    end
    line(T("UNIQUE_HEADER"))
    local unreadable = 0
    for _, row in ipairs(self.rows) do
        if not row.export then unreadable = unreadable + 1 end
        if not self.colors[row.id] then line(row.name .. (not row.export and T("NO_EXPORT_SUFFIX") or "")) end
    end
    self.content:SetHeight(math.max(y, 1))
    if self.view == "list" then
        self.status:SetText(T("SUMMARY", #self.rows, #self.groups) ..
            (unreadable > 0 and (T("UNREADABLE_SUFFIX", unreadable)) or ""))
    end
    self:UpdateCombatState()
    self:Attach()
end

TM:RegisterMenu()

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_CREATED",
    "TRAIT_CONFIG_DELETED", "TRAIT_CONFIG_LIST_UPDATED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= "LawkhsTalentMerger" and name ~= "Blizzard_PlayerSpells" then return end
    end
    if event == "TRAIT_CONFIG_DELETED" then TM:ConfirmDeletion(...) end
    if TM.ConfirmRestore and TM.operation and TM.operation.kind == "restore" and
        (event == "TRAIT_CONFIG_CREATED" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED") then TM:ConfirmRestore() end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then TM:UpdateCombatState() end
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" or event == "PLAYER_REGEN_ENABLED" then
        TM:RegisterMenu(); TM:Attach()
    end
    -- New saved loadouts (including imports) get one check after population.
    -- Ordinary config updates never schedule a background scan.
    if event == "TRAIT_CONFIG_CREATED" and not TM.operation then
        local id = ...
        if type(id) == "number" then C_Timer.After(0.25, function() TM:CheckCreatedLoadout(id, 1) end) end
    end
end)

SLASH_LAWKHSTALENTMERGER1 = "/tm"
SLASH_LAWKHSTALENTMERGER2 = "/lawkhtm"
SlashCmdList.LAWKHSTALENTMERGER = function(command)
    command = command:lower():match("^%s*(.-)%s*$")
    if command == "memory" then TM:MemoryReport(); return end
    if command == "launcher" then TM:LauncherReport(); return end
    TM:CreateWindow()
    TM:UpdateCombatState()
    if command == "status" then TM:Refresh() end
    if command == "status" then
        TM:Message(T("STATUS", TM.version, TM:Supported() and T("OK") or T("UNAVAILABLE"),
            TM.menuRegistered and T("REGISTERED") or T("UNAVAILABLE"), #(TM.rows or {}), #(TM.groups or {})))
        if InCombatLockdown() then
            TM:Message(T("STATUS_COMBAT"))
        elseif TM:Supported() then
            local spec = TM:SpecID()
            local diagnostic = TM.readDiagnostics and TM.readDiagnostics[spec]
            local defaultIDs = C_ClassTalents.GetConfigIDsBySpecID() or {}
            TM:Message(T("DIAGNOSTICS", tostring(spec), #defaultIDs, diagnostic and diagnostic.raw or 0,
                diagnostic and diagnostic.missing or 0, diagnostic and diagnostic.active or 0,
                diagnostic and diagnostic.unreadable or 0, diagnostic and diagnostic.byNodes or 0))
        end
    elseif not TM:Supported() then TM:Message(T("RETAIL_REQUIRED"))
    elseif command == "nuke" then TM:ShowNuke()
    elseif command == "clean" then TM:ShowClean()
    elseif command == "merge" then TM:ShowMerge()
    elseif TM.window:IsShown() then TM.window:Hide()
    else TM:ShowList() end
end

function TM:MatchesConfirmation(value, required)
    return required == "NUKE" and self:IsNukeToken(value) or value == required
end
