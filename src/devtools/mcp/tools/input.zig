//! press_key and type_text - chrome-devtools-mcp's src/tools/input.ts
//! (chrome-devtools-mcp-v1.13.0, Copyright 2025 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md): keys go to the page as Puppeteer's keyboard
//! sends them (keyboard.zig), under WaitForHelper (wait.zig). upload_file
//! (batch 3) sets a file input's files as Puppeteer's ElementHandle.uploadFile
//! does (puppeteer-core 25.17.0 src/cdp/ElementHandle.ts: the `multiple`
//! check, DOM.describeNode, DOM.setFileInputFiles; an empty list by script),
//! its paths checked by the path policy first (verifyFilesSchema
//! {filePaths: {local: true}}: Crane's browser is local). The element tools
//! that click (click, hover, fill, drag, and upload_file's file-chooser
//! fallback) come with the user's element-input ruling (batch 5).

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;
const wait = @import("../wait.zig");
const keyboard = @import("../keyboard.zig");
const elements = @import("../elements.zig");
const snapshot_tools = @import("snapshot.zig");

pub const list = [_]Tool{
    .{ .name = "press_key", .page_tool = true, .blocked_by_dialog = true, .run = pressKey },
    .{ .name = "type_text", .page_tool = true, .blocked_by_dialog = true, .run = typeText },
    .{ .name = "upload_file", .page_tool = true, .blocked_by_dialog = true, .files = &.{.{ .name = "filePaths" }}, .run = uploadFile },
};

/// upload_file (chrome-devtools-mcp v1.13.0 src/tools/input.ts): the
/// element's uploadFile; any failure but the `multiple` assertion falls back
/// to clicking the element and accepting the file chooser it opens. Clicks
/// are batch 5's: until then the fallback says so, and never that a click
/// happened (main's ruling, 2026-11-24).
fn uploadFile(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const uid = registry.stringArg(args, "uid") orelse "";
    // validateToolFiles left the checked paths, blank ones dropped.
    var files: std.ArrayList([]const u8) = .empty;
    if (args.get("filePaths")) |paths| if (paths == .array) for (paths.array.items) |p| {
        if (p == .string) try files.append(ctx.arena, p.string);
    };
    const element = try elements.byUid(ctx, target, uid);
    defer if (element.object_id) |id| elements.release(ctx, target, id);
    setInputFiles(ctx, target, element, files.items) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.MultipleUploads => return ctx.fail("Multiple file uploads only work with <input type=file multiple>", .{}),
        else => return ctx.fail("Failed to upload file. The element could not accept the file directly, and Crane's MCP server does not click elements yet, so no file chooser was opened.", .{}),
    };
    if (registry.boolArg(args, "includeSnapshot") orelse false) response.snapshot = try snapshot_tools.capture(ctx, target, false);
    try response.line("File uploaded from {s}.", .{try std.mem.join(ctx.arena, ", ", files.items)});
}

/// ElementHandle.uploadFile's compiled callbacks (puppeteer-core 25.17.0
/// lib/puppeteer/cdp/ElementHandle.js), with Puppeteer's sourceURL.
const is_multiple =
    \\element => {
    \\                return element.multiple;
    \\            }
    \\//# sourceURL=pptr:internal
    \\
;
const clear_files =
    \\element => {
    \\                    element.files = new DataTransfer().files;
    \\                    // Dispatch events for this case because it should behave akin to a user action.
    \\                    element.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
    \\                    element.dispatchEvent(new Event('change', { bubbles: true }));
    \\                }
    \\//# sourceURL=pptr:internal
    \\
;

/// CdpElementHandle.uploadFile: `files` are already absolute.
fn setInputFiles(ctx: *Context, page: *Page, element: elements.Element, files: []const []const u8) !void {
    const object_id = element.object_id orelse return error.NotAnElement;
    const context_id = try elements.mainWorld(ctx, page, element.frame_id);
    const multiple = try callOn(ctx, page, context_id, is_multiple, element.argument);
    if (files.len > 1 and !(multiple == .bool and multiple.bool)) return error.MultipleUploads;
    if (files.len == 0) {
        _ = try callOn(ctx, page, context_id, clear_files, element.argument);
        return;
    }
    const describe_params = try std.fmt.allocPrint(ctx.arena, "{{\"objectId\":{f}}}", .{std.json.fmt(object_id, .{})});
    var described = try ctx.session.client.call("DOM.describeNode", describe_params, page.session_id, session_mod.command_timeout_ms);
    defer described.deinit();
    if (described.errorMessage() != null) return error.ProtocolError;
    const node = (described.result() orelse return error.ProtocolError).object.get("node") orelse return error.ProtocolError;
    if (node != .object) return error.ProtocolError;
    const backend = node.object.get("backendNodeId") orelse return error.ProtocolError;
    if (backend != .integer) return error.ProtocolError;
    var params: std.Io.Writer.Allocating = .init(ctx.arena);
    try params.writer.print("{{\"objectId\":{f},\"files\":[", .{std.json.fmt(object_id, .{})});
    for (files, 0..) |f, i| {
        if (i != 0) try params.writer.writeAll(",");
        try params.writer.print("{f}", .{std.json.fmt(f, .{})});
    }
    try params.writer.print("],\"backendNodeId\":{d}}}", .{backend.integer});
    var set = try ctx.session.client.call("DOM.setFileInputFiles", params.written(), page.session_id, session_mod.command_timeout_ms);
    defer set.deinit();
    if (set.errorMessage() != null) return error.ProtocolError;
}

/// ElementHandle.evaluate(fn): Runtime.callFunctionOn by value with the
/// element as its argument; the returned value (copied), or an error when it
/// threw or the call failed.
fn callOn(ctx: *Context, page: *Page, context_id: i64, declaration: []const u8, argument: []const u8) !std.json.Value {
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"functionDeclaration\":{f},\"executionContextId\":{d},\"arguments\":[{s}],\"returnByValue\":true,\"awaitPromise\":true,\"userGesture\":true}}", .{ std.json.fmt(declaration, .{}), context_id, argument });
    var r = try ctx.session.client.call("Runtime.callFunctionOn", params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage() != null) return error.ProtocolError;
    const result = r.result() orelse return error.ProtocolError;
    if (result.object.get("exceptionDetails") != null) return error.Thrown;
    const remote = result.object.get("result") orelse return .null;
    if (remote != .object) return .null;
    const value = remote.object.get("value") orelse return .null;
    // Only a boolean is read back; anything else is not one.
    return if (value == .bool) .{ .bool = value.bool } else .null;
}

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
