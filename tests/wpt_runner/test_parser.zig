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
//!
//! ## Test File Types
//!
//! - `.any.js` - Runs in multiple contexts (window + worker by default)
//! - `.window.js` - Runs only in window context
//! - `.worker.js` - Runs only in dedicated worker context
//! - `.html` - Full HTML documents with embedded scripts

const std = @import("std");
const config = @import("config.zig");
const runtime = @import("runtime");
const GlobalScopeKind = runtime.GlobalScopeKind;

/// Error types for test parsing
pub const ParseError = error{
    UnsupportedTestFormat,
    InvalidMetadata,
    MalformedHtml,
    OutOfMemory,
};

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
    // ShadowRealm variants (TC39 Stage 2.7)
    /// Base ShadowRealm context
    shadowrealm,
    /// ShadowRealm created from window
    shadowrealm_in_window,
    /// ShadowRealm in dedicated worker
    shadowrealm_in_dedicatedworker,
    /// ShadowRealm in shared worker
    shadowrealm_in_sharedworker,
    /// Nested ShadowRealm
    shadowrealm_in_shadowrealm,
    /// ShadowRealm in AudioWorklet
    shadowrealm_in_audioworklet,
    /// ShadowRealm in ServiceWorker
    shadowrealm_in_serviceworker,

    /// Parse a global type from a string
    pub fn fromString(str: []const u8) ?GlobalType {
        if (std.mem.eql(u8, str, "window")) return .window;
        if (std.mem.eql(u8, str, "worker")) return .worker;
        if (std.mem.eql(u8, str, "dedicatedworker")) return .worker;
        if (std.mem.eql(u8, str, "sharedworker")) return .sharedworker;
        if (std.mem.eql(u8, str, "serviceworker")) return .serviceworker;
        // ShadowRealm variants (WPT uses hyphens, we use underscores in enum)
        if (std.mem.eql(u8, str, "shadowrealm")) return .shadowrealm;
        if (std.mem.eql(u8, str, "shadowrealm-in-window")) return .shadowrealm_in_window;
        if (std.mem.eql(u8, str, "shadowrealm-in-dedicatedworker")) return .shadowrealm_in_dedicatedworker;
        if (std.mem.eql(u8, str, "shadowrealm-in-sharedworker")) return .shadowrealm_in_sharedworker;
        if (std.mem.eql(u8, str, "shadowrealm-in-shadowrealm")) return .shadowrealm_in_shadowrealm;
        if (std.mem.eql(u8, str, "shadowrealm-in-audioworklet")) return .shadowrealm_in_audioworklet;
        if (std.mem.eql(u8, str, "shadowrealm-in-serviceworker")) return .shadowrealm_in_serviceworker;
        return null;
    }

    /// Convert to string representation
    pub fn toString(self: GlobalType) []const u8 {
        return switch (self) {
            .window => "window",
            .worker => "worker",
            .sharedworker => "sharedworker",
            .serviceworker => "serviceworker",
            .shadowrealm => "shadowrealm",
            .shadowrealm_in_window => "shadowrealm-in-window",
            .shadowrealm_in_dedicatedworker => "shadowrealm-in-dedicatedworker",
            .shadowrealm_in_sharedworker => "shadowrealm-in-sharedworker",
            .shadowrealm_in_shadowrealm => "shadowrealm-in-shadowrealm",
            .shadowrealm_in_audioworklet => "shadowrealm-in-audioworklet",
            .shadowrealm_in_serviceworker => "shadowrealm-in-serviceworker",
        };
    }

    /// Check if this context type is implemented and can execute tests
    ///
    /// Window and Worker contexts are supported. The WPT server generates proper
    /// HTML wrappers for worker tests:
    /// - `.any.js` tests get `.any.worker.html` which uses fetch_tests_from_worker
    /// - The server handles all testharness.js infrastructure
    /// - Our Worker implementation supports the required postMessage/onmessage
    ///
    /// SharedWorker/ServiceWorker require additional infrastructure not yet implemented.
    pub fn isImplemented(self: GlobalType) bool {
        return switch (self) {
            .window => true,
            // Worker context is supported - WPT server generates .any.worker.html
            // wrappers that handle fetch_tests_from_worker infrastructure
            .worker => true,
            // SharedWorker now supported with BSCOPE-11/12 infrastructure
            .sharedworker => true,
            // ServiceWorker needs additional infrastructure
            .serviceworker => true,
            // All ShadowRealm variants not implemented
            .shadowrealm,
            .shadowrealm_in_window,
            .shadowrealm_in_dedicatedworker,
            .shadowrealm_in_sharedworker,
            .shadowrealm_in_shadowrealm,
            .shadowrealm_in_audioworklet,
            .shadowrealm_in_serviceworker,
            => false,
        };
    }

    /// Check if this is any ShadowRealm variant
    pub fn isShadowRealm(self: GlobalType) bool {
        return switch (self) {
            .shadowrealm,
            .shadowrealm_in_window,
            .shadowrealm_in_dedicatedworker,
            .shadowrealm_in_sharedworker,
            .shadowrealm_in_shadowrealm,
            .shadowrealm_in_audioworklet,
            .shadowrealm_in_serviceworker,
            => true,
            else => false,
        };
    }

    /// Convert to unified GlobalScopeKind from runtime module
    ///
    /// This provides a single source of truth for scope type mapping.
    /// All ShadowRealm variants map to a single shadow_realm scope kind,
    /// as the "in-X" suffix indicates where the ShadowRealm was created,
    /// not a fundamentally different scope type.
    pub fn toGlobalScopeKind(self: GlobalType) GlobalScopeKind {
        return switch (self) {
            .window => .window,
            .worker => .dedicated_worker,
            .sharedworker => .shared_worker,
            .serviceworker => .service_worker,
            // All ShadowRealm variants map to single scope kind
            .shadowrealm,
            .shadowrealm_in_window,
            .shadowrealm_in_dedicatedworker,
            .shadowrealm_in_sharedworker,
            .shadowrealm_in_shadowrealm,
            .shadowrealm_in_audioworklet,
            .shadowrealm_in_serviceworker,
            => .shadow_realm,
        };
    }
};

