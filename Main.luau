--[[
    LarpUI - a small, runtime Roblox UI library for LocalScripts/executor loaders.
    UI only: no remotes, game-state manipulation, or exploit behavior.
    Loadstring users need an executor that exposes loadstring and HttpGetAsync.
]]

local LarpUI = {}
LarpUI.__index = LarpUI

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local DEFAULT_ACCENT = Color3.fromRGB(124, 140, 255)
local palettes = {
	Dark = { background = Color3.fromRGB(18, 21, 29), panel = Color3.fromRGB(29, 33, 44), raised = Color3.fromRGB(39, 44, 57), text = Color3.fromRGB(242, 244, 250), muted = Color3.fromRGB(160, 168, 185), border = Color3.fromRGB(255, 255, 255), input = Color3.fromRGB(13, 16, 23), danger = Color3.fromRGB(255, 104, 122) },
	Light = { background = Color3.fromRGB(241, 244, 250), panel = Color3.fromRGB(255, 255, 255), raised = Color3.fromRGB(232, 236, 245), text = Color3.fromRGB(30, 35, 48), muted = Color3.fromRGB(103, 112, 132), border = Color3.fromRGB(76, 87, 112), input = Color3.fromRGB(246, 247, 251), danger = Color3.fromRGB(208, 55, 75) },
}

local function safe(fn, ...)
	if type(fn) ~= "function" then return end
	local args = table.pack(...)
	local ok, err = pcall(function() fn(table.unpack(args, 1, args.n)) end)
	if not ok then warn("[LarpUI callback] " .. tostring(err)) end
end

local function create(class, props, parent)
	local object = Instance.new(class)
	for key, value in pairs(props or {}) do
		local ok = pcall(function() object[key] = value end)
		if not ok then warn("[LarpUI] Unsupported property " .. tostring(key)) end
	end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

local function stroke(parent, color, transparency)
	return create("UIStroke", { Color = color, Transparency = transparency or 0.65, Thickness = 1 }, parent)
end

local function padding(parent, left, right, top, bottom)
	return create("UIPadding", { PaddingLeft = UDim.new(0, left or 0), PaddingRight = UDim.new(0, right or 0), PaddingTop = UDim.new(0, top or 0), PaddingBottom = UDim.new(0, bottom or 0) }, parent)
end

function LarpUI:_connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self._connections, connection)
	return connection
end

