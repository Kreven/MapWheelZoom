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
    
    local cursorX, cursorY = scroll:GetNormalizedCursorPosition()
    
    if cursorX and cursorY and (cursorX >= 0 and cursorX <= 1 and cursorY >= 0 and cursorY <= 1) then
        local oldScrollX = scroll:GetNormalizedHorizontalScroll()
        local oldScrollY = scroll:GetNormalizedVerticalScroll()
        
        -- Cache repeated calculations
        local cursorOffset = cursorX - 0.5
        local cursorOffsetY = cursorY - 0.5
        local oldViewportSize = 1 / currentScale
        local newViewportSize = 1 / newScale
        
        -- Calculate world position under cursor
        local worldX = oldScrollX + cursorOffset * oldViewportSize
        local worldY = oldScrollY + cursorOffsetY * oldViewportSize
        
        -- Calculate new scroll position to keep world point under cursor
        local newScrollX = worldX - cursorOffset * newViewportSize
        local newScrollY = worldY - cursorOffsetY * newViewportSize
        
        -- Set instant zoom (very high lerp = instant)
        scroll.normalizedZoomLerpAmount = 999
        scroll.normalizedPanXLerpAmount = 999
        scroll.normalizedPanYLerpAmount = 999
        
        scroll:SetZoomTarget(newScale)
        
        -- Calculate scroll extents at new scale
        local tempScale = scroll.currentScale
        scroll.currentScale = newScale
        scroll:CalculateScrollExtents()
        scroll.currentScale = tempScale
        
        -- Clamp scroll to valid bounds using math functions
        newScrollX = math.max(scroll.scrollXExtentsMin or 0.5, math.min(newScrollX, scroll.scrollXExtentsMax or 0.5))
        newScrollY = math.max(scroll.scrollYExtentsMin or 0.5, math.min(newScrollY, scroll.scrollYExtentsMax or 0.5))
        
        scroll:SetPanTarget(newScrollX, newScrollY)
    else
        if delta > 0 then
            scroll:ZoomIn()
        else
            scroll:ZoomOut()
        end
    end
end

local function Init()
    if not WorldMapFrame then return end
    local scroll = WorldMapFrame.ScrollContainer
    if not scroll then return end
    
    WorldMapFrame:EnableMouseWheel(true)
    scroll:EnableMouseWheel(true)
    
    scroll.mouseWheelZoomMode = 0 
    
    -- Override max zoom to allow deeper zoom
    local originalGetScaleForMaxZoom = scroll.GetScaleForMaxZoom
    scroll.GetScaleForMaxZoom = function(self)
        return originalGetScaleForMaxZoom(self) * 3
    end
    
    if not WorldMapFrame:GetScript("OnMouseWheel") then
        WorldMapFrame:SetScript("OnMouseWheel", OnMouseWheel)
    else
        WorldMapFrame:HookScript("OnMouseWheel", OnMouseWheel)
    end
    
    -- Override ScrollContainer handler to have full control
    scroll:SetScript("OnMouseWheel", OnMouseWheel)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", Init)
