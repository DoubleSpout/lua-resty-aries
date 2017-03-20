
	local Aries = require("aries")
    local aries1 = Aries:new({
                -- startTag = "{{",
			    -- endTag = "}}",
    })

    local result, err = aries1:render("error", {
            x= -1
	})

    print("----------------------------------")
    print(result)
    print("------------------------------")
    print(err)