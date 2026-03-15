# CrestUpgradeTracker — Technical Specification

## Overview

CrestUpgradeTracker (CUT) is a World of Warcraft addon for **Midnight (12.0)** that tracks the **High Watermark** per equipment slot and displays **Dawncrest upgrade cost/discount information** on item tooltips. It also provides a `/cut` slash command with a full gear upgrade summary.

**Version:** 2.0.0
**Interface:** 120001 (WoW Midnight 12.0.1)
**Saved Variable:** `CrestUpgradeTrackerDB` (per-character)

---

## File Structure

```
CrestUpgradeTracker/
├── CrestUpgradeTracker.toc   -- Addon metadata (must match folder name)
├── Constants.lua              -- Static data tables (loaded first)
├── Core.lua                   -- DB, scanning, events, /cut command
├── Tooltip.lua                -- Tooltip injection via TooltipDataProcessor
├── Spec.md                    -- This file
└── README.md                  -- User-facing documentation
```

**Load order** (defined in .toc): Constants.lua → Core.lua → Tooltip.lua

---

## Architecture

### Global Namespace

- `CUT_Addon` — single global table shared across all files via `local WT = CUT_Addon`
- `CrestUpgradeTrackerDB` — SavedVariablesPerCharacter, persists `{ watermarks = { [slotID] = ilvl } }`

### Constants.lua

Defines all static data:

| Table | Purpose |
|---|---|
| `WT.ALL_SLOTS` | Array of all 16 tracked equipment slot IDs |
| `WT.SLOT_NAMES` | `[slotID] → "Head"`, `"Neck"`, etc. |
| `WT.DUAL_SLOT_PAIRS` | `[slotID] → partnerSlotID` for rings (11↔12), trinkets (13↔14), weapons (16↔17) |
| `WT.EQUIP_LOC_TO_SLOTS` | `["INVTYPE_HEAD"] → {1}`, `["INVTYPE_FINGER"] → {11,12}`, etc. |
| `WT.UPGRADE_TRACKS` | Array of 5 track definitions (see below) |

#### Upgrade Track Schema

```lua
{
    name           = "Hero",           -- Display name
    color          = "ff8000",         -- Hex color (no #) for UI display
    crestName      = "Hero Dawncrest", -- Fallback display name
    currencyID     = 3345,             -- C_CurrencyInfo currency ID
    crestCost      = 20,               -- Dawncrests per upgrade step
    crestStartRank = 2,                -- First rank requiring crests
    ranks          = { 259, 263, 266, 269, 272, 276 },  -- ilvl at each rank (1-6)
}
```

**Midnight Season 1 Tracks:**

| Track | Color | Currency ID | Rank 1→6 Item Levels |
|---|---|---|---|
| Adventurer | Green (`1eff00`) | 3383 | 220, 224, 227, 230, 233, 237 |
| Veteran | Blue (`0070dd`) | 3341 | 233, 237, 240, 243, 246, 250 |
| Champion | Purple (`a335ee`) | 3343 | 246, 250, 253, 256, 259, 263 |
| Hero | Orange (`ff8000`) | 3345 | 259, 263, 266, 269, 272, 276 |
| Myth | Red (`ff4040`) | 3347 | 272, 276, 279, 282, 285, 289 |

All tracks: 6 ranks, 20 Dawncrests per upgrade (ranks 2-6), weekly cap 100 per type.

### Core.lua

**Database:**
- `InitDB()` — creates `CrestUpgradeTrackerDB.watermarks` table on first load
- `GetRaw(slotID)` — raw per-slot watermark
- `SetRaw(slotID, ilvl)` — updates if strictly higher (watermarks only go up)
- `WT.GetWatermark(slotID)` — **effective** watermark; for dual-slot pairs returns `math.min(slotA, slotB)` (second-highest rule)

**Scanning:**
- `LocIlvl(itemLoc)` — uses `C_Item.GetCurrentItemLevel(itemLocation)` (the only reliable ilvl API in Midnight)
- `ScanEquipped()` — all 16 equipped slots
- `ScanContainer(bagIndex)` — single bag/bank container
- `ScanBags()` — bags 0 through NUM_BAG_SLOTS
- `ScanBank()` — BANK_CONTAINER + bank bags (only when bank frame is open)
- `UpdateDualSlot(slots, ilvl)` — for multi-slot items (rings, trinkets, 1H weapons), assigns ilvl to the slot with the lower watermark
- `WT.FullScan()` — ScanEquipped + ScanBags (public)

**Events:**

