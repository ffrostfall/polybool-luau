local function deepCopy(original)
	local copy = {}

	for k, v in original do
		if type(v) == "table" then
			v = deepCopy(v)
		end

		copy[k] = v
	end

	return copy
end

return deepCopy
