//! The tools Crane's MCP server offers, by chrome-devtools-mcp's names
//! (design tmp/plans/mcp1-design.md 2.3 and 4), and the dispatch of a
//! tools/call to one: its page resolved from `pageId` (definePageTool under
//! --pageIdRouting, chrome-devtools-mcp's default), its answer assembled by
//! `response.Response`, a failure turned into the error result
//! chrome-devtools-mcp's ToolHandler answers (the message alone, isError).
//!
//! The definitions tools/list answers - names, descriptions, input schemas,
//! annotations - are chrome-devtools-mcp's own, copied (schemas/tools.json,
//! Apache-2.0; see that file's notice), for the tools Crane implements.

const std = @import("std");
const Allocator = std.mem.Allocator;
const protocol = @import("protocol.zig");
const session_mod = @import("session.zig");
const Session = session_mod.Session;
const Page = session_mod.Page;
const Response = @import("response.zig").Response;
const url_check = @import("url_check.zig");

/// A tool's run: `page` is the one `pageId` named (null for a browser-wide
/// tool). It writes its answer into `response`, or fails with `ctx.fail`.
pub const Run = *const fn (ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void;

pub const Tool = struct {
    name: []const u8,
    /// Takes `pageId` and runs on that page (definePageTool, or a tool that
    /// resolves it itself as evaluate_script does).
    page_tool: bool,
    /// blockedByDialog: refused while the page has a dialog open.
    blocked_by_dialog: bool = false,
    /// The response shows the page's dialog (definePageTool's setPage);
    /// evaluate_script resolves its page without it.
    set_page: bool = true,
    run: Run,
};

/// One call's context.
pub const Context = struct {
    session: *Session,
    arena: Allocator,
    /// The server's validateUrl options (its flags).
    url_options: url_check.Options = .{},
    /// The message `fail` set.
    failure: ?[]const u8 = null,

    /// End the tool with `message` as its error result.
    pub fn fail(self: *Context, comptime format: []const u8, args: anytype) error{ToolFailed} {
        self.failure = std.fmt.allocPrint(self.arena, format, args) catch "Error";
        return error.ToolFailed;
    }
};

const pages = @import("tools/pages.zig");
const console_tools = @import("tools/console.zig");
const script = @import("tools/script.zig");

/// Every tool Crane offers (tools/list orders them as the copied
/// definitions do).
pub const all: []const Tool = &(pages.list ++ console_tools.list ++ script.list);

/// The tools/list JSON array for `all`, from the copied definitions.
pub fn listJson(allocator: Allocator) ![]u8 {
    const copied = @embedFile("schemas/tools.json");
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, copied, .{});
    defer parsed.deinit();
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    const w = &out.writer;
    try w.writeAll("[");
    var first = true;
    for (parsed.value.object.get("tools").?.array.items) |definition| {
        const name = definition.object.get("name").?.string;
        if (find(name) == null) continue;
        if (!first) try w.writeAll(",");
        first = false;
        try std.json.Stringify.value(definition, .{}, w);
    }
    try w.writeAll("]");
    return out.toOwnedSlice();
}

pub fn find(name: []const u8) ?Tool {
    for (all) |tool| if (std.mem.eql(u8, tool.name, name)) return tool;
    return null;
}

/// protocol.Handler.call.
pub fn call(context: *anyopaque, arena: Allocator, name: []const u8, arguments: std.json.Value) anyerror!?protocol.ToolResult {
    const session: *Session = @ptrCast(@alignCast(context));
    const tool = find(name) orelse return null;
    session.dropClosed();
    // Whatever came since the last call is recorded first.
    _ = try session.client.pump(0);
    try session.initPages();
    var ctx: Context = .{ .session = session, .arena = arena };
    var response: Response = .init(arena);
    var page: ?*Page = null;
    if (tool.page_tool) {
        // routedPageId: an integer pageId names the page; any other number
        // means the selected one.
        const id_value = arguments.object.get("pageId") orelse return errorResult(arena, try std.fmt.allocPrint(arena, "Input validation error: Invalid arguments for tool {s}: pageId: Invalid input: expected number, received undefined", .{name}));
        const id: ?i64 = switch (id_value) {
            .integer => |i| i,
            .float => |f| if (f == @floor(f) and @abs(f) < 9.0e15) @as(i64, @intFromFloat(f)) else null,
            else => return errorResult(arena, try std.fmt.allocPrint(arena, "Input validation error: Invalid arguments for tool {s}: pageId: Invalid input: expected number, received {s}", .{ name, jsonTypeName(id_value) })),
        };
        page = if (id) |i| session.pageById(i) else session.selected;
        const resolved = page orelse return errorResult(arena, if (id != null) "No page found" else "No page selected");
        try pages.emulateFocus(&ctx, resolved);
        if (tool.set_page) response.page = resolved;
        if (tool.blocked_by_dialog) if (resolved.dialog) |d| {
            return errorResult(arena, try std.fmt.allocPrint(arena, "A dialog is open ({s}: {s}).", .{ d.type, d.message }));
        };
    }
    tool.run(&ctx, arguments.object, page, &response) catch |err| switch (err) {
        error.ToolFailed => return errorResult(arena, ctx.failure orelse "Error"),
        error.OutOfMemory => return error.OutOfMemory,
        else => return errorResult(arena, try std.fmt.allocPrint(arena, "{t}", .{err})),
    };
    try session.initPages();
    return try response.finish(session);
}

/// zod's name for a JSON value's type ("received <type>").
pub fn jsonTypeName(value: std.json.Value) []const u8 {
    return switch (value) {
        .null => "null",
        .bool => "boolean",
        .integer, .float, .number_string => "number",
        .string => "string",
        .array => "array",
        .object => "object",
    };
}

fn errorResult(arena: Allocator, text: []const u8) !?protocol.ToolResult {
    return .{ .content = try arena.dupe(protocol.Content, &.{.{ .text = text }}), .is_error = true };
}

/// A JSON string argument, or null when absent or not a string.
pub fn stringArg(args: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const v = args.get(key) orelse return null;
    return if (v == .string) v.string else null;
}

pub fn boolArg(args: std.json.ObjectMap, key: []const u8) ?bool {
    const v = args.get(key) orelse return null;
    return if (v == .bool) v.bool else null;
}

pub fn numberArg(args: std.json.ObjectMap, key: []const u8) ?f64 {
    const v = args.get(key) orelse return null;
    return switch (v) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        else => null,
    };
}
