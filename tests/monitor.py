#!/usr/bin/env python3
"""Deterministic monitor tests through Zshctl, with only Codex nudge replaced."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MonitorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="muster-monitor-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "bin").mkdir()
        self.muster = self.root / "bin/muster"
        shutil.copy2(ROOT / "bin/muster", self.muster)
        commands = self.root / "share/muster/commands"
        commands.mkdir(parents=True)
        shutil.copytree(ROOT / "share/muster/commands/monitor", commands / "monitor")
        (commands / "codex/nudge").mkdir(parents=True)
        (commands / "codex/command.zsh").write_text('function :execute:codex { delegate "$@"; }\n')
        (commands / "codex/nudge/command.zsh").write_text('''
function :execute:codex:nudge {
    python3 "$MONITOR_TEST_ROOT/nudge.py" "$@"
}
''')
        (self.root / "nudge.py").write_text('''
import json, os, pathlib, sys, time
root = pathlib.Path(os.environ["MONITOR_TEST_ROOT"])
with (root / "calls").open("a") as out:
    out.write(json.dumps({"args": sys.argv[1:], "text": sys.stdin.read(), "start": time.monotonic()}) + "\\n")
(root / "nudging").touch()
time.sleep(float(os.environ.get("MONITOR_TEST_DELAY", "0")))
print('{"success":"must not leak"}')
print("nudge diagnostic", file=sys.stderr)
with (root / "ends").open("a") as out:
    out.write(str(time.monotonic()) + "\\n")
sys.exit(int(os.environ.get("MONITOR_TEST_FAIL", "0")))
''')
        self.env = dict(os.environ, MONITOR_TEST_ROOT=str(self.root))

    def start(self, code, *args, **env):
        child = subprocess.Popen(
            [str(self.muster), "monitor", "--slug", "scratch", "--", sys.executable, "-c", code, *args],
            env=dict(self.env, **env), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        self.addCleanup(self.cleanup_process, child)
        return child

    def cleanup_process(self, child):
        if child.poll() is None:
            child.kill()
            child.wait()
        for stream in (child.stdout, child.stderr):
            if stream is not None:
                stream.close()
        pid_file = self.root / "pid"
        if pid_file.exists():
            try:
                os.kill(int(pid_file.read_text()), signal.SIGKILL)
            except ProcessLookupError:
                pass

    def finish(self, child):
        out, err = child.communicate(timeout=8)
        return child.returncode, out, err

    def calls(self):
        path = self.root / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def await_file(self, name):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            path = self.root / name
            if path.exists() and (name != "pid" or path.read_text()):
                return path
            time.sleep(0.01)
        self.fail(f"timed out waiting for {name}")

    def assert_reaped(self):
        pid = int((self.root / "pid").read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)

    def producer(self, output="", close=False):
        return f'''
import os, pathlib, signal, sys
root = pathlib.Path(os.environ["MONITOR_TEST_ROOT"])
def stop(number, frame):
    (root / "signal").write_text(str(number))
    sys.exit(0)
for number in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
    signal.signal(number, stop)
(root / "pid").write_text(str(os.getpid()))
sys.stdout.write({output!r}); sys.stdout.flush()
if {close!r}: os.close(1)
while True: signal.pause()
'''

    def test_framing_argv_stderr_serial_and_status(self):
        code = 'import sys; print(sys.argv[1]); print(" \\t"); print("diagnostic", file=sys.stderr); print("second\\r"); sys.exit(7)'
        rc, out, err = self.finish(self.start(code, r'  a\b "$()"  ', MONITOR_TEST_DELAY="0.1"))
        self.assertEqual(rc, 7, err)
        self.assertEqual(out, '  a\\b "$()"  \nsecond\n')  # communicate translates CRLF
        self.assertIn("diagnostic", err)
        self.assertNotIn("success", out)
        calls = self.calls()
        self.assertEqual([c["text"] for c in calls], ['  a\\b "$()"  \n', 'second\r\n'])
        self.assertEqual(calls[0]["args"], ["--slug", "scratch"])
        ends = [float(line) for line in (self.root / "ends").read_text().splitlines()]
        self.assertGreaterEqual(calls[1]["start"], ends[0])

    def test_partial_tail_is_error_not_nudge(self):
        for tail in ["tail", "   "]:
            with self.subTest(tail=tail):
                rc, out, err = self.finish(self.start(f'import sys; sys.stdout.write("complete\\n" + {tail!r}); sys.exit(7)'))
                self.assertEqual(rc, 1, err)
                self.assertEqual(out, "complete\n")
                self.assertIn("unterminated", err)
        self.assertEqual([c["text"] for c in self.calls()], ["complete\n", "complete\n"])

    def test_nudge_failure_stops_and_reaps_producer(self):
        rc, out, err = self.finish(self.start(self.producer("first\nsecond\n"), MONITOR_TEST_FAIL="9"))
        self.assertEqual(rc, 9, err)
        self.assertEqual(out, "first\n")
        self.assertEqual(len(self.calls()), 1)
        self.assertIn("uncertain", err)
        self.assert_reaped()

    def test_signals_during_read_nudge_and_wait(self):
        for phase in ["read", "nudge", "wait"]:
            for sig in [signal.SIGINT, signal.SIGTERM, signal.SIGHUP]:
                with self.subTest(phase=phase, sig=sig):
                    for name in ["pid", "signal", "nudging"]:
                        (self.root / name).unlink(missing_ok=True)
                    child = self.start(self.producer("record\n" if phase == "nudge" else "", close=phase == "wait"), MONITOR_TEST_DELAY="0.3")
                    self.await_file("pid")
                    if phase == "nudge":
                        self.await_file("nudging")
                    else:
                        time.sleep(0.05)
                    child.send_signal(sig)
                    rc, out, err = self.finish(child)
                    self.assertEqual(rc, 128 + sig, err)
                    self.assertEqual(int((self.root / "signal").read_text()), sig)
                    self.assert_reaped()

    def test_broken_local_stdout_stops_producer_without_nudge(self):
        code = self.producer("first\n").replace(
            "sys.stdout.write(",
            "while not (root / 'go').exists(): __import__('time').sleep(0.01)\nsys.stdout.write(",
        )
        child = self.start(code)
        self.await_file("pid")
        child.stdout.close()
        child.stdout = None
        (self.root / "go").touch()
        rc, out, err = self.finish(child)
        self.assertNotEqual(rc, 0)
        self.assertEqual(self.calls(), [])
        self.assert_reaped()

    def test_command_arguments_are_not_evaluated(self):
        arguments = ["", "--help", "--", "a b", "$(touch should-not-exist)", "one\ntwo"]
        rc, out, err = self.finish(self.start('import json, sys; print(json.dumps(sys.argv[1:]))', *arguments))
        self.assertEqual(rc, 0, err)
        self.assertEqual(json.loads(self.calls()[0]["text"]), arguments)

    def test_empty_and_missing_command(self):
        rc, out, err = self.finish(self.start('pass'))
        self.assertEqual((rc, out), (0, ""), err)
        missing = subprocess.run([str(self.muster), "monitor", "--slug", "scratch", "--", "/no/such/monitor-producer"], env=self.env, capture_output=True, text=True)
        self.assertEqual(missing.returncode, 127, missing.stderr)
        no_separator = subprocess.run([str(self.muster), "monitor", "--slug", "scratch", "true"], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(no_separator.returncode, 0)
        late_separator = subprocess.run([str(self.muster), "monitor", "--slug", "scratch", "printf", "--", "unexpected\n"], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(late_separator.returncode, 0)
        self.assertEqual(late_separator.stdout, "")


if __name__ == "__main__":
    unittest.main()
