-- Keynova's independent animation model. Values stay JSON-safe until sampled.
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Engine = {}
Engine.easingStyles = {"Linear", "Constant", "Sine", "Quad", "Cubic", "Quart", "Quint", "Sextic", "Expo", "Circ", "Back", "Bounce", "Elastic"}
Engine.directions = {"In", "Out", "InOut", "OutIn"}
Engine.valueTypes = {"CFrame", "Vector3", "Color3", "Vector2", "UDim", "UDim2", "Rect", "NumberRange", "NumberSequence", "ColorSequence", "number", "boolean", "string"}
-- Verified against the native NumberSequence/ColorSequence constructors.
Engine.sequenceCapacity = 20
-- An explicit Keynova allocation budget, not a Roblox/Moon format restriction.
Engine.operationCapacity = 120000

local styles, directions, valueTypes = {}, {}, {}
for _, name in ipairs(Engine.easingStyles) do styles[name] = true end
for _, name in ipairs(Engine.directions) do directions[name] = true end
for _, name in ipairs(Engine.valueTypes) do valueTypes[name] = true end
local tweenStyles = {
    Linear = Enum.EasingStyle.Linear, Sine = Enum.EasingStyle.Sine,
    Quad = Enum.EasingStyle.Quad, Cubic = Enum.EasingStyle.Cubic,
    Quart = Enum.EasingStyle.Quart, Quint = Enum.EasingStyle.Quint,
    Expo = Enum.EasingStyle.Exponential, Circ = Enum.EasingStyle.Circular,
    Back = Enum.EasingStyle.Back, Bounce = Enum.EasingStyle.Bounce,
    Elastic = Enum.EasingStyle.Elastic,
}

local function id(prefix)
    return (prefix or "id") .. "_" .. HttpService:GenerateGUID(false)
end
Engine.id = id

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function frameNumber(value)
    return finite(value) and value >= 0 and value <= 9007199254740991 and value % 1 == 0
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[deepCopy(key, seen)] = deepCopy(child, seen) end
    return result
end
Engine.clone = deepCopy

local function array(value)
    if type(value) ~= "table" then return false end
    local length = #value
    for key in pairs(value) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > length then return false end
    end
    for index = 1, length do if value[index] == nil then return false end end
    return true
end

