-- CrestUpgradeTracker: Tooltip
-- Injects watermark and crest discount info onto item tooltips.

local WT = CUT_Addon

-- ─── Helpers ───────────────────────────────────────────────────────────────

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

--- Reads the effective item level from the tooltip's own "Item Level" line.
local function GetIlvlFromTooltip(tooltip)
    local name = tooltip:GetName()
    if not name then return nil end
    for i = 2, tooltip:NumLines() do
        local fontStr = _G[name .. "TextLeft" .. i]
        if fontStr then
            local text = fontStr:GetText()
            if text then
                local ilvl = text:match("Item Level (%d+)")
                if ilvl then return tonumber(ilvl) end
            end
        end
    end
    return nil
end

--- Parses the "Upgrade Level: TrackName X/Y" line from the tooltip.
--- Returns trackName, currentRank, maxRank or nil if not found.
local function GetUpgradeInfoFromTooltip(tooltip)
    local name = tooltip:GetName()
    if not name then return nil end
    for i = 2, tooltip:NumLines() do
        local fontStr = _G[name .. "TextLeft" .. i]
        if fontStr then
            local text = fontStr:GetText()
            if text then
                local trackName, cur, max = text:match("Upgrade Level: (%a+) (%d+)/(%d+)")
                if trackName then
                    return trackName, tonumber(cur), tonumber(max)
                end
            end
        end
    end
    return nil
end

--- Finds the upgrade track by name (parsed from tooltip).
local function FindTrackByName(trackName)
    for _, track in ipairs(WT.UPGRADE_TRACKS) do
        if track.name == trackName then
            return track
        end
    end
    return nil
end

--- Finds which equipment slot the item occupies (by link comparison).
--- Returns the slot ID, or nil if not found (falls back to mappedSlots[1]).
local function FindEquippedSlotID(link, candidateSlots)
    for _, slotID in ipairs(candidateSlots) do
        if GetInventoryItemLink("player", slotID) == link then
            return slotID
        end
    end
    return nil
end

-- ─── Core Tooltip Logic ────────────────────────────────────────────────────

