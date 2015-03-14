//
//  Tile.swift
//  warfare
//
//  Created by Justin Domingue on 2015-01-21.
//  Copyright (c) 2015 Justin Domingue. All rights reserved.
//

import SpriteKit
import Darwin

func == (lhs: Tile, rhs: Tile) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

class Tile: SKShapeNode, Hashable {
    var coordinates: (Int, Int)!
    var unit: Unit?
    var village: Constants.Types.Village?
    var structure: Constants.Types.Structure?
    var land: Constants.Types.Land!
    var owner: Village!
    override var hashValue: Int {
        return "\(self.coordinates.0), \(self.coordinates.1)".hashValue
    }

    var selected: Bool = false {
        didSet {
            if selected {
                self.fillColor = UIColor.blackColor()
            } else {
                self.fillColor = Utilities.Colors.colorForLandType(self.land)
            }
        }
    }

    // MARK - Initializer

    init(dict: NSDictionary, ownerVillage village: Village? = nil) {
        super.init()

        self.owner = village
        self.deserialize(dict)

        self.draw()
    }

    init(coordinates: (Int, Int), landType: Constants.Types.Land = .Grass) {
        self.coordinates = coordinates
        self.land = landType

        super.init()
    }

    func draw() {
		self.removeAllChildren()

        self.path = makeHexagonalPath(CGFloat(Constants.Tile.size))
        self.fillColor = Utilities.Colors.colorForLandType(self.land)
        
        if self.owner?.player != nil {
            self.lineWidth = 2
            self.glowWidth = 2
        }
        
		if let s = self.structure {
			var v: Int = s.rawValue

			switch v {
			case 0:
				self.addChild(SKLabelNode(text: "Tower"))
			case 1:
				self.addChild(SKLabelNode(text: "Road"))
			case 2:
				self.addChild(SKLabelNode(text: "Tomb"))
			default:
				println("Swift wants something here. Shouldn't be printing")
			}
		}
		if self.village != nil {
			self.addChild((self.owner?.draw())!)

		}
		if let u = self.unit {
			self.addChild(u.draw())
		}

        if let order = self.owner?.player?.order {
            self.strokeColor = Utilities.Colors.colorForPlayer(order)
        } else {
            self.strokeColor = Utilities.Colors.colorForPlayer(-1)
        }
        
        if self.land == Constants.Types.Land.Tree || self.land == Constants.Types.Land.Sea {
            let sprite = SKSpriteNode(imageNamed: self.land.name())
            sprite.setScale(CGFloat(self.land.scale()))
            self.addChild(sprite)
        }
    }

    // MARK - Public functions

    func goldValue() -> Int {
        return self.land.gold()
    }

    func wage() -> Int {
        if let u = self.unit {
            return u.type.wage()
        }
		if let v = self.village {
			return v.wage()
		}

        return 0
    }

    func replaceTombstone() {
        if self.structure? == Constants.Types.Structure.Tombstone {
            self.structure = nil
            self.land = .Tree
        }
    }

	func removeUnit() {
		if self.unit != nil {
			self.unit?.node?.removeFromParent()
			self.unit = nil
		}
	}

    func isWalkable() -> Bool {
        return (self.land == .Grass || self.land == .Meadow)
                && self.structure != .Tombstone
    }

    // Check if self can prevent enemy from invading neighbouring tile.
    // @returns True if againt unit is outclassed by tile content.
	// TODO: Check the edges cases
    func isProtected(againt: Unit) -> Bool {
        return againt.type.rawValue = min(self.unit?.type.rawValue, Constants.Types.Unit.Knight.rawValue)
            || (self.structure? == Constants.Types.Structure.Tower && againt.type.rawValue < Constants.Types.Unit.Soldier.rawValue)
            || (self.village?.rawValue >= Constants.Types.Village.Fort.rawValue && againt.type.rawValue < Constants.Types.Unit.Knight.rawValue)
    }

    func isBuildable() -> Bool {
        return self.unit == nil
                    && self.village == nil
                    && self.structure == nil
                    && self.land == .Grass
    }

	func isGrowable() -> Bool {
		return self.unit == nil
					&& self.village == nil
					&& self.structure == nil
					&& self.land != .Sea
					&& self.land != .Tree
	}

    func clear() {
        unit = nil
        village = nil
        structure = nil
    }

    // MARK - Serialize

    func serialize() -> NSDictionary {
        var dict = [String: AnyObject]()

        dict["position"] = [self.coordinates.0, self.coordinates.1]
        dict["unit"] = self.unit?.serialize()
        dict["structure"] = self.structure?.rawValue
        dict["village"] = self.village?.rawValue
        dict["land"] = self.land.rawValue
        
        return dict
    }

    func deserialize(dict: NSDictionary) {
        let p = dict["position"] as? NSArray
        self.coordinates = (p![0] as Int, p![1] as Int)

        self.land = Constants.Types.Land(rawValue: dict["land"] as Int)!

        // Unit
        if let u = dict["unit"] as? NSDictionary {
            self.unit = Unit(dict: u, position: self)
        }

        // Structure
        if let s = dict["structure"] as? Int {
            self.structure = Constants.Types.Structure(rawValue: s)
        }
        
        // Village
        if let v = dict["village"] as? Int {
            self.village = Constants.Types.Village(rawValue: v)
        }
 
        // Add tile to Map
        GameEngine.Instance.map.setTile(at:self.coordinates, to: self)
    }

    // MARK - Drawing

    private func makeHexagonalPath(size: CGFloat) -> CGPath {
        let path = CGPathCreateMutable()

        for i in 0...5 {
            var angle: CGFloat = CGFloat(M_PI) / 3 * (CGFloat(i) + 0.5)
            var x = size * cos(angle)
            var y = size * sin(angle)

            if i == 0 {
                CGPathMoveToPoint(path, nil, x, y)
            } else {
                CGPathAddLineToPoint(path, nil, x, y)
            }
        }

        CGPathCloseSubpath(path)
        return path
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
