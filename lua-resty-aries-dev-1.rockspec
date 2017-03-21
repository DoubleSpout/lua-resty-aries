package = "lua-resty-aries"
version = "dev-1"
source = {
    url = "git://github.com/DoubleSpout/lua-resty-aries.git"
}
description = {
    summary = "Templating Engine (HTML) for Lua and OpenResty",
    detailed = "lua-resty-aries is a compiling (HTML) templating engine for Lua and OpenResty.It can correct postion template's error line.",
    homepage = "https://github.com/DoubleSpout/lua-resty-aries",
    maintainer = "DoubleSpout <53822985@qq.com>",
    license = "MIT"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        ["resty.aries"]                 = "lib/resty/aries.lua",
        ["resty.aries.tools"]           = "lib/resty/aries/tools.lua",
        ["resty.aries.lib"]             = "lib/resty/aries/lib.lua"
    }
}
