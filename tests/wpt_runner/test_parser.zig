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
const host = @import("host");
const xml = @import("xml");
const xml_document_encoding = @import("xml_document_encoding");

/// `s` repeated `n` times: what `s ** n` was (Zig 0.17 removes `**`; roadmap zig-017).
fn repeat(comptime s: []const u8, comptime n: usize) *const [s.len * n:0]u8 {
    return comptime blk: {
        @setEvalBranchQuota(10 * n + 1000);
        var out: [s.len * n:0]u8 = undefined;
        for (0..n) |i| @memcpy(out[i * s.len ..][0..s.len], s);
        const final = out;
        break :blk &final;
    };
}

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
    /// Module dedicated worker context (`new Worker(url, {type: "module"})`)
    worker_module,
    /// Module shared worker context
    sharedworker_module,
    /// Module service worker context
    serviceworker_module,
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
    /// A module script in a window (`.any.window-module.html`).
    window_module,
    /// A JavaScript shell with no web platform (`.any.js` itself).
    jsshell,

    /// Parse a global type from a string
    pub fn fromString(str: []const u8) ?GlobalType {
        if (std.mem.eql(u8, str, "window")) return .window;
        if (std.mem.eql(u8, str, "worker")) return .worker;
        if (std.mem.eql(u8, str, "dedicatedworker")) return .worker;
        if (std.mem.eql(u8, str, "sharedworker")) return .sharedworker;
        if (std.mem.eql(u8, str, "serviceworker")) return .serviceworker;
        if (std.mem.eql(u8, str, "dedicatedworker-module")) return .worker_module;
        // No longhand upstream, and the same URL as dedicatedworker-module:
        // `.any.worker-module.html`.
        if (std.mem.eql(u8, str, "worker-module")) return .worker_module;
        if (std.mem.eql(u8, str, "sharedworker-module")) return .sharedworker_module;
        if (std.mem.eql(u8, str, "serviceworker-module")) return .serviceworker_module;
        if (std.mem.eql(u8, str, "window-module")) return .window_module;
        if (std.mem.eql(u8, str, "jsshell")) return .jsshell;
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
            .worker_module => "dedicatedworker-module",
            .sharedworker_module => "sharedworker-module",
            .serviceworker_module => "serviceworker-module",
            .shadowrealm => "shadowrealm",
            .shadowrealm_in_window => "shadowrealm-in-window",
            .shadowrealm_in_dedicatedworker => "shadowrealm-in-dedicatedworker",
            .shadowrealm_in_sharedworker => "shadowrealm-in-sharedworker",
            .shadowrealm_in_shadowrealm => "shadowrealm-in-shadowrealm",
            .shadowrealm_in_audioworklet => "shadowrealm-in-audioworklet",
            .shadowrealm_in_serviceworker => "shadowrealm-in-serviceworker",
            .window_module => "window-module",
            .jsshell => "jsshell",
        };
    }

    /// The globals one name in a `// META: global=` list stands for, as
    /// upstream's manifest expands it (tools/manifest/sourcefile.py,
    /// `_any_variants` and `get_any_variants`): "worker" is the dedicated,
    /// shared and service worker, "shadowrealm" its six variants, any other
    /// name WPT knows itself. Null for a name WPT does not know, which
    /// declares nothing.
    pub fn expand(name: []const u8) ?[]const GlobalType {
        if (std.mem.eql(u8, name, "worker")) return &.{ .worker, .sharedworker, .serviceworker };
        if (std.mem.eql(u8, name, "shadowrealm")) return &.{
            .shadowrealm_in_window,
            .shadowrealm_in_shadowrealm,
            .shadowrealm_in_dedicatedworker,
            .shadowrealm_in_sharedworker,
            .shadowrealm_in_serviceworker,
            .shadowrealm_in_audioworklet,
        };
        inline for (comptime std.enums.values(GlobalType)) |g| {
            // `.shadowrealm` names the longhand above, never a global of its
            // own.
            if (g != .shadowrealm and std.mem.eql(u8, name, comptime g.toString())) return &.{g};
        }
        if (std.mem.eql(u8, name, "dedicatedworker")) return &.{.worker};
        if (std.mem.eql(u8, name, "worker-module")) return &.{.worker_module};
        return null;
    }

    /// Whether a test declaring this global should actually be run.
    ///
    /// A global that is off here is skipped outright rather than reported as a
    /// failure, so this is a claim about infrastructure, not about any
    /// particular test. Turning one on before its plumbing exists converts a
    /// silent skip into a wall of timeouts, each costing the full test timeout
    /// in wall clock; the bar for flipping one is that the harness can get
    /// results back out of that global at all.
    pub fn isImplemented(self: GlobalType) bool {
        return switch (self) {
            .window => true,
            // The dedicated worker clears that bar: `wpt serve` generates the
            // `.any.worker.html` wrapper, the Worker constructor spawns a real
            // thread with its own V8 context, importScripts() pulls
            // testharness.js into it, and fetch_tests_from_worker() carries the
            // results back over postMessage.
            .worker => true,
            // `wpt serve`'s `.any.sharedworker.html` connects a SharedWorker
            // and fetch_tests_from_worker() carries its harness results
            // back over the connection's MessagePort, as for module workers.
            .sharedworker => true,
            // The service worker clears the bar (lane sw1-b2, granted): `wpt
            // serve`'s `.any.serviceworker.html` registers the test script,
            // and fetch_tests_from_worker() reads its results back over
            // ServiceWorker.postMessage and Client.postMessage. Its URL is
            // https whatever the file's name says (WptServer.buildTestUrl).
            .serviceworker => true,
            // The module workers: `wpt serve` generates the
            // `.any.worker-module.html` / `.any.sharedworker-module.html` /
            // `.any.serviceworker-module.html` wrappers, whose worker imports
            // testharness.js and the test as modules; a module Worker and a
            // module SharedWorker run the graph (crane/script-module-workers.html),
            // and a module service worker's registration ({type: "module"})
            // runs it with the classic one's plumbing above (lane sw1-b8: it
            // was left off untried in e1acbff5d49, never for a crash or hang).
            .worker_module => true,
            .sharedworker_module => true,
            .serviceworker_module => true,
            // All ShadowRealm variants not implemented
            .shadowrealm,
            .shadowrealm_in_window,
            .shadowrealm_in_dedicatedworker,
            .shadowrealm_in_sharedworker,
            .shadowrealm_in_shadowrealm,
            .shadowrealm_in_audioworklet,
            .shadowrealm_in_serviceworker,
            => false,
            // A module script in a window has no wrapper the runner drives
            // yet, and a JavaScript shell is not a web platform.
            .window_module, .jsshell => false,
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
    /// A `// META: global=` line with a value was read: `globals` is what it
    /// declares - possibly nothing - and the `.any.js` defaults do not apply.
    globals_declared: bool = false,
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
        const owned = try self.allocator.dupe(u8, variant);
        errdefer self.allocator.free(owned);
        try self.variants.append(self.allocator, owned);
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
    ///
    /// This is how many URLs MANIFEST.json lists for the file - what a complete
    /// implementation would run. For how many this runner will actually run,
    /// see `runCount`.
    pub fn getEffectiveTestCount(self: TestMetadata) usize {
        const variant_count = if (self.variants.items.len > 0) self.variants.items.len else 1;
        return variant_count * @max(1, self.globals.items.len);
    }

    /// How many times this runner will execute the file: once per implemented
    /// global, times once per variant.
    ///
    /// The progress denominator, so it has to predict exactly what the
    /// execution loop does. Unimplemented globals are skipped rather than run,
    /// and their variants are skipped with them - a file with none of its
    /// globals implemented counts 1, matching the single skip it reports.
    pub fn runCount(self: TestMetadata) usize {
        var implemented: usize = 0;
        for (self.globals.items) |g| {
            if (g.isImplemented()) implemented += 1;
        }
        if (implemented == 0) return 1;
        return implemented * self.variantsOrDefault().len;
    }

    /// The variants to run, with WPT's default filled in.
    ///
    /// A file that declares no variant still runs exactly once - upstream
    /// sourcefile.py ends its variant list with `if not rv: rv = [""]`. Handing
    /// back one empty variant rather than an empty list means the runner has a
    /// single loop instead of a loop and a special case, and an empty variant
    /// costs nothing downstream: it appends nothing to the URL and names
    /// nothing in the result.
    pub fn variantsOrDefault(self: TestMetadata) []const []const u8 {
        if (self.variants.items.len == 0) return &no_variants;
        return self.variants.items;
    }
};

const no_variants = [_][]const u8{""};

/// How one run of a source is named in the results.
///
/// A source fans out along two independent axes - the globals it declares (a
/// `.any.js` runs in window and worker) and the query-string variants it
/// declares - and they multiply. MANIFEST.json lists every combination as its
/// own test URL, so each needs a name that tells it apart from its siblings;
/// without one, several URLs' results collapse onto a single scoreboard line.
///
/// Null means there is nothing to tell apart: one global, no variants, which is
/// most of the corpus and whose display name should stay the bare path.
///
/// `global_count` is how many globals the file *declares*, not how many of them
/// this runner can execute. A file declaring window and sharedworker is named
/// `[window]` even though only one global runs, so that its scoreboard line
/// stays the same line once the missing global is turned on.
///
/// The caller owns a non-null result.
pub fn runLabel(
    allocator: std.mem.Allocator,
    context: GlobalType,
    global_count: usize,
    variant: []const u8,
) !?[]const u8 {
    const name_global = global_count > 1;
    if (name_global and variant.len > 0) {
        return try std.fmt.allocPrint(allocator, "{s} {s}", .{ context.toString(), variant });
    }
    if (name_global) return try allocator.dupe(u8, context.toString());
    if (variant.len > 0) return try allocator.dupe(u8, variant);
    return null;
}

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

/// One `// META: key=value` line, as upstream's `js_meta_re` matches it:
/// `//\s*META:\s*(\w*)=(.*)$`, from the line's first byte. Null when the
/// line is no META line.
const MetaLine = struct {
    key: []const u8,
    value: []const u8,

    fn match(line: []const u8) ?MetaLine {
        if (!std.mem.startsWith(u8, line, "//")) return null;
        var i: usize = 2;
        while (i < line.len and isRegexSpace(line[i])) i += 1;
        if (!std.mem.startsWith(u8, line[i..], "META:")) return null;
        i += "META:".len;
        while (i < line.len and isRegexSpace(line[i])) i += 1;
        const key_start = i;
        while (i < line.len and (std.ascii.isAlphanumeric(line[i]) or line[i] == '_')) i += 1;
        if (i >= line.len or line[i] != '=') return null;
        // A CRLF file's lines end in '\r', which is no part of the value.
        return .{ .key = line[key_start..i], .value = std.mem.trimEnd(u8, line[i + 1 ..], "\r") };
    }

    /// Python's `\s` in a bytes pattern.
    fn isRegexSpace(c: u8) bool {
        return switch (c) {
            ' ', '\t', '\n', '\r', 0x0b, 0x0c => true,
            else => false,
        };
    }
};

/// Parse META comments from a JavaScript test file
/// Note: This does NOT add default globals - callers should set defaults based on file type
///
/// As upstream reads them (tools/manifest/sourcefile.py,
/// `read_script_metadata`): the file's lines from the first, each a META
/// line, until the first that is not - a blank line or a plain comment ends
/// the metadata, and what follows it is none. MANIFEST.json and `wpt serve`'s
/// wrappers are built from exactly that, so the runner reads no more and no
/// less.
pub fn parseMetaComments(allocator: std.mem.Allocator, content: []const u8) !TestMetadata {
    var metadata = TestMetadata.init(allocator);
    errdefer metadata.deinit();

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const meta = MetaLine.match(line) orelse break;
        const key = meta.key;
        const value = meta.value;

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
            // Only the first `global` line counts, and an empty one is the
            // defaults (`parse_variants("")`).
            if (metadata.globals_declared or value.len == 0) continue;
            metadata.globals_declared = true;
            // Comma-separated names (e.g. "window,worker,sharedworker"),
            // each expanded as upstream does; a name WPT does not know
            // declares nothing.
            var globals = std.mem.splitScalar(u8, value, ',');
            while (globals.next()) |g| {
                const gtrim = std.mem.trim(u8, g, &std.ascii.whitespace);
                for (GlobalType.expand(gtrim) orelse continue) |global| {
                    try metadata.addGlobal(global);
                }
            }
        }
        // Other META keys (like "quic") are ignored for now
    }

    return metadata;
}

