-- Compact native Studio controls shared by Keynova's floating windows.
local Gui = {}

local palettes = {
    Default = {
        background = Color3.fromRGB(33, 33, 33),
        panel = Color3.fromRGB(33, 33, 33),
        title = Color3.fromRGB(108, 113, 117),
        border = Color3.fromRGB(70, 74, 76),
        text = Color3.fromRGB(178, 187, 193),
        muted = Color3.fromRGB(108, 113, 117),
        accent = Color3.fromRGB(174, 102, 66),
        cyan = Color3.fromRGB(178, 187, 193),
        key = Color3.fromRGB(23, 101, 184),
    },
    Midnight = {
        background = Color3.fromRGB(18, 22, 60),
        panel = Color3.fromRGB(23, 29, 66),
        title = Color3.fromRGB(53, 143, 175),
        border = Color3.fromRGB(49, 113, 142),
        text = Color3.fromRGB(213, 224, 233),
        muted = Color3.fromRGB(134, 159, 180),
        accent = Color3.fromRGB(174, 114, 52),
        cyan = Color3.fromRGB(53, 156, 189),
        key = Color3.fromRGB(214, 145, 58),
    },
}

Gui.colors = {}

local paletteKeys = {}
for key in pairs(palettes.Default) do
    table.insert(paletteKeys, key)
end
table.sort(paletteKeys)

function Gui.themeNames()
    local names = {}
    for name in pairs(palettes) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function Gui.theme(name)
    local palette = palettes[name] or palettes.Default
    -- Preserve the shared table identity; callers redraw existing controls.
    for key, color in pairs(palette) do
        Gui.colors[key] = color
    end
    return Gui.colors
end

Gui.theme("Default")

-- Plain RGB data is suitable for JSON and Plugin settings; it contains no
-- Color3 values and does not share mutable arrays with the active palette.
function Gui.exportTheme()
    local result = {}
    for _, key in ipairs(paletteKeys) do
        local color = Gui.colors[key]
        result[key] = {
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5),
        }
    end
    return result
end

-- Imported themes must supply every supported color as exactly three integer
-- RGB channels in 0..255. Validate everything before changing shared state.
function Gui.importTheme(map)
    if type(map) ~= "table" or getmetatable(map) ~= nil then
        return false, "A theme must be a plain map of color names to RGB arrays."
    end
    for key in pairs(map) do
        if palettes.Default[key] == nil then
            return false, "Unknown theme color: " .. tostring(key)
        end
    end

    local pending = {}
    for _, key in ipairs(paletteKeys) do
        local channels = map[key]
        if type(channels) ~= "table" or getmetatable(channels) ~= nil then
            return false, "Theme color " .. key .. " needs an RGB array."
        end
        local count = 0
        for index in pairs(channels) do
            if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > 3 then
                return false, "Theme color " .. key .. " needs exactly three RGB channels."
            end
            count = count + 1
        end
        if count ~= 3 then
            return false, "Theme color " .. key .. " needs exactly three RGB channels."
        end
        for index = 1, 3 do
            local channel = channels[index]
            if type(channel) ~= "number" or channel ~= channel or channel < 0 or channel > 255 or channel % 1 ~= 0 then
                return false, "Theme color " .. key .. " channels must be integers from 0 to 255."
            end
        end
        pending[key] = Color3.fromRGB(channels[1], channels[2], channels[3])
    end

    for _, key in ipairs(paletteKeys) do
        Gui.colors[key] = pending[key]
    end
    return true
end

function Gui.make(class, props, parent)
    local object = Instance.new(class)
    if class == "ScrollingFrame" then
        object.ScrollBarImageColor3 = Gui.colors.title
        object.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
        object.BottomImage = object.TopImage
    end
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    if parent ~= nil then
        object.Parent = parent
    end
    return object
end

local function alignment(value)
    if type(value) == "string" then
        return Enum.TextXAlignment[value]
    end
    return value or Enum.TextXAlignment.Left
end

local function font(value)
    if type(value) == "string" then
        return Enum.Font[value]
    end
    return value or Enum.Font.SourceSans
end

