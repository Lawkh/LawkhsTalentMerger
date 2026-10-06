local _, TM = ...
if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end
local function T(key, ...) return TM:T(key, ...) end
local function Button(parent, text, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 26); b:SetText(text)
    b:SetWidth(math.max(width, b:GetTextWidth() + 24))
    b:SetScript("OnClick", callback)
    return b
end
local function Divider(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 20, y); line:SetPoint("TOPRIGHT", -20, y)
    line:SetHeight(1); line:SetColorTexture(0.65, 0.50, 0.22, 0.6)
end

function TM:CreateDashboard()
    if self.dashboard then return end
    self.listScroll:Hide()
    local board = CreateFrame("Frame", nil, self.listPanel)
    board:SetPoint("TOPLEFT", 20, -105); board:SetPoint("BOTTOMRIGHT", -20, 125)
    self.dashboard, self.specCards, self.selectedSpecs = board, {}, {}
    Divider(self.listPanel, -78)
    local footer = self.listPanel:CreateTexture(nil, "ARTWORK")
    footer:SetPoint("BOTTOMLEFT", 20, 115); footer:SetPoint("BOTTOMRIGHT", -20, 115)
    footer:SetHeight(1); footer:SetColorTexture(0.65, 0.50, 0.22, 0.6)
    self.selectionLabel = self.listPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.selectionLabel:SetPoint("TOPLEFT", 20, -86)
    self.mergeButton:ClearAllPoints(); self.mergeButton:SetPoint("BOTTOMLEFT", 20, 22)
    self.cleanButton:ClearAllPoints(); self.cleanButton:SetPoint("LEFT", self.mergeButton, "RIGHT", 12, 0)
    self.refreshButton:ClearAllPoints(); self.refreshButton:SetPoint("BOTTOMLEFT", 20, 58)
    self.undoButton = Button(self.listPanel, T("UNDO"), 110, function() self:ShowHistory() end)
    self.undoButton:SetPoint("LEFT", self.cleanButton, "RIGHT", 12, 0)
    self.nukeButton:ClearAllPoints(); self.nukeButton:SetPoint("BOTTOMRIGHT", -20, 22)
end

function TM:UpdateDashboardSelection()
    local specs, builds = 0, 0
    for _, spec in ipairs(self.dashboardSpecs or {}) do
        if self.selectedSpecs[spec.id] then specs = specs + 1; builds = builds + #spec.rows end
    end
    self.selectionLabel:SetText(T("NUKE_SELECTION_COUNT", specs, builds))
end