/// Parse a .any.js test file
/// .any.js files run in multiple contexts by default (window + worker)
/// unless explicitly specified via // META: global=...
pub fn parseAnyJs(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ParsedTest {
    var metadata = try parseMetaComments(allocator, content);
    errdefer metadata.deinit();

    // Default globals for .any.js: window + worker - only when the file
    // declares none (`get_default_any_variants`). A declaration of names WPT
    // does not know declares nothing, and nothing runs.
    if (!metadata.globals_declared) {
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
/// Handles both single and double quotes
/// The value of attribute `attr_name` in one start tag: double-quoted,
/// single-quoted, or unquoted - HTML allows `<meta name=timeout
/// content=long>`, and an unquoted value ends at whitespace or the tag's end.
/// The name must be a whole attribute name: whitespace (or the start of the
/// text) before it and `=` right after, so the `content` in `http-equiv=content-type` and the `name`
/// in `data-name` are not matches.
fn extractAttribute(tag: []const u8, attr_name: []const u8) ?[]const u8 {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, tag, pos, attr_name)) |at| {
        pos = at + 1;
        if (at != 0 and !std.ascii.isWhitespace(tag[at - 1])) continue;
        const equals = at + attr_name.len;
        if (equals >= tag.len or tag[equals] != '=') continue;

        const value_start = equals + 1;
        if (value_start >= tag.len) return null;
        const quote = tag[value_start];
        if (quote == '"' or quote == '\'') {
            const end = std.mem.indexOfScalarPos(u8, tag, value_start + 1, quote) orelse return null;
            return tag[value_start + 1 .. end];
        }
        var end = value_start;
        while (end < tag.len and !std.ascii.isWhitespace(tag[end]) and tag[end] != '>') : (end += 1) {}
        return tag[value_start..end];
    }
    return null;
}

test "an unquoted meta attribute is read like a quoted one" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // HTML allows unquoted attribute values, and 120 worklist files declare
    // their budget as `<meta name=timeout content=long>`: read only in its
    // quoted form, every one of them ran on the 10s budget.
    const content =
        \\<!DOCTYPE html>
        \\<meta charset=utf-8>
        \\<meta name=timeout content=long>
        \\<meta name=variant content=?a=1>
        \\<meta http-equiv=content-type content=text/html>
        \\<script src=/resources/testharness.js></script>
    ;

    var parsed = try parseHtml(allocator, "html/unquoted.html", content);
    defer parsed.deinit();

    try testing.expectEqual(config.Timeout.long, parsed.metadata.timeout);
    try testing.expectEqual(@as(usize, 1), parsed.metadata.variants.items.len);
    try testing.expectEqualStrings("?a=1", parsed.metadata.variants.items[0]);
}

