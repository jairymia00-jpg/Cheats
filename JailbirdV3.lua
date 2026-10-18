-- Jailbird V3 | Visual overlay (no automatic aim or firing)
-- Designed for a Roblox client LocalScript in a game you control.
-- F1 toggles the purple menu. Does not alter existing teammate indicators.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local me = Players.LocalPlayer
assert(me, "This script requires a client LocalScript")
local playerGui = me:WaitForChild("PlayerGui")

-- Clear a previous V3 instance before creating new objects.
if type(_G.JBV3Stop) == "function" then pcall(_G.JBV3Stop) end
local previous = playerGui:FindFirstChild("JBV3_GUI")
if previous then previous:Destroy() end

local active = true
local connections, objects = {}, {}
local cfg = {
    ESP = true, Boxes = true, Silhouette = true,
    Health = true, Names = true, Distance = true,
    FOV = true, VisibleTarget = true,
    Radius = 150, Range = 2500
}
local purple = Color3.fromRGB(155, 94, 255)
local red = Color3.fromRGB(255, 65, 85)
local white = Color3.fromRGB(245, 245, 255)

local function mk(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do obj[key] = value end
    obj.Parent = parent
    return obj
end
local gui = mk("ScreenGui", {
    Name = "JBV3_GUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 999, Enabled = true
}, playerGui)
local menu = mk("Frame", {
    Name = "Menu", Size = UDim2.fromOffset(300, 450),
    Position = UDim2.fromOffset(25, 90), BackgroundColor3 = Color3.fromRGB(21, 18, 34),
    BorderSizePixel = 0, Visible = true
}, gui)
mk("UICorner", {CornerRadius = UDim.new(0, 11)}, menu)
mk("UIStroke", {Color = purple, Thickness = 2}, menu)
mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1,
    Text = "JAILBIRD V3 | F1", Font = Enum.Font.GothamBold,
    TextSize = 18, TextColor3 = white
}, menu)
local scroller = mk("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 45), Size = UDim2.new(1, -24, 1, -58),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0, 0)
}, menu)
mk("UIListLayout", {Padding = UDim.new(0, 7)}, scroller)
local function button(text)
    local b = mk("TextButton", {
        Size = UDim2.new(1, -5, 0, 32), BackgroundColor3 = Color3.fromRGB(39, 33, 59),
        BorderSizePixel = 0, Text = text, TextColor3 = white,
        Font = Enum.Font.GothamMedium, TextSize = 12
    }, scroller)
    mk("UICorner", {CornerRadius = UDim.new(0, 7)}, b)
    return b
end
local function toggle(label, key)
    local b = button("")
    local function refresh()
        b.Text = label .. ": " .. (cfg[key] and "ON" or "OFF")
        b.TextColor3 = cfg[key] and purple or white
    end
    table.insert(connections, b.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        refresh()
    end))
    refresh()
end
for _, item in ipairs({
    {"Enemy ESP", "ESP"}, {"Thin Boxes", "Boxes"},
    {"Body Outlines", "Silhouette"}, {"Health", "Health"},
    {"Names", "Names"}, {"Distance", "Distance"},
    {"FOV Circle", "FOV"}, {"Visible Target", "VisibleTarget"}
}) do toggle(item[1], item[2]) end
local radiusButton = button("")
local function radiusText() radiusButton.Text = "FOV radius: " .. cfg.Radius .. " px (click)" end
radiusText()
table.insert(connections, radiusButton.MouseButton1Click:Connect(function()
    cfg.Radius = cfg.Radius + 25
    if cfg.Radius > 400 then cfg.Radius = 75 end
    radiusText()
end))
local rangeButton = button("")
local function rangeText() rangeButton.Text = "Info range: " .. cfg.Range .. " studs (click)" end
rangeText()
table.insert(connections, rangeButton.MouseButton1Click:Connect(function()
    cfg.Range = cfg.Range + 500
    if cfg.Range > 5000 then cfg.Range = 500 end
    rangeText()
end))
local status = mk("TextLabel", {
    Size = UDim2.new(1, -5, 0, 42), BackgroundTransparency = 1,
    Text = "Ready | F1 to hide menu", TextColor3 = white,
    TextSize = 11, TextWrapped = true
}, scroller)
table.insert(connections, UIS.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.F1 then
        menu.Visible = not menu.Visible
    end
end))

local circle = mk("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1
}, gui)
mk("UICorner", {CornerRadius = UDim.new(1, 0)}, circle)
mk("UIStroke", {Color = purple, Thickness = 1.5}, circle)
local target = mk("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(250, 27),
    BackgroundColor3 = Color3.fromRGB(30, 23, 48), BackgroundTransparency = 0.15,
    TextColor3 = white, Font = Enum.Font.GothamBold, TextSize = 12,
    Visible = false
}, gui)
mk("UICorner", {CornerRadius = UDim.new(0, 7)}, target)

local function remove(player)
    local data = objects[player]
    if not data then return end
    if data.highlight then data.highlight:Destroy() end
    if data.box then data.box:Destroy() end
    if data.billboard then data.billboard:Destroy() end
    objects[player] = nil
end

