package rhythm;

import dev.DevTools;
import dev.DevTools.RhythmDevMode;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.Assets;
import rhythm.ArrowRenderer;
import rhythm.CharacterAnimationBridge;
import rhythm.CharacterSpriteManager;
import rhythm.ChartData;
import rhythm.ChartHandler;
import rhythm.Conductor;
import rhythm.JudgementSystem.HitRating;
import rhythm.JudgementSystem;
import rhythm.Note;
import rhythm.NoteHandler;
import rhythm.NoteRenderer;
import util.MobileSupport;

class RhythmState extends FlxState
{
	public var song:String;
	public var chartPath:String;
	public var returnStateFactory:Void->flixel.FlxState;
	public var onComplete:Dynamic;

	private var conductor:Conductor;
	private var chartHandler:ChartHandler;
	private var judgement:JudgementSystem;
	private var noteHandler:NoteHandler;

	private var arrowRenderer:ArrowRenderer;
	private var noteRenderer:NoteRenderer;
	private var characterSprites:CharacterSpriteManager;
	private var characterBridge:CharacterAnimationBridge;
	private var isFinishingSong:Bool = false;
	private var touchPads:Array<FlxSprite> = [];
	private var touchPadLabels:Array<FlxText> = [];
	private var touchLaneHeld:Array<Bool> = [false, false, false, false];

	private var devOverlayBg:FlxSprite;
	private var devOverlayText:FlxText;

	override public function create():Void
	{
		super.create();

		if (chartPath == null)
			throw "RhythmState started without chartPath";
		if (!Assets.exists(chartPath))
			throw 'RhythmState could not find chart at ${chartPath}';

		var chart:ChartData = cast haxe.Json.parse(Assets.getText(chartPath));
		configureMobileLayout();

		var stageSprite = createStageSprite(chart.song.stage);
		if (stageSprite != null)
		{
			add(stageSprite);
		}

		FlxG.sound.playMusic('assets/music/${chart.song.song}.ogg', 1.0, false);

		conductor = new Conductor(chart.song.bpm, chart.song.offset);
		judgement = new JudgementSystem();
		chartHandler = new ChartHandler(chart, conductor);
		noteHandler = new NoteHandler(chartHandler, conductor, judgement);
		noteHandler.spawnAheadMs = NoteRenderer.SPAWN_AHEAD_MS;

		arrowRenderer = new ArrowRenderer();
		noteRenderer = new NoteRenderer(conductor, arrowRenderer);
		characterSprites = new CharacterSpriteManager();

		var allCharacterIDs:Array<String> = [];
		var loadedCharacterIDs:Array<String> = [];

		for (section in chart.song.notes)
		{
			if (section.singers != null)
			{
				for (singerID in section.singers)
				{
					if (!allCharacterIDs.contains(singerID))
					{
						allCharacterIDs.push(singerID);
					}
				}
			}
		}

		trace('[RhythmState] Loading ${allCharacterIDs.length} unique characters');

		for (i in 0...allCharacterIDs.length)
		{
			var characterID = allCharacterIDs[i];
			trace('[RhythmState] Loading character: ${characterID}');

			var sprite = characterSprites.loadCharacter(characterID);
			if (sprite != null)
			{
				// Use the base position from the character JSON directly.
				// The xOffset override was wrong: it ignored per-character positioning data.
				var basePos = characterSprites.getBasePosition(characterID);
				characterSprites.setCharacterPosition(characterID, basePos.x, basePos.y);
				trace('[RhythmState]   Positioned at: [${basePos.x}, ${basePos.y}]');

				add(sprite);
				loadedCharacterIDs.push(characterID);
			}
		}

		characterBridge = new CharacterAnimationBridge(conductor, characterSprites);
		for (characterID in loadedCharacterIDs)
		{
			characterBridge.registerCharacter(characterID);
			trace('[RhythmState] Registered character for animations: ${characterID}');
		}

		add(arrowRenderer);
		add(noteRenderer);
		add(characterBridge);

		noteHandler.onNoteSpawn.add(onNoteSpawn);
		noteHandler.onNoteHit.add(onNoteHit);
		noteHandler.onNoteMiss.add(onNoteMiss);
		noteHandler.onGhostTap.add(onGhostTap);

		if (DevTools.ENABLED)
		{
			createDevOverlay();
		}

		if (MobileSupport.isMobile())
		{
			createTouchControls();
		}

		conductor.start();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		conductor.update();
		noteHandler.update();

		if (DevTools.ENABLED)
		{
			handleDevTools(elapsed);
			updateDevOverlay();
		}

		if (!DevTools.ENABLED || DevTools.RHYTHM_MODE == RhythmDevMode.OFF)
		{
			handleInput();
		}
		else if (DevTools.RHYTHM_MODE == RhythmDevMode.BOTPLAY)
		{
			updateBotplay();
		}

		if (FlxG.sound.music != null && !FlxG.sound.music.playing)
		{
			finishSong();
		}
	}

