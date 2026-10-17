-- Real Studio checks for adornments, coordinate conversion and drag lifecycle.
local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local function near(a, b) return math.abs(a - b) < 0.0001 end
local function same(a, b)
    local aa, bb = { a:GetComponents() }, { b:GetComponents() }
    for i = 1, 12 do if not near(aa[i], bb[i]) then return false end end
    return true
end
local function rayAt(point) return Ray.new(point + Vector3.new(0, 0, 20), Vector3.new(0, 0, -1)) end
local fixture = Instance.new("Model")
fixture.Name = "KeynovaGizmoTest"
fixture.Parent = workspace
local function part(name, frame)
    local object = Instance.new("Part")
    object.Name = name
    object.Anchored = true
    object.CFrame = frame or CFrame.new()
    object.Parent = fixture
    return object
end
local camera = workspace.CurrentCamera
local cameraBefore = camera.CFrame
camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 20), Vector3.new())
local commits, committed = 0, nil
local gizmo = Gizmo.new(plugin, function(value) commits = commits + 1; committed = value end)
local target = part("Part")
local binding = { instance = target, property = "CFrame", base = target.CFrame }
check(gizmo:set(binding, {}, CFrame.new(), "Move", { constantSize = false, alwaysOnTop = false, showOrigin = true }), "Part binding accepts native gizmos")
check(#gizmo.folder:GetChildren() == 10, "All owned move, ring and origin adornments exist")
check(gizmo.move[1].shaft.Visible and not gizmo.rings[1].Visible and gizmo.origin.Visible, "Mode and origin options affect real adornment visibility")
check(not gizmo.move[1].shaft.AlwaysOnTop and not gizmo.rings[1].AlwaysOnTop, "Depth option updates native adornments")

gizmo:set(binding, {}, CFrame.new(), "Move", { world = true, increment = true, translationStep = 0.5 })
check(gizmo:_begin(1, rayAt(Vector3.new())), "Axis drag starts from an unambiguous ray")
check(gizmo.Dragging and gizmo:_drag(rayAt(Vector3.new(1.26, 0, 0))), "Dragging state owns live pointer preview")
check(near(target.Position.X, 1.5), "Movement snaps in studs before committing")
gizmo:_draw()
check(near((target.CFrame * gizmo.origin.CFrame).X, target.Position.X), "Origin geometry follows the live preview position")
gizmo:_finish(true)
check(commits == 1 and near(committed.X, 1.5) and not gizmo.Dragging, "Changed gesture commits once and clears dragging")
gizmo:_finish(true)
check(commits == 1, "Repeated release cannot commit twice")

local beforeCancel = target.CFrame
gizmo:set(binding, {}, beforeCancel, "Move", {})
gizmo:_begin(1, rayAt(beforeCancel.Position))
gizmo:_drag(rayAt(beforeCancel.Position + Vector3.new(2, 0, 0)))
gizmo:cancel()
check(same(target.CFrame, beforeCancel) and commits == 1 and not gizmo.Dragging, "Cancellation restores actual pre-drag transform without commit")
gizmo:_begin(1, rayAt(beforeCancel.Position))
gizmo:_drag(rayAt(beforeCancel.Position + Vector3.new(2, 0, 0)))
gizmo:set(binding, {}, beforeCancel, "Rotate", {})
check(same(target.CFrame, beforeCancel) and not gizmo.Dragging, "Rebinding cancels and restores an active gesture")

target.CFrame = CFrame.new()
gizmo:set(binding, {}, CFrame.new(), "Rotate", { world = true, increment = true, rotationStep = 30 })
check(gizmo:_begin(3, rayAt(Vector3.new(1, 0, 0))), "Rotation begins on the selected axis plane")
gizmo:_drag(rayAt(Vector3.new(0.05, 1, 0)))
check(same(target.CFrame, CFrame.Angles(0, 0, math.pi / 2)), "Rotation step is in degrees and applies to native CFrame")
gizmo:_finish(true)
check(commits == 2 and same(committed, target.CFrame), "Rotation commits the preview value")

local parent = part("MotorParent", CFrame.new(10, 0, 0) * CFrame.Angles(0, 0, math.pi / 2))
local child = part("MotorChild")
local motor = Instance.new("Motor6D")
motor.Part0, motor.Part1, motor.C0, motor.Parent = parent, child, CFrame.new(0, 2, 0), parent
local motorBase = motor.C0
local motorBinding = { instance = motor, property = "C0", base = motorBase }
local origin = (parent.CFrame * motorBase).Position
gizmo:set(motorBinding, {}, CFrame.new(), "Move", { world = false })
gizmo:_begin(1, rayAt(origin))
gizmo:_drag(rayAt(origin + Vector3.new(0, 2, 0)))
check(same(motor.C0, motorBase * CFrame.new(2, 0, 0)), "Local joint movement respects rotated Part0 and base offset")
gizmo:_finish(true)
check(same(committed, CFrame.new(2, 0, 0)), "Motor commit stays relative to binding.base")
motor.C0 = motorBase
gizmo:set(motorBinding, {}, CFrame.new(), "Move", { world = true })
gizmo:_begin(1, rayAt(origin))
gizmo:_drag(rayAt(origin + Vector3.new(2, 0, 0)))
check(same(motor.C0, motorBase * CFrame.new(0, -2, 0)), "World joint movement converts into the rotated local base")
gizmo:clear()
check(same(motor.C0, motorBase), "Clear cancels and restores Motor6D preview")
local released = true
for _, object in ipairs(gizmo.geometry) do if object.Adornee ~= nil then released = false end end
check(released and gizmo.binding == nil, "Clear releases all target references while retaining reusable geometry")

local mesh = Instance.new("MeshPart")
mesh.Anchored, mesh.CFrame, mesh.Parent = true, CFrame.new(-5, 0, 0), fixture
local bone = Instance.new("Bone")
bone.CFrame, bone.Transform, bone.Parent = CFrame.new(0, 2, 0), CFrame.new(0.25, 0, 0), mesh
local boneBase = bone.Transform
local boneOrigin = bone.TransformedWorldCFrame.Position
gizmo:set({ instance = bone, property = "Transform", base = boneBase }, {}, CFrame.new(), "Move", { constantSize = false })
check(gizmo.move[1].shaft.Adornee == mesh, "Bone handles adorn their BasePart ancestor")
gizmo:_begin(1, rayAt(boneOrigin))
gizmo:_drag(rayAt(boneOrigin + Vector3.new(1, 0, 0)))
check(same(bone.Transform, boneBase * CFrame.new(1, 0, 0)), "Bone preview retains rest transform")
gizmo:cancel()
check(same(bone.Transform, boneBase), "Bone cancellation restores the captured property")

local model = Instance.new("Model")
model.Parent = fixture
local modelPart = part("ModelPart", CFrame.new(0, 4, 0))
modelPart.Parent = model
model.PrimaryPart = modelPart
local pivot = model:GetPivot()
gizmo:set({ instance = model, property = "Pivot", base = pivot }, {}, pivot, "Move", { world = true })
gizmo:_begin(1, rayAt(pivot.Position))
gizmo:_drag(rayAt(pivot.Position + Vector3.new(3, 0, 0)))
check(near(model:GetPivot().X, pivot.X + 3), "Model preview uses PivotTo")
gizmo:clear()
check(same(model:GetPivot(), pivot), "Model clear restores its captured pivot")

target.CFrame = CFrame.new()
camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 1), Vector3.new())
gizmo:set(binding, {}, CFrame.new(), "Rotate", { constantSize = true, showOrigin = false })
local radius = gizmo.rings[1].Radius
camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 2), Vector3.new())
gizmo:_draw()
check(near(gizmo.rings[1].Radius / radius, 2), "Constant screen size scales geometry with camera depth")
check(not gizmo.origin.Visible, "Origin display can be disabled")
camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -20), Vector3.new(0, 0, -40))
gizmo:_draw()
check(not gizmo.rings[1].Visible, "Behind-camera geometry is hidden")
camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 20), Vector3.new())
gizmo:set(binding, { locked = true }, CFrame.new(), "Move", {})
check(not gizmo:_begin(1, rayAt(Vector3.new())), "Locked tracks cannot start a gesture")
gizmo:set(binding, {}, CFrame.new(), "Move", {})
check(not gizmo:_begin(3, Ray.new(Vector3.new(0, 0, 20), Vector3.new(0, 0, -1))), "Parallel-axis rays reject rather than producing invalid movement")
gizmo:_begin(1, rayAt(Vector3.new()))
gizmo:_drag(rayAt(Vector3.new(2, 0, 0)))
local beforeDestroy = commits
gizmo:destroy()
gizmo:destroy()
check(same(target.CFrame, CFrame.new()) and commits == beforeDestroy, "Destroy cancels an active preview without a final key")
check(gizmo.folder.Parent == nil and #gizmo.connections == 0 and not gizmo.Dragging, "Idempotent destruction releases geometry and all connections")
fixture:Destroy()
camera.CFrame = cameraBefore
print("KEYNOVA_GIZMO_PARITY_PASS " .. checks .. " checks")
