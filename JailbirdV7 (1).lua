-- Jailbird V7 | client-side visual overlay + circle-based camera aim assist.
-- F1: menu. F2: aim toggle. F3: auto-lock toggle. Rebind these in the menu.
-- Auto lock is on by default; turn it off to require RMB. F10: unload.
-- Run once after joining. Re-running replaces the previous copy.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
assert(LP, "Run this in the Roblox client")
local PlayerGui = LP:WaitForChild("PlayerGui")

if type(_G.JBV7Stop) == "function" then pcall(_G.JBV7Stop) end
if type(_G.JBV6Stop) == "function" then pcall(_G.JBV6Stop) end
local previous = PlayerGui:FindFirstChild("JBV7_GUI")
if previous then previous:Destroy() end

local C = {
    ESP = true, Allies = false, Boxes = true, Health = true, Names = true, Distance = true,
    Outlines = true, Skeleton = false, Tracers = false, FOV = true,
    Indicator = true, Headshot = true, Aim = true, AutoLock = true,
    NPCs = false, UnknownEnemy = false,
    Radius = 150, Range = 2500, AimSpeed = 13,
}
local COL = {
    bg = Color3.fromRGB(17, 20, 31), card = Color3.fromRGB(27, 34, 51),
    raised = Color3.fromRGB(37, 45, 66), accent = Color3.fromRGB(138, 111, 255),
    text = Color3.fromRGB(241, 244, 255), muted = Color3.fromRGB(161, 171, 195),
    enemy = Color3.fromRGB(255, 82, 107), ally = Color3.fromRGB(75, 170, 255),
    good = Color3.fromRGB(81, 209, 151),
}
local running = true
local connections, overlays, npcHumanoids = {}, {}, {}
local bestTarget, bestName, bestDistance, bestPlayer = nil, nil, nil, nil
local renderName = "JBV7_Render"
local aimName = "JBV7_Aim"

local function make(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do obj[key] = value end
    obj.Parent = parent
    return obj
end
local function corner(obj, r)
    make("UICorner", {CornerRadius = UDim.new(0, r)}, obj)
end
local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end
local function show(obj, on)
    if obj.Visible ~= on then obj.Visible = on end
end
local function aimingHeld()
    return C.AutoLock or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end
local function line(parent, width, color)
    return make("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(width, 1),
        BorderSizePixel = 0, BackgroundColor3 = color, Visible = false,
    }, parent)
end
local function placeLine(obj, a, b, width)
    local dx, dy = b.X - a.X, b.Y - a.Y
    obj.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    obj.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), width)
    obj.Rotation = math.deg(math.atan2(dy, dx))
    show(obj, true)
end

