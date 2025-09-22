--This is a simple cultivation game where you can meditate to gain experience and level up.
--Server Side Script

-- Get APIs, get all services and store into this table, avoid dirty code, can be used to call in a module and get that module to use for every script
local Services = {
	Players = game:GetService("Players"),
	RepStore = game:GetService("ReplicatedStorage"),
	ServerStorage = game:GetService("ServerStorage"),
	Lighting = game:GetService("Lighting"),
	
	Collection = game:GetService("CollectionService"),
	RunService = game:GetService("RunService"),
	Tween = game:GetService("TweenService")
}

-- Basic stats template for all players, stores all player stats and data, can be adjusted here for easy adjustment later
local BaseStats = {
	--store level data with Exp and MaxExp, ExpPerTime is the amount of exp that can be gained per second and the multiplier used to multiply by ExpPerSecond
	--can use Multiplier for Gamepasses/Products
	Level = {
		Level = 1,
		
		CurrentExp = 0,
		MaxExp = 5,
		
		ExpPerTime = 1,
		Multiplier = 1,
	},
	
	--Each stat has a current value and a multiplier value to multiply it by, which can be used for Gamepass/Products
	Stats = {
		Strength = {
			Current = 1,
			Multiplier = 1
		},
		Agility = {
			Current = 1,
			Multiplier = 1
		},
		Vitality = {
			Current = 1,
			Multiplier = 1
		},
		Qi = {
			Current = 0,
			Multiplier = 5
		}
	},
	
	--Current Rebirth value
	Rebirth = 0
}

-- Rebirth requirements
-- Each element is a new rebirth, storing the requirements of the Rebirth such as Level or Cash,...
local Rebirths = {
	{
		Require = {
			Level = 5
		}
	},
	{
		Require = {
			Level = 10
		}
	},
	{
		Require = {
			Level = 20,
		}
	}
}

-- Table to store all active player data
local AllPlayers = {}

-- Main Cultivate module
local CultivateModule = {}
CultivateModule.__index = CultivateModule

-- Constructor: creates a new cultivation object for a player
function CultivateModule.new(Player : Player)
	local Character = Player.Character
	local Humanoid = Character:WaitForChild("Humanoid")
	local T = {
		Player = Player,
		Character = Character,
		Humanoid = Humanoid,
				
		Connections = {}
	}
	
	AllPlayers[Player] = T
	
	local self = setmetatable(AllPlayers[Player], CultivateModule)
	
	-- Deep clone BaseStats so each player has independent stats
	-- *Avoid using table.clone because table.clone only does shallow copying

	self.Stats = self:DeepClone(BaseStats)
	
	-- Apply stats to character
	self:UpdateCharacter()
	
	return self
end

-- Reset player stats while keeping their rebirth count
function CultivateModule:ResetData()
	local Stats = self["Stats"]
	local CurrentRebirth = Stats["Rebirth"]
	
	--Get current Stats data and Current Rebirth
	--Each rebirth will reset all stats, only keep rebirth, each rebirth will double the experience gained
		
	local newStats = self:DeepClone(BaseStats)
	
	--Store new stats and current rebirth value to player cultivation object
	self["Stats"] = newStats
	self["Stats"]["Rebirth"] = CurrentRebirth
end

--

-- Start or stop cultivation (experience gain per second)
function CultivateModule:StartCultivate(IsStart : boolean)
	--if IsStart value is false or nil then set OnStart to false and return to stop culvitate
	--OnStart value here to avoid calling multiple times if already in cultivate
	if not IsStart then
		self.OnStart = false
		
		--call DisabledMovement function with false value to enabled player movement
		self:DisabledMovment(false)
		return
	end
	if self.OnStart then return end -- doubt check if already OnStart then return
	self.OnStart = true
	
	--call DisabledMovement function with false value to Disabled player movement
	self:DisabledMovment(true)

	task.spawn(function()
		while self.OnStart do -- stop if OnStart is false
			--use GetValue function to get all needed values ??at once for clean code
			local CurrentLevel, CurrentExp, MaxExp, ExpPerTime, Multiplier, CurrentRebirth = self:GetValue()
			task.wait(1)
			
			--increases Exp per second and applies to CurrentExp value
			--ExpPerTime is the base Exp value that can be increased per second
			--The multiplier has a base value of 1, if there is no Rebirth then just multiply by 1
			
			local Result = CurrentExp + (ExpPerTime * (Multiplier + CurrentRebirth))
			self["Stats"]["Level"]["CurrentExp"] = Result
			
			--If CurrentExp is greater than MaxExp, call the LevelUp function to set the statistics.
			if Result >= MaxExp then
				self:LevelUp()
			end
		end
	end)
