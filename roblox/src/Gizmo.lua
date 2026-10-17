-- Independently authored Studio gizmos, using public HandleAdornment events.
-- This is not KojoGizmos code or a claim of identical visual behavior.
local Gizmo = {}
Gizmo.__index = Gizmo

local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local AXES = { Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1) }
local COLORS = { Color3.fromRGB(229, 83, 76), Color3.fromRGB(103, 196, 96), Color3.fromRGB(74, 143, 223) }
local HOVER = Color3.fromRGB(244, 194, 92)

local function positive(value, fallback, maximum)
    if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then return fallback end
    return math.min(value, maximum)
end

local function normalizedOptions(options)
    options = options or {}
    return {
        enabled = options.enabled ~= false,
        world = options.world == true,
        increment = options.increment == true,
        translationStep = positive(options.translationStep, 0.1, 10000),
        rotationStep = positive(options.rotationStep, 15, 360),
        constantSize = options.constantSize ~= false,
        alwaysOnTop = options.alwaysOnTop ~= false,
        showOrigin = options.showOrigin == true,
        size = positive(options.size, 1, 20),
    }
end

local function snapped(value, step)
    return math.floor(value / step + 0.5) * step
end

local function closeCFrame(a, b)
    local aa, bb = { a:GetComponents() }, { b:GetComponents() }
    for i = 1, 12 do if math.abs(aa[i] - bb[i]) > 0.000001 then return false end end
    return true
end

local function closestAxis(ray, origin, axis)
    local direction = ray.Direction.Unit
    local between = ray.Origin - origin
    local dot = axis:Dot(direction)
    local denominator = 1 - dot * dot
    if denominator < 0.00001 then return nil end
    return (axis:Dot(between) - dot * direction:Dot(between)) / denominator
end

local function planeVector(ray, origin, normal)
    local direction = ray.Direction.Unit
    local denominator = normal:Dot(direction)
    if math.abs(denominator) < 0.00001 then return nil end
    local distance = normal:Dot(origin - ray.Origin) / denominator
    if distance < 0 then return nil end
    local vector = ray.Origin + direction * distance - origin
    if vector.Magnitude < 0.00001 then return nil end
    return vector.Unit
end

local function isRelative(binding)
    return binding.instance:IsA("Motor6D") or binding.instance:IsA("Bone")
end

local function readActual(binding)
    if binding.property == "Pivot" then return binding.instance:GetPivot() end
    return binding.instance[binding.property]
end

local function writeActual(binding, value)
    if binding.property == "Pivot" then binding.instance:PivotTo(value)
    else binding.instance[binding.property] = value end
end

local function writeValue(binding, value)
    writeActual(binding, isRelative(binding) and binding.base * value or value)
end

local function referenceWorld(binding)
    local target = binding.instance
    if target:IsA("Motor6D") then
        if not target.Part0 then return nil end
        return target.Part0.CFrame
    elseif target:IsA("Bone") then
        -- Strip only this bone's current Transform; retain all parent poses.
        return target.TransformedWorldCFrame * target.Transform:Inverse()
    end
    return CFrame.new()
end

local function findAdornee(target)
    if target:IsA("Motor6D") then return target.Part0 or target.Part1 end
    if target:IsA("Bone") then return target:FindFirstAncestorWhichIsA("BasePart") end
    if target:IsA("BasePart") then return target end
    if target:IsA("Model") then return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true) end
    return nil
end

local function worldValue(binding, value)
    if not isRelative(binding) then return value end
    local reference = referenceWorld(binding)
    return reference and reference * binding.base * value or nil
end