test "an attribute name matches only a whole attribute" {
    const testing = std.testing;
    // `content=` inside `http-equiv=content-type` is not the content
    // attribute, and `name=` inside `data-name=` is not the name attribute.
    try testing.expectEqualStrings("text/html", extractAttribute("<meta http-equiv=content-type content=text/html>", "content").?);
    try testing.expect(extractAttribute("<meta data-name=x>", "name") == null);
    try testing.expectEqualStrings("long", extractAttribute("<meta name='timeout' content='long'>", "content").?);
    try testing.expectEqualStrings("long", extractAttribute("<meta name=\"timeout\" content=\"long\">", "content").?);
}

/// Parse a test file based on its extension
pub fn parseTestFile(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ParsedTest {
    const file_type = config.FileType.fromPath(path);
    return switch (file_type) {
        .any_js => parseAnyJs(allocator, path, content),
        .window_js => parseWindowJs(allocator, path, content),
        .worker_js => parseWorkerJs(allocator, path, content),
        .html => parseHtml(allocator, path, content),
        .xml => parseXml(allocator, path, content),
        .unknown => error.UnsupportedTestFormat,
    };
}

/// XML documents run in a Window. Only metadata is read here; Browser loads
/// the original response and runs its scripts with HTML §14.2 XML scripting.
pub fn parseXml(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !ParsedTest {
    var metadata = try parseXmlMetadata(allocator, content);
    errdefer metadata.deinit();
    try metadata.addGlobal(.window);
    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);
    return .{
        .allocator = allocator,
        .path = owned_path,
        .file_type = .xml,
        .metadata = metadata,
        .content = try allocator.dupe(u8, content),
    };
}

/// WPT tools/manifest/sourcefile.py selects descendant XHTML-namespace meta
/// elements. XML names are case-sensitive; prefixes, entity references,
/// comments and CDATA must be interpreted by the XML parser, not an HTML
/// substring scan. The first timeout element wins; variants retain order.
fn parseXmlMetadata(allocator: std.mem.Allocator, content: []const u8) !TestMetadata {
    var metadata = TestMetadata.init(allocator);
    errdefer metadata.deinit();
    const decoded = (try xml_document_encoding.decodeDocumentBytes(allocator, content, null)) orelse return metadata;
    defer allocator.free(decoded.text);
    var parser = xml.Parser.init(allocator, .{ .xhtml_entities = xml_document_encoding.htmlNamedReference });
    defer parser.deinit();
    var sink = XmlMetadataSink{ .metadata = &metadata };
    if (try parser.parse(decoded.text, &sink) != null) {
        // Upstream has no metadata for an ill-formed XML source. Still load
        // it in the browser: parsing errors are document behavior, not a
        // reason for the runner to suppress a requested navigation.
        metadata.deinit();
        metadata = TestMetadata.init(allocator);
    }
    return metadata;
}

test "XML metadata decodes UTF-16 with and without a byte order mark" {
    const text = "<?xml version='1.0' encoding='UTF-16'?><r xmlns:h='http://www.w3.org/1999/xhtml'><h:meta name='variant' content='?wide'/></r>";
    for ([_]bool{ false, true }) |big_endian| {
        for ([_]bool{ false, true }) |bom| {
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(std.testing.allocator);
            if (bom) try bytes.appendSlice(std.testing.allocator, if (big_endian) "\xfe\xff" else "\xff\xfe");
            for (text) |c| try bytes.appendSlice(std.testing.allocator, if (big_endian) &.{ 0, c } else &.{ c, 0 });
            var metadata = try parseXmlMetadata(std.testing.allocator, bytes.items);
            defer metadata.deinit();
            try std.testing.expectEqual(@as(usize, 1), metadata.variants.items.len);
            try std.testing.expectEqualStrings("?wide", metadata.variants.items[0]);
        }
    }
}

test "XML metadata decodes declared legacy encodings and XHTML entities" {
    const sources = [_][]const u8{
        "<?xml version='1.0' encoding='windows-1252'?><r xmlns='http://www.w3.org/1999/xhtml'><meta name='variant' content='?caf\xe9'/></r>",
        "<!DOCTYPE r PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'><r xmlns='http://www.w3.org/1999/xhtml'><meta name='variant' content='?caf&eacute;'/></r>",
    };
    for (sources) |source| {
        var metadata = try parseXmlMetadata(std.testing.allocator, source);
        defer metadata.deinit();
        try std.testing.expectEqual(@as(usize, 1), metadata.variants.items.len);
        try std.testing.expectEqualStrings("?café", metadata.variants.items[0]);
    }
}

test "XML metadata ignores an unsupported declared encoding" {
    var metadata = try parseXmlMetadata(std.testing.allocator, "<?xml version='1.0' encoding='xm1-unknown'?><r xmlns='http://www.w3.org/1999/xhtml'><meta name='variant' content='?invalid'/></r>");
    defer metadata.deinit();
    try std.testing.expectEqual(@as(usize, 0), metadata.variants.items.len);
}

test "malformed encoded XML discards metadata even after a complete meta element" {
    const prefix = "<r xmlns='http://www.w3.org/1999/xhtml'><meta name='variant' content='?bad'/><x>";
    const suffix = "</x></r>";
    var utf16: std.ArrayList(u8) = .empty;
    defer utf16.deinit(std.testing.allocator);
    try utf16.appendSlice(std.testing.allocator, "\xff\xfe");
    for (prefix) |c| try utf16.appendSlice(std.testing.allocator, &.{ c, 0 });
    try utf16.appendSlice(std.testing.allocator, "\x00\xd8");
    for (suffix) |c| try utf16.appendSlice(std.testing.allocator, &.{ c, 0 });
    const sources = [_][]const u8{
        prefix ++ "\xff" ++ suffix,
        prefix ++ "\xe2\x82" ++ suffix,
        utf16.items,
        "<?xml version='1.0' encoding='Shift_JIS'?>" ++ prefix ++ "\x82" ++ suffix,
    };
    for (sources) |source| {
        var metadata = try parseXmlMetadata(std.testing.allocator, source);
        defer metadata.deinit();
        try std.testing.expectEqual(@as(usize, 0), metadata.variants.items.len);
    }
}

test "XML metadata preserves multibyte text across decoder output buffers" {
    const allocator = std.testing.allocator;
    const text = "<?xml version='1.0' encoding='UTF-16'?><r xmlns='http://www.w3.org/1999/xhtml'>" ++
        repeat("<x>é😀</x>", 1200) ++ "<meta name='variant' content='?é😀'/></r>";
    const units = try std.unicode.utf8ToUtf16LeAlloc(allocator, text);
    defer allocator.free(units);
    var metadata = try parseXmlMetadata(allocator, std.mem.sliceAsBytes(units));
    defer metadata.deinit();
    try std.testing.expectEqual(@as(usize, 1), metadata.variants.items.len);
    try std.testing.expectEqualStrings("?é😀", metadata.variants.items[0]);
}

fn checkMalformedEncodedMetadataAllocations(allocator: std.mem.Allocator) !void {
    const source = "<?xml version='1.0' encoding='Shift_JIS'?><r xmlns='http://www.w3.org/1999/xhtml'>" ++
        "<meta name='variant' content='?bad'/><x>" ++ &@as([12000:0]u8, @splat('a')) ++ "\x82</x></r>";
    var metadata = try parseXmlMetadata(allocator, source);
    defer metadata.deinit();
    try std.testing.expectEqual(@as(usize, 0), metadata.variants.items.len);
}

test "fatal XML byte errors release all previously decoded buffers" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkMalformedEncodedMetadataAllocations, .{});
}