local gui = make("ScreenGui", {
    Name = "JBV7_GUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local menu = make("Frame", {
    Position = UDim2.fromOffset(28, 90), Size = UDim2.fromOffset(356, 485),
    BackgroundColor3 = COL.bg, BorderSizePixel = 0, Active = true,
}, gui)
corner(menu, 12)
make("UIStroke", {Color = COL.accent, Thickness = 1.3, Transparency = .35}, menu)
local title = make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 42), Position = UDim2.fromOffset(12, 5),
    BackgroundTransparency = 1, Text = "JAILBIRD V7    •    F1",
    TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold,
    TextSize = 17, TextColor3 = COL.text, Active = true,
}, menu)
local subtitle = make("TextLabel", {
    Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 0, 19),
    BackgroundTransparency = 1, Text = "Auto lock in circle  •  F1 menu  •  F10 unload",
    TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham,
    TextSize = 11, TextColor3 = COL.muted,
}, menu)
local scroll = make("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 74), Size = UDim2.new(1, -24, 1, -130),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
    ScrollBarImageColor3 = COL.accent, AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
}, menu)
make("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

local function button(label, order)
    local b = make("TextButton", {
        Size = UDim2.new(1, -5, 0, 31), LayoutOrder = order,
        Text = label, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = COL.card, BorderSizePixel = 0,
        TextColor3 = COL.text, Font = Enum.Font.GothamMedium, TextSize = 12,
        AutoButtonColor = true,
    }, scroll)
    corner(b, 6)
    make("UIPadding", {PaddingLeft = UDim.new(0, 10)}, b)
    return b
end
local order = 0
local togglePaint = {}
local function toggle(label, key)
    order += 1
    local b = button(label, order)
    local function paint()
        b.Text = label .. "     " .. (C[key] and "ON" or "OFF")
        b.BackgroundColor3 = C[key] and COL.raised or COL.card
        b.TextColor3 = C[key] and COL.text or COL.muted
    end
    connect(b.MouseButton1Click, function()
        C[key] = not C[key]
        if key == "NPCs" and C.NPCs then
            task.spawn(function()
                local list = workspace:GetDescendants()
                for i, obj in ipairs(list) do
                    if not running or not C.NPCs then return end
                    if obj:IsA("Humanoid") and obj.Parent:IsA("Model") then
                        npcHumanoids[obj] = true
                    end
                    if i % 400 == 0 then task.wait() end
                end
            end)
        end
        paint()
    end)
    paint()
    togglePaint[key] = paint
end

toggle("Enemy ESP", "ESP")
toggle("Show allies in blue", "Allies")
toggle("2D boxes", "Boxes")
toggle("Health bars", "Health")
toggle("Names", "Names")
toggle("Distance", "Distance")
toggle("Character outlines", "Outlines")
toggle("Skeleton", "Skeleton")
toggle("Tracers", "Tracers")
toggle("FOV circle", "FOV")
toggle("Target indicator", "Indicator")
toggle("Head aligned indicator", "Headshot")
toggle("Head aim assist", "Aim")
toggle("Auto lock inside circle", "AutoLock")
toggle("Include NPC humanoids", "NPCs")
toggle("Unknown teams as enemies", "UnknownEnemy")

-- Click a binding row, then press a key, gamepad button, or mouse button.
-- If that button is already assigned here, the two bindings swap.
local binds = {Menu = Enum.KeyCode.F1, Aim = Enum.KeyCode.F2,
    AutoLock = Enum.KeyCode.F3}
local bindButtons = {}
local listening = nil
local function bindName(code)
    local name = code.Name:gsub("MouseButton", "Mouse ")
    return name
end
local function paintBinds()
    for key, b in pairs(bindButtons) do
        b.Text = key .. " toggle key    " ..
            (listening == key and "PRESS A BUTTON..." or bindName(binds[key]))
        b.BackgroundColor3 = listening == key and COL.accent or COL.card
    end
    title.Text = "JAILBIRD V7    •    " .. bindName(binds.Menu)
    subtitle.Text = "Auto lock in circle  •  " .. bindName(binds.Menu) .. " menu  •  F10 unload"
end
for _, key in ipairs({"Aim", "AutoLock", "Menu"}) do
    local slot = key
    order += 1
    local b = button("", order)
    bindButtons[slot] = b
    connect(b.MouseButton1Click, function()
        listening = slot
        paintBinds()
    end)
end
paintBinds()

order += 1
local radiusBtn = button("", order)
local function radiusText() radiusBtn.Text = "FOV radius    " .. C.Radius .. " px   (+25)" end
connect(radiusBtn.MouseButton1Click, function()
    C.Radius = C.Radius + 25
    if C.Radius > 400 then C.Radius = 75 end
    radiusText()
end)
radiusText()
order += 1
local rangeBtn = button("", order)
local function rangeText() rangeBtn.Text = "ESP range    " .. C.Range .. " studs   (+500)" end
connect(rangeBtn.MouseButton1Click, function()
    C.Range = C.Range + 500
    if C.Range > 5000 then C.Range = 500 end
    rangeText()
end)
rangeText()
order += 1
local speedBtn = button("", order)
local function speedText() speedBtn.Text = "Aim response    " .. C.AimSpeed .. "   (+3)" end
connect(speedBtn.MouseButton1Click, function()
    C.AimSpeed = C.AimSpeed + 3
    if C.AimSpeed > 25 then C.AimSpeed = 4 end
    speedText()
end)
speedText()

local status = make("TextLabel", {
    Position = UDim2.new(0, 12, 1, -48), Size = UDim2.new(1, -24, 0, 38),
    BackgroundTransparency = 1, Text = "Starting...", TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham,
    TextSize = 11, TextColor3 = COL.muted,
}, menu)

local circle = make("Frame", {
    AnchorPoint = Vector2.new(.5, .5), BackgroundTransparency = 1,
    Visible = true,
}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, circle)
local circleStroke = make("UIStroke", {Color = COL.accent, Thickness = 1.5, Transparency = .2}, circle)
local indicator = make("TextLabel", {
    AnchorPoint = Vector2.new(.5, 0), Size = UDim2.fromOffset(250, 25),
    BackgroundColor3 = COL.card, BorderSizePixel = 0, TextColor3 = COL.text,
    Font = Enum.Font.GothamBold, TextSize = 11, Visible = false,
}, gui)
corner(indicator, 6)

local dragInput, dragStart, menuStart
connect(title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragInput, dragStart, menuStart = input, input.Position, menu.Position
    end
end)
connect(UIS.InputChanged, function(input)
    if dragInput and input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        menu.Position = UDim2.new(menuStart.X.Scale, menuStart.X.Offset + d.X,
            menuStart.Y.Scale, menuStart.Y.Offset + d.Y)
    end
end)
connect(UIS.InputEnded, function(input)
    if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragInput = nil
    end
end)
local function inputButton(input)
    if input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode end
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2
        or t == Enum.UserInputType.MouseButton3 then return t end
    return nil
end
connect(UIS.InputBegan, function(input)
    local pressed = inputButton(input)
    if listening then
        if pressed and pressed ~= Enum.KeyCode.F10 then
            local old, target = binds[listening], listening
            for key, bound in pairs(binds) do
                if key ~= target and bound == pressed then binds[key] = old end
            end
            binds[target] = pressed
            listening = nil
            paintBinds()
        end
        return
    end
    if UIS:GetFocusedTextBox() then return end
    if pressed == Enum.KeyCode.F10 then
        if _G.JBV7Stop then _G.JBV7Stop() end
    elseif pressed == binds.Menu then
        menu.Visible = not menu.Visible
    elseif pressed == binds.Aim then
        C.Aim = not C.Aim
        togglePaint.Aim()
    elseif pressed == binds.AutoLock then
        C.AutoLock = not C.AutoLock
        togglePaint.AutoLock()
    end
end)

local bonesR15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
}
local bonesR6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local function removeOverlay(model)
    local o = overlays[model]
    if not o then return end
    o.box:Destroy()
    o.name:Destroy()
    o.distance:Destroy()
    o.barBG:Destroy()
    o.tracer:Destroy()
    for _, segment in ipairs(o.bones) do segment:Destroy() end
    if o.highlight then o.highlight:Destroy() end
    overlays[model] = nil
