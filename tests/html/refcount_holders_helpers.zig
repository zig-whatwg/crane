//! Shared by the refcount step-5 holder tests (lane rc5; tmp/plans/refcount-
//! design.md section 7, step 5): a page on a thread of its own, a node read
//! from script, two collections with a task turn between, and the count
//! check. SHADOW MODE: the counts decide nothing yet (frees are still the
//! collector's), so each test reads them through `dom.refcount.count`:
//! born (1) + the wrapper's (1, the node is kept by a global) + the holders'.
pub const std = @import("std");
pub const testing = std.testing;
pub const browser_mod = @import("browser");
pub const runtime = @import("runtime");
pub const engine = @import("engine");
pub const dom = @import("dom");

pub fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

pub const Page = struct {
    browser: *browser_mod.Browser,

    pub fn open() !Page {
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        return .{ .browser = browser };
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

    /// The node `source` evaluates to (keep it in a global: its wrapper's
    /// reference must stay put).
    pub fn node(self: Page, source: []const u8) !*dom.NodeBase {
        const held = try self.browser.evaluateScript(source);
        defer held.release();
        const realm = self.browser.getRealm() orelse return error.NoRealm;
        const instance = engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NotAPlatformObject;
        return dom.instance_bridge.getNodeBase(@ptrCast(instance)) orelse error.NotANode;
    }

    /// Two collections, with a task turn between, so a dropped holder's
    /// wrapper is finalized and the holder freed.
    pub fn collect(self: Page) !void {
        try self.run("TestUtils.gc();");
        _ = try self.browser.runEventLoopBlocking(20);
        try self.run("TestUtils.gc(); TestUtils.gc();");
    }
};

pub fn expectCount(expected: u32, node: *dom.NodeBase, what: []const u8) !void {
    const actual = dom.refcount.count(node);
    if (actual != expected) {
        std.debug.print("{s}: count {d}, expected {d}\n", .{ what, actual, expected });
        return error.WrongCount;
    }
}
