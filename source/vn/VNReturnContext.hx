package vn;

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
     * Node ID to resume at after rhythm completes
     * Example: "n6_after_rhythm"
     */
    public var resumeNodeId:String;
    
    // -----------------------------------------------
    // Static Storage (Single Pending Context)
    // -----------------------------------------------
    
    private static var pendingContext:VNReturnContext = null;
    
    /**
     * Store a return context before entering rhythm.
     * Called by RhythmBridge before state switch.
     */
    public static function store(scenePath:String, resumeNodeId:String):Void
    {
        trace('[VNReturnContext] Storing: scene=$scenePath, resumeNode=$resumeNodeId');
        
        pendingContext = new VNReturnContext();
        pendingContext.scenePath = scenePath;
        pendingContext.resumeNodeId = resumeNodeId;
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
        if (pendingContext == null)
        {
            trace('[VNReturnContext] WARNING: consume() called with no pending context');
            return null;
        }
        
        trace('[VNReturnContext] Consuming context');
        var ctx = pendingContext;
        pendingContext = null;
        return ctx;
    }
    
    /**
     * Clear pending context without consumption.
     * Use for cleanup or reset.
     */
    public static function clear():Void
    {
        if (pendingContext != null)
        {
            trace('[VNReturnContext] Clearing pending context');
        }
        pendingContext = null;
    }
    
    /**
     * Private constructor - use static methods only.
     */
    private function new() {}
}