end

local function createOverlay(model)
    local box = make("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
    }, gui)
    local stroke = make("UIStroke", {Color = COL.enemy, Thickness = 1.5}, box)
    local name = make("TextLabel", {
        BackgroundTransparency = 1, TextColor3 = COL.text, TextStrokeTransparency = .25,
        Font = Enum.Font.GothamBold, TextSize = 12, Visible = false,
    }, gui)
    local distance = make("TextLabel", {
        BackgroundTransparency = 1, TextColor3 = COL.muted, TextStrokeTransparency = .2,
        Font = Enum.Font.Gotham, TextSize = 10, Visible = false,
    }, gui)
    local barBG = make("Frame", {
        BackgroundColor3 = COL.card, BorderSizePixel = 0, Visible = false,
    }, gui)
    local fill = make("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
        BackgroundColor3 = COL.good,
    }, barBG)
    local tracer = line(gui, 1, COL.enemy)
    local bones = {}
    for i = 1, #bonesR15 do bones[i] = line(gui, 1, COL.enemy) end
    local o = {box = box, stroke = stroke, name = name, distance = distance,
        barBG = barBG, fill = fill, tracer = tracer, bones = bones, highlight = nil}
    overlays[model] = o
    return o
end
local function hideOverlay(o)
    show(o.box, false); show(o.name, false); show(o.distance, false)
    show(o.barBG, false); show(o.tracer, false)
    for _, segment in ipairs(o.bones) do show(segment, false) end
    if o.highlight then o.highlight.Enabled = false end
