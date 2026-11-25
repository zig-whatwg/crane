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
const validate = @import("validate.zig");

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
    /// verifyFilesSchema: the parameters that name the server's files,
    /// checked against the path policy before the page is resolved.
    files: []const FileParam = &.{},
    run: Run,
};

/// One verifyFilesSchema entry. Crane's browser is always local (it is this
/// process), so `{local: true}` and `true` alike are checked.
pub const FileParam = struct {
    name: []const u8,
    /// allowUrl: an http(s) or ws(s) URL passes unchanged.
    allow_url: bool = false,
};

/// One call's context.
pub const Context = struct {
    session: *Session,
    arena: Allocator,
    /// The server's validateUrl options (its flags).
    url_options: url_check.Options = .{},
    /// The message `fail` set.
    failure: ?[]const u8 = null,
    /// `failPlain`: the failure is McpResponse.handle's own (a lookup it
    /// makes, as of an attached message or request), which ToolHandler
    /// answers as the message alone; a tool's own error is the response with
    /// "Error: <message>" last.
    plain: bool = false,

    /// End the tool with an error the response reports ("Error: ...").
    pub fn fail(self: *Context, comptime format: []const u8, args: anytype) error{ToolFailed} {
        self.failure = std.fmt.allocPrint(self.arena, format, args) catch "Error";
        return error.ToolFailed;
    }

    /// End the tool with the message alone as its error result (ToolHandler's
    /// errorResult: a failure of the response's own handling).
    pub fn failPlain(self: *Context, comptime format: []const u8, args: anytype) error{ToolFailed} {
        self.plain = true;
        return self.fail(format, args);
    }
};

const pages = @import("tools/pages.zig");
const console_tools = @import("tools/console.zig");
const script = @import("tools/script.zig");
const network_tools = @import("tools/network.zig");
const input_tools = @import("tools/input.zig");
const snapshot_tools = @import("tools/snapshot.zig");
const emulation_tools = @import("tools/emulation.zig");
const logpoint_tools = @import("tools/logpoints.zig");
const logpoints = @import("logpoints.zig");

/// Every tool Crane offers (tools/list orders them as the copied
/// definitions do).
pub const all: []const Tool = &(pages.list ++ console_tools.list ++ script.list ++ network_tools.list ++ input_tools.list ++ snapshot_tools.list ++ emulation_tools.list ++ logpoint_tools.list);

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

/// The tools chrome-devtools-mcp v1.13.0 offers with its default flags (its
/// tools/list, dumped by lane mcp1 into tmp/mcp1/tools-default.json): every
/// other copied definition is a category's or a flag's, off by default.
const default_tools = [_][]const u8{
    "click",
    "close_page",
    "drag",
    "emulate",
    "evaluate_script",
    "fill",
    "fill_form",
    "get_console_message",
    "get_css_styles",
    "get_network_request",
    "handle_dialog",
    "hover",
    "lighthouse_audit",
    "list_console_messages",
    "list_network_requests",
    "list_pages",
    "navigate_page",
    "new_page",
    "performance_analyze_insight",
    "performance_start_trace",
    "performance_stop_trace",
    "press_key",
    "resize_page",
    "screencast_start",
    "screencast_stop",
    "select_page",
    "set_logpoints",
    "take_heapsnapshot",
    "take_screenshot",
    "take_snapshot",
    "type_text",
    "upload_file",
    "wait_for",
};

/// Handler.disabled: a tool Google's server has but leaves off by default
/// (mock_network's category, the heap tools' flag, the Chrome products).
pub fn disabled(name: []const u8) bool {
    for (default_tools) |d| if (std.mem.eql(u8, d, name)) return false;
    // A definition's name, as the copied file writes it.
    const copied = @embedFile("schemas/tools.json");
    var buffer: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&buffer, "\"name\": \"{s}\"", .{name}) catch return false;
    return std.mem.indexOf(u8, copied, needle) != null;
}

// The tool files whose own tests src-devtools runs (lane core1): Zig
// collects a file's test blocks only when something analyzes its import.
test {
    _ = script;
}

