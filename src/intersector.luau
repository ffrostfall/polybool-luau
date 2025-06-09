--!optimize 2
--!native
--[[
	Adapted from PolyBool (github.com/voidqk/polybooljs) under the MIT license.
	(c) 2016 Sean Connelly (@voidqk)
	
	Original Lua port by EgoMoose.
	Refactor and optimisations by Elttob.
]]

--[[
	The core workhorse of the module, used for resolving intersecting segments.
]]

local epsilon = require("./epsilon")
local types = require("./types")

local EPSILON = 0.0001
local NEG_EPSILON = -0.0001

local table_remove = table.remove
local table_find = table.find
local table_clone = table.clone

local current_event_root: { Event } = table.create(32, nil :: any)

type Event = {
	is_start: boolean,
	point: vector,
	seg: types.Segment,
	primary: boolean,
	other: Event?,
	status: Event?,
}

local TEMPLATE: types.Segment = {
	start = vector.zero,
	finish = vector.zero,
	my_fill_above = false,
	my_fill_below = false,
	other_filled = false,
	-- other_filled_above = false,
	-- other_filled_below = false,
}

local function segment_new(start: vector, finish: vector): types.Segment
	local cloned = table_clone(TEMPLATE)
	cloned.start, cloned.finish = start, finish
	return cloned
end

local function points_collinear(pt1: vector, pt2: vector, pt3: vector)
	-- does pt1->pt2->pt3 make a straight line?
	-- essentially this is just checking to see if the slope(pt1->pt2) === slope(pt2->pt3)
	-- if slopes are equal, then they must be collinear, because they share pt2
	return math.abs((pt1.x - pt2.x) * (pt2.y - pt3.y) - (pt2.x - pt3.x) * (pt1.y - pt2.y))
		< EPSILON
end

local function point_above_or_on_line(point: vector, left: vector, right: vector): boolean
	local left_x, left_y = left.x, left.y

	return (right.x - left_x) * (point.y - left_y) - (right.y - left_y) * (point.x - left_x)
		>= -EPSILON
end

local function point_between(point: vector, left: vector, right: vector): boolean
	local d_py_ly = point.y - left.y
	local d_rx_lx = right.x - left.x
	local d_px_lx = point.x - left.x
	local d_ry_ly = right.y - left.y

	local dot = (d_px_lx * d_rx_lx) + (d_py_ly * d_ry_ly)
	local sqlen = (d_rx_lx * d_rx_lx) + (d_ry_ly * d_ry_ly)

	return not ((dot < EPSILON) or (dot - sqlen > NEG_EPSILON))
end

local function points_compare(point1: vector, point2: vector): number
	if vector.magnitude(point1 - point2) <= EPSILON then
		return 0
	end

	if math.abs(point1.x - point2.x) < EPSILON then
		return if point1.y < point2.y then -1 else 1
	end

	return if point1.x < point2.x then -1 else 1
end

local function points_same(p1: vector, p2: vector): boolean
	return vector.magnitude(p1 - p2) < EPSILON
end

local function event_compare(
	iter_event: Event,
	p1_is_start: boolean,
	p1_1: vector,
	p1_2: vector
): boolean
	local p2_is_start = iter_event.is_start
	local p2_1 = iter_event.point
	local p2_2 = (iter_event.other :: any).point

	-- compare the selected points first
	local comp = points_compare(p1_1, p2_1)
	if comp ~= 0 then
		return comp < 0 -- the selected points are the same
	elseif vector.magnitude(p1_1 - p2_2) < EPSILON then -- if the non-selected points are the same too...
		return false
	elseif p1_is_start ~= p2_is_start then -- if one is a start and the other isn't...
		-- favor the one that isn't the start
		return not p1_is_start
	end

	-- otherwise, we'll have to calculate which one is below the other manually
	return not if p2_is_start
		then point_above_or_on_line(p1_2, p2_1, p2_2)
		else point_above_or_on_line(p1_2, p2_2, p2_1)
end

