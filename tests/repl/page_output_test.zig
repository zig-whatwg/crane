//! The page's own output in the browser console (tools/repl.zig, the
//! Browser's developer console): console.* of the page, its frames, its
//! popups and its workers, and the exceptions and rejections nothing handled,
//! printed as they happen - not only while the console evaluates - and marked
//! with where they came from when that is not the one tab's own document.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const Console = @import("repl").Console;
const Site = @import("site.zig").Site;

const Fixture = struct {
    site: *Site,
    browser: *Browser,
    output: std.Io.Writer.Allocating,
    console: Console,

    fn init(self: *Fixture) !void {
        self.site = try Site.start(testing.allocator);
        errdefer self.site.stop();
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
        self.site.stop();
    }

    fn url(self: *Fixture, path: []const u8) ![]u8 {
        return self.site.url(testing.allocator, path);
    }

    fn run(self: *Fixture, line: []const u8) ![]const u8 {
        std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
        self.output.clearRetainingCapacity();
        std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
        _ = try self.console.feedLine(line);
        return self.printed();
    }

    fn printed(self: *Fixture) []const u8 {
        std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
        return self.output.written();
    }

    fn open(self: *Fixture, path: []const u8) !void {
        const target = try self.url(path);
        defer testing.allocator.free(target);
        const line = try std.fmt.allocPrint(testing.allocator, ".open {s}", .{target});
        defer testing.allocator.free(line);
        _ = try self.run(line);
    }

    /// Run the loop as the console does while it waits for input, until it
    /// has printed `text`.
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

fn expectContains(haystack: []const u8, needle: []const u8) !void {
    if (std.mem.indexOf(u8, haystack, needle) == null) {
        std.debug.print("expected to find:\n{s}\nin:\n{s}\n", .{ needle, haystack });
        return error.TestExpectedContains;
    }
}

test "the page's console.log prints when the page runs it - a timer's, while the console waits for input" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.open("/a.html");
    try testing.expectEqualStrings("logged\nundefined\n", try f.run("console.log('logged')"));
    _ = try f.run("setTimeout(() => console.log('from a timer', 1 + 1), 20), undefined");
    try f.runUntilPrinted("from a timer 2\n");
}

test "an uncaught exception and an unhandled rejection print as DevTools reports them" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.open("/a.html");
    _ = try f.run("setTimeout(() => { throw new TypeError('thrown later'); }, 10), undefined");
    try f.runUntilPrinted("Uncaught TypeError: thrown later\n");
    _ = try f.run("Promise.reject(new Error('nobody caught')), undefined");
    try f.runUntilPrinted("Uncaught (in promise) Error: nobody caught\n");
    // The source of a script's error: its URL and line.
    _ = try f.run("document.body.appendChild(Object.assign(document.createElement('script'), {textContent: '\\n\\nundefinedFunction()'})), undefined");
    try f.runUntilPrinted("Uncaught ReferenceError: undefinedFunction is not defined\n");
    try expectContains(f.printed(), "    at ");
}

test "a frame's console.log is marked with its frame" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.open("/a.html");
    const b = try f.url("/b.html");
    defer testing.allocator.free(b);
    const line = try std.fmt.allocPrint(testing.allocator, "const frame = document.body.appendChild(Object.assign(document.createElement('iframe'), {{src: '{s}'}})); await new Promise(r => frame.onload = r); frame.contentWindow.console.log('in the frame'), undefined", .{b});
    defer testing.allocator.free(line);
    const printed = try f.run(line);
    const marked = try std.fmt.allocPrint(testing.allocator, "[frame {s}] in the frame\n", .{b});
    defer testing.allocator.free(marked);
    try expectContains(printed, marked);
}

test "a dedicated worker's message and console.log arrive while the console waits for input" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.open("/a.html");
    _ = try f.run("const w = new Worker(URL.createObjectURL(new Blob([\"console.log('worker up'); postMessage('hello')\"]))); w.onmessage = e => console.log('page got', e.data); undefined");
    try f.runUntilPrinted("page got hello\n");
    try expectContains(f.printed(), "] worker up\n");
    try expectContains(f.printed(), "[worker blob:");
}

test "a popup's console.log is marked with its tab" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.open("/a.html");
    const popup = try f.url("/popup.html");
    defer testing.allocator.free(popup);
    const line = try std.fmt.allocPrint(testing.allocator, "const p = window.open('{s}'); await new Promise(r => p.onload = r); p.console.log('in the popup'), undefined", .{popup});
    defer testing.allocator.free(line);
    try expectContains(try f.run(line), "[tab 2] in the popup\n");
}
