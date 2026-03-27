package states;

import core.audio.AudioSystem;
import core.dialogue.ChoiceSystem;
import core.dialogue.DialogueSystem;
import core.effects.EffectSystem;
import core.rendering.BackgroundSystem;
import core.rendering.CharacterSystem;
import core.scene.SceneRunner;
import core.state.GameState;
import dev.DevTools;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import rhythm.RhythmCompletionBridge;
import ui.DialogueHistory;
import ui.PauseOverlay;
import util.MobileSupport;
import vn.RhythmBridge;
import vn.VNCommands;
import vn.VNConfig;
import vn.VNReturnContext;

class VNState extends FlxState
{
	public var bgGroup:FlxSpriteGroup;
	public var charGroup:FlxGroup;
	public var uiGroup:FlxGroup;
	public var runner:SceneRunner;

	private var scenePath:String;
	private var defaultBGM:String;
	private var startNodeOverride:String;

	private var pauseOverlay:PauseOverlay;
	private var pauseButton:FlxSprite;
	private var dialogueHistory:DialogueHistory;

	private var devOverlayBg:FlxSprite;
	private var devOverlayText:FlxText;
	private var devNodeSelectionIndex:Int = 0;
	private var devFastForwardCooldown:Float = 0;

	public function new(scenePath:String = "scenes/act1/scene1.json", ?defaultBGM:String, ?startNode:String)
	{
		super();
		this.scenePath = scenePath;
		this.defaultBGM = defaultBGM;
		this.startNodeOverride = startNode;
	}

