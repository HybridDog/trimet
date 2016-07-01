local load_time_start = os.clock()

local formspec = ""
for _,i in pairs{"x", "y", "z"} do
	local min = "min"..i
	formspec = formspec.."field["..min..";"..min..";${"..min.."}]"
	local max = "max"..i
	formspec = formspec.."field["..max..";"..max..";${"..max.."}]"
end


local get = vector.get_data_from_pos
local set = vector.set_data_to_pos
local remove = vector.remove_data_from_pos

local trimets = {}
local attachpos, second, wood_cache, dark_cache
minetest.register_node("trimet:trimet", {
	description = "trimet spawer",
	tiles = {"trimet.png"}, -- 3lamp mesh
	light_source = 15,
	on_punch = function(pos, node, player, pointed_thing)
		wood_cache = {}
		dark_cache = {}
		local sons = get(trimets, pos.z,pos.y,pos.x) or {}
		if sons[1]
		and sons[1].setpos then
			for i = 1,3 do
				local obj = sons[i]
				obj:setpos(pos)
				obj:setvelocity(vector.zero)
				obj:get_luaentity().timer = 1
			end
			return
		end
		attachpos = pos
		for i = 1,3 do
			sons[i] = minetest.add_entity(pos, "trimet:violet")
			if not sons[i] then
				error"can't add entity"
			end
		end
		attachpos = nil
		local minp = {}
		local maxp = {}
		local meta = minetest.get_meta(pos)
		for _,i in pairs{"x", "y", "z"} do
			minp[i] = meta:get_int("min"..i)
			maxp[i] = meta:get_int("max"..i)
		end
		sons.limit = {minp, maxp}
		set(trimets, pos.z,pos.y,pos.x, sons)
	end,
	on_destruct = function(pos)
		local sons = get(trimets, pos.z,pos.y,pos.x) or {}
		if not sons[1] then
			return
		end
		for i = 1,3 do
			sons[i]:remove()
		end
		remove(trimets, pos.z,pos.y,pos.x)
	end,
	on_construct = function(pos)
		minetest.get_meta(pos):set_string("formspec", "field[text;seperate with spaces;${text}]")
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		--print("Sign at "..minetest.pos_to_string(pos).." got "..dump(fields))
		if minetest.is_protected(pos, sender:get_player_name()) then
			minetest.record_protection_violation(pos, sender:get_player_name())
			return
		end
		if not fields.text then
			return
		end
		local coords = string.split(fields.text, " ")
		if #coords ~= 6 then
			return
		end
		for i = 1,6 do
			local cord = tonumber(coords[i])
			if not cord then
				return
			end
		end
		local minp = {}
		local maxp = {}
		minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z = unpack(coords)
		local meta = minetest.get_meta(pos)
		for _,i in pairs{"x", "y", "z"} do
			meta:set_int("min"..i, minp[i])
			meta:set_int("max"..i, maxp[i])
		end
		meta:set_string("text", fields.text)
		local sons = get(trimets, pos.z,pos.y,pos.x) or {}
		if not sons.limit then
			return
		end
		sons.limit = {minp, maxp}
	end,
})

--[[
trimet object
3 x 2 + 1
violet, zfight, carrier
rollos
]]

local function woody(pos)
	local woody = get(wood_cache, pos.z,pos.y,pos.x)
	if woody ~= nil then
		return woody
	end
	local name = minetest.get_node(pos).name
	woody = minetest.get_item_group(name, "wood") ~= 0 or minetest.get_item_group(name, "choppy") ~= 0
	set(wood_cache, pos.z,pos.y,pos.x, woody)
	return woody
end

local function is_dark(pos)
	local dark = get(dark_cache, pos.z,pos.y,pos.x)
	if dark ~= nil then
		return dark
	end
	local light = minetest.get_node_light(pos)
	if not light then
		dark = 0
	else
		dark = light < 13
	end
	set(dark_cache, pos.z,pos.y,pos.x, dark)
	return dark
end

local function trimet_sturf(p)
	local pos = vector.round(p)
	if woody(pos) then
		minetest.sound_play("trimet_step", {pos=p})
	elseif math.random() > 0.98 then
		local dark = is_dark(pos)
		if dark == true then
			minetest.sound_play("trimet_noise", {pos=p})
		elseif dark == 0 then
			minetest.sound_play("trimet_splat", {pos=p})
		end
	end
end

local function rand_pos(pos)
	return {x=pos.x+math.random()-0.5, y=pos.y+math.random()-0.5,z=pos.z+math.random()-0.5}
