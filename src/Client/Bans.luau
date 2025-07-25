local Bans = {}
Bans.__index = Bans

function Bans.new(_K)
	local UI = _K.UI
	local escape = _K.Util.String.escapeRichText

	local function close(self)
		self.Activated(false)
	end

	local newBanDialog, unbanDialog
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
			task.defer(close, self)
		end,

		[UI.Hook] = {
			Action = function(v)
				unbanDialog.Visible(false)
				if v and unbanDialog.userId then
					_K.Remote.Unban:FireServer(tonumber(unbanDialog.userId))
				end
				unbanDialog.userId = nil
			end,
		},
	}
	unbanDialog._content:Destroy()

	local inputSize = function()
		local size = UI.Theme.FontSize()
		local padding = UI.Theme.Padding().Offset
		return UDim2.fromOffset(0, size + padding)
	end

	local banType = UI.state("Server")
	local banTypes = UI.state({ "Forever", "Timed", "Server" })
	local banTarget = UI.state()
	local banReason = nil
	local banDuration = 1
	local banDurationUnit = UI.new "Select" {
		AutomaticSize = Enum.AutomaticSize.X,
		Choice = "Hour",
		Choices = { "Hour", "Day", "Week", "Month", "Year" },
	}

	local banTargetInput
	local function resetbanTargetInput()
		banTargetInput.Value("")
		banTargetInput.Selected("")
	end

	banTargetInput = UI.new "Input" {
		AutomaticSize = Enum.AutomaticSize.X,
		Font = UI.Theme.FontMono,
		FontSize = UI.Theme.FontSize,
		MaxChars = 20,
		Placeholder = "UserId or Username",
		Size = inputSize,
		Value = "",

		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Shrink,
		},

		[UI.Hook] = {
			Selected = function(value)
				local userId
				if tonumber(value) then
					userId = tonumber(value)
				else
					local ok, result = pcall(_K.Service.Players.GetUserIdFromNameAsync, _K.Service.Players, value)
					userId = ok and result
				end

				local fauxArg = {
					_K = _K,
					definition = _K.Registry.commands.ban.args[1],
					command = {
						from = _K.LocalPlayer.UserId,
						fromRank = _K.Auth.getRank(_K.LocalPlayer.UserId),
						fromRole = {},
						rank = _K.Auth.hasCommand(_K.LocalPlayer.UserId, "ban") or 0,
					},
				}

				if userId and not _K.Auth.targetUserArgument(fauxArg, userId, userId) then
					userId = nil
					task.defer(resetbanTargetInput)
				end
				banTarget(userId)
			end,
		},
	}

	local banReasonInput = UI.new "Input" {
		AutomaticSize = Enum.AutomaticSize.X,
		Font = UI.Theme.FontMono,
		FontSize = UI.Theme.FontSize,
		MaxChars = 400,
		Placeholder = "No reason.",
		Size = inputSize,
		Value = "",
		[UI.Hook] = {
			Selected = function(value)
				banReason = value ~= "" and value
			end,
		},
	}

	local function createItem(self)
		local tooltip = UI.new "Tooltip" {
			Font = UI.Theme.FontMono,
			Text = "Loading...",
		}

		local itemRef = {
			userId = 0,
			reason = nil,
			term = nil,
			name = "",
			tipText = "",
		}

		local editBanButton = UI.new "Button" {
			LayoutOrder = 9,
			BackgroundTransparency = 1,
			-- HoverTransparency = 0,
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Icon = UI.Theme.Image.Edit,
			IconProperties = {
				ImageColor3 = UI.Theme.PrimaryText,
				Size = UDim2.fromScale(0.625, 0.625),
			},
			Text = "",
			Activated = function()
				banType(if itemRef.term == "Server" or itemRef.term == "Forever" then itemRef.term else "Timed")
				banTarget(tonumber(itemRef.userId))
				banTargetInput.Value(itemRef.userId)
				banReason = itemRef.reason
				banReasonInput.Value(itemRef.reason or "")
				newBanDialog.Title("Edit Ban")
				newBanDialog.Visible(true)
			end,
		}
		UI.new "Tooltip" { Parent = editBanButton, Text = "Edit Ban", Hovering = editBanButton._hovering }

		local unbanButton = UI.new "Button" {
			LayoutOrder = 9,
			BackgroundColor3 = Color3.fromRGB(200, 0, 0),
			BackgroundTransparency = 1,
			HoverTransparency = 0,
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Icon = UI.Theme.Image.Close_Bold,
			IconProperties = {
				ImageColor3 = UI.Theme.PrimaryText,
				Size = UDim2.fromScale(0.5, 0.5),
			},
			Text = "",
			Activated = function()
				unbanDialog.userId = itemRef.userId
				unbanDialog.ActionText(`Unban {itemRef.name} [{itemRef.userId}]?`)
				unbanDialog.Visible(true)
			end,
		}
		UI.new "Tooltip" { Parent = unbanButton, Text = "Remove Ban", Hovering = unbanButton._hovering }

		itemRef._instance = UI.new "Frame" {
			BackgroundTransparency = 1,
			Size = self.ItemSize,

			UI.new "UIPadding" {
				PaddingBottom = UI.Theme.Padding,
			},

			UI.new "UIListLayout" {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.Padding,
			},

			UI.new "ImageLabel" {
				BackgroundTransparency = UI.Theme.TransparencyHeavy,
				BackgroundColor3 = UI.Theme.PrimaryText,
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,

				UI.new "UICorner" {
					CornerRadius = UDim.new(1, 0),
				},
				UI.new "Stroke" {},
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
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
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
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = Enum.TextXAlignment.Right,

				UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill },
			},

			editBanButton,
			unbanButton,
			tooltip,
		}

		tooltip.Visible:Connect(function()
			if tooltip.Visible._value then
				tooltip.Text(itemRef.tipText)
			end
		end)

		return itemRef
	end

	local function renderItem(self, itemData, userId)
		local ban = _K.Data.bans[userId]
		if ban and ban.renderTextLeft then
			local item = itemData._instance
			item.Left.Text = ban.renderTextLeft
			item.Right.Text = ban.renderTextRight
			item.ImageLabel.Image = `rbxthumb://type=AvatarHeadShot&id={ban.userId}&w=48&h=48`

			itemData.name = ban[1]
			itemData.tipText = ban.tipText
			itemData.userId = ban.userId
			itemData.reason = ban.reason
			itemData.term = ban.term
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

	scroller._filterUpdate = true
	local function filterTest(self, list)
		local filter = string.lower(scroller._input._input.Text)
		self._filter = filter

		local noFilter = string.find(filter, "^%s*$")

		local new = {}
		for _, userId in list do
			local ban = _K.Data.bans[userId]
			if not ban then
				continue
			end

			if not ban.filterText then
				ban.userId = userId
				ban.reason = if ban[2] and _K.Util.String.trim(ban[2]) ~= "" then ban[2] else "No reason."
				ban.term = if ban[3] and ban[3] ~= 0
					then (if ban[3] > 0 and ban[3] ~= math.huge then os.date("%y-%m-%d %X", ban[3]) else "Forever")
					else "Server"

				ban.rawTextLeft = `@{ban[1] or "UNKNOWN"} [{ban.userId}]}`
				ban.rawTextRight = `{ban.term}`

				ban.richTextLeft = `<b>@{if ban[1] then escape(ban[1]) else "UNKNOWN"}</b> [{userId}]`
				ban.richTextRight = `<font transparency="0.5">{ban.term}</font>`

				ban.filterTextLeft = string.lower(ban.rawTextLeft)
				ban.filterTextRight = string.lower(ban.rawTextRight)
				ban.filterText = `{ban.filterTextLeft}\t{ban.filterTextRight}`

				ban.tipText = `<b>Reason:</b> {escape(ban.reason)}`

				task.spawn(function()
					local name = if ban[4] then _K.Util.getUserInfo(ban[4]).Username else "SYSTEM"
					ban.tipText = `<b>Author:</b> @{name}\n{ban.tipText}`
					scroller:render(true)
				end)
			end

			if noFilter then
				ban.renderTextLeft = ban.richTextLeft
				ban.renderTextRight = ban.richTextRight
				table.insert(new, userId)
			elseif string.find(ban.filterText, filter, 1, true) then
				local filterLeft = string.find(ban.filterTextLeft, self._filter, 1, true)
				local filterRight = string.find(ban.filterTextRight, self._filter, 1, true)

				if filterLeft then
					local pre = escape(string.sub(ban.rawTextLeft, 1, filterLeft - 1))
					local query = escape(string.sub(ban.rawTextLeft, filterLeft, filterLeft + #self._filter - 1))
					local post = escape(string.sub(ban.rawTextLeft, filterLeft + #self._filter))

					ban.renderTextLeft =
						`<font transparency="0.5">{pre}</font><b>{query}</b><font transparency="0.5">{post}</font>`
				else
					ban.renderTextLeft = `<font transparency="0.5">{ban.rawTextLeft}</font>`
				end

				if filterRight then
					local pre = escape(string.sub(ban.rawTextRight, 1, filterRight - 1))
					local query = escape(string.sub(ban.rawTextRight, filterRight, filterRight + #self._filter - 1))
					local post = escape(string.sub(ban.rawTextRight, filterRight + #self._filter))

					ban.renderTextRight =
						`<font transparency="0.5">{pre}</font><b>{query}</b><font transparency="0.5">{post}</font>`
				else
					ban.renderTextRight = `<font transparency="0.5">{ban.rawTextRight}</font>`
				end

				table.insert(new, userId)
			end
		end
		return new
	end

	task.defer(scroller.filter, scroller, filterTest)

	local banTypeListItem = UI.new "ListItem" {
		Text = "Type",
		UI.new "Select" {
			Choice = banType,
			Choices = banTypes,
			[UI.Hook] = {
				Selected = function(value)
					banType(value)
				end,
			},
		},
	}

	local function updateAuth()
		local savedBans = _K.Auth.hasPermission(_K.LocalPlayer.UserId, "banasync")
		if savedBans then
			banType("Forever")
		else
			banType("Server")
		end
		banTypeListItem._instance.Visible = savedBans
	end
	_K.Hook.authChanged:Connect(updateAuth)
	updateAuth()

	newBanDialog = UI.new "Dialog" {
		Parent = UI.LayerTop,
		BackgroundTransparency = 0,
		Draggable = true,
		Title = "New Ban",
		Visible = false,
		ExitButton = true,
		Modal = true,
		Close = function()
			newBanDialog.Visible(false)
		end,

		UI.new "UIPadding" {
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
		},

		UI.new "ListItem" {
			Text = "User",
			UI.new "ImageLabel" {
				BackgroundTransparency = UI.Theme.TransparencyHeavy,
				BackgroundColor3 = UI.Theme.PrimaryText,
				Size = inputSize,
				Image = function()
					return `rbxthumb://type=AvatarHeadShot&id={banTarget()}&w=48&h=48`
				end,
				UI.new "UIAspectRatioConstraint" {
					AspectType = Enum.AspectType.ScaleWithParentSize,
					DominantAxis = Enum.DominantAxis.Height,
				},
				UI.new "UICorner" {
					CornerRadius = UDim.new(1, 0),
				},
			},
			banTargetInput,
		},
		UI.new "ListItem" {
			Text = "Reason",
			banReasonInput,
		},

		banTypeListItem,

		UI.new "ListItem" {
			Text = "Duration",
			Visible = function()
				return banType() == "Timed"
			end,
			UI.new "Input" {
				AutomaticSize = Enum.AutomaticSize.X,
				Font = UI.Theme.FontMono,
				FontSize = UI.Theme.FontSize,
				MaxChars = 3,
				NumberOnly = true,
				NumberRange = NumberRange.new(1, 999),
				Placeholder = "",
				Size = inputSize,
				Value = 1,
				[UI.Hook] = {
					Selected = function(value)
						banDuration = value
					end,
				},
			},
			banDurationUnit,
		},

		UI.new "Button" {
			Label = "Ban",
			Activated = function()
				if banTarget._value then
					newBanDialog.Visible(false)
					local duration: number = if banType._value == "Server"
						then 0
						elseif banType._value == "Forever" then -1
						else banDuration * _K.Util.Time.fromUnit(banDurationUnit.Choice._value)
					_K.Remote.Ban:FireServer(banTarget._value, banReason, duration)
				end
			end,
		},
	}

	local newBanButton = UI.new "Button" {
		LayoutOrder = 3,
		ActiveSound = false,
		Icon = UI.Theme.Image.Add,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.625, 0.625),
		},
		Size = UDim2.new(1, 0, 1, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		UI.new "UIPadding" {
			PaddingTop = UI.Theme.PaddingHalf,
			PaddingBottom = UI.Theme.PaddingHalf,
			PaddingLeft = UI.Theme.PaddingHalf,
			PaddingRight = UI.Theme.PaddingHalf,
		},

		Activated = function()
			if not newBanDialog.Visible._value then
				banTarget(nil)
				banTargetInput.Value("")
				banReason = nil
				banReasonInput.Value("")
				newBanDialog.Title("New Ban")
				UI.Sound.Hover03:Play()
			end
			newBanDialog.Visible(not newBanDialog.Visible._value)
		end,
	}
	UI.new "Tooltip" { Parent = newBanButton, Text = "New Ban", Hovering = newBanButton._hovering }

	scroller._input._instance = UI.new "Frame" {
		Parent = scroller,
		Name = "FilterInput",

		BackgroundTransparency = 1,
		Size = function()
			return UDim2.new(0, 0, 0, UI.Theme.FontSize() + UI.Theme.PaddingDouble().Offset)
		end,
		UI.new "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UI.Theme.Padding,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		UI.edit(scroller._input, { UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill } }),
		newBanButton,
	}

	return scroller
end

return Bans
