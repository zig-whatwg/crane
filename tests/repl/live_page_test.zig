//! The browser console as a headless browser on a live page (tools/repl.zig):
//! its navigation commands - `.open`, `.reload`, `.back`, `.forward`, `.url` -
//! the navigations a page makes itself (a link, a form, history.back()), what
//! the console prints of each ("Navigating to", "Navigated to <url>
//! (<status>)"), and the difference between a terminal, which gets its prompt
//! back at once as Chrome's console does, and scripted input, which waits for
//! the navigation an input started. Against the local site (site.zig).
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const Console = @import("repl").Console;
const Site = @import("site.zig").Site;

/// A Browser on about:blank, a console on it printing into a buffer, and the
/// local site. Not moved once made.
const Fixture = struct {
    site: *Site,
    browser: *Browser,
    output: std.Io.Writer.Allocating,
    console: Console,

    fn init(self: *Fixture) !void {
        self.site = try Site.start(testing.allocator);
        errdefer self.site.stop();
        self.browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer self.browser.deinit();
        self.output = .init(testing.allocator);
        self.console = Console.init(testing.allocator, self.browser, &self.output.writer);
        self.console.load_timeout_ms = 20_000;
    }

    fn deinit(self: *Fixture) void {
        self.console.deinit();
        self.output.deinit();
        self.browser.deinit();
        self.site.stop();
    }

    /// The site's URL for `path`. OWNED (testing.allocator).
    fn url(self: *Fixture, path: []const u8) ![]u8 {
        return self.site.url(testing.allocator, path);
    }

    /// Feed `line`: what the console printed for it.
    fn run(self: *Fixture, line: []const u8) ![]const u8 {
        self.output.clearRetainingCapacity();
        _ = try self.console.feedLine(line);
        return self.output.written();
    }

    fn runf(self: *Fixture, comptime format: []const u8, args: anytype) ![]const u8 {
        const line = try std.fmt.allocPrint(testing.allocator, format, args);
        defer testing.allocator.free(line);
        return self.run(line);
    }

    /// `.open` the site's `path`.
    fn open(self: *Fixture, path: []const u8) ![]const u8 {
        const target = try self.url(path);
        defer testing.allocator.free(target);
        return self.runf(".open {s}", .{target});
    }

    /// Run the loop - as the console does while it waits for input - until
    /// it has printed `text` (or 20 s pass).
    fn runUntilPrinted(self: *Fixture, text: []const u8) !void {
        const Goal = struct {
            fixture: *Fixture,
            text: []const u8,
            fn met(context: *anyopaque) bool {
                const goal: *@This() = @ptrCast(@alignCast(context));
                goal.fixture.console.poll();
                return std.mem.indexOf(u8, goal.fixture.output.written(), goal.text) != null;
            }
        };
        var goal: Goal = .{ .fixture = self, .text = text };
        const outcome = try self.browser.spinEventLoopUntil(.{ .context = &goal, .met = Goal.met }, 20_000);
        try testing.expectEqual(Browser.SpinOutcome.met, outcome);
    }
};

fn expectContains(haystack: []const u8, needle: []const u8) !void {
    if (std.mem.indexOf(u8, haystack, needle) == null) {
        std.debug.print("expected to find:\n{s}\nin:\n{s}\n", .{ needle, haystack });
        return error.TestExpectedContains;
    }
}

test ".open loads a page and waits for its load event; .url prints its URL; the navigation is printed with its status" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = try f.url("/a.html");
    defer testing.allocator.free(a);
    const opened = try f.open("/a.html");
    const navigated = try std.fmt.allocPrint(testing.allocator, "Navigated to {s} (200)\n", .{a});
    defer testing.allocator.free(navigated);
    try expectContains(opened, navigated);
    try testing.expectEqualStrings("'A'\n", try f.run("document.title"));
    try testing.expectEqualStrings("'complete'\n", try f.run("document.readyState"));
    const url_line = try std.fmt.allocPrint(testing.allocator, "{s}\n", .{a});
    defer testing.allocator.free(url_line);
    try testing.expectEqualStrings(url_line, try f.run(".url"));
}

test "a redirect and a 404 print the URL and status of what was loaded" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const b = try f.url("/b.html");
    defer testing.allocator.free(b);
    const redirected = try std.fmt.allocPrint(testing.allocator, "Navigated to {s} (200)\n", .{b});
    defer testing.allocator.free(redirected);
    try expectContains(try f.open("/redirect"), redirected);
    try testing.expectEqualStrings("'B'\n", try f.run("document.title"));

    const missing = try f.url("/missing");
    defer testing.allocator.free(missing);
    const not_found = try std.fmt.allocPrint(testing.allocator, "Navigated to {s} (404)\n", .{missing});
    defer testing.allocator.free(not_found);
    try expectContains(try f.open("/missing"), not_found);
    try testing.expectEqualStrings("'Not Found'\n", try f.run("document.title"));
}

test ".back and .forward traverse the tab's session history; at its ends there is nothing to traverse to" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.open("/a.html");
    _ = try f.open("/b.html");
    try testing.expectEqualStrings("'B'\n", try f.run("document.title"));
    _ = try f.run(".back");
    try testing.expectEqualStrings("'A'\n", try f.run("document.title"));
    _ = try f.run(".forward");
    try testing.expectEqualStrings("'B'\n", try f.run("document.title"));
    try expectContains(try f.run(".forward"), "(no next entry in the tab's session history)\n");
    try testing.expectEqualStrings("'B'\n", try f.run("document.title"));
}