function LarpUI:_bind(instance, property, token, alpha)
	table.insert(self._bindings, { instance = instance, property = property, token = token, alpha = alpha or 0 })
	self:_applyBinding(self._bindings[#self._bindings])
end

function LarpUI:_applyBinding(binding)
	if not binding.instance or not binding.instance.Parent then return end
	local color = self._palette[binding.token]
	if binding.token == "accent" then color = self.AccentColor end
	if not color then return end
	pcall(function() binding.instance[binding.property] = color end)
	if binding.property == "BackgroundColor3" then
		local base = self.Transparency
		local t = math.clamp(base + (binding.alpha or 0), 0, 0.86)
		pcall(function() binding.instance.BackgroundTransparency = t end)
	end
end

function LarpUI:_set(instance, property, token, alpha)
	self:_bind(instance, property, token, alpha)
end

function LarpUI:_tween(instance, properties, duration)
	if self._destroyed or not instance or not instance.Parent then return nil end
	local tween = TweenService:Create(instance, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	table.insert(self._tweens, tween)
	tween:Play()
	return tween
end

function LarpUI:_label(parent, text, size, colorToken, bold)
	local label = create("TextLabel", { BackgroundTransparency = 1, Text = tostring(text or ""), Font = bold and Enum.Font.GothamSemibold or Enum.Font.Gotham, TextSize = size or 13, TextColor3 = self._palette[colorToken or "text"], TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true, BorderSizePixel = 0 }, parent)
	self:_bind(label, "TextColor3", colorToken or "text")
	return label
end

function LarpUI:_button(parent, text, size, callback, opts)
	opts = opts or {}
	local button = create("TextButton", { AutoButtonColor = false, Text = text or "", Font = opts.font or Enum.Font.GothamSemibold, TextSize = opts.textSize or 13, TextColor3 = self._palette[opts.textToken or "text"], BackgroundColor3 = self._palette[opts.token or "raised"], BackgroundTransparency = 0.03, Size = size, BorderSizePixel = 0, TextWrapped = true }, parent)
	corner(button, opts.radius or 11)
	self:_bind(button, "BackgroundColor3", opts.token or "raised", opts.alpha or 0)
	self:_bind(button, "TextColor3", opts.textToken or "text")
	if opts.outline then stroke(button, self._palette.border, 0.82) end
	if opts.tooltip then self:_tooltip(button, opts.tooltip) end
	local enabled = opts.disabled ~= true
	button.Active = enabled
	button.TextTransparency = enabled and 0 or 0.45
	if enabled and callback then
		self:_connect(button.MouseEnter, function() if button.Parent then self:_tween(button, { BackgroundTransparency = math.max(0, button.BackgroundTransparency - 0.08) }, 0.12) end end)
		self:_connect(button.MouseLeave, function() if button.Parent then self:_tween(button, { BackgroundTransparency = math.clamp(self.Transparency + (opts.alpha or 0), 0, 0.86) }, 0.12) end end)
		self:_connect(button.Activated, function() if not self._destroyed then safe(callback, button) end end)
	end
	return button
end

function LarpUI:_tooltip(target, text)
	self:_connect(target.MouseEnter, function()
		if self._destroyed then return end
		local tip = create("TextLabel", { Name = "Tooltip", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.new(0, math.clamp(#tostring(text) * 7 + 22, 80, 240), 0, 30), BackgroundColor3 = self._palette.raised, TextColor3 = self._palette.text, Text = tostring(text), Font = Enum.Font.Gotham, TextSize = 11, ZIndex = 50, BorderSizePixel = 0 }, target)
		corner(tip, 8); padding(tip, 8, 8, 2, 2); self:_set(tip, "BackgroundColor3", "raised"); self:_set(tip, "TextColor3", "text")
	end)
	self:_connect(target.MouseLeave, function() local tip = target:FindFirstChild("Tooltip"); if tip then tip:Destroy() end end)
end

function LarpUI:_resolvePlayer()
	local ok, player = pcall(function() return Players.LocalPlayer end)
	if not ok or not player then return nil end
	return player
end

local function greeting()
	local hour = tonumber(os.date("%H")) or 12
	if hour < 12 then return "Good morning" elseif hour < 18 then return "Good afternoon" else return "Good evening" end
end

function LarpUI:_refreshGreeting()
	if not self._greetingLabel or not self._greetingLabel.Parent then return end
	local player = self:_resolvePlayer()
	local name = player and player.Name or "there"
	self._greetingLabel.Text = greeting() .. ", " .. name
end

function LarpUI:_loadIcons()
	if self._iconsLoaded then return self._icons end
	self._iconsLoaded = true
	local ok, icons = pcall(function()
		if type(loadstring) ~= "function" then error("loadstring unavailable") end
		local source = game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua")
		local loader = loadstring(source)
		if type(loader) ~= "function" then error("icon loader did not compile") end
		return loader()
	end)
	if ok and type(icons) == "table" then
		self._icons = icons
		if type(icons.SetIconsType) == "function" then pcall(icons.SetIconsType, self.IconSet or "lucide") end
	else
		warn("[LarpUI] Footagesus Icons unavailable; rendering text-only controls")
	end
	return self._icons
end

function LarpUI:SetIconSet(iconSet)
	self.IconSet = tostring(iconSet or "lucide")
	if self._icons and type(self._icons.SetIconsType) == "function" then pcall(self._icons.SetIconsType, self.IconSet) end
	return self
end

-- Creates a Footagesus V2 icon frame for custom compositions. Colors accepts Color3 entries.
function LarpUI:CreateIcon(parent, options)
	options = options or {}
	local icons = self:_loadIcons()
	if not icons or type(icons.Image) ~= "function" then return nil end
	local config = { Icon = options.Icon, Colors = options.Colors, Size = options.Size or UDim2.fromOffset(20, 20) }
	local ok, result = pcall(icons.Image, config)
	if not ok or type(result) ~= "table" or not result.IconFrame then return nil end
	result.IconFrame.Parent = parent
	return result.IconFrame
end

function LarpUI:_icon(parent, name, size, tint)
	if not name then return nil end
	local icons = self:_loadIcons()
	if not icons then return nil end
	local image
	local ok, result = pcall(function()
		if type(icons.GetIcon) == "function" then return icons.GetIcon(name) end
	end)
	if ok then image = result end
	if type(image) == "string" and image ~= "" then
		return create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = image, ImageColor3 = tint or self._palette.text, Size = size or UDim2.fromOffset(18, 18), ScaleType = Enum.ScaleType.Fit }, parent)
	end
	if type(icons.Image) == "function" then
		local success, object = pcall(icons.Image, { Icon = name, Colors = { tint or self._palette.text }, Size = size or UDim2.fromOffset(18, 18) })
		if success and type(object) == "table" and object.IconFrame then
			object.IconFrame.Name = "Icon"
			object.IconFrame.Size = size or UDim2.fromOffset(18, 18)
			object.IconFrame.Parent = parent
			return object.IconFrame
		end
	end
	return nil
end

function LarpUI:_registerControl(control, name, widget)
	control.Name = name or "Control"
	control:SetAttribute("LarpUIControl", true)
	control:SetAttribute("LarpUIName", string.lower(tostring(name or "")))
	if self._window._searchQuery then control.Visible = string.find(string.lower(tostring(name or "")), self._window._searchQuery, 1, true) ~= nil end
	return control
end

function LarpUI:_newWidget(section, name, height)
	local card = create("Frame", { BackgroundColor3 = self._palette.panel, Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0 }, section._body)
	corner(card, 13); self:_bind(card, "BackgroundColor3", "panel", 0.02)
	self:_registerControl(card, name)
	return card
end

function LarpUI:CreateWindow(options)
	options = options or {}
	local selfUI = setmetatable({}, LarpUI)
	selfUI._connections, selfUI._tweens, selfUI._bindings, selfUI._destroyed = {}, {}, {}, false
	selfUI._palette = palettes[options.Theme] and options.Theme or "Dark"
	selfUI._palette = palettes[selfUI._palette]
	selfUI.Theme = palettes[options.Theme] and options.Theme or "Dark"
	selfUI.AccentColor = typeof(options.AccentColor) == "Color3" and options.AccentColor or DEFAULT_ACCENT
	selfUI.Transparency = math.clamp(tonumber(options.Transparency) or 0.16, 0, 0.55)
	selfUI.IconSet = options.IconSet or "lucide"
	selfUI._tabs, selfUI._sections = {}, {}
	selfUI._toasts = {}
	selfUI._window = selfUI
	selfUI._gui = Instance.new("ScreenGui")
	selfUI._gui.Name = "LarpUI_" .. HttpService:GenerateGUID(false):sub(1, 8)
	selfUI._gui.ResetOnSpawn = false
	selfUI._gui.IgnoreGuiInset = false
	selfUI._gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local player = selfUI:_resolvePlayer()
	local function parentGui()
		local p = selfUI:_resolvePlayer()
		if not p then return false end
		local pg = p:FindFirstChildOfClass("PlayerGui") or p:WaitForChild("PlayerGui", 5)
		if pg then selfUI._gui.Parent = pg; return true end
		return false
	end
	parentGui()
	if player then selfUI:_connect(player.CharacterAdded, function() task.defer(parentGui) end) end
	if not player then
		task.spawn(function()
			for _ = 1, 30 do
				if selfUI._destroyed then return end
				local latePlayer = selfUI:_resolvePlayer()
				if latePlayer then selfUI:_connect(latePlayer.CharacterAdded, function() task.defer(parentGui) end); parentGui(); return end
				task.wait(1)
			end
		end)
	end
	local root = create("Frame", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.82, 0, 0.78, 0), BackgroundColor3 = selfUI._palette.background, BorderSizePixel = 0, ClipsDescendants = true }, selfUI._gui)
	root.Size = UDim2.new(0.82, 0, 0.78, 0)
	local constraints = create("UISizeConstraint", { MinSize = Vector2.new(320, 340), MaxSize = Vector2.new(900, 680) }, root)
	-- On narrow devices, remove the desktop minimum so the window always fits.
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.X < 520 then constraints.MinSize = Vector2.new(280, 300); root.Size = UDim2.new(0.94, 0, 0.82, 0) end
	corner(root, 22); stroke(root, selfUI._palette.border, 0.77); selfUI:_bind(root, "BackgroundColor3", "background", 0.03)
	selfUI._root = root
	local top = create("Frame", { Name = "TitleBar", Size = UDim2.new(1, 0, 0, 84), BackgroundTransparency = 1, BorderSizePixel = 0 }, root)
	local title = selfUI:_label(top, options.Title or "LarpUI", 18, "text", true)
	title.Position = UDim2.fromOffset(22, 12); title.Size = UDim2.new(0.52, 0, 0, 25)
	local subtitle = selfUI:_label(top, options.Subtitle or "A calm, focused workspace", 11, "muted")
	subtitle.Position = UDim2.fromOffset(22, 38); subtitle.Size = UDim2.new(0.58, 0, 0, 18)
	selfUI._titleLabel, selfUI._subtitleLabel = title, subtitle
	local greetingLabel = selfUI:_label(top, "", 12, "accent", true)
	greetingLabel.Position = UDim2.fromOffset(22, 59); greetingLabel.Size = UDim2.new(0.6, 0, 0, 18)
	selfUI._greetingLabel = greetingLabel; selfUI:_refreshGreeting()
	task.spawn(function()
		while not selfUI._destroyed do task.wait(60); if not selfUI._destroyed then selfUI:_refreshGreeting() end end
	end)
	local controls = create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(94, 34) }, top)
	local minimize = selfUI:_button(controls, "−", UDim2.fromOffset(34, 32), function() selfUI:Minimize() end, { textSize = 18, tooltip = "Minimize" })
	local close = selfUI:_button(controls, "×", UDim2.fromOffset(34, 32), function() selfUI:Destroy() end, { textSize = 19, token = "danger", tooltip = "Close" })
	minimize.Position = UDim2.fromOffset(0, 0); close.Position = UDim2.fromOffset(40, 0)
	local dragZone = create("TextButton", { Name = "DragZone", BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, -130, 1, 0), ZIndex = 0, Active = true }, top)
	local dragging, dragStart, startPosition = false, nil, nil
	selfUI:_connect(dragZone.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = input.Position; startPosition = root.Position end
	end)
	selfUI:_connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			root.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end)
	selfUI:_connect(UserInputService.InputEnded, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	local body = create("Frame", { Name = "Body", Position = UDim2.fromOffset(14, 88), Size = UDim2.new(1, -28, 1, -102), BackgroundTransparency = 1, BorderSizePixel = 0 }, root)
	local side = create("Frame", { Name = "Sidebar", Size = UDim2.new(0, 178, 1, 0), BackgroundColor3 = selfUI._palette.panel, BorderSizePixel = 0 }, body)
	corner(side, 16); selfUI:_bind(side, "BackgroundColor3", "panel", 0.01)
	local search = create("TextBox", { Name = "Search", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 38), BackgroundColor3 = selfUI._palette.input, TextColor3 = selfUI._palette.text, PlaceholderText = "Search controls…", PlaceholderColor3 = selfUI._palette.muted, Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, Text = "", BorderSizePixel = 0 }, side)
	corner(search, 11); padding(search, 11, 8, 2, 2); stroke(search, selfUI._palette.border, 0.9); selfUI:_bind(search, "BackgroundColor3", "input"); selfUI:_bind(search, "TextColor3", "text"); selfUI:_bind(search, "PlaceholderColor3", "muted")
	selfUI._searchBox = search
	local nav = create("ScrollingFrame", { Name = "TabList", Position = UDim2.fromOffset(8, 58), Size = UDim2.new(1, -16, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new() }, side)
	local navLayout = create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, nav)
	selfUI:_connect(navLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function() nav.CanvasSize = UDim2.new(0, 0, 0, navLayout.AbsoluteContentSize.Y + 8) end)
	local content = create("Frame", { Name = "Content", Position = UDim2.new(0, 190, 0, 0), Size = UDim2.new(1, -190, 1, 0), BackgroundColor3 = selfUI._palette.panel, BorderSizePixel = 0, ClipsDescendants = true }, body)
	corner(content, 16); selfUI:_bind(content, "BackgroundColor3", "panel", 0.01)
	selfUI._body, selfUI._nav, selfUI._content = body, nav, content
	selfUI:_connect(search:GetPropertyChangedSignal("Text"), function()
		local query = string.lower(search.Text)
		selfUI._searchQuery = query
		for _, tab in ipairs(selfUI._tabs) do
			for _, section in ipairs(tab._sections) do
				for _, child in ipairs(section._body:GetChildren()) do
					if child:GetAttribute("LarpUIControl") then
						child.Visible = query == "" or string.find(child:GetAttribute("LarpUIName") or "", query, 1, true) ~= nil
					end
				end
			end
		end
	end)
	if options.Blur then
		local ok, blur = pcall(function() local b = Instance.new("BlurEffect"); b.Name = "LarpUIBlur"; b.Size = 8; b.Parent = Lighting; return b end)
		if ok then selfUI._blur = blur end
	end
	if options.ToggleKey then selfUI:SetToggleKey(options.ToggleKey) end
	return selfUI