function Gui.label(parent, text, x, y, w, h, options)
    options = options or {}
    return Gui.make("TextLabel", {
        Name = "Label",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        Font = font(options.font),
        Text = tostring(text or ""),
        TextColor3 = options.color or Gui.colors.text,
        TextSize = options.size or 12,
        TextXAlignment = alignment(options.align),
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end

function Gui.button(parent, text, x, y, w, h, callback, options)
    options = options or {}
    local button = Gui.make("TextButton", {
        Name = "Button",
        AutoButtonColor = false,
        BackgroundColor3 = Gui.colors.background,
        BackgroundTransparency = options.flat and 1 or 0,
        BorderColor3 = options.selected and Gui.colors.accent or Gui.colors.title,
        BorderSizePixel = options.flat and 0 or 1,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        Font = Enum.Font.SourceSans,
        Text = tostring(text or ""),
        TextColor3 = options.color or (options.selected and Gui.colors.accent or Gui.colors.text),
        TextSize = options.size or 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)

    button.MouseEnter:Connect(function()
        button.TextColor3 = options.color or Gui.colors.accent
        if not options.flat then
            button.BorderColor3 = Gui.colors.cyan
        end
    end)
    button.MouseLeave:Connect(function()
        button.TextColor3 = options.color or (options.selected and Gui.colors.accent or Gui.colors.text)
        button.BorderColor3 = options.selected and Gui.colors.accent or Gui.colors.title
    end)
    if callback then
        button.Activated:Connect(callback)
    end
    return button
end

function Gui.field(parent, text, x, y, w, h, callback, options)
    options = options or {}
    local field = Gui.make("TextBox", {
        Name = "Field",
        BackgroundColor3 = Gui.colors.background,
        BorderColor3 = Gui.colors.title,
        BorderSizePixel = 1,
        ClearTextOnFocus = false,
        MultiLine = options.multiline == true,
        PlaceholderText = options.placeholder or "",
        PlaceholderColor3 = Gui.colors.muted,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        Font = Enum.Font.SourceSans,
        Text = tostring(text or ""),
        TextColor3 = Gui.colors.text,
        TextSize = options.size or 12,
        TextWrapped = options.multiline == true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = options.multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
    }, parent)
    Gui.make("UIPadding", {
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
        PaddingTop = UDim.new(0, options.multiline and 3 or 0),
        PaddingBottom = UDim.new(0, options.multiline and 3 or 0),
    }, field)
    field.Focused:Connect(function()
        field.BorderColor3 = Gui.colors.cyan
    end)
    field.FocusLost:Connect(function()
        field.BorderColor3 = Gui.colors.title
        if callback then
            callback(field.Text)
        end
    end)
    return field
end

function Gui.check(parent, text, checked, x, y, w, callback)
    local value = checked == true
    local button = Gui.button(parent, "", x, y, w, 20, nil, { flat = true })
    button.Name = "Checkbox"
    local box = Gui.make("TextLabel", {
        Name = "Indicator",
        BackgroundColor3 = Gui.colors.background,
        BorderColor3 = Gui.colors.border,
        BorderSizePixel = 1,
        Position = UDim2.fromOffset(1, 4),
        Size = UDim2.fromOffset(12, 12),
        Font = Enum.Font.SourceSans,
        TextSize = 14,
        TextColor3 = Gui.colors.background,
    }, button)
    Gui.label(button, text, 20, 0, math.max(0, w - 20), 20)
    local function paint()
        box.BackgroundColor3 = value and Gui.colors.text or Gui.colors.background
        box.Text = value and "\226\156\147" or ""
    end
    paint()
    button.Activated:Connect(function()
        value = not value
        paint()
        if callback then
            callback(value)
        end
    end)
    return button
end

function Gui.dialog(plugin, id, title, width, height)
    local info = DockWidgetPluginGuiInfo.new(
        Enum.InitialDockState.Float,
        true,
        true,
        width,
        height,
        width,
        height
    )
    local widget = plugin:CreateDockWidgetPluginGuiAsync(id, info)
    widget.Title = title
    widget.Name = id
    widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local body = Gui.make("Frame", {
        Name = "Body",
        BackgroundColor3 = Gui.colors.background,
        BorderColor3 = Gui.colors.border,
        BorderSizePixel = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromScale(1, 1),
    }, widget)
    return widget, body
end

function Gui.section(parent, title, x, y, w, h)
    local frame = Gui.make("Frame", {
        Name = "Section",
        BackgroundColor3 = Gui.colors.background,
        BackgroundTransparency = 1,
        BorderColor3 = Gui.colors.border,
        BorderSizePixel = 1,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
    }, parent)
    local label = Gui.label(frame, title, 7, -9, math.min(w - 14, #tostring(title or "") * 7 + 10), 18, {
        color = Gui.colors.muted,
    })
    label.BackgroundColor3 = Gui.colors.background
    label.BackgroundTransparency = 0
    return frame, label
end

function Gui.clear(parent)
    for _, child in ipairs(parent:GetChildren()) do
        child:Destroy()
    end
end

return Gui
