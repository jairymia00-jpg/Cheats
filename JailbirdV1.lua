
-- JAILBIRD V2 | PURPLE ESP SYSTEM
-- LocalScript: StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local Me = Players.LocalPlayer
local PG = Me:WaitForChild("PlayerGui")

if _G.JailbirdV2Stop then
    _G.JailbirdV2Stop()
end

local S = {
    Enabled = true,
    Boxes = true,
    Names = true,
    Health = true,
    Distance = true,
    Tracers = true,
    FOV = true,
    TeamCheck = true,
    Radius = 160,
    Thickness = 2
}

local purple = Color3.fromRGB(165, 110, 255)
local white = Color3.fromRGB(245, 245, 255)
local dark = Color3.fromRGB(17, 17, 29)
local panelColor = Color3.fromRGB(35, 32, 55)

local connections = {}
local visuals = {}

local function new(class, parent, props)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local gui = new("ScreenGui", PG, {
    Name = "JailbirdV2",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999
})

local panel = new("Frame", gui, {
    Size = UDim2.fromOffset(290, 425),
    Position = UDim2.fromOffset(35, 110),
    BackgroundColor3 = dark,
    BorderSizePixel = 0,
    Active = true,
    Draggable = true
})

new("UICorner", panel, {
    CornerRadius = UDim.new(0, 12)
})

new("UIStroke", panel, {
    Color = purple,
    Thickness = 2
})

new("TextLabel", panel, {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundTransparency = 1,
    Text = "JAILBIRD  V2",
    TextColor3 = purple,
    Font = Enum.Font.GothamBold,
    TextSize = 21
})

new("TextLabel", panel, {
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.fromOffset(0, 42),
    BackgroundTransparency = 1,
    Text = "VISUAL CONTROL SYSTEM",
    TextColor3 = Color3.fromRGB(145, 140, 170),
    Font = Enum.Font.Gotham,
    TextSize = 10
})

local function button(text, y, callback)
    local b = new("TextButton", panel, {
        Size = UDim2.new(1, -24, 0, 33),
        Position = UDim2.fromOffset(12, y),
        BackgroundColor3 = panelColor,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = white,
        Font = Enum.Font.GothamBold,
        TextSize = 12
    })

    new("UICorner", b, {
        CornerRadius = UDim.new(0, 7)
    })

    b.MouseButton1Click:Connect(function()
        callback(b)
    end)

    return b
end

local function toggle(key, title, y)
    button(title .. ": ON", y, function(b)
        S[key] = not S[key]
        b.Text = title .. ": " ..
            (S[key] and "ON" or "OFF")
    end)
end

toggle("Enabled", "MASTER ESP", 68)
toggle("Boxes", "2D BOXES", 107)
toggle("Names", "PLAYER NAMES", 146)
toggle("Health", "HEALTH BARS", 185)
toggle("Tracers", "TARGET LINES", 224)
toggle("FOV", "FOV CIRCLE", 263)
toggle("TeamCheck", "TEAM FILTER", 302)

button("FOV RADIUS: 160", 341, function(b)
    S.Radius += 20
    if S.Radius > 300 then
        S.Radius = 80
    end
    b.Text = "FOV RADIUS: " .. S.Radius
end)

local circle = new("Frame", gui, {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(.5, .5)
})

new("UICorner", circle, {
    CornerRadius = UDim.new(1, 0)
})

new("UIStroke", circle, {
    Color = purple,
    Thickness = 2
})

local tracer = new("Frame", gui, {
    AnchorPoint = Vector2.new(0, .5),
    BackgroundColor3 = purple,
    BorderSizePixel = 0,
    Visible = false
})

local targetDot = new("Frame", gui, {
    Size = UDim2.fromOffset(9, 9),
    AnchorPoint = Vector2.new(.5, .5),
    BackgroundColor3 = Color3.fromRGB(255, 95, 125),
    BorderSizePixel = 0,
    Visible = false
})

