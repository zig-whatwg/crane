//! `send.sendAsyncFinish`: an asynchronous send() once its fetch - run on
//! the event loop by the WebIDL impl - has an outcome.
//!
//! An asynchronous request used to run its whole fetch inside a task, blocked
//! in curl, so nothing else ran until it finished, two requests finished in
//! the order they were sent, and a timeout or abort() could not end one early.
//! Now the impl fetches on the event loop and hands the outcome here from a
//! task. These pin what that outcome does, with the same recording sink
//! `send_async_test.zig` uses: the events, in order, and the state they leave.

const std = @import("std");
const testing = std.testing;
const xhr_root = @import("xhr");
const fetch = @import("fetch");
const XMLHttpRequestState = xhr_root.XMLHttpRequestState;
const ReadyState = xhr_root.ReadyState;
const XHREventType = xhr_root.XHREventType;
const EventTargetKind = xhr_root.EventTargetKind;
const ProgressEventData = xhr_root.ProgressEventData;
const open = xhr_root.open.open;
const send_algo = xhr_root.send;
const FetchResult = fetch.algorithms.FetchResult;
const FetchError = fetch.algorithms.FetchError;

const Recorder = struct {
    names: std.ArrayListUnmanaged([]const u8) = .empty,
    states: std.ArrayListUnmanaged(ReadyState) = .empty,
    state: *XMLHttpRequestState,

    fn fire(ctx: *anyopaque, target: EventTargetKind, event_type: XHREventType, progress: ?ProgressEventData) void {
        _ = progress;
        const self: *Recorder = @ptrCast(@alignCast(ctx));
        if (target != .xhr) return;
        self.names.append(testing.allocator, event_type.name()) catch {};
        self.states.append(testing.allocator, self.state.ready_state) catch {};
    }

    fn deinit(self: *Recorder) void {
        self.names.deinit(testing.allocator);
        self.states.deinit(testing.allocator);
    }

    fn expectNames(self: *const Recorder, expected: []const []const u8) !void {
        try testing.expectEqual(expected.len, self.names.items.len);
        for (expected, self.names.items) |e, a| try testing.expectEqualStrings(e, a);
    }
};

/// An opened async GET whose send() has run up to the fetch - what the impl
/// does before handing req to the event loop.
fn sent(state: *XMLHttpRequestState, recorder: *Recorder) !void {
    try open(state, "GET", "http://example.com/data", true, null, null, null, false);
    state.event_sink = .{ .ctx = @ptrCast(recorder), .fire = &Recorder.fire };
    const body = try send_algo.sendPrologue(state, null);
    try testing.expect(send_algo.sendStart(state, body));
}

fn responseWith(status: u16, body: ?[]const u8) !FetchResult {
    const response = try fetch.internal.InternalResponse.init(testing.allocator);
    errdefer response.deinit();
    response.status = status;
    try response.addUrl("http://example.com/data");
    if (body) |b| response.body = try fetch.internal.Body.fromBytes(testing.allocator, b);
    return .{ .response = response, .timing_info = fetch.internal.FetchTimingInfo.init(testing.allocator) };
}

test "a response runs headers received, loading and done, then load and loadend" {
    var state = XMLHttpRequestState.init(testing.allocator);
    defer state.deinit();
    var recorder = Recorder{ .state = &state };
    defer recorder.deinit();
    try sent(&state, &recorder);

    var processor = xhr_root.response.ResponseProcessor.init(&state);
    try std.testing.expect((try send_algo.sendAsyncFinish(&state, null, try responseWith(200, "hello"), &processor)) == null);

    // loadstart (send()), headers received, then - whether the throttled
    // body chunk reported itself or not - end-of-body's progress, done, load
    // and loadend.
    const names = recorder.names.items;
    try testing.expect(names.len >= 6);
    try testing.expectEqualStrings("loadstart", names[0]);
    try testing.expectEqualStrings("readystatechange", names[1]);
    try testing.expectEqual(ReadyState.HEADERS_RECEIVED, recorder.states.items[1]);
    for ([_][]const u8{ "progress", "readystatechange", "load", "loadend" }, names[names.len - 4 ..]) |e, a| {
        try testing.expectEqualStrings(e, a);
    }
    try testing.expectEqual(ReadyState.DONE, state.ready_state);
    try testing.expectEqualStrings("hello", state.received_bytes.items);
    try testing.expect(!state.send_flag);
}

test "a network error runs the request error steps for error" {
    var state = XMLHttpRequestState.init(testing.allocator);
    defer state.deinit();
    var recorder = Recorder{ .state = &state };
    defer recorder.deinit();
    try sent(&state, &recorder);

    const result: FetchResult = .{
        .response = try fetch.internal.networkError(testing.allocator),
        .timing_info = fetch.internal.FetchTimingInfo.init(testing.allocator),
    };
    var processor = xhr_root.response.ResponseProcessor.init(&state);
    _ = try send_algo.sendAsyncFinish(&state, null, result, &processor);

    try recorder.expectNames(&.{ "loadstart", "readystatechange", "error", "loadend" });
    try testing.expectEqual(ReadyState.DONE, state.ready_state);
}

