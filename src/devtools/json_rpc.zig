//! CDP's message envelope: what a client sends, and the responses, errors
//! and events Crane sends back.
//!
//! The rules are Chromium's crdtp dispatcher's (third_party/inspector_protocol/
//! crdtp/dispatch.cc, BSD-3: `Dispatchable`, `CreateErrorResponse`,
//! `CreateErrorNotification`) and DevToolsSession's routing
//! (content/browser/devtools/devtools_session.cc): a command is a JSON object
//! with an integer "id", a string "method", an optional object "params" and,
//! in flat mode, a string "sessionId"; a response carries the same id and the
//! session id last; error codes are JSON-RPC 2.0's.

const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;

/// JSON-RPC 2.0 error codes as crdtp's DispatchCode uses them.
pub const Code = enum(i32) {
    parse_error = -32700,
    invalid_request = -32600,
    method_not_found = -32601,
    invalid_params = -32602,
    internal_error = -32603,
    server_error = -32000,
    /// DevToolsSession: a sessionId that names no session.
    session_not_found = -32001,
};

/// A parsed command. Every slice points into the arena it was parsed with.
pub const Command = struct {
    id: i64,
    method: []const u8,
    /// The params object, or an empty object when the message had none.
    params: json.Value,
    /// Empty for the browser session (no "sessionId").
    session_id: []const u8,
    /// The message as it arrived (for V8's inspector, which parses its own).
    raw: []const u8,
};

pub const ParseFailure = struct {
    code: Code,
    message: []const u8,
    /// The id, when the message had a usable one: the error is its response.
    id: ?i64 = null,
    session_id: []const u8 = "",
};

pub const Parsed = union(enum) {
    command: Command,
    failure: ParseFailure,
};

/// Parse one message (crdtp Dispatchable's checks, in its order).
pub fn parse(arena: Allocator, raw: []const u8) Allocator.Error!Parsed {
    const root = json.parseFromSliceLeaky(json.Value, arena, raw, .{}) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return .{ .failure = .{ .code = .parse_error, .message = "Message must be a valid JSON" } },
    };
    const object = switch (root) {
        .object => |o| o,
        else => return .{ .failure = .{ .code = .invalid_request, .message = "Message must be an object" } },
    };
    const session_id: []const u8 = if (object.get("sessionId")) |s| switch (s) {
        .string => |text| text,
        else => return .{ .failure = .{ .code = .invalid_request, .message = "Message may have string 'sessionId' property" } },
    } else "";
    const id: i64 = if (object.get("id")) |v| switch (v) {
        .integer => |n| n,
        else => return .{ .failure = .{ .code = .invalid_request, .message = "Message must have integer 'id' property", .session_id = session_id } },
    } else return .{ .failure = .{ .code = .invalid_request, .message = "Message must have integer 'id' property", .session_id = session_id } };
    const method: []const u8 = if (object.get("method")) |v| switch (v) {
        .string => |text| text,
        else => return .{ .failure = .{ .code = .invalid_request, .message = "Message must have string 'method' property", .id = id, .session_id = session_id } },
    } else return .{ .failure = .{ .code = .invalid_request, .message = "Message must have string 'method' property", .id = id, .session_id = session_id } };
    const params: json.Value = if (object.get("params")) |v| switch (v) {
        .object => v,
        else => return .{ .failure = .{ .code = .invalid_request, .message = "Message has property 'params' but it is not an object", .id = id, .session_id = session_id } },
    } else .{ .object = .empty };
    return .{ .command = .{ .id = id, .method = method, .params = params, .session_id = session_id, .raw = raw } };
}

const stringify_options: json.Stringify.Options = .{ .emit_null_optional_fields = false };

fn writeSessionTail(w: *std.Io.Writer, session_id: []const u8) std.Io.Writer.Error!void {
    if (session_id.len != 0) {
        try w.writeAll(",\"sessionId\":");
        try json.Stringify.encodeJsonString(session_id, .{}, w);
    }
    try w.writeAll("}");
}

/// `{"id":<id>,"result":<result>,"sessionId":...}`. OWNED by the caller.
pub fn encodeResult(allocator: Allocator, id: i64, result: anytype, session_id: []const u8) Allocator.Error![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    const w = &out.writer;
    w.print("{{\"id\":{d},\"result\":", .{id}) catch return error.OutOfMemory;
    json.Stringify.value(result, stringify_options, w) catch return error.OutOfMemory;
    writeSessionTail(w, session_id) catch return error.OutOfMemory;
    return out.toOwnedSlice();
}

/// `{"id":<id>,"result":<json text>,...}` for a result already serialized.
pub fn encodeRawResult(allocator: Allocator, id: i64, result_json: []const u8, session_id: []const u8) Allocator.Error![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    const w = &out.writer;
    w.print("{{\"id\":{d},\"result\":", .{id}) catch return error.OutOfMemory;
    w.writeAll(result_json) catch return error.OutOfMemory;
    writeSessionTail(w, session_id) catch return error.OutOfMemory;
    return out.toOwnedSlice();
}

/// `{"id":<id>,"error":{"code":..,"message":..[,"data":..]},...}`; with no
/// id, crdtp's error notification (no "id"). OWNED by the caller.
pub fn encodeError(allocator: Allocator, id: ?i64, code: i32, message: []const u8, data: ?[]const u8, session_id: []const u8) Allocator.Error![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    writeError(&out.writer, id, code, message, data, session_id) catch return error.OutOfMemory;
    return out.toOwnedSlice();
}

