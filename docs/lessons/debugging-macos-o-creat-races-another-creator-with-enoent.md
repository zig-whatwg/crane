# Debugging: On macOS, an O_CREAT open that races another creator of the same name fails with ENOENT

**Date**: 2026-11-01
**Lesson**: Several threads or processes that open the same new file with O_CREAT at once can get ENOENT although the directory exists. A FileNotFound that shows up only on cold runs and only the first time is this race.

**Why**: The kernel looks the name up, finds nothing, and tries to create it. When another creator has just made the file, macOS can return ENOENT for the losing open instead of looking again and opening the new file. Once the file exists, nothing races, so the failure appears only while files are being created for the first time. std.Build.Cache hits the same race with its manifests (lib/std/Build/Cache.zig, Manifest.hit: "we have observed on macOS two processes racing to do openat() with O_CREAT manifest in ENOENT").

**What Happened**: After tools/test_launcher took over `zig build test`, a cold build failed 30 tests with "launcher: could not start the test process: FileNotFound", and every one of them passed alone (FLAKY). Each launcher takes a build-wide slot before it starts a child process: one of N lock files in `<cache>/test-launcher-slots`, opened with O_CREAT. On a cold build that directory is empty, and every worker of the first launchers takes a slot at the same moment. Three hypotheses were tested:
- a relative executable path: ruled out, because the failing command line showed absolute paths and the launcher had just spawned the same executable to list its tests;
- a slot directory removed under the launcher: ruled out, because the handle would stay on the deleted directory and every later start would fail too, but the alone runs passed;
- a race on creating the slot files: confirmed. A unit test started 8 launchers at once into an empty directory, 300 times. On chat.local (macOS 27), 2,087 of the 2,400 failed with FileNotFound. With the files created beforehand (the control), none failed.

**Fix**:
1. Use std.Build.Cache's workaround (tools/test_launcher/slots.zig, `openOrCreate`). On ENOENT from the O_CREAT open, create the file with O_EXCL. EEXIST means the open lost the race, so open the file again. ENOENT means the directory itself is gone, a real error. Retries are bounded.
2. Keep the cause of a failure that belongs to the harness. A failed process start had been recorded as each test crashing, and the classifier then made every one FLAKY. It is now its own verdict, LAUNCHER-ERROR. The test is not re-run, the step fails, and the output prints one `error: 'test <suite>' failed:` line with the path and the errno.
3. Pin both parts with tests: the concurrent cold start, a slot directory removed after it was opened, a missing executable, and the step-failure line the gate scripts grep.

**Takeaway**: **A FileNotFound that appears only on cold runs, only the first time, and never alone points to concurrent first-time creation. Reproduce it with N creators started together into an empty directory, compare against files that already exist, and create the file with an O_EXCL fallback.**
