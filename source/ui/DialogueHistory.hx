package ui;

import core.dialogue.DialogueSystem;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import util.MobileSupport;

/**
 * DialogueHistory - Scrollable backlog of recent dialogue.
 *
 * Toggle with H key (desktop) or swipe up (mobile).
 * Shows speaker names and text from DialogueSystem.history.
 */
class DialogueHistory extends FlxGroup {

    public var isOpen(default, null):Bool = false;

    private var backdrop:FlxSprite;
    private var title:FlxText;
    private var entries:FlxGroup;
    private var scrollOffset:Float = 0;
    private var maxScroll:Float = 0;
    private var closeHint:FlxText;

    public function new() {
        super();
        createUI();
    }

    private function createUI():Void {
        var sw = FlxG.width;
        var sh = FlxG.height;
        var mobile = MobileSupport.isMobile();

        backdrop = new FlxSprite(0, 0);
        backdrop.makeGraphic(sw, sh, FlxColor.fromRGBFloat(0, 0, 0, 0.85));
        backdrop.scrollFactor.set(0, 0);
        backdrop.visible = false;
        add(backdrop);

        title = new FlxText(0, mobile ? 20 : 15, sw, "DIALOGUE HISTORY");
        title.setFormat(null, mobile ? 26 : 18, 0xFF8A2BE2, CENTER);
        title.scrollFactor.set(0, 0);
        title.visible = false;
        add(title);

        entries = new FlxGroup();
        add(entries);

        closeHint = new FlxText(0, sh - (mobile ? 50 : 35), sw, "Press H or ESC to close");
        closeHint.setFormat(null, mobile ? 18 : 12, FlxColor.fromRGB(120, 110, 140), CENTER);
        closeHint.scrollFactor.set(0, 0);
        closeHint.visible = false;
        add(closeHint);
    }

    public function toggle():Void {
        if (isOpen) hide();
        else show();
    }

    public function show():Void {
        isOpen = true;
        backdrop.visible = true;
        title.visible = true;
        closeHint.visible = true;
        scrollOffset = 0;
        rebuildEntries();
    }

    public function hide():Void {
        isOpen = false;
        backdrop.visible = false;
        title.visible = false;
        closeHint.visible = false;
        clearEntries();
    }

    private function rebuildEntries():Void {
        clearEntries();

        var history = DialogueSystem.history;
        if (history == null || history.length == 0) return;

        var mobile = MobileSupport.isMobile();
        var fontSize = mobile ? 18 : 14;
        var margin = mobile ? 60 : 80;
        var startY = mobile ? 70 : 50;
        var textWidth = FlxG.width - margin * 2;

        var y = startY;
        // Show most recent at bottom, so iterate forward
        for (entry in history) {
            var displayText = entry.speaker != null
                ? entry.speaker + ": " + entry.text
                : entry.text;

            var label = new FlxText(margin, y, textWidth, displayText);
            var color = entry.speaker != null
                ? FlxColor.fromRGB(220, 210, 240)
                : FlxColor.fromRGB(170, 160, 190);
            label.setFormat(null, fontSize, color, LEFT);
            label.scrollFactor.set(0, 0);
            entries.add(label);

            y += Std.int(label.height) + 8;
        }

        maxScroll = Math.max(0, y - FlxG.height + 80);
    }

    private function clearEntries():Void {
        entries.clear();
    }

    override public function update(elapsed:Float):Void {
        if (!isOpen) return;
        super.update(elapsed);

        #if FLX_KEYBOARD
        if (FlxG.keys.justPressed.H || FlxG.keys.justPressed.ESCAPE) {
            hide();
            return;
        }

        // Scroll with arrow keys
        if (FlxG.keys.pressed.UP) {
            scrollOffset = Math.max(0, scrollOffset - 200 * elapsed);
            applyScroll();
        }
        if (FlxG.keys.pressed.DOWN) {
            scrollOffset = Math.min(maxScroll, scrollOffset + 200 * elapsed);
            applyScroll();
        }
        #end

        // Mouse wheel scroll
        #if FLX_MOUSE
        if (FlxG.mouse.wheel != 0) {
            scrollOffset = Math.max(0, Math.min(maxScroll, scrollOffset - FlxG.mouse.wheel * 30));
            applyScroll();
        }
        #end
    }

    private function applyScroll():Void {
        var mobile = MobileSupport.isMobile();
        var startY = mobile ? 70 : 50;
        var y = startY - scrollOffset;

        for (member in entries.members) {
            if (member != null) {
                var text = cast(member, FlxText);
                text.y = y;
                y += Std.int(text.height) + 8;
            }
        }
    }
}
