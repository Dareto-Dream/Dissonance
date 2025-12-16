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
                trace('SHOW_CHARACTER action:', node.character, node.pose, node.position, 'node_id:', node.id);
                // Pass node.id for placement lookup
                CharacterSystem.get().show(
                    node.character, 
                    node.pose, 
                    node.position, 
                    node.transition, 
                    node.duration,
                    node.id
                );

            case "hide_character":
                CharacterSystem.get().hide(node.character, node.transition, node.duration);

            case "shake_screen":
                EffectSystem.shake(node.intensity, node.duration);
            case "flash":
                EffectSystem.flash(node.color, node.duration);
            case "glitch":
                EffectSystem.glitch(node.intensity, node.duration);
            case "play_sound":
                AudioSystem.playSound(node.sound, node.volume);
            case "play_music":
                // Legacy action node support - uses default transition
                var transition = node.transition != null ? node.transition : "fade";
                var duration = node.duration != null ? node.duration : 2.0;
                AudioSystem.playMusic(node.track, node.volume, transition, duration);
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
        RhythmBridge.start(node.song, () -> {
            runner.goto(nextNode(node));
        });
    }

    public static function endScene(node:Dynamic, runner:SceneRunner):Void {
        SceneManager.loadScene(node.next_scene);
    }
    
    /**
     * Handle the new "music" node type for background music transitions
     */
    public static function playMusic(node:Dynamic, runner:SceneRunner):Void {
        var track = node.track != null ? node.track : "";
        var volume = node.volume != null ? node.volume : 1.0;
        var transition = node.transition != null ? node.transition : "fade";
        var duration = node.duration != null ? node.duration : 2.0;
        
        trace("[VNCommands] Music node: track=" + track + ", transition=" + transition);
        
        AudioSystem.playMusic(track, volume, transition, duration);
        
        // Continue to next node immediately (transition happens in background)
        runner.goto(nextNode(node));
    }

    private static function nextNode(node:Dynamic):String {
        return node.next != null ? node.next : node.id + "_next";
    }
}
