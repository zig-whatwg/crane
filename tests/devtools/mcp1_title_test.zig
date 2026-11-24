//! Lane mcp1, batch 2: a title the page sets after its load reaches the
//! target's info, as Chrome's does - Blink reports every title change
//! (HTMLTitleElement::ChildrenChanged / InsertedInto / RemovedFrom ->
//! Document::UpdateTitle -> WebContents TitleWasSet), so Target.getTargets
//! and Target.targetInfoChanged carry it. Crane reported the title only at
//! DOMContentLoaded and load; the MCP differential pass showed a page that
//! retitles itself from a fetch listed under its old title.

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

    /// The next message (5 s) `pick` accepts.
    fn next(self: *Link, context: anytype, comptime pick: fn (@TypeOf(context), std.json.ObjectMap) bool) !std.json.ObjectMap {
        var waited: u32 = 0;
        while (waited < 5000) : (waited += 10) {
            const message = self.link.receive(10 * std.time.ns_per_ms) orelse continue;
            defer self.allocator.free(message);
            const parsed = try std.json.parseFromSliceLeaky(std.json.Value, self.arena, message, .{});
            if (parsed == .object and pick(context, parsed.object)) return parsed.object;
        }
        return error.Timeout;
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

fn titledInfo(title: []const u8, o: std.json.ObjectMap) bool {
    if (!std.mem.eql(u8, methodOf(o), "Target.targetInfoChanged")) return false;
    const info = o.get("params").?.object.get("targetInfo").?.object;
    return std.mem.eql(u8, info.get("title").?.string, title);
}

/// Target.getTargets' page title.
fn pageTitle(l: *Link) ![]const u8 {
    const id = try l.send("Target.getTargets", "{}", null);
    const answer = try l.next(id, isAnswer);
    for (answer.get("result").?.object.get("targetInfos").?.array.items) |info| {
        if (std.mem.eql(u8, info.object.get("type").?.string, "page")) return info.object.get("title").?.string;
    }
    return error.NoPage;
}

test "a title set after the load - by document.title, then by its text node - reaches targetInfoChanged and Target.getTargets" {
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
    _ = try l.send("Page.enable", "{}", session);
    _ = try l.send("Page.navigate", "{\"url\":\"data:text/html,<title>First</title><p>x</p>\"}", session);
    _ = try l.next(@as([]const u8, "First"), titledInfo);

    _ = try l.send("Runtime.evaluate", "{\"expression\":\"document.title = 'Second'\"}", session);
    _ = try l.next(@as([]const u8, "Second"), titledInfo);
    try testing.expectEqualStrings("Second", try pageTitle(&l));

    _ = try l.send("Runtime.evaluate", "{\"expression\":\"document.querySelector('title').firstChild.data = 'Third'\"}", session);
    _ = try l.next(@as([]const u8, "Third"), titledInfo);
    try testing.expectEqualStrings("Third", try pageTitle(&l));

    // The title element removed: no title, which a target shows as its URL
    // (WebContents::GetTitle's fallback).
    _ = try l.send("Runtime.evaluate", "{\"expression\":\"document.querySelector('title').remove()\"}", session);
    _ = try l.next(@as([]const u8, "data:text/html,<title>First</title><p>x</p>"), titledInfo);
}
