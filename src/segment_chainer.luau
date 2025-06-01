-- (c) Copyright 2016, Sean Connelly (@voidqk), http:--syntheti.cc
-- MIT License
-- Project Home: https:--github.com/voidqk/polybooljs
-- Converted to Lua by EgoMoose

--
-- converts a list of segments into a list of regions, while also removing unnecessary verticies
--
local epsilon = require("./epsilon")
local types = require("./types")

type Match = {
	index: number,
	matches_head: boolean,
	matches_pt1: boolean,
}

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
		local pt1 = seg.start
		local pt2 = seg.finish
		if epsilon.points_same(pt1, pt2) then
			error(
				"PolyBool: Warning: Zero-length segment detected; your epsilon is probably too small or too large"
			)
		end

		-- search for two chains that this segment matches
		local first_match: Match = {
			index = 1, -- zero?
			matches_head = false,
			matches_pt1 = false,
		}
		local second_match: Match = {
			index = 1, -- zero?
			matches_head = false,
			matches_pt1 = false,
		}
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

		for i = 1, #chains do
			local chain = chains[i]
			local head = chain[1]
			local tail = chain[#chain]

			if epsilon.points_same(head, pt1) then
				if set_match(i, true, true) then
					break
				end
			elseif epsilon.points_same(head, pt2) then
				if set_match(i, true, false) then
					break
				end
			elseif epsilon.points_same(tail, pt1) then
				if set_match(i, false, true) then
					break
				end
			elseif epsilon.points_same(tail, pt2) then
				if set_match(i, false, false) then
					break
				end
			end
		end

		if next_match == first_match then
			-- we didn't match anything, so create a new chain
			table.insert(chains, { pt1, pt2 })
			continue
		end

		if next_match == second_match then
			-- we matched a single chain

			-- add the other point to the apporpriate finish, and check to see if we've closed the
			-- chain into a loop

			local index = first_match.index
			local pt = if first_match.matches_pt1 then pt2 else pt1 -- if we matched pt1, then we add pt2, etc
			local addToHead = first_match.matches_head -- if we matched at head, then add to the head

			local chain = chains[index]
			local grow = if addToHead then chain[1] else chain[#chain]
			local grow2 = if addToHead then chain[2] else chain[#chain - 1]
			local oppo = if addToHead then chain[#chain] else chain[1]
			local oppo2 = if addToHead then chain[#chain - 1] else chain[2]

			if epsilon.points_collinear(grow2, grow, pt) then
				-- grow isn't needed because it's directly between grow2 and pt:
				-- grow2 ---grow---> pt
				if addToHead then
					table.remove(chain, 1)
				else
					table.remove(chain)
				end
				grow = grow2 -- old grow is gone... new grow is what grow2 was
			end

			if epsilon.points_same(oppo, pt) then
				-- we're closing the loop, so remove chain from chains
				table.remove(chains, index)

				if epsilon.points_collinear(oppo2, oppo, grow) then
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

		local function reverseChain(index: number)
			reverse_array(chains[index]) -- gee, that's easy
		end

		local function appendChain(index1: number, index2: number)
			-- index1 gets index2 appended to it, and index2 is removed
			local chain1 = chains[index1]
			local chain2 = chains[index2]
			local tail = chain1[#chain1]
			local tail2 = chain1[#chain1 - 1]
			local head = chain2[1]
			local head2 = chain2[2]

			if epsilon.points_collinear(tail2, tail, head) then
				-- tail isn't needed because it's directly between tail2 and head
				-- tail2 ---tail---> head
				table.remove(chain1)
				tail = tail2 -- old tail is gone... new tail is what tail2 was
			end

			if epsilon.points_collinear(tail, head, head2) then
				-- head isn't needed because it's directly between tail and head2
				-- tail ---head---> head2
				table.remove(chain2, 1)
			end

			chains[index1] = merge_array(chain1, chain2)
			table.remove(chains, index2)
		end

		local F = first_match.index
		local S = second_match.index

		local reverseF = #chains[F] < #chains[S] -- reverse the shorter chain, if needed
		if first_match.matches_head then
			if second_match.matches_head then
				if reverseF then
					-- <<<< F <<<< --- >>>> S >>>>
					reverseChain(F)
					-- >>>> F >>>> --- >>>> S >>>>
					appendChain(F, S)
				else
					-- <<<< F <<<< --- >>>> S >>>>
					reverseChain(S)
					-- <<<< F <<<< --- <<<< S <<<<   logically same as:
					-- >>>> S >>>> --- >>>> F >>>>
					appendChain(S, F)
				end
			else
				-- <<<< F <<<< --- <<<< S <<<<   logically same as:
				-- >>>> S >>>> --- >>>> F >>>>
				appendChain(S, F)
			end
		else
			if second_match.matches_head then
				-- >>>> F >>>> --- >>>> S >>>>
				appendChain(F, S)
			else
				if reverseF then
					-- >>>> F >>>> --- <<<< S <<<<
					reverseChain(F)
					-- <<<< F <<<< --- <<<< S <<<<   logically same as:
					-- >>>> S >>>> --- >>>> F >>>>
					appendChain(S, F)
				else
					-- >>>> F >>>> --- <<<< S <<<<
					reverseChain(S)
					-- >>>> F >>>> --- >>>> S >>>>
					appendChain(F, S)
				end
			end
		end
	end

	return regions
end

return segment_chainer