end

local function rand_in_limit(minp, maxp)
	return {x=math.random(minp.x, maxp.x), y=math.random(minp.y, maxp.y), z=math.random(minp.z, maxp.z)}
end

minetest.register_entity("trimet:violet",{
	visual = "cube",
	visual_size = {x=1/3, y=1/3},
	collisionbox = {0,0,0,0,0,0},
	physical = false,
	textures = {"trimet_violet.png", "trimet_violet.png", "trimet_violet.png", "trimet_violet.png^[transformR90", "trimet_violet.png", "trimet_violet.png^[transformR90"},
	on_activate = function(self)
		if not attachpos then
			self.object:remove()
			return
		end
		if second then
			self.brother = second.object
			second = false
			self.object:setyaw(math.pi)
			return
		end
		self.father = attachpos
		second = self
		local pos = rand_pos(attachpos)
		self.object:setpos(pos)
		self.sister = minetest.add_entity(pos, "trimet:violet")
	end,
	--[[get_staticdata = function(self)
		minetest.log("error", "[trimet] ended")
		self.object:remove()
	end,]]
	timer = 0,
	on_step = function(self, dtime)
		local follower = self.sister
		if not follower then
			if not self.brother then
				self.object:remove()
				minetest.log("error", "[trimet] missing brother")
			end
			return
		end
		self.timer = self.timer+dtime
		if self.timer < 1 then
			return
		end
		self.timer = 0.5-math.random()
		local father = self.father
		if not father then
			self.object:remove()
			minetest.log("error", "[trimet] missing father")
			return
		end
		local sons = get(trimets, father.z,father.y,father.x) or {}
		if not sons[1]
		or not sons[1].get_luaentity then
			self.object:remove()
			minetest.log("error", "[trimet] missing sons")
			remove(trimets, father.z,father.y,father.x)
			return
		end
		local pos = self.object:getpos()
		trimet_sturf(pos)
		local minp, maxp = unpack(sons.limit)
		minp = vector.add(father, minp)
		maxp = vector.add(father, maxp)
		local vel = self.object:getvelocity()
		if vector.inside(pos, minp, maxp)
		and not vector.equals(vel, vector.zero) then
			return
		end
		self.update(self, sons, minp, maxp)
	end,
	update = function(self, sons, minp, maxp)
		local newpos = rand_in_limit(minp, maxp)

		for i = 1,3 do
			local son = sons[i]
			if not son.get_luaentity then
				return
			end
			local ent = son:get_luaentity()
			if not ent then
				return
			end
			local follower = ent.sister
			if not follower then
				son:remove()
				minetest.log("error", "[trimet] missing son")
				return
			end
			local pos = son:getpos()
			minetest.sound_play("trimet_dirch", {pos=pos})
			local p = rand_pos(newpos)
			local vel = vector.multiply(vector.normalize(vector.subtract(p, pos)), math.random()+1)
			son:setvelocity(vel)
			follower:setvelocity(vel)
			son:setpos(pos)
			follower:setpos(pos)
		end
	end,
})


