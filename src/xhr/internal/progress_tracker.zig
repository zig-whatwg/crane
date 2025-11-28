//! Progress Event Throttling
//!
//! Spec requirement: Progress events should be throttled to approximately 50ms
//! to avoid overwhelming the event loop during fast downloads.
//!
//! Browser implementations: All use 50ms throttling timers

const std = @import("std");

/// Progress event tracker with 50ms throttling
pub const ProgressTracker = struct {
    /// Last time progress event was fired (milliseconds)
    last_progress_time: i64,

    /// Bytes accumulated since last event
    bytes_since_last_event: usize,

    /// Total bytes received
    total_bytes: usize,

    /// Content-Length from response (if known)
    content_length: ?usize,

    /// Throttle interval (50ms per spec/browsers)
    const THROTTLE_MS: i64 = 50;

    pub fn init() ProgressTracker {
        return .{
            .last_progress_time = 0,
            .bytes_since_last_event = 0,
            .total_bytes = 0,
            .content_length = null,
        };
    }

    /// Called when a chunk is received
    /// Returns true if enough time has elapsed to fire progress event
    pub fn onChunk(self: *ProgressTracker, chunk_size: usize) bool {
        self.total_bytes += chunk_size;
        self.bytes_since_last_event += chunk_size;

        const now = std.time.milliTimestamp();
        const elapsed = now - self.last_progress_time;

        if (elapsed >= THROTTLE_MS) {
            self.last_progress_time = now;
            self.bytes_since_last_event = 0;
            return true; // Fire progress event
        }

        return false; // Throttled
    }

    /// Force fire progress event (for final event)
    pub fn forceFire(self: *ProgressTracker) void {
        self.last_progress_time = std.time.milliTimestamp();
        self.bytes_since_last_event = 0;
    }

    /// Set content length from response headers
    pub fn setContentLength(self: *ProgressTracker, length: usize) void {
        self.content_length = length;
    }

    /// Get current progress info
    pub fn getProgress(self: *const ProgressTracker) ProgressInfo {
        return .{
            .loaded = self.total_bytes,
            .total = self.content_length,
            .length_computable = self.content_length != null,
        };
    }
};

/// Progress information for events
pub const ProgressInfo = struct {
    loaded: usize,
    total: ?usize,
    length_computable: bool,
};

// =============================================================================
// Tests
// =============================================================================

test "ProgressTracker - initialization" {
    const tracker = ProgressTracker.init();

    try std.testing.expectEqual(@as(usize, 0), tracker.total_bytes);
    try std.testing.expectEqual(@as(?usize, null), tracker.content_length);
}

test "ProgressTracker - first chunk fires immediately" {
    var tracker = ProgressTracker.init();

    // First chunk should fire (last_progress_time = 0)
    const should_fire = tracker.onChunk(1024);
    try std.testing.expect(should_fire);
    try std.testing.expectEqual(@as(usize, 1024), tracker.total_bytes);
}

test "ProgressTracker - throttling works" {
    var tracker = ProgressTracker.init();

    // First chunk
    _ = tracker.onChunk(1024);

    // Second chunk immediately after (should be throttled)
    const should_fire = tracker.onChunk(1024);
    try std.testing.expect(!should_fire);
    try std.testing.expectEqual(@as(usize, 2048), tracker.total_bytes);
}

test "ProgressTracker - content length" {
    var tracker = ProgressTracker.init();
    tracker.setContentLength(10240);

    const info = tracker.getProgress();
    try std.testing.expect(info.length_computable);
    try std.testing.expectEqual(@as(?usize, 10240), info.total);
}

test "ProgressTracker - multiple chunks" {
    var tracker = ProgressTracker.init();

    _ = tracker.onChunk(512);
    _ = tracker.onChunk(512);
    _ = tracker.onChunk(512);

    try std.testing.expectEqual(@as(usize, 1536), tracker.total_bytes);
}
