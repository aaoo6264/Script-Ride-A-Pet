local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- ===================== CONFIG =====================
local CONFIG = {
	FolderName = "RenderedEggs", -- ชื่อโฟลเดอร์ใน Workspace
	AccentColor = Color3.fromRGB(255, 200, 40), -- สีไฮไลต์ / เส้นทาง
	CardSize = Vector2.new(112, 140),
	MarkerSpacing = 4, -- ระยะห่างจุด waypoint (studs)
	MarkerHeight = 1.5, -- ยกจุด waypoint ให้ลอยเหนือพื้นเล็กน้อย

	-- ระบบวาปไปหาไข่เมื่อคลิก
	TeleportEnabled = false, -- false = ปิด, true = เปิด
	TeleportYOffset = 3, -- วาปไปสูงกว่าไข่กี่ studs
	SpawnName = "Spawn", -- ชื่อจุด Spawn หลักใน Workspace
	SpawnStepDistance = 40, -- วาปไป Spawn ทีละกี่ studs
	SpawnStepDelay = 0.03, -- หน่วงเวลาแต่ละช่วง (วินาที)
}
-- ====================================================

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local eggsFolder = Workspace:WaitForChild(CONFIG.FolderName)

-- ===================== GUI SETUP =====================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

-- ปุ่มเปิด/ปิดแกลเลอรี
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.fromOffset(140, 40)
toggleButton.Position = UDim2.new(0, 16, 0, 16)
toggleButton.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
toggleButton.Text = "🥚 ไข่ทั้งหมด"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 16
toggleButton.Parent = screenGui
Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 10)

-- กรอบหลักของแกลเลอรี
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromOffset(400, 460)
mainFrame.Position = UDim2.new(0, 16, 0, 64)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
mainFrame.Visible = false
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 14)

local headerFrame = Instance.new("Frame")
headerFrame.Size = UDim2.new(1, 0, 0, 44)
headerFrame.BackgroundTransparency = 1
headerFrame.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Text = "ไข่ทั้งหมด"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(1, -310, 1, 0)
titleLabel.Position = UDim2.fromOffset(16, 0)
titleLabel.Parent = headerFrame

local clearButton = Instance.new("TextButton")
clearButton.Text = "ล้างเส้นทาง"
clearButton.Font = Enum.Font.GothamMedium
clearButton.TextSize = 13
clearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
clearButton.BackgroundColor3 = Color3.fromRGB(60, 60, 72)
clearButton.Size = UDim2.fromOffset(90, 30)
clearButton.Position = UDim2.new(1, -100, 0, 7)
clearButton.Parent = headerFrame
Instance.new("UICorner", clearButton).CornerRadius = UDim.new(0, 8)

-- ปุ่มเปิด/ปิดระบบวาป
local teleportButton = Instance.new("TextButton")
teleportButton.Name = "TeleportToggle"
teleportButton.Size = UDim2.fromOffset(90, 30)
teleportButton.Position = UDim2.new(1, -198, 0, 7)
teleportButton.Font = Enum.Font.GothamMedium
teleportButton.TextSize = 13
teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
teleportButton.Parent = headerFrame
Instance.new("UICorner", teleportButton).CornerRadius = UDim.new(0, 8)

local function updateTeleportButton()
	if CONFIG.TeleportEnabled then
		teleportButton.Text = "วาป: เปิด"
		teleportButton.BackgroundColor3 = Color3.fromRGB(55, 145, 85)
	else
		teleportButton.Text = "วาป: ปิด"
		teleportButton.BackgroundColor3 = Color3.fromRGB(120, 55, 55)
	end
end

updateTeleportButton()

teleportButton.MouseButton1Click:Connect(function()
	CONFIG.TeleportEnabled = not CONFIG.TeleportEnabled
	updateTeleportButton()
end)

-- ปุ่มวาปกลับ Spawn หลัก
local spawnButton = Instance.new("TextButton")
spawnButton.Name = "SpawnButton"
spawnButton.Size = UDim2.fromOffset(90, 30)
spawnButton.Position = UDim2.new(1, -296, 0, 7)
spawnButton.BackgroundColor3 = Color3.fromRGB(65, 85, 125)
spawnButton.Text = "Spawn"
spawnButton.Font = Enum.Font.GothamMedium
spawnButton.TextSize = 13
spawnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
spawnButton.Parent = headerFrame
Instance.new("UICorner", spawnButton).CornerRadius = UDim.new(0, 8)

