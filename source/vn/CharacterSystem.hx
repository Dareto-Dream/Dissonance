package vn;

import flixel.group.FlxGroup;
import haxe.Json;
import openfl.utils.Assets;

class CharacterSystem
{
	public static var instance:CharacterSystem;

	public static function get()
		return instance;

	public var characters:Map<String, CharacterRenderer> = [];
	public var group:FlxGroup;

	public static function init(group:FlxGroup, charDefs:Array<Dynamic>)
	{
		instance = new CharacterSystem(group, charDefs);
	}

	public function new(group:FlxGroup, charDefs:Array<Dynamic>)
	{
		this.group = group;

		var index = 0;
		for (c in charDefs)
		{
			index++;

			if (c == null)
			{
				trace("[CharacterSystem] ERROR: charDefs[" + index + "] is NULL.");
				continue;
			}

			if (!Reflect.hasField(c, "name") || c.name == null)
			{
				trace("[CharacterSystem] ERROR: charDefs[" + index + "] missing 'name' field. Entry=", c);
				continue;
			}

			var name:String = c.name;

			var renderer = new CharacterRenderer(name);
			characters.set(name, renderer);
			group.add(renderer);
		}

		var count = 0;
		for (_ in characters.keys())
			count++;

		trace("[CharacterSystem] Loaded " + count + " character definitions.");
	}

	public function show(name:String, pose:String, position:String, transition:String, duration:Float)
	{
		var r = characters.get(name);
		if (r == null)
		{
			trace("[CharacterSystem] ERROR: Attempted to SHOW unknown character '" + name + "'");
			return;
		}

		r.setPose(pose);
		r.setPositionKeyword(position);

		if (transition != null && transition != "")
			r.playTransition(transition, duration);
	}

	public function hide(name:String, transition:String, duration:Float)
	{
		var r = characters.get(name);
		if (r == null)
		{
			trace("[CharacterSystem] ERROR: Attempted to HIDE unknown character '" + name + "'");
			return;
		}

		r.hide();
	}
}