test "disabled: a copied tool off by default, not one offered by default or unknown" {
    try std.testing.expect(disabled("mock_network"));
    try std.testing.expect(disabled("install_extension"));
    try std.testing.expect(!disabled("take_snapshot"));
    try std.testing.expect(!disabled("nope"));
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
    // ToolHandler: the arguments against the tool's schema, strictly.
    if (session.schemas) |parsed| for (parsed.value.array.items) |definition| {
        if (!std.mem.eql(u8, definition.object.get("name").?.string, name)) continue;
        const schema = definition.object.get("inputSchema") orelse break;
        if (schema != .object) break;
        if (try validate.check(arena, name, schema.object, arguments)) |message| return errorResult(arena, message);
        break;
    };
    var ctx: Context = .{ .session = session, .arena = arena };
    var response: Response = .init(arena);
    // validateToolFiles, inside ToolHandler's try and before the page is
    // resolved: a refusal is the response's "Error: ..." line.
    if (!try checkFiles(session, arena, tool, arguments)) {
        response.error_message = session.paths.message;
        return try response.finish(session);
    }
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
        // ToolHandler's page resolution is inside its try: a failure is the
        // response's "Error: ..." line.
        page = if (id) |i| session.pageById(i) else session.selected;
        const resolved = page orelse {
            response.error_message = if (id != null) "No page found" else "No page selected";
            return try response.finish(session);
        };
        // McpPage.init: focused-page emulation, then the DevTools universe.
        try pages.emulateFocus(&ctx, resolved);
        try logpoints.initUniverse(session, resolved);
        try logpoint_tools.syncSourceMaps(&ctx, resolved);
        if (tool.set_page) response.page = resolved;
        if (tool.blocked_by_dialog) if (resolved.dialog) |d| {
            response.error_message = try std.fmt.allocPrint(arena, "A dialog is open ({s}: {s}).", .{ d.type, d.message });
            return try response.finish(session);
        };
    }
    tool.run(&ctx, arguments.object, page, &response) catch |err| switch (err) {
        error.ToolFailed => {
            if (ctx.plain) return errorResult(arena, ctx.failure orelse "Error");
            response.error_message = ctx.failure orelse "Error";
        },
        error.OutOfMemory => return error.OutOfMemory,
        else => response.error_message = try std.fmt.allocPrint(arena, "{t}", .{err}),
    };
    if (page) |resolved| if (!resolved.closed) {
        logpoint_tools.syncSourceMaps(&ctx, resolved) catch |err| if (err == error.OutOfMemory) return error.OutOfMemory;
    };
    try session.initPages();
    return try response.finish(session);
}

/// validateToolFiles (chrome-devtools-mcp v1.13.0 src/ToolHandler.ts): each
/// file parameter given as a string, or each string of an array, replaced
/// by what validateAndResolvePathOrUrl makes of it - its canonical path, a
/// file: URL of it, a remote URL kept where allowed - an empty one left out
/// (undefined). False when the policy refused one (its `message` says why).
fn checkFiles(session: *Session, arena: Allocator, tool: Tool, arguments: std.json.Value) !bool {
    if (arguments != .object) return true;
    for (tool.files) |param| {
        const slot = arguments.object.getPtr(param.name) orelse continue;
        switch (slot.*) {
            .string => |value| {
                const checked = session.paths.checkParam(arena, value, param.allow_url) catch |err| switch (err) {
                    error.Denied => return false,
                    error.OutOfMemory => return error.OutOfMemory,
                };
                slot.* = if (checked) |c| .{ .string = c } else .null;
            },
            .array => |items| {
                var kept = std.json.Array.init(arena);
                for (items.items) |item| {
                    // The schema has made every item a string.
                    if (item != .string) {
                        session.paths.message = "Unexpected non-string value as a file path or URL";
                        return false;
                    }
                    const checked = session.paths.checkParam(arena, item.string, param.allow_url) catch |err| switch (err) {
                        error.Denied => return false,
                        error.OutOfMemory => return error.OutOfMemory,
                    };
                    if (checked) |c| try kept.append(.{ .string = c });
                }
                slot.* = .{ .array = kept };
            },
            else => {},
        }
    }
    return true;
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
