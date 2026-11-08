//! Node.isEqualNode compares two deep trees in constant native stack (lane
//! crash1 batch 2; the zero-crashes rule).
//!
//! DOM 4.4's "equals" compares each pair of children recursively, and
//! Node.call_isEqualNode recursed once per level: a 30,000-deep tree crashed
//! the release runner (crash1 b2's sweep, Node.zig call_isEqualNode, 10,000
//! frames in the report). It now walks both trees in one lockstep pre-order
//! over their links. Each test runs on a thread with a pinned 8 MiB stack, at
//! 10,000 levels; small trees pin the walk's structure checks.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

const Page = struct {
    browser: *Browser,

    fn open() !Page {
        const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        _ = try browser.runEventLoopBlocking(10);
        return .{ .browser = browser };
    }

    fn close(self: Page) void {
        self.browser.deinit();
    }

    fn run(self: Page, source: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        page.runScript(source) catch |err| {
            std.debug.print("script failed: {s}\n", .{source});
            return err;
        };
    }

    fn expect(self: Page, source: []const u8, want: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        const got = try page.evaluateScriptToString(source, testing.allocator);
        defer testing.allocator.free(got);
        if (!std.mem.eql(u8, want, got)) std.debug.print("{s}\n  answered {s}\n", .{ source, got });
        try testing.expectEqualStrings(want, got);
    }
};

/// Run `body` on a thread with a pinned 8 MiB stack.
fn withPage(comptime body: fn (Page) anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            runBody() catch |err| {
                failure.* = err;
            };
        }

        fn runBody() !void {
            const page = try Page.open();
            defer page.close();
            try body(page);
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{ .stack_size = 8 * 1024 * 1024 }, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// `chain(n, leafId)`: a detached div with `n` levels of divs below it (in
/// 500-level chunks), its deepest one given `leafId` as id.
const helpers =
    \\globalThis.chain = (n, leafId) => {
    \\  const root = document.createElement('div');
    \\  let leaf = root;
    \\  for (let made = 0; made < n; made += 500) {
    \\    let top, bottom;
    \\    top = bottom = document.createElement('div');
    \\    for (let i = 1; i < Math.min(500, n - made); i++) bottom = bottom.appendChild(document.createElement('div'));
    \\    leaf.appendChild(top);
    \\    leaf = bottom;
    \\  }
    \\  leaf.id = leafId;
    \\  return root;
    \\};
;

test "two 10,000-deep trees compare in constant stack: equal, then a difference at the bottom" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.run(helpers);
            try page.run("globalThis.a = chain(10000, 'x'); globalThis.b = chain(10000, 'x'); globalThis.c = chain(10000, 'y');");
            try page.expect("a.isEqualNode(b)", "true");
            try page.expect("a.isEqualNode(c)", "false");
            // One more level at the bottom of one tree.
            try page.run("{ let n = b; while (n.firstChild) n = n.firstChild; n.appendChild(document.createElement('div')); }");
            try page.expect("a.isEqualNode(b)", "false");
            try page.expect("b.isEqualNode(a)", "false");
        }
    }.body);
}

test "isEqualNode's walk: child counts, sibling order, text and attributes at every level" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.run(
                \\globalThis.make = (html) => { const d = document.createElement('div'); d.innerHTML = html; return d; };
            );
            try page.expect("make('<p>a</p><p b=1>c</p>').isEqualNode(make('<p>a</p><p b=1>c</p>'))", "true");
            try page.expect("make('<p>a</p><p b=1>c</p>').isEqualNode(make('<p>a</p><p b=2>c</p>'))", "false");
            try page.expect("make('<p>a</p><p>c</p>').isEqualNode(make('<p>a</p><p>c</p><p></p>'))", "false");
            try page.expect("make('<p>a</p><p>c</p><p></p>').isEqualNode(make('<p>a</p><p>c</p>'))", "false");
            try page.expect("make('<p><i></i></p><b></b>').isEqualNode(make('<p></p><i></i><b></b>'))", "false");
            try page.expect("make('<p><i></i></p><b></b>').isEqualNode(make('<p><i></i></p><b></b>'))", "true");
            try page.expect("make('<p>a</p>').isEqualNode(make('<p>b</p>'))", "false");
            try page.expect("make('').isEqualNode(make(''))", "true");
            try page.expect("make('<p></p>').isEqualNode(null)", "false");
        }
    }.body);
}
