local Aries = require("resty.aries")
local aries1 = Aries:new({
    isShowDetailError=false
})

local loop = 100000
local s = os.time()
local x = [=[
        <%= string.format("hello world %s", ctx.i) %>
    ]=]
for i=0,loop,1 do
    local result, _ = aries1:compile(x, {i=i})
    --print(result)
end
print(os.time() - s)