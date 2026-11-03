-- Nightfall RIVALS Rebuilt 2.0.0
-- F1: menu | F4: ESP toggle | F10: destroy this script and all owned resources.
-- Toggle aim: RMB switches aim on/off. Hold aim: keep the chosen button held.
-- Blue teammates, pink enemies, amber unknown teams; head dots are always red.
-- Uses current Player.Character references and locally replicated positions only.
-- Standalone: no downloaded UI, hooks, remotes, or weapon-module modifications.
-- Offline behavior tested. Current game/executor compatibility requires live testing.

local Core = {}
Core.Version = "2.0.0"
function Core.finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
function Core.token(value)
    if Core.finite(value) then return "id:" .. tostring(value) end
    if type(value) ~= "string" then return nil end
    local number = tonumber(value)
    if Core.finite(number) then return "id:" .. tostring(number) end
    local key = value:lower():gsub("[^%w]", "")
    if key == "" or key == "neutral" or key == "none" or key == "spectator"
        or key == "spectators" or key == "lobby" or key == "unassigned" then return nil end
    return key
end
function Core.field(object, names)
    if not object then return nil end
    for _, name in ipairs(names) do
        local value = object:GetAttribute(name)
        if value ~= nil then return value end
        local child = object:FindFirstChild(name)
        if child and child:IsA("ValueBase") then return child.Value end
    end
end
local TEAM_IDS = {"TeamID", "TeamId"}
local TEAM_NAMES = {"TeamName", "Team", "Side", "Faction"}
local ENVIRONMENTS = {"EnvironmentID", "EnvironmentId"}
function Core.identity(player, model)
    return {
        id = Core.token(Core.field(player, TEAM_IDS)) or Core.token(Core.field(model, TEAM_IDS)),
        side = Core.token(Core.field(player, TEAM_NAMES)) or Core.token(Core.field(model, TEAM_NAMES)),
        native = player and player.Neutral == false and player.Team or nil,
        environment = Core.token(Core.field(player, ENVIRONMENTS)) or Core.token(Core.field(model, ENVIRONMENTS)),
    }
end
function Core.relation(localIdentity, other, ffa)
    -- Prefer a common schema. Never compare a TeamID to an unrelated team name.
    if ffa then return "enemy" end
    if localIdentity.id or other.id then
        if not localIdentity.id or not other.id then return "unknown" end
        return localIdentity.id == other.id and "friendly" or "enemy"
    end
    if localIdentity.side or other.side then
        if not localIdentity.side or not other.side then return "unknown" end
        return localIdentity.side == other.side and "friendly" or "enemy"
    end
    if localIdentity.native and other.native then
        return localIdentity.native == other.native and "friendly" or "enemy"
    end
    return "unknown"
end
function Core.sameMatch(a, b)
    if a == nil and b == nil then return true end
    return a ~= nil and b ~= nil and a == b
end
function Core.ffa(world)
    if world:GetAttribute("FreeForAll") == true then return true end
    local mode = tostring(world:GetAttribute("GameMode") or world:GetAttribute("Mode") or "")
        :lower():gsub("[^%w]", "")
    return mode == "ffa" or mode == "freeforall" or mode == "deathmatch"
