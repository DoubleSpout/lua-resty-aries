-- tools common
local _M = {
    __VERSION = "1.0"
}

-- _M.osSep = (function()
--     local result = io.popen("uname -s"):read("*l")
--     if not result or result == "" then
--         return "\\"
--     end

--     return "/"

-- end)()

_M.isNgx = not not ngx
    
_M.splitNgx = function(str, pat)
    local ngx_re = require "ngx.re"
    return ngx_re.split(str, pat)
end

_M.split = function(str, pat)
    -- if _M.isNgx then    -- 如果有ngx
    --     return _M.splitNgx(str, pat)
    -- end

    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
    	if s ~= 1 or cap ~= "" then
	 		table.insert(t,cap)
      	end
      	last_end = e+1
      	s, e, cap = str:find(fpat, last_end)
   	end
   	if last_end <= #str then
    	cap = str:sub(last_end)
      	table.insert(t, cap)
    end
    return t
end

--  _M.ltrim = function(str)
--     return str:gsub(str, "^[ \t\r]+", "")
-- end


_M.trim = function(s)
    return (s:gsub("^[ \t\r]*(.-)[ \t\r]*$", "%1"))
end

-- get guid str
_M.guid = function(pr)
    math.randomseed(os.time())
    local links, tb, gs = { [8] = true, [12] = true, [16] = true, [20] = true }, {}, {"0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"}
    for i = 1, 32 do
        local link = ""
        if links[i] ~= nil then
            link = pr
        end
        table.insert(tb, gs[math.random(1, 16)] .. link)
    end
    return table.concat(tb)
end

-- deep-copy a table
_M.clone = function (t) 
if type(t) ~= "table" then return t end
    local meta = getmetatable(t)
    local target = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            target[k] = _M.clone(v)
        else
            target[k] = v
        end
    end
    setmetatable(target, meta)
    return target
end

-- read file
_M.rfile = function(path)
    local file, data
    local ok, err = pcall(function()
        file = io.open(path, "r")
        data = file:read("*a")
        file:close();
    end)
    if err then
        error(string.format("open file %s error %s", path, err), 2)
    end
    return data
end


--[[
@desc
    在自定义标签中将除了字母数字之外的特殊字符转义，以做正则拼接之用
@params
    str    		@type string 	-- 用户自定义的标签
@return
    result      @type string 	-- 转义后的字符串
]]
_M.escapetag =  function(str)
    -- if _M.isNgx then
    --     local regx = [=[([^\w])]=]
    --     local newStr = ngx.re.gsub(str, regx, "%$1", "i")
    --     -- print("====================",str, newStr)
    --     return newStr
    -- end
    local newStr = str:gsub("([^%w])","%%%1")
    -- print("====================",str, newStr)
    return newStr
end

_M.gsub = function(str, regx, replace)
    -- if _M.isNgx then
    --     return ngx.re.gsub(str, regx, replace, "i")
    -- end
    return str:gsub(regx, replace)
end

return _M