/// Script reference in a test file
pub const ScriptRef = struct {
    /// Script path (absolute or relative) or inline content
    path: []const u8,
    /// Whether this is an inline script (path field contains the script content)
    inline_script: bool = false,
    /// Script type attribute (e.g., "module", "text/javascript")
    script_type: ?[]const u8 = null,

    pub fn deinit(self: *ScriptRef, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        if (self.script_type) |t| allocator.free(t);
    }

    /// Check if this is a module script
    pub fn isModule(self: ScriptRef) bool {
        if (self.script_type) |t| {
            return std.mem.eql(u8, t, "module");
        }
        return false;
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
    /// Spec reference links (from link rel="help")
    spec_links: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) TestMetadata {
        return TestMetadata{
            .allocator = allocator,
            .variants = .empty,
            .scripts = .empty,
            .globals = .empty,
            .spec_links = .empty,
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

    /// Add a script dependency with type
    pub fn addScriptWithType(self: *TestMetadata, path: []const u8, script_type: ?[]const u8) !void {
        try self.scripts.append(self.allocator, ScriptRef{
            .path = try self.allocator.dupe(u8, path),
            .script_type = if (script_type) |t| try self.allocator.dupe(u8, t) else null,
        });
    }

    /// Add an inline script
    pub fn addInlineScript(self: *TestMetadata, content: []const u8) !void {
        try self.scripts.append(self.allocator, ScriptRef{
            .path = try self.allocator.dupe(u8, content),
            .inline_script = true,
        });
    }

    /// Add an inline script with type
    pub fn addInlineScriptWithType(self: *TestMetadata, content: []const u8, script_type: ?[]const u8) !void {
        try self.scripts.append(self.allocator, ScriptRef{
            .path = try self.allocator.dupe(u8, content),
            .inline_script = true,
            .script_type = if (script_type) |t| try self.allocator.dupe(u8, t) else null,
        });
    }

    /// Add a variant
    pub fn addVariant(self: *TestMetadata, variant: []const u8) !void {
        try self.variants.append(self.allocator, try self.allocator.dupe(u8, variant));
    }

    /// Add a global context
    pub fn addGlobal(self: *TestMetadata, global: GlobalType) !void {
        // Check if already exists to avoid duplicates
        for (self.globals.items) |g| {
            if (g == global) return;
        }
        try self.globals.append(self.allocator, global);
    }

    /// Add a spec reference link
    pub fn addSpecLink(self: *TestMetadata, link: []const u8) !void {
        try self.spec_links.append(self.allocator, try self.allocator.dupe(u8, link));
    }

    /// Check if this test has any variants
    pub fn hasVariants(self: TestMetadata) bool {
        return self.variants.items.len > 0;
    }

    /// Get the effective test count (considering variants)
    pub fn getEffectiveTestCount(self: TestMetadata) usize {
        const variant_count = if (self.variants.items.len > 0) self.variants.items.len else 1;
        return variant_count * @max(1, self.globals.items.len);
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
/// Note: This does NOT add default globals - callers should set defaults based on file type
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
                if (metadata.title) |t| allocator.free(t);
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
                // Parse comma-separated globals (e.g., "window,worker,sharedworker")
                var globals = std.mem.splitScalar(u8, value, ',');
                while (globals.next()) |g| {
                    const gtrim = std.mem.trim(u8, g, &std.ascii.whitespace);
                    if (GlobalType.fromString(gtrim)) |global| {
                        try metadata.addGlobal(global);
                    }
                }
            }
            // Other META keys (like "quic") are ignored for now
        }
    }

    return metadata;
}

