-- (c) Copyright 2016, Sean Connelly (@voidqk), http:--syntheti.cc
-- MIT License
-- Project Home: https:--github.com/voidqk/polybooljs
-- Converted to Lua by EgoMoose

--
-- converts a list of segments into a list of regions, while also removing unnecessary verticies
--
local epsilon = require("./epsilon")
local types = require("./types")

local MATCH_TEMPLATE: Match = {
	index = 1,
	matches_head = false,
	matches_pt1 = false,
}

type Match = {
	index: number,
	matches_head: boolean,
	matches_pt1: boolean,
}

local EPSILON = 0.0001
local function points_same(p1: vector, p2: vector): boolean
	return vector.magnitude(p1 - p2) < EPSILON
end

local function points_collinear(pt1: vector, pt2: vector, pt3: vector)
	-- does pt1->pt2->pt3 make a straight line?
	-- essentially this is just checking to see if the slope(pt1->pt2) === slope(pt2->pt3)
	-- if slopes are equal, then they must be collinear, because they share pt2
	return math.abs((pt1.x - pt2.x) * (pt2.y - pt3.y) - (pt2.x - pt3.x) * (pt1.y - pt2.y))
		< EPSILON
end

local function new_match(): Match
	return table.clone(MATCH_TEMPLATE)
end

local function reverse_array<T>(t: { T })
	local n = #t
	local i = 1
	while i < n do
		t[i], t[n] = t[n], t[i]
		i += 1
		n -= 1
	end
end

local function merge_array<T>(arr1: { T }, arr2: { T }): { T }
	local cloned_array = table.clone(arr1)

	for _, item in arr2 do
		table.insert(cloned_array, item)
	end

	return cloned_array
end

local function segment_chainer(segments: { types.Segment }): { types.Region }
	local chains: { { vector } } = {}
	local regions: { { vector } } = {}

	for _, seg in segments do
		local point1, point2 = seg.start, seg.finish
		assert(not points_same(point1, point2), "zero-length segment")

		-- search for two chains that this segment matches
		local first_match: Match = new_match()
		local second_match: Match = new_match()

		local next_match: Match? = first_match
		local function set_match(index, matches_head, matches_pt1)
			-- return true if we've matched twice
			assert(next_match, "next_match == nil?")

			next_match.index = index
			next_match.matches_head = matches_head
			next_match.matches_pt1 = matches_pt1
			if next_match == first_match then
				next_match = second_match
				return false
			end
			next_match = nil
			return true -- we've matched twice, we're done here
		end

		for index, chain in chains do
			local head = chain[1]
			local tail = chain[#chain]

			if points_same(head, point1) then
				if set_match(index, true, true) then
					break
				end
			elseif points_same(head, point2) then
				if set_match(index, true, false) then
					break
				end
			elseif points_same(tail, point1) then
				if set_match(index, false, true) then
					break
				end
			elseif points_same(tail, point2) then
				if set_match(index, false, false) then
					break
				end
			end
		end

		if next_match == first_match then
			-- we didn't match anything, so create a new chain
			table.insert(chains, { point1, point2 })
			continue
		end

		if next_match == second_match then
			-- we matched a single chain

			-- add the other point to the apporpriate finish, and check to see if we've closed the
			-- chain into a loop

			local index = first_match.index
			local pt = if first_match.matches_pt1 then point2 else point1 -- if we matched pt1, then we add pt2, etc
			local addToHead = first_match.matches_head -- if we matched at head, then add to the head

			local chain = chains[index]
			local chain_length = #chain
			local grow = if addToHead then chain[1] else chain[chain_length]
			local grow2 = if addToHead then chain[2] else chain[chain_length - 1]
			local oppo = if addToHead then chain[chain_length] else chain[1]
			local oppo2 = if addToHead then chain[chain_length - 1] else chain[2]

			if points_collinear(grow2, grow, pt) then
				-- grow isn't needed because it's directly between grow2 and pt:
				-- grow2 ---grow---> pt
				if addToHead then
					table.remove(chain, 1)
				else
					table.remove(chain)
				end

				grow = grow2 -- old grow is gone... new grow is what grow2 was
			end

			if points_same(oppo, pt) then
				-- we're closing the loop, so remove chain from chains
				table.remove(chains, index)

				if points_collinear(oppo2, oppo, grow) then
					-- oppo isn't needed because it's directly between oppo2 and grow:
					-- oppo2 ---oppo--->grow
					if addToHead then
						table.remove(chain)
					else
						table.remove(chain, 1)
					end
				end

				-- we have a closed chain!
				table.insert(regions, chain)
				continue
			end

			-- not closing a loop, so just add it to the apporpriate side
			if addToHead then
				table.insert(chain, 1, pt)
			else
				table.insert(chain, pt)
			end

			continue
		end

		-- otherwise, we matched two chains, so we need to combine those chains together

		local function reverse_chain(index: number)
			reverse_array(chains[index]) -- gee, that's easy
		end

		local function append_chain(index1: number, index2: number)
			-- index1 gets index2 appended to it, and index2 is removed
			local chain1 = chains[index1]
			local chain2 = chains[index2]
			local tail = chain1[#chain1]
			local tail2 = chain1[#chain1 - 1]
			local head = chain2[1]
			local head2 = chain2[2]

			if points_collinear(tail2, tail, head) then
				-- tail isn't needed because it's directly between tail2 and head
				-- tail2 ---tail---> head
				table.remove(chain1)
				tail = tail2 -- old tail is gone... new tail is what tail2 was
			end

			if points_collinear(tail, head, head2) then
				-- head isn't needed because it's directly between tail and head2
				-- tail ---head---> head2
				table.remove(chain2, 1)
			end

			chains[index1] = merge_array(chain1, chain2)
			table.remove(chains, index2)
		end

		local f = first_match.index
		local s = second_match.index

		local reverseF = #chains[f] < #chains[s] -- reverse the shorter chain, if needed
		if first_match.matches_head then
			if second_match.matches_head then
				if reverseF then
					-- <<<< F <<<< --- >>>> S >>>>
					reverse_chain(f)
					-- >>>> F >>>> --- >>>> S >>>>
					append_chain(f, s)
				else
					-- <<<< F <<<< --- >>>> S >>>>
					reverse_chain(s)
					-- <<<< F <<<< --- <<<< S <<<<   logically same as:
					-- >>>> S >>>> --- >>>> F >>>>
					append_chain(s, f)
				end
			else
				-- <<<< F <<<< --- <<<< S <<<<   logically same as:
				-- >>>> S >>>> --- >>>> F >>>>
				append_chain(s, f)
			end
		elseif second_match.matches_head then
			-- >>>> F >>>> --- >>>> S >>>>
			append_chain(f, s)
		elseif reverseF then
			-- >>>> F >>>> --- <<<< S <<<<
			reverse_chain(f)
			-- <<<< F <<<< --- <<<< S <<<<   logically same as:
			-- >>>> S >>>> --- >>>> F >>>>
			append_chain(s, f)
		else
			-- >>>> F >>>> --- <<<< S <<<<
			reverse_chain(s)
			-- >>>> F >>>> --- >>>> S >>>>
			append_chain(f, s)
		end
	end

	return regions
end

return segment_chainer
