//! Every agent has a C++ heap (cppgc) - the wrapper redesign's phase P3
//! (tmp/redesign/wrapper-redesign-design.md, section 7 P3; 4.9, 4.12; risks
//! R6 and R7). Nothing in Crane allocates on it yet: P4 puts node wrappers'
//! anchors there. What P3 must prove before anything relies on it:
//!
//! - the agent has a heap, made afresh or restored from the snapshot, and a
//!   worker agent has one too (design decision 6: every agent, as every Blink
//!   thread with V8 has its ThreadState's CppHeap);
//! - the heap and the code compiled against its headers agree: a
//!   `cppgc::Member` is 4 bytes (CPPGC_POINTER_COMPRESSION) and reads back
//!   the object it was given (the compression shift - CPPGC_ENABLE_LARGER_CAGE
//!   in the macOS and Linux archives), so build.zig's defines are the
//!   archive's (R7: a mismatch corrupts the heap far from its cause);
//! - a forced collection keeps a Member's target while its holder is rooted
//!   by a `cppgc::Persistent`, and frees both once it is not;
//! - a C++ `Trace` runs on the agent's thread, inside a major GC's pause - the
//!   atomic marking (`CppHeapCreateParams.marking_support = kAtomic`) the
//!   host's tree walk will rely on (R6), never while script runs;
//! - an agent's end frees its heap (cppgc's heap registry counts it): V8
//!   13.1.203 never frees a heap given in CreateParams, and leaks --atExit
//!   cannot see that, the heap staying reachable from the registry;
//! - the diagnostics tier reports the heap's bytes (`cpp_heap_used_bytes`);
//!   since V8 14 that includes V8's own objects on the heap it owns.
//!
//! The probe is v8_wrapper.cpp's (v8_test_CppHeapProbe_*): a holder holding a
//! leaf through a Member, observed through weak persistents, collected with no
//! conservative stack scan.

const std = @import("std");
const testing = std.testing;
const test_process = @import("test_process.zig");
const engine = @import("engine");
const ffi = @import("v8").ffi;

/// The snapshot this build generated (build.zig passes its path).
const snapshot_path = @import("test_snapshot").path;

var test_agent: test_process.TestAgent = .{};

fn probeState(probe: *ffi.CppHeapProbe) ffi.CppHeapProbeState {
    var state: ffi.CppHeapProbeState = undefined;
    ffi.v8_test_CppHeapProbe_State(probe, &state);
    return state;
}

/// The diagnostics tier's counter `name`, for the current isolate.
fn counter(name: []const u8) !i64 {
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    return error.CounterMissing;
}

/// The probe's whole life on `isolate` (entered, on the calling thread): its
/// Member reads back its leaf before anything collects; a forced collection
/// keeps holder and leaf while rooted; another frees both once the root is
/// dropped; every Trace ran on this thread inside a major GC's pause.
fn exerciseProbe(isolate: *ffi.Isolate) !void {
    const probe = ffi.v8_test_CppHeapProbe_New(isolate) orelse return error.NoCppHeap;
    defer ffi.v8_test_CppHeapProbe_Delete(probe);

    // Before any collection: a Member whose compression disagrees with the
    // library's would read back another address here - and crash the
    // marker below.
    var state = probeState(probe);
    try testing.expect(state.member_matches);

    ffi.v8_test_CppHeapProbe_Collect(probe);
    state = probeState(probe);
    try testing.expect(state.holder_alive);
    try testing.expect(state.leaf_alive);
    try testing.expect(state.member_matches);
    try testing.expect(state.traces > 0);

    ffi.v8_test_CppHeapProbe_DropRoot(probe);
    ffi.v8_test_CppHeapProbe_Collect(probe);
    state = probeState(probe);
    try testing.expect(!state.holder_alive);
    try testing.expect(!state.leaf_alive);

    try testing.expectEqual(@as(u32, 0), state.traces_off_thread);
    try testing.expectEqual(@as(u32, 0), state.traces_outside_pause);
}

