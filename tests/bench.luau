local testkit = require("@vendor/testkit")
local BENCH = testkit.benchmark()
local polybool = require("@polybool")

local box1 = polybool.segments({
	regions = {
		{
			vector.create(0, 0),
			vector.create(5, 0),
			vector.create(5, -5),
			vector.create(0, -5),
		},
	},
	inverted = false,
})

local box2 = polybool.segments({
	regions = {
		{
			vector.create(-2.5, -2.5),
			vector.create(2.5, -2.5),
			vector.create(2.5, -7.5),
			vector.create(-2.5, -7.5),
		},
	},
	inverted = false,
})

local combined = polybool.combine(box1, box2)

BENCH("difference operation", function()
	for i = 1, 100 do
		polybool.difference_selector(combined)
	end
end)
