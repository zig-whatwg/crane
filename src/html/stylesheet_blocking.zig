//! Stylesheet Blocking Scripts
//!
//! Spec: HTML Standard § 14.3.3 Render-blocking mechanism
//! https://html.spec.whatwg.org/#render-blocking
//!
//! This module implements the "style sheet that is blocking scripts" check
//! per HTML Standard. It tracks pending stylesheets and blocks script
//! execution until critical CSS is loaded.
//!
//! ## Why This Matters
//!
//! Scripts that execute before critical CSS is loaded can cause:
//! - FOUC (Flash of Unstyled Content)
//! - Incorrect layout measurements
//! - Race conditions between script and style
//!
//! ## Algorithm
//!
//! Spec: HTML Standard § 14.3.3
//! "A style sheet is blocking scripts if:
//! 1. The element is a link element
//! 2. The element has a disabled attribute
//! 3. The style sheet is from a non-blocking stylesheet algorithm"

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Blocking Stylesheet Tracker
// ============================================================================

/// A pending stylesheet entry
pub const PendingStylesheet = struct {
    /// Unique identifier for this stylesheet (typically the URL)
    id: []const u8,

    /// Whether this stylesheet is blocking scripts
    is_blocking: bool,

    /// Whether the stylesheet has finished loading
    loaded: bool,

    /// Whether the stylesheet load failed
    failed: bool,

    /// Origin URL of the stylesheet
    url: []const u8,

    /// Allocator
    allocator: Allocator,

    /// Create a new pending stylesheet entry
    pub fn init(allocator: Allocator, id: []const u8, url: []const u8, is_blocking: bool) !*PendingStylesheet {
        const stylesheet = try allocator.create(PendingStylesheet);
        errdefer allocator.destroy(stylesheet);

        const id_copy = try allocator.dupe(u8, id);
        errdefer allocator.free(id_copy);

        const url_copy = try allocator.dupe(u8, url);
        errdefer allocator.free(url_copy);

        stylesheet.* = .{
            .id = id_copy,
            .is_blocking = is_blocking,
            .loaded = false,
            .failed = false,
            .url = url_copy,
            .allocator = allocator,
        };

        return stylesheet;
    }

    /// Clean up resources
    pub fn deinit(self: *PendingStylesheet) void {
        self.allocator.free(self.id);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

/// Callback for when blocking is resolved
pub const BlockingResolvedCallback = *const fn (context: ?*anyopaque) void;

/// Stylesheet Blocking Tracker
///
/// Tracks pending stylesheets and determines when scripts can execute.
///
/// Spec: HTML Standard § 14.3.3
/// "A Document has a style sheet that is blocking scripts if it has a
/// pending parsing-blocking style sheet or a pending render-blocking element."
pub const StylesheetBlockingTracker = struct {
    /// Pending stylesheets (id -> PendingStylesheet)
    pending_stylesheets: std.StringHashMapUnmanaged(*PendingStylesheet),

    /// Count of blocking stylesheets that haven't loaded yet
    blocking_count: usize,

    /// Callback when all blocking stylesheets are resolved
    on_blocking_resolved: ?BlockingResolvedCallback,

    /// Context for callback
    callback_context: ?*anyopaque,

    /// Allocator
    allocator: Allocator,

    /// Initialize the tracker
    pub fn init(allocator: Allocator) StylesheetBlockingTracker {
        return .{
            .pending_stylesheets = .{},
            .blocking_count = 0,
            .on_blocking_resolved = null,
            .callback_context = null,
            .allocator = allocator,
        };
    }

    /// Clean up all resources
    pub fn deinit(self: *StylesheetBlockingTracker) void {
        var iter = self.pending_stylesheets.valueIterator();
        while (iter.next()) |stylesheet| {
            stylesheet.*.deinit();
        }
        self.pending_stylesheets.deinit(self.allocator);
    }

    /// Set the callback for when blocking is resolved
    pub fn setBlockingResolvedCallback(
        self: *StylesheetBlockingTracker,
        callback: BlockingResolvedCallback,
        context: ?*anyopaque,
    ) void {
        self.on_blocking_resolved = callback;
        self.callback_context = context;
    }

    /// Add a pending stylesheet
    ///
    /// Spec: HTML Standard § 4.2.4 "A link element that creates a style sheet"
    ///
    /// @param id Unique identifier for this stylesheet
    /// @param url URL of the stylesheet
    /// @param is_blocking Whether this stylesheet blocks scripts
    pub fn addStylesheet(
        self: *StylesheetBlockingTracker,
        id: []const u8,
        url: []const u8,
        is_blocking: bool,
    ) !void {
        // Check if already exists
        if (self.pending_stylesheets.get(id)) |_| {
            return; // Already tracking this stylesheet
        }

        const stylesheet = try PendingStylesheet.init(self.allocator, id, url, is_blocking);
        errdefer stylesheet.deinit();

        // Make key copy for the map
        const key = try self.allocator.dupe(u8, id);
        try self.pending_stylesheets.put(self.allocator, key, stylesheet);

        if (is_blocking) {
            self.blocking_count += 1;
        }
    }

    /// Mark a stylesheet as loaded
    ///
    /// Spec: HTML Standard § 4.2.4 step 15
    /// "When the fetch is completed, process the linked resource..."
    pub fn markLoaded(self: *StylesheetBlockingTracker, id: []const u8) void {
        if (self.pending_stylesheets.get(id)) |stylesheet| {
            if (!stylesheet.loaded and !stylesheet.failed) {
                stylesheet.loaded = true;
                if (stylesheet.is_blocking) {
                    self.decrementBlockingCount();
                }
            }
        }
    }

    /// Mark a stylesheet as failed
    ///
    /// Spec: HTML Standard § 4.2.4
    /// "If the fetch resulted in a DNS error, a TLS negotiation error..."
    pub fn markFailed(self: *StylesheetBlockingTracker, id: []const u8) void {
        if (self.pending_stylesheets.get(id)) |stylesheet| {
            if (!stylesheet.loaded and !stylesheet.failed) {
                stylesheet.failed = true;
                if (stylesheet.is_blocking) {
                    self.decrementBlockingCount();
                }
            }
        }
    }

    /// Remove a stylesheet from tracking
    pub fn removeStylesheet(self: *StylesheetBlockingTracker, id: []const u8) void {
        if (self.pending_stylesheets.fetchRemove(id)) |entry| {
            const stylesheet = entry.value;
            if (stylesheet.is_blocking and !stylesheet.loaded and !stylesheet.failed) {
                self.decrementBlockingCount();
            }
            stylesheet.deinit();
            self.allocator.free(entry.key);
        }
    }

    /// Check if scripts should be blocked
    ///
    /// Spec: HTML Standard § 14.3.3
    /// "A Document has a style sheet that is blocking scripts if..."
    pub fn hasBlockingStylesheet(self: *const StylesheetBlockingTracker) bool {
        return self.blocking_count > 0;
    }

    /// Get the number of pending blocking stylesheets
    pub fn getBlockingCount(self: *const StylesheetBlockingTracker) usize {
        return self.blocking_count;
    }

    /// Get the total number of pending stylesheets
    pub fn getTotalCount(self: *const StylesheetBlockingTracker) usize {
        return self.pending_stylesheets.count();
    }

    /// Decrement blocking count and fire callback if appropriate
    fn decrementBlockingCount(self: *StylesheetBlockingTracker) void {
        if (self.blocking_count > 0) {
            self.blocking_count -= 1;
            if (self.blocking_count == 0) {
                // All blocking stylesheets resolved
                if (self.on_blocking_resolved) |callback| {
                    callback(self.callback_context);
                }
            }
        }
    }
};

// ============================================================================
// Stylesheet Type Detection
// ============================================================================

/// Determine if a stylesheet link element is blocking
///
/// Spec: HTML Standard § 4.2.4.1 Processing the `media` attribute
/// "A link element is potentially render-blocking if the element is
/// implicitly potentially render-blocking and the element is in a
/// document tree."
pub fn isBlockingStylesheet(
    rel: []const u8,
    media: ?[]const u8,
    disabled: bool,
    rendering_attribute: ?[]const u8,
) bool {
    // Disabled stylesheets are never blocking
    if (disabled) {
        return false;
    }

    // Must be a stylesheet link
    if (!isStylesheetRel(rel)) {
        return false;
    }

    // Check render-blocking attribute
    // Spec: "blocking=render" makes it explicitly render-blocking
    if (rendering_attribute) |blocking| {
        if (std.mem.eql(u8, blocking, "render")) {
            return true;
        }
    }

    // Check media query
    // If media doesn't match, it's not blocking
    if (media) |m| {
        if (std.mem.eql(u8, m, "print")) {
            return false; // Print stylesheets never block
        }
        // TODO: Full media query evaluation
        // For now, assume other media types may match
    }

    // By default, stylesheets without explicit non-blocking attributes are blocking
    return true;
}

/// Check if rel attribute indicates a stylesheet
pub fn isStylesheetRel(rel: []const u8) bool {
    // Case-insensitive check for "stylesheet"
    var lower_buf: [64]u8 = undefined;
    const len = @min(rel.len, lower_buf.len);
    for (rel[0..len], 0..) |c, i| {
        lower_buf[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    return std.mem.startsWith(u8, lower_buf[0..len], "stylesheet");
}

// ============================================================================
// Script Blocking Check
// ============================================================================

/// Check if script execution should be blocked
///
/// Spec: HTML Standard § 14.3.3
/// "A Document has a style sheet that is blocking scripts if it has a
/// pending parsing-blocking style sheet."
///
/// This should be called before executing parser-inserted scripts.
pub fn shouldBlockScriptExecution(tracker: *const StylesheetBlockingTracker) bool {
    return tracker.hasBlockingStylesheet();
}

// ============================================================================
// Tests
// ============================================================================

test "StylesheetBlockingTracker - basic tracking" {
    const allocator = std.testing.allocator;

    var tracker = StylesheetBlockingTracker.init(allocator);
    defer tracker.deinit();

    // Initially no blocking
    try std.testing.expect(!tracker.hasBlockingStylesheet());
    try std.testing.expectEqual(@as(usize, 0), tracker.getBlockingCount());

    // Add blocking stylesheet
    try tracker.addStylesheet("style1", "https://example.com/style.css", true);
    try std.testing.expect(tracker.hasBlockingStylesheet());
    try std.testing.expectEqual(@as(usize, 1), tracker.getBlockingCount());

    // Mark loaded
    tracker.markLoaded("style1");
    try std.testing.expect(!tracker.hasBlockingStylesheet());
    try std.testing.expectEqual(@as(usize, 0), tracker.getBlockingCount());
}

test "StylesheetBlockingTracker - multiple stylesheets" {
    const allocator = std.testing.allocator;

    var tracker = StylesheetBlockingTracker.init(allocator);
    defer tracker.deinit();

    // Add multiple blocking stylesheets
    try tracker.addStylesheet("style1", "https://example.com/a.css", true);
    try tracker.addStylesheet("style2", "https://example.com/b.css", true);
    try tracker.addStylesheet("style3", "https://example.com/c.css", false); // Non-blocking

    try std.testing.expect(tracker.hasBlockingStylesheet());
    try std.testing.expectEqual(@as(usize, 2), tracker.getBlockingCount());
    try std.testing.expectEqual(@as(usize, 3), tracker.getTotalCount());

    // Mark first loaded
    tracker.markLoaded("style1");
    try std.testing.expect(tracker.hasBlockingStylesheet());
    try std.testing.expectEqual(@as(usize, 1), tracker.getBlockingCount());

    // Mark second loaded
    tracker.markLoaded("style2");
    try std.testing.expect(!tracker.hasBlockingStylesheet());
    try std.testing.expectEqual(@as(usize, 0), tracker.getBlockingCount());
}

test "StylesheetBlockingTracker - failed stylesheet" {
    const allocator = std.testing.allocator;

    var tracker = StylesheetBlockingTracker.init(allocator);
    defer tracker.deinit();

    try tracker.addStylesheet("style1", "https://example.com/broken.css", true);
    try std.testing.expect(tracker.hasBlockingStylesheet());

    // Mark failed should also unblock
    tracker.markFailed("style1");
    try std.testing.expect(!tracker.hasBlockingStylesheet());
}

test "StylesheetBlockingTracker - callback on resolution" {
    const allocator = std.testing.allocator;

    var tracker = StylesheetBlockingTracker.init(allocator);
    defer tracker.deinit();

    var callback_called: bool = false;
    const TestCallback = struct {
        fn callback(context: ?*anyopaque) void {
            const called: *bool = @ptrCast(@alignCast(context.?));
            called.* = true;
        }
    };

    tracker.setBlockingResolvedCallback(TestCallback.callback, @ptrCast(&callback_called));

    try tracker.addStylesheet("style1", "https://example.com/style.css", true);
    try std.testing.expect(!callback_called);

    tracker.markLoaded("style1");
    try std.testing.expect(callback_called);
}

test "isBlockingStylesheet - disabled" {
    try std.testing.expect(!isBlockingStylesheet("stylesheet", null, true, null));
}

test "isBlockingStylesheet - print media" {
    try std.testing.expect(!isBlockingStylesheet("stylesheet", "print", false, null));
}

test "isBlockingStylesheet - default is blocking" {
    try std.testing.expect(isBlockingStylesheet("stylesheet", null, false, null));
}

test "isBlockingStylesheet - explicit render-blocking" {
    try std.testing.expect(isBlockingStylesheet("stylesheet", null, false, "render"));
}

test "isStylesheetRel" {
    try std.testing.expect(isStylesheetRel("stylesheet"));
    try std.testing.expect(isStylesheetRel("Stylesheet"));
    try std.testing.expect(isStylesheetRel("STYLESHEET"));
    try std.testing.expect(!isStylesheetRel("icon"));
    try std.testing.expect(!isStylesheetRel("preload"));
}
