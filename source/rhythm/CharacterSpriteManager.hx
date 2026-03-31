package rhythm;

import core.content.ContentRepository;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import openfl.Assets;
import rhythm.RhythmCharacterData;

/**
 * CharacterSpriteManager
 * ======================
 * Data-driven character sprite loading and animation management.
 *
 * CRITICAL RULES:
 * - All config from assets/data/characters/<id>/<id>.json
 * - anim (engine key) ≠ name (XML prefix)
 * - No hardcoded FPS, offsets, or prefixes
 * - Graceful degradation on missing assets
 */
class CharacterSpriteManager
{
    // ------------------------------------------------------------------
    // Configuration path pattern
    // ------------------------------------------------------------------

    /**
     * Character JSON path pattern.
     * {0} = character ID
     */
    public static var CHARACTER_DATA_PATH:String = "assets/data/characters/{0}/{0}.json";

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------

    // Character data cache (loaded JSONs)
    private var characterData:Map<String, RhythmCharacterData> = new Map();

    // Character sprites (loaded FlxSprites)
    private var sprites:Map<String, FlxSprite> = new Map();

    // Current animation offsets per character
    private var currentOffsets:Map<String, {x:Float, y:Float}> = new Map();

    // Base positions per character (from JSON)
    private var basePositions:Map<String, {x:Float, y:Float}> = new Map();

    // Runtime anchor positions after layout is applied
    private var anchorPositions:Map<String, {x:Float, y:Float}> = new Map();

    public function new() {}

    // ------------------------------------------------------------------
    // Character loading
    // ------------------------------------------------------------------

    /**
     * Load a character's rhythm sprite and configuration.
     *
     * @param characterID Character to load
     * @return FlxSprite instance (or null if failed)
     */
    public function loadCharacter(characterID:String):FlxSprite
    {
        // Already loaded?
        if (sprites.exists(characterID))
        {
            trace('[CharacterSpriteManager] Character already loaded: ${characterID}');
            return sprites.get(characterID);
        }

        // Load character data
        var data = loadCharacterData(characterID);
        if (data == null)
        {
            trace('[CharacterSpriteManager] ERROR: Failed to load data for: ${characterID}');
            return null;
        }

        // Resolve image paths
        var pngPath = 'assets/images/${data.image}.png';
        var xmlPath = 'assets/images/${data.image}.xml';

        trace('[CharacterSpriteManager] Loading character: ${characterID}');
        trace('[CharacterSpriteManager]   PNG: ${pngPath}');
        trace('[CharacterSpriteManager]   XML: ${xmlPath}');

        // Create sprite
        var sprite = new FlxSprite(0, 0);

        // Load atlas
        if (!tryLoadAtlas(sprite, pngPath, xmlPath, characterID))
        {
            trace('[CharacterSpriteManager] ERROR: Failed to load atlas for: ${characterID}');
            return null;
        }

        // Register animations from data
        registerAnimations(sprite, data, characterID);

        // Apply character configuration
        applyCharacterConfig(sprite, data, characterID);

        // Cache
        sprites.set(characterID, sprite);
        characterData.set(characterID, data);
        applyResolvedPosition(characterID);

        trace('[CharacterSpriteManager] Character loaded successfully: ${characterID}');
        return sprite;
    }

    // ------------------------------------------------------------------
    // Character data loading
    // ------------------------------------------------------------------

    /**
     * Load character JSON data.
     */
    private function loadCharacterData(characterID:String):RhythmCharacterData
    {
        // Already cached?
        if (characterData.exists(characterID))
        {
            return characterData.get(characterID);
        }

        var path = StringTools.replace(CHARACTER_DATA_PATH, "{0}", characterID);

        try
        {
            if (!ContentRepository.exists(path))
            {
                trace('[CharacterSpriteManager] ERROR: Character JSON not found: ${path}');
                return null;
            }

            var jsonText = ContentRepository.readText(path);
            var data:RhythmCharacterData = Json.parse(jsonText);

            trace('[CharacterSpriteManager] Character data loaded: ${characterID}');
            trace('[CharacterSpriteManager]   Animations: ${data.animations.length}');
            trace('[CharacterSpriteManager]   Image: ${data.image}');

            return data;
        }
        catch (e:Dynamic)
        {
            trace('[CharacterSpriteManager] ERROR parsing character JSON: ${e}');
            return null;
        }
    }

