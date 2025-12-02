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
