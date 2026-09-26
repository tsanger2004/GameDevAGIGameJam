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
PLAYER_SPEED         :: 260
PLAYER_MAX_HEALTH    :: 100
PLAYER_INVULN_TIME   :: 0.6
PLAYER_CONTACT_DMG   :: 15

BULLET_RADIUS   :: 5
BULLET_SPEED    :: 640
FIRE_COOLDOWN   :: 0.14

ENEMY_RADIUS       :: 14
ENEMY_BASE_SPEED   :: 90
ENEMY_MAX_SPEED    :: 190
SPAWN_INTERVAL_MAX :: 1.2
SPAWN_INTERVAL_MIN :: 0.25

KNOCKBACK :: 900

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

Vec2 :: rl.Vector2

Player :: struct {
	pos:          Vec2,
	health:       f32,
	invuln_timer: f32,
	fire_timer:   f32,
}

Enemy :: struct {
	pos:    Vec2,
	speed:  f32,
	health: int,
	alive:  bool,
}

Bullet :: struct {
	pos:   Vec2,
	vel:   Vec2,
	alive: bool,
}

Game_State :: enum { Playing, Game_Over }

Game :: struct {
	state:       Game_State,
	player:      Player,
	enemies:     [dynamic]Enemy,
	bullets:     [dynamic]Bullet,
	spawn_timer: f32,
	elapsed:     f32,
	kills:       int,
}

game: Game

// ---------------------------------------------------------------------------
// Small vector helpers (rl.Vector2 is a plain struct, so no operator overloads)
// ---------------------------------------------------------------------------

vec2_add :: proc(a, b: Vec2) -> Vec2 { return Vec2{a.x + b.x, a.y + b.y} }
vec2_sub :: proc(a, b: Vec2) -> Vec2 { return Vec2{a.x - b.x, a.y - b.y} }
vec2_scale :: proc(a: Vec2, s: f32) -> Vec2 { return Vec2{a.x * s, a.y * s} }

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
		pos    = Vec2{SCREEN_W / 2, SCREEN_H / 2},
		health = PLAYER_MAX_HEALTH,
	}
	game.spawn_timer = SPAWN_INTERVAL_MAX
	game.elapsed = 0
	game.kills = 0
	game.state = .Playing
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

	speed := min(ENEMY_BASE_SPEED + game.elapsed * 1.4, f32(ENEMY_MAX_SPEED))
	health := 1 + int(game.elapsed / 25) // tougher enemies show up over time

	append(&game.enemies, Enemy{pos = pos, speed = speed, health = health, alive = true})
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
		p.pos = vec2_add(p.pos, vec2_scale(dir, PLAYER_SPEED * dt))
	}

	p.pos.x = clamp(p.pos.x, PLAYER_RADIUS, SCREEN_W - PLAYER_RADIUS)
	p.pos.y = clamp(p.pos.y, PLAYER_RADIUS, SCREEN_H - PLAYER_RADIUS)

	if p.invuln_timer > 0 do p.invuln_timer -= dt
	if p.fire_timer > 0   do p.fire_timer -= dt

	if rl.IsMouseButtonDown(.LEFT) && p.fire_timer <= 0 {
		mouse := rl.GetMousePosition()
		aim := vec2_normalize(vec2_sub(mouse, p.pos))
		if aim.x != 0 || aim.y != 0 {
			append(&game.bullets, Bullet{
				pos   = p.pos,
				vel   = vec2_scale(aim, BULLET_SPEED),
				alive = true,
			})
			p.fire_timer = FIRE_COOLDOWN
		}
	}
}

update_spawning :: proc(dt: f32) {
	game.elapsed += dt
	game.spawn_timer -= dt
	if game.spawn_timer <= 0 {
		spawn_enemy()
		game.spawn_timer = max(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX - game.elapsed * 0.01)
	}
}