const XmlMetadataSink = struct {
    metadata: *TestMetadata,
    depth: usize = 0,
    seen_timeout: bool = false,

    pub fn startElement(self: *XmlMetadataSink, name: xml.Name, attributes: []const xml.Attribute) !void {
        self.depth += 1;
        if (self.depth == 1 or !std.mem.eql(u8, name.namespace orelse "", "http://www.w3.org/1999/xhtml") or
            !std.mem.eql(u8, name.local, "meta")) return;
        var meta_name: ?[]const u8 = null;
        var content: ?[]const u8 = null;
        for (attributes) |attribute| {
            if (attribute.name.namespace != null) continue;
            if (std.mem.eql(u8, attribute.name.local, "name")) meta_name = attribute.value;
            if (std.mem.eql(u8, attribute.name.local, "content")) content = attribute.value;
        }
        const kind = meta_name orelse return;
        if (std.mem.eql(u8, kind, "timeout") and !self.seen_timeout) {
            self.seen_timeout = true;
            if (std.ascii.eqlIgnoreCase(content orelse "", "long")) self.metadata.timeout = .long;
        } else if (std.mem.eql(u8, kind, "variant")) {
            if (content) |value| try self.metadata.addVariant(value);
        }
    }

    pub fn endElement(self: *XmlMetadataSink, _: xml.Name) !void {
        self.depth -= 1;
    }
};

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
        const io = host.io();
        const file = host.cwd().openFile(io, resolved_path, .{}) catch |err| {
            return err;
        };
        defer file.close(io);

        var file_reader = file.reader(io, &.{});
        const content = file_reader.interface.allocRemaining(self.allocator, .limited(10 * 1024 * 1024)) catch |err| {
            return err;
        };

        // Cache the content
        const key = try self.allocator.dupe(u8, resolved_path);
        try self.cache.put(key, content);

        return content;
    }

    /// Load all scripts for a parsed test
    pub fn loadAll(self: *ScriptLoader, parsed_test: *const ParsedTest) !std.ArrayList(LoadedScript) {
        var scripts: std.ArrayList(LoadedScript) = .empty;
        errdefer {
            for (scripts.items) |*s| s.deinit(self.allocator);
            scripts.deinit(self.allocator);
        }

        for (parsed_test.metadata.scripts.items) |script_ref| {
            if (script_ref.inline_script) {
                // Inline script - content is already available
                try scripts.append(self.allocator, LoadedScript{
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
                try scripts.append(self.allocator, LoadedScript{
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
        .xml => try parseXmlMetadata(allocator, content),
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

test "XML metadata follows expanded names and excludes comments and CDATA" {
    const content =
        \\<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        \\  <!-- <meta name="variant" content="?comment"/> -->
        \\  <script><![CDATA[const s = '<meta name="variant" content="?script"/>';]]></script>
        \\  <meta name="variant" content="?svg"/>
        \\  <h:meta name="timeout" content="LONG"/>
        \\  <h:meta name="variant" content="?a=1&amp;b=2"/>
        \\  <h:meta name="variant" content="#fragment"/>
        \\</svg>
    ;
    for ([_][]const u8{ "test.xhtml", "test.xht", "test.svg", "test.xml" }) |path| {
        var parsed = try parseTestFile(std.testing.allocator, path, content);
        defer parsed.deinit();
        try std.testing.expectEqual(config.Timeout.long, parsed.metadata.timeout);
        try std.testing.expectEqualSlices(GlobalType, &.{.window}, parsed.metadata.globals.items);
        try std.testing.expectEqual(@as(usize, 2), parsed.metadata.variants.items.len);
        try std.testing.expectEqualStrings("?a=1&b=2", parsed.metadata.variants.items[0]);
        try std.testing.expectEqualStrings("#fragment", parsed.metadata.variants.items[1]);
    }
}

test "XML metadata uses the first timeout and includes only descendant meta elements" {
    const content =
        \\<meta xmlns="http://www.w3.org/1999/xhtml" name="variant" content="?root">
        \\  <meta name="timeout"/>
        \\  <meta name="timeout" content="long"/>
        \\  <META name="variant" content="?uppercase"/>
        \\  <meta name="variant"/>
        \\  <meta name="variant" content=""/>
        \\  <meta xmlns="" name="variant" content="?no-namespace"/>
        \\</meta>
    ;
    var metadata = try extractMetadata(std.testing.allocator, .xml, content);
    defer metadata.deinit();
    try std.testing.expectEqual(config.Timeout.normal, metadata.timeout);
    try std.testing.expectEqual(@as(usize, 1), metadata.variants.items.len);
    try std.testing.expectEqualStrings("", metadata.variants.items[0]);
}

test "malformed XML still schedules a browser navigation without invented metadata" {
    var parsed = try parseTestFile(std.testing.allocator, "test.xml", "<root xmlns='http://www.w3.org/1999/xhtml'><meta name='variant' content='?bad'/></wrong>");
    defer parsed.deinit();
    try std.testing.expectEqualSlices(GlobalType, &.{.window}, parsed.metadata.globals.items);
    try std.testing.expectEqual(@as(usize, 0), parsed.metadata.variants.items.len);
}

fn checkXmlMetadataAllocations(allocator: std.mem.Allocator) !void {
    var parsed = try parseTestFile(allocator, "test.xml", "<root xmlns='http://www.w3.org/1999/xhtml'><meta name='variant' content='?a&amp;b'/></root>");
    defer parsed.deinit();
}

test "XML metadata allocation failures release every owned value" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkXmlMetadataAllocations, .{});
}

fn checkEncodedXmlMetadataAllocations(allocator: std.mem.Allocator) !void {
    const text = "<?xml version='1.0' encoding='UTF-16'?><r xmlns='http://www.w3.org/1999/xhtml'><meta name='variant' content='?wide'/></r>";
    var utf16: [text.len * 2]u8 = undefined;
    for (text, 0..) |c, i| {
        utf16[i * 2] = c;
        utf16[i * 2 + 1] = 0;
    }
    const sources = [_][]const u8{
        &utf16,
        "<?xml version='1.0' encoding='windows-1252'?><r xmlns='http://www.w3.org/1999/xhtml'><meta name='variant' content='?caf\xe9'/></r>",
        "<!DOCTYPE r PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'><r xmlns='http://www.w3.org/1999/xhtml'><meta name='variant' content='?caf&eacute;'/></r>",
    };
    for (sources) |source| {
        var parsed = try parseXml(allocator, "encoded.xml", source);
        defer parsed.deinit();
        try std.testing.expectEqual(@as(usize, 1), parsed.metadata.variants.items.len);
    }
}

test "decoded XML metadata frees buffers and entities on every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkEncodedXmlMetadataAllocations, .{});
}

test "XML corpus metadata expands to the manifest URLs" {
    const allocator = std.testing.allocator;
    const manifest_module = @import("manifest.zig");
    host.cwd().access(host.io(), "tests/wpt/MANIFEST.json", .{}) catch return error.SkipZigTest;
    var manifest = try manifest_module.loadManifest(allocator, "tests/wpt");
    defer manifest.deinit();
    var iterator = manifest.source_to_urls.iterator();
    while (iterator.next()) |entry| {
        const path = entry.key_ptr.*;
        if (config.FileType.fromPath(path) != .xml) continue;
        const full_path = try std.fs.path.join(allocator, &.{ "tests/wpt", path });
        defer allocator.free(full_path);
        const content = host.cwd().readFileAlloc(host.io(), full_path, allocator, .limited(16 * 1024 * 1024)) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer allocator.free(content);
        var parsed = try parseTestFile(allocator, path, content);
        defer parsed.deinit();
        const variants = parsed.metadata.variantsOrDefault();
        try std.testing.expectEqual(entry.value_ptr.items.len, variants.len);
        for (variants) |variant| {
            const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ path, variant });
            defer allocator.free(url);
            var found = false;
            for (entry.value_ptr.items) |expected| {
                if (std.mem.eql(u8, expected, url)) found = true;
            }
            try std.testing.expect(found);
        }
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

    // "worker" is the dedicated, shared and service worker (upstream's
    // longhand); the sharedworker it names again is not named twice.
    try testing.expectEqual(@as(usize, 4), metadata.globals.items.len);
    try testing.expectEqual(GlobalType.window, metadata.globals.items[0]);
    try testing.expectEqual(GlobalType.worker, metadata.globals.items[1]);
    try testing.expectEqual(GlobalType.sharedworker, metadata.globals.items[2]);
    try testing.expectEqual(GlobalType.serviceworker, metadata.globals.items[3]);
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

test "GlobalType.fromString: the module worker globals" {
    try std.testing.expectEqual(GlobalType.worker_module, GlobalType.fromString("dedicatedworker-module").?);
    try std.testing.expectEqual(GlobalType.sharedworker_module, GlobalType.fromString("sharedworker-module").?);
    try std.testing.expectEqual(GlobalType.serviceworker_module, GlobalType.fromString("serviceworker-module").?);
    try std.testing.expectEqualStrings("dedicatedworker-module", GlobalType.worker_module.toString());
    try std.testing.expectEqualStrings("sharedworker-module", GlobalType.sharedworker_module.toString());
    try std.testing.expectEqualStrings("serviceworker-module", GlobalType.serviceworker_module.toString());
    // Run where the plumbing exists: a module Worker, a module SharedWorker
    // and a module service worker.
    try std.testing.expect(GlobalType.worker_module.isImplemented());
    try std.testing.expect(GlobalType.sharedworker_module.isImplemented());
    try std.testing.expect(GlobalType.serviceworker_module.isImplemented());
}

test "parseAnyJs: a file of module worker globals gets those globals, not the defaults" {
    const content =
        \\// META: global=dedicatedworker-module,sharedworker-module,serviceworker-module
        \\import "./x.js";
    ;
    var parsed = try parseAnyJs(std.testing.allocator, "a/b.any.js", content);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 3), parsed.metadata.globals.items.len);
    try std.testing.expectEqual(GlobalType.worker_module, parsed.metadata.globals.items[0]);
    try std.testing.expectEqual(GlobalType.sharedworker_module, parsed.metadata.globals.items[1]);
    try std.testing.expectEqual(GlobalType.serviceworker_module, parsed.metadata.globals.items[2]);
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
    // The non-ShadowRealm globals are covered by the isImplemented tests below;
    // this one is only about the ShadowRealm family. Note that
    // `shadowrealm-in-dedicatedworker` stays off even though the dedicated
    // worker itself is on - the realm inside it is the part that is missing.

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

    // "shadowrealm" is its six variants (upstream's longhand), and the
    // shadowrealm-in-window it names again is not named twice.
    try testing.expectEqual(@as(usize, 7), metadata.globals.items.len);
    try testing.expectEqual(GlobalType.window, metadata.globals.items[0]);
    try testing.expectEqual(GlobalType.shadowrealm_in_window, metadata.globals.items[1]);
    try testing.expectEqual(GlobalType.shadowrealm_in_audioworklet, metadata.globals.items[6]);
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

    // window, and "worker"'s dedicated, shared and service worker.
    try std.testing.expectEqual(@as(usize, 4), parsed.metadata.globals.items.len);
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

    // Window and all three worker globals run this file.
    try std.testing.expectEqual(@as(usize, 4), executed_contexts);
}

test "multi-context: unimplemented contexts are skipped" {
    const allocator = std.testing.allocator;

    const content =
        \\// META: global=window,shadowrealm-in-window,serviceworker
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    // Should have 3 globals parsed
    try std.testing.expectEqual(@as(usize, 3), parsed.metadata.globals.items.len);

    // Window and the service worker run; ShadowRealm does not.
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

    // window; worker's three (shared and service named again); shadowrealm's six.
    try std.testing.expectEqual(@as(usize, 10), parsed.metadata.globals.items.len);

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

    // Window and the three worker globals run; shadowrealm's six do not.
    try std.testing.expectEqual(@as(usize, 4), implemented);
    try std.testing.expectEqual(@as(usize, 6), unimplemented);
}

test "GlobalType.isImplemented - the dedicated worker runs" {
    // The single largest block of tests we are not running. Of the in-scope WPT
    // corpus, 28% of URLs are dedicated-worker variants - `foo.worker.html`
    // from a `.worker.js`, and `foo.any.worker.html` from a `.any.js` - so
    // leaving this off costs more coverage than every other global combined.
    try std.testing.expect(GlobalType.worker.isImplemented());
    try std.testing.expect(GlobalType.window.isImplemented());
}

test "classic SharedWorker metadata selects its executable wrapper" {
    const allocator = std.testing.allocator;
    var parsed = try parseTestFile(allocator, "xhr/idlharness.any.js", "// META: global=sharedworker\n");
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 1), parsed.metadata.globals.items.len);
    try std.testing.expectEqual(GlobalType.sharedworker, parsed.metadata.globals.items[0]);
    try std.testing.expect(parsed.metadata.globals.items[0].isImplemented());
}