new("UICorner", targetDot, {
    CornerRadius = UDim.new(1, 0)
})

local function eligible(player)
    if player == Me then
        return false
    end

    if S.TeamCheck and Me.Team and player.Team then
        return Me.Team ~= player.Team
    end

    return true
end

local function createVisual(player)
    local root = new("Frame", gui, {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false
    })

    local box = new("Frame", root, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1
    })

    local stroke = new("UIStroke", box, {
        Color = purple,
        Thickness = S.Thickness
    })

    local name = new("TextLabel", root, {
        Size = UDim2.new(1, 50, 0, 20),
        Position = UDim2.new(0, -25, 0, -23),
        BackgroundTransparency = 1,
        TextColor3 = white,
        TextStrokeTransparency = .25,
        Font = Enum.Font.GothamBold,
        TextSize = 12
    })

    local healthBG = new("Frame", root, {
        Size = UDim2.new(0, 5, 1, 0),
        Position = UDim2.fromOffset(-10, 0),
        BackgroundColor3 = Color3.fromRGB(60, 25, 30),
        BorderSizePixel = 0
    })

    local healthFill = new("Frame", healthBG, {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(75, 255, 140),
        BorderSizePixel = 0
    })

    visuals[player] = {
        Root = root,
        Box = box,
        Stroke = stroke,
        Name = name,
        HealthBG = healthBG,
        HealthFill = healthFill
    }

    return visuals[player]
end

local function removeVisual(player)
    local data = visuals[player]
    if data then
        data.Root:Destroy()
        visuals[player] = nil
    end
end

local function screenBounds(character, camera)
    local cf, size = character:GetBoundingBox()

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    local half = size * .5

    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local corner = cf:PointToWorldSpace(
                    Vector3.new(
                        half.X * x,
                        half.Y * y,
                        half.Z * z
                    )
                )

                local point = camera:WorldToViewportPoint(corner)

                if point.Z <= 0 then
                    return nil
                end

                minX = math.min(minX, point.X)
                minY = math.min(minY, point.Y)
                maxX = math.max(maxX, point.X)
                maxY = math.max(maxY, point.Y)
            end
        end
    end

    return minX, minY, maxX, maxY
end

local function updatePlayer(player, camera)
    if not S.Enabled or not eligible(player) then
        if visuals[player] then
            visuals[player].Root.Visible = false
        end
        return
    end

    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    local humanoid = character and
        character:FindFirstChildOfClass("Humanoid")

    if not head or not humanoid or humanoid.Health <= 0 then
        if visuals[player] then
            visuals[player].Root.Visible = false
        end
        return
    end

    local minX, minY, maxX, maxY =
        screenBounds(character, camera)

    local data = visuals[player] or createVisual(player)

    if not minX then
        data.Root.Visible = false
        return
    end

    local width = maxX - minX
    local height = maxY - minY

    if width <= 0 or height <= 0 then
        data.Root.Visible = false
        return
    end

    data.Root.Visible = true
    data.Root.Position = UDim2.fromOffset(minX, minY)
    data.Root.Size = UDim2.fromOffset(width, height)

    data.Box.Visible = S.Boxes
    data.Name.Visible = S.Names
    data.HealthBG.Visible = S.Health

    local color = player.Team
        and player.TeamColor.Color
        or purple

    data.Stroke.Color = color

    local myRoot = Me.Character and
        Me.Character:FindFirstChild("HumanoidRootPart")

    local distance = myRoot and
        math.floor((myRoot.Position - head.Position).Magnitude)
        or 0

    data.Name.Text = player.DisplayName

    if S.Distance then
        data.Name.Text ..= " | " .. distance .. "m"
    end

    local ratio = math.clamp(
        humanoid.Health / math.max(humanoid.MaxHealth, 1),
        0,
        1
    )

    data.HealthFill.Size = UDim2.fromScale(1, ratio)

    data.HealthFill.BackgroundColor3 =
        Color3.fromRGB(
            math.floor(255 * (1 - ratio)),
            math.floor(255 * ratio),
            75
        )
