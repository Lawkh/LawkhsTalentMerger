local _, TM = ...
TM.palette = { "66ccff", "ffb366", "99e699", "e699ff", "ffff80", "ff8099", "80e6cc", "b3b3ff" }

function TM:Supported()
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and C_ClassTalents and C_Traits and C_SpecializationInfo and
        type(C_SpecializationInfo.GetSpecialization) == "function" and
        type(C_SpecializationInfo.GetSpecializationInfo) == "function" and
        type(C_SpecializationInfo.GetNumSpecializationsForClassID) == "function" and
        type(C_ClassTalents.GetConfigIDsBySpecID) == "function" and
        type(C_ClassTalents.DeleteConfig) == "function" and
        type(C_ClassTalents.RenameConfig) == "function" and
        type(C_Traits.GenerateImportString) == "function" and
        type(C_Traits.ConfigHasStagedChanges) == "function"
end

function TM:Message(text)
    print("|cff66ccffLawkh's Talent Merger:|r " .. text)
end

function TM:SpecID()
    -- Use the same helper as Blizzard's talent frame when it is available.
    if PlayerUtil and PlayerUtil.GetCurrentSpecID then
        local id = PlayerUtil.GetCurrentSpecID()
        if type(id) == "number" and id > 0 then return id end
    end
    local index = C_SpecializationInfo.GetSpecialization()
    local id = index and C_SpecializationInfo.GetSpecializationInfo(index)
    return id and id > 0 and id or nil
end

