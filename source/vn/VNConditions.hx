package vn;

import core.dialogue.ConditionParser;

class VNConditions {
    public static function evaluate(expr:String):Bool {
        // Example: "tiffany_rot <= 2"
        // Expand however you like.
        return ConditionParser.eval(expr);
    }
}