end

-- Level up the player
function CultivateModule:LevelUp()
	--Get all Level value
	local Level = self["Stats"]["Level"]
		
	Level["Level"] += 1
	Level["CurrentExp"] -= Level["MaxExp"]
	
	--use exponential growth formula to calculate next level MaxExp, adjust base number or number can be very large
	Level["MaxExp"] = (1.5 ^ Level["Level"]) * 5
	
	--Get Stats value
	-- Each stat has a Multiplier, now just add them to the current value
	local StatsValue = self["Stats"]["Stats"]
	for StatName, Value in pairs(StatsValue) do
		Value["Current"] += Value["Multiplier"]
	end	
	
	--Update character Health, WalkSpeed,... after adjust stats
	self:UpdateCharacter()
end

-- Apply stats to the character (walk speed, jump height, health)
function CultivateModule:UpdateCharacter()
	--Get player value from cultivate object
	local Player : Player = self.Player
	local Humanoid : Humanoid = self.Humanoid
	
	--Get stats value
	local StatsValue = self["Stats"]["Stats"]
	
	local Agi = StatsValue["Agility"]["Current"]
	local Vita = StatsValue["Vitality"]["Current"]
	local Str = StatsValue["Strength"]["Current"]
	local Qi = StatsValue["Qi"]["Current"]
	
	--apply stat to Humanoid
	Humanoid.WalkSpeed = (Agi * 2) + 16
	Humanoid.JumpHeight = (Agi * 0.1) + 7.2
	Humanoid.MaxHealth = (Vita * 10) + 100
	
	--Qi and Damage muse use Properties because sometimes will need to use in client, it is messy to store directly in this object
	Player:SetAttribute("Qi", Qi)
	Player:SetAttribute("Damage", Str)
end

-- Disable or re-enable player movement
function CultivateModule:DisabledMovment(IsDisabled : boolean)
	local Humanoid : Humanoid = self.Humanoid
	
	-- if Disabled is true then set all movement values ??to 0, otherwise call UpdateCharacter function to apply the current stats to the character
	if IsDisabled then
		Humanoid.WalkSpeed = 0
		Humanoid.JumpHeight = 0
	else
		self:UpdateCharacter()
	end
end

--

-- Rebirth the player if they meet requirements
function CultivateModule:Rebirth()
	--if the player is cultivating then return, I don't want them to Rebirth while cultivating
	if self.OnStart then return end
	
	--Get level data because I'm currently only using level data for the Rebirth request
	local Stats = self["Stats"]
	local Level = Stats["Level"]
	
	local CurrentRebirth = Stats["Rebirth"]
	
	--find next rebirth value
	--if there is a next rebirth then check if the rebirth requirement is met, otherwise return false
	local NextRebirth = Rebirths[CurrentRebirth + 1]
	
	if NextRebirth then
		local Require = NextRebirth["Require"]
		if Require["Level"] then
			if Level["Level"] < Require["Level"] then
				return false
			end
		end
		
		--if next rebirth requirement is met then reset data and increase rebirth
		Stats["Rebirth"] += 1
		self:ResetData()
	else
		return false
	end
end

-- SKILL

-- Use the "Sixth Sense" Skill to see other players through walls
function CultivateModule:SixthSense(IsOn : boolean)
	--Get Screen Color ("ColorCorrectionEffect") of Sixth Sense in lighting and set on/off
	local SixthSenseScreenColor = Services["Lighting"]:FindFirstChild("SixthSense")
	if SixthSenseScreenColor then
		SixthSenseScreenColor.Visible = IsOn
	end
	
	--Highlight all other players to see them through walls
	for _, Player in pairs(Services["Players"]:GetPlayers()) do
		if Player == self.Player then continue end
		local Character = Player.Character
		
		--if IsON is true then create new highlight for other players, otherwise delete highlight in their character
		
		if IsOn then
			local HL = Instance.new("Highlight", Character)
		else
			local HL = Character:FindFirstChildWhichIsA("Highlight")
			if HL then
				HL:Destroy()
			end
		end
	end
