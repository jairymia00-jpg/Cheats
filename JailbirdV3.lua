local url = "https://raw.githubusercontent.com/jairymia00-jpg/Cheats/refs/heads/main/JailbirdV2.lua"

local ok, result = pcall(function()
    local source = game:HttpGet(url)
    print("Downloaded:", #source, "characters")

    local fn, err = loadstring(source)

    if not fn then
        warn("SYNTAX ERROR:", err)
        return
    end

    print("Compilation successful")

    local success, runtimeError = pcall(fn)

    print("Execution successful:", success)

    if not success then
        warn("RUNTIME ERROR:", runtimeError)
    end
end)

if not ok then
    warn("DOWNLOAD OR LOADER ERROR:", result)
end
