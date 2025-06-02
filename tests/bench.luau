local testkit = require("@vendor/testkit")
local BENCH = testkit.benchmark()
local deep_clone = require("@vendor/deep_clone")
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

local box2_polygon = {
	regions = {
		{
			vector.create(-2.5, -2.5),
			vector.create(2.5, -2.5),
			vector.create(2.5, -7.5),
			vector.create(-2.5, -7.5),
		},
	},
	inverted = false,
}
print("Hola")
local box2_segments = polybool.segments(box2_polygon)

local combined = polybool.combine(box1, box2_segments)

local prepopulated_segments_1 = {}
local prepopulated_segments_2 = {}

for i = 1, 100 do
	table.insert(prepopulated_segments_1, box2_segments)
	table.insert(prepopulated_segments_2, box1)
end

-- BENCH("difference operation", function()
-- 	for i = 1, 100 do
-- 		polybool.difference_selector(combined)
-- 	end
-- end)

-- BENCH("segmenting polygons", function()
-- 	for i = 1, 100 do
-- 		polybool.segments(box2_polygon)
-- 	end
-- end)

BENCH("combining segments", function()
	for i = 1, 100 do
		polybool.combine(prepopulated_segments_1[i], prepopulated_segments_2[i])
	end
end)