end

-- Deep clone a table
function CultivateModule:DeepClone(t)
	--use this function instead of table.clone because table.clone only returns a shallow copy
	
	--create a copy table template, check if current value is a table or just a value
	--if it's a table then call DeepClone again to clone that table, otherwise store the value into copy template
	local copy = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			copy[k] = CultivateModule:DeepClone(v)
		else
			copy[k] = v
		end
	end
	return copy
end

-- Get all relevant values for level/experience calculation
function CultivateModule:GetValue()
	--use this function to get all level and stats value from object, avoid dirty code
	local Stats = self.Stats
	local Level = Stats["Level"]

	local CurrentLevel = Level["Level"]

	local CurrentExp = Level["CurrentExp"]
	local MaxExp = Level["MaxExp"]
	
	local ExpPerTime = Level["ExpPerTime"]
	local Multiplier = Level["Multiplier"]
	
	local CurrentRebirth = Stats["Rebirth"]
	
	return CurrentLevel, CurrentExp, MaxExp, ExpPerTime, Multiplier, CurrentRebirth
end

--

-- Player added connection, check if a player join the game
local function OnPlayerAdded(Player : Player)
	local function OnCharacterAdded(Character)
		--make sure player character loaded
		--create cultivate object for player
		local PlayerCultivate = CultivateModule.new(Player)
	end
	
	--if the player joins the game then check when the player character is loaded
	Player.CharacterAdded:Connect(OnCharacterAdded)
end

-- Player removing connection, check if a player leave the game
local function OnPlayerRemove(Player : Player)
	--get that player object, stop if they are in the process of cultivating
	local PlayerCultivate = AllPlayers[Player]
	if PlayerCultivate.OnStart then
		PlayerCultivate:StartCultivate(false)
	end
	
	--clear that player object and set to nil
	table.clear(PlayerCultivate)
	AllPlayers[Player] = nil
end

Services["Players"].PlayerAdded:Connect(OnPlayerAdded)
Services["Players"].PlayerRemoving:Connect(OnPlayerRemove)

-- Spirit Stones appear all over the map

-- Make Spirit Stone float up and down
local function SpiritStoneFloating(Stone)
	-- Save the stone's original position
	local originalPosition = Stone.Position  

	-- Tween configuration (2 seconds, smooth easing, infinite loop, reverses up & down)
	local tweenInfo = TweenInfo.new(
		2,                        
		Enum.EasingStyle.Sine,    
		Enum.EasingDirection.InOut, 
		-1,                       
		true,                    
		0                        
	)

	-- Target position: move 5 studs up on Y-axis
	local goal = { Position = originalPosition + Vector3.new(0, 5, 0) }

	-- Create tween for the stone
	local floatTween = Services["Tween"]:Create(Stone, tweenInfo, goal)

	-- Play the tween
	floatTween:Play()
end

