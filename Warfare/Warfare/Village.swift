import Foundation

class Village {
	var type = Constants.Types.Village.Hovel
	var gold: Int = 0
	var wood: Int = 0

	let position: Tile
	var controlledTiles: [Tile] = [Tile]()

	init(tile: Tile) {
		self.position = tile
	}

	func upgradeVillage(newType: Constants.Types.Village) {
		if (newType.rawValue - self.type.rawValue) == 1 && self.wood >= 8 {
			self.wood -= 8
			self.type = newType
		}
	}

	func addTile(tile: Tile) {
		controlledTiles.append(tile)
	}

	func upgradeUnit(unit: Unit, newType: Constants.Types.Unit) {
		if !self.containsUnit(unit) { return }

		let upgradeInterval = newType.rawValue - unit.type.rawValue

		if upgradeInterval >= 1 && self.gold >= upgradeInterval * 10 {
			self.gold -= 10 * upgradeInterval
			unit.type = newType
		}
	}

	func containsUnit(unit: Unit) -> Bool {
		for element in self.controlledTiles {
			if element.unit === unit {
				return true
			}
		}

		return false
	}
}
