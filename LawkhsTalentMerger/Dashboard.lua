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
    board:SetPoint("TOPLEFT", 20, -105); board:SetPoint("BOTTOMRIGHT", -20, 165)
    self.dashboard, self.specCards, self.selectedSpecs = board, {}, {}
    Divider(self.listPanel, -78)
    local footer = self.listPanel:CreateTexture(nil, "ARTWORK")
    footer:SetPoint("BOTTOMLEFT", 20, 155); footer:SetPoint("BOTTOMRIGHT", -20, 155)
    footer:SetHeight(1); footer:SetColorTexture(0.65, 0.50, 0.22, 0.6)
    self.selectionLabel = self.listPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.selectionLabel:SetPoint("TOPLEFT", 20, -86)
    self.mergeButton:ClearAllPoints(); self.mergeButton:SetPoint("BOTTOMLEFT", 20, 22)
    self.cleanButton:ClearAllPoints(); self.cleanButton:SetPoint("LEFT", self.mergeButton, "RIGHT", 12, 0)
    self.refreshButton:ClearAllPoints(); self.refreshButton:SetPoint("BOTTOMLEFT", 20, 58)
    self.undoButton = Button(self.listPanel, T("UNDO"), 110, function() self:ShowHistory() end)
    self.undoButton:SetPoint("LEFT", self.cleanButton, "RIGHT", 12, 0)
    self.nukeButton:ClearAllPoints(); self.nukeButton:SetPoint("BOTTOMRIGHT", -20, 22)
    self.listHint:ClearAllPoints(); self.listHint:SetPoint("BOTTOMLEFT", 20, 132); self.listHint:SetHeight(18)
    self.actionPreviewHint = self.listPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.actionPreviewHint:SetPoint("BOTTOMLEFT", 20, 90)
    self.actionPreviewHint:SetHeight(34)
    self.actionPreviewHint:SetJustifyH("LEFT")
    self.actionPreviewHint:SetTextColor(0.80, 0.87, 0.94)
    self.actionPreviewHint:SetText(T("ACTION_PREVIEW_HINT"))
    self.hideUnique = CreateFrame("CheckButton", nil, self.listPanel, "UICheckButtonTemplate")
    self.hideUnique:SetSize(24, 24); self.hideUnique:SetPoint("TOPRIGHT", -22, -42)
    self.hideUnique.label = self.hideUnique:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.hideUnique.label:SetPoint("RIGHT", self.hideUnique, "LEFT", -5, 0)
    self.hideUnique.label:SetText(T("HIDE_UNIQUE"))
    self.hideUnique:SetScript("OnClick", function() if not InCombatLockdown() then self:RenderDashboard(self.dashboardSpecs) end end)
end

function TM:UpdateDashboardSelection()
    local specs, builds = 0, 0
    for _, spec in ipairs(self.dashboardSpecs or {}) do
        if self.selectedSpecs[spec.id] then specs = specs + 1; builds = builds + #spec.rows end
    end
    self.selectionLabel:SetText(T("NUKE_SELECTION_COUNT", specs, builds))
    self:UpdateCombatState()
end

