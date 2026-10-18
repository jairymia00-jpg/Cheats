-- Jailbird V5 | Visual overlay and FOV indicator (no automated aim)
-- Client-side Lua. Team recognition uses Roblox Team / TeamColor.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local me = Players.LocalPlayer
assert(me, 'Run this on the client')
local pg = me:WaitForChild('PlayerGui')
if type(_G.JBV5Stop) == 'function' then pcall(_G.JBV5Stop) end
local old = pg:FindFirstChild('JBV5_GUI')
if old then old:Destroy() end
local alive = true
local connections, drawings = {}, {}
local cfg = {ESP=true, Boxes=true, Health=true, Names=true, Distance=true,
    Outlines=true, FOV=true, Target=true, Radius=150, Range=2500}
local purple = Color3.fromRGB(169,105,255)
local red = Color3.fromRGB(255,90,108)
local white = Color3.fromRGB(244,244,255)
local function new(kind, properties, parent)
    local o=Instance.new(kind)
    for k,v in pairs(properties) do o[k]=v end
    o.Parent=parent
    return o
end
local gui = new('ScreenGui',{Name='JBV5_GUI',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=1000},pg)
local menu = new('Frame',{Position=UDim2.fromOffset(25,85),Size=UDim2.fromOffset(310,440),
    BackgroundColor3=Color3.fromRGB(23,19,37),BorderSizePixel=0},gui)
new('UICorner',{CornerRadius=UDim.new(0,10)},menu)
new('UIStroke',{Color=purple,Thickness=2},menu)
new('TextLabel',{Size=UDim2.new(1,0,0,40),BackgroundTransparency=1,Text='JAILBIRD V5  |  F1',
    Font=Enum.Font.GothamBold,TextSize=18,TextColor3=white},menu)
local scroll = new('ScrollingFrame',{Position=UDim2.fromOffset(12,44),Size=UDim2.new(1,-24,1,-56),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,
    AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.fromOffset(0,0)},menu)
new('UIListLayout',{Padding=UDim.new(0,6)},scroll)
local function button()
    local b=new('TextButton',{Size=UDim2.new(1,-6,0,30),BackgroundColor3=Color3.fromRGB(43,35,65),
        TextColor3=white,Font=Enum.Font.GothamMedium,TextSize=12,BorderSizePixel=0},scroll)
    new('UICorner',{CornerRadius=UDim.new(0,6)},b)
    return b
end
for _,entry in ipairs({{'Enemy ESP','ESP'},{'2D Boxes','Boxes'},{'Health Bars','Health'},
    {'Names','Names'},{'Distance','Distance'},{'Body Outlines','Outlines'},
    {'FOV Circle','FOV'},{'Visible Target Indicator','Target'}}) do
    local label,key=entry[1],entry[2]
    local b=button()
    local function refresh() b.Text=label..': '..(cfg[key] and 'ON' or 'OFF') end
    refresh()
    table.insert(connections,b.MouseButton1Click:Connect(function() cfg[key]=not cfg[key];refresh() end))
end
local radius=button()
local function radiusLabel() radius.Text='FOV radius: '..cfg.Radius..' px (click)' end
radiusLabel()
table.insert(connections,radius.MouseButton1Click:Connect(function()
    cfg.Radius=cfg.Radius+25;if cfg.Radius>400 then cfg.Radius=75 end;radiusLabel()
end))
local range=button()
local function rangeLabel() range.Text='ESP range: '..cfg.Range..' studs (click)' end
rangeLabel()
table.insert(connections,range.MouseButton1Click:Connect(function()
    cfg.Range=cfg.Range+500;if cfg.Range>5000 then cfg.Range=500 end;rangeLabel()
end))
local status=new('TextLabel',{Size=UDim2.new(1,-6,0,55),BackgroundTransparency=1,
    Text='Waiting for players...',TextColor3=white,TextSize=11,TextWrapped=true},scroll)
table.insert(connections,UIS.InputBegan:Connect(function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.F1 then menu.Visible=not menu.Visible end
end))
local circle=new('Frame',{AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1},gui)
new('UICorner',{CornerRadius=UDim.new(1,0)},circle)
new('UIStroke',{Color=purple,Thickness=1.5},circle)
local target=new('TextLabel',{AnchorPoint=Vector2.new(.5,0),Size=UDim2.fromOffset(240,25),
    BackgroundColor3=Color3.fromRGB(35,26,52),TextColor3=white,
    Font=Enum.Font.GothamBold,TextSize=12,Visible=false},gui)
new('UICorner',{CornerRadius=UDim.new(0,6)},target)
local function enemy(p)
    if p==me then return false end
    if me.Team and p.Team then return me.Team~=p.Team end
    if not me.Neutral and not p.Neutral then return me.TeamColor~=p.TeamColor end
    return false
end
local function clear(p)
    local d=drawings[p]
    if not d then return end
    if d.box then d.box:Destroy() end
    if d.hpBack then d.hpBack:Destroy() end
    if d.label then d.label:Destroy() end
    if d.outline then d.outline:Destroy() end
    drawings[p]=nil
