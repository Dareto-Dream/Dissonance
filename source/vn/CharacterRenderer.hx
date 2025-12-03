package vn;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import haxe.Json;
import openfl.Assets;

class CharacterRenderer
{
    private static var poseCache:Map<String, Dynamic> = new Map();
    private static var atlasCache:Map<String, FlxAtlasFrames> = new Map();

    public static function build(characterId:String, poseId:String):FlxSpriteGroup
    {
        var meta = loadPoses(characterId);
        var atlas = loadAtlas(characterId);

        var pose:Dynamic = meta.poses.get(poseId);
        if (pose == null)
        {
            trace("[CharacterRenderer] Pose not found: " + poseId + " for " + characterId);
            return new FlxSpriteGroup();
        }

        var group = new FlxSpriteGroup();

        var baseOffsetX = meta.config.base_offset.x;
        var baseOffsetY = meta.config.base_offset.y;
        var scale = meta.config.scale;

        var layers:Array<Dynamic> = cast pose.layers;
        for (layer in layers)
        {
            var spr = new FlxSprite();
            spr.frames = atlas;
            spr.animation.frameName = layer.frame;

            spr.x = baseOffsetX + layer.x;
            spr.y = baseOffsetY + layer.y;

            spr.scale.set(scale, scale);
            spr.updateHitbox();

            group.add(spr);
        }

        return group;
    }

    private static function loadPoses(characterId:String):Dynamic
    {
        if (poseCache.exists(characterId))
            return poseCache[characterId];

        var path = "assets/data/characters/" + characterId + "/poses.json";
        var raw = Assets.getText(path);

        var json:Dynamic = Json.parse(raw);

        // Convert poses into Map<String, Dynamic>
        var poseMap:Map<String, Dynamic> = new Map();
        for (key in Reflect.fields(json.poses))
        {
            poseMap.set(key, Reflect.field(json.poses, key));
        }
        json.poses = poseMap;

        poseCache[characterId] = json;
        return json;
    }

    private static function loadAtlas(characterId:String):FlxAtlasFrames
    {
        if (atlasCache.exists(characterId))
            return atlasCache[characterId];

        var base = "assets/images/characters/" + characterId + "/" + characterId;
        var frames = FlxAtlasFrames.fromSparrow(base + ".png", base + ".xml");

        atlasCache[characterId] = frames;
        return frames;
    }
}