test "an agent createAgent makes has a C++ heap" {
    defer test_agent.close();
    const isolate = try test_agent.open(.{});
    try testing.expect(ffi.v8_Isolate_HasCppHeap(isolate));
}

test "an agent's end frees its C++ heap: cppgc's heap registry is back where it was" {
    // The process's count of live C++ heaps (each registers when made and
    // unregisters when freed). V8 13.1.203 terminates a heap given in
    // CreateParams inside Isolate::Dispose but never deletes it
    // (Heap::StartTearDown): this count is the only thing that sees that -
    // leaks --atExit reports 0, the heap staying reachable from the registry.
    // The adapter's record frees it (v8_wrapper.cpp IsolateData::cpp_heap).
    // The count is the process's: build.zig runs this test alone beside the
    // many-Browsers variant's busy Browser (v8_alone).
    test_process.start();
    const before = ffi.v8_test_CppgcLiveHeaps();
    for (0..3) |_| {
        const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null, .allocator = std.heap.c_allocator });
        try testing.expectEqual(before + 1, ffi.v8_test_CppgcLiveHeaps());
        engine.destroyAgent(agent);
        try testing.expectEqual(before, ffi.v8_test_CppgcLiveHeaps());
    }
    // worker_realm's bare isolate the same way.
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateFailed;
    try testing.expectEqual(before + 1, ffi.v8_test_CppgcLiveHeaps());
    ffi.v8_Isolate_Dispose(isolate);
    try testing.expectEqual(before, ffi.v8_test_CppgcLiveHeaps());
}

test "cppgc::Member is 4 bytes, as the archive's CPPGC_POINTER_COMPRESSION makes it" {
    try testing.expectEqual(@as(usize, 4), ffi.v8_test_CppgcMemberSize());
}

test "a Member's target survives a forced collection through a Persistent and is freed without it" {
    defer test_agent.close();
    const isolate = try test_agent.open(.{});
    try exerciseProbe(isolate);
}

