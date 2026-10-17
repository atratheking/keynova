-- Real Studio checks for authored advanced editing and VFX/UI value semantics.
-- Engine is supplied by the package or an isolated test wrapper.
local parityChecks = 0
local function check(value, message) assert(value, message); parityChecks = parityChecks + 1 end
local function near(actual, expected, message)
    check(math.abs(actual - expected) < 0.00002, message .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function fixture(kind)
    local project = Engine.newProject("Parity engine")
    table.insert(project.items, {id = "object", name = "Target", type = "Part", path = {}})
    local track = Engine.newTrack("object", "Value", "Value", kind or "number")
    table.insert(project.tracks, track)
    return project, track
end
local function selection(track, ...)
    local result = {}
    for _, key in ipairs({...}) do table.insert(result, {trackId = track.id, keyId = key.id}) end
    return result
end
local Http = game:GetService("HttpService")
local function serialized(project) return Http:JSONEncode(project) end

local cases = {
    {"Vector2", Vector2.new(1, 3), Vector2.new(5, 7), {3, 5}},
    {"UDim", UDim.new(0.2, 10), UDim.new(0.6, 30), {0.4, 20}},
    {"UDim2", UDim2.new(0.2, 10, 0.4, 20), UDim2.new(0.6, 30, 0.8, 40), {0.4, 20, 0.6, 30}},
    {"Rect", Rect.new(1, 2, 9, 10), Rect.new(3, 4, 15, 18), {2, 3, 12, 14}},
    {"NumberRange", NumberRange.new(1, 3), NumberRange.new(5, 9), {3, 6}},
}
for _, example in ipairs(cases) do
    local kind, from, to, expected = example[1], example[2], example[3], example[4]
    local project, track = fixture(kind)
    Engine.insert(track, 0, from); Engine.insert(track, 20, to)
    check(typeof(Engine.decode(Engine.encode(from, kind), kind)) == kind, kind .. " native round trip")
    local result = Engine.sample(track, 10)
    check(typeof(result) == kind, kind .. " sample native type")
    local components = Engine.encode(result, kind)
    for index, value in ipairs(expected) do near(components[index], value, kind .. " component interpolation") end
    local roundTrip = Http:JSONDecode(serialized(project))
    local valid, problem = Engine.validate(roundTrip)
    check(valid, problem or kind .. " JSON validation")
    check(typeof(Engine.sample(roundTrip.tracks[1], 10)) == kind, kind .. " JSON sampling")
end

local numberA = NumberSequence.new({NumberSequenceKeypoint.new(0, 1, 0.2), NumberSequenceKeypoint.new(0.25, 3, 0.4), NumberSequenceKeypoint.new(1, 5, 0.6)})
local numberB = NumberSequence.new({NumberSequenceKeypoint.new(0, 3, 0.4), NumberSequenceKeypoint.new(0.75, 7, 0.8), NumberSequenceKeypoint.new(1, 9, 1)})
local sequenceProject, sequenceTrack = fixture("NumberSequence")
Engine.insert(sequenceTrack, 0, numberA); Engine.insert(sequenceTrack, 20, numberB)
local numberMixed = Engine.sample(sequenceTrack, 10)
check(#numberMixed.Keypoints == 4, "Number sequence uses union time points")
near(numberMixed.Keypoints[2].Time, 0.25, "Union retains first interior point")
near(numberMixed.Keypoints[3].Time, 0.75, "Union retains second interior point")
near(numberMixed.Keypoints[2].Value, (3 + (3 + 4 / 3)) / 2, "Union samples the other numeric curve")
near(numberMixed.Keypoints[2].Envelope, (0.4 + (0.4 + 0.4 / 3)) / 2, "Union interpolates envelope")
local emitter = Instance.new("ParticleEmitter")
emitter.Size = numberMixed
check(emitter.Size == numberMixed, "Number sequence applies to a native ParticleEmitter")
local colorA = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)), ColorSequenceKeypoint.new(0.25, Color3.new(1, 0, 0)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))})
local colorB = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0, 0, 1)), ColorSequenceKeypoint.new(0.75, Color3.new(0, 1, 0)), ColorSequenceKeypoint.new(1, Color3.new(1, 0, 1))})
local colorProject, colorTrack = fixture("ColorSequence")
Engine.insert(colorTrack, 0, colorA); Engine.insert(colorTrack, 20, colorB)
local colorMixed = Engine.sample(colorTrack, 10)
check(#colorMixed.Keypoints == 4, "Color sequence uses union time points")
near(colorMixed.Keypoints[2].Value.R, 0.5, "Color sequence red component")
near(colorMixed.Keypoints[2].Value.G, 1 / 6, "Color sequence sampled green component")
emitter.Color = colorMixed
check(emitter.Color == colorMixed, "Color sequence applies to a native ParticleEmitter")
local gradient = Instance.new("UIGradient")
gradient.Color = colorMixed
check(gradient.Color == colorMixed, "Composite interpolation applies to UIGradient")
emitter:Destroy(); gradient:Destroy()
for _, project in ipairs({sequenceProject, colorProject}) do
    local decoded = Http:JSONDecode(serialized(project))
    local valid, problem = Engine.validate(decoded)
    check(valid, problem or "Sequence JSON validation")
    check(typeof(Engine.sample(decoded.tracks[1], 10)) == decoded.tracks[1].valueType, "Sequence JSON sample")
end
local repeatedTimes = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(0.5, 3), NumberSequenceKeypoint.new(1, 4)})
local jumpMixed = Engine.interpolate(Engine.encode(repeatedTimes, "NumberSequence"), Engine.encode(NumberSequence.new(0), "NumberSequence"), 0.5, "NumberSequence")
check(#jumpMixed.Keypoints == 4 and jumpMixed.Keypoints[2].Time == jumpMixed.Keypoints[3].Time, "Sequence union preserves repeated-time discontinuities")
near(jumpMixed.Keypoints[2].Value, 0.5, "Discontinuity left value")
near(jumpMixed.Keypoints[3].Value, 1.5, "Discontinuity right value")

local denseA, denseB = {}, {}
for index = 0, 19 do
    denseA[index + 1] = NumberSequenceKeypoint.new(index / 19, index)
    denseB[index + 1] = NumberSequenceKeypoint.new(index == 0 and 0 or index == 19 and 1 or (index + 0.1) / 19, index)
end
local capacityProject, capacityTrack = fixture("NumberSequence")
Engine.insert(capacityTrack, 0, NumberSequence.new(denseA))
local before = serialized(capacityProject)
local inserted, insertProblem = pcall(Engine.insert, capacityTrack, 20, NumberSequence.new(denseB))
check(not inserted and tostring(insertProblem):find("20%-keypoint") and serialized(capacityProject) == before, "Native union capacity fails atomically at insertion")
capacityTrack.keys[1].easing = "Constant"
Engine.insert(capacityTrack, 20, NumberSequence.new(denseB), "Constant")
check(Engine.sample(capacityTrack, 10) == NumberSequence.new(denseA), "Constant sequences need no union interpolation")
local broken = Engine.clone(sequenceProject)
broken.tracks[1].keys[1].value[1][1] = 0.1
check(not Engine.validate(broken), "Sequence import requires the first time to be zero")
broken = Engine.clone(sequenceProject)
broken.tracks[1].keys[1].value[1][3] = -1
check(not Engine.validate(broken), "Sequence import rejects a negative envelope")

local params = {amplitude = 2, period = 0.4}
for _, direction in ipairs(Engine.directions) do
    near(Engine.ease(0, "Elastic", direction, params), 0, "Parameterized Elastic starts exactly")
    near(Engine.ease(1, "Elastic", direction, params), 1, "Parameterized Elastic ends exactly")
    local first = Engine.ease(0.17, "Elastic", direction, params)
    local second = Engine.ease(0.17, "Elastic", direction, {amplitude = 3, period = 0.6})
    check(math.abs(first - second) > 0.001, "Elastic amplitude and period affect the graph: " .. direction)
end
local parameterProject, parameterTrack = fixture()
local pa = Engine.insert(parameterTrack, 0, 0, "Elastic", "Out", params)
local pb = Engine.insert(parameterTrack, 100, 1)
params.period = 9
check(pa.parameters.period == 0.4, "Inserted parameters are owned independently")
near(Engine.sample(parameterTrack, 17), Engine.ease(0.17, "Elastic", "Out", pa.parameters), "Sampling uses departing key parameters")
local parameterCopy = Http:JSONDecode(serialized(parameterProject))
check(Engine.validate(parameterCopy), "Elastic parameters survive JSON validation")
near(Engine.sample(parameterCopy.tracks[1], 17), Engine.sample(parameterTrack, 17), "Elastic parameters survive JSON round trip")
for _, invalid in ipairs({{amplitude = -1}, {period = 0}, {period = math.huge}}) do
    local invalidProject = Engine.clone(parameterProject)
    invalidProject.tracks[1].keys[1].parameters = invalid
    check(not Engine.validate(invalidProject), "Invalid Elastic parameters fail validation")
end

local reverseProject, reverseTrack = fixture()
local ra = Engine.insert(reverseTrack, 10, 0, "Quad", "In")
local rb = Engine.insert(reverseTrack, 30, 1)
local earlier = Engine.sample(reverseTrack, 15)
local reversed, reverseError = Engine.reverse(reverseProject, selection(reverseTrack, ra, rb))
check(not reverseError and #reversed == 2 and ra.frame == 30 and rb.frame == 10, "Reverse preserves IDs while reflecting times")
near(Engine.sample(reverseTrack, 25), earlier, "Reverse transfers and inverts outgoing easing")
check(reverseTrack.keys[1].direction == "Out", "Reverse inverts incoming easing direction")
local blocker = Engine.insert(reverseTrack, 0, 9)
local third = Engine.insert(reverseTrack, 40, 2)
before = serialized(reverseProject)
reversed, reverseError = Engine.reverse(reverseProject, selection(reverseTrack, blocker, rb, third))
check(reverseError and serialized(reverseProject) == before, "Reverse rejects an unselected destination collision atomically")

local scaleProject, scaleTrack = fixture()
local sa = Engine.insert(scaleTrack, 1, 1)
local sb = Engine.insert(scaleTrack, 2, 2)
scaleProject.markers = {{id = "marker", frame = 100, name = "Test", value = ""}}
before = serialized(scaleProject)
local scaled, scaleError = Engine.rescale(scaleProject, 30, true)
check(not scaled and scaleError and serialized(scaleProject) == before, "FPS rounding collisions preserve the entire project")
scaled, scaleError = Engine.rescale(scaleProject, 120, true)
check(scaled and not scaleError and sa.frame == 2 and sb.frame == 4 and scaleProject.duration == 600 and scaleProject.markers[1].frame == 200, "FPS stretch updates duration, keys, and markers together")
sa.locked = true
before = serialized(scaleProject)
scaled, scaleError = Engine.rescale(scaleProject, 60, true)
check(not scaled and scaleError and serialized(scaleProject) == before, "FPS stretch respects key locks")
scaled, scaleError = Engine.rescale(scaleProject, 60, false)
check(scaled and scaleProject.duration == 600 and sa.frame == 2 and scaleProject.markers[1].frame == 200, "FPS change without stretch preserves frame positions")

local splitProject, splitTrack = fixture()
local splitA = Engine.insert(splitTrack, 0, 0)
local splitB = Engine.insert(splitTrack, 12, 12)
local split, splitError = Engine.split(splitProject, selection(splitTrack, splitA, splitB), 3)
check(not splitError and #split == 3 and #splitTrack.keys == 5, "Split inserts sampled keys at the requested stride")
near(splitTrack.keys[3].value, 6, "Split samples the original motion")
check(splitTrack.keys[1].id == splitA.id and splitTrack.keys[5].id == splitB.id, "Split preserves endpoint identities")

local wiggleProject, wiggleTrack = fixture("Vector3")
local wa = Engine.insert(wiggleTrack, 0, Vector3.new())
local wb = Engine.insert(wiggleTrack, 20, Vector3.new(20, 0, 0))
local baseProject = Engine.clone(wiggleProject)
local options = {amplitude = 2, period = 9, step = 2, seed = 3, axes = Vector3.new(0, 1, 0)}
local wiggled, wiggleError = Engine.wiggle(wiggleProject, selection(wiggleTrack, wa, wb), options)
check(not wiggleError and #wiggled == 11 and #wiggleTrack.keys == 11, "Wiggle bakes deterministic sampled motion")
check(Engine.decode(wa.value, "Vector3") == Vector3.new() and Engine.decode(wb.value, "Vector3") == Vector3.new(20, 0, 0), "Wiggle envelope preserves exact endpoints")
local changed = false
for _, key in ipairs(wiggleTrack.keys) do
    local value = Engine.decode(key.value, "Vector3")
    near(value.X, key.frame, "Wiggle only moves enabled component axes")
    near(value.Z, 0, "Wiggle leaves the disabled Z axis")
    changed = changed or math.abs(value.Y) > 0.01
end
check(changed, "Wiggle creates actual intermediate motion")
local secondTrack = baseProject.tracks[1]
local secondRefs = selection(secondTrack, secondTrack.keys[1], secondTrack.keys[2])
local secondResult, secondError = Engine.wiggle(baseProject, secondRefs, options)
check(not secondError and #secondResult == #wiggled, "Identical Wiggle options repeat successfully")
for index, key in ipairs(wiggleTrack.keys) do
    near((Engine.decode(key.value, "Vector3") - Engine.decode(secondTrack.keys[index].value, "Vector3")).Magnitude, 0, "Wiggle is deterministic for a fixed seed")
end
local collisionProject, collisionTrack = fixture()
local ca = Engine.insert(collisionTrack, 0, 0)
local cb = Engine.insert(collisionTrack, 20, 20)
Engine.insert(collisionTrack, 10, 7)
before = serialized(collisionProject)
wiggled, wiggleError = Engine.wiggle(collisionProject, selection(collisionTrack, ca, cb), {step = 2})
check(wiggleError and serialized(collisionProject) == before, "Wiggle collisions reject without changing existing values")
local unsupportedProject, unsupportedTrack = fixture("Color3")
local ua = Engine.insert(unsupportedTrack, 0, Color3.new())
local ub = Engine.insert(unsupportedTrack, 20, Color3.new(1, 1, 1))
before = serialized(unsupportedProject)
wiggled, wiggleError = Engine.wiggle(unsupportedProject, selection(unsupportedTrack, ua, ub), {})
check(wiggleError and serialized(unsupportedProject) == before, "Wiggle explicitly rejects unsupported value types")

local metadataProject, metadataTrack = fixture()
local metadataKey = Engine.insert(metadataTrack, 10, 2)
local path = {{name = "Workspace", class = "Workspace", index = 1}, {name = "Target", class = "Part", index = 1}}
metadataProject.items[1].path = Engine.clone(path)
metadataProject.items[1].rigItemId = "object"
metadataTrack.targetPath, metadataTrack.rigItemId, metadataTrack.rest = Engine.clone(path), "object", 0
metadataTrack.parentTrackId = metadataTrack.id
metadataKey.targetPath = Engine.clone(path)
metadataKey.referenceOffset = Engine.encode(CFrame.new(1, 2, 3), "CFrame")
metadataKey.referenceCamera = Engine.encode(CFrame.new(3, 2, 1), "CFrame")
metadataKey.duration, metadataKey.codeBegin, metadataKey.codeEnd, metadataKey.eventValue = 20, "begin", "finish", "value"
metadataKey.arguments = {false, 3, {nested = {"safe", true}}}
metadataProject.markers = {{id = "json-marker", frame = 0, name = "JSON", value = {enabled = false, count = 3}}}
local metadataValid, metadataError = Engine.validate(metadataProject)
check(metadataValid, metadataError or "Optional metadata validates at its owning boundary")
for _, corrupt in ipairs({
    function(p) p.items[1].path = {"Workspace"} end,
    function(p) p.items[1].path[1].index = 0 end,
    function(p) p.tracks[1].targetPath[1].class = false end,
    function(p) p.tracks[1].rest = "wrong type" end,
    function(p) p.tracks[1].keys[1].targetPath = "Workspace.Target" end,
    function(p) p.tracks[1].keys[1].referenceOffset = {0, 0, 0} end,
    function(p) p.tracks[1].keys[1].referenceCamera = {0 / 0} end,
    function(p) p.tracks[1].keys[1].duration = 400 end,
    function(p) p.tracks[1].keys[1].duration = 0.5 end,
    function(p) p.tracks[1].keys[1].codeBegin = false end,
    function(p) p.tracks[1].keys[1].codeEnd = {} end,
    function(p) p.tracks[1].keys[1].eventValue = 10 end,
    function(p) p.tracks[1].keys[1].arguments = {named = true} end,
    function(p) p.items[1].rigItemId = "missing" end,
    function(p) p.tracks[1].rigItemId = "missing" end,
    function(p) p.tracks[1].parentTrackId = "missing" end,
}) do
    local malformed = Engine.clone(metadataProject)
    corrupt(malformed)
    local valid, problem = Engine.validate(malformed)
    check(not valid and type(problem) == "string", "Malformed optional metadata is rejected before load")
end
local activeTrack = Engine.newTrack("object", "Active key", "Value", "number")
check(Engine.activeKey(activeTrack, 0) == nil, "Empty active-key lookup returns nil")
local activeA = Engine.insert(activeTrack, 10, 1)
local activeB = Engine.insert(activeTrack, 20, 2)
local activeC = Engine.insert(activeTrack, 30, 3)
check(Engine.activeKey(activeTrack, 0) == activeA, "Active lookup holds first metadata before the first key")
check(Engine.activeKey(activeTrack, 20) == activeB, "Active lookup switches metadata on the exact key")
check(Engine.activeKey(activeTrack, 29.9) == activeB, "Active lookup chooses the rightmost preceding key")
check(Engine.activeKey(activeTrack, 300) == activeC, "Active lookup holds the final key metadata")
local metadataScaled, metadataScaleError = Engine.rescale(metadataProject, 120, true)
check(metadataScaled and not metadataScaleError and metadataKey.frame == 20 and metadataKey.duration == 40, "FPS rescale preserves timed-key endpoint semantics")
check(metadataKey.codeBegin == "begin" and metadataKey.arguments[1] == false, "FPS rescale preserves authored action metadata")

local rotationProject=Engine.newProject("Rotation wiggle");rotationProject.duration=10
rotationProject.items={{id="rotation-rig"}}
local rotationTrack=Engine.newTrack("rotation-rig","Joint","Transform","CFrame");table.insert(rotationProject.tracks,rotationTrack)
local first=Engine.insert(rotationTrack,0,CFrame.new(2,3,4));local last=Engine.insert(rotationTrack,10,CFrame.new(2,3,4))
local rotationRefs,rotationError=Engine.wiggle(rotationProject,{{trackId=rotationTrack.id,keyId=first.id},{trackId=rotationTrack.id,keyId=last.id}},{mode="Rotation",amplitude=25,period=7,step=1,seed=3,axes=Vector3.new(0,1,0)})
check(rotationRefs and not rotationError,"Wiggle exposes rotation mode")
local middle=Engine.sample(rotationTrack,5);local x,y,z=middle:ToOrientation()
check((middle.Position-Vector3.new(2,3,4)).Magnitude<0.00001 and math.abs(y)>0.001 and math.abs(x)<0.00001 and math.abs(z)<0.00001,"Rotation wiggle changes only the selected angular axis and preserves translation")

print("KEYNOVA_PARITY_ENGINE_PASS " .. tostring(parityChecks) .. " checks")
