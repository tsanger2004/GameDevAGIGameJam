package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"
import "core:fmt"
import "core:strings"

spawn_enemy :: proc() {
	side := int(rand.float32() * 4)
	pos: Vec2
	switch side {
	case 0: pos = Vec2{rand_range(ENEMY_RADIUS, SCREEN_W - ENEMY_RADIUS), ENEMY_RADIUS}            // top
	case 1: pos = Vec2{SCREEN_W - ENEMY_RADIUS, rand_range(ENEMY_RADIUS, SCREEN_H - ENEMY_RADIUS)}  // right
	case 2: pos = Vec2{rand_range(ENEMY_RADIUS, SCREEN_W - ENEMY_RADIUS), SCREEN_H - ENEMY_RADIUS}  // bottom
	case:   pos = Vec2{ENEMY_RADIUS, rand_range(ENEMY_RADIUS, SCREEN_H - ENEMY_RADIUS)}            // left
	}

	boss := game.room == FINAL_ROOM
	enemy_type := Enemy_Type.Normal
	if !boss {
		roll := rand.float32()
		if game.room >= 2 {
			if game.room == 2 {
				if game.room_spawned % 5 == 0 || roll < 0.2 {
					enemy_type = game.special_enemy_first
				}
			} else if game.room_spawned % 5 == 0 || roll < 0.2 {
				enemy_type = .Charger
			} else if game.room_spawned % 5 == 1 || roll < 0.4 {
				enemy_type = .Ranged
			}
		}
	}
	enemy_id := game.next_enemy_id
	game.next_enemy_id += 1
	speed := min(ENEMY_BASE_SPEED + f32(game.room) * 10, ENEMY_MAX_SPEED) * (1 + game.enemy_speed_bonus)
	health := ENEMY_ROOM_HEALTH + game.room * ENEMY_HEALTH_PER_ROOM + game.enemy_health_bonus
	radius := f32(ENEMY_RADIUS)
	state_timer := f32(0)
	attack_timer := ENEMY_BOSS_AIMED_COOLDOWN
	charger_dash_speed := ENEMY_CHARGER_DASH_SPEED
	charger_cooldown := ENEMY_CHARGER_COOLDOWN
	ranged_shots := 1
	ranged_cooldown := ENEMY_RANGED_SHOT_COOLDOWN
	if enemy_type == .Charger {
		charger_dash_speed *= game.charger_dash_speed_multiplier
		charger_cooldown *= game.charger_cooldown_multiplier
		attack_timer = charger_cooldown
	} else if enemy_type == .Ranged {
		speed = ENEMY_RANGED_SPEED
		ranged_shots = game.ranged_shot_count
		ranged_cooldown *= game.ranged_cooldown_multiplier
		attack_timer = ranged_cooldown
	}
	if boss {
		speed = ENEMY_BOSS_OPENING_SPEED * (1 + game.enemy_speed_bonus)
		health = ENEMY_BOSS_HEALTH + game.enemy_health_bonus * 2
		radius = 34
	}

	append(&game.enemies, Enemy{
		id = enemy_id,
		type = .Boss if boss else enemy_type,
		pos = pos,
		speed = speed,
		health = health,
		max_health = health,
		radius = radius,
		boss = boss,
		attack_timer = attack_timer,
		attack_pattern = 0,
		boss_phase = 0,
		boss_phase_timer = ENEMY_BOSS_PHASE_TIME,
		boss_charges_remaining = ENEMY_BOSS_CHARGES,
		state_timer = state_timer,
		dash_dir = Vec2{0, 0},
		split_count = game.enemy_splitter,
		armor = game.enemy_armor,
		ranged_level = game.enemy_ranged_level * int(!boss && enemy_type == .Normal),
		charger_dash_speed = charger_dash_speed,
		charger_cooldown = charger_cooldown,
		ranged_shots = ranged_shots,
		ranged_cooldown = ranged_cooldown,
		spawn_timer = 0,
		alive = true,
	})
	game.room_spawned += 1
}

spawn_final_reinforcement :: proc() {
	pos := Vec2{rand_range(80, SCREEN_W - 80), 70}
	enemy_id := game.next_enemy_id
	game.next_enemy_id += 1
	append(&game.enemies, Enemy{
		id = enemy_id,
		type = .Normal,
		pos = pos,
		speed = ENEMY_BASE_SPEED,
		health = 10,
		max_health = 10,
		radius = ENEMY_RADIUS,
		boss = false,
		attack_timer = ENEMY_MINION_SHOT_COOLDOWN,
		attack_pattern = 0,
		state_timer = 0,
		dash_dir = Vec2{0, 0},
		split_count = 0,
		armor = 0,
		ranged_level = 0,
		charger_dash_speed = ENEMY_CHARGER_DASH_SPEED,
		charger_cooldown = ENEMY_CHARGER_COOLDOWN,
		ranged_shots = 1,
		ranged_cooldown = ENEMY_RANGED_SHOT_COOLDOWN,
		spawn_timer = ENEMY_DROP_TIME,
		alive = true,
	})
}

// ---------------------------------------------------------------------------
// Update
// ---------------------------------------------------------------------------

