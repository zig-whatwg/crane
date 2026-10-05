//! HTML 4.8.11.5: state shared by the load and resource selection algorithms.
//! Written before implementation. The red is not yet observed: chat.local is
//! unreachable from this session and local builds are forbidden (media Q1).
const std = @import("std");
const testing = std.testing;
const media = @import("html_core").media;
const State = media.LoadState;

test "new media has no resource, error, duration or pending selection" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    try testing.expectEqual(State.Network.empty, state.network);
    try testing.expectEqual(State.Ready.nothing, state.ready);
    try testing.expectEqual(State.Phase.idle, state.phase);
    try testing.expect(state.paused);
    try testing.expect(state.can_autoplay);
    try testing.expect(!state.delaying_load_event);
    try testing.expect(!state.stalled);
    try testing.expect(state.error_code == null);
    try testing.expect(std.math.isNan(state.duration));
    try testing.expectEqualStrings("", state.currentSrc());
}

test "load resets a previous resource without losing the default start position" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const first = state.beginLoad();
    _ = state.select(first.generation, .{ .src_attribute = true }, true);
    _ = try state.candidate(first.generation, .{ .url = "https://example.test/old.webm" });
    state.ready = .current_data;
    state.paused = false;
    state.seeking = true;
    state.position = 3;
    state.official_position = 2;
    state.default_start_position = 4;
    state.duration = 10;
    state.timeline_offset = 100;
    state.playback_rate = 2;
    state.default_playback_rate = 1.5;
    state.error_code = .network;
    state.can_autoplay = false;
    state.stalled = true;

    const reset = state.beginLoad();
    try testing.expect(reset.queue_abort);
    try testing.expect(reset.queue_emptied);
    try testing.expect(reset.stop_fetch);
    try testing.expect(reset.forget_tracks);
    try testing.expect(reset.reject_play_with_abort);
    try testing.expect(reset.queue_timeupdate);
    try testing.expect(reset.queue_ratechange);
    try testing.expect(reset.generation != first.generation);
    try testing.expectEqual(State.Network.no_source, state.network);
    try testing.expectEqual(State.Ready.nothing, state.ready);
    try testing.expectEqual(State.Phase.stable_state, state.phase);
    try testing.expect(state.paused and !state.seeking and !state.stalled);
    try testing.expect(state.can_autoplay and state.error_code == null);
    try testing.expectEqual(@as(f64, 0), state.position);
    try testing.expectEqual(@as(f64, 0), state.official_position);
    try testing.expectEqual(@as(f64, 4), state.default_start_position);
    try testing.expectEqual(@as(f64, 1.5), state.playback_rate);
    try testing.expect(std.math.isNan(state.duration));
    try testing.expect(std.math.isNan(state.timeline_offset));
    // currentSrc changes on selection of a new URL/object, not on load().
    try testing.expectEqualStrings("https://example.test/old.webm", state.currentSrc());
}

test "reset event conditions use the previous network state and official position" {
    for ([_]State.Network{ .empty, .idle, .loading, .no_source }) |network| {
        var state = State.init(testing.allocator);
        defer state.deinit();
        state.network = network;
        state.position = 9;
        state.official_position = 0;
        const reset = state.beginLoad();
        try testing.expectEqual(network == .idle or network == .loading, reset.queue_abort);
        try testing.expectEqual(network != .empty, reset.queue_emptied);
        try testing.expect(!reset.queue_timeupdate);
        try testing.expect(!reset.reject_play_with_abort);
        try testing.expect(!reset.queue_ratechange);
    }
}

test "source mode is chosen at stable state with object then attribute precedence" {
    const cases = [_]struct { sources: State.Sources, mode: State.Mode }{
        .{ .sources = .{}, .mode = .none },
        .{ .sources = .{ .source_child = true }, .mode = .children },
        .{ .sources = .{ .src_attribute = true, .source_child = true }, .mode = .attribute },
        .{ .sources = .{ .provider_object = true, .src_attribute = true, .source_child = true }, .mode = .object },
    };
    for (cases) |case| {
        var state = State.init(testing.allocator);
        defer state.deinit();
        const reset = state.beginLoad();
        try testing.expectEqual(State.Network.no_source, state.network);
        try testing.expect(!state.delaying_load_event);
        try testing.expectEqual(case.mode, state.select(reset.generation, case.sources, true).?);
        try testing.expectEqual(case.mode, state.mode);
        try testing.expectEqual(if (case.mode == .none) State.Network.empty else .loading, state.network);
        try testing.expectEqual(case.mode != .none, state.delaying_load_event);
    }
}

test "a reentrant load makes an older stable section and completion inert" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const stale = state.beginLoad();
    const current = state.beginLoad();
    try testing.expect(state.select(stale.generation, .{ .src_attribute = true }, true) == null);
    try testing.expectEqual(State.Phase.stable_state, state.phase);
    try testing.expectEqual(State.Network.no_source, state.network);
    try testing.expect(!state.delaying_load_event);
    _ = state.select(current.generation, .{ .src_attribute = true }, true);
    try testing.expectEqual(State.CandidateResult.ignored, try state.candidate(stale.generation, .{ .url = "https://example.test/stale" }));
    try testing.expectEqual(State.CandidateResult.fetch, try state.candidate(current.generation, .{ .url = "https://example.test/current" }));
    try testing.expectEqual(State.CandidateResult.ignored, state.failCandidate(stale.generation));
    try testing.expect(!state.runDedicatedFailure(stale.generation));
    state.endLoadDelay(stale.generation);
    try testing.expect(state.delaying_load_event);
    try testing.expectEqual(State.Phase.fetching, state.phase);
    try testing.expect(state.error_code == null);
    try testing.expectEqualStrings("https://example.test/current", state.currentSrc());
}

