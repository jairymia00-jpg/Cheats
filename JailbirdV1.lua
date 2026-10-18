-- Enemy Vision Combined | LocalScript for your own Roblox experience
-- Place in StarterPlayer > StarterPlayerScripts
-- F1 toggles menu; no automatic aiming or firing.

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')

-- Clean up prior run, including event connections.
if _G.EnemyVisionCleanup then pcall(_G.EnemyVisionCleanup) end
local connections = {}
local markers = {}
local gui = Instance.new('ScreenGui')
gui.Name = 'EnemyVisionCombined'
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = playerGui

local config = {ESP=true, Names=true, Health=true, Distance=true, FOV=true, Target=true, Radius=150, MaxDistance=1000}
local PURPLE = Color3.fromRGB(152, 95, 255)
local RED = Color3.fromRGB(255, 80, 95)

local function make(class, props, parent)
    local obj = Instance.new(class)
    for k,v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local menu = make('Frame', {Size=UDim2.fromOffset(292, 420), Position=UDim2.fromOffset(24, 90), BackgroundColor3=Color3.fromRGB(22,19,35), BorderSizePixel=0}, gui)
make('UICorner', {CornerRadius=UDim.new(0, 12)}, menu)
make('UIStroke', {Color=PURPLE, Thickness=2}, menu)
make('TextLabel', {Size=UDim2.new(1,0,0,42), BackgroundTransparency=1, Text='ENEMY VISION  •  F1', TextColor3=Color3.new(1,1,1), TextSize=17, Font=Enum.Font.GothamBold}, menu)
local scroll = make('ScrollingFrame', {Position=UDim2.fromOffset(12,47), Size=UDim2.new(1,-24,1,-59), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y}, menu)
make('UIListLayout', {Padding=UDim.new(0,7)}, scroll)

local function button(label, onClick)
    local b = make('TextButton', {Size=UDim2.new(1,-5,0,34), BackgroundColor3=Color3.fromRGB(39,34,57), BorderSizePixel=0, TextColor3=Color3.new(1,1,1), TextSize=13, Font=Enum.Font.GothamMedium}, scroll)
    make('UICorner', {CornerRadius=UDim.new(0,7)}, b)
    onClick(b)
    return b
end
local function toggle(label,key)
    button(label, function(b)
        local function refresh() b.Text = label .. ': ' .. (config[key] and 'ON' or 'OFF') end
        refresh()
        table.insert(connections,b.MouseButton1Click:Connect(function() config[key]=not config[key]; refresh() end))
    end)
end
for _,item in ipairs({{'Enemy ESP','ESP'},{'Names','Names'},{'Health','Health'},{'Distance','Distance'},{'FOV Circle','FOV'},{'Visible Target','Target'}}) do toggle(item[1],item[2]) end
button('FOV Radius', function(b)
    local function refresh() b.Text = 'FOV Radius: ' .. config.Radius .. ' px  (click to increase)' end
    refresh()
    table.insert(connections,b.MouseButton1Click:Connect(function() config.Radius = config.Radius >= 350 and 75 or config.Radius+25; refresh() end))
end)
button('ESP Distance', function(b)
    local function refresh() b.Text = 'ESP Distance: ' .. config.MaxDistance .. ' studs' end
    refresh()
    table.insert(connections,b.MouseButton1Click:Connect(function() config.MaxDistance = config.MaxDistance >= 2000 and 250 or config.MaxDistance+250; refresh() end))
end)

table.insert(connections, UIS.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.F1 then menu.Visible = not menu.Visible end
end))

local ring = make('Frame', {AnchorPoint=Vector2.new(.5,.5), BackgroundTransparency=1}, gui)
make('UICorner', {CornerRadius=UDim.new(1,0)}, ring)
make('UIStroke', {Color=PURPLE, Thickness=1.5}, ring)
local targetLabel = make('TextLabel', {Size=UDim2.fromOffset(250,26), AnchorPoint=Vector2.new(.5,0), BackgroundColor3=Color3.fromRGB(28,23,43), BackgroundTransparency=.15, TextColor3=Color3.new(1,1,1), TextSize=13, Font=Enum.Font.GothamBold, Visible=false}, gui)
make('UICorner', {CornerRadius=UDim.new(0,6)}, targetLabel)

local function isEnemy(other)
    return other ~= player and player.Team ~= nil and other.Team ~= nil and other.Team ~= player.Team
end
local function clear(other)
    local m = markers[other]
    if not m then return end
    if m.highlight then m.highlight:Destroy() end
    if m.tag then m.tag:Destroy() end
    markers[other] = nil
end
local function add(other, character, head)
    local hl = make('Highlight', {Name='EnemyVisionOutline', Adornee=character, FillColor=RED, OutlineColor=RED, FillTransparency=.85, OutlineTransparency=0, DepthMode=Enum.HighlightDepthMode.AlwaysOnTop}, character)
    local tag = make('BillboardGui', {Name='EnemyVisionInfo', Adornee=head, Size=UDim2.fromOffset(185,58), StudsOffsetWorldSpace=Vector3.new(0,2.5,0), AlwaysOnTop=true, MaxDistance=config.MaxDistance}, head)
    local info = make('TextLabel', {Size=UDim2.new(1,0,0,34), BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), TextStrokeTransparency=.2, TextSize=12, Font=Enum.Font.GothamBold, TextWrapped=true}, tag)
    local barBG = make('Frame', {Position=UDim2.fromOffset(15,39), Size=UDim2.new(1,-30,0,6), BorderSizePixel=0, BackgroundColor3=Color3.fromRGB(75,30,35)}, tag)
    local bar = make('Frame', {Size=UDim2.fromScale(1,1), BorderSizePixel=0, BackgroundColor3=Color3.fromRGB(70,240,110)}, barBG)
    markers[other] = {character=character,highlight=hl,tag=tag,info=info,barBG=barBG,bar=bar}
end
local function visible(character, part, camera)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = player.Character and {player.Character} or {}
