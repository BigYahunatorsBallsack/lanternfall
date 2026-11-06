--!strict
-- Character pictures as used by Icons in the lobby: the same images the world sprites show (Config/SpriteImages).
local Images = require(game:GetService("ReplicatedStorage").Shared.Config.SpriteImages)

local portraits: { [string]: string } = {}
for id, entry in Images.characters do
	portraits[id] = entry.image
end
return table.freeze(portraits)
