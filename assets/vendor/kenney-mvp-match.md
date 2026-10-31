# Kenney packs vs MVP phases

All three packs are CC0. Credit Kenney (kenney.nl) is optional.
Pirate pack: `assets/vendor/kenney-pirate-pack/` — use `PNG/Default size/`.
Generic items: `assets/vendor/kenney-generic-items/PNG/Colored/`.
UI pack: `assets/vendor/kenney-ui-pack-pixel-adventure/Tiles/Large tiles/Thick outline/`.
Tiles are 32×32 with a 1px gap on the sheet. Use the loose `tile_NNNN.png` files, not the sheet.
Ships are top-down. Do not redraw them side-on. Do not draw sheets. A missing icon stays a text label. These limits are the MVP, not a hole list.

Day is not an icon. Use `tile_0039.png` (cream circle) from the UI pack, next to the day number.

| Phase | Needed | Use now | Still missing |
|---|---|---|---|
| 1 Scaffold | panel, gold, day, food, water | Panel: `tile_0000.png`, NinePatch margin 5. Day: `tile_0039.png` (cream circle) next to the number. Gold `genericItem_color_159.png`, food `114`, water `118` | buttons. The boot screen has no actions |
| 2 Market | sugar, cheese, Madeira, Oslo, market, buy/sell | Market: `genericItem_color_143.png`. Ports: pirate `Ship parts/flag (1).png` and `flag (2).png`. Buttons: UI `tile_0043.png` / `tile_0044.png` / `tile_0045.png`, sideways only. Goods are text | sugar sack, cheese wheel, real banners, pressed, disabled. Accepted |
| 3 Sail | water, horizon, starting hull | Water: pirate `Tiles/tile_73.png`. Hull: `Ships/ship (1).png` | horizon. A flat fill is enough |
| 4 Ship bet | cargo, guns, bunks; gun-heavy hull | Cargo: `genericItem_color_141.png`. Guns: pirate `Ship parts/cannon.png`. Hull: `Ships/ship (5).png` | bunks icon. Text only |
| 5 Crew | navigation, lookout, combat; tavern | Navigation: `genericItem_color_162.png`. Combat: the cannon. Tavern: `genericItem_color_119.png` | lookout icon. Text only |
| 6 Pirate | one pirate sail, Run, Fight | Sail: `Ships/ship (2).png`. Run: red buttons from the market card. Fight: blue `tile_0069.png` / `tile_0070.png` / `tile_0071.png` | nothing |
| 7 Close the lap | used hull, yard, starved, sunk, win | Hull: `hullLarge (2).png`. Yard: `genericItem_color_010.png`. Starved: `101`. Sunk: `Effects/explosion1.png`. Win: `152` | nothing to draw |

Do not pull fort tiles, paths, plants, or the office electronics into the screens.
