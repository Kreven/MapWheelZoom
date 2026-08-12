local addonName = ...
local settingsCategory

-- Default settings
local defaults = {
    showZoomText = false,
    showMapButton = true,
    rememberZoom = true,
    closeOnCombat = false,
    autoSwitchZone = false,
    overrideSideBarOpacity = false,
    blackBarOpacity = 65,
    mapWindowTransparency = false,
    mapWindowAlpha = 80,
    movingTransparency = false,
    movingAlpha = 40,
}

-- Initialize saved variables and create settings panel
EventUtil.ContinueOnAddOnLoaded(addonName, function()
    MapWheelZoomDB = MapWheelZoomDB or {}
    
    -- Apply defaults for missing values
    for k, v in pairs(defaults) do
        if MapWheelZoomDB[k] == nil then
            MapWheelZoomDB[k] = v
        end
    end
    
    -- Initialize zoom persistence variables
    MapWheelZoomDB.savedZoom = MapWheelZoomDB.savedZoom or {}
    
    -- Create options panel using Settings API
    local optionsFrame = CreateFrame("Frame", nil, nil, "VerticalLayoutFrame")
    optionsFrame.spacing = 4
    
    local categoryName = "|TInterface/Addons/MapWheelZoom/Art/Icon:14:14:0:0|t MapWheelZoom"
    local category, layout = Settings.RegisterCanvasLayoutCategory(optionsFrame, categoryName)
    settingsCategory = category
    Settings.RegisterAddOnCategory(category)
    
    local layoutIndex = 0
    local function GetLayoutIndex()
        layoutIndex = layoutIndex + 1
        return layoutIndex
    end
    
    -- Header
    local Header = CreateFrame("Frame", nil, optionsFrame)
    Header:SetSize(150, 50)
    local headerIcon = Header:CreateTexture(nil, "ARTWORK")
    headerIcon:SetTexture("Interface/Addons/MapWheelZoom/Art/Icon")
    headerIcon:SetSize(20, 20)
    headerIcon:SetPoint("TOPLEFT", -2, -14)
    
    local headerText = Header:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    headerText:SetPoint("LEFT", headerIcon, "RIGHT", 6, 0)
    headerText:SetText("MapWheelZoom")
    
    local divider = Header:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("BOTTOMLEFT", -50)
    Header.layoutIndex = GetLayoutIndex()
    Header.bottomPadding = 10
    
    -- Function to create a checkbox with title and sub-text
    local function CreateCheckbox(label, subText, dbKey, callback)
        local cb = CreateFrame("CheckButton", nil, optionsFrame, "SettingsCheckBoxTemplate")
        cb.text = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        cb.text:SetText(label)
        cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 6)
        
        local st = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        st:SetText(subText)
        st:SetPoint("TOPLEFT", cb.text, "BOTTOMLEFT", 0, -2)
        st:SetTextColor(0.6, 0.6, 0.6)
        
        cb:SetSize(21, 20)
        cb.layoutIndex = GetLayoutIndex()
        cb.bottomPadding = 12
        cb:SetHitRectInsets(0, -cb.text:GetWidth(), 0, -10)
        cb.HoverBackground = nil
        cb:SetChecked(MapWheelZoomDB[dbKey])
        cb:SetScript("OnClick", function(self)
            MapWheelZoomDB[dbKey] = not MapWheelZoomDB[dbKey]
            self:SetChecked(MapWheelZoomDB[dbKey])
            if callback then callback(MapWheelZoomDB[dbKey]) end
        end)
        return cb
    end
    
    -- Function to create a slider with title and value display
    local sliderCounter = 0
    local function CreateSlider(label, dbKey, minVal, maxVal, step, callback)
        sliderCounter = sliderCounter + 1
        local sliderFrame = CreateFrame("Frame", nil, optionsFrame)
        sliderFrame:SetSize(400, 50)
        sliderFrame.layoutIndex = GetLayoutIndex()
        --sliderFrame.bottomPadding = 8

        local sliderName = "MapWheelZoomSlider" .. sliderCounter
        local slider = CreateFrame("Slider", sliderName, sliderFrame, "BackdropTemplate, OptionsSliderTemplate")
        slider:SetPoint("LEFT", 25, 20)
        slider:SetSize(280, 16)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step or 1)
        slider:SetObeyStepOnDrag(true)

        -- Proper "track" look using backdrop
        slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 }
        })
        
        -- Text for min/max/current
        _G[sliderName .. 'Low']:ClearAllPoints()
        _G[sliderName .. 'High']:ClearAllPoints()
        _G[sliderName .. 'Low']:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
        _G[sliderName .. 'High']:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
        _G[sliderName .. 'Low']:SetText(minVal .. "%")
        _G[sliderName .. 'High']:SetText(maxVal .. "%")
        
        local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
        
        local function UpdateText(val)
            valueText:SetText(val .. "%")
        end
        
        slider:SetValue(MapWheelZoomDB[dbKey])
        UpdateText(MapWheelZoomDB[dbKey])
        
        slider:SetScript("OnValueChanged", function(self, value)
            local val = math.floor(value + 0.5)
            -- Snap to step
            if step then
                val = math.floor(val / step + 0.5) * step
            end
            
            MapWheelZoomDB[dbKey] = val
            UpdateText(val)
            if callback then callback(val) end
        end)
        
        return sliderFrame
    end
    
    -- Show Zoom Indicator checkbox
    CreateCheckbox(
        "Show zoom text", 
        "Displayed in the bottom-left corner of the map", 
        "showZoomText"
    )

    -- Show Map Button checkbox
    CreateCheckbox(
        "Show map button", 
        "Displayed in the bottom-left corner of the map", 
        "showMapButton",
        function(checked)
            if MapWheelZoom_UpdateMapButtonVisibility then
                MapWheelZoom_UpdateMapButtonVisibility()
            end
        end
    )
    
    -- Remember Zoom checkbox
    CreateCheckbox(
        "Remember zoom", 
        "Map reopens with the same zoom level you set. The zoom resets when the map zone changes", 
        "rememberZoom"
    )
    
    -- Override background transparency checkbox
    CreateCheckbox(
        "Set background transparency", 
        "The black background behind the map will use the transparency level set below", 
        "overrideSideBarOpacity",
        function(checked)
            if WorldMapFrame.BlackoutFrame then
                if checked then
                    WorldMapFrame.BlackoutFrame:SetAlpha(MapWheelZoomDB.blackBarOpacity / 100)
                else
                    WorldMapFrame.BlackoutFrame:SetAlpha(1.0)
                end
            end
        end
    )

    -- Side Bar Opacity slider
    CreateSlider(
        "Side bars transparency",
        "blackBarOpacity",
        0, 100, 5,
        function(val)
            if WorldMapFrame.BlackoutFrame and MapWheelZoomDB.overrideSideBarOpacity then
                WorldMapFrame.BlackoutFrame:SetAlpha(val / 100)
            end
        end
    )

    -- Map window transparency checkbox
    CreateCheckbox(
        "Map window transparency",
        "Makes the entire map window semi-transparent",
        "mapWindowTransparency",
        function(checked)
            if WorldMapFrame and WorldMapFrame:IsShown() then
                WorldMapFrame:SetAlpha(checked and (MapWheelZoomDB.mapWindowAlpha / 100) or 1.0)
            end
        end
    )

    -- Map window opacity slider
    CreateSlider(
        "Map window opacity",
        "mapWindowAlpha",
        10, 100, 5,
        function(val)
            if WorldMapFrame and WorldMapFrame:IsShown() and MapWheelZoomDB.mapWindowTransparency then
                WorldMapFrame:SetAlpha(val / 100)
            end
        end
    )

    -- Moving transparency checkbox
    CreateCheckbox(
        "Transparency while moving",
        "Map becomes more transparent while your character is moving",
        "movingTransparency",
        function(checked)
            if MapWheelZoom_UpdateMapAlpha then
                MapWheelZoom_UpdateMapAlpha()
            end
        end
    )

    -- Moving opacity slider
    CreateSlider(
        "Opacity while moving",
        "movingAlpha",
        10, 100, 5,
        function(val)
            if MapWheelZoom_UpdateMapAlpha then
                MapWheelZoom_UpdateMapAlpha()
            end
        end
    )

    -- Close map on combat checkbox
    CreateCheckbox(
        "Close map on combat", 
        "Automatically closes the map when entering combat, and reopens it when combat ends", 
        "closeOnCombat"
    )

    -- Auto-switch map on zone change checkbox
    CreateCheckbox(
        "Auto-switch map on zone change", 
        "Automatically updates the map to your current zone when moving into a new area", 
        "autoSwitchZone"
    )
    
    optionsFrame:Layout()
end)

function MapWheelZoom_OpenSettings()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        HideUIPanel(WorldMapFrame)
    end
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

-- Slash command to open settings
SLASH_MAPWHEELZOOM1 = "/mwz"
SLASH_MAPWHEELZOOM2 = "/mapwheelzoom"
SlashCmdList["MAPWHEELZOOM"] = function(msg)
    MapWheelZoom_OpenSettings()
end


