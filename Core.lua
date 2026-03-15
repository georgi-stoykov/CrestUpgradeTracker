-- CrestUpgradeTracker: Core
-- Handles event registration, inventory scanning, and watermark data management.

local WT = CUT_Addon

-- ─── Database Initialization ───────────────────────────────────────────────

local function InitDB()
    if not CrestUpgradeTrackerDB then
        CrestUpgradeTrackerDB = {}
    end
    if not CrestUpgradeTrackerDB.watermarks then
        CrestUpgradeTrackerDB.watermarks = {}
    end
end

-- ─── Watermark Read / Write ────────────────────────────────────────────────

--- Returns the effective watermark ilvl for a given slot.
--- For dual-slot pairs (rings, trinkets, one-handers) this is the SECOND-highest
--- raw ilvl across both slots, matching Blizzard's High Watermark rules.
function WT.GetWatermark(slotID)
    local db = CrestUpgradeTrackerDB.watermarks
    local partner = WT.DUAL_SLOT_PAIRS[slotID]
    if partner then
        local a = db[slotID]  or 0
        local b = db[partner] or 0
        return math.min(a, b)
    end
    return db[slotID] or 0
end

--- Returns the raw per-slot watermark without dual-slot adjustment.
local function GetRaw(slotID)
    return CrestUpgradeTrackerDB.watermarks[slotID] or 0
end

--- Updates the raw watermark for a slot if ilvl is strictly higher.
local function SetRaw(slotID, ilvl)
    if ilvl and ilvl > 0 and ilvl > GetRaw(slotID) then
        CrestUpgradeTrackerDB.watermarks[slotID] = ilvl
    end
end

-- ─── Item Level Helper ─────────────────────────────────────────────────────

--- Returns the effective item level for an ItemLocation, or nil.
local function LocIlvl(itemLoc)
    if not itemLoc or not C_Item.DoesItemExist(itemLoc) then return nil end
    local ilvl = C_Item.GetCurrentItemLevel(itemLoc)
    return (ilvl and ilvl > 0) and ilvl or nil
end

-- ─── Scan Functions ────────────────────────────────────────────────────────

--- Scans all equipped gear and updates per-slot watermarks.
local function ScanEquipped()
    for _, slotID in ipairs(WT.ALL_SLOTS) do
        local loc = ItemLocation:CreateFromEquipmentSlot(slotID)
        local ilvl = LocIlvl(loc)
        if ilvl then
            SetRaw(slotID, ilvl)
        end
    end
end

--- Updates the raw watermarks for a bag/bank item that can fit in multiple slots.
--- Assigns the ilvl to the slot in the pair that currently has the lower watermark,
--- preserving the second-highest guarantee used by GetWatermark().
local function UpdateDualSlot(slots, ilvl)
    local lowestSlot = slots[1]
    local lowestVal  = GetRaw(slots[1])
    for i = 2, #slots do
        local v = GetRaw(slots[i])
        if v < lowestVal then
            lowestSlot = slots[i]
            lowestVal  = v
        end
    end
    SetRaw(lowestSlot, ilvl)
end

--- Scans a single container (bag index) for equippable items.
local function ScanContainer(bagIndex)
    local numSlots = C_Container.GetContainerNumSlots(bagIndex)
    if not numSlots or numSlots == 0 then return end

    for slot = 1, numSlots do
        local link = C_Container.GetContainerItemLink(bagIndex, slot)
        if link then
            local equipLoc = select(9, GetItemInfo(link))
            if equipLoc and equipLoc ~= "" then
                local mappedSlots = WT.EQUIP_LOC_TO_SLOTS[equipLoc]
                if mappedSlots then
                    local loc = ItemLocation:CreateFromBagAndSlot(bagIndex, slot)
                    local ilvl = LocIlvl(loc)
                    if ilvl then
                        if #mappedSlots > 1 then
                            UpdateDualSlot(mappedSlots, ilvl)
                        else
                            SetRaw(mappedSlots[1], ilvl)
                        end
                    end
                end
            end
        end
    end
end

--- Scans all carried bags (backpack + bag slots 1-4).
local function ScanBags()
    for bag = 0, NUM_BAG_SLOTS do
        ScanContainer(bag)
    end
end

--- Scans the main bank container and any attached bank bags.
--- Only runs when the bank frame is open (items are queryable at that point).
local function ScanBank()
    ScanContainer(BANK_CONTAINER)  -- main bank tray (-1)
    for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
        ScanContainer(bag)
    end
end

--- Public: full scan of equipped gear and bags.
function WT.FullScan()
    ScanEquipped()
    ScanBags()
end

