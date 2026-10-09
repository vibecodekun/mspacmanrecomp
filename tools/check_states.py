"""Check the frontend's state machinery against the machine itself, in hidden
windows with isolated settings:

  preempt  Preemptive frames: a run with 1 preemptive frame and every input a
           frame late ends in exactly the machine state of a run without
           preemptive frames and the inputs on time (the game sees each press a
           frame sooner, and nothing else changes); the late inputs without
           preemptive frames end elsewhere (the check can fail).
  states   Save-state files: a state saved during play and loaded by another
           process continues exactly as the run that saved it.

Each compares the runner's whole-machine fingerprint (GENESIS_RUN_DONE)."""
import argparse
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile

START = ["WAIT 400", "PRESS START 5", "WAIT 120", "PRESS START 5", "WAIT 60", "PRESS START 5"]
MOVES = ["WAIT 300", "HOLD LEFT", "WAIT 47", "RELEASE", "HOLD UP", "WAIT 31", "RELEASE",
         "HOLD RIGHT", "WAIT 90", "RELEASE", "HOLD DOWN", "WAIT 60", "RELEASE", "HOLD LEFT", "WAIT 200",
         "RELEASE"]


def run(args, state, frames, preempt, script_lines, frontend_script="", label="run"):
    script = Path(state, f"{label}.input")
    script.write_text("\n".join(script_lines) + "\n", encoding="utf-8")
    env = dict(os.environ, GENESIS_STATE_DIR=state, GENESIS_NO_LAUNCHER="1", GENESIS_HIDDEN_WINDOW="1",
               SDL_AUDIODRIVER="dummy", GENESIS_RUN_DONE="1", GENESIS_PREEMPTIVE_FRAMES=str(preempt))
    if frontend_script:
        fs = Path(state, f"{label}.frontend")
        fs.write_text(frontend_script, encoding="utf-8")
        env["GENESIS_FRONTEND_SCRIPT"] = str(fs)
    command = shlex.split(args.wrapper) + [str(args.exe.resolve()), str(args.rom.resolve()),
                                            "--input-script", str(script), "--max-frames", str(frames)]
    log = args.logs / f"check-states-{label}.log"
    with log.open("w", encoding="utf-8") as out:
        subprocess.run(command, cwd=state, env=env, stdout=out, stderr=subprocess.STDOUT,
                       timeout=args.timeout)
    text = log.read_text(encoding="utf-8", errors="replace")
    done = re.search(r"RUN_DONE frames=(\d+) state=([0-9a-f]+)", text)
    return (done.group(2) if done else None), text, log


def check_preempt(args):
    with tempfile.TemporaryDirectory(prefix="mspacman-preempt-") as state:
        frames = 1500
        on_time, _, log_a = run(args, state, frames, 0, START + MOVES, label="preempt-0")
        late, _, log_b = run(args, state, frames, 1, ["WAIT 1"] + START + MOVES, label="preempt-1")
        control, _, _ = run(args, state, frames, 0, ["WAIT 1"] + START + MOVES, label="preempt-control")
    ok = on_time and on_time == late and control and control != on_time
    print(f"{'PASS' if ok else 'FAIL'} preempt: on time {on_time}, a frame late with 1 preemptive frame "
          f"{late}, late without {control}" + ("" if ok else f"; see {log_a}, {log_b}"))
    return ok


def check_states(args):
    with tempfile.TemporaryDirectory(prefix="mspacman-states-") as state:
        frames = 1800
        # Play, save at 1100 (taken at the next point the game can resume
        # from), and run on without input.
        _, saved_log, log_a = run(args, state, frames, 0, START + MOVES[:10],
                                  frontend_script="1100 press save_state\n", label="states-save")
        saved_at = re.search(r"state slot 1 saved before tick (\d+)", saved_log)
        h_saved, _, _ = run(args, state, frames, 0, START + MOVES[:10],
                            frontend_script="1100 press save_state\n", label="states-save-again")
        if not saved_at:
            print(f"FAIL states: nothing saved; see {log_a}")
            return False
        saved_tick = int(saved_at.group(1))
        h_a = re.search(r"RUN_DONE frames=\d+ state=([0-9a-f]+)", saved_log)
        h_a = h_a.group(1) if h_a else None
        # Another process loads it at tick 200 (the attract mode) and runs the
        # same number of ticks after it.
        load_tick = 200
        load_frames = frames - saved_tick + load_tick
        h_b, load_log, log_b = run(args, state, load_frames, 0, ["WAIT 1"],
                                   frontend_script=f"{load_tick} press load_state\n", label="states-load")
        loaded = re.search(r"state slot 1 loaded before tick (\d+)", load_log)
    ok = bool(h_a and h_a == h_b and loaded and h_saved == h_a)
    print(f"{'PASS' if ok else 'FAIL'} states: saved before tick {saved_tick}, run on to {frames}: {h_a} "
          f"(again: {h_saved}); loaded by another process before tick {load_tick}, run on as long: {h_b}"
          + ("" if ok else f"; see {log_a}, {log_b}"))
    return ok


def main():
    root = Path(__file__).resolve().parents[1]
    exe_name = "MsPacManRecomp.exe" if os.name == "nt" else "MsPacManRecomp"
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--exe", type=Path, default=root / "build/x64" / exe_name)
    parser.add_argument("--rom", type=Path, default=root / "game/mspacman.bin")
    parser.add_argument("--logs", type=Path, default=root / "logs")
    parser.add_argument("--wrapper", default="")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("checks", nargs="*", help="preempt, states (default: both)")
    args = parser.parse_args()
    args.logs.mkdir(parents=True, exist_ok=True)
    if os.name == "nt":
        import ctypes
        ctypes.windll.kernel32.SetErrorMode(0x0001 | 0x0002)
    checks = args.checks or ["preempt", "states"]
    for c in checks:
        if c not in ("preempt", "states"):
            parser.error(f"unknown check {c}")
    results = [{"preempt": check_preempt, "states": check_states}[c](args) for c in checks]
    return 0 if all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
