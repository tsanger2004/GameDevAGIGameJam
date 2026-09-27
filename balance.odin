package main

// Tune gameplay here. The game logic in main.odin should not need editing for balance changes.

PLAYER_START_HEALTH :: f32(100)
PLAYER_START_SPEED :: f32(260)
PLAYER_START_DAMAGE :: 1
PLAYER_START_FIRE_COOLDOWN :: f32(0.14)

ENEMY_BASE_SPEED :: f32(125)
ENEMY_MAX_SPEED :: f32(260)
ENEMY_CONTACT_DAMAGE :: 22
ENEMY_ROOM_HEALTH :: 2
ENEMY_HEALTH_PER_ROOM :: 1
ENEMY_BOSS_HEALTH :: 70
ENEMY_BOSS_SPEED :: f32(70)

ROOM_COUNT :: 5
ROOM_FIRST_ENEMY_COUNT :: 6
ROOM_ENEMIES_PER_ROOM :: 3
ROOM_XP :: 1

PLAYER_UPGRADE_POOL :: [8]Upgrade_Card{
	{title = "SWIFT", description = "+20% movement speed", kind = .Player_Speed, player_speed = 1.2},
	{title = "RAPID FIRE", description = "Shoot 25% faster", kind = .Rapid_Fire, fire_rate = 0.75},
	{title = "HEAVY ROUNDS", description = "Bullets deal +1 damage", kind = .Heavy_Bullets, damage = 1},
	{title = "FORTIFY", description = "+25 maximum health", kind = .Max_Health, max_health = 25},
	{title = "SECOND WIND", description = "Restore 35 health", kind = .Heal, heal = 35},
	{title = "TRIPLE SHOT", description = "Fire 3 bullets in a spread", kind = .Multi_Shot, bullet_count = 3, spread = 0.16},
	{title = "PIERCING", description = "Bullets pass through 1 enemy", kind = .Piercing, piercing = 1},
	{title = "VAMPIRE", description = "Kills restore 5 health", kind = .Vampire, kill_heal = 5},
}

ENEMY_UPGRADE_POOL :: [8]Upgrade_Card{
	{title = "HASTE", description = "Enemies move 15% faster", kind = .Enemy_Haste, enemy_speed = 0.15},
	{title = "ARMOR", description = "Enemies gain +1 health", kind = .Enemy_Armor, enemy_health = 1},
	{title = "SWARM", description = "Enemies spawn 20% faster", kind = .Enemy_Swarm, spawn_rate = 0.8},
	{title = "FRENZY", description = "Enemies move 30% faster", kind = .Enemy_Frenzy, enemy_speed = 0.3},
	{title = "ELITES", description = "New enemies gain +2 health", kind = .Enemy_Elite, enemy_health = 2},
	{title = "SPLITTERS", description = "Normal enemies split on death", kind = .Enemy_Splitter, splitter = true},
	{title = "BLOODLUST", description = "Enemy contact damage +5", kind = .Enemy_Bloodlust, contact_damage = 5},
	{title = "THORNS", description = "Collisions knock you back harder", kind = .Enemy_Thorns, knockback = 0.5},
}
