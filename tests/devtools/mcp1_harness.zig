//! Lane mcp1: Crane's MCP server driven as an MCP client drives it -
//! initialize, then tools/list and tools/call - against a Browser on its own
//! thread, with one page (the host's first), every allocation leak-checked.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const mcp = devtools.mcp;

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

pub const Harness = struct {
    gpa: LeakChecked = .init,
    host: *browser_mod.BrowserHost = undefined,
    server: *devtools.Server = undefined,
    mcp_server: *mcp.server.McpServer = undefined,
    arena: std.heap.ArenaAllocator = undefined,
    next_id: u32 = 1,

    pub fn start(self: *Harness) !void {
        const allocator = self.gpa.allocator();
        self.arena = .init(allocator);
        // The host's first page is the one page there is.
        self.host = try browser_mod.BrowserHost.start(allocator, .{});
        self.server = try devtools.Server.start(allocator, .{ .default_host = self.host });
        self.mcp_server = try mcp.server.McpServer.create(allocator, self.server);
        _ = try self.send("initialize", "{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1\"}}");
    }

    pub fn stop(self: *Harness) void {
        self.mcp_server.destroy();
        self.server.stop();
        self.host.stop();
        self.arena.deinit();
        testing.expect(self.gpa.deinit() == .ok) catch @panic("leak");
    }

    /// A request's parsed answer.
    pub fn send(self: *Harness, method: []const u8, params: []const u8) !std.json.Value {
        const a = self.arena.allocator();
        const id = self.next_id;
        self.next_id += 1;
        const message = try std.fmt.allocPrint(a, "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"method\":\"{s}\",\"params\":{s}}}", .{ id, method, params });
        const answer = (try self.mcp_server.handle(a, message)) orelse return error.NoAnswer;
        return std.json.parseFromSliceLeaky(std.json.Value, a, answer, .{});
    }

    /// Let the browser's events reach the MCP server for `ms` (what comes
    /// between two calls).
    pub fn settle(self: *Harness, ms: u32) !void {
        var waited: u32 = 0;
        while (waited < ms) : (waited += 10) _ = try self.mcp_server.session.client.pump(10 * std.time.ns_per_ms);
    }

    /// tools/call `name`: its text, and whether it is an error.
    pub fn tool(self: *Harness, name: []const u8, arguments: []const u8) !struct { text: []const u8, is_error: bool } {
        const a = self.arena.allocator();
        const answer = try self.send("tools/call", try std.fmt.allocPrint(a, "{{\"name\":\"{s}\",\"arguments\":{s}}}", .{ name, arguments }));
        const result = answer.object.get("result") orelse return error.NoResult;
        const content = result.object.get("content").?.array.items;
        const is_error = if (result.object.get("isError")) |e| e.bool else false;
        return .{ .text = content[0].object.get("text").?.string, .is_error = is_error };
    }
};
