#!/usr/bin/env python3
"""Batch generate all 15 skill icons for Arcadia.

Pipeline per skill:
  1. Generate category base (PIL, once per category)
  2. Call Gemini API for raw skill image (green screen)
  3. Remove green background
  4. Composite transparent subject onto category base
  5. Save final icon

Usage:
    python3 scripts/tools/generate_skill_icons.py
    python3 scripts/tools/generate_skill_icons.py --skip-generate
    python3 scripts/tools/generate_skill_icons.py --only=bash
    python3 scripts/tools/generate_skill_icons.py --dry-run
"""

import sys
import math
import time
import argparse
from pathlib import Path
from io import BytesIO

# Allow importing from sibling generate_icon.py
sys.path.insert(0, str(Path(__file__).parent))
from generate_icon import generate_icon, remove_background

from PIL import Image, ImageDraw, ImageFilter

# ---------------------------------------------------------------------------
# Output paths
# ---------------------------------------------------------------------------
ASSET_ROOT = Path(__file__).parent.parent.parent / "assets/textures/ui/skills"
FINAL_DIR = ASSET_ROOT
BASES_DIR = ASSET_ROOT / "bases"
RAW_DIR = ASSET_ROOT / "raw"
SUBJECTS_DIR = ASSET_ROOT / "subjects"

# ---------------------------------------------------------------------------
# Category definitions
# ---------------------------------------------------------------------------
# Each category has: display name, base color (RGB), and a darkened palette
CATEGORIES = {
    "single_physical": (200, 60, 60),
    "single_magic":    (60, 160, 180),
    "aoe_physical":    (220, 140, 40),
    "aoe_magic":       (160, 60, 200),
    "dot_physical":    (140, 30, 50),
    "dot_magic":       (100, 30, 130),
}

# ---------------------------------------------------------------------------
# Skill definitions
# ---------------------------------------------------------------------------
PROMPT_TEMPLATE = (
    "RPG skill icon, {description}, "
    "gold metallic tint, simple clean silhouette, subtle shading, "
    "monochrome gold, emblem style, "
    "no text, no letters, no frame, no border, no medallion, no oval, "
    "no circle background, no badge, "
    "just the object floating on plain bright green background, centered"
)

# (skill_id, category, description, bg_removal_tolerance)
SKILLS = [
    # single_physical
    ("bash",      "single_physical", "A sword striking downward with a small impact star at the tip", 40),
    ("chop",      "single_physical", "An axe mid-chop with a small downward motion line", 40),
    ("crush",     "single_physical", "A mace head with small impact rings below it", 40),
    ("stab",      "single_physical", "A dagger pointing forward with small speed lines", 30),
    ("execute",   "single_physical", "An axe blade over a cracked shield", 40),
    ("shatter",   "single_physical", "A mace with fragments breaking apart around it", 40),
    ("backstab",  "single_physical", "A dagger emerging from a shadow crescent", 40),
    # single_magic
    ("arcane_bolt", "single_magic", "A glowing orb with a small spark trail", 40),
    # aoe_physical
    ("cleave",    "aoe_physical",   "A sword with a wide curved slash arc", 40),
    ("whirlwind", "aoe_physical",   "An axe surrounded by a circular wind spiral", 40),
    ("quake",     "aoe_physical",   "A mace above cracked ground with ring lines", 40),
    # aoe_magic
    ("flame_burst", "aoe_magic",   "A fireball with radiating flame petals", 40),
    # dot_physical
    ("rend",      "dot_physical",  "Three diagonal claw slash marks", 40),
    ("lacerate",  "dot_physical",  "Two crossing slash marks forming an X", 40),
    # dot_magic
    ("drain",     "dot_magic",     "Spiral tendrils converging to a center point", 40),
    # single_physical (bow/spear)
    ("aimed_shot",     "single_physical", "A bow with a single arrow drawn back, small targeting crosshair at the arrowhead", 40),
    ("piercing_arrow", "single_physical", "An arrow piercing cleanly through a metal plate", 40),
    ("thrust",         "single_physical", "A spear tip thrusting forward with small speed lines", 40),
    # aoe_physical (bow/spear)
    ("volley",         "aoe_physical",    "Multiple arrows raining downward in a spread pattern", 40),
    ("sweep",          "aoe_physical",    "A spear sweeping in a wide horizontal arc with a motion trail", 40),
    # dot_physical (spear)
    ("impale",         "dot_physical",    "A spear tip embedded deep with small blood drops dripping", 40),
]

# ---------------------------------------------------------------------------
# Base image generation
# ---------------------------------------------------------------------------

def _darken(color: tuple, factor: float) -> tuple:
    """Scale an RGB tuple by factor (0.0–1.0)."""
    return tuple(int(c * factor) for c in color)



