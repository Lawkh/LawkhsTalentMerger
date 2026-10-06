local _, TM = ...
local function T(key, ...) return TM:T(key, ...) end
TM.version = "0.6.1"
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

function TM:Export(id, specID, info)
    local ok, value = pcall(C_Traits.GenerateImportString, id)
    if ok and type(value) == "string" and value ~= "" then return value end
    -- Some saved configs do not export through the C API. Use Blizzard's
    -- serializer, with the saved config ID, without activating the loadout.
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    local treeID = info.treeIDs and info.treeIDs[1]
    if not talents or not treeID or not ExportUtil or
        not talents.WriteLoadoutHeader or not talents.WriteLoadoutContent or
        talents:GetSpecID() ~= specID or talents:IsInspecting() then return nil end
    ok, value = pcall(function()
        local hash = C_Traits.GetTreeHash(treeID)
        if not hash or #hash == 0 then return nil end
        if C_ClassTalents.IsConfigPopulated and not C_ClassTalents.IsConfigPopulated(id) then return nil end
        local stream = ExportUtil.MakeExportDataStream()
        talents:WriteLoadoutHeader(stream, C_Traits.GetLoadoutSerializationVersion(), specID, hash)
        talents:WriteLoadoutContent(stream, id, treeID)
        return stream:GetExportString()
    end)
    return ok and type(value) == "string" and value ~= "" and value or nil
end

