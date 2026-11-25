//! The Model Context Protocol's envelope for Crane's MCP server (lane mcp1;
//! design tmp/plans/mcp1-design.md 1 and 3): JSON-RPC 2.0 messages of both
//! eras the specification lets one server serve on one endpoint
//! (https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning,
//! "A dual-era server MAY serve both eras concurrently"):
//!
//! - legacy (2025-11-25 and before): `initialize` negotiates a version ("If the
//!   server supports the requested protocol version, it MUST respond with the
//!   same version. Otherwise, the server MUST respond with another protocol
//!   version it supports. This SHOULD be the latest version supported by the
//!   server."), then `notifications/initialized`;
//! - modern (2026-07-28): no handshake; every request carries
//!   `_meta["io.modelcontextprotocol/protocolVersion"]` and
//!   `["io.modelcontextprotocol/clientCapabilities"]` (missing: -32602),
//!   `server/discover` ("Servers MUST implement it"), and every result carries
//!   `resultType`; tools/list adds `ttlMs` and `cacheScope`.
//!
//! What a tool does is not this file's: `Handler` runs a tools/call and
//! answers its content. Nothing here reads a transport; a transport hands in
//! one message's text and writes back what `handle` returns.

const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;

/// Every version this server speaks, newest first. The legacy ones are the
/// versions chrome-devtools-mcp 1.13.0's SDK (@modelcontextprotocol/core
/// 2.4.0) supports, so any client of that server can speak to this one.
pub const supported_versions = [_][]const u8{ modern_version, "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05" };
pub const modern_version = "2026-07-28";
pub const latest_legacy_version = "2025-11-25";

/// JSON-RPC 2.0 error codes (and MCP's own).
pub const Code = enum(i32) {
    parse_error = -32700,
    invalid_request = -32600,
    method_not_found = -32601,
    invalid_params = -32602,
    internal_error = -32603,
    /// 2026-07-28: the MCP-Protocol-Version header and `_meta` disagree.
    header_mismatch = -32020,
    missing_required_client_capability = -32021,
    unsupported_protocol_version = -32022,
};

/// One item of a tool result's `content`.
pub const Content = union(enum) {
    text: []const u8,
    /// Base64 data and its MIME type.
    image: struct { data: []const u8, mime_type: []const u8 },
};

/// A tools/call's answer: an execution error is a result with `isError`
/// (so the model can correct itself), never a JSON-RPC error.
pub const ToolResult = struct {
    content: []const Content,
    is_error: bool = false,
};

/// What runs the tools.
pub const Handler = struct {
    context: *anyopaque,
    /// tools/list's `tools` array, as JSON text (the enabled tools' copied
    /// definitions).
    tools_json: []const u8,
    /// Run tool `name` with `arguments` (an object); null: no such tool.
    /// Allocations in `arena` live until the answer is written.
    call: *const fn (context: *anyopaque, arena: Allocator, name: []const u8, arguments: json.Value) anyerror!?ToolResult,
    /// A tool the server has but does not offer (a category or a flag off):
    /// a call to it is "Tool <name> disabled", not "not found".
    disabled: ?*const fn (name: []const u8) bool = null,
};

pub const ServerInfo = struct {
    name: []const u8,
    version: []const u8,
};

/// One entry of a client's roots/list answer.
pub const RootEntry = struct {
    uri: []const u8,
    name: []const u8 = "",
};

/// Where the client's roots go (the path policy's client roots).
pub const RootsHooks = struct {
    context: *anyopaque,
    set: *const fn (context: *anyopaque, roots: []const RootEntry) void,
};

/// How long a tool call waits for the client's roots (index.ts
/// ROOTS_REQUEST_TIMEOUT: "matching the 5s default used for page
/// operations").
pub const roots_timeout_ms = 5_000;