end
function Core.track(rows, state, now, fov, visible)
    local function eligible(row)
        return row.alive and row.relation == "enemy" and row.sameMatch
            and row.head and row.onScreen and row.screenDistance <= fov
    end
    if state.player then
        local current
        for _, row in ipairs(rows) do if row.player == state.player then current = row break end end
        local invalid = current and (not current.alive or current.relation ~= "enemy"
            or not current.sameMatch or current.model ~= state.model)
        if invalid then
            state.player, state.model, state.lostAt = nil, nil, nil
        elseif current and eligible(current) and visible(current) then
            state.lostAt = nil
            state.status = "locked"
            return current
        else
            state.lostAt = state.lostAt or now
            if now - state.lostAt < 0.20 then state.status = "paused" return nil end
            state.player, state.model, state.lostAt = nil, nil, nil
        end
    end
    local sorted = {}
    for _, row in ipairs(rows) do if eligible(row) then sorted[#sorted + 1] = row end end
    table.sort(sorted, function(a, b) return a.screenDistance < b.screenDistance end)
    for _, row in ipairs(sorted) do
        if visible(row) then
            state.player, state.model, state.status = row.player, row.model, "locked"
            return row
        end
    end
    state.status = "searching"
end

local Players = game:GetService("Players")
local World = game:GetService("Workspace")
local Input = game:GetService("UserInputService")
local Run = game:GetService("RunService")
local Me = Players.LocalPlayer
assert(Me, "Nightfall needs a local player")
local env = type(getgenv) == "function" and getgenv() or _G
for _, key in ipairs({"__NightfallRivalsV1", "__NightfallBloxStrikeV1"}) do
    local old = env[key]
    if type(old) == "table" and type(old.Destroy) == "function" then pcall(old.Destroy, old, "replaced") end
end
for _, key in ipairs({"RivalsV2Stop", "RivalsV21Stop", "RivalsV22Stop", "RivalsV23Stop", "RivalsV24Stop"}) do
    local stop = env[key] or _G[key]
    if type(stop) == "function" then pcall(stop) end
end

local App = {
    Core = Core, Alive = true, MenuOpen = true, Focused = true,
    Settings = {
        AimEnabled = true, AimMode = "Toggle", AimBind = "MouseButton2", AimFOV = 150,
        ESPEnabled = true, ESPBind = "F4", Skeleton = true, HeadDot = true, Names = true,
        Outline = true, Teammates = true, ShowFOV = true,
    },
    Connections = {}, Visuals = {}, Lock = {}, Buttons = {}, Pressed = {},
    AimStatus = "MENU OPEN", CameraWrites = 0, Errors = 0,
    RenderName = "NightfallRivalsRebuilt_Render",
}
env.__NightfallRivalsV1 = App
local C = {
    friendly = Color3.fromRGB(70, 155, 255), enemy = Color3.fromRGB(255, 90, 180),
    unknown = Color3.fromRGB(255, 193, 80), red = Color3.fromRGB(255, 40, 55),
    white = Color3.fromRGB(232, 237, 245), muted = Color3.fromRGB(147, 159, 178),
    bg = Color3.fromRGB(16, 20, 29), panel = Color3.fromRGB(26, 33, 46),
}
local HEADS = {"HitboxHead", "HitboxHeadSmall", "Head"}
local BODIES = {"HumanoidRootPart", "HitboxBody", "HitboxBodySmall", "UpperTorso", "Torso"}
local BONES = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}
local function create(class, props, parent)
    local item = Instance.new(class)
    for key, value in pairs(props or {}) do item[key] = value end
    item.Parent = parent
    return item
end
local function part(model, names)
    for _, name in ipairs(names) do
        local found = model:FindFirstChild(name, true)
        if found and found:IsA("BasePart") then return found end
    end
end
local function health(player, model)
    if Core.field(model, {"Dead", "IsDead"}) == true or Core.field(player, {"Dead", "IsDead"}) == true then return false end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local hp = humanoid and humanoid.Health
    if not Core.finite(hp) then hp = Core.field(model, {"Health", "HP"}) end
    if not Core.finite(hp) then hp = Core.field(player, {"Health", "HP"}) end
    return Core.finite(hp) and hp > 0
end
local function positionOK(p)
    return Core.finite(p.X) and Core.finite(p.Y) and Core.finite(p.Z)
