//! Upload Progress Tracking
//!
//! Spec: https://xhr.spec.whatwg.org/#upload-progress-events

const std = @import("std");
const xhr_root = @import("../root.zig");
const ProgressTracker = @import("../internal/progress_tracker.zig").ProgressTracker;

/// Upload progress tracker
pub const UploadTracker = struct {
    progress: ProgressTracker,
    total_size: usize,

    pub fn init(body_size: usize) UploadTracker {
        var tracker = ProgressTracker.init();
        tracker.setContentLength(body_size);
        return .{
            .progress = tracker,
            .total_size = body_size,
        };
    }

    /// Process upload chunk
    /// Returns true if progress event should be fired
    pub fn onChunk(self: *UploadTracker, chunk_size: usize) bool {
        return self.progress.onChunk(chunk_size);
    }

    /// Check if upload is complete
    pub fn isComplete(self: *const UploadTracker) bool {
        return self.progress.total_bytes >= self.total_size;
    }

    /// Get progress info
    pub fn getProgress(self: *const UploadTracker) struct { loaded: usize, total: usize } {
        return .{
            .loaded = self.progress.total_bytes,
            .total = self.total_size,
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

test "UploadTracker - initialization" {
    const tracker = UploadTracker.init(10240);

    try std.testing.expectEqual(@as(usize, 10240), tracker.total_size);
    try std.testing.expectEqual(@as(usize, 0), tracker.progress.total_bytes);
}

test "UploadTracker - tracks progress" {
    var tracker = UploadTracker.init(5120);

    _ = tracker.onChunk(1024);
    _ = tracker.onChunk(1024);

    const progress = tracker.getProgress();
    try std.testing.expectEqual(@as(usize, 2048), progress.loaded);
    try std.testing.expectEqual(@as(usize, 5120), progress.total);
}

test "UploadTracker - completion detection" {
    var tracker = UploadTracker.init(2048);

    try std.testing.expect(!tracker.isComplete());

    _ = tracker.onChunk(1024);
    try std.testing.expect(!tracker.isComplete());

    _ = tracker.onChunk(1024);
    try std.testing.expect(tracker.isComplete());
}