    /**
     * Load Sparrow atlas.
     */
    private function tryLoadAtlas(sprite:FlxSprite, pngPath:String, xmlPath:String, characterID:String):Bool
    {
        try
        {
            if (!Assets.exists(pngPath))
            {
                trace('[CharacterSpriteManager] ERROR: PNG not found: ${pngPath}');
                return false;
            }

            if (!Assets.exists(xmlPath))
            {
                trace('[CharacterSpriteManager] ERROR: XML not found: ${xmlPath}');
                return false;
            }

            var frames = FlxAtlasFrames.fromSparrow(pngPath, xmlPath);

            if (frames == null || frames.frames == null || frames.frames.length == 0)
            {
                trace('[CharacterSpriteManager] ERROR: Atlas loaded but contains no frames');
                return false;
            }

            sprite.frames = frames;
            trace('[CharacterSpriteManager] Atlas loaded: ${frames.frames.length} frames');

            return true;
        }
        catch (e:Dynamic)
        {
            trace('[CharacterSpriteManager] ERROR loading atlas: ${e}');
            return false;
        }
    }

    // ------------------------------------------------------------------
    // Animation registration (DATA-DRIVEN)
    // ------------------------------------------------------------------

    /**
     * Register animations from character data.
     *
     * CRITICAL: Uses anim (engine key) + name (XML prefix) split.
     */
    private function registerAnimations(sprite:FlxSprite, data:RhythmCharacterData, characterID:String):Void
    {
        for (animDef in data.animations)
        {
            try
            {
                if (animDef.indices != null && animDef.indices.length > 0)
                {
                    // Use specific frame indices
                    sprite.animation.addByIndices(
                        animDef.anim,       // Engine key
                        animDef.name,       // XML prefix
                        animDef.indices,    // Frame indices
                        "",                 // Postfix (empty)
                        animDef.fps,        // Framerate from data
                        animDef.loop        // Loop from data
                    );

                    trace('[CharacterSpriteManager]   Registered "${animDef.anim}" (indices) -> XML:"${animDef.name}" [${animDef.indices.length} frames]');
                }
                else
                {
                    // Use prefix-based auto-collection
                    sprite.animation.addByPrefix(
                        animDef.anim,       // Engine key
                        animDef.name,       // XML prefix
                        animDef.fps,        // Framerate from data
                        animDef.loop        // Loop from data
                    );

                    trace('[CharacterSpriteManager]   Registered "${animDef.anim}" (prefix) -> XML:"${animDef.name}"');
                }
            }
            catch (e:Dynamic)
            {
                trace('[CharacterSpriteManager]   WARNING: Failed to register "${animDef.anim}": ${e}');
            }
        }

        // Start with idle if available
        if (sprite.animation.exists("idle"))
        {
            sprite.animation.play("idle");
        }
    }

    /**
     * Apply character configuration (scale, flip, base position).
     */
    private function applyCharacterConfig(sprite:FlxSprite, data:RhythmCharacterData, characterID:String):Void
    {
        // Scale
        sprite.scale.set(data.scale, data.scale);
        sprite.updateHitbox();

        // Flip
        sprite.flipX = data.flip_x;

        // Store base position for later use
        var basePosition = {
            x: data.position != null && data.position.length > 0 ? data.position[0] : 0,
            y: data.position != null && data.position.length > 1 ? data.position[1] : 0
        };
        basePositions.set(characterID, basePosition);
        anchorPositions.set(characterID, basePosition);

        // Initialize offset tracking
        currentOffsets.set(characterID, {x: 0, y: 0});

        trace('[CharacterSpriteManager]   Scale: ${data.scale}');
        trace('[CharacterSpriteManager]   Flip X: ${data.flip_x}');
        trace('[CharacterSpriteManager]   Base position: [${basePosition.x}, ${basePosition.y}]');
    }

