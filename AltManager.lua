local _, AltManager = ...;
_G["AltManager"] = AltManager;
local Dialog = LibStub("LibDialog-1.0")
local sizeY = 510;
local extendForInstances = 60;
local offsetX = 0;
local offsetY = 40;
local addonName = "AltManager";
local perAltX = 120;
local ilvlTextSize = 8;
local removeButtonSize = 12;
local minSizeX = 300;
local minLevel = 90;
local nameLabel = "" -- Name
local mythicKeystoneLabel = "Keystone"
local mythicPlusLabel = "Mythic+ Rating"
local worldBossLabel = "World Boss"
local conquestLabel = "Conquest"
local conquestEarnedLabel = "Conquest Earned"
local manafluxLabel = "Manaflux Owned"
local voidcoreLabel = "Voidcore Owned"
local voidcoreEarnedLabel = "Voidcore Earned"
local adventurerDawncrestLabel = "Adv Dawncrest"
local veteranDawncrestLabel = "Vet Dawncrest"
local championDawncrestLabel = "Champ Dawncrest"
local heroDawncrestLabel = "Hero Dawncrest"
local mythDawncrestLabel = "Myth Dawncrest"
local honorLabel = "Honor"
local cofferKeyLabel = "Coffer Key"
local radiantSparkDustLabel = "Rad Spark Dust"
local isTimerunner = nil
local worldBossQuests = {
	[92560] = "Lu'ashal",
	[92034] = "Thorm'belan",
	[92636] = "Predaxas",
	[92123] = "Cragpine"
}

SLASH_ALTMANAGER1 = "/aam";
SLASH_ALTMANAGER2 = "/alts";

local function GetCurrencyStats(id)
	local info = C_CurrencyInfo.GetCurrencyInfo(id)
	if not info then return 0, 0, 0 end
    
    -- Returns: Owned, Earned (capped at max), and Max Cap
	return info.quantity, math.min(info.totalEarned, info.maxQuantity), info.maxQuantity
end

local function spairs(t, order)
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

local function true_numel(t)
	local c = 0
	for k, v in pairs(t) do c = c + 1 end
	return c
end

do
	local main_frame = CreateFrame("frame", nil, UIParent)
	AltManager.main_frame = main_frame
	main_frame:SetFrameStrata("MEDIUM")
	main_frame.background = main_frame:CreateTexture(nil, "BACKGROUND")
	main_frame.background:SetAllPoints()
	main_frame.background:SetDrawLayer("ARTWORK", 1)
	main_frame.background:SetColorTexture(0, 0, 0, 0.5)

	-- Set frame position
	main_frame:ClearAllPoints()
	main_frame:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
	main_frame:RegisterEvent("ADDON_LOADED")
	main_frame:RegisterEvent("PLAYER_LOGIN")
	main_frame:RegisterEvent("PLAYER_LOGOUT")
	main_frame:RegisterEvent("QUEST_TURNED_IN")
	main_frame:RegisterEvent("BAG_UPDATE_DELAYED")
	main_frame:RegisterEvent("CHAT_MSG_CURRENCY")
	main_frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
	main_frame:RegisterEvent("PLAYER_LEAVING_WORLD")

	main_frame:SetScript("OnEvent", function(self, event, ...)
		if event == "ADDON_LOADED" then
			local loadedAddon = ...
			if loadedAddon == addonName then
				isTimerunner = PlayerGetTimerunningSeasonID and PlayerGetTimerunningSeasonID() or nil
				AltManager:OnLoad()
			end
		elseif event == "PLAYER_LOGIN" then
			isTimerunner = PlayerGetTimerunningSeasonID and PlayerGetTimerunningSeasonID() or nil
			AltManager:OnLogin()
		elseif event == "PLAYER_LEAVING_WORLD" then
			local data = AltManager:CollectData()
			AltManager:StoreData(data)
		elseif event == "BAG_UPDATE_DELAYED" or event == "QUEST_TURNED_IN" or event == "CHAT_MSG_CURRENCY" or event == "CURRENCY_DISPLAY_UPDATE" then
			if AltManager.addon_loaded then
				local data = AltManager:CollectData()
				AltManager:StoreData(data)
			end
		end
	end)

	main_frame:EnableKeyboard(true)
	main_frame:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			main_frame:SetPropagateKeyboardInput(false)
		else
			main_frame:SetPropagateKeyboardInput(true)
		end
	end)
	main_frame:SetScript("OnKeyUp", function(self, key)
		if key == "ESCAPE" then
			AltManager:HideInterface()
		end
	end)

	-- Show Frame
	main_frame:Hide()
end

function AltManager:InitDB()
	local t = {};
	t.alts = 0;
	t.data = {};
	return t;
end

function AltManager:CalculateXSizeNoGuidCheck()
	local alts = AltManagerDB.alts;
	return max((alts + 1) * perAltX, minSizeX)
end

function AltManager:CalculateXSize()
	return self:CalculateXSizeNoGuidCheck()
end

-- because of guid...
function AltManager:OnLogin()
	self:ValidateReset();
	self:StoreData(self:CollectData());

	self.main_frame:SetSize(self:CalculateXSize(), sizeY);
	self.main_frame.background:SetAllPoints();

	-- Create menus
	AltManager:CreateContent();
	AltManager:MakeTopBottomTextures(self.main_frame);
	AltManager:MakeBorder(self.main_frame, 5);
end

function AltManager:PurgeDbShadowlands()
	if AltManagerDB == nil or AltManagerDB.data == nil then return end
	local remove = {}
	for alt_guid, alt_data in spairs(AltManagerDB.data, function(t, a, b) return t[a].ilevel > t[b].ilevel end) do
		if alt_data.charlevel == nil or alt_data.charlevel < minLevel or isTimerunner ~= nil then -- poor heuristic to remove old max level chars
			table.insert(remove, alt_guid)
		end
	end
	for k, v in pairs(remove) do
		-- don't need to redraw, this is don on load
		AltManagerDB.alts = AltManagerDB.alts - 1;
		AltManagerDB.data[v] = nil
	end
end

function AltManager:OnLoad()
	self.main_frame:UnregisterEvent("ADDON_LOADED");

	AltManagerDB = AltManagerDB or self:InitDB();

	self:PurgeDbShadowlands();

	if AltManagerDB.alts ~= true_numel(AltManagerDB.data) then
		print("Altcount inconsistent, using", true_numel(AltManagerDB.data))
		AltManagerDB.alts = true_numel(AltManagerDB.data)
	end

	self.addon_loaded = true
	C_MythicPlus.RequestRewards();
	C_MythicPlus.RequestCurrentAffixes();
	C_MythicPlus.RequestMapInfo();
end