-- Conservative enemy check: unknown team assignments are not guessed.
local function enemy(player)
    if player == me then return false end
    if me.Team and player.Team then return me.Team ~= player.Team end
    if not me.Neutral and not player.Neutral then
        return me.TeamColor ~= player.TeamColor
    end
    return false
end

local function create(player, character, head, root)
    local hl = mk("Highlight", {
        Name = "JBV3_BodyOutline", Adornee = character,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        FillColor = red, OutlineColor = red,
        FillTransparency = 0.93, OutlineTransparency = 0
    }, character)
    -- SelectionBox is attached to the root part to avoid invalid Adornee models.
    local box = mk("SelectionBox", {
        Name = "JBV3_ThinBox", Adornee = root,
        Color3 = red, LineThickness = 0.015, SurfaceTransparency = 1
    }, root)
    local billboard = mk("BillboardGui", {
        Name = "JBV3_Info", Adornee = head,
        Size = UDim2.fromOffset(195, 55),
        StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
        AlwaysOnTop = true, MaxDistance = cfg.Range
    }, head)
    local label = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
        TextColor3 = white, TextStrokeTransparency = 0.2,
        Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true
    }, billboard)
    local bar = mk("Frame", {
        Position = UDim2.fromOffset(18, 39), Size = UDim2.new(1, -36, 0, 6),
        BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(80, 35, 35)
    }, billboard)
    local fill = mk("Frame", {
        Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(60, 230, 100)
    }, bar)
    objects[player] = {
        character = character, highlight = hl, box = box,
        billboard = billboard, label = label, bar = bar, fill = fill
    }
    return objects[player]
end

local function lineOfSight(camera, character, part)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = me.Character and {me.Character} or {}
    params.IgnoreWater = true
    local origin = camera.CFrame.Position
    local hit = workspace:Raycast(origin, part.Position - origin, params)
    return not hit or hit.Instance:IsDescendantOf(character)
end

local function update()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local center = camera.ViewportSize / 2
    circle.Position = UDim2.fromOffset(center.X, center.Y)
    circle.Size = UDim2.fromOffset(cfg.Radius * 2, cfg.Radius * 2)
    circle.Visible = cfg.FOV
    target.Position = UDim2.fromOffset(center.X, center.Y + cfg.Radius + 10)
    target.Visible = false

    local myRoot = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
    local best, bestDist = nil, cfg.Radius
    local shown, unknownTeams = 0, 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= me then
            if not me.Team or not player.Team then unknownTeams = unknownTeams + 1 end
            local character = player.Character
            local head = character and character:FindFirstChild("Head")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            local valid = enemy(player) and head ~= nil and root ~= nil
                and hum ~= nil and hum.Health > 0
            local data = objects[player]
            if data and (not valid or data.character ~= character) then
                remove(player)
                data = nil
            end
            if valid then
                if not data then data = create(player, character, head, root) end
                local dist = myRoot and (myRoot.Position - head.Position).Magnitude or math.huge
                data.highlight.Enabled = cfg.ESP and cfg.Silhouette
                data.box.Visible = cfg.ESP and cfg.Boxes
                data.billboard.Enabled = cfg.ESP and dist <= cfg.Range
                    and (cfg.Health or cfg.Names or cfg.Distance)
                data.billboard.MaxDistance = cfg.Range
                data.bar.Visible = cfg.Health
                local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                data.fill.Size = UDim2.fromScale(hp, 1)
                data.fill.BackgroundColor3 = Color3.fromRGB(
                    math.floor(255 * (1 - hp)), math.floor(255 * hp), 65)
                local parts = {}
                if cfg.Names then table.insert(parts, player.DisplayName) end
                if cfg.Distance and dist < math.huge then
                    table.insert(parts, math.floor(dist) .. " studs")
                end
                if cfg.Health then table.insert(parts, math.ceil(hum.Health) .. " HP") end
                data.label.Text = table.concat(parts, " | ")
                if cfg.ESP then shown = shown + 1 end
                -- FOV affects the visible-target indicator only, never ESP.
                if cfg.VisibleTarget and cfg.FOV then
                    local point, onScreen = camera:WorldToViewportPoint(head.Position)
                    if onScreen and point.Z > 0 then
                        local screenDist = (Vector2.new(point.X, point.Y) - center).Magnitude
                        if screenDist < bestDist and lineOfSight(camera, character, head) then
                            bestDist = screenDist
                            best = player
                        end
                    end
                end
            end
        end
    end
    if best then
        target.Text = "VISIBLE: " .. best.DisplayName
        target.Visible = true
    end
    status.Text = "Enemy markers: " .. shown .. " | Team values missing: " .. unknownTeams
end

local function stop()
    if not active then return end
    active = false
    for _, conn in ipairs(connections) do conn:Disconnect() end
    for player in pairs(objects) do remove(player) end
    gui:Destroy()
end
_G.JBV3Stop = stop

table.insert(connections, Players.PlayerRemoving:Connect(remove))
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    if not active then return end
    elapsed = elapsed + dt
    if elapsed >= 0.1 then
        elapsed = 0
        local ok, err = pcall(update)
        if not ok then status.Text = "Update error: " .. tostring(err) end
    end
end))
local ok, err = pcall(update)
if not ok then status.Text = "Startup error: " .. tostring(err) end
print("Jailbird V3 visual overlay loaded | F1 menu")
