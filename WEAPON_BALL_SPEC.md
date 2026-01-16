# Weapon Ball Clone Spec (MVP)
A lightweight, data-driven, physics-based battle simulator inspired by the "Weapon Ball" style popularized by Earclacks. The goal is to capture the feel and design patterns (physics-first chaos, readable combat, per-hit scaling), while building an original implementation with clean architecture and excellent extensibility.

This spec is intentionally small. Build the core loop cleanly, make it fast, then expand.

---

## 0. How To Use This Doc With Claude Code
Paste this file (or point Claude at it) as the primary project context.

When generating code, Claude should:
- Prefer simple, readable systems over cleverness.
- Keep the hot path allocation-free (or close).
- Keep all tunables in data (Resources), not hardcoded.
- Add weapons by adding a new definition plus a behavior script, without editing core systems.

---

## 1. Product Definition

### 1.1 Core loop (MVP)
1. Spawn N balls into an arena.
2. Each ball has a weapon (or "unarmed") and a basic AI that seeks opponents.
3. Physics drives motion and collisions.
4. Weapon hits cause damage, knockback, and weapon scaling.
5. Match ends when one reference (or one team) remains alive.

### 1.2 Experience goals
- Satisfying, "clacky" physics feel (momentum, ricochets, spin).
- Matches are short and legible: you can tell what happened.
- Everything important is data-driven: weapons, ball stats, arena layout.
- Deterministic enough for debugging (seeded spawns), but perfect determinism across machines is not required in MVP.

### 1.3 Non-goals (for now)
- Multiplayer.
- Netcode determinism.
- Fancy VFX, cosmetics, progression, unlocks.
- In-editor arena/weapon authoring tools beyond a simple debug panel.

---

## 2. Tech Choices

### 2.1 Engine
- Godot 4.x, 2D.
- Balls: RigidBody2D (physics drives movement).
- Weapons: Area2D hitboxes for melee contacts; RigidBody2D or Area2D for projectiles depending on desired feel.

### 2.2 Tick model
- All simulation logic runs in `_physics_process(delta)` at fixed timestep.
- UI and rendering can run in `_process(delta)` if needed.

### 2.3 Data-driven content
- Use Godot Resources (`.tres`) for BallDefinition, WeaponDefinition, ArenaDefinition.
- Behaviors are code (GDScript) bound to a definition at runtime.

---

## 3. MVP Feature Set

### 3.1 Modes
Only these three:
- Duel (1v1)
- Free For All (N balls, last alive wins)
- Team Fight (A vs B, last team alive wins)

### 3.2 Weapons (MVP roster)
Implement exactly these six weapons first. They cover melee, reach, ranged, and a status effect, plus distinct scaling behaviors.

1) Unarmed
- Damage scales with speed (relative impact).
- On-hit scaling: +max_speed per hit.

2) Sword
- Orbiting melee hitbox.
- On-hit scaling: +damage per hit.

3) Dagger
- Orbiting melee hitbox.
- On-hit scaling: +rotation_speed per hit.

4) Spear
- Orbiting melee hitbox with extendable reach.
- On-hit scaling: +reach and +damage per hit.

5) Bow
- Ranged projectile weapon.
- Fires a volley based on arrow_count.
- On-hit scaling: +arrow_count per hit.

6) Scythe
- Orbiting melee hitbox that applies poison.
- On-hit scaling: +poison_power per hit.

### 3.3 Arena (MVP)
- One default rectangular arena with solid walls.
- 2 to 4 static obstacles (boxes) for ricochets.
- No hazards, no shrinking zone, no portals.

### 3.4 Debug UI (MVP)
A simple in-game panel:
- Mode selector
- Ball definition selector for each slot (or random)
- Seed (int) for reproducible spawns
- Start, pause, step (1 physics tick), reset
- Time scale: 0.25x, 1x, 2x, 4x
- Per-ball readout: HP, weapon name, key weapon stats (damage, rotation_speed, reach, arrow_count, poison_power)

---

## 4. Architecture Principles

### 4.1 Separation of concerns
- Simulation: physics interactions, hit detection, damage, scaling, status effects
- Content: definitions (Resources)
- Presentation: visuals, camera, UI
- Tools: debug spawner, logging, quick balance tweaks

### 4.2 Data-driven, code-pluggable weapons
Weapons must be addable without editing core systems:
- WeaponDefinition Resource stores tunables.
- WeaponBehavior scripts implement logic.
- WeaponFactory instantiates the correct behavior based on WeaponDefinition.type.