test ".reload loads the page again, in the same tab: its sessionStorage counts the loads" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.open("/count.html");
    try testing.expectEqualStrings("'count 1'\n", try f.run("document.title"));
    _ = try f.run(".reload");
    try testing.expectEqualStrings("'count 2'\n", try f.run("document.title"));
}

test "a link's click, a form's submit and history.back() navigate the tab, and the next scripted line reads the new page" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.open("/a.html");
    const b = try f.url("/b.html");
    defer testing.allocator.free(b);
    const clicked = try std.fmt.allocPrint(testing.allocator, "Navigated to {s} (200)\n", .{b});
    defer testing.allocator.free(clicked);
    try expectContains(try f.run("document.getElementById('link').click()"), clicked);
    try testing.expectEqualStrings("'B'\n", try f.run("document.title"));

    _ = try f.run("history.back()");
    try testing.expectEqualStrings("'A'\n", try f.run("document.title"));

    _ = try f.run("document.getElementById('form').submit()");
    try testing.expectEqualStrings("'submitted'\n", try f.run("document.title"));
    try testing.expectEqualStrings("'q=hello'\n", try f.run("document.getElementById('posted').textContent"));
}

test "on a terminal the prompt comes back at once: a line before the commit reads the old page, and the navigation prints as it starts and commits" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    f.console.wait_for_navigation = false;
    _ = try f.open("/a.html");
    const b = try f.url("/b.html");
    defer testing.allocator.free(b);

    f.output.clearRetainingCapacity();
    const assign = try std.fmt.allocPrint(testing.allocator, "location.href = '{s}'", .{b});
    defer testing.allocator.free(assign);
    _ = try f.console.feedLine(assign);
    // The prompt came back before the new document committed: the next line
    // reads the old page.
    const before = f.output.written().len;
    _ = try f.console.feedLine("document.title");
    try expectContains(f.output.written()[before..], "'A'\n");

    const navigating = try std.fmt.allocPrint(testing.allocator, "Navigating to {s}\n", .{b});
    defer testing.allocator.free(navigating);
    const navigated = try std.fmt.allocPrint(testing.allocator, "Navigated to {s} (200)\n", .{b});
    defer testing.allocator.free(navigated);
    try f.runUntilPrinted(navigated);
    // Printed as it started, then as it committed.
    const all = f.output.written();
    const started_at = std.mem.indexOf(u8, all, navigating) orelse return error.TestNoNavigatingLine;
    try testing.expect(started_at < std.mem.indexOf(u8, all, navigated).?);
    try testing.expectEqualStrings("'B'\n", try f.run("document.title"));
}

test "the URL a page-started navigation goes to is readable while it is under way" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.open("/a.html");
    const b = try f.url("/b.html");
    defer testing.allocator.free(b);
    const tab = f.browser.hostTraversableId().?;
    try testing.expect(f.browser.traversableState(tab).?.navigating_to == null);

    const script = try std.fmt.allocPrint(testing.allocator, "location.href = '{s}'; 'started'", .{b});
    defer testing.allocator.free(script);
    const started = try f.browser.current_context.?.evaluateScriptToString(script, testing.allocator);
    defer testing.allocator.free(started);
    const state = f.browser.traversableState(tab).?;
    try testing.expect(state.navigating);
    try testing.expectEqualStrings(b, state.navigating_to orelse return error.TestNoNavigationUrl);
}

test "a fragment .open changes the URL in the same document" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.open("/a.html");
    try testing.expectEqualStrings("undefined\n", try f.run("window.marker = 1; undefined"));
    const target = try f.url("/a.html#part");
    defer testing.allocator.free(target);
    try expectContains(try f.runf(".open {s}", .{target}), "(same document)\n");
    // The same Window: what the page had is still there.
    try testing.expectEqualStrings("1\n", try f.run("window.marker"));
    try testing.expectEqualStrings("'#part'\n", try f.run("location.hash"));
}

test ".open of something that is not a URL says so and opens nothing" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try expectContains(try f.run(".open not a url"), "(could not open not a url: not a URL)\n");
    try testing.expectEqualStrings("about:blank\n", try f.run(".url"));
}

test "an unknown command, .help and a number that starts with a dot" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try expectContains(try f.run(".nope"), "Invalid console command: .nope");
    try expectContains(try f.run(".help"), ".open <url>");
    try testing.expectEqualStrings("1.5\n", try f.run(".5 + 1"));
}

test "window.open's popup is a tab: .tabs lists it, .tab selects it, .close closes it" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try f.open("/a.html");
    const popup = try f.url("/popup.html");
    defer testing.allocator.free(popup);
    _ = try f.runf("window.open('{s}'), undefined", .{popup});
    try f.runUntilPrinted("Navigated to");
    const tabs = try f.run(".tabs");
    try expectContains(tabs, "* 1  ");
    try expectContains(tabs, "\"A\"");
    try expectContains(tabs, "  2  ");
    try expectContains(tabs, "\"Popup\"  (popup of tab 1)");

    try expectContains(try f.run(".tab 2"), "(the console evaluates in tab 2: ");
    try testing.expectEqualStrings("'Popup'\n", try f.run("document.title"));
    try testing.expectEqualStrings("true\n", try f.run("window.opener !== null"));

    try expectContains(try f.run(".close 1"), "(the Browser's own tab closes with the console: .exit)\n");
    _ = try f.run(".close 2");
    try expectContains(try f.run(".tabs"), "* 1  ");
    try testing.expectEqualStrings("'A'\n", try f.run("document.title"));
    try expectContains(try f.run(".newtab"), "not supported yet");
}
