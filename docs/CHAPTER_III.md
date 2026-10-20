# Chapter III — Bellacourt

Bellacourt is a fictional late-medieval European walled burgh. This chapter changes the role: your mounted marshal commands companies rather than performing personal melee combos. Eight allied companies (220 troops plus the marshal) face nine defending companies (248 troops).

## Start

Open `project.godot` with standard Godot 4.5.1 or newer and press F5. On the title, press **3** or click **COMMAND BELLACOURT**. The third campaign-atlas entry also launches this chapter. No prior chapter victory is required.

## Orders

| Input | Action |
| --- | --- |
| Click a friendly soldier or a bottom company card | Select that company |
| Left drag | Select companies touched by the selection box |
| Shift + select | Add companies to the selection |
| G | Select the entire allied host |
| Right click | Move selected companies, keeping them as independent formations |
| Right drag | Set destination and final facing; preview actual formation slots |
| Shift + right click | Queue another route or destination |
| Z, then right click | Attack-move |
| C, then right click | Charge; cavalry uses the wedge |
| X | Halt, clear waypoints and hold; spear schiltrons brace |
| 1 / 2 / 3 / 4 / 5 | Line / column / schiltron / wedge / loose |
| Tab | Pause the field while issuing orders; press again to resume |
| F / V | Toggle archer fire-at-will / order a targeted volley |
| R | Rally companies within 420 world units of your marshal; 35-second cooldown |
| WASD | Ride the marshal |
| Arrows / middle drag | Pan the camera |
| Mouse wheel / M | Zoom / overview |
| Space | Follow the marshal |
| Click the minimap | Move the camera to that area |
| Right click the minimap | Send a company order to that area |
| H / Esc | Field book / pause menu |
| F2 / F11 | Hide troop shadow work / fullscreen |

## Formations have different jobs

- **Line**: broad frontage for foot troops and coordinated melee. Cohesion gives directional protection; the rear remains exposed.
- **Column**: a narrower marching order for gates and crooked streets. Reform before engaging across a broad frontage.
- **Schiltron**: spear troops only. A dense spear body with outward-facing outer ranks when stationary. Halt it with X to brace. A cohesive braced block arrests an incoming horse charge and counters it with spear damage. Its density is a liability under arrows.
- **Wedge**: cavalry only. Several ranks concentrate behind the leading riders. A charge gives a temporary attack and speed advantage, scaled by cohesion. Do not drive it into formed spears.
- **Loose**: archers only. More spacing and a wider deployment. Bows require range and a clear line of sight for a commanded volley; the 18-second volley cooldown is per company.

The interface dims formations that are not compatible with the selected troop type. With several companies selected, a formation change affects only compatible companies.

## Command the ground

West Gate, Market Cross and Guildhall begin in enemy hands. A local numerical advantage of at least two soldiers moves capture progress. Taking an enemy-held ward from full enemy control takes about 20 seconds of uncontested local pressure. Secure all three and keep them for 18 seconds. Reducing the defenders below nine active soldiers also ends resistance.

Your marshal does not use personal attack combos or horse trample in this chapter. His presence steadies nearby troops; his rally can restore a wavering company. If he falls, the chapter is lost. Companies also lose morale when they take casualties; badly depleted or broken companies rout. Keep reserves, preserve frontage, and move bows behind your foot troops. Enemy cavalry seeks a vulnerable rear, while garrisons defend the wards.

The low wall circuit has a main west gate, a south-west postern, a south gate, a north gate and an east opening. These are open passages, not the giant breach-and-ladder objective from Chapter I. Buildings are solid at their foundations, and their roofs fade when they would hide the marshal or selected formations. The river edge blocks movement outside the bridge approach.

## An opening to try

1. Select one spear company and the foot company. Use columns to advance toward West Gate.
2. Halt and reform once inside the approach. Keep one spear company braced if the Crown's horse appears.
3. Move bows up behind the foot line, keeping a clear shot along the street.
4. Send the cavalry through the south-west postern instead of crowding the main entry.
5. Use Tab to place the next set of orders, then resume and watch cohesion before committing the reserves.

## The painted city

Eight original raster paintings provide the ground, townhouses, artisan cottages, market, chapel, guildhall, orchard and modest wall. The game combines them into 32 building clusters and ten orchard groups around irregular streets. The town is assembled in Godot with depth sorting; foundations and navigation are separate from the artwork. The original PNGs are in `assets/chapter3/`. The complete prompt set and generator mode are in `ART_GENERATION_PROMPTS.json`.

`../screenshots/bellacourt_painted_city.png` is a 2160 × 1620 render of the actual assembled scene. It is provided along with gameplay screenshots.

## Historical basis and game scale

These are historically inspired battlefield roles, with game-scale numbers and simplified command. There was no single universal medieval drill system that made every army use identical geometry.

The spear-body concept follows Historic Environment Scotland's account of trained schiltrons at Bannockburn, including their ability to hold against cavalry. The game's stationary outward-facing brace, cohesion percentage, arrow modifier, movement speeds and charge bonus are gameplay rules, not measured historical constants. The cavalry wedge and the other layouts are readable tactical representations rather than a reconstruction of one documented army's exact ranks or intervals.

References used for formation design context:

- Historic Environment Scotland, *Battle of Bannockburn*, battlefield inventory: https://portal.historicenvironment.scot/apex/f?p=1505:300:::::VIEWTYPE,VIEWREF:designation,BTL4
- Historic Environment Scotland, *Three Things About the Battle of Bannockburn*: https://blog.historicenvironment.scot/2025/06/three-things-about-the-battle-of-bannockburn/
- *European Warfare, 1350–1750*, “Tactics and the face of battle,” Cambridge University Press: https://www.cambridge.org/core/books/european-warfare-13501750/tactics-and-the-face-of-battle/6FFD1880BD759639D22BEE366BB394C1

## Validation and limits

The chapter was imported and run in Godot 4.5.1. Tests exercised the mounted marshal, company-card and soldier selection, queued orders, compatible formations, braced spear collisions against cavalry, planning pause, and navigation through three street routes. A live automated advance produced completed routes, melee and casualties. An arranged integration state verified the three capture transitions and hold-victory logic. The title's keyboard shortcut was driven into the actual Chapter III scene. Chapter I also started and fought after the shared pause fix.

The full chapter has not had a long human balance pass or a hardware performance certification. Tests used software OpenGL under a virtual display. The engine sometimes reports a V-Sync availability or ObjectDB cleanup warning at shutdown. Final integration checks completed without script errors or failed assertions. New company command uses keyboard and mouse; the new interface is not mapped to a controller.

Diagnostic runs:

```
godot --path . -- --autotest --level=commander_city --commander-test --len=15
godot --path . -- --autotest --level=commander_city --commander-autoplay --len=60
godot --path . -- --autotest --level=commander_city --objective-test --len=12
godot --path . -- --autotest --title --test-chapter3-entry --len=12
```

The objective test uses an arranged near-capture state to verify the end condition quickly. Autoplay is a diagnostic script and is not used during normal play.
