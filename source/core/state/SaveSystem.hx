package core.state;

import core.audio.AudioSystem;
import core.rendering.BackgroundSystem;
import core.rendering.CharacterSystem;
import core.state.SaveTypes.SaveData;
import core.state.SaveTypes.SaveSlotInfo;
import core.state.SaveTypes.VisualSnapshot;
import flixel.FlxG;

/**
 * SaveSystem - Manages save/load operations using FlxG.save.
 *
 * Supports multiple save slots with metadata.
 * Cross-platform: desktop (file), HTML5 (localStorage), mobile (app storage).
 */
class SaveSystem {
    public static inline var MAX_SLOTS:Int = 5;
    private static inline var SAVE_KEY:String = "dissonance_save";

    /**
     * Save current game state to a slot.
     */
    public static function save(slot:Int):Bool {
        if (slot < 0 || slot >= MAX_SLOTS) return false;

        var state = GameState.get();
        var data:SaveData = cast state.serialize();

        // Add visual snapshot for restoration
        data.visualSnapshot = captureVisualSnapshot();
        data.timestamp = Date.now().toString();

        var saves = getSaveSlots();
        saves[slot] = data;
        writeSaveSlots(saves);

        return FlxG.save.flush();
    }

    /**
     * Load game state from a slot.
     * Returns the save data if successful, null otherwise.
     */
    public static function load(slot:Int):SaveData {
        if (slot < 0 || slot >= MAX_SLOTS) return null;

        var saves = getSaveSlots();
        if (saves[slot] == null) return null;

        var data:SaveData = cast saves[slot];

        // Restore GameState
        var state = GameState.get();
        state.deserialize(data);
        SaveRestoreContext.store(data.visualSnapshot);

        return data;
    }

    /**
     * Check if a slot has save data.
     */
    public static function hasData(slot:Int):Bool {
        if (slot < 0 || slot >= MAX_SLOTS) return false;
        var saves = getSaveSlots();
        return saves[slot] != null;
    }

    /**
     * Get metadata for a save slot (for display in UI).
     */
    public static function getSlotInfo(slot:Int):SaveSlotInfo {
        if (slot < 0 || slot >= MAX_SLOTS) return null;

        var saves = getSaveSlots();
        if (saves[slot] == null) return null;

        return buildSlotInfo(slot, cast saves[slot]);
    }

    /**
     * Delete a save slot.
     */
    public static function deleteSave(slot:Int):Bool {
        if (slot < 0 || slot >= MAX_SLOTS) return false;

        var saves = getSaveSlots();
        saves[slot] = null;
        writeSaveSlots(saves);
        return FlxG.save.flush();
    }

    /**
     * Format playtime as "HH:MM:SS".
     */
    public static function formatPlaytime(seconds:Float):String {
        var totalSec = Std.int(seconds);
        var h = Std.int(totalSec / 3600);
        var m = Std.int((totalSec % 3600) / 60);
        var s = totalSec % 60;
        return (h > 0 ? StringTools.lpad(Std.string(h), "0", 2) + ":" : "")
            + StringTools.lpad(Std.string(m), "0", 2) + ":"
            + StringTools.lpad(Std.string(s), "0", 2);
    }

    // ========================================================================
    // Internal helpers
    // ========================================================================

    public static function autoSave():Bool {
        FlxG.save.bind(SAVE_KEY);
        var data:SaveData = cast GameState.get().serialize();
        data.visualSnapshot = captureVisualSnapshot();
        data.timestamp = Date.now().toString();
        Reflect.setField(FlxG.save.data, "autosave", data);
        return FlxG.save.flush();
    }

    public static function loadAutoSave():SaveData {
        FlxG.save.bind(SAVE_KEY);
        var data:SaveData = cast Reflect.field(FlxG.save.data, "autosave");
        if (data == null) {
            return null;
        }

        GameState.get().deserialize(data);
        SaveRestoreContext.store(data.visualSnapshot);
        return data;
    }

    public static function hasAutoSave():Bool {
        FlxG.save.bind(SAVE_KEY);
        return Reflect.field(FlxG.save.data, "autosave") != null;
    }

    public static function getAutoSaveInfo():SaveSlotInfo {
        FlxG.save.bind(SAVE_KEY);
        var data:SaveData = cast Reflect.field(FlxG.save.data, "autosave");
        return data != null ? buildSlotInfo(-1, data) : null;
    }

    private static function getSaveSlots():Array<Dynamic> {
        FlxG.save.bind(SAVE_KEY);
        var raw:Dynamic = Reflect.field(FlxG.save.data, "slots");
        if (raw == null || !Std.isOfType(raw, Array)) {
            return [for (_ in 0...MAX_SLOTS) null];
        }
        var arr:Array<Dynamic> = cast raw;
        // Ensure correct length — pad or trim if save file was corrupted/version mismatch
        while (arr.length < MAX_SLOTS) arr.push(null);
        return arr;
    }

    private static function writeSaveSlots(slots:Array<Dynamic>):Void {
        FlxG.save.bind(SAVE_KEY);
        Reflect.setField(FlxG.save.data, "slots", slots);
    }

    private static function buildSlotInfo(slot:Int, data:SaveData):SaveSlotInfo {
        var scene:String = data.currentScene != null ? data.currentScene : "Unknown";
        var node:String = data.currentNode != null ? data.currentNode : "";
        var rawPlaytime:Dynamic = Reflect.field(data, "playtime");
        var playtime:Float = rawPlaytime != null ? rawPlaytime : 0;
        var timestamp:String = data.timestamp != null ? data.timestamp : "";

        var displayScene = scene;
        if (displayScene.indexOf("/") >= 0) {
            var parts = displayScene.split("/");
            displayScene = parts[parts.length - 1];
        }
        if (StringTools.endsWith(displayScene, ".json")) {
            displayScene = displayScene.substring(0, displayScene.length - 5);
        }

        return {
            slot: slot,
            scene: displayScene,
            node: node,
            playtimeSeconds: playtime,
            timestamp: timestamp
        };
    }

    /**
     * Capture current visual state for restoration on load.
     */
    private static function captureVisualSnapshot():VisualSnapshot {
        var snapshot:VisualSnapshot = {
            musicTrack: AudioSystem.getCurrentTrack(),
            musicTime: AudioSystem.getCurrentTime(),
            musicVolume: AudioSystem.getBaseVolume(),
            backgroundPath: BackgroundSystem.currentPath,
            characters: []
        };

        // Visible characters with poses and positions
        var charSys = CharacterSystem.get();
        if (charSys != null) {
            for (id in charSys.characters.keys()) {
                var renderer = charSys.characters.get(id);
                if (renderer != null && renderer.isShowing) {
                    snapshot.characters.push({
                        id: id,
                        pose: renderer.currentPose,
                        position: renderer.currentPosition,
                        screenX: renderer.screenX,
                        screenY: renderer.screenY,
                        isFlipped: renderer.isFlipped,
                        tint: renderer.currentTint
                    });
                }
            }
        }

        return snapshot;
    }
}
