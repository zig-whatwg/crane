//! Firefox/WebKit dispatch terminal download events before sync send throws.
const std = @import("std");
const xhr = @import("xhr");

test "sync network errors dispatch DONE error and loadend without upload events" {
    const Recorder = struct {
        state: *xhr.XMLHttpRequestState,
        names: [8]xhr.XHREventType = undefined,
        count: usize = 0,
        upload_count: usize = 0,
        all_done: bool = true,
        all_zero: bool = true,

        fn fire(context: *anyopaque, target: xhr.EventTargetKind, kind: xhr.XHREventType, progress: ?xhr.ProgressEventData) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            if (target == .upload) {
                self.upload_count += 1;
                return;
            }
            self.all_done = self.all_done and self.state.ready_state == .DONE and !self.state.send_flag;
            if (progress) |p| self.all_zero = self.all_zero and !p.lengthComputable and p.loaded == 0 and p.total == 0;
            self.names[self.count] = kind;
            self.count += 1;
        }
    };
    var state = xhr.XMLHttpRequestState.init(std.testing.allocator);
    defer state.deinit();
    state.ready_state = .OPENED;
    state.synchronous_flag = true;
    state.send_flag = true;
    state.upload_complete_flag = false;
    state.upload_listener_flag = true;
    var recorder: Recorder = .{ .state = &state };
    state.event_sink = .{ .ctx = &recorder, .fire = Recorder.fire };
    var processor = xhr.response.ResponseProcessor.init(&state);
    processor.handleNetworkError();
    try std.testing.expectEqualSlices(xhr.XHREventType, &.{ .readystatechange, .@"error", .loadend }, recorder.names[0..recorder.count]);
    try std.testing.expectEqual(@as(usize, 0), recorder.upload_count);
    try std.testing.expect(recorder.all_done);
    try std.testing.expect(recorder.all_zero);
    try std.testing.expect(state.isNetworkError());
}