    // ------------------------------------------------------------------
    // Animation playback
    // ------------------------------------------------------------------

    /**
     * Play an animation on a character.
     * Automatically applies animation-specific offsets.
     *
     * @param characterID Character to animate
     * @param animKey Engine animation key (anim, not name)
     */
    public function play(characterID:String, animKey:String):Void
    {
        // Character loaded?
        if (!sprites.exists(characterID))
        {
            // Try to load on-demand
            var sprite = loadCharacter(characterID);
            if (sprite == null)
            {
                // Failed to load - silently skip
                return;
            }
        }

        var sprite = sprites.get(characterID);
        var resolvedAnim = animKey;

        // Animation exists?
        if (!sprite.animation.exists(resolvedAnim))
        {
            if (sprite.animation.exists("idle"))
            {
                resolvedAnim = "idle";
            }
            else
            {
                trace('[CharacterSpriteManager] WARNING: Animation "${animKey}" not found for character "${characterID}"');
                return;
            }
        }

        // Play animation
        sprite.animation.play(resolvedAnim, true);

        // Apply animation-specific offset
        applyAnimationOffset(characterID, resolvedAnim);
    }

    /**
     * Apply animation-specific offset from character data.
     */
    private function applyAnimationOffset(characterID:String, animKey:String):Void
    {
        if (!characterData.exists(characterID)) return;

        var data = characterData.get(characterID);
        var offsetX = 0.0;
        var offsetY = 0.0;

        // Find animation definition
        for (animDef in data.animations)
        {
            if (animDef.anim == animKey)
            {
                offsetX = animDef.offsets != null && animDef.offsets.length > 0 ? animDef.offsets[0] : 0;
                offsetY = animDef.offsets != null && animDef.offsets.length > 1 ? animDef.offsets[1] : 0;
                break;
            }
        }

        currentOffsets.set(characterID, {x: offsetX, y: offsetY});
        applyResolvedPosition(characterID);
    }

    // ------------------------------------------------------------------
    // Public accessors
    // ------------------------------------------------------------------

    /**
     * Get character sprite instance.
     */
    public function getSprite(characterID:String):FlxSprite
    {
        if (!sprites.exists(characterID))
        {
            return loadCharacter(characterID);
        }

        return sprites.get(characterID);
    }

    /**
     * Get character's base position from data.
     */
    public function getBasePosition(characterID:String):{x:Float, y:Float}
    {
        if (basePositions.exists(characterID))
        {
            return basePositions.get(characterID);
        }

        return {x: 0, y: 0};
    }

    /**
     * Set the runtime anchor position for a character.
     * Animation offsets are applied relative to this position.
     */
    public function setCharacterPosition(characterID:String, x:Float, y:Float):Void
    {
        anchorPositions.set(characterID, {x: x, y: y});
        applyResolvedPosition(characterID);
    }

    /**
     * Get character's current animation offset.
     */
    public function getCurrentOffset(characterID:String):{x:Float, y:Float}
    {
        if (currentOffsets.exists(characterID))
        {
            return currentOffsets.get(characterID);
        }

        return {x: 0, y: 0};
    }

    /**
     * Get character's sing duration from data.
     */
    public function getSingDuration(characterID:String):Float
    {
        if (characterData.exists(characterID))
        {
            return characterData.get(characterID).sing_duration;
        }

        return 4.0; // Default fallback
    }

    /**
     * Check if a character is loaded.
     */
    public function isLoaded(characterID:String):Bool
    {
        return sprites.exists(characterID) && characterData.exists(characterID);
    }

    private function applyResolvedPosition(characterID:String):Void
    {
        if (!sprites.exists(characterID))
        {
            return;
        }

        var sprite = sprites.get(characterID);
        var anchor = anchorPositions.exists(characterID)
            ? anchorPositions.get(characterID)
            : (basePositions.exists(characterID) ? basePositions.get(characterID) : {x: 0.0, y: 0.0});
        var offset = currentOffsets.exists(characterID)
            ? currentOffsets.get(characterID)
            : {x: 0.0, y: 0.0};

        sprite.setPosition(anchor.x + offset.x, anchor.y + offset.y);
    }
}
