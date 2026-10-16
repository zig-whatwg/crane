//! Browser-observable XHR upload failure and terminal progress regressions.
const std = @import("std");
const xhr = @import("xhr");
const fetch = @import("fetch");
const allocator = std.testing.allocator;

const Record = struct {
    target: xhr.EventTargetKind,
    event: xhr.XHREventType,
    loaded: ?u64,
};
const Recorder = struct {
    events: std.ArrayListUnmanaged(Record) = .empty,
    fn fire(raw: *anyopaque, target: xhr.EventTargetKind, event: xhr.XHREventType, data: ?xhr.ProgressEventData) void {
        const self: *Recorder = @ptrCast(@alignCast(raw));
        self.events.append(allocator, .{ .target = target, .event = event, .loaded = if (data) |d| d.loaded else null }) catch unreachable;
    }
    fn deinit(self: *Recorder) void {
        self.events.deinit(allocator);
    }
};

test "XHR in-band network error reports failed upload without a success notification" {
    var state = xhr.XMLHttpRequestState.init(allocator);
    defer state.deinit();
    var record: Recorder = .{};
    defer record.deinit();
    try xhr.open.open(&state, "POST", "http://example.test/", true, null, null, null, false);
    state.event_sink = .{ .ctx = &record, .fire = &Recorder.fire };
    const body = try xhr.send.sendPrologue(&state, "payload");
    state.upload_listener_flag = true;
    try std.testing.expect(xhr.send.sendStart(&state, body));
    const result: fetch.algorithms.FetchResult = .{
        .response = try fetch.internal.networkError(allocator),
        .timing_info = fetch.internal.FetchTimingInfo.init(allocator),
    };
    var processor = xhr.response.ResponseProcessor.init(&state);
    _ = try xhr.send.sendAsyncFinish(&state, body, result, &processor);
    const events = record.events.items;
    try std.testing.expectEqual(@as(usize, 7), events.len);
    const expected = [_]xhr.XHREventType{ .loadstart, .loadstart, .readystatechange, .@"error", .loadend, .@"error", .loadend };
    for (expected, events) |event, actual| try std.testing.expectEqual(event, actual.event);
    try std.testing.expectEqual(xhr.EventTargetKind.upload, events[3].target);
    try std.testing.expectEqual(@as(?u64, 0), events[3].loaded);
}

test "XHR terminal progress flushes new bytes but never repeats an emitted count" {
    for ([_]bool{ false, true }) |pending_chunk| {
        var state = xhr.XMLHttpRequestState.init(allocator);
        defer state.deinit();
        var record: Recorder = .{};
        defer record.deinit();
        state.event_sink = .{ .ctx = &record, .fire = &Recorder.fire };
        state.response = try fetch.internal.InternalResponse.init(allocator);
        state.response.?.status = 200;
        state.ready_state = .HEADERS_RECEIVED;
        var processor = xhr.response.ResponseProcessor.init(&state);
        try processor.processResponseBodyChunk("hello");
        if (pending_chunk) {
            // Pin the throttle window without relying on test execution speed.
            processor.progress_tracker.last_progress_time = std.math.maxInt(i64);
            try processor.processResponseBodyChunk("world");
        }
        processor.processResponseEndOfBody();
        var count: usize = 0;
        var last: u64 = 0;
        for (record.events.items) |event| {
            if (event.event != .progress) continue;
            try std.testing.expect(event.loaded.? > last);
            last = event.loaded.?;
            count += 1;
        }
        try std.testing.expectEqual(@as(usize, if (pending_chunk) 2 else 1), count);
        try std.testing.expectEqual(@as(u64, if (pending_chunk) 10 else 5), last);
    }
}

test "XHR request sets the use URL credentials flag only for nonempty credentials" {
    for ([_][]const u8{ "https://user:pass@example.test/", "https://example.test/" }, 0..) |url, i| {
        var state = xhr.XMLHttpRequestState.init(allocator);
        defer state.deinit();
        try xhr.open.open(&state, "GET", url, true, null, null, null, false);
        const request = try xhr.send.createRequest(allocator, &state, null);
        defer request.deinit();
        try std.testing.expectEqual(i == 0, request.use_url_credentials);
    }
}
