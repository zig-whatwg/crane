//! WPT Browser Adapter
//!
//! This module wraps the production Browser API from `src/browser/` and adds
//! WPT-specific functionality like testharness.js loading and test completion detection.
//!
//! ## Architecture
//!
//! ```
//! WptBrowser (this file)
//!     │
//!     ├── Uses Browser (src/browser/Browser.zig) for:
//!     │   - V8 isolate management (single isolate, multiple contexts)
//!     │   - Context creation with proper WebIDL bindings
//!     │   - Event loop with libuv timers
//!     │   - HTML parsing with script execution
//!     │
//!     └── Adds WPT-specific:
//!         - testharness.js loading
//!         - Test completion detection via add_completion_callback
//!         - Test result collection
//!         - Script loading from WPT root
//! ```
//!
//! ## Why This Exists
//!
//! The Browser API in `src/browser/` is a general-purpose headless browser.
//! WPT tests need additional functionality:
//! - Loading testharness.js before each test
//! - Detecting when tests complete (via completion callbacks)
//! - Collecting test results in a specific format
//! - Loading scripts relative to WPT root
//!
//! This adapter provides that functionality while delegating core browser
//! behavior to the production Browser implementation.

const std = @import("std");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const Context = browser_mod.Context;

const test_harness = @import("test_harness.zig");
const test_driver = @import("test_driver.zig");
const test_parser = @import("test_parser.zig");
const host = @import("host");
const config = @import("config.zig");
const wpt_server = @import("wpt_server.zig");
const clock = @import("clock");
/// The JavaScript engine, for one operation: abortRunningScript at a run's
/// ceiling (script_deadline.zig), when the engine has it.
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const script_deadline = @import("script_deadline.zig");
const host_media = @import("host_media.zig");

const log = std.log.scoped(.wpt_browser);

/// Default WPT test origin, used when no test URL is in hand.
///
/// Most tests run here, but a `.https.` test is fetched from
/// `https://web-platform.test:8443` (an `.h2.` one from :9000) and must be
/// told so — see `originOfUrl`.
const WPT_ORIGIN = "http://web-platform.test:8000";

const originOfUrl = wpt_server.originOfUrl;

/// Apply WPT URL rewrites (matching wpt serve behavior from tools/serve/serve.py)
/// These rewrites map friendly URLs to the actual file locations
fn applyWptRewrites(url: []const u8) []const u8 {
    // WebIDLParser.js -> webidl2.js (the actual file location)
    if (std.mem.eql(u8, url, "/resources/WebIDLParser.js")) {
        return "/resources/webidl2/lib/webidl2.js";
    }
    // Add more rewrites here as needed (from tools/serve/serve.py and tools/wpt/testfiles.py)
    return url;
}

