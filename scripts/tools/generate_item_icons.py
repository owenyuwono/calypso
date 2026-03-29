#!/usr/bin/env python3
"""Batch generate item icons for Arcadia.

Pipeline per item:
  1. Call Gemini API for raw image (green screen background)
  2. Remove background
  3. Save final icon at 64x64

Usage:
    python3 scripts/tools/generate_item_icons.py
    python3 scripts/tools/generate_item_icons.py --only=basic_sword
    python3 scripts/tools/generate_item_icons.py --dry-run
    python3 scripts/tools/generate_item_icons.py --skip-existing
"""

import sys
import time
import argparse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from generate_icon import generate_icon

OUTPUT_DIR = Path(__file__).parent.parent.parent / "assets/textures/ui/items"

# All items from item_database.gd
ITEMS = {
    # Consumables
    "healing_potion": {"name": "Healing Potion", "type": "consumable"},
    "cooked_sardine": {"name": "Cooked Sardine", "type": "consumable"},
    "cooked_trout": {"name": "Cooked Trout", "type": "consumable"},
    "cooked_salmon": {"name": "Cooked Salmon", "type": "consumable"},
    "fish_stew": {"name": "Fish Stew", "type": "consumable"},
    "hearty_soup": {"name": "Hearty Soup", "type": "consumable"},
    "bandage": {"name": "Bandage", "type": "consumable"},
    # Swords
    "basic_sword": {"name": "Basic Sword", "type": "weapon"},
    "iron_sword": {"name": "Iron Sword", "type": "weapon"},
    "steel_sword": {"name": "Steel Sword", "type": "weapon"},
    "mithril_sword": {"name": "Mithril Sword", "type": "weapon"},
    "dragon_sword": {"name": "Dragon Sword", "type": "weapon"},
    # Axes
    "basic_axe": {"name": "Basic Axe", "type": "weapon"},
    "iron_axe": {"name": "Iron Axe", "type": "weapon"},
    "steel_axe": {"name": "Steel Axe", "type": "weapon"},
    "mithril_axe": {"name": "Mithril Axe", "type": "weapon"},
    "dragon_axe": {"name": "Dragon Axe", "type": "weapon"},
    # Maces
    "basic_mace": {"name": "Basic Mace", "type": "weapon"},
    "iron_mace": {"name": "Iron Mace", "type": "weapon"},
    "steel_mace": {"name": "Steel Mace", "type": "weapon"},
    "mithril_mace": {"name": "Mithril Mace", "type": "weapon"},
    "dragon_mace": {"name": "Dragon Mace", "type": "weapon"},
    # Daggers
    "basic_dagger": {"name": "Basic Dagger", "type": "weapon"},
    "iron_dagger": {"name": "Iron Dagger", "type": "weapon"},
    "steel_dagger": {"name": "Steel Dagger", "type": "weapon"},
    "mithril_dagger": {"name": "Mithril Dagger", "type": "weapon"},
    "dragon_dagger": {"name": "Dragon Dagger", "type": "weapon"},
    # Staves
    "basic_staff": {"name": "Basic Staff", "type": "weapon"},
    "iron_staff": {"name": "Iron Staff", "type": "weapon"},
    "steel_staff": {"name": "Steel Staff", "type": "weapon"},
    "mithril_staff": {"name": "Mithril Staff", "type": "weapon"},
    "dragon_staff": {"name": "Dragon Staff", "type": "weapon"},
    # Bows
    "basic_bow": {"name": "Basic Bow", "type": "weapon"},
    "iron_bow": {"name": "Iron Bow", "type": "weapon"},
    "steel_bow": {"name": "Steel Bow", "type": "weapon"},
    "mithril_bow": {"name": "Mithril Bow", "type": "weapon"},
    "dragon_bow": {"name": "Dragon Bow", "type": "weapon"},
    # Spears
    "basic_spear": {"name": "Basic Spear", "type": "weapon"},
    "iron_spear": {"name": "Iron Spear", "type": "weapon"},
    "steel_spear": {"name": "Steel Spear", "type": "weapon"},
    "mithril_spear": {"name": "Mithril Spear", "type": "weapon"},
    "dragon_spear": {"name": "Dragon Spear", "type": "weapon"},
    # Shields
    "basic_shield": {"name": "Basic Shield", "type": "armor"},
    "iron_shield": {"name": "Iron Shield", "type": "armor"},
    "steel_shield": {"name": "Steel Shield", "type": "armor"},
    "mithril_shield": {"name": "Mithril Shield", "type": "armor"},
    "dragon_shield": {"name": "Dragon Shield", "type": "armor"},
    # Crafted equipment
    "leather_armor": {"name": "Leather Armor", "type": "armor"},
    "bone_dagger": {"name": "Bone Dagger", "type": "weapon"},
    "copper_sword": {"name": "Copper Sword", "type": "weapon"},
    # Wood
    "log": {"name": "Log", "type": "material"},
    "oak_log": {"name": "Oak Log", "type": "material"},
    "ancient_log": {"name": "Ancient Log", "type": "material"},
    "branch": {"name": "Branch", "type": "material"},
    # Ore and stone
    "copper_ore": {"name": "Copper Ore", "type": "material"},
    "iron_ore": {"name": "Iron Ore", "type": "material"},
    "gold_ore": {"name": "Gold Ore", "type": "material"},
    "stone": {"name": "Stone", "type": "material"},
    # Monster drops
    "jelly": {"name": "Jelly", "type": "material"},
    "fur": {"name": "Fur", "type": "material"},
    "goblin_tooth": {"name": "Goblin Tooth", "type": "material"},
    "bone": {"name": "Bone", "type": "material"},
    "dark_crystal": {"name": "Dark Crystal", "type": "material"},
    # Fish
    "sardine": {"name": "Sardine", "type": "material"},
    "trout": {"name": "Trout", "type": "material"},
    "salmon": {"name": "Salmon", "type": "material"},
    # Ingots
    "copper_ingot": {"name": "Copper Ingot", "type": "material"},
    "iron_ingot": {"name": "Iron Ingot", "type": "material"},
    "gold_ingot": {"name": "Gold Ingot", "type": "material"},
}