test "GlobalType.isImplemented - classic and module service and shared workers run" {
    // The service worker's variant registers its test script and reads its
    // results back over ServiceWorker.postMessage and Client.postMessage
    // (lane sw1-b2, granted): on a sample of 87 files it added 1,517 passing
    // subtests and blocked nothing new. The module service worker's wrapper
    // registers it with {type: "module"} over the same plumbing (lane
    // sw1-b8, granted). A shared worker's harness uses its MessagePort.
    try std.testing.expect(GlobalType.serviceworker.isImplemented());
    try std.testing.expect(GlobalType.serviceworker_module.isImplemented());
    try std.testing.expect(GlobalType.sharedworker.isImplemented());
    try std.testing.expect(GlobalType.sharedworker_module.isImplemented());
}

test "GlobalType.isImplemented - dedicatedworker spelling agrees" {
    // WPT writes `global=dedicatedworker` as often as `global=worker`, and both
    // parse to the same variant. A gate that disagreed with itself across the
    // two spellings would run a file in one and skip it in the other.
    const from_short = GlobalType.fromString("worker").?;
    const from_long = GlobalType.fromString("dedicatedworker").?;
    try std.testing.expectEqual(from_short, from_long);
    try std.testing.expectEqual(from_short.isImplemented(), from_long.isImplemented());
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

    // MANIFEST.json's URLs: 4 globals (window; worker's dedicated, shared
    // and service worker) * 3 variants. All four globals run.
    try std.testing.expectEqual(@as(usize, 12), parsed.metadata.getEffectiveTestCount());
    try std.testing.expectEqual(@as(usize, 12), parsed.metadata.runCount());
}

