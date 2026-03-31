package editor;

interface EditorModule
{
	public function enter():Void;
	public function exit():Void;
	public function hasUnsavedChanges():Bool;
	public function save():Bool;
	public function load():Void;
	public function getHelpText():String;
}