end

local function relation(player, model)
    if player then
        if player == LP then return "self" end
        if LP.Team and player.Team then
            return LP.Team == player.Team and "ally" or "enemy"
        end
        local ours, theirs = LP:GetAttribute("Team"), player:GetAttribute("Team")
        if ours ~= nil and theirs ~= nil then
            return tostring(ours) == tostring(theirs) and "ally" or "enemy"
        end
        if not LP.Neutral and not player.Neutral then
            return LP.TeamColor == player.TeamColor and "ally" or "enemy"
        end
        if #Teams:GetTeams() == 0 or C.UnknownEnemy then return "enemy" end
        return "unknown"
    end
    local team = model:GetAttribute("Team")
    if team and LP.Team then
        return tostring(team) == LP.Team.Name and "ally" or "enemy"
    end
    return "enemy" -- NPCs are opt-in; unknown NPC allegiance cannot be inferred.
end

local function screenPoint(camera, world)
    local v, visible = camera:WorldToViewportPoint(world)
    return Vector2.new(v.X, v.Y), visible and v.Z > 0
end
local function visibleHead(camera, model, head)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignored = {camera}
    if LP.Character then table.insert(ignored, LP.Character) end
    params.FilterDescendantsInstances = ignored
    params.IgnoreWater = true
    params.RespectCanCollide = true
    local delta = head.Position - camera.CFrame.Position
    local result = workspace:Raycast(camera.CFrame.Position, delta, params)
    return result == nil or result.Instance:IsDescendantOf(model)
end
local function feetPoint(model, root, hum)
    local left = model:FindFirstChild("LeftFoot") or model:FindFirstChild("Left Leg")
    local right = model:FindFirstChild("RightFoot") or model:FindFirstChild("Right Leg")
    if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
        local lowest = math.min(left.Position.Y - left.Size.Y / 2,
            right.Position.Y - right.Size.Y / 2)
        return Vector3.new(root.Position.X, lowest, root.Position.Z)
    end
    return root.Position - Vector3.new(0, root.Size.Y / 2 + hum.HipHeight, 0)
end

local function targetList()
    local result, present = {}, {}
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        if player ~= LP and model then
            present[model] = true
            table.insert(result, {player = player, model = model, name = player.DisplayName})
        end
    end
    if C.NPCs then
        for hum in pairs(npcHumanoids) do
            local model = hum.Parent
            if not hum:IsDescendantOf(workspace) then
                npcHumanoids[hum] = nil
            elseif model and model:IsA("Model") and not present[model]
                and not Players:GetPlayerFromCharacter(model) then
                present[model] = true
                table.insert(result, {model = model, name = model.Name})
            end
        end
    end
    return result, present
end