-- Create a minimap button
local minimapButton = CreateFrame("Button", "AltManagerMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)

-- Set the minimap button texture
local iconTexture = minimapButton:CreateTexture(nil, "BACKGROUND")
iconTexture:SetTexture("Interface\\ICONS\\inv_misc_grouplooking")
iconTexture:SetSize(20, 20)
iconTexture:SetPoint("CENTER", 0, 0)

-- Set the minimap button border (optional)
local borderTexture = minimapButton:CreateTexture(nil, "OVERLAY")
borderTexture:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
borderTexture:SetSize(54, 54)
borderTexture:SetPoint("TOPLEFT")

-- Helper function to update the button's position
local function UpdateMinimapButtonPosition()
    local angle = minimapButton.angle or math.rad(45) -- Default to 45 degrees if not set
    local radius = 80 -- Adjust radius if needed
    local x, y

    -- Check if GetMinimapShape is available
    local shape
    if type(GetMinimapShape) == "function" then
        shape = GetMinimapShape() or "ROUND"
    else
        shape = "ROUND"
    end

    -- Minimap dimensions and center
    local minimapWidth, minimapHeight = Minimap:GetWidth(), Minimap:GetHeight()
    local minimapCenterX, minimapCenterY = Minimap:GetCenter()

    if shape == "ROUND" then
        -- Calculate position for round minimap, making sure it's on the edge
        local minimapRadius = minimapWidth / 2
        x = minimapRadius * math.cos(angle)
        y = minimapRadius * math.sin(angle)
    elseif shape == "SQUARE" then
        -- Snap to edges of a square minimap
        local xEdge = radius * math.cos(angle)
        local yEdge = radius * math.sin(angle)
        local absX = math.abs(xEdge)
        local absY = math.abs(yEdge)

        if absX > absY then
            -- Snap to horizontal edge
            x = (xEdge > 0) and minimapWidth / 2 or -minimapWidth / 2
            y = (yEdge / xEdge) * x
        else
            -- Snap to vertical edge
            y = (yEdge > 0) and minimapHeight / 2 or -minimapHeight / 2
            x = (xEdge / yEdge) * y
        end
    else
        -- Default behavior for unknown shapes (fallback)
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)
    end

    -- Update the position
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Save minimap button position and visibility to the saved variables
local function SaveMinimapButtonPosition()
    if not AltManagerDB then
        AltManagerDB = {}
    end
    if not AltManagerDB.minimapButton then
        AltManagerDB.minimapButton = {}
    end
    AltManagerDB.minimapButton.angle = minimapButton.angle
    AltManagerDB.minimapButton.hidden = not minimapButton:IsShown() -- Save visibility state
end

-- Load minimap button position and visibility from the saved variables
local function LoadMinimapButtonPosition()
    if AltManagerDB and AltManagerDB.minimapButton then
        minimapButton.angle = AltManagerDB.minimapButton.angle or math.rad(45)  -- Default angle if no saved position
        local hidden = AltManagerDB.minimapButton.hidden
        if hidden == nil then
            hidden = false -- Default to showing if not saved
        end
        if hidden then
            minimapButton:Hide()
        else
            minimapButton:Show()
        end
    else
        minimapButton.angle = math.rad(45)  -- Default angle if no saved position
        minimapButton:Show() -- Default to showing if no saved visibility
    end
    UpdateMinimapButtonPosition()
end

-- Variables to track dragging state
local dragging = false
local startX, startY
local startAngle

-- Function to toggle button visibility
local function ToggleMinimapButtonVisibility()
    if minimapButton:IsShown() then
        minimapButton:Hide()
        print("[Alt Manager]: Minimap button hidden")
    else
        minimapButton:Show()
        print("[Alt Manager]: Minimap button shown")
    end
    -- Save visibility state after toggling
    SaveMinimapButtonPosition()
end

-- Set up the minimap button dragging functionality
minimapButton:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        dragging = true
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        startX, startY = (px / scale) - mx, (py / scale) - my
        startAngle = math.atan2(startY, startX)
    elseif button == "RightButton" then
        --print("Right-click detected")  -- Debug message
        ToggleMinimapButtonVisibility()
    end
end)

minimapButton:SetScript("OnMouseUp", function(self, button)
    if dragging and button == "LeftButton" then
        dragging = false
        -- Save the new position
        SaveMinimapButtonPosition()
    end
end)

minimapButton:SetScript("OnUpdate", function(self)
    if dragging then
        local px, py = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        px = px / scale
        py = py / scale

        local mx, my = Minimap:GetCenter()
        local dx = px - mx
        local dy = py - my
        minimapButton.angle = math.atan2(dy, dx)

        -- Update button position safely
        if not self.isUpdating then
            self.isUpdating = true
            UpdateMinimapButtonPosition()
            self.isUpdating = false
        end
    end
end)

-- Handle button clicks
local isShown = false
minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if not isShown then
            AltManager:ShowInterface()
            isShown = true
        else
            AltManager:HideInterface()
            isShown = false
        end
    elseif button == "RightButton" then
        -- Do nothing here to avoid conflict with OnMouseDown
    end
end)

-- Tooltip for the minimap button
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("|cffffff00AltManager|r")
    GameTooltip:AddLine("Left-click |cffffff00to toggle window|r")
    GameTooltip:AddLine("Right-click |cffffff00to hide button|r")
    GameTooltip:AddLine("|cffffff00/alts mm|r to restore button")
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Register event to load and save the minimap position
minimapButton:RegisterEvent("PLAYER_LOGIN")
minimapButton:RegisterEvent("PLAYER_LOGOUT")
minimapButton:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        LoadMinimapButtonPosition()
    elseif event == "PLAYER_LOGOUT" then
        SaveMinimapButtonPosition()
    end
end)

function SlashCmdList.ALTMANAGER(cmd, editbox)
    local rqst, arg = strsplit(' ', cmd)
    
    if rqst == "help" then
        print("Alt Manager help:")
        print("   \"/aam or /alts\" to open main addon window.")
        print("   \"/alts purge\" to remove all stored data.")
        print("   \"/alts remove name\" to remove characters by name.")
        print("   \"/alts mm\" to toggle the minimap button visibility.")
    elseif rqst == "purge" then
        AltManager:Purge()
    elseif rqst == "remove" then
        AltManager:RemoveCharactersByName(arg)
    elseif rqst == "mm" then
        if minimapButton then
            if minimapButton:IsShown() then
                minimapButton:Hide()
                print("[Alt Manager]: Minimap button hidden.")
            else
                minimapButton:Show()
                -- Save the state to the saved variables
                SaveMinimapButtonPosition()
                print("[Alt Manager]: Minimap button is now visible.")
            end
        else
            print("[Alt Manager]: Minimap button is not initialized.")
        end
    else
        AltManager:ShowInterface()
    end
end

--[[
function AltManager:CreateFontFrame(parent, x_size, height, relative_to, y_offset, label, justify)
	local f = CreateFrame("Button", nil, parent);
	f:SetSize(x_size, height);
	f:SetNormalFontObject("GameFontHighlightSmall")
	f:SetText(label)
	f:SetPoint("TOPLEFT", relative_to, "TOPLEFT", 0, y_offset);
	f:GetFontString():SetJustifyH(justify);
	f:GetFontString():SetJustifyV("MIDDLE");
	f:SetPushedTextOffset(0, 0);
	f:GetFontString():SetWidth(120)
	f:GetFontString():SetHeight(20)

	return f;
end
]]


