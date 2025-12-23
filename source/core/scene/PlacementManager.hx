package core.scene;

import haxe.Json;
import openfl.utils.Assets;

/**
 * PlacementManager - Handles character positioning with state persistence
 * 
 * Key features:
 * - Only loads placement changes, not full state at every node
 * - Characters maintain positions until explicitly moved
 * - Backwards compatible with old placement format
 * - Significantly reduced memory usage
 * - Auto-loads based on scene_id
 */
class PlacementManager
{
	private var placements:Map<String, Map<String, PlacementData>>;
	private var currentPositions:Map<String, PlacementData>;
	private var sceneId:String;

	public function new()
	{
		placements = new Map();
		currentPositions = new Map();
	}

	/**
	 * Load placement data from JSON file
	 * Supports both slot-based and custom coordinate positioning
	 */
	public function loadPlacements(placementPath:String):Bool
	{
		try {
			var fullPath = "assets/data/" + placementPath;
			
			trace('[PlacementManager] Attempting to load: $fullPath');
			
			var jsonText = Assets.getText(fullPath);
			var data:Dynamic = Json.parse(jsonText);

			if (data == null || data.placements == null)
			{
				trace("[PlacementManager] WARNING: No placements found in " + fullPath);
				return false;
			}

			sceneId = data.scene_id;
			placements.clear();

			var placementsObj:Dynamic = data.placements;
			var nodeIds:Array<String> = Reflect.fields(placementsObj);

			for (nodeId in nodeIds)
			{
				var nodeData:Dynamic = Reflect.field(placementsObj, nodeId);
				var characterMap = new Map<String, PlacementData>();

				var characterIds:Array<String> = Reflect.fields(nodeData);
				for (charId in characterIds)
				{
					var posData:Dynamic = Reflect.field(nodeData, charId);
					
					// Build placement data - support both formats
					var placement:PlacementData = {};
					
					// Check if custom coordinates provided
					if (Reflect.hasField(posData, "x") && Reflect.hasField(posData, "y"))
					{
						placement.x = posData.x;
						placement.y = posData.y;
					}
					
					// Check if slot provided (used if no x/y, or as documentation)
					if (Reflect.hasField(posData, "slot"))
					{
						placement.slot = posData.slot;
					}
					
					characterMap.set(charId, placement);
				}

				placements.set(nodeId, characterMap);
			}

			var nodeCount = Lambda.count(placements);
			trace('[PlacementManager] ✓ Loaded $nodeCount nodes with placement data for scene: $sceneId');
			return true;
		}
		catch (e:Dynamic)
		{
			trace("[PlacementManager] Could not load placements (will use defaults): " + e);
			return false;
		}
	}

	/**
	 * Apply placements for a specific node
	 * Only updates positions that changed at this node
	 */
	public function applyNode(nodeId:String):Void
	{
		if (!placements.exists(nodeId))
		{
			// No placement changes at this node, keep current positions
			return;
		}

		var nodePlacements = placements.get(nodeId);
		for (charId in nodePlacements.keys())
		{
			var placement = nodePlacements.get(charId);
			currentPositions.set(charId, {
				x: placement.x,
				y: placement.y,
				slot: placement.slot
			});
		}
	}

	/**
	 * Get the current position for a character
	 * Returns null if character doesn't have a saved position
	 */
	public function getPosition(characterId:String):Null<PlacementData>
	{
		return currentPositions.get(characterId);
	}

	/**
	 * Check if a character has a custom position
	 */
	public function hasPosition(characterId:String):Bool
	{
		return currentPositions.exists(characterId);
	}

	/**
	 * Remove a character from position tracking (when they're hidden)
	 */
	public function removeCharacter(characterId:String):Void
	{
		currentPositions.remove(characterId);
	}

	/**
	 * Clear all current positions (e.g., when loading new scene)
	 */
	public function reset():Void
	{
		currentPositions.clear();
	}

	/**
	 * Debug: Get all currently tracked characters
	 */
	public function getTrackedCharacters():Array<String>
	{
		var chars = [];
		for (key in currentPositions.keys())
			chars.push(key);
		return chars;
	}
}

/**
 * Position data for a character
 * Supports both slot-based and custom coordinate positioning
 */
typedef PlacementData =
{
    /**
     * Custom X coordinate (optional)
     * If present, takes precedence over slot
     */
    var ?x:Float;
    
    /**
     * Custom Y coordinate (optional)
     * If present, takes precedence over slot
     */
    var ?y:Float;
    
    /**
     * Slot name (optional)
     * Used if x/y not present, or as documentation
     */
    var ?slot:String;
}