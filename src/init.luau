--!optimize 2
--!native
--[[
 * @copyright 2016 Sean Connelly (@voidqk), http://syntheti.cc
 * @license MIT
 * @preserve Project Home: https://github.com/voidqk/polybooljs

   Converted to Lua by EgoMoose
--]]

local intersector = require("@self/intersector")
local segment_chainer = require("@self/segment_chainer")
local segment_selector = require("@self/segment_selector")
local types = require("@self/types")

local function segments(poly: types.Polygon): types.Segments
	local i = intersector.constructor_intersector(true)

	for _, reg in poly.regions do
		intersector.add_region_to_intersector(i, reg)
	end

	return {
		-- overload and im too lazy to deal with the type definitions
		segments = intersector.calculate_self_intersector(i, poly.inverted),
		inverted = poly.inverted,
	}
end

local function combine(segments1: types.Segments, segments2: types.Segments): types.CombinedSegments
	local i3 = intersector.constructor_intersector(false)

	return {
		combined = intersector.calculate_non_self_intersector(
			i3,
			segments1.segments,
			segments1.inverted,
			segments2.segments,
			segments2.inverted
		) :: any,
		inverted1 = segments1.inverted,
		inverted2 = segments2.inverted,
	}
end

local function selectUnion(combined: types.CombinedSegments)
	return {
		segments = segment_selector.union(combined.combined),
		inverted = combined.inverted1 or combined.inverted2,
	}
end

local function selectIntersect(combined: types.CombinedSegments)
	return {
		segments = segment_selector.intersect(combined.combined),
		inverted = combined.inverted1 and combined.inverted2,
	}
end

local function selectDifference(combined: types.CombinedSegments)
	return {
		segments = segment_selector.difference(combined.combined),
		inverted = combined.inverted1 and not combined.inverted2,
	}
end

local function selectDifferenceRev(combined: types.CombinedSegments)
	return {
		segments = segment_selector.difference_rev(combined.combined),
		inverted = not combined.inverted1 and combined.inverted2,
	}
end

local function selectXor(combined: types.CombinedSegments)
	return {
		segments = segment_selector.xor(combined.combined),
		inverted = combined.inverted1 ~= combined.inverted2,
	}
end

local function polygon(segments: types.Segments): types.Polygon
	return {
		regions = segment_chainer(segments.segments),
		inverted = segments.inverted,
	}
end

-- helper functions for common operations
local function union(poly1: types.Polygon, poly2: types.Polygon)
	local seg1 = segments(poly1)
	local seg2 = segments(poly2)
	local comb = combine(seg1, seg2)
	local seg3 = selectUnion(comb)

	return polygon(seg3)
end

local function intersect(poly1: types.Polygon, poly2: types.Polygon)
	local seg1 = segments(poly1)
	local seg2 = segments(poly2)
	local comb = combine(seg1, seg2)
	local seg3 = selectIntersect(comb)

	return polygon(seg3)
end

local function difference(poly1: types.Polygon, poly2: types.Polygon)
	local seg1 = segments(poly1)
	local seg2 = segments(poly2)
	local comb = combine(seg1, seg2)
	local seg3 = selectDifference(comb)

	return polygon(seg3)
end

local function differenceRev(poly1: types.Polygon, poly2: types.Polygon)
	local seg1 = segments(poly1)
	local seg2 = segments(poly2)
	local comb = combine(seg1, seg2)
	local seg3 = selectDifferenceRev(comb)

	return polygon(seg3)
end

local function xor(poly1: types.Polygon, poly2: types.Polygon)
	local seg1 = segments(poly1)
	local seg2 = segments(poly2)
	local comb = combine(seg1, seg2)
	local seg3 = selectXor(comb)

	return polygon(seg3)
end

return {
	polygon = polygon,
	segments = segments,
	combine = combine,

	union = union,
	intersect = intersect,
	difference = difference,
	difference_rev = differenceRev,
	xor = xor,

	union_selector = selectUnion,
	difference_selector = selectDifference,
}
