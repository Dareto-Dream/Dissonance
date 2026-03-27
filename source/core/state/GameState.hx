package core.state;

/**
 * GameState - Singleton holding all mutable game state.
 *
 * Stores numeric variables, boolean flags, scene history,
 * and rhythm results. Supports serialization for save/load.
 *
 * Variable access supports dot-notation keys (e.g. "player.flags.puppet_mode")
 * which are stored as flat string keys internally.
 */
class GameState {
    // ========================================================================
    // Singleton
    // ========================================================================

    private static var _instance:GameState;

    public static function get():GameState {
        if (_instance == null) _instance = new GameState();
        return _instance;
    }

    public static function reset():Void {
        _instance = new GameState();
    }

    // ========================================================================
    // State storage
    // ========================================================================

    /** Numeric variables (e.g. tiffany_rot, cassian_rot) */
    public var variables:Map<String, Float>;

    /** Boolean flags (e.g. asked_tiffany, puppet_mode) */
    public var flags:Map<String, Bool>;

    /** Current scene path */
    public var currentScene:String;

    /** Current node ID */
    public var currentNode:String;

    /** Total playtime in seconds */
    public var playtime:Float;

    /** Visited node history for skip/backlog */
    public var sceneHistory:Array<HistoryEntry>;

    /** Rhythm game results keyed by song ID */
    public var rhythmResults:Map<String, RhythmResult>;

    // ========================================================================
    // Constructor
    // ========================================================================

    private function new() {
        variables = new Map<String, Float>();
        flags = new Map<String, Bool>();
        currentScene = "";
        currentNode = "";
        playtime = 0;
        sceneHistory = [];
        rhythmResults = new Map<String, RhythmResult>();
    }

    // ========================================================================
    // Variable access
    // ========================================================================

    public function setVar(key:String, value:Float):Void {
        variables.set(key, value);
    }

    public function getVar(key:String):Float {
        return variables.exists(key) ? variables.get(key) : 0.0;
    }

    public function addVar(key:String, amount:Float):Void {
        setVar(key, getVar(key) + amount);
    }

    public function setFlag(key:String, value:Bool):Void {
        flags.set(key, value);
    }

    public function getFlag(key:String):Bool {
        return flags.exists(key) ? flags.get(key) : false;
    }

    /**
     * Generic getter that checks flags first (for bool), then variables (for float).
     * Used by ConditionParser for expression evaluation.
     */
    public function getValue(key:String):Dynamic {
        if (flags.exists(key)) return flags.get(key);
        if (variables.exists(key)) return variables.get(key);
        return 0.0;
    }

    // ========================================================================
    // History
    // ========================================================================

    public function recordNode(scene:String, node:String):Void {
        sceneHistory.push({scene: scene, node: node});
        // Cap history at 1000 entries
        if (sceneHistory.length > 1000) {
            sceneHistory.splice(0, sceneHistory.length - 1000);
        }
    }

    public function hasVisited(scene:String, node:String):Bool {
        for (entry in sceneHistory) {
            if (entry.scene == scene && entry.node == node) return true;
        }
        return false;
    }

    // ========================================================================
    // Rhythm results
    // ========================================================================

    public function setRhythmResult(songId:String, result:RhythmResult):Void {
        rhythmResults.set(songId, result);
    }

    public function getRhythmResult(songId:String):RhythmResult {
        return rhythmResults.exists(songId) ? rhythmResults.get(songId) : null;
    }

    // ========================================================================
    // Serialization
    // ========================================================================

    public function serialize():Dynamic {
        var varsObj:Dynamic = {};
        for (key in variables.keys()) {
            Reflect.setField(varsObj, key, variables.get(key));
        }

        var flagsObj:Dynamic = {};
        for (key in flags.keys()) {
            Reflect.setField(flagsObj, key, flags.get(key));
        }

        var rhythmObj:Dynamic = {};
        for (key in rhythmResults.keys()) {
            var r = rhythmResults.get(key);
            Reflect.setField(rhythmObj, key, {
                score: r.score,
                combo: r.combo,
                rating: r.rating,
                completed: r.completed
            });
        }

        return {
            version: 1,
            variables: varsObj,
            flags: flagsObj,
            currentScene: currentScene,
            currentNode: currentNode,
            playtime: playtime,
            sceneHistory: sceneHistory,
            rhythmResults: rhythmObj
        };
    }

    public function deserialize(data:Dynamic):Void {
        variables = new Map<String, Float>();
        flags = new Map<String, Bool>();
        rhythmResults = new Map<String, RhythmResult>();

        if (data.variables != null) {
            for (key in Reflect.fields(data.variables)) {
                variables.set(key, Reflect.field(data.variables, key));
            }
        }

        if (data.flags != null) {
            for (key in Reflect.fields(data.flags)) {
                flags.set(key, Reflect.field(data.flags, key));
            }
        }

        currentScene = data.currentScene != null ? data.currentScene : "";
        currentNode = data.currentNode != null ? data.currentNode : "";
        playtime = data.playtime != null ? data.playtime : 0.0;

        if (data.sceneHistory != null) {
            sceneHistory = [];
            var arr:Array<Dynamic> = data.sceneHistory;
            for (entry in arr) {
                sceneHistory.push({scene: entry.scene, node: entry.node});
            }
        }

        if (data.rhythmResults != null) {
            for (key in Reflect.fields(data.rhythmResults)) {
                var r = Reflect.field(data.rhythmResults, key);
                rhythmResults.set(key, {
                    score: r.score,
                    combo: r.combo,
                    rating: r.rating,
                    completed: r.completed
                });
            }
        }
    }
}

// ============================================================================
// Supporting types
// ============================================================================

typedef HistoryEntry = {
    scene:String,
    node:String
};

typedef RhythmResult = {
    score:Int,
    combo:Int,
    rating:String,
    completed:Bool
};