end
local function make(p,character)
    local box=new('Frame',{BackgroundTransparency=1,BorderSizePixel=0,Visible=false},gui)
    new('UIStroke',{Color=red,Thickness=1.5},box)
    local hpBack=new('Frame',{BackgroundColor3=Color3.fromRGB(55,30,35),BorderSizePixel=0,Visible=false},gui)
    local fill=new('Frame',{BackgroundColor3=Color3.fromRGB(80,230,100),BorderSizePixel=0,
        AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1)},hpBack)
    local label=new('TextLabel',{BackgroundTransparency=1,TextColor3=white,
        TextStrokeTransparency=.25,Font=Enum.Font.GothamBold,TextSize=12,Visible=false},gui)
    local outline=new('Highlight',{Adornee=character,FillTransparency=1,OutlineColor=red,
        OutlineTransparency=0,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop},character)
    local d={character=character,box=box,hpBack=hpBack,fill=fill,label=label,outline=outline}
    drawings[p]=d
    return d
end
-- Stable humanoid-sized projection: don't include guns, hats, or animated accessories.
local function rect(camera,root,hum)
    local height=math.clamp((hum.HipHeight or 2)*2+3,4.5,8)
    local base=root.Position-Vector3.new(0,1.8,0)
    local top=base+Vector3.new(0,height,0)
    local bottomPoint,on1=camera:WorldToViewportPoint(base)
    local topPoint,on2=camera:WorldToViewportPoint(top)
    if bottomPoint.Z<=0 or topPoint.Z<=0 or not (on1 or on2) then return nil end
    local h=math.abs(bottomPoint.Y-topPoint.Y)
    if h<3 then return nil end
    local w=h*.46
    local x=(bottomPoint.X+topPoint.X)/2-w/2
    local y=math.min(bottomPoint.Y,topPoint.Y)
    if x+w<0 or x>camera.ViewportSize.X or y+h<0 or y>camera.ViewportSize.Y then return nil end
    return x,y,w,h
end
local function visible(camera,character,head)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=me.Character and {me.Character} or {}
    params.IgnoreWater=true
    local origin=camera.CFrame.Position
    local hit=workspace:Raycast(origin,head.Position-origin,params)
    return not hit or hit.Instance:IsDescendantOf(character)
end
local function update()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local center=camera.ViewportSize/2
    circle.Position=UDim2.fromOffset(center.X,center.Y)
    circle.Size=UDim2.fromOffset(cfg.Radius*2,cfg.Radius*2)
    circle.Visible=cfg.FOV
    target.Position=UDim2.fromOffset(center.X,center.Y+cfg.Radius+10)
    target.Visible=false
    local myRoot=me.Character and me.Character:FindFirstChild('HumanoidRootPart')
    local shown,rejected,missing=0,0,0
    local best,bestDistance=nil,cfg.Radius
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=me then
            local c=p.Character
            local root=c and c:FindFirstChild('HumanoidRootPart')
            local head=c and c:FindFirstChild('Head')
            local hum=c and c:FindFirstChildOfClass('Humanoid')
            local isEnemy=enemy(p)
            if not isEnemy then rejected=rejected+1 end
            if not root or not head or not hum then missing=missing+1 end
            local valid=isEnemy and root and head and hum and hum.Health>0
            local d=drawings[p]
            if d and (not valid or d.character~=c) then clear(p);d=nil end
            if valid then
                if not d then d=make(p,c) end
                local distance=myRoot and (myRoot.Position-root.Position).Magnitude or math.huge
                local x,y,w,h=rect(camera,root,hum)
                local show=cfg.ESP and distance<=cfg.Range and x~=nil
                d.box.Visible=show and cfg.Boxes
                d.hpBack.Visible=show and cfg.Health
                d.label.Visible=show and (cfg.Names or cfg.Distance or cfg.Health)
                d.outline.Enabled=cfg.ESP and cfg.Outlines and distance<=cfg.Range
                if show then
                    shown=shown+1
                    d.box.Position=UDim2.fromOffset(x,y)
                    d.box.Size=UDim2.fromOffset(w,h)
                    d.hpBack.Position=UDim2.fromOffset(x-9,y)
                    d.hpBack.Size=UDim2.fromOffset(5,h)
                    local fraction=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                    d.fill.Size=UDim2.fromScale(1,fraction)
                    d.fill.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-fraction)),math.floor(255*fraction),60)
                    local parts={}
                    if cfg.Names then table.insert(parts,p.DisplayName) end
                    if cfg.Distance then table.insert(parts,math.floor(distance)..' studs') end
                    if cfg.Health then table.insert(parts,math.ceil(hum.Health)..' HP') end
                    d.label.Text=table.concat(parts,' | ')
                    d.label.Position=UDim2.fromOffset(x-45,y-23)
                    d.label.Size=UDim2.fromOffset(w+90,21)
                end
                if cfg.FOV and cfg.Target then
                    local pt,onScreen=camera:WorldToViewportPoint(head.Position)
                    if onScreen and pt.Z>0 then
                        local screenDistance=(Vector2.new(pt.X,pt.Y)-center).Magnitude
                        if screenDistance<bestDistance and visible(camera,c,head) then
                            best,bestDistance=p,screenDistance
                        end
                    end
                end
            end
        end
    end
    if best then target.Text='VISIBLE: '..best.DisplayName;target.Visible=true end
    status.Text='Visible ESP: '..shown..' | Rejected by team: '..rejected..' | Missing parts: '..missing
end
local function stop()
    if not alive then return end
    alive=false
    for _,c in ipairs(connections) do c:Disconnect() end
    for p in pairs(drawings) do clear(p) end
    gui:Destroy()
end
_G.JBV5Stop=stop
table.insert(connections,Players.PlayerRemoving:Connect(clear))
table.insert(connections,RunService.RenderStepped:Connect(function()
    if not alive then return end
    local ok,err=pcall(update)
    if not ok then status.Text='V5 error: '..tostring(err) end
end))
print('Jailbird V5 visual overlay loaded | F1 menu')
