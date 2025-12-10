package vn;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxTimer;

class SceneRunner {
    public var parser:SceneParser;
    public var currentNode:String;
    public var active:Bool = false;

    public function new(scenePath:String) {
        parser = new SceneParser(scenePath);
        currentNode = parser.startNode;
        active = true;
        
        // Auto-load placement file based on scene_id
        loadPlacementFile();
    }
    
    /**
     * Automatically load placement file for this scene
     * Looks for: assets/data/placements/{scene_id}_placement.json
     */
    private function loadPlacementFile():Void {
        var placementPath = 'placements/${parser.sceneId}_placement.json';
        
        try {
            var charSys = CharacterSystem.get();
            if (charSys != null && charSys.placementManager != null) {
                var loaded = charSys.placementManager.loadPlacements(placementPath);
                if (loaded) {
                    trace('[SceneRunner] Loaded placements for scene: ${parser.sceneId}');
                } else {
                    trace('[SceneRunner] No placements found for scene: ${parser.sceneId} (using defaults)');
                }
            }
        } catch (e:Dynamic) {
            trace('[SceneRunner] Could not load placements for ${parser.sceneId}: $e (using defaults)');
        }
    }

    public function update():Void {
        if (!active) return;
    }

    public function next():Void {
        if (!active) return;

        var node = parser.getNode(currentNode);
        runNode(node);
    }

    private function runNode(node:Dynamic):Void {
        switch (node.type) {
            case "dialogue":
                VNCommands.showDialogue(node, this);
            case "narration":
                VNCommands.showNarration(node, this);
            case "action":
                VNCommands.doAction(node, this);
            case "choice":
                VNCommands.showChoice(node, this);
            case "jump":
                currentNode = node.target;
                next();
            case "if":
                handleIf(node);
            case "game":
                VNCommands.startRhythm(node, this);
            case "end":
                VNCommands.endScene(node, this);
            default:
                throw "Unknown VN node type: " + node.type;
        }
    }

    private function handleIf(node:Dynamic):Void {
        var condition = VNConditions.evaluate(node.condition);

        currentNode = condition ? node.trueNode : node.falseNode;
        next();
    }

    public function goto(id:String):Void {
        currentNode = id;
        next();
    }
}
