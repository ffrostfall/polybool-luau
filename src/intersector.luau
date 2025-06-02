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
local sorted_array = require("./sorted_array")
local types = require("./types")

type Status = { Event }
type Event = {
	is_start: boolean,
	point: vector,
	seg: types.Segment,
	primary: boolean,
	other: Event?,
	status: Status?,
}

local TEMPLATE: types.Segment = {
	start = vector.zero,
	finish = vector.zero,
	my_fill_above = false,
	my_fill_below = false,
	other_filled = false,
}

local function segment_new(start: vector, finish: vector): types.Segment
	local cloned = table.clone(TEMPLATE)
	cloned.start, cloned.finish = start, finish
	return cloned
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
	local comp = epsilon.points_compare(p1_1, p2_1)
	if comp ~= 0 then
		return comp < 0
	end
	-- the selected points are the same

	if epsilon.points_same(p1_2, p2_2) then -- if the non-selected points are the same too...
		return false
	end

	if p1_is_start ~= p2_is_start then -- if one is a start and the other isn't...
		-- favor the one that isn't the start
		return not p1_is_start
	end

	-- otherwise, we'll have to calculate which one is below the other manually
	return (
		if p2_is_start
			then epsilon.point_above_or_on_line(p1_2, p2_1, p2_2)
			else epsilon.point_above_or_on_line(p1_2, p2_2, p2_1)
	) < 0
end

local function event_add(event_root: { Event }, event: Event, other_pt: vector)
	sorted_array.insert_before(
		event_root,
		event,
		event_compare,
		event.is_start,
		event.point,
		other_pt
	)
end

local function event_add_segment_start(
	event_root: { Event },
	seg: types.Segment,
	primary: boolean
): Event
	local ev_start: Event = {
		is_start = true,
		point = seg.start,
		seg = seg,
		primary = primary,
		other = nil,
		status = nil,
	}
	event_add(event_root, ev_start, seg.finish)
	return ev_start
end

local function event_add_segment_end(
	event_root: { Event },
	ev_start: Event,
	seg: types.Segment,
	primary: boolean
)
	local ev_end: Event = {
		is_start = false,
		point = seg.finish,
		seg = seg,
		primary = primary,
		other = ev_start,
		status = nil,
	}
	ev_start.other = ev_end
	event_add(event_root, ev_end, ev_start.point)
end

local function event_add_segment(event_root: { Event }, seg: types.Segment, primary: boolean)
	local ev_start = event_add_segment_start(event_root, seg, primary)
	event_add_segment_end(event_root, ev_start, seg, primary)
	return ev_start
end

local function event_update_end(event_root: { Event }, event: Event, finish: vector)
	-- slides an finish backwards
	--   (start)------------(finish)    to:
	--   (start)---(finish)
	table.remove(event_root, table.find(event_root, event.other))
	event.seg.finish = finish
	event.other.point = finish
	event_add(event_root, event.other, event.point)
end

local function event_divide(event_root: { Event }, event: Event, point: vector)
	local cloned = table.clone(event.seg)
	cloned.other_filled, cloned.start = false, point
	event_update_end(event_root, event, point)
	return (event_add_segment(event_root, cloned, event.primary))
end

local function check_intersection(event_root: { Event }, ev1: Event, ev2: Event): Event?
	-- returns the segment equal to ev1, or false if nothing equal

	local seg1 = ev1.seg
	local seg2 = ev2.seg
	local a1 = seg1.start
	local a2 = seg1.finish
	local b1 = seg2.start
	local b2 = seg2.finish

	local i = epsilon.lines_intersect(a1, a2, b1, b2)

	if not i then
		-- segments are parallel or coincident

		-- if points aren't collinear, then the segments are parallel, so no intersections
		if
			(not epsilon.points_collinear(a1, a2, b1))
			or epsilon.points_same(a1, b2)
			or epsilon.points_same(a2, b1)
		then
			return nil
		end
		-- otherwise, segments are on top of each other somehow (aka coincident)

		local a1_equ_b1 = epsilon.points_same(a1, b1)
		local a2_equ_b2 = epsilon.points_same(a2, b2)

		if a1_equ_b1 and a2_equ_b2 then
			return ev2 -- segments are exactly equal
		end

		local a2_between = not a2_equ_b2 and epsilon.point_between(a2, b1, b2)

		if a1_equ_b1 then
			if a2_between then
				--  (a1)---(a2)
				--  (b1)----------(b2)
				event_divide(event_root, ev2, a2)
			else
				--  (a1)----------(a2)
				--  (b1)---(b2)
				event_divide(event_root, ev1, b2)
			end
			return ev2
		elseif not a1_equ_b1 and epsilon.point_between(a1, b1, b2) then
			if not a2_equ_b2 then
				-- make a2 equal to b2
				if a2_between then
					--         (a1)---(a2)
					--  (b1)-----------------(b2)
					event_divide(event_root, ev2, a2)
				else
					--         (a1)----------(a2)
					--  (b1)----------(b2)
					event_divide(event_root, ev1, b2)
				end
			end

			--         (a1)---(a2)
			--  (b1)----------(b2)
			event_divide(event_root, ev2, a1)
		end
	else
		-- otherwise, lines intersect at i.point, which may or may not be between the endpoints

		-- is A divided between its endpoints? (exclusive)
		local along_a, along_b = i.along_a, i.along_b
		if along_a == 0 then
			if along_b == -1 then -- yes, at exactly b1
				event_divide(event_root, ev1, b1)
			elseif along_b == 0 then -- yes, somewhere between B's endpoints
				event_divide(event_root, ev1, i.point)
			elseif along_b == 1 then -- yes, at exactly b2
				event_divide(event_root, ev1, b2)
			end
		elseif along_b == 0 then
			if along_a == -1 then -- yes, at exactly a1
				event_divide(event_root, ev2, a1)
			elseif along_a == 0 then -- yes, somewhere between A's endpoints (exclusive)
				event_divide(event_root, ev2, i.point)
			elseif along_a == 1 then -- yes, at exactly a2
				event_divide(event_root, ev2, a2)
			end
		end
	end

	return nil