function Gizmo.new(plugin, onCommit)
    local self = setmetatable({
        plugin = plugin,
        mouse = plugin:GetMouse(),
        onCommit = onCommit,
        connections = {},
        geometry = {},
        move = {},
        rings = {},
        options = normalizedOptions(),
        Dragging = false,
        destroyed = false,
    }, Gizmo)
    local folder = Instance.new("Folder")
    folder.Name = "KeynovaGizmo"
    folder.Parent = CoreGui
    self.folder = folder

    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(self.connections, connection)
        return connection
    end
    local function adorn(class, name, axis)
        local object = Instance.new(class)
        object.Name = name
        object.Visible = false
        object.ZIndex = 5
        object.Color3 = axis and COLORS[axis] or Color3.fromRGB(230, 230, 230)
        object.Parent = folder
        table.insert(self.geometry, object)
        if axis then
            connect(object.MouseButton1Down, function() self:_begin(axis) end)
            connect(object.MouseEnter, function()
                if not self.Dragging then self.hover = axis; self:_paint() end
            end)
            connect(object.MouseLeave, function()
                if self.hover == axis then self.hover = nil; self:_paint() end
            end)
        end
        return object
    end
    for axis = 1, 3 do
        self.move[axis] = {
            shaft = adorn("BoxHandleAdornment", "MoveAxis" .. axis, axis),
            tip = adorn("SphereHandleAdornment", "MoveTip" .. axis, axis),
        }
        local ring = adorn("CylinderHandleAdornment", "RotateAxis" .. axis, axis)
        ring.Angle = 360
        self.rings[axis] = ring
    end
    self.origin = adorn("SphereHandleAdornment", "Origin")

    connect(Input.InputChanged, function(input)
        if self.Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then self:_drag(self.mouse.UnitRay) end
    end)
    connect(Input.InputEnded, function(input)
        if self.Dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then self:_finish(true) end
    end)
    connect(Input.InputBegan, function(input)
        if self.Dragging and input.KeyCode == Enum.KeyCode.Escape then self:cancel() end
    end)
    connect(Input.WindowFocusReleased, function() self:cancel() end)
    connect(plugin.Deactivation, function() self:cancel() end)
    connect(RunService.RenderStepped, function() self:_draw() end)
    return self
end

function Gizmo:_hide()
    for _, object in ipairs(self.geometry) do object.Visible = false end
end

function Gizmo:_paint()
    local active = self.Dragging and self.drag.axis or self.hover
    for axis = 1, 3 do
        local color = active == axis and HOVER or COLORS[axis]
        self.move[axis].shaft.Color3 = color
        self.move[axis].tip.Color3 = color
        self.rings[axis].Color3 = color
    end
end

function Gizmo:_draw()
    if self.destroyed then return end
    local binding = self.binding
    if not binding or not binding.instance.Parent or not self.options.enabled or (self.track and self.track.locked) then
        if self.Dragging then self:cancel() end
        self:_hide()
        return
    end
    local adornee = findAdornee(binding.instance)
    local frame = worldValue(binding, self.Dragging and self.drag.preview or self.value)
    if not adornee or not frame then self:_hide(); return end
    local camera = workspace.CurrentCamera
    if not camera then self:_hide(); return end
    local depth = -camera.CFrame:PointToObjectSpace(frame.Position).Z
    if depth < math.max(0.05, math.abs(camera.NearPlaneZ)) then self:_hide(); return end
    local radius = self.options.size * 2.5
    if self.options.constantSize then
        -- Maintain a roughly 70-pixel radius using the camera's vertical FOV.
        radius = self.options.size * depth * 2 * math.tan(math.rad(camera.FieldOfView) / 2) * 70 / math.max(1, camera.ViewportSize.Y)
    end
    radius = math.clamp(radius, 0.025, 1000)
    local basis = self.options.world and CFrame.new(frame.Position) or frame
    local localBasis = adornee.CFrame:ToObjectSpace(basis)
    for axis = 1, 3 do
        local direction = AXES[axis]
        local shaft = self.move[axis].shaft
        shaft.Adornee = adornee
        shaft.AlwaysOnTop = self.options.alwaysOnTop
        shaft.Size = Vector3.new(radius * 0.025, radius * 0.025, radius * 0.86)
        shaft.CFrame = localBasis * CFrame.lookAt(direction * radius * 0.53, direction * radius * 1.1)
        shaft.Visible = self.mode == "Move"
        local tip = self.move[axis].tip
        tip.Adornee = adornee
        tip.AlwaysOnTop = self.options.alwaysOnTop
        tip.Radius = radius * 0.075
        tip.CFrame = localBasis * CFrame.new(direction * radius)
        tip.Visible = self.mode == "Move"
        local ring = self.rings[axis]
        ring.Adornee = adornee
        ring.AlwaysOnTop = self.options.alwaysOnTop
        ring.Radius = radius
        ring.InnerRadius = radius * 0.965
        ring.Height = math.max(0.002, radius * 0.015)
        ring.CFrame = localBasis * CFrame.lookAt(Vector3.new(), direction)
        ring.Visible = self.mode == "Rotate"
    end
    self.origin.Adornee = adornee
    self.origin.AlwaysOnTop = self.options.alwaysOnTop
    self.origin.Radius = radius * 0.045
    self.origin.CFrame = adornee.CFrame:ToObjectSpace(CFrame.new(frame.Position))
    self.origin.Visible = self.options.showOrigin
    self:_paint()
