local SILENT_TEXT = Drawing.new("Text")
SILENT_TEXT.Text = Krypton.newest.Enabled and "Silent Aim: ON" or "Silent Aim: OFF"
SILENT_TEXT.Color = Krypton.newest.Enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
SILENT_TEXT.Size = 32
SILENT_TEXT.Outline = true
SILENT_TEXT.Visible = false

function UpdateText()
	if Text.Enabled then
		SILENT_TEXT.Text = Krypton.newest.Enabled and "Silent Aim: ON" or "Silent Aim: OFF"
		SILENT_TEXT.Color = Krypton.newest.Enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
		SILENT_TEXT.Visible = Text.Enabled or true
		SILENT_TEXT.Size = Text.Size or 32
		SILENT_TEXT.Position = Text.Position:lower() == "bottomright" and Vector2.new(1765, 975)
			or Text.Position:lower() == "bottomleft" and Vector2.new(15, 975)
			or Text.Position:lower() == "topright" and Vector2.new(1765, 10)
			or Text.Position:lower() == "topleft" and Vector2.new(15, 10)
			or Vector2.new(15, 10)
	end
end

local Circle = Drawing.new("Circle")
local rPoint
local toolTarget, autoTarget = nil, nil
local locked, target, autoShooting, targetVelocity = false, nil, false, nil
Circle.Transparency = 1
Circle.Radius = FOV.Size * 3
Circle.Visible = FOV.Enabled
Circle.Color = FOV.Color
Circle.Thickness = 1

local Smoothness = 30
local StoredStuff = {}
local Value = 1
local smoothVelocity = function(Character)
	local Current = Character.HumanoidRootPart.Position
	local Tick = tick()
	StoredStuff[Value] = { pos = Current, time = Tick }
	Value = Value + 1
	if Value > Smoothness then
		Value = 1
	end
	local Position = Vector3.new()
	local Time = 0
	for _ = 1, Smoothness do
		local Data = StoredStuff[_]
		if Data then
			Position = Position + Data.pos
			Time = Time + Data.time
		end
	end
	if StoredStuff[Value] then
		local velocity = (Current - StoredStuff[Value].pos) / (Tick - StoredStuff[Value].time)
		return velocity
	end
end

pcall(function()
	local spoofer, updating = false
	for i, v in pairs(game:GetService("CoreGui").RobloxGui.PerformanceStats:GetChildren()) do
		v.Name = i
	end
	game:GetService("CoreGui").RobloxGui.PerformanceStats["1"].StatsMiniTextPanelClass.ValueLabel
		:GetPropertyChangedSignal("Text")
		:Connect(function()
			if not updating then
				updating = true
				spoofer = math.random(800, 900) .. "." .. math.random(10, 99) .. "MB"
				game:GetService("CoreGui").RobloxGui.PerformanceStats["1"].StatsMiniTextPanelClass.ValueLabel.Text = spoofer
				updating = false
			end
		end)
end)

function wallCheck(position, ignoreList)
	return not workspace:FindPartOnRayWithIgnoreList(
		Ray.new(workspace.CurrentCamera.CFrame.p, position - workspace.CurrentCamera.CFrame.p),
		ignoreList
	)
end

function KnockedCheck(_)
	return _.Character.BodyEffects["K.O"].Value ~= true
end

function GrabbedCheck(_)
	return not _.Character:FindFirstChild("GRABBING_CONSTRAINT")
end

game:GetService("UserInputService").InputBegan:Connect(function(_, __)
	if _.KeyCode.Name == Krypton.newest.ToggleKey and __ == false then
		Krypton.newest.Enabled = not Krypton.newest.Enabled
	end
end)

function getClosestPart(Target)
	if Target and Target:GetChildren() then
		local closestpart, closdist = nil, math.huge
		local camera = workspace.CurrentCamera
		local mousepos = game.Players.LocalPlayer:GetMouse()
		local circleRadius = Circle.Radius
		local children = Target:GetChildren()
		local i = 1
		while i <= #children do
			local child = children[i]
			if child:IsA("BasePart") then
				local them, vis = camera:WorldToScreenPoint(child.Position)
				local magnitude = (Vector2.new(them.X, them.Y) - Vector2.new(mousepos.X, mousepos.Y)).magnitude
				if vis and circleRadius > magnitude and magnitude < closdist then
					closestpart, closdist = child, magnitude
				end
			end
			i = i + 1
		end
		return closestpart
	end
end

-- // Closest point
function cls(target)
	local selPart = getClosestPart(target)
	if not selPart or not target then
		return nil, nil
	end
	local mouse = game.Players.LocalPlayer:GetMouse()
	local mousePos, mouseTarget = mouse.hit.p, mouse.Target
	local dirToPart = (selPart.Position - mousePos).unit
	local halfSize = selPart.Size /2
	local ptOnPart = selPart.Position - dirToPart * halfSize
	local ptOffPart = mousePos
	if mouseTarget and mouseTarget:IsDescendantOf(target) then
		ptOnPart, ptOffPart = mousePos, ptOnPart + dirToPart * (halfSize * 2)
	end
	local newPos = Vector3.new(
		math.clamp(ptOnPart.X, selPart.Position.X - halfSize.X, selPart.Position.X + halfSize.X),
		math.clamp(ptOnPart.Y, selPart.Position.Y - halfSize.Y, selPart.Position.Y + halfSize.Y),
		math.clamp(ptOnPart.Z, selPart.Position.Z - halfSize.Z, selPart.Position.Z + halfSize.Z)
	)
	return newPos, ptOffPart
