# Iron & Ember: graphics and combat pass

## Play the changes

Use the root `project.godot`. The nested `kingdom_rise/` directory is an older snapshot and is not the active project. Import in Godot 4.5.1 or newer, let assets import, and press F5.

Press **T** on the title screen to enter the Combat Yard. It cycles through three encounter compositions: foot soldiers; spear/heavy/bow; officer/foot/spear. Winning an exchange restores 25% health and refills flasks. Falling respawns a new practice body. Keys 1–6 switch between sword, glaive, spear, hammer, daggers and bow while idle. The siege, snow field and Bellacourt remain accessible from their existing title/campaign entries.

| Input | Revised combat behaviour |
| --- | --- |
| Left mouse | Click for a light attack; hold to continue a melee chain |
| Right mouse | Heavy attack; hold to charge; after two lights, weapon finisher |
| Space | Two dodge charges, recovered sequentially at 0.78 seconds each; separate from stamina |
| Shift | Guard; pressing into guard immediately opens the parry window |
| E / C / R | Weapon skill / kick / flask |
| F | Existing interaction and weapon pickup |
| F7 | Reduce camera shake, roll and zoom impulses |

A successful parry restores 26 stamina and primes a 1.2-second counter. A perfect dodge restores 14 stamina and primes a 1-second counter. The next light, heavy or dash attack consumes it for +35% damage and +50% stance damage. Its trail and ground ring turn mint. One evade grants one reward, regardless of how many hitboxes touch it. Ghost Step shortens dodge recharge by 30% and retains its longer invulnerability window.

## Diagnosis and resulting changes

These are findings from the repository, not claims that its original designers made mistakes in the referenced games.

| Found in the implementation | Change and intended effect |
| --- | --- |
| Mouse aim reverted to movement direction after 1.6 seconds without mouse movement | Mouse use is remembered explicitly. A resting cursor stays authoritative; keyboard-only movement aim remains available before the mouse is used. |
| Entering guard did not open a parry until a later guard frame | Open the parry on the entry frame. Recovery can cancel into guard after a short committed interval. |
| Attacks and evades could spend more stamina than remained | Attacks check their actual price; evades use their own visible charge budget. Successful hits refund four stamina once per attack. |
| Attacks reduced movement to 30%, with relatively long stops between links | Light attacks retain 64% movement, heavies 42%, recovery 86%. Player wind-up/recovery are shortened; hold-to-chain is supported. |
| Wide auto-target cone and target selection through scenery | Narrower 44-degree assist, and line-of-sight rejection. |
| Melee and melee skills could hurt enemies through solid footprints | Occlusion checks for normal swings, melee skills, quake and barrel blasts. Direct arrows also stop at city/yard footprints; the siege's existing elevated wall archery is preserved. |
| AI wind-ups tracked the player until contact | Hostile aim commits after 62% of wind-up, creating a meaningful dodge opening. Standard wind-ups are at least 0.34 seconds. |
| Attack slots could be held by the same soldiers | Attack slots rotate after a completed exchange. Two ordinary attackers, three at senior ranks. Existing officers and archers retain their roles. |
| Several victims extended hit stop and added camera kicks during one cleave | A short shared impact beat and one camera kick per attack. Victims keep individual reactions. |
| Dense weeds, screen-edge blur, repeated combat labels competed with fighters | Clustered vegetation, lower blur/vignette, smaller deduplicated combat text, less prominent promotions. |

## Art and map changes

- Warm russet/ivory allies and cool teal/steel enemies, a warmer controlled-body palette, steel split toning and a selective rim.
- A live gold-edged mantle anchored to the actual rendered body frame, with movement drag. Existing animated KayKit bodies and weapon sheets remain the base art.
- Foot marker and directional chevron; nearby hostile ground sectors show sweep/thrust shapes, timing and committed facing. Unblockables also use a cross, not just a colour change.
- Wider weapon ribbons, gold finishers and mint counters; reduced background soldier hit flashes.
- An anchored HUD with actual health, stamina, two recharge meters, finisher milestones and skill/guard/kick/flask tiles. Bundled Lucide SVG icons have their upstream license notices.
- Quieter sage/harvest terrain with clearer earth routes. Bellacourt gains clustered carts, supplies, standards, street lamps and warm light pools.
- Breakable caches restore 24 stamina and 10 spirit once. Marked oil barrels damage/knock down nearby enemies, respect walls and do not recursively detonate props.
- Company order lines follow the real navigation path; queued waypoints use a separate colour.
- A dedicated mossy stone/sand courtyard, armoury, chapel, targets and six-weapon practice loop.

## References studied

The references inform interaction principles; no game art, code, music or proprietary assets were copied from these titles.

1. [Alex Preston, Heart Machine: Creating the World of Hyper Light Drifter](https://blog.playstation.com/2014/03/14/creating-the-world-of-hyper-light-drifter-on-ps4-and-ps-vita/) — responsive hit feedback, visible reactions, fair tactical enemy encounters, restrained UI and meaningful landmarks.
2. [Greg Kasavin, Supergiant: The origins of Hades](https://blog.playstation.com/2021/08/05/the-origins-of-hades-out-next-week-on-ps5-ps4/) — immediately responsive action and depth through interconnected systems. The dodge/parry-to-counter loop is this project's interpretation, not a reproduction of a Hades system.
3. [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) — original animated character source already bundled here, CC0.
4. [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) — original effect source already bundled here, CC0.
5. [Lucide license](https://lucide.dev/license) — new interface icon source, ISC/MIT notices retained in `assets/ui/icons/LICENSE.txt`.

## Verification and limits

Actual engine: Godot 4.5.1 stable, Linux X11, Mesa llvmpipe software OpenGL. Screenshots in `screenshots/polish_*.png` are unedited engine captures.

Completed checks:

- Project import/script compilation and shader rendering.
- 37 combat integration checks: first-frame parry, real parried damage, stamina affordability, two evade charges and recharge, one dodge reward, empowered counter, immutable weapon definitions, input priority, walls against swings/skills/direct arrows, real hit after wall removal, one hit per swing, one-shot supplies and footprint removal, all twelve weapon attack phase sequences, oil blast damage, mouse aim persistence and bounded hit stop.
- Siege line/wedge/square, move/hold/follow and density conservation checks.
- A forced fall followed by possession of another allied body and continued combat.
- All six siege navigation routes, open gate/city/keep and boss-duel startup.
- Bellacourt selection, queued movement, formation compatibility, brace/cavalry interaction, rally, planning pause and three city routes.
- Combat Yard live self-play, multiple exchanges, forced death/respawn and title-screen T entry.

Commands (use your own Godot executable):

```sh
godot --headless --editor --path . --import --quit
godot --path . -- --autotest --combat-test --god --len=15
godot --path . -- --autotest --tactics-test --god --kill=3.2 --len=32
godot --path . -- --autotest --phase=3 --navtest --god --len=20
godot --path . -- --autotest --level=commander_city --commander-test --god --len=16
godot --path . -- --autotest --title --test-yard-entry --len=18
```

Rendering tests require a display and graphics driver because the existing art system builds textures in viewports. Only import/compilation uses headless mode. Long campaigns, human combat preference, gamepad parity for the new yard weapon selectors and desktop GPU performance were not certified. Software-renderer frame rates are not a prediction of desktop hardware performance. The existing engine shutdown ObjectDB/resource cleanup warnings still occur in some runs; no claim is made that those are resolved.