end

function LarpUI:SetTheme(theme)
	if not palettes[theme] then return self end
	self.Theme, self._palette = theme, palettes[theme]
	for _, binding in ipairs(self._bindings) do self:_applyBinding(binding) end
	for _, tab in ipairs(self._tabs) do if tab._page.Visible then tab:Select(); break end end
	return self
end

function LarpUI:SetAccent(color)
	if typeof(color) ~= "Color3" then return self end
	self.AccentColor = color
	for _, binding in ipairs(self._bindings) do if binding.token == "accent" then self:_applyBinding(binding) end end
	for _, tab in ipairs(self._tabs) do if tab._page.Visible then tab:Select(); break end end
	return self
end

function LarpUI:SetTransparency(value)
	self.Transparency = math.clamp(tonumber(value) or self.Transparency, 0, 0.55)
	for _, binding in ipairs(self._bindings) do self:_applyBinding(binding) end
	return self
end

function LarpUI:SetTitle(title, subtitle)
	if title ~= nil then self._titleLabel.Text = tostring(title) end
	if subtitle ~= nil then self._subtitleLabel.Text = tostring(subtitle) end
	return self
end

function LarpUI:SetToggleKey(keyCode)
	if typeof(keyCode) == "string" then keyCode = Enum.KeyCode[keyCode] end
	if typeof(keyCode) ~= "EnumItem" then return self end
	self._toggleKey = keyCode
	if self._toggleConnection then self._toggleConnection:Disconnect() end
	self._toggleConnection = self:_connect(UserInputService.InputBegan, function(input, processed)
		if not processed and input.KeyCode == self._toggleKey then self:SetVisible(not self._root.Visible) end
	end)
	return self
