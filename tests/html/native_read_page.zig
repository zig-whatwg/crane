//! A real Browser page for tests that read, through the generated
//! interfaces, an object an element makes for script (lane lk1): classList,
//! part, dataset, children, attributeStyleMap, an SVG element's style and
//! className.
//!
//! Such an object is its WRAPPER's to end (docs/lessons/architecture-a-
//! native-sameobject-read-is-traced-like-a-script-read.md): the generated
//! [SameObject] getter traces it from its element (dom.same_object_cache ->
//! engine.traceChild), which makes its wrapper in the element's realm, and
//! the wrapper's collection - or the realm's end - frees it. A context made
//! with no engine realm, the fixture of tests/dom (real_nodes.zig), has no
//! wrapper, so nothing there ends the object: tests that read one ran over
//! an arena, or freed the object by hand. They run here instead, on the
//! production path: a Browser on the test's allocator, whose end fails the
//! test for anything left behind.
//!
//! Not a test file: the tests of this directory import it.

const std = @import("std");
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");

pub fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

pub const Page = struct {
    browser: *browser_mod.Browser,
    /// The page's document, and its body, which `element` appends to.
    document: *runtime.Instance,
    body: *runtime.Instance,

    /// A page of a Browser made with `allocator`.
    pub fn open(allocator: std.mem.Allocator) !Page {
        const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const context = browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        var page: Page = .{ .browser = browser, .document = undefined, .body = undefined };
        page.document = try page.object("document");
        page.body = try page.object("document.body");
        return page;
    }

    pub fn close(self: Page) void {
        self.browser.deinit();
    }

    /// The platform object `source` evaluates to. Script keeps it (the
    /// document, its body): the pointer is good while it does.
    pub fn object(self: Page, source: []const u8) !*runtime.Instance {
        const held = try self.browser.evaluateScript(source);
        defer held.release();
        const realm = self.browser.getRealm() orelse return error.NoRealm;
        return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
    }

    /// `document.createElement(local_name)`, made natively and not inserted:
    /// no wrapper, and nothing keeps it but its creator.
    pub fn uninserted(self: Page, local_name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, str(local_name), .{ .was_passed = false, .value = undefined });
    }

    /// `document.body.appendChild(document.createElement(local_name))`, made
    /// natively: no wrapper, and its document's tree keeps it.
    pub fn element(self: Page, local_name: []const u8) !*runtime.Instance {
        const made = try self.uninserted(local_name);
        _ = try interfaces.Node.call_appendChild(self.body, made);
        return made;
    }

    /// `document.body.appendChild(document.createElementNS(namespace, name))`.
    pub fn elementNS(self: Page, namespace: []const u8, name: []const u8) !*runtime.Instance {
        const made = try interfaces.Document.call_createElementNS(self.document, str(namespace), str(name), .notPassed());
        _ = try interfaces.Node.call_appendChild(self.body, made);
        return made;
    }

    /// Two full collections, then a turn of the event loop: a wrapper
    /// nothing reaches is collected, and what its collection left to free
    /// is freed.
    pub fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        const realm = self.browser.getRealm() orelse return error.NoRealm;
        const agent = self.browser.getAgent() orelse return error.NoAgent;
        try engine.runInRealm(realm, Collect.steps, agent);
        try engine.runInRealm(realm, Collect.steps, agent);
        try self.browser.runEventLoop(10);
    }
};

/// Run `body` on a page of its own, on a thread of its own, over
/// `std.testing.allocator`: the page's end reports what the test left.
pub fn onPage(comptime body: fn (Page) anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }

        fn exercise() !void {
            const page = try Page.open(std.testing.allocator);
            defer page.close();
            try body(page);
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// Run `exercise` on a thread of its own, for a test that opens its page
/// itself (on an allocator of its own).
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
