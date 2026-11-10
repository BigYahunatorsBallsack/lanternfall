--!strict
-- Validate approved character bounds and native provenance; Classes uses this for atomic legacy promotion.
local Artwork = {}
function Artwork.valid(art: any, native: boolean?): boolean
	local id = art and type(art.image) == "string" and tonumber(art.image:match("^rbxassetid://(%d+)$"))
	return art ~= nil
		and type(id) == "number"
		and id > 0
		and type(art.height) == "number"
		and art.height > 0
		and type(art.ground) == "number"
		and art.ground >= 0
		and type(art.center) == "number"
		and art.center > 0
		and (not native or art.nativeVersion == "1.2.0.1")
end
function Artwork.promote(class: any, package: any, art: any): boolean
	if class == package or not Artwork.valid(art, true) then
		return false
	end
	table.clear(class)
	for key, value in package do
		class[key] = value
	end
	class.available = true
	return true
end
return Artwork
