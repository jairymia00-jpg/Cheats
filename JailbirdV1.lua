
-- JAILBIRD V1 | PURPLE VISUAL SYSTEM
-- Place in StarterPlayer > StarterPlayerScripts
-- LocalScript for your own Roblox Studio experience

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")

local Me = Players.LocalPlayer
local PlayerGui = Me:WaitForChild("PlayerGui")

if _G.JailbirdV1Stop then
    _G.JailbirdV1Stop()
end

local settings = {
    ESP = true,
    Names = true,
    Distance = true,
    FOV = true,
    Tracers = true,
    TeamCheck = true,
    Radius = 160
}

local connections = {}
local markers = {}

local purple = Color3.fromRGB(155, 100, 255)
local dark = Color3.fromRGB(17, 18, 30)
local buttonColor = Color3.fromRGB(40, 36, 65)

local function create(class, parent, props)
    local obj = Instance.new(class)
    for key, value in pairs(props or {}) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local gui = create("ScreenGui", PlayerGui, {
    Name = "JailbirdV1",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999
})

local panel = create("Frame", gui, {
    Size = UDim2.fromOffset(280, 390),
    Position = UDim2.fromOffset(25, 110),
    BackgroundColor3 = dark,
    BorderSizePixel = 0,
    Active = true,
    Draggable = true
})

create("UICorner", panel, {
    CornerRadius = UDim.new(0, 12)
})

create("UIStroke", panel, {
    Color = purple,
    Thickness = 2
})

create("TextLabel", panel, {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundTransparency = 1,
    Text = "JAILBIRD  |  V1",
    TextColor3 = purple,
    Font = Enum.Font.GothamBold,
    TextSize = 20
})

local function button(text, y, callback)
    local b = create("TextButton", panel, {
        Size = UDim2.new(1, -24, 0, 38),
        Position = UDim2.fromOffset(12, y),
        BackgroundColor3 = buttonColor,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 13
    })

    create("UICorner", b, {
        CornerRadius = UDim.new(0, 8)
    })

    b.MouseButton1Click:Connect(function()
        callback(b)
    end)

    return b
end

local function toggle(key, label, y)
    button(label .. ": ON", y, function(b)
        settings[key] = not settings[key]
        b.Text = label .. ": " ..
            (settings[key] and "ON" or "OFF")
    end)
end

toggle("ESP", "PLAYER ESP", 55)
toggle("Names", "PLAYER NAMES", 100)
toggle("Distance", "DISTANCE", 145)
toggle("FOV", "FOV CIRCLE", 190)
toggle("Tracers", "TARGET LINES", 235)
toggle("TeamCheck", "TEAM CHECK", 280)

button("FOV SIZE: 160", 325, function(b)
    settings.Radius += 20

    if settings.Radius > 300 then
        settings.Radius = 80
    end

    b.Text = "FOV SIZE: " .. settings.Radius
end)

local circle = create("Frame", gui, {
    AnchorPoint = Vector2.new(.5, .5),
    BackgroundTransparency = 1
})

create("UICorner", circle, {
    CornerRadius = UDim.new(1, 0)
})

create("UIStroke", circle, {
    Color = purple,
    Thickness = 2
})

local line = create("Frame", gui, {
    AnchorPoint = Vector2.new(0, .5),
    BackgroundColor3 = purple,
    BorderSizePixel = 0,
    Visible = false
})

local dot = create("Frame", gui, {
    Size = UDim2.fromOffset(10, 10),
    AnchorPoint = Vector2.new(.5, .5),
    BackgroundColor3 = Color3.fromRGB(255, 100, 130),
    BorderSizePixel = 0,
    Visible = false
})

create("UICorner", dot, {
    CornerRadius = UDim.new(1, 0)
})

local function eligible(player)
    if player == Me then return false end

    if settings.TeamCheck and Me.Team and player.Team then
        return Me.Team ~= player.Team
    end

    return true
end

local function remove(player)
    local data = markers[player]
    if not data then return end

    data.highlight:Destroy()
    data.tag:Destroy()
    markers[player] = nil