local function find_event_comparison(here: Event, event: Event): boolean
	local ev1_seg, ev2_seg = event.seg, here.seg
	local a1 = ev1_seg.start
	local b1 = ev2_seg.start
	local b2 = ev2_seg.finish

	if points_collinear(a1, b1, b2) then
		local a2 = ev1_seg.finish

		return points_collinear(a2, b1, b2) or point_above_or_on_line(a2, b1, b2)
	end

	return (point_above_or_on_line(a1, b1, b2))
end

local function custom_table_insert<T>(array: { T }, at: number, value: T)
	local len = #array

	for i = len + 1, at, -1 do
		array[i + 1] = array[i]
	end

	array[at] = value
end

local function event_root_insert_before<U...>(
	node: Event,
	p1_is_start: boolean,
	p1_1: vector,
	p1_2: vector
)
	local length: number = #current_event_root

	if length < 1 then
		current_event_root[1] = node
		return
	end

	local low: number = 1
	local high: number = length

	while high > low do
		local index: number = bit32.rshift(low + high, 1)
		if event_compare(current_event_root[index], p1_is_start, p1_1, p1_2) then
			high = index
		else
			low = index + 1
		end
	end

	if event_compare(current_event_root[high], p1_is_start, p1_1, p1_2) then
		custom_table_insert(current_event_root, high, node)
	else
		current_event_root[length + 1] = node
	end
end

local function status_array_find_transition(array: { Event }, other_event: Event): number
	local length = #array

	if length < 1 then
		return 1
	end

	local low: number = 1
	local high: number = length

	while high > low do
		local index: number = bit32.rshift(low + high, 1)
		if find_event_comparison(array[index], other_event) then
			high = index
		else
			low = index + 1
		end
	end

	if find_event_comparison(array[high], other_event) then
		return high
	else
		return length + 1
	end
end

local function event_add_segment_start(seg: types.Segment, primary: boolean): Event
	local ev_start: Event = {
		is_start = true,
		point = seg.start,
		seg = seg,
		primary = primary,
		other = nil,
		status = nil,
	}

	event_root_insert_before(ev_start, true, seg.start, seg.finish)

	return ev_start
end

local TEMPLATEAB = {
	is_start = false,
	point = vector.zero,
	seg = {},
	primary = false,
	other = {},
}

local function event_add_segment(seg: types.Segment, primary: boolean)
	local event = event_add_segment_start(seg, primary)

	local ev_end = table_clone(TEMPLATEAB)
	ev_end.point = seg.finish
	ev_end.seg = seg
	ev_end.primary = primary
	ev_end.other = event
	-- local ev_end: Event = {
	-- 	is_start = false,
	-- 	point = seg.finish,
	-- 	seg = seg,
	-- 	primary = primary,
	-- 	other = event,
	-- }

	event.other = ev_end
	event_root_insert_before(ev_end, false, seg.finish, event.point)
end

local function event_update_end(event: Event, finish: vector)
	-- slides an finish backwards
	--   (start)------------(finish)    to:
	--   (start)---(finish)
	table_remove(current_event_root, table_find(current_event_root, event.other))
	event.seg.finish = finish
	event.other.point = finish

	event_root_insert_before(event.other, event.other.is_start, finish, event.point)
end

local function event_divide(event: Event, point: vector)
	local cloned = table_clone(event.seg)
	cloned.other_filled, cloned.start = false, point
	event_update_end(event, point)
	event_add_segment(cloned, event.primary)
end