def _apply_rounded_mask(img: Image.Image, radius: int = 50) -> Image.Image:
    """Apply rounded corner mask to an RGBA image."""
    size = img.size[0]
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    r_ch, g_ch, b_ch, a_ch = img.split()
    # Intersect existing alpha with rounded mask
    from PIL import ImageChops
    a_ch = ImageChops.multiply(a_ch, mask)
    return Image.merge("RGBA", (r_ch, g_ch, b_ch, a_ch))


def generate_base_fast(category: str, color: tuple, size: int = 512) -> Image.Image:
    """Faster base generation using PIL ImageDraw gradients and numpy-free approach."""
    import random
    from PIL import ImageChops

    img = Image.new("RGBA", (size, size), (0, 0, 0, 255))

    cx, cy = size // 2, size // 2
    max_radius = math.sqrt(cx ** 2 + cy ** 2)

    # Build gradient + vignette in one pass
    pixels = img.load()
    center_brightness = 0.40
    edge_brightness = 0.20

    for y in range(size):
        for x in range(size):
            dist = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
            t = min(dist / max_radius, 1.0)
            # radial gradient brightness
            brightness = center_brightness * (1 - t) + edge_brightness * t
            # vignette darkening (smoothstep)
            t_smooth = t * t * (3 - 2 * t)
            vig_factor = 1.0 - (t_smooth * 0.47)
            final = brightness * vig_factor
            r = int(color[0] * final)
            g = int(color[1] * final)
            b = int(color[2] * final)
            pixels[x, y] = (r, g, b, 255)

    # Subtle noise texture overlay — fixed seed per category for consistency
    # Opacity ~10%: breaks up smooth gradient, gives gritty/painted feel
    noise_opacity = 0.10
    category_seed = hash(category) & 0xFFFFFFFF
    rng = random.Random(category_seed)
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixels[x, y]
            noise = rng.randint(-128, 128)
            delta = int(noise * noise_opacity)
            r = max(0, min(255, r + delta))
            g = max(0, min(255, g + delta))
            b = max(0, min(255, b + delta))
            pixels[x, y] = (r, g, b, a)

    # Bevel effect — apply before rounding so transparent corners aren't affected
    # Top + left edges: highlight (brighter); bottom + right edges: shadow (darker)
    bevel_width = 15
    bevel_highlight = 40   # added to RGB on bright edges
    bevel_shadow = 40      # subtracted from RGB on dark edges

    pixels = img.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixels[x, y]
            # Distance from each edge
            d_top    = y
            d_left   = x
            d_bottom = size - 1 - y
            d_right  = size - 1 - x

            # Compute highlight/shadow strengths as linear gradients (0.0–1.0)
            top_str    = max(0.0, 1.0 - d_top    / bevel_width)
            left_str   = max(0.0, 1.0 - d_left   / bevel_width)
            bottom_str = max(0.0, 1.0 - d_bottom / bevel_width)
            right_str  = max(0.0, 1.0 - d_right  / bevel_width)

            highlight_str = max(top_str, left_str)
            shadow_str    = max(bottom_str, right_str)

            # Highlights and shadows cancel each other at corners — highlight wins
            if highlight_str > 0 and shadow_str > 0:
                shadow_str = 0.0

            delta = int(highlight_str * bevel_highlight) - int(shadow_str * bevel_shadow)
            r = max(0, min(255, r + delta))
            g = max(0, min(255, g + delta))
            b = max(0, min(255, b + delta))
            pixels[x, y] = (r, g, b, a)

    # Thin specular highlight line: 1px bright strip along top-left edge
    pixels = img.load()
    specular_strength = 80
    for i in range(size):
        # Top edge (y=0)
        r, g, b, a = pixels[i, 0]
        pixels[i, 0] = (min(255, r + specular_strength),
                        min(255, g + specular_strength),
                        min(255, b + specular_strength), a)
        # Left edge (x=0), skip corner already done
        if i > 0:
            r, g, b, a = pixels[0, i]
            pixels[0, i] = (min(255, r + specular_strength),
                            min(255, g + specular_strength),
                            min(255, b + specular_strength), a)

    # Rounded corners — more pronounced (80px radius on 512px image)
    img = _apply_rounded_mask(img, radius=80)
    return img


# ---------------------------------------------------------------------------
# Green background removal (skill icons)
# ---------------------------------------------------------------------------

