---
# ---- Fill every field. Use `unavailable` (with a reason in tokens_source) rather than guessing. ----
game_title: "Virus Cleanup"
twist_one_liner: "ARENA, but as you progress so do the enemies."
twist_category: "player-progression"
twist_from_ideas_list: adapted
how_far_from_arena: "substantial"

# Tools and models (lists; exact names as the tool shows them)
tools: [claude-web, Github-Copilot]
models: [claude-sonnet-5, GPT-5.6 Luna]
primary_model: "GPT-5.6 Luna"
plan: "unavailable"
agent_instructions_file: no    # yes | no  (CLAUDE.md, AGENTS.md, .cursorrules, ...)

# Totals (must match jam-log.csv)
sessions: 21
total_minutes: 465
total_prompts: 99
total_tokens_in: unavailable
total_tokens_out: unavailable
tokens_source: "unavailable: per-user token counts were not available for Claude web or GitHub Copilot"

# Your estimate of who wrote the code in the final build (should add to 100)
code_share_llm_pct: 70        # accepted from an LLM with little or no change
code_share_mixed_pct: 25       # LLM-generated then substantially edited by you
code_share_hand_pct: 5         # written by you

# Before this jam
odin_experience_before: "none"     # none | under-10h | 10-50h | over-50h
llm_coding_before: "occasional"          # never | occasional | weekly | daily
gamedev_experience_before: "a-few-small-games"  # none | a-tutorial | a-few-small-games | shipped-something

transcripts_shared: no         # yes | no  (optional, ungraded)
---

# Postmortem — Virus Cleanup

> Your own words. Grammar and spelling help from a tool is fine; the argument
> and the evidence are yours. Aim for 1-2 pages plus the table.
## 1. The game

One paragraph: what your game is and how to play it. Then what you **kept**,
**changed**, **removed** and **added** compared with ARENA.

**Where is the depth?** Answer the three questions from the README: the new
**decision** the twist creates, the **trade-off** behind it, and what an
**expert** does differently from a beginner. Use what you saw players do at
the Monday showcase as evidence.

My game is ARENA but with upgrade cards for the player but also the enemies. The player is equipped with a dash with I-frames, and after each round you pick another upgrade, but with a downside you also have to pick an upgrade for the foes.  Which is both the decision and the trade off, power yourself and the enemies up. There are ascension levels which are just the standard run but with twists to make each level unique. An expert will decide they like certian builds and combos for the enemies that respond to their own build.
## 2. Your setup

Which tools and models, and **why** those (cost, familiarity, a friend's
advice...). Did you give the agent a project instruction file, the Raylib
binding, docs, example code? Paste the instruction file, or its key lines, if
you used one.

I used claude web to set up the basic ARENA game, just spawning movement and shooting. Afterwords I just used githubs copilot which used GPT-5.6 Luna. I used claude web because previously I had used it and found it the best for coding and helping me understand what was being coded by it. I used copilot because I learnt about their student benifits and wanted to try it out and I found the vscode implementation with it extremely helpful. I did not give the AI any project instructions, it however had access to all the files that are in the zip file I submitted and I believe it looked up documentation on its own for raylib.
## 3. Feature by feature

One row per feature you built. The first rows are ARENA's parts; drop the ones
you removed, and add a row for each feature of your own.
`who` = `llm`, `mixed` or `me`. `first try` = did the first LLM answer work
without changes? `help` = 1 (got in the way) - 5 (did it well).

| feature | who | prompts | first try? | minutes | help 1-5 | note |
|---|---|--:|---|--:|:--:|---|
| window, loop, game states, restart | mixed | 17 | no | 85 | 4 | Sessions 1-2, 6, 10 |
| player movement | mixed | 13 | no | 70 | 4 | Sessions 1-2 and dash work |
| shooting | mixed | 13 | no | 70 | 4 | Sessions 1-2 and weapon upgrades |
| enemies and spawning | mixed | 32 | no | 150 | 4 | Enemy types, spawning, and boss work |
| health, damage, hit feedback | mixed | 18 | no | 95 | 4 | Damage, healing, regeneration, and balance |
| difficulty over time | mixed | 24 | no | 120 | 4 | Rooms, upgrades, ascensions, and Endless |
| HUD | mixed | 18 | no | 75 | 4 | Theme, cards, wrapping, and menu information |
| (optional) sprites / sound | mixed | 18 | no | 70 | 5 | Kenney sound effects, ambience, and volume controls |
| ascension modes | mixed | 20 | no | 150 | 5 | Five sequential ascensions with mode-specific rules |
| Endless mode | mixed | 3 | yes | 30 | 5 | Standard five-sector cycle that repeats |
| terminology legend and menu polish | mixed | 12 | no | 60 | 5 | Legend, fullscreen scaling, and menu controls |

## 4. Where the LLM sped you up

The easy parts. Name the features, the session number from `jam-log.csv` or
the commit, and estimate how long it would have taken you without it.

