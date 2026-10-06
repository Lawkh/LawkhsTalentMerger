local TM = {}
function GetLocale() return "esES" end
assert(loadfile("LawkhsTalentMerger/Localization.lua"))("LawkhsTalentMerger", TM)
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
assert(loadfile("LawkhsTalentMerger/Core.lua"))("LawkhsTalentMerger", TM)
assert(loadfile("LawkhsTalentMerger/UI.lua")) -- Syntax validation without game UI.

local builds, ids, combat, staged, renameFails, failedID
local deleted, renamed, messages
local function reset()
    builds = {
        [1] = { name = "Raid", key = "AAA" },
        [2] = { name = "Mythic", key = "AAA" },
        [3] = { name = "Raid", key = "BBB" },
        [4] = { name = "PvP", key = "CCC" },
        [5] = { name = "Arena", key = "CCC" },
        [6] = { name = "Unreadable" },
        [7] = { name = "Active", key = "AAA" },
        [8] = { name = "Other spec", key = "DDD" },
    }
    ids = { [71] = { 1, 2, 3, 4, 5, 6, 7 }, [72] = { 8 } }
    combat, staged, renameFails, failedID = false, false, false, nil
    deleted, renamed, messages = {}, {}, {}
    LawkhsTalentMergerDB = nil
    TM.operation = nil