minetest.register_node("trimet:dibrick", {
	description = "Dibrick",
	tiles = {"trimet_dibrick.png"},
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("trimet:viowood", {
	description = "violet wood?",
	tiles = {"trimet_viowood.png"},
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("trimet:rollos_maker", {
	description = "rollos maker",
	tiles = {"trimet_rollos_maker.png", "trimet_rollos_maker_bottom.png", "trimet_rollos_maker.png"},
	paramtype2 = "wallmounted",
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	on_rightclick = function(pos, node, player)
		local pname = player:get_player_name()
		if minetest.is_protected(pos, pname) then
			minetest.chat_send_player(pname, "This is not yours!!")
			return
		end

		node.param1 = (node.param1+1)%8
		if node.param1 == 0 then
			-- disabling it
			minetest.set_node(pos, node)
			for _ = 1,7 do
				pos.y = pos.y-1
				if minetest.get_node(pos).name ~= "trimet:rollos" then
					return
				end
				minetest.remove_node(pos)
			end
			return
		end
		pos.y = pos.y-node.param1
		local def = minetest.registered_nodes[minetest.get_node(pos).name]
		if not def
		or not def.buildable_to then
			-- can't place rollos there
			pos.y = pos.y+node.param1
			node.param1 = 7
			minetest.set_node(pos, node)
			return
		end
		-- add one rollos node
		minetest.set_node(pos, {name = "trimet:rollos", param2 = node.param2})
		pos.y = pos.y+node.param1
		minetest.set_node(pos, node)
	end,
})

minetest.register_node("trimet:rollos", {
	description = "rollos",
	tiles = {"trimet_rollos.png"},
	paramtype = "light",
	paramtype2 = "wallmounted",
	drawtype = "signlike",
	--[[selection_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, 0.45, 0.5, 0.5, 0.5},
		},
	},--]]
	pointable = false,
	drop = "",
	groups = {not_in_creative_inventory = 1},
	sounds = default.node_sound_stone_defaults(),
})

-- https://de.wikipedia.org/wiki/Biergarnitur

local inv_nds = {
	["trimet:biertisch"] = "trimet:biertisch",
	["trimet:bierbank_r"] = "trimet:bierbank_l",
	["trimet:bierbank_l"] = "trimet:bierbank_r",
}

local invpar = {[0]=2, 3, 0, 1}
local rightps = {[0]={1,0}, {0,-1}, {-1,0}, {0,1}}

local placed = true
local function place_next(pos)
	placed = not placed
	if placed then
		return
	end
	local node = minetest.get_node(pos)
	local ax, az = unpack(rightps[node.param2])
	pos.x = pos.x+ax
	pos.z = pos.z+az
	local def = minetest.registered_nodes[minetest.get_node(pos).name]
	if not def
	or not def.buildable_to then
		-- can't place there
		placed = not placed
		return
	end
	node.param2 = invpar[node.param2]
	node.name = inv_nds[node.name]
	minetest.set_node(pos, node)
end

local removed = true
local function remove_next(pos, node)
	removed = not removed
	if removed then
		return
	end
	local ax, az = unpack(rightps[node.param2])
	pos.x = pos.x+ax
	pos.z = pos.z+az
	local next_node = minetest.get_node(pos)
	if next_node.param2 ~= invpar[node.param2]
	or next_node.name ~= inv_nds[node.name] then
		-- don't remove this
		removed = not removed
		return
	end
	minetest.remove_node(pos)
end

minetest.register_node("trimet:biertisch", {
	description = "Biertisch",
--	tiles = {"default_wood.png^[colorize:#FF4800A0"}, -- broken because shaders
	tiles = {"default_wood.png"},
	groups = {snappy=1, bendy=2, cracky=1},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	paramtype2 = "facedir",
	legacy_facedir_simple = true,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			-- table top
			{-0.51, 0.24, -0.25, 0.5, 0.27, 0.25},

			-- knees
			{-0.41, -0.5, -0.22, -0.38, 0.24, -0.19},
			{-0.41, -0.5, 0.19, -0.38, 0.24, 0.22},
		},
	},
	--[[on_punch = function(pos, _, puncher)
		tischknall(pos)
	end,--]]
	on_construct = place_next,
	after_destruct = remove_next,
})

minetest.register_node("trimet:bierbank_r", {
	description = "Bierbank",
--	tiles = {"default_wood.png^[colorize:#FF4800A0"}, -- broken because shaders
	tiles = {"default_wood.png"},
	groups = {snappy=1, bendy=2, cracky=1},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	paramtype2 = "facedir",
	legacy_facedir_simple = true,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			-- sitzfläche
			{-0.51, -0.055, 0.25, 0.5, -0.025, 0.5},

			-- knees
			{-0.41, -0.5, 0.28, -0.38, -0.055, 0.31},
			{-0.41, -0.5, 0.44, -0.38, -0.055, 0.47},
		},
	},
	--[[on_punch = function(pos, _, puncher)
		tischknall(pos)
	end,--]]
	on_construct = place_next,
	after_destruct = remove_next,
})

minetest.register_node("trimet:bierbank_l", {
	description = "Bierbank",
--	tiles = {"default_wood.png^[colorize:#FF4800A0"}, -- broken because shaders
	tiles = {"default_wood.png^[transformR180"},
	groups = {snappy=1, bendy=2, cracky=1},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	paramtype2 = "facedir",
	legacy_facedir_simple = true,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			-- sitzfläche
			{-0.51, -0.055, -0.5, 0.5, -0.025, -0.25},

			-- knees
			{-0.41, -0.5, -0.31, -0.38, -0.055, -0.28},
			{-0.41, -0.5, -0.47, -0.38, -0.055, -0.44},
		},
	},
	--[[on_punch = function(pos, _, puncher)
		tischknall(pos)
	end,--]]
	on_construct = place_next,
	after_destruct = remove_next,
})


local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "[trimet] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end
