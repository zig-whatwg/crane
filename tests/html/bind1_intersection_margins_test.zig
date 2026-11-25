//! IntersectionObserver keeps [[rootMargin]] and [[scrollMargin]] in a block
//! made only when the constructor is given a margin other than "0px", and
//! frees it with the observer (lane bind1, batch B5 group 3a).
//!
//! The block halves what an observer made with no options holds: with both
//! margins inline, perf_bench observers.intersection-construct (20,000
//! observers, no options) reached a collection-length iteration once more in
//! every ten than main. A block the observer forgets is a leak no script
//! sees: each case runs in a Browser on a leak-checking DebugAllocator, whose
//! end fails the test for every block left - after observers with margins
//! were dropped and collected, and with some still alive (one observing a
//! target) when the page ends.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const Browser = @import("browser").Browser;

const page_url = "https://bind1-margins.test/page.html";

const Page = struct {
    browser: *Browser,

    fn open(allocator: std.mem.Allocator) !Page {
        const browser = try Browser.init(allocator, .{ .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
        _ = try browser.runEventLoopBlocking(10);
        return .{ .browser = browser };
    }

    fn close(self: Page) void {
        self.browser.deinit();
    }

    fn realm(self: Page) !runtime.Context {
        return self.browser.getRealm() orelse error.NoRealm;
    }

    fn run(self: Page, source: []const u8) ![]u8 {
        const page = self.browser.current_context orelse return error.NoPage;
        return page.evaluateScriptToString(source, self.browser.allocator);
    }

    fn expect(self: Page, source: []const u8, want: []const u8) !void {
        const got = try self.run(source);
        defer self.browser.allocator.free(got);
        if (!std.mem.eql(u8, want, got)) std.debug.print("{s}\n  answered {s}\n", .{ source, got });
        try testing.expectEqualStrings(want, got);
    }

    fn settle(self: Page) !void {
        for (0..10) |_| _ = try self.browser.runEventLoopBlocking(10);
    }

    /// Two full collections with the page's realm entered, then the event
    /// loop turns that free what they collected.
    fn collect(self: Page) !void {
        const realm_now = try self.realm();
        const Collect = struct {
            realm: runtime.Context,

            fn run(data: ?*anyopaque) void {
                const collect_in: *@This() = @ptrCast(@alignCast(data.?));
                if (collect_in.realm.agent) |agent| {
                    engine.requestGarbageCollection(agent);
                    engine.requestGarbageCollection(agent);
                }
            }
        };
        var entered: Collect = .{ .realm = realm_now };
        for (0..3) |_| {
            try engine.runInRealm(realm_now, Collect.run, &entered);
            try self.settle();
        }
    }
};

fn withPage(comptime body: fn (Page) anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            runBody() catch |err| {
                failure.* = err;
            };
        }

        fn runBody() !void {
            var debug: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
            defer if (debug.deinit() == .leak) @panic("leaked");
            const page = try Page.open(debug.allocator());
            defer page.close();
            try body(page);
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "bind1 IntersectionObserver margins: the margins given read back, none given reads 0px" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.expect(
                \\(() => {
                \\  const root = new IntersectionObserver(() => {}, { rootMargin: '10px 5%' });
                \\  const scroll = new IntersectionObserver(() => {}, { scrollMargin: '1px 2px 3px' });
                \\  const zero = new IntersectionObserver(() => {}, { rootMargin: '0px', scrollMargin: '0px 0px' });
                \\  const none = new IntersectionObserver(() => {});
                \\  return [root.rootMargin, root.scrollMargin, scroll.rootMargin, scroll.scrollMargin, zero.rootMargin, none.scrollMargin].join(' | ');
                \\})()
            , "10px 5% 10px 5% | 0px 0px 0px 0px | 0px 0px 0px 0px | 1px 2px 3px 2px | 0px 0px 0px 0px | 0px 0px 0px 0px");
            // A margin that does not parse throws before anything is made.
            try page.expect("(() => { try { new IntersectionObserver(() => {}, { rootMargin: '1em' }); return 'made'; } catch (e) { return e.name; } })()", "SyntaxError");
        }
    }.body);
}

test "bind1 IntersectionObserver margins: no block is left - observers dropped and collected, and observers alive when the page ends" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.expect(
                \\(() => {
                \\  for (let i = 0; i < 64; i++) new IntersectionObserver(() => {}, { rootMargin: i + 'px', scrollMargin: '1%' });
                \\  globalThis.kept = [new IntersectionObserver(() => {}, { rootMargin: '2px' }), new IntersectionObserver(() => {}, { scrollMargin: '3px' })];
                \\  const target = document.body.appendChild(document.createElement('div'));
                \\  kept.push(new IntersectionObserver(() => {}, { rootMargin: '4px 5px' }));
                \\  kept[2].observe(target);
                \\  return kept.map((o) => o.rootMargin).join(' | ');
                \\})()
            , "2px 2px 2px 2px | 0px 0px 0px 0px | 4px 5px 4px 5px");
            try page.collect();
            // The kept ones end with the page: withPage's allocator fails
            // the test for any block left.
        }
    }.body);
}