test "variantsOrDefault: a file with no variants still runs exactly once" {
    const allocator = std.testing.allocator;

    var parsed = try parseTestFile(allocator, "test.any.js", "test(() => {});");
    defer parsed.deinit();

    // WPT's own rule, from sourcefile.py: `if not rv: rv = [""]`. Two thirds of
    // the corpus declares no variant, and modelling that as one empty variant
    // rather than as a separate case is what lets the runner have a single loop.
    const variants = parsed.metadata.variantsOrDefault();
    try std.testing.expectEqual(@as(usize, 1), variants.len);
    try std.testing.expectEqualStrings("", variants[0]);
}

test "variantsOrDefault: declared variants come back verbatim" {
    const allocator = std.testing.allocator;

    const content =
        \\// META: variant=
        \\// META: variant=?include=file
        \\// META: variant=#fragment
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    // The leading `?` or `#` is part of the variant, and an explicitly declared
    // empty variant is a real variant that happens to look like the default.
    // They are appended to the URL as-is, so nothing here may be normalised.
    const variants = parsed.metadata.variantsOrDefault();
    try std.testing.expectEqual(@as(usize, 3), variants.len);
    try std.testing.expectEqualStrings("", variants[0]);
    try std.testing.expectEqualStrings("?include=file", variants[1]);
    try std.testing.expectEqualStrings("#fragment", variants[2]);
}

