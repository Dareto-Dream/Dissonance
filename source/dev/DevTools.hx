package dev;

import flixel.FlxG;
import haxe.PosInfos;
import openfl.utils.Assets;

enum abstract DevLogLevel(Int) from Int to Int
{
	var ERROR = 0;
	var WARN = 1;
	var INFO = 2;
	var DEBUG = 3;
	var VERBOSE = 4;
}

enum abstract RhythmDevMode(Int) from Int to Int
{
	var OFF = 0;
	var BOTPLAY = 1;
	var AUTO_FINISH_SUCCESS = 2;
	var AUTO_FINISH_FAIL = 3;
}

class DevTools
{
	public static var ENABLED:Bool = true;
	public static var SHOW_OVERLAY:Bool = true;
	public static var LOG_LEVEL:DevLogLevel = INFO;

	public static var DIALOGUE_AUTO_ADVANCE:Bool = false;
	public static var STORY_FAST_FORWARD:Bool = false;
	public static var AUTO_PICK_FIRST_CHOICE:Bool = false;
	public static var RHYTHM_MODE:RhythmDevMode = OFF;
	public static var RHYTHM_AUTO_FINISH_DELAY:Float = 1.5;

	public static var lastAction(default, null):String = "Dev tools idle";

	private static var installed:Bool = false;
	private static var originalTrace:Dynamic;
	private static var scenePaths:Array<String> = [];
	private static var chartIds:Array<String> = [];
	private static var selectedSceneIndex:Int = 0;
	private static var selectedChartIndex:Int = 0;

	public static function install():Void
	{
		if (installed)
		{
			return;
		}

		installed = true;
		originalTrace = haxe.Log.trace;
		haxe.Log.trace = function(value:Dynamic, ?infos:PosInfos):Void
		{
			handleTrace(value, infos);
		};

		discoverAssets();
		notify('Installed. ENABLED=${ENABLED}, log=${logLevelName(LOG_LEVEL)}');
	}

	public static function handleTrace(value:Dynamic, ?infos:PosInfos):Void
	{
		if (originalTrace == null)
		{
			return;
		}

		if (!ENABLED)
		{
			Reflect.callMethod(null, originalTrace, [value, infos]);
			return;
		}

		var message = Std.string(value);
		var level = inferLevel(message);
		if ((level:Int) <= (LOG_LEVEL:Int))
		{
			Reflect.callMethod(null, originalTrace, [message, infos]);
		}
	}

	public static function log(level:DevLogLevel, message:String, ?infos:PosInfos):Void
	{
		if (originalTrace == null)
		{
			return;
		}

		if (!ENABLED || (level:Int) <= (LOG_LEVEL:Int))
		{
			Reflect.callMethod(null, originalTrace, ['[${logLevelName(level)}][DevTools] ${message}', infos]);
		}
	}

	public static function notify(message:String):Void
	{
		lastAction = message;
		log(DEBUG, message);
	}

	public static function toggleOverlay():Bool
	{
		SHOW_OVERLAY = !SHOW_OVERLAY;
		notify('Overlay ${SHOW_OVERLAY ? "shown" : "hidden"}');
		return SHOW_OVERLAY;
	}

	public static function cycleLogLevel():DevLogLevel
	{
		LOG_LEVEL = switch (LOG_LEVEL)
		{
			case ERROR: WARN;
			case WARN: INFO;
			case INFO: DEBUG;
			case DEBUG: VERBOSE;
			default: ERROR;
		};

		notify('Log level set to ${logLevelName(LOG_LEVEL)}');
		return LOG_LEVEL;
	}

	public static function cycleRhythmMode():RhythmDevMode
	{
		RHYTHM_MODE = switch (RHYTHM_MODE)
		{
			case OFF: BOTPLAY;
			case BOTPLAY: AUTO_FINISH_SUCCESS;
			case AUTO_FINISH_SUCCESS: AUTO_FINISH_FAIL;
			default: OFF;
		};

		notify('Rhythm mode set to ${rhythmModeName(RHYTHM_MODE)}');
		return RHYTHM_MODE;
	}

	public static function adjustAutoFinishDelay(delta:Float):Float
	{
		RHYTHM_AUTO_FINISH_DELAY = Math.max(0.25, RHYTHM_AUTO_FINISH_DELAY + delta);
		notify('Auto-finish delay ${formatFloat(RHYTHM_AUTO_FINISH_DELAY)}s');
		return RHYTHM_AUTO_FINISH_DELAY;
	}

