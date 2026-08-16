-- QuestieIntegration.lua
-- 1. Hooks Questie to make cluster radius scale-dependent on world map zoom.
-- 2. Keeps Questie icons clipped within map boundaries when zooming and panning.
-- 3. Sets Questie icons to FrameLevel PIN_FRAME_LEVEL_GROUP_MEMBER - 1 (rendering under group members).

local function GetPinFrameLevel(frameLevelType, defaultOffset)
    if WorldMapFrame and WorldMapFrame.GetPinFrameLevelsManager then
        local mgr = WorldMapFrame:GetPinFrameLevelsManager()
        if mgr and mgr.GetValidFrameLevel then
            local lvl = mgr:GetValidFrameLevel(frameLevelType)
            if type(lvl) == "number" and lvl > 0 then
                return lvl
            end
        end
    end

    return 2000 + defaultOffset
end

local function GetQuestieTargetFrameLevel()
    return GetPinFrameLevel("PIN_FRAME_LEVEL_GROUP_MEMBER", 754) - 1
end

local function SetQuestieFrameLevel(frame)
    if not frame or not frame.SetFrameLevel then return end
    if frame.SetFixedFrameLevel then
        frame:SetFixedFrameLevel(false)
    end
    local currentLevel = (frame.GetFrameLevel and frame:GetFrameLevel()) or 2016
    local offset = currentLevel - 2016
    if offset < 0 then offset = 0 end
    local targetLevel = math.min(2750 + offset, 2753)
    frame:SetFrameLevel(targetLevel)
    if frame.SetFixedFrameLevel then
        frame:SetFixedFrameLevel(true)
    end
end

local function FixPinInstance(frame)
    if not frame or frame._mwz_fixed then return end
    
    -- Keep Questie icons at target FrameLevel above TomTom and below group members
    SetQuestieFrameLevel(frame)
    
    -- Override SetParent to redirect all parenting calls to ScrollContainer.Child
    local originalSetParent = frame.SetParent
    frame.SetParent = function(self, newParent)
        if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
            return originalSetParent(self, WorldMapFrame.ScrollContainer.Child)
        else
            return originalSetParent(self, newParent)
        end
    end
    
    -- Force immediate parenting to ScrollContainer.Child and ignore scale
    if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
        originalSetParent(frame, WorldMapFrame.ScrollContainer.Child)
        if frame.SetIgnoreParentScale then
            frame:SetIgnoreParentScale(true)
        end
    end
    
    frame._mwz_fixed = true
end

local isQuestieHooked = false
local function InitQuestieIntegration()
    if isQuestieHooked then return end
    
    if not (Questie and QuestieLoader) then
        return
    end
    
    local MapIconTooltip = QuestieLoader:ImportModule("MapIconTooltip")
    if not (MapIconTooltip and MapIconTooltip.Show) then
        return
    end
    
    -- Hook the Show function to capture zoom scale factor
    local originalShow = MapIconTooltip.Show
    MapIconTooltip.Show = function(self)
        if not self.miniMapIcon and WorldMapFrame and WorldMapFrame.ScrollContainer then
            local scroll = WorldMapFrame.ScrollContainer
            local currentScale = scroll:GetCanvasScale()
            local minScale = scroll:GetScaleForMinZoom()
            local scaleFactor = currentScale / minScale
            
            self._mwz_scaleFactor = scaleFactor
        else
            self._mwz_scaleFactor = nil
        end
        
        originalShow(self)
    end
    
    -- Hook QuestieLib:Maxdist to apply scale factor
    local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
    if QuestieLib and QuestieLib.Maxdist then
        local originalMaxdist = QuestieLib.Maxdist
        QuestieLib.Maxdist = function(self, x, y, i, e)
            local dist = originalMaxdist(self, x, y, i, e)
            
            local tooltip = GameTooltip and GameTooltip._owner
            if tooltip then
                local scaleFactor = tooltip._mwz_scaleFactor
                if scaleFactor and scaleFactor > 1 then
                    dist = dist * scaleFactor * scaleFactor
                end
            end
            
            return dist
        end
    end
    
    -- Hook Questie's SetDrawOrder to apply instance-level overrides
    local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
    if QuestieMap and QuestieMap.utils and QuestieMap.utils.SetDrawOrder then
        local originalSetDrawOrder = QuestieMap.utils.SetDrawOrder
        QuestieMap.utils.SetDrawOrder = function(a1, a2)
            local frame = (type(a2) == "table" and a2) or (type(a1) == "table" and a1)
            if not frame then
                return originalSetDrawOrder(a1, a2)
            end

            if not frame.miniMapIcon then
                FixPinInstance(frame)
            end
            
            originalSetDrawOrder(a1, a2)
            
            -- Re-enforce target frame level so Questie icons render just below group members
            if not frame.miniMapIcon then
                SetQuestieFrameLevel(frame)
            end
            
            -- Re-enforce parent after Questie's modifications
            if not frame.miniMapIcon and WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
                frame:SetParent(WorldMapFrame.ScrollContainer.Child)
            end
        end
    end
    
    isQuestieHooked = true
end

local function IsQuestieLoaded()
    return Questie ~= nil or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Questie")) or (IsAddOnLoaded and IsAddOnLoaded("Questie"))
end

if IsQuestieLoaded() then
    C_Timer.After(0.2, InitQuestieIntegration)
end

-- Event router for Questie integration
local questieFrame = CreateFrame("Frame")
questieFrame:RegisterEvent("ADDON_LOADED")
questieFrame:RegisterEvent("PLAYER_LOGIN")
questieFrame:SetScript("OnEvent", function(self, event, addonName)
    if (event == "ADDON_LOADED" and addonName == "Questie") or (event == "PLAYER_LOGIN" and IsQuestieLoaded()) then
        C_Timer.After(0.2, InitQuestieIntegration)
    end
end)