local function OnItemTooltip(tooltip, data)
    -- Get item link from data or tooltip.
    local link
    if data then
        link = data.hyperlink or data.itemLink or data.link
        if not link and data.id and data.id > 0 then
            link = select(2, GetItemInfo(data.id))
        end
    end
    if not link and tooltip and tooltip.GetItem then
        local _, l = tooltip:GetItem()
        link = l
    end
    if not link then return end

    -- Only equippable gear with a known slot mapping.
    local equipLoc = select(9, GetItemInfo(link))
    if not equipLoc or equipLoc == "" then return end
    local mappedSlots = WT.EQUIP_LOC_TO_SLOTS[equipLoc]
    if not mappedSlots then return end

    -- Read ilvl directly from the tooltip text (most reliable in Midnight).
    local currentIlvl = GetIlvlFromTooltip(tooltip)
    if not currentIlvl or currentIlvl == 0 then return end

    local equippedSlotID    = FindEquippedSlotID(link, mappedSlots)
    local watermarkSlotID   = equippedSlotID or mappedSlots[1]
    local slotName          = WT.SLOT_NAMES[watermarkSlotID] or "Slot"
    -- Build a full item link for watermark API calls.
    -- GetInventoryItemLink (equipped) and tooltip:GetItem() (bag/bank items)
    -- return proper "|cff...|Hitem:...|h[Name]|h|r" links that the API can parse.
    -- data.hyperlink is often a bare "item:..." string the API silently ignores.
    local watermarkLink
    if equippedSlotID then
        watermarkLink = GetInventoryItemLink("player", equippedSlotID)
    elseif tooltip and tooltip.GetItem then
        local _, tLink = tooltip:GetItem()
        watermarkLink = tLink
    end
    if not watermarkLink then watermarkLink = link end
    local watermark         = WT.GetWatermark(watermarkSlotID, watermarkLink)

    -- The game shares watermarks across weapon subtypes (1H sword, 2H staff,
    -- etc. have different ItemRedundancySlots but the game uses the max across
    -- them for free upgrade eligibility). Check equipped items in all candidate
    -- equipment slots and use the highest watermark found.
    for _, sid in ipairs(mappedSlots) do
        local eqLink = GetInventoryItemLink("player", sid)
        if eqLink then
            local eqWM = WT.GetWatermark(sid, eqLink)
            if eqWM > watermark then watermark = eqWM end
        end
    end

    -- ── Identify item's track and rank ─────────────────────────────────────
    -- Prefer parsing the authoritative "Upgrade Level:" line from the tooltip,
    -- which avoids ambiguity when adjacent tracks share the same ilvl.
    local track, rank
    local tooltipTrackName, tooltipRank, tooltipMaxRank = GetUpgradeInfoFromTooltip(tooltip)
    if tooltipTrackName then
        track = FindTrackByName(tooltipTrackName)
        rank  = tooltipRank
    end
    -- Fall back to ilvl-based lookup if tooltip parsing failed.
    if not track then
        track, rank = FindTrackAndRank(currentIlvl)
    end
    if not track then return end

    local maxRank     = #track.ranks
    local ci          = C_CurrencyInfo.GetCurrencyInfo(track.currencyID)
    local crestName   = (ci and ci.name) or track.crestName
    local tc          = "|cff" .. track.color  -- track color prefix

    -- ── Upgrade status line ─────────────────────────────────────────────────
    if rank >= maxRank then
        tooltip:AddLine(
            string.format("%s%s %d/%d|r |cff00ff00- Fully Upgraded|r",
                tc, track.name, rank, maxRank),
            1, 1, 1)
        return
    end

    -- Count how many remaining upgrades are free (covered by watermark)
    local freeUpgrades = 0
    for r = rank + 1, maxRank do
        if watermark >= track.ranks[r] then
            freeUpgrades = freeUpgrades + 1
        else
            break
        end
    end
    local remainingUpgrades = maxRank - rank

    if freeUpgrades >= remainingUpgrades then
        tooltip:AddLine(
            string.format("%s%s %d/%d|r |cff00ff00- Upgrade to max for FREE!|r",
                tc, track.name, rank, maxRank),
            1, 1, 1)
    elseif freeUpgrades > 0 then
        local paidUpgrades = remainingUpgrades - freeUpgrades
        local paidCost = paidUpgrades * track.crestCost
        tooltip:AddLine(
            string.format("%s%s %d/%d|r |cff00ff00- %d free upgrade%s!|r |cffcccccc then %d %s|r",
                tc, track.name, rank, maxRank,
                freeUpgrades, freeUpgrades > 1 and "s" or "",
                paidCost, crestName),
            1, 1, 1)
    else
        local cost = (rank + 1 >= track.crestStartRank) and track.crestCost or 0
        if cost > 0 then
            local totalCost = remainingUpgrades * track.crestCost
            tooltip:AddLine(
                string.format("%s%s %d/%d|r |cffffcc00- Next: %d %s|r |cff888888(%d total to max)|r",
                    tc, track.name, rank, maxRank,
                    cost, crestName,
                    totalCost),
                1, 1, 1)
        else
            tooltip:AddLine(
                string.format("%s%s %d/%d|r |cff00ff00- Next upgrade free|r",
                    tc, track.name, rank, maxRank),
                1, 1, 1)
        end
    end
end

-- ─── Hook Registration ─────────────────────────────────────────────────────
-- TooltipDataProcessor is the only hook we need. It fires exactly once per
-- tooltip build, after all lines are set, so AddLine works without any
-- Show() refresh. OnShow/OnTooltipSetItem hooks were causing a resize loop.

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    local ok, err = pcall(OnItemTooltip, tooltip, data)
    if not ok and tooltip and tooltip.AddLine then
        tooltip:AddLine("|cffff4444[CUT Error] " .. tostring(err) .. "|r", 1, 1, 1)
    end
end)
