//! Slim mode MCP tools (`--slim`, chrome-devtools-mcp v1.13.0
//! `src/tools/slim/tools.ts`, Copyright 2026 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md): `navigate`, `evaluate`, and `screenshot`.
//!
//! Slim tools never take `pageId`: they operate on the currently selected page
//! (`session.selected`).

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;
const wait = @import("../wait.zig");
const url_check = @import("../url_check.zig");
const pages = @import("pages.zig");
const logpoints = @import("../logpoints.zig");
const logpoint_tools = @import("logpoints.zig");
const script_tools = @import("script.zig");
const console = @import("../console.zig");
const elements = @import("../elements.zig");

pub const list = [_]Tool{
    .{ .name = "evaluate", .page_tool = false, .set_page = false, .slim = true, .run = evaluate },
    .{ .name = "navigate", .page_tool = false, .set_page = false, .slim = true, .run = navigate },
    .{ .name = "screenshot", .page_tool = false, .set_page = false, .files = &.{.{ .name = "filePath" }}, .slim = true, .run = screenshot },
};

const slim_navigation_timeout_ms: u32 = 30_000;
const source_url_comment = "//# sourceURL=pptr:internal";
const stringify_value = "value => JSON.stringify(value)";

fn selectedPage(ctx: *Context, response: *Response, check_dialog: bool) !*Page {
    ctx.session.snapshot();
    const target = ctx.session.selected orelse return ctx.fail("No page selected", .{});
    try pages.emulateFocus(ctx, target);
    try logpoints.initUniverse(ctx.session, target);
    try logpoint_tools.syncSourceMaps(ctx, target);
    response.page = target;
    if (check_dialog) if (target.dialog) |d| {
        return ctx.fail("A dialog is open ({s}: {s}).", .{ d.type, d.message });
    };
    return target;
}

/// `navigate`: loads `url` on the selected page (30 s timeout), auto-accepting
/// `beforeunload` dialogs, and responds `"Navigated to <url>."`.
fn navigate(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = page;
    const url = registry.stringArg(args, "url") orelse return ctx.fail("Input validation error: Invalid arguments for tool navigate: url: Invalid input: expected string, received undefined", .{});
    if (try url_check.validate(ctx.arena, url, ctx.url_options)) |message| return ctx.fail("{s}", .{message});
    const target = try selectedPage(ctx, response, false);

    const Nav = struct {
        page: *Page,
        url: []const u8,
        pub fn run(self: @This(), c: *Context) !void {
            self.page.load_fired = false;
            const params = try std.fmt.allocPrint(c.arena, "{{\"url\":{f}}}", .{std.json.fmt(self.url, .{})});
            var r = try c.session.client.call("Page.navigate", params, self.page.session_id, slim_navigation_timeout_ms);
            defer r.deinit();
            if (r.errorMessage()) |message| return c.fail("Protocol error (Page.navigate): {s}", .{message});
            const result = r.result().?.object;
            const error_text = session_mod.str(result.get("errorText"));
            if (error_text.len != 0) return c.fail("{s} at {s}", .{ error_text, self.url });
            if (result.get("loaderId") == null) return;
            const Loaded = struct {
                p: *Page,
                fn done(s: @This()) bool {
                    return s.p.load_fired or s.p.closed;
                }
            };
            if (!try c.session.waitUntil(slim_navigation_timeout_ms, Loaded{ .p = self.page }, Loaded.done)) {
                return c.fail("Navigation timeout of {d} ms exceeded", .{slim_navigation_timeout_ms});
            }
        }
    };

    const result = try wait.afterAction(ctx, target, .{
        .timeout = slim_navigation_timeout_ms,
        .dialog_action = .{ .beforeunload = "accept" },
        .wait_for_stable_dom = false,
    }, Nav{ .page = target, .url = url });
    if (result.dialog_handled) {
        try response.line("Accepted a beforeunload dialog.", .{});
        target.clearDialog(ctx.session.allocator);
    }
    const final_url = if (target.url.len != 0) target.url else url;
    try response.line("Navigated to {s}.", .{final_url});
}