/// One client's protocol state (stdio: the process's; HTTP: per request in
/// the modern era, per session in the legacy one).
pub const Protocol = struct {
    handler: Handler,
    info: ServerInfo,
    /// Legacy: the version `initialize` settled on (null before it).
    negotiated: ?[]const u8 = null,
    initialized: bool = false,
    /// The client's roots (chrome-devtools-mcp src/index.ts: roots/list
    /// after `initialized` and on notifications/roots/list_changed when the
    /// client offers the capability; a tool call waits for the first list).
    roots: ?RootsHooks = null,
    /// initialize's capabilities named `roots`.
    client_roots: bool = false,
    /// The id of the next request this server sends.
    next_request_id: i64 = 0,
    /// roots/list requests not answered yet.
    pending_roots: [8]?i64 = @splat(null),
    /// A roots/list answer came (#lastClientRoots is set).
    roots_listed: bool = false,
    /// The first tool call's wait for roots is over (#initialRoots settled):
    /// later calls never wait.
    roots_waited: bool = false,
    /// The request that wait is for, until it is answered.
    roots_wait_id: ?i64 = null,

    /// Answer one message (`text`, a JSON-RPC request or notification).
    /// Null: nothing to send (a notification, or a response a client sent).
    /// The answer is allocated in `arena`.
    pub fn handle(self: *Protocol, arena: Allocator, text: []const u8) Allocator.Error!?[]u8 {
        const parsed = json.parseFromSliceLeaky(json.Value, arena, text, .{}) catch {
            return try errorMessage(arena, .null, .parse_error, "Parse error", null);
        };
        if (parsed != .object) return try errorMessage(arena, .null, .invalid_request, "Invalid Request", null);
        const object = parsed.object;
        const id: json.Value = object.get("id") orelse .null;
        const has_id = object.get("id") != null;
        const method_value = object.get("method") orelse {
            // A response or something else a client sent: nothing to answer.
            if (has_id and (object.get("result") != null or object.get("error") != null)) {
                self.response(id, object.get("result"));
                return null;
            }
            return try errorMessage(arena, id, .invalid_request, "Invalid Request", null);
        };
        if (method_value != .string) return try errorMessage(arena, id, .invalid_request, "Invalid Request", null);
        const method = method_value.string;
        const params: json.Value = object.get("params") orelse .{ .object = .empty };
        if (!has_id) {
            // A notification: never answered - but the client's roots are
            // asked for once it is initialized and whenever they change.
            if (std.mem.eql(u8, method, "notifications/initialized")) {
                self.initialized = true;
                if (self.client_roots) return try self.rootsRequest(arena);
            }
            if (std.mem.eql(u8, method, "notifications/roots/list_changed") and self.client_roots) return try self.rootsRequest(arena);
            return null;
        }
        return self.request(arena, id, method, params) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
        };
    }

    /// A roots/list request to the client (#updateRoots), its id kept.
    fn rootsRequest(self: *Protocol, arena: Allocator) Allocator.Error![]u8 {
        const id = self.next_request_id;
        self.next_request_id += 1;
        for (&self.pending_roots) |*slot| if (slot.* == null) {
            slot.* = id;
            break;
        };
        return std.fmt.allocPrint(arena, "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"method\":\"roots/list\"}}", .{id});
    }

    /// A response the client sent: a roots/list answer gives the client's
    /// roots (a failed one changes nothing, as #updateRoots logs and moves
    /// on).
    fn response(self: *Protocol, id: json.Value, result: ?json.Value) void {
        if (id != .integer) return;
        var ours = false;
        for (&self.pending_roots) |*slot| if (slot.* == id.integer) {
            slot.* = null;
            ours = true;
        };
        if (!ours) return;
        if (self.roots_wait_id == id.integer) self.roots_wait_id = null;
        const value = result orelse return;
        if (value != .object) return;
        const list = value.object.get("roots") orelse return;
        if (list != .array) return;
        var entries: [64]RootEntry = undefined;
        var count: usize = 0;
        for (list.array.items) |item| {
            if (item != .object or count == entries.len) continue;
            const uri = item.object.get("uri") orelse continue;
            if (uri != .string) continue;
            const name: []const u8 = if (item.object.get("name")) |n| (if (n == .string) n.string else "") else "";
            entries[count] = .{ .uri = uri.string, .name = name };
            count += 1;
        }
        self.roots_listed = true;
        if (self.roots) |hooks| hooks.set(hooks.context, entries[0..count]);
    }

    /// McpServer #getContext before a tool call: when `text` is a tools/call
    /// and the client offers roots that have not come, the roots/list
    /// request to send - its answer is waited for, up to roots_timeout_ms,
    /// once (#initialRoots); null when the call need not wait.
    pub fn rootsWaitRequest(self: *Protocol, arena: Allocator, text: []const u8) Allocator.Error!?[]u8 {
        if (!self.client_roots or self.roots_listed or self.roots_waited) return null;
        const parsed = json.parseFromSliceLeaky(json.Value, arena, text, .{}) catch return null;
        if (parsed != .object) return null;
        const method = parsed.object.get("method") orelse return null;
        if (method != .string or !std.mem.eql(u8, method.string, "tools/call") or parsed.object.get("id") == null) return null;
        const request_text = try self.rootsRequest(arena);
        self.roots_wait_id = self.next_request_id - 1;
        return request_text;
    }

    /// Whether the wait `rootsWaitRequest` started is still on.
    pub fn waitingForRoots(self: *const Protocol) bool {
        return self.roots_wait_id != null;
    }

    /// The wait is over (answered or timed out): no call waits again.
    pub fn endRootsWait(self: *Protocol) void {
        self.roots_waited = true;
        self.roots_wait_id = null;
    }

    fn request(self: *Protocol, arena: Allocator, id: json.Value, method: []const u8, params: json.Value) Allocator.Error![]u8 {
        if (params != .object) return errorMessage(arena, id, .invalid_params, "Invalid params", null);
        // The era: a modern request names its version in _meta.
        const meta: ?json.ObjectMap = if (params.object.get("_meta")) |m| (if (m == .object) m.object else null) else null;
        const modern_requested: ?[]const u8 = if (meta) |m| (if (m.get("io.modelcontextprotocol/protocolVersion")) |v| (if (v == .string) v.string else null) else null) else null;

        if (std.mem.eql(u8, method, "initialize")) return self.initialize(arena, id, params.object);
        if (modern_requested) |version| {
            if (!isSupported(version)) return unsupportedVersion(arena, id, version);
            if (meta.?.get("io.modelcontextprotocol/clientCapabilities") == null) {
                return errorMessage(arena, id, .invalid_params, "Missing required _meta field: io.modelcontextprotocol/clientCapabilities", null);
            }
        }
        const modern = modern_requested != null;
        if (std.mem.eql(u8, method, "server/discover")) return self.discover(arena, id);
        if (std.mem.eql(u8, method, "ping")) return resultMessage(arena, id, if (modern) "{\"resultType\":\"complete\"}" else "{}");
        if (std.mem.eql(u8, method, "tools/list")) return self.toolsList(arena, id, modern);
        if (std.mem.eql(u8, method, "tools/call")) return self.toolsCall(arena, id, params.object, modern);
        return errorMessage(arena, id, .method_not_found, "Method not found", null);
    }

    /// Legacy `initialize`: the requested version when supported, else the
    /// latest legacy one (a modern client never sends it).
    fn initialize(self: *Protocol, arena: Allocator, id: json.Value, params: json.ObjectMap) Allocator.Error![]u8 {
        const requested: []const u8 = if (params.get("protocolVersion")) |v| (if (v == .string) v.string else "") else "";
        const version = if (requested.len != 0 and isSupported(requested) and !std.mem.eql(u8, requested, modern_version)) requested else latest_legacy_version;
        self.negotiated = version;
        // getClientCapabilities()?.roots.
        if (params.get("capabilities")) |caps| if (caps == .object) {
            if (caps.object.get("roots")) |r| self.client_roots = r != .null;
        };
        var out: std.Io.Writer.Allocating = .init(arena);
        const w = &out.writer;
        w.writeAll("{\"protocolVersion\":") catch return error.OutOfMemory;
        writeString(w, version) catch return error.OutOfMemory;
        w.writeAll(",\"capabilities\":{\"tools\":{\"listChanged\":false}},\"serverInfo\":") catch return error.OutOfMemory;
        self.writeInfo(w) catch return error.OutOfMemory;
        w.writeAll("}") catch return error.OutOfMemory;
        return resultMessage(arena, id, out.written());
    }

    /// 2026-07-28 `server/discover`.
    fn discover(self: *Protocol, arena: Allocator, id: json.Value) Allocator.Error![]u8 {
        var out: std.Io.Writer.Allocating = .init(arena);
        const w = &out.writer;
        w.writeAll("{\"resultType\":\"complete\",\"supportedVersions\":[") catch return error.OutOfMemory;
        for (supported_versions, 0..) |v, i| {
            if (i != 0) w.writeAll(",") catch return error.OutOfMemory;
            writeString(w, v) catch return error.OutOfMemory;
        }
        w.writeAll("],\"capabilities\":{\"tools\":{\"listChanged\":false}},\"_meta\":{\"io.modelcontextprotocol/serverInfo\":") catch return error.OutOfMemory;
        self.writeInfo(w) catch return error.OutOfMemory;
        w.writeAll("},\"ttlMs\":3600000,\"cacheScope\":\"public\"}") catch return error.OutOfMemory;
        return resultMessage(arena, id, out.written());
    }

    fn toolsList(self: *Protocol, arena: Allocator, id: json.Value, modern: bool) Allocator.Error![]u8 {
        const body = if (modern)
            try std.fmt.allocPrint(arena, "{{\"resultType\":\"complete\",\"tools\":{s},\"ttlMs\":300000,\"cacheScope\":\"public\"}}", .{self.handler.tools_json})
        else
            try std.fmt.allocPrint(arena, "{{\"tools\":{s}}}", .{self.handler.tools_json});
        return resultMessage(arena, id, body);
    }

    fn toolsCall(self: *Protocol, arena: Allocator, id: json.Value, params: json.ObjectMap, modern: bool) Allocator.Error![]u8 {
        const name_value = params.get("name") orelse return errorMessage(arena, id, .invalid_params, "Invalid params: name is required", null);
        if (name_value != .string) return errorMessage(arena, id, .invalid_params, "Invalid params: name must be a string", null);
        const arguments: json.Value = params.get("arguments") orelse .{ .object = .empty };
        if (arguments != .object) return errorMessage(arena, id, .invalid_params, "Invalid params: arguments must be an object", null);
        const result = self.handler.call(self.handler.context, arena, name_value.string, arguments) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // A failure the tool did not turn into its own error text: an
            // execution error the model can read.
            else => ToolResult{ .content = try arena.dupe(Content, &.{.{ .text = try std.fmt.allocPrint(arena, "Error: {t}", .{err}) }}), .is_error = true },
        } orelse {
            // chrome-devtools-mcp's tools/call handler and ToolHandler.handle
            // (viaMcp): InvalidParams, "not found" or "disabled".
            const off = if (self.handler.disabled) |f| f(name_value.string) else false;
            const message = try std.fmt.allocPrint(arena, "Tool {s} {s}", .{ name_value.string, if (off) "disabled" else "not found" });
            return errorMessage(arena, id, .invalid_params, message, null);
        };
        var out: std.Io.Writer.Allocating = .init(arena);
        writeToolResult(&out.writer, result, modern) catch return error.OutOfMemory;
        return resultMessage(arena, id, out.written());
    }

    fn writeInfo(self: *const Protocol, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.writeAll("{\"name\":");
        try writeString(w, self.info.name);
        try w.writeAll(",\"version\":");
        try writeString(w, self.info.version);
        try w.writeAll("}");
    }
};