### 4.3 Single damage pipeline
All damage flows through one pipeline:
- Contacts generate HitEvents.
- CombatSystem validates, computes damage, applies knockback, applies effects, and triggers scaling.
- WeaponBehavior receives `on_hit(HitEvent)` callback to update its scaling state.

This keeps balancing and extensibility safe.

---

## 5. Core Systems

## 5.1 Ball (Entity)
A ball is a physics body plus combat state.

### Responsibilities
- RigidBody2D movement (forces and impulses only).
- Own CombatState (HP, alive, team).
- Own Weapon instance.
- Run AI steering (cheap and predictable).

### BallDefinition fields (data-driven)
- id, display_name
- radius, mass
- base_hp
- max_speed
- linear_damp, angular_damp
- physics material: friction, bounce (PhysicsMaterial)
- weapon_id
- visuals: color (and optional sprite reference later)

### Notes
- Keep Ball scene prefab minimal: CollisionShape2D, Sprite2D (optional), WeaponMount node, and a Ball.gd script.

## 5.2 Weapon System
Weapons attach to a ball and create hit events.

### Weapon behaviors (MVP)
- OrbitMeleeBehavior
  - Creates an Area2D hitbox orbiting at rotation_speed and reach.
  - Deals damage on contact subject to hit cooldown.
- RangedProjectileBehavior
  - Fires projectiles toward current target.
  - Uses pooling.
- PoisonApplierMixin (simple helper)
  - Adds poison stacks when a hit is confirmed.

### Hit registration
MVP approach:
- Weapon hitboxes are Area2D with collision masks set to "Balls" only.
- On area overlap with an enemy ball, build a HitEvent:
  - attacker_id, defender_id
  - relative_speed (magnitude of attacker velocity minus defender velocity)
  - hit_normal (approx from positions)
  - base_damage (weapon stat)
  - knockback (weapon stat)
  - tags: melee/projectile/poison
  - weapon_id
  - timestamp (physics frame count)

### Damage model (simple and stable)
- speed_factor = clamp(relative_speed / speed_scale, 0, 1)
- damage = base_damage * (1 + speed_factor)
- defender.hp -= damage
- apply knockback impulse: hit_normal * (knockback * damage)

Tuning constants:
- speed_scale (global, default 600)
- hit_cooldown per weapon (default 0.12s for orbit weapons)

## 5.3 Scaling
Scaling triggers on confirmed hits only. Each weapon defines its scaling rule as simple additive increments.

- Sword: damage += 1
- Dagger: rotation_speed += dagger_rot_step (default 0.5)
- Spear: reach += 0.5; damage += 0.5
- Bow: arrow_count += 1
- Scythe: poison_power += 1
- Unarmed: max_speed += 1; damage depends on relative_speed

Scaling must update:
- Weapon runtime state
- Debug UI readout

## 5.4 Status Effects (MVP)
Only Poison.

Poison model:
- Each stack adds poison_dps for poison_duration.
- New stacks refresh duration and add linearly to total dps.
- Tick poison in CombatSystem on physics ticks.

Suggested defaults:
- poison_dps_per_stack = 0.75
- poison_duration = 3.0 seconds
- poison_tick_interval = 0.25 seconds (accumulate fractional time)

## 5.5 AI (Minimal but believable)
No pathfinding.

MVP AI:
- Target: nearest enemy by squared distance.
- Steering: apply impulse toward target up to max_speed.
- Add light sideways jitter based on seeded noise so fights do not look perfectly linear.
- Bow: fire when target within fire_range; ignore line of sight for MVP.

Optional later:
- Avoid clumping (separation force).
- Prioritize low HP targets.

---

## 6. Content Formats (Resources)

Use Godot Resources so designers can tune in-editor.

### 6.1 BallDefinition example (YAML-like)
```yaml
id: "unarmed_blue"
display_name: "Unarmed"
radius: 18
mass: 1.0
base_hp: 100
max_speed: 420
linear_damp: 0.2
angular_damp: 0.2
physics_material:
  friction: 0.4
  bounce: 0.8
weapon_id: "unarmed"
team: 0 # overridden by mode spawner
color: "#4aa3ff"
```

### 6.2 WeaponDefinition example (Orbit Melee)
```yaml
id: "sword"
type: "orbit_melee"
base_damage: 6
knockback: 1.0
rotation_speed: 8.0
reach: 34
hit_cooldown: 0.12
scaling:
  on_hit:
    damage_add: 1
```

### 6.3 WeaponDefinition example (Bow)
```yaml
id: "bow"
type: "ranged_projectile"
base_damage: 3
knockback: 0.6
fire_cooldown: 0.7
fire_range: 520
arrow_count: 1
projectile:
  speed: 820
  lifetime: 2.2
  radius: 6
  pierce: 0
scaling:
  on_hit:
    arrow_count_add: 1
```