update_player :: proc(dt: f32) {
	p := &game.player

	dir := Vec2{0, 0}
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)    do dir.y -= 1
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)  do dir.y += 1
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)  do dir.x -= 1
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do dir.x += 1

	if dir.x != 0 || dir.y != 0 {
		dir = vec2_normalize(dir)
		p.pos = vec2_add(p.pos, vec2_scale(dir, p.speed * dt))
	}

	if p.dash_timer > 0 do p.dash_timer -= dt
	if p.shockwave_timer > 0 do p.shockwave_timer -= dt
	if rl.IsKeyPressed(.SPACE) && p.dash_timer <= 0 {
		dash_dir := dir
		if dash_dir.x == 0 && dash_dir.y == 0 {
			mouse := rl.GetMousePosition()
			dash_dir = vec2_normalize(vec2_sub(mouse, p.pos))
		}
		if dash_dir.x != 0 || dash_dir.y != 0 {
			p.pos = vec2_add(p.pos, vec2_scale(dash_dir, PLAYER_DASH_DISTANCE))
			p.dash_timer = p.dash_cooldown
			p.invuln_timer = max(p.invuln_timer, PLAYER_INVULN_TIME)
			if p.dash_shockwave_level > 0 {
				p.shockwave_pos = p.pos
				p.shockwave_radius = PLAYER_DASH_SHOCKWAVE_RADIUS * (1 + f32(p.dash_shockwave_level - 1) * 0.25)
				p.shockwave_timer = PLAYER_DASH_SHOCKWAVE_DURATION
				p.shockwave_applied = false
			}
		}
	}

	p.pos.x = clamp(p.pos.x, PLAYER_RADIUS, SCREEN_W - PLAYER_RADIUS)
	p.pos.y = clamp(p.pos.y, PLAYER_RADIUS, SCREEN_H - PLAYER_RADIUS)

	if p.invuln_timer > 0 do p.invuln_timer -= dt
	if p.fire_timer > 0   do p.fire_timer -= dt

	if rl.IsMouseButtonDown(.LEFT) && p.fire_timer <= 0 {
		mouse := rl.GetMousePosition()
		aim := vec2_normalize(vec2_sub(mouse, p.pos))
		if aim.x != 0 || aim.y != 0 {
			for shot in 0..<p.bullet_count {
				center := f32(p.bullet_count - 1) / 2
				shot_aim := vec2_rotate(aim, (f32(shot) - center) * p.bullet_spread)
				append(&game.bullets, Bullet{
					pos       = p.pos,
					vel       = vec2_scale(shot_aim, BULLET_SPEED),
					damage    = p.bullet_damage,
					hits_left = p.piercing + 1,
					ricochets_left = p.ricochets,
					hostile   = false,
					alive     = true,
				})
			}
			p.fire_timer = p.fire_cooldown
		}
	}
}

fire_hostile_bullet :: proc(pos, vel: Vec2, damage: int) {
	append(&game.bullets, Bullet{
		pos = pos,
		vel = vel,
		damage = damage,
		hits_left = 1,
		hostile = true,
		alive = true,
	})
}

fire_boss_pattern :: proc(e: ^Enemy, player_pos: Vec2) {
	aim := vec2_normalize(vec2_sub(player_pos, e.pos))
	if e.attack_pattern == 0 {
		for shot in 0..<5 {
			angle := (f32(shot) - 2) * 0.2
			fire_hostile_bullet(e.pos, vec2_scale(vec2_rotate(aim, angle), ENEMY_BOSS_SHOT_SPEED), ENEMY_BOSS_SHOT_DAMAGE)
		}
		e.attack_timer = ENEMY_BOSS_AIMED_COOLDOWN
		e.attack_pattern = 1
	} else {
		for shot in 0..<12 {
			angle := f32(shot) * math.PI * 2 / 12
			fire_hostile_bullet(e.pos, vec2_scale(Vec2{math.cos(angle), math.sin(angle)}, ENEMY_BOSS_SHOT_SPEED * 0.85), ENEMY_BOSS_SHOT_DAMAGE)
		}
		e.attack_timer = ENEMY_BOSS_RADIAL_COOLDOWN
		e.attack_pattern = 0
	}
}

fire_boss_ranged_pattern :: proc(e: ^Enemy, player_pos: Vec2) {
	aim := vec2_normalize(vec2_sub(player_pos, e.pos))
	for shot in 0..<5 {
		angle := (f32(shot) - 2) * 0.16
		fire_hostile_bullet(e.pos, vec2_scale(vec2_rotate(aim, angle), ENEMY_BOSS_SHOT_SPEED), ENEMY_BOSS_SHOT_DAMAGE)
	}
	e.attack_timer = ENEMY_RANGED_SHOT_COOLDOWN
}

fire_boss_final_pattern :: proc(e: ^Enemy, player_pos: Vec2) {
	pattern := int(rand.float32() * 3)
	switch pattern {
	case 0:
		for shot in 0..<18 {
			angle := f32(shot) * math.PI * 2 / 18
			fire_hostile_bullet(e.pos, vec2_scale(Vec2{math.cos(angle), math.sin(angle)}, ENEMY_BOSS_FINAL_STAND_SPEED), ENEMY_BOSS_SHOT_DAMAGE)
		}
	case 1:
		aim := vec2_normalize(vec2_sub(player_pos, e.pos))
		for shot in 0..<9 {
			angle := (f32(shot) - 4) * 0.2
			fire_hostile_bullet(e.pos, vec2_scale(vec2_rotate(aim, angle), ENEMY_BOSS_FINAL_STAND_SPEED * 1.25), ENEMY_BOSS_SHOT_DAMAGE)
		}
	case:
		rotation := rand.float32() * math.PI * 2
		for shot in 0..<12 {
			angle := rotation + f32(shot) * math.PI * 2 / 12
			fire_hostile_bullet(e.pos, vec2_scale(Vec2{math.cos(angle), math.sin(angle)}, ENEMY_BOSS_FINAL_STAND_SPEED * 0.9), ENEMY_BOSS_SHOT_DAMAGE)
		}
		aim := vec2_normalize(vec2_sub(player_pos, e.pos))
		for shot in 0..<3 {
			angle := (f32(shot) - 1) * 0.2
			fire_hostile_bullet(e.pos, vec2_scale(vec2_rotate(aim, angle), ENEMY_BOSS_FINAL_STAND_SPEED * 1.35), ENEMY_BOSS_SHOT_DAMAGE)
		}
	}
	e.attack_timer = ENEMY_BOSS_FINAL_STAND_COOLDOWN
}

fire_enemy_shot :: proc(e: ^Enemy, player_pos: Vec2) {
	aim := vec2_normalize(vec2_sub(player_pos, e.pos))
	for shot in 0..<e.ranged_level {
		center := f32(e.ranged_level - 1) / 2
		angle := (f32(shot) - center) * 0.2
		append(&game.bullets, Bullet{
			pos = e.pos,
			vel = vec2_scale(vec2_rotate(aim, angle), ENEMY_MINION_SHOT_SPEED),
			damage = ENEMY_MINION_SHOT_DAMAGE,
			hits_left = 1,
			hostile = true,
			alive = true,
		})
	}
	e.attack_timer = ENEMY_MINION_SHOT_COOLDOWN
}

