function move_across_path(movement)
	local ox, oy=0, 0
	if movement.dx<0 then
		ox=8
	end
	if movement.dy<0 then
		oy=8
	end
	local t=movement.actor.tile
	local x=flr((movement.actor.pos.x+ox)/8)
	local y=flr((movement.actor.pos.y+oy)/8)
	local tleft=mget(x-1, y)==t or mget(x-1, y)==t+1
	local tright=mget(x+1, y)==t or mget(x+1, y)==t+1
	local tup=mget(x, y-1)==t or mget(x, y-1)==t+1
	local tdown=mget(x, y+1)==t or mget(x, y+1)==t+1

	if movement.dx==0 and movement.dy==0 then
		if tright then
			movement:apply_x(1)
		elseif tleft then
			movement:apply_x(-1)
		elseif tup then
			movement:apply_y(-1)
		elseif tdown then
			movement:apply_y(1)
		end
	end
	if not tright and movement.dx>0 or not tleft and movement.dx<0 then
		movement.dx=-movement.dx
	end
	if not tup and movement.dy<0 or not tdown and movement.dy>0 then
		movement.dy=-movement.dy
	end
end

function move_between(movement)
	local pos=movement.actor.pos
	if movement.dx==0 then
		movement:apply_x(1)
	else
		local offset=movement.actor.width
		if movement.dx<0 then
			offset=0
		end
		local tile_below=mget(flr(pos.x/8)+offset, flr(pos.y/8)+1)
		if tile_below==0 or fget(tile_below, 7) then
			movement.dx=-movement.dx
		end
		local tile=mget(flr(pos.x/8)+offset, flr(pos.y/8))
		if fget(tile, 2) then
			movement.dx=-movement.dx
		end
		return
	end
end

-- args: [.apply_x(force)], btn_index, btn_index
function control_with_buttons(movement, b_left, b_right)
	local force=0
	if btn(b_left) then
		force=-1
	elseif btn(b_right) then
		force=1
	end
	movement:apply_x(force)
end

function jump_with_button(movement, b_jump, grav_force, jump_force, on_jump)
	local on_jump=on_jump or function() end
	if movement.actor.grounded then
		movement.jump_force=jump_force
	end
	if movement.dy>0 then
		movement.actor.falling=true
	end
	if btnp(b_jump) and not movement.actor.grounded then
		movement.jump_force=0 -- prevent double jump
	end
	local force = grav_force
	if btnp(b_jump) and movement.actor.grounded then
		force-=0.2
		on_jump()
	elseif btn(b_jump) and movement.dy<0 and not movement.actor.falling then
		force-=movement.jump_force
		movement.jump_force-=0.05
		movement.jump_force=max(0, movement.jump_force)
	end
	movement:apply_y(force)
end

function collide_map(movement, dcc, on_collision)
	local on_collision=on_collision or function(obj_data) end
	local pos=movement.actor.pos
	movement.actor.grounded=false
	movement.actor.dcc=0
	-- floor
	for i=0,1 do
		local tile=mget(pos.x/8+i, pos.y/8+1)
		if fget(tile, 1) then
			if movement.dy>0 then
				movement.dy=0
				pos.y=flr(pos.y/8)*8
				movement.actor.grounded=true
				movement.actor.falling=false
				movement.actor.dcc=dcc
			end
		end
		if fget(tile, 0) then
			on_collision({dangerous=true})
		end
		if pos.x%8<=0.1 then
			break
		end
	end
	-- ceiling
	for i=0,1 do
		local tile=mget((pos.x-2*i+2*abs(i-1))/8+i, pos.y/8-1)
		if fget(tile, 3) then
			if movement.dy<0 then
				movement.dy=0
				pos.y=flr(pos.y/8)*8
				movement.actor.falling=true
			end
		end
		if fget(tile, 0) then
			on_collision({dangerous=true})
		end
	end
	-- walls
	for j=0,1 do
		local tile=mget(flr((pos.x+j-1)/8)+j, pos.y/8)
		if fget(tile, 2) then
			if movement.dx*(j-1+j)>0 then
				movement.dx=0
				pos.x=flr(pos.x/8)*8-0.1*(j-1)
			end
		end
		if fget(tile, 0) then
			on_collision({dangerous=true})
		end
	end
	return c
end

