//! The observable sequence of an XHR request: readyState transitions and the
//! order events fire in.
//!
//! These used to call `send()` against `http://example.com/data` and assert on
//! the string "Mock response data from simplified fetch" - they were testing a
//! mock that no longer exists, and every one of them called `open()` with four
//! arguments where it takes seven, which is why `tests/xhr/` had never
//! compiled.
//!
//! `send()` now performs a REAL, blocking fetch, so it does not belong in a
//! unit test. What does belong here is the part WPT is bad at localising: the
//! exact event order the spec prescribes. The sequence is driven through
//! `ResponseProcessor` with a recording sink, which is the same code path the
//! network takes once `fetch_integration` hands it a response.

const std = @import("std");
const xhr_root = @import("xhr");
const XMLHttpRequestState = xhr_root.XMLHttpRequestState;
const ReadyState = xhr_root.ReadyState;
const ResponseProcessor = xhr_root.response.ResponseProcessor;
const XHREventType = xhr_root.XHREventType;
const EventTargetKind = xhr_root.EventTargetKind;
const ProgressEventData = xhr_root.ProgressEventData;
const open = xhr_root.open.open;
const send = xhr_root.send.send;

/// Records every event the algorithms fire, in order.
const Recorder = struct {
    const Entry = struct {
        target: EventTargetKind,
        event_type: XHREventType,
        loaded: u64,
        total: u64,
        /// readyState AT THE MOMENT the event fired - the thing a
        /// `readystatechange` listener actually observes.
        ready_state: ReadyState,
    };

    entries: std.ArrayListUnmanaged(Entry) = .empty,
    allocator: std.mem.Allocator,
    state: *XMLHttpRequestState,

    fn fire(
        ctx: *anyopaque,
        target: EventTargetKind,
        event_type: XHREventType,
        progress: ?ProgressEventData,
    ) void {
        const self: *Recorder = @ptrCast(@alignCast(ctx));
        self.entries.append(self.allocator, .{
            .target = target,
            .event_type = event_type,
            .loaded = if (progress) |p| p.loaded else 0,
            .total = if (progress) |p| p.total else 0,
            .ready_state = self.state.ready_state,
        }) catch {};
    }

    fn install(self: *Recorder) void {
        self.state.event_sink = .{ .ctx = @ptrCast(self), .fire = &Recorder.fire };
    }

    fn deinit(self: *Recorder) void {
        self.entries.deinit(self.allocator);
    }

    /// The fired event names, in order, for one target.
    fn names(self: *const Recorder, allocator: std.mem.Allocator, target: EventTargetKind) ![]const []const u8 {
        var out: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer out.deinit(allocator);
        for (self.entries.items) |e| {
            if (e.target == target) try out.append(allocator, e.event_type.name());
        }
        return out.toOwnedSlice(allocator);
    }
};

fn expectNames(expected: []const []const u8, actual: []const []const u8) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |e, a| try std.testing.expectEqualStrings(e, a);
}

test "readyState - the spec's five values" {
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(ReadyState.UNSENT));
    try std.testing.expectEqual(@as(u16, 1), @intFromEnum(ReadyState.OPENED));
    try std.testing.expectEqual(@as(u16, 2), @intFromEnum(ReadyState.HEADERS_RECEIVED));
    try std.testing.expectEqual(@as(u16, 3), @intFromEnum(ReadyState.LOADING));
    try std.testing.expectEqual(@as(u16, 4), @intFromEnum(ReadyState.DONE));
}

test "send() - step 1: not opened is an InvalidStateError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try std.testing.expectError(error.InvalidStateError, send(&state, null));
}

test "send() - step 2: the send() flag being set is an InvalidStateError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com/data", true, null, null, null, false);
    state.send_flag = true;

    try std.testing.expectError(error.InvalidStateError, send(&state, null));
}

test "open() - fires nothing itself, and lands in OPENED" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var recorder = Recorder{ .allocator = allocator, .state = &state };
    defer recorder.deinit();
    recorder.install();

    try open(&state, "GET", "http://example.com/data", true, null, null, null, false);

    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);

    // `open()` does not fire readystatechange - step 12 is the impl's, because
    // only the impl can reach a JS object. Firing it from `changeState` would
    // fire it on every internal transition instead.
    try std.testing.expectEqual(@as(usize, 0), recorder.entries.items.len);
}

