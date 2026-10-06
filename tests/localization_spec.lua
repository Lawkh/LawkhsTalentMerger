local selectedLocale = "enUS"
function GetLocale() return selectedLocale end
local function loadLocale(locale)
    selectedLocale = locale
    local context = {}
    assert(loadfile("LawkhsTalentMerger/Localization.lua"))("LawkhsTalentMerger", context)
    return context
end
local base = loadLocale("enUS").L
local codes = { "enUS", "enGB", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW", "ptPT" }
local checked = 0
for _, locale in ipairs(codes) do
    local context = loadLocale(locale)
    assert(context.locale == locale and context.L == context.Locales[locale])
    local count = 0
    for key, english in pairs(base) do
        local value = context.L[key]
        assert(type(value) == "string" and value:match("%S"), locale .. ": missing " .. key)
        local expected, actual, args = {}, {}, {}
        for format in english:gmatch("%%([ds])") do
            expected[#expected + 1] = format
            args[#args + 1] = format == "d" and 3 or "PlayerName"
        end
        for format in value:gmatch("%%([ds])") do actual[#actual + 1] = format end
        assert(table.concat(expected) == table.concat(actual), locale .. ": format mismatch for " .. key)
        local formatted = context:T(key, table.unpack(args))
        assert(type(formatted) == "string", locale .. ": failed formatting " .. key)
        count = count + 1
    end
    assert(count == 87)
    assert(context:T("NUKE_REQUIRED"):find("NUKE", 1, true))
    assert(context:T("NUKE_PROMPT"):find("NUKE", 1, true))
    checked = checked + count
    print("PASS " .. locale .. ": " .. count .. " translations and format arguments")
end
local unknown = loadLocale("unsupported")
assert(unknown.L == unknown.Locales.enUS and unknown:T("CONFIRM") == "Confirm")
unknown.L = {}
assert(unknown:T("DELETED", 2) == "Deleted: 2.")
print("PASS unknown locale and missing translation fall back to English")
print(checked .. " localized strings checked")
