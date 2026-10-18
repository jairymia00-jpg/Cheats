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
    -- 2D box: calculate screen rectangle from the character bounding box each update.
    local box = mk("Frame", {
        Name = "JBV3_ThinBox", BackgroundTransparency = 1,
        BorderSizePixel = 0, Visible = false, ZIndex = 20
    }, gui)
    mk("UIStroke", {Color = red, Thickness = 1.5}, box)
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

local function updateBox(camera, character, box)
    local ok, cf, size = pcall(function()
        local c, sz = character:GetBoundingBox()
        return c, sz
    end)
    if not ok then box.Visible = false return end
    local loX, loY, hiX, hiY = math.huge, math.huge, -math.huge, -math.huge
    local visibleCorners = 0
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local point = cf:PointToWorldSpace(Vector3.new(x * size.X/2, y * size.Y/2, z * size.Z/2))
                local screen = camera:WorldToViewportPoint(point)
                if screen.Z > 0 then
                    visibleCorners = visibleCorners + 1
                    loX = math.min(loX, screen.X)
                    loY = math.min(loY, screen.Y)
                    hiX = math.max(hiX, screen.X)
                    hiY = math.max(hiY, screen.Y)
                end
            end
        end
    end
    if visibleCorners < 8 then box.Visible = false return end
    box.Position = UDim2.fromOffset(loX, loY)
    box.Size = UDim2.fromOffset(math.max(1, hiX-loX), math.max(1, hiY-loY))
    box.Visible = true
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
    local shown, unknownTeams, rejectedTeams, missingParts, dead = 0, 0, 0, 0, 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= me then
            if not me.Team or not player.Team then unknownTeams = unknownTeams + 1 end
            local character = player.Character
            local head = character and character:FindFirstChild("Head")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            local isEnemy = enemy(player)
            if not isEnemy then rejectedTeams = rejectedTeams + 1 end
            if not head or not root or not hum then missingParts = missingParts + 1 end
            if hum and hum.Health <= 0 then dead = dead + 1 end
            local valid = isEnemy and head ~= nil and root ~= nil
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
                if cfg.ESP and cfg.Boxes then
                    updateBox(camera, character, data.box)
                else
                    data.box.Visible = false
                end
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
    status.Text = "ESP: " .. shown .. " | No team: " .. unknownTeams
        .. " | Not enemy: " .. rejectedTeams .. " | Missing parts: " .. missingParts .. " | Dead: " .. dead
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
