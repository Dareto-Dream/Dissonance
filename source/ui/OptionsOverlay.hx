package ui;

import core.state.OptionsService;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import util.MobileSupport;

/**
 * OptionsOverlay - In-game options menu.
 *
 * Settings: text speed, music volume, SFX volume, auto-advance, fullscreen.
 * Persists via FlxG.save.
 */
class OptionsOverlay extends FlxGroup {
    private static inline var PURPLE:Int = 0xFF8A2BE2;

    public var isOpen(default, null):Bool = false;

    private var backdrop:FlxSprite;
    private var title:FlxText;
    private var sliders:Array<OptionSlider>;
    private var autoAdvanceBtn:FlxSprite;
    private var autoAdvanceText:FlxText;
    private var fullscreenBtn:FlxSprite;
    private var fullscreenText:FlxText;
    private var closeBtn:FlxSprite;
    private var closeBtnText:FlxText;
    private var onClose:Void->Void;

    public function new(onClose:Void->Void) {
        super();
        this.onClose = onClose;
        OptionsService.ensureLoaded();
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
        addSlider(sliderX, startY, sliderWidth, sliderHeight, "Text Speed", OptionsService.textSpeed, 10, 80, (v) -> {
            OptionsService.setTextSpeed(v);
        });

        // Music Volume
        addSlider(sliderX, startY + sliderSpacing, sliderWidth, sliderHeight, "Music Volume", OptionsService.musicVolume, 0, 1, (v) -> {
            OptionsService.setMusicVolume(v);
        });

        // SFX Volume
        addSlider(sliderX, startY + sliderSpacing * 2, sliderWidth, sliderHeight, "SFX Volume", OptionsService.sfxVolume, 0, 1, (v) -> {
            OptionsService.setSfxVolume(v);
        });

        // Auto-advance Speed
        addSlider(sliderX, startY + sliderSpacing * 3, sliderWidth, sliderHeight, "Auto-Advance Delay", OptionsService.autoAdvanceDelay, 0.5, 5, (v) -> {
            OptionsService.setAutoAdvanceDelay(v);
        });

        var toggleWidth = Std.int(sliderWidth / 2) - 10;
        var toggleHeight = mobile ? 44 : 32;
        var toggleY = startY + sliderSpacing * 4 + 8;

        autoAdvanceBtn = new FlxSprite(sliderX, toggleY);
        autoAdvanceBtn.makeGraphic(toggleWidth, toggleHeight, FlxColor.fromRGB(30, 20, 50));
        autoAdvanceBtn.scrollFactor.set(0, 0);
        add(autoAdvanceBtn);

        autoAdvanceText = new FlxText(autoAdvanceBtn.x, autoAdvanceBtn.y, toggleWidth, "");
        autoAdvanceText.setFormat(null, mobile ? 18 : 14, PURPLE, CENTER);
        autoAdvanceText.scrollFactor.set(0, 0);
        autoAdvanceText.y = autoAdvanceBtn.y + (toggleHeight - autoAdvanceText.height) / 2;
        add(autoAdvanceText);

        fullscreenBtn = new FlxSprite(sliderX + toggleWidth + 20, toggleY);
        fullscreenBtn.makeGraphic(toggleWidth, toggleHeight, FlxColor.fromRGB(30, 20, 50));
        fullscreenBtn.scrollFactor.set(0, 0);
        add(fullscreenBtn);

        fullscreenText = new FlxText(fullscreenBtn.x, fullscreenBtn.y, toggleWidth, "");
        fullscreenText.setFormat(null, mobile ? 18 : 14, PURPLE, CENTER);
        fullscreenText.scrollFactor.set(0, 0);
        fullscreenText.y = fullscreenBtn.y + (toggleHeight - fullscreenText.height) / 2;
        add(fullscreenText);

        // Close button
        var closeBtnWidth = mobile ? 200 : 150;
        var closeBtnHeight = mobile ? 50 : 36;
        var closeBtnY = sh - (mobile ? 60 : 40);

        closeBtn = new FlxSprite(Std.int((sw - closeBtnWidth) / 2), closeBtnY);
        closeBtn.makeGraphic(closeBtnWidth, closeBtnHeight, FlxColor.fromRGB(30, 20, 50));
        closeBtn.scrollFactor.set(0, 0);
        add(closeBtn);

        closeBtnText = new FlxText(closeBtn.x, closeBtn.y, closeBtnWidth, "BACK");
        closeBtnText.setFormat(null, mobile ? 24 : 18, PURPLE, CENTER);
        closeBtnText.scrollFactor.set(0, 0);
        closeBtnText.y = closeBtn.y + (closeBtnHeight - closeBtnText.height) / 2;
        add(closeBtnText);

        refreshToggleLabels();
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

        if (MobileSupport.pointerJustPressedOver(autoAdvanceBtn) || MobileSupport.pointerJustPressedOver(autoAdvanceText)) {
            OptionsService.toggleAutoAdvance();
            refreshToggleLabels();
        }

        if (MobileSupport.pointerJustPressedOver(fullscreenBtn) || MobileSupport.pointerJustPressedOver(fullscreenText)) {
            OptionsService.toggleFullscreen();
            refreshToggleLabels();
        }

        if (MobileSupport.pointerJustPressedOver(closeBtn)) {
            close();
        }
    }

    public function close():Void {
        isOpen = false;
        if (onClose != null) onClose();
    }

    private function refreshToggleLabels():Void {
        if (autoAdvanceText != null) {
            autoAdvanceText.text = 'AUTO: ${OptionsService.autoAdvanceEnabled ? "ON" : "OFF"}';
        }
        if (fullscreenText != null) {
            fullscreenText.text = 'FULLSCREEN: ${OptionsService.fullscreen ? "ON" : "OFF"}';
        }
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
            pointerX = FlxG.mouse.viewX;
            #end
            #if FLX_TOUCH
            for (touch in FlxG.touches.list) {
                if (touch != null && touch.pressed) {
                    pointerX = touch.viewX;
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
