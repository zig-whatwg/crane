//! HTML 4.8.11.5: state shared by the load and resource selection algorithms.
//! Written before implementation; missing-module red and passing green observed
//! on chat.local (2026-10-05, media Q8).
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

// =============================================================================
// Ready states and playback (HTML 4.8.11.7, 4.8.11.8), hostmedia lane
// =============================================================================
//
// A decoder reports metadata, or data at the current playback position
// (platform.media_backend.Result). Crane derives the rest: a current_data
// result on the end_of_stream push means every byte has arrived, so waiting
// longer will not get more data - HAVE_ENOUGH_DATA's second condition - while
// the position is short of the end. At the end there is no more data in the
// direction of playback: HAVE_CURRENT_DATA.

/// A state with a selected, fetching resource of `duration` seconds.
fn fetching(state: *State, duration: f64) !u64 {
    const reset = state.beginLoad();
    _ = state.select(reset.generation, .{ .src_attribute = true }, true);
    _ = try state.candidate(reset.generation, .{ .url = "https://example.test/a.wav" });
    try testing.expect(state.setDuration(duration));
    return reset.generation;
}

test "metadata, then current data before end of stream, stays HAVE_CURRENT_DATA" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 1);
    const metadata = state.decoderData(generation, .metadata, false, false).?;
    try testing.expectEqual(State.Ready.metadata, state.ready);
    try testing.expect(metadata.loadedmetadata and !metadata.loadeddata and !metadata.canplay);
    const data = state.decoderData(generation, .current_data, false, false).?;
    try testing.expectEqual(State.Ready.current_data, state.ready);
    try testing.expect(data.loadeddata and !data.canplay and !data.canplaythrough and !data.loadedmetadata);
    try testing.expect(!state.delaying_load_event);
    // More data short of the end of the stream changes nothing.
    const again = state.decoderData(generation, .current_data, false, false).?;
    try testing.expectEqual(State.ReadyChange{}, again);
    try testing.expectEqual(State.Ready.current_data, state.ready);
}

test "current data on the end-of-stream push is HAVE_ENOUGH_DATA: canplay, then canplaythrough" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 1);
    _ = state.decoderData(generation, .metadata, false, false).?;
    _ = state.decoderData(generation, .current_data, false, false).?;
    const end = state.decoderData(generation, .current_data, true, false).?;
    try testing.expectEqual(State.Ready.enough_data, state.ready);
    try testing.expect(end.canplay and end.canplaythrough and !end.notify_playing and !end.loadeddata);
}

test "the whole resource in one push goes through every ready state's events once" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 2);
    const change = state.decoderData(generation, .current_data, true, false).?;
    try testing.expectEqual(State.Ready.enough_data, state.ready);
    try testing.expectEqual(State.ReadyChange{ .loadedmetadata = true, .loadeddata = true, .canplay = true, .canplaythrough = true }, change);
}

test "a stale generation's decoder result changes nothing" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 1);
    state.cancel();
    try testing.expect(state.decoderData(generation, .current_data, true, false) == null);
    try testing.expectEqual(State.Ready.nothing, state.ready);
}

test "loadeddata fires once per load, even if the ready state falls back and returns" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 1);
    try testing.expect(state.decoderData(generation, .current_data, false, false).?.loadeddata);
    _ = state.changeReady(.metadata, false);
    try testing.expect(!state.changeReady(.current_data, false).loadeddata);
    // A new load fires it again.
    const next = try fetching(&state, 1);
    try testing.expect(state.decoderData(next, .current_data, false, false).?.loadeddata);
}

test "play before data: play then waiting; reaching HAVE_ENOUGH_DATA notifies about playing" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 1);
    _ = state.decoderData(generation, .current_data, false, false).?;
    const play = state.play(false);
    try testing.expect(play.play_event and play.waiting and !play.notify_playing and !play.select and !play.seek_to_start);
    try testing.expect(!state.paused);
    try testing.expect(!state.can_autoplay);
    try testing.expect(!state.potentiallyPlaying(false));
    const end = state.decoderData(generation, .current_data, true, false).?;
    try testing.expect(end.canplay and end.notify_playing and end.canplaythrough);
    try testing.expect(state.potentiallyPlaying(false));
}

test "play with enough data notifies about playing; play while playing resolves" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 1);
    _ = state.decoderData(generation, .current_data, true, false).?;
    const first = state.play(false);
    try testing.expect(first.play_event and first.notify_playing and !first.waiting and !first.resolve_pending);
    const second = state.play(false);
    try testing.expect(!second.play_event and !second.notify_playing and second.resolve_pending);
    // Play on an empty element starts resource selection first.
    var empty = State.init(testing.allocator);
    defer empty.deinit();
    const select = empty.play(false);
    try testing.expect(select.select and select.play_event and select.waiting);
}

