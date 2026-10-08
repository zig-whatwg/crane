//! A queued document error may dispatch script that destroys its native
//! XHR state. No subsequent request-error step may read that retired state.
const std = @import("std");
const xhr = @import("xhr");
const Processor = xhr.response.ResponseProcessor;

test "request error stops when its realm ends during each dispatched event" {
    const Recorder = struct {
        stop_at: usize,
        fired: usize = 0,
        alive: bool = true,

        fn fire(context: *anyopaque, _: xhr.EventTargetKind, _: xhr.XHREventType, _: ?xhr.ProgressEventData) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.fired += 1;
            if (self.fired == self.stop_at) self.alive = false;
        }

        fn mayContinue(context: *anyopaque) bool {
            const self: *@This() = @ptrCast(@alignCast(context));
            return self.alive;
        }
    };
    // readystatechange, upload.abort, upload.loadend, xhr.abort,
    // xhr.loadend: retire the state at each earlier dispatch boundary.
    for (1..5) |stop_at| {
        var state = xhr.XMLHttpRequestState.init(std.testing.allocator);
        defer state.deinit();
        state.ready_state = .OPENED;
        state.send_flag = true;
        state.upload_complete_flag = false;
        state.upload_listener_flag = true;
        var recorder: Recorder = .{ .stop_at = stop_at };
        state.event_sink = .{ .ctx = &recorder, .fire = Recorder.fire };
        var processor = Processor.init(&state);
        if (comptime @hasField(Processor, "continuation")) {
            processor.continuation = .{ .context = &recorder, .is_live = Recorder.mayContinue };
        }
        processor.handleAbort();
        try std.testing.expectEqual(stop_at, recorder.fired);
    }
}
