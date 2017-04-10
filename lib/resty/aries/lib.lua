local tools, core, md5
local ok = pcall(function() tools = require("resty.aries.tools") end)
if not ok then
	tools = require("aries.tools")
end

local ok = pcall(function() _ = require "bit" end)

if not ok then

	-- 加载c版本的md5
	local ok = pcall(function() core = require("resty.aries.core") end)
	if not ok then
		core = require("aries.core")
	end
	function md5Func (k)
		local k = core.sum(k)
		return (string.gsub(k, ".", function (c)
				return string.format("%02x", string.byte(c))
				end))
	end

else

	-- 加载lua版本的md5
	local ok = pcall(function() md5 = require("resty.aries.md5") end)
	if not ok then
		md5 = require("aries.md5")
	end
	function md5Func (message)
		local m = md5.new()
		m:update(message)
		return md5.tohex(m:finish())
	end

end

local _M = {
	_VERSION = "1.0",
	_NAME = "main",
	_ESCAPE_TABLE = { 
			-- ['&'] = '&amp;', 
			['<'] = '&lt;', 
			['>'] = '&gt;', 
			['"'] = '&quot;', 
			["'"] ='&apos;'
		},
}


-- 调用clone 是防止用户设置coroutine，table等某些字段 污染全局作用域  影响其他渲染
local tplLib = {
	whitelist = {
		ipairs = ipairs,
		pairs = pairs,
		coroutine = tools.clone(coroutine),
		type = type,
		string = tools.clone(string),
		table = tools.clone(table),
		math = tools.clone(math),
		os = {
			date = os.date,
			time = os.time
		}
	}
}



--[[
@desc
	将lua代码放置到解释器里面，返回一个函数以备运行代码
@params
	code    	@type string 	-- 拼接好的lua代码字符串
	name		@type string 	-- 所在模板名字
	ctx			@type table		-- 函数执行的上下文
@return
	func		@type function
]]
tplLib.exec = function (self, code, name, ctx)
	local name = name or self.mainTplName
	local func, err
	if setfenv then	-- use 5.1
		func, err = loadstring(code)
		if func then
			setfenv(func, ctx)
		end
	else			-- use 5.2+
		func, err = load(code, name, 't', ctx)
	end

	if not func or err then
		error(string.format("%s has error %s", name, err), 2)
	end

	return func
end
	

	