test "request error steps - the async order is readystatechange, error, loadend" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var recorder = Recorder{ .allocator = allocator, .state = &state };
    defer recorder.deinit();
    recorder.install();

    try open(&state, "GET", "http://example.com/data", true, null, null, null, false);
    state.send_flag = true;
    state.upload_complete_flag = true;

    var processor = ResponseProcessor.init(&state);
    processor.handleNetworkError();

    const got = try recorder.names(allocator, .xhr);
    defer allocator.free(got);
    try expectNames(&.{ "readystatechange", "error", "loadend" }, got);

    // Steps 1-3
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
    try std.testing.expect(!state.send_flag);
    try std.testing.expect(state.isNetworkError());

    // Step 7-8 fire with 0 and 0, NOT with the bytes transferred so far.
    for (recorder.entries.items) |e| {
        try std.testing.expectEqual(@as(u64, 0), e.loaded);
        try std.testing.expectEqual(@as(u64, 0), e.total);
    }

    // Every event a listener sees reports readyState DONE, because step 1 runs
    // before step 5.
    for (recorder.entries.items) |e| {
        try std.testing.expectEqual(ReadyState.DONE, e.ready_state);
    }
}

test "request error steps - a sync request fires nothing" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var recorder = Recorder{ .allocator = allocator, .state = &state };
    defer recorder.deinit();
    recorder.install();

    try open(&state, "GET", "http://example.com/data", false, null, null, null, false);
    try std.testing.expect(state.synchronous_flag);
    state.send_flag = true;

    var processor = ResponseProcessor.init(&state);
    processor.handleNetworkError();

    // Step 4: a sync request THROWS and fires nothing; steps 5-8 are skipped.
    try std.testing.expectEqual(@as(usize, 0), recorder.entries.items.len);

    // Steps 1-3 still ran.
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
    try std.testing.expect(!state.send_flag);
}

test "request error steps - timeout also fires the upload events when a listener is registered" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var recorder = Recorder{ .allocator = allocator, .state = &state };
    defer recorder.deinit();
    recorder.install();

    try open(&state, "POST", "http://example.com/data", true, null, null, null, false);
    state.send_flag = true;
    state.upload_listener_flag = true;
    state.upload_complete_flag = false;

    var processor = ResponseProcessor.init(&state);
    processor.handleTimeout();

    try std.testing.expect(state.timed_out_flag);

    // Step 6.2: upload events fire BEFORE the XHR's own, and with the same
    // event name.
    const upload_names = try recorder.names(allocator, .upload);
    defer allocator.free(upload_names);
    try expectNames(&.{ "timeout", "loadend" }, upload_names);

    const xhr_names = try recorder.names(allocator, .xhr);
    defer allocator.free(xhr_names);
    try expectNames(&.{ "readystatechange", "timeout", "loadend" }, xhr_names);

    // Step 6.1: the upload complete flag is now set.
    try std.testing.expect(state.upload_complete_flag);
}

test "request error steps - no upload listener means no upload events" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var recorder = Recorder{ .allocator = allocator, .state = &state };
    defer recorder.deinit();
    recorder.install();

    try open(&state, "POST", "http://example.com/data", true, null, null, null, false);
    state.send_flag = true;
    state.upload_listener_flag = false;
    state.upload_complete_flag = false;

    var processor = ResponseProcessor.init(&state);
    processor.handleAbort();

    const upload_names = try recorder.names(allocator, .upload);
    defer allocator.free(upload_names);
    try expectNames(&.{}, upload_names);

    const xhr_names = try recorder.names(allocator, .xhr);
    defer allocator.free(xhr_names);
    try expectNames(&.{ "readystatechange", "abort", "loadend" }, xhr_names);
}

test "handle response end-of-body - a network error reports nothing" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var recorder = Recorder{ .allocator = allocator, .state = &state };
    defer recorder.deinit();
    recorder.install();

    try open(&state, "GET", "http://example.com/data", true, null, null, null, false);
    state.send_flag = true;

    // The response is initially a network error, so step 2 returns.
    var processor = ResponseProcessor.init(&state);
    processor.processResponseEndOfBody();

    try std.testing.expectEqual(@as(usize, 0), recorder.entries.items.len);
}

test "processResponse - a network error stops before headers received" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var recorder = Recorder{ .allocator = allocator, .state = &state };
    defer recorder.deinit();
    recorder.install();

    try open(&state, "GET", "http://example.com/data", true, null, null, null, false);
    state.send_flag = true;

    var processor = ResponseProcessor.init(&state);
    try std.testing.expect(!processor.processResponse());

    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);
    try std.testing.expectEqual(@as(usize, 0), recorder.entries.items.len);
}
