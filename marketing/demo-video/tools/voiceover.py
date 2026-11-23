"""Generates the voiceover for the demo video with a Microsoft neural voice (edge-tts).

Writes one MP3 per narration section to public/voice/, plus public/voice/timings.json with
each word's start and end in seconds, which the video uses to time captions and shots.

    python3 -m venv .venv && .venv/bin/pip install edge-tts
    .venv/bin/python tools/voiceover.py
"""

import asyncio
import json
import pathlib
import subprocess

import edge_tts

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "public" / "voice"
TICKS = 10_000_000  # edge-tts offsets are in 100-nanosecond units


def duration(path: pathlib.Path) -> float:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=True,
    )
    return float(result.stdout.strip())


async def speak(section: dict, voice: str, rate: str) -> dict:
    path = OUT / f"{section['id']}.mp3"
    communicate = edge_tts.Communicate(section["say"], voice, rate=rate, boundary="WordBoundary")
    words = []
    with path.open("wb") as audio:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio.write(chunk["data"])
            elif chunk["type"] == "WordBoundary":
                start = chunk["offset"] / TICKS
                words.append({"word": chunk["text"], "start": round(start, 3),
                              "end": round(start + chunk["duration"] / TICKS, 3)})

    # Attach the punctuation from the script to each spoken word, then apply caption spellings.
    tokens = section["say"].split()
    replacements = section.get("captions", {})
    cursor = 0
    for word in words:
        while cursor < len(tokens) and word["word"].strip(".,?!'") not in tokens[cursor]:
            cursor += 1
        token = tokens[cursor] if cursor < len(tokens) else word["word"]
        cursor += 1
        word["text"] = replacements.get(token, token)
    words = [w for w in words if w["text"]]
    return {"id": section["id"], "file": f"voice/{path.name}", "duration": round(duration(path), 3),
            "words": words}


async def main() -> None:
    narration = json.loads((ROOT / "narration.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    sections = [await speak(s, narration["voice"], narration["rate"]) for s in narration["sections"]]
    (OUT / "timings.json").write_text(json.dumps({"sections": sections}, indent=2) + "\n")
    for s in sections:
        print(f"{s['id']:8} {s['duration']:6.2f}s  {' '.join(w['text'] for w in s['words'])}")


asyncio.run(main())
