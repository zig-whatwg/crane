//! The agent's full-collection pauses, as the adapter's diagnostic counters
//! report them (engine.diagnosticCounters): `full_gc_count`,
//! `full_gc_pause_max_us` and `full_gc_pause_p95_us`. The wrapper redesign's
//! P0 (tmp/redesign/wrapper-redesign-design.md section 7) records them on
//! base, and its later phases compare against them: C++ marking in the
//! atomic pause (P4) and the host walk (P5) lengthen exactly this time
//! (risk R4c).
//!
//! A pause is V8's GC prologue to its epilogue for one mark-compact, which
//! brackets the collection's atomic pause: V8 13.1 src/heap/heap.cc
//! Heap::CollectGarbage calls CallGCPrologueCallbacks before
//! StartObservablePause and CallGCEpilogueCallbacks after
//! StopObservablePause. Scavenges are not counted.

const std = @import("std");
const test_process = @import("test_process.zig");
const engine = @import("engine");
const ffi = @import("v8").ffi;

var test_agent: test_process.TestAgent = .{};

fn counterNamed(counters: []const engine.Counter, name: []const u8) ?i64 {
    for (counters) |counter| {
        if (std.mem.eql(u8, counter.name, name)) return counter.value;
    }
    return null;
}

fn read(name: []const u8) !i64 {
    const counters = try engine.diagnosticCounters(std.testing.allocator);
    defer std.testing.allocator.free(counters);
    return counterNamed(counters, name) orelse error.CounterMissing;
}

test "each full collection of the current agent is counted, with its pause" {
    defer test_agent.close();
    _ = try test_agent.open(.{});
    const before = try read("full_gc_count");
    // LowMemoryNotification: at least one mark-compact, as many as V8 needs.
    engine.requestGarbageCollection(test_agent.agent());
    const once = try read("full_gc_count");
    try std.testing.expect(once >= before + 1);
    engine.requestGarbageCollection(test_agent.agent());
    try std.testing.expect(try read("full_gc_count") >= once + 1);

    // A mark-compact of a live heap takes far more than a microsecond.
    const max = try read("full_gc_pause_max_us");
    const p95 = try read("full_gc_pause_p95_us");
    try std.testing.expect(max > 0);
    try std.testing.expect(p95 > 0);
    try std.testing.expect(p95 <= max);
}

test "with no agent current the pause counters read 0" {
    test_process.start();
    // What the process start makes leaves no isolate entered.
    try std.testing.expect(ffi.v8_Isolate_GetCurrent() == null);
    try std.testing.expectEqual(@as(i64, 0), try read("full_gc_count"));
    try std.testing.expectEqual(@as(i64, 0), try read("full_gc_pause_max_us"));
    try std.testing.expectEqual(@as(i64, 0), try read("full_gc_pause_p95_us"));
}

test "an agent's pauses are its own: a fresh agent starts from none of another's" {
    defer test_agent.close();
    _ = try test_agent.open(.{});
    for (0..3) |_| engine.requestGarbageCollection(test_agent.agent());
    const first = try read("full_gc_count");
    try std.testing.expect(first >= 3);
    test_agent.close();

    // A new agent: what the first counted is not its count. Its own start
    // may collect, but never as often as three LowMemoryNotifications did.
    _ = try test_agent.open(.{});
    try std.testing.expect(try read("full_gc_count") < first);
}