fire_ranged_enemy_shot :: proc(e: ^Enemy, player_pos: Vec2) {
	aim := vec2_normalize(vec2_sub(player_pos, e.pos))
	for shot in 0..<e.ranged_shots {
		center := f32(e.ranged_shots - 1) / 2
		angle := (f32(shot) - center) * 0.16
		append(&game.bullets, Bullet{
			pos = e.pos,
			vel = vec2_scale(vec2_rotate(aim, angle), ENEMY_RANGED_SHOT_SPEED),
			damage = ENEMY_RANGED_SHOT_DAMAGE,
			hits_left = 1,
			hostile = true,
			alive = true,
		})
	}
	e.attack_timer = e.ranged_cooldown
}

update_spawning :: proc(dt: f32) {
	game.elapsed += dt
	if game.room == FINAL_ROOM {
		if game.room_spawned < game.room_enemy_target {
			game.spawn_timer -= dt
			if game.spawn_timer <= 0 {
				spawn_enemy()
			}
			return
		}
		boss_present := false
				for e in game.enemies {
			if e.alive && e.boss {
				boss_present = true
				break
			}
		}
		if boss_present {
			game.final_reinforcement_timer -= dt
			if game.final_reinforcement_timer <= 0 {
				spawn_final_reinforcement()
				game.final_reinforcement_timer = FINAL_REINFORCEMENT_INTERVAL
			}
		}
		return
	}
	if game.room_spawned >= game.room_enemy_target do return
	game.spawn_timer -= dt
	if game.spawn_timer <= 0 {
		spawn_enemy()
		game.spawn_timer = max(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX - f32(game.room) * 0.08) * game.spawn_rate_multiplier
	}
}

update_charger_movement :: proc(e: ^Enemy, player: ^Player, dt: f32) {
	if e.state_timer > 0 {
		e.state_timer -= dt
		if e.state_timer <= 0 do e.state_timer = -ENEMY_CHARGER_DASH_TIME
	} else if e.state_timer < 0 {
		e.pos = vec2_add(e.pos, vec2_scale(e.dash_dir, e.charger_dash_speed * dt))
		e.state_timer += dt
		if e.state_timer >= 0 {
			e.state_timer = 0
			e.attack_timer = e.charger_cooldown
		}
	} else {
		e.attack_timer -= dt
		distance := vec2_dist(player.pos, e.pos)
		in_dash_range := distance >= ENEMY_CHARGER_MIN_DASH_RANGE && distance <= ENEMY_CHARGER_MAX_DASH_RANGE
		if distance > ENEMY_CHARGER_MAX_DASH_RANGE {
			dir := vec2_normalize(vec2_sub(player.pos, e.pos))
			e.pos = vec2_add(e.pos, vec2_scale(dir, ENEMY_CHARGER_APPROACH_SPEED * dt))
		}
		if e.attack_timer <= 0 && in_dash_range {
			e.state_timer = ENEMY_CHARGER_TELEGRAPH
			to_player := vec2_normalize(vec2_sub(player.pos, e.pos))
			past_player := vec2_add(player.pos, vec2_scale(to_player, ENEMY_CHARGER_OVERSHOOT))
			e.dash_dir = vec2_normalize(vec2_sub(past_player, e.pos))
		} else if e.attack_timer <= 0 && !in_dash_range {
			e.attack_timer = 0
		}
	}
}

update_boss_charger_movement :: proc(e: ^Enemy, player: ^Player, dt: f32) {
	if e.state_timer < 0 {
		e.pos = vec2_add(e.pos, vec2_scale(e.dash_dir, e.charger_dash_speed * dt))
		e.state_timer += dt
		if e.state_timer >= 0 {
			e.state_timer = 0
			e.boss_charges_remaining -= 1
			if e.boss_charges_remaining <= 0 {
				e.boss_phase = 2
				e.boss_phase_timer = ENEMY_BOSS_PHASE_TIME
				e.attack_timer = 0
				e.speed = ENEMY_RANGED_SPEED
			} else {
				e.attack_timer = ENEMY_BOSS_DASH_GAP
			}
		}
		return
	}

	e.attack_timer -= dt
	if e.attack_timer <= 0 && e.boss_charges_remaining > 0 {
		to_player := vec2_normalize(vec2_sub(player.pos, e.pos))
		past_player := vec2_add(player.pos, vec2_scale(to_player, ENEMY_CHARGER_OVERSHOOT))
		e.dash_dir = vec2_normalize(vec2_sub(past_player, e.pos))
		e.state_timer = -ENEMY_CHARGER_DASH_TIME
	}
}

update_ranged_movement :: proc(e: ^Enemy, player: ^Player, dt: f32) {
	to_player := vec2_sub(player.pos, e.pos)
	distance := vec2_len(to_player)
	dir := vec2_normalize(to_player)
	move_dir := Vec2{0, 0}
	if distance > ENEMY_RANGED_DISTANCE + 35 {
		move_dir = dir
	} else if distance < ENEMY_RANGED_DISTANCE - 35 {
		move_dir = vec2_scale(dir, -1)
	} else {
		strafe_sign := f32(1)
		if e.id % 2 == 0 do strafe_sign = -1
		move_dir = Vec2{-dir.y * strafe_sign, dir.x * strafe_sign}
	}
	e.pos = vec2_add(e.pos, vec2_scale(move_dir, e.speed * dt))
}

update_boss_phase :: proc(e: ^Enemy, dt: f32) {
	if f32(e.health) <= f32(e.max_health) * ENEMY_BOSS_FINAL_STAND_THRESHOLD && e.boss_phase != 3 {
		e.boss_phase = 3
		e.boss_phase_timer = 0
		e.attack_timer = 0
		e.state_timer = 0
		e.speed = ENEMY_RANGED_SPEED
		return
	}
	if e.boss_phase >= 3 do return
	if e.boss_phase == 1 do return
	e.boss_phase_timer -= dt
	if e.boss_phase_timer <= 0 {
		if e.boss_phase == 2 {
			e.boss_phase = 0
		} else {
			e.boss_phase += 1
		}
		e.boss_phase_timer = ENEMY_BOSS_PHASE_TIME
		e.attack_timer = 0
		e.state_timer = 0
		if e.boss_phase == 1 do e.boss_charges_remaining = ENEMY_BOSS_CHARGES
		if e.boss_phase == 2 {
			e.speed = ENEMY_RANGED_SPEED
		} else if e.boss_phase == 0 {
			e.speed = ENEMY_BOSS_OPENING_SPEED
		} else {
			e.speed = ENEMY_BOSS_SPEED
		}
	}
}

