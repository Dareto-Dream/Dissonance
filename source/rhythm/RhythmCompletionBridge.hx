package rhythm;

import vn.RhythmBridge.RhythmResult;

/**
 * RhythmCompletionBridge
 * ======================
 * Handles deferred execution of VN callbacks after rhythm completion.
 * 
 * CRITICAL LIFECYCLE FIX:
 * 
 * Problem:
 * - RhythmState calls onComplete() while still in RhythmState
 * - onComplete tries to run VN code (showDialogue, emphasizeCharacter, etc.)
 * - VN renderers don't exist yet (destroyed during state switch)
 * - Accessing null renderers → crash
 * 
 * Solution:
 * - RhythmState stores completion data here instead of calling callback
 * - RhythmState switches back to VN state
 * - VN state's create/resume retrieves and executes callback
 * - VN renderers are initialized before VN code runs
 * - No null access, clean lifecycle
 */
class RhythmCompletionBridge
{
    // Stored completion data
    private static var storedResult:RhythmResult = null;
    private static var storedCallback:RhythmResult->Void = null;
    
    /**
     * Store rhythm completion result and callback for deferred execution.
     * Called by RhythmState.finishSong()
     */
    public static function storeResult(result:RhythmResult, callback:RhythmResult->Void):Void
    {
        storedResult = result;
        storedCallback = callback;
    }
    
    /**
     * Check if there's a pending rhythm completion callback.
     */
    public static function hasPendingCallback():Bool
    {
        return storedCallback != null;
    }

    /**
     * Read the pending result without consuming it.
     * Used by VNState to pick the win/fail resume node before running the scene.
     */
    public static function getPendingResult():RhythmResult
    {
        return storedResult;
    }
    
    /**
     * Execute stored callback with stored result, then clear.
     * Called by VN state after renderers are initialized.
     * 
     * CRITICAL: Only call this AFTER VN renderers are fully initialized.
     */
    public static function executePendingCallback():Void
    {
        if (storedCallback == null) return;

        var callback = storedCallback;
        var result   = storedResult;

        // Clear before calling to prevent re-execution
        storedCallback = null;
        storedResult   = null;

        callback(result);
    }
    
    /**
     * Clear stored data without execution.
     * Use for cancellation or cleanup.
     */
    public static function clear():Void
    {
        storedResult = null;
        storedCallback = null;
    }
}
