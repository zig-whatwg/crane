//! A custom element agent's reaction queues under a runner's churn (lane
//! hashmaps1): `Reactions.pending` is the agent's - a Browser's, alive for
//! every page the process loads - and holds each element record with
//! reactions waiting, put at the record's first reaction and removed when
//! its last one is taken. A record is a fresh allocation per element per
//! [CEReactions] scope, so the map keeps seeing new keys.
//!
//! std's map never grows while puts and removes balance and never clears
//! its tombstones (src/infra/tombstones.zig). One page that upgrades
//! thousands of elements at once grows the table; every page after it then
//! walks the whole of it for each new element's reaction. In a 1,069-file
//! runner sample the map was out of free slots in 152 of 154 samples.

const std = @import("std");
const testing = std.testing;
const html_core = @import("html_core");
const tombstones = @import("infra").tombstones;
const AgentState = html_core.custom_element_agent.AgentState;

const Root = struct {
    pub fn release(_: Root) void {}
};
const Payload = struct {
    value: u32,
    pub fn deinit(_: *Payload) void {}
};
fn realmIsLive(_: u32) bool {
    return true;
}
const Returns = html_core.custom_element_returns.PendingReturns(u32, Root);
const State = AgentState(u32, u32, Payload, Root, Returns, realmIsLive);
fn acquire(_: void, _: u32) !Root {
    return .{};
}

const Invoked = struct {
    count: usize = 0,
    fn invoke(self: *Invoked, _: u32, _: *Payload) void {
        self.count += 1;
    }
};

/// One [CEReactions] scope over `n` elements never seen before, one
/// reaction each.
fn scope(state: *State, invoked: *Invoked, first: u32, n: u32, worst: ?*Worst) !void {
    state.begin();
    for (0..n) |i| {
        _ = try state.enqueue({}, first + @as(u32, @intCast(i)), 1, .{ .value = 1 }, acquire);
        if (i == 0) if (worst) |w| w.note(&state.queues.pending);
    }
    state.end(invoked, Invoked.invoke);
}

const Worst = struct {
    probe: usize = 0,
    starved: usize = 0,

    fn note(self: *Worst, map: anytype) void {
        self.probe = @max(self.probe, tombstones.meanMissProbe(map));
        if (!tombstones.slotCounts(map).halfOfUnusedFree()) self.starved += 1;
    }
};

test "an agent's pending reactions keep half the unused slots free after a big upgrade, page after page" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var invoked: Invoked = .{};
    // One page upgrades 5,000 elements in one scope: the table grows.
    try scope(&state, &invoked, 1, 5_000, null);
    // Then 1,000 pages of ordinary churn, 16 new elements each.
    var worst: Worst = .{};
    var next: u32 = 10_000;
    for (0..1_000) |_| {
        try scope(&state, &invoked, next, 16, &worst);
        next += 16;
    }
    try testing.expectEqual(@as(usize, 5_000 + 1_000 * 16), invoked.count);
    if (worst.starved != 0 or worst.probe > 8) {
        const counts = tombstones.slotCounts(&state.queues.pending);
        std.debug.print("Reactions.pending: {d} of 1,000 pages began with fewer than half the unused slots free; worst mean miss {d} (capacity {d}, live {d}, free {d})\n", .{ worst.starved, worst.probe, counts.capacity, counts.live, counts.free });
        return error.TombstonesFilledTheMap;
    }
}

/// A reaction whose callback enqueues reactions for new elements, as a
/// connectedCallback that appends custom elements does.
const Nesting = struct {
    state: *State,
    invoked: usize = 0,
    next: u32 = 1_000_000,
    spawned: usize = 0,

    fn invoke(self: *Nesting, _: u32, payload: *Payload) void {
        self.invoked += 1;
        if (payload.value == 0) return;
        // Each reaction spawns eight more, with no further nesting: inserts
        // into `pending` while the reactions being invoked are still taken
        // from it, element by element.
        for (0..8) |_| {
            _ = self.state.enqueue({}, self.next, 1, .{ .value = 0 }, acquire) catch unreachable;
            self.next += 1;
            self.spawned += 1;
        }
    }
};

test "reactions enqueued from inside an invocation, through rehashes, are each invoked once" {
    // The integrator's check 1: an insert into `pending` while reactions
    // are being invoked. Invocation takes each element's reactions out by
    // lookup, one at a time, and looks again after script; nothing holds
    // an iterator or a value pointer into the map across a callback.
    var state = State.init(testing.allocator);
    defer state.deinit();
    var invoked: Invoked = .{};
    // Leave tombstones behind, so the inserts below rehash.
    try scope(&state, &invoked, 1, 2_000, null);
    for (0..20) |round| try scope(&state, &invoked, 100_000 + @as(u32, @intCast(round)) * 64, 64, null);
    var nesting: Nesting = .{ .state = &state };
    state.begin();
    for (0..64) |i| _ = try state.enqueue({}, 500_000 + @as(u32, @intCast(i)), 1, .{ .value = 1 }, acquire);
    state.end(&nesting, Nesting.invoke);
    // The 64 spawned 512 more, enqueued with no scope open: the backup queue.
    try testing.expectEqual(@as(usize, 64 * 8), nesting.spawned);
    state.invokeBackup(&nesting, Nesting.invoke);
    try testing.expectEqual(@as(usize, 64 + 64 * 8), nesting.invoked);
    try testing.expectEqual(@as(usize, 0), state.queues.pending.count());
}