test "runCount: multiplies implemented globals by variants" {
    const allocator = std.testing.allocator;

    const content =
        \\// META: global=window,worker
        \\// META: variant=?1
        \\// META: variant=?2
        \\// META: variant=?3
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    // 4 run globals (window and the three workers) * 3
    // variants. This is the runner's progress denominator, so a count that
    // ignored either axis would leave the bar stuck short of its own total, or
    // run past it.
    try std.testing.expectEqual(@as(usize, 12), parsed.metadata.runCount());
}

test "runCount: counts only globals that run" {
    const allocator = std.testing.allocator;

    const content =
        \\// META: global=window,worker,shadowrealm-in-window
        \\// META: variant=?1
        \\// META: variant=?2
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    // Unlike getEffectiveTestCount, which counts what WPT would run: the
    // unimplemented ShadowRealm is skipped outright and never reports, so
    // counting it would promise results that never arrive.
    try std.testing.expectEqual(@as(usize, 10), parsed.metadata.getEffectiveTestCount());
    try std.testing.expectEqual(@as(usize, 8), parsed.metadata.runCount());
}

test "runCount: a file with no variants counts once per global" {
    const allocator = std.testing.allocator;

    var parsed = try parseTestFile(allocator, "test.any.js", "test(() => {});");
    defer parsed.deinit();

    // .any.js defaults to window+worker, both implemented, no variants.
    try std.testing.expectEqual(@as(usize, 2), parsed.metadata.runCount());
}

test "runCount: a file with no implemented global still counts once" {
    const allocator = std.testing.allocator;

    const content =
        \\// META: global=shadowrealm-in-window
        \\// META: variant=?1
        \\// META: variant=?2
        \\test(() => {});
    ;

    var parsed = try parseTestFile(allocator, "test.any.js", content);
    defer parsed.deinit();

    // The file is skipped rather than run, and its variants are skipped with
    // it - so they must not multiply. One, matching the single skip the
    // execution loop reports for it.
    try std.testing.expectEqual(@as(usize, 1), parsed.metadata.runCount());
}

test "runLabel: names both axes when both fan out" {
    const allocator = std.testing.allocator;

    const label = (try runLabel(allocator, .worker, 2, "?include=file")).?;
    defer allocator.free(label);
    try std.testing.expectEqualStrings("worker ?include=file", label);
}

test "runLabel: names the global alone when only globals fan out" {
    const allocator = std.testing.allocator;

    const label = (try runLabel(allocator, .window, 2, "")).?;
    defer allocator.free(label);
    try std.testing.expectEqualStrings("window", label);
}

test "runLabel: names the variant alone when only variants fan out" {
    const allocator = std.testing.allocator;

    // A plain .html file with variants has exactly one global, so naming it
    // would add "window" to every line of the scoreboard without telling any
    // two runs apart.
    const label = (try runLabel(allocator, .window, 1, "?include=file")).?;
    defer allocator.free(label);
    try std.testing.expectEqualStrings("?include=file", label);
}

test "runLabel: names nothing when the source runs once" {
    const allocator = std.testing.allocator;

    // The common case, and the reason this returns an optional: the display
    // name of a source that runs once should stay the bare path.
    try std.testing.expectEqual(@as(?[]const u8, null), try runLabel(allocator, .window, 1, ""));
}

test "runLabel: counts declared globals, not implemented ones" {
    const allocator = std.testing.allocator;

    // `global=window,sharedworker` fans out to two URLs in MANIFEST.json even
    // though only one of them runs here. Labelling on the declared count keeps
    // the window run named `[window]` in both the before and after of turning
    // sharedworker on, so its scoreboard line stays the same line.
    const label = (try runLabel(allocator, .window, 2, "")).?;
    defer allocator.free(label);
    try std.testing.expectEqualStrings("window", label);
}

// -----------------------------------------------------------------------------
// The global set a `.any.js` file declares, as upstream's manifest builds it
// (tests/wpt/tools/manifest/sourcefile.py: read_script_metadata, the first
// `global` key, parse_variants and _any_variants). MANIFEST.json lists one URL
// per global this yields, so the runner must run exactly these - the ones it
// implements - and no others.
// -----------------------------------------------------------------------------

/// The globals `content` declares for an `.any.js` file, by name, in order.
fn expectAnyGlobals(content: []const u8, expected: []const []const u8) !void {
    var parsed = try parseAnyJs(std.testing.allocator, "a/b.any.js", content);
    defer parsed.deinit();
    var names: std.ArrayListUnmanaged([]const u8) = .empty;
    defer names.deinit(std.testing.allocator);
    for (parsed.metadata.globals.items) |g| try names.append(std.testing.allocator, g.toString());
    std.testing.expectEqual(expected.len, names.items.len) catch |err| {
        for (names.items) |n| std.debug.print("declared: {s}\n", .{n});
        return err;
    };
    for (expected, names.items) |want, got| try std.testing.expectEqualStrings(want, got);
}

/// The globals of `content` the runner runs - the declared ones it implements.
fn expectAnyRuns(content: []const u8, expected: []const []const u8) !void {
    var parsed = try parseAnyJs(std.testing.allocator, "a/b.any.js", content);
    defer parsed.deinit();
    var names: std.ArrayListUnmanaged([]const u8) = .empty;
    defer names.deinit(std.testing.allocator);
    for (parsed.metadata.globals.items) |g| if (g.isImplemented()) try names.append(std.testing.allocator, g.toString());
    std.testing.expectEqual(expected.len, names.items.len) catch |err| {
        for (names.items) |n| std.debug.print("runs: {s}\n", .{n});
        return err;
    };
    for (expected, names.items) |want, got| try std.testing.expectEqualStrings(want, got);
}

