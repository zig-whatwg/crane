//! Lane mcp1: a title the page sets after its load reaches the target's
//! info - Target.getTargets, which the MCP server's list_pages reads - as
//! Chrome's does, and no Target.targetInfoChanged tells it: Chrome 157
//! sends that event for a commit only (tests/devtools/
//! mcp1_target_title_test.zig, against Chrome for Testing 157). Batch 1
//! pinned an event per title here, on the premise that Chrome sends one;
//! it does not.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

const Link = struct {
    link: *devtools.LocalLink,
    arena: std.mem.Allocator,
    allocator: std.mem.Allocator,
    next_id: i64 = 1,
    /// The titles every Target.targetInfoChanged named, in order.
    event_titles: std.ArrayList([]const u8) = .empty,

    fn send(self: *Link, method: []const u8, params: []const u8, session: ?[]const u8) !i64 {
        const id = self.next_id;
        self.next_id += 1;
        const text = if (session) |s|
            try std.fmt.allocPrint(self.arena, "{{\"id\":{d},\"method\":\"{s}\",\"params\":{s},\"sessionId\":\"{s}\"}}", .{ id, method, params, s })
        else
            try std.fmt.allocPrint(self.arena, "{{\"id\":{d},\"method\":\"{s}\",\"params\":{s}}}", .{ id, method, params });
        try self.link.send(text);
        return id;
    }

    /// The next message (5 s) `pick` accepts; every targetInfoChanged on
    /// the way is recorded.
    fn next(self: *Link, context: anytype, comptime pick: fn (@TypeOf(context), std.json.ObjectMap) bool) !std.json.ObjectMap {
        var waited: u32 = 0;
        while (waited < 5000) : (waited += 10) {
            const message = self.link.receive(10 * std.time.ns_per_ms) orelse continue;
            defer self.allocator.free(message);
            const parsed = try std.json.parseFromSliceLeaky(std.json.Value, self.arena, message, .{});
            if (parsed != .object) continue;
            if (std.mem.eql(u8, methodOf(parsed.object), "Target.targetInfoChanged")) {
                const info = parsed.object.get("params").?.object.get("targetInfo").?.object;
                if (std.mem.eql(u8, info.get("type").?.string, "page")) try self.event_titles.append(self.arena, info.get("title").?.string);
            }
            if (pick(context, parsed.object)) return parsed.object;
        }
        return error.Timeout;
    }

    /// Target.getTargets' page title.
    fn pageTitle(self: *Link) ![]const u8 {
        const id = try self.send("Target.getTargets", "{}", null);
        const answer = try self.next(id, isAnswer);
        for (answer.get("result").?.object.get("targetInfos").?.array.items) |info| {
            if (std.mem.eql(u8, info.object.get("type").?.string, "page")) return info.object.get("title").?.string;
        }
        return error.NoPage;
    }

    /// Target.getTargets' page title, asked until it is `want` (5 s): the
    /// title reaches the devtools thread on its own task.
    fn expectTitle(self: *Link, want: []const u8) !void {
        var tries: u32 = 0;
        while (tries < 500) : (tries += 1) {
            const title = try self.pageTitle();
            if (std.mem.eql(u8, title, want)) return;
            if (tries == 499) try testing.expectEqualStrings(want, title);
            std.Io.sleep(std.testing.io, .fromMilliseconds(10), .awake) catch {};
        }
    }

    /// Run `expression` in the page and wait for its answer.
    fn run(self: *Link, session: []const u8, expression: []const u8) !void {
        const params = try std.fmt.allocPrint(self.arena, "{{\"expression\":{f}}}", .{std.json.fmt(expression, .{})});
        _ = try self.next(try self.send("Runtime.evaluate", params, session), isAnswer);
    }
};

fn methodOf(o: std.json.ObjectMap) []const u8 {
    const m = o.get("method") orelse return "";
    return if (m == .string) m.string else "";
}

fn isAttach(_: void, o: std.json.ObjectMap) bool {
    return std.mem.eql(u8, methodOf(o), "Target.attachedToTarget");
}

fn isAnswer(id: i64, o: std.json.ObjectMap) bool {
    const v = o.get("id") orelse return false;
    return v == .integer and v.integer == id;
}

fn isLoad(_: void, o: std.json.ObjectMap) bool {
    return std.mem.eql(u8, methodOf(o), "Page.loadEventFired");
}

test "a title set after the load - by document.title, its text node, the element removed - is in Target.getTargets, and no targetInfoChanged tells it" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();

    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .default_host = host });
    defer server.stop();
    const link = try server.openLocal();
    defer link.close();
    var l: Link = .{ .link = link, .arena = arena_state.allocator(), .allocator = allocator };

    _ = try l.send("Target.setDiscoverTargets", "{\"discover\":true}", null);
    _ = try l.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":false,\"flatten\":true}", null);
    const attached = try l.next({}, isAttach);
    const session = attached.get("params").?.object.get("sessionId").?.string;
    _ = try l.next(try l.send("Page.enable", "{}", session), isAnswer);
    const url = "data:text/html,<title>First</title><p>x</p>";
    _ = try l.send("Page.navigate", "{\"url\":\"" ++ url ++ "\"}", session);
    _ = try l.next({}, isLoad);
    try l.expectTitle("First");

    try l.run(session, "document.title = 'Second'");
    try l.expectTitle("Second");
    try l.run(session, "document.querySelector('title').firstChild.data = 'Third'");
    try l.expectTitle("Third");
    // The title element removed: no title, which a target shows as its URL
    // (Chrome's GetTitleForDisplay: a data: URL as it is).
    try l.run(session, "document.querySelector('title').remove()");
    try l.expectTitle(url);

    // The commit's event alone, with the URL for its title.
    for (l.event_titles.items) |title| {
        if (std.mem.eql(u8, title, "First") or std.mem.eql(u8, title, "Second") or std.mem.eql(u8, title, "Third")) {
            std.debug.print("a targetInfoChanged named the title {s}\n", .{title});
            return error.TitleEvent;
        }
    }
}
