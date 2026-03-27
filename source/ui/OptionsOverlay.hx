package ui;

import core.audio.AudioSystem;
import core.dialogue.DialogueSystem;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import util.MobileSupport;
import vn.Constants;

/**
 * OptionsOverlay - In-game options menu.
 *
 * Settings: text speed, music volume, SFX volume, auto-advance, fullscreen.
 * Persists via FlxG.save.
 */
class OptionsOverlay extends FlxGroup {
    private static inline var PURPLE:Int = 0xFF8A2BE2;
    private static inline var SAVE_KEY:String = "dissonance_options";

    public var isOpen(default, null):Bool = false;

    private var backdrop:FlxSprite;
    private var title:FlxText;
    private var sliders:Array<OptionSlider>;
    private var closeBtn:FlxSprite;
    private var closeBtnText:FlxText;
    private var onClose:Void->Void;

    // Saved option values
    public static var textSpeed:Float = 30.0;
    public static var musicVolume:Float = 0.7;
    public static var sfxVolume:Float = 0.8;
    public static var autoAdvanceSpeed:Float = 2.0;
    public static var autoAdvanceEnabled:Bool = false;

    public function new(onClose:Void->Void) {
        super();
        this.onClose = onClose;
        loadOptions();
        createUI();
    }

    private function createUI():Void {
        var sw = FlxG.width;
        var sh = FlxG.height;
        var mobile = MobileSupport.isMobile();

        backdrop = new FlxSprite(0, 0);
        backdrop.makeGraphic(sw, sh, FlxColor.fromRGBFloat(0, 0, 0, 0.8));
        backdrop.scrollFactor.set(0, 0);
        add(backdrop);

        var titleSize = mobile ? 32 : 24;
        title = new FlxText(0, mobile ? 40 : 30, sw, "OPTIONS");
        title.setFormat(null, titleSize, PURPLE, CENTER);
        title.scrollFactor.set(0, 0);
        add(title);

        sliders = [];
        var sliderWidth = mobile ? 500 : 380;
        var sliderHeight = mobile ? 50 : 36;
        var sliderSpacing = mobile ? 70 : 55;
        var startY = mobile ? 130 : 110;
        var sliderX = Std.int((sw - sliderWidth) / 2);

        // Text Speed
        addSlider(sliderX, startY, sliderWidth, sliderHeight, "Text Speed", textSpeed, 10, 80, (v) -> {
            textSpeed = v;
            saveOptions();
        });

        // Music Volume
        addSlider(sliderX, startY + sliderSpacing, sliderWidth, sliderHeight, "Music Volume", musicVolume, 0, 1, (v) -> {
            musicVolume = v;
            if (FlxG.sound.music != null) FlxG.sound.music.volume = v;
            saveOptions();
        });

        // SFX Volume
        addSlider(sliderX, startY + sliderSpacing * 2, sliderWidth, sliderHeight, "SFX Volume", sfxVolume, 0, 1, (v) -> {
            sfxVolume = v;
            saveOptions();
        });

        // Auto-advance Speed
        addSlider(sliderX, startY + sliderSpacing * 3, sliderWidth, sliderHeight, "Auto-Advance Delay", autoAdvanceSpeed, 0.5, 5, (v) -> {
            autoAdvanceSpeed = v;
            saveOptions();
        });

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

        isOpen = true;
    }

    private function addSlider(x:Int, y:Int, w:Int, h:Int, label:String, value:Float,
                               min:Float, max:Float, onChange:Float->Void):Void {
        var slider = new OptionSlider(x, y, w, h, label, value, min, max, onChange);
        sliders.push(slider);
        add(slider);
    }

    override public function update(elapsed:Float):Void {
        if (!isOpen) return;
        super.update(elapsed);

        #if FLX_KEYBOARD
        if (FlxG.keys.justPressed.ESCAPE) {
            close();
            return;
        }
        #end

        if (MobileSupport.pointerJustPressedOver(closeBtn)) {
            close();
        }
    }

    public function close():Void {
        isOpen = false;
        if (onClose != null) onClose();
    }

    // ========================================================================
    // Persistence
    // ========================================================================

    public static function loadOptions():Void {
        FlxG.save.bind(SAVE_KEY);
        var data:Dynamic = Reflect.field(FlxG.save.data, "options");
        if (data == null) return;

        if (data.textSpeed != null) textSpeed = data.textSpeed;
        if (data.musicVolume != null) musicVolume = data.musicVolume;
        if (data.sfxVolume != null) sfxVolume = data.sfxVolume;
        if (data.autoAdvanceSpeed != null) autoAdvanceSpeed = data.autoAdvanceSpeed;
        if (data.autoAdvanceEnabled != null) autoAdvanceEnabled = data.autoAdvanceEnabled;
    }

