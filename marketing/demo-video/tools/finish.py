"""Brings the rendered video's voice up to -14 LUFS, the loudness TikTok and LinkedIn play at.

Two-pass loudnorm on the audio; the video stream is copied untouched.

    python3 tools/finish.py [input] [output]
"""

import json
import re
import subprocess
import sys

src = sys.argv[1] if len(sys.argv) > 1 else "out/plate-chase-demo.mp4"
dst = sys.argv[2] if len(sys.argv) > 2 else "out/plate-chase-demo-final.mp4"
target = "I=-14:TP=-1.5:LRA=11"

measure = subprocess.run(
    ["ffmpeg", "-hide_banner", "-i", src, "-af", f"loudnorm={target}:print_format=json", "-f", "null", "-"],
    capture_output=True, text=True, check=True,
)
stats = json.loads(re.findall(r"\{[^{}]*\}", measure.stderr)[-1])
filter_ = (f"loudnorm={target}:measured_I={stats['input_i']}:measured_TP={stats['input_tp']}"
           f":measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}"
           f":offset={stats['target_offset']}:linear=true")
subprocess.run(
    ["ffmpeg", "-hide_banner", "-v", "error", "-y", "-i", src, "-c:v", "copy", "-af", filter_,
     "-ar", "48000", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", dst],
    check=True,
)
print(f"{src} was {stats['input_i']} LUFS; wrote {dst}")
