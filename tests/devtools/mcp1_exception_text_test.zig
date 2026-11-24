//! Lane mcp1: an uncaught exception's Runtime.exceptionThrown carries
//! exceptionDetails.text "Uncaught", as Chrome's: Blink's
//! MainThreadDebugger::ExceptionThrown (core/inspector/main_thread_debugger.cc)
//! passes V8's inspector "Uncaught" as the message and the error event's
//! console message as the detailed one, and V8 puts the message in the text
//! beside the exception value. Crane passed the event's message for both, so
//! clients that print text + exception (chrome-devtools-mcp's
//! SymbolizedError, DevTools' console) read "TypeError: bad" where Chrome
//! gives "Uncaught TypeError: bad".

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

/// The next message on `link` (5 s) that `pick` accepts, parsed in `arena`.
fn next(link: *devtools.LocalLink, arena: std.mem.Allocator, allocator: std.mem.Allocator, comptime pick: fn (std.json.ObjectMap) bool) !std.json.ObjectMap {
    var waited: u32 = 0;
    while (waited < 5000) : (waited += 10) {
        const message = link.receive(10 * std.time.ns_per_ms) orelse continue;
        defer allocator.free(message);
        const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, message, .{});
        if (parsed == .object and pick(parsed.object)) return parsed.object;
    }
    return error.Timeout;
}

fn isAttach(o: std.json.ObjectMap) bool {
    const m = o.get("method") orelse return false;
    return std.mem.eql(u8, m.string, "Target.attachedToTarget");
}

fn isThrown(o: std.json.ObjectMap) bool {
    const m = o.get("method") orelse return false;
    return std.mem.eql(u8, m.string, "Runtime.exceptionThrown");
}

test "an uncaught TypeError's Runtime.exceptionThrown: text \"Uncaught\", the exception's description beside it" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .default_host = host });
    defer server.stop();
    const link = try server.openLocal();
    defer link.close();

    try link.send("{\"id\":1,\"method\":\"Target.setAutoAttach\",\"params\":{\"autoAttach\":true,\"waitForDebuggerOnStart\":false,\"flatten\":true}}");
    const attached = try next(link, arena, allocator, isAttach);
    const session = attached.get("params").?.object.get("sessionId").?.string;
    var buffer: [512]u8 = undefined;
    try link.send(try std.fmt.bufPrint(&buffer, "{{\"id\":2,\"method\":\"Runtime.enable\",\"sessionId\":\"{s}\"}}", .{session}));
    try link.send(try std.fmt.bufPrint(&buffer, "{{\"id\":3,\"method\":\"Page.navigate\",\"params\":{{\"url\":\"data:text/html,<script>throw new TypeError('bad')</script>\"}},\"sessionId\":\"{s}\"}}", .{session}));
    const thrown = try next(link, arena, allocator, isThrown);
    const details = thrown.get("params").?.object.get("exceptionDetails").?.object;
    try testing.expectEqualStrings("Uncaught", details.get("text").?.string);
    const description = details.get("exception").?.object.get("description").?.string;
    try testing.expect(std.mem.startsWith(u8, description, "TypeError: bad"));
}
