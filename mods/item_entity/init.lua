
-- Minetest: builtin/item_entity.lua

function core.spawn_item(pos, item)
	-- Take item in any format
	local stack = ItemStack(item)
	local obj = core.add_entity(pos, "__builtin:item")
	-- Don't use obj if it couldn't be added to the map.
	if obj then
		obj:get_luaentity():set_item(stack:to_string())
	end
	return obj
end

-- If item_entity_ttl is not set, enity will have default life time
-- Setting it to -1 disables the feature

local time_to_live = tonumber(core.settings:get("item_entity_ttl")) or 900
local gravity = tonumber(core.settings:get("movement_gravity")) or 9.81


core.register_entity(":__builtin:item", {
	initial_properties = {
		pointable = false,
		hp_max = 1,
		physical = true,
		collide_with_objects = false,
		collisionbox = {-0.3, -0.3, -0.3, 0.3, 0.3, 0.3},
		visual = "wielditem",
		visual_size = {x = 0.4, y = 0.4},
		textures = {""},
		spritediv = {x = 1, y = 1},
		initial_sprite_basepos = {x = 0, y = 0},
		is_visible = false,
	},

	itemstring = "",
	moving_state = true,
	slippery_state = false,
	age = collection_age,

	set_item = function(self, item)
		local stack = ItemStack(item or self.itemstring)
		self.itemstring = stack:to_string()
		if self.itemstring == "" then
			-- item not yet known
			return
		end

		-- Backwards compatibility: old clients use the texture
		-- to get the type of the item
		local itemname = stack:is_known() and stack:get_name() or "unknown"

		local max_count = stack:get_stack_max()
		local count = math.min(stack:get_count(), max_count)
		local size = 0.2 + 0.1 * (count / max_count) ^ (1 / 3)
		local coll_height = size * 0.75

		self.object:set_properties({
			is_visible = true,
			visual = "wielditem",
			textures = {itemname},
			visual_size = {x = size, y = size},
			collisionbox = {-size, -coll_height, -size,
				size, coll_height, size},
			selectionbox = {-size, -size, -size, size, size, size},
			automatic_rotate = math.pi * 0.5 * 0.2 / size,
			wield_item = self.itemstring,
		})

	end,

	get_staticdata = function(self)
		return core.serialize({
			itemstring = self.itemstring,
			age = self.age,
			dropped_by = self.dropped_by
		})
	end,

	on_activate = function(self, staticdata, dtime_s)
		if string.sub(staticdata, 1, string.len("return")) == "return" then
			local data = core.deserialize(staticdata)
			if data and type(data) == "table" then
				self.itemstring = data.itemstring
				self.age = (data.age or 0) + dtime_s
				self.dropped_by = data.dropped_by
			end
		else
			self.itemstring = staticdata
		end
		self.object:set_armor_groups({immortal = 1})
		self.object:set_velocity({x = 0, y = 2, z = 0})
		self.object:set_acceleration({x = 0, y = -gravity, z = 0})
		self:set_item()
	end,
	try_merge_with = function(self, own_stack, object, entity)
			if self.age == entity.age then
				-- Can not merge with itself
				return false
			end

			local stack = ItemStack(entity.itemstring)
			local name = stack:get_name()
			if own_stack:get_name() ~= name or
					own_stack:get_meta() ~= stack:get_meta() or
					own_stack:get_wear() ~= stack:get_wear() or
					own_stack:get_free_space() == 0 then
				-- Can not merge different or full stack
				return false
			end

			local count = own_stack:get_count()
			local total_count = stack:get_count() + count
			local max_count = stack:get_stack_max()

			if total_count > max_count then
				return false
			end
			-- Merge the remote stack into this one

			local pos = object:get_pos()
			pos.y = pos.y + ((total_count - count) / max_count) * 0.15
			self.object:move_to(pos)

			self.age = 0 -- Handle as new entity
			own_stack:set_count(total_count)
			self:set_item(own_stack)

			entity.itemstring = ""
			object:remove()
			return true
		end,
	on_step = function(self, dtime)
		self.age = self.age + dtime
		if time_to_live > 0 and self.age > time_to_live then
			self.itemstring = ""
			self.object:remove()
			return
		end

		--bolt on burning and floating
		local pos = self.object:get_pos()
		local vel = self.object:get_velocity()

		local node_inside = minetest.get_node(pos).name

		self.burn(node_inside,pos,self)


		local node = core.get_node_or_nil({
			x = pos.x,
			y = pos.y + self.object:get_properties().collisionbox[2] - 0.05,
			z = pos.z
		})

		--splash effect
		splash(self.object,pos)


		local def = node and core.registered_nodes[node.name]

		local is_moving = (def and not def.walkable) or vel.x ~= 0 or vel.y ~= 0 or vel.z ~= 0
		local is_slippery = false


		--stop the object from moving
		if math.abs(vel.x) < 0.5 and math.abs(vel.z) < 0.5 then
			self.object:set_velocity(vector.new(0,vel.y,0))
		end

		--use friction and velocity to do block friction with everything
		if def and (math.abs(vel.y) < 0.3 or minetest.get_item_group(def.name, "water") > 0) and (math.abs(vel.x) > 0.5 or math.abs(vel.z) > 0.5) then
			local slippery = core.get_item_group(node.name, "slippery")

			--override if not slippery to just do block friction
			if slippery == 0 then
				slippery = 50
			end

			if (math.abs(vel.x) > 0.2 or math.abs(vel.z) > 0.2) then

				-- Horizontal deceleration
				local slip_factor = 4.0 / (slippery + 4)
				self.object:add_velocity({
					x = -vel.x * slip_factor,
					y = 0,
					z = -vel.z * slip_factor
				})
			elseif vel.y == 0 then
				is_moving = false
			end
		end

		self.float(node_inside,pos,self,vel)

		-- make items flow
		set_flow(pos,self.object,20)

		self.slippery_state = is_slippery


		-- Collect the items around to merge with
		local own_stack = ItemStack(self.itemstring)
		if own_stack:get_free_space() == 0 then
			return
		end
		local objects = core.get_objects_inside_radius(pos, 1.0)
		for k, obj in pairs(objects) do
			local entity = obj:get_luaentity()
			if entity and entity.name == "__builtin:item" then
				if self:try_merge_with(own_stack, obj, entity) then
					own_stack = ItemStack(self.itemstring)
					if own_stack:get_free_space() == 0 then
						return
					end
				end
			end
		end
	end,

	--burn sound and remove if in fire
	burn = function(node,pos,self)
		if node == "fire:fire" then
			minetest.sound_play("fire_extinguish_flame", {
	      pos = pos,
	      max_hear_distance = 16,
	      gain = 1.0,
	      pitch = math.random(60,120)/100,
	    })
			self.object:remove()
		end
	end,

	--makes the item float
	float = function(node,pos,self,vel)
	  local in_water =  minetest.get_item_group(node, "water")

		--this is how fast water will flow up
		local modifier = 0.01

		--check if water above
		if minetest.get_item_group(minetest.get_node({x = pos.x,y = pos.y + 0.05,z = pos.z}).name, "water") > 0 then
			modifier = 3
		end


	  if in_water > 0 then
	    self.object:add_velocity({x=0,y=(modifier-vel.y),z=0}) --math.abs(vel.y/5) for slow sinking objects -- 5-vel.y for jumping objects
			self.object:set_acceleration({x=0,y=0,z=0})
	  else
	    --self.object:add_velocity({x=0,y=-0.05,z=0})
			self.object:set_acceleration({x=0,y=-10,z=0})
	  end

	end,

	on_punch = function(self, hitter)
		local inv = hitter:get_inventory()
		if inv and self.itemstring ~= "" then
			local left = inv:add_item("main", self.itemstring)
			if left and not left:is_empty() then
				self:set_item(left)
				return
			end
		end
		self.itemstring = ""
		self.object:remove()
	end,
})