end

function Gizmo:set(binding, track, value, mode, options)
    if self.destroyed then return false, "The gizmo has been destroyed." end
    self:clear()
    self.options = normalizedOptions(options)
    if not binding or not binding.instance or typeof(value) ~= "CFrame" then self:_hide(); return false, "A CFrame binding is required." end
    local target = binding.instance
    local property = binding.property
    local supported = (target:IsA("Motor6D") and property == "C0")
        or (target:IsA("Bone") and property == "Transform")
        or (target:IsA("BasePart") and property == "CFrame")
        or (target:IsA("Model") and property == "Pivot")
    if not supported or not findAdornee(target) then self:_hide(); return false, "This binding has no supported transform handle." end
    if isRelative(binding) and typeof(binding.base) ~= "CFrame" then self:_hide(); return false, "Joint bindings require a CFrame base." end
    self.binding = { instance = target, property = property, base = binding.base }
    self.track = track
    self.value = value
    self.mode = mode == "Move" and "Move" or "Rotate"
    if track and track.locked then self.options.enabled = false end
    self:_draw()
    return true
end

function Gizmo:_begin(axis, ray)
    if self.destroyed or self.Dragging or not self.binding or not self.options.enabled or not AXES[axis] then return false end
    local binding = self.binding
    if not binding.instance.Parent or (self.track and self.track.locked) then return false end
    local world = worldValue(binding, self.value)
    local reference = referenceWorld(binding)
    if not world or not reference then return false end
    ray = ray or self.mouse.UnitRay
    local direction = self.options.world and AXES[axis] or world:VectorToWorldSpace(AXES[axis])
    local start
    if self.mode == "Move" then start = closestAxis(ray, world.Position, direction)
    else start = planeVector(ray, world.Position, direction) end
    if start == nil then return false end
    self.drag = {
        axis = axis, direction = direction, world = world, reference = reference,
        value = self.value, actual = readActual(binding), start = start, last = start,
        amount = 0, preview = self.value,
    }
    self.Dragging = true
    self:_paint()
    return true
end

function Gizmo:_drag(ray)
    if not self.Dragging then return false end
    local drag, binding = self.drag, self.binding
    if not binding or not binding.instance.Parent then self:cancel(); return false end
    local desired
    if self.mode == "Move" then
        local current = closestAxis(ray, drag.world.Position, drag.direction)
        if current == nil then return false end
        local amount = current - drag.start
        if self.options.increment then amount = snapped(amount, self.options.translationStep) end
        desired = drag.world + drag.direction * amount
    else
        local vector = planeVector(ray, drag.world.Position, drag.direction)
        if not vector then return false end
        drag.amount = drag.amount + math.atan2(drag.direction:Dot(drag.last:Cross(vector)), drag.last:Dot(vector))
        drag.last = vector
        local amount = drag.amount
        if self.options.increment then amount = snapped(amount, math.rad(self.options.rotationStep)) end
        desired = CFrame.new(drag.world.Position) * CFrame.fromAxisAngle(drag.direction, amount) * (drag.world - drag.world.Position)
    end
    local value = isRelative(binding) and binding.base:ToObjectSpace(drag.reference:ToObjectSpace(desired)) or desired
    writeValue(binding, value)
    drag.preview = value
    return true
end

function Gizmo:_finish(commit)
    if not self.Dragging then return end
    local drag, binding = self.drag, self.binding
    self.drag, self.Dragging = nil, false
    commit = commit and binding ~= nil and binding.instance.Parent ~= nil
    local changed = not closeCFrame(drag.value, drag.preview)
    if not commit or not changed then
        if binding and binding.instance.Parent then writeActual(binding, drag.actual) end
        self.value = drag.value
    else
        self.value = drag.preview
    end
    self:_draw()
    if commit and changed and self.onCommit then self.onCommit(drag.preview) end
end

function Gizmo:cancel()
    self:_finish(false)
end

function Gizmo:clear()
    if self.destroyed then return end
    self:cancel()
    self.binding, self.track, self.value, self.hover = nil, nil, nil, nil
    self:_hide()
    for _, object in ipairs(self.geometry) do object.Adornee = nil end
end

function Gizmo:destroy()
    if self.destroyed then return end
    self:clear()
    self.destroyed = true
    for _, connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections = {}
    self.folder:Destroy()
    self.geometry, self.move, self.rings = {}, {}, {}
    self.plugin, self.mouse, self.onCommit, self.origin = nil, nil, nil, nil
end

return Gizmo
