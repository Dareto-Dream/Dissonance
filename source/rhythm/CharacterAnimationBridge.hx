package rhythm;

import vn.CharacterSystem;
import rhythm.ChartData.PoseType;

/**
 * CharacterAnimationBridge - Rhythm to VN animation connection
 * 
 * This class translates rhythm game events into character animations.
 * It works with the existing VN CharacterSystem to trigger poses.
 * 
 * Key features:
 * - Player note hits trigger player animations
 * - NPC notes trigger NPC animations
 * - Hold notes loop animations
 * - Release returns to idle
 * 
 * Usage:
 *   bridge = new CharacterAnimationBridge(characterSystem, "mc", ["cassian", "harumi"]);
 *   bridge.onPlayerNoteHit(lane, isHold);
 *   bridge.onNPCNote(singerIndex, poseIndex, isHold);
 */
class CharacterAnimationBridge {
    // Reference to VN character system
    private var characterSystem:CharacterSystem;
    
    // Character IDs
    private var player:String;
    private var singers:Array<String>;
    
    /**
     * Constructor
     * @param characterSystem The VN character system
     * @param player Player character ID (typically "mc")
     * @param singers Array of NPC character IDs in order
     */
    public function new(characterSystem:CharacterSystem, player:String, singers:Array<String>) {
        this.characterSystem = characterSystem;
        this.player = player;
        this.singers = singers;
    }
    
    /**
     * Handle player note hit
     * Triggers sing animation for player character
     * 
     * @param lane Which lane was hit (0-3)
     * @param isHold Whether this is a hold note
     */
    public function onPlayerNoteHit(lane:Int, isHold:Bool):Void {
        var poseName = PoseType.NAMES[lane % 4];
        
        // Play sing animation
        characterSystem.playAnimation(player, poseName);
        
        // If hold, enable looping
        if (isHold) {
            characterSystem.setLooping(player, true);
        }
    }
    
    /**
     * Handle player note release
     * Returns character to idle pose
     */
    public function onPlayerNoteRelease():Void {
        characterSystem.setLooping(player, false);
        characterSystem.playAnimation(player, "idle");
    }
    
    /**
     * Handle player miss
     * Triggers miss animation if available
     * 
     * @param lane Which lane was missed
     */
    public function onPlayerNoteMiss(lane:Int):Void {
        // Try to play miss animation, fallback to idle
        try {
            characterSystem.playAnimation(player, "miss");
        } catch (e:Dynamic) {
            characterSystem.playAnimation(player, "idle");
        }
    }
    
    /**
     * Handle NPC note
     * Triggers sing animation for specified NPC
     * 
     * @param singerIndex Which singer (0-based index in singers array)
     * @param poseIndex Which pose (0=left, 1=down, 2=up, 3=right)
     * @param isHold Whether this is a hold note
     */
    public function onNPCNote(singerIndex:Int, poseIndex:Int, isHold:Bool):Void {
        // Validate singer index
        if (singerIndex < 0 || singerIndex >= singers.length) {
            trace('Warning: Invalid NPC singer index ${singerIndex}');
            return;
        }
        
        var singerId = singers[singerIndex];
        var poseName = PoseType.NAMES[poseIndex];
        
        // Play sing animation
        characterSystem.playAnimation(singerId, poseName);
        
        if (isHold) {
            // Enable looping for hold
            characterSystem.setLooping(singerId, true);
        } else {
            // Auto-return to idle after short delay
            haxe.Timer.delay(() -> {
                characterSystem.setLooping(singerId, false);
                characterSystem.playAnimation(singerId, "idle");
            }, 200); // 200ms delay
        }
    }
    
    /**
     * Return all characters to idle
     * Useful for song end or restart
     */
    public function resetAll():Void {
        characterSystem.playAnimation(player, "idle");
        characterSystem.setLooping(player, false);
        
        for (singer in singers) {
            characterSystem.playAnimation(singer, "idle");
            characterSystem.setLooping(singer, false);
        }
    }
}