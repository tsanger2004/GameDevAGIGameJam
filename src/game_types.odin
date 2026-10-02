package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

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
	dash_cooldown: f32,
	dash_timer:   f32,
	dash_shockwave_level: int,
	shockwave_pos: Vec2,
	shockwave_radius: f32,
	shockwave_timer: f32,
	shockwave_applied: bool,
}

Enemy :: struct {
	id:     int,
	type:   Enemy_Type,
	pos:    Vec2,
	speed:  f32,
	health: int,
	max_health: int,
	radius: f32,
	boss:   bool,
	attack_timer: f32,
	attack_pattern: int,
	boss_phase: int,
	boss_phase_timer: f32,
	boss_charges_remaining: int,
	state_timer: f32,
	dash_dir: Vec2,
	split_count: int,
	armor:  int,
	ranged_level: int,
	charger_dash_speed: f32,
	charger_cooldown: f32,
	ranged_shots: int,
	ranged_cooldown: f32,
	spawn_timer: f32,
	ally_timer: f32,
	ally:   bool,
	alive:  bool,
}

Enemy_Type :: enum {
	Normal,
	Charger,
	Ranged,
	Boss,
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

Game_State :: enum { Title, Playing, Room_Clear, Player_Upgrade, Enemy_Upgrade, Game_Over, Victory }

Upgrade_Type :: enum {
	Player_Speed, Rapid_Fire, Heavy_Bullets, Max_Health, Heal, Multi_Shot, Piercing, Vampire, Ricochet, Necromancer,
	Dash_Shockwave,
	Enemy_Haste, Enemy_Armor, Enemy_Swarm, Enemy_Frenzy, Enemy_Elite, Enemy_Splitter, Enemy_Bloodlust, Enemy_Thorns, Enemy_Ranged, Enemy_Shields, Enemy_Charger, Enemy_Ranged_Volley,
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
	shockwave: int,
	enemy_speed: f32,
	enemy_health: int,
	spawn_rate: f32,
	contact_damage: int,
	splitter: bool,
	knockback: f32,
	ranged: bool,
	armor: int,
	charger_dash_speed: f32,
	charger_cooldown: f32,
	ranged_shots: int,
	ranged_cooldown: f32,
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
	special_enemy_first: Enemy_Type,
	enemy_armor: int,
	charger_dash_speed_multiplier: f32,
	charger_cooldown_multiplier: f32,
	ranged_shot_count: int,
	ranged_cooldown_multiplier: f32,
	next_enemy_id: int,
	final_reinforcement_timer: f32,
	upgrade_cards: [3]Upgrade_Card,
}

game: Game

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