def remove_green_background(img: Image.Image) -> Image.Image:
    """Remove a green-screen background from a skill icon.

    Handles non-flat green backgrounds (rounded rects, gradient shading) and
    cleans up white corners outside the green area.  Four passes:

    Pass 1 — zero alpha on all green-dominant and near-white pixels.
    Pass 2 — edge cleanup: semi-transparent pixels that still carry a green
              tint get their alpha reduced proportionally.
    Pass 3 — despill: surviving opaque pixels whose green channel is slightly
              above the R/B average get it pulled back toward that average.
    """
    img = img.copy().convert("RGBA")
    pixels = img.load()
    width, height = img.size

    # --- Pass 1: kill green-dominant and white/light pixels ---
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]

            # Bright/strong green (covers bright lime to darker greens)
            if g > r + 30 and g > b + 30 and g > 80:
                pixels[x, y] = (r, g, b, 0)
                continue

            # Near-green (softer threshold for mid-tones at edges)
            if g > r and g > b and g > 60 and (g - max(r, b)) > 15:
                pixels[x, y] = (r, g, b, 0)
                continue

            # White / near-white background outside the green rect
            if r > 230 and g > 230 and b > 230:
                pixels[x, y] = (r, g, b, 0)

    # --- Pass 2: edge cleanup — partially transparent green-tinted pixels ---
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue

            # Check if any 4-connected neighbour is transparent (i.e. we're on an edge)
            is_edge = False
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    if pixels[nx, ny][3] == 0:
                        is_edge = True
                        break

            if is_edge:
                rb_avg = (r + b) / 2.0
                green_excess = g - rb_avg
                if green_excess > 10:
                    # Reduce alpha proportionally to how green the pixel is
                    scale = max(0.0, 1.0 - green_excess / 80.0)
                    a = max(0, int(a * scale))
                    pixels[x, y] = (r, g, b, a)

    # --- Pass 3: despill surviving opaque pixels ---
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue

            rb_avg = (r + b) / 2.0
            green_excess = g - rb_avg

            if green_excess > 20:
                pull = min(green_excess - 20, green_excess * 0.8)
                g = max(0, int(g - pull))
                pixels[x, y] = (r, g, b, a)

    return img


def despill_green(img: Image.Image) -> Image.Image:
    """Legacy despill — kept for use by other callers (e.g. generate_icon.py).

    Skill icons use remove_green_background() instead.
    """
    img = img.copy()
    pixels = img.load()
    width, height = img.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue

            rb_avg = (r + b) / 2.0
            green_excess = g - rb_avg

            if green_excess > 20:
                pull = min(green_excess - 20, green_excess * 0.8)
                g = max(0, int(g - pull))

            if 1 <= a <= 200 and g > rb_avg + 15:
                a = max(0, int(a * 0.6))

            pixels[x, y] = (r, g, b, a)

    return img


# ---------------------------------------------------------------------------
# Compositing
# ---------------------------------------------------------------------------

COMPOSITE_MARGIN = 10   # px padding around content bbox
CONTENT_FILL = 0.80     # subject fills 80% of the 512×512 base


def composite_onto_base(subject: Image.Image, base: Image.Image) -> Image.Image:
    """Scale and center the bg-removed subject onto base, return final RGBA image."""
    size = base.size[0]  # assumes square

    # Get bounding box of non-transparent pixels
    bbox = subject.getbbox()
    if bbox is None:
        # Fully transparent — return base unchanged
        return base.copy()

    # Crop to content with margin
    x0 = max(bbox[0] - COMPOSITE_MARGIN, 0)
    y0 = max(bbox[1] - COMPOSITE_MARGIN, 0)
    x1 = min(bbox[2] + COMPOSITE_MARGIN, subject.width)
    y1 = min(bbox[3] + COMPOSITE_MARGIN, subject.height)
    cropped = subject.crop((x0, y0, x1, y1))

    # Scale to fit within CONTENT_FILL of the base, preserving aspect ratio.
    # Scale is driven by the larger dimension so neither axis overflows.
    cw, ch = cropped.size
    target_dim = int(size * CONTENT_FILL)
    scale = target_dim / max(cw, ch)
    new_w = int(cw * scale)
    new_h = int(ch * scale)
    scaled = cropped.resize((new_w, new_h), Image.LANCZOS)

    # Center on base
    paste_x = (size - new_w) // 2
    paste_y = (size - new_h) // 2

    result = base.copy()
    result.alpha_composite(scaled, dest=(paste_x, paste_y))
    return result


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def ensure_dirs():
    for d in (FINAL_DIR, BASES_DIR, RAW_DIR, SUBJECTS_DIR):
        d.mkdir(parents=True, exist_ok=True)


def get_base_path(category: str) -> Path:
    return BASES_DIR / f"{category}_base.png"


def get_raw_path(skill_id: str) -> Path:
    return RAW_DIR / f"{skill_id}_raw.png"


def get_subject_path(skill_id: str) -> Path:
    return SUBJECTS_DIR / f"{skill_id}.png"