/// `evaluate`: evaluates a JavaScript expression/script on the selected page
/// and responds with `JSON.stringify(result)`.
fn evaluate(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = page;
    const source = registry.stringArg(args, "script") orelse return ctx.fail("Input validation error: Invalid arguments for tool evaluate: script: Invalid input: expected string, received undefined", .{});
    const target = try selectedPage(ctx, response, true);
    const context_id = target.main_context_id;

    // Evaluate by handle first, then JSON.stringify(result) in page (matching
    // `JSON.stringify(await page.pptrPage.evaluate(script))`).
    const with_url = try std.fmt.allocPrint(ctx.arena, "{s}\n{s}\n", .{ source, source_url_comment });
    var eval_params: std.Io.Writer.Allocating = .init(ctx.arena);
    try eval_params.writer.print("{{\"expression\":{f}", .{std.json.fmt(with_url, .{})});
    if (context_id) |id| try eval_params.writer.print(",\"contextId\":{d}", .{id});
    try eval_params.writer.writeAll(",\"returnByValue\":false,\"awaitPromise\":true,\"userGesture\":true}");
    var r = try ctx.session.client.call("Runtime.evaluate", eval_params.written(), target.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |message| return ctx.fail("Protocol error (Runtime.evaluate): {s}", .{message});
    const result = r.result() orelse return ctx.fail("Protocol error (Runtime.evaluate): no result", .{});
    if (result.object.get("exceptionDetails")) |details| if (details == .object) {
        return ctx.fail("{s}", .{try script_tools.evaluationErrorMessage(ctx.arena, details.object)});
    };
    const remote = (result.object.get("result") orelse return ctx.fail("Protocol error (Runtime.evaluate): no result", .{})).object;

    var arg_buf: std.Io.Writer.Allocating = .init(ctx.arena);
    var object_id: ?[]const u8 = null;
    if (remote.get("objectId")) |id| {
        object_id = try ctx.arena.dupe(u8, session_mod.str(id));
        try arg_buf.writer.print("{{\"objectId\":{f}}}", .{std.json.fmt(id, .{})});
    } else if (remote.get("unserializableValue")) |u| {
        try arg_buf.writer.print("{{\"unserializableValue\":{f}}}", .{std.json.fmt(u, .{})});
    } else if (remote.get("value")) |v| {
        try arg_buf.writer.print("{{\"value\":{f}}}", .{std.json.fmt(v, .{})});
    } else {
        // undefined -> JSON.stringify(undefined) === undefined -> empty line.
        try response.line("", .{});
        return;
    }
    defer if (object_id) |id| elements.release(ctx, target, id);

    var call_params: std.Io.Writer.Allocating = .init(ctx.arena);
    const fn_decl = stringify_value ++ "\n" ++ source_url_comment ++ "\n";
    try call_params.writer.print("{{\"functionDeclaration\":{f}", .{std.json.fmt(fn_decl, .{})});
    if (context_id) |id| {
        try call_params.writer.print(",\"executionContextId\":{d}", .{id});
    } else if (object_id) |id| {
        try call_params.writer.print(",\"objectId\":{f}", .{std.json.fmt(id, .{})});
    } else {
        return ctx.fail("Execution context was destroyed, most likely because of a navigation.", .{});
    }
    try call_params.writer.print(",\"arguments\":[{s}],\"returnByValue\":true,\"awaitPromise\":true,\"userGesture\":true}}", .{arg_buf.written()});
    var cr = try ctx.session.client.call("Runtime.callFunctionOn", call_params.written(), target.session_id, session_mod.command_timeout_ms);
    defer cr.deinit();
    if (cr.errorMessage()) |message| return ctx.fail("Protocol error (Runtime.callFunctionOn): {s}", .{message});
    const cresult = cr.result() orelse return ctx.fail("Protocol error (Runtime.callFunctionOn): no result", .{});
    if (cresult.object.get("exceptionDetails")) |details| if (details == .object) {
        return ctx.fail("{s}", .{try script_tools.evaluationErrorMessage(ctx.arena, details.object)});
    };
    const cremote = (cresult.object.get("result") orelse {
        try response.line("", .{});
        return;
    }).object;
    const val = cremote.get("value") orelse {
        try response.line("", .{});
        return;
    };
    var out: std.Io.Writer.Allocating = .init(ctx.arena);
    try console.jsString(&out.writer, val);
    try response.line("{s}", .{out.written()});
}

/// `screenshot`: needs-renderer error naming the missing renderer cleanly.
fn screenshot(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = .{ args, page };
    _ = try selectedPage(ctx, response, true);
    return ctx.fail("screenshot is not supported by Crane's MCP server: Crane is headless and has no renderer to capture screenshots.", .{});
}
