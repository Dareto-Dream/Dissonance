package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import util.MobileSupport;

/**
 * RhythmResultsOverlay
 * ====================
 * Shown on top of VNState after returning from a rhythm segment.
 * Displays: CLEARED / FAILED, Score, Accuracy, Rank.
 * Player taps or presses any key to dismiss.
 */
class RhythmResultsOverlay extends FlxGroup
{
    private static inline var PURPLE:Int = 0xFF8A2BE2;

    private var onDismiss:Void->Void;
    private var canDismiss:Bool = false;
    private var promptText:FlxText;

    public function new(completed:Bool, score:Int, accuracy:Float, onDismiss:Void->Void)
    {
        super();
        this.onDismiss = onDismiss;

        var sw = FlxG.width;
        var sh = FlxG.height;
        var mobile = MobileSupport.isMobile();

        // Dark semi-transparent background
        var bg = new FlxSprite(0, 0);
        bg.makeGraphic(sw, sh, FlxColor.fromRGBFloat(0, 0, 0, 0.85));
        bg.scrollFactor.set(0, 0);
        add(bg);

        var rank = calcRank(completed, accuracy);

        // Result header: SONG CLEARED / SONG FAILED
        var headerColor = completed ? PURPLE : 0xFFCC2222;
        var headerText  = completed ? "SONG CLEARED" : "SONG FAILED";
        var header = new FlxText(0, mobile ? 80 : 60, sw, headerText);
        header.setFormat(null, mobile ? 52 : 42, headerColor, CENTER);
        header.scrollFactor.set(0, 0);
        header.alpha = 0;
        add(header);
        FlxTween.tween(header, {alpha: 1}, 0.4, {ease: FlxEase.quadOut});

        // Rank letter
        var rankColor = rankColor(rank);
        var rankLabel = new FlxText(0, mobile ? 170 : 130, sw, rank);
        rankLabel.setFormat(null, mobile ? 110 : 90, rankColor, CENTER);
        rankLabel.scrollFactor.set(0, 0);
        rankLabel.alpha = 0;
        add(rankLabel);
        FlxTween.tween(rankLabel, {alpha: 1}, 0.5, {ease: FlxEase.quadOut, startDelay: 0.1});

        // Stats
        var statsY = mobile ? 320 : 260;
        var statSize = mobile ? 28 : 22;
        var statSpacing = mobile ? 46 : 36;

        var accPct = Std.int(accuracy * 10) / 10; // one decimal
        var stats:Array<String> = [
            'SCORE   ${formatScore(score)}',
            'ACCURACY   ${accPct}%',
        ];

        for (i in 0...stats.length)
        {
            var stat = new FlxText(0, statsY + i * statSpacing, sw, stats[i]);
            stat.setFormat(null, statSize, FlxColor.WHITE, CENTER);
            stat.scrollFactor.set(0, 0);
            stat.alpha = 0;
            add(stat);
            FlxTween.tween(stat, {alpha: 1}, 0.4, {ease: FlxEase.quadOut, startDelay: 0.2 + i * 0.1});
        }

        // Prompt
        var promptY = sh - (mobile ? 80 : 60);
        promptText = new FlxText(0, promptY, sw, "TAP OR PRESS ANY KEY TO CONTINUE");
        promptText.setFormat(null, mobile ? 20 : 16, 0xFFAAAAAA, CENTER);
        promptText.scrollFactor.set(0, 0);
        promptText.alpha = 0;
        add(promptText);

        // Allow dismissal after a short delay (prevents accidental skip)
        flixel.util.FlxTimer.wait(1.2, () -> {
            canDismiss = true;
            FlxTween.tween(promptText, {alpha: 1}, 0.3);
        });
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (!canDismiss) return;

        var dismissed = false;

        #if FLX_KEYBOARD
        if (FlxG.keys.justPressed.ANY) dismissed = true;
        #end

        if (!dismissed)
            dismissed = MobileSupport.anyPointerJustPressed();

        if (dismissed)
        {
            canDismiss = false;
            if (onDismiss != null) onDismiss();
        }
    }

    private static function calcRank(completed:Bool, accuracy:Float):String
    {
        if (!completed) return "F";
        var pct = accuracy; // already 0–100
        if (pct >= 95) return "S";
        if (pct >= 85) return "A";
        if (pct >= 70) return "B";
        if (pct >= 50) return "C";
        return "D";
    }

    private static function rankColor(rank:String):Int
    {
        return switch (rank)
        {
            case "S": 0xFFFFD700; // gold
            case "A": PURPLE;
            case "B": 0xFF44AAFF; // blue
            case "C": 0xFF88CC44; // green
            case "D": 0xFFAAAAAA; // grey
            default:  0xFFCC2222; // red (F)
        };
    }

    private static function formatScore(score:Int):String
    {
        // insert commas: 123456 → "123,456"
        var s = Std.string(score);
        var result = "";
        var count = 0;
        var i = s.length - 1;
        while (i >= 0)
        {
            if (count > 0 && count % 3 == 0) result = "," + result;
            result = s.charAt(i) + result;
            count++;
            i--;
        }
        return result;
    }
}