-- create object that handles movement logic
-- params:
--  * actor: object created by new_actor function
--  * acc: acceleration factor
--  * dx_limit: horizontal speed limit
--  * dy_limit: vertical speed limit
--  * flipped: set to true if actor sprite is facing left side of the screen
function new_acc_movement(actor, acc, dx_limit, dy_limit, flipped)
	local flipped=flipped or false
	return {
		dx=0,
		dy=0,
		actor=actor,
		jump_force=0,
		apply_x=function(self, force)
			self.dx+=acc*force
			if force == 0 then
				self.dx*=actor.dcc
			end
		end,
		apply_y=function(self, force)
			self.dy+=force
		end,
		step=function(self)
			self.dx=mid(-dx_limit, self.dx, dx_limit)
			self.dy=mid(-dy_limit, self.dy, dy_limit)
			actor.pos.x+=self.dx
			actor.pos.y+=self.dy
			if self.dx<0 then
				actor.flip=not flipped
			elseif self.dx>0 then
				actor.flip=flipped
			end
		end
	}
end

-- create object with all information needed to be displayed
-- params:
--  * spr_id: id of the initial (idle) sprite frame
--  * pos: object that stores screen position like {x=10, y=20}
--  * w: sprite width (in tiles)
--  * h: sprite height (in tiles)
function new_actor(spr_id, pos, w, h)
	local w=w or 1;
	local h=h or 1;
	return {
		spr_id=spr_id,
		pos=pos, -- [.x, .y]
		flip=false,
		grounded=false,
		falling=false,
		dcc=0,
		width=w,
		height=h,
		draw=function(self, offset)
			spr(self.spr_id, self.pos.x+offset.x, self.pos.y+offset.y, w, h, self.flip)
		end
	}
end

-- create object that handles periodical task
-- it continously executes on_timeout function
-- params:
--  * interval: number of ticks between on_timeout executions
--  * on_timeout: periodical task function to be executed
--  * on_reset: function executed when timer reset is requested
--  * delay: (optional) number of ticks before timer starts (or reset is invoked)
function new_timer(interval, on_timeout, on_reset, delay)
	local delay=delay or 0
	local num_ticks_wait=delay
	local ticks=0
	local on_reset=on_reset or function() end
	return {
		step=function(self)
			if num_ticks_wait>0 then
				num_ticks_wait-=1
				return
			end
			ticks+=1
			if ticks%interval==0 then
				local d=on_timeout()
				if d then
					num_ticks_wait=d
				end
			end
		end,
		reset=function(self)
			on_reset()
			ticks=0
			num_ticks_wait=delay
		end
	}
end

-- create object that handles actor animation
-- it continously replaces actor.spr_id in time interval
-- params:
--  * actor: object created by new_actor function
--  * length: number of animation frames
--  * interval: number of ticks between frame changes
--  * spr_id: (optional) id of the initial (idle) sprite frame
--  * delay: (optional) number of ticks between full animation cycles
function new_anim(actor, length, interval, spr_id, delay)
	local spr_id=spr_id or actor.spr_id
	local w=actor.width
	local cur_frame=spr_id
	return new_timer(interval, function()
		local d=0
		if cur_frame>=spr_id+length*w-w then
			cur_frame=spr_id
			d=delay
		else
			cur_frame+=w
		end
		actor.spr_id=cur_frame
		return d
	end,
	function()
		cur_frame=spr_id
		actor.spr_id=cur_frame
	end, delay)
end

function new_view()
	return {
		h_cell=0,
		v_cell=0,
		get_offset=function(self)
			return {x=-self.h_cell*128, y=-self.v_cell*128}
		end,
		update=function(self, pos)
			local old_h=self.h_cell
			local old_v=self.v_cell
			self.h_cell=flr((pos.x+4)/128)
			self.v_cell=flr((pos.y+4)/128)
			return self.h_cell~=old_h or self.v_cell~=old_v
		end,
		draw_map=function(self, mask)
			map(self.h_cell*16, self.v_cell*16, 0, 0, 16, 16, mask)
		end
	}
end