update_enemies :: proc(dt: f32) {
	p := &game.player
	for i in 0 ..< len(game.enemies) {
		e := &game.enemies[i]
		if !e.alive do continue
		if e.spawn_timer > 0 {
			e.spawn_timer -= dt
			continue
		}
		if e.ally {
			e.ally_timer -= dt
			if e.ally_timer <= 0 {
				e.alive = false
				continue
			}
			target_index := -1
			target_distance := f32(1000000)
			for target_i in 0 ..< len(game.enemies) {
				target := &game.enemies[target_i]
				if !target.alive || target.ally || target_i == i do continue
				distance := vec2_dist(e.pos, target.pos)
				if distance < target_distance {
					target_index = target_i
					target_distance = distance
				}
			}
			if target_index >= 0 {
				target := &game.enemies[target_index]
				dir := vec2_normalize(vec2_sub(target.pos, e.pos))
				e.pos = vec2_add(e.pos, vec2_scale(dir, e.speed * dt))
				e.attack_timer -= dt
				if target_distance < e.radius + target.radius + 4 && e.attack_timer <= 0 {
					target.health -= 1
					e.attack_timer = ALLY_ATTACK_COOLDOWN
					if target.health <= 0 do target.alive = false
				}
			}
			continue
		}

		if e.boss {
			update_boss_phase(e, dt)
			if e.boss_phase == 1 {
				update_boss_charger_movement(e, p, dt)
			} else if e.boss_phase == 2 || e.boss_phase == 3 {
				update_ranged_movement(e, p, dt)
			} else {
				dir := vec2_normalize(vec2_sub(p.pos, e.pos))
				e.pos = vec2_add(e.pos, vec2_scale(dir, e.speed * dt))
			}
		} else if e.type == .Charger {
			update_charger_movement(e, p, dt)
		} else if e.type == .Ranged {
			update_ranged_movement(e, p, dt)
			e.attack_timer -= dt
			if e.attack_timer <= 0 do fire_ranged_enemy_shot(e, p.pos)
		} else {
			dir := vec2_normalize(vec2_sub(p.pos, e.pos))
			e.pos = vec2_add(e.pos, vec2_scale(dir, e.speed * dt))
		}
		e.pos.x = clamp(e.pos.x, e.radius, SCREEN_W - e.radius)
		e.pos.y = clamp(e.pos.y, e.radius, SCREEN_H - e.radius)
		if e.boss && e.boss_phase == 3 {
			e.attack_timer -= dt
			if e.attack_timer <= 0 do fire_boss_final_pattern(e, p.pos)
		} else if e.boss && e.boss_phase == 2 {
			e.attack_timer -= dt
			if e.attack_timer <= 0 do fire_boss_ranged_pattern(e, p.pos)
		} else if e.boss && e.boss_phase == 0 {
			e.attack_timer -= dt
			if e.attack_timer <= 0 do fire_boss_pattern(e, p.pos)
		} else if e.type == .Normal && e.ranged_level > 0 {
			e.attack_timer -= dt
			if e.attack_timer <= 0 do fire_enemy_shot(e, p.pos)
		}

		if p.invuln_timer <= 0 && vec2_dist(e.pos, p.pos) < e.radius + PLAYER_RADIUS {
			p.health -= f32(game.enemy_contact_damage)
			p.invuln_timer = PLAYER_INVULN_TIME

			push := vec2_normalize(vec2_sub(p.pos, e.pos))
			p.pos = vec2_add(p.pos, vec2_scale(push, KNOCKBACK * game.enemy_knockback * dt))
			e.pos = vec2_sub(e.pos, vec2_scale(push, KNOCKBACK * dt * 0.5))

			if p.health <= 0 {
				p.health = 0
				game.state = .Title
			}
		}
	}
}

update_bullets :: proc(dt: f32) {
	p := &game.player
	for i in 0 ..< len(game.bullets) {
		b := &game.bullets[i]
		b.pos = vec2_add(b.pos, vec2_scale(b.vel, dt))
		if b.hostile && p.invuln_timer <= 0 && vec2_dist(b.pos, p.pos) < BULLET_RADIUS + PLAYER_RADIUS {
			p.health -= f32(b.damage)
			p.invuln_timer = PLAYER_INVULN_TIME
			b.alive = false
			if p.health <= 0 {
				p.health = 0
				game.state = .Title
			}
		}
		if b.pos.x < -20 || b.pos.x > SCREEN_W + 20 || b.pos.y < -20 || b.pos.y > SCREEN_H + 20 {
			b.alive = false
		}
	}
}

retarget_ricochet :: proc(b: ^Bullet) {
	best_index := -1
	best_distance := f32(1000000)
	for i in 0 ..< len(game.enemies) {
		e := &game.enemies[i]
		if !e.alive || e.ally do continue
		already_hit := false
		for hit_id in b.hit_enemy_ids {
			if hit_id == e.id {
				already_hit = true
				break
			}
		}
		if already_hit do continue
		distance := vec2_dist(b.pos, e.pos)
		if distance < best_distance {
			best_index = i
			best_distance = distance
		}
	}
	if best_index >= 0 {
		target := &game.enemies[best_index]
		b.vel = vec2_scale(vec2_normalize(vec2_sub(target.pos, b.pos)), BULLET_SPEED)
		b.ricochets_left -= 1
	} else if b.hits_left <= 0 {
		b.alive = false
	}
}

