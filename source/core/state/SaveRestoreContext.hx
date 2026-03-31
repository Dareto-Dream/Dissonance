package core.state;

import core.state.SaveTypes.VisualSnapshot;

class SaveRestoreContext
{
	private static var pending:VisualSnapshot = null;

	public static function store(snapshot:VisualSnapshot):Void
	{
		pending = snapshot;
	}

	public static function hasPending():Bool
	{
		return pending != null;
	}

	public static function consume():VisualSnapshot
	{
		var snapshot = pending;
		pending = null;
		return snapshot;
	}

	public static function clear():Void
	{
		pending = null;
	}
}
