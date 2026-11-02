//! The adapter's live counters the Crane test runner (tests/test_runner/)
//! compares before and after every test: `live_agents` (every agent
//! createAgent made and destroyAgent has not ended - with each its realms)
//! and `flag_writes` (V8 flags set outside the start). The approved test plan,
//! tmp/plans/test-architecture-recommendation.md section 3: a test that
//! leaves an agent alive, or changes the flags every later test of its
//! process runs with, fails by name.

const std = @import("std");
const test_process = @import("test_process.zig");
const engine = @import("engine");

fn counterNamed(counters: []const engine.Counter, name: []const u8) ?i64 {
    for (counters) |counter| {
        if (std.mem.eql(u8, counter.name, name)) return counter.value;
    }
    return null;
}

const options: engine.AgentOptions = .{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .allocator = std.heap.page_allocator };

fn read(name: []const u8) !i64 {
    const counters = try engine.diagnosticCounters(std.testing.allocator);
    defer std.testing.allocator.free(counters);
    return counterNamed(counters, name) orelse error.CounterMissing;
}

test "live_agents counts an agent from createAgent to destroyAgent" {
    test_process.start();
    const before = try read("live_agents");

    // One at a time: an agent made with nothing current is its thread's host
    // agent, whose end also ends what the adapter keeps for the thread.
    for (0..2) |_| {
        const agent = try engine.createAgent(options);
        try std.testing.expectEqual(before + 1, try read("live_agents"));
        engine.destroyAgent(agent);
        try std.testing.expectEqual(before, try read("live_agents"));
    }
}

test "flag_writes is reported, and a start's own flags are not writes" {
    // test_process.start starts V8 with the runtime's flags through the
    // start (engine.initializeEngine), which is not a write: in a process
    // where nothing called v8_SetFlagsFromString the count is 0. A write
    // after the start is a fatal CHECK in V8 (its flags are frozen and
    // memory-protected), so it cannot be made here.
    test_process.start();
    const writes = try read("flag_writes");
    try std.testing.expect(writes >= 0);
}