end

function LarpUI:SetVisible(visible)
	if self._root and self._root.Parent then self._root.Visible = visible == true end
	return self
end

function LarpUI:Minimize()
	if not self._root then return self end
	self._minimized = not self._minimized
	if self._minimized then self._restoreSize = self._root.Size; self:_tween(self._root, { Size = UDim2.new(0.82, 0, 0, 84) }, 0.22)
	else self:_tween(self._root, { Size = self._restoreSize or UDim2.new(0.82, 0, 0.78, 0) }, 0.22) end
	self._body.Visible = not self._minimized
	return self
end

function LarpUI:CreateTab(options)
	options = type(options) == "table" and options or { Name = tostring(options) }
	local tab = { _window = self, _sections = {}, Name = tostring(options.Name or "Tab") }
	local navButton = self:_button(self._nav, "", UDim2.new(1, 0, 0, 42), function() tab:Select() end, { token = "panel", radius = 11 })
	navButton.LayoutOrder = #self._tabs + 1
	local icon = self:_icon(navButton, options.Icon, UDim2.fromOffset(18, 18), self._palette.muted)
	if icon then icon.Position = UDim2.fromOffset(12, 12); icon.ZIndex = navButton.ZIndex + 1 end
	local label = self:_label(navButton, tab.Name, 12, "muted", true); label.Position = UDim2.fromOffset(icon and 39 or 12, 0); label.Size = UDim2.new(1, icon and -46 or -20, 1, 0)
	local page = create("ScrollingFrame", { Name = "Page_" .. tab.Name, Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(), ScrollBarThickness = 4, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, self._content)
	local layout = create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, page)
	padding(page, 16, 16, 16, 16)
	self:_connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function() page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 32) end)
	tab._page, tab._button, tab._label = page, navButton, label
	function tab:Select()
		for _, other in ipairs(self._window._tabs) do
			local active = other == self
			other._page.Visible = active
			other._window:_tween(other._button, { BackgroundColor3 = active and other._window.AccentColor or other._window._palette.panel }, 0.16)
			other._label.TextColor3 = active and Color3.new(1, 1, 1) or other._window._palette.muted
		end
		return self
	end
	function tab:CreateSection(title)
		local section = { _window = self._window, _tab = self, Name = tostring(title or "Section") }
		local holder = create("Frame", { Name = "Section_" .. section.Name, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0 }, self._page)
		local heading = self._window:_label(holder, section.Name, 13, "text", true); heading.Size = UDim2.new(1, 0, 0, 23)
		local list = create("Frame", { Name = "Controls", Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, holder)
		local listLayout = create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		section._holder, section._body = holder, list
		table.insert(self._sections, section); table.insert(self._window._sections, section)
		local function handle(frame, get, set)
			local result = { Instance = frame, Get = get, Set = set }
			return result
		end
		function section:CreateButton(opts)
			opts = opts or {}; local card = self._window:_newWidget(self, opts.Name or "Button", opts.Description and 76 or 54)
			local enabled = opts.Disabled ~= true
			local btn = self._window:_button(card, opts.Name or "Button", UDim2.new(1, -22, 0, 36), function() if enabled then safe(opts.Callback) end end, { token = "raised", tooltip = opts.Tooltip })
			btn.Active = enabled; btn.TextTransparency = enabled and 0 or 0.45
			btn.Position = UDim2.new(0, 11, 0, opts.Description and 8 or 9)
			if opts.Icon then local i = self._window:_icon(btn, opts.Icon, UDim2.fromOffset(17, 17)); if i then i.Position = UDim2.fromOffset(12, 9) end; btn.TextXAlignment = Enum.TextXAlignment.Center end
			if opts.Description then local desc = self._window:_label(card, opts.Description, 10, "muted"); desc.Position = UDim2.new(0, 14, 0, 47); desc.Size = UDim2.new(1, -28, 0, 18) end
			return handle(card, function() return enabled end, function(v) enabled = v ~= false; btn.Active = enabled; btn.TextTransparency = enabled and 0 or 0.45 end)
		end
		function section:CreateToggle(opts)
			opts = opts or {}; local value = opts.Default == true
			local card = self._window:_newWidget(self, opts.Name or "Toggle", 58)
			local name = self._window:_label(card, opts.Name or "Toggle", 13, "text", true); name.Position = UDim2.fromOffset(14, 8); name.Size = UDim2.new(1, -80, 0, 22)
			if opts.Description then local d = self._window:_label(card, opts.Description, 10, "muted"); d.Position = UDim2.fromOffset(14, 31); d.Size = UDim2.new(1, -80, 0, 17) end
			local track = create("TextButton", { AutoButtonColor = false, Text = "", Position = UDim2.new(1, -60, 0.5, -12), Size = UDim2.fromOffset(46, 25), BackgroundColor3 = self._window._palette.raised, BorderSizePixel = 0 }, card); corner(track, 13); self._window:_bind(track, "BackgroundColor3", value and "accent" or "raised")
			local knob = create("Frame", { Position = value and UDim2.new(1, -21, 0, 3) or UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(19, 19), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track); corner(knob, 12)
			local function set(v, fire) value = v == true; self._window:_tween(knob, { Position = value and UDim2.new(1, -21, 0, 3) or UDim2.fromOffset(3, 3) }, 0.15); for _, binding in ipairs(self._window._bindings) do if binding.instance == track and binding.property == "BackgroundColor3" then binding.token = value and "accent" or "raised"; self._window:_applyBinding(binding) end end; if fire then safe(opts.Callback, value) end end
			self._window:_connect(track.Activated, function() set(not value, true) end)
			return handle(card, function() return value end, function(v) set(v, true) end)
		end
		function section:CreateSlider(opts)
			opts = opts or {}; local min, max = tonumber(opts.Min) or 0, tonumber(opts.Max) or 100; if max <= min then max = min + 1 end
			local step = math.max(tonumber(opts.Step) or 1, 0.000001); local value = math.clamp(tonumber(opts.Default) or min, min, max)
			local card = self._window:_newWidget(self, opts.Name or "Slider", 72)
			local title = self._window:_label(card, opts.Name or "Slider", 12, "text", true); title.Position = UDim2.fromOffset(13, 7); title.Size = UDim2.new(0.7, 0, 0, 20)
			local valueLabel = self._window:_label(card, "", 11, "accent", true); valueLabel.TextXAlignment = Enum.TextXAlignment.Right; valueLabel.Position = UDim2.new(0.7, 0, 0, 7); valueLabel.Size = UDim2.new(0.27, -10, 0, 20)
			local rail = create("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.new(0, 13, 0, 43), Size = UDim2.new(1, -26, 0, 8), BackgroundColor3 = self._window._palette.raised, BorderSizePixel = 0 }, card); corner(rail, 8); self._window:_bind(rail, "BackgroundColor3", "raised")
			local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = self._window.AccentColor, BorderSizePixel = 0 }, rail); corner(fill, 8); self._window:_bind(fill, "BackgroundColor3", "accent")
			local function quantize(v) return math.clamp(min + math.floor((v - min) / step + 0.5) * step, min, max) end
			local function set(v, fire) value = quantize(math.clamp(tonumber(v) or min, min, max)); local ratio = (value - min) / (max - min); fill.Size = UDim2.new(ratio, 0, 1, 0); valueLabel.Text = tostring(value); if fire then safe(opts.Callback, value) end end
			local isDragging = false
			local function fromInput(input) local x = math.clamp((input.Position.X - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1); set(min + (max - min) * x, true) end
			self._window:_connect(rail.InputBegan, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDragging = true; fromInput(input) end end)
			self._window:_connect(UserInputService.InputChanged, function(input) if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromInput(input) end end)
			self._window:_connect(UserInputService.InputEnded, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDragging = false end end)
			set(value, false)
			return handle(card, function() return value end, function(v) set(v, true) end)
		end
		function section:CreateDropdown(opts)
			opts = opts or {}; local optionsList = opts.Options or {}; local multi = opts.Multi == true; local selected = multi and {} or opts.Default
			local card = self._window:_newWidget(self, opts.Name or "Dropdown", 54)
			local title = self._window:_label(card, opts.Name or "Dropdown", 11, "muted"); title.Position = UDim2.fromOffset(13, 4); title.Size = UDim2.new(1, -25, 0, 15)
			local trigger = self._window:_button(card, "", UDim2.new(1, -18, 0, 27), nil, { token = "raised", radius = 9 }); trigger.Position = UDim2.fromOffset(9, 22)
			local listFrame
			local function summary() if multi then local items = {}; for _, v in ipairs(optionsList) do if selected[v] then table.insert(items, tostring(v)) end end; return #items > 0 and table.concat(items, ", ") or "Choose…" end; return selected and tostring(selected) or "Choose…" end
			trigger.Text = summary(); trigger.TextXAlignment = Enum.TextXAlignment.Left; padding(trigger, 10, 8, 0, 0)
			local function redraw() if trigger.Parent then trigger.Text = summary() end end
			local function toggle()
				if listFrame then listFrame:Destroy(); listFrame = nil; card.Size = UDim2.new(1, 0, 0, 54); return end
				card.Size = UDim2.new(1, 0, 0, 54 + math.min(#optionsList, 5) * 31 + 8)
				listFrame = create("ScrollingFrame", { Position = UDim2.fromOffset(9, 54), Size = UDim2.new(1, -18, 0, math.min(#optionsList, 5) * 31), BackgroundColor3 = self._window._palette.input, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, #optionsList * 31) }, card); corner(listFrame, 9); self._window:_bind(listFrame, "BackgroundColor3", "input")
				for index, option in ipairs(optionsList) do local optButton = self._window:_button(listFrame, (multi and selected[option] and "✓  " or "") .. tostring(option), UDim2.new(1, -8, 0, 29), nil, { token = "input", radius = 6 }); optButton.Position = UDim2.fromOffset(4, (index - 1) * 31); optButton.TextXAlignment = Enum.TextXAlignment.Left; padding(optButton, 8, 4, 0, 0); self._window:_connect(optButton.Activated, function() if multi then selected[option] = not selected[option]; optButton.Text = (selected[option] and "✓  " or "") .. tostring(option) else selected = option; listFrame:Destroy(); listFrame = nil; card.Size = UDim2.new(1, 0, 0, 54) end; redraw(); safe(opts.Callback, multi and selected or selected, option) end) end
			end
			self._window:_connect(trigger.Activated, toggle)
			return handle(card, function() if multi then local copy = {}; for k, v in pairs(selected) do if v then copy[k] = true end end; return copy end; return selected end, function(v) if multi and type(v) == "table" then selected = v elseif not multi then selected = v end; redraw(); safe(opts.Callback, selected) end)
		end
		function section:CreateTextbox(opts)
			opts = opts or {}; local card = self._window:_newWidget(self, opts.Name or "Textbox", 66)
			local name = self._window:_label(card, opts.Name or "Textbox", 11, "muted"); name.Position = UDim2.fromOffset(12, 3); name.Size = UDim2.new(1, -24, 0, 16)
			local box = create("TextBox", { Position = UDim2.fromOffset(9, 22), Size = UDim2.new(1, -18, 0, 35), BackgroundColor3 = self._window._palette.input, TextColor3 = self._window._palette.text, PlaceholderColor3 = self._window._palette.muted, Text = tostring(opts.Default or ""), PlaceholderText = opts.Placeholder or "Type here…", Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, BorderSizePixel = 0 }, card); corner(box, 9); padding(box, 10, 8, 0, 0); self._window:_bind(box, "BackgroundColor3", "input"); self._window:_bind(box, "TextColor3", "text"); self._window:_bind(box, "PlaceholderColor3", "muted")
			self._window:_connect(box.FocusLost, function(enter) if enter then safe(opts.Callback, box.Text); if opts.ClearOnSubmit then box.Text = "" end end end)
			return handle(card, function() return box.Text end, function(v) box.Text = tostring(v or "") end)
		end
		function section:CreateKeybind(opts)
			opts = opts or {}; local value = typeof(opts.Default) == "EnumItem" and opts.Default or Enum.KeyCode.E
			local card = self._window:_newWidget(self, opts.Name or "Keybind", 56)
			local name = self._window:_label(card, opts.Name or "Keybind", 12, "text", true); name.Position = UDim2.fromOffset(12, 0); name.Size = UDim2.new(1, -105, 1, 0)
			local binding = self._window:_button(card, value.Name, UDim2.fromOffset(84, 34), nil, { token = "raised" }); binding.Position = UDim2.new(1, -96, 0.5, -17)
			local listening = false
			self._window:_connect(binding.Activated, function() listening = true; binding.Text = "Press key…" end)
			self._window:_connect(UserInputService.InputBegan, function(input, processed)
				if processed then return end
				if listening then listening = false; if input.KeyCode ~= Enum.KeyCode.Unknown then value = input.KeyCode; binding.Text = value.Name end
				elseif input.KeyCode == value then safe(opts.Callback, value) end
			end)
			return handle(card, function() return value end, function(v) if typeof(v) == "EnumItem" then value = v; binding.Text = v.Name end end)
		end
		function section:CreateColorPicker(opts)
			opts = opts or {}; local color = typeof(opts.Default) == "Color3" and opts.Default or self._window.AccentColor; local alpha = math.clamp(tonumber(opts.Alpha) or 0, 0, 1)
			local card = self._window:_newWidget(self, opts.Name or "Color", 58)
			local name = self._window:_label(card, opts.Name or "Color", 12, "text", true); name.Position = UDim2.fromOffset(12, 0); name.Size = UDim2.new(1, -90, 1, 0)
			local swatch = self._window:_button(card, "", UDim2.fromOffset(58, 31), nil, { token = "accent" }); swatch.Position = UDim2.new(1, -70, 0.5, -15); swatch.BackgroundColor3 = color
			for index = #self._window._bindings, 1, -1 do local binding = self._window._bindings[index]; if binding.instance == swatch and binding.property == "BackgroundColor3" then table.remove(self._window._bindings, index) end end
			local edit = create("TextBox", { Visible = false, Position = UDim2.new(1, -170, 0.5, -17), Size = UDim2.fromOffset(94, 34), BackgroundColor3 = self._window._palette.input, TextColor3 = self._window._palette.text, Text = "", PlaceholderText = "#RRGGBB", Font = Enum.Font.Gotham, TextSize = 11, BorderSizePixel = 0, ClearTextOnFocus = false }, card); corner(edit, 8); padding(edit, 7, 5, 0, 0); self._window:_bind(edit, "BackgroundColor3", "input"); self._window:_bind(edit, "TextColor3", "text")
			local function set(c, a, fire) if typeof(c) == "Color3" then color = c; swatch.BackgroundColor3 = c; edit.Text = string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)) end; if a ~= nil then alpha = math.clamp(tonumber(a) or 0, 0, 1) end; if fire then safe(opts.Callback, color, alpha) end end
			self._window:_connect(swatch.Activated, function() edit.Visible = not edit.Visible; if edit.Visible then edit.Text = string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)) end end)
			self._window:_connect(edit.FocusLost, function(enter) if enter then local hex = edit.Text:gsub("#", ""); local ok, c = pcall(Color3.fromHex, hex); if ok then set(c, nil, true) else edit.Text = "Invalid hex"; self._window:_tween(edit, { BackgroundColor3 = self._window._palette.danger }, 0.15); task.delay(0.35, function() if edit.Parent and not self._window._destroyed then self._window:_applyBinding({instance=edit,property="BackgroundColor3",token="input"}) end end) end end end)
			set(color, alpha, false)
			return handle(card, function() return color, alpha end, function(v, a) set(v, a, true) end)
		end
		function section:CreateLabel(opts)
			if type(opts) == "string" then opts = { Text = opts } end; opts = opts or {}
			local card = self._window:_newWidget(self, opts.Name or "Label", opts.Paragraph and 78 or 42)
			local label = self._window:_label(card, opts.Text or opts.Name or "Label", opts.Paragraph and 12 or 13, opts.Paragraph and "muted" or "text", not opts.Paragraph); label.Position = UDim2.fromOffset(12, 6); label.Size = UDim2.new(1, -24, 1, -12); label.TextYAlignment = opts.Paragraph and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
			return handle(card, function() return label.Text end, function(v) label.Text = tostring(v) end)
		end
		function section:CreateParagraph(opts) if type(opts) == "string" then opts = { Text = opts } end; opts = opts or {}; opts.Paragraph = true; return self:CreateLabel(opts) end
		function section:CreateDivider()
			local line = create("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = self._window._palette.border, BackgroundTransparency = 0.82, BorderSizePixel = 0 }, self._body); self._window:_bind(line, "BackgroundColor3", "border"); return handle(line)
		end
		function section:CreateSpace(height)
			local gap = create("Frame", { Size = UDim2.new(1, 0, 0, math.max(tonumber(height) or 14, 1)), BackgroundTransparency = 1 }, self._body); return handle(gap)
		end
		function section:CreateProgress(opts)
			opts = opts or {}; local min, max = tonumber(opts.Min) or 0, tonumber(opts.Max) or 100; if max <= min then max = min + 1 end; local value = math.clamp(tonumber(opts.Default) or min, min, max)
			local card = self._window:_newWidget(self, opts.Name or "Progress", 60)
			local label = self._window:_label(card, opts.Name or "Progress", 11, "text"); label.Position = UDim2.fromOffset(12, 5); label.Size = UDim2.new(0.7, 0, 0, 17)
			local val = self._window:_label(card, "", 10, "muted"); val.TextXAlignment = Enum.TextXAlignment.Right; val.Position = UDim2.new(0.7, 0, 0, 5); val.Size = UDim2.new(0.27, -10, 0, 17)
			local rail = create("Frame", { Position = UDim2.new(0, 12, 0, 33), Size = UDim2.new(1, -24, 0, 11), BackgroundColor3 = self._window._palette.raised, BorderSizePixel = 0 }, card); corner(rail, 6); self._window:_bind(rail, "BackgroundColor3", "raised")
			local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = self._window.AccentColor, BorderSizePixel = 0 }, rail); corner(fill, 6); self._window:_bind(fill, "BackgroundColor3", "accent")
			local function set(v) value = math.clamp(tonumber(v) or min, min, max); fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0); val.Text = tostring(value) end; set(value)
			return handle(card, function() return value end, set)
		end
		function section:CreateImage(opts)
			opts = opts or {}; local card = self._window:_newWidget(self, opts.Name or "Image", tonumber(opts.Height) or 140)
			local imageId = tostring(opts.Image or ""); if imageId:match("^%d+$") then imageId = "rbxassetid://" .. imageId end
			local img = create("ImageLabel", { Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1, Image = imageId, ScaleType = opts.ScaleType or Enum.ScaleType.Crop }, card); corner(img, 10)
			return handle(card, function() return img.Image end, function(v) local s = tostring(v or ""); if s:match("^%d+$") then s = "rbxassetid://" .. s end; img.Image = s end)
		end
		function section:CreateSearch(opts)
			opts = opts or {}; local card = self._window:_newWidget(self, opts.Name or "Search", 54)
			local box = create("TextBox", { Position = UDim2.fromOffset(9, 9), Size = UDim2.new(1, -18, 0, 36), BackgroundColor3 = self._window._palette.input, TextColor3 = self._window._palette.text, PlaceholderColor3 = self._window._palette.muted, PlaceholderText = opts.Placeholder or "Search…", Text = "", Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, BorderSizePixel = 0 }, card); corner(box, 10); padding(box, 10, 8, 0, 0); self._window:_bind(box, "BackgroundColor3", "input"); self._window:_bind(box, "TextColor3", "text"); self._window:_bind(box, "PlaceholderColor3", "muted")
			self._window:_connect(box:GetPropertyChangedSignal("Text"), function() safe(opts.Callback, box.Text) end)
			return handle(card, function() return box.Text end, function(v) box.Text = tostring(v or "") end)
		end
		return section
	end
	self._window._tabs[#self._window._tabs + 1] = tab
	if #self._window._tabs == 1 then tab:Select() end
	return tab
end

function LarpUI:Notify(options)
	options = type(options) == "table" and options or { Title = tostring(options) }
	local toastIndex = #self._toasts + 1
	local toast = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 360, 0, 18), Size = UDim2.fromOffset(320, 88), BackgroundColor3 = self._palette.panel, BorderSizePixel = 0, ZIndex = 80 + toastIndex }, self._gui)
	table.insert(self._toasts, toast)
	corner(toast, 16); stroke(toast, self._palette.border, 0.72); self:_bind(toast, "BackgroundColor3", "panel")
	local title = self:_label(toast, options.Title or "Notification", 13, "text", true); title.Position = UDim2.fromOffset(15, 12); title.Size = UDim2.new(1, -45, 0, 20); title.ZIndex = 81
	local body = self:_label(toast, options.Content or options.Body or "", 11, "muted"); body.Position = UDim2.fromOffset(15, 36); body.Size = UDim2.new(1, -28, 0, 40); body.ZIndex = 81; body.TextYAlignment = Enum.TextYAlignment.Top
	if options.Icon then local icon = self:_icon(toast, options.Icon, UDim2.fromOffset(18, 18)); if icon then icon.Position = UDim2.new(1, -30, 0, 12); icon.ZIndex = 82 end end
	local dismissed = false
	local function restack()
		for index, item in ipairs(self._toasts) do if item.Parent then self:_tween(item, { Position = UDim2.new(1, -18, 0, 18 + (index - 1) * 98) }, 0.18) end end
	end
	local function dismiss()
		if dismissed then return end; dismissed = true
		local tw = self:_tween(toast, { Position = UDim2.new(1, 360, 0, 18) }, 0.2)
		local function finish() for index, item in ipairs(self._toasts) do if item == toast then table.remove(self._toasts, index); break end end; if toast.Parent then toast:Destroy() end; if not self._destroyed then restack() end end
		if tw then self:_connect(tw.Completed, finish) else finish() end
	end
	local dismissButton = self:_button(toast, "×", UDim2.fromOffset(26, 26), dismiss, { token = "raised", textSize = 16 }); dismissButton.Position = UDim2.new(1, -33, 1, -31); dismissButton.ZIndex = 83
	self:_tween(toast, { Position = UDim2.new(1, -18, 0, 18 + (toastIndex - 1) * 98) }, 0.24)
	local duration = tonumber(options.Duration); if duration == nil then duration = 4 end
	if duration > 0 then task.delay(duration, function() if not self._destroyed then dismiss() end end) end
	return { Instance = toast, Dismiss = dismiss }
