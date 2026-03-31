package vn;

import core.content.ContentRepository;
import haxe.Json;
import haxe.ds.StringMap;

/**
 * Data/config utilities for the VN engine.
 * Loads character definitions from characters.json.
 */

/** VN-specific atlas paths and default pose. */
typedef VNAtlasDef = {
    var png:String;
    var xml:String;
    var defaultPose:String;
};

/** Rhythm-specific atlas paths. */
typedef RhythmAtlasDef = {
    var png:String;
    var xml:String;
};

/** Full character definition matching the actual characters.json schema. */
typedef CharacterDef = {
    var id:String;
    var vn:VNAtlasDef;
    var rhythm:RhythmAtlasDef;
};

typedef CharacterDefMap = StringMap<CharacterDef>;

class VNConfig
{
    public static inline var CHARACTER_DEFS_PATH:String =
        "assets/data/characters/characters.json";

    /**
     * Load character definitions from JSON.
     *
     * Expected JSON shape:
     * {
     *   "cassian": {
     *     "id": "cassian",
     *     "rhythm": { "png": "...", "xml": "..." },
     *     "vn": { "png": "...", "xml": "...", "defaultPose": "neutral" }
     *   }
     * }
     */
    public static function loadCharacterDefs():CharacterDefMap
    {
        var map:CharacterDefMap = new StringMap<CharacterDef>();

        var raw:String;
        try {
            raw = ContentRepository.readText(CHARACTER_DEFS_PATH);
        } catch (e:Dynamic) {
            trace("[VNConfig] Could not load character defs at " + CHARACTER_DEFS_PATH + ": " + e);
            return map;
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

        var fields = Reflect.fields(dyn);
        for (id in fields) {
            var d:Dynamic = Reflect.field(dyn, id);
            if (d == null) continue;

            var vnData = d.vn;
            var rhythmData = d.rhythm;

            var def:CharacterDef = {
                id: (d.id != null) ? d.id : id,
                vn: {
                    png: vnData != null ? vnData.png : 'assets/images/characters/$id/$id.png',
                    xml: vnData != null ? vnData.xml : 'assets/images/characters/$id/$id.xml',
                    defaultPose: (vnData != null && vnData.defaultPose != null) ? vnData.defaultPose : "neutral"
                },
                rhythm: {
                    png: rhythmData != null ? rhythmData.png : 'assets/images/characters/$id/${id}_rhythm.png',
                    xml: rhythmData != null ? rhythmData.xml : 'assets/images/characters/$id/${id}_rhythm.xml'
                }
            };

            map.set(def.id, def);
        }

        trace("[VNConfig] Loaded " + fields.length + " character defs.");
        return map;
    }
}
