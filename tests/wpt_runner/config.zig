//! WPT Runner Configuration
//!
//! Defines test categories, exclusion patterns, and runtime settings for
//! the WPT test runner.
//!
//! ## In-Scope Categories
//!
//! These are the WHATWG/W3C spec categories we implement and test:
//! - url/ - URL Standard
//! - urlpattern/ - URLPattern Standard
//! - encoding/ - Encoding Standard
//! - console/ - Console Standard
//! - mimesniff/ - MIME Sniffing Standard
//! - streams/ - Streams Standard
//! - fetch/ - Fetch Standard
//! - xhr/ - XMLHttpRequest Standard
//! - dom/ - DOM Standard
//! - html/ - HTML Standard (non-rendering only)
//! - cookiestore/ - Cookie Store API
//!
//! ## Out-of-Scope Categories
//!
//! These require rendering or browser-specific features:
//! - css/ - CSS tests (require layout)
//! - 2dcontext/ - Canvas 2D (require graphics)
//! - webgl/ - WebGL (require graphics)

const std = @import("std");

/// Test timeout configuration
pub const Timeout = enum {
    /// Normal timeout: 10 seconds
    normal,
    /// Long timeout: 60 seconds (for complex async tests)
    long,

    pub fn toMillis(self: Timeout) u64 {
        return switch (self) {
            .normal => 10_000,
            .long => 60_000,
        };
    }
};

/// Test file type determined by extension
pub const FileType = enum {
    /// HTML test document
    html,
    /// Multi-context JavaScript test (window + worker)
    any_js,
    /// Window-only JavaScript test
    window_js,
    /// Worker-only JavaScript test
    worker_js,
    /// Unknown/unsupported file type
    unknown,

    pub fn fromPath(path: []const u8) FileType {
        if (std.mem.endsWith(u8, path, ".any.js")) return .any_js;
        if (std.mem.endsWith(u8, path, ".window.js")) return .window_js;
        if (std.mem.endsWith(u8, path, ".worker.js")) return .worker_js;
        if (std.mem.endsWith(u8, path, ".html") or std.mem.endsWith(u8, path, ".htm")) return .html;
        return .unknown;
    }
};

/// Test category configuration
pub const TestCategory = struct {
    /// Directory name in WPT tree
    name: []const u8,
    /// Whether this category is enabled for testing
    enabled: bool = true,
    /// Description of what this category tests
    description: []const u8 = "",
};

/// In-scope test categories
/// These match the WHATWG/W3C specs implemented in this project
pub const in_scope_categories: []const TestCategory = &.{
    .{ .name = "url", .description = "URL Standard" },
    .{ .name = "urlpattern", .description = "URLPattern Standard" },
    .{ .name = "encoding", .description = "Encoding Standard" },
    .{ .name = "console", .description = "Console Standard" },
    .{ .name = "mimesniff", .description = "MIME Sniffing Standard" },
    .{ .name = "streams", .description = "Streams Standard" },
    .{ .name = "fetch", .description = "Fetch Standard" },
    .{ .name = "xhr", .description = "XMLHttpRequest Standard" },
    .{ .name = "dom", .description = "DOM Standard" },
    .{ .name = "html", .description = "HTML Standard (non-rendering)" },
    .{ .name = "cookiestore", .description = "Cookie Store API" },
};

/// Exclusion patterns for paths that shouldn't be tested
/// These are tests that require rendering, graphics, or other unsupported features
pub const exclusion_patterns: []const []const u8 = &.{
    // HTML rendering tests
    "html/rendering/",
    "html/canvas/",
    "html/semantics/embedded-content/media-elements/",
    "html/semantics/embedded-content/the-video-element/",
    "html/semantics/embedded-content/the-audio-element/",
    "html/webappapis/animation-frames/",
    // Visual/interactive tests
    "/visual/",
    "-manual.html",
    "-manual.htm",
    // Support files (not tests themselves)
    "/support/",
    "/resources/",
    // WPT infrastructure tests
    "/infrastructure/",
    "/.well-known/",
    // Reference tests (visual comparison)
    "-ref.html",
    "-ref.htm",
    // Print tests
    "/print/",
    // Tentative/experimental tests
    "/tentative/",
};