	public static function devChordPressed(digit:Int):Bool
	{
		#if FLX_KEYBOARD
		return chordPressed(digit, false, false);
		#else
		return false;
		#end
	}

	public static function shiftDevChordPressed(digit:Int):Bool
	{
		#if FLX_KEYBOARD
		return chordPressed(digit, true, false);
		#else
		return false;
		#end
	}

	public static function sceneCount():Int
	{
		discoverAssets();
		return scenePaths.length;
	}

	public static function chartCount():Int
	{
		discoverAssets();
		return chartIds.length;
	}

	public static function getScenePaths():Array<String>
	{
		discoverAssets();
		return scenePaths.copy();
	}

	public static function getChartIds():Array<String>
	{
		discoverAssets();
		return chartIds.copy();
	}

	public static function getSelectedScene():String
	{
		discoverAssets();
		if (scenePaths.length == 0)
		{
			return "scenes/act1/scene1.json";
		}

		selectedSceneIndex = wrap(selectedSceneIndex, scenePaths.length);
		return scenePaths[selectedSceneIndex];
	}

	public static function getSelectedChart():String
	{
		discoverAssets();
		if (chartIds.length == 0)
		{
			return "gentle_start_duet";
		}

		selectedChartIndex = wrap(selectedChartIndex, chartIds.length);
		return chartIds[selectedChartIndex];
	}

	public static function cycleScene(delta:Int):String
	{
		discoverAssets();
		if (scenePaths.length == 0)
		{
			return "scenes/act1/scene1.json";
		}

		selectedSceneIndex = wrap(selectedSceneIndex + delta, scenePaths.length);
		var scene = scenePaths[selectedSceneIndex];
		notify('Selected scene ${scene}');
		return scene;
	}

	public static function cycleChart(delta:Int):String
	{
		discoverAssets();
		if (chartIds.length == 0)
		{
			return "gentle_start_duet";
		}

		selectedChartIndex = wrap(selectedChartIndex + delta, chartIds.length);
		var chart = chartIds[selectedChartIndex];
		notify('Selected chart ${chart}');
		return chart;
	}

	public static function shortScene(path:String):String
	{
		if (path == null || path == "")
		{
			return "(none)";
		}

		var slash = path.lastIndexOf("/");
		return slash >= 0 ? path.substr(slash + 1) : path;
	}

	public static function logLevelName(level:DevLogLevel):String
	{
		return switch (level)
		{
			case ERROR: "ERROR";
			case WARN: "WARN";
			case INFO: "INFO";
			case DEBUG: "DEBUG";
			case VERBOSE: "VERBOSE";
			default: "INFO";
		};
	}

	public static function rhythmModeName(mode:RhythmDevMode):String
	{
		return switch (mode)
		{
			case OFF: "OFF";
			case BOTPLAY: "BOTPLAY";
			case AUTO_FINISH_SUCCESS: "AUTO_SUCCESS";
			case AUTO_FINISH_FAIL: "AUTO_FAIL";
			default: "OFF";
		};
	}

	public static function formatFloat(value:Float):String
	{
		return Std.string(Math.round(value * 100) / 100);
	}

	private static function discoverAssets():Void
	{
		if (scenePaths.length > 0 && chartIds.length > 0)
		{
			return;
		}

		scenePaths = [];
		chartIds = [];

		try
		{
			for (assetId in Assets.list())
			{
				if (StringTools.startsWith(assetId, "assets/data/scenes/") && StringTools.endsWith(assetId, ".json"))
				{
					scenePaths.push(assetId.substr("assets/data/".length));
				}
				else if (StringTools.startsWith(assetId, "assets/data/charts/") && StringTools.endsWith(assetId, ".json"))
				{
					var chartId = assetId.substr("assets/data/charts/".length);
					chartIds.push(chartId.substr(0, chartId.length - ".json".length));
				}
			}
		}
		catch (_:Dynamic) {}

		if (scenePaths.length == 0)
		{
			scenePaths = ["scenes/act1/scene1.json"];
		}

		if (chartIds.length == 0)
		{
			chartIds = ["gentle_start_duet"];
		}

		scenePaths.sort(sortStrings);
		chartIds.sort(sortStrings);
		selectedSceneIndex = wrap(selectedSceneIndex, scenePaths.length);
		selectedChartIndex = wrap(selectedChartIndex, chartIds.length);
	}

