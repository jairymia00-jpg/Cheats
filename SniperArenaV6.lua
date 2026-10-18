
-- SNIPER ARENA V6 | VISUAL SYSTEM
-- LocalScript: StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if _G.SniperV6Cleanup then
    _G.SniperV6Cleanup()
end

local settings = {
    Enabled = true,
    Highlights = true,
    Names = true,
    Tracers = true,
    FOV = true,
    TeamCheck = true,
    Radius = 150
}

local connections = {}
local markers = {}

local function create(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local gui = create("ScreenGui", PlayerGui, {
    Name = "SniperArenaV6",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999
})

local panel = create("Frame", gui, {
    Size = UDim2.fromOffset(270, 365),
    Position = UDim2.fromOffset(25, 120),
    BackgroundColor3 = Color3.fromRGB(17, 17, 29),
    BorderSizePixel = 0,
    Active = true,
    Draggable = true
})

create("UICorner", panel, {
    CornerRadius = UDim.new(0, 12)
})

create("UIStroke", panel, {
    Color = Color3.fromRGB(155, 105, 255),
    Thickness = 2
})

create("TextLabel", panel, {
    Size = UDim2.new(1, 0, 0, 45),
    BackgroundTransparency = 1,
    Text = "SNIPER ARENA  |  V6",
    TextColor3 = Color3.fromRGB(195, 165, 255),
    TextSize = 18,
    Font = Enum.Font.GothamBold
})

local function button(label, y, callback)
    local b = create("TextButton", panel, {
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.fromOffset(12, y),
        BackgroundColor3 = Color3.fromRGB(42, 36, 66),
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        Text = label,
        BorderSizePixel = 0
    })

    create("UICorner", b, {
        CornerRadius = UDim.new(0, 7)
    })

    b.MouseButton1Click:Connect(function()
        callback(b)
    end)

    return b
end

local function toggle(key, label, y)
    button(label .. ": ON", y, function(b)
        settings[key] = not settings[key]
        b.Text = label .. ": " .. (settings[key] and "ON" or "OFF")
    end)
end

toggle("Enabled", "MASTER ESP", 50)
toggle("Highlights", "HIGHLIGHTS", 94)
toggle("Names", "NAME TAGS", 138)
toggle("Tracers", "TARGET LINE", 182)
toggle("FOV", "FOV CIRCLE", 226)

button("FOV SIZE: 150", 270, function(b)
    settings.Radius += 25
    if settings.Radius > 300 then
        settings.Radius = 75
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
    Color = Color3.fromRGB(175, 120, 255),
    Thickness = 2
})

local line = create("Frame", gui, {
    AnchorPoint = Vector2.new(0, .5),
    BackgroundColor3 = Color3.fromRGB(180, 125, 255),
    BorderSizePixel = 0,
    Visible = false
})

local targetDot = create("Frame", gui, {
    Size = UDim2.fromOffset(10, 10),
    AnchorPoint = Vector2.new(.5, .5),
    BackgroundColor3 = Color3.fromRGB(255, 100, 140),
    BorderSizePixel = 0,
    Visible = false
})

create("UICorner", targetDot, {
    CornerRadius = UDim.new(1, 0)
})

local function removeMarker(player)
    local data = markers[player]
    if not data then return end

    data.highlight:Destroy()
    data.tag:Destroy()
    markers[player] = nil
end

local function eligible(player)
    if player == LocalPlayer then return false end

    if settings.TeamCheck and LocalPlayer.Team and player.Team then
        if LocalPlayer.Team == player.Team then
            return false
        end
    end

    return true
end

local function updateMarkers()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local head = character and character:FindFirstChild("Head")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local data = markers[player]

            if data and data.character ~= character then
                removeMarker(player)
                data = nil
            end

            local valid = settings.Enabled
                and eligible(player)
                and head
                and humanoid
                and humanoid.Health > 0

            if not valid then
                removeMarker(player)
            else
                if not data then
                    local highlight = create("Highlight", character, {
                        Adornee = character,
                        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                        FillTransparency = .65,
                        OutlineTransparency = 0
                    })

                    local tag = create("BillboardGui", head, {
                        Adornee = head,
                        Size = UDim2.fromOffset(160, 40),
                        StudsOffset = Vector3.new(0, 2.5, 0),
                        AlwaysOnTop = true
                    })

                    local text = create("TextLabel", tag, {
                        Size = UDim2.fromScale(1, 1),
                        BackgroundTransparency = 1,
                        TextColor3 = Color3.new(1, 1, 1),
                        TextStrokeTransparency = .2,
                        TextSize = 13,
                        Font = Enum.Font.GothamBold
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
                    and player.TeamColor.Color
                    or Color3.fromRGB(255, 85, 125)

                data.highlight.FillColor = color
                data.highlight.OutlineColor = color
                data.highlight.Enabled = settings.Highlights
                data.tag.Enabled = settings.Names

                local root = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

                local distance = root
                    and math.floor((root.Position - head.Position).Magnitude)
                    or 0

                data.text.Text = player.DisplayName .. " | " .. distance .. " studs"
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
        removeMarker(player)
    end

    gui:Destroy()
    _G.SniperV6Cleanup = nil
end

_G.SniperV6Cleanup = cleanup

button("REMOVE V6", 314, function()
    cleanup()
end)

table.insert(connections, Players.PlayerRemoving:Connect(removeMarker))

table.insert(connections, Input.InputBegan:Connect(function(key, processed)
    if not processed and key.KeyCode == Enum.KeyCode.F1 then
        panel.Visible = not panel.Visible
    end
end))

local elapsed = 0

table.insert(connections, RunService.RenderStepped:Connect(function(dt)
    local camera = workspace.CurrentCamera
    if not camera then return end

    elapsed += dt
    if elapsed >= .2 then
        elapsed = 0
        updateMarkers()
    end

    local mouse = Input:GetMouseLocation()

    circle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
    circle.Size = UDim2.fromOffset(settings.Radius * 2, settings.Radius * 2)
    circle.Visible = settings.Enabled and settings.FOV

    local bestHead = nil
    local bestDistance = settings.Radius

    if settings.Enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if eligible(player) then
                local character = player.Character
                local head = character and character:FindFirstChild("Head")
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                if head and humanoid and humanoid.Health > 0 then
                    local point, visible = camera:WorldToViewportPoint(head.Position)

                    if visible and point.Z > 0 then
                        local screenPoint = Vector2.new(point.X, point.Y)
                        local distance = (screenPoint - mouse).Magnitude

                        if distance < bestDistance then
                            bestDistance = distance
                            bestHead = head
                        end
                    end
                end
            end
        end
    end

    line.Visible = settings.Enabled and settings.Tracers and bestHead ~= nil
    targetDot.Visible = settings.Enabled and bestHead ~= nil

    if bestHead then
        local point = camera:WorldToViewportPoint(bestHead.Position)
        local destination = Vector2.new(point.X, point.Y)
        local delta = destination - mouse

        targetDot.Position = UDim2.fromOffset(destination.X, destination.Y)

        line.Position = UDim2.fromOffset(mouse.X, mouse.Y)
        line.Size = UDim2.fromOffset(delta.Magnitude, 2)
        line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    end
end))

updateMarkers()
print("SNIPER ARENA V6 LOADED")