/// Parse a .any.js test file
/// .any.js files run in multiple contexts by default (window + worker)
/// unless explicitly specified via // META: global=...
pub fn parseAnyJs(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ParsedTest {
    var metadata = try parseMetaComments(allocator, content);
    errdefer metadata.deinit();

    // Default globals for .any.js: window + worker
    if (metadata.globals.items.len == 0) {
        try metadata.addGlobal(.window);
        try metadata.addGlobal(.worker);
    }

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
/// Extracts metadata from meta tags, title, script tags, and link tags.
/// Note: This is a simplified regex-free parser. For full HTML parsing,
/// use the HTML parser from src/html/.
pub fn parseHtml(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ParsedTest {
    var metadata = TestMetadata.init(allocator);
    errdefer metadata.deinit();

    // Window context only for HTML files
    try metadata.addGlobal(.window);

    // Extract <title> tag content
    if (findTagContent(content, "title")) |title_content| {
        metadata.title = try allocator.dupe(u8, title_content);
    }

    // Extract meta tags
    try parseHtmlMetaTags(allocator, content, &metadata);

    // Extract link tags (for spec references)
    try parseHtmlLinkTags(allocator, content, &metadata);

    // Extract script tags (both external and inline)
    try parseHtmlScriptTags(allocator, content, &metadata);

    return ParsedTest{
        .allocator = allocator,
        .path = try allocator.dupe(u8, path),
        .file_type = .html,
        .metadata = metadata,
        .content = try allocator.dupe(u8, content),
    };
}

/// Find the content between opening and closing tags
fn findTagContent(content: []const u8, tag_name: []const u8) ?[]const u8 {
    // Build opening tag pattern
    var open_tag_buf: [64]u8 = undefined;
    const open_tag = std.fmt.bufPrint(&open_tag_buf, "<{s}", .{tag_name}) catch return null;

    var close_tag_buf: [64]u8 = undefined;
    const close_tag = std.fmt.bufPrint(&close_tag_buf, "</{s}>", .{tag_name}) catch return null;

    const tag_start = std.mem.indexOf(u8, content, open_tag) orelse return null;
    const content_start = std.mem.indexOfPos(u8, content, tag_start, ">") orelse return null;
    const content_end = std.mem.indexOfPos(u8, content, content_start, close_tag) orelse return null;

    return std.mem.trim(u8, content[content_start + 1 .. content_end], &std.ascii.whitespace);
}

/// Parse meta tags from HTML content
fn parseHtmlMetaTags(allocator: std.mem.Allocator, content: []const u8, metadata: *TestMetadata) !void {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, content, pos, "<meta")) |meta_start| {
        const tag_end = std.mem.indexOfPos(u8, content, meta_start, ">") orelse break;
        const tag = content[meta_start .. tag_end + 1];

        // Extract name and content attributes
        const name = extractAttribute(tag, "name");
        const attr_content = extractAttribute(tag, "content");

        if (name != null and attr_content != null) {
            const name_val = name.?;
            const content_val = attr_content.?;

            if (std.mem.eql(u8, name_val, "timeout")) {
                if (std.mem.eql(u8, content_val, "long")) {
                    metadata.timeout = .long;
                }
            } else if (std.mem.eql(u8, name_val, "variant")) {
                try metadata.addVariant(content_val);
            } else if (std.mem.eql(u8, name_val, "title")) {
                if (metadata.title == null) {
                    metadata.title = try allocator.dupe(u8, content_val);
                }
            }
        }

        pos = tag_end + 1;
    }
}

/// Parse link tags from HTML content (for spec references)
fn parseHtmlLinkTags(_: std.mem.Allocator, content: []const u8, metadata: *TestMetadata) !void {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, content, pos, "<link")) |link_start| {
        const tag_end = std.mem.indexOfPos(u8, content, link_start, ">") orelse break;
        const tag = content[link_start .. tag_end + 1];

        const rel = extractAttribute(tag, "rel");
        const href = extractAttribute(tag, "href");

        if (rel != null and href != null) {
            if (std.mem.eql(u8, rel.?, "help")) {
                try metadata.addSpecLink(href.?);
            }
        }

        pos = tag_end + 1;
    }
}

/// Check if HTML content is a reftest (visual comparison test)
/// Reftests have <link rel="match"> or <link rel="mismatch"> elements
/// and don't use testharness.js
pub fn isReftest(content: []const u8) bool {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, content, pos, "<link")) |link_start| {
        const tag_end = std.mem.indexOfPos(u8, content, link_start, ">") orelse break;
        const tag = content[link_start .. tag_end + 1];

        const rel = extractAttribute(tag, "rel");
        if (rel) |r| {
            // Check for rel="match" or rel="mismatch" (case-insensitive comparison)
            if (std.ascii.eqlIgnoreCase(r, "match") or std.ascii.eqlIgnoreCase(r, "mismatch")) {
                return true;
            }
        }

        pos = tag_end + 1;
    }
    return false;
}

/// Check if a file path is a reftest reference file
/// Reference files are named *-ref.html or *-notref.html and are not actual tests
pub fn isReftestReference(path: []const u8) bool {
    return std.mem.endsWith(u8, path, "-ref.html") or
        std.mem.endsWith(u8, path, "-notref.html") or
        std.mem.endsWith(u8, path, "-ref.htm") or
        std.mem.endsWith(u8, path, "-notref.htm");
}

/// Check if HTML content uses testharness.js
/// This is used to differentiate between testharness.js tests and other test types
pub fn htmlUsesTestHarness(content: []const u8) bool {
    // Search for <script tags with src="/resources/testharness.js"
    // Handle both single and double quotes
    return std.mem.indexOf(u8, content, "/resources/testharness.js") != null;
}

/// Parse script tags from HTML content (both external and inline)
fn parseHtmlScriptTags(_: std.mem.Allocator, content: []const u8, metadata: *TestMetadata) !void {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, content, pos, "<script")) |script_start| {
        const tag_end = std.mem.indexOfPos(u8, content, script_start, ">") orelse break;
        const tag = content[script_start .. tag_end + 1];

        // Get script type attribute
        const script_type = extractAttribute(tag, "type");

        // Check for external script (src attribute)
        if (extractAttribute(tag, "src")) |src| {
            try metadata.addScriptWithType(src, script_type);
        } else {
            // Look for inline script content
            const close_tag = "</script>";
            if (std.mem.indexOfPos(u8, content, tag_end + 1, close_tag)) |close_start| {
                const script_content = content[tag_end + 1 .. close_start];
                const trimmed = std.mem.trim(u8, script_content, &std.ascii.whitespace);
                if (trimmed.len > 0) {
                    try metadata.addInlineScriptWithType(trimmed, script_type);
                }
                pos = close_start + close_tag.len;
                continue;
            }
        }

        pos = tag_end + 1;
    }
}