function AltManager:CreateFontFrame(parent, x_size, height, relative_to, y_offset, label, justify, fontPath)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(x_size, height)
    f:SetText(label)
    f:SetPoint("TOPLEFT", relative_to, "TOPLEFT", 0, y_offset)
    
    local fs = f:GetFontString()
    fs:SetJustifyH(justify)
    fs:SetJustifyV("MIDDLE")
    f:SetPushedTextOffset(0, 0)
    fs:SetWidth(120)
    fs:SetHeight(20)

    if fontPath then
        fs:SetFont(fontPath, 12, "")
    else
        fs:SetFontObject("GameFontHighlightSmall")
    end

    return f
end


function AltManager:Keyset()
	local keyset = {}
	if AltManagerDB and AltManagerDB.data then
		for k in pairs(AltManagerDB.data) do
			table.insert(keyset, k)
		end
	end
	return keyset
end

function AltManager:ValidateReset()
	local db = AltManagerDB
	if not db then return end;
	if not db.data then return end;

	local keyset = {}
	for k in pairs(db.data) do
		table.insert(keyset, k)
	end

	for alt = 1, db.alts do
		local expiry = db.data[keyset[alt]].expires or 0;
		local char_table = db.data[keyset[alt]];
		if time() > expiry then
			-- reset this alt
			char_table.dungeon = "Unknown";
			char_table.level = "?";
			char_table.run_history = nil;
			char_table.expires = self:GetNextWeeklyResetTime();
			char_table.worldboss = false;
			--char_table.aiding_the_accord = false;
			char_table.dreamrift_normal = 0;
			char_table.dreamrift_heroic = 0;
			char_table.dreamrift_mythic = 0;
			char_table.voidspire_normal = 0;
			char_table.voidspire_heroic = 0;
			char_table.voidspire_mythic = 0;
			char_table.queldanas_normal = 0;
			char_table.queldanas_heroic = 0;
			char_table.queldanas_mythic = 0;
		end
	end
end

function AltManager:Purge()
	AltManagerDB = self:InitDB();
end

