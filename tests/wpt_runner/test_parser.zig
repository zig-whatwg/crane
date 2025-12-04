//! WPT Test File Parser
//!
//! Parses WPT test files in various formats (.html, .any.js, .window.js, .worker.js)
//! and extracts metadata, script dependencies, and test content.
//!
//! ## Metadata Format
//!
//! JavaScript test files use META comments at the top:
//! ```javascript
//! // META: title=Test title
//! // META: script=/resources/testharness.js
//! // META: script=/resources/testharnessreport.js
//! // META: script=./helper.js
//! // META: global=window,worker
//! // META: timeout=long
//! // META: variant=?query1
//! // META: variant=?query2
//! ```
//!
//! HTML test files use meta and script tags:
//! ```html
//! <meta name="timeout" content="long">
//! <meta name="variant" content="?query">
//! <script src="/resources/testharness.js"></script>
//! <script src="/resources/testharnessreport.js"></script>
//! <script>/* test code */</script>
//! ```

const std = @import("std");
const config = @import("config.zig");

/// Global context type for test execution
pub const GlobalType = enum {
    /// Window/document context
    window,
    /// Dedicated worker context
    worker,
    /// Shared worker context
    sharedworker,
    /// Service worker context
    serviceworker,

    pub fn fromString(str: []const u8) ?GlobalType {
        if (std.mem.eql(u8, str, "window")) return .window;
        if (std.mem.eql(u8, str, "worker")) return .worker;
        if (std.mem.eql(u8, str, "dedicatedworker")) return .worker;
        if (std.mem.eql(u8, str, "sharedworker")) return .sharedworker;
        if (std.mem.eql(u8, str, "serviceworker")) return .serviceworker;
        return null;
    }
};

/// Script reference in a test file
pub const ScriptRef = struct {
    /// Script path (absolute or relative)
    path: []const u8,
    /// Whether this is an inline script (content is the script itself)
    inline_script: bool = false,

    pub fn deinit(self: *ScriptRef, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

/// Parsed test file metadata
pub const TestMetadata = struct {
    allocator: std.mem.Allocator,
    /// Test title
    title: ?[]const u8 = null,
    /// Timeout setting
    timeout: config.Timeout = .normal,
    /// Query string variants to run
    variants: std.ArrayList([]const u8),
    /// Script dependencies (in load order)
    scripts: std.ArrayList(ScriptRef),
    /// Global contexts to run in (for .any.js)
    globals: std.ArrayList(GlobalType),
    /// Spec reference links
    spec_links: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) TestMetadata {
        return TestMetadata{
            .allocator = allocator,
            .variants = .{},
            .scripts = .{},
            .globals = .{},
            .spec_links = .{},
        };
    }

    pub fn deinit(self: *TestMetadata) void {
        if (self.title) |t| self.allocator.free(t);
        for (self.variants.items) |v| self.allocator.free(v);
        self.variants.deinit(self.allocator);
        for (self.scripts.items) |*s| s.deinit(self.allocator);
        self.scripts.deinit(self.allocator);
        self.globals.deinit(self.allocator);
        for (self.spec_links.items) |l| self.allocator.free(l);
        self.spec_links.deinit(self.allocator);
    }

    /// Add a script dependency
    pub fn addScript(self: *TestMetadata, path: []const u8) !void {
        try self.scripts.append(self.allocator, ScriptRef{
            .path = try self.allocator.dupe(u8, path),
        });
    }

    /// Add an inline script
    pub fn addInlineScript(self: *TestMetadata, content: []const u8) !void {
        try self.scripts.append(self.allocator, ScriptRef{
            .path = try self.allocator.dupe(u8, content),
            .inline_script = true,
        });
    }

    /// Add a variant
    pub fn addVariant(self: *TestMetadata, variant: []const u8) !void {
        try self.variants.append(self.allocator, try self.allocator.dupe(u8, variant));
    }

    /// Add a global context
    pub fn addGlobal(self: *TestMetadata, global: GlobalType) !void {
        try self.globals.append(self.allocator, global);
    }
};

/// Parsed test file
pub const ParsedTest = struct {
    allocator: std.mem.Allocator,
    /// File path relative to WPT root
    path: []const u8,
    /// File type
    file_type: config.FileType,
    /// Parsed metadata
    metadata: TestMetadata,
    /// Test content (script content for JS files, full HTML for HTML files)
    content: []const u8,

    pub fn deinit(self: *ParsedTest) void {
        self.allocator.free(self.path);
        self.metadata.deinit();
        self.allocator.free(self.content);
    }
};

/// Parse META comments from a JavaScript test file
pub fn parseMetaComments(allocator: std.mem.Allocator, content: []const u8) !TestMetadata {
    var metadata = TestMetadata.init(allocator);
    errdefer metadata.deinit();

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        // Stop at first non-comment, non-empty line
        if (trimmed.len == 0) continue;
        if (!std.mem.startsWith(u8, trimmed, "//")) break;

        // Check for META comment
        const meta_prefix = "// META:";
        if (!std.mem.startsWith(u8, trimmed, meta_prefix)) continue;

        const meta_content = std.mem.trim(u8, trimmed[meta_prefix.len..], &std.ascii.whitespace);

        // Parse META key=value
        if (std.mem.indexOf(u8, meta_content, "=")) |eq_pos| {
            const key = std.mem.trim(u8, meta_content[0..eq_pos], &std.ascii.whitespace);
            const value = std.mem.trim(u8, meta_content[eq_pos + 1 ..], &std.ascii.whitespace);

            if (std.mem.eql(u8, key, "title")) {
                metadata.title = try allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "script")) {
                try metadata.addScript(value);
            } else if (std.mem.eql(u8, key, "timeout")) {
                if (std.mem.eql(u8, value, "long")) {
                    metadata.timeout = .long;
                }
            } else if (std.mem.eql(u8, key, "variant")) {
                try metadata.addVariant(value);
            } else if (std.mem.eql(u8, key, "global")) {
                // Parse comma-separated globals
                var globals = std.mem.splitScalar(u8, value, ',');
                while (globals.next()) |g| {
                    const gtrim = std.mem.trim(u8, g, &std.ascii.whitespace);
                    if (GlobalType.fromString(gtrim)) |global| {
                        try metadata.addGlobal(global);
                    }
                }
            }
        }
    }

    // Default globals for .any.js files
    if (metadata.globals.items.len == 0) {
        try metadata.addGlobal(.window);
        try metadata.addGlobal(.worker);
    }

    return metadata;
}

