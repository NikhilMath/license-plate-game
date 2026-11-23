"""Records the demo footage: runs the DemoRecorder UI test while the simulator screen records.

Writes public/footage/<take>.mp4 (30 fps) and public/footage/<take>.json with the time of each
step in the recording, from the test's DEMO-MARK lines. The app must already be installed in
the simulator as a Debug build (see README.md).

    python3 tools/record.py [take name] [simulator UDID]
"""

import json
import os
import pathlib
import signal
import subprocess
import sys
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
RECORDER = ROOT / "recorder"
FOOTAGE = ROOT / "public" / "footage"
TAKE = sys.argv[1] if len(sys.argv) > 1 else "take1"
UDID = sys.argv[2] if len(sys.argv) > 2 else "booted"
ENV = {**os.environ, "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer"}
BUILD = ROOT / "out" / "recorder-build"


def xcodebuild(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["xcodebuild", "-project", str(RECORDER / "DemoRecorder.xcodeproj"), "-scheme", "DemoRecorder",
         "-destination", f"id={UDID}" if UDID != "booted" else "platform=iOS Simulator,name=iPhone 18 Pro",
         "-derivedDataPath", str(BUILD), *args],
        env=ENV, capture_output=True, text=True,
    )


def main() -> None:
    FOOTAGE.mkdir(parents=True, exist_ok=True)
    raw = ROOT / "out" / f"{TAKE}.mov"
    subprocess.run(["xcrun", "simctl", "status_bar", UDID, "override", "--time", "9:41",
                    "--batteryState", "charged", "--batteryLevel", "100", "--cellularMode", "active",
                    "--cellularBars", "4", "--wifiBars", "3", "--dataNetwork", "wifi"], env=ENV, check=True)

    print("Building the recorder…")
    built = xcodebuild("build-for-testing")
    if built.returncode != 0:
        sys.exit(built.stdout[-3000:] + built.stderr[-3000:])

    recorder = subprocess.Popen(
        ["xcrun", "simctl", "io", UDID, "recordVideo", "--codec=h264", "--force", str(raw)],
        env=ENV, stderr=subprocess.PIPE, text=True,
    )
    started = threading.Event()
    start_time = [0.0]

    def watch() -> None:
        for line in recorder.stderr:
            if "Recording started" in line and not started.is_set():
                start_time[0] = time.time()
                started.set()

    threading.Thread(target=watch, daemon=True).start()
    if not started.wait(20):
        recorder.kill()
        sys.exit("The recording didn't start.")

    print("Recording. Running the UI test…")
    test = xcodebuild("test-without-building", "-only-testing:DemoRecorderUITests/DemoRecorder/testRecordDemo")
    time.sleep(1)
    recorder.send_signal(signal.SIGINT)
    recorder.wait(60)

    marks = []
    for line in test.stdout.splitlines():
        if line.startswith("DEMO-MARK "):
            parts = line.split()
            mark = {"name": parts[2], "t": round(float(parts[1]) - start_time[0], 3)}
            if len(parts) >= 5:
                mark["x"], mark["y"] = float(parts[3]), float(parts[4])
            marks.append(mark)
    if test.returncode != 0:
        print(test.stdout[-4000:])
        print("The UI test failed; keeping the footage recorded so far.")

    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(raw), "-vf", "fps=30", "-c:v", "libx264",
                    "-crf", "14", "-preset", "slow", "-pix_fmt", "yuv420p", "-an",
                    str(FOOTAGE / f"{TAKE}.mp4")], check=True)
    (FOOTAGE / f"{TAKE}.json").write_text(json.dumps(marks, indent=2) + "\n")
    for m in marks:
        print(f"{m['t']:7.2f}  {m['name']}")


main()
