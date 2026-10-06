local _, TM = ...
local function T(key, ...) return TM:T(key, ...) end

function TM:RestorePlan(backup, specID)
    local current, claimed, plan = self:Read(specID), {}, {}
    for _, build in ipairs(backup.builds) do
        if build.spec == specID then
            local found
            for _, row in ipairs(current) do
                if not claimed[row.id] and row.name == build.name and row.export == build.export then
                    found = row; break
                end
            end
            if found then claimed[found.id] = true
            else
                local survivor
                for _, row in ipairs(current) do
                    if not claimed[row.id] and row.id == build.id and build.renamedTo == row.name and
                        row.export == build.export then survivor = row; break end
                end
                if survivor then claimed[survivor.id] = true end
                -- Recent backups record actual deletions; legacy backups use missing copies.
                if survivor or build.removed or build.id == nil or not C_Traits.GetConfigInfo(build.id) then
                    plan[#plan + 1] = { build = build, survivor = survivor }
                end
            end
        end
    end
    return plan
end

-- Decode with Blizzard's serializer, then create a saved config directly.
-- Do not call OnTraitConfigCreateStarted: the native UI uses it to switch loadouts.
function TM:ImportBackup(build)
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not talents or not talents.ReadLoadoutHeader or not ExportUtil or not C_ClassTalents.ImportLoadout or
        talents:IsInspecting() or talents:GetSpecID() ~= build.spec then return false, T("RESTORE_OPEN_TALENTS") end
    local stream = ExportUtil.MakeImportDataStream(build.export)
    local valid, version, specID, hash = talents:ReadLoadoutHeader(stream)
    if not valid or specID ~= build.spec or version ~= C_Traits.GetLoadoutSerializationVersion() then
        return false, T("RESTORE_INVALID")
    end
    local tree = talents:GetTreeInfo()
    if not tree or (not talents:IsHashEmpty(hash) and not talents:HashEquals(hash, C_Traits.GetTreeHash(tree.ID))) then
        return false, T("RESTORE_INVALID")
    end
    local configID = C_ClassTalents.GetActiveConfigID()
    local content = talents:ReadLoadoutContent(stream, tree.ID)
    local entries = talents:ConvertToImportLoadoutEntryInfo(configID, tree.ID, content)
    return C_ClassTalents.ImportLoadout(configID, entries, build.name, build.export)
end

function TM:RemoveUndoSpec(backup, specID)
    for i = #backup.builds, 1, -1 do
        if backup.builds[i].spec == specID then table.remove(backup.builds, i) end
    end
    if #backup.builds == 0 then
        local backups = LawkhsTalentMergerDB and LawkhsTalentMergerDB.backups or {}
        for i = #backups, 1, -1 do
            if backups[i] == backup then table.remove(backups, i); break end
        end
    end
end

function TM:PruneUndoHistory(specs)
    if InCombatLockdown() or self.operation then return end
    local backups = LawkhsTalentMergerDB and LawkhsTalentMergerDB.backups or {}
    for i = #backups, 1, -1 do
        local backup = backups[i]
        for _, spec in ipairs(specs) do
            if #self:RestorePlan(backup, spec.id) == 0 then self:RemoveUndoSpec(backup, spec.id) end
        end
    end
end

function TM:FinishRestore(op, success, reason)
    if self.operation ~= op then return end
    self.operation = nil
    op.success = success
    -- Remove completed scopes; keep other specs and failed work available.
    if success then self:RemoveUndoSpec(op.backup, op.spec) end
    op.message = (reason and reason .. " " or "") .. T("RESTORE_RESULT", op.deleted, #op.rows)
    self:Message(op.message)
    self:Refresh()
    if self.DeletionFinished then self:DeletionFinished(op) end
end

function TM:ConfirmRestore()
    local op = self.operation
    if not op or op.kind ~= "restore" or not op.awaiting then return end
    local build = op.rows[op.index].build
    for _, row in ipairs(self:Read(op.spec)) do
        if not op.before[row.id] and row.name == build.name and row.export == build.export then
            build.restoredID = row.id
            op.awaiting = nil
            op.deleted = op.deleted + 1
            op.index = op.index + 1
            C_Timer.After(0.2, function() self:AdvanceRestore(op) end)
            return
        end
    end
end

function TM:AdvanceRestore(op)
    if self.operation ~= op or op.awaiting then return end
    local ok, reason = self:Writable(true)
    if op.cancelled then self:FinishRestore(op, false, T("DELETE_STOPPED")); return end
    if not ok then self:FinishRestore(op, false, reason); return end
    if self:SpecID() ~= op.spec then self:FinishRestore(op, false, T("RESTORE_SWITCH")); return end
    local item = op.rows[op.index]
    if not item then self:FinishRestore(op, true); return end
    if item.survivor then
        ok, reason = self:Validate({item.survivor}, true)
        if ok then ok = C_ClassTalents.RenameConfig(item.survivor.id, item.build.name) end
        if not ok then self:FinishRestore(op, false, reason or T("RENAME_FAILED")); return end
        item.build.renamedTo = nil
        op.deleted = op.deleted + 1; op.index = op.index + 1
        C_Timer.After(0.2, function() self:AdvanceRestore(op) end)
        return
    end
    op.before = {}
    for _, row in ipairs(self:Read(op.spec)) do op.before[row.id] = true end
    op.awaiting = true
    local attempt = op.index
    local called, accepted, errorText = pcall(self.ImportBackup, self, item.build)
    if not called or not accepted then
        op.awaiting = nil
        self:FinishRestore(op, false, called and (errorText or T("RESTORE_FAILED")) or T("RESTORE_FAILED"))
        return
    end
    self:ConfirmRestore()
    if self.UpdateCombatState then self:UpdateCombatState() end
    C_Timer.After(8, function()
        if self.operation ~= op or not op.awaiting or op.index ~= attempt then return end
        self:ConfirmRestore()
        if self.operation == op and op.awaiting then self:FinishRestore(op, false, T("RESTORE_TIMEOUT")) end
    end)
end

function TM:Restore(backup, specID)
    local ok, reason = self:Writable()
    if not ok then return false, reason end
    if self:SpecID() ~= specID then return false, T("RESTORE_SWITCH") end
    local plan = self:RestorePlan(backup, specID)
    if #plan == 0 then return false, T("RESTORE_NOTHING") end
    local op = {kind = "restore", backup = backup, spec = specID, rows = plan, index = 1, deleted = 0}
    self.operation = op
    self:AdvanceRestore(op)
    if self.operation == op then return "pending" end
    return op.success, op.message
end