local function updateOverlay(item, camera, viewport, center, origin, stats)
    local model, player = item.model, item.player
    local relationship = relation(player, model)
    if relationship == "ally" then stats.allies += 1 end
    if relationship == "unknown" then stats.unknown += 1 end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local head, root = model:FindFirstChild("Head"), model:FindFirstChild("HumanoidRootPart")
    local o = overlays[model]
    if (relationship ~= "enemy" and not (relationship == "ally" and C.Allies))
        or not hum or hum.Health <= 0 or not head or not root
        or not head:IsA("BasePart") or not root:IsA("BasePart") then
        if o then hideOverlay(o) end
        return
    end
    local dist = (root.Position - origin).Magnitude
    if dist > C.Range then if o then hideOverlay(o) end return end
    local head2, onScreen = screenPoint(camera, head.Position)
    if not onScreen or head2.X < 0 or head2.X > viewport.X
        or head2.Y < 0 or head2.Y > viewport.Y then
        if o then hideOverlay(o) end
        return
    end
    if relationship == "enemy" then stats.enemies += 1 end
    local fovDist = (head2 - center).Magnitude
    if relationship == "enemy" and fovDist <= C.Radius then
        stats.inside += 1
        if visibleHead(camera, model, head) then
            stats.clear += 1
            if fovDist < stats.score then
                stats.score, stats.target, stats.name, stats.dist, stats.player =
                    fovDist, head, item.name, dist, player
            end
        else
            stats.blocked += 1
        end
    end

    if not C.ESP then if o then hideOverlay(o) end return end
    local top2 = screenPoint(camera, head.Position + Vector3.new(0, head.Size.Y / 2 + .35, 0))
    local foot2 = screenPoint(camera, feetPoint(model, root, hum))
    local h = math.max(16, math.abs(foot2.Y - top2.Y))
    local w = math.clamp(h * .52, 8, viewport.X)
    local x, y = head2.X - w / 2, top2.Y
    if y > viewport.Y or y + h < 0 then if o then hideOverlay(o) end return end
    if not o then o = createOverlay(model) end
    local color = relationship == "ally" and COL.ally or COL.enemy
    o.stroke.Color = color
    o.tracer.BackgroundColor3 = color
    o.box.Position = UDim2.fromOffset(x, y)
    o.box.Size = UDim2.fromOffset(w, h)
    show(o.box, C.Boxes)
    o.name.Text = item.name
    o.name.Position = UDim2.fromOffset(x - 25, y - 20)
    o.name.Size = UDim2.fromOffset(w + 50, 18)
    show(o.name, C.Names)
    o.distance.Text = tostring(math.floor(dist + .5)) .. " studs"
    o.distance.Position = UDim2.fromOffset(x - 20, y + h + 2)
    o.distance.Size = UDim2.fromOffset(w + 40, 16)
    show(o.distance, C.Distance)
    o.barBG.Position = UDim2.fromOffset(x - 7, y)
    o.barBG.Size = UDim2.fromOffset(4, h)
    local fraction = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    o.fill.Size = UDim2.fromScale(1, fraction)
    o.fill.BackgroundColor3 = COL.enemy:Lerp(COL.good, fraction)
    show(o.barBG, C.Health)
    if C.Tracers then
        placeLine(o.tracer, Vector2.new(center.X, viewport.Y - 12), Vector2.new(head2.X, y + h), 1)
    else show(o.tracer, false) end
    if C.Outlines then
        if not o.highlight or o.highlight.Parent ~= model then
            if o.highlight then o.highlight:Destroy() end
            o.highlight = make("Highlight", {
                Adornee = model, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                FillColor = color, FillTransparency = .82,
                OutlineColor = color, OutlineTransparency = .05,
            }, model)
        end
        o.highlight.FillColor = color
        o.highlight.OutlineColor = color
        o.highlight.Enabled = true
    elseif o.highlight then o.highlight.Enabled = false end

    local pairsForRig = hum.RigType == Enum.HumanoidRigType.R6 and bonesR6 or bonesR15
    for i, segment in ipairs(o.bones) do
        segment.BackgroundColor3 = color
        local pair = C.Skeleton and pairsForRig[i]
        local a = pair and model:FindFirstChild(pair[1])
        local b = pair and model:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local p1, v1 = screenPoint(camera, a.Position)
            local p2, v2 = screenPoint(camera, b.Position)
            if v1 and v2 then placeLine(segment, p1, p2, 1.5)
            else show(segment, false) end
        else show(segment, false) end
    end
end

connect(workspace.DescendantAdded, function(obj)
    if C.NPCs and obj:IsA("Humanoid") and obj.Parent:IsA("Model") then
        npcHumanoids[obj] = true
    end
end)
connect(Players.PlayerRemoving, function(player)
    if player.Character then removeOverlay(player.Character) end
end)