local function getSpawnCFrame()
	local spawnObject = Workspace:FindFirstChild(CONFIG.SpawnName)
	if not spawnObject then
		warn("[EggFinder] ไม่พบ Workspace." .. CONFIG.SpawnName)
		return nil
	end

	if spawnObject:IsA("BasePart") then
		return spawnObject.CFrame
	elseif spawnObject:IsA("Model") then
		return spawnObject:GetPivot()
	end

	local part = spawnObject:FindFirstChildWhichIsA("BasePart", true)
	if part then
		return part.CFrame
	end

	warn("[EggFinder] Workspace." .. CONFIG.SpawnName .. " ไม่มีตำแหน่งที่ใช้วาปได้")
	return nil
end

local function teleportToSpawn()
	local spawnCFrame = getSpawnCFrame()
	if not spawnCFrame then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn("[EggFinder] ไม่พบ HumanoidRootPart สำหรับการวาปไป Spawn")
		return
	end

	local startPosition = hrp.Position
	local targetPosition = spawnCFrame.Position + Vector3.new(0, CONFIG.TeleportYOffset, 0)
	local rotation = spawnCFrame - spawnCFrame.Position

	local distance = (targetPosition - startPosition).Magnitude
	local steps = math.max(1, math.ceil(distance / CONFIG.SpawnStepDistance))

	for i = 1, steps do
		if not hrp.Parent then
			return
		end

		local alpha = i / steps
		local position = startPosition:Lerp(targetPosition, alpha)
		hrp.CFrame = CFrame.new(position) * rotation

		if i < steps then
			task.wait(CONFIG.SpawnStepDelay)
		end
	end

	clearPath()
	print("[EggFinder] ค่อยๆวาปกลับ Spawn แล้ว:", targetPosition, "Steps:", steps)
end

spawnButton.MouseButton1Click:Connect(teleportToSpawn)

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -16, 1, -52)
scrollFrame.Position = UDim2.fromOffset(8, 46)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(CONFIG.CardSize.X, CONFIG.CardSize.Y)
gridLayout.CellPadding = UDim2.fromOffset(8, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scrollFrame

-- ===================== DRAGGABLE TOGGLE BUTTON =====================
-- ให้ผู้เล่นลากปุ่ม "🥚 ไข่ทั้งหมด" ไปวางตรงไหนของจอก็ได้

local function makeDraggable(guiObject)
	local dragging = false
	local dragStartInputPos = nil
	local startPosition = nil
	local didDrag = false
	local DRAG_THRESHOLD = 4 -- พิกเซล, ใช้แยกระหว่าง "คลิก" กับ "ลาก"

	local function updatePosition(input)
		local delta = input.Position - dragStartInputPos
		if not didDrag and delta.Magnitude > DRAG_THRESHOLD then
			didDrag = true
		end
		guiObject.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end

	guiObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			didDrag = false
			dragStartInputPos = input.Position
			startPosition = guiObject.Position

			local connection
			connection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					connection:Disconnect()
				end
			end)
		end
	end)

	guiObject.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updatePosition(input)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updatePosition(input)
		end
	end)

	-- คืนค่าฟังก์ชันเช็คว่ารอบนี้ "ลาก" หรือ "คลิก" เพื่อกันปุ่มเปิด/ปิดแกลเลอรีทำงานผิดจังหวะตอนลาก
	return function()
		return didDrag
	end
end

local toggleWasDragged = makeDraggable(toggleButton)

-- ให้กรอบแกลเลอรี "ขยับตาม" ปุ่มทุกครั้งที่ปุ่มถูกลากไปวางที่ใหม่
local PANEL_GAP = 8 -- ระยะห่างระหว่างปุ่มกับกรอบแกลเลอรี (พิกเซล)