	private function handleDevTools(elapsed:Float):Void
	{
		if (DevTools.shiftDevChordPressed(1))
		{
			DevTools.cycleLogLevel();
		}
		else if (DevTools.devChordPressed(1))
		{
			DevTools.toggleOverlay();
		}

		if (DevTools.devChordPressed(2))
		{
			DevTools.cycleRhythmMode();
		}

		if (DevTools.devChordPressed(3))
		{
			restartChart(song);
			return;
		}

		if (DevTools.shiftDevChordPressed(4))
		{
			forceFail();
			return;
		}
		else if (DevTools.devChordPressed(4))
		{
			forceSuccess();
			return;
		}

		if (DevTools.devChordPressed(5))
		{
			DevTools.cycleChart(-1);
		}

		if (DevTools.devChordPressed(6))
		{
			DevTools.cycleChart(1);
		}

		if (DevTools.devChordPressed(7))
		{
			restartChart(DevTools.getSelectedChart());
			return;
		}

		if (DevTools.devChordPressed(8))
		{
			DevTools.adjustAutoFinishDelay(-0.25);
		}

		if (DevTools.devChordPressed(9))
		{
			DevTools.adjustAutoFinishDelay(0.25);
		}

		switch (DevTools.RHYTHM_MODE)
		{
			case AUTO_FINISH_SUCCESS:
				if (conductor.songPositionMs >= DevTools.RHYTHM_AUTO_FINISH_DELAY * 1000)
				{
					forceSuccess();
				}
			case AUTO_FINISH_FAIL:
				if (conductor.songPositionMs >= DevTools.RHYTHM_AUTO_FINISH_DELAY * 1000)
				{
					forceFail();
				}
			default:
		}
	}

	private function updateBotplay():Void
	{
		for (lane in 0...4)
		{
			if (noteHandler.isLaneSustaining(lane) && noteHandler.getTailInWindow(lane) != null)
			{
				noteHandler.onKeyRelease(lane);
			}

			if (noteHandler.getHittableNoteForLane(lane) != null)
			{
				noteHandler.onKeyPress(lane);
			}
		}
	}

	private function handleInput():Void
	{
		updateTouchInput();

		#if FLX_KEYBOARD
		if (FlxG.keys.justPressed.A) noteHandler.onKeyPress(0);
		if (FlxG.keys.justPressed.S) noteHandler.onKeyPress(1);
		if (FlxG.keys.justPressed.D) noteHandler.onKeyPress(2);
		if (FlxG.keys.justPressed.F) noteHandler.onKeyPress(3);

		if (FlxG.keys.justReleased.A) noteHandler.onKeyRelease(0);
		if (FlxG.keys.justReleased.S) noteHandler.onKeyRelease(1);
		if (FlxG.keys.justReleased.D) noteHandler.onKeyRelease(2);
		if (FlxG.keys.justReleased.F) noteHandler.onKeyRelease(3);
		#end
	}

	private function configureMobileLayout():Void
	{
		if (MobileSupport.isMobile())
		{
			ArrowRenderer.VISUAL_SCALE = 1.3;
			ArrowRenderer.LAYOUT_RADIUS = 130;
			ArrowRenderer.LAYOUT_CENTER_Y_OFFSET = -18;
			NoteRenderer.VISUAL_SCALE = 1.35;
			NoteRenderer.SPAWN_RADIUS = 330;
			return;
		}

		ArrowRenderer.VISUAL_SCALE = 1.0;
		ArrowRenderer.LAYOUT_RADIUS = 150;
		ArrowRenderer.LAYOUT_CENTER_Y_OFFSET = 50;
		NoteRenderer.VISUAL_SCALE = 1.0;
		NoteRenderer.SPAWN_RADIUS = 400;
	}

