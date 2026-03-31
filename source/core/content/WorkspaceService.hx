package core.content;

class WorkspaceService
{
	private static var overrides:Map<String, String> = new Map();
	private static var dirty:Map<String, Bool> = new Map();

	public static function getText(path:String):String
	{
		return overrides.exists(path) ? overrides.get(path) : ContentRepository.readText(path);
	}

	public static function stageText(path:String, content:String):Void
	{
		overrides.set(path, content);
		dirty.set(path, true);
	}

	public static function hasOverride(path:String):Bool
	{
		return overrides.exists(path);
	}

	public static function hasDirty(path:String):Bool
	{
		return dirty.exists(path) && dirty.get(path);
	}

	public static function save(path:String):Bool
	{
		if (!overrides.exists(path))
		{
			return false;
		}

		if (!ContentRepository.writeText(path, overrides.get(path)))
		{
			return false;
		}

		dirty.remove(path);
		return true;
	}

	public static function discard(path:String):Void
	{
		overrides.remove(path);
		dirty.remove(path);
	}

	public static function listDirtyPaths():Array<String>
	{
		var paths:Array<String> = [];
		for (path in dirty.keys())
		{
			if (dirty.get(path))
			{
				paths.push(path);
			}
		}
		paths.sort(sortStrings);
		return paths;
	}

	public static function dirtyCount():Int
	{
		return listDirtyPaths().length;
	}

	public static function saveAll():Array<String>
	{
		var saved:Array<String> = [];
		for (path in listDirtyPaths())
		{
			if (save(path))
			{
				saved.push(path);
			}
		}
		return saved;
	}

	public static function clear():Void
	{
		overrides.clear();
		dirty.clear();
	}

	private static function sortStrings(a:String, b:String):Int
	{
		if (a < b) return -1;
		if (a > b) return 1;
		return 0;
	}
}