fn writeError(w: *std.Io.Writer, id: ?i64, code: i32, message: []const u8, data: ?[]const u8, session_id: []const u8) std.Io.Writer.Error!void {
    if (id) |n| {
        try w.print("{{\"id\":{d},\"error\":{{\"code\":{d},\"message\":", .{ n, code });
    } else {
        try w.print("{{\"error\":{{\"code\":{d},\"message\":", .{code});
    }
    try json.Stringify.encodeJsonString(message, .{}, w);
    if (data) |d| {
        try w.writeAll(",\"data\":");
        try json.Stringify.encodeJsonString(d, .{}, w);
    }
    try w.writeAll("}");
    try writeSessionTail(w, session_id);
}

/// `{"method":"<E.method>","params":<params>,"sessionId":...}`. `E` is a
/// generated event (`protocol.Page.frameNavigated`). OWNED by the caller.
pub fn encodeEvent(allocator: Allocator, comptime E: type, params: E.Params, session_id: []const u8) Allocator.Error![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    const w = &out.writer;
    w.writeAll("{\"method\":\"" ++ E.method ++ "\",\"params\":") catch return error.OutOfMemory;
    json.Stringify.value(params, stringify_options, w) catch return error.OutOfMemory;
    writeSessionTail(w, session_id) catch return error.OutOfMemory;
    return out.toOwnedSlice();
}

/// A message V8's inspector made (`{"id":..,"result":..}` or an event), with
/// `"sessionId"` added at its end, as DevToolsSession::AppendSessionId does
/// for its renderer's messages. OWNED by the caller.
pub fn appendSessionId(allocator: Allocator, message: []const u8, session_id: []const u8) Allocator.Error![]u8 {
    const trimmed = std.mem.trimEnd(u8, message, " \t\r\n");
    if (session_id.len == 0 or trimmed.len == 0 or trimmed[trimmed.len - 1] != '}') return allocator.dupe(u8, message);
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    out.writer.writeAll(trimmed[0 .. trimmed.len - 1]) catch return error.OutOfMemory;
    writeSessionTail(&out.writer, session_id) catch return error.OutOfMemory;
    return out.toOwnedSlice();
}

test "parse: a command with params and a session id" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const parsed = try parse(arena.allocator(), "{\"id\":7,\"method\":\"Page.navigate\",\"params\":{\"url\":\"about:blank\"},\"sessionId\":\"S1\"}");
    const cmd = parsed.command;
    try std.testing.expectEqual(@as(i64, 7), cmd.id);
    try std.testing.expectEqualStrings("Page.navigate", cmd.method);
    try std.testing.expectEqualStrings("S1", cmd.session_id);
    try std.testing.expectEqualStrings("about:blank", cmd.params.object.get("url").?.string);
}

test "parse: crdtp's errors for malformed messages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqual(Code.parse_error, (try parse(a, "{nope")).failure.code);
    try std.testing.expectEqualStrings("Message must have integer 'id' property", (try parse(a, "{\"method\":\"X.y\"}")).failure.message);
    const no_method = (try parse(a, "{\"id\":3}")).failure;
    try std.testing.expectEqual(@as(?i64, 3), no_method.id);
    try std.testing.expectEqual(Code.invalid_request, (try parse(a, "{\"id\":1,\"method\":\"X.y\",\"params\":[]}")).failure.code);
}

test "parse: \"params\": null is a command with no params (crdtp MaybeParseParams)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    // Vitest browser mode's cdp().send('HeapProfiler.collectGarbage') -
    // Playwright's CDPSession sends `"params":null` (190 times in
    // tmp/plans/cdp1-evidence/vue-e2e-browser.protocol.log); Chrome answers.
    const parsed = try parse(arena.allocator(), "{\"id\":50,\"method\":\"HeapProfiler.collectGarbage\",\"params\":null,\"sessionId\":\"S8\"}");
    const cmd = parsed.command;
    try std.testing.expectEqual(@as(i64, 50), cmd.id);
    try std.testing.expectEqualStrings("HeapProfiler.collectGarbage", cmd.method);
    try std.testing.expectEqualStrings("S8", cmd.session_id);
    try std.testing.expectEqual(@as(usize, 0), cmd.params.object.count());
    // Any other non-object is still refused.
    try std.testing.expectEqual(Code.invalid_request, (try parse(arena.allocator(), "{\"id\":1,\"method\":\"X.y\",\"params\":3}")).failure.code);
    try std.testing.expectEqual(Code.invalid_request, (try parse(arena.allocator(), "{\"id\":1,\"method\":\"X.y\",\"params\":\"{}\"}")).failure.code);
}

test "encode: result, error and an event, sessionId last" {
    const a = std.testing.allocator;
    const r = try encodeResult(a, 1, .{ .frameId = "F", .loaderId = @as(?[]const u8, null) }, "S");
    defer a.free(r);
    try std.testing.expectEqualStrings("{\"id\":1,\"result\":{\"frameId\":\"F\"},\"sessionId\":\"S\"}", r);
    const e = try encodeError(a, 2, -32601, "'Foo.bar' wasn't found", null, "");
    defer a.free(e);
    try std.testing.expectEqualStrings("{\"id\":2,\"error\":{\"code\":-32601,\"message\":\"'Foo.bar' wasn't found\"}}", e);
    const Ev = struct {
        pub const method = "Page.loadEventFired";
        pub const Params = struct { timestamp: f64 };
    };
    const ev = try encodeEvent(a, Ev, .{ .timestamp = 1.5 }, "S");
    defer a.free(ev);
    try std.testing.expectEqualStrings("{\"method\":\"Page.loadEventFired\",\"params\":{\"timestamp\":1.5},\"sessionId\":\"S\"}", ev);
    const v8 = try appendSessionId(a, "{\"id\":4,\"result\":{}}", "S");
    defer a.free(v8);
    try std.testing.expectEqualStrings("{\"id\":4,\"result\":{},\"sessionId\":\"S\"}", v8);
}
