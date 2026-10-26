--!strict
-- Single entry point for all balancing data. Used by every server service and client controller.

return {
	Player = require(script.Player),
	Weapons = require(script.Weapons),
	Passives = require(script.Passives),
	Evolutions = require(script.Evolutions),
	Enemies = require(script.Enemies),
	Classes = require(script.Classes),
	Run = require(script.Run),
	Talents = require(script.Talents),
	Economy = require(script.Economy),
	Difficulty = require(script.Difficulty),
	Simulation = require(script.Simulation),
}
