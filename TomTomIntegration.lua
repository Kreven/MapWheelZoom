-- TomTomIntegration.lua
-- 1. Places or removes TomTom waypoints via Ctrl + Left Click on the world map canvas and icons.
-- 2. Automatically extracts titles from active icons' tooltips or uses map coordinates for waypoints.
-- 3. Blocks map zone/layer switching (SetMapID) when Ctrl + Left Click is pressed.

local function GetMapZoneName(mapID)
    if not mapID then return nil end
    local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return mapInfo and mapInfo.name
end

-- Helper to clean text (strip textures, color codes, whitespace)
local function CleanTitleText(text)
    if not text or type(text) ~= "string" or text == "" then return nil end
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:match("^%s*(.-)%s*$")
    if text and text ~= "" and not string.find(text, "^table: ") and not string.find(text, "^Frame%d+$") then
        return text
    end
    return nil
end

-- Helper to extract title from active tooltips
local function GetPinOrTooltipTitle(pinFrame)
    local tooltips = { GameTooltip, _G["TomTomTooltip"], _G["WorldMapTooltip"] }
    for _, tt in ipairs(tooltips) do
        if tt and tt.IsVisible and tt:IsVisible() then
            local ttName = (tt.GetName and tt:GetName()) or "Tooltip"
            local numLines = tt.NumLines and tt:NumLines() or 0
            for i = 1, numLines do
                local line = _G[ttName .. "TextLeft" .. i] or (tt.TextLeft1 and i == 1 and tt.TextLeft1)
                if line and line.GetText and line:GetText() then
                    local clean = CleanTitleText(line:GetText())
                    if clean then return clean end
                end
            end
        end
    end
    return nil
end

-- Find top mouse focus frame under cursor
local function GetCurrentMouseFrame()
    local foci = GetMouseFoci and GetMouseFoci() or (GetMouseFocus and { GetMouseFocus() }) or {}
    for _, f in ipairs(foci) do
        if f and f ~= WorldMapFrame and f ~= WorldMapFrame.ScrollContainer and f ~= (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child) then
            return f
        end
    end
    return nil
end

-- Check if frame is an interactive icon on the active WorldMap
local function IsFrameOnWorldMap(f)
    if not f or type(f) ~= "table" or not f.IsObjectType then return false end
    if not (WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:IsMouseOver()) then return false end
    
    if f == WorldMapFrame or f == WorldMapFrame.ScrollContainer or f == (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child) or f == WorldFrame or f == UIParent then
        return false
    end

    if f.GetObjectType and f:GetObjectType() == "UnitPositionFrame" then
        return false
    end
    
    return f.IsMouseOver and f:IsMouseOver()
end

-- Helper to extract pin map coordinates exclusively from frame.point (PointTable)
local function GetPointTableData(frame)
    if not frame or type(frame) ~= "table" then return nil end

    local foci = GetMouseFoci and GetMouseFoci() or (GetMouseFocus and { GetMouseFocus() }) or {}
    local candidateFrames = { frame, unpack(foci) }

    for _, f in ipairs(candidateFrames) do
        if f and type(f) == "table" then
            local parents = { f, f.GetParent and f:GetParent() }
            for _, p in ipairs(parents) do
                if p and type(p) == "table" then
                    local pt = p.point or p.uid or p.waypoint
                    if type(pt) == "table" then
                        local m = pt[1] or p.mapID or p.uiMapID
                        local x = pt[2] or pt.x
                        local y = pt[3] or pt.y
                        if type(x) == "number" and type(y) == "number" then
                            return m, x, y, pt
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- Remove TomTom waypoint exclusively by PointTable coordinates or reference
local lastRemoveTime = 0
local function RemoveClosestWaypoint(targetFrame)
    if not (TomTom and TomTom.RemoveWaypoint and TomTom.waypoints) then return false end
    
    local now = GetTime()
    if now - lastRemoveTime < 0.1 then return true end

    local target = targetFrame or GetCurrentMouseFrame()
    local mID, pinX, pinY, pointTable = GetPointTableData(target)

    -- If direct pointTable is the actual realWp table from TomTom.waypoints
    if pointTable then
        pcall(TomTom.RemoveWaypoint, TomTom, pointTable)
    end

    if not (pinX and pinY) then return false end

    local px = pinX > 1 and (pinX / 100) or pinX
    local py = pinY > 1 and (pinY / 100) or pinY

    for mID, mapWaypoints in pairs(TomTom.waypoints) do
        if type(mapWaypoints) == "table" then
            for key, realWp in pairs(mapWaypoints) do
                if type(realWp) == "table" and type(realWp[2]) == "number" and type(realWp[3]) == "number" then
                    local wx = realWp[2] > 1 and (realWp[2] / 100) or realWp[2]
                    local wy = realWp[3] > 1 and (realWp[3] / 100) or realWp[3]
                    if math.abs(wx - px) < 0.005 and math.abs(wy - py) < 0.005 then
                        TomTom:RemoveWaypoint(realWp)
                        lastRemoveTime = now
                        return true
                    end
                end
            end
        end
    end

    return false
end

