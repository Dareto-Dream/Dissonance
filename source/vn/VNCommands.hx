package vn;

import core.audio.AudioSystem;
import core.dialogue.ChoiceSystem;
import core.dialogue.DialogueSystem;
import core.effects.EffectSystem;
import core.rendering.BackgroundSystem;
import core.rendering.CharacterSystem;
import core.scene.SceneRunner;
import flixel.FlxState;
import flixel.util.FlxColor;
import util.SceneManager;

class VNCommands {
    // ------------------------------------------------------------------
    // VN State reference (for rhythm game transitions)
    // ------------------------------------------------------------------

    private static var vnState:FlxState;

    public static function setVNState(state:FlxState):Void {
        vnState = state;
    }

    // ------------------------------------------------------------------
    // Dialogue / narration
    // ------------------------------------------------------------------

    public static function showDialogue(node:Dynamic, runner:SceneRunner):Void {
        var charSys = CharacterSystem.get();

        if (node.character != null && charSys != null) {
            charSys.emphasizeCharacter(node.character);

            if (node.pose != null) {
                var r = charSys.characters.get(node.character);
                if (r != null) r.setPose(node.pose);
            }
        }

        DialogueSystem.show(
            node.speaker,
            node.text,
            () -> runner.goto(nextNode(node)),
            node
        );
    }

    public static function showNarration(node:Dynamic, runner:SceneRunner):Void {
        var charSys = CharacterSystem.get();
        if (charSys != null) charSys.deemphasizeAll();

        DialogueSystem.showNarration(
            node.text,
            () -> runner.goto(nextNode(node)),
            node
        );
    }

    // ------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------

    public static function doAction(node:Dynamic, runner:SceneRunner):Void {
        switch (node.action) {

            // ── Background ──────────────────────────────────────────────
            case "set_bg":
                BackgroundSystem.set(node.background, node.transition, node.duration);

            // ── Character visibility ─────────────────────────────────────
            case "show_character":
                var charSys = CharacterSystem.get();
                if (charSys == null) {
                    trace("[VNCommands] ERROR: CharacterSystem is NULL!");
                } else {
                    var character:String = node.character;
                    var pose:String      = node.pose       != null ? node.pose       : "default";
                    var transition:String = node.transition != null ? node.transition : "";
                    var duration:Float   = node.duration   != null ? node.duration   : 0.4;
                    charSys.show(character, pose, transition, duration, node.id);
                }

            case "hide_character":
                var charSys = CharacterSystem.get();
                if (charSys != null) {
                    var transition:String = node.transition != null ? node.transition : "";
                    var duration:Float    = node.duration   != null ? node.duration   : 0.4;
                    charSys.hide(node.character, transition, duration);
                }

            // ── Character movement ───────────────────────────────────────
            case "move_character":
                // Smoothly slide a character to a new slot (or absolute coords).
                // JSON example:
                //   {"action":"move_character","character":"tiffany","slot":"left","duration":0.5}
                //   {"action":"move_character","character":"tiffany","x":400,"y":0,"duration":0.5}
                var charSys = CharacterSystem.get();
                if (charSys != null) {
                    var character:String = node.character;
                    var duration:Float   = node.duration != null ? node.duration : 0.45;
                    if (node.x != null && node.y != null) {
                        charSys.moveCharacterAbsolute(character, node.x, node.y, duration);
                    } else if (node.slot != null) {
                        charSys.moveCharacter(character, node.slot, duration);
                    }
                }

            // ── Character flip ───────────────────────────────────────────
            case "flip_character":
                // JSON: {"action":"flip_character","character":"tiffany","flipped":true}
                var charSys = CharacterSystem.get();
                if (charSys != null) {
                    var flipped:Bool = node.flipped != null ? (node.flipped == true) : true;
                    charSys.flipCharacter(node.character, flipped);
                }

            // ── Character bounce ─────────────────────────────────────────
            case "bounce_character":
                // JSON: {"action":"bounce_character","character":"tiffany","height":40,"duration":0.5}
                var charSys = CharacterSystem.get();
                if (charSys != null) {
                    var height:Float   = node.height   != null ? node.height   : 30.0;
                    var duration:Float = node.duration != null ? node.duration : 0.5;
                    charSys.bounceCharacter(node.character, height, duration);
                }

            // ── Character shake ──────────────────────────────────────────
            case "shake_character":
                // JSON: {"action":"shake_character","character":"tiffany","intensity":15,"duration":0.5}
                var charSys = CharacterSystem.get();
                if (charSys != null) {
                    var intensity:Float = node.intensity != null ? node.intensity : 15.0;
                    var duration:Float  = node.duration  != null ? node.duration  : 0.5;
                    charSys.shakeCharacter(node.character, intensity, duration);
                }

            // ── Character tint ───────────────────────────────────────────
            case "set_tint":
                // JSON: {"action":"set_tint","character":"tiffany","color":"#888888"}
                // Omit "character" to tint all characters (e.g. grayscale flashback).
                var charSys = CharacterSystem.get();
                if (charSys != null) {
                    var color:Int = parseColor(node.color, FlxColor.WHITE);
                    if (node.character != null) charSys.setCharacterTint(node.character, color);
                    else                        charSys.setAllTint(color);
                }

            case "clear_tint":
                // JSON: {"action":"clear_tint","character":"tiffany"}  (or omit character for all)
                var charSys = CharacterSystem.get();
                if (charSys != null) {
                    if (node.character != null) charSys.clearCharacterTint(node.character);
                    else                        charSys.clearAllTints();
                }

            // ── Screen effects ───────────────────────────────────────────
            case "shake_screen":
                EffectSystem.shake(node.intensity, node.duration);

            case "flash":
                EffectSystem.flash(node.color, node.duration);

            case "glitch":
                EffectSystem.glitch(node.intensity, node.duration);

            // ── Audio ────────────────────────────────────────────────────
            case "play_sound":
                AudioSystem.playSound(node.sound, node.volume);

            case "play_music":
                var transition = node.transition != null ? node.transition : null;
                var duration   = node.duration   != null ? node.duration   : null;
                AudioSystem.playMusic(node.track, node.volume, transition, duration);

            case "stop_music":
                AudioSystem.stopMusic();

            case "fade_out_music":
                var duration = node.duration != null ? node.duration : 1.0;
                AudioSystem.fadeOutMusic(duration);

            case "set_default_bgm":
                var volume = node.volume != null ? node.volume : 1.0;
                AudioSystem.setDefaultBGM(node.track, volume);

            case "play_default_bgm":
                var volume = node.volume != null ? node.volume : 1.0;
                AudioSystem.playDefaultBGM(volume);

            // ── Text effects ─────────────────────────────────────────────
            case "set_text_effect":
                DialogueSystem.setEffect(node);

            case "clear_text_effect":
                DialogueSystem.clearEffect();

            default:
                throw "Unknown VN action: " + node.action;
        }

        runner.goto(nextNode(node));
    }