local function updateMainFramePosition()
	local screenSize = screenGui.AbsoluteSize
	local btnPos = toggleButton.AbsolutePosition
	local btnSize = toggleButton.AbsoluteSize
	local panelSize = mainFrame.AbsoluteSize

	-- ค่าเริ่มต้น: วางกรอบไว้ใต้ปุ่ม ชิดขอบซ้ายของปุ่ม
	local targetX = btnPos.X
	local targetY = btnPos.Y + btnSize.Y + PANEL_GAP

	-- ถ้าล้นขอบขวา ให้ขยับไปทางซ้ายแทน
	if targetX + panelSize.X > screenSize.X then
		targetX = math.max(0, screenSize.X - panelSize.X)
	end
	-- ถ้าล้นขอบล่าง ให้ไปโผล่ "เหนือ" ปุ่มแทน
	if targetY + panelSize.Y > screenSize.Y then
		targetY = math.max(0, btnPos.Y - panelSize.Y - PANEL_GAP)
	end

	mainFrame.Position = UDim2.fromOffset(targetX, targetY)
end

toggleButton:GetPropertyChangedSignal("Position"):Connect(updateMainFramePosition)
toggleButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateMainFramePosition)
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateMainFramePosition)

toggleButton.MouseButton1Click:Connect(function()
	if toggleWasDragged() then
		return -- เพิ่งลากปุ่ม ไม่ต้องเปิด/ปิดแกลเลอรี
	end
	updateMainFramePosition()
	mainFrame.Visible = not mainFrame.Visible
end)

-- จัดตำแหน่งกรอบให้ตรงกับปุ่มตั้งแต่แรกเริ่ม
updateMainFramePosition()

-- ===================== HELPERS =====================

-- หาตำแหน่ง (CFrame) ของไข่ ไม่ว่าจะเป็น Model หรือ BasePart
local function getEggCFrame(egg)
	if egg:IsA("Model") then
		return egg:GetPivot()
	elseif egg:IsA("BasePart") then
		return egg.CFrame
	else
		local part = egg:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.CFrame
		end
	end
	return nil
end

-- ===================== HIGHLIGHT =====================

local currentHighlight = nil
local highlightPulseThread = nil

local function clearHighlight()
	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end
	highlightPulseThread = nil
end

local function highlightEgg(egg)
	clearHighlight()

	local highlight = Instance.new("Highlight")
	highlight.Name = "EggFinderHighlight"
	highlight.FillColor = CONFIG.AccentColor
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = egg
	currentHighlight = highlight

	local myThread = {}
	highlightPulseThread = myThread
	task.spawn(function()
		while currentHighlight == highlight and highlightPulseThread == myThread do
			local t1 = TweenService:Create(highlight, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { FillTransparency = 0.85 })
			t1:Play()
			t1.Completed:Wait()
			if not (currentHighlight == highlight and highlightPulseThread == myThread) then break end
			local t2 = TweenService:Create(highlight, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { FillTransparency = 0.35 })
			t2:Play()
			t2.Completed:Wait()
		end
	end)
end

-- ===================== PATH DRAWING =====================

local pathFolder = nil

local function clearPath()
	if pathFolder then
		pathFolder:Destroy()
		pathFolder = nil
	end
end

local function spawnMarker(position, parent)
	local marker = Instance.new("Part")
	marker.Name = "Waypoint"
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(0.5, 0.5, 0.5)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = CONFIG.AccentColor
	marker.Position = position + Vector3.new(0, CONFIG.MarkerHeight, 0)
	marker.Parent = parent

	local attachment = Instance.new("Attachment")
	attachment.Parent = marker
	return marker, attachment
end

