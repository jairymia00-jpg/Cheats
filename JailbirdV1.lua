
-- JAILBIRD V1 | ENEMY VISION
-- Purple menu, enemy ESP, health, FOV and visible-target indicator
-- No automatic aiming or firing

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local Me = Players.LocalPlayer
if not Me then return end

local PlayerGui = Me:WaitForChild("PlayerGui")

-- Clean up earlier runs
if type(_G.JailbirdVisionCleanup) == "function" then
    pcall(_G.JailbirdVisionCleanup)
end

local connections = {}
local markers = {}
local running = true

local S = {
    ESP = true,
    Names = true,
    Health = true,
    Distance = true,
    FOV = true,
    Target = true,
    Radius = 150,
    MaxDistance = 2000
}

local PURPLE = Color3.fromRGB(150, 85, 255)
local RED = Color3.fromRGB(255, 65, 85)
local WHITE = Color3.fromRGB(255, 255, 255)

local function make(class, properties, parent)
    local object = Instance.new(class)

    for key, value in pairs(properties) do
        object[key] = value
    end

    object.Parent = parent
    return object
end

local gui = make("ScreenGui", {
    Name = "JailbirdVisionV1",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, PlayerGui)

local menu = make("Frame", {
    Size = UDim2.fromOffset(290, 410),
    Position = UDim2.fromOffset(25, 100),
    BackgroundColor3 = Color3.fromRGB(22, 18, 35),
    BorderSizePixel = 0,
    Visible = true
}, gui)

make("UICorner", {
    CornerRadius = UDim.new(0, 12)
}, menu)

make("UIStroke", {
    Color = PURPLE,
    Thickness = 2
}, menu)

make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 45),
    BackgroundTransparency = 1,
    Text = "JAILBIRD V1  |  F1",
    TextColor3 = WHITE,
    Font = Enum.Font.GothamBold,
    TextSize = 18
}, menu)

local content = make("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 48),
    Size = UDim2.new(1, -24, 1, -60),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, menu)

make("UIListLayout", {
    Padding = UDim.new(0, 7)
}, content)

local function newButton(text)
    local button = make("TextButton", {
        Size = UDim2.new(1, -5, 0, 34),
        BackgroundColor3 = Color3.fromRGB(40, 33, 60),
        BorderSizePixel = 0,
        TextColor3 = WHITE,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        Text = text
    }, content)

    make("UICorner", {
        CornerRadius = UDim.new(0, 7)
    }, button)

    return button
end

local function toggle(label, key)
    local button = newButton("")

    local function refresh()
        button.Text = label .. ": " ..
            (S[key] and "ON" or "OFF")

        button.TextColor3 = S[key] and PURPLE or WHITE
    end

    table.insert(connections,
        button.MouseButton1Click:Connect(function()
            S[key] = not S[key]
            refresh()
        end)
    )

    refresh()
end

toggle("Enemy ESP", "ESP")
toggle("Player Names", "Names")
toggle("Health Bars", "Health")
toggle("Distance", "Distance")
toggle("FOV Circle", "FOV")
toggle("Visible Target Indicator", "Target")

local radiusButton = newButton("")

local function refreshRadius()
    radiusButton.Text = "FOV Radius: " .. S.Radius .. " px"
end

table.insert(connections,
    radiusButton.MouseButton1Click:Connect(function()
        S.Radius += 25
        if S.Radius > 400 then
            S.Radius = 75
        end
        refreshRadius()
    end)
)

refreshRadius()

local distanceButton = newButton("")

local function refreshDistance()
    distanceButton.Text = "Display Range: " ..
        S.MaxDistance .. " studs"
end

table.insert(connections,
    distanceButton.MouseButton1Click:Connect(function()
        S.MaxDistance += 500
        if S.MaxDistance > 5000 then
            S.MaxDistance = 500
        end
        refreshDistance()
    end)
)

refreshDistance()

table.insert(connections,
    UIS.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.F1 then
            menu.Visible = not menu.Visible
        end
    end)
)

-- FOV circle
local ring = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1
}, gui)

make("UICorner", {
    CornerRadius = UDim.new(1, 0)
}, ring)

make("UIStroke", {
    Color = PURPLE,
    Thickness = 1.5
}, ring)

-- Visible target label
local targetLabel = make("TextLabel", {
    Size = UDim2.fromOffset(260, 30),
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = Color3.fromRGB(30, 24, 45),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    TextColor3 = WHITE,
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    Visible = false
}, gui)

make("UICorner", {
    CornerRadius = UDim.new(0, 8)
}, targetLabel)

local function enemy(player)
    if player == Me then return false end
    if not Me.Team or not player.Team then return false end
    return Me.Team ~= player.Team
end

local function removeMarker(player)
    local data = markers[player]
    if not data then return end

    if data.highlight then
        data.highlight:Destroy()
    end

    if data.tag then
        data.tag:Destroy()
    end

    markers[player] = nil
end

