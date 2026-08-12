-- MapButton.lua
-- Creates the MWZ icon button on the World Map and the quick settings popover menu.

local popoverFrame
local mapButton
local clickOutsideFrame

-- Helper function to refresh popover controls state
local function RefreshPopoverState()
    if not popoverFrame or not popoverFrame:IsShown() or not MapWheelZoomDB then return end
    
    if popoverFrame.cbRememberZoom then
        popoverFrame.cbRememberZoom:SetChecked(MapWheelZoomDB.rememberZoom)
    end
    
    if popoverFrame.cbSideBar then
        popoverFrame.cbSideBar:SetChecked(MapWheelZoomDB.overrideSideBarOpacity)
    end
    if popoverFrame.sliderSideBar then
        popoverFrame.sliderSideBar:SetValue(MapWheelZoomDB.blackBarOpacity or 65)
        local enabled = MapWheelZoomDB.overrideSideBarOpacity
        popoverFrame.sliderSideBar:SetEnabled(enabled)
        popoverFrame.sliderSideBar:SetAlpha(enabled and 1.0 or 0.4)
    end
    
    if popoverFrame.cbMapWindow then
        popoverFrame.cbMapWindow:SetChecked(MapWheelZoomDB.mapWindowTransparency)
    end
    if popoverFrame.sliderMapWindow then
        popoverFrame.sliderMapWindow:SetValue(MapWheelZoomDB.mapWindowAlpha or 80)
        local enabled = MapWheelZoomDB.mapWindowTransparency
        popoverFrame.sliderMapWindow:SetEnabled(enabled)
        popoverFrame.sliderMapWindow:SetAlpha(enabled and 1.0 or 0.4)
    end
    
    if popoverFrame.cbMoving then
        popoverFrame.cbMoving:SetChecked(MapWheelZoomDB.movingTransparency)
    end
    if popoverFrame.sliderMoving then
        popoverFrame.sliderMoving:SetValue(MapWheelZoomDB.movingAlpha or 40)
        local enabled = MapWheelZoomDB.movingTransparency
        popoverFrame.sliderMoving:SetEnabled(enabled)
        popoverFrame.sliderMoving:SetAlpha(enabled and 1.0 or 0.4)
    end

    if popoverFrame.cbCloseOnCombat then
        popoverFrame.cbCloseOnCombat:SetChecked(MapWheelZoomDB.closeOnCombat)
    end
    if popoverFrame.cbAutoSwitchZone then
        popoverFrame.cbAutoSwitchZone:SetChecked(MapWheelZoomDB.autoSwitchZone)
    end
end

-- Global function to update map button visibility from Settings
function MapWheelZoom_UpdateMapButtonVisibility()
    if not mapButton then return end
    if not MapWheelZoomDB or MapWheelZoomDB.showMapButton ~= false then
        mapButton:Show()
    else
        mapButton:Hide()
        if popoverFrame then popoverFrame:Hide() end
    end
end

