pcall(require, "luacov")

print("------------------------------------")
print("Lua version: " .. (jit and jit.version or _VERSION))
print("------------------------------------")
print("")


local ok, err = pcall(function()
	local HAS_RUNNER = not not lunit
	local lunit = require "lunit"
	local TEST_CASE = lunit.TEST_CASE

	local LUA_VER = _VERSION
	local unpack, pow, bit32 = unpack, math.pow, bit32

	local _ENV = TEST_CASE"some_test_case"

end)


function test_1()

		-- unit test
		local Aries = require("aries")
		--local json = require("json")

		-- normal tpl
		local aries1 = Aries:new()

		local result, err = aries1:render("normalRender")
		assert(not err)
		local q = result:find("x=1")
		assert(q>0)
		print("---------- normarl test ok ----------")



		-- test tag
		local aries2 = Aries:new({
			startTag = "{{",
			endTag = "}}",
		})
		local result, err = aries2:render("tagRender")
		assert(not err)
		local q = result:find("x=1;")
		assert(q>0)
		print("---------- tag test ok ----------")


		-- test escape
		local aries3 = Aries:new({
			startTag = "{{",
			endTag = "}}",
		})
		local result, err = aries3:render("escapeRender")
		local q = result:find("x=&lt;&gt;")
		assert(q>0)
		print("---------- test escape ok ----------")


		-- test suffix
		local aries4 = Aries:new({
			fileSuffix = "aries",
		})

		local result, err = aries4:render("suffixRender")
		assert(not err)
		local q = result:find("x=1")
		assert(q>0)
		print("---------- test suffix ok ----------")

		-- test rootPath
		local aries5 = Aries:new({
			rootPath = "./tpl/inc",
		})
		local result, err = aries5:render("a")
		assert(not err)
		local q = result:find("x=2")
		assert(q>0)
		print("---------- test rootPath ok ----------")


		-- isShowDetailError test
		local aries6 = Aries:new()
		local result, err = aries6:render("error")
		assert(err == "error.html: 19 have error  unexpected symbol near 'end'")
		print("---------- test isShowDetailError true ok ----------")


		-- off isShowDetailError test
		local aries7 = Aries:new({
			isShowDetailError = false
		})
		local result, err = aries7:render("error")
		local q = err:find("unexpected symbol near 'end'")
		assert(q>0)
		print("---------- test isShowDetailError false ok ----------")



		-- time out test
		local aries8 = Aries:new({
			timeout=0.1,
			ctx = {
				num=36
			}
		})
		local result, err = aries8:render("timeout")
		local q = err:find("tmplate is timeout ")
		assert(q>0)
		print("---------- time out ok ----------")

		-- parent ctx
		local aries9 = Aries:new({
			ctx = {
				num=10
			}
		})
		local result, err = aries9:render("timeout")
		local q = result:find("89")
		assert(q>0)
		print("---------- parent ctx ok ----------")


		-- render ctx
		local aries9 = Aries:new({
			ctx = {
				num=10
			}
		})
		local result, err = aries9:render("timeout", {
				num=1
		})
		local q = result:find("1")
		assert(q>0)
		print("---------- render ctx ok ----------")


		-- getInclude
		local aries10 = Aries:new({
			getInclude = function(self, includeName)
							return [=[
								<% x=1 %>
								x=<%= x*999 %>
							]=]
						end,
		})

		local result, err = aries10:render("normalRender")
		assert(not err)
		local q = result:find("x=999")
		assert(q>0)
		print("---------- getInclude test ok ----------")


		-- inlcued file
		local aries11 = Aries:new({
			startTag = "{{",
			endTag = "}}",
		})

		local result, err = aries11:render("includeRender", {
				x= 1
		})
		assert(not err)
		local q = result:find("inc_c")
		assert(q>0)
		print("---------- inlcued file test ok ----------")


		-- inlcued error
		local aries12 = Aries:new({
			startTag = "{{",
			endTag = "}}",
		})

		local result, err = aries12:render("includeRender", {
				x= -1
		})
		--print(err)
		local q = err:find("includeRender.html: 4 >> inc/inc_err.html: 9 have error")
		assert(q>0)
		print("---------- inlcued error test ok ----------")




		-- minify tpl
		local aries13 = Aries:new({
				minify = function(self, renderStr)
							return "minify"
					   end,
		})

		local result, err = aries13:render("normalRender")
		assert(not err)
		local q = result:find("minify")
		assert(q>0)
		print("---------- minify test ok ----------")



		-- include getIncludesByName
		local aries14 = Aries:new({
			startTag = "{{",
			endTag = "}}",
		})

		local result, err = aries14:getIncludesByName("includeRender", {
				x= 1
		})
		--print(json.encode(result))
		local key1 = [[inc/inc_c]]
		local key2 = [[inc/inc_a]]
		local key3 = [[inc/inc_b]]
		local key4 = [[inc/inc_err]]

		assert(not err)
		assert(result[key1])
		assert(result[key2])
		assert(result[key3])
		assert(result[key4])

		print("---------- include getIncludesByName test ok ----------")




		-- include getIncludesByContent
		local aries14 = Aries:new({
			startTag = "{{",
			endTag = "}}",
		})

		local result, err = aries14:getIncludesByContent([=[

				 
			{{ if ctx.x<0  then }}

				{{ include inc/inc_err }}

			{{ else }}
				mainInclude{{ include inc/inc_a }}


			{{ end }}
			
			]=])


		-- print(json.encode(result))
		assert(not err)
		local key1 = [[inc/inc_c]]
		local key2 = [[inc/inc_a]]
		local key3 = [[inc/inc_b]]
		local key4 = [[inc/inc_err]]

		assert(result[key1])
		assert(result[key2])
		assert(result[key3])
		assert(result[key4])
		print("---------- include getIncludesByContent test ok ----------")



		-- test lock error
		local aries15 = Aries:new()
		local result, err = aries15:render("lock", {
			b=-1,
		})
		local q = err:find("lock.html: 7 have error  a is locked")
		assert(q>0)
		print("---------- lock error test ok ----------")


		-- test lock unlock error
		local aries16 = Aries:new()
		local result, err = aries16:render("lock", {
			b=1,
		})
		assert(not err)
		print("---------- lock unlock test ok ----------")



		print("---------- aries tpl all test ok ----------")


end

if ok then
	print("========= in lunit ==========")
	if not HAS_RUNNER then lunit.run() end
else
	print("========= not have lunit ==========")
	test_1()
	os.exit()
end



