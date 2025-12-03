package vn;

import haxe.Json;
import haxe.ds.StringMap;
import openfl.utils.Assets;

/**
 * Data/config utilities for the VN engine.
 * Currently: character definition loading.
 */

// Single character definition from data
typedef CharacterDef = {
    var id:String;         // "cassian"
    var png:String;        // "assets/images/characters/cassian/cassian.png"
    var xml:String;        // "assets/images/characters/cassian/cassian.xml"
    var defaultPose:String;// e.g. "neutral"
};

// Map of id → def
typedef CharacterDefMap = StringMap<CharacterDef>;

class VNConfig
{
    // Path to the character definitions JSON in your assets
    public static inline var CHARACTER_DEFS_PATH:String =
        "assets/data/characters/characters.json";

    /**
     * Load character definitions from JSON and return a CharacterDefMap.
     *
     * Expected JSON shape:
     *
     * {
     *   "cassian": {
     *     "id": "cassian",
     *     "png": "assets/images/characters/cassian/cassian.png",
     *     "xml": "assets/images/characters/cassian/cassian.xml",
     *     "defaultPose": "neutral"
     *   },
     *   "tiffany": {
     *     "id": "tiffany",
     *     "png": "assets/images/characters/tiffany/tiffany.png",
     *     "xml": "assets/images/characters/tiffany/tiffany.xml",
     *     "defaultPose": "neutral"
     *   }
     * }
     */
    public static function loadCharacterDefs():CharacterDefMap
    {
        var map:CharacterDefMap = new StringMap<CharacterDef>();

        var raw:String;
        try {
            raw = Assets.getText(CHARACTER_DEFS_PATH);
        } catch (e:Dynamic) {
            trace("[VNConfig] Could not load character defs at " + CHARACTER_DEFS_PATH + ": " + e);
            return map; // empty
        }

        if (raw == null || raw.length == 0) {
            trace("[VNConfig] Character defs file is empty: " + CHARACTER_DEFS_PATH);
            return map;
        }

        var dyn:Dynamic;
        try {
            dyn = Json.parse(raw);
        } catch (e:Dynamic) {
            trace("[VNConfig] Failed to parse character defs JSON: " + e);
            return map;
        }

        // Iterate top-level fields as character IDs
        var fields = Reflect.fields(dyn);
        for (id in fields) {
            var d:Dynamic = Reflect.field(dyn, id);
            if (d == null) continue;

            // Allow "id" to be omitted and default to key
            var def:CharacterDef = {
                id: (Reflect.hasField(d, "id") && d.id != null) ? d.id : id,
                png: d.png,
                xml: d.xml,
                defaultPose: (Reflect.hasField(d, "defaultPose") && d.defaultPose != null)
                    ? d.defaultPose
                    : "neutral"
            };

            map.set(def.id, def);
        }

        trace("[VNConfig] Loaded " + fields.length + " character defs.");
        return map;
    }
}