	private function createTouchControls():Void
	{
		var gap = MobileSupport.rhythmPadGap();
		var bottomMargin = MobileSupport.rhythmPadBottomMargin();
		var padHeight = MobileSupport.rhythmPadHeight();
		var sideMargin = 18.0;
		var padWidth = (FlxG.width - (sideMargin * 2) - (gap * 3)) / 4;
		var y = FlxG.height - padHeight - bottomMargin;
		var labels = ["LEFT", "DOWN", "UP", "RIGHT"];
		var colors = [
			FlxColor.fromRGB(200, 70, 70),
			FlxColor.fromRGB(80, 180, 90),
			FlxColor.fromRGB(80, 120, 220),
			FlxColor.fromRGB(220, 190, 70)
		];

		touchPads = [];
		touchPadLabels = [];
		touchLaneHeld = [false, false, false, false];

		for (lane in 0...4)
		{
			var x = sideMargin + lane * (padWidth + gap);
			var pad = new FlxSprite(x, y);
			pad.makeGraphic(Std.int(padWidth), Std.int(padHeight), colors[lane]);
			pad.scrollFactor.set(0, 0);
			pad.alpha = MobileSupport.rhythmPadIdleAlpha();
			add(pad);
			touchPads.push(pad);

			var label = new FlxText(x, y + (padHeight / 2) - 20, padWidth, labels[lane]);
			label.setFormat(null, 22, FlxColor.WHITE, "center");
			label.scrollFactor.set(0, 0);
			add(label);
			touchPadLabels.push(label);
		}
	}

	private function updateTouchInput():Void
	{
		if (!MobileSupport.isMobile() || touchPads == null || touchPads.length == 0)
		{
			return;
		}

		for (lane in 0...touchPads.length)
		{
			var isPressed = MobileSupport.pointerPressedOver(touchPads[lane]);
			if (isPressed != touchLaneHeld[lane])
			{
				if (isPressed)
				{
					noteHandler.onKeyPress(lane);
				}
				else
				{
					noteHandler.onKeyRelease(lane);
				}
			}

			touchLaneHeld[lane] = isPressed;
			touchPads[lane].alpha = isPressed ? MobileSupport.rhythmPadPressedAlpha() : MobileSupport.rhythmPadIdleAlpha();
			touchPadLabels[lane].alpha = isPressed ? 1.0 : 0.88;
		}
	}

	private function onNoteSpawn(note:Note):Void
	{
		noteRenderer.spawnNote(note);
	}

	private function onNoteHit(note:Note, rating:HitRating):Void
	{
		noteRenderer.removeNote(note);
		arrowRenderer.onNoteHit(note, rating);
		characterBridge.onNoteHit(note, rating);
	}

	private function onNoteMiss(note:Note):Void
	{
		noteRenderer.removeNote(note);
		arrowRenderer.onNoteMiss(note);
		characterBridge.onNoteMiss(note);
	}

	private function onGhostTap(lane:Int):Void
	{
		arrowRenderer.onGhostTap(lane);
	}

	private function createStageSprite(stageId:String):FlxSprite
	{
		if (stageId == null || stageId == "")
		{
			trace("[RhythmState] No stage specified in chart; skipping stage background");
			return null;
		}

		var stagePath = 'assets/images/stages/${stageId}.png';
		var sprite = new FlxSprite(0, 0);

		if (Assets.exists(stagePath))
		{
			trace('[RhythmState] Loading stage background: ${stagePath}');
			sprite.loadGraphic(stagePath);
		}
		else
		{
			trace('[RhythmState] Stage image not found at ${stagePath}, using placeholder');
			sprite.makeGraphic(FlxG.width, FlxG.height, 0xff101018);
		}

		sprite.setGraphicSize(FlxG.width, FlxG.height);
		sprite.updateHitbox();
		sprite.scrollFactor.set(0, 0);
		sprite.antialiasing = true;

		return sprite;
	}