/// Extract an attribute value from an HTML tag
/// Handles double quotes, single quotes, and unquoted values
fn extractAttribute(tag: []const u8, attr_name: []const u8) ?[]const u8 {
    // Try with double quotes: attr="value"
    var buf: [128]u8 = undefined;
    const pattern_dq = std.fmt.bufPrint(&buf, "{s}=\"", .{attr_name}) catch return null;

    if (std.mem.indexOf(u8, tag, pattern_dq)) |start| {
        const value_start = start + pattern_dq.len;
        if (std.mem.indexOfPos(u8, tag, value_start, "\"")) |value_end| {
            return tag[value_start..value_end];
        }
    }

    // Try with single quotes: attr='value'
    const pattern_sq = std.fmt.bufPrint(&buf, "{s}='", .{attr_name}) catch return null;

    if (std.mem.indexOf(u8, tag, pattern_sq)) |start| {
        const value_start = start + pattern_sq.len;
        if (std.mem.indexOfPos(u8, tag, value_start, "'")) |value_end| {
            return tag[value_start..value_end];
        }
    }

    // Try unquoted: attr=value (value ends at space or >)
    const pattern_uq = std.fmt.bufPrint(&buf, "{s}=", .{attr_name}) catch return null;

    if (std.mem.indexOf(u8, tag, pattern_uq)) |start| {
        const value_start = start + pattern_uq.len;
        // Make sure next char is not a quote (would have been caught above)
        if (value_start < tag.len and tag[value_start] != '"' and tag[value_start] != '\'') {
            // Find end of value: space, >, or end of string
            var value_end = value_start;
            while (value_end < tag.len) : (value_end += 1) {
                const c = tag[value_end];
                if (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '>') {
                    break;
                }
            }
            if (value_end > value_start) {
                return tag[value_start..value_end];
            }
        }
    }

    return null;
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

/// Loaded script content
pub const LoadedScript = struct {
    /// Resolved path to the script
    path: []const u8,
    /// Script content (loaded from file or inline)
    content: []const u8,
    /// Whether this is an inline script
    inline_script: bool,
    /// Script type (e.g., "module")
    script_type: ?[]const u8,

    pub fn deinit(self: *LoadedScript, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.content);
        if (self.script_type) |t| allocator.free(t);
    }
};

/// Script loader for resolving and loading test script dependencies
pub const ScriptLoader = struct {
    allocator: std.mem.Allocator,
    /// Path to WPT root directory
    wpt_root: []const u8,
    /// Cache of loaded scripts (path -> content)
    cache: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, wpt_root: []const u8) ScriptLoader {
        return ScriptLoader{
            .allocator = allocator,
            .wpt_root = wpt_root,
            .cache = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *ScriptLoader) void {
        // Free cached content
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    /// Resolve a script path relative to a test file
    pub fn resolve(self: *ScriptLoader, test_path: []const u8, script_ref: ScriptRef) ![]const u8 {
        if (script_ref.inline_script) {
            // Inline scripts don't need path resolution
            return self.allocator.dupe(u8, script_ref.path);
        }
        return resolveScriptPath(self.allocator, self.wpt_root, test_path, script_ref.path);
    }

    /// Load a script from file (with caching)
    pub fn load(self: *ScriptLoader, resolved_path: []const u8) ![]const u8 {
        // Check cache first
        if (self.cache.get(resolved_path)) |cached| {
            return cached;
        }

        // Load from file
        const file = std.fs.cwd().openFile(resolved_path, .{}) catch |err| {
            return err;
        };
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 10 * 1024 * 1024) catch |err| {
            return err;
        };

        // Cache the content
        const key = try self.allocator.dupe(u8, resolved_path);
        try self.cache.put(key, content);

        return content;
    }

    /// Load all scripts for a parsed test
    pub fn loadAll(self: *ScriptLoader, parsed_test: *const ParsedTest) !std.ArrayList(LoadedScript) {
        var scripts = std.ArrayList(LoadedScript).init(self.allocator);
        errdefer {
            for (scripts.items) |*s| s.deinit(self.allocator);
            scripts.deinit();
        }

        for (parsed_test.metadata.scripts.items) |script_ref| {
            if (script_ref.inline_script) {
                // Inline script - content is already available
                try scripts.append(LoadedScript{
                    .path = try self.allocator.dupe(u8, "inline"),
                    .content = try self.allocator.dupe(u8, script_ref.path),
                    .inline_script = true,
                    .script_type = if (script_ref.script_type) |t| try self.allocator.dupe(u8, t) else null,
                });
            } else {
                // External script - resolve and load
                const resolved = try self.resolve(parsed_test.path, script_ref);
                defer self.allocator.free(resolved);

                const content = try self.load(resolved);
                try scripts.append(LoadedScript{
                    .path = try self.allocator.dupe(u8, resolved),
                    .content = try self.allocator.dupe(u8, content),
                    .inline_script = false,
                    .script_type = if (script_ref.script_type) |t| try self.allocator.dupe(u8, t) else null,
                });
            }
        }

        return scripts;
    }

    /// Clear the script cache
    pub fn clearCache(self: *ScriptLoader) void {
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.clearRetainingCapacity();
    }
};

/// Extract test metadata from content based on file type
/// This is a convenience function that combines parsing and metadata extraction
pub fn extractMetadata(allocator: std.mem.Allocator, file_type: config.FileType, content: []const u8) !TestMetadata {
    return switch (file_type) {
        .any_js, .window_js, .worker_js => try parseMetaComments(allocator, content),
        .html => blk: {
            var metadata = TestMetadata.init(allocator);
            errdefer metadata.deinit();

            // Extract title
            if (findTagContent(content, "title")) |title_content| {
                metadata.title = try allocator.dupe(u8, title_content);
            }

            // Extract meta tags
            try parseHtmlMetaTags(allocator, content, &metadata);

            break :blk metadata;
        },
        .unknown => ParseError.UnsupportedTestFormat,
    };
}

// =============================================================================
// Tests
// =============================================================================

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

test "parseAnyJs default globals - no META at all" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Test with absolutely no META comments - should default to window+worker
    const content = "test(() => {});";

    var parsed = try parseAnyJs(allocator, "test.any.js", content);
    defer parsed.deinit();

    try testing.expectEqual(@as(usize, 2), parsed.metadata.globals.items.len);
    try testing.expectEqual(GlobalType.window, parsed.metadata.globals.items[0]);
    try testing.expectEqual(GlobalType.worker, parsed.metadata.globals.items[1]);
}