handle_collisions :: proc() {
	if game.player.shockwave_timer > 0 && !game.player.shockwave_applied {
		game.player.shockwave_applied = true
		damage := PLAYER_DASH_SHOCKWAVE_DAMAGE * game.player.dash_shockwave_level
		for ei in 0 ..< len(game.enemies) {
			e := &game.enemies[ei]
			if !e.alive || e.ally do continue
			if vec2_dist(e.pos, game.player.shockwave_pos) <= game.player.shockwave_radius + e.radius {
				e.health -= max(1, damage - e.armor)
				if e.health <= 0 {
					e.alive = false
					game.kills += 1
					game.player.health = min(game.player.max_health, game.player.health + game.player.kill_heal)
				}
			}
		}
	}

	for bi in 0 ..< len(game.bullets) {
		b := &game.bullets[bi]
		if !b.alive || b.hostile do continue
		for ei in 0 ..< len(game.enemies) {
			e := &game.enemies[ei]
			if !e.alive || e.ally do continue
			already_hit := false
			for hit_id in b.hit_enemy_ids {
				if hit_id == e.id {
					already_hit = true
					break
				}
			}
			if already_hit do continue
			if vec2_dist(b.pos, e.pos) < BULLET_RADIUS + e.radius {
				append(&b.hit_enemy_ids, e.id)
				b.hits_left -= 1
				if b.hits_left <= 0 && b.ricochets_left <= 0 do b.alive = false
				e.health -= max(1, b.damage - e.armor)
				if e.health <= 0 {
					if !e.boss && rand.float32() < game.player.necromancer_chance {
						e.ally = true
						e.boss = false
						e.health = 1
						e.max_health = 1
						e.split_count = 0
						e.attack_timer = 0
						e.ally_timer = NECROMANCER_ALLY_LIFESPAN
					} else {
						death_pos := e.pos
						death_speed := e.speed
						was_boss := e.boss
						split_count := e.split_count
						e.alive = false
						game.kills += 1
						game.player.health = min(game.player.max_health, game.player.health + game.player.kill_heal)
						if split_count > 0 {
							child_count := split_count * 2
							for split in 0..<child_count {
								offset := (f32(split) - f32(child_count - 1) / 2) * 12
								child_health := 1
								child_radius := f32(9)
								if was_boss {
									child_health = max(1, e.max_health / 2)
									child_radius = 34
								}
								append(&game.enemies, Enemy{
									id = game.next_enemy_id,
									type = .Boss if was_boss else .Normal,
									pos = Vec2{death_pos.x + offset, death_pos.y},
									speed = death_speed * 1.2,
									health = child_health,
									max_health = child_health,
									radius = child_radius,
									boss = was_boss,
									attack_timer = ENEMY_BOSS_AIMED_COOLDOWN,
									attack_pattern = 0,
									boss_phase = e.boss_phase,
									boss_phase_timer = ENEMY_BOSS_PHASE_TIME,
									boss_charges_remaining = ENEMY_BOSS_CHARGES,
									state_timer = 0,
									dash_dir = Vec2{0, 0},
									split_count = 0,
									armor = game.enemy_armor,
									ranged_level = game.enemy_ranged_level * int(!was_boss),
									charger_dash_speed = ENEMY_CHARGER_DASH_SPEED,
									charger_cooldown = ENEMY_CHARGER_COOLDOWN,
									ranged_shots = 1,
									ranged_cooldown = ENEMY_RANGED_SHOT_COOLDOWN,
									spawn_timer = 0,
									ally_timer = 0,
									alive = true,
								})
								game.next_enemy_id += 1
							}
						}
					}
				}
				if b.alive && b.ricochets_left > 0 do retarget_ricochet(b)
				if !b.alive do break
			}
		}
	}

	for i := len(game.bullets) - 1; i >= 0; i -= 1 {
		if !game.bullets[i].alive do unordered_remove(&game.bullets, i)
	}
	for i := len(game.enemies) - 1; i >= 0; i -= 1 {
		if !game.enemies[i].alive do unordered_remove(&game.enemies, i)
	}

	hostile_enemies := 0
	for e in game.enemies {
		if e.alive && !e.ally do hostile_enemies += 1
	}
	if game.state == .Playing && game.room_spawned >= game.room_enemy_target && hostile_enemies == 0 {
		game.xp += ROOM_XP
		if game.room == FINAL_ROOM {
			game.state = .Victory
		} else {
			begin_level_up()
		}
	}
}

// ---------------------------------------------------------------------------
// Draw
// ---------------------------------------------------------------------------

draw_title_screen :: proc() {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{7, 20, 24, 255})
	rl.DrawRectangleLines(24, 24, SCREEN_W - 48, SCREEN_H - 48, rl.Color{50, 150, 140, 255})

	title := cstring("VIRUS CLEANUP")
	title_w := rl.MeasureText(title, 64)
	rl.DrawText(title, SCREEN_W / 2 - title_w / 2, 125, 64, rl.SKYBLUE)

	blurb := cstring("Boot the antivirus, purge the infected system, and destroy the corrupted core.")
	blurb_w := rl.MeasureText(blurb, 20)
	rl.DrawText(blurb, SCREEN_W / 2 - blurb_w / 2, 225, 20, rl.LIGHTGRAY)
	controls := cstring("WASD / Arrow Keys: Move    Mouse: Aim and Shoot")
	controls_w := rl.MeasureText(controls, 18)
	rl.DrawText(controls, SCREEN_W / 2 - controls_w / 2, 260, 18, rl.WHITE)

	m := rl.GetMousePosition()
	play_hovered := m.x >= 490 && m.x <= 790 && m.y >= 320 && m.y <= 390
	exit_hovered := m.x >= 490 && m.x <= 790 && m.y >= 420 && m.y <= 490
	play_fill := rl.Color{35, 70, 65, 255}
	exit_fill := rl.Color{65, 42, 48, 255}
	if play_hovered do play_fill = rl.Color{55, 105, 88, 255}
	if exit_hovered do exit_fill = rl.Color{100, 58, 62, 255}

	rl.DrawRectangle(490, 320, 300, 70, play_fill)
	rl.DrawRectangleLines(490, 320, 300, 70, rl.Color{140, 190, 160, 255})
	rl.DrawRectangle(490, 420, 300, 70, exit_fill)
	rl.DrawRectangleLines(490, 420, 300, 70, rl.Color{190, 140, 140, 255})

	play := cstring("PLAY")
	exit := cstring("EXIT")
	rl.DrawText(play, SCREEN_W / 2 - rl.MeasureText(play, 28) / 2, 340, 28, rl.WHITE)
	rl.DrawText(exit, SCREEN_W / 2 - rl.MeasureText(exit, 28) / 2, 440, 28, rl.WHITE)
	rl.DrawText(cstring("Click a button or press ENTER to begin the scan"), 450, 555, 18, rl.LIGHTGRAY)
}

