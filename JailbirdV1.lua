
-- ENEMY VISION V3 | Roblox Studio LocalScript
-- F1: Open/close menu
-- Visual target indicator only; no automatic aiming or firing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- Remove a previous copy of this UI if present
local previous = PlayerGui:FindFirstChild("EnemyVisionV3")
if previous then previous:Destroy() end

local Settings = {
    Enabled = true,
    Outlines = true,
    Health = true,
    Names = true,
    Distance = true,
    FOV = true,
    TargetIndicator = true,
    VisibleOnly = true,
    FOVRadius = 160,
    MaxDistance = 300
}

local Purple = Color3.fromRGB(140, 85, 255)
local Red = Color3.fromRGB(255, 75, 90)
local White = Color3.fromRGB(245, 245, 255)

local Gui = Instance.new("ScreenGui")
Gui.Name = "EnemyVisionV3"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.Parent = PlayerGui

local Menu = Instance.new("Frame")
Menu.Size = UDim2.fromOffset(280, 425)
Menu.Position = UDim2.new(0, 30, 0.5, -210)
Menu.BackgroundColor3 = Color3.fromRGB(19, 17, 29)
Menu.BorderSizePixel = 0
Menu.Parent = Gui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = Menu

local Stroke = Instance.new("UIStroke")
Stroke.Color = Purple
Stroke.Thickness = 2
Stroke.Parent = Menu

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 42)
Title.BackgroundTransparency = 1
Title.Text = "ENEMY VISION  |  F1"
Title.TextColor3 = White
Title.TextSize = 17
Title.Font = Enum.Font.GothamBold
Title.Parent = Menu

local Content = Instance.new("ScrollingFrame")
Content.Position = UDim2.fromOffset(12, 48)
Content.Size = UDim2.new(1, -24, 1, -60)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.CanvasSize = UDim2.new()
Content.Parent = Menu

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 7)
Layout.Parent = Content

local function addToggle(label, key)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -5, 0, 32)
    button.BackgroundColor3 = Color3.fromRGB(35, 31, 51)
    button.TextColor3 = White
    button.TextSize = 12
    button.Font = Enum.Font.GothamMedium
    button.Parent = Content

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)

    local function refresh()
        button.Text = label .. ": " ..
            (Settings[key] and "ON" or "OFF")
        button.TextColor3 = Settings[key] and Purple or White
    end

    button.MouseButton1Click:Connect(function()
        Settings[key] = not Settings[key]
        refresh()
    end)

    refresh()
end

local function addSlider(label, key, minValue, maxValue, step)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -5, 0, 32)
    button.BackgroundColor3 = Color3.fromRGB(35, 31, 51)
    button.TextColor3 = White
    button.TextSize = 12
    button.Font = Enum.Font.GothamMedium
    button.Parent = Content

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)

    local function refresh()
        button.Text = label .. ": " .. Settings[key] ..
            "  (+ click)"
    end

    button.MouseButton1Click:Connect(function()
        Settings[key] += step
        if Settings[key] > maxValue then
            Settings[key] = minValue
        end
        refresh()
    end)

    refresh()
end

addToggle("Master ESP", "Enabled")
addToggle("Enemy Outlines", "Outlines")
addToggle("Health Bar", "Health")
addToggle("Player Names", "Names")
addToggle("Distance", "Distance")
addToggle("FOV Circle", "FOV")
addToggle("Visible Target Indicator", "TargetIndicator")
addToggle("Visible Enemies Only", "VisibleOnly")
addSlider("FOV Radius", "FOVRadius", 80, 400, 40)
addSlider("Max Distance", "MaxDistance", 100, 1000, 100)

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        Menu.Visible = not Menu.Visible
    end
end)

-- Screen-center FOV ring
local FOVRing = Instance.new("Frame")
FOVRing.Name = "FOVRing"
FOVRing.AnchorPoint = Vector2.new(0.5, 0.5)
FOVRing.BackgroundTransparency = 1
FOVRing.Parent = Gui

Instance.new("UICorner", FOVRing).CornerRadius = UDim.new(1, 0)

local RingStroke = Instance.new("UIStroke")
RingStroke.Color = Purple
RingStroke.Thickness = 1.5
RingStroke.Transparency = 0.15
RingStroke.Parent = FOVRing

-- Indicator for a visible target within the FOV
local TargetLabel = Instance.new("TextLabel")
TargetLabel.Name = "VisibleTarget"
TargetLabel.Size = UDim2.fromOffset(260, 28)
TargetLabel.AnchorPoint = Vector2.new(0.5, 0)
TargetLabel.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
TargetLabel.BackgroundTransparency = 0.2
TargetLabel.TextColor3 = White
TargetLabel.TextSize = 13
TargetLabel.Font = Enum.Font.GothamBold
TargetLabel.Visible = false
TargetLabel.Parent = Gui

Instance.new("UICorner", TargetLabel).CornerRadius = UDim.new(0, 8)

local Markers = {}

local function isEnemy(player)
    if player == LocalPlayer then return false end
    if not LocalPlayer.Team or not player.Team then
        return false
    end
    return LocalPlayer.Team ~= player.Team
end

local function clearMarker(player)
    local marker = Markers[player]
    if not marker then return end

    marker.Highlight:Destroy()
    marker.Tag:Destroy()
    Markers[player] = nil
end

