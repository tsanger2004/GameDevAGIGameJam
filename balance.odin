package main

// Tune gameplay here. The game logic in main.odin should not need editing for balance changes.

PLAYER_START_HEALTH :: f32(100)
PLAYER_START_SPEED :: f32(260)
PLAYER_START_DAMAGE :: 1
PLAYER_START_FIRE_COOLDOWN :: f32(0.5)

ENEMY_BASE_SPEED :: f32(125)
ENEMY_MAX_SPEED :: f32(260)
ENEMY_CONTACT_DAMAGE :: 22
ENEMY_ROOM_HEALTH :: 2
ENEMY_HEALTH_PER_ROOM :: 1
ENEMY_BOSS_HEALTH :: 140
ENEMY_BOSS_SPEED :: f32(70)
ENEMY_BOSS_SHOT_SPEED :: f32(230)
ENEMY_BOSS_SHOT_DAMAGE :: 12
ENEMY_BOSS_AIMED_COOLDOWN :: f32(2.2)
ENEMY_BOSS_RADIAL_COOLDOWN :: f32(3.6)
ENEMY_MINION_SHOT_SPEED :: f32(180)
ENEMY_MINION_SHOT_DAMAGE :: 8
ENEMY_MINION_SHOT_COOLDOWN :: f32(2.8)
ENEMY_CHARGER_TELEGRAPH :: f32(0.9)
ENEMY_CHARGER_DASH_TIME :: f32(0.45)
ENEMY_CHARGER_DASH_SPEED :: f32(620)
ENEMY_CHARGER_COOLDOWN :: f32(1.0)
ENEMY_CHARGER_APPROACH_SPEED :: f32(55)
ENEMY_CHARGER_MIN_DASH_RANGE :: f32(120)
ENEMY_CHARGER_MAX_DASH_RANGE :: f32(240)
ENEMY_CHARGER_OVERSHOOT :: f32(60)
ENEMY_RANGED_DISTANCE :: f32(280)
ENEMY_RANGED_SPEED :: f32(95)
ENEMY_RANGED_SHOT_COOLDOWN :: f32(1.2)
ENEMY_RANGED_SHOT_SPEED :: f32(240)
ENEMY_RANGED_SHOT_DAMAGE :: 7
FINAL_REINFORCEMENT_INTERVAL :: f32(4.5)
ENEMY_DROP_TIME :: f32(0.9)
NECROMANCER_ALLY_LIFESPAN :: f32(30)

ROOM_COUNT :: 5
ROOM_FIRST_ENEMY_COUNT :: 6
ROOM_ENEMIES_PER_ROOM :: 3
ROOM_XP :: 1

PLAYER_UPGRADE_POOL :: [6]Upgrade_Card{
	{title = "SECOND WIND", description = "Restore 35 health", kind = .Heal, heal = 35},
	{title = "TRIPLE SHOT", description = "Fire 3 bullets in a spread", kind = .Multi_Shot, bullet_count = 3, spread = 0.16},
	{title = "PIERCING", description = "Bullets pass through 1 enemy", kind = .Piercing, piercing = 1},
	{title = "VAMPIRE", description = "Kills restore 5 health", kind = .Vampire, kill_heal = 5},
	{title = "RICOCHET ROUNDS", description = "Bullets re-aim at 1 enemy after a hit", kind = .Ricochet, ricochets = 1},
	{title = "NECROMANCER", description = "35% chance to convert a defeated enemy", kind = .Necromancer, necromancer_chance = 0.35},
}

ENEMY_UPGRADE_POOL :: [6]Upgrade_Card{
	{title = "SWARM", description = "Enemies spawn 20% faster", kind = .Enemy_Swarm, spawn_rate = 0.8},
	{title = "SPLITTERS", description = "Normal enemies split on death", kind = .Enemy_Splitter, splitter = true},
	{title = "BLOODLUST", description = "Enemy contact damage +5", kind = .Enemy_Bloodlust, contact_damage = 5},
	{title = "THORNS", description = "Collisions knock you back harder", kind = .Enemy_Thorns, knockback = 5.0},
	{title = "RANGED MINIONS", description = "Normal enemies fire at you", kind = .Enemy_Ranged, ranged = true},
	{title = "SHIELDS", description = "Enemies reduce bullet damage by 1", kind = .Enemy_Shields, armor = 1},
}
