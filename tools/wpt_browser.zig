const std = @import("std");
const Browser = @import("browser").Browser;
const Context = @import("browser").Context;
const test_runner = @import("testing").test_runner;

/// Embed the V8 snapshot at compile time to ensure it's always available
/// regardless of working directory when the binary runs
/// TEMPORARILY DISABLED FOR DEBUGGING - testing if Worker callback works without snapshot
const embedded_snapshot: ?[]const u8 = null; // @embedFile("whatwg_snapshot.bin");

const WptBrowser = struct {
    allocator: std.mem.Allocator,
    browser: *Browser,
    test_url: []const u8,

    pub fn init(allocator: std.mem.Allocator, test_url: []const u8) !*WptBrowser {
        const stderr = std.fs.File.stderr();
        stderr.writeAll("[WPT_BROWSER] init() starting, calling Browser.init()...\n") catch {};

        const browser = try Browser.init(allocator, .{
            .storage_root = null,
            .persist_storage = false,
            .initial_url = null,
            .debug = false,
            .embedded_snapshot = embedded_snapshot,
        });
        stderr.writeAll("[WPT_BROWSER] Browser.init() complete\n") catch {};

        const self = try allocator.create(WptBrowser);
        self.* = .{
            .allocator = allocator,
            .browser = browser,
            .test_url = test_url,
        };
        stderr.writeAll("[WPT_BROWSER] WptBrowser struct created\n") catch {};
        return self;
    }

    pub fn deinit(self: *WptBrowser) void {
        self.browser.deinit();
        self.allocator.destroy(self);
    }

    pub fn run(self: *WptBrowser) !void {
        const stderr = std.fs.File.stderr();
        const stdout = std.fs.File.stdout();
        stderr.writeAll("[WPT_BROWSER] run() starting\n") catch {};

        stderr.writeAll("[WPT_BROWSER] calling navigateWithOptions...\n") catch {};
        try self.browser.navigateWithOptions(self.test_url, .window, .{ .skip_load = true });
        stderr.writeAll("[WPT_BROWSER] navigateWithOptions complete\n") catch {};

        // Inject testRunner API BEFORE the page loads
        // This provides Chromium-compatible testRunner object that testharness.js expects
        const testrunner_script = test_runner.generateTestRunnerScript();

        const ctx = self.browser.current_context orelse return error.NoContext;

        // Inject testRunner API before loading the page
        stderr.writeAll("[WPT_BROWSER] injecting testRunner API...\n") catch {};
        _ = self.browser.evaluateScript(testrunner_script) catch |err| {
            stderr.writeAll("[WPT_BROWSER] ERROR: Failed to inject testRunner API\n") catch {};
            return err;
        };
        stderr.writeAll("[WPT_BROWSER] testRunner API injected\n") catch {};

        stderr.writeAll("[WPT_BROWSER] calling ctx.loadPage()...\n") catch {};
        try ctx.loadPage();
        stderr.writeAll("[WPT_BROWSER] loadPage() complete\n") catch {};

        // Register our WPT callbacks AFTER testharness.js has loaded
        stderr.writeAll("[WPT_BROWSER] registering WPT callbacks...\n") catch {};
        _ = self.browser.evaluateScript(
            \\if (typeof __crane_register_wpt_callbacks === 'function') {
            \\    __crane_register_wpt_callbacks();
            \\}
        ) catch {};

        // Post-load diagnostics
        _ = self.browser.evaluateScript(
            \\console.log("POST_LOAD: typeof window.addEventListener = " + typeof window.addEventListener);
            \\console.log("POST_LOAD: trying to add a load listener now...");
            \\var loadListenerCalled = false;
            \\window.addEventListener('load', function() {
            \\    console.log("POST_LOAD_LISTENER: window load event received!");
            \\    loadListenerCalled = true;
            \\});
            \\console.log("POST_LOAD: listener added, checking if load already fired...");
            \\// Dispatch a test event to verify addEventListener works
            \\var testEvent = new Event('testcustom');
            \\var testListenerCalled = false;
            \\window.addEventListener('testcustom', function() {
            \\    console.log("POST_LOAD: testcustom event listener called!");
            \\    testListenerCalled = true;
            \\});
            \\window.dispatchEvent(testEvent);
            \\console.log("POST_LOAD: testListenerCalled = " + testListenerCalled);
            \\console.log("POST_LOAD: typeof testRunner = " + typeof testRunner);
            \\console.log("POST_LOAD: typeof add_result_callback = " + typeof add_result_callback);
            \\console.log("POST_LOAD: typeof add_completion_callback = " + typeof add_completion_callback);
            \\console.log("POST_LOAD: typeof __wpt_report_completion = " + typeof __wpt_report_completion);
            \\console.log("POST_LOAD: testRunner._done = " + testRunner._done);
            \\console.log("POST_LOAD: typeof self = " + typeof self);
            \\console.log("POST_LOAD: self === window = " + (self === window));
            \\console.log("POST_LOAD: typeof test = " + typeof test);
            \\console.log("POST_LOAD: typeof assert_true = " + typeof assert_true);
            \\console.log("POST_LOAD: typeof setup = " + typeof setup);
            \\
            \\// Check testharness.js internal state
            \\if (typeof tests !== 'undefined') {
            \\    console.log("POST_LOAD: tests object exists, tests.tests.length = " + tests.tests.length);
            \\    console.log("POST_LOAD: tests.status = " + tests.status);
            \\    console.log("POST_LOAD: tests.num_pending = " + tests.num_pending);
            \\    console.log("POST_LOAD: tests.all_done = " + tests.all_done);
            \\    console.log("POST_LOAD: tests.completion_callbacks length = " + (tests.completion_callbacks ? tests.completion_callbacks.length : 'undefined'));
            \\}
            \\
            \\// Try to manually trigger completion if tests are done
            \\if (typeof tests !== 'undefined' && tests.all_done) {
            \\    console.log("POST_LOAD: Tests are done, manually calling done()");
            \\    if (typeof tests.complete === 'function') {
            \\        tests.complete();
            \\    }
            \\}
            \\
            \\// Test setTimeout to verify timers work
            \\setTimeout(function() {
            \\    console.log("TIMER_TEST: setTimeout(0) callback fired!");
            \\    console.log("TIMER_TEST: testRunner._done = " + testRunner._done);
            \\    console.log("TIMER_TEST: __wpt_completed = " + __wpt_completed);
            \\    console.log("TIMER_TEST: __wpt_results.length = " + __wpt_results.length);
            \\    // Check testharness.js internal state via its internals
            \\    if (typeof test_environment !== 'undefined') {
            \\        console.log("TIMER_TEST: test_environment exists");
            \\        console.log("TIMER_TEST: test_environment.all_loaded = " + test_environment.all_loaded);
            \\    } else {
            \\        console.log("TIMER_TEST: test_environment is undefined");
            \\    }
            \\    // Check via accessor if exposed
            \\    if (typeof setup_func !== 'undefined' && setup_func.all_loaded !== undefined) {
            \\        console.log("TIMER_TEST: setup_func.all_loaded = " + setup_func.all_loaded);
            \\    }
            \\}, 0);
            \\
            \\// Check if testharness test() was called
            \\if (typeof Test !== 'undefined') {
            \\    console.log("POST_LOAD: Test constructor exists");
            \\}
        ) catch {};

        const timeout_ms: u64 = 60_000;
        const start_time = std.time.milliTimestamp();

        stderr.writeAll("[WPT_BROWSER] Starting event loop\n") catch {};

        var iteration: u32 = 0;
        while (true) {
            iteration += 1;
            const elapsed = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
            if (elapsed >= timeout_ms) {
                stdout.writeAll("CRANE_WPT_RESULT: TIMEOUT\n") catch {};
                break;
            }

            // Run event loop to process scripts and network
            self.browser.runEventLoop(100) catch {};

            // Check if testRunner.notifyDone() was called OR __wpt_completed is true
            // testRunner._done is set by notifyDone() which is called by __wpt_report_completion
            if (self.browser.evaluateScriptBool("testRunner._done === true")) {
                stderr.writeAll("[WPT_BROWSER] testRunner.notifyDone() called, test complete\n") catch {};
                break;
            }

            if (iteration % 50 == 0) {
                var buf: [64]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "[WPT_BROWSER] iter={d}, elapsed={d}ms\n", .{ iteration, elapsed }) catch "[WPT_BROWSER] loop\n";
                stderr.writeAll(msg) catch {};
            }
        }
    }
};

pub fn main() !void {
    // ABSOLUTE FIRST OUTPUT - before anything else
    // std.debug.print is guaranteed to flush immediately
    std.debug.print("[WPT_BROWSER] === PROCESS STARTED ===\n", .{});

    const stderr = std.fs.File.stderr();
    stderr.writeAll("[WPT_BROWSER] main() starting\n") catch {};

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Usage: {s} <test-url>\n", .{args[0]}) catch "Usage: wpt_browser <test-url>\n";
        stderr.writeAll(msg) catch {};
        std.process.exit(1);
    }

    const test_url = args[1];
    stderr.writeAll("[WPT_BROWSER] calling WptBrowser.init()...\n") catch {};

    const wpt_browser = try WptBrowser.init(allocator, test_url);
    defer wpt_browser.deinit();

    stderr.writeAll("[WPT_BROWSER] calling wpt_browser.run()...\n") catch {};
    try wpt_browser.run();
}