fn isSupported(version: []const u8) bool {
    for (supported_versions) |v| if (std.mem.eql(u8, v, version)) return true;
    return false;
}

fn unsupportedVersion(arena: Allocator, id: json.Value, requested: []const u8) Allocator.Error![]u8 {
    var data: std.Io.Writer.Allocating = .init(arena);
    const w = &data.writer;
    w.writeAll("{\"supported\":[") catch return error.OutOfMemory;
    for (supported_versions, 0..) |v, i| {
        if (i != 0) w.writeAll(",") catch return error.OutOfMemory;
        writeString(w, v) catch return error.OutOfMemory;
    }
    w.writeAll("],\"requested\":") catch return error.OutOfMemory;
    writeString(w, requested) catch return error.OutOfMemory;
    w.writeAll("}") catch return error.OutOfMemory;
    return errorMessage(arena, id, .unsupported_protocol_version, "Unsupported protocol version", data.written());
}

/// A tool result's JSON: `content` (and `isError` when set; `resultType`
/// in the modern era).
pub fn writeToolResult(w: *std.Io.Writer, result: ToolResult, modern: bool) std.Io.Writer.Error!void {
    try w.writeAll("{");
    if (modern) try w.writeAll("\"resultType\":\"complete\",");
    try w.writeAll("\"content\":[");
    for (result.content, 0..) |item, i| {
        if (i != 0) try w.writeAll(",");
        switch (item) {
            .text => |t| {
                try w.writeAll("{\"type\":\"text\",\"text\":");
                try writeString(w, t);
                try w.writeAll("}");
            },
            .image => |img| {
                try w.writeAll("{\"type\":\"image\",\"data\":");
                try writeString(w, img.data);
                try w.writeAll(",\"mimeType\":");
                try writeString(w, img.mime_type);
                try w.writeAll("}");
            },
        }
    }
    try w.writeAll("]");
    if (result.is_error) try w.writeAll(",\"isError\":true");
    try w.writeAll("}");
}

