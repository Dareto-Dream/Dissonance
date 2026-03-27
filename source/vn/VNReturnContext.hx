package vn;

import core.rendering.CharacterSystem.CharacterSnapshot;

/**
 * VNReturnContext
 * ===============
 * Stores VN state for resuming after rhythm gameplay.
 * 
 * CONTRACT (from design spec):
 * - VN state is REBUILT when returning from rhythm (not preserved)
 * - This context allows SceneRunner to resume at the correct node
 * - Must be set before entering rhythm, consumed when VN resumes
 */
class VNReturnContext
{
    // -----------------------------------------------
    // Stored Context
    // -----------------------------------------------
    
    /**
     * Scene file path to reload
     * Example: "scenes/act1/scene1.json"
     */
    public var scenePath:String;
    
    /**
     * Node ID to resume at after rhythm completes (used when no win/fail split).
     */
    public var resumeNodeId:String;

    /**
     * Node to jump to if the player cleared the song (completed=true).
     * Falls back to resumeNodeId if null.
     */
    public var winNode:String;

    /**
     * Node to jump to if the player failed the song (completed=false).
     * Falls back to resumeNodeId if null.
     */
    public var failNode:String;

    /** Background path active when rhythm started — restored on return. */
    public var bgPath:String;

    /** Character visual state captured before rhythm — restored on return. */
    public var charSnapshots:Array<CharacterSnapshot>;

    // -----------------------------------------------
    // Static Storage (Single Pending Context)
    // -----------------------------------------------

    private static var pendingContext:VNReturnContext = null;

    /**
     * Store a return context before entering rhythm (no win/fail branching).
     */
    public static function store(scenePath:String, resumeNodeId:String,
                                 bgPath:String = "", ?charSnapshots:Array<CharacterSnapshot>):Void
    {
        pendingContext = new VNReturnContext();
        pendingContext.scenePath      = scenePath;
        pendingContext.resumeNodeId   = resumeNodeId;
        pendingContext.winNode        = null;
        pendingContext.failNode       = null;
        pendingContext.bgPath         = bgPath;
        pendingContext.charSnapshots  = charSnapshots;
    }

    /**
     * Store a return context with separate win/fail branches.
     * bgPath and charSnapshots restore visual state on return.
     */
    public static function storeWithBranch(scenePath:String, resumeNodeId:String,
                                           winNode:String, failNode:String,
                                           bgPath:String = "", ?charSnapshots:Array<CharacterSnapshot>):Void
    {
        pendingContext = new VNReturnContext();
        pendingContext.scenePath     = scenePath;
        pendingContext.resumeNodeId  = resumeNodeId;
        pendingContext.winNode       = winNode;
        pendingContext.failNode      = failNode;
        pendingContext.bgPath        = bgPath;
        pendingContext.charSnapshots = charSnapshots;
    }
    
    /**
     * Check if there's a pending return context.
     * Called by VNState.create() to detect rhythm return.
     */
    public static function hasPending():Bool
    {
        return pendingContext != null;
    }
    
    /**
     * Retrieve and consume the pending context.
     * Called by VNState.create() when resuming after rhythm.
     * 
     * IMPORTANT: This clears the context (consume-once semantics).
     */
    public static function consume():VNReturnContext
    {
        var ctx = pendingContext;
        pendingContext = null;
        return ctx;
    }

    public static function clear():Void
    {
        pendingContext = null;
    }
    
    /**
     * Private constructor - use static methods only.
     */
    private function new() {}
}
