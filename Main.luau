--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer

local BUILTIN_THEMES = {
	Dark = { Background = Color3.fromRGB(18, 20, 27), Surface = Color3.fromRGB(27, 30, 39), Card = Color3.fromRGB(35, 39, 50), Popup = Color3.fromRGB(25, 28, 37), Text = Color3.fromRGB(244, 246, 250), SecondaryText = Color3.fromRGB(158, 165, 179), MutedText = Color3.fromRGB(117, 125, 140), Border = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(91, 126, 255), Success = Color3.fromRGB(74, 204, 145), Warning = Color3.fromRGB(255, 190, 83), Error = Color3.fromRGB(255, 103, 118), BackgroundTransparency = 0.08, SurfaceTransparency = 0.12, CardTransparency = 0.16, PopupTransparency = 0.06, BorderTransparency = 0.88 },
	Light = { Background = Color3.fromRGB(239, 242, 248), Surface = Color3.fromRGB(250, 251, 254), Card = Color3.fromRGB(255, 255, 255), Popup = Color3.fromRGB(250, 251, 255), Text = Color3.fromRGB(27, 31, 42), SecondaryText = Color3.fromRGB(93, 101, 119), MutedText = Color3.fromRGB(126, 134, 150), Border = Color3.fromRGB(52, 63, 83), Accent = Color3.fromRGB(63, 103, 245), Success = Color3.fromRGB(33, 156, 105), Warning = Color3.fromRGB(199, 128, 26), Error = Color3.fromRGB(213, 63, 80), BackgroundTransparency = 0.06, SurfaceTransparency = 0.04, CardTransparency = 0.08, PopupTransparency = 0.02, BorderTransparency = 0.88 },
	Midnight = { Background = Color3.fromRGB(10, 14, 28), Surface = Color3.fromRGB(17, 23, 43), Card = Color3.fromRGB(23, 31, 57), Popup = Color3.fromRGB(16, 22, 42), Text = Color3.fromRGB(235, 241, 255), SecondaryText = Color3.fromRGB(145, 160, 192), MutedText = Color3.fromRGB(105, 120, 153), Border = Color3.fromRGB(145, 170, 255), Accent = Color3.fromRGB(115, 143, 255), Success = Color3.fromRGB(70, 209, 166), Warning = Color3.fromRGB(255, 194, 94), Error = Color3.fromRGB(255, 108, 138), BackgroundTransparency = 0.06, SurfaceTransparency = 0.09, CardTransparency = 0.12, PopupTransparency = 0.04, BorderTransparency = 0.86 },
	Glass = { Background = Color3.fromRGB(23, 31, 45), Surface = Color3.fromRGB(39, 51, 70), Card = Color3.fromRGB(57, 71, 91), Popup = Color3.fromRGB(32, 43, 60), Text = Color3.fromRGB(248, 251, 255), SecondaryText = Color3.fromRGB(188, 201, 219), MutedText = Color3.fromRGB(146, 163, 184), Border = Color3.fromRGB(235, 244, 255), Accent = Color3.fromRGB(113, 170, 255), Success = Color3.fromRGB(98, 224, 174), Warning = Color3.fromRGB(255, 205, 121), Error = Color3.fromRGB(255, 132, 150), BackgroundTransparency = 0.22, SurfaceTransparency = 0.25, CardTransparency = 0.3, PopupTransparency = 0.19, BorderTransparency = 0.72 },
}

local DEFAULT_CONFIG = { AnimationSpeed = 0.22, Transparency = 0.0, CornerRadius = 14, Font = Enum.Font.Gotham, AccentColor = nil, Theme = "Dark", UITransparency = true, UIScale = 1, Sounds = false, HoverSound = "", ClickSound = "", NotificationSound = "" }
local Icons
local UI = { Windows = {}, Notifications = {}, Theme = table.clone(BUILTIN_THEMES.Dark), Config = table.clone(DEFAULT_CONFIG), _themeBindings = {}, _connections = {}, _tweens = {}, _destroyed = false, _iconAttempted = false }

local function warnf(message)
	warn("[LarpUI] " .. tostring(message))
end

local function copyTable(source)
	local result = {}
	for key, value in pairs(source) do result[key] = value end
	return result
end

local function safeCallback(callback, ...)
	if typeof(callback) ~= "function" then return end
	local ok, err = pcall(callback, ...)
	if not ok then warnf("Callback error: " .. tostring(err)) end
end

local function trackConnection(owner, connection)
	if owner and owner._connections then table.insert(owner._connections, connection)
	else table.insert(UI._connections, connection) end
	return connection
end

local function disconnectAll(list)
	for _, connection in ipairs(list or {}) do pcall(function() connection:Disconnect() end) end
	table.clear(list or {})
end

local function tween(instance, properties, duration, style, direction)
	if not instance or not instance.Parent then return nil end
	local t = TweenService:Create(instance, TweenInfo.new(duration or UI.Config.AnimationSpeed, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), properties)
	table.insert(UI._tweens, t)
	t:Play()
	t.Completed:Once(function()
		local index = table.find(UI._tweens, t)
		if index then table.remove(UI._tweens, index) end
	end)
	return t
end

local function create(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function playConfiguredSound(name)
	if not UI.Config.Sounds then return end
	local asset = UI.Config[name]
	if asset == nil or asset == "" then return end
	local soundId = tostring(asset)
	if not string.find(soundId, "rbxassetid://", 1, true) and tonumber(soundId) then soundId = "rbxassetid://" .. soundId end
	local sound = create("Sound", { SoundId = soundId, Volume = 0.35 }, SoundService)
	pcall(function() sound:Play() end)
	Debris:AddItem(sound, 6)
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or UI.Config.CornerRadius) }, parent)
end

local function stroke(parent, transparency, color)
	local outline = create("UIStroke", { Color = color or UI.Theme.Border, Transparency = transparency or UI.Theme.BorderTransparency, Thickness = 1 }, parent)
	table.insert(UI._themeBindings, { Instance = outline, Update = function() outline.Color = color or UI.Theme.Border; outline.Transparency = UI.Theme.BorderTransparency end })
	return outline
end

local function padding(parent, left, top, right, bottom)
	return create("UIPadding", { PaddingLeft = UDim.new(0, left or 0), PaddingTop = UDim.new(0, top or 0), PaddingRight = UDim.new(0, right or 0), PaddingBottom = UDim.new(0, bottom or 0) }, parent)
end