test "a C++ Trace runs on the agent's thread inside a major GC's pause, while script allocates and after" {
    defer test_agent.close();
    const isolate = try test_agent.open(.{});
    const context = test_agent.context.?;
    const probe = ffi.v8_test_CppHeapProbe_New(isolate) orelse return error.NoCppHeap;
    defer ffi.v8_test_CppHeapProbe_Delete(probe);

    // Garbage with survivors, so that V8 collects while the script runs: its
    // scavenges never mark C++ objects, and a mark-compact it starts here
    // (incremental marking finalized in the pause) may or may not come - the
    // forced collection below always does.
    const code =
        \\let kept = [];
        \\for (let i = 0; i < 300000; i++) {
        \\  kept.push({ i, s: 'cell ' + i });
        \\  if (kept.length === 30000) kept = [];
        \\}
        \\kept.length
    ;
    const text = ffi.v8_String_NewFromUtf8(isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    ffi.v8_Value_Dispose(value);

    ffi.v8_test_CppHeapProbe_Collect(probe);
    const state = probeState(probe);
    try testing.expect(state.holder_alive);
    try testing.expect(state.traces > 0);
    try testing.expectEqual(@as(u32, 0), state.traces_off_thread);
    try testing.expectEqual(@as(u32, 0), state.traces_outside_pause);
}

test "cpp_heap_used_bytes reports the current agent's C++ objects" {
    defer test_agent.close();
    const isolate = try test_agent.open(.{});
    // A fresh agent's heap is not empty: V8 >= 14 allocates there itself -
    // its default MicrotaskQueue, Managed<T>'s CppGCManagedWrapper, and an
    // EmbedderDataSlotWrapper for every aligned pointer in an internal field
    // or a context's embedder data (V8 d04704a20fc, in 15.7.112.43). The
    // probe's objects are what its collections add and take back.
    const probe = ffi.v8_test_CppHeapProbe_New(isolate) orelse return error.NoCppHeap;
    defer ffi.v8_test_CppHeapProbe_Delete(probe);
    // Marked and kept: the holder and its leaf.
    ffi.v8_test_CppHeapProbe_Collect(probe);
    const kept = try counter("cpp_heap_used_bytes");
    try testing.expect(kept > 0);
    try testing.expectEqual(@as(usize, @intCast(kept)), ffi.v8_Isolate_CppHeapUsedBytes(isolate));
    // Both freed: the count falls by what they held.
    ffi.v8_test_CppHeapProbe_DropRoot(probe);
    ffi.v8_test_CppHeapProbe_Collect(probe);
    const freed = try counter("cpp_heap_used_bytes");
    try testing.expect(freed < kept);
    try testing.expectEqual(@as(usize, @intCast(freed)), ffi.v8_Isolate_CppHeapUsedBytes(isolate));
}

/// A worker's agent, made as html.worker_host makes it - [[CanBlock]] true,
/// never restored from the snapshot - on a thread of its own, and the bare
/// isolate worker_realm.createAgent makes; each probed on that thread.
const WorkerSide = struct {
    agent_has_heap: bool = false,
    bare_has_heap: bool = false,
    failure: ?anyerror = null,

    fn run(self: *WorkerSide) void {
        self.body() catch |err| {
            self.failure = err;
        };
    }

    fn body(self: *WorkerSide) !void {
        {
            const agent = try engine.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null, .allocator = std.heap.c_allocator });
            defer engine.destroyAgent(agent);
            const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
            ffi.v8_Isolate_Enter(isolate);
            defer ffi.v8_Isolate_Exit(isolate);
            self.agent_has_heap = ffi.v8_Isolate_HasCppHeap(isolate);
            const scope = ffi.v8_HandleScope_New(isolate);
            defer ffi.v8_HandleScope_Dispose(scope);
            try exerciseProbe(isolate);
        }
        {
            const isolate = ffi.v8_Isolate_New() orelse return error.IsolateFailed;
            defer ffi.v8_Isolate_Dispose(isolate);
            self.bare_has_heap = ffi.v8_Isolate_HasCppHeap(isolate);
        }
    }
};

test "a worker's agent has a C++ heap, and its Trace runs on the worker's thread" {
    test_process.start();
    var side: WorkerSide = .{};
    const thread = try std.Thread.spawn(.{}, WorkerSide.run, .{&side});
    thread.join();
    if (side.failure) |err| return err;
    try testing.expect(side.agent_has_heap);
    try testing.expect(side.bare_has_heap);
}

test "an agent restored from the snapshot has a C++ heap" {
    // Read for each test, never cached: restoring Crane's blob after other
    // isolates of the process came from V8's built-in snapshot is refused
    // (v8_wrapper.cpp g_read_only_heap), so this runs only as its process's
    // first V8 user (tests-v8 runs a process per test).
    if (ffi.v8_Platform_IsInitialized()) {
        std.log.warn("skipping: V8 was started in this process before this test; run it in a process of its own (tests-v8 runs at batch 1; -Dlaunch-batch=1 or -Dtest-file=)", .{});
        return error.SkipZigTest;
    }
    const io = testing.io;
    const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
    defer file.close(io);
    const size = (try file.stat(io)).size;
    const bytes = try std.heap.c_allocator.alloc(u8, size);
    defer std.heap.c_allocator.free(bytes);
    _ = try file.readPositionalAll(io, bytes, 0);

    try test_process.startSnapshot(bytes);
    defer test_process.endSnapshot();
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &test_process.no_hooks, .host = null, .allocator = std.heap.c_allocator });
    defer engine.destroyAgent(agent);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    try testing.expect(ffi.v8_Isolate_IsFromSnapshot(isolate));
    try testing.expect(ffi.v8_Isolate_HasCppHeap(isolate));
}
