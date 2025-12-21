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
        -- Fallback to default zoom if cursor position cannot be determined
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
