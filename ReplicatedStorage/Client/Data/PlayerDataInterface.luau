-- keyof type annotation support is currently broken due to the "." keypath system

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local DataPackets = require(ReplicatedStorage.Shared.Common.ByteNet.Namespaces.DataPackets)

local BaseTemplate = require(ReplicatedStorage.Shared.Data.Templates.BaseTemplate)
local GetPlayerData = ReplicatedStorage.Shared.Data.GetPlayerData

local _playerData: BaseTemplate.base_template = {}
local _playerDataSubscriptions: {
	[keyof<BaseTemplate.base_template>]: {() -> ()}
} = {}
local _waitingThreads: {
	[keyof<BaseTemplate.base_template>]: {thread}
} = {}
local _isLoaded = false

local function fireSubscriptions(key: keyof<BaseTemplate.base_template>?)
	if key then
		for _, subscription in _playerDataSubscriptions[key] do
			task.defer(
				subscription,
				_playerData[key]
			)
		end
		return
	end
	
	for k, subscriptions in _playerDataSubscriptions do
		for _, subscription in subscriptions do
			task.defer(
				subscription,
				_playerData[k]
			)
		end
	end
end

local PlayerData = {}
-- get the value of the data associated with the given key
-- @key a string representing a key
function PlayerData.get(key: keyof<BaseTemplate.base_template>): any
	if not _isLoaded then
		local thread = coroutine.running()
		
		if not _waitingThreads[key] then
			_waitingThreads[key] = {}
		end
		
		table.insert(
			_waitingThreads[key],
			thread
		)
		
		return coroutine.yield()
	else
		return _playerData[key]
	end
end

-- update the value of the data associated with the given key
-- @key a string representing a key
function PlayerData.update(key: keyof<BaseTemplate.base_template>, value: any): ()
	assert(_playerData[key])
	
	_playerData[key] = value
	fireSubscriptions(key)
end

-- add an entry to a table of the data associated with the given key
-- @key a string representing a key
function PlayerData.add(key: keyof<BaseTemplate.base_template>, value: any): ()
	assert(_playerData[key] == typeof("table"))
	
	table.insert(
		_playerData[key],
		value
	)
	fireSubscriptions(key)
end

-- add an entry to a table of the data associated with the given key
-- @key a string representing a key
function PlayerData.remove(key: keyof<BaseTemplate.base_template>, value: any): ()
	assert(_playerData[key] == typeof("table"))
	
	local i  = table.find(
		_playerData[key],
		value
	)
	table.remove(
		_playerData[key],
		i
	)
	fireSubscriptions(key)
end

-- run a given callback for when the data has been changed for a specific key
-- @key a string representing a key
-- @func a callback that takes the value of the data associated with @key 
function PlayerData.subscribeTo<T, U>(key: keyof<BaseTemplate.base_template>, 
	func: (index<BaseTemplate.base_template, T>) -> ()): ()
	if not _playerDataSubscriptions[key] then
		_playerDataSubscriptions[key] = {}
	end
	
	table.insert(
		_playerDataSubscriptions[key],
		func
	)
	return function()
		PlayerData.unsubscribeFrom(key, func)
	end
end 

function PlayerData.unsubscribeFrom<T, U>(key: keyof<BaseTemplate.base_template>, 
	func: (index<BaseTemplate.base_template, T>) -> ()): ()
	local i = table.find(
		_playerDataSubscriptions[key],
		func
	)
	table.remove(
		_playerDataSubscriptions[key],
		i
	)
end

local function setTableValue(keyPath, value)
	local keys = string.split(keyPath, ".")
	local currentRef = _playerData

	for i = 1, #keys - 1, 1 do
		local key = keys[i]
		if type(currentRef[key]) ~= "table" then
			error("Invalid key path: " .. table.concat(keys, ".", 1, i))
		end
		currentRef = currentRef[key]
	end

	local finalKey = keys[#keys]
	currentRef[finalKey] = value
end

local function getTableValue(keyPath)
	local keys = string.split(keyPath, ".")
	local currentRef = _playerData

	for i = 1, #keys - 1, 1 do
		local key = keys[i]
		if type(currentRef[key]) ~= "table" then
			error("Invalid key path: " .. table.concat(keys, ".", 1, i))
		end
		currentRef = currentRef[key]
	end

	local finalKey = keys[#keys]
	return currentRef[finalKey]
end

-- game specific
local function handleChange(data)
	--print('data change occurred!', data.location, data.value)
	setTableValue(
		data.location,
		data.value
	)
	task.defer(
		fireSubscriptions,
		data.location
	)
end

-- location data is based on keypaths; for instance;
--[[
Imagine the following data table

local data = {
	currencies = {
		coins = 50,
		emeralds = 100
	}
}

the location to update the coins would then be; "currencies.coins"
]]

DataPackets.playerDataChangedNumber.listen(handleChange)
DataPackets.playerDataChangedString.listen(handleChange)
DataPackets.playerDataChangedBool.listen(handleChange)
DataPackets.playerDataChangedMap.listen(handleChange)

-- player data loader
task.defer(
	function()
		_playerData = GetPlayerData:InvokeServer()
		warn(script:GetFullName(), "|", "Player data load received!", _playerData)
		_isLoaded = true
		
		-- if there's any waiting yielded .get() threads
		for keyPath, waitingThreads in _waitingThreads do
			local v = getTableValue(keyPath)
			
			for _, t in waitingThreads do
				task.defer(
					t,
					v
				)
			end
			table.clear(waitingThreads)
		end
		table.clear(_waitingThreads)
	end
)
return PlayerData
