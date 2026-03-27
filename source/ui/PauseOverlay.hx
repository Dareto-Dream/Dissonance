package ui;

import core.audio.AudioSystem;
import core.state.GameState;
import core.state.SaveSystem;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import states.TitleState;
import states.VNState;
import ui.OptionsOverlay;
import ui.SaveLoadOverlay;
import util.MobileSupport;

/**
 * PauseOverlay - In-game pause menu overlay.
 *
 * Renders on top of VNState. Pauses dialogue, music, and scene runner.
 * Options: RESUME, SAVE, LOAD, OPTIONS, RETURN TO TITLE
 */
class PauseOverlay extends FlxGroup {
    private static inline var PURPLE:Int = 0xFF8A2BE2;

    public var isPaused(default, null):Bool = false;

    private var backdrop:FlxSprite;
    private var title:FlxText;
    private var buttons:Array<PauseButton>;
    private var selectedIndex:Int = 0;
    private var saveLoadOverlay:SaveLoadOverlay;
    private var optionsOverlay:OptionsOverlay;
    private var vnState:VNState;

    public function new(vnState:VNState) {
        super();
        this.vnState = vnState;
        createUI();
    }

    private function createUI():Void {
        var sw = FlxG.width;
        var sh = FlxG.height;
        var mobile = MobileSupport.isMobile();

        // Dark backdrop
        backdrop = new FlxSprite(0, 0);
        backdrop.makeGraphic(sw, sh, FlxColor.fromRGBFloat(0, 0, 0, 0.7));
        backdrop.scrollFactor.set(0, 0);
        backdrop.visible = false;
        add(backdrop);

        // Title
        var titleSize = mobile ? 36 : 28;
        title = new FlxText(0, mobile ? 100 : 80, sw, "PAUSED");
        title.setFormat(null, titleSize, PURPLE, CENTER);
        title.scrollFactor.set(0, 0);
        title.visible = false;
        add(title);

        // Menu buttons
        buttons = [];
        var btnWidth = Std.int(Math.min(mobile ? 400 : 300, sw - 40));
        var btnHeight = mobile ? 60 : 44;
        var btnSpacing = mobile ? 70 : 56;
        var startY = mobile ? 220 : 180;
        var btnX = Std.int((sw - btnWidth) / 2);

        var items = ["RESUME", "SAVE", "LOAD", "OPTIONS", "RETURN TO TITLE"];
        for (i in 0...items.length) {
            var btn = new PauseButton(
                btnX, startY + i * btnSpacing,
                btnWidth, btnHeight, items[i], i,
                (idx) -> handleAction(idx)
            );
            btn.setVisible(false);
            buttons.push(btn);
            add(btn);
        }
    }

    public function toggle():Void {
        if (saveLoadOverlay != null && saveLoadOverlay.isOpen) return;

        if (isPaused) resume();
        else pause();
    }

    public function pause():Void {
        if (isPaused) return;
        isPaused = true;

        backdrop.visible = true;
        title.visible = true;
        for (btn in buttons) btn.setVisible(true);

        selectedIndex = 0;
        updateSelection();

        // Pause music
        if (FlxG.sound.music != null && FlxG.sound.music.playing) {
            FlxG.sound.music.pause();
        }
    }

    public function resume():Void {
        if (!isPaused) return;
        isPaused = false;

        backdrop.visible = false;
        title.visible = false;
        for (btn in buttons) btn.setVisible(false);

        // Remove save/load overlay if open
        if (saveLoadOverlay != null) {
            remove(saveLoadOverlay, true);
            saveLoadOverlay.destroy();
            saveLoadOverlay = null;
        }

        if (optionsOverlay != null) {
            remove(optionsOverlay, true);
            optionsOverlay.destroy();
            optionsOverlay = null;
        }

        // Resume music
        if (FlxG.sound.music != null && !FlxG.sound.music.playing) {
            FlxG.sound.music.resume();
        }
    }

