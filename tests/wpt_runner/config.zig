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

    /// What to pass as `setup({timeout_multiplier: N})` so testharness.js
    /// arms its own timeout at this budget.
    ///
    /// testharness.js decides its harness timeout for itself, in
    /// `WindowTestEnvironment.test_timeout()`, by walking
    /// `document.getElementsByTagName("meta")` for `name=timeout`. In a
    /// browser that runs when the document above the `<script>` already
    /// exists. The runner installs testharness.js *before* the page is
    /// fetched - `loadTestHarness` then `loadPageWithOptions` - so that walk
    /// always runs over an empty document, never finds the meta, and always
    /// returns `settings.harness_timeout.normal`.
    ///
    /// So a `<meta name="timeout" content="long">` file got a 60s ceiling from
    /// the runner and a 10s one from the harness, and the harness always won:
    /// it fired at 10s, called `complete()`, and the file was recorded TIMEOUT
    /// with whatever it had - usually nothing. 68 of the 664 sources under
    /// html/browsers declare `long`, and every one of them was cut to a sixth
    /// of its budget.
    ///
    /// `timeout_multiplier` is testharness's own supported knob for a slow
    /// host, and it multiplies exactly the value the meta lookup should have
    /// produced. Injecting it is what puts the two clocks back in agreement.
    pub fn harnessMultiplier(self: Timeout) u32 {
        return switch (self) {
            .normal => 1,
            .long => 6,
        };
    }
};