--[[
@desc
	将整个模板字符串拆分成对应的块（标识为代码还是文本或为表达式）返回一个迭代器
@params
	self		@type self
	template    @type string
@return
	result      @type function 	-- iterator
]]
tplLib.splitTpl = function (self, template)
	local ariesIns = self.ariesIns
	-- 转义<% 变为 %<%%, %> 转为 %%%>
	local startTag = tools.escapetag(ariesIns.startTag or "<%")
	local endTag = tools.escapetag(ariesIns.endTag or "%>")

	local luaCodeReg = startTag .. "(.-)" .. endTag -- string.format("%s(.-)%s", startTag, endTag)
	local includeReg = "^".. startTag .. " include (.-)" .. endTag -- string.format("^%s include (.-)%s", startTag, endTag)
	local expressReg = "^".. startTag .. "=(.-)" .. endTag -- string.format("^%s=(.-)%s", startTag, endTag)
	local notEscapeReg = "^".. startTag .. "%-(.-)" .. endTag --string.format("^%s%%-(.-)%s", startTag, endTag)
	local position = 1	-- postion表示匹配到的lua表达式位置

	-- 返回迭代器,把模版切成不同类型的块
	return function ()
		if not position then
			return nil
		end
		local luaCodeStart, luaCodeEnd, luaCode= template:find(luaCodeReg, position)
		local chunk = {}

		-- 如果解析的是lua代码
		if luaCodeStart == position then
			local needEscape = true
			-- 如果是lua代码，先检查是否是include的代码块
			local includeStart, includeEnd, includeTpl = template:find(includeReg, position)

			local expressStart, expressEnd, express, prefixSpace
			if not includeStart then	-- 如果这个lua代码块不是include,那么就抓取lua表达式的代码
					expressStart, expressEnd, express = template:find(expressReg, position)
					if not expressStart then
						needEscape = false
						expressStart, expressEnd, express = template:find(notEscapeReg, position)
					end
			end

						
			if includeStart then		-- 如果是include的块

				if position > 1 then	-- 这个是为了include之后代码格式还有原来的空格
					_, _, prefixSpace = template:sub(1, position - 1):find("([\t ]-)$", 1)
				end

				chunk.type = "include"
				chunk.text = tools.trim(includeTpl)
				chunk.space = prefixSpace or ""
			elseif expressStart then	-- 如果是表达式的块
				chunk.type = "expression"
				chunk.text = tools.trim(express)
				chunk.escape = needEscape
			else						-- 最后就是lua代码块，不带表达式的那种
				chunk.type = "code"
				chunk.text = luaCode
			end

			position = luaCodeEnd + 1
			return chunk

		-- 如果解析的是html和lua代码混合块
		elseif luaCodeStart then
			-- 把块定义为文本,记录下一个lua代码的开始位置
			chunk.type = "text"
			chunk.text = template:sub(position, luaCodeStart - 1)
			position = luaCodeStart
			return chunk
		else
			-- 如果解析的字符串没有lua代码
			chunk.text = template:sub(position)
			chunk.type = "text"
			position = nil	--表示结束解析
			return (#chunk.text > 0) and chunk or nil
		end
	end
end


--[[
@desc
	缓存解析之后的模版结构
@params
	self			@type table
	template    	@type string 	-- 模板字符串
@return
	ok, function() end
]]
tplLib.getCachePaseTpl = function(self, template)
	local ariesIns = self.ariesIns
	if not ariesIns.cache then	-- 未开缓存
		return nil, function() end
	end

	-- 当超过设定时间则进行扫描
	local nowTs = os.time()
	if nowTs - ariesIns.cacheLastScanTs >= ariesIns.cacheTime then
		self:scanAndClearCache()
	end

	-- or里使用ngx的md5
	local md5Key = ""
	if ngx and ngx.md5 then
		md5Key = ngx.md5(template)
	else
		md5Key = md5Func(template)
	end

	-- print(md5Key)
	
	-- 如果存在md5key
	if ariesIns.cacheData[md5Key] and ariesIns.cacheData[md5Key].data then
		return ariesIns.cacheData[md5Key].data, function() end
	else
		ariesIns.cacheData[md5Key] = nil
	end

	return nil, function(newData) 
			ariesIns.cacheData[md5Key] = {
				data = newData,
				ts = nowTs,
			}
	end

end

--[[
@desc
	扫描并删除过期的缓存
@params
	self			@type table
@return
]]
tplLib.scanAndClearCache = function(self)
	local ariesIns = self.ariesIns
	local rmKeys = {}
	local nowTs = os.time()
	for k, v in pairs(ariesIns.cacheData) do
		if not v.ts or (nowTs - v.ts >= ariesIns.cacheTime) then
			table.insert(rmKeys, k)
		end
	end

	for _, key in ipairs(rmKeys) do 
		ariesIns.cacheData[key] = nil
	end

	ariesIns.cacheLastScanTs = nowTs
end

--[[
	@desc
		将拆分的对应的语法块中include的内容解析出来
	@params
		self			@type table
		template    	@type string 	-- 模板字符串
		includeTreeStr 	@type string 	-- 模版include关系树
		lineTrack		@type string 	-- 代表进入到哪一层include的字符串并记下每层行号
	@return
		finalTplChunks	@type table 	-- 将include里面内容解析后 进行拆分的最后结果
		includes 		@type table 	-- 此模板字符串引入的所有模板（包括相同数据）
	]]
tplLib.parseInclude = function (self, template, includeTreeStr, includeTrackTreeStr)
	local ariesIns = self.ariesIns
	local includes = self.includes
	-- begin with line 1
	local curTplLine = 1	-- 当前被应用include模版的行号
	
	-- 代表进入到哪一层的include
	local includeTreeStr = includeTreeStr or (self.mainTplName .. "." .. ariesIns.fileSuffix)
	-- 每层引入的模板 并记录下相应的行号
	local includeTrackTreeStr = includeTrackTreeStr or includeTreeStr
	-- 截取分析>>
	local includeList = tools.split(tostring(includeTreeStr),">>")
	local includeMap = {}

	-- 循环解析 includeList 
	for _,v in pairs(includeList) do
		includeMap[v] = true
	end

	-- 插入tpl解析的前缀 do {xxxxx} end
	table.insert(self.finalTplChunks, "do")

	-- 对template进行split解析
	-- 分拆模版 遇到include放入一个块
	-- todo1 缓存chunk
	-- todo2 提前结束tpl的解析
	for chunk in self:splitTpl(template) do	-- 执行迭代器
		if chunk.type == "include" then
			if includeMap[chunk.text] == true then
				error(includeTreeStr.. " can't include same template " .. chunk.text , 2)
			end
			-- 此处用于去重 ariesIns.includes 里面相同的模板名字
			includes[chunk.text] = true
			local str = ariesIns:getInclude(tools.trim(chunk.text))	-- 调用用户函数获取块内容
			str = tools.gsub(str, "\n", "\n" .. chunk.space)	-- 塞入include之前的用户前面的空格或者换行，这样渲染出来就不会错位了
			
			-- 第一个参数include的模版字符串
			-- 第二个参数 includeTreeStr 这个记录所有主模版一条include分支下面的include模版名称
			-- 第三个参数 includeTrackTreeStr 这个记录所有主模版一条include分支下面的include模版名称，同时记录当前include模版的执行行号
			self:parseInclude(str, includeTreeStr..">>".. (chunk.text.. "." .. ariesIns.fileSuffix), 
			includeTrackTreeStr .. ": " .. curTplLine .. " >> " .. (chunk.text.. "." .. ariesIns.fileSuffix))
		else

			-- 如果开启了debug,那么就要去做sourceMap相关的操作
			if ariesIns.isShowDetailError then

				-- 如果在源文件中 sourceLine 才减去 1 , 防止每次来都多加 1
				if includeTreeStr == self.mainTplName then	--如果解析的是主模版的html,express,code类型
					self.sourceLine = self.sourceLine - 1	-- 主模版需要对行号都-1
				end
				self.finalLine = self.finalLine - 1			-- 主模版需要对行号都-1
				curTplLine = curTplLine - 1					-- 对当前解析的模版行号-1

				-- 追加空格是因为 split方法 对于头部和收尾h是\n 会少拆分
				local addLineSuffix = false
				if chunk.text:sub(-1) == "\n" then
					addLineSuffix = true
				end
				local addLinePrefix = false
				if chunk.text:sub(1,1) == "\n" then
					addLinePrefix = true
				end
				-- 对字符串进行split
				local splitMap= tools.split(chunk.text,"\n")	-- 对内容每行进行分割
				if addLineSuffix then
					table.insert(splitMap, "")
				end
				if addLinePrefix then
					table.insert(splitMap, 1, "")
				end

				-- 遍历每行
				for _, v in ipairs(splitMap) do		
					self.finalLine = self.finalLine + 1		
					-- map 为每一行 与 渲染行 的映射表
					local map = {}
					-- 说明是在源文件中
					if includeTreeStr == self.mainTplName then
						self.sourceLine = self.sourceLine + 1
						curTplLine = self.sourceLine
					else	-- 如果不再源文件中就增加 curTplLine 这个行号
						curTplLine = curTplLine + 1
					end

					-- 为每一行代码生成一个sourcemap
					map = {
						sourceLine = self.sourceLine,
						finalLine = self.finalLine,			--拼接好模版之后，最终的行号
						curTplLine = curTplLine,
						includeTreeStr = includeTreeStr,
						includeTrackTreeStr = includeTrackTreeStr,
						lineContent = v
					}
					table.insert(self.sourceMap,map)
				end

			end
			-- 将chunk塞入最终模版解析的chunk
			table.insert(self.finalTplChunks, chunk)
		end

	end
	
	-- 当前模版解析完毕，塞入end
	table.insert(self.finalTplChunks, "end")

	return self.finalTplChunks, includes
end


--[[
@desc
	对相应的语法块用函数包装一下，返回包装后的lua代码字符串
@params
	tplIns		@type table
	template    @type string
@return
	code		@type string
]]
tplLib.packTpl = function (self, template, mainTplName)
	local ariesIns = self.ariesIns
	-- 先获取一把缓存
	local cacheCode, callbackSave = self:getCachePaseTpl(template)
	self.callbackSave = callbackSave
	if cacheCode then
		ariesIns.lastIsCache = true
		return cacheCode
	else	
		ariesIns.lastIsCache = false
	end


	
	local ctxPrint = "ctx.print"
	local ctxRawPrint = "ctx.rawPrint" --原生的print
	local output, includes = self:parseInclude(template)	-- 把所有include放进来

	-- for include, _ in pairs(includes) do
	-- 	table.insert(self.includes, include)
	-- end

	-- 保存所有的lua代码
	local packCode = {}
	for i, chunk in ipairs(output) do
		-- 根据chunk的类型不同
		if chunk.type == "expression" then
			if chunk.escape then
				table.insert(packCode, string.format("%s(%s)", ctxPrint, chunk.text))
			else
				table.insert(packCode, string.format("%s(%s)", ctxRawPrint, chunk.text))
			end		
		elseif chunk.type == "code" then
			table.insert(packCode, string.format(" %s ", chunk.text))
		else	-- chunk.type == "text"
			if chunk.text and chunk.text ~= "" then
				table.insert(packCode, string.format("%s([======[%s]======])", ctxRawPrint, chunk.text))
			end
		end
	end
	local code = table.concat(packCode, '')
	return code
end
	


--[[
	@desc
		将lua代码字符串编译执行，返回执行后的内容
	@params
		tplIns		@type table
		code 		@type string 	-- lua代码串
	@return
		str			@type string
	]]

tplLib.compile = function(self, code)
	local ariesIns = self.ariesIns 
	local result, ctxSon, ctxGrandson = {}, {}, {}
	local locks = {}

	-- 不转义print
	local rawPrint = function (text, escape)
		local text = text or "nil" --string.format("%s", )
		if escape then
			table.insert(result, string.format("%q", text))
		else
			table.insert(result, text) --string.format("%s", text))
			--table.insert(result, tools.trim(string.format("%s", text)))
		end 
	end

	-- 转义print
	local print = function (text, escape)
		local text = string.format("%s", text or "nil")
		
		for k, v in pairs(_M._ESCAPE_TABLE) do
			text = tools.gsub(text, k, v)
		end
		rawPrint(text, escape)
	end


	-- 加锁ctx的属性
	local function lock(field)
		-- ctxSon[field] = nil
		locks[tostring(field)] = true
	end
	-- 解锁ctx的属性
	local function unlock(field)
		locks[tostring(field)] = false
		-- ctxSon[field] = nil
	end

	self.ctx.print = print
	self.ctx.rawPrint = rawPrint
	-- self.ctx.yield = coroutine.yield -- 防止用户写coroutine.yield = nil 导致死循环无法检测 所以将其存为ctx的属性 使之无法更改
	self.ctx.lock = lock
	self.ctx.unlock = unlock
	

	-- 检测死循环注释了，太浪费效率
	-- local strid = tools.guid("")
	-- if ariesIns.timeout > 0 then
	-- 	code = "coroutine.create = nil " .. code
	-- 	code = code:gsub("(['\"])(.-)%1", function(t1, t2)
	-- 		return t1 .. t2:gsub('end', ('☯♔' .. strid)):gsub('repeat', ('㊥♔' .. strid)) .. t1
	-- 	end):gsub("(%[[=]*%[)(.-)(%][=]*%])", function(t1, t2, t3)
	-- 		return t1 .. t2:gsub('end', ('☯♔' .. strid)):gsub('repeat', ('㊥♔' .. strid)) .. t3
	-- 	end)
	-- 	code = code:gsub(" end","ctx.yield%(%) end"):gsub("repeat","repeat ctx.yield%(%) ")
	-- 	code = code:gsub(('☯♔' .. strid), 'end'):gsub(('㊥♔' .. strid), 'repeat')
	-- else
	-- 	whitelist.coroutine = coroutine
	-- end

	-- 设置儿子ctx的继承
	setmetatable(ctxSon, {
		__index = self.ctx
	})

	-- 设置孙子ctx继承
	setmetatable(ctxGrandson, {
		__newindex = function (t,k,v)
			if self.ctx[k] ~= nil  then
				error("ctx.".. k .." is exists", 2)
			elseif locks[k] == true or k == "print" then
				error(k .. " is locked", 2)
			else
				ctxSon[k] = v
			end
		end,
		__index = ctxSon
	})

	local ctx = setmetatable(self.whitelist, { __index = {ctx=ctxGrandson}})

	-- 开启一个协程来渲染模版
	local func = self:exec(code, self.mainTplName, ctx)
	if ariesIns.timeout > 0 then
		local coroutineFunc = function()
			local co = coroutine.create(func)
			local start = os.time()
			local ok,errMsg = coroutine.resume(co)
			if not ok then
				error(errMsg, 2)
			end
			while true do	-- 判断超时渲染
				if (ariesIns.timeout > 0) and (os.time() - start > ariesIns.timeout) then
					error(" render tmplate is timeout ", 2)
					break
				elseif coroutine.status(co) == "dead" then
					break
				else
					local ok,errMsg = coroutine.resume(co)
					if not ok then
						error(errMsg, 2)
					end
				end
			end
		end
		local ok, err = pcall(coroutineFunc)
		if not ok then
			error(string.format("%s have error %s", self.mainTplName, err), 2)
		end
	else
		local ok, err = pcall(func)
		if not ok then
			error(string.format("%s have error %s", self.mainTplName, err), 2)
		end
	end

	self.callbackSave(code)

	return table.concat(result, "")
end




-- new ariesLib
_M.new = function(self, ariesIns, ctx)
	-- sourceLine源码里面的行  finalLine最终渲染的行  includes 里面所有引入的模板名
	local tplIns = {
		sourceLine = 1,
		finalLine = 1,
		includes = {},
		ariesIns = ariesIns,
		finalTplChunks = {},
		ctx = {},	-- 传递给用户的ctx属性
		-- sourceMap 为渲染后的文件与源文件的行号对应表
		sourceMap = {},
	}

	-- 设置ctx
	tplIns.ctx = setmetatable(tools.clone(ctx or {}), { __index = ariesIns.ctx })

	return setmetatable(tplIns, {
		__index = tplLib
	})
end


return _M