end

function getClosestPlayer()
	local closestPlayer, closestDistance = nil, 1 / 0
	local camera = workspace.CurrentCamera
	local localPlayer = game.Players.LocalPlayer
	local mouse = localPlayer:GetMouse()
	local mousePos = mouse.hit.p
	local players = game:GetService("Players"):GetPlayers()
	local knockedCheck = KnockedCheck
	local grabbedCheck = GrabbedCheck
	local wallCheck = wallCheck
	local i = 1
	while i <= #players do
		local player = players[i]
		if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local rootPart = player.Character.HumanoidRootPart
			local OnScreen = camera:WorldToViewportPoint(rootPart.Position)
			local distance = (rootPart.Position - mousePos).magnitude
			if
				distance < closestDistance
				and knockedCheck(player)
				and grabbedCheck(player)
				and OnScreen
				and wallCheck(rootPart.Position, { localPlayer, player.Character })
			 then
				closestPlayer = player
				closestDistance = distance
			end
		end
		i = i + 1
	end
	return closestPlayer
end

function isAnti(trgt)
	local c = trgt.Character
	local calculateVelocityAverage = smoothVelocity(c)
	return c.HumanoidRootPart.Velocity.Magnitude > 50 and calculateVelocityAverage * Krypton.newest.Prediction
		or c.HumanoidRootPart.Velocity * Krypton.newest.Prediction
end

game:GetService("RunService").Heartbeat:Connect(function()
	local vector2Pos = game:GetService("UserInputService"):GetMouseLocation()
	if TARGET and Krypton.newest.Enabled then
		rPoint = cls(TARGET.Character)
	end
	if TARGET and FOV.StickFov and Krypton.newest.Enabled then
		local pos = workspace.CurrentCamera:worldToViewportPoint(TARGET.Character.HumanoidRootPart.Position)
		Circle.Position = Vector2.new(pos.X, pos.Y)
	else
		Circle.Position = Vector2.new(vector2Pos.X, vector2Pos.Y)
	end
	if Krypton.newest.Enabled then
		TARGET = getClosestPlayer()
	end
	UpdateText()
	if TARGET and Krypton.newest.Enabled then
		getgenv().Result = getClosestPart(TARGET.Character)
	end

	if not Krypton.newest.AntiAimViewer and TARGET and TARGET.Character then
		local CLS = cls(TARGET.Character)
		if CLS ~= nil then
			local targetCFrame = CFrame.new(CLS) + isAnti(TARGET)
			targetVelocity = Vector3.new(targetCFrame.X, targetCFrame.Y, targetCFrame.Z)
			if targetVelocity then
				game:GetService("ReplicatedStorage")
					:WaitForChild("MainEvent")
					:FireServer("UpdateMousePos", targetVelocity)
			end
		end
	end

	if autoShooting and locked then
		toolTarget = getClosestPlayer()
		if toolTarget and toolTarget.Character then
			local targetCFrame = CFrame.new(cls(toolTarget.Character)) + isAnti(toolTarget)
			targetVelocity = Vector3.new(targetCFrame.X, targetCFrame.Y, targetCFrame.Z)
			if toolTarget and targetVelocity then
				game:GetService("ReplicatedStorage")
					:WaitForChild("MainEvent")
					:FireServer("UpdateMousePos", targetVelocity)
			end
		end
	end
end)

local autoGuns: table = {}
local regGuns: table = {}

local isAuto = function(v: tool)
	if v.MaxAmmo.Value >= 20 and v.Name ~= "[Glock]" then
		return true
	else
		return false
	end
end

local gunLoop
local ToolActivated = function(autoGun: bool)
	autoGun = autoGun or false
	if Krypton.newest.AntiAimViewer then
		toolTarget = getClosestPlayer()
		if toolTarget and toolTarget.Character then
			locked = true
			local targetCFrame = CFrame.new(cls(toolTarget.Character)) + isAnti(toolTarget)
			targetVelocity = Vector3.new(targetCFrame.X, targetCFrame.Y, targetCFrame.Z)
			if locked and toolTarget and targetVelocity then
				game:GetService("ReplicatedStorage")
					:WaitForChild("MainEvent")
					:FireServer("UpdateMousePos", targetVelocity)

				if autoGun then
					autoShooting = true
				end
			end
		end
	end
end

local ToolDeactivated = function()
	locked = false
	autoShooting = false
end

local GetConnections = function(Tool)
	if Tool:IsA("Tool") and Tool:FindFirstChild("MaxAmmo") then
		if ToolConnection then
			ToolConnection:Disconnect()
			ToolConnection = nil
		end
		if ToolDisconnection then
			ToolDisconnection:Disconnect()
			ToolDisconnection = nil
		end

		if isAuto(Tool) then
			ToolConnection = Tool.Activated:Connect(function()
				ToolActivated(true)
			end)
			ToolDisconnection = Tool.Deactivated:Connect(ToolDeactivated)
		else
			ToolConnection = Tool.Activated:Connect(ToolActivated)
			ToolDisconnection = Tool.Deactivated:Connect(ToolDeactivated)
		end
	end
end

local WhenCharacterAdded = function(Character)
	Character.ChildAdded:Connect(GetConnections)
end

WhenCharacterAdded(game.Players.LocalPlayer.Character)
game.Players.LocalPlayer.CharacterAdded:Connect(WhenCharacterAdded)
