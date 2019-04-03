--potential: minecarts pushing minecarts, minecart trains, furnace minecart
local minecart = {
  initial_properties = {
    physical = true, -- otherwise going uphill breaks
    collide_with_objects = false,
    collisionbox = {-0.25, -0.7, -0.25, 0.25, 0.5, 0.25},
    visual = "mesh",
    mesh = "minecart.b3d",
    visual_size = {x=1, y=1},
    textures = {"minecart_ent.png"},
    --automatic_face_movement_dir = 90.0,
    timer = 0,
    speed = 0,
  },

}
function minecart:on_activate(staticdata, dtime_s)
    --in the future make this check for players around and they will "push it"
    self.object:set_acceleration({x=0,y=-10,z=0})

    if staticdata ~= "" and staticdata ~= nil then
        local data = minetest.parse_json(staticdata) or {}
        --restore old data
        if data then
          self.timer = data.timer
          self.speed = data.speed
          self.old_velocity = data.old_velocity
        end
    end
end

function minecart:on_step(dtime)
  --add_velocity(vel)
  minecart:repel(self)
  minecart:change_direction(self)
  minecart:friction(self)

  local vel = self.object:get_velocity()

  self.old_velocity = vel
end

--slow down cart with friction
function minecart:friction(self)
  local vel = self.object:getvelocity()
  vel = vector.multiply(vel,-1)
  vel = vector.divide(vel,100)
  self.object:add_velocity(vel)
end

--push away from players
function minecart:repel(self)
  local pos = self.object:getpos()
  local temp_pos = self.object:getpos()
  temp_pos.y = 0
  --magnet effect
  for _,object in ipairs(minetest.get_objects_inside_radius(pos, 1)) do
    if object:is_player() then
      local pos2 = object:getpos()
      local vec = vector.subtract(pos, pos2)
      vec = vector.divide(vec,3) --divide so the player doesn't fling the cart
      self.object:add_velocity({x=vec.x,y=0,z=vec.z})
    end
  end
end
--turn corners on rails
function minecart:change_direction(self)
  local vel = self.object:get_velocity()
  local pos = self.object:getpos()
  --stopped on the x axis

  if self.old_velocity and math.abs(self.old_velocity.x) > math.abs(self.old_velocity.z) and vel.x == 0 then
    print("boing")
    --make it turn
    if minetest.get_node({x=pos.x,y=pos.y,z=pos.z-1}).name == ("nodes:rail_straight" or "nodes:rail_turn") then
      self.object:set_velocity({x=0,y=self.old_velocity.y,z=math.abs(self.old_velocity.x)*-1})
    elseif minetest.get_node({x=pos.x,y=pos.y,z=pos.z+1}).name == ("nodes:rail_straight" or "nodes:rail_turn") then
      self.object:set_velocity({x=0,y=self.old_velocity.y,z=math.abs(self.old_velocity.x)})
    end
  elseif self.old_velocity and math.abs(self.old_velocity.z) > math.abs(self.old_velocity.x) and vel.z == 0 then
    print(self.old_velocity.z)
    --make it turn
    if minetest.get_node({x=pos.x-1,y=pos.y,z=pos.z}).name == ("nodes:rail_straight" or "nodes:rail_turn") then
      self.object:set_velocity({x=math.abs(self.old_velocity.z)*-1,y=self.old_velocity.y,z=0})
    elseif minetest.get_node({x=pos.x+1,y=pos.y,z=pos.z}).name == ("nodes:rail_straight" or "nodes:rail_turn") then
      self.object:set_velocity({x=math.abs(self.old_velocity.z),y=self.old_velocity.y,z=0})
    end
  end
end


function minecart:on_punch(hitter)
  self.object:remove()
end

function minecart:get_staticdata()
    return minetest.write_json({
        message = self.message,
        timer   = self.timer,
        speed   = self.speed,
        old_velocity = self.old_velocity,
    })
end

minetest.register_entity("minecart:minecart", minecart)



minetest.register_craftitem("minecart:minecart", {
  description = "Minecart",
  inventory_image = "minecart.png",
  on_place = function(itemstack, placer, pointed_thing)
    print(dump(pointed_thing.under))
    minetest.add_entity(pointed_thing.under, "minecart:minecart")
  end,

})