test "the clock advances only while potentially playing, at the playback rate" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 2);
    _ = state.decoderData(generation, .current_data, true, false).?;
    try testing.expectEqual(State.Boundary.none, state.advance(0.5, false));
    try testing.expectEqual(@as(f64, 0), state.position);
    _ = state.play(false);
    try testing.expectEqual(State.Boundary.none, state.advance(0.5, false));
    try testing.expectEqual(@as(f64, 0.5), state.position);
    state.playback_rate = 2;
    try testing.expectEqual(State.Boundary.none, state.advance(0.25, false));
    try testing.expectEqual(@as(f64, 1), state.position);
    state.playback_rate = 0;
    try testing.expectEqual(State.Boundary.none, state.advance(5, false));
    try testing.expectEqual(@as(f64, 1), state.position);
    state.playback_rate = 1;
    try testing.expect(state.pause());
    try testing.expect(!state.pause());
    try testing.expectEqual(State.Boundary.none, state.advance(5, false));
    try testing.expectEqual(@as(f64, 1), state.position);
}

test "reaching the end: position clamps to the duration, HAVE_CURRENT_DATA, ended playback" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 1);
    _ = state.decoderData(generation, .current_data, true, false).?;
    _ = state.play(false);
    try testing.expect(!state.endedPlayback(false));
    try testing.expectEqual(State.Boundary.end, state.advance(3, false));
    try testing.expectEqual(@as(f64, 1), state.position);
    try testing.expect(state.endedPlayback(false));
    // A loop attribute means the end is not ended playback.
    try testing.expect(!state.endedPlayback(true));
    // The ready state at the end: no more data in the direction of playback,
    // and the drop from HAVE_ENOUGH_DATA queues no waiting - playback ended.
    try testing.expectEqual(State.Ready.current_data, state.readyNow(false));
    const change = state.changeReady(state.readyNow(false), false);
    try testing.expectEqual(State.Ready.current_data, state.ready);
    try testing.expectEqual(State.ReadyChange{}, change);
    try testing.expect(!state.potentiallyPlaying(false));
    // Play again from the end seeks back to the start first.
    const replay = state.play(false);
    try testing.expect(replay.seek_to_start);
}

test "a drop below HAVE_FUTURE_DATA while potentially playing queues timeupdate and waiting" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 4);
    _ = state.decoderData(generation, .current_data, true, false).?;
    _ = state.play(false);
    try testing.expect(state.potentiallyPlaying(false));
    const change = state.changeReady(.current_data, false);
    try testing.expect(change.timeupdate_waiting);
    try testing.expect(!state.potentiallyPlaying(false));
    // Paused: no waiting.
    _ = state.changeReady(.enough_data, false);
    _ = state.pause();
    try testing.expect(!state.changeReady(.current_data, false).timeupdate_waiting);
}

test "duration changes are reported once per new value, NaN included" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    try testing.expect(!state.setDuration(std.math.nan(f64)));
    try testing.expect(state.setDuration(1.5));
    try testing.expect(!state.setDuration(1.5));
    try testing.expect(state.setDuration(0.25));
    try testing.expectEqual(@as(f64, 0.25), state.duration);
}

test "a seek needs a resource, clamps to the media timeline, and a newer seek fences the older" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    try testing.expect(state.beginSeek(1) == null);
    const generation = try fetching(&state, 2);
    _ = state.decoderData(generation, .current_data, true, false).?;
    const first = state.beginSeek(5).?;
    try testing.expect(state.seeking);
    try testing.expectEqual(@as(f64, 2), state.position);
    try testing.expectEqual(@as(f64, 2), state.official_position);
    const second = state.beginSeek(-1).?;
    try testing.expectEqual(@as(f64, 0), state.position);
    try testing.expect(!state.finishSeek(first));
    try testing.expect(state.seeking);
    try testing.expect(state.finishSeek(second));
    try testing.expect(!state.seeking);
    try testing.expect(!state.finishSeek(second));
}

test "a decoder that reports no end of stream never claims enough data" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    const generation = try fetching(&state, 1);
    _ = state.decoderData(generation, .metadata, true, false).?;
    try testing.expectEqual(State.Ready.metadata, state.ready);
    try testing.expectEqual(State.Ready.metadata, state.readyNow(false));
}
