# GOLDEN MARCH — Three Playable Chapters

**New: Chapter III, Bellacourt.** On the title screen, press **3** or click **COMMAND BELLACOURT**. You can also launch it from the third campaign-atlas entry. Chapters I and II remain available.

You are a mounted marshal commanding eight independent companies, with 469 soldiers across the two armies. Select, queue routes, set facing, form columns for streets, brace spear schiltrons and coordinate cavalry / bows. The new city is assembled from eight original generated paintings, with low town walls and separate building footprints. [Chapter III field book](docs/CHAPTER_III.md).

![Bellacourt command](screenshots/bellacourt_commander.png)

A playable Godot action / formation strategy game. This update rebuilds the supplied Kingdom Rise project around dense companies, a warm illustrated European siege, and deliberate battlefield command. The original melee combat, possession, siege machinery, multi-level navigation and officer duels remain playable.

![The battlefield](screenshots/battlefield.png)

## Play

1. Extract the complete folder.
2. In **Godot 4.5.1 or newer**, choose **Import** and select `project.godot`.
3. Press **F5**. Enter or click on the title to start the siege. **M** opens the campaign atlas instead.

This is the complete editable **Godot project**, not an Unreal project or a compiled Windows executable. Use the standard Godot build; .NET is not required. Troop sprite atlases, sound and music are generated locally at startup. The eight Chapter III environment paintings are bundled PNG assets. There are no external asset downloads.

## What changed

- **300 active soldiers at the opening**: 121 allied soldiers including the player, and 179 enemies. Five allied companies meet four enemy sortie companies, backed by wall archers and garrisons. This is approximately three times the original siege deployment. Reinforcements sustain the battle.
- **Army density presets**: Standard caps 90 allies / 130 enemies; War caps 150 / 230; Epic caps 220 / 340. War is the default. F6 cycles presets. Reducing density returns distant non-command troops to reserves, preserving army strength.
- **Command immediately**: you begin as a Field Captain with up to 16 followers. Promotions increase your command to 20, 24, 32, 40 and eventually 48 soldiers.
- **Line, wedge and square**: actual slots, reforming, cohesion and combat effects. Rank-and-file companies retain ranks outside combat and use shorter pursuit leashes.
- **Tactical time**: Tab pulls the camera back and slows time to 16%. WASD pans. Right-click places the selected formation. Formation cards can be clicked or selected with 4/5/6. The command atlas shows city blocks, canal, walls, units and camera position.
- **Three contested approaches**: West Orchard, Ram Road and East Fields. Nearby numerical advantage captures a point over time. Captured ground boosts morale, then gradually drains the opposing side's morale and reserves. The three diamonds above the battlefield show ownership.
- **A new visual direction**: harvest fields, wheel-rutted roads, wheat, poppies, dry-stone boundaries, orchard trees, limestone walls, slate / terracotta roofs, a chapel and a castle keep. Rust cloth and cool teal identify the armies.
- **Character and weapon polish**: eight-frame infantry walks, smoother acceleration, stronger silhouettes, nasal helms / bascinets, heater shields with heraldry, arming swords, straight greatswords, leaf-headed pikes and halberds. Fast dashes, parries, weapon skills and finishers remain.
- **Minimal combat HUD**: compact vitals, a narrow army balance, one objective, a quiet command status and a weapon label. Detailed controls and the atlas appear only when requested. The title, pause menu, manual and promotion presentation are restyled.

![Command view](screenshots/command_view.png)

## Formation choices

| Formation | Shape and combat effect | Use |
| --- | --- | --- |
| Line | Two or more ranks; up to 25% frontal damage reduction at full squad cohesion | Hold a broad approach and cover the ram |
| Wedge | Staggered V; up to 22% attack bonus on an advance order at full cohesion | Concentrate an assault on a weak point |
| Square | Perimeter slots; soldiers face outward, with up to 35% directional protection at full cohesion | Resist attacks from several directions |

Bonuses depend on soldiers actually reaching their positions. Breaking cohesion weakens them. Flanking the unprotected side of an organised soldier increases clean melee damage by 20%. Formations are deliberately imperfect around narrow ladders, gates and solid buildings; navigation resolves the obstruction and troops reform in open ground.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrows | Move; pan in command view |
| Mouse | Aim |
| Left mouse | Light attack / combo |
| Right mouse | Heavy attack; hold to charge |
| Light, light, heavy | Weapon finisher |
| Space | Dash |
| Shift | Guard; time the press for a parry |
| E / R | Weapon skill / healing flask |
| F | Interact, pick up weapon, mount, challenge an officer |
| C / T or middle mouse | Kick / throw weapon |
| Tab | Toggle command view |
| Right mouse in command view | Place formation and advance |
| 1 / 2 / 3 | Follow / advance to cursor / hold |
| Q / 4 / 5 / 6 | Cycle formation / line / wedge / square |
| Mouse wheel | Adjust combat zoom |
| X | Release a full General's Aura |
| G / V | War cry / arrow volley at the original rank unlock |
| Backspace during possession | Cycle surviving allies; Enter chooses one |
| H / Esc | Field manual / pause |
| F2 / F6 / F11 | Low graphics / army density / fullscreen |

Keyboard and mouse are recommended for formation command. The original gamepad combat bindings remain; the new command view and formation selectors use keyboard / mouse.

## The siege

Capture the approaches and protect the covered ram, use the six scaling ladders, or escort the two rolling siege towers. Wall defenders reinforce and pour burning oil. Watch the landing warnings from the trebuchets. Breach the gate or take the wall, fight through the town and across the canal, defeat the two ward commanders, and reach Lord Aldric in the keep courtyard. Soldiers fight on their own elevation; archers can fire across levels. When the controlled soldier falls, choose another allied body and retain your rank and legacy.

The snow-plains field battle is Chapter II. Chapter III is now the playable commander battle at Bellacourt, replacing the earlier unplayable river placeholder. The sealed historical scenarios remain planned entries.

## Performance and validation

F2 reduces lighting, bloom and shadow work. F6 reduces active simulation density independently. Epic is optional and has not been benchmarked on desktop gaming hardware. Start with War and adjust for your machine.

Tested with the actual Godot 4.5.1 runtime, including rendered title, battle, command view, campaign atlas, city and keep. Integration checks exercise formations, orders, density conservation, death / possession and six navigation routes. See `docs/PLAYTEST.md` for exact scope and limitations.

## Code map

- `scripts/strategy/formation_director.gd`: regiment membership, formation geometry, command input, cohesion, capture points, density presets and integration checks.
- `scripts/world/battle.gd`: battle loop, recruitment, reserve waves and combat camera.
- `scripts/ai/ai_brain.gd`: formation-aware marching and pursuit limits.
- `scripts/combat/unit.gd`: directional protection, flank damage, advance attack bonus, movement and animation.
- `scripts/world/siege.gd`: siege collision, route logic, machines and phases.
- `scripts/world/golden_landscape.gd`, `medieval_props.gd`, `city_art.gd`, `shaders/harvest_ground.gdshader`: native vector environment and terrain.
- `scripts/core/art.gd`, `art_props.gd`: generated soldier and weapon atlases.
- `scripts/ui/title.gd`, `hud.gd`: title, manual, compact HUD and tactical atlas.
