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
    /// wptrunner's executors/test-wait.js with its class name filled in
    /// ("test-wait", as its crashtest executor fills it): `runCrashtest`.
    test_wait_js: ?[]const u8 = null,
    /// Number of tests run
    tests_run: usize,
    /// testdriver.js's automation backend (the WebDriver remote end), whose
    /// natives the vendor file wires into each test realm.
    test_driver: *test_driver.TestDriver,
    /// Ends script still running past a run's ceiling (script_deadline.zig):
    /// its thread runs only where the engine can abort a running script.
    script_deadline: script_deadline.ScriptDeadline = .{ .abort = abortAgentScript },

    /// Initialize WptBrowser with a fresh Browser instance. `poison_freed_state`:
    /// the runner poisons its allocator's frees (main.zig `poisoning`), so the
    /// Browser poisons the platform objects' freed state too
    /// (BrowserConfig.poison_freed_state).
    pub fn init(allocator: std.mem.Allocator, wpt_root: []const u8, poison_freed_state: bool) !*WptBrowser {
        const self = try allocator.create(WptBrowser);
        errdefer allocator.destroy(self);

        // Trust WPT's certificate authority, so `.https.` tests can be fetched
        // from :8443 at all. `wpt serve` signs its leaf certificate with a CA
        // it generates itself; nothing in the system trust store knows it.
        // The Browser's network context copies the path.
        const ca = try wptCertificateAuthority(allocator, wpt_root);
        defer if (ca) |path| allocator.free(path);

        // Create the underlying browser (manages V8 isolate)
        // The Browser Crane's own browser makes (tools/repl.zig, main): its
        // BrowserConfig's defaults, and nothing the console does not set - no
        // `log_performance`, which the runner used to turn on (the user,
        // 2026-11-09: "We should never special case something"). What the
        // runner adds is what WPT needs and a browser gets the same way: WPT's
        // certificate authority (the console's --ca-bundle) - and in the
        // bug-finding run alone the poisoned frees.
        // Media decoding is the compiled-in platform's capability
        // (media_decoding: kit/media_decoding's WAV in the default
        // platforms), as image decoding and the clipboard are - nothing a
        // host passes (the user, 2026-11-09 21:09 UTC: "The platform itself
        // that is compiled in will decide if these features are built within
        // the platform or dynamically link out to existing capabilities on
        // the platform").
        const browser_instance = try Browser.init(allocator, .{
            .ca_bundle_path = ca,
            .poison_freed_state = poison_freed_state,
        });
        errdefer browser_instance.deinit();

        const driver = try test_driver.TestDriver.create(allocator);
        errdefer driver.destroy();

        self.* = WptBrowser{
            .allocator = allocator,
            .browser = browser_instance,
            .wpt_root = try allocator.dupe(u8, wpt_root),
            .tests_run = 0,
            .test_driver = driver,
        };
        if (comptime engine.capabilities.script_abort != .unsupported) try self.script_deadline.start();

        // A Web Worker's blob: script is resolved by fetch's scheme fetch
        // "blob", whose resolver crane.Process installs at start - on every
        // thread, a nested worker's too.

        // Every document gets the testdriver vendor file, with test_driver's
        // natives defined first - the embedder's hook (html.embedder_scripts),
        // registered once here, before any page loads. The last runner-only
        // path: it goes when test_driver's commands move into src/webdriver
        // and the runner drives Crane as a WebDriver client (lane wptcfg
        // batch 2).
        try test_driver.registerForFrames(self.test_driver, browser_instance.scope);
        errdefer test_driver.unregisterForFrames(browser_instance.scope);

        // The harness is the page's own: testharness.js and the runner's
        // testharnessreport.js are fetched from `wpt serve` where the page
        // includes them (wpt_server.zig serves the report), as in a browser
        // under wptrunner.
        self.test_wait_js = self.loadTestWait() catch null;

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

        if (self.test_wait_js) |js| self.allocator.free(js);
        self.allocator.free(self.wpt_root);
        self.browser.deinit();
        self.allocator.destroy(self);
    }

    /// wptrunner's test-wait.js, as its crashtest executor formats it
    /// (`f.read() % {"classname": "test-wait"}`). OWNED.
    fn loadTestWait(self: *WptBrowser) ![]const u8 {
        const source = try self.loadWptScript("tools/wptrunner/wptrunner/executors/test-wait.js");
        defer self.allocator.free(source);
        return std.mem.replaceOwned(u8, self.allocator, source, "%(classname)s", "test-wait");
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

        // Each test file starts with an empty cookie jar and no permission
        // override, as runTest's do.
        self.browser.cookie_jar.clear();
        test_driver.TestDriver.resetPermissions(self.browser.scope);

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

        // The fresh realm holds nothing of the previous file's harness. The
        // page's own includes load this one, over HTTP. The page's
        // document gets a Window of its
        // own when its navigation commits ("create and initialize a
        // Document object" step 7: the initial about:blank's origin is
        // opaque), so nothing put in the initial about:blank's realm would
        // reach the page - no browser keeps it either.
        try self.checkFreshRealm(ctx);

        const nav_ms = lapMs(&phase);

        // The page's load: HTML "navigate" of the traversable to the test
        // URL with user involvement "browser UI" - the fetch, the commit and
        // the parse, with its scripts, as the navigation's tasks, waited for
        // within the run's ceiling. Every script the page includes is
        // fetched from `wpt serve` - testharness.js, and at
        // /resources/testharnessreport.js the runner's own report, which the
        // server serves in place of the stock one (wpt_server.zig), as
        // wptrunner's server serves its own (environment.py, get_routes).
        const left_ms: u64 = @intCast(@max(1, deadline - clock.monotonicMillis()));
        ctx.loadPageWithOptions(.{ .timeout_ms = left_ms }) catch |err| {
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

        // A page whose parse reaches no testharnessreport.js include gets no
        // harness hook and no results: it ends at the run's ceiling as
        // TIMEOUT, as it does in every browser under wptrunner (whose server
        // serves the report only at that include, and whose `wpt lint`
        // rejects a testharness page without it: MISSING-TESTHARNESSREPORT).
        // The runner used to install its hook after such a page's load
        // (`installHarnessLate`), a path no browser has (the user,
        // 2026-11-09).

        const load_ms = lapMs(&phase);

        // Run event loop until test completes or timeout
        var result = try self.waitForCompletion(ctx, deadline, timeout_ms, test_path);
        result.nav_ms = nav_ms;
        result.load_ms = load_ms;

        self.tests_run += 1;
        return result;
    }

    /// Run a WPT crashtest (docs/writing-tests/crashtest.md): the file passes
    /// when its page loads and finishes without the process crashing - a
    /// crash is the supervisor's CRASH, as for any file - and TIMEOUT when it
    /// has not finished by the run's ceiling.
    ///
    /// What "finishes" means is wptrunner's own: its crashtest executor
    /// (tools/wptrunner/wptrunner/executors/executorwebdriver.py
    /// `WebDriverCrashtestExecutor.do_crashtest`) navigates to the file, which
    /// WebDriver ends at the page's load (page load strategy "normal"), then
    /// runs executors/test-wait.js with the class name "test-wait" as an
    /// asynchronous script: after `document.fonts.ready` and two animation
    /// frames it waits, while the root element has that class, for it to go
    /// (dispatching a `TestRendered` event first), and then calls back
    /// "complete". The runner reads that script from the WPT checkout
    /// (`test_wait_js`) rather than keeping a copy of its steps.
    pub fn runCrashtest(
        self: *WptBrowser,
        test_path: []const u8,
        test_url: []const u8,
        timeout_ms: u64,
    ) !test_harness.TestResult {
        const deadline = clock.monotonicMillis() + @as(i64, @intCast(timeout_ms));
        self.armScriptDeadline(deadline);
        defer _ = self.endScriptDeadline();
        var phase: ?clock.Timer = clock.Timer.start();

        self.browser.cookie_jar.clear();
        try self.browser.navigateWithOptions(test_url, .window, .{ .skip_load = true });
        defer self.test_driver.endTest();
        const ctx = self.browser.current_context orelse return error.NoContext;

        const nav_ms = lapMs(&phase);

        const left_ms: u64 = @intCast(@max(1, deadline - clock.monotonicMillis()));
        ctx.loadPageWithOptions(.{ .timeout_ms = left_ms }) catch |err| {
            if (!self.script_deadline.abortedThisRun() and err != error.NavigationTimedOut) {
                var result = try test_harness.TestResult.init(self.allocator, test_path);
                result.status = .@"error";
                result.message = try std.fmt.allocPrint(self.allocator, "Page load error: {}", .{err});
                result.nav_ms = nav_ms;
                result.load_ms = lapMs(&phase);
                return result;
            }
        };

        // WebDriver "navigate to" returns once the document's readiness is
        // "complete" (the load event has fired).
        var loaded: PageLoaded = .{ .ctx = ctx };
        if (!PageLoaded.met(&loaded) and clock.monotonicMillis() < deadline) {
            _ = self.browser.spinEventLoopUntil(.{ .context = &loaded, .met = PageLoaded.met }, @intCast(@max(1, deadline - clock.monotonicMillis()))) catch null;
        }
        const load_ms = lapMs(&phase);

        // WebDriver "execute async script": test-wait.js as a function body
        // called with `this` the window and its arguments - the test URL, then
        // the callback last.
        const wait_body = self.test_wait_js orelse return error.TestWaitScriptNotFound;
        const script = try std.mem.concat(self.allocator, u8, &.{
            "(function () {\n",
            "  var callback = function () { window.__wptrunner_crashtest_complete = true; };\n",
            "  (function () {\n",
            wait_body,
            "\n  }).call(window, location.href, callback);\n",
            "})();\n",
        });
        defer self.allocator.free(script);
        var result = try test_harness.TestResult.init(self.allocator, test_path);
        errdefer result.deinit(self.allocator);
        result.nav_ms = nav_ms;
        result.load_ms = load_ms;
        result.crashtest = true;
        if (!self.script_deadline.abortedThisRun()) ctx.runScript(script) catch |err| {
            result.status = .@"error";
            result.message = try std.fmt.allocPrint(self.allocator, "test-wait.js did not run: {}", .{err});
            return result;
        };

        const start_time = clock.monotonicMillis();
        while (!self.script_deadline.abortedThisRun()) {
            const answer = ctx.evaluateScriptToString("window.__wptrunner_crashtest_complete === true", self.allocator) catch null;
            if (answer) |text| {
                defer self.allocator.free(text);
                if (std.mem.eql(u8, text, "true")) {
                    result.duration_ms = @intCast(clock.monotonicMillis() - start_time);
                    self.tests_run += 1;
                    return result;
                }
            }
            const now = clock.monotonicMillis();
            if (now >= deadline) break;
            _ = self.browser.runEventLoopBlocking(@min(@as(u64, @intCast(deadline - now)), 50)) catch {};
        }
        result.status = .timeout;
        result.message = try std.fmt.allocPrint(self.allocator, "Crashtest did not finish (load, then test-wait) within {}ms", .{timeout_ms});
        result.duration_ms = @intCast(clock.monotonicMillis() - start_time);
        self.tests_run += 1;
        return result;
    }

    /// What `runCrashtest` waits for before test-wait.js: the page's document
    /// is "complete", or the page has none.
    const PageLoaded = struct {
        ctx: *Context,

        fn met(opaque_self: *anyopaque) bool {
            const self: *PageLoaded = @ptrCast(@alignCast(opaque_self));
            const document = self.ctx.document_instance orelse return true;
            const state = interfaces.Document.get_readyState(document) catch return true;
            return state == ._complete_;
        }
    };

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
