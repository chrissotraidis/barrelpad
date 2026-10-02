#!/usr/bin/env python3
"""Exercise the real iOS entrypoints with temporary sources and fake tools.

The engine build stops at a deliberate fake-cmake boundary before packaging.
No repository sources, game data, SDKs, downloads, or dependencies are used.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ENGINE_STOP = 73
GUARD_STOP = 74
FAKE_TOOL = r'''
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["FIXTURE_LOG"], "a") as log:
    log.write(json.dumps([name] + args) + "\n")
if name == os.environ.get("FIXTURE_REFUSE"):
    sys.exit(74)
if name == "sysctl":
    print(os.environ.get("FIXTURE_CPUS", "8"))
elif name == "cmake" and "--target" in args:
    sys.exit(73)  # Never enter app packaging.
elif name in ("curl", "tar", "git", "clang", "patch", "actool", "xcrun"):
    sys.exit(99)  # An unexpected real-work path must fail closed.
'''


class BuildJobsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="barrelpad-jobs-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.scripts = self.root / "scripts"
        self.scripts.mkdir()
        for name in ("build-ios.sh", "build-sdl2-ios.sh", "build-jobs.sh"):
            shutil.copy2(ROOT / "scripts" / name, self.scripts / name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("cmake", "sysctl", "curl", "tar", "git", "clang",
                     "patch", "actool", "xcrun"):
            self.fake_tool(self.bin / name)
        for name in ("test-unit.sh", "clone-refs.sh", "apply-ios-patches.sh"):
            self.fake_tool(self.scripts / name)
        self.log = self.root / "calls.jsonl"
        self.source = self.root / "external-source"
        self.source.mkdir()
        (self.source / "CMakeLists.txt").write_text("# fixture source\n")
        (self.source / "local-change.txt").write_text("preserve source edits\n")
        self.data = self.root / "data"
        self.data.mkdir()
        (self.data / "sentinel.txt").write_text("synthetic data guard\n")
        self.work = self.root / "sdl-work"
        (self.work / "SDL2-2.32.10").mkdir(parents=True)
        self.env = os.environ.copy()
        for key in tuple(self.env):
            if key.startswith("BARRELPAD_") or key in (
                "CMAKE_BUILD_PARALLEL_LEVEL", "SDL_VER", "BASH_ENV",
                "FIXTURE_REFUSE", "FIXTURE_CPUS",
            ):
                self.env.pop(key)
        self.env.update({
            "PATH": str(self.bin) + ":/usr/bin:/bin",
            "FIXTURE_LOG": str(self.log),
            "BARRELPAD_SOURCE": str(self.source),
            "BARRELPAD_IOS_BUILD": str(self.root / "engine-output"),
            "BARRELPAD_SDL_WORK": str(self.work),
            "BARRELPAD_SDL_IOS": str(self.root / "sdl-output"),
        })

    def fake_tool(self, path):
        path.write_text("#!" + sys.executable + "\n" + FAKE_TOOL)
        path.chmod(0o755)

    def run_entrypoint(self, name, mode="--simulator", **overrides):
        env = dict(self.env, **overrides)
        return subprocess.run(
            ["/bin/bash", str(self.scripts / name), mode],
            cwd=str(self.root), env=env, text=True, capture_output=True,
        )

    def calls(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def snapshot(self, path):
        return {
            str(item.relative_to(path)): item.read_bytes() if item.is_file() else None
            for item in path.rglob("*")
        }

    def assert_jobs(self, result, expected, engine=True, sysctl_calls=0):
        self.assertEqual(result.returncode, ENGINE_STOP if engine else 0,
                         result.stdout + result.stderr)
        calls = self.calls()
        builds = [call for call in calls if call[:2] == ["cmake", "--build"]]
        self.assertEqual(len(builds), 2 if engine else 1, calls)
        for call in builds:
            self.assertEqual([arg for arg in call if arg.startswith("-j")],
                             ["-j" + expected], call)
        self.assertEqual(sum(call[0] == "sysctl" for call in calls), sysctl_calls)
        if engine:
            self.assertEqual(builds[-1][-2:], ["--target", "mdkr64"])
            self.assertIn(["apply-ios-patches.sh", str(self.source)], calls)
            self.assertFalse(any(call[0] == "clone-refs.sh" for call in calls))
        self.assertFalse(any(call[0] in ("curl", "tar") for call in calls))

    def test_invalid_overrides_stop_before_tools_or_side_effects(self):
        invalid = ("0", "-1", "+2", "02", "00", " 2", "2 ", "2\n",
                   "1.5", "two", "2;touch unexpected", "2 3")
        for entrypoint in ("build-ios.sh", "build-sdl2-ios.sh"):
            for variable in ("BARRELPAD_JOBS", "CMAKE_BUILD_PARALLEL_LEVEL"):
                for value in invalid:
                    with self.subTest(entrypoint=entrypoint, variable=variable,
                                      value=value):
                        before = self.snapshot(self.root)
                        result = self.run_entrypoint(entrypoint, **{variable: value})
                        self.assertEqual(result.returncode, 2, result.stderr)
                        self.assertIn(variable, result.stderr)
                        self.assertIn("positive canonical integer", result.stderr)
                        self.assertEqual(self.calls(), [])
                        self.assertEqual(self.snapshot(self.root), before)

    def test_invalid_jobs_do_not_create_missing_source_or_sdl_work(self):
        for entrypoint in ("build-ios.sh", "build-sdl2-ios.sh"):
            for variable in ("BARRELPAD_JOBS", "CMAKE_BUILD_PARALLEL_LEVEL"):
                with self.subTest(entrypoint=entrypoint, variable=variable):
                    before = self.snapshot(self.root)
                    result = self.run_entrypoint(entrypoint, **{
                        variable: "0",
                        "BARRELPAD_SOURCE": str(self.root / "missing-source"),
                        "BARRELPAD_SDL_WORK": str(self.root / "missing-sdl-work"),
                    })
                    self.assertEqual(result.returncode, 2, result.stderr)
                    self.assertEqual(self.calls(), [])
                    self.assertEqual(self.snapshot(self.root), before)

    def test_padmint_two_jobs_reach_sdl_and_engine_in_both_modes(self):
        for mode in ("--simulator", "--device"):
            with self.subTest(mode=mode):
                if self.log.exists():
                    self.log.unlink()
                source_before = self.snapshot(self.source)
                data_before = self.snapshot(self.data)
                result = self.run_entrypoint("build-ios.sh", mode,
                                             CMAKE_BUILD_PARALLEL_LEVEL="2")
                self.assert_jobs(result, "2")
                self.assertEqual(self.snapshot(self.source), source_before)
                self.assertEqual(self.snapshot(self.data), data_before)
                calls = self.calls()
                sdk = "iphoneos" if mode == "--device" else "iphonesimulator"
                configs = [call for call in calls if call[:2] == ["cmake", "-S"]]
                self.assertEqual(len(configs), 2)
                self.assertTrue(all("-DCMAKE_OSX_SYSROOT=" + sdk in call
                                    for call in configs))

    def test_manual_override_wins_including_invalid_lower_priority_value(self):
        for entrypoint in ("build-ios.sh", "build-sdl2-ios.sh"):
            for lower_priority in ("2", "invalid"):
                with self.subTest(entrypoint=entrypoint, lower=lower_priority):
                    if self.log.exists():
                        self.log.unlink()
                    result = self.run_entrypoint(
                        entrypoint, BARRELPAD_JOBS="3",
                        CMAKE_BUILD_PARALLEL_LEVEL=lower_priority,
                    )
                    self.assert_jobs(result, "3", engine=entrypoint == "build-ios.sh")

    def test_invalid_manual_override_does_not_fall_through(self):
        for entrypoint in ("build-ios.sh", "build-sdl2-ios.sh"):
            with self.subTest(entrypoint=entrypoint):
                result = self.run_entrypoint(entrypoint, BARRELPAD_JOBS="0",
                                             CMAKE_BUILD_PARALLEL_LEVEL="2")
                self.assertEqual(result.returncode, 2)
                self.assertIn("BARRELPAD_JOBS", result.stderr)
                self.assertEqual(self.calls(), [])

    def test_unset_and_empty_overrides_retain_cpu_fallback(self):
        for entrypoint in ("build-ios.sh", "build-sdl2-ios.sh"):
            for overrides in ({}, {"BARRELPAD_JOBS": "",
                                   "CMAKE_BUILD_PARALLEL_LEVEL": ""}):
                with self.subTest(entrypoint=entrypoint, overrides=overrides):
                    if self.log.exists():
                        self.log.unlink()
                    result = self.run_entrypoint(entrypoint, **overrides)
                    self.assert_jobs(result, "8", engine=entrypoint == "build-ios.sh",
                                     sysctl_calls=1)

    def test_empty_manual_override_honors_cmake_in_standalone_sdl(self):
        result = self.run_entrypoint("build-sdl2-ios.sh", BARRELPAD_JOBS="",
                                     CMAKE_BUILD_PARALLEL_LEVEL="2")
        self.assert_jobs(result, "2", engine=False)

    def test_invalid_cpu_fallback_stops_before_build_work(self):
        for entrypoint in ("build-ios.sh", "build-sdl2-ios.sh"):
            with self.subTest(entrypoint=entrypoint):
                if self.log.exists():
                    self.log.unlink()
                result = self.run_entrypoint(entrypoint, FIXTURE_CPUS="0")
                self.assertEqual(result.returncode, 2)
                self.assertIn("sysctl hw.ncpu", result.stderr)
                self.assertEqual(self.calls(), [["sysctl", "-n", "hw.ncpu"]])
                self.assertFalse((self.root / "engine-output").exists())
                self.assertFalse((self.root / "sdl-output").exists())

    def test_unit_and_source_failures_still_stop_downstream_work(self):
        for guard in ("test-unit.sh", "clone-refs.sh", "apply-ios-patches.sh"):
            with self.subTest(guard=guard):
                if self.log.exists():
                    self.log.unlink()
                if guard == "clone-refs.sh":
                    (self.source / "CMakeLists.txt").unlink()
                before_source = self.snapshot(self.source)
                before_data = self.snapshot(self.data)
                result = self.run_entrypoint("build-ios.sh", BARRELPAD_JOBS="2",
                                             FIXTURE_REFUSE=guard)
                self.assertEqual(result.returncode, GUARD_STOP)
                self.assertEqual(self.calls()[-1][0], guard)
                self.assertFalse(any(call[0] == "cmake" for call in self.calls()))
                self.assertEqual(self.snapshot(self.source), before_source)
                self.assertEqual(self.snapshot(self.data), before_data)
                if guard == "clone-refs.sh":
                    (self.source / "CMakeLists.txt").write_text("# fixture source\n")

    def test_existing_sdl_library_skips_dependency_build(self):
        library = self.root / "sdl-output/lib/libSDL2.a"
        library.parent.mkdir(parents=True)
        library.write_text("fixture static library\n")
        result = self.run_entrypoint("build-ios.sh", CMAKE_BUILD_PARALLEL_LEVEL="2")
        self.assertEqual(result.returncode, ENGINE_STOP, result.stderr)
        builds = [call for call in self.calls() if call[:2] == ["cmake", "--build"]]
        self.assertEqual(builds, [["cmake", "--build", str(self.root / "engine-output"),
                                   "-j2", "--target", "mdkr64"]])
        self.assertEqual(library.read_text(), "fixture static library\n")


if __name__ == "__main__":
    unittest.main()
