--!optimize 2
--!native
-- (c) Copyright 2016, Sean Connelly (@voidqk), http:--syntheti.cc
-- MIT License
-- Project Home: https:--github.com/voidqk/polybooljs
-- Converted to Lua by EgoMoose

--
-- provides the raw computation functions that takes epsilon into account
--
-- zero is defined to be between (-epsilon, epsilon) exclusive
--
local EPSILON = 0.000001
local NEG_EPSILON = -EPSILON

local function point_between(point: vector, left: vector, right: vector)
	-- p must be collinear with left->right
	-- returns false if p == left, p == right, or left == right
	local d_py_ly = point.y - left.y
	local d_rx_lx = right.x - left.x
	local d_px_lx = point.x - left.x
	local d_ry_ly = right.y - left.y

	local dot = d_px_lx * d_rx_lx + d_py_ly * d_ry_ly
	local sqlen = d_rx_lx * d_rx_lx + d_ry_ly * d_ry_ly
	-- if `dot` is 0, then `p` == `left` or `left` == `right` (reject)
	-- if `dot` is less than 0, then `p` is to the left of `left` (reject)
	-- if dot < EPSILON then
	-- return false
	-- end

	-- if `dot` > `sqlen`, then `p` is to the right of `right` (reject)
	-- therefore, if `dot - sqlen` is greater than 0, then `p` is to the right of `right` (reject)
	-- if dot - sqlen > -EPSILON then
	-- return false
	-- end

	return not ((dot < EPSILON) or (dot - sqlen > NEG_EPSILON))

	-- return true
end

local function lines_intersect(
	a0: vector,
	a1: vector,
	b0: vector,
	b1: vector
): (vector?, number?, number?)
	-- returns false if the lines are coincident (e.g., parallel or on top of each other)
	--
	-- returns an object if the lines intersect:
	--   {
	--     pt: [x, y],    where the intersection point is at
	--     alongA: where intersection point is along A,
	--     alongB: where intersection point is along B
	--   }
	--
	--  alongA and alongB will each be one of: -2, -1, 0, 1, 2
	--
	--  with the following meaning:
	--
	--    -2   intersection point is before segment's first point
	--    -1   intersection point is directly on segment's first point
	--     0   intersection point is between segment's first and second points (exclusive)
	--     1   intersection point is directly on segment's second point
	--     2   intersection point is after segment's second point
	local adx = a1.x - a0.x
	local ady = a1.y - a0.y
	local bdx = b1.x - b0.x
	local bdy = b1.y - b0.y

	local axb = adx * bdy - ady * bdx
	if math.abs(axb) < EPSILON then
		return nil, nil, nil
	end

	local dx = a0.x - b0.x
	local dy = a0.y - b0.y

	local a = (bdx * dy - bdy * dx) / axb
	local b = (adx * dy - ady * dx) / axb

	local point, along_a, along_b = vector.create(a0.x + a * adx, a0.y + a * ady), 0, 0

	-- categorize where intersection point is along A and B
	if a <= -EPSILON then
		along_a = -2
	elseif a < EPSILON then
		along_a = -1
	elseif a - 1 <= -EPSILON then
		along_a = 0
	elseif a - 1 < EPSILON then
		along_a = 1
	else
		along_a = 2
	end

	if b <= NEG_EPSILON then
		along_b = -2
	elseif b < EPSILON then
		along_b = -1
	elseif b - 1 <= NEG_EPSILON then
		along_b = 0
	elseif b - 1 < EPSILON then
		along_b = 1
	else
		along_b = 2
	end

	return point, along_a, along_b
end

return {
	value = EPSILON,

	lines_intersect = lines_intersect,
	point_between = point_between,
}
