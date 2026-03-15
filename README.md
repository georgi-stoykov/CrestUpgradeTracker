# CrestUpgradeTracker

A lightweight World of Warcraft addon for **Midnight (12.0)** that shows you exactly what it costs to upgrade your gear — right on the item tooltip.

## Features

**Tooltip Integration** — Hover over any equippable item to see:
- Which upgrade track it belongs to (Adventurer / Veteran / Champion / Hero / Myth)
- Current rank and max rank (e.g., Hero 3/6)
- Whether upgrades are **free** thanks to your High Watermark
- Exact Dawncrest cost for remaining upgrades
- Color-coded by track quality

**Upgrade Summary** — Type `/cut` in chat to see:
- Full breakdown of every equipped slot's upgrade status
- How many items are maxed vs. upgradeable
- Total Dawncrests needed per type, and how many you currently own

**Automatic Tracking** — The addon silently tracks your High Watermark by scanning:
- Equipped gear
- Bag contents
- Bank contents (when opened)

No configuration needed. Just install and play.

## What is the High Watermark?

Blizzard's upgrade discount system remembers the highest item level you've had in each gear slot. If you've previously owned a high-ilvl item, upgrading a lower-ilvl replacement in that slot costs fewer (or zero) Dawncrests. For paired slots (rings, trinkets, one-handed weapons), the discount is based on the **second-highest** ilvl across both slots.

## Installation

1. Download and extract into your WoW addons folder:
   ```
   World of Warcraft/_retail_/Interface/AddOns/CrestUpgradeTracker/
   ```
2. Make sure the folder contains: `CrestUpgradeTracker.toc`, `Constants.lua`, `Core.lua`, `Tooltip.lua`
3. Restart WoW or type `/reload`

## Usage

- **Hover** over any piece of gear to see upgrade info on the tooltip
- **Type `/cut`** in chat to see a full summary of your gear and crest needs

## Midnight Season 1 Tracks

| Track | Item Levels (Rank 1→6) | Crest Type |
|---|---|---|
| Adventurer | 220 → 237 | Adventurer Dawncrest |
| Veteran | 233 → 250 | Veteran Dawncrest |
| Champion | 246 → 263 | Champion Dawncrest |
| Hero | 259 → 276 | Hero Dawncrest |
| Myth | 272 → 289 | Myth Dawncrest |

Each upgrade costs 20 Dawncrests. Weekly cap: 100 per type.

## Known Limitations

- **Trinkets and rings** may show incorrect upgrade costs in rare cases. The game groups different item subtypes together for watermark purposes (e.g., all weapons share one watermark), but the API reports them under separate internal slots. The addon cross-checks equipped items to work around this, but if you've previously owned a high-ilvl trinket or ring that is no longer equipped or in your bags, the addon may not detect that watermark and could overstate the upgrade cost. Equipping or carrying your highest-ilvl items in each slot ensures accurate results.
- The `/cut reset` command only clears the addon's internal fallback watermarks. The game's own watermark data (used as the primary source) is unaffected and cannot be reset.

## Requirements

- World of Warcraft: Midnight (12.0.1+)
- No dependencies or libraries required
