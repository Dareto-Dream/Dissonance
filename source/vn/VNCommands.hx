package vn;

import core.audio.AudioSystem;
import core.dialogue.ChoiceSystem;
import core.dialogue.DialogueSystem;
import core.effects.EffectSystem;
import core.rendering.BackgroundSystem;
import core.rendering.CharacterSystem;
import core.scene.SceneRunner;
import flixel.FlxG;
import util.SceneManager;

class VNCommands {
    public static function showDialogue(node:Dynamic, runner:SceneRunner):Void {
        var charSys = CharacterSystem.get();
        
        // If character is specified, emphasize them (DDLC style)
        if (node.character != null && charSys != null) {
            charSys.emphasizeCharacter(node.character);
            
            // If pose is also specified, change to that pose
            if (node.pose != null) {
                var r = charSys.characters.get(node.character);
                if (r != null) {
                    r.setPose(node.pose);
                }
            }
        }
        
        // Show the dialogue - pass the entire node for effect parsing
        DialogueSystem.show(
            node.speaker,
            node.text,
            () -> runner.goto(nextNode(node)),
            node
        );
    }

    public static function showNarration(node:Dynamic, runner:SceneRunner):Void {
        // For narration, deemphasize all characters
        var charSys = CharacterSystem.get();
        if (charSys != null) {
            charSys.deemphasizeAll();
        }
        
        // Show the narration - pass the entire node for effect parsing
        DialogueSystem.showNarration(
            node.text,
            () -> runner.goto(nextNode(node)),
            node
        );
    }

    public static function doAction(node:Dynamic, runner:SceneRunner):Void {
        switch (node.action) {
            case "set_bg":
                BackgroundSystem.set(node.background, node.transition, node.duration);
            case "show_character":
                trace('[VNCommands] SHOW_CHARACTER: ${node.character}, pose: ${node.pose}, position: ${node.position}');
                
                var charSys = CharacterSystem.get();
                if (charSys == null)
                {
                    trace("[VNCommands] ERROR: CharacterSystem is NULL!");
                }
                else
                {
                    var character:String = node.character;
                    var pose:String = node.pose != null ? node.pose : "default";
                    var position:String = node.position != null ? node.position : "center";
                    var transition:String = node.transition != null ? node.transition : "";
                    var duration:Float = node.duration != null ? node.duration : 0.4;
                    
                    charSys.show(character, pose, position, transition, duration, node.id);
                    trace('[VNCommands] ✓ Character shown');
                }

            case "hide_character":
                var charSys = CharacterSystem.get();
                if (charSys != null)
                {
                    charSys.hide(node.character, node.transition, node.duration);
                }

            case "shake_screen":
                EffectSystem.shake(node.intensity, node.duration);
                
            case "flash":
                EffectSystem.flash(node.color, node.duration);
                
            case "glitch":
                EffectSystem.glitch(node.intensity, node.duration);
                
            case "play_sound":
                AudioSystem.playSound(node.sound, node.volume);
                
            case "play_music":
                var transition = node.transition != null ? node.transition : null;
                var duration = node.duration != null ? node.duration : null;
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
                
            case "set_text_effect":
                DialogueSystem.setEffect(node);
                
            case "clear_text_effect":
                DialogueSystem.clearEffect();
                
            default:
                throw "Unknown VN action: " + node.action;
        }

        runner.goto(nextNode(node));
    }

    public static function showChoice(node:Dynamic, runner:SceneRunner):Void {
        ChoiceSystem.show(
            node.choices,
            (target:String) -> runner.goto(target)
        );
    }

    public static function startRhythm(node:Dynamic, runner:SceneRunner):Void {
        RhythmBridge.start(node.song, (result) -> {
        trace('[VNCommands] Rhythm game finished - Score: ${result.score}, Combo: ${result.combo}');
        runner.goto(nextNode(node));
        });
    }

    public static function endScene(node:Dynamic, runner:SceneRunner):Void {
        SceneManager.loadScene(node.next_scene);
    }

    private static function nextNode(node:Dynamic):String {
        return node.next != null ? node.next : node.id + "_next";
    }
}
