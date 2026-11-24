//! evaluate_script - chrome-devtools-mcp's src/tools/script.ts
//! (chrome-devtools-mcp-v1.13.0), with the CDP Puppeteer sends for it
//! (puppeteer-core 25.17.0 src/cdp/ExecutionContext.ts #evaluate,
//! src/cdp/utils.ts createEvaluationError): the source made a function by
//! Runtime.evaluate in the main frame's main world, then called through
//! Runtime.callFunctionOn by chrome-devtools-mcp's wrapper, which returns
//! JSON.stringify of its awaited result and turns a non-Error throw into an
//! Error; format "script" evaluates the source and stringifies its value.
//! The action runs under WaitForHelper (wait.zig): dialogs are accepted
//! unless `dialogAction` says otherwise, and a navigation it causes is
//! reported. Translated from the TypeScript (Copyright 2025 Google LLC and
//! Copyright 2017 Google Inc., Apache-2.0; THIRD_PARTY_NOTICES.md).
//!
//! Not yet: `sourcePath` and `filePath` (the server's file access, with
//! verifyFilesSchema's checks, comes with the transports' security, batch
//! 3) and the service worker target (extensions are a Chrome product).

const std = @import("std");
const Allocator = std.mem.Allocator;
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;
const wait = @import("../wait.zig");
const console = @import("../console.zig");

pub const list = [_]Tool{
    // evaluate_script resolves its page itself (defineTool with
    // pageIdSchema): its response does not show the page's dialog.
    .{ .name = "evaluate_script", .page_tool = true, .set_page = false, .run = evaluateScript },
};

/// PuppeteerURL.INTERNAL_URL's comment, which Puppeteer appends to what it
/// evaluates.
const source_url_comment = "//# sourceURL=pptr:internal";

/// chrome-devtools-mcp's performEvaluation callback (src/tools/script.ts).
const wrapper =
    \\async (fn, ...args) => {
    \\        try {
    \\          return JSON.stringify(await fn(...args));
    \\        } catch (err) {
    \\          if (
    \\            err instanceof Error ||
    \\            (typeof err === 'object' &&
    \\              err !== null &&
    \\              'message' in err &&
    \\              typeof err.message === 'string')
    \\          ) {
    \\            throw err;
    \\          }
    \\          let message;
    \\          try {
    \\            message =
    \\              typeof err === 'object' && err !== null
    \\                ? JSON.stringify(err)
    \\                : String(err);
    \\          } catch {
    \\            message = String(err);
    \\          }
    \\          throw new Error(message);
    \\        }
    \\      }
;

const stringify_value = "value => JSON.stringify(value)";

fn evaluateScript(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const function = registry.stringArg(args, "function");
    const source_path = registry.stringArg(args, "sourcePath");
    // resolveScriptSource.
    if (function != null and source_path != null) return ctx.fail("Specify exactly one of function or sourcePath.", .{});
    if (function == null and source_path == null) return ctx.fail("Specify exactly one of function or sourcePath.", .{});
    if (source_path != null) return ctx.fail("sourcePath is not supported by Crane's MCP server yet.", .{});
    if (registry.stringArg(args, "filePath") != null) return ctx.fail("filePath is not supported by Crane's MCP server yet.", .{});
    const format = registry.stringArg(args, "format") orelse "function";
    const uids: []const std.json.Value = if (args.get("args")) |a| (if (a == .array) a.array.items else &.{}) else &.{};
    if (std.mem.eql(u8, format, "script") and uids.len > 0) return ctx.fail("args cannot be used when format is \"script\".", .{});
    // throwIfDialogOpen: evaluate_script is not page-scoped in ToolHandler.
    if (target.dialog) |d| return ctx.fail("A dialog is open ({s}: {s}).", .{ d.type, d.message });
    // Element uids come from the page's snapshot (take_snapshot).
    if (uids.len > 0) return ctx.fail("No snapshot found for page {d}. Use take_snapshot to capture one.", .{target.id});

    const dialog_action = registry.stringArg(args, "dialogAction") orelse "accept";
    const Evaluate = struct {
        page: *Page,
        source: []const u8,
        script: bool,
        response: *Response,

        pub fn run(self: @This(), c: *Context) !void {
            const result = if (self.script) try evaluateAsScript(c, self.page, self.source) else try evaluateAsFunction(c, self.page, self.source);
            try self.response.line("Script ran on page and returned:", .{});
            try self.response.line("```json", .{});
            try self.response.line("{s}", .{result});
            try self.response.line("```", .{});
        }
    };
    const result = try wait.afterAction(ctx, target, .{
        .dialog_action = .{ .all = dialog_action },
        .wait_for_stable_dom = registry.boolArg(args, "waitForStableDom") orelse true,
    }, Evaluate{ .page = target, .source = function.?, .script = std.mem.eql(u8, format, "script"), .response = response });
    response.wait_result = result.forResponse();
}

