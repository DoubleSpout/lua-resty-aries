
# lua-resty-aries —— openresty and lua multi-function template. 
[![Licence](http://img.shields.io/badge/Licence-MIT-brightgreen.svg)](LICENSE)
[![Build Status](https://travis-ci.org/DoubleSpout/lua-resty-aries.png?branch=master)](https://travis-ci.org/DoubleSpout/lua-resty-aries)

You can use `lua-resty-aries` to render template and safety run lua code string.The template or code string can be from any kind of data source, such like: file, redis, mysql or mongodb, any you like. 

**support openresty1.0.6+, lua5.1+**

lua-resty-aries support linux/ubantu, windows and mac.

you need install lua/luajit first [http://www.lua.org/](http://www.lua.org/ "Lua")

##Install

	

##Get Started

	local Aries = require("aries")
    local aries1 = Aries:new()

    local result, err = aries1:compile([=[ 
			<% hello = "welcome to lua-resty-aries" %>
			<h1><center><%= hello %></center></h1>
	 ]=])

    print(result)	-- <h1><center><%= hello %></center></h1>
	   
##Using file template

We create` index.html` file at `{workdir}/tpl/index.html`

	<!DOCTYPE html>
	<html>
	<head>
		<title><%= ctx.title %></title>
	</head>
	<body>
		<% hello = "welcome to lua-resty-aries" %>
		<h1><center><%= hello %></center></h1>
	</body>
	</html>

We can render the template like this:

	local Aries = require("aries")
    local aries1 = Aries:new()

    local result, err = aries1:render("index", {
		title="lua-resty-aries title"
	})

    print(result)

##A littel complex example

We create tpl/index2.html like this

	<!DOCTYPE html>
	<html>
	<head>
		<title><%= ctx.title %></title>
	</head>
	<body>
		<% hello = "welcome to lua-resty-aries" %>
		<h1><center><%= hello %></center></h1>
		<% if (ctx.loop or 0) > 0 then %>
			<% for i=1,ctx.loop,1 do %>
				<% include inc/loop %>
			<% end %>
		<% else %>
			<% include inc/noloop %>
		<% end %>
	</body>
	</html>

create inc/noloop.html

	<h1>ctx noloop</h1>
	this must be occur an error, undefined function <% ctx.error() %>
	ctx.loop=<%= ctx.loop %>

create inc/loop.html

	<h1>ctx doloop</h1>
	ctx.loop=<%= ctx.loop %>

create render code:

	local Aries = require("aries")
    local aries1 = Aries:new()

    local result, err = aries1:render("index2", {
		title="lua-resty-aries title",
        loop=10,	--change loop to control loop times
	})

    print(result)

if we change render code like this, this must be occur an error:

	local Aries = require("aries")
    local aries1 = Aries:new()

    local result, err = aries1:render("index2", {
		title="lua-resty-aries title",
        loop=-1,	--not loop make an errror
	})

    print(err)	-- index2.html: 14 >> inc/noloop.html: 2 have error  attempt to call field 'error' (a nil value)

we can get error msg, correct to postion the error line, even it at include template:

	index2.html: 14 >> inc/noloop.html: 2 have error  attempt to call field 'error' (a nil value)

##Aries Constructor and Instance
   
`Aries` Constructor method. Every time, you call `Aries:new(opt)` will return a new `Aries instance`.

	local Aries = require("aries")
	local ariesInstance = Aries:new(opt)

`opt` all attribute, all of these attributes are `option`:

	-- below is the default value
	opt = {
		-- custom left half tag
		startTag = "<%",

		-- custom right half tag
		endTag = "%>",

		-- custom the template file's suffix 
		fileSuffix = "html",

		-- change root of template folder path
		rootPath = "./tpl",

		-- works fine at linux and windows
		sep = "/",

		-- if occur error, show the error line and msg, this must set off in production to increase performance
		isShowDetailError = true,  

		-- template render timeout, unit seconde
		timeout = 10,

		-- instance level object to put to template
		ctx = {},

		-- change template data source, you can get template from redis or other data source.
		-- default is from file system
		getInclude = function(self, includeName)
						-- simple example get template from redis
						-- local data, err = redis_conn:get(includeName)
						-- return data == ngx.null and "" or data
						return self.readfile(string.format("%s%s%s.%s", self.rootPath, self.sep, includeName, self.fileSuffix))
					end,

		-- before return string ,you can minify the html or xml string
		-- default do nothing
		minify = function(self, renderStr)
						return renderStr
				end,

	}

`Aries Instance` Method

	-- get all the include template name by name
	local includeNameTable, err = ariesInstance:getIncludesByName(tplName string)

	-- get all the include template name by string code
	local includeNameTable, err = ariesInstance:getIncludesByContent(tplName string)

	-- render a template by name
	-- here ctx inherit the ariesInstance.ctx
	local renderStr, err = ariesInstance:render(tplName string, [ctx table])

	-- render a template by string code
	-- here ctx inherit the ariesInstance.ctx
	local renderStr, err = ariesInstance:compile(tplName string, [ctx table, tplName string])


	
##Template API (using at template)
	
We can use `include {templateName}` to include other template, `lua-resty-aries` will call `ariesInstance:getInclude({templateName})` everytime.(include first we call `ariesInstance:render({templateName})`). example:

	<% include inc/header %>	-- notice,default not to add file suffix

print on template example:
	
	-- will show hello world &lt; &gt; &quot; &apos;
	<%= string.format("hello world %s %s %s %s", "<", ">", '"', "'") %>
	
	-- will show hello world < > " '
	<%= string.format("hello world %s %s %s %s", "<", ">", '"', "'") %>

`ctx` table on template:

	-- like <%= {str} %>
	ctx.print(str string)

 	-- like <%- {str} %> 
	ctx.rawPrint(str string)

	-- lock some ctx attribute, before excute ctx.unlock({field}), you can't change such {field} value
	-- example:
	-- ctx.a = 1
	-- ctx.lock(a)
	-- ctx.a = 2 -- occur error
	ctx.lock({field})


	-- unlock field
	-- example
	-- ctx.a = 1
	-- ctx.lock(a)
	-- ctx.unlock(a)
	-- ctx.a = 2 -- ok
	ctx.unlock({field})
	