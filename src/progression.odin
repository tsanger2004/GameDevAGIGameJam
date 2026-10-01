package main

import rl "vendor:raylib"
import "core:math/rand"

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
	game.charger_dash_speed_multiplier = 1
	game.charger_cooldown_multiplier = 1
	game.ranged_shot_count = 1
	game.ranged_cooldown_multiplier = 1
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
		pool_size = 5
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
	if card.charger_dash_speed > 0 do game.charger_dash_speed_multiplier *= card.charger_dash_speed
	if card.charger_cooldown > 0 do game.charger_cooldown_multiplier *= card.charger_cooldown
	game.ranged_shot_count += card.ranged_shots
	if card.ranged_cooldown > 0 do game.ranged_cooldown_multiplier *= card.ranged_cooldown
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
