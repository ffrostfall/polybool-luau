local TEST, CASE, CHECK, FINISH = require("@vendor/testkit").test()

local epsilon = require("@polybool/epsilon")
local equals = require("@vendor/equals")
local polybool = require("@polybool/")
local prettyprint = require("@vendor/prettyprint")

local EPSILON = 0.000000001

local function points_same_x(point1: vector, point2: vector): boolean
	return math.abs(point1.x - point2.x) < EPSILON
end

local function points_same_y(point1: vector, point2: vector): boolean
	return math.abs(point1.y - point2.y) < EPSILON
end

local function points_compare_old(p1: vector, p2: vector)
	-- returns -1 if p1 is smaller, 1 if p2 is smaller, 0 if equal
	if points_same_x(p1, p2) then
		return if points_same_y(p1, p2) then 0 elseif p1.y < p2.y then -1 else 1
	end

	return if p1.x < p2.x then -1 else 1
end

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

local box2 = {
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

TEST("boolean operations", function()
	CASE("epsilon point comparison fuzz testing")
	do
		local mismatches = {}
		local amount = 10000
		for i = 1, amount do
			local v1, v2 = vector.create(i - amount, i), vector.create(i, i - amount)
			local v3, v4 = vector.create(i, i - amount), vector.create(i - amount, i)

			if points_compare_old(v1, v2) ~= epsilon.points_compare(v1, v2) then
				table.insert(
					mismatches,
					`new: [{epsilon.points_compare(v1, v2)}], old: [{points_compare_old(v1, v2)}] | vector.create({v1}), vector.create({v2})`
				)
			end

			if points_compare_old(v3, v4) ~= epsilon.points_compare(v3, v4) then
				table.insert(
					mismatches,
					`new: [{epsilon.points_compare(v3, v4)}], old: [{points_compare_old(v3, v4)}] | vector.create({v3}), vector.create({v4})`
				)
			end
		end

		if #mismatches ~= 0 then
			print(table.concat(mismatches, "\n"))
			CHECK(false)
		end
	end

	CASE("epsilon point comparison edge case")
	do
		local v1, v2 =
			vector.create(
				0.0000020005002170364605,
				0.0000020005002170364605,
				0.0000020005002170364605
			),
			vector.create(
				0.000001999500227611861,
				0.000001999500227611861,
				0.000001999500227611861
			)

		print("new", epsilon.points_compare(v1, v2))
		print("old", points_compare_old(v1, v2))
		CHECK(epsilon.points_compare(v1, v2) == points_compare_old(v1, v2))
	end

	CASE("basic intersection")
	do
		local intersection_op = polybool.intersect(triangle1, triangle2)
		local result_polygon = {
			inverted = false,
			regions = { { vector.create(10, 0), vector.create(5, 0), vector.create(7.5, 5) } },
		}

		CHECK(equals.deep_equal(intersection_op :: any, result_polygon, EPSILON))

		local intersection_op2 = polybool.intersect(triangle1, triangle2)
		local result_polygon2 = {
			inverted = false,
			regions = { { vector.create(10, 0), vector.create(5, 0), vector.create(7.5, 5) } },
		}

		CHECK(equals.deep_equal(intersection_op2 :: any, result_polygon2, EPSILON))
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

		CHECK(equals.deep_equal(union_op :: any, result_polygon, EPSILON))
	end

	CASE("basic difference")
	do
		local difference_op = polybool.difference(box1, box2)
		local result_polygon = {
			inverted = false,

			regions = {
				{
					vector.create(5, 0),
					vector.create(5, -5),
					vector.create(2.5, -5),
					vector.create(2.5, -2.5),
					vector.create(0, -2.5),
					vector.create(0, 0),
				},
			},
		}

		CHECK(equals.deep_equal(difference_op :: any, result_polygon, EPSILON))
	end
end)

FINISH()
