package core.scene;

import core.content.ContentRepository;
import haxe.Json;

class SceneParser {
    public var sceneId:String;
    public var startNode:String;
    public var nodes:Map<String, Dynamic>;
    public var nodeOrder:Array<String>;

    public function new(path:String) {
        // path example: "scenes/act1/act1_scene1.json"
        var raw:String = ContentRepository.readText("assets/data/" + path);

        var data:Dynamic = Json.parse(raw);

        sceneId = data.scene_id;
        startNode = data.start != null ? data.start : "n1";
        nodes = new Map<String, Dynamic>();
        nodeOrder = [];

        
        var arr:Array<Dynamic> = cast data.nodes;
        for (node in arr) {
            if (node.id == null) {
                throw "SceneParser Error: Node missing 'id' in " + sceneId;
            }

            nodes.set(node.id, node);
            nodeOrder.push(node.id);
        }
    }

    public function getNode(id:String):Dynamic {
        if (!nodes.exists(id)) {
            throw "SceneParser Error: Node '" + id + "' not found in " + sceneId;
        }
        return nodes.get(id);
    }

    public function hasNode(id:String):Bool {
        return nodes.exists(id);
    }
}
