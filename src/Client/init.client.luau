local _K = require(script.Parent)
local UI = _K.UI

_K.Announce = require(script:WaitForChild("Announce"))
_K.Notify = require(script:WaitForChild("Notify"))

_K.LocalPlayer = _K.Service.Players.LocalPlayer

_K.client = {
	Character = require(script:WaitForChild("Character")),
	TopbarPlus = require(script.Parent:WaitForChild("TopbarPlus")),
	UserFrame = require(script:WaitForChild("UserFrame")),

	bans = _K.Flux.state(_K.Data.bans),
	logs = _K.Flux.state(_K.Data.logs),
	members = _K.Flux.state(_K.Data.members),
	rank = _K.Flux.state(0),

	ready = false,
	hotkeys = {
		dashboard = { key = _K.Flux.state(Enum.KeyCode.Quote), mods = {}, callback = nil },
	},
	settings = {},
	themes = UI.state({}),
}

-- Initialize themes
local themeFolder = script:WaitForChild("UI"):WaitForChild("Theme"):WaitForChild("Themes")
for _, themeModule: ModuleScript in themeFolder:GetChildren() do
	if themeModule:IsA("ModuleScript") then
		if _K.client.themes._value[themeModule.Name] then
			warn("[Kohl's Admin]: Duplicate theme found! Make sure they have different names.")
		end
		local theme = require(themeModule)
		local content = {}
		for _, definition in { theme.Image, theme.Sound } do
			for key, value in definition do
				if UI.isState(definition[key]) then
					definition[key]("rbxassetid://" .. UI.raw(value))
				else
					definition[key] = "rbxassetid://" .. UI.raw(value)
				end
			end
		end
		if themeModule.Name == "Default" then
			-- clone the default theme to allow for intellisense without overwriting the values
			local default = {}
			for key, value in theme do
				default[key] = if type(value) == "table" then table.clone(value) else value
			end
			_K.client.themes._value[themeModule.Name] = default
		else
			_K.client.themes._value[themeModule.Name] = theme
		end

		task.spawn(_K.Service.ContentProvider.PreloadAsync, _K.Service.ContentProvider, content)
	end
end
_K.client.themes(_K.client.themes._value, true)

local function deepMergeTheme(from, to, prefix: string?)
	for key, value in from do
		value = UI.raw(value)
		if UI.isState(to[key]) then
			if prefix then
				key = prefix .. key
				_K.Data.settings[key] = value
				_K.client.settings[key](value)
			else
				to[key](value)
			end
		elseif type(value) == "table" then
			deepMergeTheme(value, to[key])
		end
	end
end

function UI.changeTheme(new)
	deepMergeTheme(new, UI.Theme, "theme")
end

-- Flux stateful settings
for key, value in _K.Data.settings do
	local state = _K.Flux.state(value)
	_K.client.settings[key] = state

	-- UI.Theme connection to theme settings
	if key == "defaultTheme" then
		state:Connect(function(value)
			local theme = _K.client.themes._value[value]
			if theme then
				UI.changeTheme(theme)
			end
		end)
	elseif string.find(key, "theme", 1, true) == 1 then
		key = string.sub(key, 6)
		if UI.Theme[key] then
			state:Connect(function(value)
				UI.Theme[key](value)
			end)
		end
	end
end

function _K.client.syncSettings(settings)
	for key, value in settings do
		value = UI.raw(value)
		if
			string.find(key, "theme", 1, true) == 1
			and (_K.Data.settings.changeThemeAuthority == "Studio" or settings.defaultTheme ~= "Custom (DataStore)")
		then
			continue
		end
		_K.Data.settings[key] = value
		if _K.client.settings[key] then
			_K.client.settings[key](value)
		end
	end
end

local chatCommandThrottle
local warnPrefixes = _K.Util.String.escapePattern(";:!$~.")

local function Chatted(message: string)
	if _K.Data.settings.chatCommands == false then
		return
	end
	local prefix = _K.getCommandPrefix()

	local commandFormat =
		`%s[^%s{_K.Process.ignoreFormat}{_K.Util.String.escapePattern(_K.Data.settings.splitKey or "%s")}]`
	local commandStart
	for _, value in { prefix, unpack(_K.Data.settings.prefix) } do
		local escapedPrefix = _K.Util.String.escapePattern(value)
		commandStart = string.find(message, string.format(commandFormat, escapedPrefix, escapedPrefix))
		if commandStart then
			break
		end
	end

	if not commandStart then
		-- check for optionalPrefix
		local directCommand = _K.Registry.commands[string.lower(message)]
		if directCommand and directCommand.optionalPrefix then
			commandStart = 1
			message = prefix .. message
		else
			if _K.Data.settings.wrongPrefixWarning ~= false and #warnPrefixes > 0 then
				local test = " " .. string.lower(message)
				for alias in _K.Registry.commands do
					local i = string.find(test, `[{warnPrefixes}]{_K.Util.String.escapePattern(alias)}`)
					if i then
						warnPrefixes =
							_K.Util.String.escapePattern(warnPrefixes:gsub("%%", ""):gsub(test:sub(i, i), ""))
						task.spawn(_K.Notify, {
							From = "_K",
							Text = `<b>Invalid command prefix, try "{prefix}{alias}"</b>`,
							TextColor3 = Color3.new(1, 0, 0),
							Sound = "Call_Leave",
						})
						break
					end
					_K.Util.Defer.wait()
				end
			end
			return
		end
	end
	if not chatCommandThrottle then
		chatCommandThrottle = true
		_K.Process.runCommands(_K, _K.LocalPlayer.UserId, string.sub(message, commandStart))
		task.wait(0.2)
		chatCommandThrottle = nil
	end