/// `Timeout.harnessMultiplier` for a budget that has already been flattened to
/// milliseconds.
///
/// The browser layer carries the per-file ceiling as a `u64` rather than the
/// enum, and rounding is the safe direction: a multiplier below 1 would arm
/// the harness *inside* the runner's ceiling and reintroduce the very
/// disagreement this exists to remove.
pub fn harnessMultiplierForMillis(millis: u64) u32 {
    const base = Timeout.normal.toMillis();
    const n = millis / base;
    if (n < 1) return 1;
    return @intCast(n);
}

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
    .{ .name = "webidl", .description = "WebIDL bindings" },
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
    // WPT infrastructure tests (excluded from regular runs, run with `zig build wpt -- infrastructure/`)
    "/infrastructure/",
    "/.well-known/",
    // Reference tests (visual comparison)
    "-ref.html",
    "-ref.htm",
    // Print tests
    "/print/",
    // Tentative/experimental tests (proposed features not yet in specs)
    "/tentative/",
    ".tentative.",

    // ==========================================================================
    // WPT Infrastructure Test Exclusions
    // These patterns exclude tests that require protocols/infrastructure beyond
    // the current WPT runner capabilities. Applies when running infrastructure/
    // ==========================================================================

    // WebDriver BiDi protocol tests (12 failures)
    // BiDi requires WebSocket-based bidirectional browser automation protocol
    // (~5000+ LOC) for features like real-time subscriptions, emulation, bluetooth.
    // Spec: https://w3c.github.io/webdriver-bidi/
    "bidi/",
    "webdriver/bidi/",

    // HTTP/3 (QUIC) / WebTransport tests (2 failures)
    // Requires curl built with HTTP/3 support (ngtcp2+nghttp3 or quiche)
    // and wpt serve configured with H3 endpoint.
    // curl_ffi.zig has CURL_HTTP_VERSION_3 ready for future enablement.
    "-h3.",
    "webtransport-h3",

    // WPT's own browser-driver test (1 failure)
    // infrastructure/browsers/ exercises geckodriver/chromedriver launching,
    // which is browser automation rather than a web platform API.
    //
    // Anchored at `infrastructure/`. These patterns are matched with `indexOf`,
    // so the bare `browsers/` this used to be was a substring rule that also
    // matched all 701 `html/browsers/` sources - the entire browsing-contexts
    // corpus, silently, while `isInScope` looked right because `html` matched.
    "infrastructure/browsers/",

    // Proxy Auto-Config (PAC) tests (1 failure)
    // PAC requires: PAC file fetching, JS evaluation per-request, proxy routing.
    // Significant infrastructure (~500-1000 LOC) for non-web-platform feature.
    "server/test-pac",

    // File upload tests (1 failure)
    // Requires server-side Python execution for form POST handling.
    // The WPT server needs to execute .py files, not just serve them.
    "testdriver/file_upload",

    // Media autoplay tests (2 failures)
    // Requires actual HTMLMediaElement implementation with play/pause state.
    // Our polyfill doesn't fully intercept the native element behavior.
    "assumptions/allowed-to-play",

    // ==========================================================================
    // WPT Infrastructure Helper Files (not standalone tests)
    // These are loaded by parent tests with specific parameters (uuid, etc.)
    // ==========================================================================

    // Channel test helpers - loaded via window.open/iframe with ?uuid= parameter
    "channels/child_message.html",
    "channels/child_script.html",
    "channels/serialize_child.html",
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
///
/// Accepts both "dom/nodes/foo.html" and "/dom/nodes/foo.html". The category
/// must match a whole leading path segment: "dom" matches "dom/nodes/foo.html"
/// but not "domparsing/foo.html".
pub fn isInScope(path: []const u8) bool {
    const rel = if (path.len > 0 and path[0] == '/') path[1..] else path;

    for (in_scope_categories) |cat| {
        if (!cat.enabled) continue;
        if (rel.len > cat.name.len and
            std.mem.startsWith(u8, rel, cat.name) and
            rel[cat.name.len] == '/')
        {
            return !isExcluded(path);
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

test "the harness multiplier reproduces the budget the meta lookup would have" {
    const testing = std.testing;

    // testharness.js starts from `settings.harness_timeout.normal`, which is
    // the same 10s this enum calls `normal`. The multiplier has to carry it to
    // exactly the runner's own ceiling, or the two clocks disagree again in
    // the other direction and the harness outlives the runner.
    const harness_base = Timeout.normal.toMillis();

    try testing.expectEqual(@as(u32, 1), Timeout.normal.harnessMultiplier());
    try testing.expectEqual(
        Timeout.normal.toMillis(),
        harness_base * Timeout.normal.harnessMultiplier(),
    );

    try testing.expectEqual(@as(u32, 6), Timeout.long.harnessMultiplier());
    try testing.expectEqual(
        Timeout.long.toMillis(),
        harness_base * Timeout.long.harnessMultiplier(),
    );
}

test "the millisecond form agrees with the enum form" {
    const testing = std.testing;

    try testing.expectEqual(
        Timeout.normal.harnessMultiplier(),
        harnessMultiplierForMillis(Timeout.normal.toMillis()),
    );
    try testing.expectEqual(
        Timeout.long.harnessMultiplier(),
        harnessMultiplierForMillis(Timeout.long.toMillis()),
    );

    // Never below 1. A budget shorter than the harness's own 10s floor must
    // still leave the harness at its floor, not arm it early - the runner's
    // ceiling is what ends such a file, and a harness firing first would take
    // the subtest results away with it.
    try testing.expectEqual(@as(u32, 1), harnessMultiplierForMillis(0));
    try testing.expectEqual(@as(u32, 1), harnessMultiplierForMillis(1));
    try testing.expectEqual(@as(u32, 1), harnessMultiplierForMillis(9_999));
}

test "every timeout has a multiplier that lands on its own budget" {
    const testing = std.testing;

    // Pins the relationship rather than the two known cases: a third Timeout
    // added later with a multiplier that does not divide out lands here
    // instead of in a sweep six weeks from now.
    const base = Timeout.normal.toMillis();
    inline for (@typeInfo(Timeout).@"enum".fields) |field| {
        const t: Timeout = @enumFromInt(field.value);
        try testing.expectEqual(t.toMillis(), base * t.harnessMultiplier());
    }
}

test "the browsers/ exclusion names infrastructure, not html/browsers" {
    const testing = std.testing;

    // `isExcluded` matches with `indexOf`, so every entry in
    // `exclusion_patterns` is a substring rule over the whole path. The rule
    // that meant to drop WPT's own `infrastructure/browsers/` driver test was
    // written as the bare `browsers/`, and that substring also occurs in all
    // 701 `html/browsers/` sources - browsing contexts, window.open, history,
    // location, origin. The entire browsing-contexts corpus was out of scope
    // and `wpt_runner html/browsers/...` reported "Found 0 test files", while
    // `isInScope` still looked right because the `html` category matched.
    try testing.expect(isInScope("html/browsers/windows/browsing-context-window.html"));
    try testing.expect(isInScope("html/browsers/history/the-location-interface/location_hash.html"));
    try testing.expect(isInScope("html/browsers/the-window-object/open-close/open-features-tokenization.html"));
    try testing.expect(isInScope("html/browsers/browsing-the-web/navigating-across-documents/003.html"));
    try testing.expect(isInScope("html/browsers/origin/cross-origin-objects/cross-origin-objects.html"));

    // The one source the rule was written for stays excluded.
    try testing.expect(isExcluded("infrastructure/browsers/browser-test.html"));
    try testing.expect(!isInScope("infrastructure/browsers/browser-test.html"));
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

test "isInScope matches whole path segments, not prefixes" {
    const testing = std.testing;

    // Several WPT top-level directories share a prefix with an in-scope
    // category. Matching on the prefix alone pulls them into the corpus and
    // inflates the denominator.
    try testing.expect(!isInScope("domparsing/xmlserializer.html"));
    try testing.expect(!isInScope("domxpath/evaluate.html"));
    try testing.expect(!isInScope("encoding-detection/bug-1547595.html"));
    try testing.expect(!isInScope("html-aam/roles.html"));
    try testing.expect(!isInScope("html-longdesc/link-image.html"));
    try testing.expect(!isInScope("html-media-capture/capture_reflect.html"));

    // The genuine categories still match, in both URL forms.
    try testing.expect(isInScope("dom/nodes/Node-appendChild.html"));
    try testing.expect(isInScope("/dom/nodes/Node-appendChild.html"));
    try testing.expect(isInScope("encoding/textdecoder-fatal.any.js"));
    try testing.expect(isInScope("/html/dom/aria-attribute-reflection.html"));

    // urlpattern is in scope in its own right, not because it starts with url.
    try testing.expect(isInScope("urlpattern/urlpattern.any.js"));
}