end

local function find_event_comparison(here: Status, event: Event): boolean
	local ev1_seg, ev2_seg = event.seg, here[1].seg
	local a1 = ev1_seg.start
	local b1 = ev2_seg.start
	local b2 = ev2_seg.finish

	if epsilon.points_collinear(a1, b1, b2) then
		local a2 = ev1_seg.finish

		return epsilon.points_collinear(a2, b1, b2)
			or epsilon.point_above_or_on_line(a2, b1, b2) > 0
	end

	return (epsilon.point_above_or_on_line(a1, b1, b2)) > 0
end

local function calculate(
	primary_poly_inverted: boolean,
	secondary_poly_inverted: boolean,
	event_root: { Event },
	self_intersection: boolean
): { types.Segment }
	-- if selfIntersection is true then there is no secondary polygon, so that isn't used

	-- status logic
	local status_root: { Status } = table.create(16) :: { Status }

	-- main event loop
	local segments = table.create(32) :: { types.Segment }
	while event_root[1] ~= nil do
		local event: Event = event_root[1]
		local seg = event.seg

		if event.is_start then
			local transitionIndex =
				sorted_array.find_transition(status_root, find_event_comparison, event)

			local transition_before = status_root[transitionIndex - 1]
			local transition_after = status_root[transitionIndex]

			local above: Event? = transition_before and transition_before[1]
			local below: Event? = transition_after and transition_after[1]

			local eve = (above and check_intersection(event_root, event, above))
				or (below and check_intersection(event_root, event, below))
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

				table.remove(event_root, table.find(event_root, event.other))
				table.remove(event_root, table.find(event_root, event))
			end

			if event_root[1] ~= event then
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
			local new_status = { event }
			table.insert(status_root, transitionIndex, new_status)

			event.other.status = new_status
		else
			local st = event.status
			assert(st ~= nil, "zero-length segment detected")

			local st_index = table.find(status_root, st)

			-- removing the status will create two new adjacent edges, so we'll need to check
			-- for those
			if st_index and st_index > 1 and st_index < #status_root then
				check_intersection(
					event_root,
					status_root[st_index - 1][1],
					status_root[st_index + 1][1]
				)
			end

			-- remove the status
			table.remove(status_root, st_index)

			-- if we've reached this point, we've calculated everything there is to know, so
			-- save the segment for reporting
			if not event.primary then
				-- make sure `seg.my_fill` actually points to the primary polygon though
				-- Flips the fill
				local stored_above, stored_below = seg.my_fill_above, seg.my_fill_below

				seg.my_fill_above = seg.other_filled_above :: any
				seg.my_fill_below = seg.other_filled_below :: any

				seg.other_filled_above, seg.other_filled_below = stored_above, stored_below
			end
			table.insert(segments, seg)
		end

		-- remove the event and continue
		table.remove(event_root, 1)
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

	local point1: vector? = nil
	local point2: vector = region[#region]

	for _, point in region do
		point1, point2 = point2, point

		-- type state save me
		local forward = epsilon.points_compare(point1 :: vector, point2)

		if forward == 0 then -- points are equal, so we have a zero-length segment
			continue -- just skip it
		elseif forward < 0 then
			event_add_segment(
				intersector.event_root,
				segment_new(point1 :: vector, point2),
				true
			)
		else
			event_add_segment(
				intersector.event_root,
				segment_new(point2, point1 :: vector),
				true
			)
		end
	end
end

local function calculate_self_intersector(intersector: Identity, inverted: boolean)
	return (calculate(inverted, false, intersector.event_root, intersector.self_intersecting))
end

local function calculate_non_self_intersector(
	intersector: Identity,
	segments1: { types.Segment },
	inverted1: boolean,
	segments2: { types.Segment },
	inverted2: boolean
)
	-- segmentsX come from the self-intersection API, or this API
	-- invertedX is whether we treat that list of segments as an inverted polygon or not
	-- returns segments that can be used for further operations
	for _, seg in segments1 do
		local cloned = table.clone(seg)
		cloned.other_filled = false
		event_add_segment(intersector.event_root, cloned, true)
	end

	for _, seg in segments2 do
		local cloned = table.clone(seg)
		cloned.other_filled = false
		event_add_segment(intersector.event_root, cloned, false)
	end

	return (calculate(inverted1, inverted2, intersector.event_root, intersector.self_intersecting))
end

return {
	constructor_intersector = constructor_intersector,

	calculate_non_self_intersector = calculate_non_self_intersector,
	calculate_self_intersector = calculate_self_intersector,

	add_region_to_intersector = add_region_to_intersector,
}