end

if _K.Service.TextChat.ChatVersion == Enum.ChatVersion.TextChatService then
	_K.Service.TextChat.SendingMessage:Connect(function(textChatMessage: TextChatMessage)
		Chatted(_K.Util.String.unescapeRichText(textChatMessage.Text))
	end)
end

_K.Remote.Command.OnClientEvent:Connect(Chatted)

_K.Service.UserInput.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		for keyName, data in _K.client.hotkeys do
			if
				data.callback
				and (
					input.KeyCode == data.key._value
					or (type(data.key._value) == "table" and table.find(data.key._value, input.KeyCode))
				)
			then
				local missingMod = false
				for _, modifierKey in Enum.ModifierKey:GetEnumItems() do
					local isDown = input:IsModifierKeyDown(modifierKey)
					if isDown == not data.mods[modifierKey] then
						missingMod = true
						break
					end
				end
				if missingMod then
					return
				end
				task.defer(data.callback)
			end
		end
	end
end)

-- initial remote connection

_K.Remote.Init.OnClientEvent:Once(function(bans, logs, members, roles, settings, servers)
	-- need to improve networking performance!
	if bans then
		_K.Util.Table.merge(_K.Data.bans, bans)
		_K.client.bans(_K.Data.bans)
	end

	if logs then
		table.move(logs, 1, #logs, #_K.Data.logs + 1, _K.Data.logs)
		table.sort(_K.Data.logs, _K.Logger.sortTime)
	end

	if servers then
		_K.Util.Table.merge(_K.Data.reservedServers, servers)
	end

	_K.Util.Table.merge(_K.Data.members, members)
	_K.client.members(_K.Data.members)

	_K.Data.roles = roles
	for role, roleData in roles do
		_K.Data.rolesList[roleData._rank] = roleData
	end

	_K.client.syncSettings(settings)

	_K.client.CommandBar = require(script:WaitForChild("CommandBar"))
	_K.client.CommandBar:init(_K)
	_K.client.Dashboard = require(script:WaitForChild("Dashboard")) -- relies on command bar
	require(script:WaitForChild("GetKA"))
	require(script:WaitForChild("Network"))

	if
		_K.Data.settings.joinNotificationRank
		and _K.Auth.getRank(_K.Service.Players.LocalPlayer.UserId) >= _K.Data.settings.joinNotificationRank
	then
		local member = _K.Data.members[tostring(_K.LocalPlayer.UserId)]
		local roleStrings = {}
		if member and member.roles then
			for _, role in member.roles do
				local roleData = _K.Data.roles[role]
				if roleData then
					table.insert(roleStrings, `<font color="{roleData.color}">{roleData.name}</font>`)
				end
			end
		end
		table.insert(roleStrings, `<font color="{_K.Data.roles.everyone.color}">{_K.Data.roles.everyone.name}</font>`)
		local roleString = table.concat(roleStrings, ", ")

		_K.Notify({
			From = "_K",
			Text = `<font family="{UI.Theme.FontMono._value.Name}"><b>Role{if #member.roles > 1 then "s" else ""}:</b>\n<sc>{roleString}</sc></font>`,
			Duration = 15,
		})
	end

	if _K.Data.settings.announcements then
		for _, announcement in _K.Data.settings.announcements do
			_K.Announce(announcement)
		end
	end

	if _K.Data.settings.notifications then
		for _, notification in _K.Data.settings.notifications do
			_K.Notify(notification)
		end
	end

	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	-- finally load client and shared addons
	local function loadAddons(list)
		for _, object in list do
			if object:IsA("ModuleScript") then
				task.spawn(function()
					require(object)(_K)
				end)
			else
				loadAddons(object:GetChildren())
			end
		end
	end

	loadAddons(_K.script:WaitForChild("DefaultAddons"):GetChildren())
	loadAddons(_K.script:WaitForChild("Addons"):GetChildren())
	loadAddons(_K.Service.Collection:GetTagged(_K._addonTag))

	_K.client.updateInterfaceAuth()

	_K.client.ready = true
	_K.Hook.init:Fire()
end)

_K.Remote.Init:FireServer({ Attributes = { Platform = UI.Platform, SessionStart = workspace:GetServerTimeNow() } })

local lastIdle = time()
local function resetIdle()
	if time() - 30 > lastIdle then
		_K.Remote.Idled:FireServer(0)
	end
end

_K.Service.Players.LocalPlayer.Idled:Connect(function(idleTime)
	lastIdle = time()
	_K.Remote.Idled:FireServer(idleTime)
	task.delay(35, resetIdle)
end)