local function attachTooltip(window, target, text, owner)
	if not text or text == "" then return end
	local current
	local hoverToken = 0
	local function hide()
		if current and current.Parent then current:Destroy() end
		current = nil
	end
	local function show()
		if not target.Parent or current then return end
		local bubble = create("TextLabel", { Name = "Tooltip", BackgroundColor3 = UI.Theme.Popup, BackgroundTransparency = UI.Theme.PopupTransparency, TextColor3 = UI.Theme.Text, Font = UI.Config.Font, TextSize = 11, Text = tostring(text), TextWrapped = true, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset(target.AbsolutePosition.X + target.AbsoluteSize.X / 2, target.AbsolutePosition.Y - 8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 90 }, window._overlay)
		padding(bubble, 10, 6, 10, 6); corner(bubble, 8); stroke(bubble, UI.Theme.BorderTransparency)
		current = bubble
	end
	trackConnection(owner, target.MouseEnter:Connect(function()
		hoverToken += 1
		local token = hoverToken
		task.delay(0.48, function() if token == hoverToken then show() end end)
	end))
	trackConnection(owner, target.MouseLeave:Connect(function() hoverToken += 1; hide() end))
	trackConnection(owner, target.AncestryChanged:Connect(function(_, parent) if not parent then hide() end end))
	owner._connections[#owner._connections + 1] = { Disconnect = hide }
end

local function bindTheme(instance, property, key, transparencyKey)
	local update = function()
		if instance.Parent then
			local value = UI.Theme[key]
			if value ~= nil then instance[property] = value end
			if transparencyKey then
				if UI.Config.UITransparency then
					local extra = tonumber(UI.Config.Transparency) or 0
					instance.BackgroundTransparency = math.clamp((UI.Theme[transparencyKey] or 0) + extra, 0, 0.92)
				else
					instance.BackgroundTransparency = 0
				end
			end
		end
		return instance.Parent ~= nil
	end
	table.insert(UI._themeBindings, { Instance = instance, Update = update })
end

local function refreshThemeBindings()
	local liveBindings = {}
	for _, binding in ipairs(UI._themeBindings) do
		if binding.Instance and binding.Instance.Parent then
			pcall(binding.Update)
			table.insert(liveBindings, binding)
		end
	end
	UI._themeBindings = liveBindings
	for _, window in ipairs(UI.Windows) do
		for _, tab in ipairs(window._tabs or {}) do
			local active = tab._indicator and tab._indicator.Visible
			if tab._navButton then tab._navButton.BackgroundColor3 = active and UI.Theme.Accent or UI.Theme.Card end
			if tab._navLabel then tab._navLabel.TextColor3 = active and UI.Theme.Text or UI.Theme.SecondaryText end
		end
	end
end

local themeCleanupQueued = false
local function queueThemeCleanup()
	if themeCleanupQueued then return end
	themeCleanupQueued = true
	task.defer(function()
		themeCleanupQueued = false
		refreshThemeBindings()
	end)
end

local function label(parent, text, size, color, font, props)
	local base = { BackgroundTransparency = 1, Text = tostring(text or ""), TextColor3 = color or UI.Theme.Text, Font = font or UI.Config.Font, TextSize = size or 14, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, RichText = false }
	for k, v in pairs(props or {}) do base[k] = v end
	local item = create("TextLabel", base, parent)
	local colorKey = if color == UI.Theme.SecondaryText then "SecondaryText" elseif color == UI.Theme.Accent then "Accent" elseif color == UI.Theme.MutedText then "MutedText" else "Text"
	bindTheme(item, "TextColor3", colorKey)
	return item
end

local function newButton(parent, text, size, background, textColor)
	local colorKey = (background == nil or background == UI.Theme.Card) and "Card" or background == UI.Theme.Accent and "Accent" or nil
	local idleTransparency = colorKey and UI.Theme.CardTransparency or 0
	local button = create("TextButton", { AutoButtonColor = false, Text = text or "", TextColor3 = textColor or UI.Theme.Text, Font = UI.Config.Font, TextSize = 14, BackgroundColor3 = background or UI.Theme.Card, BackgroundTransparency = idleTransparency, Size = size or UDim2.new(1, 0, 0, 42), BorderSizePixel = 0, Selectable = true }, parent)
	corner(button, math.min(UI.Config.CornerRadius, 12))
	if colorKey then bindTheme(button, "BackgroundColor3", colorKey, colorKey == "Card" and "CardTransparency" or nil) end
	button.MouseEnter:Connect(function() playConfiguredSound("HoverSound"); if button.Active then tween(button, { BackgroundTransparency = math.max((UI.Theme.CardTransparency or 0.16) - 0.08, 0) }, 0.12) end end)
	button.MouseLeave:Connect(function() tween(button, { BackgroundTransparency = colorKey and UI.Theme.CardTransparency or 0 }, 0.15) end)
	button.MouseButton1Down:Connect(function() tween(button, { Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, math.max(size.Y.Offset - 1, 1)) }, 0.08) end)
	button.MouseButton1Up:Connect(function() tween(button, { Size = size }, 0.1) end)
	button.Activated:Connect(function() playConfiguredSound("ClickSound") end)
	return button
end

local function ensureIcons()
	if Icons or UI._iconAttempted then return Icons end
	UI._iconAttempted = true
	if typeof(loadstring) == "function" then
		local ok, result = pcall(function()
			return loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"))()
		end)
		if ok and result then
			Icons = result
			pcall(function() if Icons.SetIconsType then Icons.SetIconsType("lucide") end end)
		else warnf("Footagesus Icons V2 could not be loaded; icon slots will remain empty. " .. tostring(result)) end
	else
		warnf("This runtime does not provide loadstring/game:HttpGetAsync; Footagesus Icons V2 is unavailable.")
	end
	return Icons
end

local function makeIcon(parent, name, size, color)
	if not name or name == "" then return nil end
	local lib = ensureIcons()
	if not lib then return nil end
	local result
	if lib.Image then
		local ok, wrapped = pcall(function() return lib.Image({ Icon = name, Colors = { color or UI.Theme.SecondaryText }, Size = size or UDim2.fromOffset(18, 18) }) end)
		if ok and wrapped then result = wrapped.IconFrame or (typeof(wrapped) == "Instance" and wrapped or nil) end
	end
	if not result and lib.GetIcon then
		local ok, asset = pcall(function() return lib.GetIcon(name) end)
		if ok then
			local imageId, metadata
			if typeof(asset) == "string" then imageId = asset
			elseif typeof(asset) == "table" then imageId, metadata = asset[1], asset[2] end
			if typeof(imageId) == "string" then
				result = create("ImageLabel", { BackgroundTransparency = 1, Image = imageId, ImageColor3 = color or UI.Theme.SecondaryText, ImageRectSize = metadata and metadata.ImageRectSize or Vector2.zero, ImageRectOffset = metadata and (metadata.ImageRectPosition or metadata.ImageRectOffset) or Vector2.zero, Size = size or UDim2.fromOffset(18, 18) })
			end
		end
	end
	local ok = result ~= nil
	if ok and result and result:IsA("GuiObject") then
		result.Size = size or UDim2.fromOffset(18, 18)
		result.BackgroundTransparency = 1
		result.Parent = parent
		local colorKey = color == UI.Theme.Accent and "Accent" or "SecondaryText"
		if result:IsA("ImageLabel") or result:IsA("ImageButton") then bindTheme(result, "ImageColor3", colorKey) end
		for _, descendant in ipairs(result:GetDescendants()) do
			if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then bindTheme(descendant, "ImageColor3", colorKey) end
		end
		return result
	end
	return nil
end

local function newScreenGui()
	local gui = create("ScreenGui", { Name = "LarpUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false, DisplayOrder = 50 }, LocalPlayer:WaitForChild("PlayerGui"))
	pcall(function() gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
	return gui
end

local function makeRoot()
	local gui = newScreenGui()
	local scale = create("UIScale", { Scale = UI.Config.UIScale }, gui)
	local overlay = create("Frame", { Name = "OverlayRoot", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, gui)
	return gui, overlay, scale
end

local function styleSurface(frame, key, transparencyKey, radius)
	frame.BackgroundColor3 = UI.Theme[key]
	frame.BackgroundTransparency = UI.Config.UITransparency and math.clamp((UI.Theme[transparencyKey] or 0) + UI.Config.Transparency, 0, 0.92) or 0
	corner(frame, radius)
	stroke(frame, UI.Theme.BorderTransparency, UI.Theme.Border)
	bindTheme(frame, "BackgroundColor3", key, transparencyKey)
end

local function greeting()
	local hour = tonumber(os.date("%H")) or 12
	local period = if hour < 12 then "Morning" elseif hour < 18 then "Afternoon" else "Evening"
	return "Good " .. period .. ", " .. (LocalPlayer and LocalPlayer.Name or "Player")
end

local function makeComponent(frame, name, description)
	local object = { Frame = frame, _connections = {}, _destroyed = false, _nameLabel = nil, _descriptionLabel = nil }
	function object:SetVisible(visible) if self.Frame then self.Frame.Visible = visible == true end end
	function object:SetName(value) if self._nameLabel then self._nameLabel.Text = tostring(value) end end
	function object:SetDescription(value) if self._descriptionLabel then self._descriptionLabel.Text = tostring(value); self._descriptionLabel.Visible = value ~= nil and value ~= "" end end
	function object:Destroy() if self._destroyed then return end; self._destroyed = true; disconnectAll(self._connections); if self.Frame then self.Frame:Destroy() end; queueThemeCleanup() end
	object.Name = name
	object.Description = description
	return object
end

local function controlFrame(section, height)
	local frame = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), AutomaticSize = Enum.AutomaticSize.None }, section._body)
	return frame
end

local function controlText(frame, name, description, rightWidth)
	local main = label(frame, name or "Control", 14, UI.Theme.Text, UI.Config.Font, { Size = UDim2.new(1, -(rightWidth or 96), 0, 20), Position = UDim2.fromOffset(0, description and description ~= "" and 5 or 12), TextTruncate = Enum.TextTruncate.AtEnd })
	local desc
	if description and description ~= "" then desc = label(frame, description, 11, UI.Theme.SecondaryText, UI.Config.Font, { Size = UDim2.new(1, -(rightWidth or 96), 0, 16), Position = UDim2.fromOffset(0, 27), TextTruncate = Enum.TextTruncate.AtEnd }) end
	return main, desc
end

local Library = {}
Library.__index = Library

function Library:CreateWindow(options)
	options = options or {}
	if not LocalPlayer then warnf("CreateWindow must run on a Roblox client with LocalPlayer."); return nil end
	local gui, overlay, scale = makeRoot()
	local size = options.Size or UDim2.fromOffset(920, 620)
	local minSize = options.MinSize or Vector2.new(620, 430)
	if typeof(size) ~= "UDim2" then warnf("Window Size must be a UDim2; using 920×620."); size = UDim2.fromOffset(920, 620) end
	if typeof(minSize) ~= "Vector2" then warnf("Window MinSize must be a Vector2; using 620×430."); minSize = Vector2.new(620, 430) end
	local window = { _gui = gui, _overlay = overlay, _scale = scale, _connections = {}, _components = {}, _tabs = {}, _notifications = {}, _destroyed = false, _minimized = false, _activePopover = nil, _state = {}, _keybinds = {}, Title = options.Title or "LarpUI" }
	setmetatable(window, { __index = self })
	table.insert(UI.Windows, window)
	local shadow = create("ImageLabel", { Name = "Shadow", BackgroundTransparency = 1, Image = "rbxassetid://1316045217", ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.55, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(10, 10, 118, 118), Size = UDim2.new(1, 28, 1, 28), Position = UDim2.fromOffset(-14, -14), ZIndex = 1 }, overlay)
	local shell = create("Frame", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size, BackgroundColor3 = UI.Theme.Background, BackgroundTransparency = UI.Theme.BackgroundTransparency, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2 }, overlay)
	create("UISizeConstraint", { MinSize = minSize }, shell)
	window._shell, window._shadow = shell, shadow
	styleSurface(shell, "Background", "BackgroundTransparency", UI.Config.CornerRadius + 3)
	shadow.AnchorPoint = shell.AnchorPoint
	shadow.Position = UDim2.new(shell.Position.X.Scale, shell.Position.X.Offset - 14, shell.Position.Y.Scale, shell.Position.Y.Offset - 14)
	shadow.Size = UDim2.new(size.X.Scale, size.X.Offset + 28, size.Y.Scale, size.Y.Offset + 28)
	local top = create("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), ZIndex = 3 }, shell)
	window._header = top
	local titleIcon = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 17), Size = UDim2.fromOffset(24, 24) }, top)
	makeIcon(titleIcon, options.Icon or "layers-3", UDim2.fromOffset(22, 22), UI.Theme.Accent)
	local title = label(top, options.Title or "LarpUI", 15, UI.Theme.Text, Enum.Font.GothamSemibold, { Position = UDim2.fromOffset(52, 9), Size = UDim2.new(0, 250, 0, 21) })
	local subtitle = label(top, options.Subtitle or "Premium Interface", 11, UI.Theme.SecondaryText, UI.Config.Font, { Position = UDim2.fromOffset(52, 30), Size = UDim2.new(0, 250, 0, 16) })
	window._title, window._subtitle = title, subtitle
	local actions = create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), Size = UDim2.fromOffset(126, 38), ZIndex = 5 }, top)
	local actionLayout = create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }, actions)
	local function actionButton(icon, tooltip, fn)
		local b = newButton(actions, "", UDim2.fromOffset(34, 34), UI.Theme.Card)
		b.BackgroundTransparency = 0.35
		local holder = create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18) }, b)
		makeIcon(holder, icon, UDim2.fromOffset(17, 17), UI.Theme.SecondaryText)
		b.Activated:Connect(fn)
		return b
	end
	window._minButton = actionButton("minus", "Minimize", function() window:Minimize() end)
	if options.Maximize ~= false then window._maxButton = actionButton("maximize-2", "Maximize", function() window:ToggleMaximize() end) end
	window._closeButton = actionButton("x", "Close", function() if options.CloseButtonCallback then safeCallback(options.CloseButtonCallback) end; window:Destroy() end)
	local headerRule = create("Frame", { BackgroundColor3 = UI.Theme.Border, BackgroundTransparency = UI.Theme.BorderTransparency, BorderSizePixel = 0, Position = UDim2.new(0, 14, 0, 57), Size = UDim2.new(1, -28, 0, 1), ZIndex = 3 }, shell)
	bindTheme(headerRule, "BackgroundColor3", "Border")
	local body = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -90), ZIndex = 3 }, shell)
	window._body = body
	local sidebar = create("Frame", { Name = "Sidebar", BackgroundTransparency = UI.Theme.SurfaceTransparency, BackgroundColor3 = UI.Theme.Surface, Size = UDim2.new(0, 202, 1, 0), BorderSizePixel = 0, ZIndex = 3 }, body)
	window._sidebar = sidebar
	bindTheme(sidebar, "BackgroundColor3", "Surface", "SurfaceTransparency")
	local sidePad = padding(sidebar, 12, 16, 12, 12)
	local nav = create("ScrollingFrame", { Name = "Navigation", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -68), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = UI.Theme.MutedText, ZIndex = 4 }, sidebar)
	create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, nav)
	window._nav = nav
	local content = create("Frame", { Name = "PageArea", BackgroundTransparency = 1, Position = UDim2.new(0, 202, 0, 0), Size = UDim2.new(1, -202, 1, 0), ZIndex = 3 }, body)
	window._pageArea = content
	local pageHeader = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 18), Size = UDim2.new(1, -48, 0, 55), ZIndex = 4 }, content)
	window._pageTitle = label(pageHeader, "Home", 22, UI.Theme.Text, Enum.Font.GothamSemibold, { Size = UDim2.new(1, -180, 0, 30), Position = UDim2.fromOffset(0, 1) })
	window._pageSubtitle = label(pageHeader, "Your space, at a glance.", 12, UI.Theme.SecondaryText, UI.Config.Font, { Size = UDim2.new(1, -180, 0, 19), Position = UDim2.fromOffset(0, 31) })
	local searchBox = create("TextBox", { ClearTextOnFocus = false, PlaceholderText = "Search controls", Text = "", PlaceholderColor3 = UI.Theme.MutedText, TextColor3 = UI.Theme.Text, Font = UI.Config.Font, TextSize = 12, BackgroundColor3 = UI.Theme.Card, BackgroundTransparency = UI.Theme.CardTransparency, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 10), Size = UDim2.fromOffset(168, 34), ZIndex = 5 }, pageHeader)
	corner(searchBox, 11); stroke(searchBox, UI.Theme.BorderTransparency)
	bindTheme(searchBox, "BackgroundColor3", "Card", "CardTransparency")
	local searchIcon = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(18, 18), ZIndex = 6 }, searchBox)
	makeIcon(searchIcon, "search", UDim2.fromOffset(16, 16), UI.Theme.MutedText)
	searchBox.Position = UDim2.new(1, 0, 0, 10)
	local pageScroll = create("ScrollingFrame", { Name = "Pages", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 1, -76), CanvasSize = UDim2.new(), ScrollBarThickness = 4, ScrollBarImageColor3 = UI.Theme.MutedText, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 4 }, content)
	window._pages = pageScroll
	local footer = create("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -32), Size = UDim2.new(1, 0, 0, 32), ZIndex = 4 }, shell)
	window._footer = footer
	local footerRule = create("Frame", { BackgroundColor3 = UI.Theme.Border, BackgroundTransparency = UI.Theme.BorderTransparency, BorderSizePixel = 0, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -28, 0, 1) }, footer)
	bindTheme(footerRule, "BackgroundColor3", "Border")
	label(footer, options.FooterText or "LarpUI", 10, UI.Theme.MutedText, UI.Config.Font, { Position = UDim2.fromOffset(18, 3), Size = UDim2.new(0, 180, 0, 22) })
	label(footer, options.Version or "v1.0.0", 10, UI.Theme.MutedText, UI.Config.Font, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 3), Size = UDim2.new(0, 100, 0, 22), TextXAlignment = Enum.TextXAlignment.Right })
	local profileArea = create("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 1, -65), Size = UDim2.new(0, 178, 0, 53), ZIndex = 4 }, sidebar)
	local profileCard = create("Frame", { BackgroundColor3 = UI.Theme.Card, BackgroundTransparency = UI.Theme.CardTransparency, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 4 }, profileArea)
	corner(profileCard, 13); stroke(profileCard, UI.Theme.BorderTransparency); bindTheme(profileCard, "BackgroundColor3", "Card", "CardTransparency")
	local avatar = create("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 8), Size = UDim2.fromOffset(36, 36), Image = "", ZIndex = 5 }, profileCard); corner(avatar, 18)
	if LocalPlayer then task.spawn(function() local ok, image = pcall(function() return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end); if ok and avatar.Parent then avatar.Image = image end end) end
	label(profileCard, LocalPlayer and LocalPlayer.Name or "Player", 12, UI.Theme.Text, Enum.Font.GothamSemibold, { Position = UDim2.fromOffset(53, 8), Size = UDim2.new(1, -62, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	label(profileCard, LocalPlayer and LocalPlayer.DisplayName or "", 10, UI.Theme.SecondaryText, UI.Config.Font, { Position = UDim2.fromOffset(53, 26), Size = UDim2.new(1, -62, 0, 15), TextTruncate = Enum.TextTruncate.AtEnd })
	window._profileAvatar = avatar
	window._searchBox = searchBox
	window._minimizedLauncher = create("TextButton", { Name = "Launcher", AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 90), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = UI.Theme.Surface, BackgroundTransparency = UI.Theme.SurfaceTransparency, BorderSizePixel = 0, Visible = false, ZIndex = 20 }, overlay)
	corner(window._minimizedLauncher, 22); stroke(window._minimizedLauncher, UI.Theme.BorderTransparency); bindTheme(window._minimizedLauncher, "BackgroundColor3", "Surface", "SurfaceTransparency")
	makeIcon(window._minimizedLauncher, options.Icon or "layers-3", UDim2.fromOffset(24, 24), UI.Theme.Accent)
	window._minimizedLauncher.Activated:Connect(function() window:Restore() end)
	local camera = workspace.CurrentCamera
	local function fitScale()
		if not camera or not gui.Parent then return end
		local viewport = camera.ViewportSize
		local targetW, targetH = if size.X.Scale == 0 then size.X.Offset else viewport.X * size.X.Scale, if size.Y.Scale == 0 then size.Y.Offset else viewport.Y * size.Y.Scale
		local available = math.min((viewport.X - 32) / targetW, (viewport.Y - 40) / targetH, 1)
		scale.Scale = math.clamp(available * (tonumber(UI.Config.UIScale) or 1), 0.62, 1.1)
	end
	window._fitScale = fitScale
	if camera then trackConnection(window, camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)) end
	fitScale()
	local selectedTab
	local function applySearch(query)
		query = string.lower(query or "")
		for _, tab in ipairs(window._tabs) do
			for _, component in ipairs(tab._components) do
				local frame = component.Frame
				if frame and frame.Parent then frame.Visible = query == "" or string.find(string.lower((component.Name or "") .. " " .. (component.Description or "")), query, 1, true) ~= nil end
			end
		end
	end
	trackConnection(window, searchBox:GetPropertyChangedSignal("Text"):Connect(function() applySearch(searchBox.Text) end))
	window._applySearch = applySearch
	local openTab
	openTab = function(tab)
		selectedTab = tab
		window._pageTitle.Text = tab.Name
		window._pageSubtitle.Text = tab.Subtitle or ""
		for _, item in ipairs(window._tabs) do
			local active = item == tab
			item._page.Visible = active
			item._navButton.BackgroundTransparency = active and 0.12 or 1
			item._navButton.BackgroundColor3 = active and UI.Theme.Accent or UI.Theme.Card
			item._indicator.Visible = active
			item._navLabel.TextColor3 = active and UI.Theme.Text or UI.Theme.SecondaryText
		end
	end
	window._openTab = openTab
	function window:CreateTab(tabOptions)
		tabOptions = tabOptions or {}
		local tabName = tostring(tabOptions.Name or "Tab")
		local page = create("ScrollingFrame", { Name = tabName .. "Page", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -48, 1, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = UI.Theme.MutedText, Visible = false, ZIndex = 4 }, pageScroll)
		local pageList = create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14) }, page)
		local navButton = create("TextButton", { Name = tabName, AutoButtonColor = false, Text = "", BackgroundColor3 = UI.Theme.Card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), BorderSizePixel = 0, ZIndex = 5 }, nav)
		corner(navButton, 11)
		local indicator = create("Frame", { BackgroundColor3 = UI.Theme.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 9), Size = UDim2.new(0, 3, 0, 24), Visible = false, ZIndex = 6 }, navButton); corner(indicator, 2); bindTheme(indicator, "BackgroundColor3", "Accent")
		local iconFrame = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(18, 18), ZIndex = 6 }, navButton)
		makeIcon(iconFrame, tabOptions.Icon or "circle", UDim2.fromOffset(17, 17), UI.Theme.SecondaryText)
		local navLabel = label(navButton, tabName, 12, UI.Theme.SecondaryText, UI.Config.Font, { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -67, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }); navLabel.ZIndex = 6
		if tabOptions.Badge then local badge = label(navButton, tostring(tabOptions.Badge), 10, UI.Theme.Text, UI.Config.Font, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(25, 18), BackgroundTransparency = 0, BackgroundColor3 = UI.Theme.Accent, TextXAlignment = Enum.TextXAlignment.Center }); corner(badge, 8); bindTheme(badge, "BackgroundColor3", "Accent") end
		local tab = { Name = tabName, Subtitle = tabOptions.Subtitle or "", Icon = tabOptions.Icon, _page = page, _layout = pageList, _navButton = navButton, _indicator = indicator, _navLabel = navLabel, _components = {}, _sections = {}, _window = window }
		setmetatable(tab, { __index = Library })
		table.insert(window._tabs, tab)
		navButton.Activated:Connect(function() window._openTab(tab) end)
		navButton.MouseEnter:Connect(function() if selectedTab ~= tab then tween(navButton, { BackgroundTransparency = 0.75 }, 0.12) end end)
		navButton.MouseLeave:Connect(function() if selectedTab ~= tab then tween(navButton, { BackgroundTransparency = 1 }, 0.12) end end)
		function tab:SetBadge(value)
			local existing = navButton:FindFirstChild("Badge")
			if existing then existing:Destroy() end
			if value ~= nil and value ~= "" then local badge = label(navButton, tostring(value), 10, UI.Theme.Text, UI.Config.Font, { Name = "Badge", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(25, 18), BackgroundTransparency = 0, BackgroundColor3 = UI.Theme.Accent, TextXAlignment = Enum.TextXAlignment.Center }); corner(badge, 8) end
		end
		function tab:CreateSection(sectionOptions)
			sectionOptions = sectionOptions or {}
			local sectionFrame = create("Frame", { Name = tostring(sectionOptions.Name or "Section"), BackgroundColor3 = UI.Theme.Surface, BackgroundTransparency = UI.Theme.SurfaceTransparency, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 54), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 4 }, page)
			styleSurface(sectionFrame, "Surface", "SurfaceTransparency", UI.Config.CornerRadius)
			local sectionPadding = padding(sectionFrame, 15, 12, 15, 14)
			local stack = create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, sectionFrame)
			local header = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 23), LayoutOrder = 0 }, sectionFrame)
			local sectionIcon = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 2) }, header)
			if sectionOptions.Icon then makeIcon(sectionIcon, sectionOptions.Icon, UDim2.fromOffset(16, 16), UI.Theme.Accent) end
			local sectionTitle = label(header, sectionOptions.Name or "Section", 13, UI.Theme.Text, Enum.Font.GothamSemibold, { Position = UDim2.fromOffset(sectionOptions.Icon and 25 or 0, 0), Size = UDim2.new(1, -25, 1, 0) })
			local bodyFrame = create("Frame", { Name = "Controls", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, sectionFrame)
			create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, bodyFrame)
			local section = { Name = sectionOptions.Name or "Section", Frame = sectionFrame, _body = bodyFrame, _tab = tab, _controls = {} }
			setmetatable(section, { __index = Library })
			table.insert(tab._sections, section)
			local function register(control, config)
				table.insert(section._controls, control); table.insert(tab._components, control); table.insert(window._components, control)
				if config and config.Tooltip then attachTooltip(window, control.Frame, config.Tooltip, control) end
				if window._applySearch and window._searchBox.Text ~= "" then window._applySearch(window._searchBox.Text) end
				return control
			end
			function section:CreateLabel(config)
				config = config or {}; local text = tostring(config.Text or config.Title or "")
				local f = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, config.Description and 43 or 28) }, bodyFrame)
				local iconHolder = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 5), Size = UDim2.fromOffset(18, 18) }, f)
				if config.Icon then makeIcon(iconHolder, config.Icon, UDim2.fromOffset(16, 16), UI.Theme.Accent) end
				local main = label(f, text, config.Title and 14 or 13, UI.Theme.Text, config.Title and Enum.Font.GothamSemibold or UI.Config.Font, { Position = UDim2.fromOffset(config.Icon and 27 or 0, 1), Size = UDim2.new(1, -30, 0, 21), TextXAlignment = config.Alignment == "Center" and Enum.TextXAlignment.Center or config.Alignment == "Right" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left })
				local desc
				if config.Description then desc = label(f, config.Description, 11, UI.Theme.SecondaryText, UI.Config.Font, { Position = UDim2.fromOffset(config.Icon and 27 or 0, 22), Size = UDim2.new(1, -30, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd }) end
				local item = makeComponent(f, text, config.Description); item._nameLabel = main; item._descriptionLabel = desc
				function item:SetText(value) main.Text = tostring(value) end
				return register(item, config)
			end
			function section:CreateButton(config)
				config = config or {}; local name = tostring(config.Name or "Button"); local height = config.Description and 58 or 44
				local f = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height) }, bodyFrame)
				local button = newButton(f, "", UDim2.new(1, 0, 1, 0), UI.Theme.Card); stroke(button, UI.Theme.BorderTransparency)
				local holder = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, (height - 20) / 2), Size = UDim2.fromOffset(20, 20) }, button)
				if config.Icon then makeIcon(holder, config.Icon, UDim2.fromOffset(17, 17), UI.Theme.Accent) end
				local main, desc = controlText(button, name, config.Description, 38); main.Position = UDim2.fromOffset(config.Icon and 42 or 13, config.Description and 10 or 12); if desc then desc.Position = UDim2.fromOffset(config.Icon and 42 or 13, 31) end
				local item = makeComponent(f, name, config.Description); item._nameLabel, item._descriptionLabel = main, desc
				local enabled = config.Disabled ~= true
				button.Activated:Connect(function() if enabled then safeCallback(config.Callback) end end)
				function item:SetEnabled(value) enabled = value == true; button.Active = enabled; button.TextTransparency = enabled and 0 or 0.45; main.TextTransparency = enabled and 0 or 0.45 end
				function item:SetCallback(callback) config.Callback = callback end
				item:SetEnabled(enabled)
				return register(item, config)
			end
			function section:CreateToggle(config)
				config = config or {}; local name = tostring(config.Name or "Toggle"); local value = config.Default == true
				local f = controlFrame(section, config.Description and 58 or 46)
				local main, desc = controlText(f, name, config.Description, 65)
				local track = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(46, 27), BackgroundColor3 = value and UI.Theme.Accent or UI.Theme.MutedText, BackgroundTransparency = value and 0 or 0.52, BorderSizePixel = 0 }, f); corner(track, 14); bindTheme(track, "BackgroundColor3", "Accent")
				local knob = create("Frame", { Position = value and UDim2.new(1, -23, 0, 3) or UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(21, 21), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track); corner(knob, 12)
				local hit = create("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Active = config.Disabled ~= true }, track)
				local item = makeComponent(f, name, config.Description); item._nameLabel = main; item._descriptionLabel = desc; item.Value = value
				function item:Set(nextValue, silent) value = nextValue == true; self.Value = value; tween(knob, { Position = value and UDim2.new(1, -23, 0, 3) or UDim2.fromOffset(3, 3) }, 0.16); tween(track, { BackgroundTransparency = value and 0 or 0.52 }, 0.16); if not silent then safeCallback(config.Callback, value) end end
				function item:Get() return value end
				function item:SetEnabled(enabled) hit.Active = enabled == true; track.BackgroundTransparency = enabled and (value and 0 or 0.52) or 0.72 end
				hit.Activated:Connect(function() if hit.Active then item:Set(not value) end end)
				return register(item, config)
			end
			function section:CreateSlider(config)
				config = config or {}; local name = tostring(config.Name or "Slider"); local minV = tonumber(config.Min) or 0; local maxV = tonumber(config.Max) or 100; if maxV <= minV then warnf("Slider Max must exceed Min; using 100."); maxV = minV + 100 end
				local increment = math.max(tonumber(config.Increment) or 1, 0.000001); local value = math.clamp(tonumber(config.Default) or minV, minV, maxV)
				local f = controlFrame(section, config.Description and 72 or 61); local main, desc = controlText(f, name, config.Description, 78)
				local valLabel = label(f, tostring(value), 12, UI.Theme.Accent, Enum.Font.GothamSemibold, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 9), Size = UDim2.fromOffset(70, 20), TextXAlignment = Enum.TextXAlignment.Right })
				local barY = config.Description and 50 or 39
				local bar = create("Frame", { Position = UDim2.new(0, 0, 0, barY), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = UI.Theme.Card, BackgroundTransparency = 0.05, BorderSizePixel = 0 }, f); corner(bar, 5)
				local fill = create("Frame", { Size = UDim2.new((value - minV) / (maxV - minV), 0, 1, 0), BackgroundColor3 = UI.Theme.Accent, BorderSizePixel = 0 }, bar); corner(fill, 5); bindTheme(fill, "BackgroundColor3", "Accent")
				local knob = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((value - minV) / (maxV - minV), 0, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = UI.Theme.Text, BorderSizePixel = 0, ZIndex = 2 }, bar); corner(knob, 8)
				local hit = create("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, barY - 10), ZIndex = 3, Active = config.Disabled ~= true }, f)
				local item = makeComponent(f, name, config.Description); item._nameLabel = main; item._descriptionLabel = desc; item.Value = value
				local function setValue(raw, silent)
					value = math.clamp(math.floor((raw - minV) / increment + 0.5) * increment + minV, minV, maxV)
					local digits = if increment < 1 then math.clamp(math.ceil(-math.log10(increment)), 0, 6) else 0
					value = tonumber(string.format("%." .. digits .. "f", value)) or value; item.Value = value; local ratio = (value - minV) / (maxV - minV); fill.Size = UDim2.new(ratio, 0, 1, 0); knob.Position = UDim2.new(ratio, 0, 0.5, 0); valLabel.Text = tostring(value); if not silent then safeCallback(config.Callback, value) end
				end
				local function setAt(x, silent)
					local percent = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
					setValue(minV + (maxV - minV) * percent, silent)
				end
				function item:Set(v, silent) setValue(math.clamp(tonumber(v) or minV, minV, maxV), silent) end
				function item:Get() return value end
				local dragging = false
				hit.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; setAt(input.Position.X) end end)
				trackConnection(item, UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setAt(input.Position.X) end end))
				trackConnection(item, UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end))
				return register(item, config)
			end
			local function makeChoice(config, multi)
				config = config or {}; local name = tostring(config.Name or (multi and "Options" or "Dropdown")); local options = config.Options or {}
				if typeof(options) ~= "table" then warnf(name .. ": Options must be a table."); options = {} end
				local chosen = multi and copyTable(config.Defaults or {}) or config.Default
				local f = controlFrame(section, config.Description and 60 or 48); local main, desc = controlText(f, name, config.Description, 190)
				local selection = newButton(f, "", UDim2.new(0, 174, 0, 34), UI.Theme.Card); selection.AnchorPoint = Vector2.new(1, 0.5); selection.Position = UDim2.new(1, 0, 0.5, 0); stroke(selection, UI.Theme.BorderTransparency)
				local selectedText = label(selection, "", 11, UI.Theme.Text, UI.Config.Font, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -35, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
				local arrow = create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(16, 16) }, selection); makeIcon(arrow, "chevron-down", UDim2.fromOffset(15, 15), UI.Theme.SecondaryText)
				local item = makeComponent(f, name, config.Description); item._nameLabel = main; item._descriptionLabel = desc; item.Value = chosen; item.Options = options
				local popup
				local close
				local function renderText() selectedText.Text = multi and (#chosen > 0 and table.concat(chosen, ", ") or "Select options") or tostring(chosen or "Select option") end
				local function optionValue(option) return if typeof(option) == "table" then (option.Value or option.Name) else option end
				local function isChosen(option) local value = optionValue(option); if multi then return table.find(chosen, value) ~= nil end; return chosen == value end
				local function choose(option)
					if multi then local index = table.find(chosen, option); if index then table.remove(chosen, index) else table.insert(chosen, option) end; item.Value = copyTable(chosen); safeCallback(config.Callback, copyTable(chosen))
					else chosen = option; item.Value = option; renderText(); close(); safeCallback(config.Callback, option) end
					if multi and popup then for _, row in ipairs(popup.Rows) do row:SetSelected(isChosen(row.Option)) end; renderText() end
				end
				function item:Get() return multi and copyTable(chosen) or chosen end
				function item:Set(value, silent)
					if multi then chosen = typeof(value) == "table" and copyTable(value) or {}; item.Value = copyTable(chosen)
					else chosen = value; item.Value = value end
					renderText(); if popup then for _, row in ipairs(popup.Rows) do row:SetSelected(isChosen(row.Option)) end end
					if not silent then safeCallback(config.Callback, multi and copyTable(chosen) or chosen) end
				end
				function item:SetOptions(values)
					options = typeof(values) == "table" and values or {}; item.Options = options
					if popup then close() end
					if not multi and table.find(options, chosen) == nil then chosen = nil; item.Value = nil end
					renderText()
				end
				function item:Open()
					if popup then return end
					if window._activePopover then window._activePopover:Destroy() end
					local popFrame = create("Frame", { Name = "ChoicePopup", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(220, 40), BackgroundColor3 = UI.Theme.Popup, BackgroundTransparency = UI.Theme.PopupTransparency, BorderSizePixel = 0, ZIndex = 30 }, overlay)
					styleSurface(popFrame, "Popup", "PopupTransparency", 14)
					local popupSearch
					if config.Search == true or (config.Search ~= false and #options > 6) then popupSearch = create("TextBox", { PlaceholderText = "Search", Text = "", ClearTextOnFocus = false, TextColor3 = UI.Theme.Text, PlaceholderColor3 = UI.Theme.MutedText, Font = UI.Config.Font, TextSize = 12, BackgroundColor3 = UI.Theme.Card, BackgroundTransparency = UI.Theme.CardTransparency, BorderSizePixel = 0, Position = UDim2.fromOffset(9, 8), Size = UDim2.new(1, -18, 0, 31), ZIndex = 31 }, popFrame); corner(popupSearch, 9) end
					local list = create("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, popupSearch and 45 or 7), Size = UDim2.new(1, -16, 1, -(popupSearch and 52 or 14)), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ZIndex = 31 }, popFrame)
					create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)
					local rows = {}
					local function addRow(option)
						local rowButton = newButton(list, "", UDim2.new(1, 0, 0, 34), UI.Theme.Card)
						rowButton.BackgroundTransparency = isChosen(option) and 0.25 or 1
						local iconHolder = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 8), Size = UDim2.fromOffset(17, 17) }, rowButton)
						if typeof(option) == "table" and option.Icon then makeIcon(iconHolder, option.Icon, UDim2.fromOffset(16, 16), UI.Theme.Accent) else makeIcon(iconHolder, isChosen(option) and "check" or "circle", UDim2.fromOffset(14, 14), isChosen(option) and UI.Theme.Accent or UI.Theme.MutedText) end
						local value = if typeof(option) == "table" then option.Name or option.Value or "Option" else tostring(option)
						label(rowButton, value, 12, UI.Theme.Text, UI.Config.Font, { Position = UDim2.fromOffset(31, 0), Size = UDim2.new(1, -36, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
						local record = { Option = optionValue(option), Button = rowButton }
						function record:SetSelected(selected) rowButton.BackgroundTransparency = selected and 0.25 or 1 end
						rowButton.Activated:Connect(function() choose(record.Option) end)
						table.insert(rows, record)
					end
					for _, option in ipairs(options) do addRow(option) end
					local height = math.min(#options, 7) * 37 + (popupSearch and 52 or 14)
					popFrame.Size = UDim2.fromOffset(220, math.max(height, 48))
					local pos = selection.AbsolutePosition; local screen = overlay.AbsoluteSize
					local x = math.clamp(pos.X + selection.AbsoluteSize.X - 220, 8, math.max(screen.X - 228, 8)); local y = pos.Y + selection.AbsoluteSize.Y + 5
					if y + height > screen.Y - 8 then y = math.max(pos.Y - height - 5, 8) end
					popFrame.Position = UDim2.fromOffset(x, y)
					popup = { Frame = popFrame, Rows = rows }; window._activePopover = { Destroy = function() if popFrame.Parent then popFrame:Destroy() end; popup = nil; if window._activePopover and window._activePopover.Frame == popFrame then window._activePopover = nil end end, Frame = popFrame }
					if popupSearch then popupSearch:GetPropertyChangedSignal("Text"):Connect(function() local query = string.lower(popupSearch.Text); for _, row in ipairs(rows) do row.Button.Visible = query == "" or string.find(string.lower(tostring(row.Option)), query, 1, true) ~= nil end end) end
					tween(popFrame, { BackgroundTransparency = UI.Theme.PopupTransparency }, 0.12)
				end
				function item:Close() close() end
				function item:Destroy() if close then close() end; self._destroyed = true; disconnectAll(self._connections); if self.Frame then self.Frame:Destroy() end; queueThemeCleanup() end
				close = function()
					local frame = popup and popup.Frame
					if frame then frame:Destroy() end
					popup = nil
					if window._activePopover and window._activePopover.Frame == frame then window._activePopover = nil end
					queueThemeCleanup()
				end
				renderText()
				selection.Activated:Connect(function() if popup then close() else item:Open() end end)
				return register(item, config)
			end
			function section:CreateDropdown(config) return makeChoice(config, false) end
			function section:CreateMultiDropdown(config) return makeChoice(config, true) end
			function section:CreateInput(config)
				config = config or {}; local name = tostring(config.Name or "Input"); local f = controlFrame(section, config.Description and 70 or 57); local main, desc = controlText(f, name, config.Description, 190)
			local box = create("TextBox", { Text = tostring(config.Default or ""), PlaceholderText = config.Placeholder or "Enter text...", PlaceholderColor3 = UI.Theme.MutedText, TextColor3 = UI.Theme.Text, Font = UI.Config.Font, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = config.Multiline == true, MultiLine = config.Multiline == true, TextYAlignment = config.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center, BackgroundColor3 = UI.Theme.Card, BackgroundTransparency = UI.Theme.CardTransparency, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, config.Multiline and 200 or 188, 0, config.Multiline and 54 or 36), ClearTextOnFocus = config.ClearOnFocus == true }, f)
				if config.Multiline then box.AnchorPoint = Vector2.new(1, 1); box.Position = UDim2.new(1, 0, 1, 0) end
				local passwordMask
				if config.Password then
					box.TextTransparency = 1
					box.PlaceholderText = ""
					passwordMask = label(box, string.rep("•", utf8.len(box.Text) or #box.Text), 12, UI.Theme.Text, UI.Config.Font, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -42, 1, 0), ZIndex = 3, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = config.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center, TextWrapped = config.Multiline == true })
				end
				corner(box, 10); stroke(box, UI.Theme.BorderTransparency); padding(box, 10, 0, 34, 0); bindTheme(box, "BackgroundColor3", "Card", "CardTransparency")
				local clear = newButton(box, "×", UDim2.fromOffset(28, 28), UI.Theme.Card); clear.AnchorPoint = Vector2.new(1, 0.5); clear.Position = UDim2.new(1, -3, 0.5, 0); clear.TextSize = 17; clear.Visible = box.Text ~= ""
				local item = makeComponent(f, name, config.Description); item._nameLabel = main; item._descriptionLabel = desc
				local function report() safeCallback(config.Callback, box.Text) end
				box.FocusLost:Connect(function(enter) report(); if enter then safeCallback(config.SubmitCallback, box.Text) end end)
				box:GetPropertyChangedSignal("Text"):Connect(function()
					clear.Visible = box.Text ~= ""
					if passwordMask then local ok, length = pcall(utf8.len, box.Text); passwordMask.Text = string.rep("•", ok and length or #box.Text) end
					if config.Live then report() end
				end)
				clear.Activated:Connect(function() box.Text = ""; report(); box:CaptureFocus() end)
				function item:Get() return box.Text end
				function item:Set(value, silent) box.Text = tostring(value or ""); if not silent then report() end end
				function item:Focus() box:CaptureFocus() end
				item.Input = box
				return register(item, config)
			end
			function section:CreateKeybind(config)
				config = config or {}; local name = tostring(config.Name or "Keybind"); local key = config.Default or Enum.KeyCode.Unknown; local f = controlFrame(section, 44); local main = controlText(f, name, nil, 130)
				local bindButton = newButton(f, key.Name or "None", UDim2.fromOffset(114, 34), UI.Theme.Card); bindButton.AnchorPoint = Vector2.new(1, 0.5); bindButton.Position = UDim2.new(1, 0, 0.5, 0); bindButton.TextSize = 11; stroke(bindButton, UI.Theme.BorderTransparency)
				local item = makeComponent(f, name); item._nameLabel = main; item.Value = key; local listening = false
				bindButton.Activated:Connect(function() listening = true; bindButton.Text = "Press key…" end)
				trackConnection(item, UserInputService.InputBegan:Connect(function(input, processed) if listening then if input.KeyCode == Enum.KeyCode.Escape then listening = false; bindButton.Text = key.Name else key = input.KeyCode; item.Value = key; bindButton.Text = key.Name; listening = false; safeCallback(config.Callback, key) end elseif not processed and input.KeyCode == key then safeCallback(config.PressedCallback, key) end end))
				function item:Get() return key end
				function item:Set(value, silent) if typeof(value) == "EnumItem" then key = value; item.Value = key; bindButton.Text = key.Name; if not silent then safeCallback(config.Callback, key) end end end
				return register(item, config)
			end
			function section:CreateColorPicker(config)
				config = config or {}; local name = tostring(config.Name or "Color"); local color = typeof(config.Default) == "Color3" and config.Default or UI.Theme.Accent; local alpha = tonumber(config.Alpha) or 1
				local f = controlFrame(section, config.Description and 58 or 46); local main, desc = controlText(f, name, config.Description, 64)
				local swatch = newButton(f, "", UDim2.fromOffset(42, 30), color); swatch.AnchorPoint = Vector2.new(1, 0.5); swatch.Position = UDim2.new(1, 0, 0.5, 0); swatch.BackgroundColor3 = color; stroke(swatch, UI.Theme.BorderTransparency)
				local item = makeComponent(f, name, config.Description); item._nameLabel = main; item._descriptionLabel = desc; item.Value = color
				local panel, popoverHandle
				local function apply(nextColor, nextAlpha, silent)
					color = nextColor; alpha = nextAlpha or alpha; item.Value = color; swatch.BackgroundColor3 = color; if not silent then safeCallback(config.Callback, color, alpha) end
				end
				function item:Get() return color, alpha end
				function item:Set(v, silent) if typeof(v) == "Color3" then apply(v, alpha, silent) end end
				function item:Open()
					if panel then if popoverHandle then popoverHandle:Destroy() else panel:Destroy() end; panel = nil; popoverHandle = nil; return end
					if window._activePopover then window._activePopover:Destroy() end
					local pop = create("Frame", { Size = UDim2.fromOffset(244, config.Alpha and 330 or 284), BackgroundColor3 = UI.Theme.Popup, BackgroundTransparency = UI.Theme.PopupTransparency, BorderSizePixel = 0, ZIndex = 30 }, overlay); styleSurface(pop, "Popup", "PopupTransparency", 14)
					local pos = swatch.AbsolutePosition; local bounds = overlay.AbsoluteSize; pop.Position = UDim2.fromOffset(math.clamp(pos.X + swatch.AbsoluteSize.X - 244, 8, math.max(bounds.X - 252, 8)), math.clamp(pos.Y - 115, 8, math.max(bounds.Y - (config.Alpha and 338 or 292), 8)))
					label(pop, "Color", 13, UI.Theme.Text, Enum.Font.GothamSemibold, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 22) })
					local preview = create("Frame", { Position = UDim2.fromOffset(12, 37), Size = UDim2.new(1, -24, 0, 29), BackgroundColor3 = color, BorderSizePixel = 0 }, pop); corner(preview, 8)
					local sat = create("ImageButton", { AutoButtonColor = false, Position = UDim2.fromOffset(12, 75), Size = UDim2.new(1, -24, 0, 126), BackgroundColor3 = Color3.fromHSV(select(1, color:ToHSV()), 1, 1), BorderSizePixel = 0, Image = "rbxassetid://4155801252", ScaleType = Enum.ScaleType.Stretch, ZIndex = 31 }, pop); corner(sat, 8)
					local hue = create("Frame", { Position = UDim2.fromOffset(12, 210), Size = UDim2.new(1, -24, 0, 13), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, pop); corner(hue, 7)
					local hueGradient = create("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)), ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)) }) }, hue)
					local slider = create("TextBox", { Text = "#" .. color:ToHex(), ClearTextOnFocus = false, Position = UDim2.fromOffset(12, 234), Size = UDim2.new(1, -24, 0, 30), BackgroundColor3 = UI.Theme.Card, BackgroundTransparency = UI.Theme.CardTransparency, TextColor3 = UI.Theme.Text, PlaceholderColor3 = UI.Theme.MutedText, Font = Enum.Font.Code, TextSize = 12, BorderSizePixel = 0, ZIndex = 31 }, pop); corner(slider, 8)
					local presets = { Color3.fromRGB(91, 126, 255), Color3.fromRGB(83, 207, 160), Color3.fromRGB(255, 184, 77), Color3.fromRGB(255, 99, 132), Color3.fromRGB(184, 126, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(34, 38, 48) }
					local presetRow = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 272), Size = UDim2.new(1, -24, 0, 24), ZIndex = 31 }, pop); create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7) }, presetRow)
					local hueValue, saturation, brightness = color:ToHSV()
					local function update()
						local next = Color3.fromHSV(hueValue, saturation, brightness); apply(next); preview.BackgroundColor3 = next; sat.BackgroundColor3 = Color3.fromHSV(hueValue, 1, 1); slider.Text = "#" .. next:ToHex()
					end
					local dragSat, dragHue = false, false
					local function satInput(input) saturation = math.clamp((input.Position.X - sat.AbsolutePosition.X) / sat.AbsoluteSize.X, 0, 1); brightness = 1 - math.clamp((input.Position.Y - sat.AbsolutePosition.Y) / sat.AbsoluteSize.Y, 0, 1); update() end
					sat.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragSat = true; satInput(input) end end)
					hue.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragHue = true; hueValue = math.clamp((input.Position.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1); update() end end)
					local dragConnection = UserInputService.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then if dragSat then satInput(input) elseif dragHue then hueValue = math.clamp((input.Position.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1); update() end end end)
					local endConnection = UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragSat = false; dragHue = false end end)
					for _, preset in ipairs(presets) do local sw = newButton(presetRow, "", UDim2.fromOffset(22, 22), preset); sw.BackgroundColor3 = preset; sw.Activated:Connect(function() hueValue, saturation, brightness = preset:ToHSV(); update() end) end
					if config.Alpha then local alphaLabel = label(pop, "Opacity", 10, UI.Theme.SecondaryText, UI.Config.Font, { Position = UDim2.fromOffset(12, 302), Size = UDim2.fromOffset(70, 18) }); local alphaBox = create("TextBox", { Text = tostring(math.floor(alpha * 100)), Position = UDim2.new(1, -62, 0, 299), Size = UDim2.fromOffset(48, 23), BackgroundColor3 = UI.Theme.Card, TextColor3 = UI.Theme.Text, Font = UI.Config.Font, TextSize = 11, BorderSizePixel = 0, ZIndex = 32 }, pop); corner(alphaBox, 7); alphaBox.FocusLost:Connect(function() alpha = math.clamp((tonumber(alphaBox.Text) or 100) / 100, 0, 1); safeCallback(config.Callback, color, alpha) end) end
					slider.FocusLost:Connect(function() local ok, parsed = pcall(function() return Color3.fromHex(string.gsub(slider.Text, "#", "")) end); if ok then hueValue, saturation, brightness = parsed:ToHSV(); update() else slider.Text = "#" .. color:ToHex() end end)
					panel = pop
					local handle
					handle = { Frame = pop, Destroy = function()
						dragConnection:Disconnect(); endConnection:Disconnect()
						if pop.Parent then pop:Destroy() end
						panel = nil; popoverHandle = nil
						if window._activePopover == handle then window._activePopover = nil end
						queueThemeCleanup()
					end }
					popoverHandle = handle; window._activePopover = handle
				end
				function item:Destroy() if popoverHandle then popoverHandle:Destroy() end; self._destroyed = true; disconnectAll(self._connections); if self.Frame then self.Frame:Destroy() end; queueThemeCleanup() end
				swatch.Activated:Connect(function() item:Open() end)
				return register(item, config)
			end
			function section:CreateDivider()
				local f = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 13) }, bodyFrame)
				local line = create("Frame", { BackgroundColor3 = UI.Theme.Border, BackgroundTransparency = 0.82, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1) }, f); bindTheme(line, "BackgroundColor3", "Border")
				return register(makeComponent(f, "Divider"))
			end
			function section:CreateParagraph(config)
				config = config or {}; local titleText = tostring(config.Title or "Information"); local contentText = tostring(config.Content or "")
				local f = create("Frame", { BackgroundColor3 = UI.Theme.Card, BackgroundTransparency = UI.Theme.CardTransparency, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 70), AutomaticSize = Enum.AutomaticSize.Y }, bodyFrame); corner(f, 12); stroke(f, UI.Theme.BorderTransparency); bindTheme(f, "BackgroundColor3", "Card", "CardTransparency"); padding(f, 12, 10, 12, 10)
				local iconHolder = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(18, 18) }, f); if config.Icon then makeIcon(iconHolder, config.Icon, UDim2.fromOffset(16, 16), UI.Theme.Accent) end
				local main = label(f, titleText, 12, UI.Theme.Text, Enum.Font.GothamSemibold, { Position = UDim2.fromOffset(config.Icon and 25 or 0, 0), Size = UDim2.new(1, -25, 0, 20) })
				local content = label(f, contentText, 11, UI.Theme.SecondaryText, UI.Config.Font, { Position = UDim2.fromOffset(config.Icon and 25 or 0, 23), Size = UDim2.new(1, -(config.Icon and 25 or 0), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
				f.Size = UDim2.new(1, 0, 0, 39)
				local item = makeComponent(f, titleText, contentText); item._nameLabel = main; item._descriptionLabel = content
				function item:SetContent(value) content.Text = tostring(value); self.Description = tostring(value) end
				return register(item, config)
			end
			return section
		end
		return tab
	end
	function window:CreateModal(config)
			config = config or {}; local shade = create("TextButton", { Name = "ModalOverlay", AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50 }, overlay)
			local modal = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(420, 220), BackgroundColor3 = UI.Theme.Popup, BackgroundTransparency = UI.Theme.PopupTransparency, BorderSizePixel = 0, ZIndex = 51 }, shade); styleSurface(modal, "Popup", "PopupTransparency", 18); padding(modal, 22, 18, 22, 18)
			local titleLabel = label(modal, config.Title or "Confirm", 17, UI.Theme.Text, Enum.Font.GothamSemibold, { Size = UDim2.new(1, 0, 0, 28) })
			local contentLabel = label(modal, config.Content or "", 13, UI.Theme.SecondaryText, UI.Config.Font, { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 88), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
			local buttons = config.Buttons or { { Name = "OK" } }; local row = create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 42) }, modal); create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8) }, row)
			local handle = { Frame = shade, _closed = false }
		function handle:Close() if self._closed then return end; self._closed = true; tween(shade, { BackgroundTransparency = 1 }, 0.14); task.delay(0.15, function() if shade.Parent then shade:Destroy() end; refreshThemeBindings() end) end
			for index, buttonConfig in ipairs(buttons) do local b = newButton(row, buttonConfig.Name or "OK", UDim2.fromOffset(104, 38), index == #buttons and UI.Theme.Accent or UI.Theme.Card); b.Activated:Connect(function() safeCallback(buttonConfig.Callback); handle:Close() end) end
			shade.Activated:Connect(function() if config.CloseOnBackdrop then handle:Close() end end)
			tween(shade, { BackgroundTransparency = 0.52 }, 0.16)
			return handle
		end
		function window:Minimize()
			if self._minimized then return end; self._minimized = true
			tween(shell, { Position = UDim2.new(0.5, 0, 1, 80), BackgroundTransparency = 1 }, 0.2)
			task.delay(0.2, function() if shell.Parent and self._minimized then shell.Visible = false end end)
			self._minimizedLauncher.Visible = true; self._minimizedLauncher.Position = UDim2.new(0.5, 0, 1, 90); tween(self._minimizedLauncher, { Position = UDim2.new(0.5, 0, 1, -42) }, 0.24)
		end
		function window:Restore()
			if not self._minimized then return end; self._minimized = false; self._minimizedLauncher.Visible = false; shell.Visible = true; shell.Position = UDim2.new(0.5, 0, 0, -400); shell.BackgroundTransparency = 1; tween(shell, { Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = UI.Theme.BackgroundTransparency }, 0.25)
		end
		function window:Toggle()
			if self._minimized then self:Restore() else self:Minimize() end
		end
		local maximized = false; local originalSize = size
		function window:ToggleMaximize()
			maximized = not maximized
			if maximized then originalSize = shell.Size; tween(shell, { Size = UDim2.new(1, -32, 1, -48) }, 0.22) else tween(shell, { Size = originalSize }, 0.22) end
		end
		function window:SetTitle(value) self.Title = tostring(value); title.Text = self.Title end
		function window:SetSubtitle(value) subtitle.Text = tostring(value or "") end
		function window:GetState()
			local result = {}
			for _, item in ipairs(self._components) do
				if item._stateKey then result[item._stateKey] = item.Get and item:Get() or item.Value end
			end
			return result
		end
		function window:SetState(state)
			if typeof(state) ~= "table" then return end
			for _, item in ipairs(self._components) do if item._stateKey and state[item._stateKey] ~= nil and item.Set then item:Set(state[item._stateKey], true) end end
		end
		function window:SaveConfig() return { Values = self:GetState(), Theme = UI.Config.Theme, AccentColor = UI.Config.AccentColor } end
		function window:LoadConfig(config)
			if typeof(config) ~= "table" then return end
			self:SetState(config.Values or config)
			if config.Theme then UI:SetTheme(config.Theme) end
			if typeof(config.AccentColor) == "Color3" then UI:SetAccentColor(config.AccentColor) end
		end
		function window:Destroy()
			if self._destroyed then return end; self._destroyed = true
			for _, component in ipairs(self._components) do if component.Destroy then component:Destroy() end end
			disconnectAll(self._connections)
			for _, notification in ipairs(self._notifications) do if notification.Destroy then notification:Destroy() end end
			if self._activePopover and self._activePopover.Destroy then self._activePopover:Destroy() end
			if gui.Parent then gui:Destroy() end
			refreshThemeBindings()
			local index = table.find(UI.Windows, self); if index then table.remove(UI.Windows, index) end
		end
		local dragging, dragStart, dragOrigin = false, nil, nil
		local function beginDrag(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			if input.Position.Y > top.AbsolutePosition.Y + top.AbsoluteSize.Y or input.Position.X > actions.AbsolutePosition.X then return end
			dragging = true; dragStart = input.Position; dragOrigin = shell.AbsolutePosition
		end
		top.InputBegan:Connect(beginDrag)
		trackConnection(window, UserInputService.InputChanged:Connect(function(input)
			if not dragging or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end
			local delta = input.Position - dragStart; local cameraNow = workspace.CurrentCamera; if not cameraNow then return end
			local vp = cameraNow.ViewportSize; local w, h = shell.AbsoluteSize.X, shell.AbsoluteSize.Y
			local left = math.clamp(dragOrigin.X + delta.X, 16, math.max(vp.X - w - 16, 16)); local topY = math.clamp(dragOrigin.Y + delta.Y, 16, math.max(vp.Y - h - 32, 16))
			shell.Position = UDim2.fromOffset(left + w / 2, topY + h / 2)
		end))
		trackConnection(window, UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end))
		if options.OpenAnimation ~= false then shell.Size = UDim2.new(size.X.Scale, size.X.Offset * 0.94, size.Y.Scale, size.Y.Offset * 0.94); shell.BackgroundTransparency = 1; tween(shell, { Size = size, BackgroundTransparency = UI.Theme.BackgroundTransparency }, 0.28) end
		local home = window:CreateTab({ Name = options.HomeTabName or "Home", Icon = options.HomeTabIcon or "house", Subtitle = "Your space, at a glance." })
		window.HomeTab = home
		if options.Greeting ~= false then
			local dashboard = home:CreateSection({ Name = greeting(), Icon = "sparkles" })
			dashboard:CreateLabel({ Text = "Welcome back.", Description = "Your interface is ready whenever you are.", Icon = "sun" })
			window._greeting = dashboard
		end
		local quick = home:CreateSection({ Name = "Quick access", Icon = "zap" })
		if typeof(options.QuickActions) == "table" and #options.QuickActions > 0 then
			for _, action in ipairs(options.QuickActions) do
				if typeof(action) == "table" then quick:CreateButton({ Name = action.Name or "Action", Description = action.Description, Icon = action.Icon, Disabled = typeof(action.Callback) ~= "function", Callback = action.Callback }) end
			end
		else
			quick:CreateParagraph({ Title = "Make it yours", Content = "Add controls to this dashboard or pass QuickActions when creating the window.", Icon = "layout-dashboard" })
		end
		if typeof(options.Stats) == "table" and #options.Stats > 0 then
			local stats = home:CreateSection({ Name = "Overview", Icon = "chart-no-axes-column" })
			for _, stat in ipairs(options.Stats) do
				if typeof(stat) == "table" then stats:CreateLabel({ Title = stat.Name or "Value", Text = tostring(stat.Value or "—"), Description = stat.Description, Icon = stat.Icon }) end
			end
		end
		window._openTab(home)
		if options.ToggleKey ~= false then
			local toggleKey = options.ToggleKey or Enum.KeyCode.RightShift
			trackConnection(window, UserInputService.InputBegan:Connect(function(input, processed) if not processed and input.KeyCode == toggleKey then window:Toggle() end end))
		end
		return window
end

function Library:Notify(config)
	config = config or {}; local titleText = tostring(config.Title or "Notification"); local contentText = tostring(config.Content or ""); local duration = math.max(tonumber(config.Duration) or 4, 0.5); local kind = string.lower(tostring(config.Type or "Info"))
	local gui = UI.Windows[1] and UI.Windows[1]._gui or newScreenGui()
	local root = gui:FindFirstChild("NotificationRoot")
	if not root then root = create("Frame", { Name = "NotificationRoot", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.fromOffset(330, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 80 }, gui); create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 9), HorizontalAlignment = Enum.HorizontalAlignment.Right }, root) end
	local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 78), ClipsDescendants = true, ZIndex = 80 }, root)
	local card = create("Frame", { BackgroundColor3 = UI.Theme.Popup, BackgroundTransparency = UI.Theme.PopupTransparency, Position = UDim2.new(1, 340, 0, 0), Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 81 }, holder); styleSurface(card, "Popup", "PopupTransparency", 14)
	local accent = if kind == "success" then UI.Theme.Success elseif kind == "warning" then UI.Theme.Warning elseif kind == "error" then UI.Theme.Error else UI.Theme.Accent
	local marker = create("Frame", { BackgroundColor3 = accent, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(0, 3, 0, 50), ZIndex = 82 }, card); corner(marker, 3)
	local iconHolder = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(20, 20), ZIndex = 82 }, card); makeIcon(iconHolder, config.Icon or ({ success = "check", warning = "triangle-alert", error = "circle-alert", info = "info" })[kind] or "info", UDim2.fromOffset(18, 18), accent)
	label(card, titleText, 13, UI.Theme.Text, Enum.Font.GothamSemibold, { Position = UDim2.fromOffset(43, 10), Size = UDim2.new(1, -78, 0, 20), ZIndex = 82 })
	label(card, contentText, 11, UI.Theme.SecondaryText, UI.Config.Font, { Position = UDim2.fromOffset(43, 31), Size = UDim2.new(1, -55, 0, 34), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 82 })
	local close = newButton(card, "×", UDim2.fromOffset(24, 24), UI.Theme.Card); close.AnchorPoint = Vector2.new(1, 0); close.Position = UDim2.new(1, -8, 0, 8); close.ZIndex = 84; close.TextSize = 16
	local progress = create("Frame", { BackgroundColor3 = accent, BackgroundTransparency = 0.25, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3), ZIndex = 83 }, card)
	playConfiguredSound("NotificationSound")
	local notice = { Frame = card, _closed = false }
	function notice:Destroy()
		if self._closed then return end
		self._closed = true
		if card.Parent then tween(card, { Position = UDim2.new(1, 340, 0, 0), BackgroundTransparency = 1 }, 0.16); task.delay(0.17, function() if holder.Parent then holder:Destroy() end; refreshThemeBindings() end) end
		local index = table.find(UI.Notifications, self); if index then table.remove(UI.Notifications, index) end
	end
	close.Activated:Connect(function() notice:Destroy() end)
	tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.22)
	tween(progress, { Size = UDim2.new(0, 0, 0, 3) }, duration, Enum.EasingStyle.Linear)
	task.delay(duration, function() notice:Destroy() end)
	table.insert(UI.Notifications, notice)
	if UI.Windows[1] then table.insert(UI.Windows[1]._notifications, notice) else task.delay(duration + 0.3, function() if gui.Parent and #gui:GetChildren() == 1 then gui:Destroy() end end) end
	return notice
end

function Library:SetTheme(theme)
	if typeof(theme) == "string" then
		if string.lower(theme) == "system" or string.lower(theme) == "adaptive" then
			UI.Theme = copyTable(BUILTIN_THEMES.Dark); UI.Config.Theme = theme
		elseif BUILTIN_THEMES[theme] then UI.Theme = copyTable(BUILTIN_THEMES[theme]); UI.Config.Theme = theme
		else warnf("Unknown theme '" .. theme .. "'."); return end
	elseif typeof(theme) == "table" then
		local nextTheme = copyTable(UI.Theme)
		for key, value in pairs(theme) do
			if nextTheme[key] == nil then warnf("Unknown theme key '" .. tostring(key) .. "'.")
			elseif string.find(key, "Transparency", 1, true) and typeof(value) == "number" then nextTheme[key] = math.clamp(value, 0, 1)
			elseif typeof(value) == "Color3" then nextTheme[key] = value
			else warnf("Theme value for '" .. tostring(key) .. "' has an invalid type.") end
		end
		UI.Theme = nextTheme; UI.Config.Theme = "Custom"
	else warnf("SetTheme expects a built-in theme name or theme table."); return end
	if UI.Config.AccentColor then UI.Theme.Accent = UI.Config.AccentColor end
	refreshThemeBindings()
	for _, window in ipairs(UI.Windows) do
		if window._shell then window._shell.BackgroundTransparency = UI.Config.UITransparency and math.clamp(UI.Theme.BackgroundTransparency + UI.Config.Transparency, 0, 0.92) or 0 end
	end
end

function Library:SetAccentColor(color)
	if typeof(color) ~= "Color3" then warnf("SetAccentColor expects a Color3."); return end
	UI.Config.AccentColor = color; UI.Theme.Accent = color; refreshThemeBindings()
end

function Library:SetConfig(config)
	if typeof(config) ~= "table" then warnf("SetConfig expects a table."); return end
	for key, value in pairs(config) do if DEFAULT_CONFIG[key] ~= nil then UI.Config[key] = value else warnf("Unknown config key '" .. tostring(key) .. "'.") end end
	if config.Theme then self:SetTheme(config.Theme) elseif config.AccentColor then self:SetAccentColor(config.AccentColor) else refreshThemeBindings() end
	for _, window in ipairs(UI.Windows) do
		if config.UIScale and window._fitScale then window._fitScale() end
		if config.Font then for _, descendant in ipairs(window._gui:GetDescendants()) do if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then descendant.Font = config.Font end end end
		if config.CornerRadius then for _, descendant in ipairs(window._gui:GetDescendants()) do if descendant:IsA("UICorner") then descendant.CornerRadius = UDim.new(0, tonumber(config.CornerRadius) or 14) end end end
	end
end

function Library:GetConfig() return copyTable(UI.Config) end
function Library:GetTheme() return copyTable(UI.Theme) end

function Library:Destroy()
	for _, window in ipairs(table.clone(UI.Windows)) do window:Destroy() end
	for _, notice in ipairs(table.clone(UI.Notifications)) do notice:Destroy() end
	disconnectAll(UI._connections)
	for _, activeTween in ipairs(UI._tweens) do pcall(function() activeTween:Cancel() end) end
	table.clear(UI._tweens); table.clear(UI._themeBindings); table.clear(UI.Notifications)
end

function Library:CreateStateKey(component, key)
	if not component or typeof(key) ~= "string" or key == "" then return end
	component._stateKey = key
	for _, window in ipairs(UI.Windows) do
		if table.find(window._components, component) then window._state[key] = component.Get and component:Get() or component.Value; return end
	end
end

function Library:GetIconLibrary() return ensureIcons() end

setmetatable(UI, { __index = Library })
UI.__index = Library
return UI