function TM:Fingerprint(id, specID, info)
    if not info.treeIDs or #info.treeIDs == 0 or not C_Traits.GetTreeNodes or not C_Traits.GetNodeInfo then return nil end
    local ok, signature = pcall(function()
        local parts, seen = {}, {}
        for _, treeID in ipairs(info.treeIDs) do
            local nodes = C_Traits.GetTreeNodes(treeID)
            if not nodes or #nodes == 0 then return nil end
            parts[#parts + 1] = "tree:" .. treeID
            for _, nodeID in ipairs(nodes) do
                if not seen[nodeID] then
                    seen[nodeID] = true
                    local node = C_Traits.GetNodeInfo(id, nodeID)
                    if not node or type(node.currentRank) ~= "number" or type(node.ranksPurchased) ~= "number" then return nil end
                    -- Old choices in an inactive hero subtree are not part of the build.
                    if node.subTreeActive ~= false and node.currentRank > 0 then
                        local entry = node.activeEntry
                        if not entry or not entry.entryID or type(entry.rank) ~= "number" then return nil end
                        parts[#parts + 1] = nodeID .. ":" .. entry.entryID .. ":" .. node.ranksPurchased .. ":" .. entry.rank
                    end
                end
            end
        end
        table.sort(parts)
        return "nodes:" .. specID .. ":" .. table.concat(parts, ";")
    end)
    return ok and signature or nil
end

-- Store comparison signatures separately from restorable talent exports.
-- If node data is incomplete, exact export equality remains a safe fallback.
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
    local diagnostic = { spec = specID, raw = #ids, missing = 0, active = 0, unreadable = 0, byNodes = 0 }
    self.readDiagnostics = self.readDiagnostics or {}
    self.readDiagnostics[specID] = diagnostic
    for _, id in ipairs(ids) do
        local info = C_Traits.GetConfigInfo(id)
        if info and id ~= C_ClassTalents.GetActiveConfigID() then
            local export = self:Export(id, specID, info)
            local signature = self:Fingerprint(id, specID, info)
            rows[#rows + 1] = { id = id, spec = specID, name = info.name,
                key = signature or (export and "export:" .. export), export = export }
            if signature then diagnostic.byNodes = diagnostic.byNodes + 1 end
            if not export then diagnostic.unreadable = diagnostic.unreadable + 1 end
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

function TM:Writable(allowOperation)
    if self.operation and not allowOperation then return false, T("BUSY") end
    if not self:Supported() then return false, T("RETAIL_REQUIRED") end
    if InCombatLockdown() then return false, T("COMBAT") end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        return false, T("DEAD")
    end
    local active = C_ClassTalents.GetActiveConfigID()
    if active and C_Traits.ConfigHasStagedChanges(active) then
        return false, T("STAGED")
    end
    return true
end

function TM:Validate(rows, allowOperation)
    local ok, reason = self:Writable(allowOperation)
    if not ok then return false, reason end
    local cached = {}
    for _, row in ipairs(rows) do
        if not cached[row.spec] then
            cached[row.spec] = {}
            for _, current in ipairs(self:Read(row.spec)) do cached[row.spec][current.id] = current end
        end
        local current = cached[row.spec][row.id]
        if not current or current.name ~= row.name or current.key ~= row.key then
            return false, T("CHANGED")
        end
    end
    return true
end

function TM:Backup(rows, action)
    LawkhsTalentMergerDB = LawkhsTalentMergerDB or { backups = {} }
    LawkhsTalentMergerDB.backups = LawkhsTalentMergerDB.backups or {}
    local backup = { time = time(), action = action, builds = {} }
    for _, row in ipairs(rows) do
        if not row.export then return false, T("EXPORT_FAILED", row.name) end
        backup.builds[#backup.builds + 1] = { id = row.id, name = row.name, spec = row.spec, export = row.export, key = row.key }
    end
    table.insert(LawkhsTalentMergerDB.backups, 1, backup)
    while #LawkhsTalentMergerDB.backups > 10 do table.remove(LawkhsTalentMergerDB.backups) end
    self.lastBackup = backup
    return true
end

function TM:FinishDeletion(op, success, reason)
    if self.operation ~= op then return end
    self.operation = nil
    op.success = success
    op.message = (reason and (reason .. " ") or "") .. T("DELETED", op.deleted)
    if not success then op.message = op.message .. T("REMAINING", #op.rows - op.deleted) end
    self:Message(op.message)
    self:Refresh()
    if self.DeletionFinished then self:DeletionFinished(op) end
end

function TM:ConfirmDeletion(id)
    local op = self.operation
    if not op or op.awaiting ~= id then return end
    op.awaiting = nil
    op.deleted = op.deleted + 1
    if op.backup then
        for _, build in ipairs(op.backup.builds) do
            if build.id == id then build.removed = true end
        end
    end
    op.index = op.index + 1
    op.retries = 0
    if self.UpdateCombatState then self:UpdateCombatState() end
    C_Timer.After(0.2, function() self:AdvanceDeletion(op) end)
end

function TM:AdvanceDeletion(op)
    if self.operation ~= op or op.awaiting then return end
    if op.cancelled then self:FinishDeletion(op, false, T("DELETE_STOPPED")); return end
    local row = op.rows[op.index]
    if not row then self:FinishDeletion(op, true); return end
    local valid, reason = self:Validate({ row }, true)
    if not valid then self:FinishDeletion(op, false, reason); return end
    op.awaiting = row.id
    local ok, accepted = pcall(C_ClassTalents.DeleteConfig, row.id)
    if self.operation ~= op then return end
    if not ok or not accepted then
        op.awaiting = nil
        op.retries = op.retries + 1
        if op.retries <= 3 then
            C_Timer.After(0.4, function() self:AdvanceDeletion(op) end)
        else
            self:FinishDeletion(op, false, T("DELETE_REFUSED", row.name))
        end
        return
    end
    if self.UpdateCombatState then self:UpdateCombatState() end
    -- API success means the request was accepted; wait for server confirmation.
    if not C_Traits.GetConfigInfo(row.id) then self:ConfirmDeletion(row.id); return end
    C_Timer.After(5, function()
        if self.operation ~= op or op.awaiting ~= row.id then return end
        if not C_Traits.GetConfigInfo(row.id) then self:ConfirmDeletion(row.id)
        else self:FinishDeletion(op, false, T("DELETE_TIMEOUT", row.name)) end
    end)
end

function TM:DeleteRows(rows)
    if self.operation then return false, T("BUSY") end
    local op = { rows = rows, index = 1, deleted = 0, retries = 0, backup = self.lastBackup }
    self.operation = op
    self:AdvanceDeletion(op)
    if self.operation == op then return "pending" end
    return op.success, op.message
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
    if not ok then self:Message(reason); return false, reason end
    return self:DeleteRows(remove)
end

function TM:Merge(group, name)
    name = name:match("^%s*(.-)%s*$")
    if name == "" or name:find("[|%c]") then return false, T("NAME_INVALID") end
    local ok, reason = self:Validate(group.rows)
    if ok then ok, reason = self:Backup(group.rows, "Merge") end
    if not ok then self:Message(reason); return false, reason end
    -- Reuse the first identical config: avoids the loadout cap and async creation,
    -- and preserves its equipment/action-bar settings.
    if not C_ClassTalents.RenameConfig(group.rows[1].id, name) then
        local reason = T("RENAME_FAILED")
        self:Message(reason); return false, reason
    end
    self.lastBackup.builds[1].renamedTo = name
    local remove = {}
    for i = 2, #group.rows do remove[#remove + 1] = group.rows[i] end
    return self:DeleteRows(remove)
end

function TM:Specializations()
    local specs = {}
    if not self:Supported() or InCombatLockdown() then return specs end
    local _, _, classID = UnitClass("player")
    if not classID then return specs end
    for i = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
        local id, name, _, icon = C_SpecializationInfo.GetSpecializationInfo(i)
        if id and id > 0 then
            specs[#specs + 1] = { id = id, name = name or tostring(id), icon = icon,
                rows = self:Read(id) }
        end
    end
    return specs
end

function TM:AllRows()
    local rows = {}
    for _, spec in ipairs(self:Specializations()) do
        for _, row in ipairs(spec.rows) do rows[#rows + 1] = row end
    end
    return rows
end

function TM:Nuke(rows, token, selectedSpecs)
    if not self:IsNukeToken(token) then return false, T("NUKE_REQUIRED") end
    local writable, reason = self:Writable()
    if not writable then return false, reason end
    if #rows == 0 then return false, T("NUKE_NO_SELECTION") end
    local scope = selectedSpecs or {}
    if not selectedSpecs then
        for _, row in ipairs(rows) do scope[row.spec] = true end
    end
    for _, row in ipairs(rows) do
        if not scope[row.spec] then return false, T("LIST_CHANGED") end
    end
    local current = {}
    for _, row in ipairs(self:AllRows()) do
        if scope[row.spec] then current[#current + 1] = row end
    end
    if #current ~= #rows then return false, T("LIST_CHANGED") end
    local ok, reason = self:Validate(rows)
    if ok then ok, reason = self:Backup(rows, "Nuke") end
    if not ok then self:Message(reason); return false, reason end
    return self:DeleteRows(rows)
end

function TM:IsNukeToken(value)
    return value == "NUKE" or value == "123123"
end

function TM:MergeMany(groups, names)
    local all, remove = {}, {}
    for i, group in ipairs(groups) do
        local name = (names[i] or ""):match("^%s*(.-)%s*$")
        if name == "" or name:find("[|%c]") then return false, T("NAME_INVALID") end
        names[i] = name
        for j, row in ipairs(group.rows) do
            all[#all + 1] = row
            if j > 1 then remove[#remove + 1] = row end
        end
    end
    if #all == 0 then return false, T("NO_DUPLICATES") end
    local ok, reason = self:Validate(all)
    if ok then ok, reason = self:Backup(all, "Merge") end
    if not ok then return false, reason end
    for i, group in ipairs(groups) do
        if not C_ClassTalents.RenameConfig(group.rows[1].id, names[i]) then return false, T("RENAME_FAILED") end
        for _, build in ipairs(self.lastBackup.builds) do
            if build.id == group.rows[1].id then build.renamedTo = names[i]; break end
        end
    end
    return self:DeleteRows(remove)
end