test "parseAnyJs with default globals" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\// META: title=Test
        \\// META: script=/common/utils.js
        \\test(() => {});
    ;

    var parsed = try parseAnyJs(allocator, "url/test.any.js", content);
    defer parsed.deinit();

    try testing.expectEqualStrings("Test", parsed.metadata.title.?);
    try testing.expectEqual(config.FileType.any_js, parsed.file_type);
    try testing.expectEqual(@as(usize, 2), parsed.metadata.globals.items.len);
    try testing.expectEqual(GlobalType.window, parsed.metadata.globals.items[0]);
    try testing.expectEqual(GlobalType.worker, parsed.metadata.globals.items[1]);
}

test "parseAnyJs explicit globals override default" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Explicit window-only should NOT add default worker
    const content =
        \\// META: global=window
        \\test(() => {});
    ;

    var parsed = try parseAnyJs(allocator, "test.any.js", content);
    defer parsed.deinit();

    try testing.expectEqual(@as(usize, 1), parsed.metadata.globals.items.len);
    try testing.expectEqual(GlobalType.window, parsed.metadata.globals.items[0]);
}

test "parseAnyJs with explicit globals" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\// META: global=window,serviceworker
        \\test(() => {});
    ;

    var parsed = try parseAnyJs(allocator, "sw/test.any.js", content);
    defer parsed.deinit();

    try testing.expectEqual(@as(usize, 2), parsed.metadata.globals.items.len);
    try testing.expectEqual(GlobalType.window, parsed.metadata.globals.items[0]);
    try testing.expectEqual(GlobalType.serviceworker, parsed.metadata.globals.items[1]);
}

test "parseWindowJs forces window context" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\// META: global=worker
        \\test(() => {});
    ;

    var parsed = try parseWindowJs(allocator, "dom/test.window.js", content);
    defer parsed.deinit();

    try testing.expectEqual(config.FileType.window_js, parsed.file_type);
    try testing.expectEqual(@as(usize, 1), parsed.metadata.globals.items.len);
    try testing.expectEqual(GlobalType.window, parsed.metadata.globals.items[0]);
}

test "parseWorkerJs forces worker context" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\// META: title=Worker test
        \\// META: script=./helper.js
        \\importScripts("/resources/testharness.js");
    ;

    var parsed = try parseWorkerJs(allocator, "workers/test.worker.js", content);
    defer parsed.deinit();

    try testing.expectEqual(config.FileType.worker_js, parsed.file_type);
    try testing.expectEqual(@as(usize, 1), parsed.metadata.globals.items.len);
    try testing.expectEqual(GlobalType.worker, parsed.metadata.globals.items[0]);
    try testing.expectEqual(@as(usize, 1), parsed.metadata.scripts.items.len);
}

test "parseHtml extracts metadata" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\<title>URL Test</title>
        \\<meta name="timeout" content="long">
        \\<meta name="variant" content="?test=1">
        \\<meta name="variant" content="?test=2">
        \\<link rel="help" href="https://url.spec.whatwg.org/">
        \\<script src="/resources/testharness.js"></script>
        \\<script src="/resources/testharnessreport.js"></script>
        \\</head>
        \\<body>
        \\<script>
        \\test(() => { assert_true(true); });
        \\</script>
        \\</body>
        \\</html>
    ;

    var parsed = try parseHtml(allocator, "url/test.html", content);
    defer parsed.deinit();

    try testing.expectEqual(config.FileType.html, parsed.file_type);
    try testing.expectEqualStrings("URL Test", parsed.metadata.title.?);
    try testing.expectEqual(config.Timeout.long, parsed.metadata.timeout);
    try testing.expectEqual(@as(usize, 2), parsed.metadata.variants.items.len);
    try testing.expectEqualStrings("?test=1", parsed.metadata.variants.items[0]);
    try testing.expectEqual(@as(usize, 1), parsed.metadata.spec_links.items.len);
    // External scripts + inline script
    try testing.expectEqual(@as(usize, 3), parsed.metadata.scripts.items.len);
    try testing.expect(!parsed.metadata.scripts.items[0].inline_script);
    try testing.expect(!parsed.metadata.scripts.items[1].inline_script);
    try testing.expect(parsed.metadata.scripts.items[2].inline_script);
}

test "parseHtml with single quotes" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\<script src='/resources/testharness.js'></script>
    ;

    var parsed = try parseHtml(allocator, "test.html", content);
    defer parsed.deinit();

    try testing.expectEqual(@as(usize, 1), parsed.metadata.scripts.items.len);
    try testing.expectEqualStrings("/resources/testharness.js", parsed.metadata.scripts.items[0].path);
}

test "parseMetaComments with multiple scripts" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\// META: script=/resources/testharness.js
        \\// META: script=/resources/testharnessreport.js
        \\// META: script=/common/subset-tests-by-key.js
        \\// META: script=./resources/helper.js
        \\test(() => {});
    ;

    var metadata = try parseMetaComments(allocator, content);
    defer metadata.deinit();

    try testing.expectEqual(@as(usize, 4), metadata.scripts.items.len);
    try testing.expectEqualStrings("/resources/testharness.js", metadata.scripts.items[0].path);
    try testing.expectEqualStrings("/resources/testharnessreport.js", metadata.scripts.items[1].path);
    try testing.expectEqualStrings("/common/subset-tests-by-key.js", metadata.scripts.items[2].path);
    try testing.expectEqualStrings("./resources/helper.js", metadata.scripts.items[3].path);
}

