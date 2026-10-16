//! Chromium/WebKit count decoded bytes and clear an exceeded encoded total.
const std = @import("std");
const xhr = @import("xhr");
const fetch = @import("fetch");
const Capture = struct {
    count: usize = 0,
    valid: bool = true,
    fn fire(raw: *anyopaque, _: xhr.EventTargetKind, event: xhr.XHREventType, data: ?xhr.ProgressEventData) void {
        const self: *Capture = @ptrCast(@alignCast(raw));
        if (event == .progress or event == .load or event == .loadend) {
            const p = data.?;
            self.valid = self.valid and !p.lengthComputable and p.total == 0 and p.loaded == 10;
            self.count += 1;
        }
    }
};
test "XHR decoded bytes exceeding Content-Length have an unknown total" {
    var state = xhr.XMLHttpRequestState.init(std.testing.allocator);
    defer state.deinit();
    state.response = try fetch.internal.InternalResponse.init(std.testing.allocator);
    try state.response.?.header_list.append("Content-Length", "3");
    state.ready_state = .HEADERS_RECEIVED;
    var capture: Capture = .{};
    state.event_sink = .{ .ctx = &capture, .fire = &Capture.fire };
    var processor = xhr.response.ResponseProcessor.init(&state);
    try std.testing.expect(processor.processResponse());
    try processor.processResponseBodyChunk("0123456789");
    processor.processResponseEndOfBody();
    try std.testing.expect(capture.valid);
    try std.testing.expectEqual(@as(usize, 3), capture.count);
}
