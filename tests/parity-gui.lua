-- Execute after loading Gui in a real Studio script. No widgets are required.
local HttpService = game:GetService("HttpService")
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local function copy(value)
    return HttpService:JSONDecode(HttpService:JSONEncode(value))
end
local function samePalette(expected)
    local actual = Gui.exportTheme()
    for key, channels in pairs(expected) do
        for i = 1, 3 do
            if actual[key][i] ~= channels[i] then return false end
        end
    end
    return true
end

local original = Gui.exportTheme()
local identity = Gui.colors
local names = Gui.themeNames()
check(#names == 2 and names[1] == "Default" and names[2] == "Midnight", "Built-in theme names are sorted")
names[1] = "Changed externally"
check(Gui.themeNames()[1] == "Default", "Theme-name results do not mutate built-in names")

local custom = copy(original)
custom.background = { 1, 2, 3 }
custom.text = { 240, 241, 242 }
local accepted, reason = Gui.importTheme(custom)
check(accepted and reason == nil, "A complete JSON RGB theme imports")
check(Gui.colors == identity and samePalette(custom), "Import preserves shared palette identity and all RGB values")
custom.background[1] = 99
check(Gui.exportTheme().background[1] == 1, "Imported RGB arrays are detached from caller data")
local detached = Gui.exportTheme()
detached.text[1] = 0
check(Gui.exportTheme().text[1] == 240, "Exported RGB arrays are detached from active state")

local beforeInvalid = Gui.exportTheme()
local invalid = copy(beforeInvalid)
invalid.background = { 20, 30, 40 }
invalid.title = { 300, 10, 10 }
accepted, reason = Gui.importTheme(invalid)
check(not accepted and type(reason) == "string" and reason ~= "", "Out-of-range colors return a useful error")
check(Gui.colors == identity and samePalette(beforeInvalid), "A later invalid color cannot partially apply earlier colors")

for _, malformed in ipairs({
    { label = "missing color", modify = function(data) data.text = nil end },
    { label = "extra color", modify = function(data) data.unknown = { 1, 2, 3 } end },
    { label = "sparse RGB", modify = function(data) data.text = { [1] = 1, [3] = 3 } end },
    { label = "extra channel", modify = function(data) data.text = { 1, 2, 3, 4 } end },
    { label = "named channel", modify = function(data) data.text = { 1, 2, 3, R = 1 } end },
    { label = "string channel", modify = function(data) data.text = { "1", 2, 3 } end },
    { label = "fractional channel", modify = function(data) data.text = { 1.5, 2, 3 } end },
    { label = "nonfinite channel", modify = function(data) data.text = { math.huge, 2, 3 } end },
    { label = "NaN channel", modify = function(data) data.text = { 0 / 0, 2, 3 } end },
}) do
    local data = copy(beforeInvalid)
    malformed.modify(data)
    check(not Gui.importTheme(data) and samePalette(beforeInvalid), malformed.label .. " rejects without a palette mutation")
end
check(not Gui.importTheme("{}") and samePalette(beforeInvalid), "Non-map themes reject without mutation")

Gui.theme("Midnight")
check(Gui.colors == identity and Gui.exportTheme().background[1] == 18, "Built-in switching preserves shared palette identity")
check(Gui.importTheme(original) and samePalette(original), "The original palette restores after custom or built-in themes")
print("KEYNOVA_GUI_PARITY_PASS " .. checks .. " checks")
