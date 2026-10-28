local _, core = ...;
------------------------------------------------------------------
-- Equipment item rarity borders
------------------------------------------------------------------

local ECSRarityBorders = {}

local ECSEquipmentSlots = {
    { button = "CharacterHeadSlot",         slot = "HeadSlot" },
    { button = "CharacterNeckSlot",         slot = "NeckSlot" },
    { button = "CharacterShoulderSlot",     slot = "ShoulderSlot" },
    { button = "CharacterBackSlot",         slot = "BackSlot" },
    { button = "CharacterChestSlot",        slot = "ChestSlot" },
    { button = "CharacterShirtSlot",        slot = "ShirtSlot" },
    { button = "CharacterTabardSlot",       slot = "TabardSlot" },
    { button = "CharacterWristSlot",        slot = "WristSlot" },
    { button = "CharacterHandsSlot",        slot = "HandsSlot" },
    { button = "CharacterWaistSlot",        slot = "WaistSlot" },
    { button = "CharacterLegsSlot",         slot = "LegsSlot" },
    { button = "CharacterFeetSlot",         slot = "FeetSlot" },
    { button = "CharacterFinger0Slot",      slot = "Finger0Slot" },
    { button = "CharacterFinger1Slot",      slot = "Finger1Slot" },
    { button = "CharacterTrinket0Slot",     slot = "Trinket0Slot" },
    { button = "CharacterTrinket1Slot",     slot = "Trinket1Slot" },
    { button = "CharacterMainHandSlot",     slot = "MainHandSlot" },
    { button = "CharacterSecondaryHandSlot", slot = "SecondaryHandSlot" },
    { button = "CharacterRangedSlot",       slot = "RangedSlot" },
}

local function ECSGetItemQuality(slotID)
    if GetInventoryItemQuality then
        local quality = GetInventoryItemQuality("player", slotID)
        if quality ~= nil then
            return quality
        end
    end

    local link = GetInventoryItemLink("player", slotID)
    if link and GetItemInfo then
        local _, _, quality = GetItemInfo(link)
        return quality
    end

    return nil
end

local function ECSUpdateRarityBorders()
    for _, entry in ipairs(ECSEquipmentSlots) do
        local border = ECSRarityBorders[entry.button]

        if border then
            local slotID = GetInventorySlotInfo(entry.slot)
            local quality = slotID and ECSGetItemQuality(slotID)

            if quality ~= nil and GetItemQualityColor then
                local r, g, b = GetItemQualityColor(quality)
                border:SetBackdropBorderColor(r, g, b, 1)
                border:Show()
            else
                border:Hide()
            end
        end
    end
end

local function ECSCreateRarityBorders()
    for _, entry in ipairs(ECSEquipmentSlots) do
        local slotButton = getglobal(entry.button)

        if slotButton and not ECSRarityBorders[entry.button] then
            local border = CreateFrame("Frame", nil, slotButton)

            border:SetPoint("TOPLEFT", slotButton, "TOPLEFT", 1, -1)
            border:SetPoint("BOTTOMRIGHT", slotButton, "BOTTOMRIGHT", -1, 1)
            border:SetFrameLevel(slotButton:GetFrameLevel() + 2)

            border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
                insets = {
                    left = 3,
                    right = 3,
                    top = 3,
                    bottom = 3,
                },
            })

            ECSRarityBorders[entry.button] = border
            border:Hide()
        end
    end

    ECSUpdateRarityBorders()
end

local ECSRarityEventFrame = CreateFrame("Frame")
ECSRarityEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
ECSRarityEventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")

ECSRarityEventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        ECSCreateRarityBorders()
    elseif event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then
        ECSUpdateRarityBorders()
    end
end)
