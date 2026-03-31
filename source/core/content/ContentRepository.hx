package core.content;

import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ContentRepository
{
	public static function readText(path:String):String
	{
		var normalized = normalize(path);

		#if sys
		var diskPath = resolveDesktopPath(normalized);
		if (FileSystem.exists(diskPath))
		{
			return File.getContent(diskPath);
		}
		#end

		return Assets.getText(normalized);
	}

	public static function exists(path:String):Bool
	{
		var normalized = normalize(path);

		#if sys
		if (FileSystem.exists(resolveDesktopPath(normalized)))
		{
			return true;
		}
		#end

		return Assets.exists(normalized);
	}

	public static function writeText(path:String, content:String):Bool
	{
		#if sys
		var normalized = normalize(path);
		var diskPath = resolveDesktopPath(normalized);
		ensureParentDirectory(diskPath);
		File.saveContent(diskPath, content);
		return true;
		#else
		return false;
		#end
	}

	public static function exportJson(path:String, data:Dynamic, pretty:Bool = true):Bool
	{
		var content = pretty
			? haxe.Json.stringify(data, null, "  ")
			: haxe.Json.stringify(data);
		return writeText(path, content);
	}

	public static function listFiles(root:String, suffix:String = ""):Array<String>
	{
		var normalizedRoot = normalize(root);
		var results:Array<String> = [];

		#if sys
		var diskRoot = resolveDesktopPath(normalizedRoot);
		if (FileSystem.exists(diskRoot))
		{
			collectFiles(diskRoot, normalizedRoot, suffix, results);
			results.sort(sortStrings);
			return results;
		}
		#end

		for (assetId in Assets.list())
		{
			if (!StringTools.startsWith(assetId, normalizedRoot))
			{
				continue;
			}
			if (suffix != "" && !StringTools.endsWith(assetId, suffix))
			{
				continue;
			}
			results.push(assetId);
		}

		results.sort(sortStrings);
		return results;
	}

	public static function listScenes():Array<String>
	{
		var scenes:Array<String> = [];
		for (path in listFiles("assets/data/scenes", ".json"))
		{
			if (path.indexOf("/template/") < 0)
			{
				scenes.push(path);
			}
		}
		return scenes;
	}

	public static function listCharts():Array<String>
	{
		return listFiles("assets/data/charts", ".json");
	}

	public static function listCharacters():Array<String>
	{
		return listFiles("assets/data/characters", ".json");
	}

	#if sys
	private static function collectFiles(diskRoot:String, logicalRoot:String, suffix:String, out:Array<String>):Void
	{
		for (entry in FileSystem.readDirectory(diskRoot))
		{
			var diskPath = normalize(diskRoot + "/" + entry);
			var logicalPath = normalize(logicalRoot + "/" + entry);
			if (FileSystem.isDirectory(diskPath))
			{
				collectFiles(diskPath, logicalPath, suffix, out);
			}
			else if (suffix == "" || StringTools.endsWith(logicalPath, suffix))
			{
				out.push(logicalPath);
			}
		}
	}

	private static function ensureParentDirectory(path:String):Void
	{
		var lastSlash = path.lastIndexOf("/");
		if (lastSlash <= 0)
		{
			return;
		}

		var dir = path.substr(0, lastSlash);
		if (!FileSystem.exists(dir))
		{
			FileSystem.createDirectory(dir);
		}
	}

	private static function resolveDesktopPath(path:String):String
	{
		if (isAbsolute(path))
		{
			return path;
		}

		return normalize(Sys.getCwd() + "/" + path);
	}
	#end

	private static function normalize(path:String):String
	{
		return path == null ? "" : StringTools.replace(path, "\\", "/");
	}

	private static function isAbsolute(path:String):Bool
	{
		if (path == null || path == "")
		{
			return false;
		}

		return StringTools.startsWith(path, "/")
			|| StringTools.startsWith(path, "\\")
			|| (path.length > 1 && path.charAt(1) == ":");
	}

	private static function sortStrings(a:String, b:String):Int
	{
		if (a < b) return -1;
		if (a > b) return 1;
		return 0;
	}
}