test "parseMetaComments with multiple variants" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\// META: variant=?include=file
        \\// META: variant=?include=javascript
        \\// META: variant=?include=mailto
        \\// META: variant=?exclude=(file|javascript|mailto)
        \\test(() => {});
    ;

    var metadata = try parseMetaComments(allocator, content);
    defer metadata.deinit();

    try testing.expectEqual(@as(usize, 4), metadata.variants.items.len);
    try testing.expectEqualStrings("?include=file", metadata.variants.items[0]);
    try testing.expectEqualStrings("?include=javascript", metadata.variants.items[1]);
    try testing.expectEqualStrings("?include=mailto", metadata.variants.items[2]);
    try testing.expectEqualStrings("?exclude=(file|javascript|mailto)", metadata.variants.items[3]);
}

test "parseTestFile dispatches correctly" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const js_content = "test(() => {});";

    // Test .any.js
    {
        var parsed = try parseTestFile(allocator, "test.any.js", js_content);
        defer parsed.deinit();
        try testing.expectEqual(config.FileType.any_js, parsed.file_type);
    }

    // Test .window.js
    {
        var parsed = try parseTestFile(allocator, "test.window.js", js_content);
        defer parsed.deinit();
        try testing.expectEqual(config.FileType.window_js, parsed.file_type);
    }

    // Test .worker.js
    {
        var parsed = try parseTestFile(allocator, "test.worker.js", js_content);
        defer parsed.deinit();
        try testing.expectEqual(config.FileType.worker_js, parsed.file_type);
    }

    // Test .html
    {
        const html_content = "<html></html>";
        var parsed = try parseTestFile(allocator, "test.html", html_content);
        defer parsed.deinit();
        try testing.expectEqual(config.FileType.html, parsed.file_type);
    }
}

test "GlobalType.fromString" {
    try std.testing.expectEqual(GlobalType.window, GlobalType.fromString("window").?);
    try std.testing.expectEqual(GlobalType.worker, GlobalType.fromString("worker").?);
    try std.testing.expectEqual(GlobalType.worker, GlobalType.fromString("dedicatedworker").?);
    try std.testing.expectEqual(GlobalType.sharedworker, GlobalType.fromString("sharedworker").?);
    try std.testing.expectEqual(GlobalType.serviceworker, GlobalType.fromString("serviceworker").?);
    try std.testing.expectEqual(@as(?GlobalType, null), GlobalType.fromString("invalid"));
}

test "GlobalType.toString" {
    try std.testing.expectEqualStrings("window", GlobalType.window.toString());
    try std.testing.expectEqualStrings("worker", GlobalType.worker.toString());
    try std.testing.expectEqualStrings("sharedworker", GlobalType.sharedworker.toString());
    try std.testing.expectEqualStrings("serviceworker", GlobalType.serviceworker.toString());
}

test "TestMetadata.getEffectiveTestCount" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var metadata = TestMetadata.init(allocator);
    defer metadata.deinit();

    // No variants, no globals = 1 test
    try testing.expectEqual(@as(usize, 1), metadata.getEffectiveTestCount());

    // Add variants
    try metadata.addVariant("?a");
    try metadata.addVariant("?b");
    try testing.expectEqual(@as(usize, 2), metadata.getEffectiveTestCount());

    // Add globals
    try metadata.addGlobal(.window);
    try metadata.addGlobal(.worker);
    try testing.expectEqual(@as(usize, 4), metadata.getEffectiveTestCount()); // 2 variants * 2 globals
}

test "extractAttribute" {
    // Double quotes
    try std.testing.expectEqualStrings("value", extractAttribute("name=\"value\"", "name").?);
    try std.testing.expectEqualStrings("/path/to/script.js", extractAttribute("<script src=\"/path/to/script.js\">", "src").?);

    // Single quotes
    try std.testing.expectEqualStrings("value", extractAttribute("name='value'", "name").?);

    // Unquoted values (HTML5 allows this for simple values without spaces)
    try std.testing.expectEqualStrings("match", extractAttribute("<link rel=match href=ref.html>", "rel").?);
    try std.testing.expectEqualStrings("ref.html", extractAttribute("<link rel=match href=ref.html>", "href").?);
    try std.testing.expectEqualStrings("mismatch", extractAttribute("<link rel=mismatch>", "rel").?);

    // Not found
    try std.testing.expectEqual(@as(?[]const u8, null), extractAttribute("<script>", "src"));
}

test "GlobalType.fromString - shadowrealm variants" {
    // Base shadowrealm
    try std.testing.expectEqual(GlobalType.shadowrealm, GlobalType.fromString("shadowrealm").?);

    // Nested variants (WPT uses hyphens)
    try std.testing.expectEqual(GlobalType.shadowrealm_in_window, GlobalType.fromString("shadowrealm-in-window").?);
    try std.testing.expectEqual(GlobalType.shadowrealm_in_dedicatedworker, GlobalType.fromString("shadowrealm-in-dedicatedworker").?);
    try std.testing.expectEqual(GlobalType.shadowrealm_in_sharedworker, GlobalType.fromString("shadowrealm-in-sharedworker").?);
    try std.testing.expectEqual(GlobalType.shadowrealm_in_shadowrealm, GlobalType.fromString("shadowrealm-in-shadowrealm").?);
    try std.testing.expectEqual(GlobalType.shadowrealm_in_audioworklet, GlobalType.fromString("shadowrealm-in-audioworklet").?);
    try std.testing.expectEqual(GlobalType.shadowrealm_in_serviceworker, GlobalType.fromString("shadowrealm-in-serviceworker").?);

    // Invalid variants should return null
    try std.testing.expectEqual(@as(?GlobalType, null), GlobalType.fromString("shadowrealm-invalid"));
    try std.testing.expectEqual(@as(?GlobalType, null), GlobalType.fromString("shadowrealm-in-"));
}