function AltManager:RemoveCharactersByName(name)
	local db = AltManagerDB;

	local indices = {};
	for guid, data in pairs(db.data) do
		if db.data[guid].name == name then
			indices[#indices+1] = guid
		end
	end

	db.alts = db.alts - #indices;
	for i = 1,#indices do
		db.data[indices[i]] = nil
	end

	print("Found " .. (#indices) .. " characters by the name of " .. name)
	print("Please reload ui to update the displayed info.")

	-- things wont be redrawn
end

function AltManager:RemoveCharacterByGuid(index, skip_confirmation)
	local db = AltManagerDB;

	if db.data[index] == nil then return end

	local delete = function()
		if db.data[index] == nil then return end
		db.alts = db.alts - 1;
		db.data[index] = nil
		self.main_frame:SetSize(self:CalculateXSizeNoGuidCheck(), sizeY);
		if self.main_frame.alt_columns ~= nil then
			-- Hide the last col
			-- find the correct frame to hide
			local count = #self.main_frame.alt_columns
			for j = 0,count-1 do
				if self.main_frame.alt_columns[count-j]:IsShown() then
					self.main_frame.alt_columns[count-j]:Hide()
					-- also for instances
					if self.instances_unroll ~= nil and self.instances_unroll.alt_columns ~= nil and self.instances_unroll.alt_columns[count-j] ~= nil then
						self.instances_unroll.alt_columns[count-j]:Hide()
					end
					break
				end
			end

			-- and hide the remove button
			if self.main_frame.remove_buttons ~= nil and self.main_frame.remove_buttons[index] ~= nil then
				self.main_frame.remove_buttons[index]:Hide()
			end
		end
		self:UpdateStrings()
		-- it's not simple to update the instances text with current design, so hide it and let the click do update
		if self.instances_unroll ~= nil and self.instances_unroll.state == "open" then
			self:CloseInstancesUnroll()
			self.instances_unroll.state = "closed";
		end
	end

	if skip_confirmation == nil then
		local name = db.data[index].name
		Dialog:Register("AltManagerRemoveCharacterDialog", {
			text = "Are you sure you want to remove " .. name .. " from the list?",
			width = 500,
			on_show = function(self, data)
			end,
			buttons = {
				{ text = "Delete",
				on_click = delete},
				{ text = "Cancel", }
			},
			show_while_dead = true,
			hide_on_escape = true,
		})
		if Dialog:ActiveDialog("AltManagerRemoveCharacterDialog") then
			Dialog:Dismiss("AltManagerRemoveCharacterDialog")
		end
		Dialog:Spawn("AltManagerRemoveCharacterDialog", {string = string})
	else
		delete();
	end

end

function AltManager:StoreData(data)
	if not self.addon_loaded or not data or not data.guid or UnitLevel('player') < minLevel or isTimerunner ~= nil then
		return
	end

	local db = AltManagerDB
	local guid = data.guid

	db.data = db.data or {}

	if not db.data[guid] then
		db.data[guid] = data
		db.alts = db.alts + 1
	else
		local lvl = db.data[guid].artifact_level
		data.artifact_level = data.artifact_level or lvl
		db.data[guid] = data
	end
end

local dungeons = {
	-- WOTLK
	[556] = "POS", -- Pit of Saron
	-- CATA
	-- [438] = "VP",
	-- [456] = "TOTT",
	-- [507] = "GB",
	-- MoP
	-- [2] =   "TJS",
	-- WoD
	[161] = "SR", -- Skyreach
	-- [165] = "SBG",
	-- [166] = "GD",
	-- [168] = "EB",
	-- [169] = "ID",
	-- Legion
	-- [198] = "DHT",
	-- [199] = "BRH",
	-- [200] = "HOV",
	-- [206] = "NL",
	-- [210] = "COS",
	-- [227] = "LOWR",
	-- [234] = "UPPR",
	-- BFA
	-- [244] = "AD",
	-- [245] = "FH",
	-- [246] = "TD",
	-- [247] = "ML",
	-- [248] = "WCM",
	-- [249] = "KR",
	-- [250] = "Seth",
	-- [251] = "UR",
	-- [252] = "SotS",
	--[353] = "SoB",
	--[369] = "YARD",
	-- [370] = "SHOP",
	-- Shadowlands
	--[375] = "MoTS",
	--[376] = "NW",
	-- [377] = "DOS",
	-- [378] = "HoA",
	-- [379] = "PF",
	-- [380] = "SD",
	-- [381] = "SoA",
	-- [382] = "ToP",
	-- [391] = "STRT",
	-- [392] = "GMBT",
	-- Dragonflight
	-- [399] = "RLP",
	-- [400] = "NO",
	-- [401] = "AV",
	[402] = "AA",
	-- [403] = "ULD",
	-- [404] = "NELT",
	-- [405] = "BH",
	-- [406] = "HOI"
	-- [463] = "FALL",
	-- [464] = "RISE",
	-- The War Within
	-- [499] = "PSF", -- Priory of the Sacred Flame
	-- [500] = "ROOK", -- The Rookery
	-- [501] = "SV", -- The Stonevault
	-- [502] = "COT", -- City of Threads
	-- [503] = "ARAK", -- Ara-Kara, City of Echoes
	-- [504] = "DFC", -- Darkflame Cleft
	-- [505] = "DAWN", -- The Dawnbreaker
	-- [506] = "BREW", -- Cinderbrew Meadery
	-- [525] = "FLOOD", -- Operation: Floodgate
	-- Midnight
	[557] = "WS", -- Windrunner Spire
	[558] = "MT", -- Magister's Terrace
	[559] = "NPX", -- Nexus-Point Xenas
	[560] = "MC", -- Maisara Caverns
	[583] = "SEAT", -- Seat of the Triumvirate
};

function AltManager:CollectData()

	if UnitLevel('player') < minLevel or isTimerunner ~= nil then return end;
	-- this is an awful hack that will probably have some unforeseen consequences,
	-- but Blizzard fucked something up with systems on logout, so let's see how it
	-- goes.
	_, i = GetAverageItemLevel()
	if i == 0 then return end;

	local name = UnitName('player')
	local _, class = UnitClass('player')
	local dungeon = nil;
	local expire = nil;
	local level = nil;
	local highest_mplus = 0;
	local guid = UnitGUID('player');

	local mine_old = nil
	if AltManagerDB and AltManagerDB.data then
		mine_old = AltManagerDB.data[guid];
	end

	local run_history = C_MythicPlus.GetRunHistory(false, true);

	-- find keystone
    local keystoneMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()

    if keystoneMapID and keystoneLevel then
        dungeon = keystoneMapID
        level = keystoneLevel
    else
        dungeon = "Unknown"
        level = "?"
    end

	local saves = GetNumSavedInstances();
	local normal_difficulty = 14
	local heroic_difficulty = 15
	local mythic_difficulty = 16
	local dreamriftMapName = C_Map.GetMapInfo(2531).name
	local voidspireMapName = C_Map.GetMapInfo(2529).name
	local queldanasMapName = C_Map.GetMapInfo(2533).name
	local Dreamrift_Normal, Dreamrift_Heroic, Dreamrift_Mythic = 0, 0, 0
	local Voidspire_Normal, Voidspire_Heroic, Voidspire_Mythic = 0, 0, 0
	local Queldanas_Normal, Queldanas_Heroic, Queldanas_Mythic = 0, 0, 0
	-- /run local mapID = C_Map.GetBestMapForUnit("player"); print(format("You are in %s (%d)", C_Map.GetMapInfo(mapID).name, mapID))
	for i = 1, saves do
		local raid_name, _, reset, difficulty, _, _, _, _, _, _, _, killed_bosses = GetSavedInstanceInfo(i);
		--print(string.format("Saved Instance %d: %s, Reset: %d, Difficulty: %d, Bosses Killed: %d", i, raid_name, reset, difficulty, killed_bosses))
		if raid_name == dreamriftMapName and reset > 0 then
			if difficulty == normal_difficulty then Dreamrift_Normal = killed_bosses end
			if difficulty == heroic_difficulty then Dreamrift_Heroic = killed_bosses end
			if difficulty == mythic_difficulty then Dreamrift_Mythic = killed_bosses end
		elseif raid_name == voidspireMapName and reset > 0 then
			if difficulty == normal_difficulty then Voidspire_Normal = killed_bosses end
			if difficulty == heroic_difficulty then Voidspire_Heroic = killed_bosses end
			if difficulty == mythic_difficulty then Voidspire_Mythic = killed_bosses end
		elseif raid_name == queldanasMapName and reset > 0 then
			if difficulty == normal_difficulty then Queldanas_Normal = killed_bosses end
			if difficulty == heroic_difficulty then Queldanas_Heroic = killed_bosses end
			if difficulty == mythic_difficulty then Queldanas_Mythic = killed_bosses end
		end
	end

	local worldboss = nil
	for questID, bossName in pairs(worldBossQuests) do
		if C_QuestLog.IsQuestFlaggedCompleted(questID) then
			worldboss = bossName
			break -- Exit the loop if a completed quest is found
		end
	end

	local conquest_total, conquest_earned = GetCurrencyStats(Constants.CurrencyConsts.CONQUEST_CURRENCY_ID)
	local voidcore_total, voidcore_earned = GetCurrencyStats(3418)
	local manaflux_total, manaflux_earned = GetCurrencyStats(3378)
	local radiant_spark_dust_total, radiant_spark_dust_earned = GetCurrencyStats(3212)
	local _, ilevel = GetAverageItemLevel();
	local gold = GetMoneyString(GetMoney(), true)
	local adventurer_dawncrest = GetCurrencyStats(3383);
	local veteran_dawncrest = GetCurrencyStats(3341);
	local champion_dawncrest = GetCurrencyStats(3343);
	local hero_dawncrest = GetCurrencyStats(3345);
	local myth_dawncrest = GetCurrencyStats(3347);
	local honor_points = GetCurrencyStats(1792);
	local coffer_key = GetCurrencyStats(3028);
	local radiant_spark_dust = GetCurrencyStats(3212);
	local mplus_data = C_PlayerInfo.GetPlayerMythicPlusRatingSummary('player')
	local mplus_score = mplus_data.currentSeasonScore

	local char_table = {}
	char_table.guid = UnitGUID('player');
	char_table.name = name;
	char_table.class = class;
	char_table.ilevel = ilevel;
	char_table.charlevel = UnitLevel('player')
	char_table.dungeon = dungeon;
	char_table.level = level;
	char_table.run_history = run_history;
	char_table.worldboss = worldboss;
	char_table.conquest_earned = conquest_earned;
	char_table.conquest_total = conquest_total;
	char_table.voidcore_earned = voidcore_earned;
	char_table.voidcore_total = voidcore_total;
	char_table.manaflux_earned = manaflux_earned;
	char_table.manaflux_total = manaflux_total;
	char_table.radiant_spark_dust_earned = radiant_spark_dust_earned;
	char_table.radiant_spark_dust_total = radiant_spark_dust_total;

	char_table.mplus_score = mplus_score
	char_table.gold = gold;
	char_table.veteran_dawncrest = veteran_dawncrest;
	char_table.champion_dawncrest = champion_dawncrest;
	char_table.hero_dawncrest = hero_dawncrest;
	char_table.myth_dawncrest = myth_dawncrest;
	char_table.adventurer_dawncrest = adventurer_dawncrest;
	char_table.coffer_key = coffer_key;
	char_table.radiant_spark_dust = radiant_spark_dust;
	char_table.honor_points = honor_points;

	char_table.dreamrift_normal = Dreamrift_Normal;
	char_table.dreamrift_heroic = Dreamrift_Heroic;
	char_table.dreamrift_mythic = Dreamrift_Mythic;

	char_table.voidspire_normal = Voidspire_Normal;
	char_table.voidspire_heroic = Voidspire_Heroic;
	char_table.voidspire_mythic = Voidspire_Mythic;

	char_table.queldanas_normal = Queldanas_Normal;
	char_table.queldanas_heroic = Queldanas_Heroic;
	char_table.queldanas_mythic = Queldanas_Mythic;

	char_table.expires = self:GetNextWeeklyResetTime();
	char_table.data_obtained = time();
	char_table.time_until_reset = C_DateAndTime.GetSecondsUntilDailyReset();

	return char_table;
end

function AltManager:UpdateStrings()
	local font_height = 20;
	local db = AltManagerDB;

	local keyset = {}
	for k in pairs(db.data) do
		table.insert(keyset, k)
	end

	self.main_frame.alt_columns = self.main_frame.alt_columns or {};

	local alt = 0
	for alt_guid, alt_data in spairs(db.data, function(t, a, b) return t[a].ilevel > t[b].ilevel end) do
		alt = alt + 1
		-- create the frame to which all the fontstrings anchor
		local anchor_frame = self.main_frame.alt_columns[alt] or CreateFrame("Button", nil, self.main_frame);
		if not self.main_frame.alt_columns[alt] then
			self.main_frame.alt_columns[alt] = anchor_frame;
			self.main_frame.alt_columns[alt].guid = alt_guid
			anchor_frame:SetPoint("TOPLEFT", self.main_frame, "TOPLEFT", perAltX * alt, -1);
		end
		anchor_frame:SetSize(perAltX, sizeY);
		-- init table for fontstring storage
		self.main_frame.alt_columns[alt].label_columns = self.main_frame.alt_columns[alt].label_columns or {};
		local label_columns = self.main_frame.alt_columns[alt].label_columns;
		-- create / fill fontstrings
		local i = 1;
		for column_iden, column in spairs(self.columns_table, function(t, a, b) return t[a].order < t[b].order end) do
			-- only display data with values
			if type(column.data) == "function" then
				local fontPath = "Interface\\AddOns\\AltManager\\fonts\\Quicksand-Medium.ttf"
				local current_row = label_columns[i] or self:CreateFontFrame(anchor_frame, perAltX, column.font_height or font_height, anchor_frame, -(i - 1) * font_height, column.data(alt_data), "CENTER", fontPath);
				-- insert it into storage if just created
				if not self.main_frame.alt_columns[alt].label_columns[i] then
					self.main_frame.alt_columns[alt].label_columns[i] = current_row;
				end
				if column.color then
					local color = column.color(alt_data)
					current_row:GetFontString():SetTextColor(color.r, color.g, color.b, 1);
				end
				current_row:SetText(column.data(alt_data))
				if column.font then
					current_row:GetFontString():SetFont(column.font, ilvlTextSize)
				else
					--current_row:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 14)
				end
				if column.justify then
					current_row:GetFontString():SetJustifyV(column.justify);
				end
				if column.remove_button ~= nil then
					self.main_frame.remove_buttons = self.main_frame.remove_buttons or {}
					local extra = self.main_frame.remove_buttons[alt_data.guid] or column.remove_button(alt_data)
					if self.main_frame.remove_buttons[alt_data.guid] == nil then
						self.main_frame.remove_buttons[alt_data.guid] = extra
					end
					extra:SetParent(current_row)
					extra:SetPoint("TOPRIGHT", current_row, "TOPRIGHT", -18, 2 );
					extra:SetPoint("BOTTOMRIGHT", current_row, "TOPRIGHT", -18, -removeButtonSize + 2);
					extra:SetFrameLevel(current_row:GetFrameLevel() + 1)
					extra:Show();
				end
			end
			i = i + 1
		end

	end

end

function AltManager:UpdateInstanceStrings(my_rows, font_height)
	self.instances_unroll.alt_columns = self.instances_unroll.alt_columns or {};
	local alt = 0
	local db = AltManagerDB;
	for alt_guid, alt_data in spairs(db.data, function(t, a, b) return t[a].ilevel > t[b].ilevel end) do
		alt = alt + 1
		-- create the frame to which all the fontstrings anchor
		local anchor_frame = self.instances_unroll.alt_columns[alt] or CreateFrame("Button", nil, self.main_frame.alt_columns[alt]);
		if not self.instances_unroll.alt_columns[alt] then
			self.instances_unroll.alt_columns[alt] = anchor_frame;
		end
		anchor_frame:SetPoint("TOPLEFT", self.instances_unroll.unroll_frame, "TOPLEFT", perAltX * alt, -1);
		anchor_frame:SetSize(perAltX, extendForInstances);
		-- init table for fontstring storage
		self.instances_unroll.alt_columns[alt].label_columns = self.instances_unroll.alt_columns[alt].label_columns or {};
		local label_columns = self.instances_unroll.alt_columns[alt].label_columns;
		-- create / fill fontstrings
		local i = 1;
		for column_iden, column in spairs(my_rows, function(t, a, b) return t[a].order < t[b].order end) do
			local fontPath = "Interface\\AddOns\\AltManager\\fonts\\Quicksand-Medium.ttf"
			local current_row = label_columns[i] or self:CreateFontFrame(anchor_frame, perAltX, column.font_height or font_height, anchor_frame, -(i - 1) * font_height, column.data(alt_data), "CENTER", fontPath);
			-- insert it into storage if just created
			if not self.instances_unroll.alt_columns[alt].label_columns[i] then
				self.instances_unroll.alt_columns[alt].label_columns[i] = current_row;
			end
			current_row:SetText(column.data(alt_data)) -- fills data
			i = i + 1
		end
		-- hotfix visibility
		anchor_frame:SetShown(anchor_frame:GetParent():IsShown())
	end
end

function AltManager:OpenInstancesUnroll(my_rows, button)
	-- do unroll
	self.instances_unroll.unroll_frame = self.instances_unroll.unroll_frame or CreateFrame("Button", nil, self.main_frame);
	self.instances_unroll.unroll_frame:SetSize(perAltX, extendForInstances);
	self.instances_unroll.unroll_frame:SetPoint("TOPLEFT", self.main_frame, "TOPLEFT", 4, self.main_frame.lowest_point - 10);
	self.instances_unroll.unroll_frame:Show();

	local font_height = 20;
	-- create the rows for the unroll
	if not self.instances_unroll.labels then
		self.instances_unroll.labels = {};
		local i = 1
		for row_iden, row in spairs(my_rows, function(t, a, b) return t[a].order < t[b].order end) do
			if row.label then
				local fontPath = "Interface\\AddOns\\AltManager\\fonts\\Quicksand-Medium.ttf"
				local label_row = self:CreateFontFrame(self.instances_unroll.unroll_frame, perAltX, font_height, self.instances_unroll.unroll_frame, -(i-1)*font_height, row.label..":", "RIGHT", fontPath);
				table.insert(self.instances_unroll.labels, label_row)
			end
			i = i + 1
		end
	end

	-- populate it for alts
	self:UpdateInstanceStrings(my_rows, font_height)

	-- fixup the background
	self.main_frame:SetSize(self:CalculateXSizeNoGuidCheck(), sizeY + extendForInstances);
	self.main_frame.background:SetAllPoints();

end

function AltManager:CloseInstancesUnroll()
	-- do rollup
	self.main_frame:SetSize(self:CalculateXSizeNoGuidCheck(), sizeY);
	self.main_frame.background:SetAllPoints();
	self.instances_unroll.unroll_frame:Hide();
	for k, v in pairs(self.instances_unroll.alt_columns) do
		v:Hide()
	end
end

function AltManager:ProduceRelevantMythics(run_history)
	-- find thresholds
	local weekly_info = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.MythicPlus);
	table.sort(run_history, function(left, right) return left.level > right.level; end);
	local thresholds = {}

	local max_threshold = 0
	for i = 1 , #weekly_info do
		thresholds[weekly_info[i].threshold] = true;
		if weekly_info[i].threshold > max_threshold then
			max_threshold = weekly_info[i].threshold;
		end
	end
	return run_history, thresholds, max_threshold
end

function AltManager:MythicRunHistoryString(alt_data, vault_slot)
    if alt_data.run_history == nil or alt_data.run_history == 0 or next(alt_data.run_history) == nil then
        return "-"
    end

    local sorted_history = AltManager:ProduceRelevantMythics(alt_data.run_history)
    local total_runs = #sorted_history
    local result = ""

    if vault_slot == 1 then
        if total_runs >= 1 then
            result = "|cFF00FF00" .. tostring(sorted_history[1].level) .. "|r "
        end
    elseif vault_slot == 2 then
        local max_runs = math.min(4, total_runs)
        for run = 2, max_runs do
            local run_level = tostring(sorted_history[run].level)
            if run == 4 then
                run_level = "|cFF00FF00" .. run_level .. "|r"
            end
            result = result .. run_level .. " "
        end
    elseif vault_slot == 3 then
        local max_runs = math.min(8, total_runs)
        for run = 5, max_runs do
            local run_level = tostring(sorted_history[run].level)
            if run == 8 then
                run_level = "|cFF00FF00" .. run_level .. "|r"
            end
            result = result .. run_level .. " "
        end
    end

    return result ~= "" and result or "-"
end


function AltManager:CreateContent()

	-- Close button
	self.main_frame.closeButton = CreateFrame("Button", "CloseButton", self.main_frame, "UIPanelCloseButton");
	self.main_frame.closeButton:ClearAllPoints()
	self.main_frame.closeButton:SetPoint("BOTTOMRIGHT", self.main_frame, "TOPRIGHT", -5, 2);
	self.main_frame.closeButton:SetScript("OnClick", function() AltManager:HideInterface(); end);
	--self.main_frame.closeButton:SetSize(32, h);

	local column_table = {
		name = {
			order = 1,
			label = nameLabel,
			data = function(alt_data) return alt_data.name end,
			color = function(alt_data) return RAID_CLASS_COLORS[alt_data.class] end,
		},
		ilevel = {
			order = 2,
			data = function(alt_data) return string.format("%.2f", alt_data.ilevel or 0) end, -- , alt_data.neck_level or 0
			justify = "TOP",
			font = "Fonts\\FRIZQT__.TTF",
			remove_button = function(alt_data) return self:CreateRemoveButton(function() AltManager:RemoveCharacterByGuid(alt_data.guid) end) end
		},
		gold = {
			order = 3,
			justify = "TOP",
			font = "Fonts\\FRIZQT__.TTF",
			data = function(alt_data) return tostring(alt_data.gold or "0") end,
		},
		mplus = {
			order = 4,
			label = "| Slot 1",
			data = function(alt_data) return self:MythicRunHistoryString(alt_data,1) end,
		},
		mplus2 = {
			order = 4.1,
			label = "M+ Vault | Slot 2",
			data = function(alt_data) return self:MythicRunHistoryString(alt_data,2) end,
		},
		mplus3 = {
			order = 4.2,
			label = "| Slot 3",
			data = function(alt_data) return self:MythicRunHistoryString(alt_data,3) end,
		},
		keystone = {
			order = 4.3,
			label = mythicKeystoneLabel,
			data = function(alt_data) return (dungeons[alt_data.dungeon] or alt_data.dungeon) .. " +" .. tostring(alt_data.level); end,
		},
		mplus_score = {
			order = 4.4,
			label = mythicPlusLabel,
			data = function(alt_data) return tostring(alt_data.mplus_score or "0") end,
		},
		fake_just_for_offset = {
			order = 5,
			label = "",
			data = function(alt_data) return " " end,
		},
		adventurer_dawncrest = {
			order = 6,
			label = adventurerDawncrestLabel,
			data = function(alt_data) return tostring(alt_data.adventurer_dawncrest or "?") end,
		},
		veteran_dawncrest = {
			order = 6.1,
			label = veteranDawncrestLabel,
			data = function(alt_data) return tostring(alt_data.veteran_dawncrest or "?") end,
		},
		champion_dawncrest = {
			order = 6.15,
			label = championDawncrestLabel,
			data = function(alt_data) return tostring(alt_data.champion_dawncrest or "?") end,
		},
		hero_dawncrest = {
			order = 6.2,
			label = heroDawncrestLabel,
			data = function(alt_data) return tostring(alt_data.hero_dawncrest or "?") end,
		},
		myth_dawncrest = {
			order = 6.25,
			label = mythDawncrestLabel,
			data = function(alt_data) return tostring(alt_data.myth_dawncrest or "?") end,
		},
		manaflux = {
			order = 6.3,
			label = manafluxLabel,
			data = function(alt_data) return (alt_data.manaflux_total and (tostring(alt_data.manaflux_earned) .. " / " .. C_CurrencyInfo.GetCurrencyInfo(3378).maxQuantity) or "?")  end,
		},
		radiant_spark = {
			order = 6.4,
			label = radiantSparkDustLabel,
			data = function(alt_data) return (alt_data.radiant_spark_dust_total and (tostring(alt_data.radiant_spark_dust_earned) .. " / " .. C_CurrencyInfo.GetCurrencyInfo(3212).maxQuantity) or "?")  end,
		},
		nebulous_voidcore = {
			order = 6.6,
			label = voidcoreLabel,
			data = function(alt_data) return (alt_data.voidcore_total or "?")  end,
		},
		nebulous_voidcore_cap = {
			order = 6.7,
			label = voidcoreEarnedLabel,
			data = function(alt_data) return (alt_data.voidcore_earned and (tostring(alt_data.voidcore_earned) .. " / " .. C_CurrencyInfo.GetCurrencyInfo(3418).maxQuantity) or "?")  end,
		},
		coffer_key = {
			order = 6.8,
			label = cofferKeyLabel,
			data = function(alt_data) return (alt_data.coffer_key or "?")  end,
		},
		fake_just_for_offset_2 = {
			order = 7,
			label = "",
			data = function(alt_data) return " " end,
		},
		worldbosses = {
			order = 9,
			label = worldBossLabel,
			data = function(alt_data) return alt_data.worldboss and (alt_data.worldboss .. " killed") or "-" end,
		},
		honor_points = {
			order = 10,
			label = honorLabel,
			data = function(alt_data) return tostring(alt_data.honor_points or "?") end,
		},
		conquest_pts = {
			order = 11,
			label = conquestLabel,
			data = function(alt_data) return (alt_data.conquest_total and tostring(alt_data.conquest_total) or "0")  end,
		},
		conquest_cap = {
			order = 12,
			label = conquestEarnedLabel,
			data = function(alt_data) return (alt_data.conquest_earned and (tostring(alt_data.conquest_earned) .. " / " .. tostring(C_CurrencyInfo.GetCurrencyInfo(Constants.CurrencyConsts.CONQUEST_CURRENCY_ID).maxQuantity)) or "?") end,
		},
		dummy_line = {
			order = 13,
			label = " ",
			data = function(alt_data) return " " end,
		},
		raid_unroll = {
			order = 14,
			data = "unroll",
			name = "Instances >>",
			unroll_function = function(button, my_rows)
				self.instances_unroll = self.instances_unroll or {};
				self.instances_unroll.state = self.instances_unroll.state or "closed";
				if self.instances_unroll.state == "closed" then
					self:OpenInstancesUnroll(my_rows)
					-- update ui
					button:SetText("Instances <<");
					self.instances_unroll.state = "open";
				else
					self:CloseInstancesUnroll()
					-- update ui
					button:SetText("Instances >>");
					self.instances_unroll.state = "closed";
				end
			end,
			rows = {
				Dreamrift = {
					order = 4,
					label = "Dreamrift",
					data = function(alt_data) return self:MakeRaidString(alt_data.dreamrift_normal, alt_data.dreamrift_heroic, alt_data.dreamrift_mythic) end
				},
				Voidspire = {
					order = 5,
					label = "Voidspire",
					data = function(alt_data) return self:MakeRaidString(alt_data.voidspire_normal, alt_data.voidspire_heroic, alt_data.voidspire_mythic) end
				},
				Queldanas = {
					order = 6,
					label = "Quel'Danas",
					data = function(alt_data) return self:MakeRaidString(alt_data.queldanas_normal, alt_data.queldanas_heroic, alt_data.queldanas_mythic) end
				}
			}
		}
	}
	self.columns_table = column_table;

	-- create labels and unrolls
	local font_height = 20;
	local label_column = self.main_frame.label_column or CreateFrame("Button", nil, self.main_frame);
	if not self.main_frame.label_column then self.main_frame.label_column = label_column; end
	label_column:SetSize(perAltX, sizeY);
	label_column:SetPoint("TOPLEFT", self.main_frame, "TOPLEFT", 4, -1);

	local i = 1;
	for row_iden, row in spairs(self.columns_table, function(t, a, b) return t[a].order < t[b].order end) do
		if row.label then
			local fontPath = "Interface\\AddOns\\AltManager\\fonts\\Quicksand-Medium.ttf"
			local label_row = self:CreateFontFrame(self.main_frame, perAltX, font_height, label_column, -(i-1)*font_height, row.label~="" and row.label..":" or " ", "RIGHT", fontPath);
			self.main_frame.lowest_point = -(i-1)*font_height;
		end
		if row.data == "unroll" then
			-- create a button that will unroll it
			local unroll_button = CreateFrame("Button", "UnrollButton", self.main_frame, "UIPanelButtonTemplate");
			unroll_button:SetText(row.name);
			--unroll_button:SetFrameStrata("HIGH");
			unroll_button:SetFrameLevel(self.main_frame:GetFrameLevel() + 2)
			unroll_button:SetSize(unroll_button:GetTextWidth() + 20, 25);
			unroll_button:SetPoint("BOTTOMRIGHT", self.main_frame, "TOPLEFT", 4 + perAltX, -(i-1)*font_height-10);
			unroll_button:SetScript("OnClick", function() row.unroll_function(unroll_button, row.rows) end);
			self.main_frame.lowest_point = -(i-1)*font_height;
		end
		i = i + 1
	end

end

function AltManager:MakeRaidString(normal, heroic, mythic)
	if not normal then normal = 0 end
	if not heroic then heroic = 0 end
	if not mythic then mythic = 0 end

	local string = ""
	if mythic > 0 then string = string .. tostring(mythic) .. "M" end
	if heroic > 0 and mythic > 0 then string = string .. "-" end
	if heroic > 0 then string = string .. tostring(heroic) .. "H" end
	if normal > 0 and (mythic > 0 or heroic > 0) then string = string .. "-" end
	if normal > 0 then string = string .. tostring(normal) .. "N" end
	return string == "" and "-" or string
end

function AltManager:HideInterface()
	self.main_frame:Hide();
end

function AltManager:ShowInterface()
	self.main_frame:Show();
	self:StoreData(self:CollectData())
	self:UpdateStrings();
end

function AltManager:CreateRemoveButton(func)
	local frame = CreateFrame("Button", nil, nil)
	frame:ClearAllPoints()
	frame:SetScript("OnClick", function() func() end);
	self:MakeRemoveTexture(frame)
	frame:SetWidth(removeButtonSize)
	return frame
end

function AltManager:MakeRemoveTexture(frame)
	if frame.remove_tex == nil then
		frame.remove_tex = frame:CreateTexture(nil, "BACKGROUND")
		frame.remove_tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
		frame.remove_tex:SetAllPoints()
		frame.remove_tex:Show();
	end
	return frame
end

function AltManager:MakeTopBottomTextures(frame)
	if frame.bottomPanel == nil then
		frame.bottomPanel = frame:CreateTexture(nil);
	end
	if frame.topPanel == nil then
		frame.topPanel = CreateFrame("Frame", "AltManagerTopPanel", frame);
		frame.topPanelTex = frame.topPanel:CreateTexture(nil, "BACKGROUND");
		local logo = frame.topPanel:CreateTexture("logo","ARTWORK")
		logo:SetPoint("TOPLEFT")
		logo:SetTexture("Interface\\AddOns\\AltManager\\Media\\AltManager64")
		--frame.topPanelTex:ClearAllPoints();
		frame.topPanelTex:SetAllPoints();
		--frame.topPanelTex:SetSize(frame:GetWidth(), 30);
		frame.topPanelTex:SetDrawLayer("ARTWORK", -5);
		frame.topPanelTex:SetColorTexture(0, 0, 0, 0.7);

		frame.topPanelString = frame.topPanel:CreateFontString("OVERLAY");
		frame.topPanelString:SetFont("Interface\\AddOns\\AltManager\\fonts\\Quicksand-Regular.ttf", 22)
		frame.topPanelString:SetTextColor(1, 1, 1, 1);
		frame.topPanelString:SetJustifyH("CENTER")
		frame.topPanelString:SetJustifyV("MIDDLE")
		frame.topPanelString:SetWidth(260)
		frame.topPanelString:SetHeight(20)
		frame.topPanelString:SetText("Altruis Alt Manager");
		frame.topPanelString:ClearAllPoints();
		frame.topPanelString:SetPoint("CENTER", frame.topPanel, "CENTER", 0, 0);
		frame.topPanelString:Show();

	end
	frame.bottomPanel:SetColorTexture(0, 0, 0, 0.7);
	frame.bottomPanel:ClearAllPoints();
	frame.bottomPanel:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0);
	frame.bottomPanel:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0);
	frame.bottomPanel:SetSize(frame:GetWidth(), 30);
	frame.bottomPanel:SetDrawLayer("ARTWORK", 7);

	frame.topPanel:ClearAllPoints();
	frame.topPanel:SetSize(frame:GetWidth(), 30);
	frame.topPanel:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0);
	frame.topPanel:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0);

	frame:SetMovable(true);
	frame.topPanel:EnableMouse(true);
	frame.topPanel:RegisterForDrag("LeftButton");
	frame.topPanel:SetScript("OnDragStart", function(self,button)
		frame:SetMovable(true);
        frame:StartMoving();
    end);
	frame.topPanel:SetScript("OnDragStop", function(self,button)
        frame:StopMovingOrSizing();
		frame:SetMovable(false);
    end);