draw_arena :: proc() {
	rl.DrawRectangleLines(4, 4, SCREEN_W - 8, SCREEN_H - 8, rl.Color{35, 110, 105, 255})
}

draw_player :: proc() {
	p := game.player
	if p.shockwave_timer > 0 {
		progress := 1 - p.shockwave_timer / PLAYER_DASH_SHOCKWAVE_DURATION
		wave_radius := p.shockwave_radius * (0.55 + progress * 0.45)
		rl.DrawCircleV(p.shockwave_pos, wave_radius, rl.Color{45, 210, 240, 35})
		rl.DrawCircleLinesV(p.shockwave_pos, wave_radius, rl.Color{90, 235, 255, 220})
		rl.DrawCircleLinesV(p.shockwave_pos, wave_radius * 0.78, rl.Color{90, 235, 255, 110})
	}
	col := rl.SKYBLUE
	if p.invuln_timer > 0 && int(p.invuln_timer * 20) % 2 == 0 {
		col = rl.WHITE
	}
	rl.DrawCircleV(p.pos, PLAYER_RADIUS, col)

	// aim line toward the mouse cursor
	mouse := rl.GetMousePosition()
	aim := vec2_normalize(vec2_sub(mouse, p.pos))
	tip := vec2_add(p.pos, vec2_scale(aim, PLAYER_RADIUS + 10))
	rl.DrawLineV(p.pos, tip, rl.Color{255, 255, 255, 120})
}

draw_enemies :: proc() {
	for e in game.enemies {
		if e.spawn_timer > 0 {
			progress := 1 - e.spawn_timer / ENEMY_DROP_TIME
			beam_top := Vec2{e.pos.x, 20}
			rl.DrawLineV(beam_top, e.pos, rl.Color{60, 240, 190, 90})
			rl.DrawCircleV(e.pos, e.radius * (0.5 + progress * 0.5), rl.Color{220, 60, 130, 220})
			rl.DrawCircleLinesV(e.pos, e.radius + 5 + progress * 8, rl.Color{90, 255, 210, 180})
			continue
		}
		if e.ally {
			rl.DrawCircleV(e.pos, e.radius, rl.Color{110, 255, 170, 255})
			rl.DrawCircleLinesV(e.pos, e.radius + 3, rl.Color{80, 220, 255, 255})
			continue
		}
		col := rl.Color{220, 60, 130, 255}
		if e.boss {
			switch e.boss_phase {
			case 1:
				col = rl.Color{220, 50, 150, 255}
			case 2:
				col = rl.Color{40, 230, 200, 255}
			case 3:
				col = rl.Color{210, 240, 70, 255}
			case:
				col = rl.Color{220, 60, 130, 255}
			}
			if e.boss_phase == 1 {
				if e.state_timer > 0 && int(e.state_timer * 14) % 2 == 0 do col = rl.Color{255, 220, 70, 255}
				if e.state_timer < 0 do col = rl.Color{255, 100, 190, 255}
			}
			rl.DrawCircleV(e.pos, e.radius, col)
			rl.DrawCircleLinesV(e.pos, e.radius + 4, col)
			if e.boss_phase == 1 && e.state_timer > 0 {
				rl.DrawCircleLinesV(e.pos, e.radius + 5, rl.Color{255, 220, 70, 255})
				direction_tip := vec2_add(e.pos, vec2_scale(e.dash_dir, 90))
				rl.DrawLineV(e.pos, direction_tip, rl.ORANGE)
			} else if e.boss_phase == 1 && e.state_timer < 0 {
				dash_tip := vec2_add(e.pos, vec2_scale(e.dash_dir, 70))
				rl.DrawLineV(e.pos, dash_tip, rl.Color{255, 100, 190, 255})
			}
		} else if e.type == .Charger {
			col = rl.Color{180, 50, 220, 255}
			if e.state_timer > 0 && int(e.state_timer * 14) % 2 == 0 do col = rl.Color{255, 220, 70, 255}
			if e.state_timer < 0 do col = rl.Color{255, 100, 190, 255}
			rl.DrawCircleV(e.pos, e.radius, col)
			if e.state_timer > 0 {
				rl.DrawCircleLinesV(e.pos, e.radius + 5, rl.Color{255, 220, 70, 255})
				direction_tip := vec2_add(e.pos, vec2_scale(e.dash_dir, 90))
				rl.DrawLineV(e.pos, direction_tip, rl.YELLOW)
			} else if e.state_timer < 0 {
				dash_tip := vec2_add(e.pos, vec2_scale(e.dash_dir, 70))
				rl.DrawLineV(e.pos, dash_tip, rl.Color{255, 100, 190, 255})
			}
		} else if e.type == .Ranged {
			col = rl.Color{40, 220, 200, 255}
			rl.DrawCircleV(e.pos, e.radius, col)
			rl.DrawCircleLinesV(e.pos, e.radius + 3, rl.Color{20, 150, 150, 255})
			rl.DrawCircleLinesV(e.pos, ENEMY_RANGED_DISTANCE, rl.Color{80, 220, 200, 45})
		} else {
			if e.health >= 2 do col = rl.Color{240, 190, 50, 255}
			if e.health >= 4 do col = rl.Color{100, 220, 100, 255}
			rl.DrawCircleV(e.pos, e.radius, col)
			if e.ranged_level > 0 do rl.DrawCircleLinesV(e.pos, e.radius + 2, rl.Color{70, 230, 220, 255})
			if e.armor > 0 do rl.DrawCircleLinesV(e.pos, e.radius + 4, rl.Color{190, 240, 210, 255})
		}
	}
}

draw_bullets :: proc() {
	for b in game.bullets {
		col := rl.YELLOW
		if b.hostile do col = rl.RED
		rl.DrawCircleV(b.pos, BULLET_RADIUS, col)
	}
}

