package core.scene;

import core.content.ContentRepository;
import haxe.Json;
import vn.Constants;

/**
 * PlacementManager - Character slot assignments per scene node.
 *
 * FORMAT (assets/data/placements/{scene_id}_placement.json):
 * {
 *   "node_id": { "char_id": "slot_name" },
 *   "node_id2": { "char_id": "hidden" }
 * }
 *
 * Slot names: far_left | left | center_left | center | center_right | right | far_right
 * Special:    "hidden" — character is removed from stage at this node
 *
 * getSlot() returns:
 *   - A slot name  → move character to that slot
 *   - "hidden"     → hide character at this node
 *   - null         → no entry; caller keeps current position
 *
 * This class is a pure lookup table. It holds no mutable character state.
 * Character position state lives in CharacterRenderer.
 */
class PlacementManager
{
    // nodeId → (charId → slot)
    private var data:Map<String, Map<String, String>> = new Map();

    public function new() {}

    /**
     * Load placement data from a path relative to assets/data/.
     * Returns true if the file was found and parsed successfully.
     */
    public function load(path:String):Bool
    {
        var fullPath = "assets/data/" + path;

        if (!ContentRepository.exists(fullPath))
            return false;

        try
        {
            var raw:Dynamic = Json.parse(ContentRepository.readText(fullPath));
            data.clear();

            for (nodeId in Reflect.fields(raw))
            {
                var nodeObj:Dynamic = Reflect.field(raw, nodeId);
                var nodeMap = new Map<String, String>();

                for (charId in Reflect.fields(nodeObj))
                {
                    var slot:Dynamic = Reflect.field(nodeObj, charId);
                    if (slot != null)
                        nodeMap.set(charId, Std.string(slot));
                }

                data.set(nodeId, nodeMap);
            }

            return true;
        }
        catch (e:Dynamic)
        {
            trace('[PlacementManager] Failed to parse ${fullPath}: ${e}');
            return false;
        }
    }

    /**
     * Get the slot assignment for a character at a specific node.
     *
     * Returns:
     *   slot string  — move to this slot
     *   "hidden"     — hide this character
     *   null         — no entry at this node; keep current position
     */
    public function getSlot(nodeId:String, charId:String):Null<String>
    {
        var nodeMap = data.get(nodeId);
        if (nodeMap == null) return null;
        return nodeMap.get(charId);
    }

    /**
     * Get all slot assignments defined at a node.
     * Returns null if no placements exist for this node.
     */
    public function getNodePlacements(nodeId:String):Null<Map<String, String>>
    {
        return data.get(nodeId);
    }

    /**
     * True if any placements are defined for this node.
     */
    public inline function hasNode(nodeId:String):Bool
    {
        return data.exists(nodeId);
    }

    /**
     * True if the slot value is legal (a known slot name or "hidden").
     */
    public inline function isValidSlot(slot:String):Bool
    {
        return slot == "hidden" || Constants.isValidSlot(slot);
    }

    /**
     * Clear loaded data (call before loading a new scene).
     */
    public function reset():Void
    {
        data.clear();
    }
}
