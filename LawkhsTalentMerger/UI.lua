local _, TM = ...
if not TM:Supported() then return end

local function Button(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 25)
    button:SetText(label)
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
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -85)
    scroll:SetPoint("BOTTOMRIGHT", -42, 132)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(530, 1)
    scroll:SetScrollChild(content)
    self.content, self.widgets = content, {}
    -- Position 1 is Merge; Nuke sits immediately above Clean.
    self.mergeButton = Button(frame, "Merge", 110, function() self:ShowMerge() end)
    self.mergeButton:SetPoint("BOTTOMLEFT", 20, 22)
    self.nukeButton = Button(frame, "Nuke", 110, function() self:ShowNuke() end)
    self.nukeButton:SetPoint("BOTTOMRIGHT", -20, 55)
    self.cleanButton = Button(frame, "Clean", 110, function() self:ShowClean() end)
    self.cleanButton:SetPoint("BOTTOMRIGHT", -20, 22)
    local refresh = Button(frame, "Actualizar", 110, function() self:Refresh() end)
    refresh:SetPoint("LEFT", self.mergeButton, "RIGHT", 12, 0)
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 20, 94)
    hint:SetText("Merge y Clean: especialización actual. Nuke: todas las especializaciones.")
    table.insert(UISpecialFrames, "LawkhsTalentMergerWindow")
    frame:Hide()
end

function TM:Dialog(title, report, initial, required, callback)
    if not self.dialog then
        local f = CreateFrame("Frame", "LawkhsTalentMergerDialog", UIParent, "BackdropTemplate")
        self.dialog = f
        f:SetSize(570, 440)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:EnableMouse(true)
        f:SetBackdrop(self.window:GetBackdrop())
        f:SetBackdropColor(0.05, 0.05, 0.07, 1)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.title:SetPoint("TOPLEFT", 20, -20)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -55)
        scroll:SetPoint("BOTTOMRIGHT", -42, 105)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(500)
        scroll:SetScrollChild(content)
        f.report = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.report:SetPoint("TOPLEFT")
        f.report:SetWidth(500)
        f.report:SetJustifyH("LEFT")
        f.content, f.scroll = content, scroll
        f.input = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.input:SetSize(500, 28)
        f.input:SetPoint("BOTTOMLEFT", 25, 65)
        f.input:SetAutoFocus(false)
        f.input:SetMaxLetters(0)
        f.accept = Button(f, "Confirmar", 120, function()
            local value = f.input:GetText()
            if f.required and value ~= f.required then return end
            if f.needsName and not value:match("%S") then return end
            f:Hide()
            f.callback(value)
        end)
        f.accept:SetPoint("BOTTOMRIGHT", -20, 20)
        local cancel = Button(f, "Cancelar", 120, function() f:Hide() end)
        cancel:SetPoint("RIGHT", f.accept, "LEFT", -10, 0)
        f.input:SetScript("OnTextChanged", function(box)
            f.accept:SetEnabled(not InCombatLockdown() and
                (not f.required or box:GetText() == f.required) and
                (not f.needsName or box:GetText():match("%S") ~= nil))
        end)
        f.input:SetScript("OnEscapePressed", function() f:Hide() end)
        table.insert(UISpecialFrames, "LawkhsTalentMergerDialog")
    end
    local f = self.dialog
    f.callback, f.required, f.needsName = callback, required, initial ~= nil and not required
    f.title:SetText(title)
    f.report:SetText(report)
    f.content:SetHeight(math.max(1, f.report:GetStringHeight() + 12))
    f.scroll:SetVerticalScroll(0)
    f.input:SetShown(initial ~= nil)
    f.input:SetText(initial or "")
    f.accept:SetEnabled(not InCombatLockdown() and
        (not required or f.input:GetText() == required) and
        (not f.needsName or f.input:GetText():match("%S") ~= nil))
    f:Show()
    if initial ~= nil then f.input:SetFocus(); f.input:HighlightText() end
end

