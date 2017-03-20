local template = require "resty.template"
template.caching(false)

local loop = 100000
local s = os.time()
local x = [=[
        {{ string.format("hello world %s", i) }}
    ]=]
for i=0,loop,1 do
    local func     = template.compile(x)
    local result, _ = func({i=i})
    -- print(result)
end
print(os.time() - s)