/// format "function": the result's text (`${result}`).
fn evaluateAsFunction(ctx: *Context, page: *Page, source: []const u8) ![]const u8 {
    const trimmed = std.mem.trimEnd(u8, source, " \t\n\r\x0b\x0c");
    const function_source = if (std.mem.endsWith(u8, trimmed, ";")) trimmed[0 .. trimmed.len - 1] else trimmed;
    const expression = try std.fmt.allocPrint(ctx.arena, "(\n{s}\n)", .{function_source});
    const handle = try evaluateHandle(ctx, page, expression);
    return callWith(ctx, page, wrapper, handle);
}

/// format "script".
fn evaluateAsScript(ctx: *Context, page: *Page, source: []const u8) ![]const u8 {
    const handle = try evaluateHandle(ctx, page, source);
    return callWith(ctx, page, stringify_value, handle);
}

/// ExecutionContext.evaluateHandle(string): Runtime.evaluate in the main
/// world, by reference. The handle's CallArgument (convertArgument).
fn evaluateHandle(ctx: *Context, page: *Page, expression: []const u8) ![]const u8 {
    const arena = ctx.arena;
    const with_url = if (hasSourceUrl(expression)) expression else try std.fmt.allocPrint(arena, "{s}\n{s}\n", .{ expression, source_url_comment });
    var params: std.Io.Writer.Allocating = .init(arena);
    try params.writer.print("{{\"expression\":{f}", .{std.json.fmt(with_url, .{})});
    if (page.main_context_id) |id| try params.writer.print(",\"contextId\":{d}", .{id});
    try params.writer.writeAll(",\"returnByValue\":false,\"awaitPromise\":true,\"userGesture\":true}");
    var r = try ctx.session.client.call("Runtime.evaluate", params.written(), page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    const result = try answer(ctx, &r, "Runtime.evaluate");
    const remote = (result.object.get("result") orelse return ctx.fail("Protocol error (Runtime.evaluate): no result", .{})).object;
    var argument: std.Io.Writer.Allocating = .init(arena);
    if (remote.get("objectId")) |id| {
        try argument.writer.print("{{\"objectId\":{f}}}", .{std.json.fmt(id, .{})});
    } else if (remote.get("unserializableValue")) |u| {
        try argument.writer.print("{{\"unserializableValue\":{f}}}", .{std.json.fmt(u, .{})});
    } else if (remote.get("value")) |v| {
        try argument.writer.print("{{\"value\":{f}}}", .{std.json.fmt(v, .{})});
    } else try argument.writer.writeAll("{}");
    return argument.written();
}

/// ExecutionContext.evaluate(fn, handle): Runtime.callFunctionOn by value;
/// the string it returns, or "undefined".
fn callWith(ctx: *Context, page: *Page, declaration: []const u8, argument: []const u8) ![]const u8 {
    const arena = ctx.arena;
    const with_url = try std.fmt.allocPrint(arena, "{s}\n{s}\n", .{ declaration, source_url_comment });
    var params: std.Io.Writer.Allocating = .init(arena);
    try params.writer.print("{{\"functionDeclaration\":{f}", .{std.json.fmt(with_url, .{})});
    if (page.main_context_id) |id| {
        try params.writer.print(",\"executionContextId\":{d}", .{id});
    } else if (std.mem.startsWith(u8, argument, "{\"objectId\":")) {
        // No context known yet: the argument's own.
        const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, argument, .{});
        try params.writer.print(",\"objectId\":{f}", .{std.json.fmt(parsed.object.get("objectId").?, .{})});
    } else return ctx.fail("Execution context was destroyed, most likely because of a navigation.", .{});
    try params.writer.print(",\"arguments\":[{s}],\"returnByValue\":true,\"awaitPromise\":true,\"userGesture\":true}}", .{argument});
    var r = try ctx.session.client.call("Runtime.callFunctionOn", params.written(), page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    const result = try answer(ctx, &r, "Runtime.callFunctionOn");
    const remote = (result.object.get("result") orelse return "undefined").object;
    const value = remote.get("value") orelse return "undefined";
    var out: std.Io.Writer.Allocating = .init(arena);
    try console.jsString(&out.writer, value);
    return out.written();
}

/// SOURCE_URL_REGEX: a line that is a sourceURL comment.
fn hasSourceUrl(expression: []const u8) bool {
    var lines = std.mem.splitScalar(u8, expression, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trimStart(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "//# sourceURL=") or std.mem.startsWith(u8, trimmed, "//@ sourceURL=")) return true;
    }
    return false;
}

