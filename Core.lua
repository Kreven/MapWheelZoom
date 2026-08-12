local lastPlayerMapID = nil

local lastShowTime = 0
local function SaveMapState()
    if not MapWheelZoomDB or not MapWheelZoomDB.rememberZoom then return end
    local scroll = WorldMapFrame and WorldMapFrame.ScrollContainer
    if not scroll or not WorldMapFrame:IsShown() then return end
    
    -- Protection: Don't save during the first 0.5s of map opening to avoid capturing auto-resets
    if lastShowTime and (GetTime() - lastShowTime < 0.5) then return end
    
    local scale = scroll:GetCanvasScale()
    local minScale = scroll:GetScaleForMinZoom()
    
    -- Only save if zoomed in (1.05x)
    if scale > minScale * 1.05 then
        MapWheelZoomDB.savedZoom = MapWheelZoomDB.savedZoom or {}
        MapWheelZoomDB.savedZoom.scale = scale
        MapWheelZoomDB.savedZoom.mapID = WorldMapFrame:GetMapID()
        
        -- Store normalized scroll offsets
        local horiz = scroll:GetNormalizedHorizontalScroll() or 0.5
        local vert = scroll:GetNormalizedVerticalScroll() or 0.5
        
        MapWheelZoomDB.savedZoom.centerX = horiz
        MapWheelZoomDB.savedZoom.centerY = vert
    else
        -- Clear state at 100% zoom
        if MapWheelZoomDB.savedZoom and MapWheelZoomDB.savedZoom.scale then
            MapWheelZoomDB.savedZoom = {}
        end
    end
end

local function OnMouseWheel(self, delta)
    local scroll = self.ScrollContainer or (WorldMapFrame and WorldMapFrame.ScrollContainer)
    if not scroll then return end

    local currentScale = scroll:GetCanvasScale()
    local minScale = scroll:GetScaleForMinZoom()
    local maxScale = scroll:GetScaleForMaxZoom()
    
    -- Dynamic zoom speed: faster when zoomed in for quicker navigation
    local scaleFactor = currentScale / minScale
    local zoomAmount = (scroll.zoomAmountPerMouseWheelDelta or 0.075) * 2 * scaleFactor

    local newScale = currentScale
    if delta > 0 then
        newScale = currentScale + zoomAmount
    else
        newScale = currentScale - zoomAmount
    end
    
    if newScale > maxScale then newScale = maxScale end
    if newScale < minScale then newScale = minScale end
    
    if newScale == currentScale then return end
    
    -- Get cursor position
    local cursorX, cursorY = scroll:GetNormalizedCursorPosition()
    
    -- Zoom and pan
    if cursorX and cursorY then
        scroll:InstantPanAndZoom(newScale, cursorX, cursorY)
    else
        if delta > 0 then scroll:ZoomIn() else scroll:ZoomOut() end
    end
    
    SaveMapState()
end

