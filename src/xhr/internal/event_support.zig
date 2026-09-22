//! XHR Event Support
//!
//! WHATWG XHR Standard: https://xhr.spec.whatwg.org/
//!
//! `src/xhr/` implements the spec algorithms and must not depend on the
//! runtime, on WebIDL or on V8 - it is linked into a module that has none of
//! them. But the algorithms in §3.5 fire events at every step, and an event
//! that cannot reach JavaScript makes the whole tree unobservable.
//!
//! So event firing is an INDIRECTION, not a stub: `EventSink` is a two-field
//! vtable the WebIDL impl installs on the state (see
//! `src/webidl/impls/XMLHttpRequest.zig`), and the algorithms call through it.
//! With no sink installed - which is what unit tests get - firing logs at debug
//! and does nothing else, so the algorithms stay testable without an isolate.
//!
//! This replaces three `std.log.debug` stubs that took no instance and
//! therefore could never have dispatched anything.

const std = @import("std");

const log = std.log.scoped(.xhr_events);

/// Event type enum for XHR events
///
/// Spec: https://xhr.spec.whatwg.org/#events
pub const XHREventType = enum {
    loadstart,
    progress,
    abort,
    @"error",
    load,
    timeout,
    loadend,
    readystatechange,

    /// The event's `type`, as JavaScript sees it.
    pub fn name(self: XHREventType) []const u8 {
        return switch (self) {
            .loadstart => "loadstart",
            .progress => "progress",
            .abort => "abort",
            .@"error" => "error",
            .load => "load",
            .timeout => "timeout",
            .loadend => "loadend",
            .readystatechange => "readystatechange",
        };
    }
};

/// Progress event data
///
/// Spec: https://xhr.spec.whatwg.org/#interface-progressevent
pub const ProgressEventData = struct {
    lengthComputable: bool,
    loaded: u64,
    total: u64,
};

/// Which object an event is fired at.
///
/// Spec: the upload events fire at the XHR's "upload object", everything else
/// at the XHR itself. https://xhr.spec.whatwg.org/#upload-object
pub const EventTargetKind = enum {
    xhr,
    upload,
};

/// The seam between the spec algorithms and whatever can actually dispatch an
/// event.
///
/// `ctx` is opaque on purpose - the impl passes its `*runtime.Instance` through
/// it, which is a type this module must not name.
pub const EventSink = struct {
    ctx: *anyopaque,

    /// Fire an event named `event_type` at `target`. `progress` is non-null for
    /// the ProgressEvent types and null for `readystatechange`, which is a
    /// plain Event.
    fire: *const fn (
        ctx: *anyopaque,
        target: EventTargetKind,
        event_type: XHREventType,
        progress: ?ProgressEventData,
    ) void,
};

/// Fire a simple event (no progress data) at the XHR object.
///
/// Spec: https://dom.spec.whatwg.org/#concept-event-fire
pub fn fireEvent(sink: ?EventSink, event_type: XHREventType) void {
    if (sink) |s| {
        s.fire(s.ctx, .xhr, event_type, null);
        return;
    }
    log.debug("no sink; dropped {s}", .{event_type.name()});
}

/// Fire a progress event at the XHR object.
///
/// Spec: https://xhr.spec.whatwg.org/#concept-event-fire-progress
pub fn fireProgressEvent(
    sink: ?EventSink,
    event_type: XHREventType,
    progress: ProgressEventData,
) void {
    if (sink) |s| {
        s.fire(s.ctx, .xhr, event_type, progress);
        return;
    }
    log.debug("no sink; dropped {s} loaded={d} total={d}", .{
        event_type.name(),
        progress.loaded,
        progress.total,
    });
}

/// Fire a progress event at the XHR's upload object.
///
/// Spec: https://xhr.spec.whatwg.org/#concept-event-fire-progress
pub fn fireUploadProgressEvent(
    sink: ?EventSink,
    event_type: XHREventType,
    progress: ProgressEventData,
) void {
    if (sink) |s| {
        s.fire(s.ctx, .upload, event_type, progress);
        return;
    }
    log.debug("no sink; dropped upload {s} loaded={d} total={d}", .{
        event_type.name(),
        progress.loaded,
        progress.total,
    });
}

// =============================================================================
// Tests
// =============================================================================

const RecordingSink = struct {
    const Record = struct {
        target: EventTargetKind,
        event_type: XHREventType,
        progress: ?ProgressEventData,
    };

    records: [16]Record = undefined,
    len: usize = 0,

    fn fire(
        ctx: *anyopaque,
        target: EventTargetKind,
        event_type: XHREventType,
        progress: ?ProgressEventData,
    ) void {
        const self: *RecordingSink = @ptrCast(@alignCast(ctx));
        if (self.len >= self.records.len) return;
        self.records[self.len] = .{
            .target = target,
            .event_type = event_type,
            .progress = progress,
        };
        self.len += 1;
    }

    fn sink(self: *RecordingSink) EventSink {
        return .{ .ctx = @ptrCast(self), .fire = &RecordingSink.fire };
    }
};

test "EventSink - a null sink fires nothing and does not crash" {
    fireEvent(null, .readystatechange);
    fireProgressEvent(null, .load, .{ .lengthComputable = true, .loaded = 1, .total = 2 });
    fireUploadProgressEvent(null, .load, .{ .lengthComputable = true, .loaded = 1, .total = 2 });
}

test "EventSink - routes to the XHR and to the upload object" {
    var recorder = RecordingSink{};
    const sink = recorder.sink();

    fireEvent(sink, .readystatechange);
    fireProgressEvent(sink, .load, .{ .lengthComputable = true, .loaded = 3, .total = 4 });
    fireUploadProgressEvent(sink, .progress, .{ .lengthComputable = false, .loaded = 5, .total = 0 });

    try std.testing.expectEqual(@as(usize, 3), recorder.len);

    try std.testing.expectEqual(EventTargetKind.xhr, recorder.records[0].target);
    try std.testing.expectEqual(XHREventType.readystatechange, recorder.records[0].event_type);
    try std.testing.expect(recorder.records[0].progress == null);

    try std.testing.expectEqual(EventTargetKind.xhr, recorder.records[1].target);
    try std.testing.expectEqual(XHREventType.load, recorder.records[1].event_type);
    try std.testing.expectEqual(@as(u64, 3), recorder.records[1].progress.?.loaded);

    try std.testing.expectEqual(EventTargetKind.upload, recorder.records[2].target);
    try std.testing.expectEqual(XHREventType.progress, recorder.records[2].event_type);
    try std.testing.expectEqual(@as(u64, 5), recorder.records[2].progress.?.loaded);
}

test "XHREventType - name matches the spec event names" {
    try std.testing.expectEqualStrings("error", XHREventType.@"error".name());
    try std.testing.expectEqualStrings("readystatechange", XHREventType.readystatechange.name());
    try std.testing.expectEqualStrings("loadend", XHREventType.loadend.name());
}
