package vn;

class ChoiceSystem {
    public static function show(choices:Array<Dynamic>, callback:String->Void):Void {
        trace("CHOICE: Selected " + choices[0].text);
        callback(choices[0].target);
    }
}