local function Init()
    if not WorldMapFrame then return end
    local scroll = WorldMapFrame.ScrollContainer
    if not scroll then return end
    
    -- Helper to force instant movements by bypassing animations
    local function ApplyInstantSettings()
        scroll.normalizedZoomLerpAmount = 9999
        scroll.normalizedPanXLerpAmount = 9999
        scroll.normalizedPanYLerpAmount = 9999
    end
    
    -- Reset saved zoom on initialization
    if MapWheelZoomDB then
        MapWheelZoomDB.savedZoom = {}
    end
    
    WorldMapFrame:EnableMouseWheel(true)
    scroll:EnableMouseWheel(true)
    
    scroll.mouseWheelZoomMode = 0 
    ApplyInstantSettings()
    
    -- Override max zoom to allow deeper zoom
    local originalGetScaleForMaxZoom = scroll.GetScaleForMaxZoom
    scroll.GetScaleForMaxZoom = function(self)
        return originalGetScaleForMaxZoom(self) * 3
    end

    -- Fix: Anniversary client doesn't render pure black on BlackoutFrame.Blackout texture.
    if WorldMapFrame.BlackoutFrame and WorldMapFrame.BlackoutFrame.Blackout then
        WorldMapFrame.BlackoutFrame.Blackout:SetColorTexture(0.01, 0, 0, 1)
    end

    -- Apply side bar (blackout frame) transparency settings
    local function ApplyBlackoutAlpha()
        if WorldMapFrame.BlackoutFrame and MapWheelZoomDB then
            if MapWheelZoomDB.overrideSideBarOpacity then
                WorldMapFrame.BlackoutFrame:SetAlpha(MapWheelZoomDB.blackBarOpacity / 100)
            else
                WorldMapFrame.BlackoutFrame:SetAlpha(1.0)
            end
        end
    end

    if WorldMapFrame.BlackoutFrame then
        hooksecurefunc(WorldMapFrame.BlackoutFrame, "Show", function()
            ApplyBlackoutAlpha()
        end)
    end

    -- Create zoom text
    local zoomText = WorldMapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoomText:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMLEFT", 20, 10)
    zoomText:SetTextColor(1, 1, 1, 0.8)
    zoomText:Hide()

    -- Update zoom text
    local function UpdateZoomText()
        if not MapWheelZoomDB.showZoomText then
            zoomText:Hide()
            return
        end
        
        if WorldMapFrame:IsShown() then
            local currentScale = scroll:GetCanvasScale()
            local minScale = scroll:GetScaleForMinZoom()
            local zoomPercent = (currentScale / minScale) * 100
            zoomText:SetFormattedText("Map zoom: %.0f%%", zoomPercent)
            zoomText:Show()
        else
            zoomText:Hide()
        end
    end

    -- Map window transparency system with movement detection
    local applyingAlpha = false
    local currentMapAlpha = 1.0
    local ALPHA_LERP_SPEED = 8
    
    local function GetTargetMapAlpha()
        if not MapWheelZoomDB then return 1.0 end
        
        -- Movement transparency takes priority
        local isMoving = GetUnitSpeed("player") > 0
        if isMoving and MapWheelZoomDB.movingTransparency then
            return MapWheelZoomDB.movingAlpha / 100
        end
        
        -- Static transparency
        if MapWheelZoomDB.mapWindowTransparency then
            return MapWheelZoomDB.mapWindowAlpha / 100
        end
        
        return 1.0
    end
    
    local function ForceSetAlpha(alpha)
        applyingAlpha = true
        WorldMapFrame:SetAlpha(alpha)
        applyingAlpha = false
        currentMapAlpha = alpha
    end
    
    -- Prevent Blizzard from silently resetting alpha
    hooksecurefunc(WorldMapFrame, "SetAlpha", function(self, alpha)
        if applyingAlpha then return end
        if not MapWheelZoomDB then return end
        if not WorldMapFrame:IsShown() then return end
        if MapWheelZoomDB.mapWindowTransparency or MapWheelZoomDB.movingTransparency then
            C_Timer.After(0, function()
                if WorldMapFrame:IsShown() then
                    ForceSetAlpha(GetTargetMapAlpha())
                end
            end)
        end
    end)
    
    function MapWheelZoom_UpdateMapAlpha()
        if WorldMapFrame and WorldMapFrame:IsShown() then
            ForceSetAlpha(GetTargetMapAlpha())
        end
    end

    -- Smooth alpha transitions
    WorldMapFrame:HookScript("OnUpdate", function(self, elapsed)
        if not MapWheelZoomDB then return end
        
        local targetAlpha = GetTargetMapAlpha()
        local diff = targetAlpha - currentMapAlpha
        
        if math.abs(diff) > 0.005 then
            currentMapAlpha = currentMapAlpha + diff * math.min(elapsed * ALPHA_LERP_SPEED, 1)
            applyingAlpha = true
            self:SetAlpha(currentMapAlpha)
            applyingAlpha = false
        elseif math.abs(diff) > 0 then
            ForceSetAlpha(targetAlpha)
        end
    end)

    -- Restoration and zoom text updates
    WorldMapFrame:HookScript("OnSizeChanged", UpdateZoomText)
    WorldMapFrame:HookScript("OnShow", function()
        lastShowTime = GetTime()
        UpdateZoomText()
        
        lastPlayerMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        
        -- Set transparency immediately (no fade-in when opening)
        local targetAlpha = GetTargetMapAlpha()
        ForceSetAlpha(targetAlpha)

        -- Apply side bar opacity
        ApplyBlackoutAlpha()
        
        if not MapWheelZoomDB or not MapWheelZoomDB.rememberZoom then return end
        
        local saved = MapWheelZoomDB.savedZoom
        if not saved or not saved.scale or (saved.mapID and saved.mapID ~= WorldMapFrame:GetMapID()) then return end
        
        local minScale = scroll:GetScaleForMinZoom()
        if saved.scale > minScale * 1.05 then
            -- Hide the map content immediately to prevent the 100% zoom blink
            scroll:Hide()
            
            C_Timer.After(0, function()
                if not WorldMapFrame:IsShown() then return end
                -- Ensure the map moves instantly without any sliding
                ApplyInstantSettings()
                
                -- Leatrix Maps Restoration Trick
                scroll:InstantPanAndZoom(saved.scale, saved.centerX or 0.5, saved.centerY or 0.5)
                scroll:SetPanTarget(saved.centerX or 0.5, saved.centerY or 0.5)
                
                -- Force refresh by toggling visibility (this also reveals the scroll)
                scroll:Hide(); scroll:Show()
            end)
        end
    end)
    
    -- Update zoom text when map is hidden
    WorldMapFrame:HookScript("OnHide", function() 
        zoomText:Hide()
        -- Restore full opacity so other frames are unaffected
        ForceSetAlpha(1.0)
    end)
    
    -- Update zoom text when zoom changes
    hooksecurefunc(scroll, "InstantPanAndZoom", UpdateZoomText)
    
    -- Save position ONLY after user-initiated actions (click/drag/scroll)
    -- This prevents Blizzard's internal resets from clearing our data
    scroll:HookScript("OnMouseUp", SaveMapState)
    WorldMapFrame:HookScript("OnMouseUp", SaveMapState)
    
    if not WorldMapFrame:GetScript("OnMouseWheel") then
        WorldMapFrame:SetScript("OnMouseWheel", OnMouseWheel)
    else
        WorldMapFrame:HookScript("OnMouseWheel", OnMouseWheel)
    end
    
    -- Override ScrollContainer handler to have full control
    scroll:SetScript("OnMouseWheel", OnMouseWheel)
    
    -- Initial update
    UpdateZoomText()
    ApplyBlackoutAlpha()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", Init)

