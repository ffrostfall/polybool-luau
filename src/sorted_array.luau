--[[
	Adapted from PolyBool (github.com/voidqk/polybooljs) under the MIT license.
	(c) 2016 Sean Connelly (@voidqk)
	
	Original Lua port by EgoMoose.
	Refactor and optimisations by Elttob.
]]

--[[
	Provides helper functions for working with sorted arrays.
]]

local sorted_array = {}

function sorted_array.insert_before<T>(array: { T }, node: T, check: (value: T) -> boolean)
	local length: number = #array

	if length < 1 then
		array[1] = node
		return node
	end

	local lowerBound: number = 1
	local upperBound: number = length

	local upperBoundChecked: boolean = false

	while lowerBound ~= upperBound do
		local index: number = (lowerBound + upperBound) // 2

		if check(array[index]) then
			upperBound = index
			upperBoundChecked = true
		else
			lowerBound = index + 1
			upperBoundChecked = false
		end
	end

	if upperBoundChecked or check(array[upperBound]) then
		table.insert(array, upperBound, node)
	else
		array[length + 1] = node
	end

	return node
end

function sorted_array.findTransition<T>(array: { T }, check: (value: T) -> boolean): number
	local length = #array

	if length < 1 then
		return 1
	end

	local lowerBound: number = 1
	local upperBound: number = length

	local upperBoundChecked: boolean = false

	while lowerBound ~= upperBound do
		local index: number = (lowerBound + upperBound) // 2

		if check(array[index]) then
			upperBound = index
			upperBoundChecked = true
		else
			lowerBound = index + 1
			upperBoundChecked = false
		end
	end

	if upperBoundChecked or check(array[upperBound]) then
		return upperBound
	else
		return length + 1
	end
end

return sorted_array