end

function AltManager:MakeBorderPart(frame, x, y, xoff, yoff, part)
	if part == nil then
		part = frame:CreateTexture(nil);
	end
	part:SetTexture(0, 0, 0, 1);
	part:ClearAllPoints();
	part:SetPoint("TOPLEFT", frame, "TOPLEFT", xoff, yoff);
	part:SetSize(x, y);
	part:SetDrawLayer("ARTWORK", 7);
	return part;
end

function AltManager:MakeBorder(frame, size)
	if size == 0 then
		return;
	end
	frame.borderTop = self:MakeBorderPart(frame, frame:GetWidth(), size, 0, 0, frame.borderTop); -- top
	frame.borderLeft = self:MakeBorderPart(frame, size, frame:GetHeight(), 0, 0, frame.borderLeft); -- left
	frame.borderBottom = self:MakeBorderPart(frame, frame:GetWidth(), size, 0, -frame:GetHeight() + size, frame.borderBottom); -- bottom
	frame.borderRight = self:MakeBorderPart(frame, size, frame:GetHeight(), frame:GetWidth() - size, 0, frame.borderRight); -- right
end

-- shamelessly stolen from saved instances
function AltManager:GetNextWeeklyResetTime()
	if not self.resetDays then
		local region = self:GetRegion()
		if not region then return nil end
		self.resetDays = {}
		self.resetDays.DLHoffset = 0
		if region == "US" then
			self.resetDays["2"] = true -- tuesday
			-- ensure oceanic servers over the dateline still reset on tues UTC (wed 1/2 AM server)
			self.resetDays.DLHoffset = -3
		elseif region == "EU" then
			self.resetDays["3"] = true -- wednesday
		elseif region == "CN" or region == "KR" or region == "TW" then -- XXX: codes unconfirmed
			self.resetDays["4"] = true -- thursday
		else
			self.resetDays["2"] = true -- tuesday?
		end
	end
	local offset = (self:GetServerOffset() + self.resetDays.DLHoffset) * 3600
	local nightlyReset = self:GetNextDailyResetTime()
	if not nightlyReset then return nil end
	while not self.resetDays[date("%w",nightlyReset+offset)] do
		nightlyReset = nightlyReset + 24 * 3600
	end
	return nightlyReset