	private function restartChart(nextSong:String):Void
	{
		DevTools.notify('Restarting rhythm chart ${nextSong}');
		var nextState = new RhythmState();
		nextState.song = nextSong;
		nextState.chartPath = 'assets/data/charts/${nextSong}.json';
		nextState.returnStateFactory = returnStateFactory;
		nextState.onComplete = onComplete;
		FlxG.switchState(() -> nextState);
	}

	private function forceSuccess():Void
	{
		DevTools.notify('Forced success for ${song}');
		finishSong({
			score: 123456,
			combo: 999,
			accuracy: 1.0,
			health: 1.0,
			completed: true
		});
	}

	private function forceFail():Void
	{
		DevTools.notify('Forced fail for ${song}');
		finishSong({
			score: 0,
			combo: 0,
			accuracy: 0.0,
			health: 0.0,
			completed: false
		});
	}

	private function finishSong(?resultOverride:Dynamic):Void
	{
		if (isFinishingSong)
		{
			return;
		}

		isFinishingSong = true;
		trace("[RhythmState] Song complete");

		var result = {
			score: 0,
			combo: 0,
			accuracy: 0.0,
			health: 1.0,
			completed: true
		};

		if (resultOverride != null)
		{
			for (field in Reflect.fields(resultOverride))
			{
				Reflect.setField(result, field, Reflect.field(resultOverride, field));
			}
		}

		if (onComplete != null)
		{
			rhythm.RhythmCompletionBridge.storeResult(result, onComplete);
			trace("[RhythmState] Stored completion callback for deferred execution");
		}

		if (returnStateFactory != null)
		{
			trace("[RhythmState] Returning to VN state (rebuilding new instance)");
			FlxG.switchState(() -> returnStateFactory());
		}
		else
		{
			trace("[RhythmState] WARNING: No returnStateFactory provided, cannot transition back to VN");
			if (onComplete != null)
			{
				onComplete(result);
			}
		}
	}

	private function createDevOverlay():Void
	{
		devOverlayBg = new FlxSprite(8, 8);
		devOverlayBg.makeGraphic(560, 166, FlxColor.fromRGB(10, 10, 10, 180));
		devOverlayBg.scrollFactor.set(0, 0);
		devOverlayBg.alpha = 0.8;
		add(devOverlayBg);

		devOverlayText = new FlxText(18, 16, 540, "");
		devOverlayText.setFormat(null, 12, FlxColor.WHITE, LEFT);
		devOverlayText.scrollFactor.set(0, 0);
		add(devOverlayText);
	}

	private function updateDevOverlay():Void
	{
		if (devOverlayText == null || devOverlayBg == null)
		{
			return;
		}

		devOverlayBg.visible = DevTools.SHOW_OVERLAY;
		devOverlayText.visible = DevTools.SHOW_OVERLAY;
		if (!DevTools.SHOW_OVERLAY)
		{
			return;
		}

		devOverlayText.text =
			'DEV RHYTHM | Song=${song} | Log=${DevTools.logLevelName(DevTools.LOG_LEVEL)} | Last=${DevTools.lastAction}\n'
			+ 'Mode=${DevTools.rhythmModeName(DevTools.RHYTHM_MODE)} | AutoFinishDelay=${DevTools.formatFloat(DevTools.RHYTHM_AUTO_FINISH_DELAY)}s | Time=${DevTools.formatFloat(conductor.songPositionMs)}ms\n'
			+ 'Selected Chart=${DevTools.getSelectedChart()} | Active Notes=${noteHandler.getActiveCount()} | Finishing=${isFinishingSong}\n'
			+ 'M+1 overlay | Shift+M+1 log | M+2 rhythm mode | M+3 restart current | M+4 success | Shift+M+4 fail\n'
			+ 'M+5/M+6 chart | M+7 load selected chart | M+8/M+9 auto-finish delay\n'
			+ 'Manual input remains active when mode=OFF. BOTPLAY auto-hits notes. AUTO_* ends the song with a forced result.';
	}
}
