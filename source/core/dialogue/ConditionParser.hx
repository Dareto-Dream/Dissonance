package core.dialogue;

import core.state.GameState;

/**
 * ConditionParser - Evaluates condition expressions against GameState.
 *
 * Supports:
 *   - Comparisons: ==, !=, <, <=, >, >=
 *   - Logical: and, or
 *   - Parentheses for grouping
 *   - Variable names resolved via GameState
 *   - Numeric and boolean literals (true, false)
 *
 * Examples:
 *   "tiffany_rot <= 2"
 *   "flags.asked_tiffany == true and cassian_rot > 3"
 *   "(hanami_rot >= 5 or tiffany_rot >= 5) and flags.puppet_mode == false"
 */
class ConditionParser {
    private var tokens:Array<String>;
    private var pos:Int;

    public static function eval(expr:String):Bool {
        if (expr == null || StringTools.trim(expr) == "") return true;

        var parser = new ConditionParser(tokenize(expr));
        var result = parser.parseOr();

        return toBool(result);
    }

    private function new(tokens:Array<String>) {
        this.tokens = tokens;
        this.pos = 0;
    }

    // ========================================================================
    // Tokenizer
    // ========================================================================

    private static function tokenize(expr:String):Array<String> {
        var tokens:Array<String> = [];
        var i = 0;
        var s = StringTools.trim(expr);

        while (i < s.length) {
            var c = s.charAt(i);

            // Skip whitespace
            if (c == " " || c == "\t" || c == "\n" || c == "\r") {
                i++;
                continue;
            }

            // Parentheses
            if (c == "(" || c == ")") {
                tokens.push(c);
                i++;
                continue;
            }

            // Two-char operators
            if (i + 1 < s.length) {
                var two = s.charAt(i) + s.charAt(i + 1);
                if (two == "==" || two == "!=" || two == "<=" || two == ">=") {
                    tokens.push(two);
                    i += 2;
                    continue;
                }
            }

            // Single-char operators
            if (c == "<" || c == ">") {
                tokens.push(c);
                i++;
                continue;
            }

            // Numbers (including negative)
            if (c == "-" && i + 1 < s.length && isDigit(s.charAt(i + 1))) {
                var start = i;
                i++;
                while (i < s.length && (isDigit(s.charAt(i)) || s.charAt(i) == ".")) i++;
                tokens.push(s.substring(start, i));
                continue;
            }

            if (isDigit(c)) {
                var start = i;
                while (i < s.length && (isDigit(s.charAt(i)) || s.charAt(i) == ".")) i++;
                tokens.push(s.substring(start, i));
                continue;
            }

            // Words (variable names, true, false, and, or)
            if (isWordChar(c)) {
                var start = i;
                while (i < s.length && (isWordChar(s.charAt(i)) || s.charAt(i) == ".")) i++;
                tokens.push(s.substring(start, i));
                continue;
            }

            // Unknown character, skip
            i++;
        }

        return tokens;
    }

    // ========================================================================
    // Parser (recursive descent)
    // ========================================================================

    /** Lowest precedence: or */
    private function parseOr():Dynamic {
        var left = parseAnd();

        while (pos < tokens.length && tokens[pos] == "or") {
            pos++;
            var right = parseAnd();
            left = toBool(left) || toBool(right);
        }

        return left;
    }

    /** and */
    private function parseAnd():Dynamic {
        var left = parseComparison();

        while (pos < tokens.length && tokens[pos] == "and") {
            pos++;
            var right = parseComparison();
            left = toBool(left) && toBool(right);
        }

        return left;
    }

    /** Comparison: ==, !=, <, <=, >, >= */
    private function parseComparison():Dynamic {
        var left = parsePrimary();

        if (pos < tokens.length) {
            var op = tokens[pos];
            if (op == "==" || op == "!=" || op == "<" || op == "<=" || op == ">" || op == ">=") {
                pos++;
                var right = parsePrimary();
                return compare(left, op, right);
            }
        }

        return left;
    }

    /** Primary: literal, variable, or parenthesized expression */
    private function parsePrimary():Dynamic {
        if (pos >= tokens.length) return 0.0;

        var token = tokens[pos];

        // Parenthesized expression
        if (token == "(") {
            pos++;
            var result = parseOr();
            if (pos < tokens.length && tokens[pos] == ")") pos++;
            return result;
        }

        pos++;

        // Boolean literals
        if (token == "true") return true;
        if (token == "false") return false;

        // Numeric literal
        var num = Std.parseFloat(token);
        if (!Math.isNaN(num)) return num;

        // Variable name - resolve from GameState
        var state = GameState.get();
        return state.getValue(token);
    }

    // ========================================================================
    // Helpers
    // ========================================================================

    private static function compare(left:Dynamic, op:String, right:Dynamic):Bool {
        var l = toFloat(left);
        var r = toFloat(right);

        return switch (op) {
            case "==": l == r;
            case "!=": l != r;
            case "<":  l < r;
            case "<=": l <= r;
            case ">":  l > r;
            case ">=": l >= r;
            default:   false;
        };
    }

    private static function toFloat(v:Dynamic):Float {
        if (Std.isOfType(v, Bool)) return (v : Bool) ? 1.0 : 0.0;
        if (Std.isOfType(v, Float)) return (v : Float);
        if (Std.isOfType(v, Int)) return (v : Int) * 1.0;
        return 0.0;
    }

    private static function toBool(v:Dynamic):Bool {
        if (Std.isOfType(v, Bool)) return (v : Bool);
        if (Std.isOfType(v, Float)) return (v : Float) != 0.0;
        if (Std.isOfType(v, Int)) return (v : Int) != 0;
        return false;
    }

    private static function isDigit(c:String):Bool {
        return c >= "0" && c <= "9";
    }

    private static function isWordChar(c:String):Bool {
        return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_";
    }
}
