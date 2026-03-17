#!/usr/bin/env python3
"""Generate a game icon using the Gemini API (Nano Banana 2 Flash).

Usage:
    python3 generate_icon.py "prompt text" output.png [WxH]
    python3 generate_icon.py "prompt text" output.png 16x16
"""

import sys
import json
import math
import base64
import urllib.request
import urllib.error
from pathlib import Path
from PIL import Image
from io import BytesIO

API_KEY = "AIzaSyBou5tRG35krsSkXVIgD2aHyJMPIqtDuxc"
MODEL = "gemini-3.1-flash-image-preview"
ENDPOINT = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"


def remove_background(img: Image.Image, tolerance: int = 40) -> Image.Image:
    """Remove background by sampling corner pixels and making similar colors transparent."""
    pixels = img.load()
    w, h = img.size
    # Sample all 4 corners to get the most common background color
    corners = [pixels[0, 0], pixels[w - 1, 0], pixels[0, h - 1], pixels[w - 1, h - 1]]
    bg = corners[0]  # top-left as primary reference

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            dist = math.sqrt((r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2)
            if dist < tolerance:
                pixels[x, y] = (r, g, b, 0)
    return img


def remove_background_file(path: str, tolerance: int = 40):
    """Remove background from an existing PNG file in-place."""
    img = Image.open(path).convert("RGBA")
    img = remove_background(img, tolerance)
    img.save(path, "PNG")
    print(f"Removed background: {path}")


def generate_icon(prompt: str, output_path: str, size: str = "16x16", bg_remove: bool = True):
    w, h = (int(x) for x in size.lower().split("x"))

    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseModalities": ["TEXT", "IMAGE"],
        },
    }

    req = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(payload).encode(),
        headers={
            "x-goog-api-key": API_KEY,
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"API error {e.code}: {body}", file=sys.stderr)
        sys.exit(1)

    # Extract base64 image from response parts
    image_data = None
    for part in data.get("candidates", [{}])[0].get("content", {}).get("parts", []):
        if "inlineData" in part:
            image_data = part["inlineData"]["data"]
            break

    if not image_data:
        print(f"No image in response. Full response:\n{json.dumps(data, indent=2)}", file=sys.stderr)
        sys.exit(1)

    # Decode, resize, optionally remove background, save
    img = Image.open(BytesIO(base64.b64decode(image_data)))
    img = img.convert("RGBA")
    img = img.resize((w, h), Image.LANCZOS)
    if bg_remove:
        img = remove_background(img)

    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(str(out), "PNG")
    print(f"Saved {out} ({w}x{h})")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    prompt = args[0]
    output = args[1]
    size = args[2] if len(args) > 2 else "16x16"
    bg_remove = "--no-bg-remove" not in flags
    generate_icon(prompt, output, size, bg_remove=bg_remove)