-- create game objects (enemies, collectibles, ...) repository
-- params:
--  * factories: list of objects with attributes like:
--    * tile: identifier of object tile
--    * new_obj: object factory function, executed to create object
--      it's result is also passed to on_collid_object function when collision is detected
--    * move: function that handles object movement, it takes movement object as an argument,
--      it usually modifies movement dx or dy attributes,
--      examples of this kind of function are move_across_path or move_between
function new_objects(factories)
	return {
		instances={},
		purge_all=function(self)
			self.instances={}
		end,
		spawn_all=function(self, view)
			foreach(factories, function(f)
				self:spawn(f.tile, f.new_obj, view)
			end)
		end,
		update_all=function(self)
			foreach(factories, function(f)
				self:update(f.tile, f.move)
			end)
		end,
		spawn=function(self, tile, new_obj, view)
			local v, h = view.v_cell*16, view.h_cell*16
			for i=0,15 do
				for j=0,15 do
					local t=mget(i+h, j+v)
					if tile==t then
						local pos={x=(i+h)*8, y=(j+v)*8}
						local od=new_obj(pos)
						od.actor.tile=t
						od.destroy=function(self_)
							del(self.instances, od)
							mset(i+h, j+v, 0)
						end
						add(self.instances, od)
					end
				end
			end
		end,
		update=function(self, tile, move)
			foreach(self.instances, function(obj_data)
				if obj_data.actor.tile==tile then
					obj_data.anim:step()
					move(obj_data.movement)
					obj_data.movement:step()
				end
			end)
		end,
		draw=function(self, offset)
			foreach(self.instances, function(obj_data)
				obj_data.actor:draw(offset)
			end)
		end,
		collide=function(self, movement, on_collision)
			local pos=movement.actor.pos
			local width=movement.actor.width
			local height=movement.actor.height
			foreach(self.instances, function(obj_data)
				local margin=obj_data.margin or 0
				local obj=obj_data.actor
				if(
					pos.x+width*8-1>=obj.pos.x-margin and pos.x+width*8<=obj.pos.x+obj.width*8+margin
					or pos.x>=obj.pos.x-margin and pos.x<=obj.pos.x+obj.width*8-1+margin
				) and (
					pos.y+height*8-1>=obj.pos.y-margin and pos.y+height*8<=obj.pos.y+obj.height*8+margin
					or pos.y>=obj.pos.y-margin and pos.y<=obj.pos.y+obj.height*8-1+margin
				)
				then
					on_collision(obj_data)
				end
			end)
		end
	}
end

-- create player object
-- params:
--  * movement: object created with new_movement function
--  * on_update: function executed after payer update is performed
--  * on_collide_obj: function executed when collision with object is detected
--    it takes object data (result of object factory function) as an argument
--  * on_jump: function executed when player jumps
function new_player(movement, on_update, on_collide_obj, on_jump)
	return {
		update=function(self, objects)
			collide_map(movement, 0.8, on_collide_obj)
			objects:collide(movement, on_collide_obj)
			control_with_buttons(movement, 0, 1)
			jump_with_button(movement, 5, 0.15, 0.56, on_jump)
			movement:step()
			on_update()
		end,
		draw=function(self, offset)
			movement.actor:draw(offset)
		end,
		get_pos=function(self)
			return movement.actor.pos
		end
	}
end

function new_player_data()
	return {
		collected={},
		collect=function(self, obj)
			add(self.collected, obj)
		end
	}
end

-- create game object
-- params:
--  * player: object created with new_player function
--  * objects: table created with new_objects function
--  * layers: table of functions which take view object as an argument,
--    usually used for drawing backgrounds
--  * hud: function that takes view as an argument, used for drawing hud
--  * colors: color configuration table, can conain attributes like
--    * bg: background color index
--    * player_transparent: player sprite transparent color index
function new_game(player, objects, layers, hud, colors)
	local colors=colors or {}
	local view=new_view()
	objects:spawn_all(view)
	return {
		update=function(self)
			player:update(objects)
			if view:update(player.get_pos()) then
				objects:purge_all()
				objects:spawn_all(view)
			end
			objects:update_all()
		end,
		draw=function(self)
			cls(colors.bg or 0)

			foreach(layers, function(layer)
				layer(view)
			end)

			view:draw_map(0x82)
			local view_offset=view:get_offset()

			palt(colors.player_transparent or 0, true)
			palt(0, false)
			player:draw(view_offset)
			palt(colors.player_transparent or 0, false)
			palt(0, true)

			objects:draw(view_offset)
			hud(view)
		end
	}
end

function spr_scroll(spr_id, x, y, w, h, speed)
		local offset=(time()%16)*speed
		for i=0,128/(w*8)+speed*2/w do
			spr(spr_id, x+i*8*w-offset, y, w, h)
		end
end

function scan_map(width, height, process)
	for i=0,width-1 do
		for j=0,height-1 do
			tile=mget(i, j)
			process(tile)
		end
	end
end
