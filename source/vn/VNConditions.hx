package vn;

class VNConditions {
    public static function evaluate(expr:String):Bool {
        // Example: "tiffany_rot <= 2"
        // Expand however you like.
        return ConditionParser.eval(expr);
    }
}
