package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"
import "core:fmt"

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

SCREEN_W :: 1280
SCREEN_H :: 720

PLAYER_RADIUS        :: 16
PLAYER_INVULN_TIME   :: 0.6
PLAYER_CONTACT_DMG   :: 15

BULLET_RADIUS   :: 5
BULLET_SPEED    :: 640

ENEMY_RADIUS       :: 14
SPAWN_INTERVAL_MAX :: 1.2
SPAWN_INTERVAL_MIN :: 0.25
FINAL_ROOM        :: ROOM_COUNT

KNOCKBACK :: 900
ALLY_ATTACK_COOLDOWN :: f32(0.5)

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

Vec2 :: rl.Vector2

Player :: struct {
	pos:          Vec2,
	health:       f32,
	max_health:   f32,
	speed:        f32,
	fire_cooldown: f32,
	bullet_damage: int,
	bullet_count:  int,
	bullet_spread: f32,
	piercing:      int,
	ricochets:     int,
	necromancer_chance: f32,
	kill_heal:     f32,
	invuln_timer: f32,
	fire_timer:   f32,
}

Enemy :: struct {
	id:     int,
	pos:    Vec2,
	speed:  f32,
	health: int,
	max_health: int,
	radius: f32,
	boss:   bool,
	attack_timer: f32,
	attack_pattern: int,
	split_count: int,
	armor:  int,
	ranged_level: int,
	spawn_timer: f32,
	ally_timer: f32,
	ally:   bool,
	alive:  bool,
}

Bullet :: struct {
	pos:   Vec2,
	vel:   Vec2,
	damage: int,
	hits_left: int,
	hit_enemy_ids: [dynamic]int,
	ricochets_left: int,
	hostile: bool,
	alive: bool,
}

Game_State :: enum { Playing, Room_Clear, Player_Upgrade, Enemy_Upgrade, Game_Over, Victory }

Upgrade_Type :: enum {
	Player_Speed, Rapid_Fire, Heavy_Bullets, Max_Health, Heal, Multi_Shot, Piercing, Vampire, Ricochet, Necromancer,
	Enemy_Haste, Enemy_Armor, Enemy_Swarm, Enemy_Frenzy, Enemy_Elite, Enemy_Splitter, Enemy_Bloodlust, Enemy_Thorns, Enemy_Ranged, Enemy_Shields,
}

Upgrade_Card :: struct {
	title:       cstring,
	description: cstring,
	kind:        Upgrade_Type,
	player_speed: f32,
	fire_rate: f32,
	damage: int,
	max_health: f32,
	heal: f32,
	bullet_count: int,
	spread: f32,
	piercing: int,
	ricochets: int,
	necromancer_chance: f32,
	kill_heal: f32,
	enemy_speed: f32,
	enemy_health: int,
	spawn_rate: f32,
	contact_damage: int,
	splitter: bool,
	knockback: f32,
	ranged: bool,
	armor: int,
}

Game :: struct {
	state:       Game_State,
	player:      Player,
	enemies:     [dynamic]Enemy,
	bullets:     [dynamic]Bullet,
	spawn_timer: f32,
	elapsed:     f32,
	kills:       int,
	level:       int,
	xp:          int,
	next_xp:     int,
	room:        int,
	room_spawned: int,
	room_enemy_target: int,
	enemy_speed_bonus: f32,
	enemy_health_bonus: int,
	spawn_rate_multiplier: f32,
	enemy_contact_damage: int,
	enemy_splitter: int,
	enemy_knockback: f32,
	enemy_ranged: bool,
	enemy_ranged_level: int,
	enemy_armor: int,
	next_enemy_id: int,
	final_reinforcement_timer: f32,
	upgrade_cards: [3]Upgrade_Card,
}

game: Game

// ---------------------------------------------------------------------------
// Small vector helpers (rl.Vector2 is a plain struct, so no operator overloads)
// ---------------------------------------------------------------------------

vec2_add :: proc(a, b: Vec2) -> Vec2 { return Vec2{a.x + b.x, a.y + b.y} }
vec2_sub :: proc(a, b: Vec2) -> Vec2 { return Vec2{a.x - b.x, a.y - b.y} }
vec2_scale :: proc(a: Vec2, s: f32) -> Vec2 { return Vec2{a.x * s, a.y * s} }
vec2_rotate :: proc(a: Vec2, angle: f32) -> Vec2 {
	return Vec2{a.x * math.cos(angle) - a.y * math.sin(angle), a.x * math.sin(angle) + a.y * math.cos(angle)}
}