end
function App:Connect(signal, callback)
    local connection = signal:Connect(callback)
    self.Connections[#self.Connections + 1] = connection
    return connection
end
function App:ClearLock()
    self.Lock, self.Target = {}, nil
end
function App:HideOverlays()
    if self.Canvas then self.Canvas.Visible = false end
    for _, view in pairs(self.Visuals) do view.highlight.Enabled = false end
end
function App:Destroy()
    if not self.Alive then return end
    self.Alive = false
    pcall(function() Run:UnbindFromRenderStep(self.RenderName) end)
    for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
    for _, view in pairs(self.Visuals) do pcall(function() view.root:Destroy() end) end
    if self.Gui then pcall(function() self.Gui:Destroy() end) end
    self:ClearLock()
    self.Connections, self.Visuals, self.Pressed, self.Capture = {}, {}, {}, nil
    if env.__NightfallRivalsV1 == self then env.__NightfallRivalsV1 = nil end
    print("[Nightfall] Fully shut down")
end
function App:Set(key, value)
    local old = self.Settings[key]
    if old == nil then return false, "Unknown setting: " .. tostring(key) end
    if type(old) ~= type(value) then return false, "Wrong setting type" end
    if key == "AimMode" and value ~= "Toggle" and value ~= "Hold" then return false, "Choose Toggle or Hold" end
    if key == "AimFOV" then
        if not Core.finite(value) then return false, "FOV must be finite" end
        value = math.floor(math.clamp(value, 30, 500))
    end
    if key == "AimBind" or key == "ESPBind" then
        if value == "F1" or value == "F10" or value == "Escape" or value == "Unknown" then return false, "Reserved key" end
        local valid = value:match("^MouseButton[123]$") ~= nil
        if not valid then
            local ok, member = pcall(function() return Enum.KeyCode[value] end)
            valid = ok and member ~= nil
        end
        if not valid then return false, "Unsupported button" end
        local other = key == "AimBind" and "ESPBind" or "AimBind"
        if value == self.Settings[other] then return false, "Choose different aim and ESP buttons" end
    end
    self.Settings[key] = value
    if key:sub(1, 3) == "Aim" then self:ClearLock() end
    if self.Refresh then self:Refresh() end
    return true
end
function App:SetMenu(open)
    self.MenuOpen, self.Capture = open, nil
    self.Pressed = {}
    self:ClearLock()
    if self.Menu then self.Menu.Visible = open end
    if self.Refresh then self:Refresh() end
end
function App:IsDown(bind)
    if self.Pressed[bind] then return true end
    if bind:match("^MouseButton[123]$") then return Input:IsMouseButtonPressed(Enum.UserInputType[bind]) end
    return Input:IsKeyDown(Enum.KeyCode[bind])
end
function App:AimActive()
    if not self.Settings.AimEnabled or not self.Focused or self.MenuOpen or self.Capture or Input:GetFocusedTextBox() then return false end
    return self.Settings.AimMode == "Toggle" or self:IsDown(self.Settings.AimBind)
end
function App:Rows(camera)
    local rows, localModel = {}, Me.Character
    local localIdentity = Core.identity(Me, localModel)
    local ffa = Core.ffa(World)
    local center = camera.ViewportSize / 2
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Me then
            -- Read Character again each frame. Never use name-matched spawn clones.
            local model = player.Character
            local inWorld = model and model.Parent and model:IsDescendantOf(World)
            local head = inWorld and part(model, HEADS) or nil
            local body = inWorld and part(model, BODIES) or nil
            local identity = Core.identity(player, inWorld and model or nil)
            local row = {
                player = player, model = model, head = head, body = body,
                alive = inWorld and health(player, model) or false,
                relation = Core.relation(localIdentity, identity, ffa),
                sameMatch = Core.sameMatch(localIdentity.environment, identity.environment),
                matchKnown = (localIdentity.environment == nil) == (identity.environment == nil),
                onScreen = false, screenDistance = math.huge,
            }
            if head and positionOK(head.Position) then
                local projected, onScreen = camera:WorldToViewportPoint(head.Position)
                if positionOK(projected) then
                    row.onScreen = onScreen and projected.Z > 0
                    row.screenDistance = (Vector2.new(projected.X, projected.Y) - center).Magnitude
                end
            end
            rows[#rows + 1] = row
        end
    end
    self.LocalIdentity = localIdentity
    return rows, localModel
end
function App:Visible(row, camera, localModel)
    if not row.head or not row.head.Parent then return false end
    local origin, destination = camera.CFrame.Position, row.head.Position
    if not positionOK(origin) or not positionOK(destination) then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    local ignored = {camera}
    if localModel then ignored[#ignored + 1] = localModel end
    for _ = 1, 8 do
        params.FilterDescendantsInstances = ignored
        local hit = World:Raycast(origin, destination - origin, params)
        if not hit then return true end
        if hit.Instance:IsDescendantOf(row.model) then return true end
        local obstruction = hit.Instance
        if obstruction:IsA("BasePart") and obstruction.Transparency >= 0.98 and not obstruction.CanCollide then
            ignored[#ignored + 1] = obstruction
        else return false end
    end
    return false
end

local function line(parent)
    return create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
        BackgroundTransparency = 0, Visible = false, ZIndex = 3}, parent)
end
local function drawLine(item, a, b, color)
    local dx, dy = b.X - a.X, b.Y - a.Y
    local length = math.sqrt(dx * dx + dy * dy)
    if not Core.finite(length) or length < 0.5 then item.Visible = false return end
    item.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    item.Size = UDim2.fromOffset(length, 1.5)
    item.Rotation = math.deg(math.atan2(dy, dx))
    item.BackgroundColor3, item.Visible = color, true
end
function App:Visual(player, model)
    local view = self.Visuals[player]
    if view and view.model == model then return view end
    if view then view.root:Destroy() end
    local root = create("Frame", {Name = "PlayerOverlay", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Visible = false}, self.Canvas)
    view = {root = root, model = model, bones = {}, parts = {}, partsAt = -math.huge}
    view.dot = create("Frame", {Name = "HeadDot", Size = UDim2.fromOffset(7, 7),
        AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = C.red, ZIndex = 5}, root)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, view.dot)
    create("UIStroke", {Color = Color3.new(), Thickness = 1}, view.dot)
    view.name = create("TextLabel", {Name = "PlayerName", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(300, 20), TextSize = 13,
        Font = Enum.Font.Code, TextStrokeTransparency = 0.15, TextStrokeColor3 = Color3.new(),
        RichText = false, TextColor3 = C.white, ZIndex = 5}, root)
    view.highlight = create("Highlight", {Adornee = model, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        FillTransparency = 0.87, OutlineTransparency = 0.1, Enabled = false}, root)
    for i = 1, #BONES do view.bones[i] = line(root) end
    self.Visuals[player] = view
    return view
end
function App:Draw(row, camera, now)
    local settings = self.Settings
    local show = settings.ESPEnabled and row.alive and row.sameMatch and row.head and positionOK(row.head.Position)
        and (settings.Teammates or row.relation ~= "friendly")
    local existing = self.Visuals[row.player]
    if not show then
        if existing then existing.root.Visible, existing.highlight.Enabled = false, false end
        return
    end
    local view = self:Visual(row.player, row.model)
    local projected, onScreen = camera:WorldToViewportPoint(row.head.Position)
    local validProjection = positionOK(projected)
    local color = C[row.relation]
    view.root.Visible = true
    view.highlight.Enabled = settings.Outline
    view.highlight.FillColor, view.highlight.OutlineColor = color, color
    view.dot.Visible = settings.HeadDot and validProjection and onScreen and projected.Z > 0
    if validProjection then view.dot.Position = UDim2.fromOffset(projected.X, projected.Y) end
    view.name.Visible = settings.Names and validProjection and onScreen and projected.Z > 0
    local tag = row.relation == "friendly" and "TEAM" or row.relation == "enemy" and "ENEMY" or "TEAM ?"
    view.name.Text = (row.player.DisplayName or row.player.Name) .. "  [" .. tag .. "]"
    if validProjection then view.name.Position = UDim2.fromOffset(projected.X, projected.Y - 13) end
    view.name.TextColor3 = color
    if settings.Skeleton and now - view.partsAt >= 0.5 then
        view.parts, view.partsAt = {}, now
        for _, object in ipairs(row.model:GetDescendants()) do
            if object:IsA("BasePart") and view.parts[object.Name] == nil then view.parts[object.Name] = object end
        end
    end
    for i, bone in ipairs(BONES) do
        local a, b = view.parts[bone[1]], view.parts[bone[2]]
        if bone[1] == "Head" then a = row.head end
        if settings.Skeleton and a and b and a:IsDescendantOf(row.model) and b:IsDescendantOf(row.model) then
            local pa = camera:WorldToViewportPoint(a.Position)
            local pb = camera:WorldToViewportPoint(b.Position)
            if positionOK(pa) and positionOK(pb) and pa.Z > 0.1 and pb.Z > 0.1 then
                drawLine(view.bones[i], pa, pb, color)
            else view.bones[i].Visible = false end
        else view.bones[i].Visible = false end
    end
end

local function label(parent, text, size, color)
    return create("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = text, TextSize = size or 14, TextColor3 = color or C.white, RichText = false,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left}, parent)
end
local function button(parent, text, x, y, width, callback)
    local item = create("TextButton", {Text = text, TextSize = 13, Font = Enum.Font.Gotham,
        TextColor3 = C.white, BackgroundColor3 = C.panel, BorderSizePixel = 0,
        AutoButtonColor = true, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, 30)}, parent)
    create("UICorner", {CornerRadius = UDim.new(0, 6)}, item)
    App:Connect(item.MouseButton1Click, function() if App.Alive then callback() end end)
    return item
end
local function short(bind)
    return ({MouseButton1 = "LMB", MouseButton2 = "RMB", MouseButton3 = "MMB"})[bind] or bind
end
function App:Refresh()
    for key, item in pairs(self.Buttons) do
        if type(self.Settings[key]) == "boolean" then
            item.Text = self.Settings[key] and "ON" or "OFF"
            item.TextColor3 = self.Settings[key] and C.friendly or C.muted
        elseif key == "AimBind" or key == "ESPBind" then
            item.Text = self.Capture == key and "Press key..." or short(self.Settings[key])
        elseif key == "AimFOV" then item.Text = tostring(self.Settings[key]) .. " px"
        else item.Text = tostring(self.Settings[key]) end
    end
end
function App:BuildUI()
    self.Gui = create("ScreenGui", {Name = "NightfallRivalsRebuilt", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 100000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, Me:WaitForChild("PlayerGui"))
    self.Canvas = create("Frame", {Name = "Overlay", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ClipsDescendants = true}, self.Gui)
    self.Circle = create("Frame", {Name = "AimFOV", AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1, BorderSizePixel = 0}, self.Canvas)
    create("UICorner", {CornerRadius = UDim.new(1, 0)}, self.Circle)
    self.CircleStroke = create("UIStroke", {Color = C.white, Thickness = 1.3, Transparency = 0.25}, self.Circle)
    self.Hud = label(self.Gui, "Nightfall | F1 menu | F10 shutdown", 13)
    self.Hud.Position, self.Hud.Size = UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 24)
    self.Hud.TextStrokeTransparency, self.Hud.ZIndex = 0.25, 20
    self.Menu = create("Frame", {Name = "Menu", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 586),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 50}, self.Gui)
    create("UICorner", {CornerRadius = UDim.new(0, 12)}, self.Menu)
    create("UIStroke", {Color = C.panel, Thickness = 1}, self.Menu)
    self.MenuScale = create("UIScale", {Scale = 1}, self.Menu)
    local title = label(self.Menu, "NIGHTFALL / RIVALS", 19)
    title.Position, title.Size = UDim2.fromOffset(20, 14), UDim2.fromOffset(300, 27)
    local hint = label(self.Menu, "F1 menu   /   F10 full shutdown", 12, C.muted)
    hint.Position, hint.Size = UDim2.fromOffset(20, 44), UDim2.fromOffset(400, 18)
    -- A visible modal button frees the pointer for menu controls in first person.
    local close = button(self.Menu, "X", 390, 14, 30, function() self:SetMenu(false) end)
    close.Modal = true
    local y = 78
    local function setting(key, text, handler)
        local caption = label(self.Menu, text, 14)
        caption.Position, caption.Size = UDim2.fromOffset(20, y), UDim2.fromOffset(258, 30)
        self.Buttons[key] = button(self.Menu, "", 294, y, 126, handler or function() self:Set(key, not self.Settings[key]) end)
        y = y + 34
    end
    setting("AimEnabled", "Aimbot")
    setting("AimMode", "Aim activation", function()
        self:Set("AimMode", self.Settings.AimMode == "Toggle" and "Hold" or "Toggle")
    end)
    setting("AimBind", "Aim button", function() self.Capture = "AimBind" self:ClearLock() self:Refresh() end)
    local fovCaption = label(self.Menu, "Aim FOV radius", 14)
    fovCaption.Position, fovCaption.Size = UDim2.fromOffset(20, y), UDim2.fromOffset(210, 30)
    button(self.Menu, "-", 250, y, 34, function() self:Set("AimFOV", self.Settings.AimFOV - 25) end)
    self.Buttons.AimFOV = button(self.Menu, "", 294, y, 82, function() end)
    button(self.Menu, "+", 386, y, 34, function() self:Set("AimFOV", self.Settings.AimFOV + 25) end)
    y = y + 34
    setting("ShowFOV", "Show FOV circle")
    setting("ESPEnabled", "ESP")
    setting("ESPBind", "ESP toggle button", function() self.Capture = "ESPBind" self:ClearLock() self:Refresh() end)
    setting("Skeleton", "Skeleton")
    setting("HeadDot", "Red head dot")
    setting("Names", "Player names")
    setting("Outline", "Through-wall outline")
    setting("Teammates", "Show blue teammates")
    local note = label(self.Menu, "Blue: team   /   Pink: enemy   /   Amber: team unknown\nHead lock uses the red dot. Unknown teams are skipped.", 11, C.muted)
    note.Position, note.Size = UDim2.fromOffset(20, 492), UDim2.fromOffset(400, 34)
    note.TextWrapped = true
    button(self.Menu, "Close menu (F1)", 20, 540, 193, function() self:SetMenu(false) end)
    button(self.Menu, "Shut down (F10)", 227, 540, 193, function() self:Destroy() end)
    self:Refresh()