/// The command's result, or the error Puppeteer throws: rewriteError for a
/// lost context, createEvaluationError for an exception.
fn answer(ctx: *Context, r: *const @import("../client.zig").Response, method: []const u8) !std.json.Value {
    if (r.errorMessage()) |message| {
        if (std.mem.endsWith(u8, message, "Cannot find context with specified id") or std.mem.endsWith(u8, message, "Inspected target navigated or closed")) {
            return ctx.fail("Execution context was destroyed, most likely because of a navigation.", .{});
        }
        return ctx.fail("Protocol error ({s}): {s}", .{ method, message });
    }
    const result = r.result() orelse return ctx.fail("Protocol error ({s}): no result", .{method});
    if (result.object.get("exceptionDetails")) |details| if (details == .object) {
        return ctx.fail("{s}", .{try evaluationErrorMessage(ctx.arena, details.object)});
    };
    return result;
}

/// The message of createEvaluationError's error (what ToolHandler prints):
/// the details' text with no exception; a primitive's String(); else
/// getErrorDetails' message - the description without its stack lines and
/// without its "<className>: " prefix.
pub fn evaluationErrorMessage(arena: Allocator, details: std.json.ObjectMap) ![]const u8 {
    const exception_value = details.get("exception") orelse return session_mod.str(details.get("text"));
    if (exception_value != .object) return session_mod.str(details.get("text"));
    const exception = exception_value.object;
    const is_error = std.mem.eql(u8, session_mod.str(exception.get("type")), "object") and std.mem.eql(u8, session_mod.str(exception.get("subtype")), "error");
    if (!is_error and exception.get("objectId") == null) {
        // valueFromPrimitiveRemoteObject, then String().
        var out: std.Io.Writer.Allocating = .init(arena);
        if (exception.get("unserializableValue")) |u| {
            const text = session_mod.str(u);
            try out.writer.writeAll(if (std.mem.eql(u8, text, "-0")) "0" else if (std.mem.endsWith(u8, text, "n")) text[0 .. text.len - 1] else text);
        } else if (exception.get("value")) |v| try console.jsString(&out.writer, v) else try out.writer.writeAll("undefined");
        return out.written();
    }
    // getErrorDetails.
    var lines: std.ArrayList([]const u8) = .empty;
    if (exception.get("description")) |d| {
        var it = std.mem.splitSequence(u8, session_mod.str(d), "\n    at ");
        while (it.next()) |part| try lines.append(arena, part);
    }
    var frames: usize = 0;
    if (details.get("stackTrace")) |st| if (st == .object) if (st.object.get("callFrames")) |cf| if (cf == .array) {
        frames = cf.array.items.len;
    };
    const size = @min(frames, lines.items.len -| 1);
    lines.shrinkRetainingCapacity(lines.items.len - size);
    var message = try std.mem.join(arena, "\n", lines.items);
    const name = session_mod.str(exception.get("className"));
    if (name.len != 0 and message.len > name.len + 1 and std.mem.startsWith(u8, message, name) and std.mem.startsWith(u8, message[name.len..], ": ")) {
        message = message[name.len + 2 ..];
    }
    return message;
}

test "an evaluation error's message: the description without its stack and its class name" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const thrown =
        \\{"text":"Uncaught","exception":{"type":"object","subtype":"error","className":"TypeError","description":"TypeError: bad thing\n    at f (pptr:internal:2:7)\n    at g (pptr:internal:3:1)","objectId":"1"},"stackTrace":{"callFrames":[{},{}]}}
    ;
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, thrown, .{});
    try std.testing.expectEqualStrings("bad thing", try evaluationErrorMessage(arena, parsed.object));
    const primitive =
        \\{"text":"Uncaught","exception":{"type":"string","value":"x"}}
    ;
    const p2 = try std.json.parseFromSliceLeaky(std.json.Value, arena, primitive, .{});
    try std.testing.expectEqualStrings("x", try evaluationErrorMessage(arena, p2.object));
}