fn writeString(w: *std.Io.Writer, s: []const u8) std.Io.Writer.Error!void {
    try json.Stringify.encodeJsonString(s, .{}, w);
}

/// `{"jsonrpc":"2.0","id":<id>,"result":<result_json>}`.
pub fn resultMessage(arena: Allocator, id: json.Value, result_json: []const u8) Allocator.Error![]u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    w.writeAll("{\"jsonrpc\":\"2.0\",\"id\":") catch return error.OutOfMemory;
    json.Stringify.value(id, .{}, w) catch return error.OutOfMemory;
    w.writeAll(",\"result\":") catch return error.OutOfMemory;
    w.writeAll(result_json) catch return error.OutOfMemory;
    w.writeAll("}") catch return error.OutOfMemory;
    return out.written();
}

/// `{"jsonrpc":"2.0","id":<id>,"error":{"code":..,"message":..,"data":..}}`.
pub fn errorMessage(arena: Allocator, id: json.Value, code: Code, message: []const u8, data_json: ?[]const u8) Allocator.Error![]u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    w.writeAll("{\"jsonrpc\":\"2.0\",\"id\":") catch return error.OutOfMemory;
    json.Stringify.value(id, .{}, w) catch return error.OutOfMemory;
    w.print(",\"error\":{{\"code\":{d},\"message\":", .{@backingInt(code)}) catch return error.OutOfMemory;
    writeString(w, message) catch return error.OutOfMemory;
    if (data_json) |d| {
        w.writeAll(",\"data\":") catch return error.OutOfMemory;
        w.writeAll(d) catch return error.OutOfMemory;
    }
    w.writeAll("}}") catch return error.OutOfMemory;
    return out.written();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

