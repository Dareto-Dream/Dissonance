package core.state;

typedef SavedCharacterVisual = {
	var id:String;
	var pose:String;
	var position:String;
	var screenX:Float;
	var screenY:Float;
	var isFlipped:Bool;
	var tint:Int;
}

typedef VisualSnapshot = {
	var musicTrack:String;
	var musicTime:Float;
	var musicVolume:Float;
	var backgroundPath:String;
	var characters:Array<SavedCharacterVisual>;
}

typedef SaveData = {
	var version:Int;
	var variables:Dynamic;
	var flags:Dynamic;
	var currentScene:String;
	var currentNode:String;
	var playtime:Float;
	var sceneHistory:Array<Dynamic>;
	var rhythmResults:Dynamic;
	var visualSnapshot:VisualSnapshot;
	var timestamp:String;
}

typedef SaveSlotInfo = {
	slot:Int,
	scene:String,
	node:String,
	playtimeSeconds:Float,
	timestamp:String
}
