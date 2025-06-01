local process = require("@lute/process")

process.run("luau --profile tests/bench.luau -O2", { shell = true })
process.run("py tools/perfgraph.py profile.out > flamegraph.svg", { shell = true })
