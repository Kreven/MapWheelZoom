-- QuestieIntegration.lua
-- Hooks Questie to make cluster radius scale-dependent on world map zoom

local function InitQuestieIntegration()
    if not (Questie and QuestieLoader) then
        return -- Questie not loaded
    end
    
    local MapIconTooltip = QuestieLoader:ImportModule("MapIconTooltip")
    if not (MapIconTooltip and MapIconTooltip.Show) then
        return -- MapIconTooltip module not found
    end
    
    -- Hook the Show function
    local originalShow = MapIconTooltip.Show
    MapIconTooltip.Show = function(self)
        -- Inject our scale-dependent cluster logic before calling original
        if not self.miniMapIcon and WorldMapFrame and WorldMapFrame.ScrollContainer then
            local scroll = WorldMapFrame.ScrollContainer
            local currentScale = scroll:GetCanvasScale()
            local minScale = scroll:GetScaleForMinZoom()
            local scaleFactor = currentScale / minScale
            
            -- Store the scale factor in the icon data for use by the original function
            -- We'll use this to modify the distance check
            self._mwz_scaleFactor = scaleFactor
        else
            self._mwz_scaleFactor = nil
        end
        
        -- Call original Show function
        originalShow(self)
    end
    
    -- Hook QuestieLib:Maxdist to apply scale factor
    local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
    if QuestieLib and QuestieLib.Maxdist then
        local originalMaxdist = QuestieLib.Maxdist
        QuestieLib.Maxdist = function(self, x, y, i, e)
            local dist = originalMaxdist(self, x, y, i, e)
            
            -- Check if we're in a tooltip context with scale factor
            local tooltip = GameTooltip and GameTooltip._owner
            if tooltip then
                local scaleFactor = tooltip._mwz_scaleFactor
                if scaleFactor and scaleFactor > 1 then
                    -- Use exponentiation for squared factor (more efficient than multiplication)
                    dist = dist * scaleFactor * scaleFactor
                end
            end
            
            return dist
        end
    end
end

-- Initialize when Questie loads
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Questie" then
        -- Delay slightly to ensure Questie is fully initialized
        C_Timer.After(0.5, InitQuestieIntegration)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
