//! XHR Event Support
//!
//! Helper module for firing XHR events (loadstart, progress, load, etc.)
//! Integrates with the runtime event dispatch system.

const std = @import("std");

/// Event type enum for XHR events
pub const XHREventType = enum {
    loadstart,
    progress,
    abort,
    @"error",
    load,
    timeout,
    loadend,
    readystatechange,
};

/// Progress event data
pub const ProgressEventData = struct {
    lengthComputable: bool,
    loaded: u64,
    total: u64,
};

/// Fire a progress event
///
/// NOTE: This is a stub that will be properly implemented when integrated
/// with the runtime event dispatch system. For now, it just logs the event.
pub fn fireProgressEvent(
    event_type: XHREventType,
    progress: ProgressEventData,
) void {
    // TODO: Integrate with runtime.Instance.dispatchEvent
    // For now, just log for debugging
    std.log.debug("XHR Event: {s} - loaded={} total={} computable={}", .{
        @tagName(event_type),
        progress.loaded,
        progress.total,
        progress.lengthComputable,
    });
}

/// Fire a simple event (no progress data)
pub fn fireEvent(event_type: XHREventType) void {
    // TODO: Integrate with runtime.Instance.dispatchEvent
    std.log.debug("XHR Event: {s}", .{@tagName(event_type)});
}

/// Fire an upload progress event
///
/// NOTE: This is a stub that will be properly implemented when integrated
/// with the runtime event dispatch system. For now, it just logs the event.
pub fn fireUploadProgressEvent(
    event_type: XHREventType,
    progress: ProgressEventData,
) void {
    // TODO: Integrate with XMLHttpRequestUpload.dispatchEvent
    // For now, just log for debugging
    std.log.debug("XHR Upload Event: {s} - loaded={} total={} computable={}", .{
        @tagName(event_type),
        progress.loaded,
        progress.total,
        progress.lengthComputable,
    });
}

// =============================================================================
// Future Integration Notes
// =============================================================================
//
// When integrating with runtime event system:
//
// 1. Pass *runtime.Instance to fire functions
// 2. Create ProgressEvent instance:
//    const event = try ProgressEvent.init(allocator, event_type_str, .{
//        .lengthComputable = progress.lengthComputable,
//        .loaded = progress.loaded,
//        .total = progress.total,
//    });
// 3. Dispatch event:
//    try instance.dispatchEvent(event);
// 4. Clean up event after dispatch
//
// Event handlers are stored in XMLHttpRequestEventTarget.State:
//    - onloadstart, onprogress, onabort, onerror, onload, ontimeout, onloadend
//
// Inherited from EventTarget:
//    - addEventListener, removeEventListener, dispatchEvent
