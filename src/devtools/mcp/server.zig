//! One MCP server instance (design tmp/plans/mcp1-design.md 2.1-2.2): an
//! in-process CDP connection to Crane's devtools server, the MCP session over
//! it, and the protocol envelope. A transport feeds it messages - `serveStdio`
//! for `crane --mcp` (newline-delimited JSON-RPC on stdin and stdout,
//! https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
//! "stdio": "Messages are delimited by newlines, and MUST NOT contain embedded
//! newlines"; nothing but MCP messages on stdout).

const std = @import("std");
const Allocator = std.mem.Allocator;
const DevtoolsServer = @import("../server.zig").Server;
const LocalLink = @import("../server.zig").LocalLink;
const protocol = @import("protocol.zig");
const Session = @import("session.zig").Session;
const tools = @import("tools.zig");

/// The serverInfo it names (Crane's, not chrome-devtools-mcp's).
pub const server_name = "crane";
pub const server_version = "0.1.0";

pub const McpServer = struct {
    allocator: Allocator,
    link: *LocalLink,
    session: *Session,
    tools_json: []u8,
    protocol: protocol.Protocol,

    pub fn create(allocator: Allocator, devtools: *DevtoolsServer) !*McpServer {
        const self = try allocator.create(McpServer);
        errdefer allocator.destroy(self);
        const link = try devtools.openLocal();
        errdefer link.close();
        const session = try Session.create(allocator, link);
        errdefer session.destroy();
        const tools_json = try tools.listJson(allocator);
        errdefer allocator.free(tools_json);
        // The input schemas each call is checked against.
        session.schemas = try std.json.parseFromSlice(std.json.Value, allocator, tools_json, .{});
        self.* = .{
            .allocator = allocator,
            .link = link,
            .session = session,
            .tools_json = tools_json,
            .protocol = .{
                .handler = .{ .context = session, .tools_json = tools_json, .call = tools.call, .disabled = tools.disabled },
                .info = .{ .name = server_name, .version = server_version },
            },
        };
        self.protocol.handler.tools_json = self.tools_json;
        return self;
    }

    pub fn destroy(self: *McpServer) void {
        self.session.destroy();
        self.link.close();
        self.allocator.free(self.tools_json);
        self.allocator.destroy(self);
    }

    /// Answer one message; the answer (null: none) lives in `arena`.
    pub fn handle(self: *McpServer, arena: Allocator, message: []const u8) !?[]u8 {
        return self.protocol.handle(arena, message);
    }
};

/// Serve MCP on `input`/`output` until `input` ends.
pub fn serveStdio(allocator: Allocator, devtools: *DevtoolsServer, input: *std.Io.Reader, output: *std.Io.Writer) !void {
    const server = try McpServer.create(allocator, devtools);
    defer server.destroy();
    while (true) {
        const line = input.takeDelimiterInclusive('\n') catch |err| switch (err) {
            error.EndOfStream => return,
            error.StreamTooLong => {
                // A message longer than the reader's buffer: refused whole.
                _ = input.discardDelimiterInclusive('\n') catch return;
                try output.writeAll("{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32600,\"message\":\"Message too long\"}}\n");
                try output.flush();
                continue;
            },
            else => return err,
        };
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;
        var arena_state = std.heap.ArenaAllocator.init(allocator);
        defer arena_state.deinit();
        if (try server.handle(arena_state.allocator(), trimmed)) |answer| {
            try output.writeAll(answer);
            try output.writeAll("\n");
            try output.flush();
        }
    }
}
