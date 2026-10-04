package main

// Tune gameplay here. The game logic in main.odin should not need editing for balance changes.

PLAYER_START_HEALTH :: f32(100)
PLAYER_START_SPEED :: f32(260)
PLAYER_START_DAMAGE :: 1
PLAYER_REGEN_PER_SECOND :: f32(1)
PLAYER_START_FIRE_COOLDOWN :: f32(0.5)
DEBUG_PLAYER_DAMAGE :: 10
PLAYER_DASH_DISTANCE :: f32(150)
PLAYER_DASH_COOLDOWN :: f32(1.5)
PLAYER_DASH_SHOCKWAVE_RADIUS :: f32(105)
PLAYER_DASH_SHOCKWAVE_DURATION :: f32(0.35)
PLAYER_DASH_SHOCKWAVE_DAMAGE :: 2

ENEMY_BASE_SPEED :: f32(125)
ENEMY_MAX_SPEED :: f32(260)
ENEMY_CONTACT_DAMAGE :: 22
ENEMY_ROOM_HEALTH :: 2
ENEMY_HEALTH_PER_ROOM :: 1
ENEMY_BOSS_HEALTH :: 140
DASH_ONLY_BOSS_HEALTH :: 45
ENEMY_BOSS_SPEED :: f32(70)
ENEMY_BOSS_OPENING_SPEED :: f32(95)
ENEMY_BOSS_SHOT_SPEED :: f32(230)
ENEMY_BOSS_SHOT_DAMAGE :: 12
ENEMY_BOSS_AIMED_COOLDOWN :: f32(1.6)
ENEMY_BOSS_RADIAL_COOLDOWN :: f32(2.6)
ENEMY_BOSS_PHASE_TIME :: f32(7)
ENEMY_BOSS_CHARGES :: 3
ENEMY_BOSS_DASH_GAP :: f32(0.5)
ENEMY_BOSS_FINAL_STAND_THRESHOLD :: f32(0.3)
ENEMY_BOSS_FINAL_STAND_COOLDOWN :: f32(1.1)
ENEMY_BOSS_FINAL_STAND_SPEED :: f32(210)
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

PLAYER_UPGRADE_POOL :: [7]Upgrade_Card{
	{title = "QUICK SCAN", description = "Scan 20% faster", kind = .Rapid_Fire, fire_rate = 0.8},
	{title = "PACKET BURST", description = "Send 3 packets in a spread", kind = .Multi_Shot, bullet_count = 3, spread = 0.16},
	{title = "DEEP CLEAN", description = "Packets pass through 1 virus", kind = .Piercing, piercing = 1},
	{title = "SYSTEM RESTORE", description = "Deleted viruses restore 5 integrity", kind = .Vampire, kill_heal = 5},
	{title = "REDIRECT", description = "Packets retarget 1 virus after a hit", kind = .Ricochet, ricochets = 1},
	{title = "QUARANTINE", description = "35% chance to convert a virus into an ally", kind = .Necromancer, necromancer_chance = 0.35},
	{title = "FIREWALL PULSE", description = "Dash damages nearby viruses; stacks grow its radius", kind = .Dash_Shockwave, shockwave = 1},
}

ENEMY_UPGRADE_POOL :: [5]Upgrade_Card{
	{title = "BOTNET BLOOM", description = "Viruses spawn 20% faster", kind = .Enemy_Swarm, spawn_rate = 0.8},
	{title = "POLYMORPHIC CODE", description = "Basic viruses split when deleted", kind = .Enemy_Splitter, splitter = true},
	{title = "BACKDOOR PROTOCOL", description = "Basic viruses begin firing packets", kind = .Enemy_Ranged, ranged = true},
	{title = "WORM SURGE", description = "Worms dash 30% faster and recover 20% sooner", kind = .Enemy_Charger, charger_dash_speed = 1.3, charger_cooldown = 0.8},
	{title = "PACKET FLOOD", description = "Backdoor viruses fire 1 extra packet", kind = .Enemy_Ranged_Volley, ranged_shots = 1},
}

RESTLESS_ENEMY_CARD :: Upgrade_Card{
	title = "THEY GROW RESTLESS",
	description = "Every enemy system boost activates at once",
	kind = .Enemy_Frenzy,
	enemy_speed = 0.2,
	enemy_health = 1,
	spawn_rate = 0.75,
	contact_damage = 5,
	splitter = true,
	ranged = true,
	armor = 1,
	charger_dash_speed = 1.25,
	charger_cooldown = 0.8,
	ranged_shots = 1,
	ranged_cooldown = 0.8,
}
