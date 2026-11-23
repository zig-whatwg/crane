//! press_key and type_text - chrome-devtools-mcp's src/tools/input.ts
//! (chrome-devtools-mcp-v1.13.0, Copyright 2025 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md): keys go to the page as Puppeteer's keyboard
//! sends them (keyboard.zig), under WaitForHelper (wait.zig). The element
//! tools that take uids (click, hover, fill, drag, upload_file) come with the
//! snapshot (batch 2) and the user's element-input ruling (batch 5).

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;
const wait = @import("../wait.zig");
const keyboard = @import("../keyboard.zig");

pub const list = [_]Tool{
    .{ .name = "press_key", .page_tool = true, .blocked_by_dialog = true, .run = pressKey },
    .{ .name = "type_text", .page_tool = true, .blocked_by_dialog = true, .run = typeText },
};

/// A schema transform's (parseKey's) failure: ToolHandler's validation
/// error, the message alone.
fn validationError(ctx: *Context, tool: []const u8, field: []const u8, message: []const u8) error{ToolFailed} {
    return ctx.failPlain("Input validation error: Invalid arguments for tool {s}: {s}: {s}", .{ tool, field, message });
}

fn pressKey(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const input = registry.stringArg(args, "key") orelse return validationError(ctx, "press_key", "key", "Invalid input: expected string, received undefined");
    const keys = switch (try keyboard.parseKey(ctx.arena, input)) {
        .keys => |k| k,
        .invalid => |message| return validationError(ctx, "press_key", "key", message),
    };
    if (registry.boolArg(args, "includeSnapshot") orelse false) return ctx.fail("includeSnapshot needs take_snapshot, which Crane's MCP server does not have yet.", .{});
    const Press = struct {
        page: *Page,
        keys: []const *const keyboard.KeyDefinition,

        pub fn run(self: @This(), c: *Context) !void {
            const modifiers = self.keys[1..];
            var held: usize = 0;
            // Every modifier pressed is released, even when a later key
            // event fails (chrome-devtools-mcp #2309).
            defer {
                var i = held;
                while (i > 0) {
                    i -= 1;
                    keyUp(c, self.page, modifiers[i]) catch {};
                }
            }
            for (modifiers) |m| {
                try keyDown(c, self.page, m, true);
                held += 1;
            }
            try press(c, self.page, self.keys[0]);
        }
    };
    const result = try wait.afterAction(ctx, target, .{}, Press{ .page = target, .keys = keys });
    var names: std.Io.Writer.Allocating = .init(ctx.arena);
    for (keys[1..]) |m| try names.writer.print("{s}+", .{m.input});
    try names.writer.writeAll(keys[0].input);
    try response.line("Successfully pressed key: {s}", .{names.written()});
    response.wait_result = result.forResponse();
}

fn typeText(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const text = registry.stringArg(args, "text") orelse return validationError(ctx, "type_text", "text", "Invalid input: expected string, received undefined");
    var submit: ?*const keyboard.KeyDefinition = null;
    if (registry.stringArg(args, "submitKey")) |key| if (key.len != 0) {
        submit = keyboard.definition(key) orelse return validationError(ctx, "type_text", "submitKey", try keyboard.invalidKeyMessage(ctx.arena, key));
    };
    const Type = struct {
        page: *Page,
        text: []const u8,
        submit: ?*const keyboard.KeyDefinition,

        pub fn run(self: @This(), c: *Context) !void {
            // keyboard.type: a character the layout has is pressed, any
            // other inserted.
            const view = std.unicode.Utf8View.init(self.text) catch return c.fail("Invalid UTF-8 in text", .{});
            var it = view.iterator();
            while (it.nextCodepointSlice()) |char| {
                if (keyboard.definition(char)) |d| {
                    try press(c, self.page, d);
                } else {
                    const params = try std.fmt.allocPrint(c.arena, "{{\"text\":{f}}}", .{std.json.fmt(char, .{})});
                    try send(c, self.page, "Input.insertText", params);
                }
            }
            if (self.submit) |d| try press(c, self.page, d);
        }
    };
    const result = try wait.afterAction(ctx, target, .{}, Type{ .page = target, .text = text, .submit = submit });
    if (submit) |d| {
        try response.line("Typed text \"{s} + {s}\"", .{ text, d.input });
    } else try response.line("Typed text \"{s}\"", .{text});
    response.wait_result = result.forResponse();
}

/// Keyboard.press: down then up (no commands).
fn press(ctx: *Context, page: *Page, d: *const keyboard.KeyDefinition) !void {
    try keyDown(ctx, page, d, false);
    try keyUp(ctx, page, d);
}

fn keyDown(ctx: *Context, page: *Page, d: *const keyboard.KeyDefinition, commands: bool) !void {
    try send(ctx, page, "Input.dispatchKeyEvent", try page.keyboard.down(ctx.session.allocator, ctx.arena, d, commands));
}

fn keyUp(ctx: *Context, page: *Page, d: *const keyboard.KeyDefinition) !void {
    try send(ctx, page, "Input.dispatchKeyEvent", try page.keyboard.up(ctx.arena, d));
}

fn send(ctx: *Context, page: *Page, method: []const u8, params: []const u8) !void {
    var r = try ctx.session.client.call(method, params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |message| return ctx.fail("Protocol error ({s}): {s}", .{ method, message });
}
