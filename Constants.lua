-- CrestUpgradeTracker: Constants
-- Static data for equipment slots, dual-slot pairs, and Midnight (12.0) upgrade tracks.
-- Source: Wowhead Midnight gear upgrade guide + Blizzard patch notes.
-- NOTE: Update UPGRADE_TRACKS each Season/major patch if item levels change.

CUT_Addon = CUT_Addon or {}
local WT = CUT_Addon

-- All equippable slot IDs tracked by this addon.
WT.ALL_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }

-- Human-readable slot names, indexed by slot ID.
WT.SLOT_NAMES = {
    [1]  = "Head",
    [2]  = "Neck",
    [3]  = "Shoulder",
    [5]  = "Chest",
    [6]  = "Waist",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [11] = "Finger",
    [12] = "Finger",
    [13] = "Trinket",
    [14] = "Trinket",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
}

-- For these slot pairs, the effective watermark is the SECOND-highest ilvl
-- (i.e. the minimum of the two raw per-slot values), per Blizzard's rules.
-- Maps slot ID -> partner slot ID.
WT.DUAL_SLOT_PAIRS = {
    [11] = 12,  -- Finger 1 <-> Finger 2
    [12] = 11,
    [13] = 14,  -- Trinket 1 <-> Trinket 2
    [14] = 13,
    [16] = 17,  -- Main Hand <-> Off Hand (dual-wield one-handers)
    [17] = 16,
}

-- Maps item equip-location strings (from C_Item.GetItemInfo) to the slot IDs
-- the item can occupy.
WT.EQUIP_LOC_TO_SLOTS = {
    ["INVTYPE_HEAD"]           = { 1 },
    ["INVTYPE_NECK"]           = { 2 },
    ["INVTYPE_SHOULDER"]       = { 3 },
    ["INVTYPE_CHEST"]          = { 5 },
    ["INVTYPE_ROBE"]           = { 5 },
    ["INVTYPE_WAIST"]          = { 6 },
    ["INVTYPE_LEGS"]           = { 7 },
    ["INVTYPE_FEET"]           = { 8 },
    ["INVTYPE_WRIST"]          = { 9 },
    ["INVTYPE_HAND"]           = { 10 },
    ["INVTYPE_FINGER"]         = { 11, 12 },
    ["INVTYPE_TRINKET"]        = { 13, 14 },
    ["INVTYPE_BACK"]           = { 15 },
    ["INVTYPE_2HWEAPON"]       = { 16 },
    ["INVTYPE_WEAPON"]         = { 16, 17 },
    ["INVTYPE_WEAPONMAINHAND"] = { 16 },
    ["INVTYPE_WEAPONOFFHAND"]  = { 17 },
    ["INVTYPE_SHIELD"]         = { 17 },
    ["INVTYPE_HOLDABLE"]       = { 17 },
    ["INVTYPE_RANGED"]         = { 16 },
    ["INVTYPE_RANGEDRIGHT"]    = { 16 },
}

-- Current season identifier — bump this each season to auto-reset watermarks.
WT.CURRENT_SEASON = "Midnight_S1"

-- WoW: Midnight (12.0) Season 1 upgrade track definitions.
-- Source: https://www.wowhead.com/guide/midnight/item-level-gear-upgrades-dawncrests
--
-- ranks[]       : item level at each upgrade rank (index = rank number, 1-6).
-- crestName     : Dawncrest currency display name.
-- currencyID    : in-game currency ID for C_CurrencyInfo lookups.
-- crestCost     : Dawncrests required per rank upgrade (ranks 2-6).
-- crestStartRank: first rank that requires Dawncrests (rank 1 is the base item, free).
--
-- All tracks have 6 ranks and cost 20 Dawncrests per upgrade step (ranks 2-6).
-- Valorstones have been removed in Midnight — Dawncrests are the only currency.
-- Weekly cap: 100 Dawncrests per type.
WT.UPGRADE_TRACKS = {
    {
        name           = "Adventurer",
        color          = "1eff00",   -- green (uncommon)
        crestName      = "Adventurer Dawncrest",
        currencyID     = 3383,
        crestCost      = 20,
        crestStartRank = 2,
        ranks          = { 220, 224, 227, 230, 233, 237 },
    },
    {
        name           = "Veteran",
        color          = "0070dd",   -- blue (rare)
        crestName      = "Veteran Dawncrest",
        currencyID     = 3341,
        crestCost      = 20,
        crestStartRank = 2,
        ranks          = { 233, 237, 240, 243, 246, 250 },
    },
    {
        name           = "Champion",
        color          = "a335ee",   -- purple (epic)
        crestName      = "Champion Dawncrest",
        currencyID     = 3343,
        crestCost      = 20,
        crestStartRank = 2,
        ranks          = { 246, 250, 253, 256, 259, 263 },
    },
    {
        name           = "Hero",
        color          = "ff8000",   -- orange (legendary)
        crestName      = "Hero Dawncrest",
        currencyID     = 3345,
        crestCost      = 20,
        crestStartRank = 2,
        ranks          = { 259, 263, 266, 269, 272, 276 },
    },
    {
        name           = "Myth",
        color          = "ff4040",   -- red
        crestName      = "Myth Dawncrest",
        currencyID     = 3347,
        crestCost      = 20,
        crestStartRank = 2,
        ranks          = { 272, 276, 279, 282, 285, 289 },
    },
}