local function check_intersection(ev1: Event, ev2: Event): Event?
	-- returns the segment equal to ev1, or false if nothing equal
	local seg1: types.Segment = ev1.seg
	local seg2: types.Segment = ev2.seg
	local a1: vector = seg1.start
	local a2: vector = seg1.finish
	local b1: vector = seg2.start
	local b2: vector = seg2.finish

	local intersection_point: vector?, along_a: number?, along_b: number? =
		epsilon.lines_intersect(a1, a2, b1, b2)

	if not intersection_point then
		-- segments are parallel or coincident

		-- if points aren't collinear, then the segments are parallel, so no intersections
		if (not points_collinear(a1, a2, b1)) or points_same(a1, b2) then
			return nil
		end
		-- otherwise, segments are on top of each other somehow (aka coincident)

		local a1_equ_b1: boolean = points_same(a1, b1)
		local a2_equ_b2: boolean = points_same(a2, b2)

		if a1_equ_b1 and a2_equ_b2 then
			return ev2 -- segments are exactly equal
		end

		local a2_between: boolean = not a2_equ_b2 and point_between(a2, b1, b2)

		if a1_equ_b1 then
			if a2_between then
				--  (a1)---(a2)
				--  (b1)----------(b2)
				event_divide(ev2, a2)
			else
				--  (a1)----------(a2)
				--  (b1)---(b2)
				event_divide(ev1, b2)
			end
			return ev2
		elseif not a1_equ_b1 and point_between(a1, b1, b2) then
			if not a2_equ_b2 then
				-- make a2 equal to b2
				if a2_between then
					--         (a1)---(a2)
					--  (b1)-----------------(b2)
					event_divide(ev2, a2)
				else
					--         (a1)----------(a2)
					--  (b1)----------(b2)
					event_divide(ev1, b2)
				end
			end

			--         (a1)---(a2)
			--  (b1)----------(b2)
			event_divide(ev2, a1)
		end
	else -- otherwise, lines intersect at i.point, which may or may not be between the endpoints
		-- is A divided between its endpoints? (exclusive)
		if along_a == 0 then
			if along_b == -1 then -- yes, at exactly b1
				event_divide(ev1, b1)
			elseif along_b == 0 then -- yes, somewhere between B's endpoints
				event_divide(ev1, intersection_point)
			elseif along_b == 1 then -- yes, at exactly b2
				event_divide(ev1, b2)
			end
		elseif along_b == 0 then
			if along_a == -1 then -- yes, at exactly a1
				event_divide(ev2, a1)
			-- elseif along_a == 0 then -- yes, somewhere between A's endpoints (exclusive)
			-- 	-- This never gets hit
			-- 	event_divide(event_root, ev2, intersection_point)
			elseif along_a == 1 then -- yes, at exactly a2
				event_divide(ev2, a2)
			end
		end
	end

	return nil
end

