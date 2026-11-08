//! The HTML parser bounds the DOM depth it builds: past 512 open elements a
//! node goes to its parent's parent (lane crash1 batch 2).
//!
//! The spec sets no bound; every browser has one. Blink
//! HTMLConstructionSite::Attach (kMaximumHTMLParserDOMTreeDepth = 512) and
//! Gecko (nsHtml5TreeBuilder nodeFromStackWithBlinkCompat) nest at most 512
//! levels under a fragment's root and 511 under a document's body; WebKit one
//! level fewer. Measured (lane crash1 b1, tmp/crash1/probe): innerHTML of 513
//! nested divs is 512 deep in Chrome 156 and Firefox 159, 511 in Safari 27;
//! a document's body 511, 511 and 510. Golden rule 2: the majority, 512.
//! Crane built every level: 30,000 nested divs parsed in 32 s (each insert
//! walks the ancestors) into a tree whose teardown overflowed the stack.
//!
//! Past the bound the open elements keep nesting, the DOM does not: the
//! 513th nested div of a fragment is the 512th's next sibling, and every
//! later one too - all children of the 511th. Blink's mechanism whole (the
//! integrator's ruling): a void element, a self-closing foreign element and
//! a comment are attached without being pushed, so they are bounded one
//! level deeper; text is never bounded. The edge cases below are Chrome
//! 157's measured trees (tmp/crash1/probe/depth2.html,
//! results-chromed.jsonl).
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

/// `levels(node)`: how many levels the first-child chain below `node` goes.
/// `childrenAt(node, k)`: how many children the node k levels down that chain
/// has.
const helpers =
    \\globalThis.levels = (node) => { let n = 0; while (node.firstChild) { node = node.firstChild; n++; } return n; };
    \\globalThis.childrenAt = (node, k) => { for (let i = 0; i < k; i++) node = node.firstChild; return node.childNodes.length; };
    \\globalThis.maxDepth = (root) => { let max = 0; const stack = [[root, 0]]; while (stack.length) { const [n, d] = stack.pop(); if (d > max) max = d; for (let c = n.firstChild; c; c = c.nextSibling) stack.push([c, d + 1]); } return max; };
;

