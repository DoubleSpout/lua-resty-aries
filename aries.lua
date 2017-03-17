local tools = require("lib.tools")
local lib = require("lib.lib")


-- temlate default option
local Aries = {
    startTag = "<%",
    endTag = "%>",
    fileSuffix = "html",
    rootPath = "./tpl",
    sep = "/",
    isShowDetailError = true,   -- must set off in production
    timeout = 10,       --sec
    ctx = {},
    getInclude = function(self, includeName)
                    return self.readfile(string.format("%s%s%s.%s", self.rootPath, self.sep, includeName, self.fileSuffix))
                end,
    minify = function(self, renderStr)
                    return renderStr
               end,
}

Aries.readfile = tools.rfile

-- 获取这个模版的所有include Name
Aries.getIncludesByName = function(self, tplName)
     local str = self:getInclude(tplName)
     return self:getIncludesByContent(str, tplName)
end

-- 获取一个模版所有的includes
Aries.getIncludesByContent = function(self, tplString, tplName)
    local tplIns = lib:new(self)
    local tplName = tplName or lib._NAME
    tplIns.mainTplName = tplName

    -- compile and render the tpl 
    local ok, errMsg = pcall(function()
        tplIns:parseInclude(tplString, tplName)
    end)

    if errMsg then
        return nil, errMsg
    end

    return tplIns.includes, nil
end

-- 从getinclude中获取内容
Aries.render = function (self, tplName, ctx)
    if not tplName or tplName == "" then
        error("invalid tplName", 2)
    end
    local ctx = ctx or {}
    -- first get include name to render
    local str = self:getInclude(tplName)
    return self:compile(str, ctx, tplName)
end

--[[
    @desc
        render template function
    @params
        templateStr @type string
    @return
        result      @type string
        err         @type error
 ]]
Aries.compile = function (self, tplString, ctx, tplName)
    -- every time one ariesInstance to many tplInstance
    local ctx = ctx or {}
    local tplIns = lib:new(self, ctx)  
    local tplName = tplName or lib._NAME
    tplIns.mainTplName = tplName
    local result

    -- compile and render the tpl
    local ok, errMsg = pcall(function()
        local code = tplIns:packTpl(tplString, tplName)
        result = tplIns:compile(code)
    end)

    -- if has any error
    if not ok then
        -- debug the error, print detail error msg
        if self.isShowDetailError then
            local line, realErr= errMsg:match(":(%d+):(.*)")
            local curTplLine, innerErrMsg = realErr:match(":(%d+):(.*)")
            -- print(curTplLine, innerErrMsg)
            -- 自定义错误时  会进入此分支
            if not innerErrMsg then
                return nil, string.format("%s %s %s","lua-ariestp>>lib.lua", line, realErr)
            end

            local errSource = {}
            for i, chunk in pairs(tplIns.sourceMap) do
                --print(chunk.finalLine, curTplLine, chunk.finalLine == tonumber(curTplLine))
                if chunk.finalLine == tonumber(curTplLine) then
                    table.insert(errSource, chunk)
                end
            end
            if errSource[1] and errSource[#errSource] then
                local errInSameline = (errSource[1].curTplLine ~= errSource[#errSource].curTplLine) or (errSource[1].includeTreeStr ~= errSource[#errSource].includeTreeStr)
                if errInSameline then
                    return nil, string.format("(%s:%s) or (%s:%s) have error %s", errSource[1].includeTrackTreeStr, errSource[1].curTplLine, errSource[#errSource].includeTrackTreeStr, errSource[#errSource].curTplLine, innerErrMsg)
                end
            end

            if errSource[1] then
                return nil, string.format("%s: %s have error %s", errSource[1].includeTrackTreeStr, errSource[1].curTplLine, innerErrMsg)
            end
        end

        return nil, errMsg
    end

    -- normal return
    return self:minify(result) , nil
end



local _M = {
    __VERSION = "1.0"
}
_M.new = function(self, opt)
    local aries = opt or {}
     return setmetatable(aries,{__index=Aries}) 
end




return _M