### 6.4 ArenaDefinition example
```yaml
id: "default_arena"
size: [1280, 720]
walls: true
obstacles:
  - shape: "box"
    pos: [0, 0]
    size: [180, 40]
```

---

## 7. Performance Targets

### 7.1 Target scale
- Smooth 64-ball FFA with moderate projectile counts.
- Dev-only stress test: 200 balls (expect reduced FPS, but no instability).

### 7.2 Budget rules
- Avoid per-tick allocations in hot paths.
- Pool projectiles and optional hit VFX later.
- Use collision layers/masks so weapon hitboxes only query balls.
- AI: O(N) nearest target search for MVP, upgrade later (grid or spatial hash) if needed.

### 7.3 Stability rules
- Do not manually set RigidBody2D position each frame.
- Apply forces/impulses and let physics resolve contacts.
- Run combat logic on physics tick.

---

## 8. Suggested Directory Structure

```
/ (repo root)
  /project.godot
  /scenes
    /game
      Game.tscn
      Arena.tscn
      Ball.tscn
      Projectile.tscn
    /ui
      DebugSpawner.tscn
  /src
    /core
      Simulation.gd
      HitEvent.gd
      CombatSystem.gd
      StatusSystem.gd
      MatchSystem.gd
    /ai
      SimpleAIController.gd
    /weapons
      WeaponFactory.gd
      behaviors/
        OrbitMeleeBehavior.gd
        RangedProjectileBehavior.gd
        PoisonApplier.gd
        UnarmedBehavior.gd
  /content
    /balls/*.tres
    /weapons/*.tres
    /arenas/*.tres
  /docs
    /references.md
```

---

## 9. Implementation Order (Do This In Sequence)

### Milestone A: Physics sandbox
- Arena scene with walls and obstacles
- Ball prefab (RigidBody2D) with PhysicsMaterial
- Debug spawner: spawn N balls, seeded positions, reset

### Milestone B: Combat pipeline
- HitEvent struct
- CombatSystem: HP, death, removal
- Win conditions: last alive, last team

### Milestone C: Weapon framework
- WeaponDefinition Resource
- WeaponFactory and behavior interface
- OrbitMeleeBehavior + Sword working end-to-end

### Milestone D: Add remaining MVP weapons
- Dagger scaling
- Spear scaling
- Bow projectiles + scaling
- Scythe poison DOT + scaling
- Unarmed speed-based damage + max_speed scaling

### Milestone E: Modes + polish
- Duel, FFA, TeamFight spawners
- HUD: alive count, winning team
- Pause, step, time scale

---

## 10. Definition of Done (MVP)
MVP is done when:
- Duel, FFA, TeamFight runnable from debug UI.
- All six weapons work and scale as specified.
- Weapons and balls are fully tunable via `.tres` definitions (no code changes for balance).
- 64-ball FFA runs smoothly on a typical dev machine.
- Adding a new weapon requires:
  - a new WeaponDefinition, and
  - a new behavior script (or reuse an existing behavior),
  without editing CombatSystem or Simulation.

---

## 11. Reference Links (for Claude to explore)

### 11.1 Earclacks inspiration
- Earclacks official hub (overview + roadmap): https://www.earclacks.com/
- Earclacks Scratch profile (lists Weapon Ball projects and variants): https://scratch.mit.edu/users/Earclacks/
- Weapon Balls community rules (Fandom): https://earclacks-fighting.fandom.com/wiki/Weapon_Balls
- Battle Royale page with weapon scaling summaries (Fandom): https://earclacks-fighting.fandom.com/wiki/Battle_Royale
- Earclacks YouTube channel: https://www.youtube.com/@Earclacks

### 11.2 Godot docs (core engine behaviors)
- RigidBody2D (forces/impulses, not direct control): https://docs.godotengine.org/en/stable/classes/class_rigidbody2d.html
- Idle and Physics Processing (`_physics_process` fixed timestep): https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html
- Physics introduction (physics materials usage context): https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html
- PhysicsMaterial (friction, bounce): https://docs.godotengine.org/en/stable/classes/class_physicsmaterial.html
- Resources tutorial (custom resource types): https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html
- CPU optimization guide (performance mindset): https://docs.godotengine.org/en/4.5/tutorials/performance/cpu_optimization.html

---

## 12. Licensing and originality note
We are cloning the style and gameplay feel for fun and learning.
Do not reuse Earclacks assets, code, or trademarked branding.
All visuals and code in this project should be original or properly licensed.
