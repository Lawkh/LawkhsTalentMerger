local TM = {}
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
end
function InCombatLockdown() return combat end
function UnitClass() return "Warrior", "WARRIOR", 1 end
C_SpecializationInfo = {
    GetSpecialization = function() return 1 end,
    GetSpecializationInfo = function(i) return i == 1 and 71 or 72 end,
    GetNumSpecializationsForClassID = function() return 2 end,
}
function time() return 123 end
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
test("partial deletion failures are reported", function()
    failedID = 2
    TM:Clean(TM:Group(TM:Read(71)))
    assert(#deleted == 1 and deleted[1] == 5 and builds[2])
    assert(messages[1]:find("Mythic"))
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
print(passed .. " tests passed")
