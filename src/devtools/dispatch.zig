//! Commands to their handlers: the one dispatcher every session kind uses.
//!
//! A handler module serves one domain (src/devtools/domains/<domain>.zig, or
//! browser_target.zig's Browser and Target on the devtools thread) and
//! declares one function per command it implements, named as the command:
//!
//!     // sync: the result, or an error
//!     pub fn enable(session: *PageSession, params: P.enable.Params) !P.enable.Result
//!     // async: answer through `reply`, now or later
//!     pub fn navigate(session: *PageSession, params: P.navigate.Params, reply: Reply(P.navigate)) !void
//!
//! where `P` is the domain's generated namespace (`protocol.Page`). The
//! dispatcher parses the params into `P.<command>.Params` (unknown fields
//! ignored, as Chrome's generated parsers do) and answers:
//! - a command the handler module has no function for: -32601
//!   "'<method>' wasn't found" (crdtp dispatch.cc `MethodNotFound`), unless
//!   the module declares `dispatchRaw` and takes it (V8's inspector);
//! - params that do not parse: -32602 "Invalid parameters" with the reason
//!   as `data` (crdtp `InvalidParams`);
//! - a returned `error.Protocol`: the code and message the handler set with
//!   `session.fail(...)` (Chrome's per-command messages, "No frame with given
//!   id found");
//! - any other returned error: -32000 with the error's name.
//! An async handler that returns an error must not have answered or kept its
//! reply: the dispatcher answers with the error. One that returns normally
//! has answered, or keeps the reply and answers later (or `drop`s it when its
//! session ends).

const std = @import("std");
const Allocator = std.mem.Allocator;
const json_rpc = @import("json_rpc.zig");
const SessionLink = @import("outbound.zig").SessionLink;
const protocol = @import("protocol/root.zig");

pub const Code = json_rpc.Code;

/// The code and message of a handler's failure, set by `fail`.
pub const Failure = struct {
    code: i32 = @backingInt(Code.server_error),
    buffer: [512]u8 = undefined,
    len: usize = 0,

    /// Record `message` (truncated to the buffer) and return error.Protocol
    /// for the handler to return.
    pub fn set(self: *Failure, code: Code, text: []const u8) error{Protocol} {
        self.code = @backingInt(code);
        self.len = @min(text.len, self.buffer.len);
        @memcpy(self.buffer[0..self.len], text[0..self.len]);
        return error.Protocol;
    }

    pub fn message(self: *const Failure) []const u8 {
        return self.buffer[0..self.len];
    }
};

/// The answer to one command of type `C` (a generated command namespace):
/// a copyable value that may be kept and answered later. Holds a reference
/// to its session's link until answered or dropped; an answer after the
/// session ended is dropped.
pub fn Reply(comptime C: type) type {
    return struct {
        link: *SessionLink,
        id: i64,

        const Self = @This();
        pub const Command = C;

        pub fn ok(self: Self, result: C.Result) void {
            defer self.link.release();
            const message = json_rpc.encodeResult(self.link.allocator, self.id, result, self.link.sessionId()) catch return;
            self.link.send(message);
        }

        /// Answer with an already serialized result object.
        pub fn okRaw(self: Self, result_json: []const u8) void {
            defer self.link.release();
            const message = json_rpc.encodeRawResult(self.link.allocator, self.id, result_json, self.link.sessionId()) catch return;
            self.link.send(message);
        }

        pub fn fail(self: Self, code: Code, message: []const u8) void {
            self.failWithData(code, message, null);
        }

        pub fn failWithData(self: Self, code: Code, message: []const u8, data: ?[]const u8) void {
            defer self.link.release();
            const encoded = json_rpc.encodeError(self.link.allocator, self.id, @backingInt(code), message, data, self.link.sessionId()) catch return;
            self.link.send(encoded);
        }

        /// Never answered: the session ended while it waited.
        pub fn drop(self: Self) void {
            self.link.release();
        }
    };
}