local function createMarker(player, character, head)
    local highlight = Instance.new("Highlight")
    highlight.Name = "EV_EnemyOutline"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.FillColor = Red
    highlight.OutlineColor = Red
    highlight.FillTransparency = 0.9
    highlight.OutlineTransparency = 0
    highlight.Parent = character

    local tag = Instance.new("BillboardGui")
    tag.Name = "EV_EnemyHealth"
    tag.Adornee = head
    tag.Size = UDim2.fromOffset(170, 56)
    tag.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
    tag.AlwaysOnTop = false
    tag.MaxDistance = Settings.MaxDistance
    tag.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 34)
    label.BackgroundTransparency = 1
    label.TextColor3 = White
    label.TextStrokeTransparency = 0.25
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.TextWrapped = true
    label.Parent = tag

    local healthBG = Instance.new("Frame")
    healthBG.Position = UDim2.fromOffset(15, 39)
    healthBG.Size = UDim2.new(1, -30, 0, 6)
    healthBG.BackgroundColor3 = Color3.fromRGB(70, 30, 35)
    healthBG.BorderSizePixel = 0
    healthBG.Parent = tag

    local healthFill = Instance.new("Frame")
    healthFill.Size = UDim2.fromScale(1, 1)
    healthFill.BackgroundColor3 = Color3.fromRGB(60, 240, 110)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBG

    Markers[player] = {
        Character = character,
        Highlight = highlight,
        Tag = tag,
        Label = label,
        HealthBG = healthBG,
        HealthFill = healthFill
    }
end

local function visible(character, part)
    local camera = workspace.CurrentCamera
    if not camera or not part then return false end

    local origin = camera.CFrame.Position
    local direction = part.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    if LocalPlayer.Character then
        params.FilterDescendantsInstances = {LocalPlayer.Character}
    end

    local hit = workspace:Raycast(origin, direction, params)
    return hit == nil or hit.Instance:IsDescendantOf(character)
end

local function update()
    local camera = workspace.CurrentCamera
    if not camera then return end

    local viewport = camera.ViewportSize
    local center = viewport / 2

    FOVRing.Position = UDim2.fromOffset(center.X, center.Y)
    FOVRing.Size = UDim2.fromOffset(
        Settings.FOVRadius * 2,
        Settings.FOVRadius * 2
    )
    FOVRing.Visible = Settings.Enabled and Settings.FOV

    TargetLabel.Position = UDim2.fromOffset(
        center.X, center.Y + Settings.FOVRadius + 12
    )
    TargetLabel.Visible = false

    local myRoot = LocalPlayer.Character and
        LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    local bestPlayer = nil
    local bestScreenDistance = Settings.FOVRadius

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        local humanoid = character and
            character:FindFirstChildOfClass("Humanoid")

        local enemy = isEnemy(player)
        local alive = humanoid and humanoid.Health > 0

        local valid = Settings.Enabled and enemy
            and character and head and alive

        local marker = Markers[player]

        if marker and
            (not valid or marker.Character ~= character) then
            clearMarker(player)
            marker = nil
        end

        if valid then
            local distance = myRoot and
                (myRoot.Position - head.Position).Magnitude
                or math.huge

            local onScreenPosition, onScreen =
                camera:WorldToViewportPoint(head.Position)

            local lineOfSight = visible(character, head)

            local show = onScreen
                and distance <= Settings.MaxDistance
                and (not Settings.VisibleOnly or lineOfSight)

            if show and not marker then
                createMarker(player, character, head)
                marker = Markers[player]
            end

            if marker then
                marker.Highlight.Enabled = show and Settings.Outlines
                marker.Tag.Enabled = show and (
                    Settings.Health or Settings.Names or Settings.Distance
                )
                marker.Tag.MaxDistance = Settings.MaxDistance
                marker.HealthBG.Visible = Settings.Health

                local hp = math.clamp(
                    humanoid.Health / math.max(humanoid.MaxHealth, 1),
                    0, 1
                )

                marker.HealthFill.Size = UDim2.fromScale(hp, 1)
                marker.HealthFill.BackgroundColor3 =
                    Color3.fromRGB(
                        math.floor(255 * (1 - hp)),
                        math.floor(255 * hp),
                        60
                    )

                local parts = {}

                if Settings.Names then
                    table.insert(parts, player.DisplayName)
                end
                if Settings.Distance then
                    table.insert(parts, math.floor(distance) .. " studs")
                end
                if Settings.Health then
                    table.insert(parts, math.ceil(humanoid.Health) .. " HP")
                end

                marker.Label.Text = table.concat(parts, " | ")
            end

            -- Only indicate visible, unobstructed targets
            if show and lineOfSight and Settings.TargetIndicator then
                local dx = onScreenPosition.X - center.X
                local dy = onScreenPosition.Y - center.Y
                local screenDistance = math.sqrt(dx * dx + dy * dy)

                if screenDistance < bestScreenDistance then
                    bestScreenDistance = screenDistance
                    bestPlayer = player
                end
            end
        end
    end

    if bestPlayer then
        TargetLabel.Text = "VISIBLE: " .. bestPlayer.DisplayName
        TargetLabel.Visible = true
    end
end

Players.PlayerRemoving:Connect(clearMarker)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt

    -- 10 updates per second to reduce CPU use
    if elapsed >= 0.1 then
        elapsed = 0
        update()
    end
end)

update()
print("Enemy Vision V3 loaded | F1 menu")
