//! Upload Progress Tracking
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/#interface-xmlhttprequestupload
//!
//! The XMLHttpRequestUpload interface provides a way to track upload progress.
//! Progress events are fired on the upload object when request body is being sent.
//!
//! ## Event Ordering (per spec)
//!
//! 1. Upload events fire BEFORE download events
//! 2. Upload events: loadstart -> progress (repeated) -> load -> loadend
//! 3. Upload aborted: loadstart -> progress -> abort -> loadend
//! 4. Upload error: loadstart -> progress -> error -> loadend
//!
//! ## CORS Integration
//!
//! When upload listeners are registered, a CORS preflight is required.
//! The presence of listeners triggers the "upload listener flag" which:
//! - Forces preflight even for simple requests
//! - Affects CORS mode in the Fetch request

const std = @import("std");
const xhr_root = @import("../root.zig");
const ProgressTracker = @import("../internal/progress_tracker.zig").ProgressTracker;
const event_support = @import("../internal/event_support.zig");

/// Upload progress tracker with event firing
pub const UploadTracker = struct {
    progress: ProgressTracker,
    total_size: usize,
    started: bool,
    completed: bool,
    error_occurred: bool,
    aborted: bool,

    pub fn init(body_size: usize) UploadTracker {
        var tracker = ProgressTracker.init();
        tracker.setContentLength(body_size);
        return .{
            .progress = tracker,
            .total_size = body_size,
            .started = false,
            .completed = false,
            .error_occurred = false,
            .aborted = false,
        };
    }

    /// Fire loadstart event (called once at upload start)
    pub fn fireLoadStart(self: *UploadTracker) void {
        if (self.started) return; // Already started
        self.started = true;

        event_support.fireUploadProgressEvent(.loadstart, .{
            .lengthComputable = true,
            .loaded = 0,
            .total = self.total_size,
        });
    }

    /// Process upload chunk
    /// Returns true if progress event should be fired
    pub fn onChunk(self: *UploadTracker, chunk_size: usize) bool {
        if (!self.started) {
            self.fireLoadStart();
        }

        return self.progress.onChunk(chunk_size);
    }

    /// Fire progress event (called after chunk processing if throttle allows)
    pub fn fireProgress(self: *const UploadTracker) void {
        const info = self.getProgress();
        event_support.fireUploadProgressEvent(.progress, .{
            .lengthComputable = true,
            .loaded = info.loaded,
            .total = info.total,
        });
    }

    /// Fire completion events
    pub fn fireComplete(self: *UploadTracker) void {
        if (self.completed or self.error_occurred or self.aborted) return;
        self.completed = true;

        const info = self.getProgress();

        // Fire final progress event
        event_support.fireUploadProgressEvent(.progress, .{
            .lengthComputable = true,
            .loaded = info.loaded,
            .total = info.total,
        });

        // Fire load event
        event_support.fireUploadProgressEvent(.load, .{
            .lengthComputable = true,
            .loaded = info.loaded,
            .total = info.total,
        });

        // Fire loadend event
        event_support.fireUploadProgressEvent(.loadend, .{
            .lengthComputable = true,
            .loaded = info.loaded,
            .total = info.total,
        });
    }

    /// Fire error events
    pub fn fireError(self: *UploadTracker) void {
        if (self.completed or self.aborted) return;
        self.error_occurred = true;

        const info = self.getProgress();

        // Fire error event
        event_support.fireUploadProgressEvent(.@"error", .{
            .lengthComputable = true,
            .loaded = info.loaded,
            .total = info.total,
        });

        // Fire loadend event
        event_support.fireUploadProgressEvent(.loadend, .{
            .lengthComputable = true,
            .loaded = info.loaded,
            .total = info.total,
        });
    }

    /// Fire abort events
    pub fn fireAbort(self: *UploadTracker) void {
        if (self.completed or self.error_occurred) return;
        self.aborted = true;

        const info = self.getProgress();

        // Fire abort event
        event_support.fireUploadProgressEvent(.abort, .{
            .lengthComputable = true,
            .loaded = info.loaded,
            .total = info.total,
        });

        // Fire loadend event
        event_support.fireUploadProgressEvent(.loadend, .{
            .lengthComputable = true,
            .loaded = info.loaded,
            .total = info.total,
        });
    }

    /// Fire timeout events
    pub fn fireTimeout(self: *UploadTracker) void {
        if (self.completed or self.error_occurred or self.aborted) return;

        const info = self.getProgress();

        // Fire timeout event
        event_support.fireUploadProgressEvent(.timeout, .{
            .lengthComputable = true,
            .loaded = info.loaded,
            .total = info.total,
        });

        // Fire loadend event
        event_support.fireUploadProgressEvent(.loadend, .{
            .lengthComputable = true,
            .loaded = info.loaded,
            .total = info.total,
        });
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

    /// Force fire final progress (for completion)
    pub fn forceFire(self: *UploadTracker) void {
        self.progress.forceFire();
    }
};

// =============================================================================
// CORS Integration
// =============================================================================

/// CORS configuration for XHR upload
///
/// Spec: https://xhr.spec.whatwg.org/#the-send()-method
/// "If upload listener flag is set, set request's use-CORS-preflight flag."
pub const CorsConfig = struct {
    /// Whether credentials should be included
    with_credentials: bool,

    /// Whether upload listeners are present (triggers preflight)
    has_upload_listeners: bool,

    /// Get the credentials mode for Fetch
    pub fn getCredentialsMode(self: *const CorsConfig) CredentialsMode {
        return if (self.with_credentials) .include else .same_origin;
    }

    /// Check if CORS preflight is required
    ///
    /// Preflight is required when:
    /// - Request method is not simple (GET, HEAD, POST)
    /// - Request headers are not simple
    /// - Upload listeners are present
    pub fn requiresPreflight(self: *const CorsConfig, method: []const u8, headers: anytype) bool {
        // Upload listeners always trigger preflight
        if (self.has_upload_listeners) {
            return true;
        }

        // Non-simple methods require preflight
        if (!isSimpleMethod(method)) {
            return true;
        }

        // Non-simple headers require preflight
        _ = headers; // TODO: Check headers when integrated

        return false;
    }
};

/// Credentials mode (matching Fetch spec)
pub const CredentialsMode = enum {
    omit,
    same_origin,
    include,
};

/// Check if method is a simple method (no preflight needed)
fn isSimpleMethod(method: []const u8) bool {
    return std.ascii.eqlIgnoreCase(method, "GET") or
        std.ascii.eqlIgnoreCase(method, "HEAD") or
        std.ascii.eqlIgnoreCase(method, "POST");
}

/// Simple headers that don't trigger preflight
const simple_headers = [_][]const u8{
    "accept",
    "accept-language",
    "content-language",
    "content-type",
};

/// Check if a header is a simple header
pub fn isSimpleHeader(name: []const u8, value: []const u8) bool {
    const name_lower = name; // Assume already lowercase

    for (simple_headers) |simple| {
        if (std.ascii.eqlIgnoreCase(name_lower, simple)) {
            // content-type has additional restrictions
            if (std.ascii.eqlIgnoreCase(name_lower, "content-type")) {
                return isSimpleContentType(value);
            }
            return true;
        }
    }

    return false;
}

/// Simple content-type values
fn isSimpleContentType(value: []const u8) bool {
    // Extract MIME type (before parameters)
    const mime_end = std.mem.indexOf(u8, value, ";") orelse value.len;
    const mime = value[0..mime_end];

    return std.ascii.eqlIgnoreCase(mime, "application/x-www-form-urlencoded") or
        std.ascii.eqlIgnoreCase(mime, "multipart/form-data") or
        std.ascii.eqlIgnoreCase(mime, "text/plain");
}

// =============================================================================
// Tests
// =============================================================================

test "UploadTracker - initialization" {
    const tracker = UploadTracker.init(10240);

    try std.testing.expectEqual(@as(usize, 10240), tracker.total_size);
    try std.testing.expectEqual(@as(usize, 0), tracker.progress.total_bytes);
    try std.testing.expect(!tracker.started);
    try std.testing.expect(!tracker.completed);
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

test "UploadTracker - loadstart fires on first chunk" {
    var tracker = UploadTracker.init(1024);

    try std.testing.expect(!tracker.started);

    _ = tracker.onChunk(256);

    try std.testing.expect(tracker.started);
}

test "UploadTracker - fireComplete sets completed flag" {
    var tracker = UploadTracker.init(1024);
    tracker.started = true;

    _ = tracker.onChunk(1024);
    tracker.fireComplete();

    try std.testing.expect(tracker.completed);
}

test "UploadTracker - fireComplete only fires once" {
    var tracker = UploadTracker.init(1024);
    tracker.started = true;

    tracker.fireComplete();
    try std.testing.expect(tracker.completed);

    // Second call should be no-op
    tracker.fireComplete();
    try std.testing.expect(tracker.completed);
}

test "UploadTracker - fireError sets error flag" {
    var tracker = UploadTracker.init(1024);
    tracker.started = true;

    tracker.fireError();

    try std.testing.expect(tracker.error_occurred);
    try std.testing.expect(!tracker.completed);
}

test "UploadTracker - fireAbort sets aborted flag" {
    var tracker = UploadTracker.init(1024);
    tracker.started = true;

    tracker.fireAbort();

    try std.testing.expect(tracker.aborted);
    try std.testing.expect(!tracker.completed);
}

// =============================================================================
// CORS Tests
// =============================================================================

test "CorsConfig - credentials mode" {
    const config_with = CorsConfig{ .with_credentials = true, .has_upload_listeners = false };
    try std.testing.expectEqual(CredentialsMode.include, config_with.getCredentialsMode());

    const config_without = CorsConfig{ .with_credentials = false, .has_upload_listeners = false };
    try std.testing.expectEqual(CredentialsMode.same_origin, config_without.getCredentialsMode());
}

test "CorsConfig - preflight required for upload listeners" {
    const config = CorsConfig{ .with_credentials = false, .has_upload_listeners = true };

    // Even simple GET requires preflight when upload listeners present
    try std.testing.expect(config.requiresPreflight("GET", .{}));
}

test "CorsConfig - preflight for non-simple methods" {
    const config = CorsConfig{ .with_credentials = false, .has_upload_listeners = false };

    try std.testing.expect(!config.requiresPreflight("GET", .{}));
    try std.testing.expect(!config.requiresPreflight("HEAD", .{}));
    try std.testing.expect(!config.requiresPreflight("POST", .{}));

    try std.testing.expect(config.requiresPreflight("PUT", .{}));
    try std.testing.expect(config.requiresPreflight("DELETE", .{}));
    try std.testing.expect(config.requiresPreflight("PATCH", .{}));
}

test "isSimpleMethod - simple methods" {
    try std.testing.expect(isSimpleMethod("GET"));
    try std.testing.expect(isSimpleMethod("get"));
    try std.testing.expect(isSimpleMethod("HEAD"));
    try std.testing.expect(isSimpleMethod("POST"));
}

test "isSimpleMethod - non-simple methods" {
    try std.testing.expect(!isSimpleMethod("PUT"));
    try std.testing.expect(!isSimpleMethod("DELETE"));
    try std.testing.expect(!isSimpleMethod("PATCH"));
    try std.testing.expect(!isSimpleMethod("OPTIONS"));
}

test "isSimpleHeader - simple headers" {
    try std.testing.expect(isSimpleHeader("accept", "text/html"));
    try std.testing.expect(isSimpleHeader("Accept-Language", "en-US"));
    try std.testing.expect(isSimpleHeader("content-language", "en"));
}

test "isSimpleHeader - content-type restrictions" {
    try std.testing.expect(isSimpleHeader("content-type", "text/plain"));
    try std.testing.expect(isSimpleHeader("content-type", "application/x-www-form-urlencoded"));
    try std.testing.expect(isSimpleHeader("content-type", "multipart/form-data"));
    try std.testing.expect(isSimpleHeader("content-type", "text/plain; charset=utf-8"));

    try std.testing.expect(!isSimpleHeader("content-type", "application/json"));
    try std.testing.expect(!isSimpleHeader("content-type", "application/xml"));
}

test "isSimpleHeader - non-simple headers" {
    try std.testing.expect(!isSimpleHeader("Authorization", "Bearer token"));
    try std.testing.expect(!isSimpleHeader("X-Custom-Header", "value"));
}