local elapsed, statusElapsed = 0, 0
local function onRender(dt)
    if not running then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local center = viewport / 2
    circle.Position = UDim2.fromOffset(center.X, center.Y)
    circle.Size = UDim2.fromOffset(C.Radius * 2, C.Radius * 2)
    show(circle, C.FOV)
    indicator.Position = UDim2.fromOffset(center.X, center.Y + C.Radius + 12)

    elapsed += dt
    if elapsed < 1 / 30 then return end
    elapsed = math.min(elapsed - 1 / 30, 1 / 30)
    local localRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local list, present = targetList()
    for model in pairs(overlays) do
        if not model:IsDescendantOf(workspace) or not present[model] then
            removeOverlay(model)
        end
    end
    local stats = {enemies = 0, allies = 0, unknown = 0,
        inside = 0, clear = 0, blocked = 0,
        score = math.huge, target = nil, name = nil, dist = nil, player = nil}
    for _, item in ipairs(list) do
        updateOverlay(item, camera, viewport, center, origin, stats)
    end
    bestTarget, bestName, bestDistance, bestPlayer =
        stats.target, stats.name, stats.dist, stats.player
    local held = aimingHeld()
    circleStroke.Color = bestTarget and COL.good or COL.accent
    if C.Indicator and bestTarget then
        local label = C.Aim and held and "LOCK" or "IN FOV"
        local headScreen = screenPoint(camera, bestTarget.Position)
        if C.Headshot and (headScreen - center).Magnitude <= 12 then
            label = "HEAD ALIGNED"
        end
        indicator.Text = string.format("%s  %s  •  %d studs", label, bestName,
            math.floor(bestDistance + .5))
        indicator.TextColor3 = C.Aim and held and COL.good or COL.text
        show(indicator, true)
    else show(indicator, false) end
    statusElapsed += 1 / 30
    if statusElapsed >= .25 then
        statusElapsed = 0
        local action = not C.Aim and "OFF"
            or not held and "HOLD RMB"
            or bestTarget and (C.AutoLock and "AUTO LOCK" or "RMB LOCK")
            or stats.unknown > 0 and "TEAM UNKNOWN"
            or stats.blocked > 0 and "NO LINE OF SIGHT"
            or "NO TARGET IN CIRCLE"
        status.Text = string.format("Aim: %s  |  Circle: %d  |  Clear: %d\nAllies: %d  Unknown: %d  Blocked: %d",
            action, stats.inside, stats.clear, stats.allies, stats.unknown, stats.blocked)
    end
end

local function onAim(dt)
    if not running or not C.Aim or not aimingHeld() or UIS:GetFocusedTextBox() then return end
    local camera, head = workspace.CurrentCamera, bestTarget
    if not camera or not head or not head.Parent or not head:IsDescendantOf(workspace) then return end
    local model = head.Parent
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if relation(bestPlayer, model) ~= "enemy" then return end
    local screen, visible = screenPoint(camera, head.Position)
    if not visible or (screen - camera.ViewportSize / 2).Magnitude > C.Radius then return end
    if not visibleHead(camera, model, head) then return end
    local desired = CFrame.lookAt(camera.CFrame.Position, head.Position)
    local alpha = 1 - math.exp(-C.AimSpeed * math.clamp(dt, 0, .1))
    camera.CFrame = camera.CFrame:Lerp(desired, alpha)
end

local function stop()
    if not running then return end
    running = false
    RunService:UnbindFromRenderStep(renderName)
    RunService:UnbindFromRenderStep(aimName)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for model in pairs(overlays) do removeOverlay(model) end
    gui:Destroy()
    table.clear(npcHumanoids)
    if _G.JBV7Stop == stop then _G.JBV7Stop = nil end
end
_G.JBV7Stop = stop
RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, onRender)
RunService:BindToRenderStep(aimName, Enum.RenderPriority.Camera.Value + 2, onAim)