def get_final_path(skill_id: str) -> Path:
    return FINAL_DIR / f"{skill_id}.png"


def build_prompt(description: str) -> str:
    return PROMPT_TEMPLATE.format(description=description)


def generate_all_bases(dry_run: bool = False):
    """Generate all category base images."""
    for category, color in CATEGORIES.items():
        out_path = get_base_path(category)
        if dry_run:
            print(f"  [base] {out_path} (color={color})")
            continue
        if out_path.exists():
            print(f"  [base] skip (exists): {out_path}")
            continue
        print(f"  [base] generating: {category}...")
        img = generate_base_fast(category, color)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        img.save(str(out_path), "PNG")
        print(f"  [base] saved: {out_path}")


def process_skill(skill_id: str, category: str, description: str, tolerance: int,
                  skip_generate: bool, dry_run: bool):
    prompt = build_prompt(description)
    raw_path = get_raw_path(skill_id)
    subject_path = get_subject_path(skill_id)
    final_path = get_final_path(skill_id)
    base_path = get_base_path(category)

    if dry_run:
        print(f"\n[{skill_id}]")
        print(f"  category : {category}")
        print(f"  tolerance: {tolerance}")
        print(f"  prompt   : {prompt}")
        print(f"  raw      : {raw_path}")
        print(f"  subject  : {subject_path}")
        print(f"  final    : {final_path}")
        return

    print(f"\n[{skill_id}] processing...")

    # Step 1: Generate raw image from Gemini (unless skipping)
    if not skip_generate:
        if raw_path.exists():
            print(f"  [generate] skip (exists): {raw_path}")
        else:
            print(f"  [generate] calling Gemini API...")
            # generate_icon handles raw save; we want 512x512 with no bg removal
            try:
                generate_icon(prompt, str(raw_path), size="512x512", bg_remove=False)
            except SystemExit:
                print(f"  [FAILED] API call failed for {skill_id}, skipping")
                return
            print(f"  [generate] saved raw: {raw_path}")
            time.sleep(2)  # rate limit
    else:
        if not raw_path.exists():
            print(f"  [generate] WARNING: raw file missing, skipping: {raw_path}")
            return

    # Step 2: Remove background + despill
    print(f"  [bg-remove] green-dominant keying...")
    raw_img = Image.open(str(raw_path)).convert("RGBA")
    subject_img = remove_green_background(raw_img)
    subject_path.parent.mkdir(parents=True, exist_ok=True)
    subject_img.save(str(subject_path), "PNG")
    print(f"  [bg-remove] saved subject: {subject_path}")

    # Step 3: Load base
    if not base_path.exists():
        print(f"  [composite] ERROR: base not found: {base_path}")
        return
    base_img = Image.open(str(base_path)).convert("RGBA")

    # Backstab uses a dark shadow icon — brighten its base copy for contrast
    if skill_id == "backstab":
        from PIL import ImageEnhance
        base_img = ImageEnhance.Brightness(base_img).enhance(1.4)

    # Step 4: Composite
    print(f"  [composite] compositing onto {category} base...")
    final_img = composite_onto_base(subject_img, base_img)
    final_path.parent.mkdir(parents=True, exist_ok=True)
    final_img.save(str(final_path), "PNG")
    print(f"  [composite] saved final: {final_path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--skip-generate", action="store_true",
                        help="Reuse existing raw images, only re-composite")
    parser.add_argument("--only", metavar="SKILL_ID",
                        help="Generate a single skill only (e.g. --only=bash)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print prompts and paths without calling the API")
    args = parser.parse_args()

    if not args.dry_run:
        ensure_dirs()

    # Filter skills if --only specified
    skills_to_run = SKILLS
    if args.only:
        skills_to_run = [s for s in SKILLS if s[0] == args.only]
        if not skills_to_run:
            print(f"ERROR: unknown skill '{args.only}'. Valid IDs: {[s[0] for s in SKILLS]}")
            sys.exit(1)

    if args.dry_run:
        print("=== DRY RUN — no API calls will be made ===\n")
        print("Category bases:")
        for category, color in CATEGORIES.items():
            print(f"  {get_base_path(category)}  (color={color})")
        print(f"\nSkills ({len(skills_to_run)}):")
    else:
        # Always regenerate bases (idempotent — skips if exists)
        print("=== Generating category bases ===")
        generate_all_bases(dry_run=False)

    for skill_id, category, description, tolerance in skills_to_run:
        process_skill(
            skill_id=skill_id,
            category=category,
            description=description,
            tolerance=tolerance,
            skip_generate=args.skip_generate,
            dry_run=args.dry_run,
        )

    if not args.dry_run:
        print("\nDone.")


if __name__ == "__main__":
    main()
