-- StaminaController.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local StaminaController = {}
StaminaController.__index = StaminaController

local DEFAULT_CONFIG = {
	MaxStamina = 100,
	DrainRate = 22,
	RegenRate = 16,
	RegenDelay = 1.1,
	WalkSpeed = 16,
	SprintSpeed = 25,
	ExhaustedThreshold = 15,
	SprintKey = Enum.KeyCode.LeftShift,
}

function StaminaController.new(customConfig)
	local config = table.clone(DEFAULT_CONFIG)
	if customConfig then
		for key, value in pairs(customConfig) do
			if config[key] ~= nil then
				config[key] = value
			end
		end
	end

	local self = setmetatable({}, StaminaController)
	self.Config = config
	self.Stamina = config.MaxStamina
	self.IsSprinting = false
	self.IsExhausted = false
	self.LastDrainTime = 0
	self.Connections = {}
	self.OnStaminaChanged = Instance.new("BindableEvent")

	return self
end

local function getHumanoid()
	local player = Players.LocalPlayer
	local character = player and player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid
end

function StaminaController:CanSprint(humanoid)
	if self.IsExhausted then
		return false
	end
	if self.Stamina <= 0 then
		return false
	end
	if humanoid.MoveDirection.Magnitude <= 0.05 then
		return false
	end
	return true
end

function StaminaController:SetSprinting(active)
	local humanoid = getHumanoid()
	if not humanoid then
		self.IsSprinting = false
		return
	end

	if active and self:CanSprint(humanoid) then
		self.IsSprinting = true
		humanoid.WalkSpeed = self.Config.SprintSpeed
	else
		self.IsSprinting = false
		humanoid.WalkSpeed = self.Config.WalkSpeed
	end
end

function StaminaController:Update(dt)
	local humanoid = getHumanoid()
	if not humanoid then
		self.IsSprinting = false
		return
	end

	local holdingSprint = UserInputService:IsKeyDown(self.Config.SprintKey)
	local moving = humanoid.MoveDirection.Magnitude > 0.05

	if holdingSprint and moving and not self.IsExhausted and self.Stamina > 0 then
		self.IsSprinting = true
		humanoid.WalkSpeed = self.Config.SprintSpeed
		self.LastDrainTime = os.clock()
		self.Stamina = math.max(0, self.Stamina - self.Config.DrainRate * dt)

		if self.Stamina <= 0 then
			self.IsExhausted = true
			self.IsSprinting = false
			humanoid.WalkSpeed = self.Config.WalkSpeed
		end

		self.OnStaminaChanged:Fire(self.Stamina, self.Config.MaxStamina, self.IsExhausted)
	else
		if self.IsSprinting then
			self.IsSprinting = false
			humanoid.WalkSpeed = self.Config.WalkSpeed
		end

		local elapsedSinceDrain = os.clock() - self.LastDrainTime
		if elapsedSinceDrain >= self.Config.RegenDelay and self.Stamina < self.Config.MaxStamina then
			self.Stamina = math.min(self.Config.MaxStamina, self.Stamina + self.Config.RegenRate * dt)

			if self.IsExhausted and self.Stamina >= self.Config.ExhaustedThreshold then
				self.IsExhausted = false
			end

			self.OnStaminaChanged:Fire(self.Stamina, self.Config.MaxStamina, self.IsExhausted)
		end
	end
end

function StaminaController:Start()
	self:Stop()

	local renderConn = RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end)
	table.insert(self.Connections, renderConn)

	local player = Players.LocalPlayer
	if player then
		local charConn = player.CharacterAdded:Connect(function(character)
			self.Stamina = self.Config.MaxStamina
			self.IsExhausted = false
			self.IsSprinting = false

			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid then
				humanoid.WalkSpeed = self.Config.WalkSpeed
			end

			self.OnStaminaChanged:Fire(self.Stamina, self.Config.MaxStamina, self.IsExhausted)
		end)
		table.insert(self.Connections, charConn)
	end
end

function StaminaController:Stop()
	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	table.clear(self.Connections)
	self.IsSprinting = false
end

return StaminaController