end
function InCombatLockdown() return combat end
function UnitClass() return "Warrior", "WARRIOR", 1 end
C_SpecializationInfo = {
    GetSpecialization = function() return 1 end,
    GetSpecializationInfo = function(i) return i == 1 and 71 or 72 end,
    GetNumSpecializationsForClassID = function() return 2 end,
}
function time() return 123 end
C_Timer = { After = function(_, callback) callback() end }
TM.Message = function(_, text) messages[#messages + 1] = text end
TM.Refresh = function() end
C_ClassTalents = {
    GetActiveConfigID = function() return 7 end,
    GetConfigIDsBySpecID = function(spec) return ids[spec or TM:SpecID()] end,
    RenameConfig = function(id, name)
        if renameFails then return false end
        builds[id].name = name; renamed[id] = name; return true
    end,
    DeleteConfig = function(id)
        if id == failedID then return false end
        deleted[#deleted + 1] = id
        builds[id] = nil
        for _, list in pairs(ids) do
            for i, item in ipairs(list) do if item == id then table.remove(list, i); break end end
        end
        return true
    end,
}
C_Traits = {
    GetConfigInfo = function(id) return builds[id] end,
    GenerateImportString = function(id) return builds[id].key end,
    ConfigHasStagedChanges = function() return staged end,
}
local passed = 0
local function test(name, fn)
    reset(); fn(); passed = passed + 1; print("PASS " .. name)
end
test("groups by talents, preserves API order, excludes active and unreadable", function()
    local groups, colors = TM:Group(TM:Read(71))
    assert(#groups == 2 and groups[1].rows[1].id == 1)
    assert(colors[1] == colors[2] and colors[1] ~= colors[4])
    assert(not colors[3] and not colors[6] and not colors[7])
    assert(TM:SuggestedName(groups[1]) == "Raid/Mythic")
end)
test("clean retains first and unique builds, backs up exports", function()
    TM:Clean(TM:Group(TM:Read(71)))
    assert(#deleted == 2 and deleted[1] == 2 and deleted[2] == 5)
    assert(builds[1] and builds[3] and builds[4] and builds[6])
    assert(#LawkhsTalentMergerDB.backups[1].builds == 4)
end)
test("merge renames survivor and deletes only its group", function()
    local groups = TM:Group(TM:Read(71))
    TM:Merge(groups[1], " Raid/Mythic ")
    assert(renamed[1] == "Raid/Mythic" and #deleted == 1 and deleted[1] == 2)
end)
test("failed rename never deletes", function()
    renameFails = true
    TM:Merge(TM:Group(TM:Read(71))[1], "Merged")
    assert(#deleted == 0)
end)
test("stale preview never deletes", function()
    local groups = TM:Group(TM:Read(71))
    builds[2].key = "CHANGED"
    TM:Clean(groups)
    assert(#deleted == 0)
end)
test("combat and staged talents block mutations", function()
    local groups = TM:Group(TM:Read(71))
    combat = true; TM:Clean(groups); combat = false
    staged = true; TM:Merge(groups[1], "Merged")
    assert(#deleted == 0 and not next(renamed))
end)
test("dead player gets an explicit reason and no mutation", function()
    UnitIsDeadOrGhost = function() return true end
    local ok, reason = TM:Merge(TM:Group(TM:Read(71))[1], "Merged")
    assert(ok == false and reason:find("Resucita") and #deleted == 0 and not next(renamed))
    UnitIsDeadOrGhost = nil
end)
test("nuke requires exact token and a readable backup", function()
    local rows = TM:AllRows()
    TM:Nuke(rows, "nuke"); assert(#deleted == 0)
    TM:Nuke(rows, "NUKE"); assert(#deleted == 0)
    builds[6].key = "EEE"
    TM:Nuke(TM:AllRows(), "NUKE")
    assert(#deleted == 7 and builds[7])
end)
test("nuke rejects builds added after preview", function()
    builds[6].key = "EEE"
    local rows = TM:AllRows()
    builds[9] = { name = "New", key = "FFF" }; ids[72][2] = 9
    TM:Nuke(rows, "NUKE"); assert(#deleted == 0)
end)
test("Nuke can delete only one specialization and backs up only that scope", function()
    local selected = TM:Read(72)
    assert(TM:Nuke(selected, "NUKE", { [72] = true }) == true)
    assert(#deleted == 1 and deleted[1] == 8 and builds[1] and builds[2] and builds[6])
    assert(#LawkhsTalentMergerDB.backups[1].builds == 1)
    assert(LawkhsTalentMergerDB.backups[1].builds[1].spec == 72)
end)
test("unselected specialization changes do not block selected-spec deletion", function()
    local selected = TM:Read(72)
    builds[9] = { name = "New other spec", key = "FFF" }; ids[71][#ids[71] + 1] = 9
    assert(TM:Nuke(selected, "NUKE", { [72] = true }) == true)
    assert(builds[9] and #deleted == 1 and deleted[1] == 8)
end)
test("selected specialization additions and mismatched scope are rejected", function()
    local selected = TM:Read(72)
    assert(TM:Nuke(selected, "NUKE", { [71] = true }) == false)
    builds[9] = { name = "New selected spec", key = "FFF" }; ids[72][2] = 9
    assert(TM:Nuke(selected, "NUKE", { [72] = true }) == false)
    assert(#deleted == 0)
end)
test("an empty Nuke selection cannot start deleting anything", function()
    local ok, reason = TM:Nuke({}, "NUKE", {})
    assert(ok == false and reason == TM:T("NUKE_NO_SELECTION") and #deleted == 0)
end)
test("persistent deletion refusal stops the queue and reports remaining builds", function()
    failedID = 2
    TM:Clean(TM:Group(TM:Read(71)))
    assert(#deleted == 0 and builds[2] and builds[5])
    assert(messages[1]:find("Mythic"))
end)
local function asyncDeletes(fn)
    local oldTimer, oldDelete = C_Timer, C_ClassTalents.DeleteConfig
    local timers, requests = {}, {}
    C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback } end }
    C_ClassTalents.DeleteConfig = function(id) requests[#requests + 1] = id; return true end
    local function tick(delay)
        for i, timer in ipairs(timers) do
            if timer[1] == delay then table.remove(timers, i); timer[2](); return end
        end
        error("No timer for " .. delay)
    end
    local function confirm(id) oldDelete(id); TM:ConfirmDeletion(id) end
    fn(requests, tick, confirm)
    C_Timer, C_ClassTalents.DeleteConfig = oldTimer, oldDelete
end
test("Nuke waits for each server deletion before requesting the next", function()
    builds[6].key = "EEE"
    asyncDeletes(function(requests, tick, confirm)
        local rows = TM:AllRows()
        assert(TM:Nuke(rows, "NUKE") == "pending" and #requests == 1 and TM.operation.deleted == 0)
        assert(TM:Nuke(TM:AllRows(), "NUKE") == false and #requests == 1)
        TM:ConfirmDeletion(999); assert(TM.operation.deleted == 0)
        for i, row in ipairs(rows) do
            assert(#requests == i and requests[i] == row.id)
            confirm(row.id)
            TM:ConfirmDeletion(row.id) -- duplicate event must not double-count
            assert(TM.operation.deleted == i)
            tick(0.2)
        end
        assert(not TM.operation and #deleted == #rows and builds[7])
    end)
end)
test("accepted request timeout stops instead of counting an unconfirmed deletion", function()
    asyncDeletes(function(requests, tick)
        TM:Clean(TM:Group(TM:Read(71)))
        tick(5)
        assert(not TM.operation and #requests == 1 and #deleted == 0)
        assert(messages[1]:find("no confirmó") and messages[1]:find("Pendientes: 2"))
    end)
end)
test("combat between confirmations prevents further deletion requests", function()
    asyncDeletes(function(requests, tick, confirm)
        TM:Clean(TM:Group(TM:Read(71)))
        confirm(2); combat = true; tick(0.2)
        assert(not TM.operation and #requests == 1 and builds[5])
    end)
end)
test("changed queued build is checked before the next deletion", function()
    asyncDeletes(function(requests, tick, confirm)
        TM:Clean(TM:Group(TM:Read(71)))
        confirm(2); builds[5].key = "CHANGED"; tick(0.2)
        assert(not TM.operation and #requests == 1 and builds[5])
    end)
end)
test("cancellation waits for the outstanding request and sends no more", function()
    asyncDeletes(function(requests, tick, confirm)
        TM:Clean(TM:Group(TM:Read(71)))
        TM.operation.cancelled = true
        confirm(2); tick(0.2)
        assert(not TM.operation and #requests == 1 and builds[5])
        assert(messages[1]:find("detenido") and messages[1]:find("Borradas: 1"))
    end)
end)
test("temporary busy responses retry the same row without skipping ahead", function()
    local oldDelete, attempts = C_ClassTalents.DeleteConfig, 0
    C_ClassTalents.DeleteConfig = function(id)
        attempts = attempts + 1
        if attempts <= 2 then assert(id == 2); return false end
        return oldDelete(id)
    end
    TM:Clean(TM:Group(TM:Read(71)))
    assert(not TM.operation and #deleted == 2 and attempts == 4)
    C_ClassTalents.DeleteConfig = oldDelete
end)
test("retail guard prevents mutation on Classic", function()
    local groups = TM:Group(TM:Read(71))
    WOW_PROJECT_ID = 2
    assert(#TM:Read(71) == 0)
    TM:Clean(groups)
    assert(#deleted == 0)
    WOW_PROJECT_ID = 1
end)
test("missing retail API is rejected", function()
    local api = C_Traits.GenerateImportString
    C_Traits.GenerateImportString = nil
    assert(not TM:Supported() and #TM:Read(71) == 0)
    C_Traits.GenerateImportString = api
end)
test("uses Blizzard current-spec helper when available", function()
    PlayerUtil = { GetCurrentSpecID = function() return 72 end }
    assert(TM:SpecID() == 72 and #TM:Read(TM:SpecID()) == 1)
    PlayerUtil = nil
end)
test("read diagnostics distinguish empty lists from unavailable configs", function()
    TM:Read(71)
    assert(TM.readDiagnostics[71].raw == 7 and TM.readDiagnostics[71].active == 1)
    assert(TM.readDiagnostics[71].unreadable == 1 and TM.readDiagnostics[71].missing == 0)
    builds[2] = nil
    TM:Read(71)
    assert(TM.readDiagnostics[71].missing == 1)
end)
test("current specialization uses the same default query verified in game", function()
    local api = C_ClassTalents.GetConfigIDsBySpecID
    C_ClassTalents.GetConfigIDsBySpecID = function(spec)
        if spec == 71 then return {} end
        return api(spec)
    end
    assert(#TM:Read(71) == 6 and #TM:Read(72) == 1)
    C_ClassTalents.GetConfigIDsBySpecID = api
end)
test("empty C export falls back to Blizzard serializer for the saved config", function()
    builds[6].treeIDs = { 100 }
    local savedHash, savedVersion = C_Traits.GetTreeHash, C_Traits.GetLoadoutSerializationVersion
    C_Traits.GetTreeHash = function() return { 1, 2 } end
    C_Traits.GetLoadoutSerializationVersion = function() return 2 end
    ExportUtil = { MakeExportDataStream = function()
        return { GetExportString = function(stream) return stream.header .. stream.body end }
    end }
    PlayerSpellsFrame = { TalentsFrame = {
        GetSpecID = function() return 71 end,
        IsInspecting = function() return false end,
        WriteLoadoutHeader = function(_, stream, version, spec) stream.header = version .. ":" .. spec .. ":" end,
        WriteLoadoutContent = function(_, stream, config, tree)
            assert(config == 6 and tree == 100); stream.body = "SAVED_CHOICES"
        end,
    } }
    assert(TM:Export(6, 71, builds[6]) == "2:71:SAVED_CHOICES")
    assert(not TM:Export(6, 72, builds[6]))
    PlayerSpellsFrame, ExportUtil = nil, nil
    C_Traits.GetTreeHash, C_Traits.GetLoadoutSerializationVersion = savedHash, savedVersion
end)
local function withNodes(fn)
    local savedNodes, savedInfo = C_Traits.GetTreeNodes, C_Traits.GetNodeInfo
    builds[1].treeIDs, builds[2].treeIDs = { 100 }, { 100 }
    builds[1].nodes = {
        [10] = { currentRank = 1, ranksPurchased = 1, activeEntry = { entryID = 101, rank = 1 } },
        [20] = { currentRank = 1, ranksPurchased = 1, activeEntry = { entryID = 201, rank = 1 }, subTreeActive = true },
        [30] = { currentRank = 1, ranksPurchased = 1, activeEntry = { entryID = 301, rank = 1 }, subTreeActive = false },
    }
    builds[2].nodes = {
        [10] = { currentRank = 1, ranksPurchased = 1, activeEntry = { entryID = 101, rank = 1 } },
        [20] = { currentRank = 1, ranksPurchased = 1, activeEntry = { entryID = 201, rank = 1 }, subTreeActive = true },
        [30] = { currentRank = 2, ranksPurchased = 2, activeEntry = { entryID = 302, rank = 2 }, subTreeActive = false },
    }
    C_Traits.GetTreeNodes = function() return { 30, 10, 20 } end
    C_Traits.GetNodeInfo = function(id, node) return builds[id].nodes[node] end
    fn()
    C_Traits.GetTreeNodes, C_Traits.GetNodeInfo = savedNodes, savedInfo
end
test("same chosen talents group despite differing exports and inactive hero choices", function()
    withNodes(function()
        builds[2].key = "DIFFERENT_SERIALIZATION"
        local rows = TM:Read(71)
        assert(rows[1].key == rows[2].key and rows[1].export ~= rows[2].export)
        local groups = TM:Group(rows)
        assert(#groups == 2 and #groups[1].rows == 2)
        TM:Clean(groups)
        assert(deleted[1] == 2)
        assert(LawkhsTalentMergerDB.backups[1].builds[2].export == "DIFFERENT_SERIALIZATION")
    end)
end)
test("different chosen entry is not a duplicate", function()
    withNodes(function()
        builds[2].nodes[10].activeEntry.entryID = 102
        local rows = TM:Read(71)
        assert(rows[1].key ~= rows[2].key)
    end)
end)
test("different rank or active hero selection is not a duplicate", function()
    withNodes(function()
        builds[2].nodes[10].ranksPurchased = 2
        local rows = TM:Read(71); assert(rows[1].key ~= rows[2].key)
        builds[2].nodes[10].ranksPurchased = 1
        builds[2].nodes[20].activeEntry.entryID = 202
        rows = TM:Read(71); assert(rows[1].key ~= rows[2].key)
    end)
end)
test("partial node data cannot produce an incomplete comparison signature", function()
    withNodes(function()
        builds[2].nodes[20] = nil
        assert(not TM:Fingerprint(2, 71, builds[2]))
        local rows = TM:Read(71)
        assert(rows[1].key ~= rows[2].key and rows[2].key == "export:AAA")
    end)
end)
assert(loadfile("LawkhsTalentMerger/Restore.lua"))("LawkhsTalentMerger", TM)
local imported = 0
local realImport = TM.ImportBackup
TM.ImportBackup = function(_, build)
    imported = imported + 1
    local id = 100 + imported
    builds[id] = {name = build.name, key = build.export}
    ids[build.spec][#ids[build.spec] + 1] = id
    return true
end

test("Undo Clean restores only missing copies and is idempotent", function()
    TM:Clean(TM:Group(TM:Read(71)))
    local backup = LawkhsTalentMergerDB.backups[1]
    assert(backup.builds[2].removed and #TM:RestorePlan(backup, 71) == 2)
    local before = imported
    local ok = TM:Restore(backup, 71)
    assert(ok and imported == before + 2 and #TM:RestorePlan(backup, 71) == 0)
    assert(TM:Restore(backup, 71) == false and imported == before + 2)
end)

test("Undo Merge restores survivor name and deleted duplicate", function()
    TM:Merge(TM:Group(TM:Read(71))[1], "Merged")
    local backup = LawkhsTalentMergerDB.backups[1]
    assert(backup.builds[1].renamedTo == "Merged")
    assert(TM:Restore(backup, 71))
    assert(builds[1].name == "Raid" and #TM:RestorePlan(backup, 71) == 0)
end)

test("Undo uses multiset matching for identical names and legacy backups", function()
    local backup = {builds = {{name="Raid", spec=71, export="AAA"}, {name="Raid", spec=71, export="AAA"}}}
    assert(#TM:RestorePlan(backup, 71) == 1)
    assert(TM:Restore(backup, 71))
    assert(#TM:RestorePlan(backup, 71) == 0)
end)

test("Undo blocks wrong spec, combat and dead player", function()
    local backup = {builds = {{name="Old", spec=72, export="OLD"}}}
    local before = imported
    assert(TM:Restore(backup, 72) == false)
    backup.builds[1].spec = 71
    combat = true; assert(TM:Restore(backup, 71) == false); combat = false
    UnitIsDeadOrGhost = function() return true end
    assert(TM:Restore(backup, 71) == false and imported == before)
    UnitIsDeadOrGhost = nil
end)

test("Undo partial Clean restores confirmed deletions but keeps untouched copies", function()
    failedID = 5
    TM:Clean(TM:Group(TM:Read(71)))
    local backup = LawkhsTalentMergerDB.backups[1]
    assert(#TM:RestorePlan(backup, 71) == 1 and builds[5])
    assert(TM:Restore(backup, 71) and #TM:RestorePlan(backup, 71) == 0)
end)

test("Undo preserves edited Merge survivor and does not rename it", function()
    TM:Merge(TM:Group(TM:Read(71))[1], "Merged")
    local backup = LawkhsTalentMergerDB.backups[1]
    builds[1].key = "EDITED"
    assert(#TM:RestorePlan(backup, 71) == 1)
    assert(TM:Restore(backup, 71) and builds[1].name == "Merged" and builds[1].key == "EDITED")
end)

test("Undo import refusal stops and keeps backup retryable", function()
    local fn = TM.ImportBackup
    TM.ImportBackup = function() return false, "Loadout cap" end
    local backup = {builds = {{name="Old", spec=71, export="OLD"}}}
    local ok, reason = TM:Restore(backup, 71)
    assert(not ok and reason:find("Loadout cap",1,true) and not TM.operation)
    assert(#TM:RestorePlan(backup, 71) == 1)
    TM.ImportBackup = fn
end)

test("Undo waits for matching server config, unrelated events do not complete", function()
    local fn, timer = TM.ImportBackup, C_Timer.After
    local callbacks = {}
    C_Timer.After = function(_, callback) callbacks[#callbacks+1] = callback end
    TM.ImportBackup = function() return true end
    local backup = {builds = {{name="Old", spec=71, export="OLD"}, {name="Next", spec=71, export="NEXT"}}}
    assert(TM:Restore(backup, 71) == "pending")
    builds[90] = {name="Unrelated", key="OTHER"}; ids[71][#ids[71]+1] = 90
    TM:ConfirmRestore(); assert(TM.operation.deleted == 0)
    builds[91] = {name="Old", key="OLD"}; ids[71][#ids[71]+1] = 91
    TM:ConfirmRestore(); assert(TM.operation.deleted == 1)
    TM.operation.cancelled = true
    callbacks[#callbacks]()
    assert(not TM.operation and #TM:RestorePlan(backup,71) == 1)
    TM.ImportBackup, C_Timer.After = fn, timer
end)

test("Blizzard import decoder checks version, spec and hash without switching builds", function()
    local oldFrame, oldExport, importFn = PlayerSpellsFrame, ExportUtil, C_ClassTalents.ImportLoadout
    local version, spec, empty, same, calls = 1, 71, false, true, 0
    ExportUtil = {MakeImportDataStream=function() return {} end}
    PlayerSpellsFrame = {TalentsFrame = {
        IsInspecting=function() return false end, GetSpecID=function() return 71 end,
        ReadLoadoutHeader=function() return true,version,spec,{} end,
        GetTreeInfo=function() return {ID=1} end, IsHashEmpty=function() return empty end,
        HashEquals=function() return same end, ReadLoadoutContent=function() return {} end,
        ConvertToImportLoadoutEntryInfo=function() return {1} end,
    }}
    C_Traits.GetLoadoutSerializationVersion=function() return 1 end
    C_Traits.GetTreeHash=function() return {} end
    C_ClassTalents.ImportLoadout=function(id, entries, name, export)
        assert(id==7 and entries[1]==1 and name=="Old" and export=="OLD"); calls=calls+1; return true
    end
    local build={name="Old",spec=71,export="OLD"}
    assert(realImport(TM,build) and calls==1)
    version=2; assert(not realImport(TM,build)); version=1
    spec=72; assert(not realImport(TM,build)); spec=71
    same=false; assert(not realImport(TM,build) and calls==1)
    PlayerSpellsFrame, ExportUtil, C_ClassTalents.ImportLoadout=oldFrame,oldExport,importFn
end)
test("old restore timeout cannot abort the next import", function()
    local fn,timer=TM.ImportBackup,C_Timer.After
    local callbacks={}
    C_Timer.After=function(delay,callback) callbacks[#callbacks+1]={delay=delay,fn=callback} end
    TM.ImportBackup=function(_,build)
        if build.name=="First" then builds[91]={name="First",key="FIRST"};ids[71][#ids[71]+1]=91 end
        return true
    end
    local backup={builds={{name="First",spec=71,export="FIRST"},{name="Second",spec=71,export="SECOND"}}}
    assert(TM:Restore(backup,71)=="pending" and TM.operation.index==2)
    callbacks[1].fn()
    assert(TM.operation.awaiting and TM.operation.index==2)
    callbacks[2].fn()
    assert(TM.operation and TM.operation.index==2)
    callbacks[3].fn()
    assert(not TM.operation and #TM:RestorePlan(backup,71)==1)
    TM.ImportBackup,C_Timer.After=fn,timer
end)
test("numeric Nuke confirmation is accepted with identical scope guards", function()
    assert(TM:IsNukeToken("123123") and TM:IsNukeToken("NUKE"))
    assert(not TM:IsNukeToken("12312") and not TM:IsNukeToken("nuke") and not TM:IsNukeToken(" NUKE"))
    assert(TM:Nuke(TM:Read(72),"123123",{[72]=true}))
    assert(#deleted==1 and deleted[1]==8 and builds[1])
end)

test("batch Merge renames each group and preserves unrelated specs", function()
    builds[9]={name="Other copy",key="DDD"};ids[72][#ids[72]+1]=9
    local a=TM:Group(TM:Read(71));local b=TM:Group(TM:Read(72))
    local groups={a[1],b[1]}
    assert(TM:MergeMany(groups,{"Raid merged","Fury merged"}))
    assert(builds[1].name=="Raid merged" and builds[8].name=="Fury merged")
    assert(not builds[2] and not builds[9] and builds[4] and builds[5])
    local backup=LawkhsTalentMergerDB.backups[1]
    assert(#backup.builds==4 and backup.builds[1].renamedTo=="Raid merged" and backup.builds[3].renamedTo=="Fury merged")
end)

test("batch Merge validates every name and snapshot before any mutation", function()
    local groups=TM:Group(TM:Read(71))
    assert(TM:MergeMany(groups,{"Good","  "})==false and not next(renamed) and #deleted==0)
    builds[5].name="Changed"
    assert(TM:MergeMany(groups,{"Good","Good too"})==false and not next(renamed) and #deleted==0)
end)
test("completed restore removes its spec from Undo and drops empty operations", function()
    local backup={time=123,action="Nuke",builds={{name="Old Arms",spec=71,export="OLD"},{name="Old Fury",spec=72,export="FURY"}}}
    LawkhsTalentMergerDB={backups={backup}}
    assert(TM:Restore(backup,71))
    assert(#backup.builds==1 and backup.builds[1].spec==72 and #LawkhsTalentMergerDB.backups==1)
    TM:RemoveUndoSpec(backup,72)
    assert(#LawkhsTalentMergerDB.backups==0)
end)

test("failed restore retains the missing work in Undo", function()
    local fn=TM.ImportBackup
    TM.ImportBackup=function(_,build)
        if build.name=="Second" then return false,"Rejected" end
        return fn(TM,build)
    end
    local backup={time=123,action="Nuke",builds={{name="First",spec=71,export="FIRST"},{name="Second",spec=71,export="SECOND"}}}
    LawkhsTalentMergerDB={backups={backup}}
    assert(TM:Restore(backup,71)==false)
    assert(#LawkhsTalentMergerDB.backups==1)
    local pending=TM:RestorePlan(backup,71)
    assert(#pending==1 and pending[1].build.name=="Second")
    TM:PruneUndoHistory(TM:Specializations())
    assert(#LawkhsTalentMergerDB.backups==1)
    TM.ImportBackup=fn
end)

test("Undo cleans older restored entries but keeps pending specs", function()
    local complete={time=123,action="Clean",builds={{name="Raid",spec=71,export="AAA"}}}
    local mixed={time=123,action="Nuke",builds={{name="Raid",spec=71,export="AAA"},{name="Missing Fury",spec=72,export="MISSING"}}}
    LawkhsTalentMergerDB={backups={complete,mixed}}
    combat=true;TM:PruneUndoHistory({{id=71},{id=72}})
    assert(#LawkhsTalentMergerDB.backups==2);combat=false
    TM:PruneUndoHistory(TM:Specializations())
    assert(#LawkhsTalentMergerDB.backups==1 and LawkhsTalentMergerDB.backups[1]==mixed)
    assert(#mixed.builds==1 and mixed.builds[1].spec==72)
end)
test("node lists are shared within a read but validation remains fresh", function()
    withNodes(function()
        local api=C_Traits.GetTreeNodes
        local calls=0
        C_Traits.GetTreeNodes=function(tree) calls=calls+1;return api(tree) end
        local rows=TM:Read(71)
        assert(calls==1)
        builds[2].nodes[10].activeEntry.entryID=999
        assert(TM:Validate({rows[2]})==false and calls==2)
    end)
end)

test("Undo stays bounded and does not store node signatures", function()
    for i=1,20 do assert(TM:Backup(TM:Read(72),"Nuke")) end
    assert(#LawkhsTalentMergerDB.backups==10)
    assert(not LawkhsTalentMergerDB.backups[1].builds[1].key)
end)
print(passed .. " tests passed")