local function CreateQuickSettingsPopover()
    if popoverFrame then return popoverFrame end

    -- Click outside overlay frame
    clickOutsideFrame = CreateFrame("Button", "MapWheelZoomClickOutsideFrame", UIParent)
    clickOutsideFrame:SetAllPoints(UIParent)
    clickOutsideFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    clickOutsideFrame:SetFrameLevel(4999)
    clickOutsideFrame:Hide()
    clickOutsideFrame:SetScript("OnClick", function()
        if popoverFrame then popoverFrame:Hide() end
    end)

    -- Main popover container frame
    popoverFrame = CreateFrame("Frame", "MapWheelZoomQuickSettingsFrame", UIParent, "BackdropTemplate")
    popoverFrame:SetSize(235, 365)
    popoverFrame:SetScale(1.20)
    popoverFrame:SetPoint("BOTTOMLEFT", mapButton, "TOPLEFT", 0, 8)
    popoverFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    popoverFrame:SetFrameLevel(5001)
    popoverFrame:SetClampedToScreen(true)
    popoverFrame:EnableMouse(true)
    popoverFrame:SetScript("OnMouseDown", function() end)
    popoverFrame:Hide()

    popoverFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    popoverFrame:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
    popoverFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)

    -- Title Header
    local titleIcon = popoverFrame:CreateTexture(nil, "ARTWORK")
    titleIcon:SetTexture("Interface\\AddOns\\MapWheelZoom\\Art\\Icon")
    titleIcon:SetSize(16, 16)
    titleIcon:SetPoint("TOPLEFT", 12, -12)

    local titleText = popoverFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 6, 0)
    titleText:SetText("MapWheelZoom Settings")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, popoverFrame, "UIPanelCloseButton")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -4, -8)
    closeBtn:SetScript("OnClick", function()
        popoverFrame:Hide()
    end)

    local divider = popoverFrame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\UI-Line-Thin")
    divider:SetPoint("TOPLEFT", 8, -32)
    divider:SetPoint("TOPRIGHT", -8, -32)
    divider:SetHeight(8)
    divider:SetTexCoord(0, 1, 0, 1)

    local currentY = -42

    -- Helper to create checkbuttons inside popover
    local function CreatePopoverCheckbox(label, dbKey, callback)
        local cb = CreateFrame("CheckButton", nil, popoverFrame, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("TOPLEFT", 12, currentY)
        
        cb.text = cb:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.text:SetText(label)
        
        cb:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            MapWheelZoomDB[dbKey] = isChecked
            if callback then callback(isChecked) end
            RefreshPopoverState()
        end)
        
        currentY = currentY - 26
        return cb
    end

    -- Helper to create sliders inside popover
    local sliderIdx = 0
    local function CreatePopoverSlider(dbKey, minVal, maxVal, step, callback)
        sliderIdx = sliderIdx + 1
        local sliderName = "MapWheelZoomPopoverSlider" .. sliderIdx
        local sliderFrame = CreateFrame("Frame", nil, popoverFrame)
        sliderFrame:SetSize(226, 32)
        sliderFrame:SetPoint("TOPLEFT", 12, currentY)
        sliderFrame:EnableMouse(true)
        sliderFrame:SetScript("OnMouseDown", function() end)

        local slider = CreateFrame("Slider", sliderName, sliderFrame, "BackdropTemplate, OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 12, 0)
        slider:SetSize(160, 14)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step or 5)
        slider:SetObeyStepOnDrag(true)

        slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 }
        })

        _G[sliderName .. 'Low']:Hide()
        _G[sliderName .. 'High']:Hide()

        local valText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        valText:SetPoint("LEFT", slider, "RIGHT", 8, 0)

        local function UpdateText(val)
            valText:SetText(val .. "%")
        end

        slider:SetScript("OnValueChanged", function(self, value)
            local val = math.floor(value + 0.5)
            if step then
                val = math.floor(val / step + 0.5) * step
            end
            MapWheelZoomDB[dbKey] = val
            UpdateText(val)
            if callback then callback(val) end
        end)

        currentY = currentY - 32
        return slider
    end

    -- 1. Remember Zoom
    popoverFrame.cbRememberZoom = CreatePopoverCheckbox("Remember zoom level", "rememberZoom")

    -- 2. Side Bar Transparency
    popoverFrame.cbSideBar = CreatePopoverCheckbox("Set background transparency", "overrideSideBarOpacity", function(checked)
        if WorldMapFrame.BlackoutFrame then
            if checked then
                WorldMapFrame.BlackoutFrame:SetAlpha(MapWheelZoomDB.blackBarOpacity / 100)
            else
                WorldMapFrame.BlackoutFrame:SetAlpha(1.0)
            end
        end
    end)

    popoverFrame.sliderSideBar = CreatePopoverSlider("blackBarOpacity", 0, 100, 5, function(val)
        if WorldMapFrame.BlackoutFrame and MapWheelZoomDB.overrideSideBarOpacity then
            WorldMapFrame.BlackoutFrame:SetAlpha(val / 100)
        end
    end)

    -- 3. Map Window Transparency
    popoverFrame.cbMapWindow = CreatePopoverCheckbox("Map window transparency", "mapWindowTransparency", function(checked)
        if WorldMapFrame and WorldMapFrame:IsShown() then
            WorldMapFrame:SetAlpha(checked and (MapWheelZoomDB.mapWindowAlpha / 100) or 1.0)
        end
    end)

    popoverFrame.sliderMapWindow = CreatePopoverSlider("mapWindowAlpha", 10, 100, 5, function(val)
        if WorldMapFrame and WorldMapFrame:IsShown() and MapWheelZoomDB.mapWindowTransparency then
            WorldMapFrame:SetAlpha(val / 100)
        end
    end)

    -- 4. Moving Transparency
    popoverFrame.cbMoving = CreatePopoverCheckbox("Transparency while moving", "movingTransparency", function(checked)
        if MapWheelZoom_UpdateMapAlpha then
            MapWheelZoom_UpdateMapAlpha()
        end
    end)

    popoverFrame.sliderMoving = CreatePopoverSlider("movingAlpha", 10, 100, 5, function(val)
        if MapWheelZoom_UpdateMapAlpha then
            MapWheelZoom_UpdateMapAlpha()
        end
    end)

    -- 5. Close Map On Combat
    popoverFrame.cbCloseOnCombat = CreatePopoverCheckbox("Close map on combat", "closeOnCombat")

    -- 6. Auto-switch Map On Zone Change
    popoverFrame.cbAutoSwitchZone = CreatePopoverCheckbox("Auto-switch map on zone change", "autoSwitchZone")

    -- Bottom Divider
    currentY = currentY - 4
    local btmDivider = popoverFrame:CreateTexture(nil, "ARTWORK")
    btmDivider:SetTexture("Interface\\Buttons\\UI-Line-Thin")
    btmDivider:SetPoint("TOPLEFT", 8, currentY)
    btmDivider:SetPoint("TOPRIGHT", -8, currentY)
    btmDivider:SetHeight(8)

    currentY = currentY - 14

    -- Settings Button
    local settingsBtn = CreateFrame("Button", nil, popoverFrame, "UIPanelButtonTemplate")
    settingsBtn:SetSize(100, 20)
    settingsBtn:SetPoint("TOP", 0, currentY)
    settingsBtn:SetText("Settings")
    settingsBtn:SetScript("OnClick", function()
        popoverFrame:Hide()
        if WorldMapFrame and WorldMapFrame:IsShown() then
            HideUIPanel(WorldMapFrame)
        end
        if MapWheelZoom_OpenSettings then
            MapWheelZoom_OpenSettings()
        end
    end)

    popoverFrame:SetScript("OnShow", function()
        RefreshPopoverState()
        if clickOutsideFrame then clickOutsideFrame:Show() end
    end)

    popoverFrame:SetScript("OnHide", function()
        if clickOutsideFrame then clickOutsideFrame:Hide() end
    end)

    WorldMapFrame:HookScript("OnHide", function()
        popoverFrame:Hide()
    end)

    return popoverFrame
