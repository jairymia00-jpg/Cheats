-- Jailbird V3 | Visual overlay (no automatic aim or firing)
-- Designed for a Roblox client LocalScript in a game you control.
-- F1 toggles the purple menu. Does not alter existing teammate indicators.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local me = Players.LocalPlayer
assert(me, "This script requires a client LocalScript")
local playerGui = me:WaitForChild("PlayerGui")

-- Clear a previous V3 instance before creating new objects.
if type(_G.JBV3Stop) == "function" then pcall(_G.JBV3Stop) end
local previous = playerGui:FindFirstChild("JBV3_GUI")
if previous then previous:Destroy() end

local active = true
local connections, objects = {}, {}
local cfg = {
    ESP = true, Boxes = true, Silhouette = true,
    Health = true, Names = true, Distance = true,
    FOV = true, VisibleTarget = true,
    Radius = 150, Range = 2500
}
local purple = Color3.fromRGB(155, 94, 255)
local red = Color3.fromRGB(255, 65, 85)
local white = Color3.fromRGB(245, 245, 255)

local function mk(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do obj[key] = value end
    obj.Parent = parent
    return obj
end
local gui = mk("ScreenGui", {
    Name = "JBV3_GUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 999, Enabled = true
}, playerGui)
local menu = mk("Frame", {
    Name = "Menu", Size = UDim2.fromOffset(300, 450),
    Position = UDim2.fromOffset(25, 90), BackgroundColor3 = Color3.fromRGB(21, 18, 34),
    BorderSizePixel = 0, Visible = true
}, gui)
mk("UICorner", {CornerRadius = UDim.new(0, 11)}, menu)
mk("UIStroke", {Color = purple, Thickness = 2}, menu)
mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1,
    Text = "JAILBIRD V3 | F1", Font = Enum.Font.GothamBold,
    TextSize = 18, TextColor3 = white
}, menu)
local scroller = mk("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 45), Size = UDim2.new(1, -24, 1, -58),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0, 0)
}, menu)
mk("UIListLayout", {Padding = UDim.new(0, 7)}, scroller)
local function button(text)
    local b = mk("TextButton", {
        Size = UDim2.new(1, -5, 0, 32), BackgroundColor3 = Color3.fromRGB(39, 33, 59),
        BorderSizePixel = 0, Text = text, TextColor3 = white,
        Font = Enum.Font.GothamMedium, TextSize = 12
    }, scroller)
    mk("UICorner", {CornerRadius = UDim.new(0, 7)}, b)
    return b
end
local function toggle(label, key)
    local b = button("")
    local function refresh()
        b.Text = label .. ": " .. (cfg[key] and "ON" or "OFF")
        b.TextColor3 = cfg[key] and purple or white
    end
    table.insert(connections, b.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        refresh()
    end))
    refresh()
end
for _, item in ipairs({
    {"Enemy ESP", "ESP"}, {"Thin Boxes", "Boxes"},
    {"Body Outlines", "Silhouette"}, {"Health", "Health"},
    {"Names", "Names"}, {"Distance", "Distance"},
    {"FOV Circle", "FOV"}, {"Visible Target", "VisibleTarget"}
}) do toggle(item[1], item[2]) end
local radiusButton = button("")
local function radiusText() radiusButton.Text = "FOV radius: " .. cfg.Radius .. " px (click)" end
radiusText()
table.insert(connections, radiusButton.MouseButton1Click:Connect(function()
    cfg.Radius = cfg.Radius + 25
    if cfg.Radius > 400 then cfg.Radius = 75 end
    radiusText()
end))
local rangeButton = button("")
local function rangeText() rangeButton.Text = "Info range: " .. cfg.Range .. " studs (click)" end
rangeText()
table.insert(connections, rangeButton.MouseButton1Click:Connect(function()