local function calculate(
	primary_poly_inverted: boolean,
	secondary_poly_inverted: boolean,
	self_intersection: boolean
): { types.Segment }
	-- if selfIntersection is true then there is no secondary polygon, so that isn't used

	-- status logic
	local status_root: { Event } = table.create(16) :: { Event }

	-- main event loop
	local segments = table.create(32) :: { types.Segment }
	while current_event_root[1] do
		local event: Event = current_event_root[1]
		local seg = event.seg

		if event.is_start then
			local transition_index = status_array_find_transition(status_root, event)

			local above = status_root[transition_index - 1]
			local below = status_root[transition_index]

			local eve = (above and check_intersection(event, above))
				or (below and check_intersection(event, below))

			-- This is not a bottleneck, it only runs when we're doing operations
			if eve then
				-- event and eve are equal
				-- we'll keep eve and throw away event

				-- merge event.seg's fill information into eve.seg

				local eve_seg = eve.seg

				if self_intersection then
					-- merge two segments that belong to the same polygon
					-- think of this as sandwiching two segments together, where `eve.seg` is
					-- the bottom -- this will cause the above fill flag to toggle
					-- This might break things
					eve_seg.my_fill_above = seg.my_fill_below
						or seg.my_fill_above == seg.my_fill_below
				else
					-- merge two segments that belong to different polygons
					-- each segment has distinct knowledge, so no special logic is needed
					-- note that this can only happen once per segment in this phase, because we
					-- are guaranteed that all self-intersections are gone
					eve_seg.other_filled = true
					eve_seg.other_filled_above = seg.my_fill_above
					eve_seg.other_filled_below = seg.my_fill_below
				end

				table_remove(current_event_root, table_find(current_event_root, event.other))
				table_remove(current_event_root, table_find(current_event_root, event))
			end

			if current_event_root[1] ~= event then
				-- something was inserted before us in the event queue, so loop back around and
				-- process it before continuing
				continue
			end

			-- calculate fill flags
			if self_intersection then
				-- next, calculate whether we are filled below us
				if not below then -- if nothing is below us...
					-- we are filled below us if the polygon is inverted
					seg.my_fill_below = primary_poly_inverted
				else
					-- otherwise, we know the answer -- it's the same if whatever is below
					-- us is filled above it
					seg.my_fill_below = below.seg.my_fill_above
				end

				-- since now we know if we're filled below us, we can calculate whether
				-- we're filled above us by applying toggle to whatever is below us
				seg.my_fill_above = if seg.my_fill_below
						or seg.my_fill_above == seg.my_fill_below
					then not seg.my_fill_below
					else seg.my_fill_below
			elseif not seg.other_filled then
				-- if we don't have other information, then we need to figure out if we're
				-- inside the other polygon
				local inside = below
					and (
						if event.primary == below.primary
							then below.seg.other_filled_above
							else below.seg.my_fill_above
					)

				seg.other_filled = true :: any
				seg.other_filled_above = inside
				seg.other_filled_below = inside
			end

			-- insert the status and remember it for later removal
			custom_table_insert(status_root, transition_index, event)

			event.other.status = event
		else
			local st_index = table_find(status_root, event.status)
			assert(st_index, "zero-length segment detected")

			-- removing the status will create two new adjacent edges, so we'll need to check
			-- for those
			if st_index and st_index > 1 and st_index < #status_root then
				check_intersection(status_root[st_index - 1], status_root[st_index + 1])
			end

			-- remove the status
			table_remove(status_root, st_index)

			-- if we've reached this point, we've calculated everything there is to know, so
			-- save the segment for reporting
			if not event.primary then
				-- make sure `seg.my_fill` actually points to the primary polygon though
				-- Flips the fill
				seg.my_fill_above, seg.other_filled_above =
					seg.other_filled_above, seg.my_fill_above
				seg.my_fill_below, seg.other_filled_below =
					seg.other_filled_below, seg.my_fill_below
			end

			segments[#segments + 1] = seg
			-- table_insert(segments, seg)
		end

		-- remove the event and continue
		local len = #current_event_root
		for i = 1, len do
			current_event_root[i] = current_event_root[i + 1]
		end
	end

	return segments
end

type Identity = {
	event_root: { Event },
	self_intersecting: boolean,
}

local function constructor_intersector(self_intersecting: boolean): Identity
	return {
		self_intersecting = self_intersecting,

		event_root = table.create(32) :: { Event },
	}
end

local function add_region_to_intersector(intersector: Identity, region: types.Region)
	-- regions are a list of points:
	--  [ [0, 0], [100, 0], [50, 100] ]
	-- you can add multiple regions before running calculate
	current_event_root = intersector.event_root

	local point1: vector? = nil
	local point2: vector = region[#region]

	for _, point in region do
		point1, point2 = point2, point

		-- type state save me
		local forward = points_compare(point1 :: vector, point2)

		if forward == 0 then -- points are equal, so we have a zero-length segment
			continue -- just skip it
		elseif forward < 0 then
			event_add_segment(segment_new(point1 :: vector, point2), true)
		else
			event_add_segment(segment_new(point2, point1 :: vector), true)
		end
	end
end

local function calculate_self_intersector(intersector: Identity, inverted: boolean)
	current_event_root = intersector.event_root
	return (calculate(inverted, false, intersector.self_intersecting))
end

local function calculate_non_self_intersector(
	intersector: Identity,
	segments1: { types.Segment },
	inverted1: boolean,
	segments2: { types.Segment },
	inverted2: boolean
)
	current_event_root = intersector.event_root

	-- segmentsX come from the self-intersection API, or this API
	-- invertedX is whether we treat that list of segments as an inverted polygon or not
	-- returns segments that can be used for further operations
	for _, seg in segments1 do
		local cloned = seg
		cloned.other_filled = false
		event_add_segment(cloned, true)
	end

	for _, seg in segments2 do
		local cloned = seg
		cloned.other_filled = false
		event_add_segment(cloned, false)
	end

	return (calculate(inverted1, inverted2, intersector.self_intersecting))
end

return {
	constructor_intersector = constructor_intersector,

	calculate_non_self_intersector = calculate_non_self_intersector,
	calculate_self_intersector = calculate_self_intersector,

	add_region_to_intersector = add_region_to_intersector,
}
