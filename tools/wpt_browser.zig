const std = @import("std");
const Browser = @import("browser").Browser;
const Context = @import("browser").Context;

/// Embed the V8 snapshot at compile time to ensure it's always available
/// regardless of working directory when the binary runs
const embedded_snapshot = @embedFile("whatwg_snapshot.bin");

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
        stderr.writeAll("[WPT_BROWSER] run() starting\n") catch {};

        stderr.writeAll("[WPT_BROWSER] calling navigateWithOptions...\n") catch {};
        try self.browser.navigateWithOptions(self.test_url, .window, .{ .skip_load = true });
        stderr.writeAll("[WPT_BROWSER] navigateWithOptions complete\n") catch {};

        // Define WPT report functions BEFORE the page loads
        // testharnessreport.js checks for these on the GLOBAL scope (not window.*)
        // We use var to hoist them to global scope, and also set on window for consistency
        const wpt_setup_script =
            \\var __wpt_results = [];
            \\var __wpt_completed = false;
            \\var __wpt_harness_status = null;
            \\var __wpt_report_result = function(name, status, message, stack, duration) {
            \\    __wpt_results.push([name, status, message, stack]);
            \\};
            \\var __wpt_report_completion = function(harness_status) {
            \\    __wpt_completed = true;
            \\    if (harness_status) __wpt_harness_status = harness_status;
            \\    var status = __wpt_harness_status || {status: 0};
            \\    var results = __wpt_results || [];
            \\    var passed = 0;
            \\    for (var i = 0; i < results.length; i++) {
            \\        if (results[i][1] === 0) passed++;
            \\    }
            \\    // Output result via console.log - Console impl writes CRANE_WPT_RESULT: lines to stdout
            \\    console.log("CRANE_WPT_RESULT:[null," + (status.status||0) + ",null,null,[[\"" + passed + "/" + results.length + " passed\",0,null,null]]]");
            \\};
            \\// Also set on window for scripts that use window.* syntax
            \\window.__wpt_results = __wpt_results;
            \\window.__wpt_completed = __wpt_completed;
            \\window.__wpt_harness_status = __wpt_harness_status;
            \\window.__wpt_report_result = __wpt_report_result;
            \\window.__wpt_report_completion = __wpt_report_completion;
        ;

        const ctx = self.browser.current_context orelse return error.NoContext;

        // Inject WPT functions before loading the page
        stderr.writeAll("[WPT_BROWSER] calling evaluateScript for WPT setup...\n") catch {};
        _ = self.browser.evaluateScript(wpt_setup_script) catch {};
        stderr.writeAll("[WPT_BROWSER] evaluateScript complete\n") catch {};

        // DIAGNOSTIC: Check if Worker is available on the global object
        _ = self.browser.evaluateScript(
            \\console.log("DIAG: typeof Worker = " + typeof Worker);
            \\console.log("DIAG: typeof XMLHttpRequest = " + typeof XMLHttpRequest);
            \\console.log("DIAG: typeof fetch = " + typeof fetch);
            \\console.log("DIAG: typeof EventTarget = " + typeof EventTarget);
        ) catch {};

        stderr.writeAll("[WPT_BROWSER] calling ctx.loadPage()...\n") catch {};
        try ctx.loadPage();
        stderr.writeAll("[WPT_BROWSER] loadPage() complete\n") catch {};

        const timeout_ms: u64 = 60_000;
        const start_time = std.time.milliTimestamp();

        stderr.writeAll("[WPT_BROWSER] Starting event loop\n") catch {};

        var iteration: u32 = 0;
        while (true) {
            iteration += 1;
            const elapsed = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
            if (elapsed >= timeout_ms) {
                const stdout = std.fs.File.stdout();
                stdout.writeAll("CRANE_WPT_RESULT:[null,2,\"Timeout\",null,[]]\n") catch {};
                break;
            }

            // Run event loop to process scripts and network
            self.browser.runEventLoop(100) catch {};

            // Check if tests completed - evaluateScript returns true/false for boolean expressions
            // The console.log in __wpt_report_completion writes result to stdout automatically
            // Use global __wpt_completed (not window.*) to match testharnessreport.js
            if (self.browser.evaluateScriptBool("__wpt_completed === true")) {
                stderr.writeAll("[WPT_BROWSER] Test completed, breaking\n") catch {};
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