/// Check if a path matches any exclusion pattern
pub fn isExcluded(path: []const u8) bool {
    for (exclusion_patterns) |pattern| {
        if (std.mem.indexOf(u8, path, pattern) != null) {
            return true;
        }
    }
    return false;
}

/// Check if a path is in an in-scope category
pub fn isInScope(path: []const u8) bool {
    for (in_scope_categories) |cat| {
        if (cat.enabled and std.mem.startsWith(u8, path, cat.name)) {
            return !isExcluded(path);
        }
        // Also check with leading slash (e.g., "/url/")
        if (cat.enabled and path.len > 0 and path[0] == '/') {
            // Build pattern: check if path starts with /<name>/
            if (std.mem.startsWith(u8, path[1..], cat.name)) {
                // Check for trailing / or end of category name
                const after_name = 1 + cat.name.len;
                if (path.len > after_name and path[after_name] == '/') {
                    return !isExcluded(path);
                }
            }
        }
    }
    return false;
}

/// WPT runner configuration
pub const WptConfig = struct {
    /// Path to WPT root directory (usually tests/wpt/)
    wpt_root: []const u8 = "tests/wpt",
    /// Output directory for results
    output_dir: []const u8 = "wpt-results",
    /// Output filename
    output_file: []const u8 = "wptreport.json",
    /// Default timeout for tests
    default_timeout: Timeout = .normal,
    /// Number of parallel test runners (0 = auto based on CPU count)
    parallel: u32 = 0,
    /// Verbose output (show each test as it runs)
    verbose: bool = false,
    /// Directory filters (empty = all in-scope)
    filters: []const []const u8 = &.{},

    /// Get the full output path
    pub fn getOutputPath(self: WptConfig, allocator: std.mem.Allocator) ![]const u8 {
        return std.fs.path.join(allocator, &.{ self.output_dir, self.output_file });
    }
};

/// Default configuration
pub const default_config = WptConfig{};

test "FileType.fromPath" {
    const testing = std.testing;

    try testing.expectEqual(FileType.any_js, FileType.fromPath("url/url-constructor.any.js"));
    try testing.expectEqual(FileType.window_js, FileType.fromPath("dom/event.window.js"));
    try testing.expectEqual(FileType.worker_js, FileType.fromPath("streams/byte-stream.worker.js"));
    try testing.expectEqual(FileType.html, FileType.fromPath("html/test.html"));
    try testing.expectEqual(FileType.unknown, FileType.fromPath("readme.md"));
}

test "isExcluded" {
    const testing = std.testing;

    try testing.expect(isExcluded("html/rendering/foo.html"));
    try testing.expect(isExcluded("html/canvas/test.html"));
    try testing.expect(isExcluded("url/support/helper.js"));
    try testing.expect(isExcluded("test-manual.html"));
    try testing.expect(!isExcluded("url/url-constructor.any.js"));
    try testing.expect(!isExcluded("dom/events/Event.html"));
}

test "isInScope" {
    const testing = std.testing;

    try testing.expect(isInScope("url/url-constructor.any.js"));
    try testing.expect(isInScope("urlpattern/urlpattern.any.js"));
    try testing.expect(isInScope("encoding/textdecoder.any.js"));
    try testing.expect(isInScope("dom/events/Event.html"));
    try testing.expect(isInScope("cookiestore/cookieStore_get_set_basic.https.any.js"));
    try testing.expect(!isInScope("css/selectors/test.html"));
    try testing.expect(!isInScope("webgl/test.html"));
    try testing.expect(!isInScope("html/rendering/test.html"));
}