/// Parse a .any.js test file
pub fn parseAnyJs(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ParsedTest {
    var metadata = try parseMetaComments(allocator, content);
    errdefer metadata.deinit();

    return ParsedTest{
        .allocator = allocator,
        .path = try allocator.dupe(u8, path),
        .file_type = .any_js,
        .metadata = metadata,
        .content = try allocator.dupe(u8, content),
    };
}

/// Parse a .window.js test file
pub fn parseWindowJs(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ParsedTest {
    var metadata = try parseMetaComments(allocator, content);
    errdefer metadata.deinit();

    // Window-only - override any global settings
    metadata.globals.clearRetainingCapacity();
    try metadata.addGlobal(.window);

    return ParsedTest{
        .allocator = allocator,
        .path = try allocator.dupe(u8, path),
        .file_type = .window_js,
        .metadata = metadata,
        .content = try allocator.dupe(u8, content),
    };
}

/// Parse a .worker.js test file
pub fn parseWorkerJs(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ParsedTest {
    var metadata = try parseMetaComments(allocator, content);
    errdefer metadata.deinit();

    // Worker-only - override any global settings
    metadata.globals.clearRetainingCapacity();
    try metadata.addGlobal(.worker);

    return ParsedTest{
        .allocator = allocator,
        .path = try allocator.dupe(u8, path),
        .file_type = .worker_js,
        .metadata = metadata,
        .content = try allocator.dupe(u8, content),
    };
}

/// Parse an HTML test file
/// Note: This is a simplified parser that extracts scripts. For full HTML parsing,
/// use the HTML parser from src/html/.
pub fn parseHtml(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ParsedTest {
    var metadata = TestMetadata.init(allocator);
    errdefer metadata.deinit();

    // Window context only for HTML files
    try metadata.addGlobal(.window);

    // Simple extraction of meta tags and scripts
    // TODO: Use proper HTML parser for robust extraction

    // Look for timeout meta tag
    if (std.mem.indexOf(u8, content, "name=\"timeout\"")) |_| {
        if (std.mem.indexOf(u8, content, "content=\"long\"")) |_| {
            metadata.timeout = .long;
        }
    }

    // Extract script src attributes (very simplified)
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, content, pos, "<script")) |script_start| {
        const tag_end = std.mem.indexOfPos(u8, content, script_start, ">") orelse break;

        const tag = content[script_start..tag_end];
        if (std.mem.indexOf(u8, tag, "src=\"")) |src_start| {
            const src_value_start = script_start + src_start + 5;
            if (std.mem.indexOfPos(u8, content, src_value_start, "\"")) |src_end| {
                const src = content[src_value_start..src_end];
                try metadata.addScript(src);
            }
        } else if (std.mem.indexOf(u8, tag, "src='")) |src_start| {
            const src_value_start = script_start + src_start + 5;
            if (std.mem.indexOfPos(u8, content, src_value_start, "'")) |src_end| {
                const src = content[src_value_start..src_end];
                try metadata.addScript(src);
            }
        }

        pos = tag_end + 1;
    }

    return ParsedTest{
        .allocator = allocator,
        .path = try allocator.dupe(u8, path),
        .file_type = .html,
        .metadata = metadata,
        .content = try allocator.dupe(u8, content),
    };
}

/// Parse a test file based on its extension
pub fn parseTestFile(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ParsedTest {
    const file_type = config.FileType.fromPath(path);
    return switch (file_type) {
        .any_js => parseAnyJs(allocator, path, content),
        .window_js => parseWindowJs(allocator, path, content),
        .worker_js => parseWorkerJs(allocator, path, content),
        .html => parseHtml(allocator, path, content),
        .unknown => error.UnsupportedTestFormat,
    };
}

/// Resolve a script path relative to the test file
pub fn resolveScriptPath(
    allocator: std.mem.Allocator,
    wpt_root: []const u8,
    test_path: []const u8,
    script_path: []const u8,
) ![]const u8 {
    if (std.mem.startsWith(u8, script_path, "/")) {
        // Absolute path - relative to WPT root
        return std.fs.path.join(allocator, &.{ wpt_root, script_path[1..] });
    } else if (std.mem.startsWith(u8, script_path, "./")) {
        // Relative to test file directory
        const test_dir = std.fs.path.dirname(test_path) orelse "";
        return std.fs.path.join(allocator, &.{ wpt_root, test_dir, script_path[2..] });
    } else if (std.mem.startsWith(u8, script_path, "../")) {
        // Parent directory relative
        const test_dir = std.fs.path.dirname(test_path) orelse "";
        return std.fs.path.join(allocator, &.{ wpt_root, test_dir, script_path });
    } else {
        // Bare filename - relative to test file directory
        const test_dir = std.fs.path.dirname(test_path) orelse "";
        return std.fs.path.join(allocator, &.{ wpt_root, test_dir, script_path });
    }
}

test "parseMetaComments basic" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\// META: title=URL constructor tests
        \\// META: script=/resources/testharness.js
        \\// META: timeout=long
        \\// META: variant=?exclude=none
        \\
        \\test(function() {
        \\  // test code
        \\});
    ;

    var metadata = try parseMetaComments(allocator, content);
    defer metadata.deinit();

    try testing.expectEqualStrings("URL constructor tests", metadata.title.?);
    try testing.expectEqual(config.Timeout.long, metadata.timeout);
    try testing.expectEqual(@as(usize, 1), metadata.scripts.items.len);
    try testing.expectEqualStrings("/resources/testharness.js", metadata.scripts.items[0].path);
    try testing.expectEqual(@as(usize, 1), metadata.variants.items.len);
}

test "parseMetaComments global" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\// META: global=window,worker,sharedworker
        \\test(() => {});
    ;

    var metadata = try parseMetaComments(allocator, content);
    defer metadata.deinit();

    try testing.expectEqual(@as(usize, 3), metadata.globals.items.len);
    try testing.expectEqual(GlobalType.window, metadata.globals.items[0]);
    try testing.expectEqual(GlobalType.worker, metadata.globals.items[1]);
    try testing.expectEqual(GlobalType.sharedworker, metadata.globals.items[2]);
}

test "resolveScriptPath" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Absolute path
    const abs = try resolveScriptPath(allocator, "tests/wpt", "url/test.any.js", "/resources/testharness.js");
    defer allocator.free(abs);
    try testing.expectEqualStrings("tests/wpt/resources/testharness.js", abs);

    // Relative path
    const rel = try resolveScriptPath(allocator, "tests/wpt", "url/test.any.js", "./helper.js");
    defer allocator.free(rel);
    try testing.expectEqualStrings("tests/wpt/url/helper.js", rel);
}