draw_hud :: proc() {
	// health bar
	bar_w := f32(240)
	pct := max(game.player.health, 0) / game.player.max_health
	rl.DrawRectangle(20, 20, i32(bar_w), 22, rl.Color{50, 50, 50, 255})
	rl.DrawRectangle(20, 20, i32(bar_w * pct), 22, rl.GREEN)
	rl.DrawRectangleLines(20, 20, i32(bar_w), 22, rl.WHITE)
	rl.DrawText(fmt.ctprintf("INTEGRITY %d/%d", int(game.player.health), int(game.player.max_health)), 26, 24, 16, rl.WHITE)

	score := game.kills * 10 + int(game.elapsed)
	rl.DrawText(fmt.ctprintf("THREATS: %d", game.kills), SCREEN_W - 180, 20, 22, rl.WHITE)
	rl.DrawText(fmt.ctprintf("SCAN TIME: %.1fs", game.elapsed), SCREEN_W - 180, 48, 18, rl.LIGHTGRAY)
	rl.DrawText(fmt.ctprintf("SCORE: %d", score), SCREEN_W - 180, 70, 18, rl.LIGHTGRAY)
	rl.DrawText(fmt.ctprintf("CLEARANCE %d  DATA %d", game.level, game.xp), 20, 52, 18, rl.LIGHTGRAY)

	dash_x := i32(285)
	dash_y := i32(18)
	dash_size := i32(46)
	dash_ready := 1.0 - game.player.dash_timer / game.player.dash_cooldown
	dash_ready = clamp(dash_ready, 0, 1)
	rl.DrawRectangle(dash_x, dash_y, dash_size, dash_size, rl.Color{35, 45, 58, 255})
	rl.DrawRectangle(dash_x, dash_y + dash_size - i32(f32(dash_size) * dash_ready), dash_size, i32(f32(dash_size) * dash_ready), rl.Color{40, 190, 220, 170})
	rl.DrawRectangleLines(dash_x, dash_y, dash_size, dash_size, rl.WHITE)
	dash_icon := rl.Color{100, 120, 135, 255}
	if dash_ready >= 1 do dash_icon = rl.SKYBLUE
	rl.DrawLine(dash_x + 12, dash_y + 29, dash_x + 24, dash_y + 17, dash_icon)
	rl.DrawLine(dash_x + 24, dash_y + 17, dash_x + 22, dash_y + 25, dash_icon)
	rl.DrawLine(dash_x + 24, dash_y + 17, dash_x + 32, dash_y + 19, dash_icon)
	rl.DrawText(cstring("SPACE"), dash_x + 52, dash_y + 14, 14, rl.LIGHTGRAY)
	room_label := fmt.ctprintf("SECTOR %d/%d", game.room, FINAL_ROOM)
	if game.room == FINAL_ROOM do room_label = cstring("KERNEL - CORRUPTED CORE")
	rl.DrawText(room_label, SCREEN_W / 2 - rl.MeasureText(room_label, 20) / 2, 20, 20, rl.YELLOW)

	draw_boss_health_bars()
}

draw_boss_health_bars :: proc() {
	boss_count := 0
	for e in game.enemies {
		if e.alive && e.boss && !e.ally do boss_count += 1
	}
	if boss_count == 0 do return

	bar_y := f32(SCREEN_H - 54)
	bar_h := f32(28)
	gap := f32(10)
	available_width := f32(SCREEN_W - 80)
	bar_w := (available_width - gap * f32(boss_count - 1)) / f32(boss_count)
	boss_index := 0
	for e in game.enemies {
		if !e.alive || !e.boss || e.ally do continue
		bar_x := f32(40) + f32(boss_index) * (bar_w + gap)
		pct := clamp(max(f32(e.health), 0) / f32(e.max_health), 0, 1)
		bar_color := rl.RED
		switch e.boss_phase {
		case 1:
			bar_color = rl.Color{255, 40, 190, 255}
		case 2:
			bar_color = rl.Color{40, 220, 255, 255}
		case 3:
			bar_color = rl.YELLOW
		}
		rl.DrawRectangle(i32(bar_x), i32(bar_y), i32(bar_w), i32(bar_h), rl.Color{45, 25, 35, 255})
		rl.DrawRectangle(i32(bar_x), i32(bar_y), i32(bar_w * pct), i32(bar_h), bar_color)
		rl.DrawRectangleLines(i32(bar_x), i32(bar_y), i32(bar_w), i32(bar_h), rl.WHITE)
		label := fmt.ctprintf("CORRUPTED CORE %d", boss_index + 1)
		rl.DrawText(label, i32(bar_x + 10), i32(bar_y + 5), 18, rl.WHITE)
		boss_index += 1
	}
}

draw_wrapped_text :: proc(text: cstring, x, y, max_width, font_size, line_height: i32, color: rl.Color) {
	words, _ := strings.split(string(text), " ")
	line := cstring("")
	line_y := y
	for word in words {
		candidate := fmt.ctprintf("%s", word)
		if len(line) > 0 do candidate = fmt.ctprintf("%s %s", line, word)
		if len(line) > 0 && rl.MeasureText(candidate, font_size) > max_width {
			rl.DrawText(line, x, line_y, font_size, color)
			line = fmt.ctprintf("%s", word)
			line_y += line_height
		} else {
			line = candidate
		}
	}
	if len(line) > 0 do rl.DrawText(line, x, line_y, font_size, color)
}

draw_room_clear :: proc() {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{8, 10, 18, 220})
	title := cstring("SECTOR PURGED")
	title_w := rl.MeasureText(title, 52)
	rl.DrawText(title, SCREEN_W / 2 - title_w / 2, 190, 52, rl.GREEN)
	sub := fmt.ctprintf("Data recovered +%d   |   Total data %d", ROOM_XP, game.xp)
	sub_w := rl.MeasureText(sub, 22)
	rl.DrawText(sub, SCREEN_W / 2 - sub_w / 2, 280, 22, rl.WHITE)
	hint := cstring("Press ENTER to scan the next sector")
	hint_w := rl.MeasureText(hint, 22)
	rl.DrawText(hint, SCREEN_W / 2 - hint_w / 2, 360, 22, rl.LIGHTGRAY)
}