function TM:ShowMerge(group)
    if InCombatLockdown() then self:Message("Espera a salir de combate."); return end
    if not group then
        self.window:Show()
        self:Refresh()
        if #self.groups == 0 then self:Message("No hay builds repetidas."); return end
        if #self.groups > 1 then self:Message("Elige Merge en el grupo que quieras fusionar."); return end
        group = self.groups[1]
    end
    local names = {}
    for _, row in ipairs(group.rows) do names[#names + 1] = self:Colored(row, group.color) end
    self:Dialog("Merge — nombre de la build resultante",
        "Estas builds tienen los mismos talentos:\n\n" .. table.concat(names, "\n") ..
        "\n\nSe renombrará la primera y se borrarán las demás. Se conservarán los talentos y los ajustes de la primera.\n\nNombre sugerido (puedes editarlo):",
        self:SuggestedName(group), nil, function(name) self:Merge(group, name) end)
end

function TM:ShowClean()
    if InCombatLockdown() then self:Message("Espera a salir de combate."); return end
    self:Refresh()
    if #self.groups == 0 then self:Message("No hay builds repetidas."); return end
    local groups, lines = self.groups, { "Se conservará la primera build de cada grupo, según el orden de WoW. Las copias restantes se borrarán. Las builds únicas se conservarán.\n" }
    for i, group in ipairs(groups) do
        lines[#lines + 1] = "Grupo " .. i .. " — CONSERVAR: " .. self:Colored(group.rows[1], group.color)
        for j = 2, #group.rows do lines[#lines + 1] = "BORRAR: " .. self:Colored(group.rows[j], group.color) end
        lines[#lines + 1] = ""
    end
    self:Dialog("Clean — revisar y confirmar", table.concat(lines, "\n"), nil, nil,
        function() self:Clean(groups) end)
end

function TM:ShowNuke()
    if InCombatLockdown() then self:Message("Espera a salir de combate."); return end
    local rows = self:AllRows()
    if #rows == 0 then self:Message("No hay builds guardadas."); return end
    local lines = { "Se borrarán TODAS las builds guardadas de este personaje, en TODAS sus especializaciones. Los talentos activos del personaje no se restablecen.\n" }
    for _, row in ipairs(rows) do
        local _, specName = GetSpecializationInfoForSpecID(row.spec)
        lines[#lines + 1] = "BORRAR: [" .. (specName or tostring(row.spec)) .. "] " .. row.name
    end
    lines[#lines + 1] = "\nEscribe exactamente NUKE para confirmar."
    self:Dialog("Nuke — borrar todas las builds", table.concat(lines, "\n"), "", "NUKE",
        function(token) self:Nuke(rows, token) end)
end

function TM:ColorNative(talents)
    if InCombatLockdown() or not talents.LoadSystem or not talents.configIDs or
        not talents.configIDToName or talents:IsInspecting() then return end
    local _, colors = self:Group(self:Read(talents:GetSpecID()))
    -- Use the public display translator; do not alter Blizzard's name lookup.
    talents.LoadSystem:SetSelectionOptions(talents.configIDs, function(id)
        local name = talents.configIDToName[id] or ""
        return colors[id] and ("|cff" .. colors[id] .. name .. "|r") or name
    end, NORMAL_FONT_COLOR, function(id)
        if talents:IsStarterBuildConfig(id) then return TALENT_FRAME_DROP_DOWN_STARTER_BUILD_TOOLTIP end
    end)
end

function TM:Attach()
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not talents or self.attached or InCombatLockdown() or
        type(talents.RefreshLoadoutOptions) ~= "function" or not talents.LoadSystem then return end
    self.attached = talents
    local open = Button(talents, "Lawkh's Talent Merger", 190, function()
        self.window:Show(); self:Refresh()
    end)
    open:SetPoint("TOPRIGHT", -45, -38)
    hooksecurefunc(talents, "RefreshLoadoutOptions", function(frame) self:ColorNative(frame) end)
    talents:HookScript("OnShow", function(frame) self:ColorNative(frame) end)
    self:ColorNative(talents)
end

function TM:Refresh()
    self:CreateWindow()
    if InCombatLockdown() then
        self.status:SetText("Espera a salir de combate para revisar las builds.")
        self.mergeButton:SetEnabled(false)
        self.cleanButton:SetEnabled(false)
        self.nukeButton:SetEnabled(false)
        return
    end
    local specID = self:SpecID()
    self.rows = specID and self:Read(specID) or {}
    self.groups, self.colors = self:Group(self.rows)
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
            widget.merge = Button(widget, "Merge", 80, function() self:ShowMerge(widget.group) end)
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
        line("|cff" .. group.color .. "Grupo " .. i .. " · " .. #group.rows .. " builds iguales|r", group)
        for _, row in ipairs(group.rows) do line("    " .. self:Colored(row, group.color)) end
    end
    line("Builds únicas / sin exportación")
    local unreadable = 0
    for _, row in ipairs(self.rows) do
        if not row.key then unreadable = unreadable + 1 end
        if not self.colors[row.id] then line(row.name .. (not row.key and " (no se pudo leer)" or "")) end
    end
    self.content:SetHeight(math.max(y, 1))
    self.status:SetText(#self.rows .. " builds · " .. #self.groups .. " grupos repetidos" ..
        (unreadable > 0 and (" · " .. unreadable .. " sin leer") or ""))
    self.mergeButton:SetEnabled(#self.groups > 0)
    self.cleanButton:SetEnabled(#self.groups > 0)
    self.nukeButton:SetEnabled(true)
    self:Attach()
    if self.attached then self:ColorNative(self.attached) end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_CREATED",
    "TRAIT_CONFIG_DELETED", "TRAIT_CONFIG_LIST_UPDATED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" and TM.dialog then TM.dialog:Hide() end
    if TM.pendingRefresh then return end
    TM.pendingRefresh = true
    C_Timer.After(0.1, function()
        TM.pendingRefresh = nil
        TM:Refresh()
    end)
end)

SLASH_LAWKHSTALENTMERGER1 = "/tm"
SLASH_LAWKHSTALENTMERGER2 = "/lawkhtm"
SlashCmdList.LAWKHSTALENTMERGER = function(command)
    TM:CreateWindow()
    TM:Refresh()
    command = command:lower():match("^%s*(.-)%s*$")
    if command == "nuke" then TM:ShowNuke()
    elseif command == "clean" then TM:ShowClean()
    elseif command == "merge" then TM:ShowMerge()
    else TM.window:SetShown(not TM.window:IsShown()) end
end
