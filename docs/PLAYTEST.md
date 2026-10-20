# Runtime validation

Engine: Godot 4.5.1 stable, standard Linux build. Rendered under X11 using Mesa llvmpipe software OpenGL. These are engine runs, not static mockups.

## Passed

- Project import and script compilation.
- Generated 322 vector sprites, including all eight infantry walk frames.
- Title and campaign atlas rendering.
- Opening siege: 121 allies / 179 enemies, 16 followers and 28 company groups in the captured run.
- Line / wedge / square selection; advance / hold / follow orders.
- All recruited formation goals finite.
- Reducing density respects the 90 / 130 Standard caps and preserves each side's combined active + reserve strength; returning to War restores the configured 150 / 230 caps.
- Forced player death and successful possession of a surviving allied soldier. Subsequent melee combat, kicks and executions continue.
- Tactical camera, city footprint atlas and selected formation overlay rendering.
- Open gate, city phase, open keep and general duel startup.
- Navigation mesh rebuilt successfully: 123 polygons and 160 vertices in the open-city run.
- All six route tests reached their destination: field to ladder; wall to city stairs; south to north across canal; street to keep platform; field through open gate to city; west to east wall-walk.
- Final strategy and navigation regression runs completed without script errors or assertion failures.

## Scope

This is a substantial playable source update, not a full campaign completion or a hardware performance certification. Real graphics hardware and long-duration player sessions were not available. The optional Epic density setting is not GPU-benchmarked. Capture-point progression is implemented in the running simulation; the regression did not drive an entire siege to victory through player input. Controller support for the new command UI is not added.

The engine emitted a V-Sync availability warning under the virtual display and an ObjectDB cleanup warning at shutdown in several runs. These did not stop rendering, navigation, combat or possession. They have not been certified absent on a normal desktop display.

## Reproduce checks

From this project directory, using your Godot executable:

```
godot --path . -- --autotest --tactics-test --god --kill=3.2 --len=30
godot --path . -- --autotest --phase=3 --navtest --god --len=20
godot --path . -- --autotest --command --noauto --god --len=12
godot --path . -- --autotest --map --len=6
```

`--autotest` starts a battle immediately and self-plays. `--god` prevents normal player damage; `--kill` still forces the handoff test. `--noauto` leaves the controlled body stationary for visual inspection. `--lowgfx` can be added to reduce software-renderer cost. `--shots=4 --out=/absolute/existing/directory` records engine frames. Diagnostic flags are optional and not needed to play.


## Chapter III update

The mounted commander chapter is now implemented. See `CHAPTER_III.md` for its separate controls, formation rules, art provenance, and completed integration checks. The earlier scope notes above describe the first polish pass.