end

local function InitMapButton()
    if mapButton then return end
    if not WorldMapFrame then return end

    -- Create MWZ Map Button anchored above zoom text (zoom text at 20, 10)
    mapButton = CreateFrame("Button", "MapWheelZoomMapButton", WorldMapFrame)
    mapButton:SetSize(22, 22)
    mapButton:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMLEFT", 20, 32)
    mapButton:SetFrameStrata("FULLSCREEN_DIALOG")
    mapButton:SetFrameLevel(5000)

    local icon = mapButton:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetTexture("Interface\\AddOns\\MapWheelZoom\\Art\\Icon")
    icon:SetAllPoints(mapButton)
    mapButton.icon = icon

    local highlight = mapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(mapButton)

    mapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine("MapWheelZoom", 1, 1, 1)
        GameTooltip:AddLine("Click to open quick settings", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    mapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    mapButton:SetScript("OnClick", function()
        local pop = CreateQuickSettingsPopover()
        if pop:IsShown() then
            pop:Hide()
        else
            pop:Show()
        end
    end)

    local function ReassertMapButton()
        if not mapButton then return end
        MapWheelZoom_UpdateMapButtonVisibility()
        if mapButton and mapButton:IsShown() then
            mapButton:ClearAllPoints()
            mapButton:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMLEFT", 20, 32)
            mapButton:SetFrameStrata("FULLSCREEN_DIALOG")
            mapButton:SetFrameLevel(5000)
        end
    end

    local function OnMapModeChange()
        ReassertMapButton()
        if popoverFrame and popoverFrame:IsShown() then
            popoverFrame:Hide()
        end
    end

    WorldMapFrame:HookScript("OnShow", OnMapModeChange)
    WorldMapFrame:HookScript("OnSizeChanged", ReassertMapButton)

    if WorldMapFrame.SetMaximized then
        hooksecurefunc(WorldMapFrame, "SetMaximized", function()
            C_Timer.After(0.01, OnMapModeChange)
        end)
    end
    if WorldMapFrame.SetMinimized then
        hooksecurefunc(WorldMapFrame, "SetMinimized", function()
            C_Timer.After(0.01, OnMapModeChange)
        end)
    end

    ReassertMapButton()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "MapWheelZoom" then
        InitMapButton()
    elseif event == "PLAYER_LOGIN" then
        InitMapButton()
    end
end)

if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MapWheelZoom") then
    InitMapButton()
elseif IsAddOnLoaded and IsAddOnLoaded("MapWheelZoom") then
    InitMapButton()
end

