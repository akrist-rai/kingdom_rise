# Credits

All third-party art, audio and fonts in this project are free to use. The 3D source models are
kept in `art_src/` (excluded from the Godot import with `.gdignore`) and are rendered into the 2D
sprite sheets in `assets/units/` and `assets/props/` by the bake tools in `tools/`.

## 3D models (rendered to sprites)

| Pack | Author | License | Used for |
| --- | --- | --- | --- |
| KayKit Adventurers Character Pack 1.0 | Kay Lousberg (kaylousberg.com) | CC0 1.0 | Soldiers (Knight, Barbarian, Rogue Hooded), their animations and weapons |
| KayKit Medieval Hexagon Pack 1.0 | Kay Lousberg (kaylousberg.com) | CC0 1.0 | Houses, castle, towers, walls, tents, carts, crates, flags and other props |
| Stylized Nature MegaKit (free edition) | Quaternius (quaternius.com) | CC0 1.0 | Trees, bushes, rocks, grass, flowers and ground clutter |
| Horse | Quaternius (via poly.pizza) | CC0 1.0 | Cavalry horses |

The siege tower, ram and trebuchet, and the hammer, glaive, spear and bow meshes, are built in
code (`tools/bake_siege.gd`, `tools/bake_units.gd`).

## Effects

| Pack | Author | License |
| --- | --- | --- |
| Particle Pack 1.1 | Kenney (kenney.nl) | CC0 1.0 |
| Smoke Particles | Kenney (kenney.nl) | CC0 1.0 |

## Audio

See `assets/audio/CREDITS.txt`.

- Music (CC0, opengameart.org): "War Theme" by Spring Spring; "Determined Pursuit (epic orchestra loop)" by Emma_MA; "Massive Battle" by Eldritch Grim.
- Sound effects: Kenney Impact Sounds, RPG Audio and Interface Sounds (CC0, kenney.nl); "Swishes Sound Pack" and "RPG Sound Pack" by artisticdude (CC0, opengameart.org).

## Fonts

- Cinzel by Natanael Gama, SIL Open Font License 1.1 (`assets/fonts/Cinzel-OFL.txt`).
- Barlow Condensed by Jeremy Tribby, SIL Open Font License 1.1 (`assets/fonts/Barlow-OFL.txt`).

## Interface icons added in the Iron & Ember polish pass

- [Lucide](https://lucide.dev/), Lucide Icons and Contributors. ISC license; selected inherited Feather icons also carry the MIT notice. The complete upstream notices are retained in `assets/ui/icons/LICENSE.txt`.
- Icons are bundled SVGs; `currentColor` strokes were changed to white for Godot import and are tinted at runtime. No remote requests are made by the game.
- Character mantle, combat cues, courtyard shader, and UI layouts are original project code. Existing KayKit, Quaternius, Kenney, audio, and font credits above continue to apply.
