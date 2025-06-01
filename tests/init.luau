local TEST, CASE, CHECK, FINISH = require("@vendor/testkit").test()

local equals = require("@vendor/equals")
local polybool = require("@polybool/")

local triangle1 = {
	regions = { {
		vector.create(0, 0),
		vector.create(5, 10),
		vector.create(10, 0),
	} },
	inverted = false,
}

local triangle2 = {
	regions = { {
		vector.create(5, 0),
		vector.create(10, 10),
		vector.create(15, 0),
	} },
	inverted = false,
}

local box1 = {
	regions = {
		{
			vector.create(0, 0),
			vector.create(5, 0),
			vector.create(5, -5),
			vector.create(0, -5),
		},
	},
	inverted = false,
}

TEST("boolean operations", function()
	CASE("basic intersection")
	do
		local intersection_op = polybool.intersect(triangle1, triangle2)
		local result_polygon = {
			inverted = false,
			regions = { { vector.create(10, 0), vector.create(5, 0), vector.create(7.5, 5) } },
		}

		CHECK(equals.deep_equal(intersection_op :: any, result_polygon, 0.001))
	end

	CASE("basic union")
	do
		local union_op = polybool.union(triangle1, triangle2)
		local result_polygon = {
			inverted = false,

			regions = {
				{
					vector.create(10, 10),
					vector.create(7.5, 5),
					vector.create(5, 10),
					vector.create(0, 0),
					vector.create(15, 0),
				},
			},
		}

		CHECK(equals.deep_equal(union_op :: any, result_polygon))
	end
end)

FINISH()
