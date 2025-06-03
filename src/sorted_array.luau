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

function sorted_array.insert_before<T, U...>(
	array: { T },
	node: T,
	check: (value: T, U...) -> boolean,
	...: U...
)
	local length: number = #array

	if length < 1 then
		array[1] = node
		return
	end

	local low: number = 1
	local high: number = length

	while high > low do
		local index: number = bit32.rshift(low + high, 1)
		if check(array[index], ...) then
			high = index
		else
			low = index + 1
		end
	end

	if check(array[high], ...) then
		table.insert(array, high, node)
	else
		table.insert(array, node)
	end
end

function sorted_array.find_transition<T, U...>(
	array: { T },
	check: (value: T, U...) -> boolean,
	...: U...
): number
	local length = #array

	if length < 1 then
		return 1
	end

	local low: number = 1
	local high: number = length

	while high > low do
		local index: number = bit32.rshift(low + high, 1)
		if check(array[index], ...) then
			high = index
		else
			low = index + 1
		end
	end

	if check(array[high], ...) then
		return high
	else
		return length + 1
	end
end

return sorted_array
