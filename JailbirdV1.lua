-- Jailbird V2 - visual overlay (client-side)
-- Visual-only: no automatic aiming, firing, or wallbang.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local me = Players.LocalPlayer
if not me then return end
local pg = me:WaitForChild('PlayerGui')

if type(_G.JailbirdV2Stop) == 'function' then pcall(_G.JailbirdV2Stop) end
local old = pg:FindFirstChild('JailbirdV2UI')
if old then old:Destroy() end
local active, connections, objects = true, {}, {}
local cfg = {ESP=true, Boxes=true, Silhouette=true, Health=true, Names=true, Distance=true, FOV=true, VisibleTarget=true, Radius=160, Range=2000}
local purple = Color3.fromRGB(155,85,255)
local red = Color3.fromRGB(255,70,90)
local white = Color3.fromRGB(245,245,255)
local function mk(class, props, parent)
    local obj = Instance.new(class)
    for k,v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local gui = mk('ScreenGui',{Name='JailbirdV2UI',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=1000},pg)
local menu = mk('Frame',{Size=UDim2.fromOffset(290,460),Position=UDim2.fromOffset(24,90),BackgroundColor3=Color3.fromRGB(22,18,35),BorderSizePixel=0},gui)
mk('UICorner',{CornerRadius=UDim.new(0,12)},menu)
mk('UIStroke',{Color=purple,Thickness=2},menu)
mk('TextLabel',{Size=UDim2.new(1,0,0,43),BackgroundTransparency=1,Text='JAILBIRD V2  |  F1',TextColor3=white,Font=Enum.Font.GothamBold,TextSize=18},menu)
local scroller=mk('ScrollingFrame',{Position=UDim2.fromOffset(12,46),Size=UDim2.new(1,-24,1,-58),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},menu)
mk('UIListLayout',{Padding=UDim.new(0,6)},scroller)
local function button(text)
    local b=mk('TextButton',{Size=UDim2.new(1,-5,0,32),BackgroundColor3=Color3.fromRGB(42,34,63),BorderSizePixel=0,Text=text,TextColor3=white,TextSize=12,Font=Enum.Font.GothamMedium},scroller)
    mk('UICorner',{CornerRadius=UDim.new(0,7)},b)
    return b
end
local function toggle(label,key)
    local b=button('')
    local function refresh() b.Text=label..': '..(cfg[key] and 'ON' or 'OFF'); b.TextColor3=cfg[key] and purple or white end
    table.insert(connections,b.MouseButton1Click:Connect(function() cfg[key]=not cfg[key];refresh() end))
    refresh()
end
for _,item in ipairs({{'Enemy ESP','ESP'},{'Thin Boxes','Boxes'},{'Body Outlines','Silhouette'},{'Health','Health'},{'Names','Names'},{'Distance','Distance'},{'FOV Circle','FOV'},{'Visible Target','VisibleTarget'}}) do toggle(item[1],item[2]) end
local radius=button('')
local function radiusText() radius.Text='FOV radius: '..cfg.Radius..' px  (click to change)' end
radiusText()
table.insert(connections,radius.MouseButton1Click:Connect(function() cfg.Radius=cfg.Radius+25;if cfg.Radius>400 then cfg.Radius=75 end;radiusText() end))
local range=button('')
local function rangeText() range.Text='Info range: '..cfg.Range..' studs  (click)' end
rangeText()
table.insert(connections,range.MouseButton1Click:Connect(function() cfg.Range=cfg.Range+500;if cfg.Range>5000 then cfg.Range=500 end;rangeText() end))
local status=mk('TextLabel',{Size=UDim2.new(1,-5,0,28),BackgroundTransparency=1,Text='Visual overlay ready',TextColor3=white,TextSize=11,TextWrapped=true},scroller)
table.insert(connections,UIS.InputBegan:Connect(function(input,processed) if not processed and input.KeyCode==Enum.KeyCode.F1 then menu.Visible=not menu.Visible end end))
local circle=mk('Frame',{AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1},gui)
mk('UICorner',{CornerRadius=UDim.new(1,0)},circle)
mk('UIStroke',{Color=purple,Thickness=1.5},circle)
local target=mk('TextLabel',{AnchorPoint=Vector2.new(.5,0),Size=UDim2.fromOffset(250,27),BackgroundColor3=Color3.fromRGB(30,23,48),BackgroundTransparency=.15,TextColor3=white,Font=Enum.Font.GothamBold,TextSize=12,Visible=false},gui)
mk('UICorner',{CornerRadius=UDim.new(0,7)},target)

local function remove(p)
    local data=objects[p]
    if not data then return end
    if data.highlight then data.highlight:Destroy() end
    if data.billboard then data.billboard:Destroy() end
    if data.box then data.box:Destroy() end
    objects[p]=nil
end
local function enemy(p)
    if p==me then return false end
    if me.Team and p.Team then return me.Team~=p.Team end
    if not me.Neutral and not p.Neutral and me.TeamColor and p.TeamColor then return me.TeamColor~=p.TeamColor end
    return false -- Unknown team assignments are not guessed.
end
local function create(p,char,head,root)
    local hl=mk('Highlight',{Name='JBV2_BodyOutline',Adornee=char,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,FillColor=red,OutlineColor=red,FillTransparency=.93,OutlineTransparency=0},char)
    local box=mk('SelectionBox',{Name='JBV2_ThinBox',Adornee=char,Color3=red,LineThickness=.015,SurfaceTransparency=1},char)
    local billboard=mk('BillboardGui',{Name='JBV2_Info',Adornee=head,Size=UDim2.fromOffset(195,55),StudsOffsetWorldSpace=Vector3.new(0,2.6,0),AlwaysOnTop=true,MaxDistance=cfg.Range},head)
    local label=mk('TextLabel',{Size=UDim2.new(1,0,0,34),BackgroundTransparency=1,TextColor3=white,TextStrokeTransparency=.2,Font=Enum.Font.GothamBold,TextSize=12,TextWrapped=true},billboard)
    local bar=mk('Frame',{Position=UDim2.fromOffset(18,39),Size=UDim2.new(1,-36,0,6),BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(80,35,35)},billboard)
    local fill=mk('Frame',{Size=UDim2.fromScale(1,1),BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(60,230,100)},bar)
    objects[p]={character=char,highlight=hl,box=box,billboard=billboard,label=label,bar=bar,fill=fill}
    return objects[p]
end
local function lineOfSight(camera,char,part)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=me.Character and {me.Character} or {}
    params.IgnoreWater=true
    local origin=camera.CFrame.Position
    local hit=workspace:Raycast(origin,part.Position-origin,params)
    return not hit or hit.Instance:IsDescendantOf(char)
end
local function update()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local center=camera.ViewportSize/2
    circle.Position=UDim2.fromOffset(center.X,center.Y)
