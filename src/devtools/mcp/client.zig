//! The MCP server's CDP client (design tmp/plans/mcp1-design.md 2.1): CDP
//! commands sent over an in-process session link (`Server.openLocal`) to
//! Crane's own devtools server, answered by the same handlers every client
//! reaches. Used by one thread - the MCP server's - which blocks in `call`
//! while the devtools and Browser threads work; events that come meanwhile
//! go to the sink as they arrive, so the server's records (pages, console,
//! network, dialogs) are current whenever a tool reads them.

const std = @import("std");
const Allocator = std.mem.Allocator;
const LocalLink = @import("../server.zig").LocalLink;

/// A command's answer: the whole message, parsed. `deinit` frees it.
pub const Response = struct {
    parsed: std.json.Parsed(std.json.Value),

    pub fn deinit(self: *Response) void {
        self.parsed.deinit();
    }

    /// The `result` object, or null for an error answer.
    pub fn result(self: *const Response) ?std.json.Value {
        return self.parsed.value.object.get("result");
    }

    /// The error's message, or null for a result.
    pub fn errorMessage(self: *const Response) ?[]const u8 {
        const e = self.parsed.value.object.get("error") orelse return null;
        if (e != .object) return "error";
        const m = e.object.get("message") orelse return "error";
        return if (m == .string) m.string else "error";
    }
};

/// Where events go: `method` and `params` are borrowed for the call;
/// `session_id` is empty for the browser session's.
pub const EventSink = struct {
    context: *anyopaque,
    on_event: *const fn (context: *anyopaque, method: []const u8, params: std.json.Value, session_id: []const u8) void,
};

pub const Client = struct {
    allocator: Allocator,
    link: *LocalLink,
    next_id: i64 = 1,
    sink: ?EventSink = null,

    pub const Error = error{ Timeout, Closed, OutOfMemory };

    /// Send `method` with `params_json` (an object's text; "{}" when none)
    /// on `session_id` (empty: the browser session) and wait up to
    /// `timeout_ms` for its answer, dispatching events as they come.
    pub fn call(self: *Client, method: []const u8, params_json: []const u8, session_id: []const u8, timeout_ms: u32) Error!Response {
        const id = try self.send(method, params_json, session_id);
        var waited_ms: u32 = 0;
        while (waited_ms < timeout_ms) {
            const text = self.link.receive(10 * std.time.ns_per_ms) orelse {
                if (self.link.closed) return error.Closed;
                waited_ms += 10;
                continue;
            };
            if (try self.take(text, id)) |response| return response;
        }
        return error.Timeout;
    }

    /// Send a command without waiting: its answer is dropped when it comes
    /// (Puppeteer's `void dialog.accept()`). Safe inside an event's
    /// dispatch, where a waiting `call` would take the answers of the call
    /// that dispatched it.
    pub fn post(self: *Client, method: []const u8, params_json: []const u8, session_id: []const u8) Error!void {
        _ = try self.send(method, params_json, session_id);
    }

    fn send(self: *Client, method: []const u8, params_json: []const u8, session_id: []const u8) Error!i64 {
        const id = self.next_id;
        self.next_id += 1;
        var out: std.Io.Writer.Allocating = .init(self.allocator);
        defer out.deinit();
        const w = &out.writer;
        w.print("{{\"id\":{d},\"method\":", .{id}) catch return error.OutOfMemory;
        std.json.Stringify.encodeJsonString(method, .{}, w) catch return error.OutOfMemory;
        w.writeAll(",\"params\":") catch return error.OutOfMemory;
        w.writeAll(params_json) catch return error.OutOfMemory;
        if (session_id.len != 0) {
            w.writeAll(",\"sessionId\":") catch return error.OutOfMemory;
            std.json.Stringify.encodeJsonString(session_id, .{}, w) catch return error.OutOfMemory;
        }
        w.writeAll("}") catch return error.OutOfMemory;
        self.link.send(out.written()) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.Closed,
        };
        return id;
    }

    /// Dispatch every message that comes within `wait_ns` (0: only what is
    /// there now). Whether any came.
    pub fn pump(self: *Client, wait_ns: u64) Error!bool {
        var any = false;
        while (self.link.receive(wait_ns)) |text| {
            any = true;
            if (try self.take(text, null)) |r| {
                var stray = r;
                stray.deinit();
            }
        }
        return any;
    }

    /// Parse `text` (OWNED: freed here): the answer to `want` when it is
    /// that, else an event (to the sink) or a stray answer (dropped).
    fn take(self: *Client, text: []u8, want: ?i64) Error!?Response {
        defer self.allocator.free(text);
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, text, .{}) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return null,
        };
        if (parsed.value != .object) {
            parsed.deinit();
            return null;
        }
        const object = parsed.value.object;
        if (object.get("id")) |id| {
            if (want != null and id == .integer and id.integer == want.?) return .{ .parsed = parsed };
            parsed.deinit();
            return null;
        }
        defer parsed.deinit();
        const method = object.get("method") orelse return null;
        if (method != .string) return null;
        const params: std.json.Value = object.get("params") orelse .{ .object = .empty };
        const session: []const u8 = if (object.get("sessionId")) |s| (if (s == .string) s.string else "") else "";
        if (self.sink) |sink| sink.on_event(sink.context, method.string, params, session);
        return null;
    }
};

/// `value` as JSON text (a string's quoted form), in `arena`.
pub fn jsonText(arena: Allocator, value: anytype) Allocator.Error![]u8 {
    return std.json.Stringify.valueAlloc(arena, value, .{ .emit_null_optional_fields = false });
}