-- Export strings contain class, spec, hero choices and ranks, but no loadout name.
-- Failed/empty exports must never be grouped as duplicates.
function TM:Read(specID)
    local rows = {}
    if not specID or not self:Supported() or InCombatLockdown() then return rows end
    -- The nil argument is Blizzard's documented current-specialization query.
    -- Use it for the current spec, matching the verified in-game list.
    local current = specID == self:SpecID()
    local ids
    if current then ids = C_ClassTalents.GetConfigIDsBySpecID()
    else ids = C_ClassTalents.GetConfigIDsBySpecID(specID) end
    ids = ids or {}
    local diagnostic = { spec = specID, raw = #ids, missing = 0, active = 0, unreadable = 0 }
    self.readDiagnostics = self.readDiagnostics or {}
    self.readDiagnostics[specID] = diagnostic
    for _, id in ipairs(ids) do
        local info = C_Traits.GetConfigInfo(id)
        if info and id ~= C_ClassTalents.GetActiveConfigID() then
            local ok, export = pcall(C_Traits.GenerateImportString, id)
            rows[#rows + 1] = { id = id, spec = specID, name = info.name,
                key = ok and type(export) == "string" and export ~= "" and export or nil }
            if not rows[#rows].key then diagnostic.unreadable = diagnostic.unreadable + 1 end
        elseif not info then
            diagnostic.missing = diagnostic.missing + 1
        else
            diagnostic.active = diagnostic.active + 1
        end
    end
    return rows
end

function TM:Group(rows)
    local groups, byKey = {}, {}
    for _, row in ipairs(rows) do
        if row.key then
            local group = byKey[row.key]
            if not group then
                group = { key = row.key, rows = {} }
                byKey[row.key] = group
                groups[#groups + 1] = group
            end
            group.rows[#group.rows + 1] = row
        end
    end
    local duplicates, colors = {}, {}
    for _, group in ipairs(groups) do
        if #group.rows > 1 then
            duplicates[#duplicates + 1] = group
            group.color = self.palette[(#duplicates - 1) % #self.palette + 1]
            for _, row in ipairs(group.rows) do colors[row.id] = group.color end
        end
    end
    return duplicates, colors
end

function TM:Colored(row, color)
    return color and ("|cff" .. color .. row.name .. "|r") or row.name
end

function TM:SuggestedName(group)
    local names, seen = {}, {}
    for _, row in ipairs(group.rows) do
        if not seen[row.name] then names[#names + 1] = row.name; seen[row.name] = true end
    end
    return table.concat(names, "/")
end

function TM:Writable()
    if not self:Supported() then return false, "Este addon necesita WoW Retail y sus API de talentos." end
    if InCombatLockdown() then return false, "Espera a salir de combate." end
    local active = C_ClassTalents.GetActiveConfigID()
    if active and C_Traits.ConfigHasStagedChanges(active) then
        return false, "Aplica o deshaz los cambios de talentos pendientes primero."
    end
    return true
end

function TM:Validate(rows)
    local ok, reason = self:Writable()
    if not ok then return false, reason end
    local cached = {}
    for _, row in ipairs(rows) do
        if not cached[row.spec] then
            cached[row.spec] = {}
            for _, current in ipairs(self:Read(row.spec)) do cached[row.spec][current.id] = current end
        end
        local current = cached[row.spec][row.id]
        if not current or current.name ~= row.name or current.key ~= row.key then
            return false, "Las builds han cambiado. Revisa la lista y confirma de nuevo."
        end
    end
    return true
end

function TM:Backup(rows, action)
    LawkhsTalentMergerDB = LawkhsTalentMergerDB or { backups = {} }
    LawkhsTalentMergerDB.backups = LawkhsTalentMergerDB.backups or {}
    local backup = { time = time(), action = action, builds = {} }
    for _, row in ipairs(rows) do
        if not row.key then return false, "No se pudo exportar " .. row.name .. ". No se ha borrado nada." end
        backup.builds[#backup.builds + 1] = { name = row.name, spec = row.spec, export = row.key }
    end
    table.insert(LawkhsTalentMergerDB.backups, 1, backup)
    while #LawkhsTalentMergerDB.backups > 10 do table.remove(LawkhsTalentMergerDB.backups) end
    return true
end

function TM:DeleteRows(rows)
    local deleted, failures = 0, {}
    for _, row in ipairs(rows) do
        if InCombatLockdown() then failures[#failures + 1] = row.name .. " (combate)"
        elseif C_ClassTalents.DeleteConfig(row.id) then
            deleted = deleted + 1
        else failures[#failures + 1] = row.name end
    end
    self:Message("Borradas: " .. deleted .. "." .. (#failures > 0 and (" No se pudieron borrar: " .. table.concat(failures, ", ")) or ""))
    self:Refresh()
end

function TM:Clean(groups)
    local all, remove = {}, {}
    for _, group in ipairs(groups) do
        for i, row in ipairs(group.rows) do
            all[#all + 1] = row
            if i > 1 then remove[#remove + 1] = row end
        end
    end
    local ok, reason = self:Validate(all)
    if ok then ok, reason = self:Backup(all, "Clean") end
    if not ok then self:Message(reason); return end
    self:DeleteRows(remove)
end

function TM:Merge(group, name)
    name = name:match("^%s*(.-)%s*$")
    if name == "" or name:find("[|%c]") then self:Message("Escribe un nombre válido sin códigos de color."); return end
    local ok, reason = self:Validate(group.rows)
    if ok then ok, reason = self:Backup(group.rows, "Merge") end
    if not ok then self:Message(reason); return end
    -- Reuse the first identical config: avoids the loadout cap and async creation,
    -- and preserves its equipment/action-bar settings.
    if not C_ClassTalents.RenameConfig(group.rows[1].id, name) then
        self:Message("No se pudo guardar el nombre. No se ha borrado ninguna build."); return
    end
    local remove = {}
    for i = 2, #group.rows do remove[#remove + 1] = group.rows[i] end
    self:DeleteRows(remove)
end

function TM:AllRows()
    local rows = {}
    if not self:Supported() or InCombatLockdown() then return rows end
    local _, _, classID = UnitClass("player")
    if not classID then return rows end
    for i = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
        for _, row in ipairs(self:Read(C_SpecializationInfo.GetSpecializationInfo(i))) do rows[#rows + 1] = row end
    end
    return rows
end

function TM:Nuke(rows, token)
    if token ~= "NUKE" then self:Message("Debes escribir exactamente NUKE."); return end
    local current = self:AllRows()
    if #current ~= #rows then self:Message("La lista ha cambiado. Confirma de nuevo."); return end
    local ok, reason = self:Validate(rows)
    if ok then ok, reason = self:Backup(rows, "Nuke") end
    if not ok then self:Message(reason); return end
    self:DeleteRows(rows)
end
