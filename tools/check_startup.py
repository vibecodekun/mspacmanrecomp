"""Run the game loop through the real frontend (GL context, menus, rewind)
with isolated settings and saves, in a hidden window, and check that it got
there: the frame limit reached, no recompiled-code miss handed to the
interpreter, and no dispatch miss recorded."""
import argparse
import os
from pathlib import Path
import shlex
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    exe_name = "MsPacManRecomp.exe" if os.name == "nt" else "MsPacManRecomp"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", type=Path, default=root / "build/x64" / exe_name)
    parser.add_argument("--rom", type=Path, default=root / "game/mspacman.bin")
    parser.add_argument("--frames", type=int, default=600)
    parser.add_argument("--log", type=Path, default=root / "logs/startup-smoke.log")
    parser.add_argument("--wrapper", default="",
                        help="command to run the exe under, e.g. 'qemu-aarch64-static -L <root>'")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--no-gl", action="store_true",
                        help="SDL's dummy video driver: the SDL_Renderer fallback, no GL")
    args = parser.parse_args()
    if args.frames < 1:
        parser.error("--frames must be positive")
    args.log.parent.mkdir(parents=True, exist_ok=True)
    if os.name == "nt":
        # Let a crashing child fail the test instead of opening a WER dialog.
        import ctypes
        ctypes.windll.kernel32.SetErrorMode(0x0001 | 0x0002)
    with tempfile.TemporaryDirectory(prefix="mspacman-startup-") as state:
        env = dict(os.environ, GENESIS_STATE_DIR=state, GENESIS_NO_LAUNCHER="1",
                   GENESIS_HIDDEN_WINDOW="1", SDL_AUDIODRIVER="dummy", GENESIS_RUN_DONE="1")
        if args.no_gl:
            env["SDL_VIDEODRIVER"] = "dummy"
        command = shlex.split(args.wrapper) + [
            str(args.exe.resolve()), str(args.rom.resolve()), "--max-frames", str(args.frames)]
        with args.log.open("w", encoding="utf-8") as log:
            try:
                result = subprocess.run(command, cwd=state, env=env, stdout=log,
                                        stderr=subprocess.STDOUT, timeout=args.timeout)
            except subprocess.TimeoutExpired:
                print(f"FAIL startup timed out; see {args.log}")
                return 1
        misses = Path(state, "dispatch_misses.toml")
        miss_count = 0
        if misses.exists():
            import re
            found = re.search(r"^# entries:\s+(\d+)", misses.read_text(encoding="utf-8", errors="replace"), re.M)
            miss_count = int(found.group(1)) if found else 0
    output = args.log.read_text(encoding="utf-8", errors="replace")
    reached = f"[DONE] {args.frames} frames completed" in output
    no_interp = "[INTERP] hybrid_jmp/call_interpret: 0 total calls" in output
    gl = "[GL] vendor=" in output
    problems = []
    if result.returncode:
        problems.append(f"exit {result.returncode}")
    if not reached:
        problems.append("frame limit not reached")
    if not no_interp:
        problems.append("recompiled code fell back to the interpreter")
    if miss_count:
        problems.append(f"{miss_count} dispatch miss(es)")
    if not args.no_gl and not gl:
        problems.append("no GL context (fell back to SDL_Renderer)")
    if problems:
        print(f"FAIL startup ({', '.join(problems)}); see {args.log}")
        return 1
    print(f"PASS startup: {args.frames} frames through the game loop"
          f"{' on ' + output.split('renderer=')[1].split('|')[0].strip() if gl and 'renderer=' in output else ''}; "
          f"see {args.log}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
