local fs = require("@lute/fs")
local process = require("@lute/process")
local task = require("@lute/task")

process.run(
	"luau --profile=50000 tests/bench.luau -O2 --codegen",
	{ shell = true, stdio = "inherit" }
)

-- post-processing to make flamegraph easier to view
local output_profile = fs.readasync("profile.out")
local lines = string.split(output_profile, "\n")
for i = #lines, 1, -1 do
	local line = lines[i]

	if not string.match(line, "./tests/bench.luau,,1") then
		table.remove(lines, i)
	elseif string.match(line, "require") then
		table.remove(lines, i)
	elseif not string.match(line, "xpcall") then
		table.remove(lines, i)
	end
end

fs.writestringtofile("profile.out", table.concat(lines, "\n"))

task.wait(0.5)

process.run(
	"py tools/perfgraph.py profile.out > flamegraph.svg",
	{ shell = true, stdio = "inherit" }
)
