local function deep_equal<T>(left: { T }, right: { T }, epsilon: number): boolean
	if left == right then
		return true
	end

	if type(left) == "number" and type(right) == "number" then
		return math.abs(left :: any - right) < epsilon
	end

	if type(left) == "vector" and type(right) == "vector" then
		return vector.magnitude(left :: any - right) < epsilon
	end

	if not (type(left) == "table" and type(right) == "table") then
		return false
	end

	if #left ~= #right then
		return false
	end

	for key, value in left do
		if not deep_equal(value, right[key], epsilon) then
			return false
		end
	end

	return true
end

return {
	deep_equal = deep_equal,
}
