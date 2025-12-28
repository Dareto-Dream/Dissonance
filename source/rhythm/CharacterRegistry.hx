package rhythm;

/**
 * CharacterRegistry
 * =================
 * Typed representation of characters.json
 * 
 * Defines paths to character assets for both rhythm and VN systems.
 * 
 * CRITICAL: Rhythm code must ONLY use rhythm paths.
 * VN paths are documented here but never accessed by rhythm systems.
 */

typedef CharacterRegistry = Map<String, CharacterData>;

typedef CharacterData =
{
    var id:String;
    var rhythm:CharacterRhythmAssets;
    var vn:CharacterVNAssets;
}

typedef CharacterRhythmAssets =
{
    var png:String;
    var xml:String;
}

typedef CharacterVNAssets =
{
    var png:String;
    var xml:String;
    var defaultPose:String;
}