	override public function create():Void
	{
		super.create();

		#if FLX_MOUSE
		FlxG.mouse.visible = !MobileSupport.isMobile();
		#end

		var returnContext:VNReturnContext = null;
		if (VNReturnContext.hasPending())
		{
			trace('[VNState] Detected return from rhythm gameplay');
			returnContext = VNReturnContext.consume();
		}

		var sceneToLoad:String;
		var resumeNode:String = null;

		if (returnContext != null)
		{
			sceneToLoad = returnContext.scenePath;
			resumeNode = returnContext.resumeNodeId;
			trace('[VNState] Resuming scene: ${sceneToLoad} at node: ${resumeNode}');
		}
		else
		{
			sceneToLoad = scenePath;
			resumeNode = startNodeOverride;
			trace('[VNState] Starting new scene: ${sceneToLoad}');
			if (resumeNode != null)
			{
				trace('[VNState] Applying explicit start node: ${resumeNode}');
			}
		}

		// Initialize or update GameState
		var gameState = GameState.get();
		gameState.currentScene = sceneToLoad;

		runner = new SceneRunner(sceneToLoad);
		if (resumeNode != null)
		{
			runner.currentNode = resumeNode;
			trace('[VNState] SceneRunner positioned at resume node: ${resumeNode}');
		}

		gameState.currentNode = runner.currentNode;

		BackgroundSystem.reset();
		VNCommands.setVNState(this);

		bgGroup = new FlxSpriteGroup();
		add(bgGroup);

		BackgroundSystem.init(bgGroup);

		var debugBG = new FlxSprite(0, 0);
		debugBG.makeGraphic(FlxG.width, FlxG.height, 0xff111111);
		debugBG.scrollFactor.set(0, 0);
		bgGroup.add(debugBG);

		charGroup = new FlxGroup();
		add(charGroup);

		var charDefsMap = VNConfig.loadCharacterDefs();
		var charDefs:Array<Dynamic> = [];
		for (key in charDefsMap.keys())
		{
			charDefs.push(charDefsMap.get(key));
		}

		CharacterSystem.init(charGroup, charDefs);
		runner.loadPlacementFile();

		uiGroup = new FlxGroup();
		add(uiGroup);

		DialogueSystem.init(uiGroup);
		ChoiceSystem.init(uiGroup);
		EffectSystem.init(uiGroup);
		AudioSystem.init();

		if (defaultBGM != null && defaultBGM != "")
		{
			AudioSystem.setDefaultBGM(defaultBGM, 0.7);
		}

		if (DevTools.ENABLED)
		{
			DialogueSystem.setAutoAdvance(DevTools.DIALOGUE_AUTO_ADVANCE);
			ChoiceSystem.debugAuto = DevTools.AUTO_PICK_FIRST_CHOICE;
			createDevOverlay();
			syncSelectedNodeToCurrent();
		}

		// Dialogue history overlay
		dialogueHistory = new DialogueHistory();
		add(dialogueHistory);

		// Pause overlay (must be added last to render on top)
		pauseOverlay = new PauseOverlay(this);
		add(pauseOverlay);

		// Mobile pause button
		if (MobileSupport.isMobile())
		{
			pauseButton = new FlxSprite(FlxG.width - 52, 12);
			pauseButton.makeGraphic(40, 40, FlxColor.fromRGBFloat(0.1, 0.07, 0.18, 0.7));
			pauseButton.scrollFactor.set(0, 0);
			add(pauseButton);
		}

		if (RhythmCompletionBridge.hasPendingCallback())
		{
			trace('[VNState] Executing pending rhythm completion callback');
			RhythmCompletionBridge.executePendingCallback();
			trace('[VNState] Rhythm callback executed successfully');
		}

		runner.next();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Pause toggle: ESC key or mobile pause button
		#if FLX_KEYBOARD
		if (FlxG.keys.justPressed.ESCAPE)
		{
			pauseOverlay.toggle();
		}
		#end

		if (pauseButton != null && MobileSupport.pointerJustPressedOver(pauseButton))
		{
			pauseOverlay.toggle();
		}

		// Dialogue history toggle (H key)
		#if FLX_KEYBOARD
		if (FlxG.keys.justPressed.H && !pauseOverlay.isPaused)
		{
			dialogueHistory.toggle();
		}
		#end

		// When dialogue history is open, only update it
		if (dialogueHistory.isOpen)
		{
			dialogueHistory.update(elapsed);
			return;
		}

		// When paused, only update the pause overlay
		if (pauseOverlay.isPaused)
		{
			pauseOverlay.update(elapsed);
			return;
		}

		// Track playtime
		GameState.get().playtime += elapsed;

		if (runner != null)
		{
			runner.update();
		}

		ChoiceSystem.update();
		DialogueSystem.update(elapsed);

		if (DevTools.ENABLED)
		{
			handleDevTools(elapsed);
			updateDevOverlay();
		}

		DialogueSystem.handleInput();
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
			DevTools.DIALOGUE_AUTO_ADVANCE = !DevTools.DIALOGUE_AUTO_ADVANCE;
			DialogueSystem.setAutoAdvance(DevTools.DIALOGUE_AUTO_ADVANCE);
			DevTools.notify('Dialogue auto-advance ${DevTools.DIALOGUE_AUTO_ADVANCE ? "enabled" : "disabled"}');
		}

		if (DevTools.devChordPressed(3))
		{
			DevTools.STORY_FAST_FORWARD = !DevTools.STORY_FAST_FORWARD;
			DevTools.notify('Story fast-forward ${DevTools.STORY_FAST_FORWARD ? "enabled" : "disabled"}');
		}

		if (DevTools.devChordPressed(4))
		{
			DevTools.AUTO_PICK_FIRST_CHOICE = !DevTools.AUTO_PICK_FIRST_CHOICE;
			ChoiceSystem.debugAuto = DevTools.AUTO_PICK_FIRST_CHOICE;
			DevTools.notify('Auto-pick first choice ${DevTools.AUTO_PICK_FIRST_CHOICE ? "enabled" : "disabled"}');
		}

		if (DevTools.shiftDevChordPressed(5))
		{
			reloadScene(runner.getScenePath(), runner.currentNode);
			return;
		}

		if (DevTools.devChordPressed(5))
		{
			reloadScene(runner.getScenePath(), null);
			return;
		}

		if (DevTools.shiftDevChordPressed(6))
		{
			DevTools.cycleRhythmMode();
		}