test "GlobalType.toString - shadowrealm variants" {
    try std.testing.expectEqualStrings("shadowrealm", GlobalType.shadowrealm.toString());
    try std.testing.expectEqualStrings("shadowrealm-in-window", GlobalType.shadowrealm_in_window.toString());
    try std.testing.expectEqualStrings("shadowrealm-in-dedicatedworker", GlobalType.shadowrealm_in_dedicatedworker.toString());
    try std.testing.expectEqualStrings("shadowrealm-in-sharedworker", GlobalType.shadowrealm_in_sharedworker.toString());
    try std.testing.expectEqualStrings("shadowrealm-in-shadowrealm", GlobalType.shadowrealm_in_shadowrealm.toString());
    try std.testing.expectEqualStrings("shadowrealm-in-audioworklet", GlobalType.shadowrealm_in_audioworklet.toString());
    try std.testing.expectEqualStrings("shadowrealm-in-serviceworker", GlobalType.shadowrealm_in_serviceworker.toString());
}

test "GlobalType.isImplemented - shadowrealm returns false" {
    // Implemented contexts: window and worker
    try std.testing.expect(GlobalType.window.isImplemented());
    // Worker IS implemented - WPT server handles fetch_tests_from_worker via generated HTML
    try std.testing.expect(GlobalType.worker.isImplemented());

    // SharedWorker IS implemented (BSCOPE-11/12)
    try std.testing.expect(GlobalType.sharedworker.isImplemented());

    // Not implemented contexts
    try std.testing.expect(!GlobalType.serviceworker.isImplemented());

    // All ShadowRealm variants return false
    try std.testing.expect(!GlobalType.shadowrealm.isImplemented());
    try std.testing.expect(!GlobalType.shadowrealm_in_window.isImplemented());
    try std.testing.expect(!GlobalType.shadowrealm_in_dedicatedworker.isImplemented());
    try std.testing.expect(!GlobalType.shadowrealm_in_sharedworker.isImplemented());
    try std.testing.expect(!GlobalType.shadowrealm_in_shadowrealm.isImplemented());
    try std.testing.expect(!GlobalType.shadowrealm_in_audioworklet.isImplemented());
    try std.testing.expect(!GlobalType.shadowrealm_in_serviceworker.isImplemented());
}

test "GlobalType.isShadowRealm" {
    // Non-ShadowRealm contexts
    try std.testing.expect(!GlobalType.window.isShadowRealm());
    try std.testing.expect(!GlobalType.worker.isShadowRealm());
    try std.testing.expect(!GlobalType.sharedworker.isShadowRealm());
    try std.testing.expect(!GlobalType.serviceworker.isShadowRealm());

    // All ShadowRealm variants return true
    try std.testing.expect(GlobalType.shadowrealm.isShadowRealm());
    try std.testing.expect(GlobalType.shadowrealm_in_window.isShadowRealm());
    try std.testing.expect(GlobalType.shadowrealm_in_dedicatedworker.isShadowRealm());
    try std.testing.expect(GlobalType.shadowrealm_in_sharedworker.isShadowRealm());
    try std.testing.expect(GlobalType.shadowrealm_in_shadowrealm.isShadowRealm());
    try std.testing.expect(GlobalType.shadowrealm_in_audioworklet.isShadowRealm());
    try std.testing.expect(GlobalType.shadowrealm_in_serviceworker.isShadowRealm());
}

test "parseMetaComments - shadowrealm global" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const content =
        \\// META: global=window,shadowrealm,shadowrealm-in-window
        \\test(() => {});
    ;

    var metadata = try parseMetaComments(allocator, content);
    defer metadata.deinit();

    try testing.expectEqual(@as(usize, 3), metadata.globals.items.len);
    try testing.expectEqual(GlobalType.window, metadata.globals.items[0]);
    try testing.expectEqual(GlobalType.shadowrealm, metadata.globals.items[1]);
    try testing.expectEqual(GlobalType.shadowrealm_in_window, metadata.globals.items[2]);
}

// =============================================================================
// Multi-Context Execution Tests
// =============================================================================

test "multi-context: parseTestFile extracts multiple globals" {
    const allocator = std.testing.allocator;

    const content =
        \\// META: global=window,worker
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 2), parsed.metadata.globals.items.len);
    try std.testing.expectEqual(GlobalType.window, parsed.metadata.globals.items[0]);
    try std.testing.expectEqual(GlobalType.worker, parsed.metadata.globals.items[1]);
}

test "multi-context: test runs in each specified context" {
    const allocator = std.testing.allocator;

    const content =
        \\// META: global=window,worker
        \\test(function() {
        \\  if (self.GLOBAL.isWindow()) {
        \\    assert_true(true, "window context");
        \\  } else if (self.GLOBAL.isWorker()) {
        \\    assert_true(true, "worker context");
        \\  }
        \\});
    ;

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    // Count how many contexts would execute
    var executed_contexts: usize = 0;
    for (parsed.metadata.globals.items) |ctx| {
        if (ctx.isImplemented()) {
            executed_contexts += 1;
        }
    }

    // Both window and worker are implemented
    try std.testing.expectEqual(@as(usize, 2), executed_contexts);
}

test "multi-context: unimplemented contexts are skipped" {
    const allocator = std.testing.allocator;

    const content =
        \\// META: global=window,sharedworker,serviceworker
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    // Should have 3 globals parsed
    try std.testing.expectEqual(@as(usize, 3), parsed.metadata.globals.items.len);

    // 2 implemented (window, sharedworker)
    var implemented: usize = 0;
    for (parsed.metadata.globals.items) |ctx| {
        if (ctx.isImplemented()) {
            implemented += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 2), implemented);
}

test "multi-context: .any.js defaults to window+worker" {
    const allocator = std.testing.allocator;

    // No META: global specified
    const content = "test(() => { assert_true(true); });";

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    // Should default to window + worker
    try std.testing.expectEqual(@as(usize, 2), parsed.metadata.globals.items.len);
    try std.testing.expectEqual(GlobalType.window, parsed.metadata.globals.items[0]);
    try std.testing.expectEqual(GlobalType.worker, parsed.metadata.globals.items[1]);
}

