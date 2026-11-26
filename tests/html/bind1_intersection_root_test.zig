//! IntersectionObserver.root is the root the constructor was given, held
//! weakly: it reads back while anything else keeps the root, and null once
//! the root was collected (lane bind1, batch B5 group 3a).
//!
//! Before this lane the constructor never kept the root: `observer.root` was
//! always null. The observer now keeps a WEAK link to it, as Chrome and
//! Safari do - Blink `UntracedMember<Node> root_` with "custom weak
//! processing", WebKit `WeakPtr<ContainerNode, ...> m_root`; Firefox holds
//! it strongly (`RefPtr<nsINode> mRoot`), golden rule 2's one of three.
//! Chrome 157 with gc() exposed answers null for `observer.root` once
//! nothing else holds the root, also while the observer observes one of the
//! root's children (probe tmp/probes/bind1-nullmember/report-g3.txt,
//! 2026-11-24).
//!
//! Each case runs in a Browser's page; a collection is two full collections
//! with the realm entered and the event loop turns that free what they
//! collected (the form of tests/html/leaks6_navigation_api_handles_test.zig).
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const Browser = @import("browser").Browser;

const page_url = "https://bind1-root.test/page.html";

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

test "bind1 IntersectionObserver.root: the root given reads back, an Element or a Document" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.expect(
                \\(() => {
                \\  globalThis.keptRoot = document.createElement('div');
                \\  globalThis.kept = new IntersectionObserver(() => {}, { root: keptRoot });
                \\  globalThis.ofDocument = new IntersectionObserver(() => {}, { root: document });
                \\  globalThis.implicit = new IntersectionObserver(() => {});
                \\  globalThis.explicitNull = new IntersectionObserver(() => {}, { root: null });
                \\  return [kept.root === keptRoot, ofDocument.root === document, implicit.root, explicitNull.root].join(' ');
                \\})()
            , "true true  ");
            // A collection takes nothing that something else keeps.
            try page.collect();
            try page.expect("[kept.root === keptRoot, ofDocument.root === document].join(' ')", "true true");
        }
    }.body);
}

test "bind1 IntersectionObserver.root: null once the root was collected - the observer does not keep it" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.expect(
                \\(() => {
                \\  globalThis.dropped = new IntersectionObserver(() => {}, { root: document.createElement('div') });
                \\  globalThis.keptRoot = document.createElement('div');
                \\  globalThis.kept = new IntersectionObserver(() => {}, { root: keptRoot });
                \\  // An observed child does not keep its root for the observer either.
                \\  const root = document.createElement('div');
                \\  globalThis.observing = new IntersectionObserver(() => {}, { root });
                \\  observing.observe(root.appendChild(document.createElement('span')));
                \\  return [dropped.root !== null, kept.root === keptRoot, observing.root !== null].join(' ');
                \\})()
            , "true true true");
            try page.collect();
            try page.expect("[String(dropped.root), kept.root === keptRoot, String(observing.root)].join(' ')", "null true null");
            // The observers go on working without their roots.
            try page.expect("(() => { dropped.disconnect(); observing.disconnect(); return dropped.takeRecords().length; })()", "0");
        }
    }.body);
}