const Echo = struct {
    fn call(context: *anyopaque, arena: Allocator, name: []const u8, arguments: json.Value) anyerror!?ToolResult {
        _ = context;
        if (!std.mem.eql(u8, name, "echo")) return null;
        const text = if (arguments.object.get("text")) |t| t.string else "";
        if (std.mem.eql(u8, text, "fail")) return error.SomethingBroke;
        return .{ .content = try arena.dupe(Content, &.{.{ .text = text }}) };
    }
};

fn testProtocol(dummy: *u8) Protocol {
    return .{
        .handler = .{ .context = dummy, .tools_json = "[{\"name\":\"echo\",\"inputSchema\":{\"type\":\"object\"}}]", .call = Echo.call },
        .info = .{ .name = "crane", .version = "0.1" },
    };
}

test "legacy: initialize answers the requested supported version, else the latest legacy one; the notification is not answered" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var dummy: u8 = 0;
    var p = testProtocol(&dummy);
    try testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{\"tools\":{\"listChanged\":false}},\"serverInfo\":{\"name\":\"crane\",\"version\":\"0.1\"}}}",
        (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{}}}")).?,
    );
    const other = (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":\"a\",\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"1999-01-01\"}}")).?;
    try testing.expect(std.mem.indexOf(u8, other, "\"protocolVersion\":\"2025-11-25\"") != null);
    try testing.expect(std.mem.indexOf(u8, other, "\"id\":\"a\"") != null);
    try testing.expectEqual(@as(?[]u8, null), try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}"));
    try testing.expect(p.initialized);
}

test "tools/list and tools/call, legacy and modern; an unknown tool is a JSON-RPC error, a failing one a result with isError" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var dummy: u8 = 0;
    var p = testProtocol(&dummy);
    try testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"tools\":[{\"name\":\"echo\",\"inputSchema\":{\"type\":\"object\"}}]}}",
        (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}")).?,
    );
    const meta = "\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}";
    const modern_list = (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/list\",\"params\":{" ++ meta ++ "}}")).?;
    try testing.expect(std.mem.indexOf(u8, modern_list, "\"resultType\":\"complete\"") != null);
    try testing.expect(std.mem.indexOf(u8, modern_list, "\"cacheScope\":\"public\"") != null);
    try testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":4,\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"hi\"}]}}",
        (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"echo\",\"arguments\":{\"text\":\"hi\"}}}")).?,
    );
    const failed = (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"tools/call\",\"params\":{\"name\":\"echo\",\"arguments\":{\"text\":\"fail\"}}}")).?;
    try testing.expect(std.mem.indexOf(u8, failed, "\"isError\":true") != null);
    const unknown = (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"tools/call\",\"params\":{\"name\":\"nope\"}}")).?;
    try testing.expect(std.mem.indexOf(u8, unknown, "\"code\":-32602") != null);
    try testing.expect(std.mem.indexOf(u8, unknown, "Tool nope not found") != null);
}