-- Central handler for Ctrl+LeftClick on map canvas or pins
local lastClickTime = 0
local function HandleMapClick(clickedFrame, button)
    if not (IsControlKeyDown() and button == "LeftButton") then return end
    if not (TomTom and TomTom.AddWaypoint and WorldMapFrame and WorldMapFrame:IsShown()) then return end
    
    local now = GetTime()
    if now - lastClickTime < 0.15 then return end
    
    local target = clickedFrame or GetCurrentMouseFrame()
    
    -- Check if any frame under cursor is a Questie pin
    local foci = GetMouseFoci and GetMouseFoci() or (GetMouseFocus and { GetMouseFocus() }) or {}
    for _, f in ipairs(foci) do
        if f and type(f) == "table" then
            local name = f.GetName and f:GetName()
            if (name and string.find(name, "Questie")) or (f.data and f.data.QuestID) then
                return
            end
        end
    end
    
    -- Check if any frame under cursor is a TomTom pin (has PointTable) or if TomTomTooltip is visible
    local isTomTomTooltipVisible = _G["TomTomTooltip"] and _G["TomTomTooltip"]:IsVisible()
    local hasPointData = false

    for _, f in ipairs(foci) do
        if f and type(f) == "table" then
            local m, x, y = GetPointTableData(f)
            if x and y then
                hasPointData = true
                break
            end
        end
    end
    
    if hasPointData or isTomTomTooltipVisible then
        lastClickTime = now
        if RemoveClosestWaypoint(target) then
            return
        end
    end
    
    -- 3. Otherwise -> Place new TomTom waypoint
    local mapID = WorldMapFrame:GetMapID()
    local cx, cy
    if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition then
        cx, cy = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
    end
    
    if not (mapID and cx and cy and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1) then
        return
    end
    
    local title = GetPinOrTooltipTitle()
    if not title or title == "" then
        local zoneName = GetMapZoneName(mapID) or "Waypoint"
        title = string.format("%s (%.2f, %.2f)", zoneName, cx * 100, cy * 100)
    end
    
    lastClickTime = now
    
    TomTom:AddWaypoint(mapID, cx, cy, {
        title = title,
        from = "Map click",
    })
end

-- Hook pin frames
local function HookPinFrame(pinFrame)
    if not pinFrame or pinFrame._mwz_hooked then return end
    if pinFrame == WorldMapFrame or pinFrame == WorldMapFrame.ScrollContainer or pinFrame == (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child) then return end
    if pinFrame.GetObjectType and pinFrame:GetObjectType() == "UnitPositionFrame" then return end

    if pinFrame.HookScript then
        pcall(pinFrame.HookScript, pinFrame, "OnMouseDown", function(self, button)
            if IsControlKeyDown() and button == "LeftButton" then
                HandleMapClick(self, button)
            end
        end)
    end
    
    pinFrame._mwz_hooked = true
end

-- Hook WorldMapFrame canvas
local isCanvasHookInstalled = false
local function HookCanvasWaypointCreation()
    if isCanvasHookInstalled then return end

    if WorldMapFrame and WorldMapFrame.ScrollContainer then
        WorldMapFrame.ScrollContainer:HookScript("OnMouseDown", function(self, button)
            if IsControlKeyDown() and button == "LeftButton" then
                HandleMapClick(GetCurrentMouseFrame(), button)
            end
        end)

        isCanvasHookInstalled = true
    end
end

-- Hook tooltips SetOwner to intercept pins on active map
local isTomTomHookInstalled = false
local function HookTomTomPinClicks()
    HookCanvasWaypointCreation()
    
    if isTomTomHookInstalled then return end
    
    local tooltipsToHook = { GameTooltip, _G["TomTomTooltip"], _G["WorldMapTooltip"] }
    for _, tt in ipairs(tooltipsToHook) do
        if tt and tt.SetOwner then
            hooksecurefunc(tt, "SetOwner", function(self, owner)
                if IsFrameOnWorldMap(owner) then
                    HookPinFrame(owner)
                end
            end)
        end
    end
    
    isTomTomHookInstalled = true
end



-- Block map layer switching (entering sub-zones) when Ctrl + LeftClick is held down
local isSetMapIDHooked = false
local function HookSetMapIDBlock()
    if isSetMapIDHooked then return end
    if WorldMapFrame and WorldMapFrame.SetMapID then
        local origSetMapID = WorldMapFrame.SetMapID
        WorldMapFrame.SetMapID = function(self, mapID, ...)
            if IsControlKeyDown() and self:IsShown() and self:IsMouseOver() then
                return
            end
            return origSetMapID(self, mapID, ...)
        end
        isSetMapIDHooked = true
    end
end

HookSetMapIDBlock()

local function IsTomTomLoaded()
    return TomTom ~= nil or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("TomTom")) or (IsAddOnLoaded and IsAddOnLoaded("TomTom"))
end

if IsTomTomLoaded() then
    HookSetMapIDBlock()
    HookTomTomPinClicks()
    C_Timer.After(0.2, HookTomTomPinClicks)
end

-- Event router
local tomtomFrame = CreateFrame("Frame")
tomtomFrame:RegisterEvent("ADDON_LOADED")
tomtomFrame:RegisterEvent("PLAYER_LOGIN")
tomtomFrame:SetScript("OnEvent", function(self, event, addonName)
    if (event == "ADDON_LOADED" and addonName == "TomTom") or (event == "PLAYER_LOGIN" and IsTomTomLoaded()) then
        HookSetMapIDBlock()
        C_Timer.After(0.2, HookTomTomPinClicks)
    end
end)