		if (DevTools.devChordPressed(6))
		{
			launchSelectedChart();
			return;
		}

		if (DevTools.devChordPressed(7))
		{
			changeSelectedNode(-1);
		}

		if (DevTools.devChordPressed(8))
		{
			changeSelectedNode(1);
		}

		if (DevTools.devChordPressed(9))
		{
			jumpToSelectedNode();
			return;
		}

		if (DevTools.shiftDevChordPressed(7))
		{
			DevTools.cycleScene(-1);
		}

		if (DevTools.shiftDevChordPressed(8))
		{
			DevTools.cycleScene(1);
		}

		if (DevTools.shiftDevChordPressed(9))
		{
			DevTools.cycleChart(-1);
		}

		if (DevTools.shiftDevChordPressed(0))
		{
			DevTools.cycleChart(1);
		}

		if (DevTools.devChordPressed(0))
		{
			reloadScene(DevTools.getSelectedScene(), null);
			return;
		}

		handleChoiceHotkeys();
		updateFastForward(elapsed);
	}

	private function handleChoiceHotkeys():Void
	{
		#if FLX_KEYBOARD
		if (!FlxG.keys.pressed.CONTROL || !ChoiceSystem.hasActiveChoices())
		{
			return;
		}

		var selectedIndex = -1;
		if (FlxG.keys.justPressed.ONE) selectedIndex = 0;
		if (FlxG.keys.justPressed.TWO) selectedIndex = 1;
		if (FlxG.keys.justPressed.THREE) selectedIndex = 2;
		if (FlxG.keys.justPressed.FOUR) selectedIndex = 3;
		if (FlxG.keys.justPressed.FIVE) selectedIndex = 4;
		if (FlxG.keys.justPressed.SIX) selectedIndex = 5;
		if (FlxG.keys.justPressed.SEVEN) selectedIndex = 6;
		if (FlxG.keys.justPressed.EIGHT) selectedIndex = 7;
		if (FlxG.keys.justPressed.NINE) selectedIndex = 8;

		if (selectedIndex >= 0 && ChoiceSystem.selectChoice(selectedIndex))
		{
			DevTools.notify('Picked choice ${selectedIndex + 1}');
		}
		#end
	}

	private function updateFastForward(elapsed:Float):Void
	{
		if (!DevTools.STORY_FAST_FORWARD)
		{
			devFastForwardCooldown = 0;
			return;
		}

		devFastForwardCooldown -= elapsed;
		if (devFastForwardCooldown > 0)
		{
			return;
		}

		if (ChoiceSystem.hasActiveChoices())
		{
			ChoiceSystem.selectChoice(0);
			devFastForwardCooldown = 0.08;
			return;
		}

		if (DialogueSystem.isVisible())
		{
			DialogueSystem.forceAdvance();
			devFastForwardCooldown = 0.05;
			return;
		}

		if (runner != null)
		{
			runner.next();
			devFastForwardCooldown = 0.05;
		}
	}

	private function reloadScene(path:String, ?node:String):Void
	{
		ChoiceSystem.clear();
		DialogueSystem.hide();
		VNReturnContext.clear();
		RhythmCompletionBridge.clear();
		DevTools.notify('Reloading ${path}${node != null ? " at " + node : ""}');
		FlxG.switchState(() -> new VNState(path, defaultBGM, node));
	}

	private function launchSelectedChart():Void
	{
		var chartId = DevTools.getSelectedChart();
		var resumeNode = getDevRhythmResumeNode();
		VNReturnContext.store(runner.getScenePath(), resumeNode);
		DevTools.notify('Launching chart ${chartId}, resume at ${resumeNode}');
		RhythmBridge.start(chartId, this, (result) -> {
			trace('[VNState][Dev] Rhythm sandbox completed=${result.completed} score=${result.score} combo=${result.combo}');
		});
	}

	private function getDevRhythmResumeNode():String
	{
		if (runner == null)
		{
			return startNodeOverride != null ? startNodeOverride : "n1";
		}

		var node = runner.parser.getNode(runner.currentNode);
		if (node != null && Reflect.hasField(node, "next") && Reflect.field(node, "next") != null)
		{
			return Reflect.field(node, "next");
		}

		return runner.currentNode;
	}

	private function syncSelectedNodeToCurrent():Void
	{
		if (runner == null || runner.parser == null || runner.parser.nodeOrder == null)
		{
			devNodeSelectionIndex = 0;
			return;
		}

		var index = runner.parser.nodeOrder.indexOf(runner.currentNode);
		devNodeSelectionIndex = index >= 0 ? index : 0;
	}

	private function changeSelectedNode(delta:Int):Void
	{
		if (runner == null || runner.parser.nodeOrder.length == 0)
		{
			return;
		}

		devNodeSelectionIndex += delta;
		if (devNodeSelectionIndex < 0)
		{
			devNodeSelectionIndex = runner.parser.nodeOrder.length - 1;
		}
		else if (devNodeSelectionIndex >= runner.parser.nodeOrder.length)
		{
			devNodeSelectionIndex = 0;
		}

		DevTools.notify('Selected node ${getSelectedNodeId()}');
	}

	private function getSelectedNodeId():String
	{
		if (runner == null || runner.parser.nodeOrder.length == 0)
		{
			return "(none)";
		}

		return runner.parser.nodeOrder[devNodeSelectionIndex];
	}

	private function jumpToSelectedNode():Void
	{
		var targetNode = getSelectedNodeId();
		if (targetNode == "(none)")
		{
			return;
		}

		reloadScene(runner.getScenePath(), targetNode);
	}

	private function createDevOverlay():Void
	{
		devOverlayBg = new FlxSprite(8, 8);
		devOverlayBg.makeGraphic(620, 244, FlxColor.fromRGB(10, 10, 10, 180));
		devOverlayBg.scrollFactor.set(0, 0);
		devOverlayBg.alpha = 0.8;
		uiGroup.add(devOverlayBg);

		devOverlayText = new FlxText(18, 16, 600, "");
		devOverlayText.setFormat(null, 12, FlxColor.WHITE, LEFT);
		devOverlayText.scrollFactor.set(0, 0);
		uiGroup.add(devOverlayText);
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

		var currentNode = runner != null ? runner.currentNode : "(none)";
		var currentNodeType = runner != null ? runner.parser.getNode(currentNode).type : "(none)";
		var selectedNode = getSelectedNodeId();
		var choiceLabels = ChoiceSystem.getChoiceLabels();
		var choiceSummary = choiceLabels.length > 0 ? choiceLabels.join(" | ") : "(no active choices)";

		devOverlayText.text =
			'DEV MODE | Log=${DevTools.logLevelName(DevTools.LOG_LEVEL)} | Last=${DevTools.lastAction}\n'
			+ 'Scene=${runner != null ? runner.getScenePath() : "(none)"} | Current=${currentNode} (${currentNodeType}) | Selected=${selectedNode}\n'
			+ 'Selected Scene=${DevTools.shortScene(DevTools.getSelectedScene())} | Selected Chart=${DevTools.getSelectedChart()} | Rhythm=${DevTools.rhythmModeName(DevTools.RHYTHM_MODE)}\n'
			+ 'AutoAdvance=${DevTools.DIALOGUE_AUTO_ADVANCE} | FastForward=${DevTools.STORY_FAST_FORWARD} | AutoChoice=${DevTools.AUTO_PICK_FIRST_CHOICE}\n'
			+ 'Choices=${choiceSummary}\n'
			+ 'M+1 overlay | Shift+M+1 log | M+2 auto-advance | M+3 fast-forward | M+4 auto-choice\n'
			+ 'M+5 restart scene | Shift+M+5 reload node | M+6 launch chart | Shift+M+6 rhythm mode\n'
			+ 'M+7/M+8 node select | M+9 jump node | Shift+M+7/8 scene | Shift+M+9/0 chart | M+0 load selected scene | Ctrl+1..9 pick choice';
	}
}
