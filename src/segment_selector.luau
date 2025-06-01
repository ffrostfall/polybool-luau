-- (c) Copyright 2016, Sean Connelly (@voidqk), http:--syntheti.cc
-- MIT License
-- Project Home: https:--github.com/voidqk/polybooljs
-- Converted to Lua by EgoMoose

--
-- filter a list of segments based on boolean operations
--
local types = require("./types")

local function selector_func(segments: { types.Segment }, selection: { number }): { types.Segment }
	local result = {}

	for _, seg in segments do
		local index = (if seg.my_fill.above then 8 else 0)
			+ (if seg.my_fill.below then 4 else 0)
			+ (if seg.other_fill and seg.other_fill.above then 2 else 0)
			+ (if seg.other_fill and seg.other_fill.below then 1 else 0)
			+ 1

		if selection[index] ~= 0 then
			-- copy the segment to the results, while also calculating the fill status
			table.insert(result, {
				start = seg.start,
				finish = seg.finish,

				myFill = {
					above = selection[index] == 1, -- 1 if filled above
					below = selection[index] == 2, -- 2 if filled below
				},

				otherFill = nil,
			})
		end
	end

	return result
end

local function union(segments: { types.Segment }): { types.Segment } -- primary | secondary
	-- above1 below1 above2 below2    Keep?               Value
	--    0      0      0      0   =>   no                  0
	--    0      0      0      1   =>   yes filled below    2
	--    0      0      1      0   =>   yes filled above    1
	--    0      0      1      1   =>   no                  0
	--    0      1      0      0   =>   yes filled below    2
	--    0      1      0      1   =>   yes filled below    2
	--    0      1      1      0   =>   no                  0
	--    0      1      1      1   =>   no                  0
	--    1      0      0      0   =>   yes filled above    1
	--    1      0      0      1   =>   no                  0
	--    1      0      1      0   =>   yes filled above    1
	--    1      0      1      1   =>   no                  0
	--    1      1      0      0   =>   no                  0
	--    1      1      0      1   =>   no                  0
	--    1      1      1      0   =>   no                  0
	--    1      1      1      1   =>   no                  0
	--stylua: ignore
	return selector_func(segments, {
		0, 2, 1, 0,
		2, 2, 0, 0,
		1, 0, 1, 0,
		0, 0, 0, 0
	})
end
local function intersect(segments: { types.Segment }): { types.Segment } -- primary & secondary
	-- above1 below1 above2 below2    Keep?               Value
	--    0      0      0      0   =>   no                  0
	--    0      0      0      1   =>   no                  0
	--    0      0      1      0   =>   no                  0
	--    0      0      1      1   =>   no                  0
	--    0      1      0      0   =>   no                  0
	--    0      1      0      1   =>   yes filled below    2
	--    0      1      1      0   =>   no                  0
	--    0      1      1      1   =>   yes filled below    2
	--    1      0      0      0   =>   no                  0
	--    1      0      0      1   =>   no                  0
	--    1      0      1      0   =>   yes filled above    1
	--    1      0      1      1   =>   yes filled above    1
	--    1      1      0      0   =>   no                  0
	--    1      1      0      1   =>   yes filled below    2
	--    1      1      1      0   =>   yes filled above    1
	--    1      1      1      1   =>   no                  0
	--stylua: ignore
	return selector_func(segments, {
		0, 0, 0, 0,
		0, 2, 0, 2,
		0, 0, 1, 1,
		0, 2, 1, 0
	})
end
local function difference(segments: { types.Segment }): { types.Segment } -- primary - secondary
	-- above1 below1 above2 below2    Keep?               Value
	--    0      0      0      0   =>   no                  0
	--    0      0      0      1   =>   no                  0
	--    0      0      1      0   =>   no                  0
	--    0      0      1      1   =>   no                  0
	--    0      1      0      0   =>   yes filled below    2
	--    0      1      0      1   =>   no                  0
	--    0      1      1      0   =>   yes filled below    2
	--    0      1      1      1   =>   no                  0
	--    1      0      0      0   =>   yes filled above    1
	--    1      0      0      1   =>   yes filled above    1
	--    1      0      1      0   =>   no                  0
	--    1      0      1      1   =>   no                  0
	--    1      1      0      0   =>   no                  0
	--    1      1      0      1   =>   yes filled above    1
	--    1      1      1      0   =>   yes filled below    2
	--    1      1      1      1   =>   no                  0
	--stylua: ignore
	return selector_func(segments, {
		0, 0, 0, 0,
		2, 0, 2, 0,
		1, 1, 0, 0,
		0, 1, 2, 0
	})
end
local function difference_rev(segments: { types.Segment }): { types.Segment } -- secondary - primary
	-- above1 below1 above2 below2    Keep?               Value
	--    0      0      0      0   =>   no                  0
	--    0      0      0      1   =>   yes filled below    2
	--    0      0      1      0   =>   yes filled above    1
	--    0      0      1      1   =>   no                  0
	--    0      1      0      0   =>   no                  0
	--    0      1      0      1   =>   no                  0
	--    0      1      1      0   =>   yes filled above    1
	--    0      1      1      1   =>   yes filled above    1
	--    1      0      0      0   =>   no                  0
	--    1      0      0      1   =>   yes filled below    2
	--    1      0      1      0   =>   no                  0
	--    1      0      1      1   =>   yes filled below    2
	--    1      1      0      0   =>   no                  0
	--    1      1      0      1   =>   no                  0
	--    1      1      1      0   =>   no                  0
	--    1      1      1      1   =>   no                  0
	--stylua: ignore
	return selector_func(segments, {
		0, 2, 1, 0,
		0, 0, 1, 1,
		0, 2, 0, 2,
		0, 0, 0, 0
	})
end
local function xor(segments: { types.Segment }): { types.Segment } -- primary ^ secondary
	-- above1 below1 above2 below2    Keep?               Value
	--    0      0      0      0   =>   no                  0
	--    0      0      0      1   =>   yes filled below    2
	--    0      0      1      0   =>   yes filled above    1
	--    0      0      1      1   =>   no                  0
	--    0      1      0      0   =>   yes filled below    2
	--    0      1      0      1   =>   no                  0
	--    0      1      1      0   =>   no                  0
	--    0      1      1      1   =>   yes filled above    1
	--    1      0      0      0   =>   yes filled above    1
	--    1      0      0      1   =>   no                  0
	--    1      0      1      0   =>   no                  0
	--    1      0      1      1   =>   yes filled below    2
	--    1      1      0      0   =>   no                  0
	--    1      1      0      1   =>   yes filled above    1
	--    1      1      1      0   =>   yes filled below    2
	--    1      1      1      1   =>   no                  0
	--stylua: ignore
	return selector_func(segments, {
		0, 2, 1, 0,
		2, 0, 0, 1,
		1, 0, 0, 2,
		0, 1, 2, 0
	})
end

return {
	union = union,
	xor = xor,
	difference = difference,
	difference_rev = difference_rev,
	intersect = intersect,
}
