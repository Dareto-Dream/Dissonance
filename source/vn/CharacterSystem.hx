package vn;

import Lambda;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup;
import haxe.ds.StringMap;
import vn.VNConfig.CharacterDef;
import vn.VNConfig.CharacterDefMap;


class CharacterSystem
{
	private static var instance:CharacterSystem;

	public var renderers:StringMap<CharacterRenderer>;

	public function new()
	{
		renderers = new StringMap<CharacterRenderer>();
	}

	public static function get():CharacterSystem
	{
		if (instance == null)
			instance = new CharacterSystem();
		return instance;
	}

	// -------------------------------------------------
	//  INITIALIZE FROM DATA
	// -------------------------------------------------
	/**
	 * Build character sprites and renderers from data and attach them to the given group.
	 *
	 * charGroup: the FlxGroup that sits in VNState.charGroup
	 * defs:      character definition data from VNConfig.loadCharacterDefs()
	 */
	public static function init(charGroup:FlxGroup, defs:CharacterDefMap):Void
	{
		var cs = get();

		for (id in defs.keys())
		{
			var def = defs.get(id);
			if (def == null)
				continue;

			// Create sprite and load atlas frames
			var spr = new FlxSprite();
			var frames = FlxAtlasFrames.fromSparrow(def.png, def.xml);
			spr.frames = frames;
			spr.scrollFactor.set(0, 0);
			spr.visible = false;
			spr.antialiasing = true;

			// Attach to the character layer
			charGroup.add(spr);

			// Wrap in renderer
			var renderer = new CharacterRenderer(spr);

			// Apply default pose if present
			if (def.defaultPose != null && def.defaultPose != "")
			{
				renderer.setPose(def.defaultPose);
			}

			cs.addRenderer(def.id, renderer);
		}

		trace("[CharacterSystem] Initialized " + Lambda.count(defs) + " characters.");
	}

	// -------------------------------------------------
	//  REGISTRY
	// -------------------------------------------------
	public function addRenderer(character:String, renderer:CharacterRenderer):Void
	{
		renderers.set(character, renderer);
	}

	public function getRenderer(character:String):CharacterRenderer
	{
		return renderers.get(character);
	}

	// -------------------------------------------------
	//  HIGH LEVEL CONTROL
	// -------------------------------------------------
	// instance method, used via CharacterSystem.get()
	public function show(character:String, pose:String, position:Dynamic, transition:String, duration:Float):Void
	{
		var r = getRenderer(character);
		if (r == null)
			return;
		if (pose != null && pose != "")
			r.setPose(pose);

		r.resolvePosition(position);
		r.playTransition(transition, duration);
		r.show();
	}

	public function hide(character:String, ?transition:String, ?duration:Float = 0):Void
	{
		var r = getRenderer(character);
		if (r == null)
			return;

		r.hide(transition, duration);
	}
}
