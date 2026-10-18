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
    circle.Size=UDim2.fromOffset(cfg.Radius*2,cfg.Radius*2)
    circle.Visible=cfg.FOV
    target.Position=UDim2.fromOffset(center.X,center.Y+cfg.Radius+10)
    target.Visible=false
    local root=me.Character and me.Character:FindFirstChild('HumanoidRootPart')
    local best,bestDist=nil,cfg.Radius
    local shown=0
    for _,p in ipairs(Players:GetPlayers()) do
        local char=p.Character
        local head=char and char:FindFirstChild('Head')
        local hum=char and char:FindFirstChildOfClass('Humanoid')
        local valid=enemy(p) and head~=nil and hum~=nil and hum.Health>0
        local d=objects[p]
        if d and (not valid or d.character~=char) then remove(p);d=nil end
        if valid then
            if not d then d=create(p,char,head) end
            local dist=root and (root.Position-head.Position).Magnitude or math.huge
            local inRange=dist<=cfg.Range
            d.highlight.Enabled=cfg.ESP and cfg.Silhouette
            d.box.Visible=cfg.ESP and cfg.Boxes
            d.billboard.Enabled=cfg.ESP and inRange and (cfg.Health or cfg.Names or cfg.Distance)
            d.billboard.MaxDistance=cfg.Range
            d.bar.Visible=cfg.Health
            local hp=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
            d.fill.Size=UDim2.fromScale(hp,1)
            d.fill.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-hp)),math.floor(255*hp),65)
            local parts={}
            if cfg.Names then table.insert(parts,p.DisplayName) end
            if cfg.Distance and dist<math.huge then table.insert(parts,math.floor(dist)..' studs') end
            if cfg.Health then table.insert(parts,math.ceil(hum.Health)..' HP') end
            d.label.Text=table.concat(parts,' | ')
            if cfg.ESP then shown=shown+1 end
            if cfg.VisibleTarget and cfg.FOV then
                local pos,onScreen=camera:WorldToViewportPoint(head.Position)
                if onScreen and pos.Z>0 then
                    local screenDist=(Vector2.new(pos.X,pos.Y)-center).Magnitude
                    if screenDist<bestDist and lineOfSight(camera,char,head) then
                        bestDist=screenDist
                        best=p
                    end
                end
            end
        end
    end
    if best then target.Text='VISIBLE: '..best.DisplayName;target.Visible=true end
    status.Text='Enemy markers: '..shown..' | F1 to hide menu'
end
local function stop()
    if not active then return end
    active=false
    for _,c in ipairs(connections) do c:Disconnect() end
    for p in pairs(objects) do remove(p) end
    gui:Destroy()
end
_G.JailbirdV2Stop=stop
table.insert(connections,Players.PlayerRemoving:Connect(remove))
local elapsed=0
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
    if not active then return end
    elapsed=elapsed+dt
    if elapsed>=.1 then
        elapsed=0
        local ok,err=pcall(update)
        if not ok then status.Text='Update error: '..tostring(err) end