def build_prompt(name: str, item_type: str) -> str:
    return (
        f"Game item icon on solid bright green background, "
        f"{name}, {item_type}, medieval fantasy RPG, "
        f"flat color texture, centered, no text, no labels"
    )


def main():
    parser = argparse.ArgumentParser(description="Generate item icons via Gemini API")
    parser.add_argument("--only", type=str, help="Generate only this item_id")
    parser.add_argument("--dry-run", action="store_true", help="Print prompts without calling API")
    parser.add_argument("--skip-existing", action="store_true", help="Skip items with existing icons")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    items = ITEMS
    if args.only:
        if args.only not in ITEMS:
            print(f"Unknown item_id: {args.only}")
            print(f"Available: {', '.join(sorted(ITEMS.keys()))}")
            sys.exit(1)
        items = {args.only: ITEMS[args.only]}

    total = len(items)
    for i, (item_id, data) in enumerate(items.items(), 1):
        output_path = OUTPUT_DIR / f"{item_id}.png"

        if args.skip_existing and output_path.exists():
            print(f"[{i}/{total}] Skipping {item_id} (exists)")
            continue

        prompt = build_prompt(data["name"], data["type"])

        if args.dry_run:
            print(f"[{i}/{total}] {item_id}: {prompt}")
            print(f"         -> {output_path}")
            continue

        print(f"[{i}/{total}] Generating {item_id}...")
        try:
            generate_icon(prompt, str(output_path), size="64x64", bg_remove=True)
        except SystemExit:
            print(f"  Failed to generate {item_id}, continuing...")
            continue

        if i < total:
            time.sleep(1)

    print("Done!")


if __name__ == "__main__":
    main()