test "modern: server/discover; an unsupported version is -32022 naming the supported ones; missing client capabilities -32602; unknown methods -32601; bad JSON -32700" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var dummy: u8 = 0;
    var p = testProtocol(&dummy);
    const discover = (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"server/discover\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}")).?;
    try testing.expect(std.mem.indexOf(u8, discover, "\"supportedVersions\":[\"2026-07-28\",\"2025-11-25\"") != null);
    try testing.expect(std.mem.indexOf(u8, discover, "\"io.modelcontextprotocol/serverInfo\":{\"name\":\"crane\"") != null);
    const bad_version = (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"1900-01-01\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}")).?;
    try testing.expect(std.mem.indexOf(u8, bad_version, "\"code\":-32022") != null);
    try testing.expect(std.mem.indexOf(u8, bad_version, "\"requested\":\"1900-01-01\"") != null);
    const no_caps = (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/list\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\"}}}")).?;
    try testing.expect(std.mem.indexOf(u8, no_caps, "\"code\":-32602") != null);
    try testing.expect(std.mem.indexOf(u8, (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"resources/list\"}")).?, "\"code\":-32601") != null);
    try testing.expect(std.mem.indexOf(u8, (try p.handle(arena, "{not json")).?, "\"code\":-32700") != null);
}

test "roots: asked for once initialized when the client offers them, again on list_changed; an answer sets them; the first tool call waits once" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var dummy: u8 = 0;
    var p = testProtocol(&dummy);
    const Seen = struct {
        count: usize = 0,
        first: [64]u8 = undefined,
        first_len: usize = 0,
        fn set(context: *anyopaque, roots: []const RootEntry) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.count = roots.len;
            if (roots.len > 0) {
                self.first_len = @min(roots[0].uri.len, self.first.len);
                @memcpy(self.first[0..self.first_len], roots[0].uri[0..self.first_len]);
            }
        }
    };
    var seen: Seen = .{};
    p.roots = .{ .context = &seen, .set = Seen.set };
    _ = (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{\"roots\":{\"listChanged\":true}}}}")).?;
    try testing.expect(p.client_roots);
    try testing.expectEqualStrings("{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"roots/list\"}", (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}")).?);
    // A tool call before the answer waits, on a request of its own.
    const call = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"echo\",\"arguments\":{}}}";
    try testing.expectEqualStrings("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"roots/list\"}", (try p.rootsWaitRequest(arena, call)).?);
    try testing.expect(p.waitingForRoots());
    try testing.expectEqual(@as(?[]u8, null), try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"roots\":[{\"uri\":\"file:///work\",\"name\":\"work\"}]}}"));
    try testing.expect(!p.waitingForRoots());
    try testing.expectEqual(@as(usize, 1), seen.count);
    try testing.expectEqualStrings("file:///work", seen.first[0..seen.first_len]);
    p.endRootsWait();
    try testing.expectEqual(@as(?[]u8, null), try p.rootsWaitRequest(arena, call));
    // A change asks again; a response to an id it never sent is ignored.
    try testing.expectEqualStrings("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"roots/list\"}", (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/roots/list_changed\"}")).?);
    try testing.expectEqual(@as(?[]u8, null), try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":77,\"result\":{\"roots\":[]}}"));
    try testing.expectEqual(@as(usize, 1), seen.count);
}

test "roots: a client that does not offer them is never asked and no call waits" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var dummy: u8 = 0;
    var p = testProtocol(&dummy);
    _ = (try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{}}}")).?;
    try testing.expectEqual(@as(?[]u8, null), try p.handle(arena, "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}"));
    try testing.expectEqual(@as(?[]u8, null), try p.rootsWaitRequest(arena, "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"echo\"}}"));
}
