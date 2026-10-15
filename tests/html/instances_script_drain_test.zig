//! Two Browsers on two threads drain their documents' script queues at the
//! same time, and each drain is its own agent's: neither one's drain
//! suppresses, strands or unbalances the other's (docs/instances.md - an
//! agent owns its event loop's state).
//!
//! A drain (html.script_execution: executeScriptsWhenParsingFinished, and
//! drainReadyScripts for the "as soon as possible" queues) records the
//! document it walks and how deeply drains nest, so a script it runs cannot
//! re-enter the same document's drain. Both were process-wide variables, so
//! two Browsers' drains interleaved on them: the drain that ended second
//! put back the document the OTHER Browser had been draining when it began.
//! That document's every later drain then saw itself as "already draining"
//! and returned, and its ready scripts never ran; and the unguarded
//! `drain_depth -= 1` of two threads at once underflowed and panicked
//! (tests/html/instances_navigables_test.zig, in native gates).
//!
//! Each round both Browsers load a page whose deferred (parser-inserted
//! module) script busy-waits inside its drain, so the two drains overlap;
//! then each inserts a script that only a drain of the same document can run.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

const page_url = "http://drainrace.test/page.html";
const rounds = 8;

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn expectScript(browser: *browser_mod.Browser, source: []const u8) !void {
    if (!try truthy(browser, source)) {
        std.debug.print("false: {s}\n", .{source});
        return error.ScriptAnsweredFalse;
    }
}

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 300) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),

    /// Wait until both threads have arrived at meeting point `point` (1, 2..).
    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (spins > 50_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

const Side = struct {
    index: usize,
    shared: *Shared,
    failure: ?anyerror = null,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            // Whatever happened, never leave the other side waiting.
            _ = self.shared.arrived.fetchAdd(1000, .acq_rel);
        };
    }

    fn steps(self: *Side) !void {
        const shared = self.shared;
        var buffer: [512]u8 = undefined;
        const browser = try startBrowser();
        defer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });

        for (0..rounds) |round| {
            const point: u32 = @intCast(2 * round + 1);
            try shared.meet(point);
            // The page's deferred script runs inside "the end"'s drain and
            // holds it ~25 ms, while the other Browser's drain runs too.
            const page = browser.current_context orelse return error.NoPage;
            const html = try std.fmt.bufPrint(&buffer,
                \\<!doctype html><body><script type=module>
                \\const end = performance.now() + 25;
                \\while (performance.now() < end) {{}}
                \\globalThis.deferred = {d};
                \\</script></body>
            , .{round});
            try page.loadHTML(html, .{ .base_url = page_url });
            try waitFor(browser, try std.fmt.bufPrint(&buffer, "globalThis.deferred === {d}", .{round}));

            // Both drains are over. A script inserted now is "as soon as
            // possible" (force async): only a drain of this document runs it.
            try shared.meet(point + 1);
            try expectScript(browser, try std.fmt.bufPrint(&buffer,
                \\{{
                \\const script = document.createElement('script');
                \\script.type = 'module';
                \\script.textContent = 'globalThis.inserted = {d}';
                \\document.body.appendChild(script);
                \\}}
                \\true
            , .{round}));
            try waitFor(browser, try std.fmt.bufPrint(&buffer, "globalThis.inserted === {d}", .{round}));
            try waitFor(browser, "document.readyState === 'complete'");
        }
    }
};

test "two Browsers on two threads drain their documents' scripts at once, and neither drain strands the other's" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .index = 0, .shared = &shared }, .{ .index = 1, .shared = &shared } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