end

function AltManager:GetNextDailyResetTime()
	local resettime = GetQuestResetTime()
	if not resettime or resettime <= 0 or -- ticket 43: can fail during startup
		-- also right after a daylight savings rollover, when it returns negative values >.<
		resettime > 24*3600+30 then -- can also be wrong near reset in an instance
		return nil
	end
	if false then -- this should no longer be a problem after the 7.0 reset time changes
		-- ticket 177/191: GetQuestResetTime() is wrong for Oceanic+Brazilian characters in PST instances
		local serverHour, serverMinute = GetGameTime()
		local serverResetTime = (serverHour*3600 + serverMinute*60 + resettime) % 86400 -- GetGameTime of the reported reset
		local diff = serverResetTime - 10800 -- how far from 3AM server
		if math.abs(diff) > 3.5*3600  -- more than 3.5 hours - ignore TZ differences of US continental servers
			and self:GetRegion() == "US" then
			local diffhours = math.floor((diff + 1800)/3600)
			resettime = resettime - diffhours*3600
			if resettime < -900 then -- reset already passed, next reset
				resettime = resettime + 86400
				elseif resettime > 86400+900 then
				resettime = resettime - 86400
			end
		end
	end
	return time() + resettime
end

function AltManager:GetServerOffset()
	local serverDay = C_DateAndTime.GetCurrentCalendarTime().weekday - 1 -- 1-based starts on Sun
	local localDay = tonumber(date("%w")) -- 0-based starts on Sun
	local serverHour, serverMinute = GetGameTime()
	local localHour, localMinute = tonumber(date("%H")), tonumber(date("%M"))
	if serverDay == (localDay + 1)%7 then -- server is a day ahead
		serverHour = serverHour + 24
	elseif localDay == (serverDay + 1)%7 then -- local is a day ahead
		localHour = localHour + 24
	end
	local server = serverHour + serverMinute / 60
	local localT = localHour + localMinute / 60
	local offset = floor((server - localT) * 2 + 0.5) / 2
	return offset