end

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Me then
            local character = player.Character
            local head = character and character:FindFirstChild("Head")
            local humanoid = character and
                character:FindFirstChildOfClass("Humanoid")

            local data = markers[player]

            if data and data.character ~= character then
                remove(player)
                data = nil
            end

            if not settings.ESP or not eligible(player)
                or not head or not humanoid
                or humanoid.Health <= 0 then

                remove(player)
            else
                if not data then
                    local highlight = create("Highlight", character, {
                        Adornee = character,
                        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                        FillTransparency = .7,
                        OutlineTransparency = 0
                    })

                    local tag = create("BillboardGui", head, {
                        Adornee = head,
                        Size = UDim2.fromOffset(180, 42),
                        StudsOffset = Vector3.new(0, 2.5, 0),
                        AlwaysOnTop = true
                    })

                    local text = create("TextLabel", tag, {
                        Size = UDim2.fromScale(1, 1),
                        BackgroundTransparency = 1,
                        TextColor3 = Color3.new(1, 1, 1),
                        TextStrokeTransparency = .2,
                        Font = Enum.Font.GothamBold,
                        TextSize = 13
                    })

                    data = {
                        character = character,
                        highlight = highlight,
                        tag = tag,
                        text = text
                    }

                    markers[player] = data
                end

                local color = player.Team
                    and player.TeamColor.Color or purple

                data.highlight.FillColor = color
                data.highlight.OutlineColor = color
                data.tag.Enabled = settings.Names

                local root = Me.Character and
                    Me.Character:FindFirstChild("HumanoidRootPart")

                local distance = root and
                    math.floor((root.Position - head.Position).Magnitude)
                    or 0

                local label = player.DisplayName

                if settings.Distance then
                    label ..= " | " .. distance .. " studs"
                end

                data.text.Text = label
            end
        end
    end
end

local function cleanup()
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    local list = {}

    for player in pairs(markers) do
        table.insert(list, player)
    end

    for _, player in ipairs(list) do
        remove(player)
    end

    gui:Destroy()
    _G.JailbirdV1Stop = nil
end

_G.JailbirdV1Stop = cleanup

table.insert(connections,
    Players.PlayerRemoving:Connect(remove)
)

table.insert(connections,
    Input.InputBegan:Connect(function(key, processed)
        if not processed and key.KeyCode == Enum.KeyCode.F1 then
            panel.Visible = not panel.Visible
        end
    end)
)

local elapsed = 0

table.insert(connections,
    RunService.RenderStepped:Connect(function(dt)
        local camera = workspace.CurrentCamera
        if not camera then return end

        elapsed += dt

        if elapsed >= .2 then
            elapsed = 0
            updateESP()
        end

        local mouse = Input:GetMouseLocation()

        circle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
        circle.Size = UDim2.fromOffset(
            settings.Radius * 2,
            settings.Radius * 2
        )
        circle.Visible = settings.FOV

        local bestHead = nil
        local bestDistance = settings.Radius

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
                        local distance = (
                            Vector2.new(point.X, point.Y) - mouse
                        ).Magnitude

                        if distance < bestDistance then
                            bestDistance = distance
                            bestHead = head
                        end
                    end
                end
            end
        end

        line.Visible = settings.Tracers and bestHead ~= nil
        dot.Visible = bestHead ~= nil

        if bestHead then
            local point =
                camera:WorldToViewportPoint(bestHead.Position)

            local destination = Vector2.new(point.X, point.Y)
            local delta = destination - mouse

            dot.Position = UDim2.fromOffset(
                destination.X,
                destination.Y
            )

            line.Position = UDim2.fromOffset(
                mouse.X,
                mouse.Y
            )

            line.Size = UDim2.fromOffset(
                delta.Magnitude,
                2
            )

            line.Rotation = math.deg(
                math.atan2(delta.Y, delta.X)
            )
        end
    end)
)

updateESP()
print("JAILBIRD V1 LOADED")