update_enemies :: proc(dt: f32) {
	p := &game.player
	for i in 0 ..< len(game.enemies) {
		e := &game.enemies[i]
		if !e.alive do continue

		dir := vec2_normalize(vec2_sub(p.pos, e.pos))
		e.pos = vec2_add(e.pos, vec2_scale(dir, e.speed * dt))

		if p.invuln_timer <= 0 && vec2_dist(e.pos, p.pos) < ENEMY_RADIUS + PLAYER_RADIUS {
			p.health -= PLAYER_CONTACT_DMG
			p.invuln_timer = PLAYER_INVULN_TIME

			push := vec2_normalize(vec2_sub(p.pos, e.pos))
			p.pos = vec2_add(p.pos, vec2_scale(push, KNOCKBACK * dt))
			e.pos = vec2_sub(e.pos, vec2_scale(push, KNOCKBACK * dt * 0.5))

			if p.health <= 0 {
				p.health = 0
				game.state = .Game_Over
			}
		}
	}
}

update_bullets :: proc(dt: f32) {
	for i in 0 ..< len(game.bullets) {
		b := &game.bullets[i]
		b.pos = vec2_add(b.pos, vec2_scale(b.vel, dt))
		if b.pos.x < -20 || b.pos.x > SCREEN_W + 20 || b.pos.y < -20 || b.pos.y > SCREEN_H + 20 {
			b.alive = false
		}
	}
}

handle_collisions :: proc() {
	for bi in 0 ..< len(game.bullets) {
		b := &game.bullets[bi]
		if !b.alive do continue
		for ei in 0 ..< len(game.enemies) {
			e := &game.enemies[ei]
			if !e.alive do continue
			if vec2_dist(b.pos, e.pos) < BULLET_RADIUS + ENEMY_RADIUS {
				b.alive = false
				e.health -= 1
				if e.health <= 0 {
					e.alive = false
					game.kills += 1
				}
				break
			}
		}
	}

	for i := len(game.bullets) - 1; i >= 0; i -= 1 {
		if !game.bullets[i].alive do unordered_remove(&game.bullets, i)
	}
	for i := len(game.enemies) - 1; i >= 0; i -= 1 {
		if !game.enemies[i].alive do unordered_remove(&game.enemies, i)
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
		col := rl.RED
		if e.health >= 2 do col = rl.ORANGE
		if e.health >= 4 do col = rl.GREEN
		rl.DrawCircleV(e.pos, ENEMY_RADIUS, col)
	}
}

draw_bullets :: proc() {
	for b in game.bullets {
		rl.DrawCircleV(b.pos, BULLET_RADIUS, rl.YELLOW)
	}
}

draw_hud :: proc() {
	// health bar
	bar_w := f32(240)
	pct := max(game.player.health, 0) / PLAYER_MAX_HEALTH
	rl.DrawRectangle(20, 20, i32(bar_w), 22, rl.Color{50, 50, 50, 255})
	rl.DrawRectangle(20, 20, i32(bar_w * pct), 22, rl.GREEN)
	rl.DrawRectangleLines(20, 20, i32(bar_w), 22, rl.WHITE)
	rl.DrawText(fmt.ctprintf("HP %d/%d", int(game.player.health), PLAYER_MAX_HEALTH), 26, 24, 16, rl.WHITE)

	score := game.kills * 10 + int(game.elapsed)
	rl.DrawText(fmt.ctprintf("Score: %d", score), SCREEN_W - 180, 20, 22, rl.WHITE)
	rl.DrawText(fmt.ctprintf("Time: %.1fs", game.elapsed), SCREEN_W - 180, 48, 18, rl.LIGHTGRAY)
	rl.DrawText(fmt.ctprintf("Kills: %d", game.kills), SCREEN_W - 180, 70, 18, rl.LIGHTGRAY)
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
		if game.state == .Game_Over do draw_game_over()

		rl.EndDrawing()
	}
}