draw_upgrade_screen :: proc() {
	is_enemy_upgrade := game.state == .Enemy_Upgrade
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{5, 16, 21, 245})
	rl.DrawRectangle(0, 0, SCREEN_W, 86, rl.Color{7, 27, 31, 255})
	rl.DrawRectangle(0, 84, SCREEN_W, 2, rl.Color{45, 180, 160, 180})
	title := cstring("ANTIVIRUS UPDATE")
	if is_enemy_upgrade do title = cstring("THREAT LEVEL INCREASED")
	title_w := rl.MeasureText(title, 42)
	title_color := rl.Color{100, 240, 210, 255}
	if is_enemy_upgrade do title_color = rl.Color{255, 100, 180, 255}
	rl.DrawText(title, SCREEN_W / 2 - title_w / 2, 25, 42, title_color)
	subtitle := cstring("Install one security patch")
	if is_enemy_upgrade do subtitle = cstring("The infection has adapted")
	subtitle_w := rl.MeasureText(subtitle, 20)
	rl.DrawText(subtitle, SCREEN_W / 2 - subtitle_w / 2, 72, 20, rl.LIGHTGRAY)

	mouse := rl.GetMousePosition()
	for i in 0..<3 {
		x := i32(170 + i * 320)
		hovered := mouse.x >= f32(x) && mouse.x <= f32(x + 260) && mouse.y >= 240 && mouse.y <= 480
		fill := rl.Color{13, 43, 48, 255}
		accent := rl.Color{70, 220, 190, 255}
		if i == 1 do accent = rl.Color{70, 180, 240, 255}
		if i == 2 do accent = rl.Color{150, 240, 100, 255}
		if is_enemy_upgrade {
			fill = rl.Color{48, 22, 43, 255}
			accent = rl.Color{255, 75, 165, 255}
			if i == 1 do accent = rl.Color{205, 80, 240, 255}
			if i == 2 do accent = rl.Color{255, 170, 65, 255}
		}
		if hovered {
			fill = rl.Color{24, 70, 72, 255}
			if is_enemy_upgrade do fill = rl.Color{78, 30, 62, 255}
		}
		rl.DrawRectangle(x, 240, 260, 240, fill)
		rl.DrawRectangle(x, 240, 260, 7, accent)
		rl.DrawRectangle(x, 240, 260, 42, rl.Color{0, 0, 0, 45})
		rl.DrawRectangleLines(x, 240, 260, 240, accent)
		rl.DrawCircle(x + 22, 261, 7, accent)
		rl.DrawCircleLines(x + 22, 261, 10, rl.Color{220, 255, 245, 180})
	rl.DrawText(is_enemy_upgrade ? cstring("MUTATION") : cstring("PATCH"), x + 38, 253, 14, rl.Color{210, 230, 225, 255})
		card := game.upgrade_cards[i]
		draw_wrapped_text(card.title, x + 18, 300, 224, 25, 27, accent)
		draw_wrapped_text(card.description, x + 18, 350, 224, 18, 23, rl.WHITE)
		rl.DrawLine(x + 18, 430, x + 242, 430, rl.Color{150, 190, 185, 100})
		rl.DrawText(fmt.ctprintf("%s %d", "OPTION", i + 1), x + 18, 445, 16, rl.LIGHTGRAY)
	}
}

draw_game_over :: proc() {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{0, 0, 0, 150})

	score := game.kills * 10 + int(game.elapsed)

	title := cstring("SYSTEM FAILURE")
	title_w := rl.MeasureText(title, 60)
	rl.DrawText(title, SCREEN_W / 2 - title_w / 2, SCREEN_H / 2 - 80, 60, rl.RED)

	sub := fmt.ctprintf("System held for %.1fs  -  Threats %d", game.elapsed, game.kills)
	sub_w := rl.MeasureText(sub, 24)
	rl.DrawText(sub, SCREEN_W / 2 - sub_w / 2, SCREEN_H / 2, 24, rl.WHITE)

	hint := cstring("Press R to play again")
	hint_w := rl.MeasureText(hint, 20)
	rl.DrawText(hint, SCREEN_W / 2 - hint_w / 2, SCREEN_H / 2 + 40, 20, rl.LIGHTGRAY)
}

draw_victory :: proc() {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{8, 10, 18, 235})
	title := cstring("SYSTEM PURGED")
	title_w := rl.MeasureText(title, 56)
	rl.DrawText(title, SCREEN_W / 2 - title_w / 2, SCREEN_H / 2 - 100, 56, rl.YELLOW)
	sub := fmt.ctprintf("Core deleted  -  Score %d", game.kills * 10 + int(game.elapsed))
	sub_w := rl.MeasureText(sub, 24)
	rl.DrawText(sub, SCREEN_W / 2 - sub_w / 2, SCREEN_H / 2 - 10, 24, rl.WHITE)
	hint := cstring("Press R to play again")
	hint_w := rl.MeasureText(hint, 20)
	rl.DrawText(hint, SCREEN_W / 2 - hint_w / 2, SCREEN_H / 2 + 50, 20, rl.LIGHTGRAY)
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

main :: proc() {
	rl.InitWindow(SCREEN_W, SCREEN_H, "Virus Cleanup")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	init_game()
	game.state = .Title
	quit := false

	for !rl.WindowShouldClose() && !quit {
		dt := rl.GetFrameTime()

		if game.state == .Title {
			if rl.IsKeyPressed(.ENTER) do init_game()
			if rl.IsMouseButtonPressed(.LEFT) {
				mouse := rl.GetMousePosition()
				if mouse.x >= 490 && mouse.x <= 790 && mouse.y >= 320 && mouse.y <= 390 do init_game()
				if mouse.x >= 490 && mouse.x <= 790 && mouse.y >= 420 && mouse.y <= 490 do quit = true
			}
		} else if game.state == .Playing {
			update_player(dt)
			update_spawning(dt)
			update_enemies(dt)
			update_bullets(dt)
			handle_collisions()
		} else if game.state == .Player_Upgrade || game.state == .Enemy_Upgrade {
			handle_upgrade_input()
		} else if game.state == .Room_Clear {
			if rl.IsKeyPressed(.ENTER) do start_next_room()
		} else {
			if rl.IsKeyPressed(.R) do init_game()
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{8, 22, 26, 255})

		if game.state == .Title {
			draw_title_screen()
		} else {
			draw_arena()
			draw_bullets()
			draw_enemies()
			draw_player()
			draw_hud()
			if game.state == .Room_Clear do draw_room_clear()
			if game.state == .Player_Upgrade || game.state == .Enemy_Upgrade do draw_upgrade_screen()
			if game.state == .Game_Over do draw_game_over()
			if game.state == .Victory do draw_victory()
		}

		rl.EndDrawing()
	}
}