end

function LarpUI:Confirm(options)
	options = options or {}
	local overlay = create("Frame", { Name = "ModalOverlay", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.42, ZIndex = 100 }, self._gui)
	local dialog = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.82, 0, 0, 206), BackgroundColor3 = self._palette.panel, BorderSizePixel = 0, ZIndex = 101 }, overlay)
	corner(dialog, 18); stroke(dialog, self._palette.border, 0.7); self:_bind(dialog, "BackgroundColor3", "panel")
	local heading = self:_label(dialog, options.Title or "Are you sure?", 16, "text", true); heading.Position = UDim2.fromOffset(20, 19); heading.Size = UDim2.new(1, -40, 0, 26); heading.ZIndex = 102
	local message = self:_label(dialog, options.Message or "", 12, "muted"); message.Position = UDim2.fromOffset(20, 53); message.Size = UDim2.new(1, -40, 0, 80); message.TextYAlignment = Enum.TextYAlignment.Top; message.ZIndex = 102
	local result
	local function close(value, callback) if result ~= nil then return end; result = value; safe(callback); if overlay.Parent then overlay:Destroy() end end
	local cancel = self:_button(dialog, options.CancelText or "Cancel", UDim2.new(0.42, 0, 0, 40), function() close(false, options.OnCancel) end, { token = "raised" }); cancel.Position = UDim2.new(0.06, 0, 1, -56); cancel.ZIndex = 102
	local confirm = self:_button(dialog, options.ConfirmText or "Confirm", UDim2.new(0.42, 0, 0, 40), function() close(true, options.OnConfirm) end, { token = "accent", textToken = "text" }); confirm.Position = UDim2.new(0.52, 0, 1, -56); confirm.ZIndex = 102
	return { Instance = overlay, Close = function() close(false, options.OnCancel) end }
end

function LarpUI:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	for _, tween in ipairs(self._tweens) do pcall(function() tween:Cancel() end) end
	for _, connection in ipairs(self._connections) do pcall(function() connection:Disconnect() end) end
	if self._blur then pcall(function() self._blur:Destroy() end) end
	if self._gui then pcall(function() self._gui:Destroy() end) end
	return nil
end

LarpUI.Window = LarpUI
LarpUI.Version = "1.0.0"
return LarpUI