local function createMarker(player, character, head)
    local highlight = make("Highlight", {
        Name = "JailbirdEnemyOutline",
        Adornee = character,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        FillColor = RED,
        OutlineColor = RED,
        FillTransparency = 0.85,
        OutlineTransparency = 0
    }, character)

    local tag = make("BillboardGui", {
        Name = "JailbirdEnemyInfo",
        Adornee = head,
        Size = UDim2.fromOffset(190, 58),
        StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
        AlwaysOnTop = true,
        MaxDistance = S.MaxDistance
    }, head)

    local info = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        TextColor3 = WHITE,
        TextStrokeTransparency = 0.2,
        TextSize = 12,
        TextWrapped = true,
        Font = Enum.Font.GothamBold
    }, tag)

    local bg = make("Frame", {
        Position = UDim2.fromOffset(15, 39),
        Size = UDim2.new(1, -30, 0, 6),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(75, 30, 35)
    }, tag)

    local fill = make("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(70, 240, 110)
    }, bg)

    markers[player] = {
        character = character,
        highlight = highlight,
        tag = tag,
        info = info,
        bg = bg,
        fill = fill
    }
end

-- Wall check applies ONLY to target indication
local function visible(character, part, camera)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances =
        Me.Character and {Me.Character} or {}
    params.IgnoreWater = true

    local origin = camera.CFrame.Position
    local direction = part.Position - origin

    local hit = workspace:Raycast(origin, direction, params)

    return not hit or hit.Instance:IsDescendantOf(character)
end

local function update()
    local camera = workspace.CurrentCamera
    if not camera then return end

    local center = camera.ViewportSize / 2

    ring.Size = UDim2.fromOffset(
        S.Radius * 2,
        S.Radius * 2
    )
    ring.Position = UDim2.fromOffset(center.X, center.Y)
    ring.Visible = S.FOV

    targetLabel.Position = UDim2.fromOffset(
        center.X,
        center.Y + S.Radius + 12
    )
    targetLabel.Visible = false

    local root = Me.Character and
        Me.Character:FindFirstChild("HumanoidRootPart")

    local closest = nil
    local closestScreenDistance = S.Radius

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        local humanoid = character and
            character:FindFirstChildOfClass("Humanoid")

        local valid = enemy(player)
            and head ~= nil
            and humanoid ~= nil
            and humanoid.Health > 0

        local data = markers[player]

        if data and (
            not valid or data.character ~= character
        ) then
            removeMarker(player)
            data = nil
        end

        if valid then
            if not data then
                createMarker(player, character, head)
                data = markers[player]
            end

            local distance = root and
                (root.Position - head.Position).Magnitude
                or math.huge

            -- ESP is independent of FOV and wall checks
            data.highlight.Enabled = S.ESP
            data.tag.Enabled = S.ESP and
                (S.Names or S.Health or S.Distance)

            data.tag.MaxDistance = S.MaxDistance
            data.bg.Visible = S.Health

            local hp = math.clamp(
                humanoid.Health /
                math.max(humanoid.MaxHealth, 1),
                0, 1
            )

            data.fill.Size = UDim2.fromScale(hp, 1)
            data.fill.BackgroundColor3 = Color3.fromRGB(
                math.floor(255 * (1 - hp)),
                math.floor(255 * hp),
                65
            )

            local textParts = {}

            if S.Names then
                table.insert(textParts, player.DisplayName)
            end

            if S.Distance and distance < math.huge then
                table.insert(textParts,
                    math.floor(distance) .. " studs")
            end

            if S.Health then
                table.insert(textParts,
                    math.ceil(humanoid.Health) .. " HP")
            end

            data.info.Text = table.concat(textParts, " | ")

            -- Only visible enemies within FOV are indicated
            if S.Target and S.FOV then
                local point, onScreen =
                    camera:WorldToViewportPoint(head.Position)

                if onScreen and point.Z > 0 then
                    local dx = point.X - center.X
                    local dy = point.Y - center.Y
                    local screenDistance =
                        math.sqrt(dx * dx + dy * dy)

                    if screenDistance <= closestScreenDistance
                        and visible(character, head, camera) then
                        closestScreenDistance = screenDistance
                        closest = player
                    end
                end
            end
        end
    end

    if closest then
        targetLabel.Text = "VISIBLE: " .. closest.DisplayName
        targetLabel.Visible = true
    end
end

local function cleanup()
    if not running then return end
    running = false

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    for player in pairs(markers) do
        removeMarker(player)
    end

    gui:Destroy()
end

_G.JailbirdVisionCleanup = cleanup

table.insert(connections,
    Players.PlayerRemoving:Connect(removeMarker)
)

local elapsed = 0

table.insert(connections,
    RunService.Heartbeat:Connect(function(dt)
        if not running then return end

        elapsed += dt
        if elapsed >= 0.1 then
            elapsed = 0
            update()
        end
    end)
)

update()
print("Jailbird Vision V1 loaded | F1 menu")
