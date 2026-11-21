#!/usr/bin/env python3
"""End-to-end check of /q against a real Claude Code session.

Runs Claude Code (haiku) in a pseudo-terminal inside a throwaway folder, with
timestamp-logging hooks passed via --settings (your own settings are untouched).

Scenario:
  1. Main task: two `sleep` commands in a row.
  2. While it is busy: type `/q #1` (also sleeps), `/q #2`, then a plain message.

Passes when:
  - /q #1 is only processed after the main task stops, and
  - /q #2 is only processed after /q #1 stops.
The plain message is reported for comparison (it normally lands mid-task).

Usage: python3 tests/verify.py [--debug]
Needs `claude` on PATH and uses a small amount of quota.
"""
import json, os, pty, re, select, shutil, sys, tempfile, time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CMD = os.path.join(REPO, "commands", "q.md")
DEBUG = "--debug" in sys.argv
ANSI = re.compile(rb"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b[=>()][0-9A-Za-z]?")


def main():
    tmp = tempfile.mkdtemp(prefix="htt-test-")
    work = os.path.join(tmp, "work")
    os.makedirs(os.path.join(work, ".claude", "commands"))
    shutil.copy(CMD, os.path.join(work, ".claude", "commands", "q.md"))
    events = os.path.join(tmp, "events.log")

    logger = os.path.join(tmp, "log.py")
    with open(logger, "w") as f:
        f.write(
            "import json,sys,time\n"
            "d=json.load(sys.stdin)\n"
            "p=(d.get('prompt') or '').replace('\\n',' ')[:80]\n"
            f"open({events!r},'a').write('%.2f\\t%s\\t%s\\n'%(time.time(),sys.argv[1],p))\n"
        )
    hook = lambda ev: [{"hooks": [{"type": "command", "command": f"python3 {logger} {ev}"}]}]
    settings = os.path.join(tmp, "settings.json")
    with open(settings, "w") as f:
        json.dump({"hooks": {"UserPromptSubmit": hook("SUBMIT"), "Stop": hook("STOP")}}, f)

    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(work)
        os.environ["TERM"] = "xterm-256color"
        os.execvp("claude", ["claude", "--model", "haiku", "--settings", settings,
                             "--allowedTools", "Bash(sleep *)"])

    buf = bytearray()

    def screen():
        return ANSI.sub(b"", bytes(buf)).decode(errors="replace")

    def pump(sec, until=None):
        end = time.time() + sec
        while time.time() < end:
            r, _, _ = select.select([fd], [], [], 0.2)
            if r:
                try:
                    buf.extend(os.read(fd, 65536))
                except OSError:
                    raise SystemExit("Claude Code exited early. Last screen:\n" + screen()[-1500:])
            if until and until in re.sub(r"\s", "", screen()).lower():
                return True
        return False

    def typ(s):
        for ch in s:
            os.write(fd, ch.encode())
            time.sleep(0.02)
        time.sleep(0.4)
        os.write(fd, b"\r")

    try:
        if pump(15, until="itrustthisfolder"):
            pump(1)
            os.write(fd, b"\x1b[B")  # move to "Yes, I trust this folder"
            time.sleep(0.5)
            os.write(fd, b"\r")
        pump(6)
        if DEBUG:
            print("--- screen before typing ---\n" + screen()[-1500:])
        typ("Run these bash commands one at a time: first `sleep 20`, then `sleep 15`. Then reply exactly DONE-MAIN.")
        pump(9)
        typ("/q run bash `sleep 8` then reply exactly DONE-Q1")
        pump(3)
        typ("/q reply exactly DONE-Q2")
        pump(3)
        typ("reply PLAIN too")
        pump(90)
        typ("/exit")
        pump(3)
    finally:
        try:
            os.kill(pid, 9)
        except OSError:
            pass

    rows = []
    if os.path.exists(events):
        rows = [l.rstrip("\n").split("\t") for l in open(events)]
    print("Timeline:")
    t0 = float(rows[0][0]) if rows else 0
    for t, ev, p in rows:
        print(f"  +{float(t) - t0:6.1f}s  {ev:6}  {p}")

    seq = [(ev, p) for _, ev, p in rows]

    def first(pred):
        return next((i for i, x in enumerate(seq) if pred(x)), None)

    q1 = first(lambda x: x[0] == "SUBMIT" and "DONE-Q1" in x[1])
    q2 = first(lambda x: x[0] == "SUBMIT" and "DONE-Q2" in x[1])
    plain = first(lambda x: x[0] == "SUBMIT" and "PLAIN" in x[1])
    stops = [i for i, x in enumerate(seq) if x[0] == "STOP"]

    ok1 = q1 is not None and bool(stops) and stops[0] < q1
    ok2 = q1 is not None and q2 is not None and any(q1 < s < q2 for s in stops)
    print()
    print("PASS" if ok1 else "FAIL", "/q #1 held until the main task finished")
    print("PASS" if ok2 else "FAIL", "/q #2 waited for /q #1 to finish")
    if plain is not None and stops:
        print("INFO plain message", "landed mid-task" if plain < stops[0] else "landed after the task")
    if DEBUG and not (ok1 and ok2):
        print("--- last screen ---\n" + screen()[-1500:])
    shutil.rmtree(tmp, ignore_errors=True)
    sys.exit(0 if ok1 and ok2 else 1)


if __name__ == "__main__":
    main()
