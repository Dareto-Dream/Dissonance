"""Shared data loading helpers for Dissonance editor modules."""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List

BASE_TEXT_EFFECTS: List[Dict[str, Any]] = [
    {
        "name": "shake",
        "params": {"effect_intensity": 2.0},
        "description": "Random jitter for anxious or intense dialogue.",
    },
    {
        "name": "glitch",
        "params": {"effect_intensity": 5.0},
        "description": "Corrupted movement and chromatic offsets.",
    },
    {
        "name": "wave",
        "params": {"effect_speed": 3.0, "effect_amplitude": 5.0},
        "description": "Sine wave motion for ethereal voices.",
    },
    {
        "name": "rainbow",
        "params": {"effect_speed": 2.0},
        "description": "Color cycling for magical emphasis.",
    },
    {
        "name": "fade",
        "params": {"effect_speed": 2.0},
        "description": "Alpha pulsing for ghosts or whispers.",
    },
    {
        "name": "typewriter",
        "params": {"effect_speed": 30.0},
        "description": "Character-by-character reveal for terminals.",
    },
]


def _bot_context_dir(project_root: Path) -> Path:
    project_root = Path(project_root)
    candidates = [
        project_root / "bot_context",
        Path(__file__).resolve().parents[2] / "bot_context",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0]


def _load_json(path: Path, default: Any) -> Any:
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        return default
    except json.JSONDecodeError as exc:
        print(f"Failed to parse {path}: {exc}")
        return default


@lru_cache(maxsize=1)
def load_characters(project_root: Path) -> Dict[str, Any]:
    ctx = _bot_context_dir(project_root)
    return _load_json(ctx / "characters.json", {})


@lru_cache(maxsize=1)
def load_pose_catalog(project_root: Path) -> Dict[str, Any]:
    ctx = _bot_context_dir(project_root)
    data = _load_json(ctx / "poses.json", {})
    character = data.get("character", "unknown")
    poses = data.get("poses", {})
    return {"character": character, "poses": poses, "config": data.get("config", {})}


@lru_cache(maxsize=2)
def load_scene_demo(project_root: Path) -> Dict[str, Any]:
    ctx = _bot_context_dir(project_root)
    return _load_json(ctx / "demo.json", {})


@lru_cache(maxsize=2)
def load_scene_template(project_root: Path) -> Dict[str, Any]:
    ctx = _bot_context_dir(project_root)
    return _load_json(ctx / "template.json", {})


def list_text_effects() -> List[Dict[str, Any]]:
    return [dict(effect) for effect in BASE_TEXT_EFFECTS]


def ensure_export_dir(project_root: Path, folder_name: str) -> Path:
    target = Path(project_root) / "exports" / folder_name
    target.mkdir(parents=True, exist_ok=True)
    return target