local function drawPathTo(targetPosition)
	clearPath()

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	pathFolder = Instance.new("Folder")
	pathFolder.Name = "EggFinderPath"
	pathFolder.Parent = Workspace

	-- ลองคำนวณเส้นทางจริงด้วย PathfindingService
	local waypointPositions = {}
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = CONFIG.MarkerSpacing,
	})

	local ok = pcall(function()
		path:ComputeAsync(hrp.Position, targetPosition)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(path:GetWaypoints()) do
			table.insert(waypointPositions, wp.Position)
		end
	end

	-- ถ้าคำนวณเส้นทางไม่ได้ (หรือได้จุดน้อยเกินไป) ใช้เส้นตรง fallback
	if #waypointPositions < 2 then
		waypointPositions = {}
		local distance = (targetPosition - hrp.Position).Magnitude
		local steps = math.clamp(math.floor(distance / CONFIG.MarkerSpacing), 4, 60)
		for i = 0, steps do
			local alpha = i / steps
			table.insert(waypointPositions, hrp.Position:Lerp(targetPosition, alpha))
		end
	end

	local prevAttachment = nil
	for _, pos in ipairs(waypointPositions) do
		local marker, attachment = spawnMarker(pos, pathFolder)

		if prevAttachment then
			local beam = Instance.new("Beam")
			beam.Attachment0 = prevAttachment
			beam.Attachment1 = attachment
			beam.Width0 = 0.15
			beam.Width1 = 0.15
			beam.Color = ColorSequence.new(CONFIG.AccentColor)
			beam.Transparency = NumberSequence.new(0.2)
			beam.FaceCamera = true
			beam.Parent = marker
		end
		prevAttachment = attachment
	end
end

clearButton.MouseButton1Click:Connect(function()
	clearPath()
	clearHighlight()
end)

-- ===================== TELEPORT =====================

local function teleportToEgg(eggCFrame)
	if not CONFIG.TeleportEnabled then
		return false
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if not hrp then
		warn("[EggFinder] ไม่พบ HumanoidRootPart สำหรับการวาป")
		return false
	end

	local targetPosition = eggCFrame.Position + Vector3.new(0, CONFIG.TeleportYOffset, 0)
	hrp.CFrame = CFrame.new(targetPosition)

	return true
end

-- ===================== GALLERY CARDS =====================

local cardsByEgg = {}

local function createEggCard(egg)
	local card = Instance.new("TextButton")
	card.Name = "Card_" .. egg.Name
	card.Text = ""
	card.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
	card.AutoButtonColor = true
	card.LayoutOrder = 0
	card.Parent = scrollFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	-- ภาพ 3D จริงของไข่ ผ่าน ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, -10, 1, -34)
	viewport.Position = UDim2.fromOffset(5, 5)
	viewport.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	viewport.BorderSizePixel = 0
	viewport.Parent = card
	Instance.new("UICorner", viewport).CornerRadius = UDim.new(0, 8)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local clone = egg:Clone()
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
	clone.Parent = worldModel

	local boundsCFrame, boundsSize
	if clone:IsA("Model") then
		boundsCFrame, boundsSize = clone:GetBoundingBox()
	elseif clone:IsA("BasePart") then
		boundsCFrame, boundsSize = clone.CFrame, clone.Size
	else
		boundsCFrame, boundsSize = CFrame.new(), Vector3.new(4, 4, 4)
	end

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local maxExtent = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z)
	local distance = maxExtent * 1.9 + 1.5
	local camOffset = Vector3.new(distance * 0.55, distance * 0.5, distance * 0.75)
	camera.CFrame = CFrame.lookAt(boundsCFrame.Position + camOffset, boundsCFrame.Position)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -8, 0, 26)
	nameLabel.Position = UDim2.new(0, 4, 1, -28)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = egg.Name
	nameLabel.Parent = card

	card.MouseButton1Click:Connect(function()
		local eggCFrame = getEggCFrame(egg)
		if not eggCFrame then
			return
		end

		highlightEgg(egg)

		if CONFIG.TeleportEnabled then
			-- เปิดวาปอยู่: วาปไปหาไข่ทันที
			if teleportToEgg(eggCFrame) then
				clearPath()
				print("[EggFinder] วาปไปหาไข่:", egg.Name)
			end
		else
			-- ปิดวาป: แสดงเส้นทางเหมือนเดิม
			drawPathTo(eggCFrame.Position)
		end
	end)

	return card
end

local function refreshGallery()
	for _, card in pairs(cardsByEgg) do
		card:Destroy()
	end
	table.clear(cardsByEgg)

	local order = 0
	for _, egg in ipairs(eggsFolder:GetChildren()) do
		order += 1
		local card = createEggCard(egg)
		card.LayoutOrder = order
		cardsByEgg[egg] = card
	end

	titleLabel.Text = string.format("ไข่ทั้งหมด (%d)", order)
end

-- อัปเดตแกลเลอรีอัตโนมัติเมื่อมีไข่เพิ่ม/หาย
eggsFolder.ChildAdded:Connect(function()
	task.wait(0.1)
	refreshGallery()
end)
eggsFolder.ChildRemoved:Connect(function(child)
	local card = cardsByEgg[child]
	if card then
		card:Destroy()
		cardsByEgg[child] = nil
	end
end)

refreshGallery()