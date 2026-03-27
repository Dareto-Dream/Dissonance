package ui;

import core.state.GameState;
import core.state.SaveSystem;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import states.VNState;
import util.MobileSupport;

/**
 * SaveLoadOverlay - Overlay UI for save/load slot selection.
 *
 * Renders on top of the current state without destroying it.
 * Supports both SAVE and LOAD modes.
 */
class SaveLoadOverlay extends FlxGroup {
    private static inline var PURPLE:Int = 0xFF8A2BE2;
    private static inline var DARK_BG:Int = 0xCC0A0A14;

    private var mode:SaveLoadMode;
    private var onClose:Void->Void;
    private var onLoad:Dynamic->Void;
    private var backdrop:FlxSprite;
    private var title:FlxText;
    private var slots:Array<SlotButton>;
    private var statusText:FlxText;
    private var closeBtn:FlxSprite;
    private var closeBtnText:FlxText;

    /**
     * @param mode SAVE or LOAD
     * @param onClose callback when overlay is dismissed
     * @param onLoad callback when a save is loaded (receives save data)
     */
    public function new(mode:SaveLoadMode, onClose:Void->Void, ?onLoad:Dynamic->Void) {
        super();
        this.mode = mode;
        this.onClose = onClose;
        this.onLoad = onLoad;

        createUI();
    }

    private function createUI():Void {
        var sw = FlxG.width;
        var sh = FlxG.height;
        var mobile = MobileSupport.isMobile();

        // Dark backdrop
        backdrop = new FlxSprite(0, 0);
        backdrop.makeGraphic(sw, sh, DARK_BG);
        backdrop.scrollFactor.set(0, 0);
        add(backdrop);

        // Title
        var titleSize = mobile ? 32 : 24;
        title = new FlxText(0, mobile ? 40 : 30, sw, mode == SAVE ? "SAVE GAME" : "LOAD GAME");
        title.setFormat(null, titleSize, PURPLE, CENTER);
        title.scrollFactor.set(0, 0);
        add(title);

        // Slot buttons
        slots = [];
        var slotWidth = mobile ? 580 : 440;
        var slotHeight = mobile ? 80 : 60;
        var slotSpacing = mobile ? 90 : 70;
        var startY = mobile ? 130 : 110;
        var slotX = Std.int((sw - slotWidth) / 2);

        for (i in 0...SaveSystem.MAX_SLOTS) {
            var slot = new SlotButton(slotX, startY + i * slotSpacing, slotWidth, slotHeight, i, mode, (slotIdx) -> {
                handleSlotAction(slotIdx);
            });
            slots.push(slot);
            add(slot);
        }

        // Status text
        statusText = new FlxText(0, startY + SaveSystem.MAX_SLOTS * slotSpacing + 10, sw, "");
        statusText.setFormat(null, mobile ? 20 : 14, FlxColor.fromRGB(220, 210, 255), CENTER);
        statusText.scrollFactor.set(0, 0);
        statusText.alpha = 0;
        add(statusText);

        // Close button
        var closeBtnWidth = mobile ? 200 : 150;
        var closeBtnHeight = mobile ? 50 : 36;
        var closeBtnY = sh - (mobile ? 80 : 60);

        closeBtn = new FlxSprite(Std.int((sw - closeBtnWidth) / 2), closeBtnY);
        closeBtn.makeGraphic(closeBtnWidth, closeBtnHeight, FlxColor.fromRGB(30, 20, 50));
        closeBtn.scrollFactor.set(0, 0);
        add(closeBtn);

        closeBtnText = new FlxText(closeBtn.x, closeBtn.y, closeBtnWidth, "BACK");
        closeBtnText.setFormat(null, mobile ? 24 : 18, PURPLE, CENTER);
        closeBtnText.scrollFactor.set(0, 0);
        closeBtnText.y = closeBtn.y + (closeBtnHeight - closeBtnText.height) / 2;
        add(closeBtnText);

        active = true;
    }

