//! Every terminal resource path must release its document's load delay.
const std = @import("std");
const State = @import("html_core").media.LoadState;
const testing = std.testing;

fn loading() State {
    var state = State.init(testing.allocator);
    const generation = state.beginSelection();
    _ = state.select(generation, .{ .src_attribute = true }, true);
    return state;
}

test "reloading releases the old document delay before the new stable section" {
    var state = loading();
    defer state.deinit();
    _ = state.beginLoad();
    try testing.expect(!state.delaying_load_event);
}

test "aborting for removal or unload releases the load delay and ignores stale continuations" {
    for (0..2) |_| {
        var state = loading();
        defer state.deinit();
        const generation = state.generation;
        state.cancel();
        try testing.expect(!state.delaying_load_event);
        try testing.expect(generation != state.generation);
    }
}

test "fatal network failure, suspend, and current data release the load delay" {
    var failed = loading();
    defer failed.deinit();
    failed.fatalFailure(failed.generation, .network);
    try testing.expect(!failed.delaying_load_event);
    try testing.expectEqual(State.ErrorCode.network, failed.error_code.?);
    var suspended = loading();
    defer suspended.deinit();
    suspended.suspendFetch(suspended.generation);
    try testing.expect(!suspended.delaying_load_event);
    try testing.expectEqual(State.Network.idle, suspended.network);
    var ready = loading();
    defer ready.deinit();
    _ = ready.decoderData(ready.generation, .current_data, false, false).?;
    try testing.expect(!ready.delaying_load_event);
    try testing.expectEqual(State.Ready.current_data, ready.ready);
}

test "an old resource cannot change readiness, error, or network state after reload" {
    var state = loading();
    defer state.deinit();
    const old = state.generation;
    const current = state.beginLoad();
    _ = state.select(current.generation, .{ .src_attribute = true }, true);
    state.fatalFailure(old, .network);
    state.suspendFetch(old);
    try testing.expect(state.decoderData(old, .current_data, false, false) == null);
    try testing.expect(state.delaying_load_event);
    try testing.expectEqual(State.Network.loading, state.network);
    try testing.expectEqual(State.Ready.nothing, state.ready);
    try testing.expect(state.error_code == null);
}