    // ------------------------------------------------------------------
    // Choices
    // ------------------------------------------------------------------

    public static function showChoice(node:Dynamic, runner:SceneRunner):Void {
        ChoiceSystem.show(
            node.choices,
            (target:String) -> runner.goto(target)
        );
    }

    // ------------------------------------------------------------------
    // Rhythm game
    // ------------------------------------------------------------------

    public static function startRhythm(node:Dynamic, runner:SceneRunner):Void {
        if (vnState == null)
            throw '[VNCommands] ERROR: vnState not set. Call VNCommands.setVNState(this) in VN state.create()';

        var resumeNode = nextNode(node);
        var scenePath  = runner.getScenePath();

        VNReturnContext.store(scenePath, resumeNode);

        RhythmBridge.start(node.song, vnState, (result) -> {
            trace('[VNCommands] Rhythm result: Score=${result.score}, Combo=${result.combo}, Completed=${result.completed}');
        });
    }

    // ------------------------------------------------------------------
    // Scene end
    // ------------------------------------------------------------------

    public static function endScene(node:Dynamic, runner:SceneRunner):Void {
        SceneManager.loadScene(node.next_scene);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private static function nextNode(node:Dynamic):String {
        return node.next != null ? node.next : node.id + "_next";
    }

    /**
     * Parse a color value from a node field.
     * Accepts "#RRGGBB", "#AARRGGBB", or integer strings.
     * Returns `fallback` if parsing fails.
     */
    private static function parseColor(value:Dynamic, fallback:Int):Int {
        if (value == null) return fallback;
        var s = Std.string(value);
        if (s.indexOf("#") == 0) return FlxColor.fromString(s);
        var i = Std.parseInt(s);
        return i != null ? i : fallback;
    }
}