-- Auto-close map when entering combat & reopen when combat ends
local wasMapClosedByCombat = false

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    if not MapWheelZoomDB or not MapWheelZoomDB.closeOnCombat then return end

    if event == "PLAYER_REGEN_DISABLED" then
        if WorldMapFrame and WorldMapFrame:IsShown() then
            wasMapClosedByCombat = true
            if HideUIPanel then HideUIPanel(WorldMapFrame) end
            WorldMapFrame:Hide()
        else
            wasMapClosedByCombat = false
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if wasMapClosedByCombat then
            wasMapClosedByCombat = false
            if WorldMapFrame and not WorldMapFrame:IsShown() then
                if ToggleWorldMap then
                    ToggleWorldMap()
                elseif OpenWorldMap then
                    OpenWorldMap()
                elseif ShowUIPanel then
                    ShowUIPanel(WorldMapFrame)
                else
                    WorldMapFrame:Show()
                end
            end
        end
    end
end)

-- Auto-switch map to current zone when moving into a new area
local lastCheckTime = 0
local function CheckZoneChange()
    if not MapWheelZoomDB or not MapWheelZoomDB.autoSwitchZone then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local playerMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not playerMapID or playerMapID <= 0 then return end

    local currentMapID = WorldMapFrame:GetMapID()
    if not currentMapID then return end

    if not lastPlayerMapID then
        lastPlayerMapID = playerMapID
    end

    -- Auto-switch map ONLY if the map currently being viewed is the map where the player is located.
    if currentMapID == lastPlayerMapID or currentMapID == playerMapID then
        if currentMapID ~= playerMapID then
            WorldMapFrame:SetMapID(playerMapID)
        end
    end

    lastPlayerMapID = playerMapID
end

local zoneFrame = CreateFrame("Frame")
zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneFrame:RegisterEvent("ZONE_CHANGED")
zoneFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneFrame:SetScript("OnEvent", CheckZoneChange)

WorldMapFrame:HookScript("OnUpdate", function(self, elapsed)
    if not MapWheelZoomDB or not MapWheelZoomDB.autoSwitchZone then return end
    if GetTime() - lastCheckTime < 1.0 then return end
    lastCheckTime = GetTime()

    if GetUnitSpeed("player") > 0 then
        CheckZoneChange()
    end
end)