    private static function saveOptions():Void {
        FlxG.save.bind(SAVE_KEY);
        Reflect.setField(FlxG.save.data, "options", {
            textSpeed: textSpeed,
            musicVolume: musicVolume,
            sfxVolume: sfxVolume,
            autoAdvanceSpeed: autoAdvanceSpeed,
            autoAdvanceEnabled: autoAdvanceEnabled
        });
        FlxG.save.flush();
    }
}

/**
 * Simple horizontal slider with label and value display.
 */
private class OptionSlider extends FlxGroup {
    private var bg:FlxSprite;
    private var fill:FlxSprite;
    private var label:FlxText;
    private var valueText:FlxText;
    private var min:Float;
    private var max:Float;
    private var value:Float;
    private var onChange:Float->Void;
    private var sliderX:Float;
    private var sliderY:Float;
    private var sliderWidth:Float;
    private var sliderHeight:Float;
    private var barX:Float;
    private var barWidth:Float;
    private var barY:Float;
    private var barHeight:Float = 8;
    private var isDragging:Bool = false;

    public function new(x:Int, y:Int, w:Int, h:Int, labelText:String, value:Float,
                        min:Float, max:Float, onChange:Float->Void) {
        super();
        this.sliderX = x;
        this.sliderY = y;
        this.sliderWidth = w;
        this.sliderHeight = h;
        this.min = min;
        this.max = max;
        this.value = value;
        this.onChange = onChange;

        var mobile = MobileSupport.isMobile();
        var labelWidth = mobile ? 200 : 150;
        barX = x + labelWidth;
        barWidth = w - labelWidth - (mobile ? 80 : 60);
        barY = y + (h - barHeight) / 2;

        // Label
        label = new FlxText(x, y, labelWidth, labelText);
        label.setFormat(null, mobile ? 20 : 14, 0xFF8A2BE2, LEFT);
        label.scrollFactor.set(0, 0);
        label.y = y + (h - label.height) / 2;
        add(label);

        // Bar background
        bg = new FlxSprite(barX, barY);
        bg.makeGraphic(Std.int(barWidth), Std.int(barHeight), FlxColor.fromRGB(30, 20, 50));
        bg.scrollFactor.set(0, 0);
        add(bg);

        // Bar fill
        fill = new FlxSprite(barX, barY);
        var fillW = Std.int(barWidth * getNormalized());
        if (fillW < 1) fillW = 1;
        fill.makeGraphic(fillW, Std.int(barHeight), 0xFF8A2BE2);
        fill.scrollFactor.set(0, 0);
        add(fill);

        // Value display
        valueText = new FlxText(barX + barWidth + 8, y, mobile ? 70 : 50, formatValue());
        valueText.setFormat(null, mobile ? 18 : 12, FlxColor.fromRGB(200, 190, 220), LEFT);
        valueText.scrollFactor.set(0, 0);
        valueText.y = y + (h - valueText.height) / 2;
        add(valueText);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        // Handle drag on the bar
        if (MobileSupport.pointerPressedOver(bg) || isDragging) {
            isDragging = true;

            var pointerX:Float = 0;
            #if FLX_MOUSE
            pointerX = FlxG.mouse.screenX;
            #end
            #if FLX_TOUCH
            for (touch in FlxG.touches.list) {
                if (touch != null && touch.pressed) {
                    pointerX = touch.screenX;
                    break;
                }
            }
            #end

            var normalized = (pointerX - barX) / barWidth;
            if (normalized < 0) normalized = 0;
            if (normalized > 1) normalized = 1;

            value = min + normalized * (max - min);
            updateFill();

            if (onChange != null) onChange(value);
        }

        // Release drag
        var anyPressed = false;
        #if FLX_MOUSE
        anyPressed = FlxG.mouse.pressed;
        #end
        #if FLX_TOUCH
        for (touch in FlxG.touches.list) {
            if (touch != null && touch.pressed) { anyPressed = true; break; }
        }
        #end
        if (!anyPressed) isDragging = false;
    }

    private function getNormalized():Float {
        if (max == min) return 0;
        return (value - min) / (max - min);
    }

    private function updateFill():Void {
        var fillW = Std.int(barWidth * getNormalized());
        if (fillW < 1) fillW = 1;
        fill.makeGraphic(fillW, Std.int(barHeight), 0xFF8A2BE2);
        valueText.text = formatValue();
    }

    private function formatValue():String {
        if (max <= 1) {
            return Std.string(Std.int(value * 100)) + "%";
        }
        return Std.string(Math.round(value * 10) / 10);
    }
}
