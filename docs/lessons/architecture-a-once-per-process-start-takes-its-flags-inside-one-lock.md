# Architecture: A once-per-process start takes its flags inside one lock, and every lazy start applies the host's flags

**Date**: 2026-11-01
**Lesson**: V8 starts once per process and FATALs on a second or concurrent start, so its start - the flags AND the platform - is one call under one lock, and a convenience start on the isolate path must apply the same flags the host's start does.

**Why**: V8::InitializePlatform and V8::Initialize advance a process-wide state machine and abort when two threads race it ("Wrong initialization order", "Multiple threads are initializating V8": 13.1.203 src/init/v8.cc AdvanceStartupState), and V8 freezes its flags in V8::Initialize. Chromium starts V8 once, from one thread, at process start, with the flags set inside the same start (gin/v8_initializer.cc V8Initializer::Initialize), and every IsolateHolder CHECKs that start came first (gin/isolate_holder.cc). Crane's host does the same (engine.initializeEngine from crane.Process.init), but v8_Isolate_New also started V8 for a caller that skipped it - a test, a tool - behind an unlocked bool, and with no flags at all.

**What Happened**: Lane tlaunch2 ran tests-v8 one test per process and found template_registry_isolation_test's two-thread test crashing every time alone: two threads making the process's first isolates both read the bool false, both replaced `g_platform`, and the second V8::InitializePlatform aborted. In the shared suite it passed only because an earlier file had started V8. TSAN named the race (`Location is global 'g_platform'`, v8_Platform_Initialize <- v8_Isolate_New). Two quieter defects sat beside it: the host's start was two calls (SetFlagsFromString, then Initialize), a check-then-act a lazy start could fall between; and a lazy start applied NO flags, after which initializeEngine saw "already started" and silently ran the process without the runtime flags (ShadowRealm, Float16Array, the wasm features), so which flags a test had depended on which test made its process's first isolate.

**Fix**:
1. `v8_Platform_Start(flags)` (v8_wrapper.cpp): the flags, then the platform, under one mutex, published with a release store that every reader acquires; it answers started-now, already-started, started-with-other-flags or disposed. Every start goes through it: snapshot_loader's two helpers, the snapshot generator, initializeEngine.
2. A caller whose flags differ from the start's is told so, and its helper says so at err level - never passed over.
3. ffi.zig's `v8_Isolate_New`, `v8_Isolate_NewFromSnapshot` and `v8_Platform_Initialize` start V8 with snapshot_loader.RUNTIME_V8_FLAGS, as initializeEngine does, so the convenience start and the host's start are the same start whichever comes first. The C++ entries keep a flagless, thread-safe net below them.
4. Tests that make isolates start the engine as a process does, each test for itself (template_registry_isolation_test's `startEngine`).

**Takeaway**: **A once-only start is the start and its configuration together, under one lock - and a lazy start is the host's start, flags included, or which configuration a process gets depends on who came first.**
