package vn;

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
        
        // Show the dialogue
        DialogueSystem.show(
            node.speaker,
            node.text,
            () -> runner.goto(nextNode(node))
        );
    }

    public static function showNarration(node:Dynamic, runner:SceneRunner):Void {
        // For narration, deemphasize all characters
        var charSys = CharacterSystem.get();
        if (charSys != null) {
            charSys.deemphasizeAll();
        }
        
        DialogueSystem.showNarration(
            node.text,
            () -> runner.goto(nextNode(node))
        );
    }

    public static function doAction(node:Dynamic, runner:SceneRunner):Void {
        switch (node.action) {
            case "set_bg":
                BackgroundSystem.set(node.background, node.transition, node.duration);
            case "show_character":
				trace('SHOW_CHARACTER action:', node.character, node.pose, node.position);
				CharacterSystem.get().show(node.character, node.pose, node.position, node.transition, node.duration);

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
                AudioSystem.playMusic(node.track, node.volume);
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

    private static function nextNode(node:Dynamic):String {
        return node.next != null ? node.next : node.id + "_next";
    }
}
