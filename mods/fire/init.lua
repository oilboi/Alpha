minetest.register_node("fire:fire",
{
  description = "Fire",
  tiles = {
		{
			name = "fire_basic_flame_animated.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 1
			},
		},
	},
  groups = {fire = 1,instant=1},
  sounds = sounds.stone(),
  paramtype = "light",
  drop = "",
  drawtype = "nodebox",
  walkable = false,
  node_box = {
    type = "connected",
    --fixed = {{-1/2, -1/2, -1/2, 1/2, -3/8, 1/2}},
    connect_front = {{-1/2, -1/2, -1/2, 1/2, 1/2, -3/8}},

    connect_left = {{-1/2,  -1/2, -1/2,-3/8, 1/2,1/2}},

    connect_back = {{-1/2,  -1/2, 3/8,1/2, 1/2,1/2}},

    connect_right = {{3/8,  -1/2, -1/2,1/2, 1/2,1/2}},

    connect_top = {{-1/2,  3/8, -1/2,1/2, 1/2,1/2}},
    connect_bottom = {{-1/2,  -1/2, -1/2,1/2, -3/8,1/2}},
  },
  connects_to = {"group:flammable"},
  on_construct = function(pos)
    fire_on_create(pos)
  end,
  on_timer = function(pos, elapsed)
    fire_on_timer(pos)
  end,
}
)

--gets called when leaf decay timer ends
function fire_on_timer(pos)
  --make fire be put out by rain or snow
  if weather > 0 then
    minetest.sound_play("fire_extinguish_flame", {
      pos = pos,
      max_hear_distance = 16,
      gain = 1.0,
      pitch = math.random(60,120)/100,
    })
    minetest.remove_node(pos)
    return
  end


  local nodenear = minetest.find_node_near(pos, 1, "group:flammable")
  --cancel out removing self
  if nodenear then
    --remove nodes near
    minetest.set_node(nodenear,{name="fire:fire"})

    local timer = minetest.get_node_timer(pos)
    timer:start(math.random(20,45) / 10)

    return false
  end

	minetest.remove_node(pos)
end

--starts fire timer when created
function fire_on_create(pos)
  --make fire be put out by rain or snow
  if weather > 0 then
    minetest.sound_play("fire_extinguish_flame", {
      pos = pos,
      max_hear_distance = 16,
      gain = 1.0,
      pitch = math.random(60,120)/100,
    })
    minetest.remove_node(pos)
    return
  end

  --otherwise create a fire node timer to spread
	if minetest.find_node_near(pos, 1, "group:flammable") then
    local node = minetest.get_node(pos)
		local timer = minetest.get_node_timer(pos)
		if node.param2 == 0 and not timer:is_started() then
			timer:start(math.random(20,45) / 10)
		end
	end
end
