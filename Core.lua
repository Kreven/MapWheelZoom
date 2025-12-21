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

    -- Restoration and zoom text updates
    WorldMapFrame:HookScript("OnShow", function()
        lastShowTime = GetTime()
        UpdateZoomText()
        
        -- Apply side bar opacity
        if WorldMapFrame.BlackoutFrame and MapWheelZoomDB then
            if MapWheelZoomDB.overrideSideBarOpacity then
                WorldMapFrame.BlackoutFrame:SetAlpha(MapWheelZoomDB.blackBarOpacity / 100)
            else
                WorldMapFrame.BlackoutFrame:SetAlpha(1.0)
            end
        end
        
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
    
    -- Feature: Map side bars (blackout frame) control
    if WorldMapFrame.BlackoutFrame then
        hooksecurefunc(WorldMapFrame.BlackoutFrame, "Show", function(self)
            if MapWheelZoomDB then
                if MapWheelZoomDB.overrideSideBarOpacity then
                    self:SetAlpha(MapWheelZoomDB.blackBarOpacity / 100)
                else
                    self:SetAlpha(1.0)
                end
            end
        end)
        
        -- Initial apply
        if MapWheelZoomDB.overrideSideBarOpacity then
            WorldMapFrame.BlackoutFrame:SetAlpha(MapWheelZoomDB.blackBarOpacity / 100)
        else
            WorldMapFrame.BlackoutFrame:SetAlpha(1.0)
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", Init)
