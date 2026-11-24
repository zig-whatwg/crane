//! Lane mcp1, batch 1: the in-process session link Crane's MCP server speaks
//! CDP through (devtools.Server.openLocal, devtools.LocalLink; design
//! tmp/plans/mcp1-design.md 2.1): a browser session at once, as a pipe's
//! connection is, answering the same handlers every client reaches, and its
//! end detaching what it attached.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

/// The next message on `link` whose `"id"` is `id` (5 s), OWNED.
fn answer(link: *devtools.LocalLink, allocator: std.mem.Allocator, id: i64) ![]u8 {
    var waited: u32 = 0;
    while (waited < 5000) : (waited += 10) {
        const message = link.receive(10 * std.time.ns_per_ms) orelse continue;
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, message, .{}) catch {
            allocator.free(message);
            continue;
        };
        defer parsed.deinit();
        if (parsed.value.object.get("id")) |v| if (v == .integer and v.integer == id) return message;
        allocator.free(message);
    }
    return error.Timeout;
}

test "a local link is a browser session at once: Browser.getVersion and Target.getTargets answer through the same handlers, and close ends it" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    // The host's first page.
    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .default_host = host });
    defer server.stop();

    const link = try server.openLocal();
    try link.send("{\"id\":1,\"method\":\"Browser.getVersion\"}");
    const version = try answer(link, allocator, 1);
    defer allocator.free(version);
    try testing.expect(std.mem.indexOf(u8, version, "\"protocolVersion\":\"1.3\"") != null);

    try link.send("{\"id\":2,\"method\":\"Target.getTargets\"}");
    const targets = try answer(link, allocator, 2);
    defer allocator.free(targets);
    try testing.expect(std.mem.indexOf(u8, targets, "\"type\":\"page\"") != null);

    // An unknown method: the dispatcher's own error, as for any client.
    try link.send("{\"id\":3,\"method\":\"Nope.nothing\"}");
    const refused = try answer(link, allocator, 3);
    defer allocator.free(refused);
    try testing.expect(std.mem.indexOf(u8, refused, "\"error\"") != null);

    link.close();
}

test "a local link's attach is a flat session: auto-attach announces the page, and commands on its sessionId reach the page" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    // The host's first page.
    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .default_host = host });
    defer server.stop();
    const link = try server.openLocal();
    defer link.close();

    try link.send("{\"id\":1,\"method\":\"Target.setAutoAttach\",\"params\":{\"autoAttach\":true,\"waitForDebuggerOnStart\":false,\"flatten\":true}}");
    // The attach event comes before or after the answer; collect both.
    var session_id: ?[]u8 = null;
    defer if (session_id) |s| allocator.free(s);
    var answered = false;
    var waited: u32 = 0;
    while ((session_id == null or !answered) and waited < 5000) : (waited += 10) {
        const message = link.receive(10 * std.time.ns_per_ms) orelse continue;
        defer allocator.free(message);
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, message, .{});
        defer parsed.deinit();
        const object = parsed.value.object;
        if (object.get("id")) |v| if (v == .integer and v.integer == 1) {
            answered = true;
        };
        if (object.get("method")) |m| if (std.mem.eql(u8, m.string, "Target.attachedToTarget")) {
            const params = object.get("params").?.object;
            if (session_id == null and std.mem.eql(u8, params.get("targetInfo").?.object.get("type").?.string, "page")) {
                session_id = try allocator.dupe(u8, params.get("sessionId").?.string);
            }
        };
    }
    try testing.expect(answered);
    const page_session = session_id orelse return error.NoAttach;

    var buffer: [256]u8 = undefined;
    try link.send(try std.fmt.bufPrint(&buffer, "{{\"id\":2,\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"6*7\",\"returnByValue\":true}},\"sessionId\":\"{s}\"}}", .{page_session}));
    const evaluated = try answer(link, allocator, 2);
    defer allocator.free(evaluated);
    try testing.expect(std.mem.indexOf(u8, evaluated, "\"value\":42") != null);
}