-- Spawn a SpiritStone randomly on the Baseplate surface
local function SpawnSpiritStone()
	-- Find the SpiritStone template in ServerStorage
	-- Make sure it exist to avoid bug
	local Stone = Services["ServerStorage"]:FindFirstChild("SpiritStone")
	if not Stone then return end
	
	-- Create a folder in workspace to store all SpiritStones
	local SpiritStoneFolder = workspace:FindFirstChild("SpiritStone")
	if not SpiritStoneFolder then
		SpiritStoneFolder = Instance.new("Folder", workspace)
		SpiritStoneFolder.Name = "SpiritStone"
	end
	
	-- Clone the stone from template
	Stone = Stone:Clone()
	
	-- Get Baseplate info for spawning position
	local baseplate = workspace.Baseplate
	local baseSize = baseplate.Size
	local basePos = baseplate.Position
	
	-- Random X and Z position inside Baseplate bounds
	local randX = math.random(-baseSize.X/2, baseSize.X/2)
	local randZ = math.random(-baseSize.Z/2, baseSize.Z/2)
	
	-- Calculate stone spawn position (right above Baseplate surface)
	local stonePos = Vector3.new(
		basePos.X + randX,
		basePos.Y + baseSize.Y/2 + Stone.Size.Y/2,-- top surface of baseplate
		basePos.Z + randZ
	)
	
	-- Place stone in the world
	Stone.Position = stonePos
	Stone.Parent = SpiritStoneFolder
	
	-- Apply floating animation
	SpiritStoneFloating(Stone)
	
	-- Add "SpiritStone" tag for easier management later
	Services["Collection"]:AddTag(Stone, "SpiritStone")
	
	-- Handle when player touches the stone
	local StoneConn
	StoneConn = Stone.Touched:Connect(function(Hit)
		local Character = Hit.Parent
		local Player = Services["Players"]:GetPlayerFromCharacter(Character)
		if not Player then return end
		
		-- Disconnect event and remove stone after being touched
		StoneConn:Disconnect()
		Stone:Destroy()
		
		-- Add EXP to the player who touched the stone
		local PlayerCultivate = AllPlayers[Player]
		if PlayerCultivate then
			local StatsLevel = PlayerCultivate["Stats"]["Level"]
			local MaxExp = StatsLevel["MaxExp"]
			
			StatsLevel["CurrentExp"] += 5
			
			if StatsLevel["CurrentExp"] >= MaxExp then
				PlayerCultivate:LevelUp()
			end
		end
	end)
end

-- Timer and maximum SpiritStones allowed on the map
local Elapsed, MaxSpiritStone = 0, 10

-- Use Heartbeat to spawn SpiritStones every second
Services["RunService"].Heartbeat:Connect(function(DT)
	Elapsed += DT
	if Elapsed >= 1 then
		Elapsed = 0 -- reset timer after 1 second
	else return end -- skip if not enough time has passed
	
	-- Use collection service to Count current SpiritStones in the game
	local TotalSpiritStone = Services["Collection"]:GetTagged("SpiritStone")
	if #TotalSpiritStone >= MaxSpiritStone then return end
	
	-- Spawn the missing amount of SpiritStones up to the max limit
	for i = 1, MaxSpiritStone - #TotalSpiritStone do
		SpawnSpiritStone()
	end
end)

-- Remote events/functions for client-server communication
local Remote = Services["RepStore"]:WaitForChild("Remote")

--get all remote event
local StartEvent = Remote:WaitForChild("Start")
local GetStatsFunction = Remote:WaitForChild("GetStats")
local RebirthEvent = Remote:WaitForChild("Rebirth")
local UseSkillEvent = Remote:WaitForChild("UseSkill")

--Handle use skill request from client
UseSkillEvent.OnServerEvent:Connect(function(Player : Player, SkillName : string, IsOn : boolean)
	local PlayerCultivate = AllPlayers[Player]
	if PlayerCultivate then
		--check if that skill function exist
		if not PlayerCultivate[SkillName] then return end
		PlayerCultivate[SkillName](PlayerCultivate, SkillName, IsOn)
	end
end)

-- Handle rebirth requests from client
RebirthEvent.OnServerEvent:Connect(function(Player : Player)
	--client sends request to server to rebirth, check if player object exists, if so rebirth
	local PlayerCultivate = AllPlayers[Player]
	if PlayerCultivate then
		PlayerCultivate:Rebirth()
	end
end)

-- Return player stats to client
GetStatsFunction.OnServerInvoke = function(Player : Player)
	--sometimes will need to use stat in client but this object is created from server, use remote function to return data to client
	local PlayerCultivate = AllPlayers[Player]
	return PlayerCultivate["Stats"]
end

-- Handle start/stop cultivation requests from client
StartEvent.OnServerEvent:Connect(function(Player : Player, IsStart : boolean)
	--starting or stopping cultivation will be handled in the client via a UI button
	--if player press button then client will fire an event to server
	--check if player object exists, if so call function to start or stop based on boolean IsStart
	local PlayerCultivate = AllPlayers[Player]
	if PlayerCultivate then
		PlayerCultivate:StartCultivate(IsStart)
	end
end)