test "multi-context: .window.js forces single window context" {
    const allocator = std.testing.allocator;

    // Even if META: global is specified, .window.js should force window only
    const content =
        \\// META: global=window,worker,sharedworker
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.window.js", content);
    defer parsed.deinit();

    // .window.js should force window context only
    try std.testing.expectEqual(@as(usize, 1), parsed.metadata.globals.items.len);
    try std.testing.expectEqual(GlobalType.window, parsed.metadata.globals.items[0]);
}

test "multi-context: .worker.js forces single worker context" {
    const allocator = std.testing.allocator;

    // Even if META: global is specified, .worker.js should force worker only
    const content =
        \\// META: global=window,worker
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.worker.js", content);
    defer parsed.deinit();

    // .worker.js should force worker context only
    try std.testing.expectEqual(@as(usize, 1), parsed.metadata.globals.items.len);
    try std.testing.expectEqual(GlobalType.worker, parsed.metadata.globals.items[0]);
}

test "multi-context: counting implemented vs unimplemented contexts" {
    const allocator = std.testing.allocator;

    // Test with many context types including unimplemented ones
    const content =
        \\// META: global=window,worker,sharedworker,serviceworker,shadowrealm
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    // Should have 5 globals parsed
    try std.testing.expectEqual(@as(usize, 5), parsed.metadata.globals.items.len);

    // Count implemented contexts
    var implemented: usize = 0;
    var unimplemented: usize = 0;
    for (parsed.metadata.globals.items) |ctx| {
        if (ctx.isImplemented()) {
            implemented += 1;
        } else {
            unimplemented += 1;
        }
    }

    // Window, worker, and sharedworker are implemented
    try std.testing.expectEqual(@as(usize, 3), implemented);
    // ServiceWorker, ShadowRealm are not implemented
    try std.testing.expectEqual(@as(usize, 2), unimplemented);
}

test "multi-context: effective test count with variants and globals" {
    const allocator = std.testing.allocator;

    const content =
        \\// META: global=window,worker
        \\// META: variant=?test=1
        \\// META: variant=?test=2
        \\// META: variant=?test=3
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    // 2 contexts * 3 variants = 6 effective tests
    try std.testing.expectEqual(@as(usize, 6), parsed.metadata.getEffectiveTestCount());
}

// =============================================================================
// Reftest Detection Tests
// =============================================================================

test "isReftest - detects link rel=match" {
    const content =
        \\<!doctype html>
        \\<title>Test</title>
        \\<link rel="match" href="ref.html">
        \\<p>Test content</p>
    ;
    try std.testing.expect(isReftest(content));
}

test "isReftest - detects link rel=mismatch" {
    const content =
        \\<!doctype html>
        \\<title>Ahem checker</title>
        \\<link rel="mismatch" href="ahem-notref.html">
        \\<style>table { font: 15px/1 Ahem; }</style>
    ;
    try std.testing.expect(isReftest(content));
}

test "isReftest - case insensitive" {
    // Test with uppercase MATCH
    const content_upper =
        \\<!doctype html>
        \\<link rel="MATCH" href="ref.html">
    ;
    try std.testing.expect(isReftest(content_upper));

    // Test with mixed case
    const content_mixed =
        \\<!doctype html>
        \\<link rel="Match" href="ref.html">
    ;
    try std.testing.expect(isReftest(content_mixed));
}

test "isReftest - false for testharness tests" {
    const content =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\<title>URL Test</title>
        \\<link rel="help" href="https://url.spec.whatwg.org/">
        \\<script src="/resources/testharness.js"></script>
        \\<script src="/resources/testharnessreport.js"></script>
        \\</head>
        \\<body>
        \\<script>
        \\test(() => { assert_true(true); });
        \\</script>
        \\</body>
        \\</html>
    ;
    try std.testing.expect(!isReftest(content));
}

test "isReftest - false for empty content" {
    try std.testing.expect(!isReftest(""));
}

test "isReftest - false for non-HTML content" {
    try std.testing.expect(!isReftest("test(() => { assert_true(true); });"));
}

test "isReftest - unquoted attributes" {
    // WPT's blank.html uses unquoted rel=match
    const content =
        \\<title>Blank Document</title>
        \\<link rel=match href="about:blank">
    ;
    try std.testing.expect(isReftest(content));
}

test "isReftestReference - detects reference files" {
    try std.testing.expect(isReftestReference("ahem-ref.html"));
    try std.testing.expect(isReftestReference("ahem-notref.html"));
    try std.testing.expect(isReftestReference("path/to/test-ref.html"));
    try std.testing.expect(isReftestReference("path/to/test-notref.htm"));

    // Non-reference files
    try std.testing.expect(!isReftestReference("test.html"));
    try std.testing.expect(!isReftestReference("reftest.html"));
    try std.testing.expect(!isReftestReference("test-reference.html"));
}

test "htmlUsesTestHarness - detects testharness.js" {
    const content =
        \\<!DOCTYPE html>
        \\<script src="/resources/testharness.js"></script>
        \\<script src="/resources/testharnessreport.js"></script>
    ;
    try std.testing.expect(htmlUsesTestHarness(content));
}

test "htmlUsesTestHarness - detects testharness.js with single quotes" {
    const content =
        \\<!DOCTYPE html>
        \\<script src='/resources/testharness.js'></script>
    ;
    try std.testing.expect(htmlUsesTestHarness(content));
}

test "htmlUsesTestHarness - false for harnessless content" {
    const content =
        \\<!DOCTYPE html>
        \\<p>Just some HTML</p>
    ;
    try std.testing.expect(!htmlUsesTestHarness(content));
}