test "META global: `//META:` with no space is a META line (Worker-constructor-proto.any.js)" {
    // upstream js_meta_re: //\s*META:\s*(\w*)=(.*)$
    const content =
        \\//META: global=worker
        \\test(() => {});
    ;
    try expectAnyGlobals(content, &.{ "worker", "sharedworker", "serviceworker" });
    // All three workers run, with no window run the file never asked for.
    try expectAnyRuns(content, &.{ "worker", "sharedworker", "serviceworker" });
    // And it is labelled: MANIFEST.json lists three URLs for the file, and an
    // unlabelled run took the first of them, `.any.serviceworker.html`
    // (wpt_test_ids.pickManifestUrl).
    var parsed = try parseAnyJs(std.testing.allocator, "workers/Worker-constructor-proto.any.js", content);
    defer parsed.deinit();
    const label = (try runLabel(std.testing.allocator, .worker, parsed.metadata.globals.items.len, "")).?;
    defer std.testing.allocator.free(label);
    try std.testing.expectEqualStrings("worker", label);
}

test "META global: whitespace around META: is optional, around = it is not" {
    try expectAnyGlobals("//   META:global=window\ntest(() => {});", &.{"window"});
    // `(\w*)=`: a space before `=` is no META line, so metadata ends there -
    // and a file whose metadata ends before any `global` gets the defaults.
    try expectAnyGlobals("// META: global = window\ntest(() => {});", &.{ "window", "worker" });
}

test "META global: worker is the dedicated, shared and service worker" {
    try expectAnyGlobals("// META: global=worker\n", &.{ "worker", "sharedworker", "serviceworker" });
    try expectAnyRuns("// META: global=worker\n", &.{ "worker", "sharedworker", "serviceworker" });
    try expectAnyGlobals("// META: global=window,worker\n", &.{ "window", "worker", "sharedworker", "serviceworker" });
    try expectAnyRuns("// META: global=window,worker\n", &.{ "window", "worker", "sharedworker", "serviceworker" });
    // Named once each, however often the longhand repeats them.
    try expectAnyGlobals("// META: global=dedicatedworker,worker,sharedworker\n", &.{ "worker", "sharedworker", "serviceworker" });
}

test "META global: each single global" {
    try expectAnyGlobals("// META: global=window\n", &.{"window"});
    try expectAnyGlobals("// META: global=dedicatedworker\n", &.{"worker"});
    try expectAnyGlobals("// META: global=sharedworker\n", &.{"sharedworker"});
    try expectAnyRuns("// META: global=sharedworker\n", &.{"sharedworker"});
    try expectAnyGlobals("// META: global=serviceworker\n", &.{"serviceworker"});
    try expectAnyRuns("// META: global=serviceworker\n", &.{"serviceworker"});
    try expectAnyGlobals("// META: global=dedicatedworker-module\n", &.{"dedicatedworker-module"});
    try expectAnyRuns("// META: global=dedicatedworker-module\n", &.{"dedicatedworker-module"});
    try expectAnyGlobals("// META: global=sharedworker-module\n", &.{"sharedworker-module"});
    try expectAnyRuns("// META: global=sharedworker-module\n", &.{"sharedworker-module"});
    try expectAnyGlobals("// META: global=serviceworker-module\n", &.{"serviceworker-module"});
    try expectAnyRuns("// META: global=serviceworker-module\n", &.{"serviceworker-module"});
    // worker-module has no longhand; its URL is the dedicated module
    // worker's (.any.worker-module.html).
    try expectAnyGlobals("// META: global=worker-module\n", &.{"dedicatedworker-module"});
    // window-module and jsshell are WPT globals Crane does not run: declared,
    // never run - not dropped (an empty list would be the defaults).
    try expectAnyGlobals("// META: global=window-module\n", &.{"window-module"});
    try expectAnyRuns("// META: global=window-module\n", &.{});
    try expectAnyGlobals("// META: global=window,dedicatedworker,jsshell\n", &.{ "window", "worker", "jsshell" });
    try expectAnyRuns("// META: global=window,dedicatedworker,jsshell\n", &.{ "window", "worker" });
}

test "META global: shadowrealm is its six variants, none of them run" {
    try expectAnyGlobals("// META: global=shadowrealm\n", &.{
        "shadowrealm-in-window",
        "shadowrealm-in-shadowrealm",
        "shadowrealm-in-dedicatedworker",
        "shadowrealm-in-sharedworker",
        "shadowrealm-in-serviceworker",
        "shadowrealm-in-audioworklet",
    });
    try expectAnyRuns("// META: global=shadowrealm\n", &.{});
    try expectAnyGlobals("// META: global=window,shadowrealm-in-window\n", &.{ "window", "shadowrealm-in-window" });
    try expectAnyRuns("// META: global=window,shadowrealm-in-window\n", &.{"window"});
}

test "META global: the defaults only when no global is declared, or it is empty" {
    try expectAnyGlobals("test(() => {});", &.{ "window", "worker" });
    try expectAnyGlobals("// META: global=\n", &.{ "window", "worker" });
    // Names WPT does not know make an empty set: nothing to run, and never
    // the defaults (docs/lessons/testing-an-unknown-meta-global-is-dropped-not-skipped.md).
    try expectAnyGlobals("// META: global=nonsense\n", &.{});
    try expectAnyRuns("// META: global=nonsense\n", &.{});
}

test "META global: only the first global line counts" {
    try expectAnyGlobals("// META: global=window\n// META: global=dedicatedworker\n", &.{"window"});
}

test "META: metadata ends at the first line that is not a META line" {
    // A blank line or a plain comment ends it (read_script_metadata breaks
    // on the first non-matching line): what follows is not metadata.
    try expectAnyGlobals("// A comment.\n// META: global=window\n", &.{ "window", "worker" });
    try expectAnyGlobals("\n// META: global=window\n", &.{ "window", "worker" });
    try expectAnyGlobals(" // META: global=window\n", &.{ "window", "worker" });
    var metadata = try parseMetaComments(std.testing.allocator,
        \\// META: script=/a.js
        \\
        \\// META: timeout=long
        \\// META: variant=?x
    );
    defer metadata.deinit();
    try std.testing.expectEqual(@as(usize, 1), metadata.scripts.items.len);
    try std.testing.expectEqual(config.Timeout.normal, metadata.timeout);
    try std.testing.expectEqual(@as(usize, 0), metadata.variants.items.len);
}

test "META: a CRLF line's value has no carriage return" {
    var metadata = try parseMetaComments(std.testing.allocator, "// META: variant=?a\r\n// META: timeout=long\r\n// META: global=window\r\n");
    defer metadata.deinit();
    try std.testing.expectEqualStrings("?a", metadata.variants.items[0]);
    try std.testing.expectEqual(config.Timeout.long, metadata.timeout);
    try std.testing.expectEqual(@as(usize, 1), metadata.globals.items.len);
}
