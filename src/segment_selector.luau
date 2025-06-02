-- (c) Copyright 2016, Sean Connelly (@voidqk), http:--syntheti.cc
-- MIT License
-- Project Home: https:--github.com/voidqk/polybooljs
-- Converted to Lua by EgoMoose

--
-- filter a list of segments based on boolean operations
--
local types = require("./types")

--stylua: ignore
local UNION = {
	0, 2, 1, 0,
	2, 2, 0, 0,
	1, 0, 1, 0,
	0, 0, 0, 0
}

--stylua: ignore
local INTERSECT = {
	0, 0, 0, 0,
	0, 2, 0, 2,
	0, 0, 1, 1,
	0, 2, 1, 0
}

--stylua: ignore
local DIFFERENCE = {
	0, 0, 0, 0,
	2, 0, 2, 0,
	1, 1, 0, 0,
	0, 1, 2, 0
}

--stylua: ignore
local DIFFERENCE_REV = {
	0, 2, 1, 0,
	0, 0, 1, 1,
	0, 2, 0, 2,
	0, 0, 0, 0
}

-- stylua: ignore
local XOR = {
	0, 2, 1, 0,
	2, 0, 0, 1,
	1, 0, 0, 2,
	0, 1, 2, 0
}

local SEGMENT_TEMPLATE = {
	start = vector.zero,
	finish = vector.zero,
	my_fill = {
		above = nil, -- is there fill above us?
		below = nil, -- is there fill below us?
	},
	other_fill = nil,
}

local function selector_func(segments: { types.Segment }, selection: { number }): { types.Segment }
	local result = {}

	for _, seg in segments do
		local other_filled = seg.other_filled

		local index = selection[(if seg.my_fill_above then 8 else 0) + (if seg.my_fill_below
			then 4
			else 0) + (if other_filled and seg.other_filled_above then 2 else 0) + (if other_filled
				and seg.other_filled_below
			then 1
			else 0) + 1]

		if index == 0 then
			continue
		end

		-- copy the segment to the results, while also calculating the fill status
		local cloned = table.clone(SEGMENT_TEMPLATE)

		cloned.start = seg.start
		cloned.finish = seg.finish
		cloned.my_fill_above = index == 1
		cloned.my_fill_below = index == 2

		table.insert(result, cloned)
	end

	return result
end

local function union(segments: { types.Segment }): { types.Segment } -- primary | secondary
	return (selector_func(segments, UNION))
end

local function intersect(segments: { types.Segment }): { types.Segment } -- primary & secondary
	return (selector_func(segments, INTERSECT))
end

local function difference(segments: { types.Segment }): { types.Segment } -- primary - secondary
	return (selector_func(segments, DIFFERENCE))
end

local function difference_rev(segments: { types.Segment }): { types.Segment } -- secondary - primary
	return (selector_func(segments, DIFFERENCE_REV))
end

local function xor(segments: { types.Segment }): { types.Segment } -- primary ^ secondary
	return (selector_func(segments, XOR))
end

return {
	union = union,
	xor = xor,
	difference = difference,
	difference_rev = difference_rev,
	intersect = intersect,
}