end

function AltManager:GetRegion()
	if not self.region then
		local reg
		reg = GetCVar("portal")
		if reg == "public-test" then -- PTR uses US region resets, despite the misleading realm name suffix
			reg = "US"
		end
		if not reg or #reg ~= 2 then
			local gcr = GetCurrentRegion()
			reg = gcr and ({ "US", "KR", "EU", "TW", "CN" })[gcr]
		end
		if not reg or #reg ~= 2 then
			reg = (GetCVar("realmList") or ""):match("^(%a+)%.")
		end
		if not reg or #reg ~= 2 then -- other test realms?
			reg = (GetRealmName() or ""):match("%((%a%a)%)")
		end
		reg = reg and reg:upper()
		if reg and #reg == 2 then
			self.region = reg
		end
	end
	return self.region
end

function AltManager:GetWoWDate()
	local hour = tonumber(date("%H"));
	local day = C_DateAndTime.GetCurrentCalendarTime().weekday;
	return day, hour;
end

function AltManager:TimeString(length)
	if length == 0 then
		return "Now";
	end
	if length < 3600 then
		return string.format("%d mins", length / 60);
	end
	if length < 86400 then
		return string.format("%d hrs %d mins", length / 3600, (length % 3600) / 60);
	end
	return string.format("%d days %d hrs", length / 86400, (length % 86400) / 3600);
end