/// Send an error response for `command` on `link`.
pub fn sendError(link: *SessionLink, id: ?i64, code: i32, message: []const u8, data: ?[]const u8) void {
    const encoded = json_rpc.encodeError(link.allocator, id, code, message, data, link.sessionId()) catch return;
    link.send(encoded);
}

fn sendNotFound(link: *SessionLink, command: *const json_rpc.Command) void {
    var buffer: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "'{s}' wasn't found", .{command.method}) catch "method wasn't found";
    sendError(link, command.id, @backingInt(Code.method_not_found), text, null);
}

fn sendHandlerError(link: *SessionLink, failure: *Failure, id: i64, err: anyerror) void {
    switch (err) {
        error.Protocol => sendError(link, id, failure.code, failure.message(), null),
        error.InvalidParams => sendError(link, id, @backingInt(Code.invalid_params), if (failure.len != 0) failure.message() else "Invalid parameters", null),
        error.OutOfMemory => sendError(link, id, @backingInt(Code.internal_error), "Out of memory", null),
        else => sendError(link, id, @backingInt(Code.server_error), @errorName(err), null),
    }
    failure.len = 0;
}

/// Dispatch `command` to its handler among `Handlers` - a struct whose
/// public declarations are handler modules named by their domain
/// (`pub const Page = @import("page.zig");`). `session` is a pointer to a
/// session type with `link: *SessionLink` and `failure: Failure`. `arena`
/// holds the parsed message; handlers copy what they keep.
pub fn dispatch(comptime Handlers: type, session: anytype, arena: Allocator, command: *const json_rpc.Command) void {
    const dot = std.mem.indexOfScalar(u8, command.method, '.') orelse return sendNotFound(session.link, command);
    const domain_name = command.method[0..dot];
    const command_name = command.method[dot + 1 ..];
    inline for (@typeInfo(Handlers).@"struct".decl_names) |name| {
        if (std.mem.eql(u8, domain_name, name)) {
            return dispatchIn(@field(Handlers, name), name, session, arena, command, command_name);
        }
    }
    sendNotFound(session.link, command);
}

fn dispatchIn(comptime H: type, comptime domain_name: []const u8, session: anytype, arena: Allocator, command: *const json_rpc.Command, command_name: []const u8) void {
    if (comptime @hasDecl(protocol, domain_name) and @hasDecl(@field(protocol, domain_name), "CommandName")) {
        const P = @field(protocol, domain_name);
        if (std.meta.stringToEnum(P.CommandName, command_name)) |which| {
            switch (which) {
                inline else => |tag| {
                    const name = @tagName(tag);
                    if (comptime @hasDecl(H, name)) {
                        return invoke(@field(P, name), @field(H, name), session, arena, command);
                    }
                },
            }
        }
    }
    if (comptime @hasDecl(H, "dispatchRaw")) {
        if (H.dispatchRaw(session, command.method, command.raw)) return;
    }
    sendNotFound(session.link, command);
}

fn invoke(comptime C: type, comptime handler: anytype, session: anytype, arena: Allocator, command: *const json_rpc.Command) void {
    const params = std.json.parseFromValueLeaky(C.Params, arena, command.params, .{ .ignore_unknown_fields = true }) catch |err| {
        return sendError(session.link, command.id, @backingInt(Code.invalid_params), "Invalid parameters", @errorName(err));
    };
    const info = @typeInfo(@TypeOf(handler)).@"fn";
    switch (info.param_types.len) {
        2 => {
            const result = handler(session, params) catch |err| return sendHandlerError(session.link, &session.failure, command.id, err);
            const reply: Reply(C) = .{ .link = session.link.retain(), .id = command.id };
            reply.ok(result);
        },
        3 => {
            const reply: Reply(C) = .{ .link = session.link.retain(), .id = command.id };
            handler(session, params, reply) catch |err| {
                reply.drop();
                return sendHandlerError(session.link, &session.failure, command.id, err);
            };
        },
        else => @compileError("a command handler takes (session, params) or (session, params, reply): " ++ C.method),
    }
}