end

local function cleanup()
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    for player in pairs(visuals) do
        removeVisual(player)
    end

    gui:Destroy()
    _G.JailbirdV2Stop = nil
end

_G.JailbirdV2Stop = cleanup

button("REMOVE JAILBIRD V2", 380, function()
    cleanup()
end)

table.insert(connections,
    Players.PlayerRemoving:Connect(removeVisual)
)

table.insert(connections,
    UIS.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.F1 then
            panel.Visible = not panel.Visible
        end
    end)
)

local elapsed = 0

table.insert(connections,
    RunService.RenderStepped:Connect(function(dt)
        local camera = workspace.CurrentCamera
        if not camera then return end

        local mouse = UIS:GetMouseLocation()

        circle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
        circle.Size = UDim2.fromOffset(
            S.Radius * 2,
            S.Radius * 2
        )

        circle.Visible = S.Enabled and S.FOV

        elapsed += dt

        if elapsed >= .05 then
            elapsed = 0

            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= Me then
                    updatePlayer(player, camera)
                end
            end
        end

        local closest = nil
        local closestDistance = S.Radius

        if S.Enabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if eligible(player) then
                    local character = player.Character
                    local head = character and
                        character:FindFirstChild("Head")

                    local humanoid = character and
                        character:FindFirstChildOfClass("Humanoid")

                    if head and humanoid and humanoid.Health > 0 then
                        local point, visible =
                            camera:WorldToViewportPoint(head.Position)

                        if visible and point.Z > 0 then
                            local position = Vector2.new(
                                point.X,
                                point.Y
                            )

                            local distance =
                                (position - mouse).Magnitude

                            if distance < closestDistance then
                                closestDistance = distance
                                closest = position
                            end
                        end
                    end
                end
            end
        end

        tracer.Visible =
            S.Enabled and S.Tracers and closest ~= nil

        targetDot.Visible =
            S.Enabled and closest ~= nil

        if closest then
            local delta = closest - mouse

            targetDot.Position = UDim2.fromOffset(
                closest.X,
                closest.Y
            )

            tracer.Position = UDim2.fromOffset(
                mouse.X,
                mouse.Y
            )

            tracer.Size = UDim2.fromOffset(
                delta.Magnitude,
                2
            )

            tracer.Rotation = math.deg(
                math.atan2(delta.Y, delta.X)
            )
        end
    end)
)

-- SKELETON ESP | R15 CHARACTERS
local skeletons = {}

local bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local targetPart = "Head"

local function drawSkeleton(player, camera)
    local character = player.Character
    if not character then return end

    if not skeletons[player] then
        skeletons[player] = {}

        for i = 1, #bones do
            local line = Instance.new("Frame")
            line.AnchorPoint = Vector2.new(0, .5)
            line.BackgroundColor3 = Color3.fromRGB(175, 115, 255)
            line.BorderSizePixel = 0
            line.Visible = false
            line.Parent = gui

            skeletons[player][i] = line
        end
    end

    for i, pair in ipairs(bones) do
        local line = skeletons[player][i]
        local a = character:FindFirstChild(pair[1])
        local b = character:FindFirstChild(pair[2])

        line.Visible = false

        if a and b then
            local p1, v1 = camera:WorldToViewportPoint(a.Position)
            local p2, v2 = camera:WorldToViewportPoint(b.Position)

            if v1 and v2 and p1.Z > 0 and p2.Z > 0 then
                local start = Vector2.new(p1.X, p1.Y)
                local finish = Vector2.new(p2.X, p2.Y)
                local delta = finish - start

                line.Position = UDim2.fromOffset(start.X, start.Y)
                line.Size = UDim2.fromOffset(delta.Magnitude, 2)
                line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                line.Visible = true
            end
        end
    end
end

print("JAILBIRD V2 LOADED SUCCESSFULLY")
