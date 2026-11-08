//! Serializing a deep tree takes constant native stack (lane crash1 batch
//! 2; the zero-crashes rule).
//!
//! The HTML fragment serialization algorithm and DOM Parsing's XML
//! serialization recurse once per tree level, and src/html/serialization.zig
//! did too (Writer.children -> node -> element -> children): outerHTML,
//! innerHTML and XMLSerializer of a 100,000-deep tree crashed the release
//! runner (crash1 b2's sweep, crane/crash1-probe2/sweep-*.html). The writer
//! now keeps its open elements on the heap; its output is unchanged. Firefox
//! 159 serializes such a tree, Chrome crashes, WebKit stops recursing at
//! 1,024 levels; the spec sets no limit.
//!
//! Each test runs on a thread with a pinned 8 MiB stack, at 10,000 levels -
//! more than twice what the recursion fitted there in a Debug build. 100,000
//! levels would take minutes to build here (each insert walks the ancestors;
//! the queued deep-construction perf item); the release runner's probe pages
//! serialize 100,000. The shadow-root test pins the order the stack keeps:
//! a host's declarative shadow root before its light children.
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

/// `globalThis.root`: a div with 10,000 levels of divs below it, in the
/// document, built in 500-level chunks.
const build =
    \\globalThis.root = document.createElement('div');
    \\document.body.appendChild(root);
    \\{
    \\  let leaf = root;
    \\  for (let made = 0; made < 10000; made += 500) {
    \\    let top, bottom;
    \\    top = bottom = document.createElement('div');
    \\    for (let i = 1; i < 500; i++) bottom = bottom.appendChild(document.createElement('div'));
    \\    leaf.appendChild(top);
    \\    leaf = bottom;
    \\  }
    \\}
;

test "outerHTML and innerHTML of a 10,000-deep tree, in constant stack" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.run(build);
            try page.expect("root.outerHTML === '<div>'.repeat(10001) + '</div>'.repeat(10001)", "true");
            try page.expect("root.innerHTML === '<div>'.repeat(10000) + '</div>'.repeat(10000)", "true");
        }
    }.body);
}

test "XMLSerializer of a 10,000-deep tree, in constant stack" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.run(build);
            // The root declares the HTML namespace; its descendants inherit it.
            try page.expect("new XMLSerializer().serializeToString(root) === '<div xmlns=\"http://www.w3.org/1999/xhtml\">' + '<div>'.repeat(10000) + '</div>'.repeat(10001)", "true");
        }
    }.body);
}

test "a deep tree's void leaf, text and attributes serialize as before" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.run(build);
            try page.run(
                \\{ let leaf = root; while (leaf.firstChild) leaf = leaf.firstChild;
                \\  leaf.setAttribute('id', 'deep'); leaf.appendChild(document.createElement('br'));
                \\  leaf.appendChild(document.createTextNode('a<b')); }
            );
            try page.expect("root.innerHTML.endsWith('<div id=\"deep\"><br>a&lt;b</div>' + '</div>'.repeat(9999))", "true");
            try page.expect("new XMLSerializer().serializeToString(root).endsWith('<div id=\"deep\"><br />a&lt;b</div>' + '</div>'.repeat(10000))", "true");
        }
    }.body);
}

test "getHTML writes a host's serializable shadow root before its light children" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.run(
                \\globalThis.host = document.createElement('div');
                \\const shadow = host.attachShadow({ mode: 'open', serializable: true });
                \\shadow.innerHTML = '<span>in</span>';
                \\host.innerHTML = '<b>light</b><i></i>';
                \\globalThis.outer = document.createElement('section');
                \\outer.appendChild(host);
            );
            try page.expect("outer.getHTML({ serializableShadowRoots: true })", "<div><template shadowrootmode=\"open\" shadowrootserializable=\"\"><span>in</span></template><b>light</b><i></i></div>");
            try page.expect("outer.getHTML()", "<div><b>light</b><i></i></div>");
        }
    }.body);
}
