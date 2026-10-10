//! Shared by the refcount_*_test.zig files (lane rc12, step 1 of
//! tmp/plans/refcount-design.md section 7): a page on a thread of its own, a
//! settled collection, and the live-node count read from the slab - the probe
//! the design calls "a live-node count probe through a test hook".
//!
//! RED TESTS WITHOUT A RED BUILD. A test that pins what the migration must
//! achieve is red until its step lands, and `zig build test` must stay green on
//! main in between. So such a test asserts through `knownRed(step, holds, ...)`:
//! until `migrated.<step>` is flipped, the property is expected NOT to hold
//! (the measured red value is printed, and recorded in the lane handoff), and
//! the build passes; a property that holds while its flag is false fails, so
//! the lane that makes it true must flip the flag in the same commit; once the
//! flag is true the property is required. Flip the flag of the step you land.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");

/// Which migration steps have landed (tmp/plans/refcount-design.md section 7).
pub const migrated = struct {
    /// Step 7: counts decide; a garbage tree is freed through the deferred
    /// queue, so a never-wrapped detached tree no longer lives to realm end.
    pub const switch_step7 = false;
    /// Step 8: listener and observer callbacks are traced from their
    /// target's wrapper instead of owned as strong roots.
    pub const cycle_breakers_step8 = false;
};

/// Assert `holds`, or - while `landed` is false - that it does not.
pub fn knownRed(comptime landed: bool, holds: bool, what: []const u8) !void {
    if (landed) {
        if (!holds) {
            std.debug.print("REGRESSION (its step has landed): {s}\n", .{what});
            return error.PropertyLost;
        }
        return;
    }
    if (holds) {
        std.debug.print("UNEXPECTEDLY GREEN (flip its `migrated` flag in tests/html/refcount_probe.zig): {s}\n", .{what});
        return error.RedTestTurnedGreen;
    }
    std.debug.print("known red until its migration step: {s}\n", .{what});
}

pub fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exercise() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

pub const Page = struct {
    browser: *browser_mod.Browser,
    slab: *runtime.SlabAllocator,
    baseline: usize,

    /// A page with `body_markup` in its body, collected once, and the live
    /// instance count taken as the baseline.
    pub fn open(body_markup: []const u8) !Page {
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        var buffer: [512]u8 = undefined;
        const html = try std.fmt.bufPrint(&buffer, "<!doctype html><body>{s}</body>", .{body_markup});
        try page.loadHTML(html, .{ .base_url = "about:blank" });
        try page.runScript("TestUtils.gc(); TestUtils.gc();");
        const slab = try runtime.SlabAllocator.tryGet();
        return .{ .browser = browser, .slab = slab, .baseline = slab.stats().currently_allocated };
    }

    pub fn close(self: Page) void {
        self.browser.deinit();
    }

    pub fn run(self: Page, source: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        page.runScript(source) catch |err| {
            std.debug.print("script failed: {s}\n", .{source});
            return err;
        };
    }

    /// The completion of `source` as a string, OWNED by std.testing.allocator.
    pub fn evaluate(self: Page, source: []const u8) ![]u8 {
        const page = self.browser.current_context orelse return error.NoPage;
        return page.evaluateScriptToString(source, testing.allocator);
    }

    pub fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        const result = try self.evaluate(source);
        defer testing.allocator.free(result);
        testing.expectEqualStrings(expected, result) catch |err| {
            std.debug.print("script: {s}\n", .{source});
            return err;
        };
    }

    /// Two collections, an event loop turn (the deferred teardown queue runs
    /// between tasks), two more.
    pub fn settle(self: Page) !void {
        try self.run("TestUtils.gc(); TestUtils.gc();");
        _ = try self.browser.runEventLoopBlocking(20);
        try self.run("TestUtils.gc(); TestUtils.gc();");
        _ = try self.browser.runEventLoopBlocking(20);
        try self.run("TestUtils.gc(); TestUtils.gc();");
    }

    /// Instances (nodes and every other platform object) alive now beyond the
    /// page's own at open.
    pub fn grown(self: Page) usize {
        return self.slab.stats().currently_allocated -| self.baseline;
    }
};