function TM:RenderDashboard()
    self:CreateDashboard()
    local specs = self:Specializations()
    self.dashboardSpecs = specs
    local width = math.max(760, #specs * 230 + 40)
    if self.view == "list" then
        self.window:SetSize(width, 600); self.status:SetWidth(width - 40)
        self.listHint:SetWidth(width - 40)
    end
    for _, card in ipairs(self.specCards) do card:Hide() end
    local cardWidth = (width - 40 - (#specs - 1) * 12) / math.max(1, #specs)
    local total, groupTotal = 0, 0
    for i, spec in ipairs(specs) do
        local card = self.specCards[i]
        if not card then
            card = CreateFrame("Frame", nil, self.dashboard, "BackdropTemplate")
            card:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12})
            card:SetBackdropColor(0.07, 0.10, 0.15, 0.95)
            card.check = CreateFrame("CheckButton", nil, card, "UICheckButtonTemplate")
            card.check:SetSize(26, 26); card.check:SetPoint("TOPLEFT", 6, -10)
            card.icon = card:CreateTexture(nil, "ARTWORK")
            card.icon:SetSize(30, 30); card.icon:SetPoint("TOPLEFT", 36, -8)
            card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            card.name:SetPoint("TOPLEFT", 73, -8); card.name:SetJustifyH("LEFT")
            card.summary = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            card.summary:SetPoint("TOPLEFT", 10, -50); card.summary:SetJustifyH("LEFT")
            card.scroll = CreateFrame("ScrollFrame", nil, card, "UIPanelScrollFrameTemplate")
            card.scroll:SetPoint("TOPLEFT", 10, -85); card.scroll:SetPoint("BOTTOMRIGHT", -30, 12)
            card.content = CreateFrame("Frame", nil, card.scroll); card.scroll:SetScrollChild(card.content)
            card.lines = {}
            self.specCards[i] = card
        end
        card.spec = spec
        if #spec.rows == 0 then self.selectedSpecs[spec.id] = nil end
        card:ClearAllPoints(); card:SetPoint("TOPLEFT", (i - 1) * (cardWidth + 12), 0)
        card:SetPoint("BOTTOMLEFT", (i - 1) * (cardWidth + 12), 0); card:SetWidth(cardWidth)
        card.icon:SetTexture(spec.icon or "Interface/Icons/INV_Misc_QuestionMark")
        card.name:SetWidth(cardWidth - 80); card.name:SetHeight(35); card.name:SetText(spec.name)
        local groups, colors = self:Group(spec.rows)
        total = total + #spec.rows; groupTotal = groupTotal + #groups
        card.summary:SetWidth(cardWidth - 20); card.summary:SetHeight(30)
        card.summary:SetText(T("SUMMARY", #spec.rows, #groups))
        card:SetBackdropBorderColor(spec.id == self:SpecID() and 1 or 0.3, 0.6, 0.25)
        card.check:SetChecked(self.selectedSpecs[spec.id] or false)
        card.check:SetScript("OnClick", function(box)
            if self.operation or InCombatLockdown() then box:SetChecked(self.selectedSpecs[card.spec.id] or false); return end
            self.selectedSpecs[card.spec.id] = box:GetChecked()
            self:UpdateDashboardSelection()
        end)
        card.content:SetWidth(cardWidth - 40)
        for _, line in ipairs(card.lines) do line:Hide() end
        local n, y = 0, 0
        local function Row(text, group)
            n = n + 1
            local line = card.lines[n]
            if not line then
                line = CreateFrame("Frame", nil, card.content)
                line.label = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                line.label:SetPoint("TOPLEFT"); line.label:SetJustifyH("LEFT")
                line.merge = Button(line, T("MERGE"), 80, function() self:ShowMerge(line.group) end)
                line.merge:SetPoint("BOTTOMLEFT", 0, 3)
                card.lines[n] = line
            end
            line.group = group; line:ClearAllPoints(); line:SetPoint("TOPLEFT", 0, -y)
            line:SetSize(cardWidth - 40, group and 60 or 32)
            line.label:SetWidth(cardWidth - 40); line.label:SetHeight(30); line.label:SetText(text)
            line.merge:SetShown(group ~= nil); line.merge:SetEnabled(not self.operation and not InCombatLockdown())
            line:Show(); y = y + (group and 60 or 32)
        end
        for j, group in ipairs(groups) do
            Row("|cff" .. group.color .. T("GROUP_DUPLICATES", j, #group.rows) .. "|r", group)
            for _, row in ipairs(group.rows) do Row(self:Colored(row, group.color)) end
        end
        Row(T("UNIQUE_HEADER"))
        for _, row in ipairs(spec.rows) do
            if not colors[row.id] then Row(row.name .. (not row.export and T("NO_EXPORT_SUFFIX") or "")) end
        end
        if #spec.rows == 0 then Row(T("NO_SAVED")) end
        card.content:SetHeight(math.max(1, y)); card:Show()
    end
    if self.view == "list" then self.status:SetText(T("SUMMARY", total, groupTotal)) end
    self:UpdateDashboardSelection()
    self:UpdateCombatState()
end

function TM:ShowHistory()
    if self.operation then self:Message(T("BUSY")); return end
    self:Dialog(T("UNDO"), T("HISTORY_INTRO"), nil, nil, nil)
    local f = self.dialog
    f.accept:Hide()
    self.view = "history"
    if not f.historyRows then f.historyRows = {} end
    for _, row in ipairs(f.historyRows) do row:Hide() end
    local backups = LawkhsTalentMergerDB and LawkhsTalentMergerDB.backups or {}
    local n, y = 0, f.report:GetStringHeight() + 20
    local function Row(text, callback)
        n = n + 1
        local row = f.historyRows[n]
        if not row then
            row = CreateFrame("Frame", nil, f.content)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("TOPLEFT"); row.label:SetWidth(365); row.label:SetJustifyH("LEFT")
            row.button = Button(row, T("RESTORE"), 130, function() if row.callback then row.callback() end end)
            row.button:SetPoint("TOPRIGHT")
            f.historyRows[n] = row
        end
        row.callback = callback; row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y)
        row:SetSize(530, 55); row.label:SetHeight(50); row.label:SetText(text)
        row.button:SetShown(callback ~= nil); row.button:SetEnabled(not InCombatLockdown()); row:Show()
        y = y + 60
    end
    if #backups == 0 then Row(T("HISTORY_EMPTY")) end
    for _, backup in ipairs(backups) do
        local stamp = date and date("%d/%m %H:%M", backup.time) or tostring(backup.time)
        Row("|cffffcc66" .. T(backup.action:upper()) .. " · " .. stamp .. "|r")
        for _, spec in ipairs(self:Specializations()) do
            local count = 0
            for _, build in ipairs(backup.builds) do if build.spec == spec.id then count = count + 1 end end
            if count > 0 then
                local pending = #self:RestorePlan(backup, spec.id)
                Row(spec.name .. " · " .. T("RESTORE_PENDING", pending), pending > 0 and function()
                    self:ShowRestore(backup, spec)
                end or nil)
            end
        end
    end
    f.content:SetHeight(y)
end

function TM:ShowRestore(backup, spec)
    local lines = {T("RESTORE_DETAIL")}
    for _, item in ipairs(self:RestorePlan(backup, spec.id)) do lines[#lines + 1] = item.build.name end
    if spec.id ~= self:SpecID() then lines[#lines + 1] = "\n" .. T("RESTORE_SWITCH") end
    self:Dialog(T("RESTORE") .. " · " .. spec.name, table.concat(lines, "\n"), nil, nil,
        function() return self:Restore(backup, spec.id) end)
    self.dialog.restoreSpec = spec.id
    self:UpdateCombatState()
end

local oldCreate = TM.CreateWindow
function TM:CreateWindow()
    oldCreate(self)
    self:CreateDashboard()
end
local oldRefresh = TM.Refresh
function TM:Refresh()
    oldRefresh(self)
    if self:Supported() and not InCombatLockdown() then self:RenderDashboard() end
end
local oldState = TM.UpdateCombatState
function TM:UpdateCombatState()
    oldState(self)
    local ready = self:Supported() and not InCombatLockdown() and not self.operation
    if self.undoButton then self.undoButton:SetEnabled(ready) end
    for _, card in ipairs(self.specCards or {}) do
        card.check:SetEnabled(ready and #card.spec.rows > 0)
        for _, line in ipairs(card.lines) do line.merge:SetEnabled(ready) end
    end
    local f = self.dialog
    if f then
        if f.restoreSpec and f.restoreSpec ~= self:SpecID() then f.accept:SetEnabled(false) end
        for _, row in ipairs(f.historyRows or {}) do row.button:SetEnabled(ready) end
        if self.operation and self.operation.kind == "restore" then
            f.error:SetText(T("RESTORE_PROGRESS", self.operation.deleted, #self.operation.rows))
        end
    end
end

function TM:ShowNuke()
    if self.operation then self:Message(T("BUSY")); return end
    if InCombatLockdown() then self:Message(T("COMBAT")); return end
    self:CreateWindow()
    if not self.dashboardSpecs then self:ShowList() end
    local scope, rows, lines = {}, {}, {T("NUKE_SELECT_INTRO")}
    for _, spec in ipairs(self.dashboardSpecs or {}) do
        if self.selectedSpecs[spec.id] then
            scope[spec.id] = true
            lines[#lines + 1] = "\n|cffffcc66" .. spec.name .. "|r"
            for _, row in ipairs(spec.rows) do rows[#rows + 1] = row; lines[#lines + 1] = row.name end
        end
    end
    if #rows == 0 then self:ShowList(T("NUKE_NO_SELECTION")); return end
    self:Dialog(T("NUKE_SELECT_TITLE"), table.concat(lines, "\n"), "", "NUKE",
        function(token) return self:Nuke(rows, token, scope) end)
end
