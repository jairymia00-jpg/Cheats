
-- JAILBIRD | ENEMY OUTLINES + HEALTH
-- LocalScript in StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Me = Players.LocalPlayer

local markers = {}
local connections = {}
local red = Color3.fromRGB(255, 75, 90)

local function remove(player)
    local data = markers[player]
    if not data then return end

    data.Highlight:Destroy()
    data.Tag:Destroy()
    markers[player] = nil
end

local function isEnemy(player)
    if player == Me then return false end

    -- Unknown teams are not treated as enemies.
    if not Me.Team or not player.Team then
        return false
    end

    return Me.Team ~= player.Team
end

local function createMarker(player, character, head)
    local highlight = Instance.new("Highlight")
    highlight.Name = "EnemyOutline"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.FillTransparency = 0.85
    highlight.OutlineTransparency = 0
    highlight.FillColor = red
    highlight.OutlineColor = red
    highlight.Parent = character

    local tag = Instance.new("BillboardGui")
    tag.Name = "EnemyInfo"
    tag.Adornee = head
    tag.Size = UDim2.fromOffset(150, 52)
    tag.StudsOffset = Vector3.new(0, 2.8, 0)
    tag.AlwaysOnTop = false
    tag.MaxDistance = 250
    tag.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 30)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.25
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.Parent = tag

    local background = Instance.new("Frame")
    background.Position = UDim2.fromOffset(15, 34)
    background.Size = UDim2.new(1, -30, 0, 5)
    background.BackgroundColor3 = Color3.fromRGB(65, 30, 35)
    background.BorderSizePixel = 0
    background.Parent = tag

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = Color3.fromRGB(70, 240, 125)
    fill.BorderSizePixel = 0
    fill.Parent = background

    markers[player] = {
        Character = character,
        Highlight = highlight,
        Tag = tag,
        Label = label,
        Fill = fill
    }
end

local function update()
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        local humanoid = character and
            character:FindFirstChildOfClass("Humanoid")

        local valid = isEnemy(player)
            and head
            and humanoid
            and humanoid.Health > 0

        local data = markers[player]

        if data and (not valid or data.Character ~= character) then
            remove(player)
            data = nil
        end

        if valid then
            if not data then
                createMarker(player, character, head)
                data = markers[player]
            end

            local root = Me.Character and
                Me.Character:FindFirstChild("HumanoidRootPart")

            local distance = root and
                math.floor((root.Position - head.Position).Magnitude)
                or 0

            local hp = math.clamp(
                humanoid.Health / math.max(humanoid.MaxHealth, 1),
                0, 1
            )

            data.Label.Text = string.format(
                "%s | %d studs | %d HP",
                player.DisplayName,
                distance,
                math.ceil(humanoid.Health)
            )

            data.Fill.Size = UDim2.fromScale(hp, 1)
            data.Fill.BackgroundColor3 = Color3.fromRGB(
                math.floor(255 * (1 - hp)),
                math.floor(255 * hp),
                70
            )
        end
    end
end

table.insert(connections, Players.PlayerRemoving:Connect(remove))

local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed >= 0.1 then
        elapsed = 0
        update()
    end
end))

update()
print("Enemy outlines and health loaded")