-- ─── Slash Command ─────────────────────────────────────────────────────────

--- Finds track and rank for an item level.
local function FindTrackAndRank(ilvl)
    ilvl = tonumber(ilvl)
    if not ilvl then return nil, nil end
    for _, track in ipairs(WT.UPGRADE_TRACKS) do
        for rank, rankIlvl in ipairs(track.ranks) do
            if rankIlvl == ilvl then
                return track, rank
            end
        end
    end
    return nil, nil
end

SLASH_CRESTUPGRADETRACKER1 = "/cut"
SlashCmdList["CRESTUPGRADETRACKER"] = function()
    print("|cff00ccffCrestUpgradeTracker|r — Equipped Gear Status:")

    -- Tally crests needed per track
    local crestTotals = {}  -- keyed by track name
    local upgradeable = 0
    local maxed = 0
    local freeTotal = 0

    for _, slotID in ipairs(WT.ALL_SLOTS) do
        local loc = ItemLocation:CreateFromEquipmentSlot(slotID)
        if loc and C_Item.DoesItemExist(loc) then
            local ilvl = C_Item.GetCurrentItemLevel(loc)
            if ilvl and ilvl > 0 then
                local track, rank = FindTrackAndRank(ilvl)
                if track then
                    local maxRank = #track.ranks
                    local slotName = WT.SLOT_NAMES[slotID] or ("Slot " .. slotID)
                    local tc = "|cff" .. track.color
                    local watermark = WT.GetWatermark(slotID)

                    if rank >= maxRank then
                        maxed = maxed + 1
                        print(string.format("  %s[%s]|r %s%s %d/%d|r |cff00ff00Maxed|r",
                            tc, slotName, tc, track.name, rank, maxRank))
                    else
                        -- Count free upgrades
                        local free = 0
                        for r = rank + 1, maxRank do
                            if watermark >= track.ranks[r] then
                                free = free + 1
                            else
                                break
                            end
                        end
                        local remaining = maxRank - rank
                        local paid = remaining - free
                        local cost = paid * track.crestCost
                        freeTotal = freeTotal + free
                        upgradeable = upgradeable + 1

                        if not crestTotals[track.name] then
                            crestTotals[track.name] = { cost = 0, color = track.color, crestName = track.crestName, currencyID = track.currencyID }
                        end
                        crestTotals[track.name].cost = crestTotals[track.name].cost + cost

                        local statusStr
                        if free >= remaining then
                            statusStr = "|cff00ff00FREE to max|r"
                        elseif free > 0 then
                            statusStr = string.format("|cff00ff00%d free|r, |cffffcc00%d %s|r", free, cost, track.crestName)
                        else
                            statusStr = string.format("|cffffcc00%d %s|r", cost, track.crestName)
                        end
                        print(string.format("  %s[%s]|r %s%s %d/%d|r %s",
                            tc, slotName, tc, track.name, rank, maxRank, statusStr))
                    end
                end
            end
        end
    end

    -- Summary
    print(" ")
    print("|cff00ccff--- Summary ---|r")
    print(string.format("  |cff00ff00%d|r maxed, |cffffcc00%d|r upgradeable, |cff00ff00%d|r free upgrades available", maxed, upgradeable, freeTotal))

    local hasCosts = false
    for _, track in ipairs(WT.UPGRADE_TRACKS) do
        local info = crestTotals[track.name]
        if info and info.cost > 0 then
            local ci = C_CurrencyInfo.GetCurrencyInfo(info.currencyID)
            local displayName = (ci and ci.name) or info.crestName
            local owned = (ci and ci.quantity) or 0
            print(string.format("  |cff%s%s|r: |cffffcc00%d|r needed (have |cffffffff%d|r)",
                info.color, displayName, info.cost, owned))
            hasCosts = true
        end
    end
    if not hasCosts and upgradeable > 0 then
        print("  All remaining upgrades are |cff00ff00FREE|r!")
    end
end

-- ─── Event Handler ─────────────────────────────────────────────────────────

local frame = CreateFrame("Frame", "CUT_AddonFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("BANKFRAME_OPENED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "CrestUpgradeTracker" then
            InitDB()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        WT.FullScan()

    elseif event == "BAG_UPDATE_DELAYED" then
        ScanBags()

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- arg1 = slot ID that changed; re-scan just that slot.
        local slotID = arg1
        if slotID then
            local loc = ItemLocation:CreateFromEquipmentSlot(slotID)
            local ilvl = LocIlvl(loc)
            if ilvl then
                SetRaw(slotID, ilvl)
            end
        end

    elseif event == "BANKFRAME_OPENED" then
        ScanBank()
    end
end)