	private static function inferLevel(message:String):DevLogLevel
	{
		var upper = message.toUpperCase();
		if (upper.indexOf("ERROR") >= 0)
		{
			return ERROR;
		}

		if (upper.indexOf("WARN") >= 0)
		{
			return WARN;
		}

		if (upper.indexOf("VERBOSE") >= 0)
		{
			return VERBOSE;
		}

		if (upper.indexOf("DEBUG") >= 0)
		{
			return DEBUG;
		}

		return INFO;
	}

	private static function sortStrings(a:String, b:String):Int
	{
		if (a < b) return -1;
		if (a > b) return 1;
		return 0;
	}

	private static function wrap(value:Int, length:Int):Int
	{
		if (length <= 0)
		{
			return 0;
		}

		var result = value % length;
		return result < 0 ? result + length : result;
	}

	private static function chordPressed(digit:Int, shift:Bool, control:Bool):Bool
	{
		#if FLX_KEYBOARD
		if (!FlxG.keys.pressed.M && !FlxG.keys.justPressed.M)
		{
			return false;
		}

		var shiftActive = FlxG.keys.pressed.SHIFT || FlxG.keys.justPressed.SHIFT;
		if (shiftActive != shift)
		{
			return false;
		}

		var controlActive = FlxG.keys.pressed.CONTROL || FlxG.keys.justPressed.CONTROL;
		if (controlActive != control)
		{
			return false;
		}

		if (!digitPressed(digit))
		{
			return false;
		}

		return FlxG.keys.justPressed.M
			|| digitJustPressed(digit)
			|| (shift && FlxG.keys.justPressed.SHIFT)
			|| (control && FlxG.keys.justPressed.CONTROL);
		#else
		return false;
		#end
	}

	private static function digitPressed(digit:Int):Bool
	{
		#if FLX_KEYBOARD
		return switch (digit)
		{
			case 0: FlxG.keys.pressed.ZERO || FlxG.keys.pressed.NUMPADZERO;
			case 1: FlxG.keys.pressed.ONE || FlxG.keys.pressed.NUMPADONE;
			case 2: FlxG.keys.pressed.TWO || FlxG.keys.pressed.NUMPADTWO;
			case 3: FlxG.keys.pressed.THREE || FlxG.keys.pressed.NUMPADTHREE;
			case 4: FlxG.keys.pressed.FOUR || FlxG.keys.pressed.NUMPADFOUR;
			case 5: FlxG.keys.pressed.FIVE || FlxG.keys.pressed.NUMPADFIVE;
			case 6: FlxG.keys.pressed.SIX || FlxG.keys.pressed.NUMPADSIX;
			case 7: FlxG.keys.pressed.SEVEN || FlxG.keys.pressed.NUMPADSEVEN;
			case 8: FlxG.keys.pressed.EIGHT || FlxG.keys.pressed.NUMPADEIGHT;
			case 9: FlxG.keys.pressed.NINE || FlxG.keys.pressed.NUMPADNINE;
			default: false;
		};
		#else
		return false;
		#end
	}

	private static function digitJustPressed(digit:Int):Bool
	{
		#if FLX_KEYBOARD
		return switch (digit)
		{
			case 0: FlxG.keys.justPressed.ZERO || FlxG.keys.justPressed.NUMPADZERO;
			case 1: FlxG.keys.justPressed.ONE || FlxG.keys.justPressed.NUMPADONE;
			case 2: FlxG.keys.justPressed.TWO || FlxG.keys.justPressed.NUMPADTWO;
			case 3: FlxG.keys.justPressed.THREE || FlxG.keys.justPressed.NUMPADTHREE;
			case 4: FlxG.keys.justPressed.FOUR || FlxG.keys.justPressed.NUMPADFOUR;
			case 5: FlxG.keys.justPressed.FIVE || FlxG.keys.justPressed.NUMPADFIVE;
			case 6: FlxG.keys.justPressed.SIX || FlxG.keys.justPressed.NUMPADSIX;
			case 7: FlxG.keys.justPressed.SEVEN || FlxG.keys.justPressed.NUMPADSEVEN;
			case 8: FlxG.keys.justPressed.EIGHT || FlxG.keys.justPressed.NUMPADEIGHT;
			case 9: FlxG.keys.justPressed.NINE || FlxG.keys.justPressed.NUMPADNINE;
			default: false;
		};
		#else
		return false;
		#end
	}
}