vec2_len :: proc(a: Vec2) -> f32 {
	return math.sqrt(a.x * a.x + a.y * a.y)
}

vec2_normalize :: proc(a: Vec2) -> Vec2 {
	l := vec2_len(a)
	if l < 0.0001 do return Vec2{0, 0}
	return Vec2{a.x / l, a.y / l}
}

vec2_dist :: proc(a, b: Vec2) -> f32 {
	return vec2_len(vec2_sub(a, b))
}

rand_range :: proc(lo, hi: f32) -> f32 {
	return lo + rand.float32() * (hi - lo)
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

init_game :: proc() {
	clear(&game.enemies)
	clear(&game.bullets)
	game.player = Player{
		pos            = Vec2{SCREEN_W / 2, SCREEN_H / 2},
		health         = PLAYER_START_HEALTH,
		max_health     = PLAYER_START_HEALTH,
		speed          = PLAYER_START_SPEED,
		fire_cooldown  = PLAYER_START_FIRE_COOLDOWN,
		bullet_damage  = PLAYER_START_DAMAGE,
			bullet_count   = 1,
			bullet_spread  = 0,
	}
	game.spawn_timer = SPAWN_INTERVAL_MAX
	game.elapsed = 0
	game.kills = 0
	game.level = 1
	game.xp = 0
	game.next_xp = 2
	game.room = 1
	game.enemy_speed_bonus = 0
	game.enemy_health_bonus = 0
	game.spawn_rate_multiplier = 1
	game.enemy_contact_damage = ENEMY_CONTACT_DAMAGE
	game.enemy_splitter = 0
	game.enemy_knockback = 1
	game.enemy_ranged = false
	game.enemy_ranged_level = 0
	game.enemy_armor = 0
	game.next_enemy_id = 1
	game.final_reinforcement_timer = FINAL_REINFORCEMENT_INTERVAL
	start_room()
	game.state = .Playing
}

start_room :: proc() {
	clear(&game.enemies)
	clear(&game.bullets)
	game.room_spawned = 0
	game.room_enemy_target = ROOM_FIRST_ENEMY_COUNT + game.room * ROOM_ENEMIES_PER_ROOM
	if game.room == FINAL_ROOM do game.room_enemy_target = 1
	game.spawn_timer = 0.5
	game.final_reinforcement_timer = FINAL_REINFORCEMENT_INTERVAL
	game.elapsed = 0
	game.player.pos = Vec2{SCREEN_W / 2, SCREEN_H / 2}
}

start_next_room :: proc() {
	game.room += 1
	start_room()
	game.state = .Playing
}

make_upgrade_cards :: proc(enemy: bool) {
	player_pool := PLAYER_UPGRADE_POOL
	enemy_pool := ENEMY_UPGRADE_POOL
	pool: [8]Upgrade_Card
	pool_size := 6
	for i in 0..<pool_size {
		pool[i] = player_pool[i]
	}
	if enemy {
		pool_size = 6
		for i in 0..<pool_size {
			pool[i] = enemy_pool[i]
		}
	}
	used: [8]bool
	for i in 0..<3 {
		index := int(rand.float32() * f32(pool_size))
		for used[index] do index = (index + 1) % pool_size
		used[index] = true
		game.upgrade_cards[i] = pool[index]
	}
}

begin_level_up :: proc() {
	game.level += 1
	make_upgrade_cards(false)
	game.state = .Player_Upgrade
}

apply_upgrade :: proc(card: Upgrade_Card) {
	if card.player_speed > 0 do game.player.speed *= card.player_speed
	if card.fire_rate > 0 do game.player.fire_cooldown *= card.fire_rate
	game.player.bullet_damage += card.damage
	game.player.max_health += card.max_health
	game.player.health += card.max_health
	game.player.health = min(game.player.max_health, game.player.health + card.heal)
	if card.bullet_count > 0 {
		if game.player.bullet_count == 1 {
			game.player.bullet_count = card.bullet_count
		} else {
			game.player.bullet_count += card.bullet_count
		}
	}
	game.player.bullet_spread = max(game.player.bullet_spread, card.spread)
	game.player.piercing += card.piercing
	game.player.ricochets += card.ricochets
	game.player.necromancer_chance = min(1, game.player.necromancer_chance + card.necromancer_chance)
	game.player.kill_heal += card.kill_heal
	game.enemy_speed_bonus += card.enemy_speed
	game.enemy_health_bonus += card.enemy_health
	if card.spawn_rate > 0 do game.spawn_rate_multiplier *= card.spawn_rate
	game.enemy_contact_damage += card.contact_damage
	if card.splitter do game.enemy_splitter += 1
	game.enemy_knockback += card.knockback
	if card.ranged {
		game.enemy_ranged = true
		game.enemy_ranged_level += 1
	}
	game.enemy_armor += card.armor
}

handle_upgrade_input :: proc() {
	if !rl.IsMouseButtonPressed(.LEFT) do return
	mouse := rl.GetMousePosition()
	for i in 0..<3 {
		x := f32(170 + i * 320)
		if mouse.x >= x && mouse.x <= x + 260 && mouse.y >= 240 && mouse.y <= 480 {
			apply_upgrade(game.upgrade_cards[i])
			if game.state == .Player_Upgrade {
				make_upgrade_cards(true)
				game.state = .Enemy_Upgrade
			} else {
				start_next_room()
			}
			return
		}
	}
}

spawn_enemy :: proc() {
	side := int(rand.float32() * 4)
	pos: Vec2
	switch side {
	case 0: pos = Vec2{rand_range(0, SCREEN_W), -ENEMY_RADIUS}            // top
	case 1: pos = Vec2{SCREEN_W + ENEMY_RADIUS, rand_range(0, SCREEN_H)}  // right
	case 2: pos = Vec2{rand_range(0, SCREEN_W), SCREEN_H + ENEMY_RADIUS}  // bottom
	case:   pos = Vec2{-ENEMY_RADIUS, rand_range(0, SCREEN_H)}            // left
	}

	boss := game.room == FINAL_ROOM
	enemy_id := game.next_enemy_id
	game.next_enemy_id += 1
	speed := min(ENEMY_BASE_SPEED + f32(game.room) * 10, ENEMY_MAX_SPEED) * (1 + game.enemy_speed_bonus)
	health := ENEMY_ROOM_HEALTH + game.room * ENEMY_HEALTH_PER_ROOM + game.enemy_health_bonus
	radius := f32(ENEMY_RADIUS)
	if boss {
		speed = ENEMY_BOSS_SPEED * (1 + game.enemy_speed_bonus)
		health = ENEMY_BOSS_HEALTH + game.enemy_health_bonus * 2
		radius = 34
	}

	append(&game.enemies, Enemy{
		id = enemy_id,
		pos = pos,
		speed = speed,
		health = health,
		max_health = health,
		radius = radius,
		boss = boss,
		attack_timer = ENEMY_BOSS_AIMED_COOLDOWN,
		attack_pattern = 0,
		split_count = game.enemy_splitter,
		armor = game.enemy_armor,
		ranged_level = game.enemy_ranged_level * int(!boss),
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
		pos = pos,
		speed = ENEMY_BASE_SPEED,
		health = 1,
		max_health = 1,
		radius = ENEMY_RADIUS,
		boss = false,
		attack_timer = ENEMY_MINION_SHOT_COOLDOWN,
		attack_pattern = 0,
		split_count = 0,
		armor = 0,
		ranged_level = 0,
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

fire_boss_pattern :: proc(e: ^Enemy, player_pos: Vec2) {
	aim := vec2_normalize(vec2_sub(player_pos, e.pos))
	if e.attack_pattern == 0 {
		for shot in 0..<3 {
			angle := (f32(shot) - 1) * 0.24
			append(&game.bullets, Bullet{
				pos = e.pos,
				vel = vec2_scale(vec2_rotate(aim, angle), ENEMY_BOSS_SHOT_SPEED),
				damage = ENEMY_BOSS_SHOT_DAMAGE,
				hits_left = 1,
				hostile = true,
				alive = true,
			})
		}
		e.attack_timer = ENEMY_BOSS_AIMED_COOLDOWN
		e.attack_pattern = 1
	} else {
		for shot in 0..<8 {
			angle := f32(shot) * math.PI * 2 / 8
			append(&game.bullets, Bullet{
				pos = e.pos,
				vel = vec2_scale(Vec2{math.cos(angle), math.sin(angle)}, ENEMY_BOSS_SHOT_SPEED * 0.85),
				damage = ENEMY_BOSS_SHOT_DAMAGE,
				hits_left = 1,
				hostile = true,
				alive = true,
			})
		}
		e.attack_timer = ENEMY_BOSS_RADIAL_COOLDOWN
		e.attack_pattern = 0
	}
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

		dir := vec2_normalize(vec2_sub(p.pos, e.pos))
		e.pos = vec2_add(e.pos, vec2_scale(dir, e.speed * dt))
		if e.boss {
			e.attack_timer -= dt
			if e.attack_timer <= 0 do fire_boss_pattern(e, p.pos)
		} else if e.ranged_level > 0 {
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
				game.state = .Game_Over
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
				game.state = .Game_Over
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
						if split_count > 0 && !was_boss {
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
									pos = Vec2{death_pos.x + offset, death_pos.y},
									speed = death_speed * 1.2,
									health = child_health,
									max_health = child_health,
									radius = child_radius,
									boss = was_boss,
									attack_timer = ENEMY_BOSS_AIMED_COOLDOWN,
									attack_pattern = 0,
									split_count = 0,
									armor = game.enemy_armor,
									ranged_level = game.enemy_ranged_level * int(!was_boss),
									spawn_timer = 0,
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

draw_arena :: proc() {
	rl.DrawRectangleLines(4, 4, SCREEN_W - 8, SCREEN_H - 8, rl.Color{60, 60, 75, 255})
}

draw_player :: proc() {
	p := game.player
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
			rl.DrawLineV(beam_top, e.pos, rl.Color{255, 240, 150, 90})
			rl.DrawCircleV(e.pos, e.radius * (0.5 + progress * 0.5), rl.Color{255, 100, 100, 220})
			rl.DrawCircleLinesV(e.pos, e.radius + 5 + progress * 8, rl.Color{255, 245, 170, 180})
			continue
		}
		if e.ally {
			rl.DrawCircleV(e.pos, e.radius, rl.LIME)
			rl.DrawCircleLinesV(e.pos, e.radius + 3, rl.SKYBLUE)
			continue
		}
		col := rl.RED
		if e.boss {
			col = rl.PURPLE
			rl.DrawCircleV(e.pos, e.radius, col)
			rl.DrawCircleLinesV(e.pos, e.radius + 4, rl.YELLOW)
			bar_w := f32(150)
			bar_x := e.pos.x - bar_w / 2
			bar_y := e.pos.y - e.radius - 18
			pct := max(f32(e.health), 0) / f32(e.max_health)
			rl.DrawRectangle(i32(bar_x), i32(bar_y), i32(bar_w), 10, rl.Color{45, 25, 35, 255})
			rl.DrawRectangle(i32(bar_x), i32(bar_y), i32(bar_w * pct), 10, rl.RED)
			rl.DrawRectangleLines(i32(bar_x), i32(bar_y), i32(bar_w), 10, rl.WHITE)
		} else {
			if e.health >= 2 do col = rl.ORANGE
			if e.health >= 4 do col = rl.GREEN
			rl.DrawCircleV(e.pos, e.radius, col)
			if e.ranged_level > 0 do rl.DrawCircleLinesV(e.pos, e.radius + 2, rl.SKYBLUE)
			if e.armor > 0 do rl.DrawCircleLinesV(e.pos, e.radius + 4, rl.LIGHTGRAY)
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
	rl.DrawText(fmt.ctprintf("HP %d/%d", int(game.player.health), int(game.player.max_health)), 26, 24, 16, rl.WHITE)

	score := game.kills * 10 + int(game.elapsed)
	rl.DrawText(fmt.ctprintf("Score: %d", score), SCREEN_W - 180, 20, 22, rl.WHITE)
	rl.DrawText(fmt.ctprintf("Time: %.1fs", game.elapsed), SCREEN_W - 180, 48, 18, rl.LIGHTGRAY)
	rl.DrawText(fmt.ctprintf("Kills: %d", game.kills), SCREEN_W - 180, 70, 18, rl.LIGHTGRAY)
	rl.DrawText(fmt.ctprintf("Level %d  Room XP %d", game.level, game.xp), 20, 52, 18, rl.LIGHTGRAY)
	room_label := fmt.ctprintf("Room %d/%d", game.room, FINAL_ROOM)
	if game.room == FINAL_ROOM do room_label = cstring("FINAL ROOM - BOSS")
	rl.DrawText(room_label, SCREEN_W / 2 - rl.MeasureText(room_label, 20) / 2, 20, 20, rl.YELLOW)
}

draw_room_clear :: proc() {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{8, 10, 18, 220})
	title := cstring("ROOM CLEARED")
	title_w := rl.MeasureText(title, 52)
	rl.DrawText(title, SCREEN_W / 2 - title_w / 2, 190, 52, rl.GREEN)
	sub := fmt.ctprintf("Room XP +%d   |   Total room XP %d", ROOM_XP, game.xp)
	sub_w := rl.MeasureText(sub, 22)
	rl.DrawText(sub, SCREEN_W / 2 - sub_w / 2, 280, 22, rl.WHITE)
	hint := cstring("Press ENTER to enter the next room")
	hint_w := rl.MeasureText(hint, 22)
	rl.DrawText(hint, SCREEN_W / 2 - hint_w / 2, 360, 22, rl.LIGHTGRAY)
}

draw_upgrade_screen :: proc() {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{8, 10, 18, 220})
	title := cstring("LEVEL UP")
	if game.state == .Enemy_Upgrade do title = cstring("THE ENEMIES GROW")
	title_w := rl.MeasureText(title, 42)
	rl.DrawText(title, SCREEN_W / 2 - title_w / 2, 120, 42, rl.WHITE)
	subtitle := cstring("Choose one upgrade")
	if game.state == .Enemy_Upgrade do subtitle = cstring("Choose the enemy upgrade you can handle")
	subtitle_w := rl.MeasureText(subtitle, 20)
	rl.DrawText(subtitle, SCREEN_W / 2 - subtitle_w / 2, 175, 20, rl.LIGHTGRAY)

	mouse := rl.GetMousePosition()
	for i in 0..<3 {
		x := i32(170 + i * 320)
		hovered := mouse.x >= f32(x) && mouse.x <= f32(x + 260) && mouse.y >= 240 && mouse.y <= 480
		fill := rl.Color{35, 42, 62, 255}
		if game.state == .Enemy_Upgrade do fill = rl.Color{58, 38, 42, 255}
		if hovered do fill = rl.Color{65, 78, 108, 255}
		rl.DrawRectangle(x, 240, 260, 240, fill)
		rl.DrawRectangleLines(x, 240, 260, 240, rl.Color{130, 150, 190, 255})
		card := game.upgrade_cards[i]
		card_w := rl.MeasureText(card.title, 25)
		rl.DrawText(card.title, x + 130 - card_w / 2, 285, 25, rl.YELLOW)
		rl.DrawText(card.description, x + 18, 350, 18, rl.WHITE)
		rl.DrawText(fmt.ctprintf("CARD %d", i + 1), x + 18, 445, 16, rl.LIGHTGRAY)
	}
}

draw_game_over :: proc() {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{0, 0, 0, 150})

	score := game.kills * 10 + int(game.elapsed)

	title := cstring("GAME OVER")
	title_w := rl.MeasureText(title, 60)
	rl.DrawText(title, SCREEN_W / 2 - title_w / 2, SCREEN_H / 2 - 80, 60, rl.RED)

	sub := fmt.ctprintf("Survived %.1fs  -  Score %d", game.elapsed, score)
	sub_w := rl.MeasureText(sub, 24)
	rl.DrawText(sub, SCREEN_W / 2 - sub_w / 2, SCREEN_H / 2, 24, rl.WHITE)

	hint := cstring("Press R to play again")
	hint_w := rl.MeasureText(hint, 20)
	rl.DrawText(hint, SCREEN_W / 2 - hint_w / 2, SCREEN_H / 2 + 40, 20, rl.LIGHTGRAY)
}

draw_victory :: proc() {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{8, 10, 18, 235})
	title := cstring("DUNGEON CLEARED")
	title_w := rl.MeasureText(title, 56)
	rl.DrawText(title, SCREEN_W / 2 - title_w / 2, SCREEN_H / 2 - 100, 56, rl.YELLOW)
	sub := fmt.ctprintf("Boss defeated  -  Score %d", game.kills * 10 + int(game.elapsed))
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
	rl.InitWindow(SCREEN_W, SCREEN_H, "ARENA")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	init_game()

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		if game.state == .Playing {
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
		rl.ClearBackground(rl.Color{18, 18, 24, 255})

		draw_arena()
		draw_bullets()
		draw_enemies()
		draw_player()
		draw_hud()
		if game.state == .Room_Clear do draw_room_clear()
		if game.state == .Player_Upgrade || game.state == .Enemy_Upgrade do draw_upgrade_screen()
		if game.state == .Game_Over do draw_game_over()
		if game.state == .Victory do draw_victory()

		rl.EndDrawing()
	}
}
