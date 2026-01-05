const std = @import("std");
const Browser = @import("browser").Browser;
const Context = @import("browser").Context;

const WptBrowser = struct {
    allocator: std.mem.Allocator,
    browser: *Browser,
    test_url: []const u8,

    pub fn init(allocator: std.mem.Allocator, test_url: []const u8) !*WptBrowser {
        const browser = try Browser.init(allocator, .{
            .storage_root = null,
            .persist_storage = false,
            .initial_url = null,
            .debug = false,
            .snapshot_path = "zig-out/bin/whatwg_snapshot.bin",
        });

        const self = try allocator.create(WptBrowser);
        self.* = .{
            .allocator = allocator,
            .browser = browser,
            .test_url = test_url,
        };
        return self;
    }

    pub fn deinit(self: *WptBrowser) void {
        self.browser.deinit();
        self.allocator.destroy(self);
    }

    pub fn run(self: *WptBrowser) !void {
        try self.browser.navigateWithOptions(self.test_url, .window, .{ .skip_load = true });

        // Define WPT report functions BEFORE the page loads
        // testharnessreport.js checks for these and uses them to report results
        const wpt_setup_script =
            \\window.__wpt_results = [];
            \\window.__wpt_completed = false;
            \\window.__wpt_harness_status = null;
            \\window.__wpt_report_result = function(name, status, message, stack, duration) {
            \\    window.__wpt_results.push([name, status, message, stack]);
            \\};
            \\window.__wpt_report_completion = function(harness_status) {
            \\    window.__wpt_completed = true;
            \\    if (harness_status) window.__wpt_harness_status = harness_status;
            \\    var status = window.__wpt_harness_status || {status: 0};
            \\    var results = window.__wpt_results || [];
            \\    var passed = 0;
            \\    for (var i = 0; i < results.length; i++) {
            \\        if (results[i][1] === 0) passed++;
            \\    }
            \\    var output = "CRANE_WPT_RESULT:[null," + (status.status||0) + ",null,null,[[\"" + passed + "/" + results.length + " passed\",0,null,null]]]";
            \\    console.log(output);
            \\};
        ;

        const ctx = self.browser.current_context orelse return error.NoContext;

        // Inject WPT functions before loading the page
        _ = self.browser.evaluateScript(wpt_setup_script) catch {};

        try ctx.loadPage();

        const timeout_ms: u64 = 60_000;
        const start_time = std.time.milliTimestamp();

        while (true) {
            const elapsed = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
            if (elapsed >= timeout_ms) {
                const stdout = std.fs.File.stdout();
                stdout.writeAll("CRANE_WPT_RESULT: [null, 2, \"Timeout\", null, []]\n") catch {};
                break;
            }

            // Run event loop to process scripts and network
            self.browser.runEventLoop(100) catch {};

            // Check if tests completed - __wpt_completed is set by __wpt_report_completion
            // We just need to check if it's true; the result was already logged to stdout
            _ = self.browser.evaluateScript(
                \\if (window.__wpt_completed === true) { throw new Error("WPT_DONE"); }
            ) catch {
                // Error thrown means tests completed
                break;
            };
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        const stderr = std.fs.File.stderr();
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Usage: {s} <test-url>\n", .{args[0]}) catch "Usage: wpt_browser <test-url>\n";
        stderr.writeAll(msg) catch {};
        std.process.exit(1);
    }

    const test_url = args[1];

    const wpt_browser = try WptBrowser.init(allocator, test_url);
    defer wpt_browser.deinit();

    try wpt_browser.run();
}