const Page = struct {
    browser: *Browser,

    fn open(html: []const u8) !Page {
        const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML(html, .{ .base_url = "about:blank" });
        _ = try browser.runEventLoopBlocking(10);
        try page.runScript(helpers);
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

/// A document whose body holds `n` nested divs. OWNED by the caller.
fn nestedDocument(n: usize) ![]u8 {
    const prefix = "<!doctype html><body>";
    const out = try testing.allocator.alloc(u8, prefix.len + n * "<div>".len);
    @memcpy(out[0..prefix.len], prefix);
    for (0..n) |i| @memcpy(out[prefix.len + i * 5 ..][0..5], "<div>");
    return out;
}

/// A page of a document whose body holds `n` nested divs.
fn openNested(n: usize) !Page {
    const html = try nestedDocument(n);
    defer testing.allocator.free(html);
    return Page.open(html);
}

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
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

test "innerHTML of 513 nested divs nests 512 deep: the 513th is the 512th's sibling" {
    try onFreshThread(struct {
        fn run() !void {
            const page = try Page.open("<!doctype html><body>");
            defer page.close();
            try page.run("globalThis.d = document.createElement('div'); d.innerHTML = '<div>'.repeat(513);");
            try page.expect("levels(d)", "512");
            try page.expect("maxDepth(d)", "512");
            // The 511th div holds the 512th and the 513th.
            try page.expect("childrenAt(d, 511)", "2");
            try page.expect("d.querySelectorAll('div').length", "513");
        }
    }.run);
}

test "innerHTML of 10,000 nested divs nests 512 deep, the rest the 511th's children" {
    try onFreshThread(struct {
        fn run() !void {
            const page = try Page.open("<!doctype html><body>");
            defer page.close();
            try page.run("globalThis.d = document.createElement('div'); d.innerHTML = '<div>'.repeat(10000);");
            try page.expect("levels(d)", "512");
            try page.expect("maxDepth(d)", "512");
            try page.expect("childrenAt(d, 511)", "9489");
            try page.expect("d.querySelectorAll('div').length", "10000");
        }
    }.run);
}

test "a document's 513 nested divs nest 511 deep under its body" {
    try onFreshThread(struct {
        fn run() !void {
            const page = try openNested(513);
            defer page.close();
            try page.expect("levels(document.body)", "511");
            try page.expect("maxDepth(document.body)", "511");
            // The 510th div holds the 511th, 512th and 513th.
            try page.expect("childrenAt(document.body, 510)", "3");
            try page.expect("document.querySelectorAll('div').length", "513");
        }
    }.run);
}

test "a document's 10,000 nested divs nest 511 deep under its body" {
    try onFreshThread(struct {
        fn run() !void {
            const page = try openNested(10_000);
            defer page.close();
            try page.expect("levels(document.body)", "511");
            try page.expect("maxDepth(document.body)", "511");
            try page.expect("childrenAt(document.body, 510)", "9490");
            try page.expect("document.querySelectorAll('div').length", "10000");
        }
    }.run);
}

test "text past the bound goes into the current node: one level below the deepest element" {
    try onFreshThread(struct {
        fn run() !void {
            const page = try Page.open("<!doctype html><body>");
            defer page.close();
            try page.run("globalThis.d = document.createElement('div'); d.innerHTML = '<div>'.repeat(600) + 'x';");
            // The 600th div is a child of the 511th, 512 levels down; its
            // text is in it.
            try page.expect("maxDepth(d)", "513");
            try page.expect("d.querySelectorAll('div')[599].textContent", "x");
            try page.expect("d.querySelectorAll('div')[599].parentNode === d.querySelectorAll('div')[510]", "true");
        }
    }.run);
}

test "at 512 open elements a void element, a self-closing svg and a comment still go into the current node (Chrome)" {
    try onFreshThread(struct {
        fn run() !void {
            const page = try Page.open("<!doctype html><body>");
            defer page.close();
            // Chrome: inner-div-512+br, +svg/, +comment, +text all @513.
            try page.run("globalThis.d = document.createElement('div'); d.innerHTML = '<div>'.repeat(512) + '<br><svg/><!--c-->x';");
            try page.run("globalThis.at512 = d.querySelectorAll('div')[511];");
            try page.expect("[...at512.childNodes].map(n => n.nodeName).join(',')", "BR,svg,#comment,#text");
            try page.expect("maxDepth(d)", "513");
        }
    }.run);
}

test "past 512 open elements a void element, a self-closing svg and a comment go to the parent's parent; text does not (Chrome)" {
    try onFreshThread(struct {
        fn run() !void {
            const page = try Page.open("<!doctype html><body>");
            defer page.close();
            // Chrome: inner-div-513+br, +svg/, +comment @512, +text @513.
            try page.run("globalThis.d = document.createElement('div'); d.innerHTML = '<div>'.repeat(513) + '<br><svg/><!--c-->x';");
            try page.run("globalThis.at511 = d.querySelectorAll('div')[510]; globalThis.at513 = d.querySelectorAll('div')[512];");
            try page.expect("[...at511.childNodes].map(n => n.nodeName).join(',')", "DIV,DIV,BR,svg,#comment");
            try page.expect("[...at513.childNodes].map(n => n.nodeName).join(',')", "#text");
            try page.expect("maxDepth(d)", "513");
        }
    }.run);
}

test "a document's body: a void element and a comment one level deeper than an element at the bound (Chrome)" {
    try onFreshThread(struct {
        fn run() !void {
            // Chrome: doc-div-511+br and +comment @512, doc-div-512+br and
            // +comment @511 (under the body).
            {
                const html = try nestedDocument(511);
                defer testing.allocator.free(html);
                const doc = try std.mem.concat(testing.allocator, u8, &.{ html, "<br><!--c-->" });
                defer testing.allocator.free(doc);
                const page = try Page.open(doc);
                defer page.close();
                try page.expect("[...document.querySelectorAll('div')[510].childNodes].map(n => n.nodeName).join(',')", "BR,#comment");
                try page.expect("maxDepth(document.body)", "512");
            }
            {
                const html = try nestedDocument(512);
                defer testing.allocator.free(html);
                const doc = try std.mem.concat(testing.allocator, u8, &.{ html, "<br><!--c-->" });
                defer testing.allocator.free(doc);
                const page = try Page.open(doc);
                defer page.close();
                try page.expect("[...document.querySelectorAll('div')[509].childNodes].map(n => n.nodeName).join(',')", "DIV,DIV,BR,#comment");
                try page.expect("maxDepth(document.body)", "511");
            }
        }
    }.run);
}

test "DOMParser application/xml: 5,000 nested elements parse, 5,001 are a parsererror" {
    try onFreshThread(struct {
        fn run() !void {
            const page = try Page.open("<!doctype html><body>");
            defer page.close();
            // Chrome 157, Firefox 159 and Safari 27.2: the same boundary
            // (tmp/crash1/probe/depth2.html, xml-boundary).
            try page.run("globalThis.xmlOf = (n, inner) => new DOMParser().parseFromString('<a>'.repeat(n) + inner + '</a>'.repeat(n), 'application/xml');");
            try page.expect("(() => { const d = xmlOf(5000, 'x'); return d.getElementsByTagName('parsererror').length + ' ' + maxDepth(d); })()", "0 5001");
            try page.expect("xmlOf(5001, '').getElementsByTagName('parsererror').length > 0", "true");
            try page.expect("xmlOf(30000, '').getElementsByTagName('parsererror').length > 0", "true");
        }
    }.run);
}
