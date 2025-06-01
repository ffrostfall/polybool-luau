local TEST, CASE, CHECK, FINISH = require("@vendor/testkit").test()

local polybool = require("@polybool/")

--[==[
const poly1 = {
  regions: [
    [[50,50], [150,150], [190,50]],
    [[130,50], [290,150], [290,50]]
  ],
  inverted: false
};
]==]
local poly1 = {
	regions = {
		{ vector.create(50, 50, 0), vector.create(150, 150), vector.create(190, 50) },
		{ vector.create(130, 50, 0), vector.create(290, 150, 0), vector.create(290, 50) },
	},

	inverted = false,
}

local poly2 = {
	regions = {
		{ vector.create(110, 20), vector.create(110, 110), vector.create(20, 20) },
		{
			vector.create(130, 170),
			vector.create(130, 20),
			vector.create(260, 20),
			vector.create(260, 170),
		},
	},

	inverted = false,
}

-- this is fine
local polyresult = polybool.intersect(poly1, poly2)

TEST("maybe ill test this", function()
	CASE("later")
	do
		CHECK(true)
	end
end)

FINISH()