end
function App:Step()
    if not self.Alive then return end
    local camera = World.CurrentCamera
    if not camera or camera.ViewportSize.X <= 0 or camera.ViewportSize.Y <= 0 then
        self:ClearLock()
        self:HideOverlays()
        self.AimStatus = "WAITING FOR CAMERA"
        self.Hud.Text = "Nightfall | " .. self.AimStatus .. " | F1 menu / F10 shutdown"
        return
    end
    self.Canvas.Visible = true
    self.MenuScale.Scale = math.min(1, (camera.ViewportSize.Y - 24) / 586, (camera.ViewportSize.X - 24) / 440)
    local now = os.clock()
    local rows, localModel = self:Rows(camera)
    self.RowsNow = rows
    local localAlive = localModel and localModel.Parent and health(Me, localModel)
    local target
    if self:AimActive() and localAlive then
        target = Core.track(rows, self.Lock, now, self.Settings.AimFOV, function(row)
            return self:Visible(row, camera, localModel)
        end)
        if target then
            local origin, goal = camera.CFrame.Position, target.head.Position
            if (goal - origin).Magnitude > 0.001 and positionOK(goal) then
                camera.CFrame = CFrame.lookAt(origin, goal)
                self.CameraWrites = self.CameraWrites + 1
                self.AimStatus = "LOCKED: " .. (target.player.DisplayName or target.player.Name)
            end
        elseif self.Lock.status == "paused" then self.AimStatus = "LOCK PAUSED / COVER OR FOV"
        else
            local unknown, duelUnknown = false, false
            for _, row in ipairs(rows) do
                if row.alive and not row.matchKnown then duelUnknown = true end
                if row.alive and row.sameMatch and row.relation == "unknown" then unknown = true end
            end
            self.AimStatus = unknown and "WAITING FOR TEAM DATA"
                or duelUnknown and "WAITING FOR DUEL DATA" or "NO VISIBLE ENEMY IN FOV"
        end
    else
        self:ClearLock()
        if self.MenuOpen then self.AimStatus = "MENU OPEN / AIM PAUSED"
        elseif not self.Focused then self.AimStatus = "WINDOW UNFOCUSED"
        elseif Input:GetFocusedTextBox() then self.AimStatus = "TYPING / AIM PAUSED"
        elseif not localAlive then self.AimStatus = "WAITING FOR YOUR CHARACTER"
        elseif not self.Settings.AimEnabled then self.AimStatus = "AIM OFF"
        else self.AimStatus = "HOLD " .. short(self.Settings.AimBind) .. " TO AIM" end
    end
    self.Target = target
    self.Circle.Visible = self.Settings.ShowFOV and self.Focused
    self.Circle.Size = UDim2.fromOffset(self.Settings.AimFOV * 2, self.Settings.AimFOV * 2)
    self.Circle.Position = UDim2.fromOffset(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    self.CircleStroke.Color = target and C.enemy or C.white
    local seen = {}
    for _, row in ipairs(rows) do
        seen[row.player] = true
        self:Draw(row, camera, now)
    end
    for player, view in pairs(self.Visuals) do
        if not seen[player] or player.Character ~= view.model or not view.model.Parent then
            view.root:Destroy()
            self.Visuals[player] = nil
        end
    end
    local action = self.Settings.AimMode == "Toggle" and "toggle" or "hold"
    self.Hud.Text = "Nightfall | " .. self.AimStatus .. " | " .. short(self.Settings.AimBind)
        .. " " .. action .. " | ESP " .. (self.Settings.ESPEnabled and "ON" or "OFF")
        .. " | F1 menu / F10 shutdown"
end
local function inputName(object)
    local kind = object.UserInputType
    if kind == Enum.UserInputType.Keyboard then return object.KeyCode.Name end
    if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
        or kind == Enum.UserInputType.MouseButton3 then return kind.Name end
end
local function start()
    App:BuildUI()
    App:Connect(Input.InputBegan, function(object)
        local name = inputName(object)
        if not name then return end
        if name == "F10" then App:Destroy() return end
        if name == "F1" then App:SetMenu(not App.MenuOpen) return end
        if App.Capture then
            if name == "Escape" then App.Capture = nil App:Refresh() return end
            local success, message = App:Set(App.Capture, name)
            if success then App.Capture = nil else warn("[Nightfall] " .. message) end
            App.Pressed = {}
            App:Refresh()
            return
        end
        if Input:GetFocusedTextBox() or not App.Focused or App.MenuOpen then return end
        if App.Pressed[name] then return end
        App.Pressed[name] = true
        if name == App.Settings.ESPBind then App:Set("ESPEnabled", not App.Settings.ESPEnabled) end
        if name == App.Settings.AimBind and App.Settings.AimMode == "Toggle" then
            App:Set("AimEnabled", not App.Settings.AimEnabled)
        end
    end)
    App:Connect(Input.InputEnded, function(object)
        local name = inputName(object)
        if name then App.Pressed[name] = nil end
        if name == App.Settings.AimBind and App.Settings.AimMode == "Hold" then App:ClearLock() end
    end)
    App:Connect(Input.WindowFocusReleased, function()
        App.Focused, App.Pressed, App.Capture = false, {}, nil
        App:ClearLock()
        App:Refresh()
    end)
    App:Connect(Input.WindowFocused, function() App.Focused = true end)
    Run:BindToRenderStep(App.RenderName, Enum.RenderPriority.Last.Value + 1, function()
        local ok, problem = pcall(App.Step, App)
        if not ok then
            App.Errors = App.Errors + 1
            App:ClearLock()
            if App.Errors == 1 then warn("[Nightfall] Render error: " .. tostring(problem)) end
            if App.Hud then App.Hud.Text = "Nightfall | RUNTIME ERROR | see console | F10 shutdown" end
            App:HideOverlays()
            if App.Errors >= 3 then App:Destroy() end
        end
    end)
    print("[Nightfall] Rebuilt 2.0.0 loaded. F1 menu; F10 shutdown. RMB toggles aim; F4 toggles ESP.")
end
local ok, problem = pcall(start)
if not ok then App:Destroy() error("[Nightfall] Startup failed: " .. tostring(problem)) end
return App