| Event | Action |
|---|---|
| `ADDON_LOADED` (arg1 = "CrestUpgradeTracker") | InitDB |
| `PLAYER_ENTERING_WORLD` | FullScan |
| `BAG_UPDATE_DELAYED` | ScanBags |
| `PLAYER_EQUIPMENT_CHANGED` (arg1 = slotID) | Scan single slot |
| `BANKFRAME_OPENED` | ScanBank |

**Slash Command (`/cut`):**
- Lists every equipped slot with track name (color-coded), rank progress, and upgrade cost
- Summary section: maxed count, upgradeable count, free upgrades, total crests needed per type with current owned quantity

### Tooltip.lua

**Item Level Detection:**
- `GetIlvlFromTooltip(tooltip)` — parses "Item Level XXX" from tooltip text lines
- This is the **only reliable method** in Midnight; `C_Item.GetDetailedItemLevelInfo(link)` and the global `GetDetailedItemLevelInfo(link)` both return incorrect base ilvl values

**Slot Detection:**
- `FindEquippedSlotID(link, candidateSlots)` — compares item link against `GetInventoryItemLink("player", slotID)` for each candidate slot
- Falls back to `mappedSlots[1]` if not found (item in bags, AH, etc.)

**Tooltip Display (color-coded by track):**

| Condition | Display |
|---|---|
| rank = max (6/6) | `Hero 6/6 - Fully Upgraded` (green) |
| All remaining upgrades free | `Hero 3/6 - Upgrade to max for FREE!` (green) |
| Some upgrades free | `Hero 3/6 - 2 free upgrades! then 40 Hero Dawncrest` |
| No discount, has cost | `Hero 3/6 - Next: 20 Hero Dawncrest (60 total to max)` (yellow) |
| No discount, next is free | `Hero 1/6 - Next upgrade free` (green) |

**Hook:** `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)`
- Fires once per tooltip build, after all lines are set
- Wrapped in `pcall` — errors show as `[CUT Error]` line on tooltip instead of crashing

---

## Known API Pitfalls (Midnight 12.0)

These are critical for anyone maintaining this addon:

1. **`C_Item.GetDetailedItemLevelInfo(link)` is BROKEN** — the namespaced version expects `ItemLocation`, not a link string. Returns base ilvl (28, 100) instead of effective upgraded ilvl.

2. **`GetDetailedItemLevelInfo(link)` (global) is ALSO unreliable** — returns incorrect base ilvl in Midnight for upgraded items.

3. **`C_Item.GetCurrentItemLevel(itemLocation)` works correctly** — but requires an `ItemLocation` object (from `CreateFromEquipmentSlot` or `CreateFromBagAndSlot`), not a link.

4. **Tooltip link != Inventory link** — `GetInventoryItemLink("player", slotID)` and tooltip `data.hyperlink` may have different formatting, so direct `==` comparison can fail for slot detection. The addon handles this gracefully by falling back to `mappedSlots[1]`.

5. **`tonumber()` with multi-return functions** — `tonumber(select(1, SomeFunc()))` passes ALL return values. If the second return is a boolean, it becomes `tonumber`'s base argument and errors. Always capture first return in a local.

6. **`OnShow`/`OnTooltipSetItem` hooks cause infinite resize loops** — only use `TooltipDataProcessor.AddTooltipPostCall`.

---

## Updating for a New Season/Patch

### Step 1: Update Interface Version (`.toc`)
Change `## Interface:` to match the new client version (e.g., `120002` for 12.0.2).

### Step 2: Update Upgrade Tracks (`Constants.lua`)
Modify `WT.UPGRADE_TRACKS`:
- Update `ranks` arrays with new item levels per rank
- Update `currencyID` if currency IDs change
- Update `crestName` if the currency is renamed
- Update `crestCost` if cost per upgrade changes
- Add/remove tracks if Blizzard changes the number of quality tiers

### Step 3: Verify API Compatibility
Test that these still work:
- `C_Item.GetCurrentItemLevel(itemLocation)` — for scanning
- `GetIlvlFromTooltip()` — check if "Item Level" text format changed
- `TooltipDataProcessor.AddTooltipPostCall` — tooltip hook
- `C_CurrencyInfo.GetCurrencyInfo(currencyID)` — for crest names/quantities

### Step 4: Bump Version
Update `## Version:` in the `.toc` file.

---

## Color Codes Reference (WoW escape sequences)

```
|cffRRGGBB   — start color (ff = full alpha, RRGGBB = hex color)
|r           — reset to default color
```

Track colors follow WoW quality conventions:
- Green (`1eff00`) = Uncommon → Adventurer
- Blue (`0070dd`) = Rare → Veteran
- Purple (`a335ee`) = Epic → Champion
- Orange (`ff8000`) = Legendary → Hero
- Red (`ff4040`) = Artifact → Myth
