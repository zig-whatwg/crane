//! The browser console as a headless browser against the local site
//! (site.zig): a page's script that fetches JSON and writes the DOM, XHR,
//! cookies set by the server and by script and seen after a reload, and
//! storage that stays with its Browser - a second console run starts with
//! none of the first's (the console is in memory: no profile persists).
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const Console = @import("repl").Console;
const Site = @import("site.zig").Site;

const Fixture = struct {
    browser: *Browser,
    output: std.Io.Writer.Allocating,
    console: Console,

    fn init(self: *Fixture) !void {
        self.browser = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
        errdefer self.browser.deinit();
        self.output = .init(testing.allocator);
        self.console = Console.init(testing.allocator, self.browser, &self.output.writer);
        self.console.load_timeout_ms = 20_000;
        try self.console.attach();
    }

    fn deinit(self: *Fixture) void {
        self.console.deinit();
        self.output.deinit();
        self.browser.deinit();
    }

    fn printed(self: *Fixture) []const u8 {
        std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
        return self.output.written();
    }

    fn run(self: *Fixture, line: []const u8) ![]const u8 {
        std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
        self.output.clearRetainingCapacity();
        std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
        _ = try self.console.feedLine(line);
        return self.printed();
    }

    fn runf(self: *Fixture, comptime format: []const u8, args: anytype) ![]const u8 {
        const line = try std.fmt.allocPrint(testing.allocator, format, args);
        defer testing.allocator.free(line);
        return self.run(line);
    }

    fn open(self: *Fixture, site: *Site, path: []const u8) !void {
        const target = try site.url(testing.allocator, path);
        defer testing.allocator.free(target);
        _ = try self.runf(".open {s}", .{target});
    }

    fn runUntilPrinted(self: *Fixture, text: []const u8) !void {
        const Goal = struct {
            fixture: *Fixture,
            text: []const u8,
            fn met(context: *anyopaque) bool {
                const goal: *@This() = @ptrCast(@alignCast(context));
                goal.fixture.console.poll();
                return std.mem.indexOf(u8, goal.fixture.printed(), goal.text) != null;
            }
        };
        var goal: Goal = .{ .fixture = self, .text = text };
        const outcome = try self.browser.spinEventLoopUntil(.{ .context = &goal, .met = Goal.met }, 20_000);
        if (outcome != .met) {
            std.debug.print("never printed {s}; printed:\n{s}\n", .{ text, self.printed() });
            return error.TestNotPrinted;
        }
    }
};

test "a page's script fetches JSON and writes the DOM; the console reads what it wrote" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.open(site, "/fetch.html");
    try f.runUntilPrinted("fetched 2\n");
    try testing.expectEqualStrings("'x,y'\n", try f.run("[...document.querySelectorAll('#out li')].map(li => li.textContent).join()"));
    try testing.expectEqualStrings("['x', 'y']\n", try f.run("(await (await fetch('/data.json')).json()).items"));
}

test "XMLHttpRequest from the console's input" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.open(site, "/a.html");
    try testing.expectEqualStrings("'200 {\"items\":[\"x\",\"y\"]}'\n", try f.run("await new Promise(r => { const x = new XMLHttpRequest(); x.open('GET', '/data.json'); x.onload = () => r(x.status + ' ' + x.responseText); x.send(); })"));
}

test "a cookie the server set and one script set are both sent after .reload" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.open(site, "/cookie.html");
    // The first load set the server's cookie; it was not sent with it.
    try testing.expectEqualStrings("''\n", try f.run("document.getElementById('sent').textContent"));
    try testing.expectEqualStrings("'server=1'\n", try f.run("document.cookie"));
    _ = try f.run("document.cookie = 'script=2; path=/'");
    _ = try f.run(".reload");
    const sent = try f.run("document.getElementById('sent').textContent");
    if (std.mem.indexOf(u8, sent, "server=1") == null or std.mem.indexOf(u8, sent, "script=2") == null) {
        std.debug.print("sent: {s}\n", .{sent});
        return error.TestCookiesNotSent;
    }
}

test "localStorage and IndexedDB live as long as their Browser: a second console run starts without the first's" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    {
        var f: Fixture = undefined;
        try f.init();
        defer f.deinit();
        try f.open(site, "/a.html");
        _ = try f.run("localStorage.setItem('k', 'kept')");
        try testing.expectEqualStrings("'kept'\n", try f.run("localStorage.getItem('k')"));
        try testing.expectEqualStrings("'stored'\n", try f.run("await new Promise((resolve, reject) => { const open = indexedDB.open('db', 1); open.onupgradeneeded = () => open.result.createObjectStore('s'); open.onsuccess = () => { const t = open.result.transaction('s', 'readwrite'); t.objectStore('s').put('v', 'key'); t.oncomplete = () => { open.result.close(); resolve('stored'); }; }; open.onerror = () => reject(open.error); })"));
        try testing.expectEqualStrings("['db']\n", try f.run("(await indexedDB.databases()).map(d => d.name)"));
    }
    // The second run: a new Browser on the same origin.
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.open(site, "/a.html");
    try testing.expectEqualStrings("null\n", try f.run("localStorage.getItem('k')"));
    try testing.expectEqualStrings("[]\n", try f.run("(await indexedDB.databases()).map(d => d.name)"));
}
