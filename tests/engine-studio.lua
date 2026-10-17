-- Executes against real Roblox value types and TweenService. The package/test
-- runner supplies the local Engine module before this file.
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end
local function near(actual, expected, message)
    check(math.abs(actual - expected) < 0.00001, message .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function refs(track, ...)
    local result = {}
    for _, key in ipairs({...}) do table.insert(result, {trackId = track.id, keyId = key.id}) end
    return result
end
local function fixture()
    local project = Engine.newProject("Engine fixture")
    table.insert(project.items, {id = "item", name = "Fixture", type = "Part", path = {{name="Workspace",class="Workspace",index=1},{name="Fixture",class="Model",index=1}}})
    local track = Engine.newTrack("item", "Transparency", "Transparency", "number")
    table.insert(project.tracks, track)
    return project, track
end

local project, track = fixture()
check(project.format == "keynova" and project.version == 2 and project.duration == 300 and project.fps == 60 and not project.loop, "Project defaults")
check(Engine.sample(track, 0) == nil, "An empty track has no sample")
local left = Engine.insert(track, 10, 0)
local right = Engine.insert(track, 30, 1)
local originalId = left.id
Engine.insert(track, 10, 0, "Linear", "InOut")
check(left.id == originalId and #track.keys == 2, "Replacing a key keeps its identity")
near(Engine.sample(track, 20), 0.5, "Numeric interpolation")
near(Engine.sample(track, -1), 0, "Hold before the first key")
near(Engine.sample(track, 300), 1, "Hold after the last key")
left.easing = "Constant"
near(Engine.sample(track, 29.9), 0, "Constant easing holds until the next key")
near(Engine.sample(track, 30), 1, "Constant easing reaches the next key")
left.easing = "Linear"

local service = game:GetService("TweenService")
local names = {Expo = "Exponential", Circ = "Circular"}
for _, style in ipairs(Engine.easingStyles) do
    for _, direction in ipairs(Engine.directions) do
        for _, alpha in ipairs({0, 0.13, 0.37, 0.5, 0.73, 1}) do
            local eased = Engine.ease(alpha, style, direction)
            check(eased == eased and eased > -math.huge and eased < math.huge, "Easing is finite: " .. style .. " " .. direction)
            if style ~= "Constant" and style ~= "Sextic" and direction ~= "OutIn" then
                near(eased, service:GetValue(alpha, Enum.EasingStyle[names[style] or style], Enum.EasingDirection[direction]), "Native easing matches TweenService")
            end
        end
    end
end
near(Engine.ease(0.5, "Sextic", "In"), 1 / 64, "Sixth power incoming")
near(Engine.ease(0.25, "Quad", "OutIn"), 0.375, "OutIn outgoing half")
near(Engine.ease(0.75, "Quad", "OutIn"), 0.625, "OutIn incoming half")

local valueCases = {
    {"CFrame", CFrame.new(1, 2, 3) * CFrame.Angles(0.1, 0.2, 0.3), CFrame.new(3, 4, 5) * CFrame.Angles(0.3, 0.4, 0.5)},
    {"Vector3", Vector3.new(1, 2, 3), Vector3.new(3, 4, 5)},
    {"Color3", Color3.new(0.1, 0.2, 0.3), Color3.new(0.3, 0.4, 0.5)},
    {"boolean", false, true}, {"string", "first", "second"},
}
for _, example in ipairs(valueCases) do
    local valueType, from, to = example[1], example[2], example[3]
    local valueTrack = Engine.newTrack("item", valueType, "Value", valueType)
    Engine.insert(valueTrack, 0, from)
    Engine.insert(valueTrack, 10, to)
    local encoded = Engine.encode(from, valueType)
    local decoded = Engine.decode(encoded, valueType)
    check(typeof(decoded) == valueType, "Decoded native type: " .. valueType)
    local sampled = Engine.sample(valueTrack, 5)
    if valueType == "boolean" or valueType == "string" then
        check(sampled == from and Engine.sample(valueTrack, 10) == to, "Discrete values hold and switch on their exact key")
    elseif valueType == "CFrame" then
        local expected = from:Lerp(to, 0.5)
        near((sampled.Position - expected.Position).Magnitude, 0, "CFrame position interpolates")
        near(sampled.LookVector:Dot(expected.LookVector), 1, "CFrame rotation interpolates")
    elseif valueType == "Vector3" then
        near((sampled - from:Lerp(to, 0.5)).Magnitude, 0, "Vector3 interpolation")
    else
        near(sampled.R, 0.2, "Color3 interpolation")
    end
end

local selected = refs(track, left, right)
local moved, problem = Engine.retime(project, selected, -100)
check(not problem and #moved == 2 and left.frame == 0 and right.frame == 20, "Retime clamps all keys together at zero")
moved, problem = Engine.retime(project, selected, 1000)
check(not problem and left.frame == 280 and right.frame == 300, "Retime clamps all keys together at the duration")
Engine.retime(project, selected, -270)
local blocker = Engine.insert(track, 40, 0.7)
local before = game:GetService("HttpService"):JSONEncode(project)
moved, problem = Engine.retime(project, selected, 10)
check(problem and game:GetService("HttpService"):JSONEncode(project) == before, "Collision leaves the whole edit unchanged")
right.locked = true
Engine.retime(project, selected, 5)
check(left.frame == 15 and right.frame == 30, "Locked keys stay at their existing time")
right.locked = nil
track.locked = true
moved, problem = Engine.retime(project, selected, 1)
check(problem and left.frame == 15, "Locked tracks reject time edits")
track.locked = false

local stretched, stretchError = Engine.stretch(project, refs(track, left), 2)
check(not stretchError and #stretched == 1 and left.frame == 15, "One-key stretch does not divide by zero or move its default pivot")
stretched, stretchError = Engine.stretch(project, selected, 0)
check(stretchError and left.frame == 15 and right.frame == 30, "Zero factor is rejected atomically")
Engine.stretch(project, selected, 0.5)
check(left.frame == 15 and right.frame == 23, "Stretch rounds shared pivot offsets")
local snapshot = Engine.clone(project)
snapshot.tracks[1].keys[1].value = 99
check(track.keys[1].value ~= 99, "Project clone owns its key values")

local copyProject, copyTrack = fixture()
local a = Engine.insert(copyTrack, 10, 0)
local b = Engine.insert(copyTrack, 20, 1)
a.group, b.group = "group-source", "group-source"
local copied = Engine.copy(copyProject, refs(copyTrack, b, a))
check(copied.span == 10 and copied.tracks[1].keys[1].frame == 0 and copied.tracks[1].keys[2].frame == 10, "Clipboard sorts and normalizes times")
local pasted, pasteError = Engine.paste(copyProject, copied, 40)
check(not pasteError and #pasted == 2 and #copyTrack.keys == 4, "Paste creates both keys")
check(copyTrack.keys[3].id ~= a.id and copyTrack.keys[3].group == copyTrack.keys[4].group and copyTrack.keys[3].group ~= a.group, "Paste allocates IDs and an independent group")
local countBefore = #copyTrack.keys
pasted, pasteError = Engine.paste(copyProject, copied, 40)
check(pasteError and #pasted == 0 and #copyTrack.keys == countBefore, "Paste collisions preserve every existing key")
local dest = Engine.newTrack("item", "Other number", "Reflectance", "number")
table.insert(copyProject.tracks, dest)
pasted, pasteError = Engine.paste(copyProject, copied, 0, dest.id)
check(not pasteError and #pasted == 2 and #dest.keys == 2, "Explicit paste redirects compatible tracks")
local repeats, repeatError = Engine.repeatKeys(copyProject, refs(copyTrack, a, b), 2, 60)
check(not repeatError and #repeats == 4 and #copyTrack.keys == 8, "Repeat duplicates the selected range with a shared spacing")
countBefore = #copyTrack.keys
repeats, repeatError = Engine.repeatKeys(copyProject, refs(copyTrack, a, b), 2, 5)
check(repeatError and #copyTrack.keys == countBefore, "Repeat checks all destinations before adding any keys")

local filledProject, filledTrack = fixture()
local fillA = Engine.insert(filledTrack, 0, 0, "Quad", "In")
local fillB = Engine.insert(filledTrack, 20, 1)
local expectedSamples = {}
for frame = 5, 15, 5 do expectedSamples[frame] = Engine.sample(filledTrack, frame) end
local filled, fillError = Engine.fill(filledProject, refs(filledTrack, fillA, fillB), 5)
check(not fillError and #filled == 3 and #filledTrack.keys == 5, "Fill inserts all missing samples")
for _, key in ipairs(filledTrack.keys) do
    if expectedSamples[key.frame] then near(key.value, expectedSamples[key.frame], "Fill sampled the original curve before mutation") end
end
filled, fillError = Engine.fill(filledProject, refs(filledTrack, fillA), 1)
check(fillError and #filledTrack.keys == 5, "One-key fill safely has no range")

-- Import boundary regressions: sorting is normalized only after every track and
-- marker passes, while malformed values, duplicate identities and times fail.
local imported = Engine.clone(copyProject)
local reversed = {}
for index = #imported.tracks[1].keys, 1, -1 do table.insert(reversed, imported.tracks[1].keys[index]) end
imported.tracks[1].keys = reversed
local valid, validationError = Engine.validate(imported)
check(valid and validationError == nil and imported.tracks[1].keys[1].frame == 10, "Valid imported keys are sorted")
local transformTrack = Engine.newTrack("item", "Camera", "CFrame", "CFrame")
table.insert(imported.tracks, transformTrack)
Engine.insert(transformTrack, 0, valueCases[1][2])
Engine.insert(transformTrack, 20, valueCases[1][3])
local serializer = game:GetService("HttpService")
local roundTrip = serializer:JSONDecode(serializer:JSONEncode(imported))
valid, validationError = Engine.validate(roundTrip)
check(valid and validationError == nil, "Encoded project passes a real JSON round trip")
near((Engine.sample(roundTrip.tracks[3], 10).Position - Engine.sample(transformTrack, 10).Position).Magnitude, 0, "JSON round trip preserves decoded CFrame samples")
for _, corrupt in ipairs({
    function(p) p.tracks[1].keys[2].frame = p.tracks[1].keys[1].frame end,
    function(p) p.tracks[1].keys[2].id = p.tracks[1].keys[1].id end,
    function(p) p.tracks[1].itemId = "missing-item" end,
    function(p) p.tracks[1].keys[1].value = 0 / 0 end,
    function(p) p.tracks[1].keys[1].easing = "MadeUp" end,
    function(p) p.tracks[1].keys[1].frame = p.duration + 1 end,
    function(p) p.tracks[1].keys[1].frame = 1.5 end,
    function(p) p.fps = 0 end,
}) do
    local broken = Engine.clone(imported)
    corrupt(broken)
    valid, validationError = Engine.validate(broken)
    check(not valid and type(validationError) == "string", "Malformed import is rejected with a reason")
end
local atomicImport = Engine.clone(imported)
local firstKey = atomicImport.tracks[1].keys[1]
atomicImport.tracks[1].keys[1], atomicImport.tracks[1].keys[2] = atomicImport.tracks[1].keys[2], firstKey
atomicImport.tracks[2].keys[1].easing = "Bad"
valid = Engine.validate(atomicImport)
check(not valid and atomicImport.tracks[1].keys[2] == firstKey, "Rejected imports do not mutate earlier valid tracks")

print("KEYNOVA_ENGINE_PASS " .. tostring(checks) .. " checks")