local componentLengths = {CFrame = 12, Vector3 = 3, Color3 = 3, Vector2 = 2, UDim = 2, UDim2 = 4, Rect = 4, NumberRange = 2}
local function encodedValue(value, valueType)
    if valueType == "number" then return finite(value) end
    if valueType == "boolean" or valueType == "string" then return type(value) == valueType end
    if valueType == "NumberSequence" or valueType == "ColorSequence" then
        if not array(value) or #value < 2 or #value > Engine.sequenceCapacity then return false end
        local previous = -1
        for _, point in ipairs(value) do
            if not array(point) or #point ~= (valueType == "NumberSequence" and 3 or 4) then return false end
            for _, component in ipairs(point) do if not finite(component) then return false end end
            if point[1] < previous or point[1] < 0 or point[1] > 1 then return false end
            if valueType == "NumberSequence" and point[3] < 0 then return false end
            previous = point[1]
        end
        return value[1][1] == 0 and value[#value][1] == 1
    end
    local length = componentLengths[valueType]
    if not length or not array(value) or #value ~= length then return false end
    for _, component in ipairs(value) do if not finite(component) then return false end end
    if valueType == "NumberRange" and value[1] > value[2] then return false end
    if valueType == "Rect" and (value[1] > value[3] or value[2] > value[4]) then return false end
    return true
end

function Engine.encode(value, valueType)
    valueType = valueType or typeof(value)
    local encoded
    if valueType == "CFrame" and typeof(value) == "CFrame" then
        encoded = {value:GetComponents()}
    elseif valueType == "Vector3" and typeof(value) == "Vector3" then
        encoded = {value.X, value.Y, value.Z}
    elseif valueType == "Color3" and typeof(value) == "Color3" then
        encoded = {value.R, value.G, value.B}
    elseif valueType == "Vector2" and typeof(value) == "Vector2" then
        encoded = {value.X, value.Y}
    elseif valueType == "UDim" and typeof(value) == "UDim" then
        encoded = {value.Scale, value.Offset}
    elseif valueType == "UDim2" and typeof(value) == "UDim2" then
        encoded = {value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset}
    elseif valueType == "Rect" and typeof(value) == "Rect" then
        encoded = {value.Min.X, value.Min.Y, value.Max.X, value.Max.Y}
    elseif valueType == "NumberRange" and typeof(value) == "NumberRange" then
        encoded = {value.Min, value.Max}
    elseif (valueType == "NumberSequence" or valueType == "ColorSequence") and typeof(value) == valueType then
        encoded = {}
        for _, point in ipairs(value.Keypoints) do
            local components
            if valueType == "NumberSequence" then components = {point.Time, point.Value, point.Envelope}
            else components = {point.Time, point.Value.R, point.Value.G, point.Value.B} end
            table.insert(encoded, components)
        end
    else
        encoded = deepCopy(value)
    end
    assert(encodedValue(encoded, valueType), "Invalid " .. tostring(valueType) .. " animation value")
    return encoded
end

function Engine.decode(value, valueType)
    assert(encodedValue(value, valueType), "Invalid " .. tostring(valueType) .. " animation value")
    if valueType == "CFrame" then return CFrame.new(table.unpack(value)) end
    if valueType == "Vector3" then return Vector3.new(value[1], value[2], value[3]) end
    if valueType == "Color3" then return Color3.new(value[1], value[2], value[3]) end
    if valueType == "Vector2" then return Vector2.new(value[1], value[2]) end
    if valueType == "UDim" then return UDim.new(value[1], value[2]) end
    if valueType == "UDim2" then return UDim2.new(value[1], value[2], value[3], value[4]) end
    if valueType == "Rect" then return Rect.new(value[1], value[2], value[3], value[4]) end
    if valueType == "NumberRange" then return NumberRange.new(value[1], value[2]) end
    if valueType == "NumberSequence" or valueType == "ColorSequence" then
        local points = {}
        for _, point in ipairs(value) do
            if valueType == "NumberSequence" then table.insert(points, NumberSequenceKeypoint.new(point[1], point[2], point[3]))
            else table.insert(points, ColorSequenceKeypoint.new(point[1], Color3.new(point[2], point[3], point[4]))) end
        end
        if valueType == "NumberSequence" then return NumberSequence.new(points) end
        return ColorSequence.new(points)
    end
    return value
end

-- A union retains repeated times so discontinuities in either sequence survive.
local function sequenceTimes(from, to)
    local counts, times = {}, {}
    for _, points in ipairs({from, to}) do
        local localCounts = {}
        for _, point in ipairs(points) do localCounts[point[1]] = (localCounts[point[1]] or 0) + 1 end
        for time, count in pairs(localCounts) do
            if not counts[time] then table.insert(times, time) end
            counts[time] = math.max(counts[time] or 0, count)
        end
    end
    table.sort(times)
    local result = {}
    for _, time in ipairs(times) do
        for occurrence = 1, counts[time] do table.insert(result, {time = time, occurrence = occurrence, count = counts[time]}) end
    end
    return result
end

local function sequenceAt(points, position)
    local time = position.time
    for index, point in ipairs(points) do
        if point[1] == time then
            local last = index
            while points[last + 1] and points[last + 1][1] == time do last = last + 1 end
            local fraction = position.count == 1 and 0 or (position.occurrence - 1) / (position.count - 1)
            return points[index + math.floor((last - index) * fraction + 0.5)]
        elseif point[1] > time then
            local previous = points[index - 1]
            local alpha = (time - previous[1]) / (point[1] - previous[1])
            local result = {time}
            for component = 2, #point do result[component] = previous[component] + (point[component] - previous[component]) * alpha end
            return result
        end
    end
    return points[#points]
end

local function sequenceCompatible(left, right, valueType, easing)
    if (valueType ~= "NumberSequence" and valueType ~= "ColorSequence") or easing == "Constant" then return true end
    return #sequenceTimes(left, right) <= Engine.sequenceCapacity
end

local function sequenceTrackCompatible(track, keys)
    if track.valueType ~= "NumberSequence" and track.valueType ~= "ColorSequence" then return true end
    local ordered = {}
    for _, key in ipairs(keys) do table.insert(ordered, key) end
    table.sort(ordered, function(a, b) return a.frame < b.frame end)
    for index = 2, #ordered do
        if not sequenceCompatible(ordered[index - 1].value, ordered[index].value, track.valueType, ordered[index - 1].easing) then return false end
    end
    return true
end

-- Interpolation owns all structured value semantics, including sequence union
-- points and nonnegative envelopes. Exported players embed this same module.
function Engine.interpolate(from, to, alpha, valueType)
    assert(encodedValue(from, valueType) and encodedValue(to, valueType), "Invalid interpolation values")
    if alpha == 1 then return Engine.decode(to, valueType) end
    if alpha == 0 or valueType == "boolean" or valueType == "string" then return Engine.decode(from, valueType) end
    if valueType == "number" then return from + (to - from) * alpha end
    if valueType == "CFrame" then return Engine.decode(from, valueType):Lerp(Engine.decode(to, valueType), alpha) end
    local encoded = {}
    if valueType == "NumberSequence" or valueType == "ColorSequence" then
        local times = sequenceTimes(from, to)
        assert(#times <= Engine.sequenceCapacity, "Interpolated sequence exceeds Roblox's 20-keypoint capacity; align the source sequence times")
        for _, position in ipairs(times) do
            local a, b = sequenceAt(from, position), sequenceAt(to, position)
            local point = {position.time}
            for component = 2, #a do point[component] = a[component] + (b[component] - a[component]) * alpha end
            if valueType == "NumberSequence" then point[3] = math.max(0, point[3]) end
            table.insert(encoded, point)
        end
    else
        for component = 1, #from do encoded[component] = from[component] + (to[component] - from[component]) * alpha end
        -- Back/Elastic overshoot must still produce constructible rectangles/ranges.
        if valueType == "NumberRange" then encoded[2] = math.max(encoded[1], encoded[2]) end
        if valueType == "Rect" then encoded[3] = math.max(encoded[1], encoded[3]); encoded[4] = math.max(encoded[2], encoded[4]) end
    end
    return Engine.decode(encoded, valueType)
end

function Engine.newProject(name)
    return {format = "keynova", version = 2, name = name or "Untitled animation", fps = 60,
        duration = 300, loop = false, items = {}, tracks = {}, markers = {}}
end

function Engine.newTrack(itemId, name, property, valueType)
    assert(type(itemId) == "string" and itemId ~= "", "A track needs an item ID")
    assert(type(property) == "string" and property ~= "", "A track needs a property")
    assert(valueTypes[valueType], "Unsupported animation value type")
    return {id = id("track"), name = name or property, itemId = itemId, property = property,
        valueType = valueType, keys = {}, locked = false, enabled = true}
end

-- Easing belongs to the departing key. OutIn is the outgoing half followed by
-- the incoming half; Constant holds the departing value until the next key.
local function validParameters(parameters)
    if parameters == nil then return true end
    if type(parameters) ~= "table" then return false end
    for key in pairs(parameters) do if key ~= "amplitude" and key ~= "period" then return false end end
    return (parameters.amplitude == nil or (finite(parameters.amplitude) and parameters.amplitude >= 0))
        and (parameters.period == nil or (finite(parameters.period) and parameters.period > 0))
end

function Engine.ease(alpha, style, direction, parameters)
    alpha = math.max(0, math.min(1, alpha))
    style, direction = style or "Linear", direction or "InOut"
    assert(styles[style] and directions[direction], "Unsupported easing")
    assert(validParameters(parameters), "Elastic amplitude must be nonnegative and period must be positive and finite")
    if style == "Constant" then return alpha >= 1 and 1 or 0 end
    if style == "Linear" then return alpha end
    if style == "Elastic" and parameters ~= nil then
        if alpha == 0 or alpha == 1 then return alpha end
        -- Authored Penner-style parameterization; nil parameters retain Roblox's
        -- native defaults. Normalized amplitudes below 1 use the minimum unit
        -- amplitude needed to meet both endpoints, as in the Penner equations.
        local amplitude = math.max(1, parameters.amplitude or 1)
        local period = parameters.period or 0.3
        local shift = period / (2 * math.pi) * math.asin(1 / amplitude)
        local function outgoing(t)
            if t == 0 or t == 1 then return t end
            return amplitude * 2 ^ (-10 * t) * math.sin(((t % period) - shift) / period * 2 * math.pi) + 1
        end
        local function incoming(t) return 1 - outgoing(1 - t) end
        if direction == "In" then return incoming(alpha) end
        if direction == "Out" then return outgoing(alpha) end
        if direction == "InOut" then
            if alpha < 0.5 then return incoming(2 * alpha) / 2 end
            return 0.5 + outgoing(2 * alpha - 1) / 2
        end
        if alpha < 0.5 then return outgoing(2 * alpha) / 2 end
        return 0.5 + incoming(2 * alpha - 1) / 2
    end
    local function portion(value, inOrOut)
        if style == "Sextic" then
            if inOrOut == "In" then return value ^ 6 end
            return 1 - (1 - value) ^ 6
        end
        return TweenService:GetValue(value, tweenStyles[style], Enum.EasingDirection[inOrOut])
    end
    if direction == "In" or direction == "Out" then return portion(alpha, direction) end
    if direction == "InOut" then
        if style ~= "Sextic" then return TweenService:GetValue(alpha, tweenStyles[style], Enum.EasingDirection.InOut) end
        if alpha < 0.5 then return portion(alpha * 2, "In") / 2 end
        return 0.5 + portion(alpha * 2 - 1, "Out") / 2
    end
    if alpha < 0.5 then return portion(alpha * 2, "Out") / 2 end
    return 0.5 + portion(alpha * 2 - 1, "In") / 2
end

function Engine.activeKey(track, frame)
    local keys = track.keys
    if #keys == 0 then return nil end
    if frame <= keys[1].frame then return keys[1], 1 end
    if frame >= keys[#keys].frame then return keys[#keys], #keys end
    local low, high = 1, #keys
    while high - low > 1 do
        local middle = math.floor((low + high) / 2)
        if keys[middle].frame <= frame then low = middle else high = middle end
    end
    return keys[low], low
end

local function sampleInterval(track,frame)
    local left,index=Engine.activeKey(track,frame)
    if not left then return nil end
    local right=track.keys[index+1]
    if frame<=left.frame or not right then return left,nil,0 end
    return left,right,Engine.ease((frame-left.frame)/(right.frame-left.frame),left.easing,left.direction,left.parameters)
end
local function intervalValue(track,left,right,alpha)
    if not left then return nil end
    if not right then return Engine.decode(left.value,track.valueType)end
    return Engine.interpolate(left.value,right.value,alpha,track.valueType)
end
local function intervalWeight(left,right,alpha)
    if not left then return 1 end
    local weight=left.nativeWeight or 1
    if not right then return weight end
    return math.clamp(weight+((right.nativeWeight or 1)-weight)*alpha,0,1)
end
function Engine.sampleRaw(track,frame)
    local left,right,alpha=sampleInterval(track,frame)
    return intervalValue(track,left,right,alpha)
end
function Engine.sampleWeight(track,frame)
    local left,right,alpha=sampleInterval(track,frame)
    return intervalWeight(left,right,alpha)
end
function Engine.sample(track,frame)
    local left,right,alpha=sampleInterval(track,frame)
    local value=intervalValue(track,left,right,alpha)
    if value==nil then return nil end
    local weight=intervalWeight(left,right,alpha)
    if weight~=1 then
        if track.valueType=="CFrame"then return CFrame.new():Lerp(value,weight)end
        if track.valueType=="number"then return value*weight end
    end
    return value
end

local function sortKeys(track)
    table.sort(track.keys, function(left, right) return left.frame < right.frame end)
end

function Engine.insert(track, frame, value, easing, direction, parameters)
    assert(frameNumber(frame), "Keyframe time must be a nonnegative integer")
    assert(not track.locked, "Track is locked")
    if easing ~= nil then assert(styles[easing], "Unsupported easing style") end
    if direction ~= nil then assert(directions[direction], "Unsupported easing direction") end
    assert(validParameters(parameters), "Invalid elastic parameters")
    local encoded = Engine.encode(value, track.valueType)
    local prior, following, existing
    for _, key in ipairs(track.keys) do
        if key.frame < frame and (not prior or key.frame > prior.frame) then prior = key end
        if key.frame > frame and (not following or key.frame < following.frame) then following = key end
        if key.frame == frame then existing = key end
    end
    assert(not prior or sequenceCompatible(prior.value, encoded, track.valueType, prior.easing), "Sequence interpolation exceeds Roblox's 20-keypoint capacity")
    assert(not following or sequenceCompatible(encoded, following.value, track.valueType, easing or (existing and existing.easing)), "Sequence interpolation exceeds Roblox's 20-keypoint capacity")
    for _, key in ipairs(track.keys) do
        if key.frame == frame then
            assert(not key.locked, "Keyframe is locked")
            key.value = encoded
            key.easing = easing or key.easing or "Linear"
            key.direction = direction or key.direction or "InOut"
            if parameters ~= nil then key.parameters = deepCopy(parameters) end
            return key
        end
    end
    local key = {id = id("key"), frame = frame, value = encoded,
        easing = easing or "Linear", direction = direction or "InOut"}
    if parameters ~= nil then key.parameters = deepCopy(parameters) end
    table.insert(track.keys, key)
    sortKeys(track)
    return key
end

local function safeMetadata(value, visiting)
    local kind = type(value)
    if kind == "number" then return finite(value) end
    if kind == "string" or kind == "boolean" then return true end
    if kind ~= "table" then return false end
    visiting = visiting or {}
    if visiting[value] then return false end
    visiting[value] = true
    for key, child in pairs(value) do
        if (type(key) ~= "string" and not frameNumber(key)) or not safeMetadata(child, visiting) then
            visiting[value] = nil
            return false
        end
    end
    visiting[value] = nil
    return true
end

local function identity(value)
    return type(value) == "string" and value ~= ""
end

local function validPath(path)
    if path == nil then return true end
    if not array(path) then return false end
    for _, segment in ipairs(path) do
        if type(segment) ~= "table" or type(segment.name) ~= "string" or not identity(segment.class)
            or not frameNumber(segment.index) or segment.index < 1 then return false end
    end
    return true
end

-- Imports are checked before normalization, so a failed validation never leaves
-- a partially sorted or partially repaired project behind.
function Engine.validate(project)
    if type(project) ~= "table" or not safeMetadata(project) then return false, "Project must contain only finite JSON-safe values" end
    if project.format ~= "keynova" or project.version ~= 2 then return false, "Expected a Keynova version 2 project" end
    if type(project.name) ~= "string" then return false, "Project name must be text" end
    if not finite(project.fps) or project.fps <= 0 then return false, "Frame rate must be a positive number" end
    if not frameNumber(project.duration) then return false, "Duration must be a nonnegative whole frame" end
    if type(project.loop) ~= "boolean" then return false, "Loop must be a boolean" end
    if not array(project.items) or not array(project.tracks) or not array(project.markers) then return false, "Items, tracks, and markers must be arrays" end
    local itemIds, trackIds, keyIds, markerIds = {}, {}, {}, {}
    for _, item in ipairs(project.items) do
        if type(item) ~= "table" or not identity(item.id) or itemIds[item.id] then return false, "Item IDs must be unique nonempty strings" end
        if not validPath(item.path) then return false, "Item path must contain name/class/index segments" end
        itemIds[item.id] = true
    end
    for _, item in ipairs(project.items) do
        if item.rigItemId ~= nil and not itemIds[item.rigItemId] then return false, "Item references a missing rig item" end
    end
    if project.groupKeyframes~=nil and type(project.groupKeyframes)~="boolean"then return false,"Group Keyframes must be a boolean"end
    if project.rigItemId~=nil and not itemIds[project.rigItemId]then return false,"Rig file references a missing item"end
    for _, track in ipairs(project.tracks) do
        if type(track) ~= "table" or not identity(track.id) or trackIds[track.id] then return false, "Track IDs must be unique nonempty strings" end
        trackIds[track.id] = true
        if not itemIds[track.itemId] then return false, "Track references a missing item" end
        if type(track.name) ~= "string" or not identity(track.property) or not valueTypes[track.valueType] then return false, "Track has an invalid name, property, or value type" end
        if not validPath(track.targetPath) then return false, "Track target path must contain name/class/index segments" end
        if track.rigItemId ~= nil and not itemIds[track.rigItemId] then return false, "Track references a missing rig item" end
        if track.restTargets~=nil then
            if not array(track.restTargets)then return false,"Property rest targets must be an array"end
            for _,target in ipairs(track.restTargets)do
                if type(target)~="table"or target.path==nil or not validPath(target.path)or not encodedValue(target.value,track.valueType)then return false,"Property rest target has invalid path or value"end
            end
        end
        if track.rest ~= nil and not encodedValue(track.rest, track.valueType) then return false, "Track rest value has an invalid " .. track.valueType .. " value" end
        if track.locked ~= nil and type(track.locked) ~= "boolean" then return false, "Track locked state must be a boolean" end
        if track.enabled ~= nil and type(track.enabled) ~= "boolean" then return false, "Track enabled state must be a boolean" end
        if not array(track.keys) then return false, "Track keys must be an array" end
        local frames = {}
        for _, key in ipairs(track.keys) do
            if type(key) ~= "table" or not identity(key.id) or keyIds[key.id] then return false, "Keyframe IDs must be unique nonempty strings" end
            keyIds[key.id] = true
            if not frameNumber(key.frame) or key.frame > project.duration then return false, "Keyframe lies outside the project duration" end
            if frames[key.frame] then return false, "A track cannot contain two keys on the same frame" end
            frames[key.frame] = true
            if not encodedValue(key.value, track.valueType) then return false, "Keyframe has an invalid " .. track.valueType .. " value" end
            if key.easing ~= nil and not styles[key.easing] then return false, "Keyframe has an unsupported easing style" end
            if key.direction ~= nil and not directions[key.direction] then return false, "Keyframe has an unsupported easing direction" end
            if not validParameters(key.parameters) then return false, "Keyframe has invalid elastic parameters" end
            if key.events~=nil then
                if type(key.events)~="table"then return false,"Event values must be a dictionary"end
                for name in pairs(key.events)do if type(name)~="string"or name==""then return false,"Event values need nonempty names"end end
            end
            if key.nativeWeight~=nil and(not finite(key.nativeWeight)or key.nativeWeight<0 or key.nativeWeight>1)then return false,"Pose weight must be between zero and one"end
            if key.locked ~= nil and type(key.locked) ~= "boolean" then return false, "Keyframe locked state must be a boolean" end
            if key.group ~= nil and not identity(key.group) then return false, "Keyframe group must be a nonempty string" end
            if not validPath(key.targetPath) then return false, "Keyframe target path must contain name/class/index segments" end
            if key.referenceOffset ~= nil and not encodedValue(key.referenceOffset, "CFrame") then return false, "Keyframe reference offset must be an encoded CFrame" end
            if key.referenceCamera ~= nil and not encodedValue(key.referenceCamera, "CFrame") then return false, "Keyframe reference camera must be an encoded CFrame" end
            if key.duration ~= nil and (not frameNumber(key.duration) or key.frame + key.duration > project.duration) then return false, "Keyframe duration must fit inside the timeline" end
            for _, field in ipairs({"codeBegin", "codeEnd", "eventValue"}) do
                if key[field] ~= nil and type(key[field]) ~= "string" then return false, "Keyframe " .. field .. " must be text" end
            end
            if key.arguments ~= nil and not array(key.arguments) then return false, "Keyframe arguments must be a JSON-safe array" end
        end
        if not sequenceTrackCompatible(track, track.keys) then return false, "Sequence interpolation exceeds Roblox's 20-keypoint capacity" end
    end
    for _, track in ipairs(project.tracks) do
        if track.parentTrackId ~= nil and not trackIds[track.parentTrackId] then return false, "Track references a missing parent track" end
    end
    for _, marker in ipairs(project.markers) do
        if type(marker) ~= "table" or not identity(marker.id) or markerIds[marker.id] then return false, "Marker IDs must be unique nonempty strings" end
        markerIds[marker.id] = true
        if not frameNumber(marker.frame) or marker.frame > project.duration or type(marker.name) ~= "string" then return false, "Marker has an invalid frame or name" end
    end
    for _, track in ipairs(project.tracks) do
        if track.locked == nil then track.locked = false end
        if track.enabled == nil then track.enabled = true end
        for _, key in ipairs(track.keys) do
            key.easing = key.easing or "Linear"
            key.direction = key.direction or "InOut"
        end
        sortKeys(track)
    end
    table.sort(project.markers, function(left, right)
        if left.frame == right.frame then return left.id < right.id end
        return left.frame < right.frame
    end)
    for _, marker in ipairs(project.markers) do if marker.value == nil then marker.value = "" end end
    return true
end

local function selectedKeys(project, selection)
    local wanted, result, refs = {}, {}, {}
    for _, ref in ipairs(selection or {}) do
        if type(ref) == "table" and identity(ref.trackId) and identity(ref.keyId) then
            wanted[ref.trackId] = wanted[ref.trackId] or {}
            wanted[ref.trackId][ref.keyId] = true
        end
    end
    for _, track in ipairs(project.tracks) do
        local trackWanted = wanted[track.id]
        if trackWanted then
            for _, key in ipairs(track.keys) do
                if trackWanted[key.id] then
                    table.insert(result, {track = track, key = key})
                    table.insert(refs, {trackId = track.id, keyId = key.id})
                end
            end
        end
    end
    return result, refs
end

local function editable(selected)
    local result = {}
    for _, entry in ipairs(selected) do
        if not entry.track.locked and not entry.key.locked then table.insert(result, entry) end
    end
    return result
end

local function rounding(value)
    return math.floor(value + 0.5)
end

-- Apply time edits atomically; a blocked target never destroys an unrelated key.
local function moveKeys(project, entries, refs, times, overrides)
    local moving, proposed = {}, {}
    for index, entry in ipairs(entries) do moving[entry.key] = times[index] end
    for index, entry in ipairs(entries) do
        local frame = times[index]
        if not frameNumber(frame) or frame > project.duration then return refs, "Edited keys would fall outside the project duration" end
        if entry.key.duration ~= nil and frame + entry.key.duration > project.duration then return refs, "Edited key duration would exceed the project timeline" end
        proposed[entry.track] = proposed[entry.track] or {}
        if proposed[entry.track][frame] then return refs, "Edited keys would overlap on the same frame" end
        proposed[entry.track][frame] = true
    end
    for track, frames in pairs(proposed) do
        local virtual = {}
        for _, key in ipairs(track.keys) do
            if not moving[key] and frames[key.frame] then return refs, "An existing or locked key occupies the destination frame" end
            local override = overrides and overrides[key]
            table.insert(virtual, {frame = moving[key] or key.frame, value = key.value, easing = override and override.easing or key.easing})
        end
        if not sequenceTrackCompatible(track, virtual) then return refs, "Edited sequence interpolation exceeds Roblox's 20-keypoint capacity" end
    end
    for index, entry in ipairs(entries) do entry.key.frame = times[index] end
    for key, override in pairs(overrides or {}) do
        key.easing, key.direction, key.parameters = override.easing, override.direction, override.parameters
    end
    for track in pairs(proposed) do sortKeys(track) end
    return refs
end

function Engine.retime(project, selection, delta)
    local selected, refs = selectedKeys(project, selection)
    if not finite(delta) then return refs, "Time offset must be a finite number" end
    local entries = editable(selected)
    if #entries == 0 then return refs, "No unlocked keyframes are selected" end
    local minimum, maximum = math.huge, -math.huge
    for _, entry in ipairs(entries) do minimum = math.min(minimum, entry.key.frame); maximum = math.max(maximum, entry.key.frame + (entry.key.duration or 0)) end
    delta = math.max(-minimum, math.min(project.duration - maximum, rounding(delta)))
    local times = {}
    for _, entry in ipairs(entries) do table.insert(times, entry.key.frame + delta) end
    return moveKeys(project, entries, refs, times)
end

function Engine.stretch(project, selection, factor, pivot)
    local selected, refs = selectedKeys(project, selection)
    if not finite(factor) or factor <= 0 then return refs, "Stretch factor must be positive and finite" end
    local entries = editable(selected)
    if #entries == 0 then return refs, "No unlocked keyframes are selected" end
    if pivot ~= nil and not finite(pivot) then return refs, "Stretch pivot must be finite" end
    if pivot == nil then
        pivot = math.huge
        for _, entry in ipairs(entries) do pivot = math.min(pivot, entry.key.frame) end
    end
    local times = {}
    for _, entry in ipairs(entries) do table.insert(times, rounding(pivot + (entry.key.frame - pivot) * factor)) end
    return moveKeys(project, entries, refs, times)
end

-- Clipboard times are relative to the earliest copied frame. Source IDs map
-- tracks within this project; targetTrackId explicitly redirects one track.
function Engine.copy(project, selection)
    local selected = selectedKeys(project, selection)
    if #selected == 0 then return nil, "No keyframes are selected" end
    local first, last = math.huge, -math.huge
    for _, entry in ipairs(selected) do first = math.min(first, entry.key.frame); last = math.max(last, entry.key.frame) end
    local clipboard, byTrack = {format = "keynova-clipboard", version = 1, span = last - first, tracks = {}}, {}
    for _, entry in ipairs(selected) do
        local source = byTrack[entry.track.id]
        if not source then
            source = {trackId = entry.track.id, itemId = entry.track.itemId, name = entry.track.name,
                property = entry.track.property, valueType = entry.track.valueType, keys = {}}
            byTrack[entry.track.id] = source
            table.insert(clipboard.tracks, source)
        end
        local key = deepCopy(entry.key)
        key.frame = key.frame - first
        table.insert(source.keys, key)
    end
    return clipboard
end

local function trackMap(project)
    local result = {}
    for _, track in ipairs(project.tracks) do result[track.id] = track end
    return result
end

local function preparePaste(project, clipboard, at, targetTrackId, pending, groups, tracks)
    if type(clipboard) ~= "table" or not safeMetadata(clipboard) or clipboard.format ~= "keynova-clipboard" or clipboard.version ~= 1 or not array(clipboard.tracks) then return nil, "Clipboard is not a Keynova keyframe selection" end
    if not frameNumber(at) then return nil, "Paste frame must be a nonnegative whole frame" end
    if targetTrackId ~= nil and #clipboard.tracks ~= 1 then return nil, "Redirecting a paste requires keys from one source track" end
    tracks = tracks or trackMap(project)
    local additions = {}
    for _, source in ipairs(clipboard.tracks) do
        if type(source) ~= "table" or not array(source.keys) then return nil, "Clipboard track is malformed" end
        local track = tracks[targetTrackId or source.trackId]
        if not track then return nil, "The destination track no longer exists" end
        if track.locked then return nil, "The destination track is locked" end
        if track.valueType ~= source.valueType then return nil, "Source and destination value types do not match" end
        if not pending[track] then
            pending[track] = {}
            for _, existing in ipairs(track.keys) do pending[track][existing.frame] = true end
        end
        for _, original in ipairs(source.keys) do
            if type(original) ~= "table" or not frameNumber(original.frame) or not encodedValue(original.value, track.valueType)
                or (original.easing ~= nil and not styles[original.easing]) or (original.direction ~= nil and not directions[original.direction])
                or (original.nativeWeight~=nil and(not finite(original.nativeWeight)or original.nativeWeight<0 or original.nativeWeight>1)) or not validParameters(original.parameters) or (original.group ~= nil and not identity(original.group)) then
                return nil, "Clipboard contains an invalid keyframe"
            end
            local frame = original.frame + at
            if frame > project.duration then return nil, "Pasted keys would exceed the project duration" end
            if original.duration ~= nil and (not frameNumber(original.duration) or frame + original.duration > project.duration) then return nil, "Pasted key duration would exceed the project timeline" end
            if pending[track][frame] then return nil, "An existing key occupies a paste destination" end
            pending[track][frame] = true
            local key = deepCopy(original)
            key.id, key.frame, key.locked = id("key"), frame, nil
            key.easing, key.direction = key.easing or "Linear", key.direction or "InOut"
            if key.group then
                groups[key.group] = groups[key.group] or id("group")
                key.group = groups[key.group]
            end
            table.insert(additions, {track = track, key = key})
        end
    end
    return additions
end

local function commitAdditions(additions)
    local refs, touched = {}, {}
    for _, entry in ipairs(additions) do
        if not touched[entry.track] then
            touched[entry.track] = {}
            for _, key in ipairs(entry.track.keys) do table.insert(touched[entry.track], key) end
        end
        table.insert(touched[entry.track], entry.key)
    end
    for track, keys in pairs(touched) do
        if not sequenceTrackCompatible(track, keys) then return {}, "Added sequence interpolation exceeds Roblox's 20-keypoint capacity" end
    end
    for _, entry in ipairs(additions) do
        table.insert(entry.track.keys, entry.key)
        table.insert(refs, {trackId = entry.track.id, keyId = entry.key.id})
    end
    for track in pairs(touched) do sortKeys(track) end
    return refs
end

function Engine.paste(project, clipboard, at, targetTrackId)
    local additions, problem = preparePaste(project, clipboard, at, targetTrackId, {}, {})
    if not additions then return {}, problem end
    return commitAdditions(additions)
end

function Engine.repeatKeys(project, selection, count, spacing)
    local selected, refs = selectedKeys(project, selection)
    if #selected == 0 then return refs, "No keyframes are selected" end
    if not frameNumber(count) or count < 1 then return refs, "Repeat count must be a positive whole number" end
    if #selected*count>Engine.operationCapacity then return refs,"Repeat exceeds the 120000-key operation budget"end
    local clipboard = Engine.copy(project, selection)
    local first = math.huge
    for _, entry in ipairs(selected) do first = math.min(first, entry.key.frame) end
    spacing = spacing or clipboard.span + 1
    if not frameNumber(spacing) or spacing < 1 then return refs, "Repeat spacing must be a positive whole frame" end
    if first + clipboard.span + count * spacing > project.duration then return refs, "Repeated keys would exceed the project duration" end
    local additions, pending, tracks = {}, {}, trackMap(project)
    for repetition = 1, count do
        local batch, problem = preparePaste(project, clipboard, first + repetition * spacing, nil, pending, {}, tracks)
        if not batch then return refs, problem end
        for _, entry in ipairs(batch) do table.insert(additions, entry) end
    end
    return commitAdditions(additions)
end

-- Fill samples the original curves before changing any track. Existing keys and
-- their easing remain intact; new sampled keys depart with Linear easing.
function Engine.fill(project, selection, step)
    local selected, refs = selectedKeys(project, selection)
    if not frameNumber(step) or step < 1 then return refs, "Fill step must be a positive whole frame" end
    local ranges = {}
    for _, entry in ipairs(selected) do
        if not entry.track.locked and not entry.key.locked then
            local range = ranges[entry.track]
            if not range then range = {first = entry.key.frame, last = entry.key.frame}; ranges[entry.track] = range end
            range.first, range.last = math.min(range.first, entry.key.frame), math.max(range.last, entry.key.frame)
        end
    end
    local additions, estimate = {}, 0
    for _, range in pairs(ranges) do estimate = estimate + math.max(0, math.ceil((range.last - range.first) / step) - 1) end
    if estimate > Engine.operationCapacity then return refs, "Subdivision exceeds the 120000-key operation budget; increase the frame step" end
    for _, track in ipairs(project.tracks) do
        local range = ranges[track]
        if range then
            local occupied = {}
            for _, key in ipairs(track.keys) do occupied[key.frame] = true end
            local frame = range.first + step
            while frame < range.last do
                if not occupied[frame] then
                    local value = Engine.sample(track, frame)
                    local key = {id = id("key"), frame = frame, value = Engine.encode(value, track.valueType), easing = "Linear", direction = "InOut"}
                    local source = Engine.activeKey(track, frame)
                    for _, field in ipairs({"targetPath", "referenceOffset", "referenceCamera"}) do key[field] = deepCopy(source[field]) end
                    table.insert(additions, {track = track, key = key})
                end
                frame = frame + step
            end
        end
    end
    if #additions == 0 then return refs, "No empty frames lie between the selected keys at this spacing" end
    return commitAdditions(additions)
end

-- Authored sampled subdivision. It shares Fill's exact sample-point semantics;
-- arbitrary nonlinear easing is approximated between the newly sampled keys.
function Engine.split(project, selection, stride)
    return Engine.fill(project, selection, stride or 1)
end

function Engine.reverse(project, selection)
    local selected, refs = selectedKeys(project, selection)
    local entries = editable(selected)
    if #entries == 0 then return refs, "No unlocked keyframes are selected" end
    local first, last, byTrack = math.huge, -math.huge, {}
    for _, entry in ipairs(entries) do
        first, last = math.min(first, entry.key.frame), math.max(last, entry.key.frame)
        byTrack[entry.track] = byTrack[entry.track] or {}
        table.insert(byTrack[entry.track], entry.key)
    end
    local times, overrides = {}, {}
    for _, entry in ipairs(entries) do table.insert(times, first + last - entry.key.frame) end
    local inverse = {In = "Out", Out = "In", InOut = "InOut", OutIn = "OutIn"}
    for _, keys in pairs(byTrack) do
        table.sort(keys, function(a, b) return a.frame < b.frame end)
        for index = 2, #keys do
            local left = keys[index - 1]
            overrides[keys[index]] = {easing = left.easing or "Linear", direction = inverse[left.direction or "InOut"], parameters = deepCopy(left.parameters)}
        end
    end
    return moveKeys(project, entries, refs, times, overrides)
end

-- Changing FPS owns all frame rounding. It preflights every track and marker
-- before mutating anything and never resolves a collision by discarding a key.
function Engine.rescale(project, newFps, stretch)
    if not finite(newFps) or newFps <= 0 then return false, "Frame rate must be positive and finite" end
    if not finite(project.fps) or project.fps <= 0 then return false, "Current frame rate is invalid" end
    if stretch == nil then stretch = true end
    if type(stretch) ~= "boolean" then return false, "Stretch must be a boolean" end
    local ratio = stretch and newFps / project.fps or 1
    local duration = rounding(project.duration * ratio)
    if not frameNumber(duration) then return false, "Rescaled duration is invalid" end
    local changes, markers = {}, {}
    for _, track in ipairs(project.tracks) do
        local occupied = {}
        for _, key in ipairs(track.keys) do
            local frame = rounding(key.frame * ratio)
            local keyDuration = key.duration ~= nil and rounding((key.frame + key.duration) * ratio) - frame or nil
            if not frameNumber(frame) or frame > duration then return false, "Rescaled key is outside the timeline" end
            if keyDuration ~= nil and (not frameNumber(keyDuration) or frame + keyDuration > duration) then return false, "Rescaled key duration is outside the timeline" end
            if (frame ~= key.frame or keyDuration ~= key.duration) and (track.locked or key.locked) then return false, "Unlock affected tracks and keys before rescaling time" end
            if occupied[frame] then return false, "Changing FPS would merge keyframes; choose a higher FPS or disable Stretch Animation" end
            occupied[frame] = true
            table.insert(changes, {key = key, frame = frame, duration = keyDuration})
        end
    end
    for _, marker in ipairs(project.markers) do
        local frame = rounding(marker.frame * ratio)
        if not frameNumber(frame) or frame > duration then return false, "Rescaled marker is outside the timeline" end
        if frame ~= marker.frame and marker.locked then return false, "Unlock affected markers before rescaling time" end
        table.insert(markers, {marker = marker, frame = frame})
    end
    for _, change in ipairs(changes) do change.key.frame, change.key.duration = change.frame, change.duration end
    for _, change in ipairs(markers) do change.marker.frame = change.frame end
    project.duration, project.fps = duration, newFps
    return true
end

-- Independently authored deterministic movement, not a claim about Moon's
-- proprietary Wiggle algorithm. CFrame offsets use local translation; Vector3
-- offsets use component axes. The endpoint envelope leaves selected ends fixed.
function Engine.wiggle(project, selection, options)
    local selected, refs = selectedKeys(project, selection)
    if options ~= nil and type(options) ~= "table" then return refs, "Wiggle options must be a table" end
    options = options or {}
    local amplitude = options.amplitude == nil and 1 or options.amplitude
    local mode=options.mode or"Position"
    if mode~="Position"and mode~="Rotation"then return refs,"Wiggle mode must be Position or Rotation"end
    local period = options.period == nil and 30 or options.period
    local step = options.step == nil and 1 or options.step
    local seed = options.seed == nil and 0 or options.seed
    local axes = options.axes == nil and Vector3.new(1, 1, 1) or options.axes
    if not finite(amplitude) or amplitude < 0 or not finite(period) or period <= 0 or not frameNumber(step) or step < 1 or not finite(seed) then return refs, "Wiggle needs nonnegative amplitude, positive period/whole frame step, and a finite seed" end
    if typeof(axes) ~= "Vector3" or not finite(axes.X) or not finite(axes.Y) or not finite(axes.Z) then return refs, "Wiggle axes must be a finite Vector3" end
    local ranges, selectedSet = {}, {}
    for _, entry in ipairs(editable(selected)) do
        if entry.track.valueType ~= "number" and entry.track.valueType ~= "Vector3" and entry.track.valueType ~= "CFrame" then return refs, "Wiggle supports number, Vector3, and CFrame tracks" end
        local range = ranges[entry.track]
        if not range then range = {first = entry.key.frame, last = entry.key.frame, keys = {}}; ranges[entry.track] = range end
        range.first, range.last = math.min(range.first, entry.key.frame), math.max(range.last, entry.key.frame)
        table.insert(range.keys, entry.key)
        selectedSet[entry.key] = true
    end
    local estimated = 0
    for _, range in pairs(ranges) do
        if range.last == range.first then return refs, "Select at least two different frames on each Wiggle track" end
        estimated = estimated + math.floor((range.last - range.first) / step) + 2 + #range.keys
    end
    if estimated == 0 then return refs, "No unlocked keyframes are selected" end
    if estimated > Engine.operationCapacity then return refs, "Wiggle exceeds the 120000-key operation budget; increase the frame step" end
    local additions, updates, result = {}, {}, {}
    for _, track in ipairs(project.tracks) do
        local range = ranges[track]
        if range then
            local wanted, existing = {[range.last] = true}, {}
            for frame = range.first, range.last, step do wanted[frame] = true end
            for _, key in ipairs(range.keys) do wanted[key.frame] = true end
            for _, key in ipairs(track.keys) do existing[key.frame] = key end
            local frames = {}
            for frame in pairs(wanted) do table.insert(frames, frame) end
            table.sort(frames)
            for _, frame in ipairs(frames) do
                local key = existing[frame]
                if key and (not selectedSet[key] or key.locked) then return refs, "An unselected or locked key occupies a Wiggle sample; include it in the selection or change the frame step" end
                local base = Engine.sample(track, frame)
                local envelope = (frame == range.first or frame == range.last) and 0 or math.sin(math.pi * (frame - range.first) / (range.last - range.first))
                local function wave(axis)
                    local phase = seed * 1.61803398875 + axis * 2.39996322973
                    local time = (frame - range.first) / period
                    return amplitude * envelope * (math.sin(time * 2 * math.pi + phase) * 0.75 + math.sin(time * 2 * math.pi / 0.53 + phase * 1.37) * 0.25)
                end
                local value
                if track.valueType == "number" then value = base + wave(1)
                else
                    local offset = Vector3.new(wave(1) * axes.X, wave(2) * axes.Y, wave(3) * axes.Z)
                    if track.valueType=="Vector3"then value=base+offset
                    elseif mode=="Rotation"then value=base*CFrame.Angles(math.rad(offset.X),math.rad(offset.Y),math.rad(offset.Z))
                    else value=base*CFrame.new(offset)end
                end
                local ok, encoded = pcall(Engine.encode, value, track.valueType)
                if not ok then return refs, "Wiggle produced a nonfinite value; reduce amplitude or axes" end
                if key then table.insert(updates, {key = key, value = encoded})
                else
                    key = {id = id("key"), frame = frame, value = encoded, easing = "Linear", direction = "InOut"}
                    table.insert(additions, {track = track, key = key})
                end
                table.insert(result, {trackId = track.id, keyId = key.id})
            end
        end
    end
    -- Supported Wiggle types have no sequence-union failure after this point.
    local _, problem = commitAdditions(additions)
    if problem then return refs, problem end
    for _, update in ipairs(updates) do
        update.key.value, update.key.easing, update.key.direction, update.key.parameters = update.value, "Linear", "InOut", nil
    end
    return result
end

return Engine