/// WPT Browser - wraps Browser API with WPT-specific functionality
pub const WptBrowser = struct {
    allocator: std.mem.Allocator,
    /// Underlying browser instance (manages V8 isolate and event loop)
    browser: *Browser,
    /// WPT root directory for loading scripts
    wpt_root: []const u8,
    /// Cached testharness.js content
    testharness_js: ?[]const u8,
    /// Cached testharnessreport.js content
    testharnessreport_js: ?[]const u8,
    /// Number of tests run
    tests_run: usize,
    /// testdriver.js's automation backend (the WebDriver remote end), whose
    /// natives the vendor file wires into each test realm.
    test_driver: *test_driver.TestDriver,
    /// Ends script still running past a run's ceiling (script_deadline.zig):
    /// its thread runs only where the engine can abort a running script.
    script_deadline: script_deadline.ScriptDeadline = .{ .abort = abortAgentScript },

    /// Initialize WptBrowser with a fresh Browser instance
    pub fn init(allocator: std.mem.Allocator, wpt_root: []const u8) !*WptBrowser {
        const self = try allocator.create(WptBrowser);
        errdefer allocator.destroy(self);

        // Trust WPT's certificate authority, so `.https.` tests can be fetched
        // from :8443 at all. `wpt serve` signs its leaf certificate with a CA
        // it generates itself; nothing in the system trust store knows it.
        // The Browser's network context copies the path.
        const ca = try wptCertificateAuthority(allocator, wpt_root);
        defer if (ca) |path| allocator.free(path);

        // Create the underlying browser (manages V8 isolate)
        const browser_instance = try Browser.init(allocator, .{
            .log_performance = true,
            // The runner is a host, and supplies media decoding as one: WAV
            // linear PCM and WebM (VP8/VP9, Vorbis/Opus), which it really
            // reads (host_media.zig). Crane itself builds in no decoder.
            .media_backend = host_media.backend,
            .ca_bundle_path = ca,
        });
        errdefer browser_instance.deinit();

        const driver = try test_driver.TestDriver.create(allocator);
        errdefer driver.destroy();

        self.* = WptBrowser{
            .allocator = allocator,
            .browser = browser_instance,
            .wpt_root = try allocator.dupe(u8, wpt_root),
            .testharness_js = null,
            .testharnessreport_js = null,
            .tests_run = 0,
            .test_driver = driver,
        };
        if (comptime engine.capabilities.script_abort != .unsupported) try self.script_deadline.start();

        // A Web Worker's blob: script is resolved by fetch's scheme fetch
        // "blob", whose resolver crane.Process installs at start - on every
        // thread, a nested worker's too.

        // Frame and popup documents get the testdriver vendor file too - the
        // embedder's hook, registered once here, before any page loads.
        try test_driver.registerForFrames(self.test_driver, browser_instance.scope);
        errdefer test_driver.unregisterForFrames(browser_instance.scope);

        // Pre-load testharness.js for efficiency
        self.testharness_js = self.loadWptScript("resources/testharness.js") catch null;
        self.testharnessreport_js = self.loadWptScript("resources/testharnessreport.js") catch null;

        return self;
    }

    /// WPT's own certificate authority, for the Browser to trust: its path
    /// (OWNED), or null if the checkout has none.
    ///
    /// Only adds a CA; it does not relax verification. A `.https.` test served
    /// with a certificate this CA did not sign should still fail, because that
    /// is a real defect in the server, not in the test.
    fn wptCertificateAuthority(allocator: std.mem.Allocator, wpt_root: []const u8) !?[]u8 {
        const ca = try std.fs.path.join(allocator, &.{ wpt_root, "tools/certs/cacert.pem" });
        host.cwd().access(host.io(), ca, .{}) catch |err| {
            // Not fatal: a run that touches no `.https.` test never needs it.
            log.warn("no WPT certificate authority at {s} ({}); .https. tests will fail to connect", .{ ca, err });
            allocator.free(ca);
            return null;
        };
        return ca;
    }

    /// Cleanup
    pub fn deinit(self: *WptBrowser) void {
        // Before the agent goes: the thread holds its address.
        _ = self.endScriptDeadline();
        self.script_deadline.stop();

        // Pending testdriver commands give their promises back while the
        // engine is still up.
        test_driver.unregisterForFrames(self.browser.scope);
        self.test_driver.destroy();

        if (self.testharness_js) |js| {
            self.allocator.free(js);
        }
        if (self.testharnessreport_js) |js| {
            self.allocator.free(js);
        }
        self.allocator.free(self.wpt_root);
        self.browser.deinit();
        self.allocator.destroy(self);
    }

    /// Load a script from WPT root
    fn loadWptScript(self: *WptBrowser, relative_path: []const u8) ![]const u8 {
        const full_path = try std.fs.path.join(self.allocator, &.{ self.wpt_root, relative_path });
        defer self.allocator.free(full_path);

        // Use cwd-relative open since wpt_root may not be absolute
        const io = host.io();
        const script_file = host.cwd().openFile(io, full_path, .{}) catch |err| {
            log.warn("failed to open WPT script {s}: {}", .{ full_path, err });
            return err;
        };
        defer script_file.close(io);

        const stat = try script_file.stat(io);
        const content = try self.allocator.alloc(u8, stat.size);
        errdefer self.allocator.free(content);

        const bytes_read = try script_file.readPositionalAll(io, content, 0);
        if (bytes_read != stat.size) {
            return error.IncompleteRead;
        }

        return content;
    }

    /// Run a JavaScript test
    ///
    /// Creates a fresh context, loads testharness.js, executes the test,
    /// and waits for completion.
    pub fn runTest(
        self: *WptBrowser,
        test_path: []const u8,
        test_content: []const u8,
        timeout: config.Timeout,
        context_type: test_parser.GlobalType,
    ) !test_harness.TestResult {
        // Map GlobalType to Context.ContextType
        const ctx_type: Context.ContextType = switch (context_type) {
            .window => .window,
            .worker, .worker_module => .worker,
            .sharedworker, .sharedworker_module => .shared_worker,
            .serviceworker, .serviceworker_module => .service_worker,
            // ShadowRealm variants map to window for now
            else => .window,
        };

        // Build test URL
        const test_url = try self.buildTestUrl(test_path);
        defer self.allocator.free(test_url);

        // Each test file starts with an empty cookie jar, as with a fresh
        // profile: a run shares one Browser across every file in a shard, and
        // a file's result must not depend on the cookies the files before it
        // left behind.
        self.browser.cookie_jar.clear();

        // Navigate to create fresh context
        try self.browser.navigate(test_url, ctx_type);
        // Whatever testdriver commands the test left pending end with it,
        // before its page does.
        defer self.test_driver.endTest();

        // Get the context
        const ctx = self.browser.current_context orelse return error.NoContext;

        // Load testharness.js
        try self.loadTestHarness(ctx, timeout.explicitTimeout());

        // Execute the test script
        ctx.runScript(test_content) catch |err| {
            return test_harness.TestResult{
                .status = .@"error",
                .message = try std.fmt.allocPrint(self.allocator, "Script execution error: {}", .{err}),
                .subtests = .{},
                .duration_ms = 0,
            };
        };

        // Run event loop until test completes or timeout
        const timeout_ms = timeout.toMillis();
        const deadline = clock.monotonicMillis() + @as(i64, @intCast(timeout_ms));
        self.armScriptDeadline(deadline);
        const result = try self.waitForCompletion(ctx, deadline, timeout_ms, test_path);

        self.tests_run += 1;
        return result;
    }

    /// Run an HTML test via HTTP navigation
    ///
    /// Navigates to the test URL, fetches via HTTP, parses HTML, and executes scripts.
    /// This mimics real browser behavior where all content is fetched over the network.
    pub fn runHTMLTest(
        self: *WptBrowser,
        test_path: []const u8,
        test_url: []const u8,
        timeout_ms: u64,
        context_type: browser_mod.ContextType,
    ) !test_harness.TestResult {
        // The run's ceiling counts from its start, as wptrunner's per-URL
        // timeout does: the navigation, the parse and every script the parser
        // runs are inside it, and script still running past it is aborted
        // (script_deadline.zig). The wait for completion ends at the same
        // moment, so a slow load no longer buys a second full budget.
        const deadline = clock.monotonicMillis() + @as(i64, @intCast(timeout_ms));
        self.armScriptDeadline(deadline);
        defer _ = self.endScriptDeadline();

        // Phase clocks. `waitForCompletion` measures itself, but on a page of
        // synchronous subtests it starts after the work is already done, so on
        // its own it makes the most expensive files look free. Timing the two
        // phases ahead of it is what makes the per-file cost add up.
        // 0.15's std.time.Timer.start() could fail, so this was `catch null` and the
        // helpers below take a *?Timer. clock.Timer.start() is infallible, so the
        // optional is now explicit rather than incidental.
        var phase: ?clock.Timer = clock.Timer.start();

        // Each test file starts with an empty cookie jar, as runTest's do.
        self.browser.cookie_jar.clear();

        // A fresh top-level traversable for the file, on its initial
        // about:blank (HTML "create a new top-level traversable"), loaded
        // below by navigating it to the test URL - as wptrunner opens each
        // test in a browser's window.
        try self.browser.navigateWithOptions(test_url, context_type, .{
            .skip_load = true,
        });
        // Whatever testdriver commands the test left pending end with it,
        // before its page does.
        defer self.test_driver.endTest();

        // Get the context
        const ctx = self.browser.current_context orelse return error.NoContext;
        const explicit_timeout = config.explicitTimeoutForMillis(timeout_ms);
        // The harness loads where the page includes it, as in a browser
        // (`HarnessLoad`); a page that includes none gets it after its load.
        const harness_load = self.harnessLoadOf(test_path);
        // The harness can finish while parsing still waits on a sheet. The
        // run and the persistent parser hold independent context references.
        const loader_ctx = try self.allocator.create(ScriptLoaderContext);
        loader_ctx.* = .{ .allocator = self.allocator, .wpt_browser = self, .harness_load = harness_load, .explicit_timeout = explicit_timeout };
        defer ScriptLoaderContext.release(loader_ctx);

        // The fresh realm holds nothing of the previous file's harness. The
        // page's own includes load this one; a page with none gets it once
        // it has loaded (below). The page's document gets a Window of its
        // own when its navigation commits ("create and initialize a
        // Document object" step 7: the initial about:blank's origin is
        // opaque), so nothing put in the initial about:blank's realm would
        // reach the page - no browser keeps it either.
        try self.checkFreshRealm(ctx);

        const nav_ms = lapMs(&phase);

        // The page's load: HTML "navigate" of the traversable to the test
        // URL with user involvement "browser UI" - the fetch, the commit and
        // the parse, with its scripts, as the navigation's tasks, waited for
        // within the run's ceiling. The script loader answers for the
        // harness's includes in the page's document (scriptLoaderCallback).
        const left_ms: u64 = @intCast(@max(1, deadline - clock.monotonicMillis()));
        ctx.loadPageWithOptions(.{
            .script_loader = .{
                .context = loader_ctx,
                .loadScript = scriptLoaderCallback,
                .retain = &ScriptLoaderContext.retain,
                .release = &ScriptLoaderContext.release,
            },
            .timeout_ms = left_ms,
        }) catch |err| {
            // A load its ceiling aborted, or one still in flight when the
            // ceiling came, is a run that timed out: the wait below lets the
            // harness report what ran. Any other failure is the page's.
            if (!self.script_deadline.abortedThisRun() and err != error.NavigationTimedOut) {
                var result = try test_harness.TestResult.init(self.allocator, test_path);
                result.status = .@"error";
                result.message = try std.fmt.allocPrint(self.allocator, "Page load error: {}", .{err});
                result.nav_ms = nav_ms;
                result.load_ms = lapMs(&phase);
                return result;
            }
        };

        // A page whose parse reached no testharnessreport.js include - one
        // that names the harness without including it, includes only
        // testharness.js, or names none (`before_page`) - has the runner's
        // hook installed once its parse has ended, before the harness can
        // complete (it completes after the load event, from a task).
        //
        // Upstream wptrunner installs nothing after a page: it serves its
        // report at the include's path, and wpt lint rejects a testharness
        // page without that include (MISSING-TESTHARNESSREPORT). Crane's
        // runner keeps a late install because its results come only through
        // its own completion hook, and it runs pages that never reach the
        // hook from an include: Crane tests with no include
        // (crane/c6-harness-no-include.html), and sources that name the
        // harness in a form the script loader does not answer.
        //
        // "Reached no include" is known only once the parse has ended. The
        // load returns when its parser has run as far as it can, which may
        // be a parsing-blocking script still loading before the page's
        // includes (Context.LoadWait, a CDP Page.navigate-style settle
        // point that its callers rely on). Deciding there made a second
        // harness: the runner's, with no subtests, then the page's own at
        // its include. In a file that ends at the harness timeout, the
        // runner's copy armed its timer first and completed with nothing
        // (html/cross-origin-embedder-policy/reporting-to-frame-owner and
        // -worker-owner load get-host-info.sub.js before testharness.js:
        // no subtest reported in 6-9 of 10 fresh runs; lane coi2 batch 3,
        // crane/coi2-harness-after-pending-script.html). So the runner
        // spins the event loop until HTML "the end" step 1 has set the
        // document's readiness to "interactive", within the run's ceiling,
        // and installs nothing for a parse that never ends: no browser runs
        // a harness its page never reached.
        if (!self.harnessHookInstalled(ctx) and self.waitForParseEnd(ctx, deadline) and !self.harnessHookInstalled(ctx)) {
            self.installHarnessLate(ctx, explicit_timeout) catch |err| {
                log.warn("runHTMLTest: could not install the harness after the page: {}", .{err});
            };
        }

        const load_ms = lapMs(&phase);

        // Run event loop until test completes or timeout
        var result = try self.waitForCompletion(ctx, deadline, timeout_ms, test_path);
        result.nav_ms = nav_ms;
        result.load_ms = load_ms;

        self.tests_run += 1;
        return result;
    }

    /// What `waitForParseEnd` waits for: the page's document is past
    /// readiness "loading" - HTML "the end" step 1 has run, so its parser
    /// has reached the end of its input (and every include in it) - or the
    /// page has no document. Read natively, as Context.LoadWait reads it: a
    /// spin's goal runs no script.
    const ParseEnd = struct {
        ctx: *Context,

        fn met(opaque_self: *anyopaque) bool {
            const self: *ParseEnd = @ptrCast(@alignCast(opaque_self));
            const document = self.ctx.document_instance orelse return true;
            const state = interfaces.Document.get_readyState(document) catch return true;
            return state != ._loading_;
        }
    };

    /// Run the page's event loop until its parse has ended (`ParseEnd`) or
    /// the run's ceiling `deadline` (clock.monotonicMillis) passes. Whether
    /// the parse ended.
    fn waitForParseEnd(self: *WptBrowser, ctx: *Context, deadline: i64) bool {
        var goal: ParseEnd = .{ .ctx = ctx };
        if (ParseEnd.met(&goal)) return true;
        const now = clock.monotonicMillis();
        if (now >= deadline) return false;
        const outcome = self.browser.spinEventLoopUntil(.{ .context = &goal, .met = ParseEnd.met }, @intCast(deadline - now)) catch |err| {
            log.warn("runHTMLTest: could not wait for the page's parse to end: {}", .{err});
            return ParseEnd.met(&goal);
        };
        return outcome == .met;
    }

    /// Milliseconds since the timer was last lapped, and reset it.
    ///
    /// Null timers report zero rather than failing the run: losing a phase
    /// breakdown is not worth losing a test result over.
    fn lapMs(timer: *?clock.Timer) u64 {
        // Capture by pointer: `timer.* orelse ...` would lap a copy and the
        // next phase would be measured from the wrong origin.
        if (timer.*) |*t| return t.lap() / std.time.ns_per_ms;
        return 0;
    }

    /// Where a run's harness loads (`runHTMLTest`).
    ///
    /// `at_include`: where the page includes it, as in a browser. The page's
    /// own `<script src="/resources/testharness.js">` runs the harness, and
    /// its `<script src="/resources/testharnessreport.js">` runs the runner's
    /// hooks (`runnerReportSource`) in place of the stock report - upstream
    /// wptrunner's model: it serves its own testharnessreport.js at that path
    /// (tools/wptrunner/wptrunner/environment.py `get_routes`, the
    /// "/resources/testharnessreport.js" route over executors/message-queue.js
    /// and wptrunner/testharnessreport.js, whose `setup(props)` and
    /// `add_completion_callback` are what `runnerReportSource` does here) and
    /// preloads nothing. So script before the include runs without the
    /// harness, and what the harness reads of the document - `<meta
    /// name=timeout>` - is there when it loads.
    /// content-security-policy/generic/generic-0_8_1.sub.html calls
    /// async_test() before its include: every browser throws a ReferenceError
    /// there (wpt.fyi 2026-11-02, Chrome 156 / Firefox 159 / Safari 27.2: one
    /// subtest, "Wildcard host matching works.", PASS), where a harness loaded
    /// before the page ran the rest of that script and raced its async
    /// script against the parser.
    ///
    /// `before_page`: a page whose source names no testharness.js - one the
    /// runner still runs as a testharness test - gets the harness once its
    /// load has parsed it (`installHarnessLate`). It got it before the page
    /// until lane loadpath1, in the realm of the traversable's initial
    /// about:blank document, which the page's own document now replaces with
    /// a Window of its own ("create and initialize a Document object" step
    /// 7), as in every browser. No worklist file is one: the seven whose
    /// source has no ASCII "testharness.js" name it in UTF-16 (2026-11-05).
    const HarnessLoad = test_harness.HarnessLoad;

    /// Script loader context for HTML parsing
    const ScriptLoaderContext = struct {
        allocator: std.mem.Allocator,
        wpt_browser: *WptBrowser,
        /// Where this run's harness loads.
        harness_load: HarnessLoad,
        /// Whether the run's budget is the runner's (`runnerReportSource`).
        explicit_timeout: bool,
        references: usize = 1,

        fn retain(context: ?*anyopaque) void {
            const self: *ScriptLoaderContext = @ptrCast(@alignCast(context.?));
            self.references += 1;
        }

        fn release(context: ?*anyopaque) void {
            const self: *ScriptLoaderContext = @ptrCast(@alignCast(context.?));
            self.references -= 1;
            if (self.references == 0) self.allocator.destroy(self);
        }
    };

    /// The embedder's script loader for the parser: it answers for
    /// testharness.js and testharnessreport.js, and for testdriver's vendor
    /// file.
    ///
    /// A run whose harness loads at the page's include (`HarnessLoad`) gets
    /// the cached testharness.js at the first, and the runner's own report
    /// at the second. A `before_page` run gets empty scripts for both: its
    /// harness is the runner's to load, once (`installHarnessLate`) - running
    /// it twice would make a new Tests object and lose the runner's
    /// completion callback.
    ///
    /// Every other script returns null, so the engine fetches it with HTML's
    /// "fetch a classic script": a request with destination "script", the
    /// element's CORS mode and credentials, and the document's origin and
    /// referrer, resolved against the document base URL. This used to fetch
    /// every parser-inserted script itself - through navigation.fetchUrl, with
    /// no destination, relative to the test file's path - so no WPT page's
    /// `<script src>` ever reached Fetch's MIME type and nosniff checks, a
    /// `<base href>` was ignored, and a data: URL was fetched as a path. (The
    /// WebIDLParser.js -> webidl2.js rewrite it applied is wpt serve's own.)
    fn scriptLoaderCallback(ctx_ptr: ?*anyopaque, url: []const u8) ?[]const u8 {
        const loader_ctx: *const ScriptLoaderContext = @ptrCast(@alignCast(ctx_ptr orelse return null));
        const self = loader_ctx.wpt_browser;
        // The realm of the document whose parser asks: the page's, as its
        // navigation's commit made it - read now, not when the run began
        // (the page's document has a Window of its own).
        const realm = (self.browser.current_context orelse return null).realm orelse return null;
        if (!realm.hasEngine()) return null;

        const is_harness = std.mem.eql(u8, url, "/resources/testharness.js");
        const is_report = std.mem.eql(u8, url, "/resources/testharnessreport.js");
        if (is_harness or is_report) switch (loader_ctx.harness_load) {
            .at_include => {
                // The harness itself, as wpt serve would answer; a runner
                // with none cached lets the engine fetch it.
                if (is_harness) return self.allocator.dupe(u8, self.testharness_js orelse return null) catch null;
                return runnerReportSource(self.allocator, loader_ctx.explicit_timeout) catch null;
            },
            .before_page => {
                log.debug("scriptLoaderCallback: skipping {s} (already loaded)", .{url});
                // An empty script, so the element still runs and fires load.
                return self.allocator.dupe(u8, "// Already loaded by WPT runner") catch null;
            },
        };
        // testdriver.js's vendor hook: Crane's, with its natives defined on
        // the test realm first (test_driver.zig).
        if (std.mem.eql(u8, url, test_driver.vendor_path)) {
            self.test_driver.defineNatives(realm);
            return self.allocator.dupe(u8, test_driver.vendor_js) catch null;
        }
        return null;
    }

    /// Where the harness loads for the test at `test_path`: from its file's
    /// source (test_harness.harnessLoadFor).
    fn harnessLoadOf(self: *WptBrowser, test_path: []const u8) HarnessLoad {
        const path = test_harness.sourcePathOf(test_path);
        if (std.mem.endsWith(u8, path, ".js")) return test_harness.harnessLoadFor(path, null);
        const source = self.loadWptScript(path) catch return test_harness.harnessLoadFor(path, null);
        defer self.allocator.free(source);
        return test_harness.harnessLoadFor(path, source);
    }

    /// The report the runner serves at a page's testharnessreport.js
    /// include (`HarnessLoad.at_include`): `runnerReportSource`, with the
    /// runner's budget when it is the runner's. OWNED.
    ///
    /// A realm with no harness (a page that included the report alone) gets
    /// nothing: the hook is then installed after the page
    /// (`installHarnessLate`).
    fn runnerReportSource(allocator: std.mem.Allocator, explicit_timeout: bool) ![]u8 {
        return std.mem.concat(allocator, u8, &.{
            "if (typeof add_completion_callback === 'function') {\n",
            disable_output_js,
            if (explicit_timeout) explicit_timeout_js else "",
            completion_hook_js,
            "}\n",
        });
    }

    /// Turn off the harness's human-facing reporting. It is pure waste in a
    /// headless runner, and it is the single largest cost in the suite.
    ///
    /// One `setup({output: false})` disables two separate things, because
    /// testharness.js keeps two flags and this sets both:
    ///
    ///   `output.enabled` gates the results table. On completion the harness
    ///   renders one row per subtest into `#log` - a `<tr>`, three `<td>`, a
    ///   `<pre>`, and, even for a test that ran no asserts, a `<details>`/
    ///   `<summary>`/`<table>` plus two querySelector calls. A dozen-odd DOM
    ///   operations each, every one crossing into Zig at roughly 75us.
    ///   Measured on a page of trivial subtests: 2.16ms per subtest, against
    ///   0.069ms to register and run one. 31x more time spent describing the
    ///   results than producing them.
    ///
    ///   `tests.output` gates per-assertion bookkeeping in `expose_assert`,
    ///   which wraps every `assert_*`. It pushes an AssertRecord, and in its
    ///   `finally` calls `get_stack()` - `new Error().stack`, split into
    ///   lines, matched against a RegExp built fresh each time - on *passing*
    ///   assertions too, since a pass leaves `stack` null.
    ///
    /// Nothing reads either one. `asserts_run` is consumed only by
    /// `Output.show_results`; results come back through `__wpt_results`,
    /// built by the completion callback (`completion_hook_js`), whose
    /// signature is `(tests, harness_status)` - it never even receives the
    /// assert records. The context is destroyed immediately afterwards.
    ///
    /// Only the table is measured above; the assertion path is extra, and is
    /// the likeliest reason real files run ~8.6ms/subtest where the trivial
    /// fixtures run 2.16 - those fixtures have empty bodies and assert
    /// nothing. Failure reporting is untouched: on a throw `expose_assert`
    /// takes the stack from the exception, outside the flag.
    ///
    /// This is the mechanism upstream intends for exactly this - wptrunner
    /// ships its own testharnessreport.js that does the same. The stock one
    /// only reads `window.opener.testharness_properties`, and there is no
    /// opener here, so the runner has to say it. `Output.prototype.setup`
    /// ands its flag rather than assigning, so a test calling
    /// `setup({output: true})` later cannot switch the table back on. (The
    /// assertion flag *is* a plain assignment, so such a test would resume
    /// paying for stacks - correct behaviour, and vanishingly rare.)
    ///
    /// Not fatal when it throws: the table is a waste of time, not a
    /// correctness requirement, and a result is worth more than the
    /// speed-up.
    const disable_output_js =
        \\  try { setup({ output: false }); } catch (e) { console.log('[wpt runner] could not disable harness output: ' + e); }
        \\
    ;

    /// A budget that is the runner's, not the harness's.
    ///
    /// `WindowTestEnvironment.test_timeout()` walks the document's <meta>
    /// elements for `name=timeout` when testharness.js runs: before the
    /// document, for a harness loaded before the page, it sees nothing - and
    /// every file, including the ones that declare `content="long"`, would
    /// get the 10s default, which fires first and ends a 60s file at 10s;
    /// at its include, it misses a meta that comes after. An explicit timeout
    /// leaves the harness with no timer of its own: `waitForCompletion` calls
    /// its `timeout()` at the runner's ceiling instead.
    ///
    /// Not `timeout_multiplier`: testharness scales `step_timeout` by it
    /// too, so a `long` file's own waits ran six times longer - see
    /// `config.Timeout.explicitTimeout`.
    ///
    /// Skipped for the harness default: `setup()` moves the harness into
    /// its SETUP phase, and there is no reason to do that to the ~90% of
    /// files whose budget is already the harness's own. Not fatal either: a
    /// file running on the short budget is worth more than no result at all.
    const explicit_timeout_js =
        \\  try { setup({ explicit_timeout: true }); } catch (e) { console.log('[wpt runner] could not set an explicit timeout: ' + e); }
        \\
    ;

    /// The completion callback that captures the results
    /// (`collectResults`, `isComplete`).
    const completion_hook_js =
        \\(function() {
        \\  // Register completion callback
        \\  add_completion_callback(function(tests, harness_status) {
        \\    try {
        \\      window.__wpt_results = {
        \\        status: harness_status ? harness_status.status : 0,
        \\        message: harness_status ? (harness_status.message || null) : null,
        \\        tests: (tests || []).map(function(t) {
        \\          return {
        \\            name: t.name,
        \\            status: t.status,
        \\            message: t.message || null
        \\          };
        \\        })
        \\      };
        \\    } catch (e) {
        \\      window.__wpt_results = { status: 1, message: e.toString(), tests: [] };
        \\    }
        \\    window.__wpt_complete = true;
        \\  });
        \\  // Store test results for collection: there once the callback is
        \\  // (`harnessHookInstalled`).
        \\  window.__wpt_results = null;
        \\  window.__wpt_complete = false;
        \\})();
        \\
    ;

    /// Verify testharness.js loaded correctly by checking for its globals.
    /// This catches cases where testharness.js execution fails silently.
    const verify_harness_js =
        \\if (typeof test !== 'function' || typeof async_test !== 'function' ||
        \\    typeof promise_test !== 'function' || typeof setup !== 'function') {
        \\  throw new Error('testharness.js failed to load: globals not defined. ' +
        \\    'test=' + typeof test + ', async_test=' + typeof async_test +
        \\    ', promise_test=' + typeof promise_test + ', setup=' + typeof setup);
        \\}
        \\'GLOBALS_VERIFIED';
    ;

    /// No state of a previous file's harness in the fresh realm: a leak is
    /// logged.
    fn checkFreshRealm(self: *WptBrowser, ctx: *Context) !void {
        const leak_check =
            \\(function() {
            \\  var leaks = [];
            \\  if (typeof window.__wpt_complete !== 'undefined') leaks.push('__wpt_complete=' + window.__wpt_complete);
            \\  if (typeof window.__wpt_results !== 'undefined') leaks.push('__wpt_results exists');
            \\  if (typeof test === 'function') leaks.push('test() already defined');
            \\  if (typeof Tests !== 'undefined') leaks.push('Tests object exists');
            \\  if (leaks.length > 0) {
            \\    console.log('[LEAK DETECTED] Previous test state found: ' + leaks.join(', '));
            \\    return 'LEAKED: ' + leaks.join(', ');
            \\  }
            \\  return 'CLEAN';
            \\})();
        ;
        const leak_str = ctx.evaluateScriptToString(leak_check, self.allocator) catch |err| {
            log.warn("loadTestHarness: leak check error: {}", .{err});
            return err;
        };
        defer self.allocator.free(leak_str);
        // Only print if there's a leak
        if (!std.mem.eql(u8, leak_str, "CLEAN")) {
            log.warn("loadTestHarness: state leak detected: {s}", .{leak_str});
        }
    }

    /// Load testharness.js and testharnessreport.js into the context, before
    /// the page (`HarnessLoad.before_page`, and `runTest`'s scripts), with
    /// the runner's hooks.
    ///
    /// `explicit_timeout` is whether this file's budget is the runner's to
    /// enforce rather than the harness's (`explicit_timeout_js`).
    fn loadTestHarness(self: *WptBrowser, ctx: *Context, explicit_timeout: bool) !void {
        try self.checkFreshRealm(ctx);

        // Load testharness.js
        if (self.testharness_js) |js| {
            try ctx.runScript(js);
        } else {
            return error.TestHarnessNotFound;
        }

        // Load testharnessreport.js
        if (self.testharnessreport_js) |js| {
            try ctx.runScript(js);
        }

        try self.installRunnerHooks(ctx, explicit_timeout);
    }

    /// The runner's hooks in a realm whose harness has loaded: its output
    /// off, its budget when it is the runner's, and the completion callback.
    fn installRunnerHooks(self: *WptBrowser, ctx: *Context, explicit_timeout: bool) !void {
        ctx.runScript(verify_harness_js) catch |err| {
            log.err("testharness.js verification failed: {}", .{err});
            return error.TestHarnessLoadFailed;
        };
        const report = try runnerReportSource(self.allocator, explicit_timeout);
        defer self.allocator.free(report);
        try ctx.runScript(report);
    }

    /// Whether the runner's completion hook is in the page's realm.
    fn harnessHookInstalled(self: *WptBrowser, ctx: *Context) bool {
        const answer = ctx.evaluateScriptToString("typeof window.__wpt_complete !== 'undefined'", self.allocator) catch return false;
        defer self.allocator.free(answer);
        return std.mem.eql(u8, answer, "true");
    }

    /// For a page whose include did not reach the runner's report
    /// (`HarnessLoad.at_include`): the harness, if the page loaded none, and
    /// then the runner's hooks - after the page, which is all the runner can
    /// still do.
    fn installHarnessLate(self: *WptBrowser, ctx: *Context, explicit_timeout: bool) !void {
        const has_harness = blk: {
            const answer = try ctx.evaluateScriptToString("typeof add_completion_callback === 'function'", self.allocator);
            defer self.allocator.free(answer);
            break :blk std.mem.eql(u8, answer, "true");
        };
        if (!has_harness) {
            try ctx.runScript(self.testharness_js orelse return error.TestHarnessNotFound);
            if (self.testharnessreport_js) |js| try ctx.runScript(js);
        }
        try self.installRunnerHooks(ctx, explicit_timeout);
    }

    /// script_deadline's abort: HTML "abort a running script" in the page's
    /// agent. Runs on the deadline's thread.
    fn abortAgentScript(target: ?*anyopaque) void {
        if (comptime engine.capabilities.script_abort == .unsupported) return;
        const agent: *engine.Agent = @ptrCast(@alignCast(target orelse return));
        engine.abortRunningScript(agent);
    }

    /// Watch the run whose ceiling is `deadline_ms`: script still running past
    /// it is aborted (script_deadline.zig).
    fn armScriptDeadline(self: *WptBrowser, deadline_ms: i64) void {
        if (comptime engine.capabilities.script_abort == .unsupported) return;
        const agent = self.browser.agent orelse return;
        self.script_deadline.arm(agent, deadline_ms);
    }

    /// Stop watching the run. If its script was aborted, the agent runs script
    /// again from here (engine.resumeScripts) - for the harness's report, and
    /// for the next run. Whether it was aborted.
    fn endScriptDeadline(self: *WptBrowser) bool {
        if (comptime engine.capabilities.script_abort == .unsupported) return false;
        const aborts = self.script_deadline.disarm();
        if (aborts == 0) return false;
        if (self.browser.agent) |agent| engine.resumeScripts(agent);
        return true;
    }

    /// A run whose script was aborted at its ceiling reached that ceiling: it
    /// is TIMEOUT, whatever the harness made of the abort (an aborted script
    /// can reach it as an uncaught error, which it reports as ERROR). The
    /// subtests it reported stay.
    fn markAborted(self: *WptBrowser, result: *test_harness.TestResult, timeout_ms: u64) !void {
        result.status = .timeout;
        if (result.message) |old| self.allocator.free(old);
        result.message = try std.fmt.allocPrint(self.allocator, "Test timed out after {}ms; script still running at the ceiling was aborted", .{timeout_ms});
    }

    /// How long `waitForCompletion` waits, past the ceiling, for a harness told
    /// to time out to report.
    const timeout_grace_ms: i64 = 2_000;

    /// Wait for test completion with proper blocking.
    ///
    /// This uses the new blocking event loop to efficiently wait for test completion.
    /// The test signals completion by setting `window.__wpt_complete = true`.
    ///
    /// @param ctx The browser context
    /// @param timeout_ms Maximum time to wait for completion
    /// @param test_path Test path for error reporting
    /// @return TestResult with test results or timeout status
    fn waitForCompletion(self: *WptBrowser, ctx: *Context, deadline: i64, timeout_ms: u64, test_path: []const u8) !test_harness.TestResult {
        const start_time = clock.monotonicMillis();
        // The run is armed from its start (runHTMLTest); nothing more of it
        // completes normally once its script has been aborted.
        defer _ = self.endScriptDeadline();

        // Polling interval for completion check
        // With proper blocking, we can use a longer interval while still being responsive
        // to timer events (blocking wakes on timer fire)
        const check_interval_ms: u64 = 50;

        while (true) {
            const now = clock.monotonicMillis();
            if (now >= deadline) break;
            if (self.script_deadline.abortedThisRun()) break;

            // Calculate how long to block
            const remaining: u64 = @intCast(deadline - now);
            const wait_time = @min(remaining, check_interval_ms);

            // Block on event loop - this runs timer callbacks, I/O, etc.
            // Uses efficient libuv blocking, waking when timers fire
            _ = self.browser.runEventLoopBlocking(wait_time) catch {};

            // Check if test is complete
            if (self.isComplete(ctx)) {
                const aborted = self.endScriptDeadline();
                var result = try self.collectResults(ctx, start_time, test_path);
                if (aborted) try self.markAborted(&result, timeout_ms);
                return result;
            }
        }

        // The ceiling. A file under an explicit timeout has no harness timer
        // of its own, and `timeout()` is how the harness learns its budget is
        // spent: it completes, reporting every subtest that ran and the rest
        // as TIMEOUT or NOTRUN. A file on the harness's own timer ignores the
        // call. The grace is for completion callbacks queued behind it, and it
        // is bounded the same way: script still running past it is aborted.
        const aborted = self.endScriptDeadline();
        const grace_deadline = clock.monotonicMillis() + timeout_grace_ms;
        self.armScriptDeadline(grace_deadline);
        ctx.runScript("if (typeof timeout === 'function') timeout();") catch {};
        while (true) {
            if (self.isComplete(ctx)) {
                const aborted_in_grace = self.endScriptDeadline();
                var result = try self.collectResults(ctx, start_time, test_path);
                if (aborted or aborted_in_grace) try self.markAborted(&result, timeout_ms);
                return result;
            }
            const now = clock.monotonicMillis();
            if (now >= grace_deadline or self.script_deadline.abortedThisRun()) break;
            _ = self.browser.runEventLoopBlocking(@min(@as(u64, @intCast(grace_deadline - now)), check_interval_ms)) catch {};
        }
        _ = self.endScriptDeadline();

        // Timeout
        const duration = @as(u64, @intCast(clock.monotonicMillis() - start_time));
        var result = try test_harness.TestResult.init(self.allocator, test_path);
        result.status = .timeout;
        result.message = try std.fmt.allocPrint(self.allocator, "Test timed out after {}ms", .{timeout_ms});
        result.duration_ms = duration;
        return result;
    }

    /// Whether the harness has completed: `window.__wpt_complete` is true
    /// (the boolean, nothing merely truthy).
    fn isComplete(self: *WptBrowser, ctx: *Context) bool {
        const answer = ctx.evaluateScriptToString("window.__wpt_complete === true", self.allocator) catch return false;
        defer self.allocator.free(answer);
        return std.mem.eql(u8, answer, "true");
    }

    /// Collect test results from window.__wpt_results
    fn collectResults(self: *WptBrowser, ctx: *Context, start_time: i64, test_path: []const u8) !test_harness.TestResult {
        const duration = @as(u64, @intCast(clock.monotonicMillis() - start_time));

        // Get results JSON - "=" and the JSON text, or "" when there is
        // none to stringify (JSON.stringify(undefined) is undefined).
        const json_script =
            \\(function () { var s = JSON.stringify(window.__wpt_results); return typeof s === 'string' ? '=' + s : ''; })()
        ;
        const json_result = ctx.evaluateScriptToString(json_script, self.allocator) catch {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try self.allocator.dupe(u8, "Failed to collect test results");
            result.duration_ms = duration;
            return result;
        };

        defer self.allocator.free(json_result);
        if (json_result.len > 0) return try self.parseTestResults(json_result[1..], duration, test_path);

        var result = try test_harness.TestResult.init(self.allocator, test_path);
        result.status = .@"error";
        result.message = try self.allocator.dupe(u8, "No test results available");
        result.duration_ms = duration;
        return result;
    }

    /// Parse JSON test results into TestResult struct
    fn parseTestResults(self: *WptBrowser, json_str: []const u8, duration: u64, test_path: []const u8) !test_harness.TestResult {
        // Parse JSON
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_str, .{}) catch {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try self.allocator.dupe(u8, "Failed to parse test results JSON");
            result.duration_ms = duration;
            return result;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try self.allocator.dupe(u8, "Invalid test results format");
            result.duration_ms = duration;
            return result;
        }

        // Get harness status
        const status_num = if (root.object.get("status")) |s| switch (s) {
            .integer => @as(i64, s.integer),
            .float => @as(i64, @intFromFloat(s.float)),
            else => 2, // Error
        } else 2;

        const harness_status: test_harness.HarnessStatus = switch (status_num) {
            0 => .ok,
            1 => .@"error",
            2 => .timeout,
            else => .@"error",
        };

        // Get message
        const message = if (root.object.get("message")) |m| switch (m) {
            .string => try self.allocator.dupe(u8, m.string),
            else => null,
        } else null;

        // Get subtests (Zig 0.15 ArrayList is unmanaged by default)
        // Note: We don't defer deinit here because ownership transfers to result
        var subtests: std.ArrayList(test_harness.SubtestResult) = .empty;
        errdefer subtests.deinit(self.allocator);

        if (root.object.get("tests")) |tests| {
            if (tests == .array) {
                for (tests.array.items) |test_item| {
                    if (test_item == .object) {
                        const name = if (test_item.object.get("name")) |n| switch (n) {
                            .string => try self.allocator.dupe(u8, n.string),
                            else => try self.allocator.dupe(u8, "<unknown>"),
                        } else try self.allocator.dupe(u8, "<unknown>");

                        const test_status_num = if (test_item.object.get("status")) |s| switch (s) {
                            .integer => @as(i64, s.integer),
                            .float => @as(i64, @intFromFloat(s.float)),
                            else => 2,
                        } else 2;

                        const test_status: test_harness.TestStatus = switch (test_status_num) {
                            0 => .pass,
                            1 => .fail,
                            2 => .timeout,
                            3 => .notrun,
                            else => .fail,
                        };

                        const test_message = if (test_item.object.get("message")) |m| switch (m) {
                            .string => try self.allocator.dupe(u8, m.string),
                            else => null,
                        } else null;

                        try subtests.append(self.allocator, .{
                            .name = name,
                            .status = test_status,
                            .message = test_message,
                        });
                    }
                }
            }
        }

        var result = try test_harness.TestResult.init(self.allocator, test_path);
        result.status = harness_status;
        result.message = message;
        result.subtests = subtests;
        result.duration_ms = duration;
        return result;
    }

    /// Build test URL from path.
    ///
    /// Scheme and port follow the `.h2.` and `.https.` markers in the
    /// filename (`wpt_server.testOriginFor`), the same way
    /// `wpt_server.buildTestUrl` does - a TLS test fetched over plain HTTP
    /// gets whatever the server chooses to serve on :8000, which is not the
    /// test.
    fn buildTestUrl(self: *WptBrowser, test_path: []const u8) ![]const u8 {
        return std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ wpt_server.testOriginFor(test_path), test_path });
    }
};