    override public function update(elapsed:Float):Void {
        if (!active) return;
        super.update(elapsed);

        // ESC to close
        #if FLX_KEYBOARD
        if (FlxG.keys.justPressed.ESCAPE) {
            close();
            return;
        }
        #end

        // Close button click
        if (MobileSupport.pointerJustPressedOver(closeBtn)) {
            close();
        }
    }

    private function handleSlotAction(slotIdx:Int):Void {
        if (mode == SAVE) {
            var success = SaveSystem.save(slotIdx);
            if (success) {
                showStatus('Game saved to Slot ${slotIdx + 1}');
                refreshSlots();
            } else {
                showStatus("Save failed!");
            }
        } else {
            // LOAD mode
            if (!SaveSystem.hasData(slotIdx)) {
                showStatus("Slot is empty.");
                return;
            }
            var data = SaveSystem.load(slotIdx);
            if (data != null && onLoad != null) {
                onLoad(data);
            } else {
                showStatus("Load failed!");
            }
        }
    }

    private function refreshSlots():Void {
        for (slot in slots) {
            slot.refreshInfo();
        }
    }

    private function showStatus(message:String):Void {
        statusText.text = message;
        FlxTween.cancelTweensOf(statusText);
        statusText.alpha = 1;
        FlxTween.tween(statusText, {alpha: 0}, 1.5, {
            startDelay: 1.0,
            ease: FlxEase.quadOut
        });
    }

    public function close():Void {
        active = false;
        if (onClose != null) onClose();
    }

    override public function destroy():Void {
        slots = null;
        super.destroy();
    }
}

enum SaveLoadMode {
    SAVE;
    LOAD;
}

/**
 * Individual save slot button.
 */
private class SlotButton extends FlxGroup {
    private var bg:FlxSprite;
    private var label:FlxText;
    private var info:FlxText;
    private var slotIdx:Int;
    private var mode:SaveLoadMode;
    private var onClick:Int->Void;
    private var slotWidth:Int;

    public function new(x:Int, y:Int, w:Int, h:Int, slot:Int, mode:SaveLoadMode, onClick:Int->Void) {
        super();
        this.slotIdx = slot;
        this.mode = mode;
        this.onClick = onClick;
        this.slotWidth = w;

        var mobile = MobileSupport.isMobile();

        bg = new FlxSprite(x, y);
        bg.makeGraphic(w, h, FlxColor.fromRGB(20, 14, 36));
        bg.scrollFactor.set(0, 0);
        add(bg);

        label = new FlxText(x + 12, y + 4, w - 24, 'Slot ${slot + 1}');
        label.setFormat(null, mobile ? 22 : 16, 0xFF8A2BE2, LEFT);
        label.scrollFactor.set(0, 0);
        add(label);

        info = new FlxText(x + 12, y + (mobile ? 38 : 26), w - 24, "");
        info.setFormat(null, mobile ? 18 : 12, FlxColor.fromRGB(180, 170, 200), LEFT);
        info.scrollFactor.set(0, 0);
        add(info);

        refreshInfo();
    }

    public function refreshInfo():Void {
        var slotInfo = SaveSystem.getSlotInfo(slotIdx);
        if (slotInfo != null) {
            var playtime = SaveSystem.formatPlaytime(slotInfo.playtimeSeconds);
            info.text = '${slotInfo.scene} | ${playtime} | ${slotInfo.timestamp}';
        } else {
            info.text = mode == LOAD ? "— Empty —" : "— Empty Slot —";
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (MobileSupport.pointerOverlaps(bg)) {
            bg.color = FlxColor.fromRGB(35, 25, 60);
            if (MobileSupport.pointerJustPressedOver(bg)) {
                if (onClick != null) onClick(slotIdx);
            }
        } else {
            bg.color = FlxColor.fromRGB(20, 14, 36);
        }
    }
}
