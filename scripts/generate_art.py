"""
Generate artwork for each prompt in the memory/prompts directory.

This script reads each text file in `memory/prompts`, combines the prompt
with a base style to ensure continuity across images, and calls an
image generation API (e.g. OpenAI's DALL·E) to produce a single image.
The generated images are saved into the `asset/designs` directory with
filenames matching the prompt file (e.g. `palace_exterior.png`).

Before running this script you must:

1. Sign up with your chosen image generation provider and obtain an API key.
2. Store the key in the environment variable `ART_API_KEY` (e.g. via
   GitHub Actions secrets when run in CI).
3. Ensure the `asset/designs` directory exists.
4. Install the `requests` Python package (`pip install requests`).

This script is intentionally simple and may be expanded with error
handling or batching as needed.
"""

import os
import json
import requests
from pathlib import Path

API_KEY = os.environ.get("ART_API_KEY")
if not API_KEY:
    raise EnvironmentError("ART_API_KEY is not set. Set this environment variable to your image generation API key.")

# Endpoint for OpenAI's DALL·E image generation API.  Change this to your
# provider's endpoint if using a different service.
API_URL = "https://api.openai.com/v1/images/generations"

# A consistent style prompt appended to each scene prompt to ensure the
# resulting images share a cohesive look.  Adjust this to your preferred
# art direction (e.g. "watercolour", "low poly", "pastel cyberpunk").
BASE_STYLE = "in the style of digital art with soft pastel colours and cohesive Avalon aesthetics"

# Directories
PROMPTS_DIR = Path("memory/prompts")
OUTPUT_DIR = Path("asset/designs")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def generate_image(prompt: str) -> bytes:
    """Call the image generation API and return the binary image data."""
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    }
    data = {
        "prompt": prompt,
        "n": 1,
        "size": "1024x1024",
    }
    response = requests.post(API_URL, headers=headers, json=data, timeout=60)
    response.raise_for_status()
    result = response.json()
    image_url = result["data"][0]["url"]
    # Download the image
    img_resp = requests.get(image_url, timeout=60)
    img_resp.raise_for_status()
    return img_resp.content

def main():
    for prompt_file in PROMPTS_DIR.glob("*.txt"):
        with open(prompt_file, "r", encoding="utf-8") as f:
            base_prompt = f.read().strip()
        combined_prompt = f"{base_prompt}, {BASE_STYLE}"
        print(f"Generating image for {prompt_file.name} ...")
        image_data = generate_image(combined_prompt)
        out_name = prompt_file.stem + ".png"
        out_path = OUTPUT_DIR / out_name
        with open(out_path, "wb") as out_f:
            out_f.write(image_data)
        print(f"Saved {out_path}")

if __name__ == "__main__":
    main()