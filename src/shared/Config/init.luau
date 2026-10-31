--!strict
-- Single entry point for all balancing data. Used by every server service and client controller.

return {
	Player = require(script.Player),
	Weapons = require(script.Weapons),
	WeaponClasses = require(script.WeaponClasses),
	Combat = require(script.Combat),
	Items = require(script.Items),
	Effects = require(script.Effects),
	Stats = require(script.Stats),
	Evolutions = require(script.Evolutions),
	Enemies = require(script.Enemies),
	Classes = require(script.Classes),
	Run = require(script.Run),
	Talents = require(script.Talents),
	Economy = require(script.Economy),
	Difficulty = require(script.Difficulty),
	Simulation = require(script.Simulation),
	Map = require(script.Map),
	Admin = require(script.Admin),
	Camera = require(script.Camera),
	Feedback = require(script.Feedback),
	Shop = require(script.Shop),
	Loot = require(script.Loot),
	Structures = require(script.Structures),
	Save = require(script.Save), -- Paket 12
	Progress = require(script.Progress), -- Paket 13
	Settings = require(script.Settings), -- Paket 14
	Places = require(script.Places), -- Paket 15
	Store = require(script.Store), -- Paket 16
	Cosmetics = require(script.Cosmetics), -- Paket 17
}
