local Bans = {}
Bans.__index = Bans

function Bans.new(_K)
	local UI = _K.UI
	local escape = _K.Util.String.escapeRichText

	local unbanDialog
	unbanDialog = UI.new "Dialog" {
		LayoutOrder = 9,
		BackgroundTransparency = 0.875,
		BackgroundColor3 = UI.Theme.Secondary,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		ActionText = "Unban this user?",
		Action = true,
		LeftAction = true,
		RightAction = true,
		Visible = false,
		Close = function(self)
			task.defer(self.Activated.set, self.Activated, false)
		end,

		[UI.Hook] = {
			Action = function(v)
				unbanDialog._instance.Visible = false
				if v and unbanDialog.userId then
					_K.Remote.Unban:FireServer(tonumber(unbanDialog.userId))
				end
				unbanDialog.userId = nil
			end,
		},
	}
	unbanDialog._content:Destroy()

	local nameRef = {}
	local userIdRef = {}

	local function createItem(self)
		local item
		local unbanButton = UI.new "Button" {
			LayoutOrder = 9,
			BackgroundColor3 = Color3.fromRGB(200, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Icon = UI.Theme.Image.Close,
			IconProperties = {
				Size = UDim2.new(0, 10, 0, 10),
			},
			Text = "",
			Activated = function()
				unbanDialog.userId = userIdRef[item]
				unbanDialog.ActionText:set(`Unban {nameRef[item]} [{userIdRef[item]}]?`)
				unbanDialog._instance.Visible = true
			end,
		}

		item = UI.new "Frame" {
			BackgroundTransparency = 1,
			Size = self.ItemSize,

			UI.new "UIPadding" {
				PaddingTop = UI.Theme.PaddingHalf,
				PaddingBottom = UI.Theme.PaddingHalf,
			},

			UI.new "UIListLayout" {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.Padding,
			},

			UI.new "ImageLabel" {
				BackgroundTransparency = 0.75,
				BackgroundColor3 = UI.Theme.Border,
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,

				UI.new "UICorner" {
					CornerRadius = UDim.new(1, 0),
				},
				UI.new "UIStroke" {
					Enabled = UI.Theme.StrokeEnabled,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Transparency = UI.Theme.TransparencyClamped,
					Color = UI.Theme.Border,
				},
			},

			UI.new "TextLabel" {
				Name = "Left",
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 1, 0),
				RichText = true,
				Font = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			UI.new "TextLabel" {
				Name = "Right",
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 1, 0),
				RichText = true,
				Font = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = Enum.TextXAlignment.Right,

				UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill },
			},

			unbanButton,
		}

		return item
	end

	local function renderItem(self, item, ban)
		if not ban.userId then
			return
		end

		nameRef[item] = ban[1]
		userIdRef[item] = ban.userId

		if self._filter ~= "" then
			item.Left.Text = ban.richFilterTextLeft
			item.Right.Text = ban.richFilterTextRight
		else
			item.Left.Text = ban.richTextLeft
			item.Right.Text = ban.richTextRight
		end

		if item:FindFirstChild("ImageLabel") then
			item.ImageLabel.Image = `rbxthumb://type=AvatarHeadShot&id={ban.userId}&w=48&h=48`
		end
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Bans",
		List = _K.client.bans,
		Enabled = false,
		DictList = true,
		FilterInput = true,
		Visible = false,
		CreateItem = createItem,
		RenderItem = renderItem,

		unbanDialog,
	}
	UI.edit(scroller._scroller, {
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	})

	local function filterTest(self, list)
		local filter = string.lower(scroller._input._input.Text)
		self._filter = filter
		local new = {}
		for _, userId in list do
			local ban = _K.Data.bans[userId]
			if not ban then
				warn("no ban defined?")
				continue
			end

			if not ban.filterText then
				ban.userId = userId
				ban.reason = if ban[2] and _K.Util.String.trim(ban[2]) ~= "" then ban[2] else "No reason."
				ban.term = if ban[3]
					then (if ban[3] > 0 and ban[3] ~= math.huge then os.date("%y-%m-%d %X", ban[3]) else "Forever")
					else "Session"

				local termPadding = if #ban.term < 18 then string.rep(" ", 18 - #ban.term) else ""
				ban.rawTextLeft = `@{ban[1] or "UNKNOWN"} [{ban.userId}]`
				ban.rawTextRight = `{ban.reason}{termPadding}{ban.term}`

				ban.richTextLeft = `<b>@{if ban[1] then escape(ban[1]) else "UNKNOWN"}</b> [{escape(userId)}]`
				ban.richTextRight =
					`{escape(ban.reason)}{escape(termPadding)}<font transparency="0.5">{escape(ban.term)}</font>`

				ban.filterTextLeft = string.lower(ban.rawTextLeft)
				ban.filterTextRight = string.lower(ban.rawTextRight)
				ban.filterText = `{ban.filterTextLeft}\t{ban.filterTextRight}`
			end

			if string.find(ban.filterText, filter, 1, true) then
				local filterLeft = string.find(ban.filterTextLeft, self._filter, 1, true)
				local filterRight = string.find(ban.filterTextRight, self._filter, 1, true)

				if filterLeft then
					local pre = escape(string.sub(ban.rawTextLeft, 1, filterLeft - 1))
					local query = escape(string.sub(ban.rawTextLeft, filterLeft, filterLeft + #self._filter - 1))
					local post = escape(string.sub(ban.rawTextLeft, filterLeft + #self._filter))

					ban.richFilterTextLeft =
						`<font transparency="0.5">{pre}</font><b>{query}</b><font transparency="0.5">{post}</font>`
				else
					ban.richFilterTextLeft = `<font transparency="0.5">{ban.rawTextLeft}</font>`
				end

				if filterRight then
					local pre = escape(string.sub(ban.rawTextRight, 1, filterRight - 1))
					local query = escape(string.sub(ban.rawTextRight, filterRight, filterRight + #self._filter - 1))
					local post = escape(string.sub(ban.rawTextRight, filterRight + #self._filter))

					ban.richFilterTextRight =
						`<font transparency="0.5">{pre}</font><b>{query}</b><font transparency="0.5">{post}</font>`
				else
					ban.richFilterTextRight = `<font transparency="0.5">{ban.rawTextRight}</font>`
				end

				table.insert(new, ban)
			end
		end
		return new
	end

	task.defer(scroller.filter, scroller, filterTest)

	return scroller
end

return Bans
