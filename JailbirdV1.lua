
print("loadstring type:", type(loadstring))

local fn, err = loadstring("print('LUA TEST PASSED')")

print("Compiled:", type(fn))
print("Compile error:", err)

if fn then
    fn()
end