    override public function update(elapsed:Float):Void {
        if (!isPaused) return;

        // Handle save/load overlay first
        if (saveLoadOverlay != null && saveLoadOverlay.isOpen) {
            saveLoadOverlay.update(elapsed);
            return;
        }

        if (optionsOverlay != null) {
            optionsOverlay.update(elapsed);
            return;
        }

        super.update(elapsed);

        #if FLX_KEYBOARD
        if (FlxG.keys.justPressed.ESCAPE) {
            resume();
            return;
        }

        if (FlxG.keys.justPressed.UP) {
            selectedIndex--;
            if (selectedIndex < 0) selectedIndex = buttons.length - 1;
            updateSelection();
        }

        if (FlxG.keys.justPressed.DOWN) {
            selectedIndex++;
            if (selectedIndex >= buttons.length) selectedIndex = 0;
            updateSelection();
        }

        if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) {
            handleAction(selectedIndex);
        }
        #end
    }

    private function updateSelection():Void {
        for (i in 0...buttons.length) {
            buttons[i].setSelected(i == selectedIndex);
        }
    }

    private function handleAction(index:Int):Void {
        switch (index) {
            case 0: // RESUME
                resume();
            case 1: // SAVE
                openSaveLoad(SAVE);
            case 2: // LOAD
                openSaveLoad(LOAD);
            case 3: // OPTIONS
                openOptions();
            case 4: // RETURN TO TITLE
                resume();
                AudioSystem.fadeOutMusic(0.3);
                FlxG.camera.fade(FlxColor.BLACK, 0.3, false, () -> {
                    FlxG.switchState(() -> new TitleState());
                });
        }
    }

    private function openSaveLoad(mode:SaveLoadMode):Void {
        if (saveLoadOverlay != null) {
            remove(saveLoadOverlay, true);
            saveLoadOverlay.destroy();
        }

        saveLoadOverlay = new SaveLoadOverlay(mode, () -> {
            // On close - remove overlay, return to pause menu
            if (saveLoadOverlay != null) {
                remove(saveLoadOverlay, true);
                saveLoadOverlay.destroy();
                saveLoadOverlay = null;
            }
        }, (data) -> {
            // On load - restore game
            if (data != null) {
                var state = GameState.get();
                var scenePath = state.currentScene;
                var nodeId = state.currentNode;

                resume();
                FlxG.camera.fade(FlxColor.BLACK, 0.3, false, () -> {
                    FlxG.switchState(() -> new VNState(scenePath, null, nodeId));
                });
            }
        });

        add(saveLoadOverlay);
    }

    private function openOptions():Void {
        if (optionsOverlay != null) {
            remove(optionsOverlay, true);
            optionsOverlay.destroy();
        }
        optionsOverlay = new OptionsOverlay(() -> {
            if (optionsOverlay != null) {
                remove(optionsOverlay, true);
                optionsOverlay.destroy();
                optionsOverlay = null;
            }
        });
        add(optionsOverlay);
    }
}

/**
 * Simple pause menu button.
 */
private class PauseButton extends FlxGroup {
    private var bg:FlxSprite;
    private var label:FlxText;
    private var index:Int;
    private var onClick:Int->Void;
    private var isSelected:Bool = false;

    public function new(x:Int, y:Int, w:Int, h:Int, text:String, index:Int, onClick:Int->Void) {
        super();
        this.index = index;
        this.onClick = onClick;

        var mobile = MobileSupport.isMobile();

        bg = new FlxSprite(x, y);
        bg.makeGraphic(w, h, FlxColor.fromRGB(18, 12, 32));
        bg.scrollFactor.set(0, 0);
        add(bg);

        label = new FlxText(x, y, w, text);
        label.setFormat(null, mobile ? 26 : 20, 0xFF8A2BE2, CENTER);
        label.scrollFactor.set(0, 0);
        label.y = y + (h - label.height) / 2;
        add(label);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (MobileSupport.pointerOverlaps(bg)) {
            bg.color = FlxColor.fromRGB(35, 25, 60);
            label.color = FlxColor.fromRGB(168, 73, 255);

            if (MobileSupport.pointerJustPressedOver(bg)) {
                if (onClick != null) onClick(index);
            }
        } else if (!isSelected) {
            bg.color = FlxColor.fromRGB(18, 12, 32);
            label.color = 0xFF8A2BE2;
        }
    }

    public function setSelected(selected:Bool):Void {
        isSelected = selected;
        if (selected) {
            bg.color = FlxColor.fromRGB(35, 25, 60);
            label.color = FlxColor.fromRGB(168, 73, 255);
        } else {
            bg.color = FlxColor.fromRGB(18, 12, 32);
            label.color = 0xFF8A2BE2;
        }
    }

    public function setVisible(v:Bool):Void {
        bg.visible = v;
        label.visible = v;
    }
}