test "a fetch that could not run at all is an error, and an aborted one an abort" {
    for ([_]struct { err: FetchError, event: []const u8 }{
        .{ .err = FetchError.NetworkError, .event = "error" },
        .{ .err = FetchError.AbortError, .event = "abort" },
    }) |case| {
        var state = XMLHttpRequestState.init(testing.allocator);
        defer state.deinit();
        var recorder = Recorder{ .state = &state };
        defer recorder.deinit();
        try sent(&state, &recorder);

        var processor = xhr_root.response.ResponseProcessor.init(&state);
        _ = try send_algo.sendAsyncFinish(&state, null, case.err, &processor);

        try recorder.expectNames(&.{ "loadstart", "readystatechange", case.event, "loadend" });
    }
}

test "a response that arrived is not a timeout, however late its task runs" {
    var state = XMLHttpRequestState.init(testing.allocator);
    defer state.deinit();
    var recorder = Recorder{ .state = &state };
    defer recorder.deinit();
    try sent(&state, &recorder);
    state.timeout = 100;

    // The impl ends a fetch still running at the deadline. One that ended
    // first had its response in time, even if a long task kept its task from
    // running until later (xhr/xhr-timeout-longtask.any.js).
    var processor = xhr_root.response.ResponseProcessor.init(&state);
    _ = try send_algo.sendAsyncFinish(&state, null, try responseWith(200, "in time"), &processor);

    try testing.expect(!state.timed_out_flag);
    const names = recorder.names.items;
    try testing.expectEqualStrings("loadend", names[names.len - 1]);
    try testing.expectEqualStrings("load", names[names.len - 2]);
}

/// A response whose body is still arriving, through a pipe the test feeds.
fn streamedResponse(source: **fetch.internal.PipeSource) !FetchResult {
    const response = try fetch.internal.InternalResponse.init(testing.allocator);
    errdefer response.deinit();
    response.status = 200;
    try response.addUrl("http://example.com/data");
    try response.header_list.append("Content-Length", "10");
    source.* = try fetch.internal.PipeSource.create(testing.allocator);
    const pipe = try source.*.branch();
    response.body = try fetch.internal.Body.fromPipe(testing.allocator, pipe);
    return .{ .response = response, .timing_info = fetch.internal.FetchTimingInfo.init(testing.allocator) };
}

test "a body still arriving is handed back to read, and its pieces and end run their steps" {
    var state = XMLHttpRequestState.init(testing.allocator);
    defer state.deinit();
    var recorder = Recorder{ .state = &state };
    defer recorder.deinit();
    try sent(&state, &recorder);

    var source: *fetch.internal.PipeSource = undefined;
    var processor = xhr_root.response.ResponseProcessor.init(&state);
    const pipe = (try send_algo.sendAsyncFinish(&state, null, try streamedResponse(&source), &processor)) orelse return error.TestUnexpectedResult;
    // Headers received, and nothing of the body yet.
    try testing.expectEqual(ReadyState.HEADERS_RECEIVED, state.ready_state);

    source.push("hello");
    const first = try pipe.take();
    defer testing.allocator.free(first);
    try send_algo.sendAsyncBodyChunk(&state, &processor, first);
    try testing.expectEqual(ReadyState.LOADING, state.ready_state);
    try testing.expectEqualStrings("hello", state.received_bytes.items);

    source.push("world");
    source.finish();
    const second = try pipe.take();
    defer testing.allocator.free(second);
    try send_algo.sendAsyncBodyChunk(&state, &processor, second);
    send_algo.sendAsyncEndOfBody(&state, &processor);

    try testing.expectEqualStrings("helloworld", state.received_bytes.items);
    try testing.expectEqual(ReadyState.DONE, state.ready_state);
    const names = recorder.names.items;
    try testing.expectEqualStrings("load", names[names.len - 2]);
    try testing.expectEqualStrings("loadend", names[names.len - 1]);
}

test "a body that fails while arriving runs the request error steps" {
    var state = XMLHttpRequestState.init(testing.allocator);
    defer state.deinit();
    var recorder = Recorder{ .state = &state };
    defer recorder.deinit();
    try sent(&state, &recorder);

    var source: *fetch.internal.PipeSource = undefined;
    var processor = xhr_root.response.ResponseProcessor.init(&state);
    _ = (try send_algo.sendAsyncFinish(&state, null, try streamedResponse(&source), &processor)) orelse return error.TestUnexpectedResult;
    source.fail(.{ .kind = .network });
    send_algo.sendAsyncBodyFailed(&state, &processor);

    try testing.expectEqual(ReadyState.DONE, state.ready_state);
    const names = recorder.names.items;
    try testing.expectEqualStrings("error", names[names.len - 2]);
    try testing.expectEqualStrings("loadend", names[names.len - 1]);
}
