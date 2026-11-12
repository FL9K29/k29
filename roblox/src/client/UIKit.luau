--[[
	UIKit — small helpers for building the interface in code: colours, labels, buttons, windows.
]]

local UIKit = {}

UIKit.Colors = {
	bg = Color3.fromRGB(30, 27, 44),
	panel = Color3.fromRGB(46, 42, 66),
	row = Color3.fromRGB(58, 53, 82),
	accent = Color3.fromRGB(255, 200, 60),
	green = Color3.fromRGB(84, 190, 96),
	red = Color3.fromRGB(226, 84, 84),
	blue = Color3.fromRGB(80, 150, 240),
	grey = Color3.fromRGB(110, 106, 130),
	text = Color3.fromRGB(255, 255, 255),
	dim = Color3.fromRGB(190, 186, 210),
}

UIKit.onClick = nil :: (() -> ())? -- set by Effects to play the click sound

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className) :: any
	local parent = nil
	for key, value in (props or {}) :: { [string]: any } do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.corner(radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function UIKit.stroke(color: Color3?, thickness: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.padding(amount: number): UIPadding
	return UIKit.new("UIPadding", {
		PaddingLeft = UDim.new(0, amount), PaddingRight = UDim.new(0, amount),
		PaddingTop = UDim.new(0, amount), PaddingBottom = UDim.new(0, amount),
	})
end

function UIKit.list(direction: Enum.FillDirection, gap: number, align: Enum.HorizontalAlignment?): UIListLayout
	return UIKit.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
end

function UIKit.label(props: { [string]: any }): TextLabel
	local label = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UIKit.Colors.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

function UIKit.button(text: string, color: Color3, callback: () -> (), props: { [string]: any }?): TextButton
	local button = UIKit.new("TextButton", {
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = UIKit.Colors.text,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		TextWrapped = true,
	}, { UIKit.corner(8) })
	for key, value in (props or {}) :: { [string]: any } do
		(button :: any)[key] = value
	end
	button.MouseButton1Click:Connect(function()
		if not button.Active then
			return
		end
		if UIKit.onClick then
			UIKit.onClick()
		end
		callback()
	end)
	return button
end

-- Greys a button out and makes it ignore clicks.
function UIKit.setEnabled(button: TextButton, enabled: boolean, color: Color3?)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = enabled and (color or button.BackgroundColor3) or UIKit.Colors.grey
end

-- Removes everything from a list container except its layout objects.
function UIKit.clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

--[[
	Centered window with a title, a close button, a scrolling list and an optional footer.
	Returns { frame, content, footer }.
]]
function UIKit.window(parent: Instance, title: string, footerHeight: number?, onClose: () -> ())
	local footerSize = footerHeight or 0
	local frame = UIKit.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(660, 480),
		BackgroundColor3 = UIKit.Colors.bg,
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	}, { UIKit.corner(16), UIKit.stroke(UIKit.Colors.accent, 3) })

	UIKit.label({
		Text = title, TextSize = 24, Font = Enum.Font.GothamBlack, TextColor3 = UIKit.Colors.accent,
		Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -90, 0, 40), ZIndex = 11, Parent = frame,
	})
	UIKit.button("×", UIKit.Colors.red, onClose, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(36, 36), TextSize = 26, ZIndex = 11, Parent = frame,
	})

	local content = UIKit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.new(1, -28, 1, -(72 + footerSize)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 11,
		Parent = frame,
	}, { UIKit.list(Enum.FillDirection.Vertical, 8) })

	local footer = nil
	if footerSize > 0 then
		footer = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -12),
			Size = UDim2.new(1, -28, 0, footerSize), BackgroundColor3 = UIKit.Colors.panel,
			ZIndex = 11, Parent = frame,
		}, { UIKit.corner(10) })
	end
	return { frame = frame, content = content, footer = footer }
end

-- A list row: dark rounded frame of the given height.
function UIKit.row(parent: Instance, height: number, order: number): Frame
	return UIKit.new("Frame", {
		Size = UDim2.new(1, -12, 0, height),
		BackgroundColor3 = UIKit.Colors.row,
		LayoutOrder = order,
		ZIndex = 12,
		Parent = parent,
	}, { UIKit.corner(10) })
end

return UIKit