GitHub Copilot sped me up most during the implementation of the upgrade system, boss fight, and additional game modes. In session 2, it helped create the player and enemy upgrade-card system, which would have taken me several hours to design and implement alone. In session 3, it helped add the first boss and room progression. Sessions 7 and 13 added new enemy types and a multi-phase boss fight. Sessions 16-20 added the Ascension modes and Endless mode. Session 21 helped finish fullscreen scaling, audio controls, the legend, and menu polish. Without LLM assistance, I estimate the full project would have taken at least three times longer, and I probably would have removed the Ascension and Endless modes to reduce the scope.

## 5. Where it did not help

The hard parts. What was the problem, what did you try (prompts, other models,
docs, a classmate, doing it by hand), and what finally worked? Was the
difficulty Odin, Raylib, game design, tuning the feel, or the tool itself?

The difficulty was tuning the feel of the game, as well as the numbers for health and damage. As well as when prompted to make my ideas and to mention any similar ones I could introduce, for example triple shot and necromancy upgrade cards the only upgrade cards it recomended were like HP increase, damage increase, knockback increase, so the ideas the AI was not good at. It must be used as a tool to see your very specific vision to life.

## 6. One LLM-introduced bug: found, fixed, verified

- **The bug**: what it did wrong, and the code (a short excerpt or a commit link).
- **How you noticed**.
- **The fix**: the code after.
- **How you know it is fixed**: the evidence (debug draw, printed values, a
  test, a before/after clip or screenshot in the repo).
- **The bug:** The Necromancer upgrade card converted defeated enemies into
  allies, but those allies stayed in `game.enemies`. Room completion checked
  the total length of that array, so a room could not finish until every ally
  was gone. This was especially noticeable when several enemies were
  converted during the same wave.

  **Before:**

  ```odin
  if game.state == .Playing &&
      game.room_spawned >= game.room_enemy_target &&
      len(game.enemies) == 0 {
      game.xp += ROOM_XP
      // Advance to the next room...
  }
  ```

- **How I noticed:** I noticed it by playtesting the Necromancer card. The
  enemies had been defeated, but the room did not complete because the green
  converted allies were still present in the enemy array.

- **The fix:** I counted only living hostile enemies for room completion. The
  allies still exist long enough to attack, but they do not block the room
  from completing. They also receive a 30-second lifetime and are removed by
  the normal cleanup afterward.

  **After:**

  ```odin
  hostile_enemies := 0
  for e in game.enemies {
      if e.alive && !e.ally do hostile_enemies += 1
  }

  if game.state == .Playing &&
      game.room_spawned >= game.room_enemy_target &&
      hostile_enemies == 0 {
      game.xp += ROOM_XP
      // Advance to the next room...
  }
  ```

  The ally lifetime is handled separately:

  ```odin
  if e.ally {
      e.ally_timer -= dt
      if e.ally_timer <= 0 {
          e.alive = false
          continue
      }
  }
  ```

- **How I know it is fixed:** I replayed a wave with Necromancer active and
  confirmed that converted allies could remain on screen while the room
  advanced once no hostile enemies remained. `odin check .` also passed after
  the change.
- 
## 7. Pitch vs. delivered

Paste your Wednesday pitch. What survived, what was cut, what was added, and why.
What did you change after the Monday showcase, based on how people played it?

ARENA game with upgrades

The core idea evolved to upgrades to players and enemies, more unique and added fun contrast to getting upgrades. Added a dash as well after the Monday showcase to popular request from player feedback and it was the right decision. I added more enemy types based on watching players play and the game being to predictable. I had cut the single battle of enemies and made different "rooms" of enemies which was the same physical space just cleared off enemies and with different enemy layouts and randomized spawns and eventually a boss on clearance 5. Added extra ascension levels which showcase certian upgrades to the player or its foes or both. As well as a not balanced endless mode. 

## 8. Improving the pipeline

If you did another jam next week with the same tools, what would you change?
Be concrete: setup, instruction files, prompting habits, when to use the LLM
and when not, commit rhythm, how you verify, which model for which job.
What would you want **from the tools** that they do not do today?

If I did another jam and was allowed the tools, I woud make sure I had a concrete plan for the final vision of the game. I would allow myself wiggle room for certian things but the scope of the game as in levels and structure of the game. I would make the foundation myself, create a instruction file with basic rules for the game and coding practices for long term health of the project. I would make sure my prompts are very specific and would use LLMs wherever possible but make sure debugging is done by me to not introduce more bugs, I would commit very often if I use the LLMs a lot as they are prone to many errors it seemed. But I would continue to use github copilot as I feel very comftorable with it now. I would want in the future the tools to have more information available of how I used them. Like the tokens used, as well as tips to prompt better to use the tokens more efficiently.
## 9. Anything else

Optional: what surprised you, what you learned about Odin, Raylib or game
development, what you would tell next year's class.

I learned a lot about Odin and Raylib, I would say if you are going to use LLMs in game development make sure to create a strong foundation, keep rendering and balancing and structure seperate as the AI will want to just create 1 massive file unless heavily instructed otherwise.