test "empty or invalid src selects the attribute and defers its error to a task" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const reset = state.beginLoad();
    _ = state.select(reset.generation, .{ .src_attribute = true, .source_child = true }, true);
    try testing.expectEqual(State.CandidateResult.dedicated_failure, try state.candidate(reset.generation, .{}));
    try testing.expectEqual(State.Network.loading, state.network);
    try testing.expect(state.error_code == null);
    try testing.expectEqual(State.Phase.failure_task, state.phase);
    try testing.expect(state.runDedicatedFailure(reset.generation));
    try testing.expectEqual(State.ErrorCode.source_not_supported, state.error_code.?);
    try testing.expectEqual(State.Network.no_source, state.network);
    try testing.expect(state.show_poster);
    // The caller fires error and rejects its captured promises before step 7.
    try testing.expect(state.delaying_load_event);
    state.endLoadDelay(reset.generation);
    try testing.expect(!state.delaying_load_event);
    try testing.expect(!state.runDedicatedFailure(reset.generation));
}

test "source filtering fails the candidate without updating currentSrc or fetching" {
    const candidates = [_]State.Candidate{
        .{},
        .{ .url = "https://example.test/new", .media_matches = false },
        .{ .url = "https://example.test/new", .known_unsupported_type = true },
    };
    for (candidates) |candidate| {
        var state = State.init(testing.allocator);
        defer state.deinit();
        const first = state.beginLoad();
        _ = state.select(first.generation, .{ .src_attribute = true }, true);
        _ = try state.candidate(first.generation, .{ .url = "https://example.test/old" });
        const reset = state.beginLoad();
        _ = state.select(reset.generation, .{ .source_child = true }, true);
        try testing.expectEqual(State.CandidateResult.source_error, try state.candidate(reset.generation, candidate));
        try testing.expectEqualStrings("https://example.test/old", state.currentSrc());
        try testing.expect(state.error_code == null);
        try testing.expectEqual(State.Network.loading, state.network);
    }
}

test "exhausted source children wait without raising a media error and resume at stable state" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const reset = state.beginLoad();
    _ = state.select(reset.generation, .{ .source_child = true }, true);
    _ = try state.candidate(reset.generation, .{ .url = "https://example.test/first" });
    try testing.expectEqual(State.CandidateResult.source_error, state.failCandidate(reset.generation));
    try testing.expectEqual(State.NextCandidate.wait, state.nextCandidate(reset.generation, false, true));
    try testing.expectEqual(State.Network.no_source, state.network);
    try testing.expect(state.error_code == null);
    try testing.expect(state.delaying_load_event);
    state.endLoadDelay(reset.generation);
    try testing.expect(!state.delaying_load_event);
    // The DOM owns the live pointer; insertion resumes with the same load.
    try testing.expectEqual(State.NextCandidate.process, state.nextCandidate(reset.generation, true, true));
    try testing.expectEqual(State.Network.loading, state.network);
    try testing.expect(state.delaying_load_event);
    _ = try state.candidate(reset.generation, .{ .url = "https://example.test/second" });
    try testing.expectEqualStrings("https://example.test/second", state.currentSrc());
    try testing.expect(state.error_code == null);
}

test "selected URLs are owned, replaced and freed; object mode clears currentSrc" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var url = [_]u8{ 'h', 't', 't', 'p', ':', '/', '/', 'a', '/' };
    const first = state.beginLoad();
    _ = state.select(first.generation, .{ .src_attribute = true }, true);
    _ = try state.candidate(first.generation, .{ .url = &url });
    url[7] = 'b';
    try testing.expectEqualStrings("http://a/", state.currentSrc());
    const second = state.beginLoad();
    _ = state.select(second.generation, .{ .src_attribute = true }, true);
    _ = try state.candidate(second.generation, .{ .url = "https://example.test/replacement" });
    const third = state.beginLoad();
    _ = state.select(third.generation, .{ .provider_object = true }, true);
    try testing.expectEqualStrings("", state.currentSrc());
}

test "candidate allocation failure preserves the last selected URL" {
    try testing.checkAllAllocationFailures(testing.allocator, replaceUrl, .{});
}

fn replaceUrl(allocator: std.mem.Allocator) !void {
    var state = State.init(allocator);
    defer state.deinit();
    const first = state.beginLoad();
    _ = state.select(first.generation, .{ .src_attribute = true }, true);
    _ = try state.candidate(first.generation, .{ .url = "https://example.test/first" });
    const second = state.beginLoad();
    _ = state.select(second.generation, .{ .src_attribute = true }, true);
    _ = state.candidate(second.generation, .{ .url = "https://example.test/second" }) catch |err| {
        try testing.expectEqualStrings("https://example.test/first", state.currentSrc());
        try testing.expectEqual(State.Phase.selecting, state.phase);
        return err;
    };
    try testing.expectEqualStrings("https://example.test/second", state.currentSrc());
}

test "silent cancellation invalidates pending candidates and failure tasks" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const reset = state.beginLoad();
    _ = state.select(reset.generation, .{ .src_attribute = true }, true);
    _ = try state.candidate(reset.generation, .{});
    state.cancel();
    try testing.expect(!state.runDedicatedFailure(reset.generation));
    try testing.expect(state.error_code == null);
    try testing.expectEqual(State.Phase.idle, state.phase);
    try testing.expectEqual(State.CandidateResult.ignored, state.failCandidate(reset.generation));
}
