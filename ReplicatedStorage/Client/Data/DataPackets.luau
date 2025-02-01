-- shouldnt be in this location but this repo is purely for tutorial/implementation purposes

local ByteNet = require(script.Parent.Parent.ByteNet)

return ByteNet.defineNamespace("Data", function()
	return {
		playerDataChangedNumber = ByteNet.definePacket({
			value = ByteNet.struct({
				location = ByteNet.string,
				value = ByteNet.float32
			})
		}),

		playerDataChangedString = ByteNet.definePacket({
			value = ByteNet.struct({
				location = ByteNet.string,
				value = ByteNet.string
			})
		}),

		playerDataChangedMap = ByteNet.definePacket({
			value = ByteNet.struct({
				location = ByteNet.string,
				value = ByteNet.map
			})
		}),

		playerDataChangedBool = ByteNet.definePacket({
			value = ByteNet.struct({
				location = ByteNet.string,
				value = ByteNet.bool
			})
		}),
	}
end)