local function Cell(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",edgeFile="Interface/Tooltips/UI-Tooltip-Border",edgeSize=8})
    f:SetBackdropColor(0.10,0.14,0.20,0.95)
    f.label=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f.label:SetPoint("CENTER");f.label:SetJustifyH("CENTER")
    return f
end

function TM:RenderDashboard(snapshot)
    self:CreateDashboard()
    local specs = snapshot or self:Specializations()
    self.dashboardSpecs = specs
    local width = math.max(760, #specs * 240 + 40)
    self.dashboardWidth = width
    if self.view == "list" then
        self.window:SetSize(width, 620); self.status:SetWidth(width - 280)
        self.listHint:SetWidth(width - 40)
        self.actionPreviewHint:SetWidth(width - 40)
    end
    for _, card in ipairs(self.specCards) do card:Hide() end
    local cardWidth = (width - 40 - (#specs - 1) * 12) / math.max(1, #specs)
    local total, groupTotal, unknown = 0, 0, false
    for i, spec in ipairs(specs) do
        local card = self.specCards[i]
        if not card then
            card = CreateFrame("Frame", nil, self.dashboard, "BackdropTemplate")
            card:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12})
            card:SetBackdropColor(0.05, 0.08, 0.12, 0.95)
            card.header=Cell(card);card.header:SetPoint("TOPLEFT",5,-5);card.header:SetPoint("TOPRIGHT",-5,-5);card.header:SetHeight(48)
            card.header.label:Hide()
            card.check = CreateFrame("CheckButton", nil, card.header, "UICheckButtonTemplate")
            card.check:SetSize(26, 26); card.check:SetPoint("RIGHT", -6, 0)
            card.icon = card.header:CreateTexture(nil, "ARTWORK")
            card.icon:SetSize(30, 30); card.icon:SetPoint("LEFT", 8, 0)
            card.name = card.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            card.name:SetPoint("CENTER"); card.name:SetJustifyH("CENTER")
            card.loadouts=Cell(card);card.loadouts:SetPoint("TOPLEFT",5,-54);card.loadouts:SetHeight(42)
            card.duplicates=Cell(card);card.duplicates:SetPoint("TOPRIGHT",-5,-54);card.duplicates:SetHeight(42)
            card.scroll = CreateFrame("ScrollFrame", nil, card, "UIPanelScrollFrameTemplate")
            card.scroll:SetPoint("TOPLEFT", 10, -109); card.scroll:SetPoint("BOTTOMRIGHT", -30, 12)
            card.content = CreateFrame("Frame", nil, card.scroll); card.scroll:SetScrollChild(card.content)
            card.lines = {}
            self.specCards[i] = card
        end
        card.spec = spec
        if #spec.rows == 0 then self.selectedSpecs[spec.id] = nil end
        card:ClearAllPoints(); card:SetPoint("TOPLEFT", (i - 1) * (cardWidth + 12), 0)
        card:SetPoint("BOTTOMLEFT", (i - 1) * (cardWidth + 12), 0); card:SetWidth(cardWidth)
        card.icon:SetTexture(spec.icon or "Interface/Icons/INV_Misc_QuestionMark")
        card.name:SetWidth(cardWidth - 90); card.name:SetHeight(36); card.name:SetText(spec.name)
        local groups, colors = self:Group(spec.rows)
        if spec.id == self:SpecID() then self.rows, self.groups, self.colors = spec.rows, groups, colors end
        total = total + #spec.rows; groupTotal = groupTotal + #groups
        for _, row in ipairs(spec.rows) do if not row.key then unknown = true end end
        local cellWidth=(cardWidth-12)/2
        card.loadouts:SetWidth(cellWidth);card.duplicates:SetWidth(cellWidth)
        card.loadouts.label:SetWidth(cellWidth-10);card.loadouts.label:SetHeight(34)
        card.duplicates.label:SetWidth(cellWidth-10);card.duplicates.label:SetHeight(34)
        card.loadouts.label:SetText(T("LOADOUT_CELL",#spec.rows))
        card.duplicates.label:SetText(#groups==0 and "|cff66dd88"..T("NO_DUPLICATED_GROUPS").."|r" or T("DUPLICATE_CELL",#groups))
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
        local function Row(text, color, heading)
            n = n + 1
            local line = card.lines[n]
            if not line then
                line = CreateFrame("Frame", nil, card.content,"BackdropTemplate")
                line:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",edgeFile="Interface/Tooltips/UI-Tooltip-Border",edgeSize=8})
                line.label = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                line.label:SetPoint("LEFT",8,0); line.label:SetJustifyH("LEFT")
                card.lines[n] = line
            end
            line:ClearAllPoints(); line:SetPoint("TOPLEFT", 0, -y)
            line:SetSize(cardWidth - 40, heading and 36 or 42)
            line:SetBackdropColor(heading and 0.10 or 0.07,0.12,0.18,0.95)
            if color then
                line:SetBackdropBorderColor(tonumber(color:sub(1,2),16)/255,tonumber(color:sub(3,4),16)/255,tonumber(color:sub(5,6),16)/255,0.6)
            else line:SetBackdropBorderColor(0.22,0.28,0.36,0.6) end
            line.label:SetWidth(cardWidth - 56); line.label:SetHeight(34); line.label:SetText(text)
            line:Show(); y = y + (heading and 44 or 50)
        end
        for j, group in ipairs(groups) do
            Row("|cff" .. group.color .. T("GROUP_DUPLICATES", j, #group.rows) .. "|r",group.color,true)
            for _, row in ipairs(group.rows) do Row(self:Colored(row, group.color),group.color) end
            y=y+6
        end
        if not self.hideUnique:GetChecked() then
            for _, row in ipairs(spec.rows) do
                if not colors[row.id] then Row(row.name .. (not row.export and T("NO_EXPORT_SUFFIX") or "")) end
            end
        end
        if n==0 then Row(#spec.rows==0 and T("NO_SAVED") or T("NO_DUPLICATED_GROUPS"),nil,true) end
        card.content:SetHeight(math.max(1, y)); card:Show()
    end
    if self.view == "list" then self.status:SetText(T("SUMMARY", total, groupTotal)) end
    if groupTotal == 0 and unknown then self:SetDuplicateStatus(nil) else self:SetDuplicateStatus(groupTotal) end
    self:UpdateDashboardSelection()
end

function TM:ShowHistory()
    if self.operation then self:Message(T("BUSY")); return end
    self:Dialog(T("UNDO"), T("HISTORY_INTRO"), nil, nil, nil)
    local f = self.dialog
    f.accept:Hide()
    self.view = "history"
    if not f.historyRows then f.historyRows = {} end
    for _, row in ipairs(f.historyRows) do row:Hide() end
    local historySpecs = self:Specializations()
    self:PruneUndoHistory(historySpecs)
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
        for _, spec in ipairs(historySpecs) do
            local count = 0
            for _, build in ipairs(backup.builds) do if build.spec == spec.id then count = count + 1 end end
            if count > 0 then
                local pending = #self:RestorePlan(backup, spec.id, spec.rows)
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
function TM:Refresh()
    self:CreateWindow()
    self:RegisterMenu()
    self:Attach()
    if not self:Supported() then self.status:SetText(T("API_UNAVAILABLE")); self:UpdateCombatState(); return end
    if InCombatLockdown() then self:UpdateCombatState(); return end
    -- Dialog previews are immutable. Read again when returning to the list.
    if self.view ~= "list" then self:UpdateCombatState(); return end
    self:RenderDashboard()
end
local oldState = TM.UpdateCombatState
function TM:UpdateCombatState()
    oldState(self)
    local ready = self:Supported() and not InCombatLockdown() and not self.operation
    if self.undoButton then self.undoButton:SetEnabled(ready) end
    if self.hideUnique then self.hideUnique:SetEnabled(not InCombatLockdown()) end
    for _, card in ipairs(self.specCards or {}) do
        card.check:SetEnabled(ready and #card.spec.rows > 0)

    end
    local selected = false
    for _, checked in pairs(self.selectedSpecs or {}) do if checked then selected = true end end
    if self.dashboard then
        self.mergeButton:SetEnabled(ready and selected)
        self.cleanButton:SetEnabled(ready and selected)
        self.nukeButton:SetEnabled(ready and selected)
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
    local scope, rows, lines, selectedNames = {}, {}, {}, {}
    for _, spec in ipairs(self.dashboardSpecs or {}) do
        if self.selectedSpecs[spec.id] then
            scope[spec.id] = true
            selectedNames[#selectedNames + 1] = spec.name
            lines[#lines + 1] = "\n|cffffcc66" .. spec.name .. "|r"
            for _, row in ipairs(spec.rows) do rows[#rows + 1] = row; lines[#lines + 1] = row.name end
        end
    end
    if #rows == 0 then self:ShowList(T("NUKE_NO_SELECTION")); return end
    table.insert(lines, 1, T("NUKE_CONFIRM_INTRO", #rows, table.concat(selectedNames, ", ")))
    self:Dialog(T("NUKE_CONFIRM_TITLE"), table.concat(lines, "\n"), "", "NUKE",
        function(token) return self:Nuke(rows, token, scope) end)
end

function TM:SelectedDuplicateGroups()
    self:CreateWindow()
    if not self.dashboardSpecs then self:ShowList() end
    local groups, count = {}, 0
    for _, spec in ipairs(self.dashboardSpecs or {}) do
        if self.selectedSpecs[spec.id] then
            count = count + 1
            for _, group in ipairs(self:Group(spec.rows)) do
                group.specName = spec.name
                groups[#groups + 1] = group
            end
        end
    end
    return groups, count
end

function TM:ShowClean()
    if self.operation then self:Message(T("BUSY")); return end
    if InCombatLockdown() then self:Message(T("COMBAT")); return end
    local groups,count = self:SelectedDuplicateGroups()
    if count==0 then self:ShowList(T("SELECT_SPECS"));return end
    if #groups==0 then self:ShowList(T("NO_DUPLICATES"));return end
    local lines={T("CLEAN_INTRO")}
    for i,group in ipairs(groups) do
        lines[#lines+1]="\n|cffffcc66"..group.specName.."|r"
        lines[#lines+1]=T("GROUP_KEEP",i,self:Colored(group.rows[1],group.color))
        for j=2,#group.rows do lines[#lines+1]=T("REMOVE",self:Colored(group.rows[j],group.color)) end
    end
    self:Dialog(T("CLEAN_TITLE"),table.concat(lines,"\n"),nil,nil,function() return self:Clean(groups) end)
end

function TM:ShowMerge()
    if self.operation then self:Message(T("BUSY"));return end
    if InCombatLockdown() then self:Message(T("COMBAT"));return end
    local groups,count=self:SelectedDuplicateGroups()
    if count==0 then self:ShowList(T("SELECT_SPECS"));return end
    if #groups==0 then self:ShowList(T("NO_DUPLICATES"));return end
    local inputs={}
    self:Dialog(T("MERGE_TITLE"),T("MERGE_BATCH_INTRO"),nil,nil,function()
        local names={}
        for i,box in ipairs(inputs) do names[i]=box:GetText() end
        return self:MergeMany(groups,names)
    end)
    local f=self.dialog
    f.mergeRows=f.mergeRows or {}
    local y=f.report:GetStringHeight()+20
    for i,group in ipairs(groups) do
        local row=f.mergeRows[i]
        if not row then
            row=CreateFrame("Frame",nil,f.content)
            row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            row.label:SetPoint("TOPLEFT");row.label:SetJustifyH("LEFT")
            row.input=CreateFrame("EditBox",nil,row,"InputBoxTemplate")
            row.input:SetAutoFocus(false);row.input:SetMaxLetters(0)
            row.input:SetScript("OnEscapePressed",function() f.back:GetScript("OnClick")(f.back) end)
            f.mergeRows[i]=row
        end
        local labels={"|cffffcc66"..group.specName.."|r"}
        for _,build in ipairs(group.rows) do labels[#labels+1]=self:Colored(build,group.color) end
        row.label:SetWidth(680);row.label:SetHeight(0);row.label:SetText(table.concat(labels,"\n"))
        local h=row.label:GetStringHeight()+52
        row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-y);row:SetSize(680,h)
        row.input:ClearAllPoints();row.input:SetPoint("BOTTOMLEFT",5,10);row.input:SetSize(660,28)
        row.input:SetText(self:SuggestedName(group));row:Show()
        inputs[i]=row.input;y=y+h+14
    end
    f.content:SetHeight(y)
end
